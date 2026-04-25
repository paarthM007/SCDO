import sys
import os

# Add the project root to sys.path to ensure absolute imports work
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), ".")))

from scdo.simulation.telemetry_monitor import TelemetryMonitor
from scdo.simulation.crisis_manager import CrisisManager

def run_phase5_test():
    print("\n" + "="*50)
    print("PHASE 5 TEST: Endogenous Anomaly Detection")
    print("="*50)

    cm = CrisisManager()
    cm.reset_crises()
    telemetry = TelemetryMonitor(cm)

    # 1. Initialize Baselines
    print("\n[STEP 1] Initializing Baselines...")
    mocked_baselines = {
        "Mumbai": {"mean": 24.0, "std_dev": 2.0}
    }
    telemetry.pre_warm_baselines(mocked_baselines)
    print(f"Mumbai Baseline: Mean=24.0, StdDev=2.0 (Threshold: {24.0 + 3*2.0}h)")

    # 2. Feed Normal Data
    print("\n[STEP 2] Feeding Normal Data...")
    print("Recording 23.0h...")
    telemetry.record_dwell_time("Mumbai", 23.0)
    print("Recording 25.0h...")
    telemetry.record_dwell_time("Mumbai", 25.0)
    print(f"Crisis Active: {'Mumbai' in cm.active_risk_multipliers}")

    # 3. Trigger the Hidden Bottleneck
    print("\n[STEP 3] Triggering the Hidden Bottleneck (Abnormal Data)...")
    print("Recording 35.0h...")
    telemetry.record_dwell_time("Mumbai", 35.0)
    print(f"Rolling Window: {list(telemetry.live_windows['Mumbai'])}")
    
    print("\nRecording 38.0h (This should push the rolling mean over 30h)...")
    telemetry.record_dwell_time("Mumbai", 38.0)
    
    print(f"\nFinal Expected Result Check:")
    has_crisis = "Mumbai" in cm.active_risk_multipliers
    print(f"Crisis Active at Mumbai: {has_crisis}")
    if has_crisis:
        print(f"Crisis Multiplier: {cm.active_risk_multipliers['Mumbai']}x")
        print(f"Window Cleared: {len(telemetry.live_windows['Mumbai']) == 0}")

    print("\nRecording 40.0h (Post-clearance)...")
    telemetry.record_dwell_time("Mumbai", 40.0)
    print(f"New Rolling Window Size: {len(telemetry.live_windows['Mumbai'])}")

if __name__ == "__main__":
    run_phase5_test()
