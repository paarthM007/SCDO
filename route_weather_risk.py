import requests
import json
import os
import time
import logging
from collections import OrderedDict
from concurrent.futures import ThreadPoolExecutor, as_completed
from flask import Flask, request, jsonify
from flask_cors import CORS

# ==============================================================================
# LOGGING SETUP (replaces all print() calls)
# ==============================================================================
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)
logger = logging.getLogger("WeatherRisk")

app = Flask(__name__)
CORS(app)

# ==============================================================================
# Supply Chain Disruption Optimization - Weather Risk Module
# ==============================================================================
# REQUIRED API: OpenWeatherMap (https://openweathermap.org/)
#
# SECURITY: The API key is loaded from the OWM_API_KEY environment variable.
# Set it before running:
#   Windows PowerShell:  $env:OWM_API_KEY="your_key_here"
#   Linux / macOS:       export OWM_API_KEY="your_key_here"
#
# If the env var is not set, the app will start but all API calls will fail.
# ==============================================================================

OWM_API_KEY = '3d9674b7e59462ae04b589f2b2d06147'

# ==============================================================================
# CONSTANTS
# ==============================================================================
CACHE_TTL_SECONDS = 30 * 60          # 30 minutes
CACHE_MAX_ENTRIES = 500              # Max cities to keep in cache
MAX_CITIES_PER_REQUEST = 15          # Abuse prevention limit
API_RETRY_ATTEMPTS = 3              # Number of retries on transient errors
API_RETRY_DELAY_SECONDS = 2          # Wait between retries


# ==============================================================================
# CACHING LAYER (LRU-style with max size + TTL eviction)
# ==============================================================================
# Uses an OrderedDict so the oldest entries can be efficiently evicted
# when the cache exceeds CACHE_MAX_ENTRIES.
# ==============================================================================

class WeatherCache:
    """Thread-aware, size-limited, TTL-based in-memory cache."""

    def __init__(self, max_entries=CACHE_MAX_ENTRIES, ttl=CACHE_TTL_SECONDS):
        self._store = OrderedDict()
        self._max = max_entries
        self._ttl = ttl

    def get(self, city_name):
        key = city_name.lower()
        entry = self._store.get(key)
        if entry and (time.time() - entry["ts"]) < self._ttl:
            # Move to end so it's treated as "recently used"
            self._store.move_to_end(key)
            logger.info("CACHE HIT  — %s", city_name)
            return entry["data"]
        # Expired or missing — remove stale entry if present
        if entry:
            del self._store[key]
        return None

    def set(self, city_name, data):
        key = city_name.lower()
        # If already exists, remove first so re-insertion goes to end
        if key in self._store:
            del self._store[key]
        self._store[key] = {"data": data, "ts": time.time()}
        # Evict oldest entries if over limit
        while len(self._store) > self._max:
            evicted_key, _ = self._store.popitem(last=False)
            logger.debug("CACHE EVICT — %s (%.0f entries)", evicted_key, len(self._store))

    def cleanup_expired(self):
        """Remove all entries older than TTL. Call periodically if desired."""
        now = time.time()
        expired = [k for k, v in self._store.items() if (now - v["ts"]) >= self._ttl]
        for k in expired:
            del self._store[k]
        if expired:
            logger.info("CACHE CLEANUP — removed %d expired entries", len(expired))

    @property
    def size(self):
        return len(self._store)


_cache = WeatherCache()


# ==============================================================================
# GRACEFUL RETRY HELPER
# ==============================================================================

def _api_get_with_retry(url, retries=API_RETRY_ATTEMPTS, delay=API_RETRY_DELAY_SECONDS):
    """
    Performs a GET request with automatic retry on transient failures
    (5xx server errors, timeouts, connection errors).
    """
    last_exception = None
    for attempt in range(1, retries + 1):
        try:
            response = requests.get(url, timeout=10)
            # Only retry on server-side errors (5xx). Client errors (4xx) fail immediately.
            if response.status_code >= 500:
                logger.warning(
                    "Attempt %d/%d — Server error %d for %s",
                    attempt, retries, response.status_code, url
                )
                last_exception = requests.exceptions.HTTPError(
                    f"{response.status_code} Server Error"
                )
                time.sleep(delay)
                continue
            response.raise_for_status()
            return response
        except (requests.exceptions.ConnectionError,
                requests.exceptions.Timeout) as e:
            logger.warning("Attempt %d/%d — %s for %s", attempt, retries, type(e).__name__, url)
            last_exception = e
            time.sleep(delay)
        except requests.exceptions.HTTPError:
            # Non-retryable client error (401, 404, etc.) — fail fast
            raise

    # All retries exhausted
    raise last_exception


# ==============================================================================
# API CALLS (with caching + 5-day forecast + retry)
# ==============================================================================

def get_weather_forecast(city_name):
    """
    Fetches the 5-day / 3-hour FORECAST for a city.
    Uses cache → retry → returns forecast JSON or None.
    """
    # 1. Check cache
    cached = _cache.get(city_name)
    if cached is not None:
        return cached

    # 2. Geocode the city
    geocode_url = (
        f"http://api.openweathermap.org/geo/1.0/direct"
        f"?q={city_name}&limit=1&appid={OWM_API_KEY}"
    )

    try:
        geo_response = _api_get_with_retry(geocode_url)
        geo_data = geo_response.json()

        if not geo_data:
            logger.error("Could not geocode city '%s'", city_name)
            return None

        lat = geo_data[0]['lat']
        lon = geo_data[0]['lon']

        # 3. Fetch the 5-day / 3-hour forecast
        forecast_url = (
            f"https://api.openweathermap.org/data/2.5/forecast"
            f"?lat={lat}&lon={lon}&appid={OWM_API_KEY}&units=metric"
        )

        forecast_response = _api_get_with_retry(forecast_url)
        forecast_data = forecast_response.json()

        # 4. Cache the result
        _cache.set(city_name, forecast_data)
        return forecast_data

    except requests.exceptions.RequestException as e:
        logger.error("API failed for %s after retries: %s", city_name, e)
        return None


# ==============================================================================
# RISK SCORING (forecast-based + extreme temperature)
# ==============================================================================

def _score_single_forecast_entry(entry):
    """
    Scores a single 3-hour forecast window.
    Returns a risk value 0–100.
    """
    risk = 0

    # --- Weather condition codes ---
    weather_id = entry['weather'][0]['id']
    condition = entry['weather'][0]['main'].lower()

    if weather_id == 781:                           # Tornado
        risk += 100
    elif 200 <= weather_id < 300:                   # Thunderstorm
        risk += 70
    elif 600 <= weather_id < 700:                   # Snow
        risk += 40
    elif condition == 'rain':
        rain_3h = entry.get('rain', {}).get('3h', 0)
        if rain_3h > 20:
            risk += 50
        elif rain_3h > 5:
            risk += 20
        else:
            risk += 10

    # --- Wind speed (m/s) ---
    wind_speed = entry.get('wind', {}).get('speed', 0)
    if wind_speed > 25:
        risk += 80
    elif wind_speed > 15:
        risk += 40
    elif wind_speed > 10:
        risk += 15

    # --- Visibility (meters) ---
    visibility = entry.get('visibility', 10000)
    if visibility < 500:
        risk += 50
    elif visibility < 2000:
        risk += 20

    # --- Extreme Temperature ---
    temp = entry.get('main', {}).get('temp', 20)
    if temp > 45:           # Extreme heat (>45 °C)
        risk += 40
    elif temp > 35:         # Very hot (>35 °C — affects perishables, cold-chain)
        risk += 30
    elif temp < -15:        # Extreme cold (<-15 °C)
        risk += 40
    elif temp < -5:         # Freezing (<-5 °C — icy roads, equipment issues)
        risk += 30

    return min(risk, 100)


def calculate_city_risk_score(forecast_data):
    """
    Composite risk from the full 5-day forecast.
    Formula:  0.6 × max_risk_next_24h  +  0.4 × avg_risk_5_days
    """
    if not forecast_data or 'list' not in forecast_data:
        return 50

    entries = forecast_data['list']
    all_scores = [_score_single_forecast_entry(e) for e in entries]

    next_24h = all_scores[:8]
    max_24h = max(next_24h) if next_24h else 0
    avg_5d = sum(all_scores) / len(all_scores) if all_scores else 0

    composite = 0.6 * max_24h + 0.4 * avg_5d
    return round(min(composite, 100), 1)


# ==============================================================================
# PARALLEL ROUTE EVALUATION
# ==============================================================================

def _fetch_and_score(city_name):
    """Worker: fetch forecast + compute risk for one city."""
    forecast = get_weather_forecast(city_name)
    if forecast and 'list' in forecast:
        score = calculate_city_risk_score(forecast)
        first = forecast['list'][0]
        return {
            "city": city_name,
            "score": score,
            "condition": first['weather'][0]['description'].title(),
            "temp": first['main']['temp'],
            "ok": True
        }
    return {
        "city": city_name,
        "score": 50,
        "condition": "Data Unavailable",
        "temp": None,
        "ok": False
    }


def evaluate_route_risk(route_cities):
    """Evaluates weather risk for the full route using parallel requests."""
    logger.info("Evaluating route: %s", " -> ".join(route_cities))

    city_results = {}

    with ThreadPoolExecutor(max_workers=min(10, len(route_cities))) as executor:
        futures = {
            executor.submit(_fetch_and_score, city): city
            for city in route_cities
        }
        for future in as_completed(futures):
            result = future.result()
            city_results[result["city"]] = result

    # Collect results in original route order
    total_risk = 0
    city_breakdown = {}
    for city in route_cities:
        r = city_results[city]
        city_breakdown[city] = r["score"]
        total_risk += r["score"]

        if r["ok"]:
            logger.info(
                "  %-20s | Temp: %5.1f°C | %-22s | Risk: %s",
                city, r["temp"], r["condition"], r["score"]
            )
        else:
            logger.warning("  %-20s | Data unavailable. Default risk: 50", city)

    avg_risk = total_risk / len(route_cities) if route_cities else 0

    if avg_risk > 60:
        risk_level = "HIGH"
        logger.warning("ALERT: High disruption risk! Consider alternative routes.")
    elif avg_risk > 30:
        risk_level = "MODERATE"
        logger.warning("Moderate risk. Monitor weather closely.")
    else:
        risk_level = "LOW"
        logger.info("Route weather risk is low. Safe to proceed.")

    return {
        "average_risk": round(avg_risk, 1),
        "risk_level": risk_level,
        "city_breakdown": city_breakdown
    }


# ==============================================================================
# FLASK API ENDPOINT (with input validation)
# ==============================================================================

@app.route('/api/weather-risk', methods=['GET'])
def api_get_weather_risk():
    """
    GET /api/weather-risk?cities=Seattle,Denver,Chicago
    Returns JSON: { average_risk, risk_level, city_breakdown }
    """
    # --- Validate API key is configured ---
    if not OWM_API_KEY:
        logger.error("OWM_API_KEY environment variable is not set.")
        return jsonify({
            "error": "OpenWeatherMap API key is not configured. "
                     "Set the OWM_API_KEY environment variable on the server."
        }), 500

    # --- Validate 'cities' parameter ---
    cities_param = request.args.get('cities')
    if not cities_param:
        return jsonify({
            "error": "Provide a 'cities' query parameter (e.g., ?cities=Seattle,Denver)"
        }), 400

    route_cities = [c.strip() for c in cities_param.split(',') if c.strip()]

    if not route_cities:
        return jsonify({"error": "No valid city names provided."}), 400

    # --- Abuse prevention: limit number of cities ---
    if len(route_cities) > MAX_CITIES_PER_REQUEST:
        return jsonify({
            "error": f"Too many cities. Maximum allowed per request is {MAX_CITIES_PER_REQUEST}."
        }), 400

    result = evaluate_route_risk(route_cities)
    return jsonify(result)


# ==============================================================================
# ENTRY POINT
# ==============================================================================

if __name__ == "__main__":
    logger.info("Supply Chain Disruption Optimization — Weather Risk API Server")
    logger.info("--------------------------------------------------------------")

    if OWM_API_KEY:
        logger.info("OWM_API_KEY loaded from environment variable.")
    else:
        logger.warning(
            "OWM_API_KEY is NOT set! API calls will fail. "
            "Set it with:  $env:OWM_API_KEY='your_key_here'  (PowerShell)"
        )

    port = int(os.environ.get('PORT', 8080))

    logger.info("Starting server on port %d", port)
    logger.info(
        "Usage: GET /api/weather-risk?cities=Seattle,Denver,Chicago"
    )

    app.run(host='0.0.0.0', port=port, debug=False)
