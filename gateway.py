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
    find_route, find_alternate_route, list_cities, get_graph
)
from scdo.simulation.monte_carlo import run_simulation_with_risk, monte_carlo_des

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(name)s] %(message)s")
logger = logging.getLogger("gateway")

app = Flask(__name__)
CORS(app)

def _check_auth():
    return request.headers.get("X-API-Key", "") == GATEWAY_API_KEY

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
    if not _check_auth(): return _err("Unauthorized", 401)
    data = request.json or {}
    cities = data.get("cities")
    modes = data.get("modes")
    if not cities or not modes: return _err("Provide 'cities' and 'modes'")
    
    from scdo.config import MAX_MC_ITERATIONS, DEFAULT_MC_ITERATIONS
    n_iter = min(data.get("n_iterations", DEFAULT_MC_ITERATIONS), MAX_MC_ITERATIONS)

    try:
        result = run_simulation_with_risk(
            cities=cities, modes=modes,
            cargo_type=data.get("cargo_type", "general"),
            n_iterations=n_iter
        )
        
        # Log to Firestore for history/analytics
        try:
            db = get_db()
            db.collection(FIRESTORE_COLLECTION).add({
                "cities": cities,
                "modes": modes,
                "result": result,
                "status": "completed",
                "created_at": datetime.now(timezone.utc),
                "source": "api_gateway"
            })
        except Exception as db_err:
            logger.warning(f"Firestore logging failed: {db_err}")

        return jsonify({"status": "ok", "result": result})
    except Exception as e:
        logger.error(f"Simulation failed: {e}")
        return _err(str(e), 500)

@app.route("/api/alternate-route", methods=["POST"])
def api_alternate_route():
    if not _check_auth(): return _err("Unauthorized", 401)
    data = request.json or {}
    result = find_alternate_route(
        origin=data.get("start"),
        destination=data.get("end"),
        blocked_nodes=data.get("blocked", []),
        cargo_type=data.get("cargo_type", "general")
    )
    return jsonify({"status": "ok", "result": result})

@app.route("/api/history", methods=["GET"])
def api_history():
    if not _check_auth(): return _err("Unauthorized", 401)
    from scdo.analytics import get_job_history, compute_analytics
    mode = request.args.get("mode", "list")
    if mode == "analytics":
        return jsonify({"status": "ok", "analytics": compute_analytics()})
    return jsonify({"status": "ok", "jobs": get_job_history()})

@app.route("/api/report", methods=["POST"])
def api_report():
    if not _check_auth(): return _err("Unauthorized", 401)
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
