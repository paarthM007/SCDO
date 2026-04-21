import math
import random
import numpy as np

class Shipment:
    """Represents a single shipment moving through the supply chain."""
    def __init__(self, env, shipment_id: str):
        self.env = env
        self.shipment_id = shipment_id
        self.log = []
        self.total_cost = 0.0

    def record(self, activity: str, delay: float, cost: float):
        start_time = self.env.now - delay
        self.log.append({
            "activity": activity,
            "start": round(start_time, 2),
            "end": round(self.env.now, 2),
            "duration_h": round(delay, 2),
            "cost": round(cost, 2)
        })
        self.total_cost += cost

def get_lognormal_params(mean: float, std_dev: float):
    """Converts arithmetic mean/std to mu/sigma for lognormal distribution."""
    variance = std_dev ** 2
    mu = math.log(mean ** 2 / math.sqrt(variance + mean ** 2))
    sigma = math.sqrt(math.log(variance / mean ** 2 + 1))
    return mu, sigma

def to_native(obj):
    """Converts numpy types to native Python for JSON serialization."""
    if isinstance(obj, (np.integer,)):
        return int(obj)
    elif isinstance(obj, (np.floating,)):
        return float(obj)
    elif isinstance(obj, np.ndarray):
        return obj.tolist()
    elif isinstance(obj, (tuple, list)):
        return [to_native(x) for x in obj]
    elif isinstance(obj, dict):
        return {k: to_native(v) for k, v in obj.items()}
    return obj
