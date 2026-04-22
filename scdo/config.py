import os
import json
import tempfile
import logging
from dotenv import load_dotenv

load_dotenv()
logger = logging.getLogger("config")

def _get_env(key, default=""):
    val = os.getenv(key, default)
    return val.strip() if isinstance(val, str) else val

# ── API Keys ──────────────────────────────────────────────────
GOOGLE_MAPS_API_KEY = _get_env("GOOGLE_MAPS_API_KEY")
AIRLABS_API_KEY = _get_env("AIRLABS_API_KEY")
OWM_API_KEY = _get_env("OWM_API_KEY")
NEWS_API_KEY = _get_env("NEWS_API_KEY")
GEMINI_API_KEY = _get_env("GEMINI_API_KEY")
GATEWAY_API_KEY = _get_env("GATEWAY_API_KEY", "scdo-dev-key-change-me")

# ── Project Config ────────────────────────────────────────────
GOOGLE_CLOUD_PROJECT = _get_env("GOOGLE_CLOUD_PROJECT", "scdodeployment-32cba")
FIRESTORE_COLLECTION = _get_env("FIRESTORE_COLLECTION", "sim_jobs")
FIRESTORE_CACHE_COLLECTION = _get_env("FIRESTORE_CACHE_COLLECTION", "api_cache")
PORT = int(_get_env("PORT", 7860))

# ── Cache TTL Settings (Missing variables) ────────────────────
WEATHER_CACHE_TTL_SECONDS = 3600  # 1 hour
SENTIMENT_CACHE_TTL_SECONDS = 7200  # 2 hours
AIRLABS_CACHE_TTL_DAYS = 7  # 7 days

# ── Raw Credentials ───────────────────────────────────────────
GOOGLE_APPLICATION_CREDENTIALS_JSON = os.getenv("GOOGLE_APPLICATION_CREDENTIALS_JSON")
if GOOGLE_APPLICATION_CREDENTIALS_JSON:
    GOOGLE_APPLICATION_CREDENTIALS_JSON = GOOGLE_APPLICATION_CREDENTIALS_JSON.strip()

# ── Simulation Tuning ─────────────────────────────────────────
MAX_WORKERS = int(_get_env("MAX_WORKERS", 4))
DEFAULT_MC_ITERATIONS = int(_get_env("DEFAULT_MC_ITERATIONS", 50))
MAX_MC_ITERATIONS = int(_get_env("MAX_MC_ITERATIONS", 500))
