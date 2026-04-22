"""
sentiment_risk.py - Sentiment risk scoring (from engine.py).
"""
import logging
import pycountry
from scdo.clients.news import NewsClient
from scdo.clients.gemini import GeminiClient

logger = logging.getLogger(__name__)

SUPPLY_CHAIN_KEYWORDS = [
    "supply chain", "logistics", "shipping", "freight", "cargo",
    "port", "customs", "tariff", "embargo", "sanctions", "blockade",
    "strike", "disruption", "shortage", "delay", "backlog",
    "hurricane", "typhoon", "earthquake", "flood", "tsunami",
    "war", "conflict", "military", "coup", "protest", "riot",
]


def _city_to_country(city_name):
    """Best-effort city->country mapping."""
    known = {
        "mumbai": "India", "delhi": "India", "chennai": "India",
        "dubai": "UAE", "rotterdam": "Netherlands", "singapore": "Singapore",
        "shanghai": "China", "tokyo": "Japan", "london": "UK",
        "new york": "USA", "los angeles": "USA", "hamburg": "Germany",
    }
    return known.get(city_name.lower(), "")


def _filter_relevant(headlines):
    """Keep only headlines containing supply-chain keywords."""
    kw_lower = SUPPLY_CHAIN_KEYWORDS
    return [h for h in headlines if any(k in h.lower() for k in kw_lower)]


def compute_sentiment_risk(cities):
    """Evaluate sentiment risk for a list of cities using news + Gemini."""
    news_client = NewsClient()
    gemini_client = GeminiClient()

    city_headlines = {}
    for city in cities:
        country = _city_to_country(city)
        raw = news_client.fetch_headlines(city, country)
        filtered = _filter_relevant(raw)
        city_headlines[city] = filtered if filtered else ["No relevant headlines found"]

    results = gemini_client.evaluate_risks(city_headlines)

    scores = []
    city_details = {}
    for city in cities:
        info = results.get(city, {"risk_score": 0.05, "primary_hazard": "None"})
        score = float(info.get("risk_score", 0.05))
        scores.append(score)
        city_details[city] = {
            "risk_score": round(score, 4),
            "primary_hazard": info.get("primary_hazard", "None"),
            "headlines_analyzed": len(city_headlines.get(city, [])),
        }

    return {
        "sentiment_risk_score": round(max(scores) if scores else 0.05, 4),
        "city_details": city_details,
    }
