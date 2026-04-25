import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'orchestrator_controller.dart';
import 'screens/orchestrator_dashboard.dart';
import 'models.dart';

/// OrchestratorPage — thin wiring layer between the controller and the UI.
///
/// Sits at the top of the widget tree for the "Live Orchestrator" tab.
/// Reads state from [OrchestratorController] via [context.watch] and
/// passes it down as plain values to [OrchestratorDashboard].
class OrchestratorPage extends StatelessWidget {
  const OrchestratorPage({super.key});

  @override
  Widget build(BuildContext context) {
    // ChangeNotifierProvider is placed above AppScaffold in main.dart,
    // so we can safely read the controller here.
    final ctrl = context.watch<OrchestratorController>();

    return OrchestratorDashboard(
      shipmentState: ctrl.currentShipment,
      globalState: ctrl.globalState,
      allLogs: ctrl.auditLogs,
      onDispatch: (cargo) => ctrl.startScenario(cargo),
      onSyncOsint: () => ctrl.syncOsint(demoMode: true),
      // onTick is null — the heartbeat timer fires automatically.
      onTick: null,
    );
  }
}
