import os
import io
import time
import logging
import threading
from datetime import datetime, timezone, timedelta
from collections import defaultdict

from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
from firebase_admin import auth

from scdo.config import GATEWAY_API_KEY, PORT, FIRESTORE_COLLECTION, DEFAULT_MC_ITERATIONS
from scdo.db import get_db
from scdo.routing.router import (
    find_route, find_alternate_route, list_cities, get_graph, extract_simulation_params
)
from scdo.simulation.monte_carlo import run_simulation_with_risk, monte_carlo_des
from scdo.analytics import get_job_history, compute_analytics
from scdo.reports import generate_report_pdf

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(name)s] %(message)s")
logger = logging.getLogger("gateway")

user_requests = defaultdict(list)
RATE_LIMIT_WINDOW = 60 # seconds
RATE_LIMIT_MAX = 5 # requests per window

app = Flask(__name__)
CORS(app)

def _start_worker_thread():
    try:
        from worker import start_listener
        t = threading.Thread(target=start_listener, daemon=True)
        t.start()
        logger.info("Background worker started")
    except Exception as e:
        logger.warning(f"Worker failed to start: {e}")

# Start worker immediately on load
_start_worker_thread()

def _get_user():
    # Priority 1: Check for Firebase JWT (Real Users)
    auth_header = request.headers.get("Authorization")
    if auth_header and auth_header.startswith("Bearer "):
        token = auth_header.split("Bearer ")[1]
        try:
            decoded_token = auth.verify_id_token(token)
            uid = decoded_token.get("uid")
            
            # Track user activity for auto-deletion
            if uid:
                db = get_db()
                user_doc_ref = db.collection("users").document(uid)
                user_doc = user_doc_ref.get()
                
                now = datetime.now(timezone.utc)
                if user_doc.exists:
                    user_data = user_doc.to_dict()
                    user_expires = user_data.get("expires_at")
                    if user_expires and user_expires.replace(tzinfo=timezone.utc) < now:
                        # Soft Delete: User has been inactive for > 30 days
                        # We could delete their data here or just treat them as new
                        logger.info(f"User {uid} expired. Re-initializing.")

                # Refresh activity
                user_doc_ref.set({
                    "last_active": now,
                    "expires_at": now + timedelta(days=30),
                    "email": decoded_token.get("email")
                }, merge=True)
            
            return uid
        except Exception as e:
            logger.warning(f"Firebase Token Auth failed: {e}")
            # Fall through to check API Key

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
    mode = request.args.get("mode", "list")
    if mode == "analytics":
        return jsonify({"status": "ok", "analytics": compute_analytics(user_id=uid)})
    return jsonify({"status": "ok", "jobs": get_job_history(user_id=uid)})

@app.route("/api/history/<job_id>", methods=["DELETE", "POST"])
def api_delete_history(job_id):
    uid = _get_user()
    if not uid: return _err("Unauthorized", 401)
    
    try:
        db = get_db()
        doc_ref = db.collection(FIRESTORE_COLLECTION).document(job_id)
        doc = doc_ref.get()
        
        if not doc.exists:
            return _err("Job not found", 404)
            
        doc_data = doc.to_dict()
        if doc_data.get("user_id") != uid:
            return _err("Forbidden", 403)
            
        doc_ref.delete()
        return jsonify({"status": "ok", "message": f"Job {job_id} deleted successfully"})
    except Exception as e:
        logger.error(f"Failed to delete job {job_id}: {e}")
        return _err(str(e), 500)

@app.route("/api/report", methods=["POST"])
def api_report():
    uid = _get_user()
    if not uid: return _err("Unauthorized", 401)
    data = request.json or {}
    try:
        pdf_bytes = generate_report_pdf(data)
        return send_file(io.BytesIO(pdf_bytes), mimetype="application/pdf", download_name="report.pdf")
    except Exception as e:
        return _err(str(e), 500)

@app.route("/api/feedback", methods=["POST"])
def api_feedback():
    """Save community risk ratings for cities. Body: { ratings: { "CityName": 7, ... }, job_id?: "..." }
    One rating per user per city — subsequent submissions update the existing rating."""
    uid = _get_user()
    if not uid: return _err("Unauthorized", 401)

    data = request.json or {}
    ratings = data.get("ratings", {})
    job_id = data.get("job_id")

    if not ratings or not isinstance(ratings, dict):
        return _err("Provide 'ratings' dict, e.g. {\"Mumbai\": 7, \"Delhi\": 3}")

    db = get_db()
    saved = 0
    updated = 0
    for city, score in ratings.items():
        try:
            score = int(score)
            if score < 1 or score > 10:
                continue
            city_lower = city.strip().lower()

            # Check if this user already rated this city — upsert
            existing = (
                db.collection("community_risk_reports")
                  .where("user_id", "==", uid)
                  .where("city", "==", city_lower)
                  .limit(1)
                  .stream()
            )
            existing_doc = next(existing, None)

            if existing_doc:
                # Update existing rating
                existing_doc.reference.update({
                    "risk_rating": score,
                    "job_id": job_id,
                    "updated_at": datetime.now(timezone.utc),
                    "expires_at": datetime.now(timezone.utc) + timedelta(hours=72),
                })
                updated += 1
            else:
                # Create new rating
                db.collection("community_risk_reports").add({
                    "city": city_lower,
                    "city_display": city.strip(),
                    "risk_rating": score,
                    "user_id": uid,
                    "job_id": job_id,
                    "created_at": datetime.now(timezone.utc),
                    "expires_at": datetime.now(timezone.utc) + timedelta(hours=72),
                })
                saved += 1
        except Exception as e:
            logger.warning(f"Failed to save rating for {city}: {e}")

    return jsonify({
        "status": "ok",
        "new": saved,
        "updated": updated,
        "message": f"{saved} new + {updated} updated rating(s). Thank you!"
    })

@app.route("/api/multi-supplier-routes", methods=["POST"])
def api_multi_supplier_routes():
    """Find routes from multiple suppliers to a single buyer.
    Body: { buyer: "CityName", suppliers: ["City1", "City2", ...],
            blocked: [...], cargo_type: "general" }
    Returns route options (fastest/cheapest/balanced) for each supplier→buyer pair.
    """
    uid = _get_user()
    if not uid: return _err("Unauthorized", 401)
    if not _check_rate_limit(uid): return _err("Rate limit exceeded. Please wait a minute.", 429)

    data = request.json or {}
    buyer = data.get("buyer")
    suppliers = data.get("suppliers", [])
    blocked = data.get("blocked", [])
    cargo_type = data.get("cargo_type", "general")

    if not buyer: return _err("Provide 'buyer' city name")
    if not suppliers or not isinstance(suppliers, list):
        return _err("Provide 'suppliers' as a list of city names")

    results = []
    for supplier in suppliers:
        supplier = supplier.strip()
        if not supplier:
            continue
        route_result = find_alternate_route(
            origin=supplier,
            destination=buyer,
            blocked_nodes=blocked,
            cargo_type=cargo_type,
        )
        results.append({
            "supplier": supplier,
            "buyer": buyer,
            "routes": route_result,
        })

    # Build a comparison summary
    comparison = []
    for r in results:
        entry = {"supplier": r["supplier"]}
        for key in ("fastest", "cheapest", "balanced"):
            route_data = r["routes"].get(key, {})
            if route_data and "error" not in route_data:
                entry[key] = {
                    "total_distance_km": route_data.get("total_distance_km"),
                    "total_time_h": route_data.get("total_time_h"),
                    "total_time_readable": route_data.get("total_time_readable"),
                    "total_cost_usd": route_data.get("total_cost_usd"),
                    "num_hops": route_data.get("num_hops"),
                    "modes_used": route_data.get("modes_used"),
                }
            else:
                entry[key] = {"error": route_data.get("error", "No route found")}
        comparison.append(entry)

    return jsonify({
        "status": "ok",
        "buyer": buyer,
        "supplier_count": len(results),
        "supplier_routes": results,
        "comparison": comparison,
    })

@app.route("/api/cities", methods=["GET"])
def api_cities():
    q = request.args.get("q", "")
    return jsonify({"cities": list_cities(q)})

if __name__ == "__main__":
    get_graph()
    app.run(host="0.0.0.0", port=PORT)
