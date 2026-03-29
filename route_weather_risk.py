import math
import requests
import json
import os
import time
import logging
from datetime import datetime, timedelta, timezone
from collections import OrderedDict
from concurrent.futures import ThreadPoolExecutor, as_completed
from flask import Flask, request, jsonify
from flask_cors import CORS

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s", datefmt="%Y-%m-%d %H:%M:%S")
logger = logging.getLogger("WeatherRisk")

app = Flask(__name__)
CORS(app)

OWM_API_KEY = '3d9674b7e59462ae04b589f2b2d06147'

CACHE_TTL_SECONDS = 30 * 60
CACHE_MAX_ENTRIES = 500
MAX_CITIES_PER_REQUEST = 15
API_RETRY_ATTEMPTS = 3
API_RETRY_DELAY_SECONDS = 2

# ==============================================================================
# CARGO PROFILES — temp thresholds + sensitivity multipliers
# ==============================================================================
CARGO_PROFILES = {
    "general": {
        "label": "General Cargo",
        "temp_high_warn": 35, "temp_high_extreme": 45,
        "temp_low_warn": -5, "temp_low_extreme": -15,
        "wind_sensitivity": 1.0, "visibility_sensitivity": 1.0,
    },
    "frozen_food": {
        "label": "Frozen Food / Cold Chain",
        "temp_high_warn": 0, "temp_high_extreme": 5,
        "temp_low_warn": -30, "temp_low_extreme": -40,
        "wind_sensitivity": 0.8, "visibility_sensitivity": 0.8,
    },
    "perishable": {
        "label": "Perishable Goods (Fruits, Dairy)",
        "temp_high_warn": 20, "temp_high_extreme": 30,
        "temp_low_warn": 0, "temp_low_extreme": -5,
        "wind_sensitivity": 0.8, "visibility_sensitivity": 0.8,
    },
    "electronics": {
        "label": "Electronics & Semiconductors",
        "temp_high_warn": 40, "temp_high_extreme": 50,
        "temp_low_warn": -10, "temp_low_extreme": -20,
        "wind_sensitivity": 1.0, "visibility_sensitivity": 1.0,
    },
    "pharmaceuticals": {
        "label": "Pharmaceuticals (2-8C controlled)",
        "temp_high_warn": 8, "temp_high_extreme": 15,
        "temp_low_warn": 2, "temp_low_extreme": -5,
        "wind_sensitivity": 0.5, "visibility_sensitivity": 0.5,
    },
    "heavy_machinery": {
        "label": "Heavy Machinery & Industrial",
        "temp_high_warn": 45, "temp_high_extreme": 55,
        "temp_low_warn": -15, "temp_low_extreme": -25,
        "wind_sensitivity": 1.5, "visibility_sensitivity": 1.5,
    },
    "fragile": {
        "label": "Fragile / Glass / Ceramics",
        "temp_high_warn": 35, "temp_high_extreme": 45,
        "temp_low_warn": -5, "temp_low_extreme": -15,
        "wind_sensitivity": 1.8, "visibility_sensitivity": 1.3,
    },
    "chemicals": {
        "label": "Hazardous Chemicals",
        "temp_high_warn": 25, "temp_high_extreme": 35,
        "temp_low_warn": 0, "temp_low_extreme": -10,
        "wind_sensitivity": 1.2, "visibility_sensitivity": 1.4,
    },
}

# ==============================================================================
# CACHE
# ==============================================================================
class WeatherCache:
    def __init__(self, max_entries=CACHE_MAX_ENTRIES, ttl=CACHE_TTL_SECONDS):
        self._store = OrderedDict()
        self._max = max_entries
        self._ttl = ttl

    def get(self, city_name):
        key = city_name.lower()
        entry = self._store.get(key)
        if entry and (time.time() - entry["ts"]) < self._ttl:
            self._store.move_to_end(key)
            logger.info("CACHE HIT  -- %s", city_name)
            return entry["data"]
        if entry:
            del self._store[key]
        return None

    def set(self, city_name, data):
        key = city_name.lower()
        if key in self._store:
            del self._store[key]
        self._store[key] = {"data": data, "ts": time.time()}
        while len(self._store) > self._max:
            self._store.popitem(last=False)

    @property
    def size(self):
        return len(self._store)

_cache = WeatherCache()

# ==============================================================================
# RETRY HELPER
# ==============================================================================
def _api_get_with_retry(url, retries=API_RETRY_ATTEMPTS, delay=API_RETRY_DELAY_SECONDS):
    last_exc = None
    for attempt in range(1, retries + 1):
        try:
            resp = requests.get(url, timeout=10)
            if resp.status_code >= 500:
                last_exc = requests.exceptions.HTTPError(f"{resp.status_code}")
                time.sleep(delay)
                continue
            resp.raise_for_status()
            return resp
        except (requests.exceptions.ConnectionError, requests.exceptions.Timeout) as e:
            last_exc = e
            time.sleep(delay)
        except requests.exceptions.HTTPError:
            raise
    raise last_exc

# ==============================================================================
# FORECAST FETCH
# ==============================================================================
def get_weather_forecast(city_name):
    cached = _cache.get(city_name)
    if cached is not None:
        return cached
    try:
        geo_url = f"http://api.openweathermap.org/geo/1.0/direct?q={city_name}&limit=1&appid={OWM_API_KEY}"
        geo_data = _api_get_with_retry(geo_url).json()
        if not geo_data:
            logger.error("Could not geocode '%s'", city_name)
            return None
        lat, lon = geo_data[0]['lat'], geo_data[0]['lon']
        fc_url = f"https://api.openweathermap.org/data/2.5/forecast?lat={lat}&lon={lon}&appid={OWM_API_KEY}&units=metric"
        fc_data = _api_get_with_retry(fc_url).json()
        _cache.set(city_name, fc_data)
        return fc_data
    except requests.exceptions.RequestException as e:
        logger.error("API failed for %s: %s", city_name, e)
        return None

# ==============================================================================
# CONTINUOUS RISK FUNCTIONS (all return 0.0 - 1.0)
# ==============================================================================

def _continuous_temp_risk(temp, profile):
    """
    Smooth exponential ramp based on distance from safe thresholds.
    Within safe range -> 0.0
    At extreme threshold -> ~0.30
    Far beyond extreme -> approaches 1.0 asymptotically
    """
    risk = 0.0
    if temp > profile['temp_high_warn']:
        excess = temp - profile['temp_high_warn']
        ref = max(profile['temp_high_extreme'] - profile['temp_high_warn'], 1)
        n = excess / ref
        risk = max(risk, 1.0 - math.exp(-0.35 * n ** 1.5))
    if temp < profile['temp_low_warn']:
        excess = profile['temp_low_warn'] - temp
        ref = max(profile['temp_low_warn'] - profile['temp_low_extreme'], 1)
        n = excess / ref
        risk = max(risk, 1.0 - math.exp(-0.35 * n ** 1.5))
    return risk

def _continuous_wind_risk(speed, sensitivity=1.0):
    """Exponential ramp: <5 m/s = 0, 15 m/s ~ 0.36, 25 m/s ~ 0.83"""
    if speed <= 5:
        return 0.0
    raw = 1.0 - math.exp(-((speed - 5) / 15) ** 2)
    return min(raw * sensitivity, 1.0)

def _continuous_vis_risk(visibility, sensitivity=1.0):
    """Exponential ramp: 10000m = 0, 5000m ~ 0.63, 500m ~ 0.97"""
    if visibility >= 10000:
        return 0.0
    raw = 1.0 - math.exp(-((10000 - visibility) / 5000) ** 2)
    return min(raw * sensitivity, 1.0)

def _continuous_rain_risk(rain_3h):
    """Exponential ramp: 1mm ~ 0.02, 5mm ~ 0.12, 20mm ~ 0.79"""
    if rain_3h <= 0:
        return 0.0
    return min(1.0 - math.exp(-(rain_3h / 15) ** 1.5), 0.9)

# ==============================================================================
# SCORE ONE FORECAST ENTRY (returns 0.0-1.0 + hazards)
# ==============================================================================

def _score_single_forecast_entry(entry, profile):
    hazards = []
    weather_id = entry['weather'][0]['id']
    condition = entry['weather'][0]['main'].lower()
    desc = entry['weather'][0]['description'].title()

    # -- Weather condition risk (continuous where possible) --
    if weather_id == 781:
        weather_risk = 1.0
        hazards.append(f"Tornado ({desc})")
    elif 200 <= weather_id < 300:
        severity = (weather_id - 200) / 100
        weather_risk = 0.4 + 0.4 * severity
        hazards.append(f"Thunderstorm ({desc})")
    elif 600 <= weather_id < 700:
        snow_map = {600: 0.2, 601: 0.35, 602: 0.5}
        weather_risk = snow_map.get(weather_id, 0.3)
        hazards.append(f"Snowfall ({desc})")
    elif 500 <= weather_id < 600:
        rain_3h = entry.get('rain', {}).get('3h', 0)
        weather_risk = _continuous_rain_risk(rain_3h) if rain_3h > 0 else {500:0.05,501:0.15,502:0.35,503:0.55,504:0.75,511:0.5}.get(weather_id, 0.15)
        if weather_risk > 0.25:
            hazards.append(f"Heavy Rain ({rain_3h:.1f} mm/3h)")
        elif weather_risk > 0.08:
            hazards.append(f"Rain ({rain_3h:.1f} mm/3h)")
    elif 300 <= weather_id < 400:
        weather_risk = 0.03
    elif 700 <= weather_id < 800:
        weather_risk = 0.02
    elif weather_id == 800:
        weather_risk = 0.0
    elif 801 <= weather_id <= 804:
        weather_risk = 0.005 * (weather_id - 800)
    else:
        weather_risk = 0.0

    # -- Wind (continuous) --
    wind_speed = entry.get('wind', {}).get('speed', 0)
    wind_risk = _continuous_wind_risk(wind_speed, profile['wind_sensitivity'])
    if wind_risk > 0.5:
        hazards.append(f"Extreme Wind ({wind_speed} m/s)")
    elif wind_risk > 0.2:
        hazards.append(f"High Wind ({wind_speed} m/s)")

    # -- Visibility (continuous) --
    visibility = entry.get('visibility', 10000)
    vis_risk = _continuous_vis_risk(visibility, profile['visibility_sensitivity'])
    if vis_risk > 0.5:
        hazards.append(f"Very Low Visibility ({visibility}m)")
    elif vis_risk > 0.15:
        hazards.append(f"Reduced Visibility ({visibility}m)")

    # -- Temperature (continuous, cargo-aware) --
    temp = entry.get('main', {}).get('temp', 20)
    temp_risk = _continuous_temp_risk(temp, profile)
    if temp_risk > 0.3:
        if temp > profile['temp_high_warn']:
            hazards.append(f"High Temp {temp:.1f}C (limit {profile['temp_high_warn']}C for {profile['label']}, severity {temp_risk:.0%})")
        elif temp < profile['temp_low_warn']:
            hazards.append(f"Low Temp {temp:.1f}C (limit {profile['temp_low_warn']}C for {profile['label']}, severity {temp_risk:.0%})")
    elif temp_risk > 0.05:
        if temp > profile['temp_high_warn']:
            hazards.append(f"Temp advisory {temp:.1f}C (warn at {profile['temp_high_warn']}C for {profile['label']})")
        elif temp < profile['temp_low_warn']:
            hazards.append(f"Temp advisory {temp:.1f}C (warn at {profile['temp_low_warn']}C for {profile['label']})")

    # -- Weighted combination --
    # Weather events dominate (40%), temp is secondary (20%)
    final = (0.40 * weather_risk +
             0.25 * wind_risk +
             0.15 * vis_risk +
             0.20 * temp_risk)

    return round(min(final, 1.0), 4), hazards

# ==============================================================================
# CITY-LEVEL RISK
# ==============================================================================

def calculate_city_risk_score(forecast_data, profile, target_date=None):
    if not forecast_data or 'list' not in forecast_data:
        return 0.5, ["Forecast data unavailable"], 0

    entries = forecast_data['list']

    if target_date:
        date_str = target_date.strftime("%Y-%m-%d")
        entries = [e for e in entries if e.get('dt_txt', '').startswith(date_str)]
        if not entries:
            return None, [f"Date {date_str} is outside the 5-day forecast window."], 0

    scores, all_hazards = [], []
    for e in entries:
        s, h = _score_single_forecast_entry(e, profile)
        scores.append(s)
        all_hazards.extend(h)

    if not scores:
        return 0.5, ["No forecast entries"], 0

    # Simple average — no artificial boost from max
    avg_score = sum(scores) / len(scores)

    # De-duplicate hazards
    seen = set()
    unique = []
    for h in all_hazards:
        if h not in seen:
            seen.add(h)
            unique.append(h)

    return round(min(avg_score, 1.0), 4), unique, len(entries)

# ==============================================================================
# ROUTE EVALUATION
# ==============================================================================

def _fetch_and_score(city_name, profile, target_date):
    forecast = get_weather_forecast(city_name)
    if forecast and 'list' in forecast:
        score, hazards, n = calculate_city_risk_score(forecast, profile, target_date)
        if score is None:
            return {"city": city_name, "risk_score": None, "condition": "Date out of range", "temp": None, "hazards": hazards, "forecast_entries_used": 0, "ok": False}

        display = forecast['list'][0]
        if target_date:
            ds = target_date.strftime("%Y-%m-%d")
            day_entries = [e for e in forecast['list'] if e.get('dt_txt','').startswith(ds)]
            if day_entries:
                display = day_entries[len(day_entries)//2]

        return {"city": city_name, "risk_score": score, "condition": display['weather'][0]['description'].title(),
                "temp": display['main']['temp'], "hazards": hazards, "forecast_entries_used": n, "ok": True}

    return {"city": city_name, "risk_score": 0.5, "condition": "Data Unavailable", "temp": None,
            "hazards": ["Weather data could not be fetched"], "forecast_entries_used": 0, "ok": False}


def evaluate_route_risk(route_cities, cargo_type="general", target_date=None):
    profile = CARGO_PROFILES.get(cargo_type, CARGO_PROFILES["general"])
    logger.info("Route: %s | Cargo: %s | Date: %s", " -> ".join(route_cities), profile['label'],
                target_date.strftime("%Y-%m-%d") if target_date else "all")

    city_results = {}
    with ThreadPoolExecutor(max_workers=min(10, len(route_cities))) as executor:
        futures = {executor.submit(_fetch_and_score, c, profile, target_date): c for c in route_cities}
        for f in as_completed(futures):
            r = f.result()
            city_results[r["city"]] = r

    city_details, all_warnings, valid_scores = [], [], []
    for city in route_cities:
        r = city_results[city]
        city_details.append(r)
        if r["ok"] and r["risk_score"] is not None:
            valid_scores.append(r["risk_score"])
            for h in r["hazards"]:
                all_warnings.append(f"{h} in {city}")
            logger.info("  %-20s | %5.1fC | %-22s | Risk: %.4f", city, r["temp"], r["condition"], r["risk_score"])
        else:
            for h in r["hazards"]:
                all_warnings.append(f"{h} ({city})")

    avg_risk = round(sum(valid_scores) / len(valid_scores), 4) if valid_scores else 0.5

    if avg_risk > 0.6:
        risk_level = "HIGH"
    elif avg_risk > 0.3:
        risk_level = "MODERATE"
    else:
        risk_level = "LOW"

    logger.info("Route avg risk: %.4f (%s)", avg_risk, risk_level)

    return {
        "average_risk": avg_risk, "risk_level": risk_level,
        "cargo_type": cargo_type, "cargo_label": profile["label"],
        "target_date": target_date.strftime("%Y-%m-%d") if target_date else None,
        "warnings": all_warnings, "city_details": city_details,
        "city_breakdown": {r["city"]: r["risk_score"] for r in city_details},
    }

# ==============================================================================
# FLASK ENDPOINTS
# ==============================================================================

@app.route('/api/weather-risk', methods=['GET'])
def api_get_weather_risk():
    if not OWM_API_KEY:
        return jsonify({"error": "API key not configured."}), 500

    cities_param = request.args.get('cities')
    if not cities_param:
        return jsonify({"error": "Provide 'cities' param (e.g. ?cities=Seattle,Denver)"}), 400

    route_cities = [c.strip() for c in cities_param.split(',') if c.strip()]
    if not route_cities:
        return jsonify({"error": "No valid city names."}), 400
    if len(route_cities) > MAX_CITIES_PER_REQUEST:
        return jsonify({"error": f"Max {MAX_CITIES_PER_REQUEST} cities allowed."}), 400

    # -- Parse date (timezone-aware UTC) --
    target_date = None
    date_param = request.args.get('date')
    if date_param:
        try:
            target_date = datetime.strptime(date_param.strip(), "%Y-%m-%d").replace(tzinfo=timezone.utc)
        except ValueError:
            return jsonify({"error": f"Invalid date '{date_param}'. Use YYYY-MM-DD."}), 400

        now = datetime.now(timezone.utc)
        if target_date.date() < now.date():
            return jsonify({"error": "Date is in the past."}), 400
        if (target_date - now).days > 5:
            return jsonify({"error": "Date > 5 days ahead. OWM only provides 5-day forecasts."}), 400

    # -- Parse cargo type --
    cargo_type = request.args.get('cargo_type', 'general').strip().lower()
    if cargo_type not in CARGO_PROFILES:
        return jsonify({"error": f"Unknown cargo_type '{cargo_type}'. Valid: {', '.join(sorted(CARGO_PROFILES))}"}), 400

    return jsonify(evaluate_route_risk(route_cities, cargo_type, target_date))


@app.route('/api/cargo-types', methods=['GET'])
def api_list_cargo_types():
    return jsonify({k: {kk: vv for kk, vv in v.items()} for k, v in CARGO_PROFILES.items()})


if __name__ == "__main__":
    logger.info("SCDO Weather Risk API")
    logger.info("Cargo profiles: %s", ", ".join(sorted(CARGO_PROFILES)))
    port = int(os.environ.get('PORT', 8080))
    logger.info("GET /api/weather-risk?cities=Seattle,Denver&date=2026-04-01&cargo_type=frozen_food")
    app.run(host='0.0.0.0', port=port, debug=False)
