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
GATEWAY_API_KEY = _get_env("GATEWAY_API_KEY")

# ── Project Config ────────────────────────────────────────────
GOOGLE_CLOUD_PROJECT = _get_env("GOOGLE_CLOUD_PROJECT")
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

# ══════════════════════════════════════════════════════════════
# CTR Tensor Economics — SCDO Logistics Engine v3.0
# Cost-Time-Risk multi-factor routing parameters
# ══════════════════════════════════════════════════════════════

# ── Fixed Overhead F(mode, product_type) in USD ───────────────
# Keys: (mode, product_type) → fixed cost.
# "general" is the fallback for unlisted product types.
FIXED_OVERHEAD = {
    ("HIGHWAY", "general"):      25.0,
    ("HIGHWAY", "perishable"):   60.0,
    ("HIGHWAY", "hazmat"):       100.0,
    ("HIGHWAY", "electronics"):  40.0,
    ("HIGHWAY", "bulk_commodity"): 20.0,
    ("SEA", "general"):          250.0,
    ("SEA", "perishable"):       400.0,   # reefer container surcharge
    ("SEA", "hazmat"):           600.0,  # IMO class handling
    ("SEA", "electronics"):      300.0,
    ("SEA", "bulk_commodity"):   175.0,
    ("AIR", "general"):          150.0,
    ("AIR", "perishable"):       225.0,
    ("AIR", "hazmat"):           450.0,   # DG cargo handling
    ("AIR", "electronics"):      175.0,
    ("AIR", "bulk_commodity"):   350.0,   # air is bad for bulk
}

# ── Variable Rate V(mode) — cost per unit·km ──────────────────
VARIABLE_RATE = {
    "HIGHWAY": 0.00025,  # $/unit-km  (trucks, moderate)
    "SEA":     0.00004,  # $/unit-km  (ships, cheapest per unit)
    "AIR":     0.0015,   # $/unit-km  (planes, most expensive)
    "RAIL":    0.0001,   # $/unit-km  (trains, efficient)
}

# ── Speed Constants s(mode) — km/h ────────────────────────────
SPEED_CONSTANTS = {
    "HIGHWAY": 80.0,
    "SEA":     35.0,     # Adjusted to a realistic ~19 knots
    "AIR":     900.0,
    "RAIL":    60.0,
}

# ── Processing Time P(mode) parameters ─────────────────────
# P(mode) = base_hours
# Represents loading/unloading, customs processing etc.
PROCESSING_TIME = {
    "HIGHWAY": {"base_h": 0.5},   # fast loading
    "SEA":     {"base_h": 6.0},   # port operations
    "AIR":     {"base_h": 1.5},    # cargo terminal
}

# ── Risk Penalty Coefficients ─────────────────────────────────
ALPHA_COST_PENALTY = 0.25    # α: scales insurance/hazard cost in high-risk zones
BETA_DELAY_COEFF   = 0.35    # β: scales transit delay in high-risk zones

# ── Cargo-Mode Incompatibility Rules ──────────────────────────
# If (product_type, mode) is in this set → skip the edge entirely.
CARGO_MODE_BLACKLIST = {
    ("perishable", "SEA"),       # perishable goods can't survive long sea transit
    ("live_animals", "SEA"),     # animal welfare
    ("frozen_food", "SEA"),      # cold chain breaks
    ("pharmaceuticals", "SEA"),  # temperature-sensitive
}

# ── Default Shipment Parameters ───────────────────────────────
DEFAULT_PRODUCT_TYPE = "general"
DEFAULT_OMEGA = 0.5            # balanced cost-time preference
DEFAULT_MAX_BUDGET = float("inf")
DEFAULT_DEADLINE_H = float("inf")

# ── Cargo Specialty Requirements ──────────────────────────────
# Map cargo types to the specific node capabilities required.
CARGO_REQUIREMENTS = {
    'PERISHABLE': 'COLD_CHAIN',
    'HAZMAT':     'HAZMAT_CERT',
    'HIGH_VALUE': 'SECURE_STORAGE',
    'BULK':       'HEAVY_LIFT',
    'STANDARD':   None
}
