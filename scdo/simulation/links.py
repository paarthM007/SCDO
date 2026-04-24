"""
links.py - All transport link types from DES.py.
v3.0: Uses pre-calculated base_time and base_cost from the routing engine if provided,
      ensuring perfect alignment between router metrics and simulation results.
"""
import random
from scdo.simulation.entities import get_lognormal_params

class TransportLink:
    def __init__(self, env, source, dest, mode, base_time=None, base_cost=None):
        self.env = env
        self.source = source
        self.dest = dest
        self.mode = mode
        self.ctr_base_time = base_time
        self.ctr_base_cost = base_cost

    def _scale_delay(self, delay):
        return delay * getattr(self, '_risk_delay_multiplier', 1.0)
        
    def _scale_cost(self, cost):
        return cost * getattr(self, '_risk_cost_multiplier', 1.0)
        
    def _apply_ctr(self, delay, cost):
        """Applies CTR scaling and noise to base values if they exist."""
        if self.ctr_base_time is not None and self.ctr_base_cost is not None:
            delay = self.ctr_base_time
            cost = self.ctr_base_cost
            if delay > 0:
                noise = random.gauss(0, delay * 0.1) # 10% gaussian noise
                delay = max(0.1, delay + noise)
            
            return self._scale_delay(delay), self._scale_cost(cost), True
        return delay, cost, False

    def traverse(self, shipment):
        yield self.env.timeout(0)

class RoadLink(TransportLink):
    def __init__(self, env, src, dst, google_client=None, base_time=None, base_cost=None,
                 noise_mean_h=0.5, noise_std_h=0.2,
                 fallback_mean_h=15.0, fallback_std_h=3.0,
                 base_cost_fallback=250.0, cost_per_hour=12.0):
        super().__init__(env, src, dst, "ROAD", base_time, base_cost)
        self.google_client = google_client
        self.noise_mean_h = noise_mean_h
        self.noise_std_h = noise_std_h
        self.fallback_mean_h = fallback_mean_h
        self.fallback_std_h = fallback_std_h
        self.base_cost_fallback = base_cost_fallback
        self.cost_per_hour = cost_per_hour
        
    def traverse(self, shipment):
        delay, cost, used_ctr = self._apply_ctr(0, 0)
        if not used_ctr:
            if hasattr(self, '_pre_delay'):
                delay = self._pre_delay
            elif self.google_client:
                api_hours = self.google_client.get_travel_time_hours(self.source, self.dest, self.env.now)
                noise = 0.0
                if self.noise_mean_h > 0 and self.noise_std_h > 0:
                    mu, sigma = get_lognormal_params(self.noise_mean_h, self.noise_std_h)
                    noise = random.lognormvariate(mu, sigma)
                delay = api_hours + noise
            else:
                mu, sigma = get_lognormal_params(self.fallback_mean_h, self.fallback_std_h)
                delay = random.lognormvariate(mu, sigma)
            delay = self._scale_delay(delay)
            cost = self._scale_cost(self.base_cost_fallback + (self.cost_per_hour * delay))
            
        yield self.env.timeout(delay)
        shipment.record(f"Road Transit: {self.source} -> {self.dest}", delay, cost)

class RailLink(TransportLink):
    def __init__(self, env, src, dst, rail_client=None, base_time=None, base_cost=None,
                 min_hours=20.0, max_hours=30.0,
                 base_cost_fallback=500.0, cost_per_hour=5.0):
        super().__init__(env, src, dst, "RAIL", base_time, base_cost)
        self.rail_client = rail_client
        self.min_hours = min_hours
        self.max_hours = max_hours
        self.base_cost_fallback = base_cost_fallback
        self.cost_per_hour = cost_per_hour
        
    def traverse(self, shipment):
        delay, cost, used_ctr = self._apply_ctr(0, 0)
        if not used_ctr:
            if hasattr(self, '_pre_delay'):
                delay = self._pre_delay
            elif self.rail_client:
                base_h = self.rail_client.get_transit_time_hours(self.source, self.dest)
                delay = random.uniform(base_h * 0.95, base_h * 1.15)
            else:
                delay = random.uniform(self.min_hours, self.max_hours)
            delay = self._scale_delay(delay)
            cost = self._scale_cost(self.base_cost_fallback + (self.cost_per_hour * delay))
            
        yield self.env.timeout(delay)
        shipment.record(f"Rail Transit: {self.source} -> {self.dest}", delay, cost)

class AirLink(TransportLink):
    def __init__(self, env, src, dst, air_client=None, base_time=None, base_cost=None,
                 mean_hours=5.0, std_hours=0.5,
                 base_cost_fallback=2000.0, cost_per_hour=50.0):
        super().__init__(env, src, dst, "AIR", base_time, base_cost)
        self.air_client = air_client
        self.mean_hours = mean_hours
        self.std_hours = std_hours
        self.base_cost_fallback = base_cost_fallback
        self.cost_per_hour = cost_per_hour
        
    def traverse(self, shipment):
        delay, cost, used_ctr = self._apply_ctr(0, 0)
        if not used_ctr:
            if hasattr(self, '_pre_delay'):
                delay = self._pre_delay
            else:
                base_h = self.air_client.get_transit_time_hours(self.source, self.dest) if self.air_client else self.mean_hours
                delay = max(1.0, random.normalvariate(base_h, self.std_hours))
            delay = self._scale_delay(delay)
            cost = self._scale_cost(self.base_cost_fallback + (self.cost_per_hour * delay))
            
        yield self.env.timeout(delay)
        shipment.record(f"Air Transit: {self.source} -> {self.dest}", delay, cost)

class ShipLink(TransportLink):
    def __init__(self, env, src, dst, sea_client=None, base_time=None, base_cost=None,
                 min_hours=100.0, mode_hours=120.0, max_hours=180.0,
                 fuel_cost_fallback=1500.0, cost_per_hour=2.5):
        super().__init__(env, src, dst, "SHIP", base_time, base_cost)
        self.sea_client = sea_client
        self.min_hours = min_hours
        self.mode_hours = mode_hours
        self.max_hours = max_hours
        self.fuel_cost_fallback = fuel_cost_fallback
        self.cost_per_hour = cost_per_hour
        
    def traverse(self, shipment):
        delay, cost, used_ctr = self._apply_ctr(0, 0)
        if not used_ctr:
            if hasattr(self, '_pre_delay'):
                delay = self._pre_delay
            elif self.sea_client:
                base_h = self.sea_client.get_transit_time_hours(self.source, self.dest)
                delay = random.triangular(base_h * 0.9, base_h * 1.3, base_h)
            else:
                delay = random.triangular(self.min_hours, self.max_hours, self.mode_hours)
            delay = self._scale_delay(delay)
            cost = self._scale_cost(self.fuel_cost_fallback + (self.cost_per_hour * delay))
            
        yield self.env.timeout(delay)
        shipment.record(f"Sea Transit: {self.source} -> {self.dest}", delay, cost)
