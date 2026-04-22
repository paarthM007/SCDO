import json
import logging
from google.cloud import firestore
from google.oauth2 import service_account
from scdo.config import GOOGLE_CLOUD_PROJECT, GOOGLE_APPLICATION_CREDENTIALS_JSON

logger = logging.getLogger("db")

def get_db():
    """Initialize Firestore Client directly from JSON string or default env."""
    if GOOGLE_APPLICATION_CREDENTIALS_JSON:
        try:
            info = json.loads(GOOGLE_APPLICATION_CREDENTIALS_JSON)
            creds = service_account.Credentials.from_service_account_info(info)
            return firestore.Client(project=GOOGLE_CLOUD_PROJECT, credentials=creds)
        except Exception as e:
            logger.error(f"Failed to load credentials from JSON string: {e}")
    
    # Fallback to default behavior
    return firestore.Client(project=GOOGLE_CLOUD_PROJECT)
