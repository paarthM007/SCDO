import sys
import os

# Add the project root to sys.path to ensure absolute imports work
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), ".")))

from scdo.routing.router import find_route
from scdo.simulation.crisis_manager import CrisisManager

def print_route(result, title):
    print(f"\n{'='*20} {title} {'='*20}")
    if "error" in result:
        print(f"ERROR: {result['error']}")
        return
    
    print(f"Origin:      {result['origin']}")
    print(f"Destination: {result['destination']}")
    print(f"Total Time:  {result['total_time_readable']} ({result['total_time_h']} hours)")
    print(f"Total Cost:  ${result['total_cost_usd']}")
    
    # Identify the ports used in the waypoints
    ports = [w['name'] for w in result['waypoints'] if w.get('is_port')]
    print(f"Ports Used:  {', '.join(ports) if ports else 'None'}")
    
    # Path Summary
    path = " -> ".join([w['name'] for w in result['waypoints']])
    print(f"Path Taken:  {path}")

def run_phase1_tests():
    cm = CrisisManager()
    
    # --- Step 1: The Baseline Test ---
    # Objective: Verify Mumbai is the default choice under normal conditions.
    cm.reset_crises()
    print("\n[STEP 1] Running Baseline Test: Pune -> Dubai")
    # Using quantity=1000 to trigger v3.0 CTR dynamic weighting logic
    baseline = find_route("Pune", "Dubai", quantity=1000, objective="FASTEST", mode_pref="SEA")
    print_route(baseline, "BASELINE (NORMAL)")

    # --- Step 2: The News Crisis (Risk Spike) Test ---
    # Objective: Penalize Mumbai so heavily that the router switches to an alternative like Kandla.
    print("\n[STEP 2] Injecting News Crisis: Mumbai risk multiplier = 10.0")
    cm.inject_news_crisis("Mumbai", 10.0)
    risk_spike = find_route("Pune", "Dubai", quantity=1000, objective="FASTEST", mode_pref="SEA")
    print_route(risk_spike, "NEWS CRISIS (RISK SPIKE ON MUMBAI)")

    # --- Step 3: The Weather Crisis (Hard Ban) Test ---
    # Objective: Completely ban Mumbai. System must route around it regardless of delay math.
    print("\n[STEP 3] Injecting Weather Crisis: Hard Ban on Mumbai")
    cm.reset_crises() # Clear the risk spike first
    cm.inject_weather_crisis("Mumbai")
    hard_ban = find_route("Pune", "Dubai", quantity=1000, objective="FASTEST", mode_pref="SEA")
    print_route(hard_ban, "WEATHER CRISIS (HARD BAN ON MUMBAI)")

    # Cleanup
    cm.reset_crises()
    print("\nTests completed. Crisis Manager state reset.")

if __name__ == "__main__":
    run_phase1_tests()
