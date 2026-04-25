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
    ("HIGHWAY", "general"):      50.0,
    ("HIGHWAY", "perishable"):   120.0,
    ("HIGHWAY", "hazmat"):       200.0,
    ("HIGHWAY", "electronics"):  80.0,
    ("HIGHWAY", "bulk_commodity"): 40.0,
    ("SEA", "general"):          500.0,
    ("SEA", "perishable"):       800.0,   # reefer container surcharge
    ("SEA", "hazmat"):           1200.0,  # IMO class handling
    ("SEA", "electronics"):      600.0,
    ("SEA", "bulk_commodity"):   350.0,
    ("AIR", "general"):          300.0,
    ("AIR", "perishable"):       450.0,
    ("AIR", "hazmat"):           900.0,   # DG cargo handling
    ("AIR", "electronics"):      350.0,
    ("AIR", "bulk_commodity"):   700.0,   # air is bad for bulk
}

# ── Variable Rate V(mode) — cost per unit·km ──────────────────
VARIABLE_RATE = {
    "HIGHWAY": 0.0005,   # $/unit-km  (trucks, moderate)
    "SEA":     0.00008,  # $/unit-km  (ships, cheapest per unit)
    "AIR":     0.003,    # $/unit-km  (planes, most expensive)
    "RAIL":    0.0002,   # $/unit-km  (trains, efficient)
}

# ── Speed Constants s(mode) — km/h ────────────────────────────
SPEED_CONSTANTS = {
    "HIGHWAY": 65.0,
    "SEA":     46.0,
    "AIR":     850.0,
    "RAIL":    45.0,
}

# ── Processing Time P(mode, Q) parameters ─────────────────────
# P(mode, Q) = base_hours + per_unit_hours * Q
# Represents loading/unloading, customs processing etc.
PROCESSING_TIME = {
    "HIGHWAY": {"base_h": 1.0,  "per_unit_h": 0.001},   # fast loading
    "SEA":     {"base_h": 12.0, "per_unit_h": 0.005},    # port operations
    "AIR":     {"base_h": 3.0,  "per_unit_h": 0.002},    # cargo terminal
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

# ── Quantity Thresholds ───────────────────────────────────────
# Below this quantity, certain modes are mathematically inferior.
# (mode → minimum sensible quantity for that mode)
MODE_MIN_QUANTITY = {
    "SEA": 100,    # below 100 units, sea overhead dominates
    "AIR": 1,      # air is viable for any quantity
    "HIGHWAY": 1,  # road is always viable
}

# ── Default Shipment Parameters ───────────────────────────────
DEFAULT_QUANTITY = 100
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
