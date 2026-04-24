"""
crisis_manager.py - Live World State manager for external crises.

This singleton manages weather bans and news/labor risk spikes to alter
the simulation's routing graph and node processing delays in real time.
Phase 3: Implements Cascading Bottlenecks (Overflow Penalties).
"""

# Define the Adjacency Map for spillover traffic.
# If a major node goes down, its adjacent nodes receive an overflow penalty.
ADJACENCY_MAP = {
    "Mumbai": ["Kandla", "Surat", "Palghar", "Raigad", "Navi Mumbai"],
    "New Delhi": ["Jaipur", "Gurugram", "Noida", "Agra", "Faridabad"],
    "Dubai": ["Abu Dhabi", "Sharjah"],
    "Singapore": ["Port Klang", "Johor Bahru", "Tanjung Pelepas"],
    "Shanghai": ["Ningbo", "Qingdao"],
    "Rotterdam": ["Antwerp", "Hamburg", "Bremen"],
    "Los Angeles": ["Long Beach", "San Diego", "Oakland"],
    "New York": ["Newark", "Philadelphia", "Boston"],
    "Chennai": ["Ennore", "Kattupalli", "Krishnapatnam", "Kanchipuram"],
    "Kolkata": ["Haldia", "Paradip"],
}

OVERFLOW_PENALTY = 1.20 # A 20% baseline congestion penalty for overflow traffic.

class CrisisManager:
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(CrisisManager, cls).__new__(cls)
            cls._instance.banned_nodes = set()
            cls._instance.active_risk_multipliers = {}
        return cls._instance

    def _apply_overflow_penalties(self, primary_node: str):
        """Applies a secondary congestion penalty to geographically adjacent nodes."""
        if primary_node in ADJACENCY_MAP:
            for adj_node in ADJACENCY_MAP[primary_node]:
                current_risk = self.active_risk_multipliers.get(adj_node, 1.0)
                # Keep the max penalty so we don't overwrite a severe spike with a weaker overflow penalty
                self.active_risk_multipliers[adj_node] = max(current_risk, OVERFLOW_PENALTY)

    def inject_weather_crisis(self, node_name: str):
        """Adds the node to the banned list and triggers overflow delays."""
        self.banned_nodes.add(node_name)
        self._apply_overflow_penalties(node_name)

    def inject_news_crisis(self, node_name: str, severity_multiplier: float):
        """Updates the risk multiplier for that node and triggers overflow delays."""
        current_risk = self.active_risk_multipliers.get(node_name, 1.0)
        self.active_risk_multipliers[node_name] = max(current_risk, severity_multiplier)
        self._apply_overflow_penalties(node_name)

    def reset_crises(self):
        """Clears all active anomalies and their overflow penalties."""
        self.banned_nodes.clear()
        self.active_risk_multipliers.clear()
