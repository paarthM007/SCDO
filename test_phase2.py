import sys
import os

# Add the project root to sys.path to ensure absolute imports work
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), ".")))

from scdo.routing.router import find_route

def print_route(result, title):
    print(f"\n{'='*20} {title} {'='*20}")
    if "error" in result:
        print(f"ERROR: {result['error']}")
        return
    
    print(f"Total Time:  {result['total_time_readable']} ({result['total_time_h']} hours)")
    print(f"Total Cost:  ${result['total_cost_usd']}")
    
    path = " -> ".join([w['name'] for w in result['waypoints']])
    print(f"Path Taken:  {path}")

def run_phase2_tests():
    print("\n[PHASE 2] Testing Dynamic Cargo Weighting")
    
    # We test from a location where there are trade-offs between modes.
    # Delhi to Dubai without mode_pref should pick the best mode based on cargo_type.
    # But wait, our Phase 2 scoring function is currently active when use_ctr is True (quantity != None).

    # 1. STANDARD Cargo
    standard = find_route("Delhi", "Dubai", quantity=1000, cargo_type="STANDARD")
    print_route(standard, "STANDARD CARGO (Balanced)")

    # 2. PERISHABLE Cargo (Cares mostly about Time: 0.80)
    perishable = find_route("Delhi", "Dubai", quantity=1000, cargo_type="PERISHABLE")
    print_route(perishable, "PERISHABLE CARGO (Prioritizes Time)")

    # 3. BULK Cargo (Cares mostly about Cost: 0.80)
    bulk = find_route("Delhi", "Dubai", quantity=1000, cargo_type="BULK")
    print_route(bulk, "BULK CARGO (Prioritizes Cost)")

if __name__ == "__main__":
    run_phase2_tests()
