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
    def __init__(self, name: str):
        self.name = name
        self.time_h = 0.0  # Processing time is bundled into transport edges for now, so Node time is 0.

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

class ActiveShipment:
    def __init__(self, shipment_id: str, cargo_type: str, route_plan: List[Union[NodeStep, LinkStep]]):
        self.shipment_id = shipment_id
        self.cargo_type = cargo_type
        self.route_plan = route_plan
        self.current_step_index = 0
        self.progress_on_step = 0.0
        self.status = 'IN_TRANSIT'

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
            while shipment.progress_on_step >= step_duration and shipment.status != 'DELIVERED':
                
                # --- TELEMETRY INTEGRATION HOOK ---
                # Trigger anomaly detection right when a shipment finishes a Node
                if isinstance(current_step, NodeStep) and self.telemetry_monitor:
                    actual_hours_spent = step_duration  # In a full simulation, this includes stochastic noise
                    self.telemetry_monitor.record_dwell_time(current_step.name, actual_hours_spent)
                # ----------------------------------

                shipment.progress_on_step -= step_duration
                shipment.current_step_index += 1
                
                if shipment.current_step_index >= len(shipment.route_plan):
                    shipment.status = 'DELIVERED'
                    shipment.progress_on_step = 0.0
                    break
                else:
                    current_step = shipment.route_plan[shipment.current_step_index]
                    step_duration = current_step.time_h

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
                    cargo_type=shipment.cargo_type
                )
                
                if "error" in new_route_response:
                    logger.warning(f"Could not reroute shipment {shipment.shipment_id}: {new_route_response['error']}")
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
                        
                shipment.status = 'IN_TRANSIT'
