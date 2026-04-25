import sys
import os
# Add the project root to sys.path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from scdo.routing.router import find_route
from scdo.simulation.crisis_manager import CrisisManager
from scdo.routing.cities_data import NODE_CAPABILITIES

def test_capability_reroute_complex():
    cm = CrisisManager()
    cm.reset_crises()
    
    # We use a shipment that forces intermediate hubs.
    # New Delhi to Dubai, but we'll try to observe the path.
    # We'll use BALANCED objective to maybe see more hops.
    origin = "New Delhi"
    destination = "Dubai"
    cargo = "HAZMAT"
    
    print(f"--- Scenario: {cargo} from {origin} to {destination} ---")
    
    # 1. Normal state: Should prefer Mumbai or Mundra (both have HAZMAT_CERT)
    route1 = find_route(origin, destination, cargo_type=cargo, product_type="hazmat", objective="BALANCED")
    if "error" in route1:
        print(f"Error 1: {route1['error']}")
    else:
        path1 = [w['name'] for w in route1['waypoints']]
        print(f"Initial Route: {' -> '.join(path1)}")

    # 2. Block Mumbai: Should reroute to another capable node (like Mundra)
    print("\n--- Blocking Mumbai ---")
    cm.inject_weather_crisis("Mumbai")
    route2 = find_route(origin, destination, cargo_type=cargo, product_type="hazmat", objective="BALANCED")
    if "error" in route2:
        print(f"Error 2: {route2['error']}")
    else:
        path2 = [w['name'] for w in route2['waypoints']]
        print(f"Rerouted (Mumbai blocked): {' -> '.join(path2)}")
        
    # 3. Block both Mumbai and Mundra: Should fail if no other HAZMAT nodes are near
    print("\n--- Blocking Mumbai AND Mundra ---")
    cm.inject_weather_crisis("Mundra")
    route3 = find_route(origin, destination, cargo_type=cargo, product_type="hazmat", objective="BALANCED")
    if "error" in route3:
        print(f"Route Search Result (Expected Error or long path): {route3['error'] if 'error' in route3 else ' -> '.join([w['name'] for w in route3['waypoints']])}")
        if "error" not in route3:
             # Check if it somehow went through a GENERAL node
             path3 = [w['name'] for w in route3['waypoints']]
             for node in path3[1:-1]:
                 if "HAZMAT_CERT" not in NODE_CAPABILITIES.get(node, ["GENERAL"]):
                     print(f"CRITICAL FAILURE: Route went through {node} which lacks HAZMAT_CERT!")

if __name__ == "__main__":
    test_capability_reroute_complex()
