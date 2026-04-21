"""
worker.py — SCDO Firestore Worker (Spark Plan Compatible)
=========================================================
Listens to Firestore collection 'sim_jobs' for documents with 
status='pending', runs the DES simulation, and writes results back.

Architecture:
  Flutter → Firestore (direct write) → THIS WORKER → Firestore (update) → Flutter

Usage:
  export GOOGLE_CLOUD_PROJECT=your-project-id
  python3 worker.py
"""

import os
import sys
import time
import signal
import logging
import threading
from datetime import datetime, timezone

from google.cloud import firestore

# ── Ensure sibling modules are importable ─────────────────────
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from DES import run_simulation_with_risk

# ── Logging ───────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
log = logging.getLogger("SCDO-Worker")

# ── Configuration ─────────────────────────────────────────────
PROJECT_ID = os.environ.get("GOOGLE_CLOUD_PROJECT", "")
FIRESTORE_COLLECTION = "sim_jobs"

if not PROJECT_ID:
    log.error("GOOGLE_CLOUD_PROJECT environment variable is not set.")
    sys.exit(1)

db = firestore.Client(project=PROJECT_ID)

# ── Tracking processed jobs in this session ───────────────────
processed_jobs = set()

def process_job(doc_snapshot):
    """
    Process a single Firestore document.
    """
    job_id = doc_snapshot.id
    payload = doc_snapshot.to_dict()
    
    # Validation
    if payload.get("status") != "pending":
        return
    if job_id in processed_jobs:
        return

    log.info("--- Starting Job: %s ---", job_id)
    processed_jobs.add(job_id)

    doc_ref = db.collection(FIRESTORE_COLLECTION).document(job_id)

    # 1. Mark as processing
    try:
        doc_ref.update({
            "status": "processing",
            "updated_at": datetime.now(timezone.utc).isoformat()
        })
    except Exception as e:
        log.error("Failed to update status: %s", e)

    # 2. Run simulation
    try:
        cities = payload.get("cities", [])
        modes = payload.get("modes", [])
        cargo_type = payload.get("cargo_type", "general")
        target_date = payload.get("date")
        n_iterations = payload.get("n_iterations", 50)

        log.info("Running simulation: %s via %s", " -> ".join(cities), ", ".join(modes))

        result = run_simulation_with_risk(
            cities=cities,
            modes=modes,
            cargo_type=cargo_type,
            target_date=target_date,
            n_iterations=n_iterations,
            seed=42,
        )

        # 3. Write results back to Firestore
        doc_ref.update({
            "status": "completed",
            "result": result,
            "updated_at": datetime.now(timezone.utc).isoformat()
        })
        log.info("Job %s completed successfully.", job_id)

    except Exception as e:
        log.error("Simulation failed for job %s: %s", job_id, e, exc_info=True)
        doc_ref.update({
            "status": "failed",
            "error": str(e),
            "updated_at": datetime.now(timezone.utc).isoformat()
        })

def on_snapshot(col_snapshot, changes, read_time):
    """
    Callback for Firestore snapshot listener.
    """
    for change in changes:
        # We only care about new or modified documents that are 'pending'
        if change.type.name in ['ADDED', 'MODIFIED']:
            doc = change.document
            if doc.get("status") == "pending":
                # Process in a separate thread to keep the listener responsive
                threading.Thread(target=process_job, args=(doc,), daemon=True).start()

def main():
    log.info("=" * 70)
    log.info("  SCDO Firestore Worker (No-Card Mode)")
    log.info("  Project:   %s", PROJECT_ID)
    log.info("  Watching:  %s where status=='pending'", FIRESTORE_COLLECTION)
    log.info("=" * 70)

    # Initial query and watch
    query = db.collection(FIRESTORE_COLLECTION).where("status", "==", "pending")
    query_watch = query.on_snapshot(on_snapshot)

    log.info("Listening for new jobs...")

    # Handle graceful shutdown
    def shutdown(signum, frame):
        log.info("Shutting down worker...")
        query_watch.unsubscribe()
        sys.exit(0)

    signal.signal(signal.SIGINT, shutdown)
    signal.signal(signal.SIGTERM, shutdown)

    # Keep main thread alive
    while True:
        time.sleep(1)

if __name__ == "__main__":
    main()
