# Supply Chain Disruption Optimization (SCDO)

## Weather Risk Module

This Python script is a standalone microservice using Flask. Since you are using a Node.js server and Firebase, you cannot run Python code directly inside your Node.js backend. Instead, you run this script as a separate service, and your Node.js server makes HTTP GET requests to it.

---

## 🚀 Key Features

### ⚡ High-Performance Architecture
* **Parallel Processing:** Uses `ThreadPoolExecutor` to fetch weather data for multiple cities simultaneously. A route with 15 cities processes in the same time as a single city.
* **Intelligent LRU Caching:** Built-in `WeatherCache` stores results for 30 minutes. This prevents redundant API calls, saves money on API credits, and provides near-instant responses for frequent routes.
* **Production-Ready Logging:** Implements a structured Python logging system with timestamps, replacing standard `print` statements for better monitoring in cloud environments (Google Cloud, AWS, Firebase).

### 🧠 Advanced Logistics Intelligence
* **Composite Risk Scoring:** Unlike basic weather apps, this module uses a weighted formula ($0.6 \times \text{Immediate Risk} + 0.4 \times \text{5-Day Forecast}$) to account for the duration of a supply chain journey.
* **Cargo-Specific Sensitivity:** Includes specialized logic for Temperature Extremes. It automatically flags risks for cold-chain shipments if temperatures drop below -5°C or exceed 35°C.
* **Visibility & Wind Analysis:** Factors in wind speed (m/s) and visibility (meters) to predict potential transit delays or safety hazards for heavy trucking.

### 🛡️ Resiliency & Security
* **Self-Healing API Calls:** Features a graceful retry mechanism that automatically attempts to reconnect up to 3 times during transient network failures or server timeouts.
* **Environment Variable Security:** Designed with security-first principles, loading sensitive API keys from `.env` files or system environment variables to prevent accidental exposure in version control.
* **Cross-Origin Support (CORS):** Pre-configured with Flask-CORS, allowing seamless integration with Node.js, React, or Vue.js frontends.

---

## ⚠️ Known Limitations (Cons)

* **In-Memory Volatility:** If your Cloud Run instance restarts (which they do often), your cache is wiped.
* **Static Risk Weights:** The formula ($0.6 \times \text{max\_24h} + 0.4 \times \text{avg\_5d}$) is hardcoded. Different industries might want different sensitivities.
* **Single-Threaded Server:** While the tasks are parallel, Flask's built-in server (`app.run`) is only meant for development. In production, it can struggle with many simultaneous users.
* **Lack of "Time-on-Route" Logic:** It treats the whole 5-day forecast as a block. It doesn't know that the truck will be in Seattle on Day 1 and Chicago on Day 3.

---

## 💡 Suggested Improvements

| Feature | Why it matters |
|---|---|
| **Gunicorn/Uvicorn** | Use a production WSGI server to handle hundreds of concurrent requests. |
| **Redis Caching** | Move the cache out of RAM and into a Redis database so it survives server restarts. |
| **Dynamic Thresholds** | Add a `cargo_type` parameter to the API (e.g., `?type=electronics` vs `?type=frozen_food`) to change risk sensitivities. |
| **Critical Hazard List** | Instead of just a number, return a warnings array: `["High Winds in Denver", "Extreme Heat in Phoenix"]`. |

---

## 🛠️ How to Deploy and Run This Service

### Option A: Run it locally (for development/testing)
1. Install dependencies: 
   ```bash
   pip install -r requirements.txt
   ```
2. Set your OpenWeatherMap API key as an environment variable:
   * **Windows PowerShell:** `$env:OWM_API_KEY="your_api_key"`
   * **Mac/Linux:** `export OWM_API_KEY="your_api_key"`
3. Start the server: 
   ```bash
   python route_weather_risk.py
   ```
4. The server runs on `http://localhost:8080` by default.

### Option B: Deploy to Google Cloud Run (Recommended for Production / Firebase)
1. Put this script and your `requirements.txt` in a new folder.
2. Deploy as a web service using Google Cloud Run (it natively supports Python and Flask, so you only need to upload the files and set the `OWM_API_KEY` environment variable in the Cloud Run deploy settings).
3. Cloud Run gives you a public URL (e.g., `https://weather-api-xyz.run.app`).

---

## 🌐 How to Call This from Firebase / Node.js

In your Node.js code or Firebase Cloud Function, use `fetch` or `axios` to request the risk analysis from this Python service.

### Example Node.js Code (using axios):

```javascript
const axios = require('axios');

async function getRouteWeatherRisk(citiesArray) {
    try {
        // Convert array to comma-separated string: "Seattle,Denver,Chicago"
        const citiesQuery = citiesArray.join(',');
        
        // Use localhost for dev, or your Cloud Run URL for Prod
        const PYTHON_API_URL = 'http://localhost:8080/api/weather-risk';
        
        const response = await axios.get(`${PYTHON_API_URL}?cities=${citiesQuery}`);
        
        // This is the JSON response from the Python script!
        const result = response.data; 
        
        console.log(`Risk Level: ${result.risk_level}`); // "LOW" | "MODERATE" | "HIGH"
        console.log(`Average Risk Score: ${result.average_risk}`);
        
        return result; 
    } catch (error) {
        console.error("Error communicating with Python Weather API:", error.message);
        throw error;
    }
}

// Example usage:
// getRouteWeatherRisk(['Los Angeles', 'Las Vegas', 'Salt Lake City']);
```
