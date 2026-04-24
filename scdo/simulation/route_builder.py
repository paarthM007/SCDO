"""
route_builder.py - Route assembly from DES.py RouteExecution + build_route_with_nodes.
"""
import simpy
from scdo.simulation.entities import Shipment
from scdo.simulation.nodes import (
    Node, StateBorderNode, SeaportClearance, AirCargoClearance,
    ICPClearance, ICDClearance
)
from scdo.simulation.links import (
    TransportLink, RoadLink, RailLink, AirLink, ShipLink
)

class RouteExecution:
    def __init__(self, env, locations, modes, google_client=None, path_edges=None):
        self.env = env
        self.locations = locations
        self.modes = modes
        self.google_client = google_client
        self.path_edges = path_edges
        self.route = self._assemble_route()

    def _assemble_route(self):
        steps = []
        for i in range(len(self.modes)):
            src = self.locations[i]
            dst = self.locations[i + 1]
            mode = self.modes[i].lower()
            
            base_time = None
            base_cost = None
            if self.path_edges and i < len(self.path_edges):
                edge = self.path_edges[i]
                base_time = edge.get("time_h")
                base_cost = edge.get("cost_usd")

            if i == 0:
                steps.append(Node(self.env, src))
            
            if mode == "road":
                steps.append(RoadLink(self.env, src, dst, google_client=self.google_client, base_time=base_time, base_cost=base_cost))
            elif mode == "rail":
                steps.append(RailLink(self.env, src, dst, base_time=base_time, base_cost=base_cost))
            elif mode == "air":
                steps.append(AirLink(self.env, src, dst, base_time=base_time, base_cost=base_cost))
            elif mode == "ship":
                steps.append(ShipLink(self.env, src, dst, base_time=base_time, base_cost=base_cost))
            else:
                steps.append(TransportLink(self.env, src, dst, mode.upper()))
            steps.append(Node(self.env, dst))
        return steps

    def run_shipment(self, shipment_id):
        shipment = Shipment(self.env, shipment_id)
        for element in self.route:
            if isinstance(element, Node):
                yield self.env.process(element.process(shipment))
            elif isinstance(element, TransportLink):
                yield self.env.process(element.traverse(shipment))
        return shipment


def build_route_with_nodes(env, locations, modes, gmaps=None, facility_configs=None, path_edges=None):
    planner = RouteExecution(env, locations, modes, google_client=gmaps, path_edges=path_edges)
    if facility_configs:
        cls_map = {
            "seaport": SeaportClearance, "air": AirCargoClearance,
            "icp": ICPClearance, "icd": ICDClearance,
        }
        for cfg in sorted(facility_configs, key=lambda c: c["position"], reverse=True):
            cls = cls_map.get(cfg["type"], SeaportClearance)
            kwargs = {k: v for k, v in cfg.items() if k not in ("type", "position")}
            planner.route.insert(cfg["position"], cls(env, **kwargs))
    else:
        planner.route.insert(1, StateBorderNode(env, "UP-Rajasthan Border",
            min_wait_hours=0.5, max_wait_hours=2.0, entry_fee=15.0))
        planner.route.insert(4, SeaportClearance(env, "JNPT Mumbai",
            direction="import", fixed_cost=500.0, hourly_rate=30.0))
    return planner
