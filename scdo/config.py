"""
config.py - Centralized configuration from environment variables.
"""
import os
from dotenv import load_dotenv
load_dotenv()

GOOGLE_CLOUD_PROJECT = os.getenv("GOOGLE_CLOUD_PROJECT", "")
FIRESTORE_COLLECTION = os.getenv("FIRESTORE_COLLECTION", "sim_jobs")
FIRESTORE_CACHE_COLLECTION = os.getenv("FIRESTORE_CACHE_COLLECTION", "api_cache")
GOOGLE_MAPS_API_KEY = os.getenv("GOOGLE_MAPS_API_KEY", "")
AIRLABS_API_KEY = os.getenv("AIRLABS_API_KEY", "")
OWM_API_KEY = os.getenv("OWM_API_KEY", "")
NEWS_API_KEY = os.getenv("NEWS_API_KEY", "")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
GATEWAY_API_KEY = os.getenv("GATEWAY_API_KEY", "scdo-dev-key-change-me")
PORT = int(os.getenv("PORT", "7860"))
DEFAULT_MC_ITERATIONS = int(os.getenv("DEFAULT_MC_ITERATIONS", "50"))
MAX_MC_ITERATIONS = int(os.getenv("MAX_MC_ITERATIONS", "500"))
MAX_WORKERS = int(os.getenv("MAX_WORKERS", "4"))
AIRLABS_CACHE_TTL_DAYS = int(os.getenv("AIRLABS_CACHE_TTL_DAYS", "90"))
WEATHER_CACHE_TTL_SECONDS = int(os.getenv("WEATHER_CACHE_TTL_SECONDS", "1800"))
