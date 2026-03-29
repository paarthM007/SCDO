# Supply Chain Disruption Optimization (SCDO)

## Weather Risk Module

This Python script is a standalone microservice using Flask. Since you are using a Node.js server and Firebase, you cannot run Python code directly inside your Node.js backend. Instead, you run this script as a separate service, and your Node.js server makes HTTP GET requests to it.

---

## 🚀 Key Features

### ⚡ High-Performance Architecture
* **Parallel Processing:** Uses `ThreadPoolExecutor` to fetch weather data for multiple cities simultaneously. A route with 15 cities processes in the same time as a single city.
* **Intelligent LRU Caching:** Built-in `WeatherCache` stores results for 30 minutes. This prevents redundant API calls, saves money on API credits, and provides near-instant responses for frequent routes.
* **Production-Ready Logging:** Implements a structured Python logging system with timestamps, replacing standard `print` statements for better monitoring in cloud environments.
* **Production WSGI Server:** Includes `gunicorn` in requirements and a `Procfile` for deploying behind a proper multi-worker server (handles hundreds of concurrent requests).

### 🧠 Advanced Logistics Intelligence
* **Normalized Risk Score (0.0–1.0):** All risk scores are on a 0-to-1 scale. A normal route on a clear day scores **~0.005–0.01**, moderate weather **~0.05–0.15**, and severe storms **0.5+**.
* **Continuous Scoring Functions:** Instead of flat penalties, all risk components (temperature, wind, visibility, rain) use smooth exponential ramp functions (`1 - e^(-x^1.5)`) so that small deviations produce proportionally small scores while severe conditions approach 1.0 asymptotically.
* **Weighted Component Model:** Final risk = `0.40 × weather + 0.25 × wind + 0.15 × visibility + 0.20 × temperature`. This ensures weather events dominate while temperature is a meaningful but secondary factor.
* **Date-Specific Risk:** Users provide a target delivery date (`?date=2026-04-01`) and the system calculates weather risk specifically for that date, instead of a generic 5-day average.
* **Timezone-Aware:** All date handling uses `datetime.now(timezone.utc)` (not the deprecated `datetime.utcnow()`).
* **8 Cargo-Type Profiles:** The `cargo_type` parameter adjusts temperature thresholds and wind/visibility sensitivity multipliers:
  | `cargo_type` | Label | Temp High Warn | Temp Low Warn |
  |---|---|---|---|
  | `general` | General Cargo | 35°C | -5°C |
  | `frozen_food` | Frozen Food / Cold Chain | 0°C | -30°C |
  | `perishable` | Perishable Goods | 20°C | 0°C |
  | `electronics` | Electronics & Semiconductors | 40°C | -10°C |
  | `pharmaceuticals` | Pharmaceuticals (2–8°C) | 8°C | 2°C |
  | `heavy_machinery` | Heavy Machinery & Industrial | 45°C | -15°C |
  | `fragile` | Fragile / Glass / Ceramics | 35°C | -5°C |
  | `chemicals` | Hazardous Chemicals | 25°C | 0°C |
* **Critical Hazard Warnings:** Every response includes a `warnings` array with severity percentages like `"High Temp 15.0C (limit 0C for Frozen Food, severity 84%)"`.
* **Per-City Detail Breakdown:** Each city includes `risk_score`, `temp`, `condition`, `hazards`, and `forecast_entries_used`.

### 🛡️ Resiliency & Security
* **Self-Healing API Calls:** Features a graceful retry mechanism that automatically attempts to reconnect up to 3 times during transient network failures or server timeouts.
* **Cross-Origin Support (CORS):** Pre-configured with Flask-CORS, allowing seamless integration with Node.js, React, or Vue.js frontends.
* **Input Validation:** Validates date format (YYYY-MM-DD), prevents past dates, verifies cargo type exists, and limits cities per request to 15.

---

## 📡 API Reference

### `GET /api/weather-risk`

Calculate weather risk for a transport route.

| Parameter | Required | Example | Description |
|---|---|---|---|
| `cities` | ✅ Yes | `Seattle,Denver,Chicago` | Comma-separated list of cities along the route |
| `date` | ❌ No | `2026-04-01` | Target delivery date (YYYY-MM-DD, within 5 days). If omitted, scores all available forecast data. |
| `cargo_type` | ❌ No | `frozen_food` | Type of cargo. Default: `general`. See table above for all options. |

**Example Request:**
```
GET /api/weather-risk?cities=Seattle,Denver,Chicago&date=2026-04-01&cargo_type=pharmaceuticals
```

**Example Response:**
```json
{
  "average_risk": 0.245,
  "risk_level": "LOW",
  "cargo_type": "pharmaceuticals",
  "cargo_label": "Pharmaceuticals (2–8 °C controlled)",
  "target_date": "2026-04-01",
  "warnings": [
    "High Temp (12.5°C — warning for Pharmaceuticals (2–8 °C controlled): 8°C) in Denver"
  ],
  "city_details": [
    {
      "city": "Seattle",
      "risk_score": 0.12,
      "condition": "Overcast Clouds",
      "temp": 8.3,
      "hazards": [],
      "forecast_entries_used": 8,
      "ok": true
    }
  ],
  "city_breakdown": {
    "Seattle": 0.12,
    "Denver": 0.35,
    "Chicago": 0.265
  }
}
```

### `GET /api/cargo-types`

Returns all supported cargo type profiles with their temperature thresholds and sensitivity multipliers.

---

## ⚠️ Remaining Limitations

* **In-Memory Volatility:** If your Cloud Run instance restarts, the cache is wiped. Consider adding Redis for persistent caching (requires infrastructure setup).
* **API Key Hardcoded:** The OWM API key is currently hardcoded in the source file. For production, move it to an environment variable (`os.environ.get('OWM_API_KEY')`) and use a `.env` file with `python-dotenv`.
* **5-Day Forecast Limit:** OpenWeatherMap free tier only provides 5-day forecasts. If your supply chain journey is longer, the `date` parameter will reject dates beyond that window.

---

## ✅ Issues Fixed (from previous version)

| Previous Issue | Status | How |
|---|---|---|
| **Static Risk Weights** (hardcoded 0.6 × immediate + 0.4 × forecast) | ✅ Fixed | Replaced with user-specified `date` parameter. Risk is calculated for the exact delivery date. |
| **Flat penalty scoring** (same 40 points whether 6°C or 35°C above threshold) | ✅ Fixed | Continuous exponential ramp: penalty scales proportionally with deviation (`1 - e^(-0.35 × n^1.5)`). |
| **Inflated risk scores** (normal route gave 0.4) | ✅ Fixed | Weighted component averaging + continuous functions. General cargo on a clear day now scores ~0.007. |
| **No Cargo Sensitivity** (one-size-fits-all) | ✅ Fixed | 8 cargo profiles with custom temp thresholds, wind/visibility multipliers. |
| **No Warnings / Hazard List** | ✅ Fixed | `warnings` array + per-city `hazards` with severity percentages. |
| **Single-Threaded Server** | ✅ Fixed | `gunicorn` + `Procfile` for production. |
| **Risk score 0–100** | ✅ Fixed | Normalized to 0.0–1.0. |
| **UTC vs Local Time** (deprecated `datetime.utcnow()`) | ✅ Fixed | Uses `datetime.now(timezone.utc)` with timezone-aware objects. |

---

## 🔧 What You Need To Do Manually

| Task | How |
|---|---|
| **Move API key to env variable** | Replace the hardcoded key in `route_weather_risk.py` line 29 with `os.environ.get('OWM_API_KEY', '')`. Then set `$env:OWM_API_KEY="your_key"` before running. |
| **Rotate the leaked API key** | The key `3d9674b7...` was committed to Git history. Go to [OpenWeatherMap](https://home.openweathermap.org/api_keys), generate a new key, and delete the old one. |
| **Purge key from Git history** | Run `git filter-branch` or use [BFG Repo-Cleaner](https://rtyley.github.io/bfg-repo-cleaner/) to remove the key from all past commits. |
| **Set up Redis caching** | Install Redis, add `redis` to `requirements.txt`, and replace `WeatherCache` with a Redis-backed implementation so the cache survives server restarts. |
| **Install new dependencies** | Run `pip install -r requirements.txt` to get `gunicorn` and `python-dotenv`. |

---

## 🛠️ How to Deploy and Run This Service

### Option A: Run locally (development/testing)
1. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
2. Start the server:
   ```bash
   python route_weather_risk.py
   ```
3. The server runs on `http://localhost:8080` by default.
4. Test it:
   ```
   http://localhost:8080/api/weather-risk?cities=Seattle,Denver,Chicago&date=2026-04-01&cargo_type=frozen_food
   ```

### Option B: Deploy to Google Cloud Run (Production)
1. Put all files (`route_weather_risk.py`, `requirements.txt`, `Procfile`) in a folder.
2. Deploy to Cloud Run. It will use the `Procfile` to run Gunicorn with 4 workers.
3. Set the `OWM_API_KEY` environment variable in the Cloud Run deploy settings.
4. Cloud Run gives you a public URL (e.g., `https://weather-api-xyz.run.app`).

---

## 🌐 How to Call This from Firebase / Node.js

```javascript
const axios = require('axios');

async function getRouteWeatherRisk(citiesArray, deliveryDate, cargoType = 'general') {
    try {
        const citiesQuery = citiesArray.join(',');
        const PYTHON_API_URL = 'http://localhost:8080/api/weather-risk';

        let url = `${PYTHON_API_URL}?cities=${citiesQuery}&cargo_type=${cargoType}`;
        if (deliveryDate) {
            url += `&date=${deliveryDate}`;  // e.g. "2026-04-01"
        }

        const response = await axios.get(url);
        const result = response.data;

        console.log(`Risk Level: ${result.risk_level}`);       // "LOW" | "MODERATE" | "HIGH"
        console.log(`Average Risk: ${result.average_risk}`);   // 0.0 – 1.0
        console.log(`Warnings: ${result.warnings.length}`);    // number of hazard warnings

        // Per-city details
        result.city_details.forEach(city => {
            console.log(`  ${city.city}: ${city.risk_score} — ${city.condition}`);
            city.hazards.forEach(h => console.log(`    ⚠ ${h}`));
        });

        return result;
    } catch (error) {
        console.error("Error:", error.message);
        throw error;
    }
}

// Example: Check weather risk for frozen food delivery arriving April 1st
// getRouteWeatherRisk(['Los Angeles', 'Las Vegas', 'Salt Lake City'], '2026-04-01', 'frozen_food');
```
