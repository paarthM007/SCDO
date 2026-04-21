"""
gateway.py - Single Flask API gateway for SCDO v2.0.
Endpoints:
  POST /api/simulate            — Functionality 1: route cost & delay
  POST /api/alternate-route     — Functionality 2: blocked-node routing
  POST /api/compare-routes      — Feature: side-by-side route comparison
  GET  /api/history             — Feature: historical job analytics
  POST /api/insurance           — Feature: cargo insurance estimator
  POST /api/what-if             — Feature: scenario analysis
  GET  /api/report/<job_id>     — Feature: PDF report download
  GET  /api/route               — Simple point-to-point routing
  GET  /api/cities              — City search/autocomplete
  GET  /health                  — Liveness check
"""
import os
import logging
import threading
from datetime import datetime, timezone
from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
import io

from scdo.config import GATEWAY_API_KEY, PORT
from scdo.routing.router import (
    find_route, find_alternate_route, list_cities, get_graph
)
from scdo.simulation.monte_carlo import run_simulation_with_risk, monte_carlo_des

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(name)s] %(message)s")
logger = logging.getLogger("gateway")

app = Flask(__name__)
CORS(app)


# ── Auth ──────────────────────────────────────────────────────
def _check_auth():
    return request.headers.get("X-API-Key", "") == GATEWAY_API_KEY

def _err(msg, code=400):
    return jsonify({"error": msg, "status": "error"}), code


# ══════════════════════════════════════════════════════════════
#  HEALTH
# ══════════════════════════════════════════════════════════════
@app.route("/health", methods=["GET"])
def health():
    g = get_graph()
    return jsonify({
        "status": "ok", "version": "2.0",
        "nodes": len(g.nodes),
        "edges": sum(len(v) for v in g.adj.values()) // 2,
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "endpoints": [
            "POST /api/simulate", "POST /api/alternate-route",
            "POST /api/compare-routes", "GET /api/history",
            "POST /api/insurance", "POST /api/what-if",
            "GET /api/report/<job_id>", "GET /api/cities",
        ],
    })


# ══════════════════════════════════════════════════════════════
#  FUNCTIONALITY 1: Route Cost & Delay Simulation
# ══════════════════════════════════════════════════════════════
@app.route("/api/simulate", methods=["POST"])
def api_simulate():
    if not _check_auth(): return _err("Unauthorized", 401)
    data = request.json or {}
    cities = data.get("cities")
    modes = data.get("modes")
    if not cities or not modes: return _err("Provide 'cities' and 'modes'")
    if len(modes) != len(cities) - 1:
        return _err(f"Need {len(cities)-1} modes for {len(cities)} cities")

    from scdo.config import MAX_MC_ITERATIONS, DEFAULT_MC_ITERATIONS
    n_iter = min(data.get("n_iterations", DEFAULT_MC_ITERATIONS), MAX_MC_ITERATIONS)

    try:
        result = run_simulation_with_risk(
            cities=cities, modes=modes,
            cargo_type=data.get("cargo_type", "general"),
            target_date=data.get("target_date"),
            n_iterations=n_iter,
            seed=data.get("seed", 42),
            importance_boost=data.get("importance_boost", 1.0),
            facility_configs=data.get("facility_configs"),
        )
        return jsonify({"status": "ok", "result": result})
    except Exception as e:
        logger.error("Simulation failed: %s", e, exc_info=True)
        return _err(f"Simulation failed: {str(e)}", 500)


# ══════════════════════════════════════════════════════════════
#  FUNCTIONALITY 2: Alternate Route (blocked nodes)
# ══════════════════════════════════════════════════════════════
@app.route("/api/alternate-route", methods=["POST"])
def api_alternate_route():
    if not _check_auth(): return _err("Unauthorized", 401)
    data = request.json or {}
    start = data.get("start") or data.get("origin")
    end = data.get("end") or data.get("destination")
    blocked = data.get("blocked", [])
    if not start: return _err("Provide 'start' city")
    if not end: return _err("Provide 'end' city")
    if not blocked: return _err("Provide 'blocked' list (cities to avoid)")

    result = find_alternate_route(
        origin=start, destination=end, blocked_nodes=blocked,
        cargo_type=data.get("cargo_type", "general"),
        mode_pref=data.get("mode"),
    )
    if "error" in result: return _err(result["error"], 404)
    return jsonify({"status": "ok", "result": result})


# ══════════════════════════════════════════════════════════════
#  FEATURE: Route Comparison (2-3 routes side-by-side)
# ══════════════════════════════════════════════════════════════
@app.route("/api/compare-routes", methods=["POST"])
def api_compare_routes():
    """
    Compare 2-3 routes side-by-side.
    Body: { "routes": [ {cities, modes, cargo_type}, {cities, modes, cargo_type} ] }
    """
    if not _check_auth(): return _err("Unauthorized", 401)
    data = request.json or {}
    routes = data.get("routes", [])
    if len(routes) < 2: return _err("Provide at least 2 routes to compare")
    if len(routes) > 3: return _err("Maximum 3 routes for comparison")

    from scdo.config import MAX_MC_ITERATIONS, DEFAULT_MC_ITERATIONS
    n_iter = min(data.get("n_iterations", DEFAULT_MC_ITERATIONS), MAX_MC_ITERATIONS)

    results = []
    for i, route_cfg in enumerate(routes):
        cities = route_cfg.get("cities")
        modes = route_cfg.get("modes")
        if not cities or not modes:
            results.append({"route_index": i, "error": "Missing cities or modes"})
            continue
        try:
            r = run_simulation_with_risk(
                cities=cities, modes=modes,
                cargo_type=route_cfg.get("cargo_type", "general"),
                target_date=route_cfg.get("target_date"),
                n_iterations=n_iter,
                seed=data.get("seed", 42) + i,
            )
            r["route_index"] = i
            r["route_label"] = " → ".join(cities)
            results.append(r)
        except Exception as e:
            results.append({"route_index": i, "error": str(e)})

    # Build comparison summary
    valid = [r for r in results if "simulation_stats" in r]
    comparison = None
    if len(valid) >= 2:
        comparison = {
            "fastest": min(valid, key=lambda r: r["simulation_stats"]["time"]["mean"])["route_label"],
            "cheapest": min(valid, key=lambda r: r["simulation_stats"]["cost"]["mean"])["route_label"],
            "lowest_risk": min(valid, key=lambda r: r["combined_risk"]["score"])["route_label"],
            "table": [{
                "route": r["route_label"],
                "time_mean_h": r["simulation_stats"]["time"]["mean"],
                "time_p95_h": r["simulation_stats"]["time"]["p95"],
                "cost_mean": r["simulation_stats"]["cost"]["mean"],
                "cost_p95": r["simulation_stats"]["cost"]["p95"],
                "risk_score": r["combined_risk"]["score"],
                "risk_level": r["combined_risk"]["level"],
            } for r in valid],
        }

    return jsonify({
        "status": "ok",
        "comparison": comparison,
        "routes": results,
    })


# ══════════════════════════════════════════════════════════════
#  FEATURE: Historical Job Analytics
# ══════════════════════════════════════════════════════════════
@app.route("/api/history", methods=["GET"])
def api_history():
    if not _check_auth(): return _err("Unauthorized", 401)
    mode = request.args.get("mode", "list")  # "list" or "analytics"
    limit = min(int(request.args.get("limit", "50")), 200)

    try:
        from scdo.analytics import get_job_history, compute_analytics
        if mode == "analytics":
            return jsonify({"status": "ok", "analytics": compute_analytics(limit)})
        else:
            status = request.args.get("status")
            jobs = get_job_history(limit, status)
            return jsonify({"status": "ok", "count": len(jobs), "jobs": jobs})
    except Exception as e:
        logger.error("History query failed: %s", e)
        return _err(f"History query failed: {str(e)}", 500)


# ══════════════════════════════════════════════════════════════
#  FEATURE: Cargo Insurance Cost Estimator
# ══════════════════════════════════════════════════════════════
@app.route("/api/insurance", methods=["POST"])
def api_insurance():
    """
    Estimate insurance premium for a shipment.
    Body: {cargo_type, cargo_value_usd, risk_score, p95_delay_hours}
    OR:   {cargo_type, cargo_value_usd, cities, modes} (auto-simulates first)
    """
    if not _check_auth(): return _err("Unauthorized", 401)
    data = request.json or {}

    cargo_type = data.get("cargo_type", "general")
    cargo_value = data.get("cargo_value_usd")
    if not cargo_value: return _err("Provide 'cargo_value_usd'")

    risk_score = data.get("risk_score")
    p95_hours = data.get("p95_delay_hours")

    # If no pre-computed values, run a quick simulation
    if risk_score is None or p95_hours is None:
        cities = data.get("cities")
        modes = data.get("modes")
        if not cities or not modes:
            return _err("Provide risk_score+p95_delay_hours OR cities+modes for auto-sim")
        try:
            sim = run_simulation_with_risk(
                cities=cities, modes=modes, cargo_type=cargo_type, n_iterations=20, seed=42)
            risk_score = sim["combined_risk"]["score"]
            p95_hours = sim["simulation_stats"]["time"]["p95"]
        except Exception as e:
            return _err(f"Auto-simulation failed: {str(e)}", 500)

    from scdo.analytics import estimate_insurance
    result = estimate_insurance(cargo_type, float(cargo_value),
                                float(risk_score), float(p95_hours))
    return jsonify({"status": "ok", "insurance": result})


# ══════════════════════════════════════════════════════════════
#  FEATURE: What-If Scenario Analysis
# ══════════════════════════════════════════════════════════════
@app.route("/api/what-if", methods=["POST"])
def api_what_if():
    """
    Run baseline vs scenario comparison.
    Body: {
      cities, modes, cargo_type,
      scenarios: [
        {name: "Suez blocked", blocked_nodes: ["Cairo", "Suez"]},
        {name: "High risk", risk_override: 0.8},
        {name: "Monsoon", delay_multiplier: 1.5},
      ]
    }
    """
    if not _check_auth(): return _err("Unauthorized", 401)
    data = request.json or {}
    cities = data.get("cities")
    modes = data.get("modes")
    scenarios = data.get("scenarios", [])
    if not cities or not modes: return _err("Provide 'cities' and 'modes'")
    if not scenarios: return _err("Provide at least one scenario")

    from scdo.config import DEFAULT_MC_ITERATIONS
    n_iter = min(data.get("n_iterations", 20), 100)
    cargo = data.get("cargo_type", "general")

    results = []

    # Run baseline
    try:
        baseline = run_simulation_with_risk(
            cities=cities, modes=modes, cargo_type=cargo, n_iterations=n_iter, seed=42)
        baseline["scenario"] = "Baseline"
        results.append(baseline)
    except Exception as e:
        results.append({"scenario": "Baseline", "error": str(e)})

    # Run each scenario
    for i, sc in enumerate(scenarios):
        name = sc.get("name", f"Scenario {i+1}")
        try:
            if sc.get("blocked_nodes"):
                # Route-finding scenario (alternate route)
                alt = find_alternate_route(
                    cities[0], cities[-1], sc["blocked_nodes"], cargo)
                results.append({
                    "scenario": name, "type": "alternate_route",
                    "result": alt,
                })
            elif sc.get("risk_override") is not None:
                # Override risk score
                sim = monte_carlo_des(
                    locations=cities, modes=modes,
                    n_iterations=n_iter, seed=42 + i + 1,
                    combined_risk_score=float(sc["risk_override"]),
                )
                results.append({
                    "scenario": name, "type": "risk_override",
                    "risk_override": sc["risk_override"],
                    "simulation_stats": sim,
                })
            elif sc.get("delay_multiplier"):
                # Manual delay multiplier
                sim = monte_carlo_des(
                    locations=cities, modes=modes,
                    n_iterations=n_iter, seed=42 + i + 1,
                    combined_risk_score=0.0,  # We'll inject multiplier directly
                )
                # Scale results by the multiplier
                mult = float(sc["delay_multiplier"])
                for key in ["mean", "std", "min", "max", "p5", "p50", "p95"]:
                    if key in sim["time"]:
                        sim["time"][key] = round(sim["time"][key] * mult, 2)
                results.append({
                    "scenario": name, "type": "delay_multiplier",
                    "delay_multiplier": mult,
                    "simulation_stats": sim,
                })
            else:
                results.append({"scenario": name, "error": "Unknown scenario type"})
        except Exception as e:
            results.append({"scenario": name, "error": str(e)})

    return jsonify({"status": "ok", "baseline_route": " → ".join(cities), "results": results})


# ══════════════════════════════════════════════════════════════
#  FEATURE: PDF Report Generation
# ══════════════════════════════════════════════════════════════
@app.route("/api/report", methods=["POST"])
def api_report():
    """
    Generate PDF report from simulation result.
    Body: simulation result dict (from /api/simulate)
    OR:   {cities, modes, cargo_type} to auto-simulate then generate
    """
    if not _check_auth(): return _err("Unauthorized", 401)
    data = request.json or {}

    # If it's a raw simulation result, use it directly
    if "simulation_stats" in data:
        sim_result = data
    elif "cities" in data and "modes" in data:
        try:
            sim_result = run_simulation_with_risk(
                cities=data["cities"], modes=data["modes"],
                cargo_type=data.get("cargo_type", "general"),
                n_iterations=data.get("n_iterations", 20), seed=42)
        except Exception as e:
            return _err(f"Simulation failed: {str(e)}", 500)
    else:
        return _err("Provide simulation result or cities+modes")

    try:
        from scdo.reports import generate_report_pdf
        pdf_bytes = generate_report_pdf(sim_result)
        return send_file(
            io.BytesIO(pdf_bytes),
            mimetype="application/pdf",
            as_attachment=True,
            download_name="scdo_report.pdf"
        )
    except Exception as e:
        logger.error("Report generation failed: %s", e, exc_info=True)
        return _err(f"Report generation failed: {str(e)}", 500)


# ══════════════════════════════════════════════════════════════
#  EXISTING: Simple route + city search
# ══════════════════════════════════════════════════════════════
@app.route("/api/route", methods=["GET"])
def api_route():
    if not _check_auth(): return _err("Unauthorized", 401)
    origin = request.args.get("from") or request.args.get("origin")
    dest = request.args.get("to") or request.args.get("destination")
    mode = request.args.get("mode", "BEST")
    if not origin: return _err("Provide ?from=CityName")
    if not dest: return _err("Provide ?to=CityName")
    result = find_route(origin, dest, mode)
    if "error" in result: return _err(result["error"], 404)
    return jsonify(result)


@app.route("/api/cities", methods=["GET"])
def api_cities():
    q = request.args.get("q", "")
    country = request.args.get("country", "")
    cities = list_cities(q or None, country or None)
    return jsonify({"count": len(cities), "cities": cities})


# ══════════════════════════════════════════════════════════════
#  Startup
# ══════════════════════════════════════════════════════════════
def _start_worker_thread():
    try:
        from worker import start_listener
        t = threading.Thread(target=start_listener, daemon=True)
        t.start()
        logger.info("Firestore worker started in background")
    except Exception as e:
        logger.warning("Firestore worker not started: %s", e)


if __name__ == "__main__":
    logger.info("Loading routing graph...")
    get_graph()
    _start_worker_thread()
    logger.info(f"SCDO Gateway v2.0 on port {PORT}")
    app.run(host="0.0.0.0", port=PORT, debug=False)
