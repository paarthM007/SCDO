"""
graph_router.py — Multi-modal global routing graph
===================================================
Modes:  HIGHWAY  (land, ~65 km/h avg)
        SEA      (shipping, ~25 knots ≈ 46 km/h)
        AIR      (flight, ~850 km/h + 2 h overhead)

Objectives (tri-Dijkstra):
  FASTEST   — minimise total travel time
  CHEAPEST  — minimise total USD cost
  BALANCED  — weighted blend of time + cost

Cost rates (USD / km):
  HIGHWAY  $0.08   truck freight
  SEA      $0.007  bulk container shipping
  AIR      $0.45   air cargo
"""

from __future__ import annotations
import math
import heapq
from typing import Dict, List, Optional, Tuple

from cities_data import get_all_nodes


# ── tuneable constants ────────────────────────────────────────
MAX_HIGHWAY_KM       = 300    # max highway link (shows realistic intermediate cities)
MAX_CROSS_BORDER_KM  = 120    # max land cross-border link (adjacent countries only)
MAX_SEA_KM           = 8_000  # max direct sea route (km)
MAX_AIR_KM           = 12_000 # max direct air route (km)

AVG_HIGHWAY_KMH = 65
AVG_SEA_KMH     = 46     # 25 knots
AVG_AIR_KMH     = 850
AIR_OVERHEAD_H  = 2.0    # check-in, boarding, taxiing overhead (hours)

# Sea "ocean" groupings  — ports in the same ocean can connect directly
OCEAN_ZONES = {
    "Indian Ocean":   ["India","Sri Lanka","Maldives","Bangladesh","Myanmar",
                        "Pakistan","Oman","Yemen","Saudi Arabia","UAE","Bahrain",
                        "Qatar","Kuwait","Iran","Iraq","Kenya","Tanzania",
                        "Mozambique","South Africa","Mauritius","Djibouti",
                        "Somalia","Australia"],
    "Pacific Ocean":  ["China","Japan","South Korea","Taiwan","Philippines",
                        "Indonesia","Malaysia","Singapore","Vietnam","Thailand",
                        "Cambodia","Australia","New Zealand","Papua New Guinea",
                        "Fiji","USA","Canada","Mexico","Peru","Chile",
                        "Ecuador","Colombia","Panama","Guam"],
    "Atlantic Ocean": ["USA","Canada","Mexico","Brazil","Argentina","Chile",
                        "Colombia","Venezuela","Uruguay","Guyana","Suriname",
                        "Nigeria","Ghana","Ivory Coast","Senegal","Cameroon",
                        "Angola","DRC","South Africa","Morocco","Algeria",
                        "Tunisia","Libya","France","Spain","Portugal",
                        "UK","Netherlands","Belgium","Germany","Denmark",
                        "Norway","Sweden","Ireland"],
    "Mediterranean":  ["Spain","France","Italy","Greece","Turkey","Lebanon",
                        "Israel","Egypt","Libya","Tunisia","Algeria","Morocco",
                        "Malta","Cyprus","Croatia","Slovenia","Montenegro",
                        "Albania","Syria"],
    "Baltic Sea":     ["Germany","Poland","Russia","Sweden","Finland",
                        "Denmark","Estonia","Latvia","Lithuania"],
    "Asia Pacific":   ["China","Japan","South Korea","Taiwan","Philippines",
                        "Indonesia","Malaysia","Singapore","Vietnam","Thailand",
                        "Cambodia","Myanmar","India","Sri Lanka","Bangladesh"],
}

# Build reverse map: country → ocean set
COUNTRY_TO_OCEANS: Dict[str, List[str]] = {}
for ocean, countries in OCEAN_ZONES.items():
    for c in countries:
        COUNTRY_TO_OCEANS.setdefault(c, []).append(ocean)


# ═══════════════════════════════════════════════════════════════
#  Haversine distance
# ═══════════════════════════════════════════════════════════════

def haversine(lat1, lon1, lat2, lon2) -> float:
    """Return distance in km between two lat/lon points."""
    R = 6371.0
    φ1, φ2 = math.radians(lat1), math.radians(lat2)
    Δφ = math.radians(lat2 - lat1)
    Δλ = math.radians(lon2 - lon1)
    a = math.sin(Δφ/2)**2 + math.cos(φ1)*math.cos(φ2)*math.sin(Δλ/2)**2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


# ── Cost rates USD/km ────────────────────────────────────────
COST_PER_KM = {
    "HIGHWAY": 0.08,    # truck freight
    "SEA":     0.007,   # container ship
    "AIR":     0.45,    # air cargo
}
# Fixed overhead costs (USD) per mode-switch / booking
MODE_FIXED_COST = {
    "HIGHWAY": 0,
    "SEA":     120,     # port handling fees
    "AIR":     80,      # airport handling fees
}


def travel_time_h(dist_km: float, mode: str) -> float:
    """Return approximate travel time in hours."""
    if mode == "HIGHWAY":
        return dist_km / AVG_HIGHWAY_KMH
    if mode == "SEA":
        return dist_km / AVG_SEA_KMH
    if mode == "AIR":
        return dist_km / AVG_AIR_KMH + AIR_OVERHEAD_H
    return dist_km / 50


def travel_cost_usd(dist_km: float, mode: str) -> float:
    """Return estimated freight cost in USD."""
    return dist_km * COST_PER_KM.get(mode, 0.08)


# ═══════════════════════════════════════════════════════════════
#  Graph (adjacency list)
# ═══════════════════════════════════════════════════════════════

class GlobalRoutingGraph:
    def __init__(self):
        self.nodes: Dict[str, dict] = {}  # id → node_dict
        self.adj: Dict[str, List[dict]]  = {}  # id → list of {to, mode, dist_km, time_h}

    def add_node(self, node: dict):
        self.nodes[node["id"]] = node
        if node["id"] not in self.adj:
            self.adj[node["id"]] = []

    def add_edge(self, id_a: str, id_b: str, mode: str, dist_km: float):
        t = travel_time_h(dist_km, mode)
        c = travel_cost_usd(dist_km, mode)
        edge_a = {"to": id_b, "mode": mode, "dist_km": round(dist_km, 1),
                  "time_h": round(t, 4), "cost_usd": round(c, 2)}
        edge_b = {"to": id_a, "mode": mode, "dist_km": round(dist_km, 1),
                  "time_h": round(t, 4), "cost_usd": round(c, 2)}
        self.adj[id_a].append(edge_a)
        self.adj[id_b].append(edge_b)

    def neighbours(self, node_id: str) -> List[dict]:
        return self.adj.get(node_id, [])


# ═══════════════════════════════════════════════════════════════
#  Graph builder
# ═══════════════════════════════════════════════════════════════

def build_graph() -> GlobalRoutingGraph:
    g = GlobalRoutingGraph()
    all_nodes = get_all_nodes()
    for n in all_nodes:
        g.add_node(n)

    node_ids = list(g.nodes.keys())
    n_total  = len(node_ids)
    print(f"[graph] Building graph for {n_total} nodes…")

    # Categorise once
    ports    = [nid for nid in node_ids if g.nodes[nid]["is_port"]]
    airports = [nid for nid in node_ids if g.nodes[nid]["is_airport"]]

    # ── 1. HIGHWAY edges ────────────────────────────────────────
    print("[graph] Adding HIGHWAY edges…")
    for i in range(n_total):
        na = g.nodes[node_ids[i]]
        for j in range(i + 1, n_total):
            nb = g.nodes[node_ids[j]]
            d = haversine(na["lat"], na["lon"], nb["lat"], nb["lon"])
            if na["country"] == nb["country"]:
                # Same country — use standard highway threshold
                if d <= MAX_HIGHWAY_KM:
                    g.add_edge(node_ids[i], node_ids[j], "HIGHWAY", d)
            else:
                # Cross-border — only allow very short links (neighbouring border towns)
                if d <= MAX_CROSS_BORDER_KM:
                    g.add_edge(node_ids[i], node_ids[j], "HIGHWAY", d)

    # ── 2. SEA edges ─────────────────────────────────────────────
    # SEA edges ONLY between ports in DIFFERENT countries.
    # Within-country sea is never used — highway is always preferred.
    print("[graph] Adding SEA edges…")
    for i in range(len(ports)):
        pa = g.nodes[ports[i]]
        for j in range(i + 1, len(ports)):
            pb = g.nodes[ports[j]]
            # No same-country sea routes
            if pa["country"] == pb["country"]:
                continue
            d = haversine(pa["lat"], pa["lon"], pb["lat"], pb["lon"])
            if d > MAX_SEA_KM:
                continue
            oceans_a = set(COUNTRY_TO_OCEANS.get(pa["country"], []))
            oceans_b = set(COUNTRY_TO_OCEANS.get(pb["country"], []))
            shared   = oceans_a & oceans_b
            if shared or d < 2000:
                g.add_edge(ports[i], ports[j], "SEA", d)

    # ── 3. AIR edges ─────────────────────────────────────────────
    print("[graph] Adding AIR edges…")
    # Major hub airports (IATA hubs)
    MAJOR_HUBS = {
        "new_delhi","mumbai","london","new_york","dubai","singapore",
        "hong_kong","amsterdam","paris","frankfurt","chicago","los_angeles",
        "tokyo","beijing","shanghai","sydney","johannesburg","dubai",
        "istanbul","doha","abu_dhabi","seoul","bangkok","kuala_lumpur",
        "toronto","houston","miami","moscow","cairo","nairobi",
        "sao_paulo","buenos_aires","santiago","bogota",
    }

    for i in range(len(airports)):
        pa = g.nodes[airports[i]]
        for j in range(i + 1, len(airports)):
            pb = g.nodes[airports[j]]
            d = haversine(pa["lat"], pa["lon"], pb["lat"], pb["lon"])
            if d > MAX_AIR_KM:
                continue
            # Major hub ↔ anywhere within range
            if airports[i] in MAJOR_HUBS or airports[j] in MAJOR_HUBS:
                g.add_edge(airports[i], airports[j], "AIR", d)
            elif d <= 3000:
                # Regional airports connect within 3000 km
                g.add_edge(airports[i], airports[j], "AIR", d)

    print(f"[graph] Done. Edges: {sum(len(v) for v in g.adj.values()) // 2}")
    return g


# ═══════════════════════════════════════════════════════════════
#  Objective weight functions
# ═══════════════════════════════════════════════════════════════
# BALANCED: normalise time + cost to comparable scale.
# TIME reference  : 1 hour   ~ $50 equivalent   (opportunity cost)
# COST reference  : $1       ~ 0.02 h equivalent
# balanced_weight = time_h + cost_usd / 50

BALANCED_USD_PER_H = 50.0   # $50 per hour of transit = opportunity cost


def _edge_weight(edge: dict, objective: str) -> float:
    if objective == "FASTEST":
        return edge["time_h"]
    if objective == "CHEAPEST":
        return edge["cost_usd"]
    # BALANCED: unified "cost" in equivalent-USD
    return edge["time_h"] * BALANCED_USD_PER_H + edge["cost_usd"]


# ═══════════════════════════════════════════════════════════════
#  Dijkstra — generalised for any objective
# ═══════════════════════════════════════════════════════════════

def dijkstra(graph: GlobalRoutingGraph, src_id: str, dst_id: str,
             allowed_modes: Optional[set] = None,
             objective: str = "FASTEST") -> Tuple[float, List[dict]]:
    """
    objective: "FASTEST" | "CHEAPEST" | "BALANCED"
    Returns (total_weight, path_edges).
    path_edges: list of {from, to, mode, dist_km, time_h, cost_usd}
    """
    if src_id not in graph.nodes:
        raise ValueError(f"Source node '{src_id}' not found in graph")
    if dst_id not in graph.nodes:
        raise ValueError(f"Destination node '{dst_id}' not found in graph")

    dist   = {nid: float("inf") for nid in graph.nodes}
    prev   = {}   # nid → (prev_nid, edge_dict)
    dist[src_id] = 0.0
    heap = [(0.0, src_id)]

    while heap:
        cur_w, cur = heapq.heappop(heap)
        if cur_w > dist[cur]:
            continue
        if cur == dst_id:
            break
        for edge in graph.neighbours(cur):
            mode = edge["mode"]
            if allowed_modes and mode not in allowed_modes:
                continue
            nb    = edge["to"]
            new_w = cur_w + _edge_weight(edge, objective)
            if new_w < dist[nb]:
                dist[nb] = new_w
                prev[nb] = (cur, edge)
                heapq.heappush(heap, (new_w, nb))

    if dist[dst_id] == float("inf"):
        return float("inf"), []

    # Reconstruct path
    path_edges = []
    cur = dst_id
    while cur in prev:
        p, edge = prev[cur]
        path_edges.append({
            "from":     graph.nodes[p]["name"],
            "from_id":  p,
            "to":       graph.nodes[cur]["name"],
            "to_id":    cur,
            "mode":     edge["mode"],
            "dist_km":  edge["dist_km"],
            "time_h":   round(edge["time_h"], 2),
            "cost_usd": edge["cost_usd"],
        })
        cur = p
    path_edges.reverse()
    return dist[dst_id], path_edges


# ═══════════════════════════════════════════════════════════════
#  Fuzzy city lookup
# ═══════════════════════════════════════════════════════════════

def find_node_id(graph: GlobalRoutingGraph, query: str) -> Optional[str]:
    """
    Find best matching node for a plain-text city query.
    Returns node_id or None.
    """
    q = query.lower().strip()
    # Exact match on id
    qid = q.replace(" ", "_").replace("-", "_").replace("'", "")
    if qid in graph.nodes:
        return qid
    # Exact match on name
    for nid, node in graph.nodes.items():
        if node["name"].lower() == q:
            return nid
    # Prefix / substring match on name
    matches = []
    for nid, node in graph.nodes.items():
        name_l = node["name"].lower()
        if name_l.startswith(q) or q in name_l:
            matches.append((len(name_l), nid))   # prefer shorter (more exact) names
    if matches:
        matches.sort()
        return matches[0][1]
    # Fuzzy: token overlap
    q_tokens = set(q.split())
    best_score, best_id = 0, None
    for nid, node in graph.nodes.items():
        name_tokens = set(node["name"].lower().split())
        score = len(q_tokens & name_tokens)
        if score > best_score:
            best_score = score
            best_id = nid
    return best_id if best_score > 0 else None


# ═══════════════════════════════════════════════════════════════
#  High-level route function
# ═══════════════════════════════════════════════════════════════

MODE_SETS = {
    "BEST":     {"HIGHWAY", "SEA", "AIR"},
    "HIGHWAY":  {"HIGHWAY"},
    "SEA":      {"HIGHWAY", "SEA"},
    "AIR":      {"HIGHWAY", "AIR"},
    "LAND_SEA": {"HIGHWAY", "SEA"},
    "LAND_AIR": {"HIGHWAY", "AIR"},
}


def find_route(graph: GlobalRoutingGraph,
               origin: str, destination: str,
               mode_pref: str = "BEST",
               objective: str = "FASTEST") -> dict:
    """
    Find a single route between two city names.
    mode_pref : which transport modes are allowed
    objective : FASTEST | CHEAPEST | BALANCED
    """
    src_id = find_node_id(graph, origin)
    dst_id = find_node_id(graph, destination)

    if not src_id:
        return {"error": f"Origin city '{origin}' not found"}
    if not dst_id:
        return {"error": f"Destination city '{destination}' not found"}

    src_name = graph.nodes[src_id]["name"]
    dst_name = graph.nodes[dst_id]["name"]
    allowed  = MODE_SETS.get(mode_pref.upper(), {"HIGHWAY", "SEA", "AIR"})

    _, path_edges = dijkstra(graph, src_id, dst_id, allowed, objective)

    if not path_edges:
        return {
            "origin":      src_name,
            "destination": dst_name,
            "error":       "No route found between these cities with selected transport modes",
        }

    return _build_result(graph, src_id, dst_id, path_edges, mode_pref, objective)


def find_best_paths(graph: GlobalRoutingGraph,
                    origin: str, destination: str,
                    allowed_modes: Optional[set] = None) -> dict:
    """
    Run Dijkstra three times (FASTEST / CHEAPEST / BALANCED)
    and return all three routes with a comparison table.
    """
    src_id = find_node_id(graph, origin)
    dst_id = find_node_id(graph, destination)

    if not src_id:
        return {"error": f"Origin city '{origin}' not found"}
    if not dst_id:
        return {"error": f"Destination city '{destination}' not found"}

    modes = allowed_modes or {"HIGHWAY", "SEA", "AIR"}
    results = {}

    for obj in ("FASTEST", "CHEAPEST", "BALANCED"):
        _, edges = dijkstra(graph, src_id, dst_id, modes, obj)
        if edges:
            results[obj] = _build_result(graph, src_id, dst_id, edges, "BEST", obj)
        else:
            results[obj] = {"error": "No route found"}

    # ── comparison table ──────────────────────────────────────
    comparison = []
    for obj, r in results.items():
        if "error" not in r:
            comparison.append({
                "objective":        obj,
                "total_time_h":     r["total_time_h"],
                "total_time_readable": r["total_time_readable"],
                "total_cost_usd":   r["total_cost_usd"],
                "total_distance_km":r["total_distance_km"],
                "num_hops":         r["num_hops"],
                "modes_used":       r["modes_used"],
                "recommendation":   _recommendation(obj),
            })

    src_node = graph.nodes[src_id]
    dst_node = graph.nodes[dst_id]
    return {
        "origin":           graph.nodes[src_id]["name"],
        "origin_coords":    {"lat": src_node["lat"], "lon": src_node["lon"]},
        "destination":      graph.nodes[dst_id]["name"],
        "dest_coords":      {"lat": dst_node["lat"], "lon": dst_node["lon"]},
        "comparison":       comparison,
        "fastest":          results.get("FASTEST"),
        "cheapest":         results.get("CHEAPEST"),
        "balanced":         results.get("BALANCED"),
    }


def _recommendation(obj: str) -> str:
    return {
        "FASTEST":  "Use when speed is critical (perishables, urgent shipments)",
        "CHEAPEST": "Use for bulk/non-urgent cargo where cost dominates",
        "BALANCED": "Best overall trade-off — recommended for general cargo",
    }[obj]


def _build_result(graph, src_id, dst_id, path_edges, mode_pref, objective) -> dict:
    """Build a full route result dict from path edges."""
    total_km   = sum(e["dist_km"]  for e in path_edges)
    total_h    = sum(e["time_h"]   for e in path_edges)
    total_cost = sum(e["cost_usd"] for e in path_edges)
    waypoints  = build_waypoints(graph, path_edges)
    segments   = build_segments(path_edges)

    # Add cost to segments
    for seg in segments:
        seg["cost_usd"] = round(sum(
            e["cost_usd"] for e in path_edges if e["mode"] == seg["mode"]
        ), 2)

    return {
        "origin":              graph.nodes[src_id]["name"],
        "origin_id":           src_id,
        "origin_coords":       {"lat": graph.nodes[src_id]["lat"], "lon": graph.nodes[src_id]["lon"]},
        "destination":         graph.nodes[dst_id]["name"],
        "destination_id":      dst_id,
        "dest_coords":         {"lat": graph.nodes[dst_id]["lat"], "lon": graph.nodes[dst_id]["lon"]},
        "objective":           objective,
        "mode_preference":     mode_pref,
        "total_distance_km":   round(total_km, 1),
        "total_time_h":        round(total_h, 2),
        "total_time_readable": _fmt_time(total_h),
        "total_cost_usd":      round(total_cost, 2),
        "cost_breakdown": {
            m: round(sum(e["cost_usd"] for e in path_edges if e["mode"] == m), 2)
            for m in {e["mode"] for e in path_edges}
        },
        "modes_used":          sorted({e["mode"] for e in path_edges}),
        "num_hops":            len(path_edges),
        "waypoints":           waypoints,
        "segments":            segments,
        "path_edges":          path_edges,
    }


def build_waypoints(graph: GlobalRoutingGraph, path_edges: List[dict]) -> List[dict]:
    """Build ordered list of waypoints (lat/lon + name) from path edges."""
    if not path_edges:
        return []
    pts = []
    # First node
    first_id = path_edges[0]["from_id"]
    n = graph.nodes[first_id]
    pts.append({"name": n["name"], "lat": n["lat"], "lon": n["lon"],
                "is_port": n["is_port"], "is_airport": n["is_airport"]})
    for e in path_edges:
        nid = e["to_id"]
        n = graph.nodes[nid]
        pts.append({"name": n["name"], "lat": n["lat"], "lon": n["lon"],
                    "mode": e["mode"], "dist_km": e["dist_km"],
                    "is_port": n["is_port"], "is_airport": n["is_airport"]})
    return pts


def build_segments(path_edges: List[dict]) -> List[dict]:
    """Group consecutive edges by mode into segments."""
    if not path_edges:
        return []
    segments = []
    cur_mode  = path_edges[0]["mode"]
    seg_start = path_edges[0]["from"]
    seg_edges = []

    for e in path_edges:
        if e["mode"] == cur_mode:
            seg_edges.append(e)
        else:
            segments.append(_make_seg(cur_mode, seg_start, seg_edges))
            cur_mode  = e["mode"]
            seg_start = e["from"]
            seg_edges = [e]
    if seg_edges:
        segments.append(_make_seg(cur_mode, seg_start, seg_edges))
    return segments


def _make_seg(mode: str, start: str, edges: List[dict]) -> dict:
    dist = sum(e["dist_km"]  for e in edges)
    time = sum(e["time_h"]   for e in edges)
    cost = sum(e["cost_usd"] for e in edges)
    cities = [edges[0]["from"]] + [e["to"] for e in edges]
    return {
        "mode":          mode,
        "from":          start,
        "to":            edges[-1]["to"],
        "cities":        cities,
        "dist_km":       round(dist, 1),
        "time_h":        round(time, 2),
        "time_readable": _fmt_time(time),
        "cost_usd":      round(cost, 2),
        "icon":          MODE_ICONS[mode],
    }


MODE_ICONS = {
    "HIGHWAY": "🚛",
    "SEA":     "🚢",
    "AIR":     "✈️",
}


def _fmt_time(h: float) -> str:
    hours = int(h)
    mins  = int((h - hours) * 60)
    if hours >= 24:
        days  = hours // 24
        hours = hours % 24
        return f"{days}d {hours}h {mins}m"
    return f"{hours}h {mins}m"


# ═══════════════════════════════════════════════════════════════
#  Singleton graph (built once, shared across requests)
# ═══════════════════════════════════════════════════════════════
_GRAPH: Optional[GlobalRoutingGraph] = None


def get_graph() -> GlobalRoutingGraph:
    global _GRAPH
    if _GRAPH is None:
        _GRAPH = build_graph()
    return _GRAPH


def get_all_city_names(graph: GlobalRoutingGraph) -> List[dict]:
    return sorted(
        [{"id": nid, "name": n["name"], "region": n["region"], "country": n["country"]}
         for nid, n in graph.nodes.items()],
        key=lambda x: x["name"]
    )
