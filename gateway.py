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

# --- Live Orchestrator Imports ---
import uuid
from scdo.simulation.crisis_manager import CrisisManager
from scdo.simulation.telemetry_monitor import TelemetryMonitor
from scdo.simulation.shipment_tracker import ShipmentOrchestrator, ActiveShipment, parse_route_to_plan, NodeStep, LinkStep
from scdo.routing.cities_data import get_all_nodes


logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(name)s] %(message)s")
logger = logging.getLogger("gateway")

user_requests = defaultdict(list)
RATE_LIMIT_WINDOW = 60 # seconds
RATE_LIMIT_MAX = 5 # requests per window

app = Flask(__name__)
CORS(app)

# --- Global State Setup for Live Orchestrator ---
crisis_manager = CrisisManager()
telemetry_monitor = TelemetryMonitor(crisis_manager)
orchestrator = ShipmentOrchestrator(telemetry_monitor)

# Pre-warm telemetry with mocked baselines
all_nodes = get_all_nodes()
mocked_baselines = {n["name"]: {"mean": 2.0, "std_dev": 0.5} for n in all_nodes}
telemetry_monitor.pre_warm_baselines(mocked_baselines)

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
        "status": "ok", "version": "3.0",
        "engine": "CTR Tensor Routing",
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
            # v3.0 CTR parameters
            "quantity": data.get("quantity"),
            "product_type": data.get("product_type"),
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
    """
    Return path options only — no simulation is triggered.
    v3.0: Accepts quantity, product_type, budget, deadline_h, omega.
    """
    uid = _get_user()
    if not uid: return _err("Unauthorized", 401)
    if not _check_rate_limit(uid): return _err("Rate limit exceeded. Please wait a minute.", 429)
    data = request.json or {}

    # Parse v3.0 CTR parameters
    quantity = data.get("quantity")
    if quantity is not None:
        try:
            quantity = float(quantity)
        except (ValueError, TypeError):
            quantity = None

    budget = data.get("budget")
    if budget is not None:
        try:
            budget = float(budget)
        except (ValueError, TypeError):
            budget = None

    deadline_h = data.get("deadline_h")
    if deadline_h is not None:
        try:
            deadline_h = float(deadline_h)
        except (ValueError, TypeError):
            deadline_h = None

    omega = data.get("omega")
    if omega is not None:
        try:
            omega = max(0.0, min(1.0, float(omega)))
        except (ValueError, TypeError):
            omega = None

    result = find_alternate_route(
        origin=data.get("start"),
        destination=data.get("end"),
        blocked_nodes=data.get("blocked", []),
        cargo_type=data.get("cargo_type", "general"),
        quantity=quantity,
        product_type=data.get("product_type"),
        budget=budget,
        deadline_h=deadline_h,
        omega=omega,
    )
    return jsonify({"status": "ok", "result": result})

@app.route("/api/simulate-path", methods=["POST"])
def api_simulate_path():
    """
    Simulate a single chosen path (fastest / cheapest / balanced).
    v3.0: Passes CTR parameters to simulation engine.
    """
    uid = _get_user()
    if not uid: return _err("Unauthorized", 401)
    if not _check_rate_limit(uid): return _err("Rate limit exceeded. Please wait a minute.", 429)

    data = request.json or {}
    route_key = data.get("route_key")          # "fastest" | "cheapest" | "balanced"
    if route_key not in ("fastest", "cheapest", "balanced"):
        return _err("route_key must be one of: fastest, cheapest, balanced")

    # Parse v3.0 CTR parameters
    quantity = data.get("quantity")
    if quantity is not None:
        try:
            quantity = float(quantity)
        except (ValueError, TypeError):
            quantity = None

    # Re-compute the specific route so we have path_edges
    result = find_alternate_route(
        origin=data.get("start"),
        destination=data.get("end"),
        blocked_nodes=data.get("blocked", []),
        cargo_type=data.get("cargo_type", "general"),
        quantity=quantity,
        product_type=data.get("product_type"),
        budget=data.get("budget"),
        deadline_h=data.get("deadline_h"),
        omega=data.get("omega"),
    )
    path_data = result.get(route_key)
    if not path_data or "error" in path_data:
        return _err(f"No valid '{route_key}' route found")

    cities, modes, edges = extract_simulation_params(path_data)
    if not cities or not modes:
        return _err("Could not extract simulation params from route")

    n_iter = data.get("n_iterations", DEFAULT_MC_ITERATIONS)

    try:
        db = get_db()
        job_ref = db.collection(FIRESTORE_COLLECTION).add({
            "user_id": uid,
            "cities": cities,
            "modes": modes,
            "path_edges": edges,
            "cargo_type": data.get("cargo_type", "general"),
            "n_iterations": n_iter,
            # v3.0 CTR parameters
            "quantity": quantity,
            "product_type": data.get("product_type"),
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

            from google.cloud.firestore import FieldFilter
            # Check if this user already rated this city — upsert
            existing = (
                db.collection("community_risk_reports")
                  .where(filter=FieldFilter("user_id", "==", uid))
                  .where(filter=FieldFilter("city", "==", city_lower))
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
    """Smart multi-supplier routing with automatic disruption detection.
    Body: {
        buyer: "CityName",
        suppliers: ["City1", "City2", ...],
        cargo_type: "general",
        risk_threshold: 0.65,       # cities above this are auto-avoided
        avoid_disruptions: true     # enable/disable auto-avoidance
    }
    Two-pass routing:
      Pass 1 → find optimal route
      Pass 2 → scan waypoint cities for risk, auto-block high-risk, re-route
    """
    uid = _get_user()
    if not uid: return _err("Unauthorized", 401)
    if not _check_rate_limit(uid): return _err("Rate limit exceeded. Please wait a minute.", 429)

    data = request.json or {}
    buyer = data.get("buyer")
    suppliers = data.get("suppliers", [])
    cargo_type = data.get("cargo_type", "general")
    risk_threshold = float(data.get("risk_threshold", 0.65))
    avoid_disruptions = data.get("avoid_disruptions", True)

    if not buyer: return _err("Provide 'buyer' city name")
    if not suppliers or not isinstance(suppliers, list):
        return _err("Provide 'suppliers' as a list of city names")

    # Lazy-import risk engine (it calls external APIs)
    from scdo.risk.combined_risk import compute_combined_risk

    results = []
    all_disruptions = []   # global list of flagged cities for the response

    for supplier in suppliers:
        supplier = supplier.strip()
        if not supplier:
            continue

        disruption_report = {
            "supplier": supplier,
            "flagged_cities": [],
            "risk_threshold_used": risk_threshold,
        }

        # ── Pass 1: Find initial route (no blocks) ──────────────
        initial_result = find_alternate_route(
            origin=supplier,
            destination=buyer,
            blocked_nodes=[],
            cargo_type=cargo_type,
        )

        auto_blocked = []

        if avoid_disruptions:
            # ── Extract waypoint cities from balanced route ──────
            balanced = initial_result.get("balanced", {})
            waypoint_cities = []
            if balanced and "error" not in balanced:
                waypoints = balanced.get("waypoints", [])
                for wp in waypoints:
                    name = wp.get("name", "")
                    # Don't block origin or destination themselves
                    if name and name.lower() != supplier.lower() and name.lower() != buyer.lower():
                        waypoint_cities.append(name)

            # ── Scan waypoints for disruptions ──────────────────
            if waypoint_cities:
                try:
                    risk_result = compute_combined_risk(
                        waypoint_cities, cargo_type=cargo_type
                    )
                    # The risk engine gives per-city data inside weather/sentiment
                    combined_score = risk_result.get("combined_risk_score", 0)
                    weather_data = risk_result.get("weather_risk", {})
                    sentiment_data = risk_result.get("sentiment_risk", {})
                    community_data = risk_result.get("community_risk", {})

                    # Get per-city weather scores
                    per_city_weather = weather_data.get("city_scores", {})
                    per_city_sentiment = sentiment_data.get("city_scores", {})
                    per_city_community = community_data.get("city_scores", {})

                    for city in waypoint_cities:
                        # Estimate per-city combined risk
                        w_score = per_city_weather.get(city, {}).get("normalized", 0)
                        s_score = per_city_sentiment.get(city, {}).get("normalized", 0)
                        c_score = per_city_community.get(city, {}).get("normalized", 0)

                        # Same formula as combined_risk.py
                        base = 1.0 - (1.0 - s_score) * (1.0 - w_score)
                        synergy = s_score * w_score * 0.40
                        city_risk = base + synergy

                        reasons = []
                        if w_score > 0.3:
                            reasons.append(f"Weather risk: {w_score:.0%}")
                        if s_score > 0.3:
                            reasons.append(f"News sentiment: {s_score:.0%}")
                        if c_score > 0.3:
                            reasons.append(f"Community reports: {c_score:.0%}")

                        if city_risk >= risk_threshold:
                            auto_blocked.append(city)
                            disruption_report["flagged_cities"].append({
                                "city": city,
                                "risk_score": round(city_risk, 3),
                                "reasons": reasons if reasons else ["Combined risk above threshold"],
                                "action": "auto_avoided",
                            })
                        elif city_risk >= risk_threshold * 0.7:
                            # Warn but don't block
                            disruption_report["flagged_cities"].append({
                                "city": city,
                                "risk_score": round(city_risk, 3),
                                "reasons": reasons if reasons else ["Elevated risk"],
                                "action": "warning",
                            })
                except Exception as e:
                    logger.warning(f"Risk scan failed for {supplier}→{buyer}: {e}")
                    disruption_report["scan_error"] = str(e)

        # ── Pass 2: Re-route if disruptions found ──────────────
        if auto_blocked:
            disruption_report["auto_avoided_count"] = len(auto_blocked)
            route_result = find_alternate_route(
                origin=supplier,
                destination=buyer,
                blocked_nodes=auto_blocked,
                cargo_type=cargo_type,
            )
        else:
            route_result = initial_result

        results.append({
            "supplier": supplier,
            "buyer": buyer,
            "routes": route_result,
            "disruption_report": disruption_report,
        })
        all_disruptions.append(disruption_report)

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
        # Include disruption summary in comparison
        dr = r.get("disruption_report", {})
        entry["disruptions"] = {
            "avoided_count": dr.get("auto_avoided_count", 0),
            "flagged_cities": dr.get("flagged_cities", []),
        }
        comparison.append(entry)

    return jsonify({
        "status": "ok",
        "buyer": buyer,
        "supplier_count": len(results),
        "risk_threshold": risk_threshold,
        "avoid_disruptions": avoid_disruptions,
        "supplier_routes": results,
        "comparison": comparison,
        "disruption_summary": all_disruptions,
    })

@app.route("/api/cities", methods=["GET"])
def api_cities():
    q = request.args.get("q", "")
    return jsonify({"cities": list_cities(q)})

@app.route("/dispatch", methods=["POST"])
@app.route("/api/dispatch", methods=["POST"])
def api_dispatch():
    data = request.json or {}
    cargo_type = data.get("cargo_type", "PERISHABLE")
    origin = data.get("origin")
    destination = data.get("destination")
    
    if not origin or not destination:
        return _err("Missing origin or destination")
        
    crisis_manager.reset_crises()
    orchestrator.active_shipments.clear()
    
    route_resp = find_route(
        origin=origin,
        destination=destination,
        cargo_type=cargo_type,
        quantity=100
    )
    if "error" in route_resp:
        return _err(route_resp["error"])
        
    path_edges = route_resp.get("path_edges", [])
    if not path_edges:
        return _err("No path edges returned")
        
    route_plan = parse_route_to_plan(path_edges)
    shipment_id = str(uuid.uuid4())
    shipment = ActiveShipment(shipment_id=shipment_id, cargo_type=cargo_type, route_plan=route_plan)
    orchestrator.add_shipment(shipment)
    
    route_names = [step.name for step in route_plan if isinstance(step, NodeStep)]
    
    return jsonify({
        "shipment_id": shipment_id,
        "route_plan": route_names,
        "status": "DISPATCHED"
    })

@app.route("/tick", methods=["POST"])
@app.route("/api/tick", methods=["POST"])
def api_tick():
    data = request.json or {}
    hours_to_advance = float(data.get("hours_to_advance", 1.0))
    
    crises_before = set(crisis_manager.banned_nodes).union(set(crisis_manager.active_risk_multipliers.keys()))
    
    orchestrator.tick(hours_to_advance)
    
    crises_after = set(crisis_manager.banned_nodes).union(set(crisis_manager.active_risk_multipliers.keys()))
    new_crises = crises_after - crises_before
    
    for crisis_node in new_crises:
        orchestrator.evaluate_active_routes(crisis_node)

    shipments_data = []
    for s_id, shipment in orchestrator.active_shipments.items():
        fresh_logs = list(shipment.decision_logs)
        shipment.decision_logs.clear()

        # Guard: index is out of range once status is DELIVERED
        if shipment.status == 'DELIVERED' or shipment.current_step_index >= len(shipment.route_plan):
            route_names = [step.name for step in shipment.route_plan if isinstance(step, NodeStep)]
            shipments_data.append({
                "shipment_id": shipment.shipment_id,
                "status": "DELIVERED",
                "current_step_name": route_names[-1] if route_names else "Unknown",
                "next_step_name": "Delivered",
                "progress_percentage": 1.0,
                "route_plan": route_names,
                "fresh_logs": fresh_logs
            })
            continue

        current_step = shipment.route_plan[shipment.current_step_index]
        
        if isinstance(current_step, NodeStep):
            curr_name = current_step.name
            next_name = shipment.route_plan[shipment.current_step_index + 1].name if (shipment.current_step_index + 1) < len(shipment.route_plan) else "Final Destination"
        else:
            curr_name = f"Transit to {current_step.to_node}"
            next_name = current_step.to_node

        progress_pct = shipment.progress_on_step / current_step.time_h if current_step.time_h > 0 else 1.0
        progress_pct = min(progress_pct, 1.0)  # clamp to 100%
        
        route_names = [step.name for step in shipment.route_plan if isinstance(step, NodeStep)]

        shipments_data.append({
            "shipment_id": shipment.shipment_id,
            "status": shipment.status,
            "current_step_name": curr_name,
            "next_step_name": next_name,
            "progress_percentage": round(progress_pct, 2),
            "route_plan": route_names,
            "fresh_logs": fresh_logs
        })


    active_crises = list(crises_after)
    
    telemetry_charts = {}
    for node in active_crises:
        if node in telemetry_monitor.baselines and node in telemetry_monitor.live_windows:
            windows = telemetry_monitor.live_windows[node]
            telemetry_charts[node] = {
                "rolling_mean": sum(windows) / len(windows) if len(windows) > 0 else 0,
                "threshold": telemetry_monitor.baselines[node]["mean"] + (3 * telemetry_monitor.baselines[node]["std_dev"]),
                "history": list(windows)
            }

    return jsonify({
        "active_shipments": shipments_data,
        "global_state": {
            "active_crises": active_crises,
            "telemetry_charts": telemetry_charts
        }
    })

if __name__ == "__main__":
    get_graph()
    app.run(host="0.0.0.0", port=PORT)
