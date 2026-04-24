import sys
import os
import logging

# Add the project root to sys.path to ensure absolute imports work
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), ".")))

from scdo.routing.router import find_route
from scdo.simulation.shipment_tracker import ActiveShipment, ShipmentOrchestrator, parse_route_to_plan
from scdo.simulation.crisis_manager import CrisisManager

# Configure logging to see the reroute info
logging.basicConfig(level=logging.INFO)

def run_phase4_test():
    print("\n" + "="*50)
    print("PHASE 4 TEST: Mid-Flight Rerouting")
    print("="*50)

    orchestrator = ShipmentOrchestrator()
    cm = CrisisManager()
    cm.reset_crises()

    # Step 1: Initialize a long-distance shipment (Delhi -> Dubai)
    # This route usually passes through a major port like Mumbai or Kandla.
    print("\n[STEP 1] Planning baseline route: New Delhi -> Dubai (BULK)")
    baseline = find_route("New Delhi", "Dubai", quantity=1000, cargo_type="BULK")
    
    if "error" in baseline:
        print(f"Error: {baseline['error']}")
        return

    path_edges = baseline.get("path_edges", [])
    route_plan = parse_route_to_plan(path_edges)
    
    shipment = ActiveShipment(
        shipment_id="SCDO-777",
        cargo_type="BULK",
        route_plan=route_plan
    )
    orchestrator.add_shipment(shipment)

    print(f"Initial Route Plan Length: {len(shipment.route_plan)} steps")
    print(f"Initial Path: {' -> '.join([str(s) for s in shipment.route_plan[:5]])} ...")
    
    # Step 2: Simulate 5 hours of driving
    print("\n[STEP 2] Simulating 5 hours of transit...")
    for i in range(5):
        orchestrator.tick(1.0)
    
    print(f"Current Step Index: {shipment.current_step_index}")
    print(f"Current Step:       {shipment.route_plan[shipment.current_step_index]}")
    print(f"Progress on Step:   {shipment.progress_on_step} hours")

    # Step 3: Identify a future node in the plan to sabotage
    # We need a node that is NOT the immediate destination of the current link
    # because our physics rules say we must finish the current link first.
    # If the destination of the current link is the one that's broken, 
    # we'd be arriving at a broken port.
    sabotage_node = ""
    current_link_dest = shipment.get_divert_node().name
    
    for step in shipment.route_plan[shipment.current_step_index + 1:]:
        if hasattr(step, 'name') and step.name != current_link_dest:
            sabotage_node = step.name
            break
    
    if not sabotage_node:
        print("Error: Could not find a future node to sabotage.")
        return

    print(f"\n[STEP 3] Sabotaging future node: {sabotage_node}")
    cm.inject_weather_crisis(sabotage_node) # Hard ban

    # Step 4: Trigger Rerouting Evaluation
    print("\n[STEP 4] Triggering Route Evaluation...")
    old_plan_len = len(shipment.route_plan)
    orchestrator.evaluate_active_routes(sabotage_node)

    print("\n[RESULTS]")
    print(f"New Route Plan Length: {len(shipment.route_plan)} steps")
    print(f"Status:                {shipment.status}")
    print(f"Current Step Index:    {shipment.current_step_index} (Should be same as before)")
    print(f"Progress on Step:      {shipment.progress_on_step} hours (Should be 5.0 or 4.0 depending on start)")
    
    # Verify that sabotage_node is NO LONGER in the route plan
    is_gone = all(not (hasattr(s, 'name') and s.name == sabotage_node) for s in shipment.route_plan)
    print(f"Crisis Node Removed:   {is_gone}")
    
    if is_gone and shipment.current_step_index < old_plan_len:
        print("\nSUCCESS: Shipment successfully rerouted mid-flight while preserving transit state!")
    else:
        print("\nFAILURE: Reroute did not behave as expected.")

if __name__ == "__main__":
    run_phase4_test()
