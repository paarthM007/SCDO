"""
analytics.py - Historical job analytics + insurance cost estimator.
"""
import logging
from datetime import datetime, timezone
from collections import Counter
from google.cloud import firestore
from scdo.db import get_db
from scdo.config import GOOGLE_CLOUD_PROJECT, FIRESTORE_COLLECTION

logger = logging.getLogger(__name__)


def get_job_history(limit=50, status_filter=None, user_id=None):
    """Fetch recent jobs from Firestore with optional status and user filter."""
    db = get_db()
    query = db.collection(FIRESTORE_COLLECTION)

    if user_id:
        query = query.where("user_id", "==", user_id)
        
    query = query.order_by(
        "created_at", direction=firestore.Query.DESCENDING
    ).limit(limit)

    if status_filter:
        query = query.where("status", "==", status_filter)

    docs = query.stream()
    jobs = []
    for doc in docs:
        d = doc.to_dict()
        d["job_id"] = doc.id
        # Strip heavy fields for listing
        if "result" in d and isinstance(d["result"], dict):
            sim = d["result"].get("simulation_stats", {})
            d["summary"] = {
                "time_mean": sim.get("time", {}).get("mean"),
                "cost_mean": sim.get("cost", {}).get("mean"),
                "risk_score": d["result"].get("combined_risk", {}).get("score"),
                "risk_level": d["result"].get("combined_risk", {}).get("level"),
            }
            del d["result"]  # Don't send full result in listing
        jobs.append(d)
    return jobs


def compute_analytics(limit=200, user_id=None):
    """Aggregate analytics over recent completed jobs."""
    db = get_db()
    query = db.collection(FIRESTORE_COLLECTION).where(
        "status", "==", "completed"
    )
    if user_id:
        query = query.where("user_id", "==", user_id)
        
    docs = query.order_by(
        "created_at", direction=firestore.Query.DESCENDING
    ).limit(limit).stream()

    route_counter = Counter()
    risk_scores = []
    time_means = []
    cost_means = []
    cargo_counter = Counter()
    total_jobs = 0

    for doc in docs:
        d = doc.to_dict()
        total_jobs += 1

        # Count routes
        cities = d.get("cities", d.get("request", {}).get("cities", []))
        if cities:
            route_key = " → ".join(cities)
            route_counter[route_key] += 1

        # Count cargo types
        cargo = d.get("cargo_type", d.get("request", {}).get("cargo_type", "general"))
        cargo_counter[cargo] += 1

        # Aggregate stats from results
        result = d.get("result", {})
        risk = result.get("combined_risk", {}).get("score")
        if risk is not None:
            risk_scores.append(float(risk))
        sim = result.get("simulation_stats", {})
        t = sim.get("time", {}).get("mean")
        c = sim.get("cost", {}).get("mean")
        if t is not None:
            time_means.append(float(t))
        if c is not None:
            cost_means.append(float(c))

    return {
        "total_completed_jobs": total_jobs,
        "most_simulated_routes": [
            {"route": r, "count": c} for r, c in route_counter.most_common(10)
        ],
        "cargo_type_distribution": dict(cargo_counter.most_common()),
        "risk_stats": {
            "avg": round(sum(risk_scores) / len(risk_scores), 4) if risk_scores else None,
            "max": round(max(risk_scores), 4) if risk_scores else None,
            "min": round(min(risk_scores), 4) if risk_scores else None,
            "count": len(risk_scores),
        },
        "time_stats_hours": {
            "avg": round(sum(time_means) / len(time_means), 1) if time_means else None,
            "max": round(max(time_means), 1) if time_means else None,
            "min": round(min(time_means), 1) if time_means else None,
        },
        "cost_stats_usd": {
            "avg": round(sum(cost_means) / len(cost_means), 2) if cost_means else None,
            "max": round(max(cost_means), 2) if cost_means else None,
            "min": round(min(cost_means), 2) if cost_means else None,
        },
    }


# ── Insurance Cost Estimator ─────────────────────────────────
# Industry-standard marine/cargo insurance base rates (annual % of cargo value)
INSURANCE_BASE_RATES = {
    "general":        0.0035,  # 0.35%
    "frozen_food":    0.0055,  # 0.55%
    "perishable":     0.0050,  # 0.50%
    "live_animals":   0.0080,  # 0.80%
    "pharmaceuticals":0.0060,  # 0.60%
    "electronics":    0.0045,  # 0.45%
    "bulk_commodity": 0.0025,  # 0.25%
    "hazmat":         0.0090,  # 0.90%
    "vehicles":       0.0040,  # 0.40%
}


def estimate_insurance(cargo_type, cargo_value_usd, risk_score,
                       p95_delay_hours, transit_days=None):
    """
    Estimate cargo insurance premium.
    Formula: premium = base_rate × (1 + risk_score) × cargo_value × transit_days / 365
    With surcharges for high risk and long transit.
    """
    base_rate = INSURANCE_BASE_RATES.get(cargo_type, 0.0035)

    if transit_days is None:
        transit_days = p95_delay_hours / 24.0

    # Risk adjustment: higher risk = higher premium
    risk_multiplier = 1.0 + risk_score * 2.0  # 0 risk = 1x, 1.0 risk = 3x

    # Transit duration adjustment: longer = more exposure
    duration_factor = transit_days / 365.0

    # Base premium
    premium = base_rate * risk_multiplier * cargo_value_usd * max(duration_factor, 0.01)

    # Surcharges
    surcharges = {}
    if risk_score > 0.65:
        war_surcharge = cargo_value_usd * 0.001  # 0.1% war risk
        premium += war_surcharge
        surcharges["war_risk"] = round(war_surcharge, 2)
    if transit_days > 30:
        extended_surcharge = premium * 0.15  # 15% surcharge for 30+ day transit
        premium += extended_surcharge
        surcharges["extended_transit"] = round(extended_surcharge, 2)

    return {
        "premium_usd": round(premium, 2),
        "base_rate_pct": round(base_rate * 100, 3),
        "risk_multiplier": round(risk_multiplier, 2),
        "transit_days": round(transit_days, 1),
        "cargo_value_usd": cargo_value_usd,
        "cargo_type": cargo_type,
        "surcharges": surcharges,
        "coverage_note": "All-risk marine cargo insurance (ICC-A equivalent)",
    }
