"""
nodes.py - All simulation node types from DES.py.
"""
import random
import math
from typing import Optional
from scdo.simulation.entities import get_lognormal_params

class Node:
    def __init__(self, env, name):
        self.env = env
        self.name = name
    def _scale_delay(self, delay):
        return delay * getattr(self, '_risk_delay_multiplier', 1.0)
    def _scale_cost(self, cost):
        return cost * getattr(self, '_risk_cost_multiplier', 1.0)
    def process(self, shipment):
        yield self.env.timeout(0)

class CustomsNode(Node):
    def __init__(self, env, name, mean_delay_hours=4.0, std_delay_hours=1.5,
                 inspection_prob=0.15, inspection_extra_hours=8.0,
                 fixed_fee=100.0, hourly_rate=20.0):
        super().__init__(env, name)
        self.mean_delay = mean_delay_hours
        self.std_delay = std_delay_hours
        self.inspection_prob = inspection_prob
        self.inspection_extra = inspection_extra_hours
        self.fixed_fee = fixed_fee
        self.hourly_rate = hourly_rate
    def process(self, shipment):
        mu, sigma = get_lognormal_params(self.mean_delay, self.std_delay)
        delay = random.lognormvariate(mu, sigma)
        if random.random() < self.inspection_prob:
            delay += self.inspection_extra
        delay = self._scale_delay(delay)
        cost = self._scale_cost(self.fixed_fee + self.hourly_rate * delay)
        yield self.env.timeout(delay)
        shipment.record(f"Customs: {self.name}", delay, cost)

class StateBorderNode(Node):
    def __init__(self, env, name, min_wait_hours=0.5, max_wait_hours=2.0, entry_fee=10.0):
        super().__init__(env, name)
        self.min_wait = min_wait_hours
        self.max_wait = max_wait_hours
        self.entry_fee = entry_fee
    def process(self, shipment):
        delay = self._scale_delay(random.uniform(self.min_wait, self.max_wait))
        cost = self._scale_cost(self.entry_fee)
        yield self.env.timeout(delay)
        shipment.record(f"Border: {self.name}", delay, cost)

class TransshipmentNode(Node):
    def __init__(self, env, name, handling_mean_h=3.0, handling_std_h=1.0,
                 fixed_cost=150.0, hourly_rate=25.0):
        super().__init__(env, name)
        self.handling_mean = handling_mean_h
        self.handling_std = handling_std_h
        self.fixed_cost = fixed_cost
        self.hourly_rate = hourly_rate
    def process(self, shipment):
        mu, sigma = get_lognormal_params(self.handling_mean, self.handling_std)
        delay = self._scale_delay(random.lognormvariate(mu, sigma))
        cost = self._scale_cost(self.fixed_cost + self.hourly_rate * delay)
        yield self.env.timeout(delay)
        shipment.record(f"Transshipment: {self.name}", delay, cost)

class FacilityClearance(Node):
    def __init__(self, env, name, direction="import", stages=None,
                 triggers=None, fixed_cost=0.0, hourly_rate=0.0):
        super().__init__(env, name)
        self.direction = direction
        self.stages = stages or []
        self.triggers = triggers or []
        self.fixed_cost = fixed_cost
        self.hourly_rate = hourly_rate
    def _sample_stage(self, stage):
        dist, p = stage["distribution"], stage["params"]
        if dist == "normal": return max(0.5, random.normalvariate(p["mu"], p["sigma"]))
        if dist == "uniform": return random.uniform(p["low"], p["high"])
        if dist == "exponential": return random.expovariate(1.0 / p["mean"])
        if dist == "lognormal":
            mu, sigma = get_lognormal_params(p["mean"], p["std"])
            return random.lognormvariate(mu, sigma)
        if dist == "triangular": return random.triangular(p["low"], p["high"], p["mode"])
        return p.get("mean", 1.0)
    def _evaluate_triggers(self, base_total, boost_factor=1.0):
        additive_extra, swap_value = 0.0, None
        fired, log_weight = [], 0.0
        for t in self.triggers:
            p_real = t["probability"]
            p_boosted = min(p_real * boost_factor, 0.99)
            if random.random() < p_boosted:
                fired.append(t["name"])
                log_weight += math.log(p_real / p_boosted) if p_boosted > 0 else 0.0
                if t["mode"] == "swap":
                    if swap_value is None or t["hours"] > swap_value: swap_value = t["hours"]
                else: additive_extra += t["hours"]
            else:
                log_weight += math.log((1 - p_real) / (1 - p_boosted)) if p_boosted < 1 else 0.0
        final = (swap_value if swap_value is not None else base_total) + additive_extra
        return final, fired, math.exp(log_weight)
    def process(self, shipment):
        boost = getattr(self, '_importance_boost', 1.0)
        base_total = sum(self._sample_stage(s) for s in self.stages)
        total_delay, fired, weight = self._evaluate_triggers(base_total, boost)
        self._is_weight = weight
        total_delay = self._scale_delay(total_delay)
        cost = self._scale_cost(self.fixed_cost + (self.hourly_rate * total_delay))
        yield self.env.timeout(total_delay)
        shipment.record(f"{self.name} ({self.direction})", total_delay, cost)

class SeaportClearance(FacilityClearance):
    def __init__(self, env, name, direction="import", fixed_cost=500.0, hourly_rate=30.0):
        if direction == "import":
            stages = [
                {"name": "Arrival->Assessment", "distribution": "normal", "params": {"mu": 68.6, "sigma": 17.15}},
                {"name": "Assessment->Payment", "distribution": "uniform", "params": {"low": 23.53, "high": 113.88}},
                {"name": "Payment->OOC", "distribution": "exponential", "params": {"mean": 52.45}},
                {"name": "OOC->GateOut", "distribution": "lognormal", "params": {"mean": 66.63, "std": 23.32}},
            ]
            triggers = [
                {"name": "Amendment", "probability": 0.27, "mode": "additive", "hours": 17.98},
                {"name": "OnHold", "probability": 0.10, "mode": "additive", "hours": 48.0},
            ]
        else:
            stages = [
                {"name": "Arrival->LEO", "distribution": "exponential", "params": {"mean": 47.38}},
                {"name": "LEO->Shipping", "distribution": "triangular", "params": {"low": 30.78, "mode": 41.05, "high": 61.57}},
            ]
            triggers = []
        super().__init__(env, name, direction, stages, triggers, fixed_cost, hourly_rate)

class AirCargoClearance(FacilityClearance):
    def __init__(self, env, name, direction="import", bill_type=None, fixed_cost=300.0, hourly_rate=25.0):
        if direction == "import":
            stages = [
                {"name": "Arrival->Assessment", "distribution": "normal", "params": {"mu": 56.80, "sigma": 14.20}},
                {"name": "Assessment->Payment", "distribution": "uniform", "params": {"low": 22.05, "high": 59.17}},
                {"name": "Payment->OOC", "distribution": "exponential", "params": {"mean": 32.35}},
                {"name": "OOC->GateOut", "distribution": "lognormal", "params": {"mean": 30.83, "std": 10.79}},
            ]
            triggers = [{"name": "Amendment", "probability": 0.27, "mode": "additive", "hours": 17.98}]
        else:
            stages = [
                {"name": "Arrival->LEO", "distribution": "exponential", "params": {"mean": 25.43}},
                {"name": "LEO->Departure", "distribution": "triangular", "params": {"low": 12.95, "mode": 16.18, "high": 24.27}},
            ]
            triggers = []
            if bill_type == "SB": triggers.append({"name": "SB", "probability": 1.0, "mode": "swap", "hours": 82.43})
            elif bill_type == "CS": triggers.append({"name": "CS", "probability": 1.0, "mode": "swap", "hours": 35.40})
        super().__init__(env, name, direction, stages, triggers, fixed_cost, hourly_rate)
        self.bill_type = bill_type

class ICPClearance(FacilityClearance):
    def __init__(self, env, name, direction="import", advance_filed=False,
                 late_facilitated=False, is_aeo=None, fixed_cost=200.0, hourly_rate=15.0):
        triggers = []
        if direction == "import":
            stages = [
                {"name": "Arrival->Assessment", "distribution": "normal", "params": {"mu": 7.15, "sigma": 6.06}},
                {"name": "Assessment->Payment", "distribution": "uniform", "params": {"low": 3.47, "high": 27.47}},
                {"name": "Payment->OOC", "distribution": "exponential", "params": {"mean": 11.67}},
                {"name": "OOC->GateOut", "distribution": "lognormal", "params": {"mean": 6.85, "std": 4.80}},
            ]
            if advance_filed: triggers.append({"name": "AdvanceFiled", "probability": 1.0, "mode": "swap", "hours": 18.78})
            elif late_facilitated: triggers.append({"name": "LateFacilitated", "probability": 1.0, "mode": "swap", "hours": 11.47})
        else:
            stages = [
                {"name": "Arrival->LEO", "distribution": "exponential", "params": {"mean": 6.17}},
                {"name": "LEO->Departure", "distribution": "triangular", "params": {"low": 6.22, "mode": 8.88, "high": 13.33}},
            ]
            if is_aeo is True: triggers.append({"name": "AEO=True", "probability": 1.0, "mode": "swap", "hours": 19.95})
            elif is_aeo is False: triggers.append({"name": "AEO=False", "probability": 1.0, "mode": "swap", "hours": 14.02})
        super().__init__(env, name, direction, stages, triggers, fixed_cost, hourly_rate)

class ICDClearance(FacilityClearance):
    def __init__(self, env, name, direction="import", container_load=None,
                 stuffing_loc=None, fixed_cost=400.0, hourly_rate=20.0):
        if direction == "import":
            stages = [
                {"name": "Arrival->Assessment", "distribution": "normal", "params": {"mu": 100.35, "sigma": 25.09}},
                {"name": "Assessment->Payment", "distribution": "uniform", "params": {"low": 45.62, "high": 106.45}},
                {"name": "Payment->OOC", "distribution": "exponential", "params": {"mean": 89.45}},
                {"name": "OOC->GateOut", "distribution": "lognormal", "params": {"mean": 84.83, "std": 29.69}},
            ]
            triggers = [{"name": "Amendment", "probability": 0.27, "mode": "additive", "hours": 17.98}]
        else:
            triggers = []
            if stuffing_loc == "factory":
                stages = [
                    {"name": "Arrival->LEO", "distribution": "exponential", "params": {"mean": 20.0}},
                    {"name": "LEO->RakeLoading", "distribution": "triangular", "params": {"low": 51.45, "mode": 70.93, "high": 90.40}},
                ]
            elif stuffing_loc == "icd":
                stages = [
                    {"name": "Arrival->LEO", "distribution": "exponential", "params": {"mean": 30.65}},
                    {"name": "LEO->RakeLoading", "distribution": "triangular", "params": {"low": 78.47, "mode": 104.91, "high": 131.37}},
                ]
            else:
                stages = [
                    {"name": "Arrival->LEO", "distribution": "exponential", "params": {"mean": 30.65}},
                    {"name": "LEO->RakeLoading", "distribution": "triangular", "params": {"low": 69.90, "mode": 99.85, "high": 149.78}},
                ]
            if container_load == "FCL": triggers.append({"name": "FCL", "probability": 1.0, "mode": "swap", "hours": 127.07})
            elif container_load == "LCL": triggers.append({"name": "LCL", "probability": 1.0, "mode": "swap", "hours": 155.08})
        super().__init__(env, name, direction, stages, triggers, fixed_cost, hourly_rate)
