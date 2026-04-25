import 'dart:async';
import 'package:flutter/foundation.dart'; // for ChangeNotifier
import 'api_service.dart';
import 'models.dart';

/// OrchestratorController — the single source of truth for the live simulation.
///
/// Wraps the heartbeat timer, API calls, and audit log sequencing.
/// Extends [ChangeNotifier] so the [OrchestratorDashboard] can listen
/// via [ChangeNotifierProvider] and rebuild automatically on every tick.
class OrchestratorController extends ChangeNotifier {
  final ApiService _api = ApiService();
  Timer? _ticker;

  // ── Exposed State ──────────────────────────────────────────────
  ShipmentState? currentShipment;
  GlobalState? globalState;
  List<String> auditLogs = [];
  List<String> currentCrises = [];

  /// Whether a scenario is actively ticking.
  bool isRunning = false;

  /// Set to true while waiting for the API to respond (prevents double-ticks).
  bool isFetching = false;

  // ── Public API ─────────────────────────────────────────────────

  /// Dispatch a new shipment and start the 1-second heartbeat.
  Future<void> startScenario(String cargoType) async {
    // Stop any existing scenario cleanly
    stopScenario();

    try {
      // 1. Dispatch via REST
      await _api.dispatchShipment(cargoType);

      // 2. Reset state and log the kick-off
      currentShipment = null;
      currentCrises = [];
      auditLogs = ['[SYSTEM] Dispatched $cargoType shipment. Awaiting telemetry...'];
      isRunning = true;
      notifyListeners();

      // 3. Start heartbeat — every 2 seconds
      _ticker = Timer.periodic(const Duration(milliseconds: 2000), _onTick);
    } catch (e) {
      auditLogs.insert(0, '[ERROR] Dispatch failed: $e');
      notifyListeners();
    }
  }

  /// Stop the heartbeat and mark simulation as idle.
  void stopScenario() {
    _ticker?.cancel();
    _ticker = null;
    isRunning = false;
    isFetching = false;
  }

  /// Manually trigger a global intelligence sweep (OSINT Sync).
  Future<void> syncOsint({bool demoMode = true}) async {
    if (isFetching) return;
    isFetching = true;
    notifyListeners();

    try {
      auditLogs.insert(0, '[OSINT] Initiating global intelligence sweep...');
      notifyListeners();
      
      await _api.triggerOsintSync(demoMode: demoMode);
      
      auditLogs.insert(0, '[OSINT] Intelligence Sync Complete. Automated response engaged.');
    } catch (e) {
      auditLogs.insert(0, '[ERROR] OSINT Sync failed: $e');
    } finally {
      isFetching = false;
      notifyListeners();
    }
  }

  // ── Private Heartbeat ──────────────────────────────────────────

  /// Called every second by the Timer.
  Future<void> _onTick(Timer timer) async {
    // Guard: if a previous request is still in flight, skip this tick
    if (isFetching) return;
    isFetching = true;

    try {
      final response = await _api.tickSimulation(1.0);

      if (response.shipments.isNotEmpty) {
        currentShipment = response.shipments.first;
        globalState = response.globalState;
        currentCrises = response.globalState.activeCrises;

        // Update UI immediately with latest position / status
        notifyListeners();

        // Stream new logs sequentially (blocking this tick's completion)
        // so the UI has time to render them before the scenario ends.
        if (currentShipment!.freshLogs.isNotEmpty) {
          await _streamLogsSequentially(currentShipment!.freshLogs);
        }

        // Terminate the scenario if delivered or route is exhausted
        if (currentShipment!.status == 'DELIVERED' || currentShipment!.routePlan.isEmpty) {
          timer.cancel();
          isRunning = false;
          auditLogs.insert(0, '[SYSTEM] Scenario Terminated. Final status: ${currentShipment!.status}');
          notifyListeners();
        }
      }
    } catch (e) {
      auditLogs.insert(0, '[ERROR] Tick failed: $e');
      notifyListeners();
    } finally {
      isFetching = false;
    }
  }

  /// Adds logs one by one with a staggered delay so the audit trail
  /// animates smoothly rather than appearing all at once.
  Future<void> _streamLogsSequentially(List<String> newLogs) async {
    for (final log in newLogs) {
      await Future.delayed(const Duration(milliseconds: 800));
      // Guard: don't update state after widget disposal
      auditLogs.insert(0, log);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopScenario();
    super.dispose();
  }
}
