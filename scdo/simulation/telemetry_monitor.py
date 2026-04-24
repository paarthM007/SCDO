"""
telemetry_monitor.py - Endogenous Anomaly Detector.
Monitors live rolling shipment dwell times against Monte-Carlo baselines.
Triggers 3-Sigma alerts for cascading congestion.
"""
from collections import deque
import logging
from scdo.simulation.crisis_manager import CrisisManager

logger = logging.getLogger(__name__)

class TelemetryMonitor:
    def __init__(self, crisis_manager_ref: CrisisManager):
        self.crisis_manager_ref = crisis_manager_ref
        self.baselines = {}
        self.live_windows = {}

    def pre_warm_baselines(self, mocked_baselines: dict):
        """
        Populates the baseline metrics.
        In production, this would run the Monte-Carlo engine 100 times.
        Format: {'Node_Name': {'mean': float, 'std_dev': float}}
        """
        self.baselines = mocked_baselines
        # Initialize empty deques for each node
        for node in self.baselines.keys():
            self.live_windows[node] = deque(maxlen=5)

    def record_dwell_time(self, node_name: str, actual_hours: float):
        """
        Records the actual processing hours and performs advanced anomaly detection.
        """
        if node_name not in self.baselines:
            return

        if node_name not in self.live_windows:
            self.live_windows[node_name] = deque(maxlen=5)

        window = self.live_windows[node_name]
        window.append(actual_hours)

        # Perform advanced check
        anomaly_type = self.check_advanced_anomalies(node_name)
        if anomaly_type:
            print(f"[TELEMETRY] {anomaly_type} Detected at {node_name}! Auto-triggering Crisis Manager.")
            logger.warning(f"{anomaly_type} at {node_name}. Latest Value: {actual_hours:.2f}h")
            
            # Inject crisis with a massive 5.0x penalty multiplier to simulate severe gridlock
            self.crisis_manager_ref.inject_news_crisis(node_name, severity_multiplier=5.0)
            
            # Clear the deque so it doesn't continuously spam the Crisis Manager
            window.clear()

    def check_advanced_anomalies(self, node_name: str):
        """
        Detects sudden spikes (3-Sigma) and gradual congestion builds (Velocity/Trend).
        """
        window = list(self.live_windows[node_name])
        if len(window) < 4: 
            return None
        
        baseline = self.baselines[node_name]
        b_mean = baseline['mean']
        b_std = baseline['std_dev']

        # 1. The Sudden Explosion (3-Sigma)
        rolling_mean = sum(window) / len(window)
        if rolling_mean > (b_mean + (3 * b_std)):
            return "3-SIGMA SPIKE"

        # 2. The "Slow Boil" (Velocity/Trend Detection)
        # If the last 3 shipments were strictly increasing and the latest is 15% over the mean
        if window[-1] > window[-2] > window[-3]:
            if window[-1] > (b_mean * 1.15):
                return "GRADUAL CONGESTION BUILDUP"
                
        # 3. (Multi-Variate Stub) 
        # if api_client.get_cancelled_departures() > 5 and rolling_mean > baseline: return "MULTI-VARIATE BLOCKAGE"

        return None
