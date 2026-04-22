"""
weather_risk.py - Weather risk scoring (from route_weather_risk.py).
"""
import logging
from datetime import datetime, timezone
from scdo.clients.weather import WeatherClient

logger = logging.getLogger(__name__)

CARGO_PROFILES = {
    "general":        {"temp_high": 40, "temp_low": -10, "wind_warn": 20, "rain_warn": 50, "weight": 1.0},
    "frozen_food":    {"temp_high": -5, "temp_low": -30, "wind_warn": 15, "rain_warn": 30, "weight": 1.5},
    "perishable":     {"temp_high": 25, "temp_low": 0,   "wind_warn": 15, "rain_warn": 30, "weight": 1.3},
    "live_animals":   {"temp_high": 30, "temp_low": 5,   "wind_warn": 12, "rain_warn": 25, "weight": 1.6},
    "pharmaceuticals":{"temp_high": 25, "temp_low": 2,   "wind_warn": 15, "rain_warn": 30, "weight": 1.4},
    "electronics":    {"temp_high": 45, "temp_low": -15, "wind_warn": 25, "rain_warn": 60, "weight": 0.8},
    "bulk_commodity": {"temp_high": 50, "temp_low": -20, "wind_warn": 30, "rain_warn": 80, "weight": 0.5},
    "hazmat":         {"temp_high": 35, "temp_low": -5,  "wind_warn": 18, "rain_warn": 40, "weight": 1.2},
    "vehicles":       {"temp_high": 50, "temp_low": -20, "wind_warn": 25, "rain_warn": 60, "weight": 0.6},
}


def compute_weather_risk(cities, cargo_type="general", target_date=None):
    """Evaluate weather risk for a list of cities."""
    client = WeatherClient()
    profile = CARGO_PROFILES.get(cargo_type, CARGO_PROFILES["general"])
    city_risks = {}
    overall_max = 0.0

    for city in cities:
        forecast = client.get_forecast(city)
        if not forecast or "list" not in forecast:
            city_risks[city] = {"risk_score": 0.1, "reason": "No forecast data"}
            continue

        scores = []
        for entry in forecast.get("list", [])[:16]:  # ~48 hours
            main = entry.get("main", {})
            wind = entry.get("wind", {})
            rain = entry.get("rain", {})
            temp = main.get("temp", 20)
            wind_speed = wind.get("speed", 0)
            rain_3h = rain.get("3h", 0)

            score = 0.0
            if temp > profile["temp_high"]:
                score += min((temp - profile["temp_high"]) / 20.0, 0.4)
            if temp < profile["temp_low"]:
                score += min((profile["temp_low"] - temp) / 20.0, 0.4)
            if wind_speed > profile["wind_warn"]:
                score += min((wind_speed - profile["wind_warn"]) / 30.0, 0.3)
            if rain_3h > profile["rain_warn"]:
                score += min((rain_3h - profile["rain_warn"]) / 100.0, 0.3)

            scores.append(min(score * profile["weight"], 1.0))

        avg_risk = sum(scores) / len(scores) if scores else 0.1
        city_risks[city] = {"risk_score": round(avg_risk, 4), "samples": len(scores)}
        overall_max = max(overall_max, avg_risk)

    return {
        "weather_risk_score": round(overall_max, 4),
        "city_details": city_risks,
        "cargo_type": cargo_type,
    }
