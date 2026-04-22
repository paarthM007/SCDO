import os
from dotenv import load_dotenv

load_dotenv()

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
PORT = int(os.getenv("PORT", 7860))

# ── Raw Credentials ───────────────────────────────────────────
GOOGLE_APPLICATION_CREDENTIALS_JSON = os.getenv("GOOGLE_APPLICATION_CREDENTIALS_JSON")

# ── Simulation Tuning ─────────────────────────────────────────
MAX_WORKERS = int(os.getenv("MAX_WORKERS", 4))
DEFAULT_MC_ITERATIONS = int(os.getenv("DEFAULT_MC_ITERATIONS", 50))
MAX_MC_ITERATIONS = int(os.getenv("MAX_MC_ITERATIONS", 500))
