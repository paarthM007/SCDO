"""
worker.py — SCDO Pub/Sub Worker
=================================
Subscribes to Google Cloud Pub/Sub topic 'calculate-topic',
runs the DES simulation with combined risk, and writes results
to Firestore for the Flutter frontend to pick up via listener.

Architecture:
  Flutter → index.js (orchestrator) → Pub/Sub → THIS WORKER → Firestore → Flutter

Usage:
  # Set your GCP project
  export GOOGLE_CLOUD_PROJECT=your-project-id

  # Run the worker
  python3 worker.py

  # Or with explicit subscription:
  python3 worker.py --subscription calculate-topic-sub
"""

import os
import sys
import json
import signal
import logging
import argparse
from datetime import datetime, timezone

from google.cloud import pubsub_v1
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
SUBSCRIPTION_NAME = os.environ.get("PUBSUB_SUBSCRIPTION", "calculate-topic-sub")
FIRESTORE_COLLECTION = "sim_jobs"


# ==============================================================================
# FIRESTORE HELPERS
# ==============================================================================
def _get_firestore_client():
    """Lazy-init Firestore client."""
    return firestore.Client(project=PROJECT_ID)


def _update_job_status(db, job_id: str, status: str, result=None, error=None):
    """
    Update the Firestore document for this job.
    Flutter's snapshot listener will fire on each update.
    """
    doc_ref = db.collection(FIRESTORE_COLLECTION).document(job_id)
    update_data = {
        "status": status,
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }
    if result is not None:
        update_data["result"] = result
    if error is not None:
        update_data["error"] = error

    doc_ref.update(update_data)
    log.info("Firestore updated: %s -> status=%s", job_id, status)


# ==============================================================================
# MESSAGE HANDLER
# ==============================================================================
def handle_message(message):
    """
    Process a single Pub/Sub message:
      1. Parse the JSON payload
      2. Update Firestore status → "processing"
      3. Run simulation with combined risk
      4. Update Firestore status → "completed" with results
      5. Acknowledge the message
    """
    try:
        payload = json.loads(message.data.decode("utf-8"))
        log.info("Received message: %s", json.dumps(payload, indent=2))
    except (json.JSONDecodeError, UnicodeDecodeError) as e:
        log.error("Failed to parse message: %s", e)
        message.ack()  # Don't retry malformed messages
        return

    job_id = payload.get("jobId")
    if not job_id:
        log.error("Message missing 'jobId', skipping.")
        message.ack()
        return

    db = _get_firestore_client()

    # ── Mark as processing ────────────────────────────────────
    try:
        _update_job_status(db, job_id, "processing")
    except Exception as e:
        log.error("Failed to update Firestore (processing): %s", e)
        # Continue anyway — simulation is more important than status update

    # ── Run simulation ────────────────────────────────────────
    try:
        cities = payload.get("cities", [])
        modes = payload.get("modes", [])
        cargo_type = payload.get("cargo_type", "general")
        target_date = payload.get("date")
        n_iterations = payload.get("n_iterations", 50)

        log.info("Starting simulation for job %s: %s via %s",
                 job_id, " → ".join(cities), ", ".join(modes))

        result = run_simulation_with_risk(
            cities=cities,
            modes=modes,
            cargo_type=cargo_type,
            target_date=target_date,
            n_iterations=n_iterations,
            seed=42,
        )

        # ── Write results to Firestore ────────────────────────
        _update_job_status(db, job_id, "completed", result=result)
        log.info("Job %s completed successfully.", job_id)

    except Exception as e:
        log.error("Simulation failed for job %s: %s", job_id, e, exc_info=True)
        _update_job_status(db, job_id, "failed", error=str(e))

    # ── Always acknowledge ────────────────────────────────────
    message.ack()
    log.info("Message acknowledged for job %s", job_id)


# ==============================================================================
# MAIN — Pull Subscriber Loop
# ==============================================================================
def main():
    parser = argparse.ArgumentParser(description="SCDO Pub/Sub Worker")
    parser.add_argument("--subscription", default=SUBSCRIPTION_NAME,
                        help="Pub/Sub subscription name")
    parser.add_argument("--project", default=PROJECT_ID,
                        help="GCP Project ID")
    args = parser.parse_args()

    project = args.project or PROJECT_ID
    subscription = args.subscription

    if not project:
        log.error("Set GOOGLE_CLOUD_PROJECT env var or pass --project")
        sys.exit(1)

    subscription_path = f"projects/{project}/subscriptions/{subscription}"

    log.info("=" * 70)
    log.info("  SCDO Pub/Sub Worker")
    log.info("  Project:      %s", project)
    log.info("  Subscription: %s", subscription_path)
    log.info("  Firestore:    %s/<jobId>", FIRESTORE_COLLECTION)
    log.info("=" * 70)

    subscriber = pubsub_v1.SubscriberClient()

    # Graceful shutdown on SIGINT/SIGTERM
    streaming_pull = subscriber.subscribe(subscription_path, callback=handle_message)
    log.info("Listening for messages on %s ...", subscription_path)

    def shutdown(signum, frame):
        log.info("Shutting down worker (signal %s)...", signum)
        streaming_pull.cancel()
        streaming_pull.result(timeout=10)
        subscriber.close()
        log.info("Worker stopped.")
        sys.exit(0)

    signal.signal(signal.SIGINT, shutdown)
    signal.signal(signal.SIGTERM, shutdown)

    # Block forever, processing messages via callback
    try:
        streaming_pull.result()
    except Exception as e:
        log.error("Subscriber terminated: %s", e)
        streaming_pull.cancel()
        subscriber.close()


if __name__ == "__main__":
    main()
