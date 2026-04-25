"""
sentiment_risk.py - Sentiment risk scoring (from engine.py).
"""
import logging
import pycountry
from scdo.clients.news import NewsClient
from scdo.clients.gemini import GeminiClient

logger = logging.getLogger(__name__)

# --- CONFIGURABLE SOURCE WEIGHTS ---
WEIGHT_NEWS = 0.8
WEIGHT_REDDIT = 0.2

def _city_to_country(city_name):
    """Best-effort city->country mapping."""
    known = {
        "mumbai": "India", "delhi": "India", "chennai": "India",
        "dubai": "UAE", "rotterdam": "Netherlands", "singapore": "Singapore",
        "shanghai": "China", "tokyo": "Japan", "london": "UK",
        "new york": "USA", "los angeles": "USA", "hamburg": "Germany",
        "tehran": "Iran", "kuwait": "Kuwait"
    }
    return known.get(city_name.lower(), "")

def _parse_llm_score(raw_score) -> float:
    """Translates Gemini's text JSON ('HIGH') into our router's math float."""
    if isinstance(raw_score, str):
        score_map = {"LOW": 0.1, "MEDIUM": 0.5, "HIGH": 0.9}
        return score_map.get(raw_score.upper(), 0.1)
    return float(raw_score)

def compute_sentiment_risk(cities):
    """Evaluate sentiment risk with weighted OSINT sources."""
    news_client = NewsClient()
    gemini_client = GeminiClient()

    # 1. Gather all briefs and prep a flat batch dictionary for Gemini
    batch_intelligence = {}
    
    for city in cities:
        country = _city_to_country(city)
        briefs = news_client.fetch_source_briefs(city, country)
        
        # We append '_news' and '_reddit' so Gemini can score them independently
        batch_intelligence[f"{city}_news"] = briefs["news"]
        batch_intelligence[f"{city}_reddit"] = briefs["reddit"]

    # 2. Single batch call to Gemini (CHAT 1/3 FIX: Passing raw strings, no double-filters)
    results = gemini_client.evaluate_risks(batch_intelligence)

    scores = []
    city_details = {}

    # 3. Process results and apply mathematical weights
    for city in cities:
        # Retrieve independent JSON objects from Gemini
        news_info = results.get(f"{city}_news", {"risk_score": 0.1, "primary_hazard": "None"})
        reddit_info = results.get(f"{city}_reddit", {"risk_score": 0.1, "primary_hazard": "None"})
        
        news_score = _parse_llm_score(news_info.get("risk_score", 0.1))
        reddit_score = _parse_llm_score(reddit_info.get("risk_score", 0.1))
        
        # Dynamic Weighting Adjustment:
        # If Reddit is totally silent, don't let it mathematically drag down a HIGH news alert
        has_news = "No significant" not in batch_intelligence[f"{city}_news"]
        has_reddit = "No significant" not in batch_intelligence[f"{city}_reddit"]
        
        if has_news and not has_reddit:
            final_score = news_score * 1.0
        elif has_reddit and not has_news:
            final_score = reddit_score * 1.0
        else:
            # CHAT 5 FIX: Standard 80/20 split applied
            final_score = (news_score * WEIGHT_NEWS) + (reddit_score * WEIGHT_REDDIT)

        scores.append(final_score)
        
        # Aggregate the hazard reporting for the UI/Router
        combined_hazards = [h for h in [news_info.get("primary_hazard"), reddit_info.get("primary_hazard")] if h and h != "None"]
        
        city_details[city] = {
            "risk_score": round(final_score, 4),
            "primary_hazard": " | ".join(combined_hazards) if combined_hazards else "None",
            "intelligence_found": has_news or has_reddit
        }

    return {
        # Overall route sentiment assumes the bottleneck is the highest risk node
        "sentiment_risk_score": round(max(scores) if scores else 0.1, 4),
        "city_details": city_details,
    }