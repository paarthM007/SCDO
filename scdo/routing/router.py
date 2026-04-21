"""
router.py - High-level routing API with alternate route + blocked node support.
Implements Functionality 2: find alternate route avoiding blocked cities.
"""
import time
import logging
from typing import List, Optional, Set
from scdo.routing.cities_data import get_all_nodes
from scdo.routing.graph import (
    GlobalRoutingGraph, build_graph, dijkstra, find_node_id,
    get_all_city_names, fmt_time, MODE_SETS, MODE_ICONS
)

logger = logging.getLogger(__name__)

_GRAPH: Optional[GlobalRoutingGraph] = None

def get_graph() -> GlobalRoutingGraph:
    global _GRAPH
    if _GRAPH is None:
        logger.info("[router] Building global routing graph...")
        t0 = time.time()
        _GRAPH = build_graph(get_all_nodes())
        logger.info(f"[router] Graph ready in {time.time()-t0:.1f}s — {len(_GRAPH.nodes)} nodes")
    return _GRAPH


def _build_result(graph, src_id, dst_id, path_edges, mode_pref, objective):
    """Build a full route result dict from path edges."""
    total_km = sum(e["dist_km"] for e in path_edges)
    total_h = sum(e["time_h"] for e in path_edges)
    total_cost = sum(e["cost_usd"] for e in path_edges)

    # Build waypoints
    waypoints = []
    if path_edges:
        first = graph.nodes[path_edges[0]["from_id"]]
        waypoints.append({"name": first["name"], "lat": first["lat"], "lon": first["lon"],
                          "is_port": first["is_port"], "is_airport": first["is_airport"]})
        for e in path_edges:
            n = graph.nodes[e["to_id"]]
            waypoints.append({"name": n["name"], "lat": n["lat"], "lon": n["lon"],
                              "mode": e["mode"], "dist_km": e["dist_km"],
                              "is_port": n["is_port"], "is_airport": n["is_airport"]})

    # Build segments (group consecutive same-mode edges)
    segments = []
    if path_edges:
        cur_mode = path_edges[0]["mode"]
        seg_start = path_edges[0]["from"]
        seg_edges = []
        for e in path_edges:
            if e["mode"] == cur_mode:
                seg_edges.append(e)
            else:
                segments.append(_make_seg(cur_mode, seg_start, seg_edges))
                cur_mode = e["mode"]
                seg_start = e["from"]
                seg_edges = [e]
        if seg_edges:
            segments.append(_make_seg(cur_mode, seg_start, seg_edges))

    src_node = graph.nodes[src_id]
    dst_node = graph.nodes[dst_id]
    return {
        "origin": src_node["name"], "origin_id": src_id,
        "origin_coords": {"lat": src_node["lat"], "lon": src_node["lon"]},
        "destination": dst_node["name"], "destination_id": dst_id,
        "dest_coords": {"lat": dst_node["lat"], "lon": dst_node["lon"]},
        "objective": objective, "mode_preference": mode_pref,
        "total_distance_km": round(total_km, 1),
        "total_time_h": round(total_h, 2),
        "total_time_readable": fmt_time(total_h),
        "total_cost_usd": round(total_cost, 2),
        "modes_used": sorted({e["mode"] for e in path_edges}),
        "num_hops": len(path_edges),
        "waypoints": waypoints,
        "segments": segments,
        "path_edges": path_edges,
    }


def _make_seg(mode, start, edges):
    dist = sum(e["dist_km"] for e in edges)
    t = sum(e["time_h"] for e in edges)
    cost = sum(e["cost_usd"] for e in edges)
    cities = [edges[0]["from"]] + [e["to"] for e in edges]
    return {
        "mode": mode, "from": start, "to": edges[-1]["to"],
        "cities": cities, "dist_km": round(dist, 1),
        "time_h": round(t, 2), "time_readable": fmt_time(t),
        "cost_usd": round(cost, 2), "icon": MODE_ICONS.get(mode, "📦"),
    }


def find_route(origin, destination, mode_pref="BEST",
               objective="FASTEST", blocked_nodes=None):
    """
    Find a single route between two city names.
    Supports blocked_nodes for Functionality 2.
    """
    graph = get_graph()
    src_id = find_node_id(graph, origin)
    dst_id = find_node_id(graph, destination)
    if not src_id: return {"error": f"Origin '{origin}' not found"}
    if not dst_id: return {"error": f"Destination '{destination}' not found"}

    allowed = MODE_SETS.get(mode_pref.upper(), {"HIGHWAY", "SEA", "AIR"})

    # Resolve blocked node names to IDs
    blocked_ids = set()
    if blocked_nodes:
        for bn in blocked_nodes:
            bid = find_node_id(graph, bn)
            if bid:
                blocked_ids.add(bid)
            else:
                logger.warning(f"Blocked node '{bn}' not found in graph, skipping")

    try:
        _, path_edges = dijkstra(graph, src_id, dst_id, allowed, objective, blocked_ids)
    except ValueError as e:
        return {"error": str(e)}

    if not path_edges:
        msg = "No route found"
        if blocked_ids:
            msg += f" (avoiding {len(blocked_ids)} blocked nodes)"
        return {"origin": graph.nodes[src_id]["name"],
                "destination": graph.nodes[dst_id]["name"], "error": msg}

    result = _build_result(graph, src_id, dst_id, path_edges, mode_pref, objective)
    if blocked_ids:
        result["blocked_nodes"] = [graph.nodes[bid]["name"] for bid in blocked_ids if bid in graph.nodes]
    return result


def find_alternate_route(origin, destination, blocked_nodes,
                         cargo_type="general", mode_pref=None):
    """
    Functionality 2: Find best alternate route avoiding blocked cities.
    Returns comparison of fastest, cheapest, balanced routes.
    """
    CARGO_MODE_MAP = {
        "frozen_food": "AIR", "perishable": "AIR", "live_animals": "AIR",
        "pharmaceuticals": "AIR", "bulk_commodity": "SEA", "hazmat": "LAND_SEA",
        "vehicles": "SEA", "general": "BEST", "electronics": "BEST",
    }
    effective_mode = mode_pref or CARGO_MODE_MAP.get(cargo_type, "BEST")

    results = {}
    for obj in ("FASTEST", "CHEAPEST", "BALANCED"):
        r = find_route(origin, destination, effective_mode, obj, blocked_nodes)
        results[obj.lower()] = r

    graph = get_graph()
    src_id = find_node_id(graph, origin)
    dst_id = find_node_id(graph, destination)

    return {
        "origin": graph.nodes[src_id]["name"] if src_id else origin,
        "destination": graph.nodes[dst_id]["name"] if dst_id else destination,
        "blocked_nodes": blocked_nodes,
        "cargo_type": cargo_type,
        "effective_mode": effective_mode,
        "fastest": results.get("fastest"),
        "cheapest": results.get("cheapest"),
        "balanced": results.get("balanced"),
    }


def list_cities(query=None, country=None):
    """List all cities, optionally filtered."""
    graph = get_graph()
    all_c = get_all_city_names(graph)
    if query:
        q = query.lower()
        all_c = [c for c in all_c if q in c["name"].lower()]
    if country:
        ct = country.lower()
        all_c = [c for c in all_c if ct in c["country"].lower()]
    return all_c[:500]
