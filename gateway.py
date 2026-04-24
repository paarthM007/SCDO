import os
import logging
import threading
from datetime import datetime, timezone
from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
import io

from scdo.config import GATEWAY_API_KEY, PORT, FIRESTORE_COLLECTION
from scdo.db import get_db
from scdo.routing.router import (
    find_route, find_alternate_route, list_cities, get_graph, extract_simulation_params
)
from scdo.simulation.monte_carlo import run_simulation_with_risk, monte_carlo_des

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(name)s] %(message)s")
logger = logging.getLogger("gateway")

app = Flask(__name__)
CORS(app)

from firebase_admin import auth
from collections import defaultdict
import time

user_requests = defaultdict(list)
RATE_LIMIT_WINDOW = 60 # seconds
RATE_LIMIT_MAX = 5 # requests per window

def _get_user():
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        # Fallback to dev api key for easy local testing if needed, though JWT is preferred
        if request.headers.get("X-API-Key", "") == GATEWAY_API_KEY:
            return "dev_admin_user"
        return None
    token = auth_header.split("Bearer ")[1]
    try:
        decoded_token = auth.verify_id_token(token)
        return decoded_token.get("uid")
    except Exception as e:
        logger.warning(f"Auth failed: {e}")
        return None

def _check_rate_limit(uid):
    now = time.time()
    user_requests[uid] = [t for t in user_requests[uid] if now - t < RATE_LIMIT_WINDOW]
    if len(user_requests[uid]) >= RATE_LIMIT_MAX:
        return False
    user_requests[uid].append(now)
    return True

def _err(msg, code=400):
    return jsonify({"error": msg, "status": "error"}), code

@app.route("/health", methods=["GET"])
def health():
    g = get_graph()
    return jsonify({
        "status": "ok", "version": "2.0",
        "nodes": len(g.nodes),
        "timestamp": datetime.now(timezone.utc).isoformat()
    })

@app.route("/api/simulate", methods=["POST"])
def api_simulate():
    uid = _get_user()
    if not uid: return _err("Unauthorized", 401)
    if not _check_rate_limit(uid): return _err("Rate limit exceeded. Please wait a minute.", 429)

    data = request.json or {}
    cities = data.get("cities")
    modes = data.get("modes")
    if not cities or not modes: return _err("Provide 'cities' and 'modes'")
    
    from scdo.config import DEFAULT_MC_ITERATIONS
    n_iter = data.get("n_iterations", DEFAULT_MC_ITERATIONS)

    try:
        db = get_db()
        job_ref = db.collection(FIRESTORE_COLLECTION).add({
            "user_id": uid,
            "cities": cities,
            "modes": modes,
            "cargo_type": data.get("cargo_type", "general"),
            "n_iterations": n_iter,
            "status": "pending",
            "created_at": datetime.now(timezone.utc),
            "source": "api_simulate"
        })
        return jsonify({
            "status": "ok", 
            "message": "Simulation job enqueued", 
            "job_id": job_ref[1].id
        })
    except Exception as e:
        logger.error(f"Failed to enqueue simulation: {e}")
        return _err(str(e), 500)

@app.route("/api/alternate-route", methods=["POST"])
def api_alternate_route():
    """Return path options only — no simulation is triggered."""
    uid = _get_user()
    if not uid: return _err("Unauthorized", 401)
    if not _check_rate_limit(uid): return _err("Rate limit exceeded. Please wait a minute.", 429)
    data = request.json or {}
    result = find_alternate_route(
        origin=data.get("start"),
        destination=data.get("end"),
        blocked_nodes=data.get("blocked", []),
        cargo_type=data.get("cargo_type", "general")
    )
    return jsonify({"status": "ok", "result": result})

@app.route("/api/simulate-path", methods=["POST"])
def api_simulate_path():
    """Simulate a single chosen path (fastest / cheapest / balanced)."""
    uid = _get_user()
    if not uid: return _err("Unauthorized", 401)
    if not _check_rate_limit(uid): return _err("Rate limit exceeded. Please wait a minute.", 429)

    data = request.json or {}
    route_key = data.get("route_key")          # "fastest" | "cheapest" | "balanced"
    if route_key not in ("fastest", "cheapest", "balanced"):
        return _err("route_key must be one of: fastest, cheapest, balanced")

    # Re-compute the specific route so we have path_edges
    result = find_alternate_route(
        origin=data.get("start"),
        destination=data.get("end"),
        blocked_nodes=data.get("blocked", []),
        cargo_type=data.get("cargo_type", "general")
    )
    path_data = result.get(route_key)
    if not path_data or "error" in path_data:
        return _err(f"No valid '{route_key}' route found")

    cities, modes = extract_simulation_params(path_data)
    if not cities or not modes:
        return _err("Could not extract simulation params from route")

    from scdo.config import DEFAULT_MC_ITERATIONS
    n_iter = data.get("n_iterations", DEFAULT_MC_ITERATIONS)

    try:
        db = get_db()
        job_ref = db.collection(FIRESTORE_COLLECTION).add({
            "user_id": uid,
            "cities": cities,
            "modes": modes,
            "cargo_type": data.get("cargo_type", "general"),
            "n_iterations": n_iter,
            "status": "pending",
            "created_at": datetime.now(timezone.utc),
            "source": f"alternate_route_{route_key}"
        })
        return jsonify({
            "status": "ok",
            "message": f"Simulation enqueued for '{route_key}' path",
            "job_id": job_ref[1].id,
            "route_key": route_key,
            "cities": cities,
            "modes": modes
        })
    except Exception as e:
        logger.error(f"Failed to enqueue simulation: {e}")
        return _err(str(e), 500)

@app.route("/api/history", methods=["GET"])
def api_history():
    uid = _get_user()
    if not uid: return _err("Unauthorized", 401)
    
    from scdo.analytics import get_job_history, compute_analytics
    mode = request.args.get("mode", "list")
    if mode == "analytics":
        return jsonify({"status": "ok", "analytics": compute_analytics(user_id=uid)})
    return jsonify({"status": "ok", "jobs": get_job_history(user_id=uid)})

@app.route("/api/report", methods=["POST"])
def api_report():
    uid = _get_user()
    if not uid: return _err("Unauthorized", 401)
    data = request.json or {}
    try:
        from scdo.reports import generate_report_pdf
        pdf_bytes = generate_report_pdf(data)
        return send_file(io.BytesIO(pdf_bytes), mimetype="application/pdf", download_name="report.pdf")
    except Exception as e:
        return _err(str(e), 500)

@app.route("/api/cities", methods=["GET"])
def api_cities():
    q = request.args.get("q", "")
    return jsonify({"cities": list_cities(q)})

def _start_worker_thread():
    try:
        from worker import start_listener
        t = threading.Thread(target=start_listener, daemon=True)
        t.start()
        logger.info("Background worker started")
    except Exception as e:
        logger.warning(f"Worker failed to start: {e}")

if __name__ == "__main__":
    get_graph()
    _start_worker_thread()
    app.run(host="0.0.0.0", port=PORT)
