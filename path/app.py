"""
app.py — Global Route Graph Microservice
=========================================
Pure JSON API. No frontend.

Endpoints
---------
GET /api/route
    ?from=Mumbai&to=Rotterdam&mode=BEST
    → point-to-point shortest route

GET /api/combined-risk
    ?cities=Paris,Patna,Lucknow,Reykjavik&date=2026-03-31&cargo_type=frozen_food
    → full multi-city route chain with per-segment details

GET /api/cities
    ?q=mum           (optional substring filter)
    → list of all nodes (for autocomplete / discovery)

GET /api/city/<name>
    → metadata for a single city

GET /health
    → service liveness check
"""

from __future__ import annotations

import os
import time
from datetime import datetime
from functools import lru_cache
from typing import List

from flask import Flask, request, jsonify

from graph_router import get_graph, find_route, find_node_id, get_all_city_names, find_best_paths, MODE_SETS

app = Flask(__name__)

# ── build graph once at startup ───────────────────────────────
print("[startup] Loading global routing graph …")
t0 = time.time()
GRAPH = get_graph()
print(f"[startup] Graph ready in {time.time()-t0:.1f}s")


# ═══════════════════════════════════════════════════════════════
#  Helpers
# ═══════════════════════════════════════════════════════════════

CARGO_CONSTRAINTS = {
    "frozen_food":    {"max_sea_hours": 72,  "preferred_mode": "AIR",      "notes": "Cold-chain critical; prefer air for long hauls"},
    "perishable":     {"max_sea_hours": 120, "preferred_mode": "AIR",      "notes": "Refrigerated transport required"},
    "live_animals":   {"max_sea_hours": 48,  "preferred_mode": "AIR",      "notes": "Minimal transit time"},
    "pharmaceuticals":{"max_sea_hours": 168, "preferred_mode": "AIR",      "notes": "Temperature-controlled; air preferred"},
    "electronics":    {"max_sea_hours": None,"preferred_mode": "BEST",     "notes": "No time constraint; minimize cost"},
    "bulk_commodity": {"max_sea_hours": None,"preferred_mode": "SEA",      "notes": "Sea freight preferred for bulk"},
    "hazmat":         {"max_sea_hours": None,"preferred_mode": "LAND_SEA",  "notes": "Air transport restricted for hazmat"},
    "vehicles":       {"max_sea_hours": None,"preferred_mode": "SEA",      "notes": "RoRo sea shipping preferred"},
    "general":        {"max_sea_hours": None,"preferred_mode": "BEST",     "notes": "Standard multimodal routing"},
}

MODE_PRIORITY = {
    "frozen_food":    "AIR",
    "perishable":     "AIR",
    "live_animals":   "AIR",
    "pharmaceuticals":"AIR",
    "electronics":    "BEST",
    "bulk_commodity": "SEA",
    "hazmat":         "LAND_SEA",
    "vehicles":       "SEA",
    "general":        "BEST",
}


def _cargo_mode(cargo_type: str, explicit_mode: str | None) -> str:
    if explicit_mode:
        return explicit_mode.upper()
    return MODE_PRIORITY.get(cargo_type.lower().replace(" ", "_"), "BEST")


def _err(msg: str, code: int = 400):
    return jsonify({"error": msg, "status": "error"}), code


def _normalise_city(raw: str) -> str:
    """Replace underscores with spaces for lookup."""
    return raw.strip().replace("_", " ")


# ═══════════════════════════════════════════════════════════════
#  /health
# ═══════════════════════════════════════════════════════════════

@app.route("/health", methods=["GET"])
def health():
    return jsonify({
        "status":     "ok",
        "nodes":      len(GRAPH.nodes),
        "edges":      sum(len(v) for v in GRAPH.adj.values()) // 2,
        "timestamp":  datetime.utcnow().isoformat() + "Z",
    })


# ═══════════════════════════════════════════════════════════════
#  /api/cities
# ═══════════════════════════════════════════════════════════════

@app.route("/api/cities", methods=["GET"])
def api_cities():
    q       = request.args.get("q", "").lower().strip()
    country = request.args.get("country", "").lower().strip()
    all_c   = get_all_city_names(GRAPH)

    if q:
        all_c = [c for c in all_c if q in c["name"].lower()]
    if country:
        all_c = [c for c in all_c if country in c["country"].lower()]

    return jsonify({
        "count":  len(all_c),
        "cities": all_c[:500],   # cap at 500 for bandwidth
    })


# ═══════════════════════════════════════════════════════════════
#  /api/city/<name>
# ═══════════════════════════════════════════════════════════════

@app.route("/api/city/<name>", methods=["GET"])
def api_city(name: str):
    nid = find_node_id(GRAPH, _normalise_city(name))
    if not nid:
        return _err(f"City '{name}' not found")
    node = GRAPH.nodes[nid]
    neighbours = [
        {"city": GRAPH.nodes[e["to"]]["name"],
         "mode": e["mode"],
         "dist_km": e["dist_km"],
         "time_h":  e["time_h"]}
        for e in GRAPH.adj[nid]
    ]
    neighbours.sort(key=lambda x: x["dist_km"])
    return jsonify({
        **node,
        "neighbours_count": len(neighbours),
        "neighbours":       neighbours[:20],
    })


# ═══════════════════════════════════════════════════════════════
#  /api/route   — point-to-point
# ═══════════════════════════════════════════════════════════════

@app.route("/api/route", methods=["GET"])
def api_route():
    origin = request.args.get("from") or request.args.get("origin")
    dest   = request.args.get("to")   or request.args.get("destination")
    mode   = request.args.get("mode", "BEST").upper()
    cargo  = request.args.get("cargo_type", "general")

    if not origin:
        return _err("Provide ?from=CityName")
    if not dest:
        return _err("Provide ?to=CityName")

    effective_mode = _cargo_mode(cargo, mode if mode != "BEST" else None)

    result = find_route(GRAPH,
                        _normalise_city(origin),
                        _normalise_city(dest),
                        effective_mode)

    if "error" in result:
        return _err(result["error"], 404)

    result["cargo_type"]       = cargo
    result["effective_mode"]   = effective_mode
    result["cargo_notes"]      = CARGO_CONSTRAINTS.get(cargo, {}).get("notes", "")
    result["generated_at"]     = datetime.utcnow().isoformat() + "Z"
    return jsonify(result)


# ═══════════════════════════════════════════════════════════════
#  /api/best-path  — compact: fastest vs cheapest
# ═══════════════════════════════════════════════════════════════

@app.route("/api/best-path", methods=["GET"])
def api_best_path():
    """
    Compact route comparison between 2 cities.
    Returns 5 distinct routing options (Fastest, Cheapest, Balanced, Highway-Only, Land & Sea)
    each showing only:
      - ordered city list  (the actual route)
      - total time
      - total cost (USD)
      - transport modes used

    Required:  ?from=CityA&to=CityB
    Optional:  ?mode=BEST|HIGHWAY|SEA|AIR|LAND_SEA|LAND_AIR
               ?cargo_type=frozen_food|bulk_commodity|...
    """
    origin = request.args.get("from") or request.args.get("origin")
    dest   = request.args.get("to")   or request.args.get("destination")
    mode   = request.args.get("mode", None)
    cargo  = request.args.get("cargo_type", "general")

    if not origin:
        return _err("Provide ?from=CityName")
    if not dest:
        return _err("Provide ?to=CityName")

    effective_mode = _cargo_mode(cargo, mode)
    allowed = MODE_SETS.get(effective_mode, {"HIGHWAY", "SEA", "AIR"})

    raw = find_best_paths(GRAPH,
                          _normalise_city(origin),
                          _normalise_city(dest),
                          allowed_modes=allowed)

    if "error" in raw:
        return _err(raw["error"], 404)

    def _compact(r):
        """Strip a full route result down to just what matters."""
        if not r or "error" in r:
            return {"error": r.get("error", "No route found")}
        # Build ordered city sequence with mode transitions annotated
        route_steps = []
        prev_mode = None
        for e in r.get("path_edges", []):
            if e["mode"] != prev_mode:
                route_steps.append(f"[{e['mode']}] {e['from']}")
                prev_mode = e["mode"]
            # always add destination of each hop, collapsed later
        # Deduplicated ordered city list
        cities = []
        prev_mode = None
        for e in r.get("path_edges", []):
            if not cities:
                cities.append({"city": e["from"], "via": e["mode"]})
            if e["mode"] != prev_mode and cities:
                cities[-1]["via"] = e["mode"]
                prev_mode = e["mode"]
            cities.append({"city": e["to"], "via": e["mode"]})

        # Simple flat city name list
        city_names = [r.get("origin")]
        prev_mode  = None
        for e in r.get("path_edges", []):
            if e["mode"] != prev_mode:
                city_names.append(f"──[{e['mode']}]──▶")
                prev_mode = e["mode"]
            city_names.append(e["to"])

        return {
            "route":       city_names,
            "total_time":  r["total_time_readable"],
            "total_cost":  f"${r['total_cost_usd']:,.2f}",
            "modes_used":  r["modes_used"],
            "hops":        r["num_hops"],
        }

    highway_raw = find_route(GRAPH, _normalise_city(origin), _normalise_city(dest), mode_pref="HIGHWAY", objective="FASTEST")
    surface_raw = find_route(GRAPH, _normalise_city(origin), _normalise_city(dest), mode_pref="LAND_SEA", objective="BALANCED")

    response = {
        "from":    raw["origin"],
        "to":      raw["destination"],
        "fastest": _compact(raw.get("fastest")),
        "cheapest":_compact(raw.get("cheapest")),
        "balanced":_compact(raw.get("balanced")),
        "highway_only": _compact(highway_raw),
        "surface_only": _compact(surface_raw),
    }
    return jsonify(response)


# ═══════════════════════════════════════════════════════════════
#  /api/combined-risk   — multi-city chain
# ═══════════════════════════════════════════════════════════════

@app.route("/api/combined-risk", methods=["GET"])
def api_combined_risk():
    """
    Example:
      /api/combined-risk?cities=Paris,Patna,Addis_Ababa,Lucknow&date=2026-03-31&cargo_type=frozen_food
    """
    cities_raw  = request.args.get("cities", "")
    cargo       = request.args.get("cargo_type", "general").lower().replace(" ", "_")
    mode_param  = request.args.get("mode", None)
    date_str    = request.args.get("date", datetime.utcnow().strftime("%Y-%m-%d"))

    if not cities_raw:
        return _err("Provide ?cities=City1,City2,City3,…")

    city_names: List[str] = [_normalise_city(c) for c in cities_raw.split(",") if c.strip()]
    if len(city_names) < 2:
        return _err("Provide at least 2 cities")

    effective_mode = _cargo_mode(cargo, mode_param)
    cargo_info     = CARGO_CONSTRAINTS.get(cargo, CARGO_CONSTRAINTS["general"])

    # ── route every consecutive pair ──────────────────────────
    legs       = []
    failed     = []
    total_km   = 0.0
    total_h    = 0.0
    all_modes  = set()
    full_waypoints: List[dict] = []

    for i in range(len(city_names) - 1):
        src = city_names[i]
        dst = city_names[i + 1]
        leg = find_route(GRAPH, src, dst, effective_mode)

        if "error" in leg:
            failed.append({"from": src, "to": dst, "error": leg["error"]})
            legs.append({"leg": i + 1, "from": src, "to": dst,
                         "status": "FAILED", "error": leg["error"]})
            continue

        total_km += leg["total_distance_km"]
        total_h  += leg["total_time_h"]
        all_modes.update(leg["modes_used"])

        # Deduplicate waypoints at junctions
        leg_wps = leg.get("waypoints", [])
        if full_waypoints and leg_wps:
            leg_wps = leg_wps[1:]   # skip first (= last of previous leg)
        full_waypoints.extend(leg_wps)

        legs.append({
            "leg":               i + 1,
            "from":              leg["origin"],
            "to":                leg["destination"],
            "status":            "OK",
            "distance_km":       leg["total_distance_km"],
            "time_h":            leg["total_time_h"],
            "time_readable":     leg["total_time_readable"],
            "num_hops":          leg["num_hops"],
            "modes_used":        leg["modes_used"],
            "segments":          leg["segments"],
            "waypoints":         leg["waypoints"],
        })

    if not legs or all(l["status"] == "FAILED" for l in legs):
        return _err("Could not find any routes between the provided cities", 404)

    # ── cargo time-constraint check ────────────────────────────
    warnings = []
    max_sea  = cargo_info.get("max_sea_hours")
    if max_sea:
        sea_h = sum(
            e["time_h"]
            for leg in legs if leg.get("status") == "OK"
            for seg in leg.get("segments", [])
            if seg["mode"] == "SEA"
            for e in [{"time_h": seg["time_h"]}]
        )
        if sea_h > max_sea:
            warnings.append(
                f"Total sea transit {sea_h:.1f}h exceeds {max_sea}h limit for {cargo}. "
                f"Consider switching to AIR mode."
            )

    # ── build summary ──────────────────────────────────────────
    ok_legs   = [l for l in legs if l.get("status") == "OK"]
    mode_breakdown = {}
    for leg in ok_legs:
        for seg in leg.get("segments", []):
            m = seg["mode"]
            mode_breakdown[m] = mode_breakdown.get(m, 0.0) + seg["dist_km"]

    response = {
        "status":              "ok",
        "query": {
            "cities":          city_names,
            "cargo_type":      cargo,
            "effective_mode":  effective_mode,
            "date":            date_str,
        },
        "summary": {
            "total_cities":       len(city_names),
            "total_legs":         len(legs),
            "successful_legs":    len(ok_legs),
            "failed_legs":        len(failed),
            "total_distance_km":  round(total_km, 1),
            "total_time_h":       round(total_h, 2),
            "total_time_readable": _fmt_time(total_h),
            "modes_used":         sorted(all_modes),
            "mode_distance_km":   {k: round(v, 1) for k, v in mode_breakdown.items()},
            "cargo_notes":        cargo_info.get("notes", ""),
            "warnings":           warnings,
        },
        "legs":           legs,
        "full_waypoints": full_waypoints,
        "generated_at":   datetime.utcnow().isoformat() + "Z",
    }

    if failed:
        response["failed_segments"] = failed

    return jsonify(response)


# ═══════════════════════════════════════════════════════════════
#  /api/search  — find nearest nodes to a lat/lon
# ═══════════════════════════════════════════════════════════════

@app.route("/api/search", methods=["GET"])
def api_search():
    q = request.args.get("q", "").strip()
    if not q:
        return _err("Provide ?q=CityName")
    all_c = get_all_city_names(GRAPH)
    ql = q.lower()
    matches = [c for c in all_c if ql in c["name"].lower()]
    matches.sort(key=lambda x: (not x["name"].lower().startswith(ql), len(x["name"])))
    return jsonify({"count": len(matches), "results": matches[:30]})


# ═══════════════════════════════════════════════════════════════
#  Helpers
# ═══════════════════════════════════════════════════════════════

def _fmt_time(h: float) -> str:
    hours = int(h)
    mins  = int((h - hours) * 60)
    if hours >= 24:
        days  = hours // 24
        hours = hours % 24
        return f"{days}d {hours}h {mins}m"
    return f"{hours}h {mins}m"


# ═══════════════════════════════════════════════════════════════
#  Entry point
# ═══════════════════════════════════════════════════════════════

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    print(f"\n[server] Listening on http://localhost:{port}")
    print("[server] Example calls:")
    print(f"  http://localhost:{port}/health")
    print(f"  http://localhost:{port}/api/route?from=Mumbai&to=Rotterdam&mode=BEST")
    print(f"  http://localhost:{port}/api/combined-risk?cities=Paris,Patna,Lucknow,Reykjavik&date=2026-03-31&cargo_type=frozen_food")
    print(f"  http://localhost:{port}/api/cities?q=mum")
    print(f"  http://localhost:{port}/api/city/Mumbai\n")
    print(f" http://localhost:5000/api/best-path?from=Mumbai&to=Rotterdam\n")
    app.run(host="0.0.0.0", port=port, debug=False)
