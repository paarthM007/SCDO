"""
graph.py - Multi-modal routing graph with cargo-aware CTR Dijkstra.
SCDO Logistics Engine v3.0: Cost-Time-Risk Tensor edge weighting.

Edge weights are computed dynamically at Dijkstra runtime based on shipment
variables (quantity Q, product_type, risk R, user preference ω).
"""
import math
import heapq
import logging
from typing import Dict, List, Optional, Set, Tuple
from scdo.config import (
    FIXED_OVERHEAD, VARIABLE_RATE, SPEED_CONSTANTS, PROCESSING_TIME,
    ALPHA_COST_PENALTY, BETA_DELAY_COEFF, CARGO_MODE_BLACKLIST,
    MODE_MIN_QUANTITY, DEFAULT_QUANTITY, DEFAULT_PRODUCT_TYPE,
    DEFAULT_OMEGA, DEFAULT_MAX_BUDGET, DEFAULT_DEADLINE_H,
    CARGO_REQUIREMENTS,
)

logger = logging.getLogger(__name__)

# ── Legacy constants (still used for graph construction thresholds) ────
AVG_HIGHWAY_KMH = 65
AVG_SEA_KMH = 46
AVG_AIR_KMH = 850
AIR_OVERHEAD_H = 2.0

MAX_HIGHWAY_KM = 300
MAX_CROSS_BORDER_KM = 120
MAX_SEA_KM = 8000
MAX_AIR_KM = 12000

# Realistic freight cost per km (USD) for commercial cargo
COST_PER_KM = {"HIGHWAY": 0.18, "SEA": 0.035, "AIR": 0.45}
# Fixed costs per leg: port handling, airport fees, tolls, etc.
MODE_FIXED_COST = {"HIGHWAY": 25, "SEA": 350, "AIR": 150}

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

# ══════════════════════════════════════════════════════════════
# Phase 2: Dynamic Cargo Weighting
# ══════════════════════════════════════════════════════════════

CARGO_PROFILES = {
    'PERISHABLE': {'time': 0.80, 'cost': 0.05, 'risk': 0.15},
    'HIGH_VALUE': {'time': 0.20, 'cost': 0.10, 'risk': 0.70},
    'BULK':       {'time': 0.10, 'cost': 0.80, 'risk': 0.10},
    'STANDARD':   {'time': 0.33, 'cost': 0.33, 'risk': 0.34},
}

def _calculate_edge_score(edge_time, edge_cost, edge_risk, cargo_type='STANDARD', omega=None):
    """
    Min-Max / Baseline normalization for Multi-Objective Cost Function.
    Ensures that Time, Cost, and Risk fall roughly between 0.0 and 1.0
    so weights can be applied meaningfully without one metric dominating.

    v3.0 Logic: If user provides omega (Time-Cost preference), it overrides 
    the base profile's time/cost weights while preserving risk sensitivity.
    """
    MAX_EXPECTED_TIME = 200.0  # hours (e.g. 8 days by sea)
    MAX_EXPECTED_COST = 5000.0 # dollars
    MAX_EXPECTED_RISK = 10.0   # risk multiplier (e.g. crisis spike max)

    norm_time = edge_time / MAX_EXPECTED_TIME
    norm_cost = edge_cost / MAX_EXPECTED_COST
    norm_risk = edge_risk / MAX_EXPECTED_RISK

    profile = CARGO_PROFILES.get(cargo_type.upper(), CARGO_PROFILES['STANDARD'])
    
    if omega is not None:
        # Use user's omega to balance Time vs Cost, 
        # but keep the profile's risk weight and scale others to fit.
        risk_w = profile['risk']
        remaining_w = 1.0 - risk_w
        w_time = (1.0 - omega) * remaining_w
        w_cost = omega * remaining_w
        w_risk = risk_w
    else:
        w_time = profile['time']
        w_cost = profile['cost']
        w_risk = profile['risk']

    score = (norm_time * w_time) + \
            (norm_cost * w_cost) + \
            (norm_risk * w_risk)

    return score



# ══════════════════════════════════════════════════════════════
# CTR Tensor: Dynamic Cost & Time Functions
# ══════════════════════════════════════════════════════════════

def compute_edge_cost(mode: str, dist_km: float, quantity: float,
                      product_type: str, risk_score: float) -> float:
    """
    Holistic Cost Model C_total for a single edge.
    C_total = F(mode, p) + (Q · d · V_mode) · (1 + R · α)
    """
    key = (mode, product_type)
    F = FIXED_OVERHEAD.get(key, FIXED_OVERHEAD.get((mode, "general"), 0.0))
    V = VARIABLE_RATE.get(mode, 0.0005)
    variable = quantity * dist_km * V
    risk_factor = 1.0 + risk_score * ALPHA_COST_PENALTY
    return F + variable * risk_factor


def compute_edge_time(mode: str, dist_km: float, quantity: float,
                      risk_score: float) -> float:
    """
    Stochastic Time Model T_total for a single edge.
    T_total = (d / s_mode) · (1 + R · β) + P(mode, Q)
    """
    s = SPEED_CONSTANTS.get(mode, 65.0)
    transit = (dist_km / s) * (1.0 + risk_score * BETA_DELAY_COEFF)
    p_cfg = PROCESSING_TIME.get(mode, {"base_h": 1.0, "per_unit_h": 0.001})
    processing = p_cfg["base_h"] + p_cfg["per_unit_h"] * quantity
    return transit + processing


def compute_edge_weight(mode: str, dist_km: float, quantity: float,
                        product_type: str, risk_score: float,
                        omega: float) -> float:
    """
    CTR Objective Function W(e).
    W(e) = ω · Ĉ(e) + (1 - ω) · T̂(e)
    Where Ĉ and T̂ are cost and time, combined via user preference ω.
    
    Note: In a full implementation, Ĉ and T̂ would be globally normalized.
    Here we use a scaling approach: cost is divided by a reference factor
    to bring it into comparable range with time (hours).
    """
    cost = compute_edge_cost(mode, dist_km, quantity, product_type, risk_score)
    time_h = compute_edge_time(mode, dist_km, quantity, risk_score)
    
    # Normalization factors (reference scales to balance cost vs time)
    COST_NORM = 500.0   # ~$500 is a "typical" edge cost
    TIME_NORM = 10.0    # ~10h is a "typical" edge time
    
    c_hat = cost / COST_NORM
    t_hat = time_h / TIME_NORM
    
    return omega * c_hat + (1.0 - omega) * t_hat


def is_cargo_compatible(mode: str, product_type: str, quantity: float) -> bool:
    """
    Constraint Pruning: checks cargo-mode compatibility.
    Returns False if the edge should be skipped.
    """
    # Hard blacklist
    if (product_type, mode) in CARGO_MODE_BLACKLIST:
        return False
    # Quantity threshold — skip modes with high overhead for small shipments
    min_q = MODE_MIN_QUANTITY.get(mode, 1)
    if quantity < min_q:
        return False
    return True


# ══════════════════════════════════════════════════════════════
# Legacy simple functions (backward compatibility)
# ══════════════════════════════════════════════════════════════

def travel_time_h(dist_km, mode):
    if mode == "HIGHWAY": return dist_km / AVG_HIGHWAY_KMH
    if mode == "SEA": return dist_km / AVG_SEA_KMH
    if mode == "AIR": return dist_km / AVG_AIR_KMH + AIR_OVERHEAD_H
    return dist_km / 50

def travel_cost_usd(dist_km, mode):
    per_km = dist_km * COST_PER_KM.get(mode, 0.18)
    fixed = MODE_FIXED_COST.get(mode, 0)
    return per_km + fixed


# ══════════════════════════════════════════════════════════════
# Graph Structure
# ══════════════════════════════════════════════════════════════

class GlobalRoutingGraph:
    def __init__(self):
        self.nodes: Dict[str, dict] = {}
        self.adj: Dict[str, List[dict]] = {}

    def add_node(self, node):
        self.nodes[node["id"]] = node
        if node["id"] not in self.adj:
            self.adj[node["id"]] = []

    def add_edge(self, id_a, id_b, mode, dist_km):
        """
        Edges now store only topology (mode + distance).
        Cost/Time are computed dynamically during Dijkstra based on
        shipment variables (Q, product_type, risk, ω).
        """
        # Pre-compute legacy values for backward compatibility in results
        t = travel_time_h(dist_km, mode)
        c = travel_cost_usd(dist_km, mode)
        
        # v3.0: Capacity limits for graph visualization (StrokeWidth)
        cap_limit = 100.0
        if mode == "SEA": cap_limit = 5000.0
        elif mode == "AIR": cap_limit = 50.0

        e_ab = {"to": id_b, "mode": mode, "dist_km": round(dist_km, 1),
                "time_h": round(t, 4), "cost_usd": round(c, 2), "capacity_limit": cap_limit}
        e_ba = {"to": id_a, "mode": mode, "dist_km": round(dist_km, 1),
                "time_h": round(t, 4), "cost_usd": round(c, 2), "capacity_limit": cap_limit}
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


# ══════════════════════════════════════════════════════════════
# CTR-Aware Dijkstra (v3.0)
# ══════════════════════════════════════════════════════════════

def _edge_weight(edge, objective):
    """Legacy edge weight for backward compatibility."""
    if objective == "FASTEST": return edge["time_h"]
    if objective == "CHEAPEST": return edge["cost_usd"]
    return edge["time_h"] * 50.0 + edge["cost_usd"]  # BALANCED


def dijkstra(graph, src_id, dst_id, allowed_modes=None,
             objective="FASTEST", blocked_nodes=None,
             # ── v3.0 CTR shipment parameters ──
             quantity=None, product_type=None, risk_score=0.0,
             omega=None, max_budget=None, deadline_h=None, cargo_type="STANDARD"):
    """
    Cargo-aware Dijkstra with CTR Tensor edge weighting.
    
    When v3.0 parameters (quantity, product_type, omega) are provided,
    edge weights are computed dynamically using the CTR formulas.
    Otherwise, falls back to legacy static weights for backward compatibility.
    
    Implements:
    - Dynamic W(e) weighting using _calculate_edge_score
    - User preference (omega) integration (§3.I)
    - Cargo-mode incompatibility pruning
    - Budget & Deadline constraint pruning (early exit)
    """
    blocked = set(blocked_nodes or [])

    if src_id not in graph.nodes: raise ValueError(f"Source '{src_id}' not found")
    if dst_id not in graph.nodes: raise ValueError(f"Destination '{dst_id}' not found")
    if src_id in blocked: raise ValueError(f"Source '{src_id}' is in blocked list")
    if dst_id in blocked: raise ValueError(f"Destination '{dst_id}' is in blocked list")

    # Determine if we're using v3.0 CTR mode
    use_ctr = quantity is not None
    Q = quantity if quantity is not None else DEFAULT_QUANTITY
    pt = product_type or DEFAULT_PRODUCT_TYPE
    R = risk_score
    budget_limit = max_budget if max_budget is not None else DEFAULT_MAX_BUDGET

    dist = {nid: float("inf") for nid in graph.nodes}
    cost_so_far = {nid: 0.0 for nid in graph.nodes}
    time_so_far = {nid: 0.0 for nid in graph.nodes}
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
            
            # ── v3.0 Node Capability Pruning ──
            # HARD CONSTRAINT CHECK:
            # If the cargo requires a specialty the node doesn't have, skip it.
            target_node = graph.nodes[nb]
            required_cap = CARGO_REQUIREMENTS.get(cargo_type.upper())
            if required_cap and required_cap not in target_node.get("capabilities", ["GENERAL"]):
                continue  # The router ignores this path entirely

            mode = edge["mode"]
            d_km = edge["dist_km"]

            if use_ctr:
                # ── v3.0 Cargo-aware pruning ──
                if not is_cargo_compatible(mode, pt, Q):
                    continue

                # ── Phase 1: Inject Live Crises (Risk Multipliers) ──
                from scdo.simulation.crisis_manager import CrisisManager
                cm = CrisisManager()
                target_name = graph.nodes[nb]["name"]
                multiplier = cm.active_risk_multipliers.get(target_name, 1.0)

                # Compute actual cost, time, and risk with crisis multipliers
                edge_cost = compute_edge_cost(mode, d_km, Q, pt, R)
                edge_time = compute_edge_time(mode, d_km, Q, R) * multiplier
                edge_risk = multiplier * (1.0 + R)

                # ── Phase 2: Dynamic Cargo Weighting ──
                # Replaces previous omega calculation with cargo profile scoring
                edge_score = _calculate_edge_score(edge_time, edge_cost, edge_risk, cargo_type, omega=omega)
                new_w = cur_w + edge_score

                # ── Constraint early exit (Budget & Deadline) ──
                new_accumulated_cost = cost_so_far[cur] + edge_cost
                new_accumulated_time = time_so_far[cur] + edge_time
                
                if new_accumulated_cost > budget_limit:
                    continue
                if deadline_h is not None and new_accumulated_time > deadline_h:
                    continue
            else:
                # ── Legacy mode ──
                new_w = cur_w + _edge_weight(edge, objective)
                edge_cost = edge["cost_usd"]
                edge_time = edge["time_h"]
                new_accumulated_cost = cost_so_far[cur] + edge_cost
                new_accumulated_time = time_so_far[cur] + edge_time

            if new_w < dist[nb]:
                dist[nb] = new_w
                cost_so_far[nb] = new_accumulated_cost
                time_so_far[nb] = new_accumulated_time
                prev[nb] = (cur, edge, edge_cost, edge_time)
                heapq.heappush(heap, (new_w, nb))

    if dist[dst_id] == float("inf"):
        return float("inf"), []

    path_edges = []
    cur = dst_id
    while cur in prev:
        p, edge, e_cost, e_time = prev[cur]
        path_edges.append({
            "from": graph.nodes[p]["name"], "from_id": p,
            "to": graph.nodes[cur]["name"], "to_id": cur,
            "mode": edge["mode"], "dist_km": edge["dist_km"],
            "time_h": round(e_time, 2), "cost_usd": round(e_cost, 2),
            "capacity_limit": edge.get("capacity_limit", 100.0),
        })
        cur = p
    path_edges.reverse()
    return dist[dst_id], path_edges


# ══════════════════════════════════════════════════════════════
# Feasibility Index (v3.0)
# ══════════════════════════════════════════════════════════════

def compute_feasibility_index(total_cost: float, total_time_h: float,
                              budget: float, deadline_h: float) -> float:
    """
    F_idx = min(1, Budget / C_total) · min(1, Deadline / T_total)
    Returns a value in [0, 1]. If < 1, the route exceeds budget or deadline.
    """
    if total_cost <= 0:
        cost_factor = 1.0
    else:
        cost_factor = min(1.0, budget / total_cost)
    if total_time_h <= 0:
        time_factor = 1.0
    else:
        time_factor = min(1.0, deadline_h / total_time_h)
    return round(cost_factor * time_factor, 4)


# ══════════════════════════════════════════════════════════════
# Utility Functions
# ══════════════════════════════════════════════════════════════

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
