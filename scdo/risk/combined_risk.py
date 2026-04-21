"""
combined_risk.py - Combines weather + sentiment into a single 0-1 score.
From combination.py.
"""
import logging
from scdo.risk.weather_risk import compute_weather_risk
from scdo.risk.sentiment_risk import compute_sentiment_risk

logger = logging.getLogger(__name__)

KILL_SWITCH = 0.85
SYNERGY_K = 0.40

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


def compute_combined_risk(cities, cargo_type="general", target_date=None):
    """
    Computes combined risk from weather + sentiment.
    Non-linear formula: R = 1 - (1-S)*(1-W) + S*W*k
    Kill-switch at 0.85.
    """
    # Get individual risks
    weather_result = compute_weather_risk(cities, cargo_type, target_date)
    sentiment_result = compute_sentiment_risk(cities)

    w = weather_result.get("weather_risk_score", 0.0)
    s = sentiment_result.get("sentiment_risk_score", 0.0)

    # Non-linear combination
    base = 1.0 - (1.0 - s) * (1.0 - w)
    synergy = s * w * SYNERGY_K
    combined = base + synergy

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
    }
