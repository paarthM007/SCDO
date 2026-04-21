"""
engine.py — Supply-Chain Disruption Oracle (SCDO) Core Engine
=============================================================
Gemini-driven supply-chain risk scoring served as a Flask API.

Flow:
  1. Receive list of cities
  2. Fetch news headlines (NewsAPI + Reddit) for ALL cities
  3. Send all headlines to Gemini in ONE call → get risk score 0-1 per city

Endpoint:
  GET /api/sentiment-risk?cities=Mumbai,Bhopal,Delhi

External APIs:
  - NewsAPI  (news headlines — free tier, key required)
  - Reddit   (public search, no key required)
  - Gemini   (risk evaluation)
"""

from __future__ import annotations

import json
import logging
import os
import time
from datetime import datetime, timezone
from typing import Dict, List

from flask import Flask, request, jsonify

import requests as http_requests
import pycountry
from google import genai

# ── Flask App ─────────────────────────────────────────────────
app = Flask(__name__)

# ── Configuration ─────────────────────────────────────────────
try:
    import config
    NEWS_API_KEY = config.NEWS_API_KEY
    GEMINI_API_KEY = config.GEMINI_API_KEY
except ImportError:
    NEWS_API_KEY = os.getenv("NEWS_API_KEY", "")
    GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")



logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(message)s")
log = logging.getLogger(__name__)


# ═══════════════════════════════════════════════════════════════
#  Supply-Chain Keyword Lists (used for headline filtering)
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


# Words that are too generic on their own — they only count when
# paired with a *specific* supply-chain keyword
GENERIC_SC_WORDS = {
    "strike", "protest", "riot", "shortage", "disruption",
    "blockade", "embargo", "backlog", "bottleneck",
    "war", "conflict", "invasion", "bombing", "ceasefire",
    "coup", "martial law", "military operation",
}

DEFAULT_RISK_RESULT = {
    "risk_score": 0.05,
    "primary_hazard": "None",
    "reasoning": "No news available or analysis failed."
}


# ═══════════════════════════════════════════════════════════════
#  Headline Filtering Logic
# ═══════════════════════════════════════════════════════════════

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
                    return getattr(c, "common_name", c.name.split(",")[0])
    except Exception as e:
        log.warning("Could not resolve country for %s: %s", city_name, e)
    return ""


# ═══════════════════════════════════════════════════════════════
#  Data Fetching: NewsAPI + Reddit (per-city)
# ═══════════════════════════════════════════════════════════════

def _fetch_newsapi_headlines(city_name: str, country_name: str) -> List[str]:
    """Fetch supply-chain-related news headlines from NewsAPI for a city."""
    headlines: List[str] = []
    if not NEWS_API_KEY or NEWS_API_KEY.startswith("YOUR_"):
        return headlines

    try:
        place_query = f'("{city_name}" OR "{country_name}")' if country_name else f'"{city_name}"'
        q = (
            f"{place_query} AND ("
            '"supply chain" OR strike OR disruption OR shortage OR '
            'embargo OR blockade OR "port closed" OR tariff OR '
            'hurricane OR earthquake OR flood OR war OR sanctions'
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
                headlines.append(title)
        log.info("NewsAPI returned %d headlines for %s", len(headlines), city_name)
    except http_requests.RequestException as e:
        log.error("NewsAPI error for %s: %s", city_name, e)

    return headlines


def _fetch_reddit_headlines(city_name: str, country_name: str) -> List[str]:
    """Fetch supply-chain-related posts from Reddit's public search API."""
    headlines: List[str] = []
    search_terms = [city_name]
    if country_name:
        search_terms.append(country_name)

    query = f"({' OR '.join(search_terms)}) AND (supply chain OR disruption OR shortage OR strike OR embargo OR war OR sanctions OR flood OR earthquake)"

    try:
        resp = http_requests.get(
            "https://www.reddit.com/search.json",
            params={
                "q": query,
                "sort": "new",
                "limit": 25,
                "t": "week",
            },
            headers={"User-Agent": "SCDO-Engine/1.0"},
            timeout=10,
        )
        resp.raise_for_status()
        data = resp.json()
        for post in data.get("data", {}).get("children", []):
            title = post.get("data", {}).get("title", "")
            if title:
                headlines.append(title)
        log.info("Reddit returned %d posts for %s", len(headlines), city_name)
    except Exception as e:
        log.warning("Reddit search error for %s: %s", city_name, e)

    return headlines


def _fetch_all_headlines_for_city(city_name: str, country_name: str) -> List[str]:
    """Fetch and filter headlines from all sources for a single city."""
    raw_headlines: List[str] = []

    # NewsAPI
    raw_headlines.extend(_fetch_newsapi_headlines(city_name, country_name))

    # Reddit
    raw_headlines.extend(_fetch_reddit_headlines(city_name, country_name))

    # Filter for supply-chain relevance
    relevant = _filter_relevant_headlines(raw_headlines, city_name, country_name)
    log.info("City %s: %d raw → %d relevant headlines", city_name, len(raw_headlines), len(relevant))

    return relevant


# ═══════════════════════════════════════════════════════════════
#  Batch Gemini Risk Evaluation (ONE call for ALL cities)
# ═══════════════════════════════════════════════════════════════

# def _build_gemini_batch_prompt(city_headlines: Dict[str, List[str]]) -> str:
#     """
#     Build a single prompt that presents headlines for ALL cities
#     and asks Gemini to return a risk score (0-1) for each.
#     """
#     prompt_parts = [
#         "You are a supply-chain risk analyst. Below are recent news headlines "
#         "and social media posts related to several locations along a shipping route. "
#         "For EACH location, evaluate the supply-chain disruption risk based on the "
#         "headlines provided.\n\n"
#         "SCORING GUIDELINES:\n"
#         "- 0.00-0.10: No disruption signals, business as usual\n"
#         "- 0.10-0.30: Minor concerns (small delays, minor weather)\n"
#         "- 0.30-0.50: Moderate risk (strikes, congestion, policy changes)\n"
#         "- 0.50-0.70: High risk (severe weather, port closures, significant strikes)\n"
#         "- 0.70-0.90: Critical risk (armed conflict near trade routes, embargoes, natural disasters)\n"
#         "- 0.90-1.00: Catastrophic (active war zone, total trade shutdown, major disaster)\n\n"
#         "If a location has NO headlines, assign a risk score of 0.05 (baseline safe).\n\n"
#         "IMPORTANT: Consider the SEVERITY and RELEVANCE of each headline to supply-chain operations. "
#         "A war or embargo is far more impactful than a minor protest.\n\n"
#         "═══════════════════════════════════════════\n"
#         "HEADLINES BY LOCATION:\n"
#         "═══════════════════════════════════════════\n\n"
#     ]

#     for city, headlines in city_headlines.items():
#         prompt_parts.append(f"### {city}\n")
#         if headlines:
#             for i, hl in enumerate(headlines[:20], 1):  # Cap at 20 per city
#                 prompt_parts.append(f"  {i}. {hl}\n")
#         else:
#             prompt_parts.append("  (No relevant headlines found)\n")
#         prompt_parts.append("\n")

#     cities_list = list(city_headlines.keys())
#     prompt_parts.append(
#         "═══════════════════════════════════════════\n"
#         "RESPONSE FORMAT:\n"
#         "═══════════════════════════════════════════\n\n"
#         "Return ONLY a valid JSON object with no extra text, no markdown fences, "
#         "no explanation outside the JSON. The JSON must have this exact structure:\n\n"
#         "{\n"
#     )

#     for city in cities_list:
#         prompt_parts.append(
#             f'  "{city}": {{\n'
#             f'    "risk_score": <float 0.0-1.0>,\n'
#             f'    "primary_hazard": "<short description of biggest threat or None>",\n'
#             f'    "reasoning": "<1-2 sentence explanation>"\n'
#             f'  }},\n'
#         )

#     prompt_parts.append("}\n")

#     return "".join(prompt_parts)
def _build_gemini_batch_prompt(city_headlines: Dict[str, List[str]]) -> str:
    """
    Build a single prompt that presents headlines for ALL cities
    and asks Gemini to return a risk score (0-1) for each.
    """
    prompt_parts = [
        "You are a corporate supply-chain risk analyst. Below are recent news headlines "
        "and social media posts related to several locations along a shipping route. "
        "For EACH location, evaluate the supply-chain disruption risk based on the "
        "headlines provided.\n\n"
        "SCORING GUIDELINES:\n"
        "- 0.00-0.20: Routine operations, general geopolitical noise, business as usual\n"
        "- 0.20-0.35: Minor concerns (small local delays, minor weather)\n"
        "- 0.35-0.55: Moderate risk (active local strikes, severe weather directly hitting the city)\n"
        "- 0.55-0.80: High risk (city port physical closure, direct embargo)\n"
        "- 0.80-1.00: Catastrophic (complete physical destruction of infrastructure)\n\n"
        "IMPORTANT: News about distant geopolitical wars (like the Strait of Hormuz) should NOT exceed a score of 0.45 unless the specific city being evaluated is physically under attack. The supply chain is resilient; grade conservatively.\n\n"
        "IMPORTANT: Use neutral, corporate risk terminology. Avoid graphic conflict words. "
        "Use terms like 'Geopolitical tension' or 'Security incident' instead of violent words.\n\n"
        "═══════════════════════════════════════════\n"
        "HEADLINES BY LOCATION:\n"
        "═══════════════════════════════════════════\n\n"
    ]

    for city, headlines in city_headlines.items():
        prompt_parts.append(f"### {city}\n")
        if headlines:
            for i, hl in enumerate(headlines[:20], 1):  # Cap at 20 per city
                prompt_parts.append(f"  {i}. {hl}\n")
        else:
            prompt_parts.append("  (No relevant headlines found)\n")
        prompt_parts.append("\n")

    cities_list = list(city_headlines.keys())
    prompt_parts.append(
        "═══════════════════════════════════════════\n"
        "RESPONSE FORMAT:\n"
        "═══════════════════════════════════════════\n\n"
        "Return ONLY a valid JSON object with no extra text. The JSON must have this exact structure:\n\n"
        "{\n"
    )

    for city in cities_list:
        prompt_parts.append(
            f'  "{city}": {{\n'
            f'    "risk_score": <float 0.0-1.0>,\n'
            f'    "primary_hazard": "<short description of biggest threat or None>"\n'
            f'  }},\n'
        )

    prompt_parts.append("}\n")

    return "".join(prompt_parts)

def _evaluate_risks_with_gemini(city_headlines: Dict[str, List[str]]) -> Dict[str, Dict]:
    """
    Send ALL city headlines to Gemini in ONE call and get back
    risk scores for every city.

    Uses response_mime_type="application/json" to force strict JSON output.
    """
    if not GEMINI_API_KEY:
        log.warning("No Gemini API key configured. Using default risk scores.")
        return {city: DEFAULT_RISK_RESULT.copy() for city in city_headlines}

    prompt = _build_gemini_batch_prompt(city_headlines)
    log.info("Sending batch prompt to Gemini for %d cities...", len(city_headlines))

    max_retries = 3
    for attempt in range(max_retries):
        try:
            client = genai.Client(api_key=GEMINI_API_KEY)
            response = client.models.generate_content(
                model="gemini-2.5-flash",
                contents=prompt,
                # config=genai.types.GenerateContentConfig(
                #     response_mime_type="application/json",
                #     temperature=0.1,       # low temperature for consistent scoring
                #     max_output_tokens=1024,  # enough for multi-city response
                # ),
                config=genai.types.GenerateContentConfig(
                    response_mime_type="application/json",
                    temperature=0.1,
                    max_output_tokens=8192, # <--- Bump this from 1024/2048 to 8192
                    safety_settings=[
                        genai.types.SafetySetting(
                            category=genai.types.HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT,
                            threshold=genai.types.HarmBlockThreshold.BLOCK_NONE,
                        ),
                        genai.types.SafetySetting(
                            category=genai.types.HarmCategory.HARM_CATEGORY_HARASSMENT,
                            threshold=genai.types.HarmBlockThreshold.BLOCK_NONE,
                        ),
                        genai.types.SafetySetting(
                            category=genai.types.HarmCategory.HARM_CATEGORY_HATE_SPEECH,
                            threshold=genai.types.HarmBlockThreshold.BLOCK_NONE,
                        )
                    ]
                ),
            )

            raw_text = response.text.strip()
            log.info("Gemini raw batch response (first 500 chars): %s", raw_text[:500])

            result = json.loads(raw_text)

            # Validate and normalize scores
            validated = {}
            for city in city_headlines:
                if city in result:
                    city_data = result[city]
                    score = float(city_data.get("risk_score", 0.05))
                    score = max(0.0, min(1.0, score))  # clamp to [0, 1]
                    validated[city] = {
                        "risk_score": round(score, 4),
                        "primary_hazard": city_data.get("primary_hazard", "None"),
                        "reasoning": city_data.get("reasoning", "No reasoning provided."),
                    }
                else:
                    log.warning("Gemini response missing city: %s. Defaulting to 0.05.", city)
                    validated[city] = DEFAULT_RISK_RESULT.copy()

            log.info("Gemini batch evaluation complete: %s",
                     {c: v["risk_score"] for c, v in validated.items()})
            return validated

        except Exception as e:
            error_msg = str(e)
            if "429" in error_msg and attempt < max_retries - 1:
                sleep_time = 2 ** attempt * 5
                log.warning("Gemini API rate limited (429). Retrying in %ds...", sleep_time)
                time.sleep(sleep_time)
                continue
            log.error("Gemini batch API call failed (attempt %d): %s", attempt + 1, e)

    # All retries failed — return defaults
    log.error("All Gemini retries failed. Returning default scores (0.05) for all cities.")
    return {city: DEFAULT_RISK_RESULT.copy() for city in city_headlines}


# ═══════════════════════════════════════════════════════════════
#  FUNCTION 1: fetch_location_data  (kept for compatibility)
# ═══════════════════════════════════════════════════════════════

def fetch_location_data(city_name: str) -> Dict:
    """Fetch supply-chain-related news headlines for a city."""
    country_name = _resolve_country(city_name)
    log.info("Resolved %s -> Country: '%s'", city_name, country_name)

    headlines = _fetch_all_headlines_for_city(city_name, country_name)

    if not headlines:
        headlines = ["No recent disruption news found for this area"]

    return {
        "city_name":      city_name,
        "country_name":   country_name,
        "news_headlines": headlines,
    }


# ═══════════════════════════════════════════════════════════════
#  FUNCTION 3: predict_route_risk  (REFACTORED — batch approach)
# ═══════════════════════════════════════════════════════════════

def predict_route_risk(
    route_id: str,
    route_cities: List[str],
) -> Dict:
    """
    Evaluate an entire shipping route by city names.

    New flow:
      1. Resolve country for each city
      2. Fetch ALL headlines (NewsAPI + Reddit) for ALL cities
      3. ONE Gemini call to score all cities
      4. Assemble results

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

    # ── Step 1: Resolve countries for all cities ──────────────
    city_countries: Dict[str, str] = {}
    for city in route_cities:
        city_countries[city] = _resolve_country(city)
        log.info("Resolved %s -> Country: '%s'", city, city_countries[city])

    # ── Step 2: Fetch headlines for ALL cities ────────────────
    city_headlines: Dict[str, List[str]] = {}
    city_raw_data: Dict[str, Dict] = {}

    for i, city in enumerate(route_cities):
        if i > 0:
            log.info("Sleeping 1s between city fetches to respect API rate limits...")
            time.sleep(1)

        country = city_countries[city]
        relevant = _fetch_all_headlines_for_city(city, country)
        city_headlines[city] = relevant
        city_raw_data[city] = {
            "country_name": country,
            "relevant_headlines": relevant,
        }

    log.info("Total headlines fetched: %s",
             {c: len(h) for c, h in city_headlines.items()})

    # ── Step 3: ONE Gemini call for all cities ────────────────
    gemini_results = _evaluate_risks_with_gemini(city_headlines)

    # ── Step 4: Assemble waypoint scores ──────────────────────
    waypoint_scores = []
    for i, city in enumerate(route_cities):
        risk_data = gemini_results.get(city, DEFAULT_RISK_RESULT.copy())
        score = risk_data["risk_score"]

        waypoint_scores.append({
            "index": i,
            "city": city,
            "sentiment_score": score,
            "combined": score,
            "gemini_analysis": {
                "risk_score": score,
                "primary_hazard": risk_data.get("primary_hazard", "None"),
                "reasoning": risk_data.get("reasoning", ""),
            },
            "raw_data": {
                "num_headlines": len(city_headlines.get(city, [])),
                "headlines": city_headlines.get(city, [])[:5],
            },
        })

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
        "Weakest link: waypoint %d (%s) with risk=%.2f",
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
        f"risk={worst_wp_info['sentiment_score']:.2f}. "
        f"Hazard: {worst_wp_info['gemini_analysis'].get('primary_hazard', 'N/A')}."
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
            "primary_hazard": worst_wp_info["gemini_analysis"].get("primary_hazard", "None"),
        },
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }

    log.info("Route '%s' → %s (risk=%.2f)", route_id, action, predicted_risk)
    return result


# ═══════════════════════════════════════════════════════════════
#  Flask Endpoint
# ═══════════════════════════════════════════════════════════════

@app.route('/', methods=['GET'])
def index():
    return jsonify({
        "message": "SCDO Sentiment Risk API is running.",
        "endpoint": "/api/sentiment-risk",
        "example": "/api/sentiment-risk?cities=Mumbai,Bhopal,Delhi"
    })

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
