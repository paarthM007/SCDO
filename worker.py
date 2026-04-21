"""
worker.py - Firestore listener + ProcessPoolExecutor.
Watches sim_jobs for pending jobs, processes them in separate processes.
Handles both simulation and route_finding job types.
"""
import os
import logging
import threading
import traceback
from datetime import datetime, timezone
from concurrent.futures import ProcessPoolExecutor
from google.cloud import firestore

from scdo.config import (
    GOOGLE_CLOUD_PROJECT, FIRESTORE_COLLECTION, MAX_WORKERS
)

logging.basicConfig(level=logging.INFO, format="%(asctime)s [worker] %(message)s")
logger = logging.getLogger("worker")

# Process pool for CPU-bound simulation jobs
executor = ProcessPoolExecutor(max_workers=MAX_WORKERS)


def _get_db():
    return firestore.Client(project=GOOGLE_CLOUD_PROJECT)


def _process_simulation(data):
    """Run in a separate process via ProcessPoolExecutor."""
    from scdo.simulation.monte_carlo import run_simulation_with_risk
    return run_simulation_with_risk(
        cities=data["cities"],
        modes=data["modes"],
        cargo_type=data.get("cargo_type", "general"),
        target_date=data.get("target_date"),
        n_iterations=data.get("n_iterations", 50),
        seed=data.get("seed", 42),
        importance_boost=data.get("importance_boost", 1.0),
        facility_configs=data.get("facility_configs"),
    )


def _process_route_finding(data):
    """Run in a separate process via ProcessPoolExecutor."""
    from scdo.routing.router import find_alternate_route
    return find_alternate_route(
        origin=data["start"],
        destination=data["end"],
        blocked_nodes=data.get("blocked", []),
        cargo_type=data.get("cargo_type", "general"),
        mode_pref=data.get("mode"),
    )


def _handle_job(doc_snapshot):
    """Process a single job document."""
    job_id = doc_snapshot.id
    data = doc_snapshot.to_dict()

    if data.get("status") != "pending":
        return

    db = _get_db()
    doc_ref = db.collection(FIRESTORE_COLLECTION).document(job_id)

    logger.info(f"Processing job {job_id} (type={data.get('type', 'simulation')})")

    # Mark as processing
    doc_ref.update({
        "status": "processing",
        "updated_at": datetime.now(timezone.utc).isoformat(),
    })

    job_type = data.get("type", "simulation")

    try:
        if job_type == "route_finding":
            # Route finding - extract from request or top-level
            req = data.get("request", data)
            future = executor.submit(_process_route_finding, req)
        else:
            # Simulation (default)
            req = data.get("request", data)
            future = executor.submit(_process_simulation, req)

        result = future.result(timeout=300)  # 5 min timeout

        doc_ref.update({
            "status": "completed",
            "result": result,
            "updated_at": datetime.now(timezone.utc).isoformat(),
        })
        logger.info(f"Job {job_id} completed successfully")

    except Exception as e:
        logger.error(f"Job {job_id} failed: {e}")
        doc_ref.update({
            "status": "failed",
            "error": str(e),
            "updated_at": datetime.now(timezone.utc).isoformat(),
        })


def _on_snapshot(col_snapshot, changes, read_time):
    """Firestore on_snapshot callback."""
    for change in changes:
        if change.type.name in ('ADDED', 'MODIFIED'):
            try:
                _handle_job(change.document)
            except Exception as e:
                logger.error(f"Error handling snapshot: {e}")
                traceback.print_exc()


def start_listener():
    """Start listening for pending jobs. Blocks until interrupted."""
    db = _get_db()
    query = db.collection(FIRESTORE_COLLECTION).where("status", "==", "pending")
    query.on_snapshot(_on_snapshot)
    logger.info(f"Worker listening on '{FIRESTORE_COLLECTION}' (max_workers={MAX_WORKERS})")
    threading.Event().wait()  # Block forever


if __name__ == "__main__":
    start_listener()
