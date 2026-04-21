"""
graph.py - Multi-modal routing graph with Dijkstra + blocked-node support.
Ported from path/graph_router.py with blocked node extension.
"""
import math
import heapq
from typing import Dict, List, Optional, Set, Tuple

AVG_HIGHWAY_KMH = 65
AVG_SEA_KMH = 46
AVG_AIR_KMH = 850
AIR_OVERHEAD_H = 2.0

MAX_HIGHWAY_KM = 300
MAX_CROSS_BORDER_KM = 120
MAX_SEA_KM = 8000
MAX_AIR_KM = 12000

COST_PER_KM = {"HIGHWAY": 0.08, "SEA": 0.007, "AIR": 0.45}
MODE_FIXED_COST = {"HIGHWAY": 0, "SEA": 120, "AIR": 80}

OCEAN_ZONES = {
    "Indian Ocean": ["India","Sri Lanka","Bangladesh","Myanmar","Pakistan","Oman","Yemen","Saudi Arabia","UAE","Bahrain","Qatar","Kuwait","Iran","Iraq","Kenya","Tanzania","Mozambique","South Africa","Mauritius","Djibouti","Somalia","Australia"],
    "Pacific Ocean": ["China","Japan","South Korea","Taiwan","Philippines","Indonesia","Malaysia","Singapore","Vietnam","Thailand","Cambodia","Australia","New Zealand","USA","Canada","Mexico","Peru","Chile","Ecuador","Colombia","Panama"],
    "Atlantic Ocean": ["USA","Canada","Mexico","Brazil","Argentina","Chile","Colombia","Venezuela","Uruguay","Nigeria","Ghana","Senegal","Cameroon","Angola","South Africa","Morocco","Algeria","Tunisia","Libya","France","Spain","Portugal","UK","Netherlands","Belgium","Germany","Denmark","Norway","Sweden","Ireland"],
    "Mediterranean": ["Spain","France","Italy","Greece","Turkey","Lebanon","Israel","Egypt","Libya","Tunisia","Algeria","Morocco","Malta","Cyprus","Croatia","Slovenia"],
    "Baltic Sea": ["Germany","Poland","Russia","Sweden","Finland","Denmark","Estonia","Latvia","Lithuania"],
    "Asia Pacific": ["China","Japan","South Korea","Taiwan","Philippines","Indonesia","Malaysia","Singapore","Vietnam","Thailand","Cambodia","Myanmar","India","Sri Lanka","Bangladesh"],
}

COUNTRY_TO_OCEANS: Dict[str, List[str]] = {}
for ocean, countries in OCEAN_ZONES.items():
    for c in countries:
        COUNTRY_TO_OCEANS.setdefault(c, []).append(ocean)

MAJOR_HUBS = {
    "new_delhi","mumbai","london","new_york","dubai","singapore","hong_kong",
    "amsterdam","paris","frankfurt","chicago","los_angeles","tokyo","beijing",
    "shanghai","sydney","johannesburg","istanbul","doha","abu_dhabi","seoul",
    "bangkok","kuala_lumpur","toronto","houston","miami","moscow","cairo",
    "nairobi","sao_paulo","buenos_aires","santiago","bogota",
}

MODE_SETS = {
    "BEST": {"HIGHWAY","SEA","AIR"}, "HIGHWAY": {"HIGHWAY"},
    "SEA": {"HIGHWAY","SEA"}, "AIR": {"HIGHWAY","AIR"},
    "LAND_SEA": {"HIGHWAY","SEA"}, "LAND_AIR": {"HIGHWAY","AIR"},
}

MODE_ICONS = {"HIGHWAY": "🚛", "SEA": "🚢", "AIR": "✈️"}


def haversine(lat1, lon1, lat2, lon2) -> float:
    R = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lon2 - lon1)
    a = math.sin(dp/2)**2 + math.cos(p1)*math.cos(p2)*math.sin(dl/2)**2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

def travel_time_h(dist_km, mode):
    if mode == "HIGHWAY": return dist_km / AVG_HIGHWAY_KMH
    if mode == "SEA": return dist_km / AVG_SEA_KMH
    if mode == "AIR": return dist_km / AVG_AIR_KMH + AIR_OVERHEAD_H
    return dist_km / 50

def travel_cost_usd(dist_km, mode):
    return dist_km * COST_PER_KM.get(mode, 0.08)


class GlobalRoutingGraph:
    def __init__(self):
        self.nodes: Dict[str, dict] = {}
        self.adj: Dict[str, List[dict]] = {}

    def add_node(self, node):
        self.nodes[node["id"]] = node
        if node["id"] not in self.adj:
            self.adj[node["id"]] = []

    def add_edge(self, id_a, id_b, mode, dist_km):
        t = travel_time_h(dist_km, mode)
        c = travel_cost_usd(dist_km, mode)
        e_ab = {"to": id_b, "mode": mode, "dist_km": round(dist_km,1), "time_h": round(t,4), "cost_usd": round(c,2)}
        e_ba = {"to": id_a, "mode": mode, "dist_km": round(dist_km,1), "time_h": round(t,4), "cost_usd": round(c,2)}
        self.adj[id_a].append(e_ab)
        self.adj[id_b].append(e_ba)

    def neighbours(self, node_id):
        return self.adj.get(node_id, [])


def build_graph(all_nodes) -> GlobalRoutingGraph:
    g = GlobalRoutingGraph()
    for n in all_nodes:
        g.add_node(n)
    node_ids = list(g.nodes.keys())
    n_total = len(node_ids)
    ports = [nid for nid in node_ids if g.nodes[nid]["is_port"]]
    airports = [nid for nid in node_ids if g.nodes[nid]["is_airport"]]

    # HIGHWAY edges
    for i in range(n_total):
        na = g.nodes[node_ids[i]]
        for j in range(i + 1, n_total):
            nb = g.nodes[node_ids[j]]
            d = haversine(na["lat"], na["lon"], nb["lat"], nb["lon"])
            if na["country"] == nb["country"]:
                if d <= MAX_HIGHWAY_KM: g.add_edge(node_ids[i], node_ids[j], "HIGHWAY", d)
            else:
                if d <= MAX_CROSS_BORDER_KM: g.add_edge(node_ids[i], node_ids[j], "HIGHWAY", d)

    # SEA edges
    for i in range(len(ports)):
        pa = g.nodes[ports[i]]
        for j in range(i + 1, len(ports)):
            pb = g.nodes[ports[j]]
            if pa["country"] == pb["country"]: continue
            d = haversine(pa["lat"], pa["lon"], pb["lat"], pb["lon"])
            if d > MAX_SEA_KM: continue
            oa = set(COUNTRY_TO_OCEANS.get(pa["country"], []))
            ob = set(COUNTRY_TO_OCEANS.get(pb["country"], []))
            if (oa & ob) or d < 2000:
                g.add_edge(ports[i], ports[j], "SEA", d)

    # AIR edges
    for i in range(len(airports)):
        pa = g.nodes[airports[i]]
        for j in range(i + 1, len(airports)):
            pb = g.nodes[airports[j]]
            d = haversine(pa["lat"], pa["lon"], pb["lat"], pb["lon"])
            if d > MAX_AIR_KM: continue
            if airports[i] in MAJOR_HUBS or airports[j] in MAJOR_HUBS:
                g.add_edge(airports[i], airports[j], "AIR", d)
            elif d <= 3000:
                g.add_edge(airports[i], airports[j], "AIR", d)

    return g


def _edge_weight(edge, objective):
    if objective == "FASTEST": return edge["time_h"]
    if objective == "CHEAPEST": return edge["cost_usd"]
    return edge["time_h"] * 50.0 + edge["cost_usd"]  # BALANCED


def dijkstra(graph, src_id, dst_id, allowed_modes=None,
             objective="FASTEST", blocked_nodes=None):
    """
    Generalized Dijkstra with BLOCKED NODE support.
    blocked_nodes: set of node IDs to skip entirely.
    """
    blocked = set(blocked_nodes or [])

    if src_id not in graph.nodes: raise ValueError(f"Source '{src_id}' not found")
    if dst_id not in graph.nodes: raise ValueError(f"Destination '{dst_id}' not found")
    if src_id in blocked: raise ValueError(f"Source '{src_id}' is in blocked list")
    if dst_id in blocked: raise ValueError(f"Destination '{dst_id}' is in blocked list")

    dist = {nid: float("inf") for nid in graph.nodes}
    prev = {}
    dist[src_id] = 0.0
    heap = [(0.0, src_id)]

    while heap:
        cur_w, cur = heapq.heappop(heap)
        if cur_w > dist[cur]: continue
        if cur == dst_id: break
        for edge in graph.neighbours(cur):
            nb = edge["to"]
            if nb in blocked: continue
            if allowed_modes and edge["mode"] not in allowed_modes: continue
            new_w = cur_w + _edge_weight(edge, objective)
            if new_w < dist[nb]:
                dist[nb] = new_w
                prev[nb] = (cur, edge)
                heapq.heappush(heap, (new_w, nb))

    if dist[dst_id] == float("inf"):
        return float("inf"), []

    path_edges = []
    cur = dst_id
    while cur in prev:
        p, edge = prev[cur]
        path_edges.append({
            "from": graph.nodes[p]["name"], "from_id": p,
            "to": graph.nodes[cur]["name"], "to_id": cur,
            "mode": edge["mode"], "dist_km": edge["dist_km"],
            "time_h": round(edge["time_h"], 2), "cost_usd": edge["cost_usd"],
        })
        cur = p
    path_edges.reverse()
    return dist[dst_id], path_edges


def find_node_id(graph, query):
    """Fuzzy city lookup: exact id -> exact name -> prefix -> substring."""
    q = query.lower().strip()
    qid = q.replace(" ", "_").replace("-", "_").replace("'", "")
    if qid in graph.nodes: return qid
    for nid, node in graph.nodes.items():
        if node["name"].lower() == q: return nid
    matches = []
    for nid, node in graph.nodes.items():
        nl = node["name"].lower()
        if nl.startswith(q) or q in nl:
            matches.append((len(nl), nid))
    if matches:
        matches.sort()
        return matches[0][1]
    q_tokens = set(q.split())
    best_score, best_id = 0, None
    for nid, node in graph.nodes.items():
        score = len(q_tokens & set(node["name"].lower().split()))
        if score > best_score: best_score, best_id = score, nid
    return best_id if best_score > 0 else None


def get_all_city_names(graph):
    return sorted(
        [{"id": nid, "name": n["name"], "region": n["region"], "country": n["country"]}
         for nid, n in graph.nodes.items()],
        key=lambda x: x["name"]
    )


def fmt_time(h):
    hours = int(h)
    mins = int((h - hours) * 60)
    if hours >= 24:
        days = hours // 24
        hours = hours % 24
        return f"{days}d {hours}h {mins}m"
    return f"{hours}h {mins}m"
