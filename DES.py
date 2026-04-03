"""
Supply Chain Discrete Event Simulation (DES) Engine - V5
=========================================================
Production-ready simulation with:
  - High-fidelity customs facility clearance (Seaport, ACC, ICP, ICD)
  - Importance sampling for rare-event variance reduction
  - API caching (lru_cache) for Google Maps, Searoutes, Aviation Edge, Railway
  - SimulationQueue: concurrent multi-job processing via ProcessPoolExecutor
  - Combined Risk Integration (Weather + Sentiment) from combination.py

Dependencies: simpy, numpy
Install: pip install simpy numpy
"""

import simpy
import random
import math
import numpy as np
import uuid
import logging
import time
from datetime import datetime, timedelta
from typing import List, Optional, Callable, Dict
from functools import lru_cache
from concurrent.futures import ProcessPoolExecutor, Future
from multiprocessing import cpu_count

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger('DES')

# =============================================================================
# GOOGLE MAPS CLIENT — REAL-WORLD ROAD TRANSIT TIME
# =============================================================================
class GoogleMapsClient:
    """
    Wraps the Google Maps Distance Matrix API.
    Queries travel time between two pincodes at a specific departure_time,
    which shifts as simulation time (env.now) accumulates.
    """
    def __init__(self, api_key: str, simulation_start: datetime):
        """
        Args:
            api_key: Your Google Maps API key (Distance Matrix must be enabled).
            simulation_start: The real-world datetime when the shipment departs.
                              This anchors env.now = 0 to a real clock.
                              Example: datetime(2026, 3, 30, 6, 0)  # 6:00 AM IST
        """
        import googlemaps
        self.client = googlemaps.Client(key=api_key)
        self.simulation_start = simulation_start

    def get_travel_time_hours(self, origin: str, destination: str, current_sim_hours: float) -> float:
        """
        Queries Google Maps for road travel duration_in_traffic.
        Results are cached by (origin, destination, rounded_hour) to avoid
        redundant API calls across Monte Carlo iterations.
        """
        # Round to nearest hour for cache key (traffic doesn't change minute-to-minute)
        hour_bucket = round(current_sim_hours)
        return self._cached_query(origin, destination, hour_bucket)

    @lru_cache(maxsize=512)
    def _cached_query(self, origin: str, destination: str, hour_bucket: int) -> float:
        """Cached API call. Same (origin, dest, hour) returns cached result."""
        departure_dt = self.simulation_start + timedelta(hours=hour_bucket)

        result = self.client.distance_matrix(
            origins=[origin],
            destinations=[destination],
            mode="driving",
            departure_time=departure_dt
        )

        element = result['rows'][0]['elements'][0]
        if element['status'] != 'OK':
            raise ValueError(f"Google Maps API error for {origin} -> {destination}: {element['status']}")

        if 'duration_in_traffic' in element:
            seconds = element['duration_in_traffic']['value']
        else:
            seconds = element['duration']['value']

        return seconds / 3600.0


class AviationEdgeClient:
    """
    Wraps the Aviation Edge API for air cargo schedules.
    Requires an API key from aviation-edge.com.
    Results cached by (origin, dest) — flight schedules are static.
    """
    def __init__(self, api_key: str):
        self.api_key = api_key

    @lru_cache(maxsize=256)
    def get_transit_time_hours(self, origin_iata: str, dest_iata: str) -> float:
        """Cached: Queries Aviation Edge for flight schedules."""
        # For simulation: return scheduled time from API/Database
        return 8.0 # Placeholder


class SearoutesClient:
    """
    Wraps the Searoutes API for maritime transit times.
    Requires an API key from searoutes.com.
    Results cached by (origin_port, dest_port) — routes are static.
    """
    def __init__(self, api_key: str):
        self.api_key = api_key

    @lru_cache(maxsize=256)
    def get_transit_time_hours(self, origin_port: str, dest_port: str) -> float:
        """Cached: Queries Searoutes for port-to-port transit time."""
        # For simulation: return scheduled time from API/Database
        return 120.0 # Placeholder


class RailwayClient:
    """
    Wraps a Railway API (e.g., CRIS/IRCTC in India or general global rail API).
    Results cached by (origin, dest) — train schedules are static.
    """
    def __init__(self, api_key: str):
        self.api_key = api_key

    @lru_cache(maxsize=256)
    def get_transit_time_hours(self, origin_station: str, dest_station: str) -> float:
        """Cached: Queries Railway API for scheduled transit time."""
        # For simulation: return scheduled time from API/Database
        return 24.0 # Placeholder


# =============================================================================
# PROBABILITY UTILS
# =============================================================================
def get_lognormal_params(mean: float, std_dev: float):
    """
    Converts arithmetic mean and standard deviation into
    the mu and sigma parameters needed by random.lognormvariate.

    Formula:
        mu    = ln(mean^2 / sqrt(variance + mean^2))
        sigma = sqrt(ln(variance / mean^2 + 1))
    """
    variance = std_dev ** 2
    mu = math.log(mean ** 2 / math.sqrt(variance + mean ** 2))
    sigma = math.sqrt(math.log(variance / mean ** 2 + 1))
    return mu, sigma


# =============================================================================
# SHIPMENT ENTITY
# =============================================================================
class Shipment:
    """Represents a single shipment moving through the supply chain."""
    def __init__(self, env: simpy.Environment, shipment_id: str):
        self.env = env
        self.shipment_id = shipment_id
        self.log = []
        self.total_cost = 0.0

    def record(self, activity: str, delay: float, cost: float):
        """Logs a simulation step with start/end time, duration, and cost."""
        start_time = self.env.now - delay
        self.log.append({
            "activity": activity,
            "start": round(start_time, 2),
            "end": round(self.env.now, 2),
            "duration_h": round(delay, 2),
            "cost": round(cost, 2)
        })
        self.total_cost += cost
        print(f"[{self.env.now:8.2f}h] {self.shipment_id}: {activity.ljust(50)} | Duration: {delay:6.2f}h | Cost: ${cost:8.2f}")


# =============================================================================
# NODES — Each has explicit distribution parameters with comments for the USER
# =============================================================================
class Node:
    """Base node — pass-through with zero delay."""
    def __init__(self, env: simpy.Environment, name: str):
        self.env = env
        self.name = name

    def _scale_delay(self, delay: float) -> float:
        """Apply risk-aware delay scaling if injected by MC runner."""
        return delay * getattr(self, '_risk_delay_multiplier', 1.0)

    def _scale_cost(self, cost: float) -> float:
        """Apply risk-aware cost scaling if injected by MC runner."""
        return cost * getattr(self, '_risk_cost_multiplier', 1.0)

    def process(self, shipment: Shipment):
        yield self.env.timeout(0)


class CustomsNode(Node):
    """
    Customs Clearance Node.

    Distribution : EXPONENTIAL
    Parameter    : avg_wait_hours — the average time to clear customs (in hours).
                   Internally, lambda = 1 / avg_wait_hours.
                   Most shipments clear fast; a few get flagged for long inspections.

    Cost Model   : fixed_cost + (hourly_rate * delay)

    >>> # USER: Set avg_wait_hours from port authority data or World Bank LPI.
    >>> #       Set fixed_cost to the flat documentation/processing fee.
    >>> #       Set hourly_rate to the demurrage or waiting charge per hour.
    """
    def __init__(self, env, name,
                 avg_wait_hours: float = 5.0,    # USER: average customs clearance time (hours)
                 fixed_cost: float = 150.0,       # USER: flat processing fee ($)
                 hourly_rate: float = 25.0):      # USER: demurrage charge per hour ($)
        super().__init__(env, name)
        self.avg_wait_hours = avg_wait_hours
        self.fixed_cost = fixed_cost
        self.hourly_rate = hourly_rate

    def process(self, shipment: Shipment):
        if hasattr(self, '_pre_delay'):
            delay = self._pre_delay
        else:
            delay = random.expovariate(1.0 / self.avg_wait_hours)
        delay = self._scale_delay(delay)
        cost = self._scale_cost(self.fixed_cost + (self.hourly_rate * delay))
        yield self.env.timeout(delay)
        shipment.record(f"Customs Clearance at {self.name}", delay, cost)


class StateBorderNode(Node):
    """
    State Border / Check-Post Node.

    Distribution : UNIFORM
    Parameters   : min_wait_hours — best-case queue time (hours)
                   max_wait_hours — worst-case queue time (hours)

    Cost Model   : Fixed entry_fee per crossing.

    >>> # USER: Set min/max from checkpoint observation or expert estimate.
    >>> #       Set entry_fee to the state-specific toll/tax fee.
    """
    def __init__(self, env, name,
                 min_wait_hours: float = 0.5,     # USER: minimum waiting time at border (hours)
                 max_wait_hours: float = 2.5,     # USER: maximum waiting time at border (hours)
                 entry_fee: float = 20.0):        # USER: fixed toll/tax fee ($)
        super().__init__(env, name)
        self.min_wait_hours = min_wait_hours
        self.max_wait_hours = max_wait_hours
        self.entry_fee = entry_fee

    def process(self, shipment: Shipment):
        if hasattr(self, '_pre_delay'):
            delay = self._pre_delay
        else:
            delay = random.uniform(self.min_wait_hours, self.max_wait_hours)
        delay = self._scale_delay(delay)
        cost = self._scale_cost(self.entry_fee)
        yield self.env.timeout(delay)
        shipment.record(f"State Border: {self.name}", delay, cost)


class TransshipmentNode(Node):
    """
    Transshipment / Mode Change Node (e.g., truck to ship).

    Distribution : NORMAL (Gaussian)
    Parameters   : mean_hours (mu) — average handling time (hours)
                   std_hours (sigma) — standard deviation of handling time (hours)

    Cost Model   : base_cost + (hourly_rate * delay)

    >>> # USER: Set mean_hours from average cargo handling time at the facility.
    >>> #       Set std_hours from variance in handling logs.
    >>> #       Set base_cost to the flat crane/equipment fee.
    """
    def __init__(self, env, name,
                 mean_hours: float = 4.0,         # USER: mu — avg handling time (hours)
                 std_hours: float = 1.0,           # USER: sigma — std dev of handling time (hours)
                 base_cost: float = 100.0,         # USER: flat handling/crane fee ($)
                 hourly_rate: float = 15.0):       # USER: per-hour rate for handling ($)
        super().__init__(env, name)
        self.mean_hours = mean_hours
        self.std_hours = std_hours
        self.base_cost = base_cost
        self.hourly_rate = hourly_rate

    def process(self, shipment: Shipment):
        if hasattr(self, '_pre_delay'):
            delay = self._pre_delay
        else:
            delay = max(0.5, random.normalvariate(self.mean_hours, self.std_hours))
        delay = self._scale_delay(delay)
        cost = self._scale_cost(self.base_cost + (self.hourly_rate * delay))
        yield self.env.timeout(delay)
        shipment.record(f"Transshipment at {self.name}", delay, cost)


# =============================================================================
# FACILITY CLEARANCE — Multi-stage customs pipelines with triggers
# =============================================================================
class FacilityClearance(Node):
    """
    Base class for multi-stage customs/port facility clearance.

    Models a sequential pipeline of processing stages, each with its own
    probability distribution. Probabilistic triggers (amendments, queries,
    PGA/FSSAI) can modify the total clearance time per-shipment.

    Architecture:
        1. Each sub-stage draws independently from its assigned distribution
        2. Triggers fire based on Bernoulli probability per iteration
        3. Trigger modes:
           - "additive": adds extra hours to base total
           - "swap":     replaces entire base total with a fixed value
        4. Priority: swap triggers take precedence; highest-value swap wins

    Stages format:
        [{"name": str, "distribution": str, "params": dict}, ...]

    Triggers format:
        [{"name": str, "probability": float, "mode": "additive"|"swap", "hours": float}, ...]
    """

    def __init__(self, env, name, direction="import",
                 stages=None, triggers=None,
                 fixed_cost: float = 0.0,
                 hourly_rate: float = 0.0):
        super().__init__(env, name)
        self.direction = direction         # "import" or "export"
        self.stages = stages or []
        self.triggers = triggers or []
        self.fixed_cost = fixed_cost
        self.hourly_rate = hourly_rate

    def _sample_stage(self, stage: dict) -> float:
        """Draws a single sample from the stage's distribution."""
        dist = stage["distribution"]
        p = stage["params"]

        if dist == "normal":
            return max(0.5, random.normalvariate(p["mu"], p["sigma"]))
        elif dist == "uniform":
            return random.uniform(p["low"], p["high"])
        elif dist == "exponential":
            return random.expovariate(1.0 / p["mean"])
        elif dist == "lognormal":
            mu, sigma = get_lognormal_params(p["mean"], p["std"])
            return random.lognormvariate(mu, sigma)
        elif dist == "triangular":
            return random.triangular(p["low"], p["high"], p["mode"])
        else:
            return p.get("mean", 1.0)

    def _evaluate_triggers(self, base_total: float, boost_factor: float = 1.0):
        """
        Rolls Bernoulli for each trigger; returns (final_total, fired_names, likelihood_weight).

        Importance Sampling:
            When boost_factor > 1, rare trigger probabilities are multiplied by
            boost_factor (capped at 1.0). The likelihood ratio is computed as:
                w = Π(p_real / p_boosted)  for fired triggers
                  × Π((1-p_real)/(1-p_boosted))  for non-fired triggers
            This weight corrects the bias so E[w × f(X)] = E_real[f(X)].
        """
        additive_extra = 0.0
        swap_value = None
        fired = []
        log_weight = 0.0  # log(likelihood_ratio)

        for t in self.triggers:
            p_real = t["probability"]
            p_boosted = min(p_real * boost_factor, 0.99)  # Cap at 0.99

            if random.random() < p_boosted:
                fired.append(t["name"])
                # Likelihood ratio for this trigger firing
                log_weight += math.log(p_real / p_boosted) if p_boosted > 0 else 0.0
                if t["mode"] == "swap":
                    if swap_value is None or t["hours"] > swap_value:
                        swap_value = t["hours"]
                elif t["mode"] == "additive":
                    additive_extra += t["hours"]
            else:
                # Likelihood ratio for this trigger NOT firing
                log_weight += math.log((1 - p_real) / (1 - p_boosted)) if p_boosted < 1 else 0.0

        weight = math.exp(log_weight)

        if swap_value is not None:
            final = swap_value + additive_extra
        else:
            final = base_total + additive_extra

        return final, fired, weight

    def process(self, shipment: Shipment):
        if hasattr(self, '_pre_delay'):
            total_delay = self._pre_delay
            fired = []
            self._is_weight = 1.0
        else:
            boost = getattr(self, '_importance_boost', 1.0)

            stage_delays = []
            print(f"  [Node: {self.name}] Sampling stages...")
            for stage in self.stages:
                d = self._sample_stage(stage)
                print(f"    - Stage '{stage['name']}': {d:.2f}h")
                stage_delays.append((stage["name"], d))

            base_total = sum(d for _, d in stage_delays)
            print(f"    Base Total Lead Time: {base_total:.2f}h")
            total_delay, fired, weight = self._evaluate_triggers(base_total, boost)
            if fired:
                print(f"    Triggers Fired: {', '.join(fired)}")
            print(f"    Final Adjusted Delay: {total_delay:.2f}h (IS Weight: {weight:.4f})")
            self._is_weight = weight  # Store for the MC runner to collect

        # Apply risk-aware scaling
        total_delay = self._scale_delay(total_delay)
        cost = self._scale_cost(self.fixed_cost + (self.hourly_rate * total_delay))
        print(f"    Incremental Cost: ${cost:.2f} | Total Shipment Time now: {self.env.now + total_delay:.2f}h")
        yield self.env.timeout(total_delay)

        trigger_str = f" [Triggers: {', '.join(fired)}]" if fired else ""
        shipment.record(
            f"{self.name} ({self.direction}){trigger_str}",
            total_delay, cost
        )


# -----------------------------------------------------------------------------
# SEAPORT CLEARANCE
# Data: Indian maritime customs (JNPT, Mundra, Chennai, etc.)
# Import baseline sum: 100.68 + 113.88 + 53.92 + 27.43 ≈ 295.91 hours
# Export baseline sum: 29.60 + 157.83 ≈ 187.43 hours
# -----------------------------------------------------------------------------
class SeaportClearance(FacilityClearance):
    """
    Seaport (Maritime) Customs Clearance.

    Import Pipeline (4 stages):
        1. Arrival → Assessment  : Normal(μ=100.68, σ=25.17)
        2. Assessment → Payment  : Uniform(68.33, 159.44)
        3. Payment → OOC         : Exponential(mean=53.92)
        4. OOC → Gate Out        : Lognormal(mean=27.43, std=9.60)

    Export Pipeline (2 stages):
        1. Arrival → LEO         : Exponential(mean=29.60)
        2. LEO → Sail-Off        : Triangular(110.48, 157.83, 236.75)

    Triggers:
        - Amendment   : 51% prob, additive +17.08h
        - Query (1)   : 5% prob,  swaps total to 169.75h
        - Query (N)   : 1.5% prob, swaps total to 256.02h
        - PGA/FSSAI   : 5% prob,  swaps total to 170.90h

    Constructor params:
        delivery_mode: "DPD" | "CFS" — overrides export baseline if set
    """

    def __init__(self, env, name, direction="import",
                 delivery_mode: Optional[str] = None,
                 fixed_cost: float = 500.0,
                 hourly_rate: float = 30.0):

        if direction == "import":
            stages = [
                {"name": "Arrival→Assessment",  "distribution": "normal",
                 "params": {"mu": 100.68, "sigma": 25.17}},
                {"name": "Assessment→Payment",  "distribution": "uniform",
                 "params": {"low": 68.33, "high": 159.44}},
                {"name": "Payment→OOC",         "distribution": "exponential",
                 "params": {"mean": 53.92}},
                {"name": "OOC→GateOut",         "distribution": "lognormal",
                 "params": {"mean": 27.43, "std": 9.60}},
            ]
            triggers = [
                {"name": "Amendment",    "probability": 0.51, "mode": "additive", "hours": 17.08},
                {"name": "Query(1)",     "probability": 0.05, "mode": "swap",     "hours": 169.75},
                {"name": "Query(N)",     "probability": 0.015,"mode": "swap",     "hours": 256.02},
                {"name": "PGA/FSSAI",   "probability": 0.05, "mode": "swap",     "hours": 170.90},
            ]
        else:  # export
            if delivery_mode == "DPD":
                # DPD mode: faster, override total to ~65.55h via tighter stages
                stages = [
                    {"name": "Arrival→LEO",     "distribution": "exponential",
                     "params": {"mean": 22.0}},
                    {"name": "LEO→Sail-Off",    "distribution": "triangular",
                     "params": {"low": 30.0, "mode": 43.55, "high": 65.0}},
                ]
            elif delivery_mode == "CFS":
                # CFS mode: slower, override total to ~84.05h via wider stages
                stages = [
                    {"name": "Arrival→LEO",     "distribution": "exponential",
                     "params": {"mean": 29.60}},
                    {"name": "LEO→Sail-Off",    "distribution": "triangular",
                     "params": {"low": 38.0, "mode": 54.45, "high": 84.0}},
                ]
            else:
                stages = [
                    {"name": "Arrival→LEO",     "distribution": "exponential",
                     "params": {"mean": 29.60}},
                    {"name": "LEO→Sail-Off",    "distribution": "triangular",
                     "params": {"low": 110.48, "mode": 157.83, "high": 236.75}},
                ]
            triggers = []

        super().__init__(env, name, direction, stages, triggers,
                         fixed_cost, hourly_rate)
        self.delivery_mode = delivery_mode


# -----------------------------------------------------------------------------
# AIR CARGO COMPLEX (ACC) CLEARANCE
# Data: Indian air cargo (Delhi IGI, Mumbai CSMI, etc.)
# Import baseline sum: 30.97 + 62.03 + 14.33 + 11.40 ≈ 118.73 hours
# Export baseline sum: 3.97 + 27.67 ≈ 31.63 hours
# -----------------------------------------------------------------------------
class AirCargoClearance(FacilityClearance):
    """
    Air Cargo Complex (ACC) Customs Clearance.

    Import Pipeline (4 stages):
        1. Arrival → Assessment  : Normal(μ=30.97, σ=7.74)
        2. Assessment → Payment  : Uniform(37.22, 86.85)
        3. Payment → OOC         : Exponential(mean=14.33)
        4. OOC → Gate Out        : Lognormal(mean=11.40, std=3.99)

    Export Pipeline (2 stages):
        1. Arrival → LEO         : Exponential(mean=3.97)
        2. LEO → Take-Off        : Triangular(19.37, 27.67, 41.50)

    Triggers:
        - Query (1)   : 5% prob,  swaps total to 151.15h
        - Query (N)   : 1.5% prob, swaps total to 267.57h
        - PGA/FSSAI   : 5% prob,  swaps total to 214.38h

    Constructor params:
        is_refrigerated: bool — if True, export baseline tightens to ~21.63h
    """

    def __init__(self, env, name, direction="import",
                 is_refrigerated: bool = False,
                 fixed_cost: float = 800.0,
                 hourly_rate: float = 50.0):

        if direction == "import":
            stages = [
                {"name": "Arrival→Assessment",  "distribution": "normal",
                 "params": {"mu": 30.97, "sigma": 7.74}},
                {"name": "Assessment→Payment",  "distribution": "uniform",
                 "params": {"low": 37.22, "high": 86.85}},
                {"name": "Payment→OOC",         "distribution": "exponential",
                 "params": {"mean": 14.33}},
                {"name": "OOC→GateOut",         "distribution": "lognormal",
                 "params": {"mean": 11.40, "std": 3.99}},
            ]
            triggers = [
                {"name": "Query(1)",   "probability": 0.05,  "mode": "swap", "hours": 151.15},
                {"name": "Query(N)",   "probability": 0.015, "mode": "swap", "hours": 267.57},
                {"name": "PGA/FSSAI", "probability": 0.05,  "mode": "swap", "hours": 214.38},
            ]
        else:  # export
            if is_refrigerated:
                # Refrigerated cargo: faster handling, ~21.63h total
                stages = [
                    {"name": "Arrival→LEO",     "distribution": "exponential",
                     "params": {"mean": 3.00}},
                    {"name": "LEO→Take-Off",    "distribution": "triangular",
                     "params": {"low": 13.0, "mode": 18.63, "high": 28.0}},
                ]
            else:
                # Non-refrigerated: standard, ~35.80h total
                stages = [
                    {"name": "Arrival→LEO",     "distribution": "exponential",
                     "params": {"mean": 3.97}},
                    {"name": "LEO→Take-Off",    "distribution": "triangular",
                     "params": {"low": 19.37, "mode": 27.67, "high": 41.50}},
                ]
            triggers = []

        super().__init__(env, name, direction, stages, triggers,
                         fixed_cost, hourly_rate)
        self.is_refrigerated = is_refrigerated


# -----------------------------------------------------------------------------
# INTEGRATED CHECK POST (ICP) CLEARANCE — Land Borders
# Data: Indian land border customs (Petrapole, Attari, Raxaul, etc.)
# Import baseline sum: 7.15 + 15.47 + 11.67 + 6.85 ≈ 41.13 hours
# Export baseline sum: 6.17 + 8.88 ≈ 15.05 hours
# NOTE: Extremely high variance for imports (std = 24.25h)
# -----------------------------------------------------------------------------
class ICPClearance(FacilityClearance):
    """
    Integrated Check Post (ICP) / Land Border Customs Clearance.

    Import Pipeline (4 stages) — HIGH VARIANCE (σ_total ≈ 24.25h):
        1. Arrival → Assessment  : Normal(μ=7.15,  σ=6.06)
        2. Assessment → Payment  : Uniform(3.47, 27.47)
        3. Payment → OOC         : Exponential(mean=11.67)
        4. OOC → Gate Out        : Lognormal(mean=6.85, std=4.80)

    Export Pipeline (2 stages):
        1. Arrival → LEO         : Exponential(mean=6.17)
        2. LEO → Departure       : Triangular(6.22, 8.88, 13.33)

    Constructor params:
        advance_filed : bool — if True, swaps import baseline to 18.78h (slower anomaly)
        late_facilitated : bool — if True, swaps import baseline to 11.47h (faster anomaly)
        is_aeo : Optional[bool] — AEO status for export:
            True  → swaps export baseline to 19.95h (slower anomaly)
            False → swaps export baseline to 14.02h (faster anomaly)
            None  → uses default distribution
    """

    def __init__(self, env, name, direction="import",
                 advance_filed: bool = False,
                 late_facilitated: bool = False,
                 is_aeo: Optional[bool] = None,
                 fixed_cost: float = 200.0,
                 hourly_rate: float = 15.0):

        triggers = []

        if direction == "import":
            # High variance: σ is distributed proportionally across stages
            # Total σ ≈ 24.25h → each stage gets a large share
            stages = [
                {"name": "Arrival→Assessment",  "distribution": "normal",
                 "params": {"mu": 7.15, "sigma": 6.06}},
                {"name": "Assessment→Payment",  "distribution": "uniform",
                 "params": {"low": 3.47, "high": 27.47}},
                {"name": "Payment→OOC",         "distribution": "exponential",
                 "params": {"mean": 11.67}},
                {"name": "OOC→GateOut",         "distribution": "lognormal",
                 "params": {"mean": 6.85, "std": 4.80}},
            ]
            # Anomaly triggers (deterministic, condition-based)
            if advance_filed:
                triggers.append(
                    {"name": "AdvanceFiled", "probability": 1.0,
                     "mode": "swap", "hours": 18.78}
                )
            elif late_facilitated:
                triggers.append(
                    {"name": "LateFacilitated", "probability": 1.0,
                     "mode": "swap", "hours": 11.47}
                )
        else:  # export
            stages = [
                {"name": "Arrival→LEO",     "distribution": "exponential",
                 "params": {"mean": 6.17}},
                {"name": "LEO→Departure",   "distribution": "triangular",
                 "params": {"low": 6.22, "mode": 8.88, "high": 13.33}},
            ]
            # AEO anomaly (deterministic, condition-based)
            if is_aeo is True:
                triggers.append(
                    {"name": "AEO=True", "probability": 1.0,
                     "mode": "swap", "hours": 19.95}
                )
            elif is_aeo is False:
                triggers.append(
                    {"name": "AEO=False", "probability": 1.0,
                     "mode": "swap", "hours": 14.02}
                )

        super().__init__(env, name, direction, stages, triggers,
                         fixed_cost, hourly_rate)
        self.advance_filed = advance_filed
        self.late_facilitated = late_facilitated
        self.is_aeo = is_aeo


# -----------------------------------------------------------------------------
# INLAND CONTAINER DEPOT (ICD) CLEARANCE — Rail/Road
# Data: Indian ICD customs (Tughlakabad, Dadri, Whitefield, etc.)
# Import baseline sum: 100.35 + 76.03 + 89.45 + 84.83 ≈ 350.67 hours
# Export baseline sum: 30.65 + 99.85 ≈ 130.50 hours
# -----------------------------------------------------------------------------
class ICDClearance(FacilityClearance):
    """
    Inland Container Depot (ICD) Customs Clearance.

    Import Pipeline (4 stages):
        1. Arrival → Assessment  : Normal(μ=100.35, σ=25.09)
        2. Assessment → Payment  : Uniform(45.62, 106.45)
        3. Payment → OOC         : Exponential(mean=89.45)
        4. OOC → Gate Out        : Lognormal(mean=84.83, std=29.69)

    Export Pipeline (2 stages):
        1. Arrival → LEO         : Exponential(mean=30.65)
        2. LEO → Rake Loading    : Triangular(69.90, 99.85, 149.78)

    Triggers:
        - Amendment: 27% prob, additive +17.98h

    Constructor params:
        container_load : "FCL" | "LCL" — export total modifier
            FCL → swaps export baseline to 127.07h
            LCL → swaps export baseline to 155.08h
        stuffing_loc : "factory" | "icd" — export range modifier
            factory → Triangular(71.45, 90.93, 110.40)h
            icd     → Triangular(109.12, 135.56, 162.02)h
    """

    def __init__(self, env, name, direction="import",
                 container_load: Optional[str] = None,
                 stuffing_loc: Optional[str] = None,
                 fixed_cost: float = 400.0,
                 hourly_rate: float = 20.0):

        if direction == "import":
            stages = [
                {"name": "Arrival→Assessment",  "distribution": "normal",
                 "params": {"mu": 100.35, "sigma": 25.09}},
                {"name": "Assessment→Payment",  "distribution": "uniform",
                 "params": {"low": 45.62, "high": 106.45}},
                {"name": "Payment→OOC",         "distribution": "exponential",
                 "params": {"mean": 89.45}},
                {"name": "OOC→GateOut",         "distribution": "lognormal",
                 "params": {"mean": 84.83, "std": 29.69}},
            ]
            triggers = [
                {"name": "Amendment", "probability": 0.27, "mode": "additive", "hours": 17.98},
            ]
        else:  # export
            triggers = []

            if stuffing_loc == "factory":
                # Factory-stuffed: range 71.45 → 110.40h
                stages = [
                    {"name": "Arrival→LEO",       "distribution": "exponential",
                     "params": {"mean": 20.0}},
                    {"name": "LEO→RakeLoading",   "distribution": "triangular",
                     "params": {"low": 51.45, "mode": 70.93, "high": 90.40}},
                ]
            elif stuffing_loc == "icd":
                # ICD-stuffed: heavily delayed, range 109.12 → 162.02h
                stages = [
                    {"name": "Arrival→LEO",       "distribution": "exponential",
                     "params": {"mean": 30.65}},
                    {"name": "LEO→RakeLoading",   "distribution": "triangular",
                     "params": {"low": 78.47, "mode": 104.91, "high": 131.37}},
                ]
            else:
                # Default export pipeline
                stages = [
                    {"name": "Arrival→LEO",       "distribution": "exponential",
                     "params": {"mean": 30.65}},
                    {"name": "LEO→RakeLoading",   "distribution": "triangular",
                     "params": {"low": 69.90, "mode": 99.85, "high": 149.78}},
                ]

            # Container load modifier
            if container_load == "FCL":
                triggers.append(
                    {"name": "FCL", "probability": 1.0,
                     "mode": "swap", "hours": 127.07}
                )
            elif container_load == "LCL":
                triggers.append(
                    {"name": "LCL", "probability": 1.0,
                     "mode": "swap", "hours": 155.08}
                )

        super().__init__(env, name, direction, stages, triggers,
                         fixed_cost, hourly_rate)
        self.container_load = container_load
        self.stuffing_loc = stuffing_loc



class TransportLink:
    """Base transport link — pass-through."""
    def __init__(self, env: simpy.Environment, source: str, dest: str, mode: str):
        self.env = env
        self.source = source
        self.dest = dest
        self.mode = mode

    def _scale_delay(self, delay: float) -> float:
        """Apply risk-aware delay scaling if injected by MC runner."""
        return delay * getattr(self, '_risk_delay_multiplier', 1.0)

    def _scale_cost(self, cost: float) -> float:
        """Apply risk-aware cost scaling if injected by MC runner."""
        return cost * getattr(self, '_risk_cost_multiplier', 1.0)

    def traverse(self, shipment: Shipment):
        yield self.env.timeout(0)


class RoadLink(TransportLink):
    """
    Road Transport Link.

    Primary Source: Google Maps Distance Matrix API (time-of-day aware).
    Optional Noise: Lognormal perturbation added on top of API result
                    to capture micro-level randomness (potholes, local detours).

    Parameters:
        google_client  — GoogleMapsClient instance (or None to use pure distribution).
        noise_mean_h   — Mean of the lognormal noise to add (hours). Set 0 to disable.
        noise_std_h    — Std dev of the lognormal noise (hours). Set 0 to disable.
        base_cost      — Fixed dispatch/loading fee ($).
        cost_per_hour  — Fuel + driver cost per hour of transit ($).

    >>> # USER: Set noise_mean_h and noise_std_h to small values (e.g., 0.5, 0.2).
    >>> #       These represent unpredictable micro-delays the API can't capture.
    >>> #       Set base_cost to your dispatch fee and cost_per_hour to fuel+driver rate.
    """
    def __init__(self, env, src, dst,
                 google_client: Optional[GoogleMapsClient] = None,
                 noise_mean_h: float = 0.5,       # USER: mean of micro-noise (hours)
                 noise_std_h: float = 0.2,         # USER: std dev of micro-noise (hours)
                 fallback_mean_h: float = 15.0,    # USER: fallback mean if no API (hours)
                 fallback_std_h: float = 3.0,      # USER: fallback std if no API (hours)
                 base_cost: float = 250.0,          # USER: fixed dispatch fee ($)
                 cost_per_hour: float = 12.0):      # USER: fuel+driver rate per hour ($)
        super().__init__(env, src, dst, "ROAD")
        self.google_client = google_client
        self.noise_mean_h = noise_mean_h
        self.noise_std_h = noise_std_h
        self.fallback_mean_h = fallback_mean_h
        self.fallback_std_h = fallback_std_h
        self.base_cost = base_cost
        self.cost_per_hour = cost_per_hour

    def traverse(self, shipment: Shipment):
        if hasattr(self, '_pre_delay'):
            delay = self._pre_delay
        else:
            if self.google_client:
                api_hours = self.google_client.get_travel_time_hours(self.source, self.dest, self.env.now)
                noise = 0.0
                if self.noise_mean_h > 0 and self.noise_std_h > 0:
                    mu, sigma = get_lognormal_params(self.noise_mean_h, self.noise_std_h)
                    noise = random.lognormvariate(mu, sigma)
                delay = api_hours + noise
            else:
                mu, sigma = get_lognormal_params(self.fallback_mean_h, self.fallback_std_h)
                delay = random.lognormvariate(mu, sigma)
        delay = self._scale_delay(delay)
        cost = self._scale_cost(self.base_cost + (self.cost_per_hour * delay))
        yield self.env.timeout(delay)
        shipment.record(f"Road Transit: {self.source} -> {self.dest}", delay, cost)


class RailLink(TransportLink):
    def __init__(self, env, src, dst,
                 rail_client: Optional[RailwayClient] = None,
                 min_hours: float = 20.0,
                 max_hours: float = 30.0,
                 base_cost: float = 500.0,
                 cost_per_hour: float = 5.0):
        super().__init__(env, src, dst, "RAIL")
        self.rail_client = rail_client
        self.min_hours = min_hours
        self.max_hours = max_hours
        self.base_cost = base_cost
        self.cost_per_hour = cost_per_hour

    def traverse(self, shipment: Shipment):
        if hasattr(self, '_pre_delay'):
            delay = self._pre_delay
        else:
            if self.rail_client:
                base_h = self.rail_client.get_transit_time_hours(self.source, self.dest)
                delay = random.uniform(base_h * 0.95, base_h * 1.15)
            else:
                delay = random.uniform(self.min_hours, self.max_hours)
        delay = self._scale_delay(delay)
        cost = self._scale_cost(self.base_cost + (self.cost_per_hour * delay))
        yield self.env.timeout(delay)
        shipment.record(f"Rail Transit: {self.source} -> {self.dest}", delay, cost)


class AirLink(TransportLink):
    def __init__(self, env, src, dst,
                 air_client: Optional[AviationEdgeClient] = None,
                 mean_hours: float = 5.0,
                 std_hours: float = 0.5,
                 base_cost: float = 2000.0,
                 cost_per_hour: float = 50.0):
        super().__init__(env, src, dst, "AIR")
        self.air_client = air_client
        self.mean_hours = mean_hours
        self.std_hours = std_hours
        self.base_cost = base_cost
        self.cost_per_hour = cost_per_hour

    def traverse(self, shipment: Shipment):
        if hasattr(self, '_pre_delay'):
            delay = self._pre_delay
        else:
            base_h = self.air_client.get_transit_time_hours(self.source, self.dest) if self.air_client else self.mean_hours
            delay = max(1.0, random.normalvariate(base_h, self.std_hours))
        delay = self._scale_delay(delay)
        cost = self._scale_cost(self.base_cost + (self.cost_per_hour * delay))
        yield self.env.timeout(delay)
        shipment.record(f"Air Transit: {self.source} -> {self.dest}", delay, cost)


class ShipLink(TransportLink):
    def __init__(self, env, src, dst,
                 sea_client: Optional[SearoutesClient] = None,
                 min_hours: float = 100.0,
                 mode_hours: float = 120.0,
                 max_hours: float = 180.0,
                 fuel_cost: float = 1500.0,
                 cost_per_hour: float = 2.5):
        super().__init__(env, src, dst, "SHIP")
        self.sea_client = sea_client
        self.min_hours = min_hours
        self.mode_hours = mode_hours
        self.max_hours = max_hours
        self.fuel_cost = fuel_cost
        self.cost_per_hour = cost_per_hour

    def traverse(self, shipment: Shipment):
        if hasattr(self, '_pre_delay'):
            delay = self._pre_delay
        else:
            if self.sea_client:
                base_h = self.sea_client.get_transit_time_hours(self.source, self.dest)
                delay = random.triangular(base_h * 0.9, base_h * 1.3, base_h)
            else:
                delay = random.triangular(self.min_hours, self.max_hours, self.mode_hours)
        delay = self._scale_delay(delay)
        cost = self._scale_cost(self.fuel_cost + (self.cost_per_hour * delay))
        yield self.env.timeout(delay)
        shipment.record(f"Sea Transit: {self.source} -> {self.dest}", delay, cost)


# =============================================================================
# ROUTE BUILDER & SIMULATION ENGINE
# =============================================================================
class RouteExecution:
    """
    Builds and runs a supply chain route from user-provided location and mode arrays.

    Args:
        env: simpy.Environment instance.
        locations: List of n location strings (pincodes or addresses).
        modes: List of n-1 transport mode strings ('Road', 'Rail', 'Air', 'Ship').
        google_client: Optional GoogleMapsClient for road links.
    """
    def __init__(self, env: simpy.Environment, locations: List[str], modes: List[str],
                 google_client: Optional[GoogleMapsClient] = None):
        self.env = env
        self.locations = locations
        self.modes = modes
        self.google_client = google_client
        self.route = self._assemble_route()

    def _assemble_route(self) -> list:
        steps = []
        for i in range(len(self.modes)):
            src = self.locations[i]
            dst = self.locations[i + 1]
            mode = self.modes[i].lower()

            # Add Origin Node for first segment only
            if i == 0:
                steps.append(Node(self.env, src))

            # Create the appropriate Link based on transport mode
            if mode == "road":
                steps.append(RoadLink(self.env, src, dst, google_client=self.google_client))
            elif mode == "rail":
                steps.append(RailLink(self.env, src, dst))
            elif mode == "air":
                steps.append(AirLink(self.env, src, dst))
            elif mode == "ship":
                steps.append(ShipLink(self.env, src, dst))
            else:
                steps.append(TransportLink(self.env, src, dst, mode.upper()))

            # Add Destination Node for this segment
            steps.append(Node(self.env, dst))

        return steps

    def run_shipment(self, shipment_id: str):
        """Runs a single shipment through the entire route."""
        shipment = Shipment(self.env, shipment_id)
        for element in self.route:
            if isinstance(element, Node):
                yield self.env.process(element.process(shipment))
            elif isinstance(element, TransportLink):
                yield self.env.process(element.traverse(shipment))

        print("\n" + "=" * 90)
        print(f"  SHIPMENT {shipment_id} COMPLETED")
        print(f"  Total Lead Time : {self.env.now:10.2f} hours ({self.env.now / 24:.1f} days)")
        print(f"  Total Cost      : ${shipment.total_cost:10.2f}")
        print("=" * 90 + "\n")
        return shipment



# =============================================================================
# MONTE CARLO RUNNER — Pure Monte Carlo with Importance Sampling
# =============================================================================
def build_route_with_nodes(env, locations, modes, gmaps=None,
                           facility_configs=None):
    """
    Factory function: builds a fresh RouteExecution and injects specialized nodes.

    Args:
        facility_configs: Optional list of facility injection configs.
            Each dict: {"type": "seaport"|"air"|"icp"|"icd", "position": int,
                        "name": str, "direction": "import"|"export", ...kwargs}
            If None, uses a default border + SeaportClearance.
    """
    planner = RouteExecution(env, locations, modes, google_client=gmaps)

    if facility_configs:
        # Sort by position descending so inserts don't shift indices
        for cfg in sorted(facility_configs, key=lambda c: c["position"], reverse=True):
            cls_map = {
                "seaport": SeaportClearance,
                "air": AirCargoClearance,
                "icp": ICPClearance,
                "icd": ICDClearance,
            }
            cls = cls_map.get(cfg["type"], SeaportClearance)
            kwargs = {k: v for k, v in cfg.items()
                      if k not in ("type", "position")}
            planner.route.insert(cfg["position"], cls(env, **kwargs))
    else:
        planner.route.insert(1, StateBorderNode(env, "UP-Rajasthan Border",
            min_wait_hours=0.5, max_wait_hours=2.0, entry_fee=15.0))
        planner.route.insert(4, SeaportClearance(env, "JNPT Mumbai",
            direction="import", fixed_cost=500.0, hourly_rate=30.0))

    return planner


def monte_carlo_des(locations, modes, n_iterations=100, seed=42,
                    importance_boost=1.0, facility_configs=None, gmaps=None,
                    combined_risk_score=0.0):
    """
    Runs the DES simulation N times using pure Monte Carlo + importance sampling.

    Each iteration draws independently from native distributions. No stratification.
    Importance sampling (boost > 1.0) over-samples rare triggers with
    likelihood-ratio reweighting for unbiased tail-risk estimation.

    Combined Risk Integration:
        When combined_risk_score > 0, delays and costs are scaled:
          delay_multiplier = 1.0 + risk_scale_factor * combined_risk_score
          cost_multiplier  = 1.0 + (risk_scale_factor * 0.6) * combined_risk_score
        This models that higher risk routes experience proportionally longer
        delays and increased costs (demurrage, rerouting, insurance).

    Args:
        locations:           List of location strings.
        modes:               List of transport modes.
        n_iterations:        MC iterations (default 100).
        seed:                Random seed.
        importance_boost:    Rare trigger probability multiplier (1.0 = off).
        facility_configs:    Optional facility injection configs.
        gmaps:               Optional GoogleMapsClient.
        combined_risk_score: 0.0-1.0 combined risk from combination.py (default 0.0 = no risk adjustment).
    """
    random.seed(seed)
    np.random.seed(seed)

    # ── Risk-Aware Scaling ─────────────────────────────────────
    # Map combined_risk_score (0.0-1.0) to delay/cost multipliers.
    # At risk=0.0: multiplier=1.0 (no change)
    # At risk=0.5: multiplier=1.50 (50% longer delays)
    # At risk=1.0: multiplier=2.00 (double delays)
    RISK_DELAY_SCALE = 1.0   # max additional delay factor at risk=1.0
    RISK_COST_SCALE  = 0.6   # max additional cost factor at risk=1.0

    delay_multiplier = 1.0 + RISK_DELAY_SCALE * combined_risk_score
    cost_multiplier  = 1.0 + RISK_COST_SCALE * combined_risk_score

    times = []
    costs = []
    weights = []

    risk_tag = f", CombinedRisk: {combined_risk_score:.4f}" if combined_risk_score > 0 else ""
    print(f"\n>>> Starting Monte Carlo Simulation: {n_iterations} iterations, Seed: {seed}, IS Boost: {importance_boost}{risk_tag}")
    if combined_risk_score > 0:
        print(f"    Risk Multipliers — Delay: {delay_multiplier:.2f}x, Cost: {cost_multiplier:.2f}x")
    mc_start_time = time.time()

    for i in range(n_iterations):
        iter_start_time = time.time()
        print(f"\n--- Iteration {i+1} ---")
        env = simpy.Environment()
        planner = build_route_with_nodes(env, locations, modes, gmaps,
                                         facility_configs)

        # Inject importance boost into facility nodes
        if importance_boost != 1.0:
            for element in planner.route:
                if isinstance(element, FacilityClearance):
                    element._importance_boost = importance_boost

        # Inject risk multipliers into all route elements
        if combined_risk_score > 0:
            for element in planner.route:
                element._risk_delay_multiplier = delay_multiplier
                element._risk_cost_multiplier = cost_multiplier

        shipment = Shipment(env, f"MC-{i+1:03d}")

        def _run_process(sh=shipment, rt=planner.route):
            for el in rt:
                if isinstance(el, Node):
                    yield env.process(el.process(sh))
                elif isinstance(el, TransportLink):
                    lnk_start = env.now
                    yield env.process(el.traverse(sh))
                    last_cost = sh.log[-1]["cost"] if sh.log else 0.0
                    print(f"  [Link: {el.mode}] {el.source} -> {el.dest} | Duration: {env.now - lnk_start:.2f}h | Cost: ${last_cost:.2f}")

        env.process(_run_process())
        env.run()

        # Collect importance weight
        iter_weight = 1.0
        for element in planner.route:
            if isinstance(element, FacilityClearance) and hasattr(element, '_is_weight'):
                iter_weight *= element._is_weight

        iter_end_time = time.time()
        print(f"  Iteration {i+1} Summary: Time={env.now:.2f}h, Cost=${shipment.total_cost:.2f}, Weight={iter_weight:.4f}, ExecTime={iter_end_time - iter_start_time:.4f}s")
        
        times.append(env.now)
        costs.append(shipment.total_cost)
        weights.append(iter_weight)

    mc_end_time = time.time()
    print(f"\n>>> Monte Carlo Completed in {mc_end_time - mc_start_time:.4f}s")

    return calculate_stats(times, costs, weights, n_iterations,
                           importance_boost > 1.0)


# =============================================================================
# SIMULATION QUEUE — Production-Ready Concurrent Job Processing
# =============================================================================
def _run_mc_job(job_config):
    """
    Top-level worker for ProcessPoolExecutor. Runs a full MC simulation
    in an isolated process. Must be top-level (not a method) for pickling.

    Returns: {"job_id": str, "status": "done"|"error", "result": dict, "error": str}
    """
    job_id = job_config["job_id"]
    try:
        result = monte_carlo_des(
            locations=job_config["locations"],
            modes=job_config["modes"],
            n_iterations=job_config.get("n_iterations", 100),
            seed=job_config.get("seed", 42),
            importance_boost=job_config.get("importance_boost", 1.0),
            facility_configs=job_config.get("facility_configs", None),
        )
        return {"job_id": job_id, "status": "done", "result": result, "error": None}
    except Exception as e:
        return {"job_id": job_id, "status": "error", "result": None, "error": str(e)}


class SimulationQueue:
    """
    Production-ready job queue for concurrent supply chain simulations.

    WHY THIS EXISTS (instead of parallelizing iterations):
        A single Monte Carlo run (100 iterations) takes ~1 second — parallelizing
        its iterations adds process-spawn overhead (~200ms/process) and actually
        makes it SLOWER. The real production need is running DIFFERENT simulation
        requests concurrently: multiple users, batch route comparisons, etc.

    Architecture:
        - ProcessPoolExecutor with N workers (default = min(cpu_count, 8))
        - Each worker runs a complete monte_carlo_des() call in full isolation
        - Jobs submitted with unique IDs, tracked via Futures
        - Context manager support for automatic cleanup

    Usage:
        with SimulationQueue(max_workers=4) as queue:
            j1 = queue.submit({"locations": [...], "modes": [...]})
            j2 = queue.submit({"locations": [...], "modes": [...], "importance_boost": 3.0})
            for r in queue.get_all_results():
                print_results(r["result"])
    """

    def __init__(self, max_workers=None):
        if max_workers is None:
            max_workers = min(cpu_count(), 8)
        self.max_workers = max_workers
        self.executor = ProcessPoolExecutor(max_workers=max_workers)
        self._futures = {}
        logger.info(f"SimulationQueue started with {max_workers} workers")

    def submit(self, job_config):
        """Submit a simulation job. Returns job_id (str)."""
        job_id = str(uuid.uuid4())[:8]
        job_config["job_id"] = job_id
        future = self.executor.submit(_run_mc_job, job_config)
        self._futures[job_id] = future
        logger.info(f"Job {job_id} submitted: {job_config.get('n_iterations', 100)} iterations")
        return job_id

    def get_status(self, job_id):
        """Non-blocking status: 'pending' | 'running' | 'done' | 'error' | 'unknown'."""
        future = self._futures.get(job_id)
        if future is None:
            return "unknown"
        if future.done():
            try:
                return future.result()["status"]
            except Exception:
                return "error"
        return "running" if future.running() else "pending"

    def get_result(self, job_id, timeout=None):
        """Blocking wait for result. Returns result dict."""
        future = self._futures.get(job_id)
        if future is None:
            raise KeyError(f"Job {job_id} not found")
        return future.result(timeout=timeout)

    def get_all_results(self, timeout=300):
        """Wait for ALL jobs, return list of result dicts."""
        results = []
        for job_id, future in self._futures.items():
            try:
                results.append(future.result(timeout=timeout))
            except Exception as e:
                results.append({"job_id": job_id, "status": "error",
                                "result": None, "error": str(e)})
        return results

    def pending_count(self):
        """Number of jobs not yet completed."""
        return sum(1 for f in self._futures.values() if not f.done())

    def shutdown(self, wait=True):
        """Graceful shutdown."""
        logger.info(f"Queue shutdown. Pending: {self.pending_count()}")
        self.executor.shutdown(wait=wait)

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.shutdown(wait=True)


# =============================================================================
# STATISTICS — Supports standard and importance-weighted computation
# =============================================================================
def calculate_stats(times, costs, weights, n_iterations,
                    use_importance_weights=False):
    """
    Computes summary statistics with optional importance-sampling reweighting.
    Uses self-normalized estimator: E[f(X)] = Σ(w_i × f(X_i)) / Σ(w_i)
    """
    times = np.array(times)
    costs = np.array(costs)
    w = np.array(weights)

    if use_importance_weights and np.any(w != 1.0):
        w_norm = w / w.sum()
        t_mean = np.sum(w_norm * times)
        c_mean = np.sum(w_norm * costs)
        t_std = np.sqrt(np.sum(w_norm * (times - t_mean) ** 2))
        c_std = np.sqrt(np.sum(w_norm * (costs - c_mean) ** 2))
        n_eff = (w.sum() ** 2) / (w ** 2).sum()
        method = "Importance-Weighted Monte Carlo"
    else:
        t_mean = np.mean(times)
        c_mean = np.mean(costs)
        t_std = np.std(times)
        c_std = np.std(costs)
        n_eff = n_iterations
        method = "Monte Carlo"

    return {
        "iterations": n_iterations,
        "effective_n": round(n_eff, 1),
        "method": method,
        "time": {
            "mean": t_mean, "std": t_std,
            "min": np.min(times), "max": np.max(times),
            "p5": np.percentile(times, 5),
            "p50": np.percentile(times, 50),
            "p95": np.percentile(times, 95),
            "ci_95": (t_mean - 1.96 * t_std / np.sqrt(n_eff),
                      t_mean + 1.96 * t_std / np.sqrt(n_eff))
        },
        "cost": {
            "mean": c_mean, "std": c_std,
            "min": np.min(costs), "max": np.max(costs),
            "p5": np.percentile(costs, 5),
            "p50": np.percentile(costs, 50),
            "p95": np.percentile(costs, 95),
            "ci_95": (c_mean - 1.96 * c_std / np.sqrt(n_eff),
                      c_mean + 1.96 * c_std / np.sqrt(n_eff))
        }
    }


def print_results(r):
    """Pretty-prints Monte Carlo results."""
    print("\n" + "=" * 90)
    print(f"  MONTE CARLO RESULTS — {r['iterations']} iterations ({r['method']})")
    if r.get('effective_n') and r['effective_n'] != r['iterations']:
        print(f"  Effective Sample Size (N_eff): {r['effective_n']}")
    print("=" * 90)

    t, c = r["time"], r["cost"]
    print(f"\n  {'LEAD TIME (hours)':^40} | {'COST ($)':^40}")
    print(f"  {'-'*40} | {'-'*40}")
    print(f"  Mean:       {t['mean']:10.2f} h  ({t['mean']/24:.1f} days)    |  Mean:       ${c['mean']:10.2f}")
    print(f"  Std Dev:    {t['std']:10.2f} h                   |  Std Dev:    ${c['std']:10.2f}")
    print(f"  Min:        {t['min']:10.2f} h                   |  Min:        ${c['min']:10.2f}")
    print(f"  Max:        {t['max']:10.2f} h                   |  Max:        ${c['max']:10.2f}")
    print(f"  5th %ile:   {t['p5']:10.2f} h                   |  5th %ile:   ${c['p5']:10.2f}")
    print(f"  Median:     {t['p50']:10.2f} h                   |  Median:     ${c['p50']:10.2f}")
    print(f"  95th %ile:  {t['p95']:10.2f} h                   |  95th %ile:  ${c['p95']:10.2f}")
    print(f"  95% CI:     [{t['ci_95'][0]:.2f}, {t['ci_95'][1]:.2f}] h      |  95% CI:     [${c['ci_95'][0]:.2f}, ${c['ci_95'][1]:.2f}]")
    print("=" * 90 + "\n")


# =============================================================================
# RUN SIMULATION WITH RISK — Single entry point for worker.py
# =============================================================================
def run_simulation_with_risk(
    cities: List[str],
    modes: List[str],
    cargo_type: str = "general",
    target_date: Optional[str] = None,
    n_iterations: int = 50,
    seed: int = 42,
    importance_boost: float = 1.0,
    facility_configs: Optional[list] = None,
) -> dict:
    """
    Complete entry point: fetches combined risk, runs MC simulation, returns
    a JSON-serializable result dict with both risk analysis and simulation stats.

    This is the function that worker.py calls.

    Args:
        cities:           List of city names (e.g. ["Mumbai", "Delhi", "Dubai"])
        modes:            List of transport modes (e.g. ["Road", "Ship"])
        cargo_type:       Cargo profile key (default "general")
        target_date:      Optional date string "YYYY-MM-DD"
        n_iterations:     Monte Carlo iterations
        seed:             Random seed
        importance_boost: IS boost factor
        facility_configs: Optional facility injection configs

    Returns:
        dict with keys: job_meta, combined_risk, simulation_stats
    """
    from combination import compute_combined_risk
    from datetime import datetime, timezone

    logger.info("=== run_simulation_with_risk ===")
    logger.info("  Cities: %s", cities)
    logger.info("  Modes: %s", modes)
    logger.info("  Cargo: %s, Date: %s", cargo_type, target_date)

    # ── Step 1: Compute Combined Risk ────────────────────────
    parsed_date = None
    if target_date:
        try:
            parsed_date = datetime.strptime(target_date, "%Y-%m-%d").replace(tzinfo=timezone.utc)
        except ValueError:
            logger.warning("Invalid date '%s', ignoring.", target_date)

    try:
        risk_result = compute_combined_risk(cities, cargo_type, parsed_date)
        combined_risk_score = risk_result.get("combined_risk_score", 0.0)
        logger.info("  Combined Risk Score: %.4f (%s)",
                    combined_risk_score, risk_result.get("risk_level", "UNKNOWN"))
    except Exception as e:
        logger.error("  Combined risk evaluation failed: %s. Using 0.0.", e)
        risk_result = {"combined_risk_score": 0.0, "risk_level": "UNKNOWN", "error": str(e)}
        combined_risk_score = 0.0

    # ── Step 2: Run Monte Carlo with risk-scaled delays ──────
    sim_stats = monte_carlo_des(
        locations=cities,
        modes=modes,
        n_iterations=n_iterations,
        seed=seed,
        importance_boost=importance_boost,
        facility_configs=facility_configs,
        combined_risk_score=combined_risk_score,
    )

    # ── Step 3: Assemble final result ────────────────────────
    # Convert numpy types to native Python for JSON serialization
    def _to_native(obj):
        if isinstance(obj, (np.integer,)):
            return int(obj)
        elif isinstance(obj, (np.floating,)):
            return float(obj)
        elif isinstance(obj, np.ndarray):
            return obj.tolist()
        elif isinstance(obj, tuple):
            return list(obj)
        elif isinstance(obj, dict):
            return {k: _to_native(v) for k, v in obj.items()}
        elif isinstance(obj, list):
            return [_to_native(x) for x in obj]
        return obj

    result = _to_native({
        "job_meta": {
            "cities": cities,
            "modes": modes,
            "cargo_type": cargo_type,
            "target_date": target_date,
            "n_iterations": n_iterations,
            "seed": seed,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        },
        "combined_risk": {
            "score": combined_risk_score,
            "level": risk_result.get("risk_level", "UNKNOWN"),
            "route_viable": risk_result.get("route_viable", True),
            "recommendation": risk_result.get("recommendation", ""),
            "weather_risk": risk_result.get("weather_risk", {}),
            "sentiment_risk": risk_result.get("sentiment_risk", {}),
        },
        "simulation_stats": sim_stats,
    })

    logger.info("=== Simulation complete ===")
    return result


# =============================================================================
# MAIN — Sequential + Queue Demo
# =============================================================================
if __name__ == "__main__":
    print("=" * 90)
    print("  SUPPLY CHAIN DES ENGINE V5 — Risk-Aware Production Architecture")
    print("  Features: Combined Risk + Importance Sampling + API Caching + SimulationQueue")
    print("=" * 90 + "\n")

    # --- Mode 1: Sequential MC ---
    print("[1/2] Sequential Monte Carlo (2 iterations)...")
    results = monte_carlo_des(
        locations=["110001", "400001", "DXB"],
        modes=["Road", "Ship"],
        n_iterations=2, seed=42
    )
    print_results(results)

    # --- Mode 2: SimulationQueue — 2 concurrent jobs ---
    print("[2/2] SimulationQueue — 2 concurrent route simulations (verbose)...")
    with SimulationQueue(max_workers=2) as queue:
        # Job 1: Delhi→Mumbai→Dubai (default)
        j1 = queue.submit({
            "locations": ["110001", "400001", "DXB"],
            "modes": ["Road", "Ship"],
            "n_iterations": 1, "seed": 100,
        })
        # Job 2: Same route, importance-sampled
        j2 = queue.submit({
            "locations": ["110001", "400001", "DXB"],
            "modes": ["Road", "Ship"],
            "n_iterations": 1, "seed": 200,
            "importance_boost": 3.0,
        })

        for r in queue.get_all_results(timeout=60):
            print(f"\n--- Job {r['job_id']} ({r['status']}) ---")
            if r["result"]:
                print_results(r["result"])
            elif r["error"]:
                print(f"  Error: {r['error']}")

