"""
shipment_tracker.py - Live Orchestrator for mid-flight rerouting.
Simulates continuous monitoring and handles real-time rerouting of active shipments.
"""
from typing import List, Union, Dict
import logging
from scdo.routing.router import find_route

logger = logging.getLogger(__name__)

class NodeStep:
    """Represents a physical location (port, airport, warehouse) in the route plan."""
    # Default processing/dwell time at each node.
    # This prevents the tick() while-loop from spinning infinitely on 0-duration steps.
    DEFAULT_NODE_DWELL_H = 2.0

    def __init__(self, name: str, dwell_h: float = DEFAULT_NODE_DWELL_H):
        self.name = name
        self.time_h = dwell_h  # Processing time at this node (hours).

    def __repr__(self):
        return f"NodeStep({self.name})"

class LinkStep:
    """Represents a transit leg between two nodes."""
    def __init__(self, from_node: str, to_node: str, mode: str, time_h: float, cost_usd: float):
        self.from_node = from_node
        self.to_node = to_node
        self.mode = mode
        self.time_h = time_h
        self.cost_usd = cost_usd
        
    def __repr__(self):
        return f"LinkStep({self.from_node}->{self.to_node}, {self.time_h}h)"

def parse_route_to_plan(path_edges: list) -> List[Union[NodeStep, LinkStep]]:
    """
    Converts path_edges from router.py into alternating NodeStep and LinkStep objects.
    Ensures the array strictly alternates: [Node, Link, Node, Link, Node...]
    """
    if not path_edges:
        return []
        
    plan = []
    # Start with the origin node
    plan.append(NodeStep(path_edges[0]["from"]))
    
    for edge in path_edges:
        link = LinkStep(
            from_node=edge["from"],
            to_node=edge["to"],
            mode=edge["mode"],
            time_h=edge.get("time_h", 0.0),
            cost_usd=edge.get("cost_usd", 0.0)
        )
        plan.append(link)
        plan.append(NodeStep(edge["to"]))
        
    return plan

# ═══════════════════════════════════════════════════════════════════
# PREDEFINED PRESENTATION SCENARIOS
# ═══════════════════════════════════════════════════════════════════

# The "Happy Path" — transit through the target bottleneck (JNPT)
DEMO_HAPPY_PATH = [
    NodeStep(name="New Delhi", dwell_h=0),
    LinkStep(from_node="New Delhi", to_node="JNPT", mode="TRUCK", time_h=24.0, cost_usd=1200), 
    NodeStep(name="JNPT", dwell_h=12.0),
    LinkStep(from_node="JNPT", to_node="Dubai", mode="SEA", time_h=48.0, cost_usd=3500),
    NodeStep(name="Dubai", dwell_h=0)
]

# The "Crisis Path" — the mid-flight diversion to an alternate port
DEMO_CRISIS_PATH = [
    # Spliced link from current position (e.g. en-route or Delhi) to alternate port
    LinkStep(from_node="New Delhi", to_node="Mundra", mode="TRUCK", time_h=18.0, cost_usd=900),
    NodeStep(name="Mundra", dwell_h=8.0), 
    LinkStep(from_node="Mundra", to_node="Dubai", mode="SEA", time_h=55.0, cost_usd=3800),
    NodeStep(name="Dubai", dwell_h=0)
]

class ActiveShipment:
    def __init__(self, shipment_id: str, cargo_type: str, route_plan: List[Union[NodeStep, LinkStep]],
                 quantity: float = 100.0, product_type: str = "general",
                 max_budget: float = float('inf'), deadline_h: float = float('inf'),
                 omega: float = 0.5):
        self.shipment_id = shipment_id
        self.cargo_type = cargo_type
        self.route_plan = route_plan
        self.quantity = quantity
        self.product_type = product_type
        self.max_budget = max_budget
        self.deadline_h = deadline_h
        self.omega = omega
        
        self.current_step_index = 0
        self.progress_on_step = 0.0
        self.status = 'IN_TRANSIT'
        self.decision_logs = []
        # UI/Presentation flags
        self.has_rerouted = False
        self.reroute_reason = None

    def get_divert_node(self) -> NodeStep:
        """
        Identifies the node from which a reroute should begin.
        If currently at a Node, return that Node.
        If currently on a TransportLink, return the destination Node of that link,
        because shipments cannot teleport mid-transit.
        """
        current_step = self.route_plan[self.current_step_index]
        if isinstance(current_step, NodeStep):
            return current_step
        elif isinstance(current_step, LinkStep):
            # The next element in route_plan is guaranteed to be the destination NodeStep
            return self.route_plan[self.current_step_index + 1]

class ShipmentOrchestrator:
    def __init__(self, telemetry_monitor=None):
        self.active_shipments: Dict[str, ActiveShipment] = {}
        self.telemetry_monitor = telemetry_monitor

    def add_shipment(self, shipment: ActiveShipment):
        self.active_shipments[shipment.shipment_id] = shipment

    def tick(self, hours: float):
        """
        Advances the simulation clock by `hours`.
        Updates the shipment's position in the route_plan.
        """
        for shipment in self.active_shipments.values():
            if shipment.status == 'DELIVERED':
                continue
                
            current_step = shipment.route_plan[shipment.current_step_index]
            step_duration = current_step.time_h
            
            shipment.progress_on_step += hours
            
            # Use while loop in case 'hours' is large enough to complete multiple steps
            # Keep advancing steps as long as we have overflow time
            while shipment.current_step_index < len(shipment.route_plan):
                current_step = shipment.route_plan[shipment.current_step_index]
                
                # SAFETY NET: Prevent infinite loops if a step has 0 duration
                step_duration = max(0.1, current_step.time_h)
            
                if shipment.progress_on_step >= step_duration:
                    
                    # --- TELEMETRY INTEGRATION HOOK ---
                    # Trigger anomaly detection right when a shipment finishes a Node
                    if isinstance(current_step, NodeStep) and self.telemetry_monitor:
                        actual_hours_spent = step_duration  # In a full simulation, this includes stochastic noise
                        self.telemetry_monitor.record_dwell_time(current_step.name, actual_hours_spent, shipment=shipment)
                    # ----------------------------------

                    # We finished this step! Subtract time and move to the next
                    shipment.progress_on_step -= step_duration
                    shipment.current_step_index += 1
                    
                    if shipment.current_step_index < len(shipment.route_plan):
                        next_step = shipment.route_plan[shipment.current_step_index]
                        if hasattr(next_step, 'name'):
                            shipment.decision_logs.append(f"PROGRESS: Docked at {next_step.name} facility. Commencing customs clearance and cargo transfer. Expected dwell time: {next_step.time_h}h.")
                        elif hasattr(next_step, 'to_node'):
                            shipment.decision_logs.append(f"PROGRESS: Departed {next_step.from_node}. En route to {next_step.to_node} via {next_step.mode}. Transit time: {next_step.time_h}h. Segment Cost: ${next_step.cost_usd}.")
                            
                    if shipment.current_step_index >= len(shipment.route_plan):
                        shipment.status = 'DELIVERED'
                        shipment.decision_logs.append("SUCCESS: Shipment delivered successfully. Operations concluded.")
                        shipment.progress_on_step = 0.0
                        break
                        
                    # DEMO FIX: If we just finished a LinkStep (actual transport), 
                    # we break the loop so the UI can render the arrival at the next node.
                    # This prevents the simulation from 'zipping' through multiple link+node pairs in one tick.
                    if not isinstance(current_step, NodeStep):
                        break
                else:
                    # The truck is still moving along the current step. 
                    # Break the loop and wait for the next API tick from Flutter.
                    break
    def evaluate_active_routes(self, crisis_node: str):
        """
        Triggered when CrisisManager registers a new anomaly.
        Evaluates shipments and performs mid-flight reroutes if they are heading toward the crisis.
        """
        for shipment in self.active_shipments.values():
            if shipment.status == 'DELIVERED':
                continue
                
            # Check if crisis_node is in the future path
            is_affected = False
            for step in shipment.route_plan[shipment.current_step_index:]:
                if isinstance(step, NodeStep) and step.name == crisis_node:
                    is_affected = True
                    break
                    
            if is_affected:
                logger.info(f"Shipment {shipment.shipment_id} is affected by crisis at {crisis_node}. Rerouting...")
                shipment.decision_logs.append(f"CRISIS AVOIDANCE: Shipment affected by crisis at {crisis_node}. Calculating new route...")
                shipment.status = 'REROUTING'
                divert_node = shipment.get_divert_node()
                
                # We need the final destination to calculate the new route
                final_node = shipment.route_plan[-1]
                if not isinstance(final_node, NodeStep):
                    logger.error(f"Shipment {shipment.shipment_id} final step is not a NodeStep.")
                    continue
                    
                # Find the new route bypassing the crisis
                new_route_response = find_route(
                    origin=divert_node.name,
                    destination=final_node.name,
                    cargo_type=shipment.cargo_type,
                    quantity=shipment.quantity,
                    product_type=shipment.product_type,
                    omega=shipment.omega,
                    max_budget=shipment.max_budget,
                    deadline_h=shipment.deadline_h
                )
                
                if "error" in new_route_response:
                    logger.warning(f"Could not reroute shipment {shipment.shipment_id}: {new_route_response['error']}")
                    shipment.decision_logs.append(f"REROUTE FAILED: {new_route_response['error']}")
                    continue
                    
                new_path_edges = new_route_response.get("path_edges", [])
                if not new_path_edges:
                    # If empty but no error, it means divert_node == final_node (already arrived)
                    pass
                else:
                    new_route_plan = parse_route_to_plan(new_path_edges)
                    
                    # ── CRITICAL SPLICING LOGIC ──
                    # Find the index of the divert node in the CURRENT plan
                    divert_index = -1
                    for i in range(shipment.current_step_index, len(shipment.route_plan)):
                        step = shipment.route_plan[i]
                        if isinstance(step, NodeStep) and step.name == divert_node.name:
                            divert_index = i
                            break
                            
                    if divert_index != -1:
                        # new_route_plan starts with the divert node as well. 
                        # To avoid duplicating the divert node, we slice the current plan *up to* the divert node,
                        # and then append the entirety of the new_route_plan.
                        # Thus, current_plan[:divert_index] does not include the old divert node,
                        # and the array remains perfectly alternating.
                        shipment.route_plan = shipment.route_plan[:divert_index] + new_route_plan
                        shipment.decision_logs.append(f"REROUTE SUCCESS: Splicing new route from {divert_node.name}.")
                        
                shipment.status = 'IN_TRANSIT'

    def evaluate_and_reroute(self, shipment_id: str, risk_data: dict):
        """
        Evaluates live risk data for the presentation use case.
        If the Kill-Switch threshold is breached, dynamically splices
        the Crisis path into the active shipment.
        """
        shipment = self.active_shipments.get(shipment_id)
        if not shipment or shipment.status == 'DELIVERED':
            return
            
        target_node = "JNPT"
        # Extract node risk from the combined_risk output structure
        city_details = risk_data.get("sentiment_risk", {}).get("city_details", {})
        node_risk = city_details.get(target_node, {})
        
        # Pull the R_final score from the combined_risk.py output
        r_final = risk_data.get("combined_risk_score", 0.1)
        primary_hazard = node_risk.get("primary_hazard", "Anomaly Detected")

        # The Kill-Switch Trigger (Threshold > 0.85)
        if r_final >= 0.85:
            print(f"\n[CRISIS] {target_node} breached R_final threshold ({r_final}).")
            print(f"[REROUTE] Engaging active dynamic pathfinding away from: {primary_hazard}")
            
            # THE SPLICE: Replace remaining steps with the crisis path
            # We keep the steps already completed and append the alternate route
            # In a real scenario, we would call find_route here, but for the demo 
            # we use the hardcoded DEMO_CRISIS_PATH.
            shipment.route_plan = shipment.route_plan[:shipment.current_step_index] + DEMO_CRISIS_PATH
            
            # UI Flags to trigger Flutter animations
            shipment.has_rerouted = True
            shipment.reroute_reason = primary_hazard
            shipment.decision_logs.append(f"CRITICAL REROUTE: {primary_hazard} at {target_node}. Diverting to Mundra port.")
