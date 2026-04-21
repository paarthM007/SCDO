import os
import json
import tempfile
import logging
from dotenv import load_dotenv

load_dotenv()
logger = logging.getLogger("config")

# ── API Keys ──────────────────────────────────────────────────
GOOGLE_MAPS_API_KEY = os.getenv("GOOGLE_MAPS_API_KEY", "")
AIRLABS_API_KEY = os.getenv("AIRLABS_API_KEY", "")
OWM_API_KEY = os.getenv("OWM_API_KEY", "")
NEWS_API_KEY = os.getenv("NEWS_API_KEY", "")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
GATEWAY_API_KEY = os.getenv("GATEWAY_API_KEY", "scdo-dev-key-change-me")

# ── Project Config ────────────────────────────────────────────
GOOGLE_CLOUD_PROJECT = os.getenv("GOOGLE_CLOUD_PROJECT", "scdodeployment-32cba")
FIRESTORE_COLLECTION = os.getenv("FIRESTORE_COLLECTION", "sim_jobs")
FIRESTORE_CACHE_COLLECTION = os.getenv("FIRESTORE_CACHE_COLLECTION", "api_cache")
PORT = int(os.getenv("PORT", 7860))

# ── Simulation Tuning ─────────────────────────────────────────
MAX_WORKERS = int(os.getenv("MAX_WORKERS", 4))
DEFAULT_MC_ITERATIONS = int(os.getenv("DEFAULT_MC_ITERATIONS", 50))
MAX_MC_ITERATIONS = int(os.getenv("MAX_MC_ITERATIONS", 500))

# ── Firebase Credential Injection ─────────────────────────────
# If the user provided the JSON string directly in an env var (e.g. on HuggingFace),
# we write it to a temp file so the Google libraries can find it.
_creds_json = os.getenv("GOOGLE_APPLICATION_CREDENTIALS_JSON")
if _creds_json and not os.getenv("GOOGLE_APPLICATION_CREDENTIALS"):
    try:
        # Validate JSON
        json.loads(_creds_json)
        
        # Create persistent temp file for the lifetime of the process
        fd, path = tempfile.mkstemp(suffix=".json")
        with os.fdopen(fd, 'w') as f:
            f.write(_creds_json)
        
        os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = path
        logger.info(f"Injected Firebase credentials from ENV to {path}")
    except Exception as e:
        logger.error(f"Failed to inject Firebase credentials from ENV: {e}")
