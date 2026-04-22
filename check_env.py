import os
from dotenv import load_dotenv

load_dotenv()

KEYS_TO_CHECK = [
    "GOOGLE_APPLICATION_CREDENTIALS_JSON",
    "GEMINI_API_KEY",
    "OWM_API_KEY",
    "NEWS_API_KEY",
    "GOOGLE_CLOUD_PROJECT"
]

print("=== SCDO ENVIRONMENT DIAGNOSTICS ===")
for key in KEYS_TO_CHECK:
    val = os.getenv(key)
    if val:
        print(f"✅ {key}: FOUND (Length: {len(val)} characters)")
    else:
        print(f"❌ {key}: NOT FOUND or EMPTY")

print("====================================")
