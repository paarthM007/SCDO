class ShipmentState {
  final String shipmentId;
  final String status; // 'DISPATCHED', 'IN_TRANSIT', 'REROUTING', 'DELIVERED'
  final String currentStepName;
  final String nextStepName;
  final double progressPercentage; // 0.0 to 1.0
  final List<String> routePlan;
  final List<String> freshLogs;
  final bool hasRerouted;
  final String? rerouteReason;

  ShipmentState.fromJson(Map<String, dynamic> json)
      : shipmentId = json['shipment_id'],
        status = json['status'],
        currentStepName = json['current_step_name'],
        nextStepName = json['next_step_name'],
        progressPercentage = (json['progress_percentage'] as num).toDouble(),
        routePlan = List<String>.from(json['route_plan']),
        freshLogs = List<String>.from(json['fresh_logs']),
        hasRerouted = json['has_rerouted'] ?? false,
        rerouteReason = json['reroute_reason'];
}

class TelemetryData {
  final double rollingMean;
  final double threshold;
  final List<double> history;
  final bool isCrisis;

  TelemetryData.fromJson(Map<String, dynamic> json)
      : rollingMean = (json['rolling_mean'] as num).toDouble(),
        threshold = (json['threshold'] as num).toDouble(),
        history = (json['history'] as List).map((e) => (e as num).toDouble()).toList(),
        isCrisis = json['is_crisis'] as bool? ?? false;
}

class GlobalState {
  final List<String> activeCrises;
  final Map<String, TelemetryData> telemetryCharts;

  GlobalState.fromJson(Map<String, dynamic> json)
      : activeCrises = List<String>.from(json['active_crises']),
        telemetryCharts = (json['telemetry_charts'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(key, TelemetryData.fromJson(value)),
        );
}

class TickResponse {
  final List<ShipmentState> shipments;
  final GlobalState globalState;

  TickResponse.fromJson(Map<String, dynamic> json)
      : shipments = (json['active_shipments'] as List)
            .map((i) => ShipmentState.fromJson(i))
            .toList(),
        globalState = GlobalState.fromJson(json['global_state']);
}
