import sys
import os

# Add the project root to sys.path to ensure absolute imports work
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), ".")))

from scdo.routing.router import find_route
from scdo.simulation.crisis_manager import CrisisManager
import scdo.simulation.crisis_manager as cm_module

def print_route(result, title):
    print(f"\n{'='*20} {title} {'='*20}")
    if "error" in result:
        print(f"ERROR: {result['error']}")
        return
    
    print(f"Total Time:  {result['total_time_readable']} ({result['total_time_h']} hours)")
    print(f"Total Cost:  ${result['total_cost_usd']}")
    
    # Identify the ports used in the waypoints
    ports = [w['name'] for w in result['waypoints'] if w.get('is_port')]
    print(f"Ports Used:  {', '.join(ports) if ports else 'None'}")
    
    path = " -> ".join([w['name'] for w in result['waypoints']])
    print(f"Path Taken:  {path}")

def run_phase3_tests():
    cm = CrisisManager()
    
    # --- Step 1: The "Healthy Backup" Baseline ---
    cm.reset_crises()
    cm_module.OVERFLOW_PENALTY = 1.20  # Reset to default
    print("\n[STEP 1] Running Baseline Test: Pune -> Dubai (BULK)")
    baseline = find_route("Pune", "Dubai", quantity=1000, cargo_type="BULK")
    print_route(baseline, "BASELINE (NORMAL)")

    # --- Step 2: The Overflow Strike ---
    # Objective: Inject crisis at Mumbai, causing 1.2x overflow to Palghar/Kandla.
    # A backup port should be selected but with a higher ETA.
    print("\n[STEP 2] Injecting News Crisis at Mumbai (10.0 multiplier)")
    print("         Expectation: Backup absorbs overflow (1.2x penalty). Slower ETA.")
    cm.inject_news_crisis("Mumbai", 10.0)
    overflow = find_route("Pune", "Dubai", quantity=1000, cargo_type="BULK")
    print_route(overflow, "OVERFLOW (MUMBAI DOWN, BACKUP CHOKED 1.2x)")

    # --- Step 3: The "Total Gridlock" Pivot ---
    # Objective: Set overflow penalty to 5.0 (catastrophic). Regional backups should be abandoned.
    print("\n[STEP 3] Setting OVERFLOW_PENALTY to 5.0x (Catastrophic Congestion)")
    print("         Expectation: Region is totally abandoned. Router pivots to a distant port.")
    cm.reset_crises()
    cm_module.OVERFLOW_PENALTY = 5.0
    cm.inject_news_crisis("Mumbai", 10.0)
    gridlock = find_route("Pune", "Dubai", quantity=1000, cargo_type="BULK")

    print_route(gridlock, "GRIDLOCK (MUMBAI DOWN, KANDLA DEAD 5.0x)")

    # Cleanup
    cm.reset_crises()
    cm_module.OVERFLOW_PENALTY = 1.20
    print("\nTests completed. Crisis Manager state reset.")

if __name__ == "__main__":
    run_phase3_tests()
