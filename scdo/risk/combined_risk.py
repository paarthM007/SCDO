"""
combined_risk.py - Combines weather + sentiment + community feedback into a single 0-1 score.
From combination.py.
"""
import logging
from datetime import datetime, timezone, timedelta
from scdo.risk.weather_risk import compute_weather_risk
from scdo.risk.sentiment_risk import compute_sentiment_risk

logger = logging.getLogger(__name__)

KILL_SWITCH = 0.85
SYNERGY_K = 0.40
COMMUNITY_WEIGHT = 0.15  # how much community feedback influences the score
COMMUNITY_COLLECTION = "community_risk_reports"
COMMUNITY_WINDOW_DAYS = 30  # only consider reports from the last N days

RISK_LEVELS = [
    (0.20, "LOW",      True, "Route is low-risk. Proceed normally."),
    (0.45, "MODERATE", True, "Route has moderate risk. Monitor conditions."),
    (0.65, "HIGH",     True, "Route is high-risk. Consider alternatives."),
    (0.85, "CRITICAL", False, "Route is critical-risk. Reroute recommended."),
    (1.00, "EXTREME",  False, "Route is extremely dangerous. Do not proceed."),
]


def _classify(score):
    for threshold, level, viable, rec in RISK_LEVELS:
        if score <= threshold:
            return level, viable, rec
    return "EXTREME", False, "Route is extremely dangerous."


def _fetch_community_risk(cities):
    """
    Fetches community risk reports from Firestore for the given cities.
    Returns a dict: { "community_risk_score": float 0-1, "report_count": int, "city_scores": {...} }
    Ratings are 1-10; normalised to 0-1 by dividing by 10.
    Deduplicates per user — only the latest rating per user per city counts.
    """
    try:
        from scdo.db import get_db
        db = get_db()
        cutoff = datetime.now(timezone.utc) - timedelta(days=COMMUNITY_WINDOW_DAYS)

        city_scores = {}
        total_reports = 0

        from google.cloud.firestore import FieldFilter
        for city in cities:
            city_lower = city.strip().lower()
            # Only filter by city in Firestore to avoid composite index requirement for date range
            docs = (
                db.collection(COMMUNITY_COLLECTION)
                  .where(filter=FieldFilter("city", "==", city_lower))
                  .stream()
            )

            # Deduplicate: keep only the latest rating per user within the time window
            user_ratings = {}  # user_id -> (timestamp, rating)
            for doc in docs:
                d = doc.to_dict()
                
                # Filter by date in Python
                ts = d.get("created_at")
                if ts:
                    # Ensure ts is offset-aware for comparison
                    if ts.tzinfo is None:
                        ts = ts.replace(tzinfo=timezone.utc)
                    if ts < cutoff:
                        continue

                r = d.get("risk_rating")
                uid = d.get("user_id", "unknown")
                updated_ts = d.get("updated_at") or ts
                
                if updated_ts and updated_ts.tzinfo is None:
                    updated_ts = updated_ts.replace(tzinfo=timezone.utc)

                if r is not None:
                    if uid not in user_ratings or (updated_ts and updated_ts > user_ratings[uid][0]):
                        user_ratings[uid] = (updated_ts, float(r))

            ratings = [v[1] for v in user_ratings.values()]

            if ratings:
                avg = sum(ratings) / len(ratings)
                city_scores[city] = {
                    "avg_rating": round(avg, 2),
                    "normalized": round(avg / 10.0, 4),
                    "num_reports": len(ratings),
                    "unique_users": len(ratings),
                }
                total_reports += len(ratings)
            else:
                city_scores[city] = {"avg_rating": 0, "normalized": 0.0, "num_reports": 0, "unique_users": 0}

        # Aggregate: average of per-city normalised scores (only cities with data)
        scored_cities = [v["normalized"] for v in city_scores.values() if v["num_reports"] > 0]
        agg_score = sum(scored_cities) / len(scored_cities) if scored_cities else 0.0

        return {
            "community_risk_score": round(agg_score, 4),
            "report_count": total_reports,
            "city_scores": city_scores,
        }
    except Exception as e:
        logger.warning(f"Community risk fetch failed: {e}")
        return {"community_risk_score": 0.0, "report_count": 0, "city_scores": {}, "error": str(e)}


def compute_combined_risk(cities, cargo_type="general", target_date=None):
    """
    Computes combined risk from weather + sentiment + community feedback.
    Non-linear formula: R_base = 1 - (1-S)*(1-W) + S*W*k
    Community blending: R = (1 - COMMUNITY_WEIGHT) * R_base + COMMUNITY_WEIGHT * C
    Kill-switch at 0.85.
    """
    # Get individual risks
    weather_result = compute_weather_risk(cities, cargo_type, target_date)
    sentiment_result = compute_sentiment_risk(cities)
    community_result = _fetch_community_risk(cities)

    w = weather_result.get("weather_risk_score", 0.0)
    s = sentiment_result.get("sentiment_risk_score", 0.0)
    c = community_result.get("community_risk_score", 0.0)

    # Non-linear combination of weather + sentiment
    base = 1.0 - (1.0 - s) * (1.0 - w)
    synergy = s * w * SYNERGY_K
    r_base = base + synergy

    # Blend in community feedback
    if community_result.get("report_count", 0) > 0:
        combined = (1.0 - COMMUNITY_WEIGHT) * r_base + COMMUNITY_WEIGHT * c
    else:
        combined = r_base  # no community data → fall back to original formula

    # Kill-switch
    if max(s, w) >= KILL_SWITCH:
        combined = max(combined, 0.95)

    combined = min(combined, 1.0)
    level, viable, rec = _classify(combined)

    return {
        "combined_risk_score": round(combined, 4),
        "risk_level": level,
        "route_viable": viable,
        "recommendation": rec,
        "weather_risk": weather_result,
        "sentiment_risk": sentiment_result,
        "community_risk": community_result,
    }
