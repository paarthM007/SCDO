import os
import time
import json
import logging
from google.cloud import firestore
from google.oauth2 import service_account
from scdo.db import get_db
from scdo.config import FIRESTORE_COLLECTION
from scdo.simulation.monte_carlo import run_simulation_with_risk

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(name)s] %(message)s")
logger = logging.getLogger("worker")

def process_job(doc_id, data):
    db = get_db()
    doc_ref = db.collection(FIRESTORE_COLLECTION).document(doc_id)
    try:
        logger.info(f"Processing job {doc_id}...")
        doc_ref.update({"status": "processing", "started_at": firestore.SERVER_TIMESTAMP})
        result = run_simulation_with_risk(
            cities=data.get("cities", []),
            modes=data.get("modes", []),
            cargo_type=data.get("cargo_type", "general"),
            n_iterations=data.get("n_iterations", 50)
        )
        doc_ref.update({"status": "completed", "result": result, "completed_at": firestore.SERVER_TIMESTAMP})
        logger.info(f"Job {doc_id} completed successfully.")
    except Exception as e:
        logger.error(f"Job {doc_id} failed: {e}")
        doc_ref.update({"status": "failed", "error": str(e), "failed_at": firestore.SERVER_TIMESTAMP})

def start_listener():
    db = get_db()
    logger.info(f"Worker listening on '{FIRESTORE_COLLECTION}'...")
    def on_snapshot(col_snapshot, changes, read_time):
        for change in changes:
            if change.type.name == 'ADDED':
                data = change.document.to_dict()
                if data.get("status") == "pending":
                    process_job(change.document.id, data)
    
    # Use a query to listen for pending jobs
    col_query = db.collection(FIRESTORE_COLLECTION).where("status", "==", "pending")
    col_query.on_snapshot(on_snapshot)
    
    while True:
        time.sleep(1)

if __name__ == "__main__":
    start_listener()
