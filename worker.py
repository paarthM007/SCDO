import time
import logging
from google.cloud import firestore
from scdo.db import get_db
from scdo.config import FIRESTORE_COLLECTION
from scdo.simulation.monte_carlo import run_simulation_with_risk

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(name)s] %(message)s")
logger = logging.getLogger("worker")

@firestore.transactional
def claim_job(transaction, doc_ref):
    snapshot = doc_ref.get(transaction=transaction)
    if snapshot.exists and snapshot.get("status") == "pending":
        transaction.update(doc_ref, {
            "status": "processing",
            "started_at": firestore.SERVER_TIMESTAMP
        })
        return True
    return False

def process_job(doc_id, data):
    db = get_db()
    doc_ref = db.collection(FIRESTORE_COLLECTION).document(doc_id)
    try:
        transaction = db.transaction()
        claimed = claim_job(transaction, doc_ref)
        if not claimed:
            logger.info(f"Job {doc_id} already claimed or not pending. Skipping.")
            return

        logger.info(f"Processing job {doc_id}...")
        result = run_simulation_with_risk(
            cities=data.get("cities", []),
            modes=data.get("modes", []),
            cargo_type=data.get("cargo_type", "general"),
            n_iterations=data.get("n_iterations", 50),
            # v3.0 CTR parameters
            quantity=data.get("quantity"),
            product_type=data.get("product_type"),
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
