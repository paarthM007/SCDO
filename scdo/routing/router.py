"""
router.py - High-level routing API with cargo-aware CTR routing.
SCDO Logistics Engine v3.0: Multi-factor logistics modeling.

Supports:
  - Product-type cargo restrictions  
  - Budget constraint pruning
  - Feasibility Index (F_idx) computation
  - User preference toggle (omega: 0=time, 1=cost)
"""
import time
import logging
from typing import List, Optional, Set
from scdo.routing.cities_data import get_all_nodes
from scdo.routing.graph import (
    GlobalRoutingGraph, build_graph, dijkstra, find_node_id,
    get_all_city_names, fmt_time, MODE_SETS, MODE_ICONS,
    compute_feasibility_index, compute_edge_cost, compute_edge_time,
)
from scdo.config import (
    DEFAULT_PRODUCT_TYPE, DEFAULT_OMEGA,
    DEFAULT_MAX_BUDGET, DEFAULT_DEADLINE_H, CARGO_REQUIREMENTS,
)
from scdo.simulation.crisis_manager import CrisisManager

logger = logging.getLogger(__name__)

_GRAPH: Optional[GlobalRoutingGraph] = None

# CARGO_REQUIREMENTS now imported from config.py


def get_graph() -> GlobalRoutingGraph:
    global _GRAPH
    if _GRAPH is None:
        logger.info("[router] Building global routing graph...")
        t0 = time.time()
        _GRAPH = build_graph(get_all_nodes())
        logger.info(f"[router] Graph ready in {time.time()-t0:.1f}s — {len(_GRAPH.nodes)} nodes")
    return _GRAPH


def _build_result(graph, src_id, dst_id, path_edges, mode_pref, objective,
                  # v3.0 shipment context
                  product_type=None, budget=None, deadline_h=None,
                  omega=None, risk_score=0.0):
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
                              "time_h": e["time_h"],
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

    result = {
        "origin": src_node["name"], "origin_id": src_id,
        "destination": dst_node["name"], "destination_id": dst_id,
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
    
    # ── v3.0: Background Graph Context ──
    # Gather edges adjacent to path nodes for geographic context rendering
    bg_edges = []
    if path_edges:
        path_nodes = {e["from_id"] for e in path_edges} | {e["to_id"] for e in path_edges}
        seen_edges = set()
        for nid in path_nodes:
            for edge in graph.neighbours(nid):
                # Unique edge identifier
                e_id = tuple(sorted([nid, edge["to"]])) + (edge["mode"],)
                if e_id not in seen_edges:
                    seen_edges.add(e_id)
                    # Don't add edges that are already in path_edges
                    is_path_edge = any(
                        (pe["from_id"] == nid and pe["to_id"] == edge["to"] and pe["mode"] == edge["mode"]) or
                        (pe["to_id"] == nid and pe["from_id"] == edge["to"] and pe["mode"] == edge["mode"])
                        for pe in path_edges
                    )
                    if not is_path_edge:
                        n_to = graph.nodes[edge["to"]]
                        n_from = graph.nodes[nid]
                        bg_edges.append({
                            "from_id": nid, "to_id": edge["to"],
                            "from_lat": n_from["lat"], "from_lon": n_from["lon"],
                            "to_lat": n_to["lat"], "to_lon": n_to["lon"],
                            "mode": edge["mode"]
                        })
    result["background_edges"] = bg_edges

    # ── v3.0: Shipment Context ──
    result["shipment"] = {
        "product_type": product_type or DEFAULT_PRODUCT_TYPE,
        "omega": omega if omega is not None else DEFAULT_OMEGA,
        "risk_score": round(risk_score, 4),
    }

    # ── v3.0: Feasibility Index ──
    effective_budget = budget if budget is not None else DEFAULT_MAX_BUDGET
    effective_deadline = deadline_h if deadline_h is not None else DEFAULT_DEADLINE_H
    f_idx = compute_feasibility_index(total_cost, total_h, effective_budget, effective_deadline)
    result["feasibility_index"] = f_idx

    # Determine feasibility warnings
    warnings = []
    if budget is not None and total_cost > budget:
        warnings.append(f"Over Budget: ${total_cost:.0f} > ${budget:.0f}")
    if deadline_h is not None and total_h > deadline_h:
        warnings.append(f"Over Deadline: {fmt_time(total_h)} > {fmt_time(deadline_h)}")
    if warnings:
        result["feasibility_warnings"] = warnings

    return result


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
               objective="FASTEST", blocked_nodes=None,
               # ── v3.0 CTR shipment parameters ──
               product_type=None, risk_score=0.0,
               omega=None, max_budget=None, deadline_h=None,
               cargo_type="STANDARD"):
    """
    Find a single route between two city names.
    Supports blocked_nodes for Functionality 2.
    
    v3.0: When product_type is provided, uses CTR Tensor
    dynamic edge weighting with cargo-aware constraint pruning.
    Phase 2: Uses cargo_type for Dynamic Cargo Weighting (Multi-Objective).
    """
    graph = get_graph()
    src_id = find_node_id(graph, origin)
    dst_id = find_node_id(graph, destination)
    if not src_id: return {"error": f"Origin '{origin}' not found"}
    if not dst_id: return {"error": f"Destination '{destination}' not found"}

    allowed = MODE_SETS.get(mode_pref.upper(), {"HIGHWAY", "SEA", "AIR"})

    # Resolve blocked node names to IDs
    cm = CrisisManager()
    
    all_blocked_names = set(blocked_nodes or [])
    all_blocked_names.update(cm.banned_nodes)

    blocked_ids = set()
    for bn in all_blocked_names:
        bid = find_node_id(graph, bn)
        if bid:
            blocked_ids.add(bid)
        else:
            logger.warning(f"Blocked node '{bn}' not found in graph, skipping")

    # ── v3.0: Map objective to omega if not provided ──
    if omega is None:
        obj_up = objective.upper()
        if obj_up == "CHEAPEST":
            omega = 1.0   # 100% Cost focus
        elif obj_up == "FASTEST":
            omega = 0.0   # 100% Time focus
        elif obj_up == "BALANCED":
            omega = 0.5   # 50/50 balance
        else:
            omega = 0.5

    try:
        _, path_edges = dijkstra(
            graph, src_id, dst_id, allowed, objective, blocked_ids,
            product_type=product_type,
            risk_score=risk_score, omega=omega, max_budget=None,
            deadline_h=None, cargo_type=cargo_type
        )
    except ValueError as e:
        return {"error": str(e)}

    if not path_edges:
        msg = "No route found"
        if blocked_ids:
            msg += f" (avoiding {len(blocked_ids)} blocked nodes)"
        if product_type and product_type != "general":
            msg += f" for cargo type '{product_type}'"
        return {"origin": graph.nodes[src_id]["name"],
                "destination": graph.nodes[dst_id]["name"], "error": msg}

    result = _build_result(
        graph, src_id, dst_id, path_edges, mode_pref, objective,
        product_type=product_type,
        budget=max_budget, deadline_h=deadline_h,
        omega=omega, risk_score=risk_score,
    )
    if blocked_ids:
        result["blocked_nodes"] = [graph.nodes[bid]["name"] for bid in blocked_ids if bid in graph.nodes]
    return result


def find_alternate_route(origin, destination, blocked_nodes,
                         cargo_type="general", mode_pref=None,
                         # ── v3.0 CTR parameters ──
                         product_type=None,
                         budget=None, deadline_h=None, omega=None):
    """
    Functionality 2: Find best alternate route avoiding blocked cities.
    Returns comparison of fastest, cheapest, balanced routes.
    
    v3.0: Forwards CTR shipment parameters to each sub-query.
    """
    CARGO_MODE_MAP = {
        "frozen_food": "AIR", "perishable": "AIR", "live_animals": "AIR",
        "pharmaceuticals": "AIR", "bulk_commodity": "SEA", "hazmat": "LAND_SEA",
        "vehicles": "SEA", "general": "BEST", "electronics": "BEST",
    }
    
    PHASE2_MAP = {
        "frozen_food": "PERISHABLE", "perishable": "PERISHABLE", "live_animals": "PERISHABLE",
        "pharmaceuticals": "PERISHABLE", "bulk_commodity": "BULK", "hazmat": "STANDARD",
        "vehicles": "STANDARD", "general": "STANDARD", "electronics": "HIGH_VALUE",
    }
    
    # Use BEST by default to allow diversification across modes.
    effective_mode = mode_pref or "BEST"
    effective_product = product_type or cargo_type
    phase_2_cargo = PHASE2_MAP.get(cargo_type, "STANDARD")
    eff_omega = omega if omega is not None else 0.5

    # We will find 3 distinct routes using the SAME omega preference,
    # as requested, and then rank them by their actual metrics.
    
    # 1. Primary Balanced Route (Best for the given omega)
    r_primary = find_route(
        origin, destination, effective_mode, "BALANCED", blocked_nodes,
        product_type=effective_product,
        risk_score=0.0, omega=eff_omega, max_budget=budget, deadline_h=deadline_h,
        cargo_type=phase_2_cargo
    )
    
    candidates = []
    if "error" not in r_primary:
        candidates.append(r_primary)

    # 2. Find Alternative 1 (Try a different primary mode for diversity)
    r_alt1 = {"error": "No mode-switched alternative found"}
    if candidates:
        primary_modes = candidates[0].get("modes_used", [])
        alt_mode = "BEST"
        if "AIR" in primary_modes:
            alt_mode = "SEA" # Force a sea/land route if primary was Air
        elif "SEA" in primary_modes:
            alt_mode = "AIR" # Force an air route if primary was Sea
            
        alt_mode = "SEA" if "AIR" in primary_modes else "AIR"
        r_alt1 = find_route(
            origin, destination, alt_mode, "BALANCED", blocked_nodes,
            product_type=effective_product,
            risk_score=0.0, omega=eff_omega, max_budget=budget, deadline_h=deadline_h,
            cargo_type=phase_2_cargo
        )
        if "error" not in r_alt1:
            candidates.append(r_alt1)

    # 3. Find Alternative 2 (Force a different path via node blocking)
    r_alt2 = {"error": "No secondary alternative found"}
    if candidates:
        # Collect all nodes from all successful candidates so far
        nodes_to_avoid = set(blocked_nodes or [])
        for c in candidates:
            for e in c.get("path_edges", []):
                if e["from"] != origin and e["from"] != destination:
                    nodes_to_avoid.add(e["from"])
        
        # Identify if we are stuck with only 1-hop paths so far
        is_stuck_with_1_hop = all(len(c.get("path_edges", [])) == 1 for c in candidates)
        
        # If we lack variety or are stuck with direct legs, force a multi-hop search
        if len(candidates) < 2 or is_stuck_with_1_hop:
            # Force block a pool of major hubs to see if a multi-hop route exists
            for hub in ["Dubai", "Singapore", "Hong Kong", "Istanbul", "Mumbai", "London", "Doha"]:
                if hub != origin and hub != destination:
                    nodes_to_avoid.add(hub)

        r_alt2 = find_route(
            origin, destination, effective_mode, "BALANCED", list(nodes_to_avoid),
            product_type=effective_product,
            risk_score=0.0, omega=eff_omega, max_budget=budget, deadline_h=deadline_h,
            cargo_type=phase_2_cargo
        )
    
    if "error" not in r_alt2:
        candidates.append(r_alt2)

    # 4. Final Selection and Ranking
    # Filter for uniqueness (include mode in uniqueness key)
    unique_candidates = []
    seen_paths = set()
    for c in candidates:
        if "error" in c: continue
        # Path signature includes nodes AND modes
        path_sig = "|".join([f"{e['to']}:{e['mode']}" for e in c.get("path_edges", [])])
        if path_sig not in seen_paths:
            unique_candidates.append(c)
            seen_paths.add(path_sig)

    # If we still only have one, try one last time with a slightly different omega 
    # to see if that reveals a different edge preference in the CTR tensor
    if len(unique_candidates) < 2:
        for test_omega in [0.1, 0.9]:
            r_last = find_route(
                origin, destination, effective_mode, "BALANCED", blocked_nodes,
                product_type=effective_product,
                risk_score=0.0, omega=test_omega, max_budget=budget, deadline_h=deadline_h,
                cargo_type=phase_2_cargo
            )
            if "error" not in r_last:
                path_sig = "|".join([f"{e['to']}:{e['mode']}" for e in r_last.get("path_edges", [])])
                if path_sig not in seen_paths:
                    unique_candidates.append(r_last)
                    seen_paths.add(path_sig)
                    if len(unique_candidates) >= 3: break

    # Map to result slots
    if not unique_candidates:
        return {
            "fastest": {"error": "No routes found"},
            "cheapest": {"error": "No routes found"},
            "balanced": {"error": "No routes found"}
        }

    # Rank them
    # Balanced = the one found with the actual eff_omega (usually the first one)
    balanced = unique_candidates[0]
    
    # Sort by time for Fastest
    fastest = sorted(unique_candidates, key=lambda x: x.get("total_time_h", float('inf')))[0]
    # Sort by cost for Cheapest
    cheapest = sorted(unique_candidates, key=lambda x: x.get("total_cost_usd", float('inf')))[0]

    # Ensure variety in the slots if possible
    # (If we have 2 unique routes, don't show the same one in all 3 if we can avoid it)
    results = {
        "balanced": balanced,
        "fastest": fastest,
        "cheapest": cheapest
    }
    
    # If we have exactly 2 unique, assign the second one to the slot it fits best
    if len(unique_candidates) == 2:
        alt = unique_candidates[1]
        if alt["total_time_h"] < balanced["total_time_h"]:
            results["fastest"] = alt
        if alt["total_cost_usd"] < balanced["total_cost_usd"]:
            results["cheapest"] = alt

    graph = get_graph()
    src_id = find_node_id(graph, origin)
    dst_id = find_node_id(graph, destination)

    return {
        "origin": graph.nodes[src_id]["name"] if src_id else origin,
        "destination": graph.nodes[dst_id]["name"] if dst_id else destination,
        "blocked_nodes": blocked_nodes,
        "cargo_type": cargo_type,
        "effective_mode": effective_mode,
        # v3.0 shipment context echoed back
        "shipment_params": {
            "product_type": effective_product,
            "budget": budget,
            "deadline_h": deadline_h,
            "omega": omega,
        },
        "fastest": results.get("fastest"),
        "cheapest": results.get("cheapest"),
        "balanced": results.get("balanced"),
    }



def extract_simulation_params(route_result):
    """
    Extracts 'cities' and 'modes' lists from a find_route/find_alternate_route result
    to be used as input for the simulation engine.
    """
    if "path_edges" not in route_result:
        return None, None
    
    edges = route_result["path_edges"]
    if not edges:
        return None, None
    
    # Mode mapping: router modes -> simulation modes
    MODE_MAP = {
        "HIGHWAY": "road",
        "SEA": "ship",
        "AIR": "air"
    }
    
    cities = [edges[0]["from"]]
    modes = []
    
    for edge in edges:
        cities.append(edge["to"])
        modes.append(MODE_MAP.get(edge["mode"], "road"))
    
    return cities, modes, edges


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
