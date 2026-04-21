"""
combination.py — SCDO Combined Risk Service
=============================================
Single microservice that merges:
  • Weather Risk   (from route_weather_risk.py)
  • Sentiment Risk (from engine.py)

into one unified 0.0–1.0 score with full breakdown.

Endpoint:
  GET /api/combined-risk?cities=Mumbai,Delhi&cargo_type=general&date=2026-04-02
"""

from __future__ import annotations

import logging
import os
from datetime import datetime, timezone

from flask import Flask, request, jsonify
from flask_cors import CORS

# ── Import scoring logic from sibling modules ─────────────────
from route_weather_risk import evaluate_route_risk, CARGO_PROFILES
from engine import predict_route_risk

# ── Flask App ─────────────────────────────────────────────────
app = Flask(__name__)
CORS(app)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
)
log = logging.getLogger("SCDO-Combined")

# ── Non-Linear Combination Parameters ────────────────────────
KILL_SWITCH_THRESHOLD = 0.85   # either risk above this → route is NO-GO
SYNERGY_MULTIPLIER    = 0.40   # compounding boost when both risks are elevated


# ==============================================================================
# NON-LINEAR RISK COMBINATION
# ==============================================================================
#
#  Formula:  R = min( 1 - (1-S)*(1-W) + S*W*k ,  1.0 )
#
#  Properties:
#    • Probabilistic OR base:  either risk alone can push R to 1.0
#    • Synergy term S*W*k:     both elevated = compounding danger
#    • Kill switch:            max(S,W) >= 0.85 → R forced to 0.95+
#
#  Quick reference (k=0.40):
#    S=1.0  W=0.0  →  R = 1.00  (war + clear sky = still max risk)
#    S=0.0  W=1.0  →  R = 1.00  (catastrophic weather alone = max)
#    S=0.5  W=0.5  →  R = 0.85  (moderate both = compounding)
#    S=0.6  W=0.6  →  R = 0.98  (high both = near no-go)
#    S=0.3  W=0.1  →  R = 0.38  (mild)
#    S=0.05 W=0.05 →  R = 0.10  (safe)
# ==============================================================================


def _combine_scores(S: float, W: float) -> dict:
    """
    Non-linear combination with kill-switch and synergy.
    Returns a dict with the combined score and diagnostic fields.
    """
    # Stage 1 — Probabilistic OR: "at least one risk materializes"
    base = 1.0 - (1.0 - S) * (1.0 - W)          # = S + W - S*W

    # Stage 2 — Synergy: compounding stress
    synergy = S * W * SYNERGY_MULTIPLIER

    # Stage 3 — Kill switch: any extreme → near-max
    dominant = max(S, W)
    kill_switch_active = dominant >= KILL_SWITCH_THRESHOLD
    if kill_switch_active:
        base = max(base, 0.95)

    combined = round(min(base + synergy, 1.0), 4)

    return {
        "score":              combined,
        "base_or":            round(base, 4),
        "synergy_boost":      round(synergy, 4),
        "kill_switch_active": kill_switch_active,
        "route_viable":       combined < 0.90,
    }


def _classify_risk(score: float, route_viable: bool) -> str:
    """Map a 0-1 score to a human-readable risk level."""
    if not route_viable:
        return "NO-GO"
    if score >= 0.70:
        return "CRITICAL"
    if score >= 0.45:
        return "HIGH"
    if score >= 0.25:
        return "MODERATE"
    return "LOW"


def _action_recommendation(level: str) -> str:
    recommendations = {
        "LOW":      "Route is clear. Proceed as planned.",
        "MODERATE": "Minor risks detected. Monitor conditions and have contingency plans ready.",
        "HIGH":     "Significant risks detected. Consider delaying shipment or switching to an alternate route.",
        "CRITICAL": "Severe disruptions expected. Halt shipment and reroute immediately.",
        "NO-GO":    "ROUTE IS NOT VIABLE. At least one extreme risk detected. Do not proceed — reroute required.",
    }
    return recommendations.get(level, "Unable to determine recommendation.")


def _build_risk_factors(weather_result: dict, sentiment_result: dict) -> list[dict]:
    """
    Collect the top contributing factors from both sub-scores
    so the caller can see *why* the combined score is what it is.
    """
    factors = []

    # --- Weather factors (from warnings list) ---
    for warning in weather_result.get("warnings", []):
        factors.append({
            "source": "weather",
            "description": warning,
        })

    # --- Sentiment factors (from waypoint headlines) ---
    for wp in sentiment_result.get("waypoint_scores", []):
        city = wp.get("city", "Unknown")
        headlines = wp.get("raw_data", {}).get("headlines", [])
        sentiment_score = wp.get("sentiment_score", 0)
        if sentiment_score > 0.15 and headlines:
            for hl in headlines[:3]:
                factors.append({
                    "source": "news_sentiment",
                    "city": city,
                    "description": hl,
                    "sentiment_score": sentiment_score,
                })

    return factors


def _build_city_breakdown(weather_result: dict, sentiment_result: dict, route_cities: list[str]) -> list[dict]:
    """
    Per-city merged breakdown so the frontend can render a table / chart.
    """
    # Index weather city details by name
    weather_by_city = {}
    for detail in weather_result.get("city_details", []):
        weather_by_city[detail["city"]] = detail

    # Index sentiment waypoint scores by city
    sentiment_by_city = {}
    for wp in sentiment_result.get("waypoint_scores", []):
        sentiment_by_city[wp["city"]] = wp

    breakdown = []
    for city in route_cities:
        w = weather_by_city.get(city, {})
        s = sentiment_by_city.get(city, {})

        w_score = w.get("risk_score") if w.get("risk_score") is not None else 0.5
        s_score = s.get("sentiment_score", 0.1)

        city_combo = _combine_scores(s_score, w_score)
        city_combined = city_combo["score"]

        breakdown.append({
            "city": city,
            "combined_score": city_combined,
            "weather_score": round(w_score, 4) if w_score is not None else None,
            "sentiment_score": round(s_score, 4),
            "weather_condition": w.get("condition"),
            "temperature_c": w.get("temp"),
            "weather_hazards": w.get("hazards", []),
            "news_headlines": s.get("raw_data", {}).get("headlines", []),
        })

    return breakdown


# ==============================================================================
# CORE COMBINATION LOGIC
# ==============================================================================

def compute_combined_risk(
    route_cities: list[str],
    cargo_type: str = "general",
    target_date: datetime | None = None,
) -> dict:
    """
    Run both sub-models, merge via non-linear formula.
    """
    # ---- 1. Weather Risk ----
    weather_result = evaluate_route_risk(route_cities, cargo_type, target_date)
    weather_score = weather_result.get("average_risk", 0.5)

    # ---- 2. Sentiment / News Risk ----
    route_id = "_".join(route_cities).lower().replace(" ", "")
    sentiment_result = predict_route_risk(route_id, route_cities)
    sentiment_score = sentiment_result.get("overall_risk_score", 0.0)

    # ---- 3. Non-linear combination ----
    combo = _combine_scores(sentiment_score, weather_score)
    combined_score = combo["score"]
    route_viable = combo["route_viable"]

    risk_level = _classify_risk(combined_score, route_viable)

    # ---- 4. Assemble response ----
    response = {
        # ─── Top-level summary ───────────────────────────────
        "combined_risk_score": combined_score,
        "risk_level": risk_level,
        "route_viable": route_viable,
        "recommendation": _action_recommendation(risk_level),

        # ─── Combination diagnostics ─────────────────────────
        "scoring_model": {
            "formula": "R = 1 - (1-S)*(1-W) + S*W*k",
            "base_or": combo["base_or"],
            "synergy_boost": combo["synergy_boost"],
            "kill_switch_active": combo["kill_switch_active"],
            "kill_switch_threshold": KILL_SWITCH_THRESHOLD,
            "synergy_k": SYNERGY_MULTIPLIER,
        },

        # ─── Sub-scores ──────────────────────────────────────
        "weather_risk": {
            "score": round(weather_score, 4),
            "level": weather_result.get("risk_level", "UNKNOWN"),
            "warnings": weather_result.get("warnings", []),
        },
        "sentiment_risk": {
            "score": round(sentiment_score, 4),
            "action": sentiment_result.get("action", "UNKNOWN"),
            "reason": sentiment_result.get("reason", ""),
            "worst_waypoint": sentiment_result.get("worst_waypoint"),
        },

        # ─── Per-city breakdown ──────────────────────────────
        "city_breakdown": _build_city_breakdown(weather_result, sentiment_result, route_cities),

        # ─── What caused this score ──────────────────────────
        "risk_factors": _build_risk_factors(weather_result, sentiment_result),

        # ─── Metadata ────────────────────────────────────────
        "meta": {
            "route": route_cities,
            "cargo_type": cargo_type,
            "cargo_label": weather_result.get("cargo_label", ""),
            "target_date": target_date.strftime("%Y-%m-%d") if target_date else None,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        },
    }

    log.info(
        "Combined %.4f (%s, viable=%s) for %s  [S=%.3f W=%.3f base=%.3f syn=%.3f kill=%s]",
        combined_score, risk_level, route_viable, " → ".join(route_cities),
        sentiment_score, weather_score,
        combo["base_or"], combo["synergy_boost"], combo["kill_switch_active"],
    )
    return response


# ==============================================================================
# FLASK ENDPOINT
# ==============================================================================

@app.route("/", methods=["GET"])
def index():
    return jsonify({
        "message": "SCDO Combined Risk API is running.",
        "endpoints": ["/api/combined-risk", "/api/cargo-types", "/api/health"],
        "example": "/api/combined-risk?cities=Mumbai,Delhi&cargo_type=general"
    })

@app.route("/api/combined-risk", methods=["GET"])
def api_combined_risk():
    """
    GET /api/combined-risk?cities=Mumbai,Delhi&cargo_type=general&date=2026-04-02

    Query params:
      cities      (required) comma-separated city names
      cargo_type  (optional) one of the CARGO_PROFILES keys, default "general"
      date        (optional) YYYY-MM-DD, must be within 5-day forecast window
    """
    # -- cities --
    cities_param = request.args.get("cities")
    if not cities_param:
        return jsonify({"error": "Provide 'cities' param (e.g. ?cities=Mumbai,Delhi)"}), 400

    route_cities = [c.strip() for c in cities_param.split(",") if c.strip()]
    if not route_cities:
        return jsonify({"error": "No valid city names provided."}), 400
    if len(route_cities) > 15:
        return jsonify({"error": "Maximum 15 cities allowed per request."}), 400

    # -- cargo_type --
    cargo_type = request.args.get("cargo_type", "general").strip().lower()
    if cargo_type not in CARGO_PROFILES:
        return jsonify({
            "error": f"Unknown cargo_type '{cargo_type}'. Valid options: {', '.join(sorted(CARGO_PROFILES))}",
        }), 400

    # -- date --
    target_date = None
    date_param = request.args.get("date")
    if date_param:
        try:
            target_date = datetime.strptime(date_param.strip(), "%Y-%m-%d").replace(tzinfo=timezone.utc)
        except ValueError:
            return jsonify({"error": f"Invalid date '{date_param}'. Use YYYY-MM-DD."}), 400

        now = datetime.now(timezone.utc)
        if target_date.date() < now.date():
            return jsonify({"error": "Date is in the past."}), 400
        if (target_date - now).days > 5:
            return jsonify({"error": "Date > 5 days ahead. Only 5-day forecasts are available."}), 400

    # -- compute & return --
    result = compute_combined_risk(route_cities, cargo_type, target_date)
    return jsonify(result)


@app.route("/api/cargo-types", methods=["GET"])
def api_cargo_types():
    """List all supported cargo types and their thresholds."""
    return jsonify({k: v for k, v in CARGO_PROFILES.items()})


@app.route("/api/health", methods=["GET"])
def api_health():
    """Simple health-check for monitoring / load balancers."""
    return jsonify({"status": "ok", "service": "SCDO Combined Risk API"})


# ==============================================================================
# MAIN
# ==============================================================================

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    log.info("SCDO Combined Risk API starting on port %s", port)
    log.info(
        "Test: GET http://localhost:%s/api/combined-risk?cities=Mumbai,Delhi&cargo_type=general",
        port,
    )
    app.run(host="0.0.0.0", port=port, debug=False)
