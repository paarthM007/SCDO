"""
monte_carlo.py - MC runner with CTR-synchronized formulas.
SCDO Logistics Engine v3.0: Uses identical cost/time models as the Router,
adding Gaussian noise (σ) for real-world variance simulation.
"""
import simpy
import random
import time
import uuid
import logging
import numpy as np
from typing import List, Optional
from concurrent.futures import ProcessPoolExecutor
from multiprocessing import cpu_count

from scdo.simulation.entities import Shipment, to_native
from scdo.simulation.nodes import Node, FacilityClearance
from scdo.simulation.links import TransportLink
from scdo.simulation.route_builder import build_route_with_nodes
from scdo.config import (
    ALPHA_COST_PENALTY, BETA_DELAY_COEFF,
    SPEED_CONSTANTS, VARIABLE_RATE, FIXED_OVERHEAD,
    PROCESSING_TIME, DEFAULT_QUANTITY, DEFAULT_PRODUCT_TYPE,
)

logger = logging.getLogger(__name__)

# ── Risk-aware scaling constants ──────────────────────────────
RISK_DELAY_SCALE = 1.0
RISK_COST_SCALE = 0.6

# ── v3.0: Gaussian noise parameters for MC stochastic simulation ──
# These σ values are added to base CTR calculations to model real-world variance.
NOISE_SIGMA = {
    "cost_fraction": 0.08,   # ±8% cost variance
    "time_fraction": 0.12,   # ±12% time variance
    "risk_sigma":    0.05,   # ±0.05 risk score jitter
}


def _apply_gaussian_noise(base_value: float, sigma_fraction: float) -> float:
    """Apply Gaussian noise to a base value. Ensures result stays positive."""
    noise = random.gauss(0, base_value * sigma_fraction) if base_value > 0 else 0
    return max(0.01, base_value + noise)


def monte_carlo_des(locations, modes, n_iterations=100, seed=42,
                    importance_boost=1.0, facility_configs=None, gmaps=None,
                    combined_risk_score=0.0,
                    # ── v3.0 CTR parameters ──
                    quantity=None, product_type=None, path_edges=None):
    """
    Runs DES N times using pure Monte Carlo + importance sampling.
    
    v3.0: Combined risk scales delays/costs using the SAME CTR formulas
    as the Router (compute_edge_cost / compute_edge_time), but with
    Gaussian noise (σ) added to model real-world stochastic variance.
    """
    random.seed(seed)
    np.random.seed(seed)

    Q = quantity if quantity is not None else DEFAULT_QUANTITY
    pt = product_type or DEFAULT_PRODUCT_TYPE

    # CTR-synchronized risk multipliers
    delay_multiplier = 1.0 + BETA_DELAY_COEFF * combined_risk_score
    cost_multiplier = 1.0 + ALPHA_COST_PENALTY * combined_risk_score

    # Also maintain legacy multipliers for backward compat
    legacy_delay = 1.0 + RISK_DELAY_SCALE * combined_risk_score
    legacy_cost = 1.0 + RISK_COST_SCALE * combined_risk_score

    times, costs, weights = [], [], []
    mc_start = time.time()

    for i in range(n_iterations):
        env = simpy.Environment()
        planner = build_route_with_nodes(env, locations, modes, gmaps, facility_configs, path_edges=path_edges)

        # Inject importance boost
        if importance_boost != 1.0:
            for element in planner.route:
                if isinstance(element, FacilityClearance):
                    element._importance_boost = importance_boost

        # ── v3.0: Apply CTR-synchronized risk multipliers with Gaussian noise ──
        if combined_risk_score > 0:
            # Add per-iteration stochastic jitter to risk score
            noisy_risk = max(0.0, min(1.0,
                combined_risk_score + random.gauss(0, NOISE_SIGMA["risk_sigma"])
            ))
            iter_delay_mult = 1.0 + BETA_DELAY_COEFF * noisy_risk
            iter_cost_mult = 1.0 + ALPHA_COST_PENALTY * noisy_risk

            for element in planner.route:
                element._risk_delay_multiplier = _apply_gaussian_noise(
                    iter_delay_mult, NOISE_SIGMA["time_fraction"]
                )
                element._risk_cost_multiplier = _apply_gaussian_noise(
                    iter_cost_mult, NOISE_SIGMA["cost_fraction"]
                )

        shipment = Shipment(env, f"MC-{i+1:03d}")

        def _run(sh=shipment, rt=planner.route):
            for el in rt:
                if isinstance(el, Node):
                    yield env.process(el.process(sh))
                elif isinstance(el, TransportLink):
                    yield env.process(el.traverse(sh))

        env.process(_run())
        env.run()

        iter_weight = 1.0
        for element in planner.route:
            if isinstance(element, FacilityClearance) and hasattr(element, '_is_weight'):
                iter_weight *= element._is_weight

        times.append(env.now)
        costs.append(shipment.total_cost)
        weights.append(iter_weight)

    mc_elapsed = time.time() - mc_start
    logger.info(f"MC completed: {n_iterations} iterations in {mc_elapsed:.2f}s "
                f"(Q={Q}, type={pt}, risk={combined_risk_score:.2f})")

    stats = calculate_stats(times, costs, weights, n_iterations,
                            importance_boost > 1.0)

    # ── v3.0: Attach CTR metadata to stats ──
    stats["ctr_params"] = {
        "quantity": Q,
        "product_type": pt,
        "risk_score": round(combined_risk_score, 4),
        "delay_coefficient_beta": BETA_DELAY_COEFF,
        "cost_penalty_alpha": ALPHA_COST_PENALTY,
        "noise_sigma": NOISE_SIGMA,
    }

    return stats


def calculate_stats(times, costs, weights, n_iterations,
                    use_importance_weights=False):
    """Computes summary statistics with optional importance-sampling reweighting."""
    times = np.array(times)
    costs = np.array(costs)
    w = np.array(weights)

    if use_importance_weights and np.any(w != 1.0):
        w_norm = w / w.sum()
        t_mean = float(np.sum(w_norm * times))
        c_mean = float(np.sum(w_norm * costs))
        t_std = float(np.sqrt(np.sum(w_norm * (times - t_mean) ** 2)))
        c_std = float(np.sqrt(np.sum(w_norm * (costs - c_mean) ** 2)))
        n_eff = float((w.sum() ** 2) / (w ** 2).sum())
        method = "Importance-Weighted Monte Carlo"
    else:
        t_mean = float(np.mean(times))
        c_mean = float(np.mean(costs))
        t_std = float(np.std(times))
        c_std = float(np.std(costs))
        n_eff = float(n_iterations)
        method = "Monte Carlo"

    return {
        "iterations": n_iterations,
        "effective_n": round(n_eff, 1),
        "method": method,
        "time": {
            "mean": round(t_mean, 2), "std": round(t_std, 2),
            "min": round(float(np.min(times)), 2),
            "max": round(float(np.max(times)), 2),
            "p5": round(float(np.percentile(times, 5)), 2),
            "p50": round(float(np.percentile(times, 50)), 2),
            "p95": round(float(np.percentile(times, 95)), 2),
            "ci_95": [round(t_mean - 1.96 * t_std / np.sqrt(n_eff), 2),
                      round(t_mean + 1.96 * t_std / np.sqrt(n_eff), 2)]
        },
        "cost": {
            "mean": round(c_mean, 2), "std": round(c_std, 2),
            "min": round(float(np.min(costs)), 2),
            "max": round(float(np.max(costs)), 2),
            "p5": round(float(np.percentile(costs, 5)), 2),
            "p50": round(float(np.percentile(costs, 50)), 2),
            "p95": round(float(np.percentile(costs, 95)), 2),
            "ci_95": [round(c_mean - 1.96 * c_std / np.sqrt(n_eff), 2),
                      round(c_mean + 1.96 * c_std / np.sqrt(n_eff), 2)]
        }
    }


def run_simulation_with_risk(cities, modes, cargo_type="general",
                             target_date=None, n_iterations=50, seed=42,
                             importance_boost=1.0, facility_configs=None,
                             # ── v3.0 CTR parameters ──
                             quantity=None, product_type=None, path_edges=None):
    """
    Complete entry point: fetches combined risk, runs MC, returns result dict.
    Called by worker.py.
    
    v3.0: Forwards quantity and product_type to Monte Carlo engine for
    CTR-synchronized stochastic simulation.
    """
    from scdo.risk.combined_risk import compute_combined_risk
    from datetime import datetime, timezone

    logger.info("=== run_simulation_with_risk ===")
    logger.info("  Cities: %s, Modes: %s, Q=%s, Type=%s",
                cities, modes, quantity, product_type)

    # Step 1: Compute combined risk
    try:
        risk_result = compute_combined_risk(cities, cargo_type, target_date)
        combined_risk_score = risk_result.get("combined_risk_score", 0.0)
    except Exception as e:
        logger.error("Combined risk failed: %s. Using 0.0.", e)
        risk_result = {"combined_risk_score": 0.0, "risk_level": "UNKNOWN", "error": str(e)}
        combined_risk_score = 0.0

    # Step 2: Run Monte Carlo with CTR parameters
    sim_stats = monte_carlo_des(
        locations=cities, modes=modes,
        n_iterations=n_iterations, seed=seed,
        importance_boost=importance_boost,
        facility_configs=facility_configs,
        combined_risk_score=combined_risk_score,
        quantity=quantity,
        product_type=product_type,
        path_edges=path_edges,
    )

    # Step 3: Assemble result
    result = to_native({
        "job_meta": {
            "cities": cities, "modes": modes,
            "cargo_type": cargo_type, "target_date": target_date,
            "n_iterations": n_iterations, "seed": seed,
            "quantity": quantity,
            "product_type": product_type or cargo_type,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        },
        "combined_risk": {
            "score": combined_risk_score,
            "level": risk_result.get("risk_level", "UNKNOWN"),
            "route_viable": risk_result.get("route_viable", True),
            "recommendation": risk_result.get("recommendation", ""),
            "weather_risk": risk_result.get("weather_risk", {}),
            "sentiment_risk": risk_result.get("sentiment_risk", {}),
            "community_risk": risk_result.get("community_risk", {}),
        },
        "simulation_stats": sim_stats,
    })

    logger.info("=== Simulation complete ===")
    return result


# ── Process-pool job runner (for worker.py) ───────────────────
def _run_mc_job(job_config):
    """Top-level worker for ProcessPoolExecutor. Must be top-level for pickling."""
    job_id = job_config["job_id"]
    try:
        result = run_simulation_with_risk(
            cities=job_config["cities"],
            modes=job_config["modes"],
            cargo_type=job_config.get("cargo_type", "general"),
            target_date=job_config.get("target_date"),
            n_iterations=job_config.get("n_iterations", 50),
            seed=job_config.get("seed", 42),
            importance_boost=job_config.get("importance_boost", 1.0),
            facility_configs=job_config.get("facility_configs"),
            quantity=job_config.get("quantity"),
            product_type=job_config.get("product_type"),
            path_edges=job_config.get("path_edges"),
        )
        return {"job_id": job_id, "status": "done", "result": result, "error": None}
    except Exception as e:
        return {"job_id": job_id, "status": "error", "result": None, "error": str(e)}
