import sys
from unittest.mock import MagicMock

# Mock problematic dependencies
mock_modules = [
    "dotenv", "firebase_admin", "google.cloud", "google.cloud.firestore",
    "google.genai", "googlemaps", "simpy"
]

for mod in mock_modules:
    sys.modules[mod] = MagicMock()

# Now run the test script
import sys
import os

# Add the current directory to sys.path
sys.path.append(os.getcwd())

from scdo.routing.router import find_alternate_route, get_graph

def test_diversity(origin, destination):
    print(f"\nTesting: {origin} -> {destination}")
    results = find_alternate_route(origin, destination, blocked_nodes=[], cargo_type="general", omega=0.5)
    
    paths = {}
    for key in ["fastest", "cheapest", "balanced"]:
        route = results.get(key, {})
        if not route or "error" in route:
            paths[key] = f"ERROR: {route.get('error', 'Unknown error')}"
        else:
            waypoints = " -> ".join([w["name"] for w in route.get("waypoints", [])])
            modes = ", ".join(route.get("modes_used", []))
            paths[key] = f"[{modes}] {waypoints}"
    
    # Check uniqueness
    p_fast = paths["fastest"]
    p_cheap = paths["cheapest"]
    p_bal = paths["balanced"]
    
    all_same = (p_fast == p_cheap == p_bal)
    any_same = (p_fast == p_cheap or p_fast == p_bal or p_cheap == p_bal)
    
    print(f"  Fastest:  {p_fast}")
    print(f"  Cheapest: {p_cheap}")
    print(f"  Balanced: {p_bal}")
    
    if all_same:
        print("  !!! FAIL: All routes are identical")
    elif any_same:
        print("  --- WARN: Some routes are identical")
    else:
        print("  +++ SUCCESS: All routes are unique")

if __name__ == "__main__":
    # Test cases
    test_cases = [
        ("Mumbai", "London"),
        ("New York", "London"),
        ("Dubai", "Singapore"),
        ("Mumbai", "New Delhi"),
        ("Chennai", "Singapore"),
        ("Jaipur", "Dubai"),
    ]
    
    for o, d in test_cases:
        try:
            test_diversity(o, d)
        except Exception as e:
            import traceback
            print(f"Error testing {o}->{d}: {e}")
            traceback.print_exc()
