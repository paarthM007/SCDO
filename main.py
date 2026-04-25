from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional
import uuid
import logging

from scdo.simulation.crisis_manager import CrisisManager
from scdo.simulation.telemetry_monitor import TelemetryMonitor
from scdo.simulation.shipment_tracker import ShipmentOrchestrator, ActiveShipment, parse_route_to_plan, NodeStep, LinkStep
from scdo.routing.router import find_route
from scdo.routing.cities_data import get_all_nodes

logger = logging.getLogger(__name__)



# --- Global State Setup ---
crisis_manager = CrisisManager()
telemetry_monitor = TelemetryMonitor(crisis_manager)
orchestrator = ShipmentOrchestrator(telemetry_monitor)

# Pre-warm telemetry with mocked baselines so it works
all_nodes = get_all_nodes()
# We give every node a mean processing time of 2.0h with std_dev of 0.5h
mocked_baselines = {n["name"]: {"mean": 2.0, "std_dev": 0.5} for n in all_nodes}
telemetry_monitor.pre_warm_baselines(mocked_baselines)

app = FastAPI(title="SCDO Live Orchestrator API")

class DispatchRequest(BaseModel):
    cargo_type: str
    origin: str
    destination: str

class TickRequest(BaseModel):
    hours_to_advance: float

@app.post("/api/dispatch")
async def api_dispatch(req: DispatchRequest):
    """
    Initializes a new shipment.
    """
    # 1. Call CrisisManager.reset_crises()
    crisis_manager.reset_crises()
    
    # 2. Clear any active shipments
    orchestrator.active_shipments.clear()
    
    # 3. Calculate baseline route
    # Note: We'll specify a quantity so the router has all context
    route_resp = find_route(
        origin=req.origin,
        destination=req.destination,
        cargo_type=req.cargo_type,
        quantity=100
    )
    if "error" in route_resp:
        raise HTTPException(status_code=400, detail=route_resp["error"])
        
    path_edges = route_resp.get("path_edges", [])
    if not path_edges:
        raise HTTPException(status_code=400, detail="No path edges returned by router")
        
    route_plan = parse_route_to_plan(path_edges)
    
    # 4. Instantiate and add ActiveShipment
    shipment_id = str(uuid.uuid4())
    shipment = ActiveShipment(shipment_id=shipment_id, cargo_type=req.cargo_type, route_plan=route_plan)
    orchestrator.add_shipment(shipment)
    
    route_names = []
    for step in route_plan:
        if isinstance(step, NodeStep):
            route_names.append(step.name)
            
    return {
        "shipment_id": shipment_id,
        "route_plan": route_names,
        "status": "DISPATCHED"
    }

@app.post("/api/tick")
async def api_tick(req: TickRequest):
    """
    Advances the simulation clock.
    """
    # Keep track of active crises before the tick
    crises_before = set(crisis_manager.banned_nodes).union(set(crisis_manager.active_risk_multipliers.keys()))
    
    # 1. Call orchestrator.tick()
    orchestrator.tick(req.hours_to_advance)
    
    # 2. Check if new crises were triggered by TelemetryMonitor
    crises_after = set(crisis_manager.banned_nodes).union(set(crisis_manager.active_risk_multipliers.keys()))
    new_crises = crises_after - crises_before
    
    for crisis_node in new_crises:
        orchestrator.evaluate_active_routes(crisis_node)

    # 3. Construct comprehensive JSON response
    shipments_data = []
    for s_id, shipment in orchestrator.active_shipments.items():
        current_step = shipment.route_plan[shipment.current_step_index]
        
        # Determine step names for UI
        if isinstance(current_step, NodeStep):
            curr_name = current_step.name
            next_name = shipment.route_plan[shipment.current_step_index + 1].name if (shipment.current_step_index + 1) < len(shipment.route_plan) else "Final Destination"
        else: # LinkStep
            curr_name = f"Transit to {current_step.to_node}"
            next_name = current_step.to_node

        # Calculate progress percentage (0.0 to 1.0)
        progress_pct = shipment.progress_on_step / max(0.001, current_step.time_h) if current_step.time_h > 0 else 1.0
        
        # Route plan string format
        route_names = []
        for step in shipment.route_plan:
            if isinstance(step, NodeStep):
                route_names.append(step.name)
                
        # Grab fresh logs and clear them
        fresh_logs = list(shipment.decision_logs)
        shipment.decision_logs.clear()

        shipments_data.append({
            "shipment_id": shipment.shipment_id,
            "status": shipment.status,
            "current_step_name": curr_name,
            "next_step_name": next_name,
            "progress_percentage": round(progress_pct, 2),
            "route_plan": route_names,
            "fresh_logs": fresh_logs
        })

    # Prepare global state
    active_crises = list(crises_after)
    
    telemetry_charts = {}
    for node in active_crises:
        if node in telemetry_monitor.baselines and node in telemetry_monitor.live_windows:
            telemetry_charts[node] = {
                "rolling_mean": sum(telemetry_monitor.live_windows[node]) / len(telemetry_monitor.live_windows[node]) if len(telemetry_monitor.live_windows[node]) > 0 else 0,
                "threshold": telemetry_monitor.baselines[node]["mean"] + (3 * telemetry_monitor.baselines[node]["std_dev"]),
                "history": list(telemetry_monitor.live_windows[node])
            }

    return {
        "active_shipments": shipments_data,
        "global_state": {
            "active_crises": active_crises,
            "telemetry_charts": telemetry_charts
        }
    }
