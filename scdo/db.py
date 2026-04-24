import json
import logging
import firebase_admin
from firebase_admin import credentials, firestore
from scdo.config import GOOGLE_CLOUD_PROJECT, GOOGLE_APPLICATION_CREDENTIALS_JSON
import os
logger = logging.getLogger("db")

_db_instance = None

def get_db():
    global _db_instance
    if _db_instance is not None:
        return _db_instance

    """Initialize Firestore Client using Firebase Admin SDK."""
    if not firebase_admin._apps:
        # Check for File Path first (Much more reliable on Windows)
        service_account_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
        if service_account_path and os.path.exists(service_account_path):
            try:
                creds = credentials.Certificate(service_account_path)
                firebase_admin.initialize_app(creds, {'projectId': GOOGLE_CLOUD_PROJECT})
                logger.info(f"Loaded credentials from file: {service_account_path}")
            except Exception as e:
                logger.error(f"Failed to load credentials from file {service_account_path}: {e}")
        
        # Fallback to JSON string (if provided)
        elif GOOGLE_APPLICATION_CREDENTIALS_JSON:
            try:
                # Handle common .env escaping issues
                json_str = GOOGLE_APPLICATION_CREDENTIALS_JSON.replace('\\n', '\n')
                info = json.loads(json_str, strict=False)
                creds = credentials.Certificate(info)
                firebase_admin.initialize_app(creds, {'projectId': GOOGLE_CLOUD_PROJECT})
                logger.info("Loaded credentials from JSON string")
            except Exception as e:
                logger.error(f"Failed to load credentials from JSON string: {e}")
                firebase_admin.initialize_app(options={'projectId': GOOGLE_CLOUD_PROJECT})
        else:
            # Fallback to ADC
            firebase_admin.initialize_app(options={'projectId': GOOGLE_CLOUD_PROJECT})

    _db_instance = firestore.client()
    return _db_instance
