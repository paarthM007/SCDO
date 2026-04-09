"""
engine.py — Supply-Chain Disruption Oracle (SCDO) Core Engine
=============================================================
Pure sentiment-driven supply-chain risk scoring served as a Flask API.

Endpoint:
  GET /api/sentiment-risk?cities=Mumbai,Bhopal,Delhi

External APIs:
  - NewsAPI  (news headlines — free tier, key required)
"""

from __future__ import annotations

import json
import logging
import os
import time
from datetime import datetime, timezone
from typing import Dict, List

from flask import Flask, request, jsonify
from vaderSentiment.vaderSentiment import SentimentIntensityAnalyzer

import numpy as np
import requests as http_requests
import pycountry

# ── Flask App ─────────────────────────────────────────────────
app = Flask(__name__)

# ── Configuration ─────────────────────────────────────────────
try:
    import config
    NEWS_API_KEY = config.NEWS_API_KEY
except ImportError:
    NEWS_API_KEY = os.getenv("NEWS_API_KEY", "")

logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(message)s")
log = logging.getLogger(__name__)


# ═══════════════════════════════════════════════════════════════
#  Supply-Chain Sentiment Configuration
# ═══════════════════════════════════════════════════════════════

SUPPLY_CHAIN_KEYWORDS = [
    # Logistics & transport
    "supply chain", "logistics", "shipping delay", "freight", "cargo",
    "port closure", "port closed", "port congestion", "canal block",
    "canal blockage", "container shortage", "route blocked",
    "rail disruption", "rail strike", "air cargo", "truck driver shortage",
    "grounded flights", "shipping lane",
    # Labor
    "labor strike", "labour strike", "dock workers", "dockworkers",
    "trucker strike", "workers strike", "union strike", "walkout",
    "industrial action",
    # Trade & policy
    "trade embargo", "trade war", "sanctions", "tariff", "export ban",
    "import restriction", "import ban", "customs blockade", "border closure",
    "border shut",
    # Natural disasters affecting supply
    "hurricane", "typhoon", "cyclone", "earthquake", "tsunami",
    "volcanic eruption", "flood damage", "wildfire",
    "drought", "famine",
    # Industrial disruption
    "factory shutdown", "factory fire", "factory closure",
    "refinery explosion", "refinery fire", "pipeline attack",
    "power outage", "blackout", "grid failure",
    "warehouse fire", "plant explosion",
    # Shortages
    "semiconductor shortage", "chip shortage", "raw material shortage",
    "fuel shortage", "gas shortage", "oil shortage", "steel shortage",
    # Conflict affecting trade
    "war", "war zone", "armed conflict", "military blockade", "naval blockade",
    "rebel attack", "insurgent attack", "piracy", "invasion", "bombing",
    "strait of hormuz", "suez canal", "red sea", "strait of malacca",
    "airspace closed", "no-fly zone", "missile strike", "missile attack",
    "coup", "martial law", "ceasefire", "conflict", "military operation",
    # General disruption terms
    "disruption", "shortage", "bottleneck", "backlog",
    "embargo", "blockade", "strike", "protest", "riot",
]

IRRELEVANT_TOPICS = [
    # Crime
    "murder", "murdered", "homicide", "robbery", "robbed", "theft",
    "assault", "assaulted", "kidnap", "kidnapped", "rape", "raped",
    "stabbing", "stabbed", "shooting", "shot dead", "gunman",
    "serial killer", "drug bust", "drug cartel", "gang violence",
    "domestic violence", "arson",
    # Law enforcement
    "arrest", "arrested", "police custody", "jail", "prison sentence",
    "court verdict", "trial", "convicted", "sentenced",
    # Entertainment & sports
    "celebrity", "bollywood", "hollywood", "movie", "film release",
    "cricket", "football", "soccer", "tennis", "ipl", "world cup",
    "oscar", "grammy", "box office", "concert", "album",
    "band", "duo", "tour", "gig", "festival", "music video",
    "tv show", "series premiere", "streaming", "netflix", "spotify",
    "trance", "hip hop", "rapper", "singer", "guitarist",
    # Politics (non-trade)
    "election", "campaign rally", "politician", "parliament debate",
    "vote count", "resignation",
    # Local accidents
    "car crash", "road accident", "bike accident", "drunk driving",
    "hit and run",
]


# ═══════════════════════════════════════════════════════════════
#  Severity Tiers — how catastrophic a supply-chain event is
# ═══════════════════════════════════════════════════════════════

CATASTROPHIC_KEYWORDS = [
    "war", "armed conflict", "invasion", "bombing", "missile strike",
    "missile attack", "naval blockade", "military blockade",
    "airspace closed", "no-fly zone",
    "tsunami", "earthquake", "volcanic eruption", "nuclear",
    "hurricane", "typhoon", "cyclone", "tornado",
    "embargo", "trade war",
    "famine", "pandemic", "coup", "martial law",
]

SEVERE_KEYWORDS = [
    "port closed", "port closure", "port shut", "canal block",
    "canal blockage", "strait", "suez", "hormuz",
    "factory shutdown", "factory fire", "factory explosion",
    "refinery explosion", "refinery fire",
    "pipeline attack", "pipeline explosion",
    "power outage", "blackout", "grid failure",
    "flood", "wildfire", "drought",
    "sanctions", "export ban", "import ban", "border closure",
    "labor strike", "labour strike", "dock workers",
    "trucker strike", "general strike",
    "semiconductor shortage", "chip shortage",
    "container shortage", "fuel shortage", "oil shortage",
    "rebel attack", "insurgent", "piracy",
    "conflict", "ceasefire", "military operation",
]

MODERATE_KEYWORDS = [
    "disruption", "delay", "shortage", "congestion",
    "bottleneck", "backlog", "protest", "riot",
    "tariff", "customs", "inspection",
    "strike", "walkout", "slowdown",
    "storm", "heavy rain",
]


# ═══════════════════════════════════════════════════════════════
#  Headline Filtering Logic
# ═══════════════════════════════════════════════════════════════

# Words that are too generic on their own — they only count when
# paired with a *specific* supply-chain keyword
GENERIC_SC_WORDS = {
    "strike", "protest", "riot", "shortage", "disruption",
    "blockade", "embargo", "backlog", "bottleneck",
    "war", "conflict", "invasion", "bombing", "ceasefire",
    "coup", "martial law", "military operation",
}


def _is_supply_chain_relevant(headline: str, city_name: str = "", country_name: str = "") -> bool:
    """
    Three-pass filter:
    1. Must contain at least one supply-chain keyword.
    2. If it also matches an irrelevant topic, only keep if a *specific*
       (non-generic) keyword is present.
    3. If the ONLY matched keywords are generic geopolitical words
       (war, conflict, etc.), the headline must also mention the city
       or country to be considered relevant to *this* route.
    """
    text = headline.lower()
    city_lower = city_name.lower()
    country_lower = country_name.lower()

    matched_sc_keywords = [kw for kw in SUPPLY_CHAIN_KEYWORDS if kw in text]
    if not matched_sc_keywords:
        return False

    # --- Pass 2: filter out entertainment / crime false-positives ---
    has_irrelevant = any(kw in text for kw in IRRELEVANT_TOPICS)
    if has_irrelevant:
        specific_keywords = [kw for kw in matched_sc_keywords if kw not in GENERIC_SC_WORDS]
        if not specific_keywords:
            return False

    # --- Pass 3: generic geopolitical keywords need locality check ---
    specific_keywords = [kw for kw in matched_sc_keywords if kw not in GENERIC_SC_WORDS]
    if not specific_keywords:
        # ALL matched keywords are generic — check if headline mentions the city or country
        mentions_city = bool(city_lower and city_lower in text)
        mentions_country = bool(country_lower and country_lower in text)
        if not mentions_city and not mentions_country:
            log.info("  ⊘ GENERIC-GEO (no city/country mention): %s", headline[:80])
            return False

    return True


def _filter_relevant_headlines(headlines: List[str], city_name: str = "", country_name: str = "") -> List[str]:
    """Filter headlines to only supply-chain-relevant ones for *this* city/country."""
    relevant = []
    for headline in headlines:
        if not headline or headline == "[Removed]":
            continue
        if headline == "No recent disruption news found for this area":
            continue
        if _is_supply_chain_relevant(headline, city_name, country_name):
            relevant.append(headline)
            log.info("  ✓ RELEVANT: %s", headline)
        else:
            log.info("  ✗ FILTERED OUT: %s", headline)
    return relevant


# ═══════════════════════════════════════════════════════════════
#  Geocoding Helper
# ═══════════════════════════════════════════════════════════════

def _resolve_country(city_name: str) -> str:
    """Resolve a city to its country name using OpenWeatherMap geocoding."""
    owm_key = getattr(config, "OWM_API_KEY", os.getenv("OWM_API_KEY", ""))
    if not owm_key:
        return ""
    try:
        url = f"http://api.openweathermap.org/geo/1.0/direct?q={city_name}&limit=1&appid={owm_key}"
        data = http_requests.get(url, timeout=5).json()
        if data and isinstance(data, list) and len(data) > 0:
            country_code = data[0].get("country")
            if country_code:
                c = pycountry.countries.get(alpha_2=country_code)
                if c:
                    # Use common name if available, otherwise strip comma info (e.g. "Iran, Islamic Republic of" -> "Iran")
                    return getattr(c, "common_name", c.name.split(",")[0])
    except Exception as e:
        log.warning("Could not resolve country for %s: %s", city_name, e)
    return ""


# ═══════════════════════════════════════════════════════════════
#  FUNCTION 1: fetch_location_data
# ═══════════════════════════════════════════════════════════════

def fetch_location_data(city_name: str) -> Dict:
    """
    Fetch supply-chain-related news headlines for a city (and its country).

    Parameters
    ----------
    city_name : str   City name (e.g. "Mumbai")

    Returns
    -------
    dict with keys: city_name, country_name, news_headlines
    """
    news_headlines: List[str] = []
    country_name = _resolve_country(city_name)
    log.info("Resolved %s -> Country: '%s'", city_name, country_name)

    if NEWS_API_KEY and not NEWS_API_KEY.startswith("YOUR_"):
        try:
            place_query = f"(\"{city_name}\" OR \"{country_name}\")" if country_name else f"\"{city_name}\""
            q = (
                f"{place_query} AND ("
                "\"supply chain\" OR strike OR disruption OR shortage OR "
                "embargo OR blockade OR \"port closed\" OR tariff OR "
                "hurricane OR earthquake OR flood OR war OR sanctions"
                ")"
            )
            resp = http_requests.get(
                "https://newsapi.org/v2/everything",
                params={
                    "q": q,
                    "language": "en",
                    "sortBy": "publishedAt",
                    "pageSize": 50,
                    "apiKey": NEWS_API_KEY,
                },
                timeout=10,
            )
            resp.raise_for_status()
            for art in resp.json().get("articles", []):
                title = art.get("title")
                if title and title != "[Removed]":
                    news_headlines.append(title)
            log.info("NewsAPI returned %d headlines for %s", len(news_headlines), city_name)
        except http_requests.RequestException as e:
            log.error("NewsAPI error: %s", e)

    if not news_headlines:
        news_headlines = ["No recent disruption news found for this area"]

    return {
        "city_name":      city_name,
        "country_name":   country_name,
        "news_headlines": news_headlines,
    }


# ═══════════════════════════════════════════════════════════════
#  Severity Helper
# ═══════════════════════════════════════════════════════════════

def _headline_severity(headline: str) -> float:
    """
    Return a severity multiplier (1.0–2.5) based on how catastrophic
    the keywords in a headline are.  Higher = more impactful.
    """
    text = headline.lower()
    for kw in CATASTROPHIC_KEYWORDS:
        if kw in text:
            return 2.5
    for kw in SEVERE_KEYWORDS:
        if kw in text:
            return 1.8
    for kw in MODERATE_KEYWORDS:
        if kw in text:
            return 1.3
    return 1.0


# ═══════════════════════════════════════════════════════════════
#  FUNCTION 2: calculate_feature_scores
# ═══════════════════════════════════════════════════════════════

def calculate_feature_scores(location_data: Dict, city_name: str = "") -> float:
    """
    Score supply-chain sentiment risk (0.0–1.0) from news headlines.

    Severity-aware:
      • Catastrophic events (war, invasion) amplify the VADER score ×2.5
      • Severe events (port closure, sanctions) amplify ×1.8
      • Moderate events (delays, protests) amplify ×1.3

    Volume-aware:
      • More negative headlines → higher confidence the risk is real
    """
    headlines = location_data.get("news_headlines", [])
    country_name = location_data.get("country_name", "")

    log.info("Filtering %d headlines for supply-chain relevance...", len(headlines))
    relevant_headlines = _filter_relevant_headlines(headlines, city_name, country_name)

    # Store filtered headlines back for output
    location_data["relevant_headlines"] = relevant_headlines

    if not relevant_headlines:
        sentiment_score = 0.05
        log.info("No supply-chain-relevant headlines → sentiment=%.2f (safe)", sentiment_score)
    else:
        analyzer = SentimentIntensityAnalyzer()
        headline_scores = []

        for headline in relevant_headlines:
            vs = analyzer.polarity_scores(headline)
            compound = vs["compound"]
            severity = _headline_severity(headline)

            if compound < -0.05:
                # Negative headline: VADER magnitude × severity multiplier
                risk_contribution = min(abs(compound) * severity, 1.0)
                headline_scores.append(risk_contribution)
                log.info("  NEG: compound=%.3f × sev=%.1f → risk=%.3f | %s",
                         compound, severity, risk_contribution, headline[:80])
            elif severity >= 1.8:
                # Even neutral/positive framing of catastrophic events is risky
                # e.g. "Iran sanctions continue" may score neutral in VADER
                risk_contribution = min(0.25 * (severity / 2.5), 1.0)
                headline_scores.append(risk_contribution)
                log.info("  SEVERE-NEUTRAL: compound=%.3f, sev=%.1f → risk=%.3f | %s",
                         compound, severity, risk_contribution, headline[:80])
            else:
                log.info("  SKIP: compound=%.3f, sev=%.1f | %s",
                         compound, severity, headline[:80])

        if not headline_scores:
            sentiment_score = 0.05
        else:
            avg_risk = float(np.mean(headline_scores))
            max_risk = float(max(headline_scores))
            num_scored = len(headline_scores)

            # Volume factor: more negative headlines = more confidence
            # 1 → 0.50,  2 → 0.65,  3 → 0.80,  5+ → 1.0
            volume_factor = min(1.0, 0.35 + 0.13 * num_scored)

            # Blend: worst headline dominates (60%) + average (40%)
            blended = 0.6 * max_risk + 0.4 * avg_risk

            sentiment_score = float(np.clip(blended * volume_factor, 0.0, 1.0))
            log.info(
                "Sentiment: %d relevant, %d scored | avg=%.3f max=%.3f vol=%.2f → score=%.4f",
                len(relevant_headlines), num_scored, avg_risk, max_risk,
                volume_factor, sentiment_score,
            )

    sentiment_score = round(sentiment_score, 4)
    log.info("Final sentiment score: %.4f", sentiment_score)
    return sentiment_score


# ═══════════════════════════════════════════════════════════════
#  FUNCTION 3: predict_route_risk
# ═══════════════════════════════════════════════════════════════

def _eval_waypoint(i: int, city: str) -> Dict:
    """Evaluate a single city waypoint."""
    log.info("── Evaluating waypoint %d (%s) ──", i, city)
    raw_data = fetch_location_data(city)
    features = calculate_feature_scores(raw_data, city)

    return {
        "index": i,
        "city": city,
        "sentiment_score": features,
        "combined": features,
        "raw_data": {
            "num_headlines": len(raw_data.get("relevant_headlines", [])),
            "headlines": raw_data.get("relevant_headlines", [])[:5],
        },
    }


def predict_route_risk(
    route_id: str,
    route_cities: List[str],
) -> Dict:
    """
    Evaluate an entire shipping route by city names.

    Returns
    -------
    dict with full risk analysis (JSON-serializable)
    """
    if not route_cities:
        return {
            "route_id": route_id,
            "overall_risk_score": 0.0,
            "action": "SAFE",
            "reason": "No cities provided.",
            "waypoint_scores": [],
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }

    waypoint_scores = []

    for i, city in enumerate(route_cities):
        if i > 0:
            log.info("Sleeping 3s to respect API rate limits...")
            time.sleep(3)
        try:
            score_data = _eval_waypoint(i, city)
            waypoint_scores.append(score_data)
        except Exception as exc:
            log.error("Waypoint %d (%s) generated an exception: %s", i, city, exc)

    if not waypoint_scores:
        return {
            "route_id": route_id,
            "overall_risk_score": 0.0,
            "action": "SAFE",
            "reason": "All waypoints failed to evaluate.",
            "waypoint_scores": [],
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }

    # Find worst waypoint
    worst_wp_info = max(waypoint_scores, key=lambda x: x["combined"])
    worst_combined = worst_wp_info["combined"]
    worst_idx = worst_wp_info["index"]

    log.info(
        "Weakest link: waypoint %d (%s) with sentiment=%.2f",
        worst_idx, worst_wp_info["city"], worst_combined,
    )

    predicted_risk = round(worst_combined, 2)

    if predicted_risk < 0.35:
        action = "SAFE"
    elif predicted_risk < 0.70:
        action = "MONITOR"
    else:
        action = "HALT_AND_REROUTE"

    reason = (
        f"Risk score {predicted_risk:.2f}/1.0. "
        f"Highest risk at waypoint {worst_idx} "
        f"({worst_wp_info['city']}): "
        f"sentiment={worst_wp_info['sentiment_score']:.2f}."
    )

    result = {
        "route_id":           route_id,
        "overall_risk_score": predicted_risk,
        "action":             action,
        "reason":             reason,
        "waypoint_scores":    waypoint_scores,
        "worst_waypoint":     {
            "index": worst_idx,
            "city": worst_wp_info["city"],
            "sentiment_score": worst_wp_info["sentiment_score"],
        },
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }

    log.info("Route '%s' → %s (risk=%.2f)", route_id, action, predicted_risk)
    return result


# ═══════════════════════════════════════════════════════════════
#  Flask Endpoint
# ═══════════════════════════════════════════════════════════════

@app.route('/api/sentiment-risk', methods=['GET'])
def api_get_sentiment_risk():
    if not NEWS_API_KEY:
        return jsonify({"error": "NewsAPI key not configured."}), 500

    cities_param = request.args.get('cities')
    if not cities_param:
        return jsonify({"error": "Provide 'cities' param (e.g. ?cities=Mumbai,Delhi)"}), 400

    route_cities = [c.strip() for c in cities_param.split(',') if c.strip()]
    if not route_cities:
        return jsonify({"error": "No valid city names."}), 400

    route_id = "_".join(route_cities).lower().replace(" ", "")
    result = predict_route_risk(route_id, route_cities)
    return jsonify(result)


if __name__ == "__main__":
    port = int(os.environ.get('PORT', 8081))
    log.info("Starting Sentiment Risk API on port %s", port)
    log.info("Test: GET http://localhost:%s/api/sentiment-risk?cities=Mumbai,Bhopal,Delhi", port)
    app.run(host='0.0.0.0', port=port, debug=False)
