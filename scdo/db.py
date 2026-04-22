import json
import logging
import firebase_admin
from firebase_admin import credentials, firestore
from scdo.config import GOOGLE_CLOUD_PROJECT, GOOGLE_APPLICATION_CREDENTIALS_JSON

logger = logging.getLogger("db")

_db_instance = None

def get_db():
    global _db_instance
    if _db_instance is not None:
        return _db_instance

    """Initialize Firestore Client using Firebase Admin SDK."""
    if not firebase_admin._apps:
        if GOOGLE_APPLICATION_CREDENTIALS_JSON:
            try:
                info = json.loads(GOOGLE_APPLICATION_CREDENTIALS_JSON)
                creds = credentials.Certificate(info)
                firebase_admin.initialize_app(creds, {'projectId': GOOGLE_CLOUD_PROJECT})
            except Exception as e:
                logger.error(f"Failed to load credentials from JSON string: {e}")
                firebase_admin.initialize_app(options={'projectId': GOOGLE_CLOUD_PROJECT})
        else:
            # Fallback to default behavior
            firebase_admin.initialize_app(options={'projectId': GOOGLE_CLOUD_PROJECT})

    _db_instance = firestore.client()
    return _db_instance
