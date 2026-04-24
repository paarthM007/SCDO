import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:scdo_app/theme/glass_theme.dart';
import 'package:scdo_app/widgets/glass_container.dart';
import '../app_config.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final String baseUrl = AppConfig.gatewayBaseUrl;

  final TextEditingController _originController = TextEditingController(text: "Mumbai");
  final TextEditingController _destinationController = TextEditingController(text: "Delhi");
  String _cargoType = "general";

  bool _isLoadingRoute = false;
  bool _isLoadingSim = false;
  String _statusMessage = "";
  Map<String, dynamic>? _routeResult;
  String? _selectedRouteKey;

  // Simulation result tracking
  String? _simJobId;
  Map<String, dynamic>? _simResult;
  Timer? _pollTimer;

  final List<String> _cargoTypes = [
    "general", "electronics", "frozen_food", "perishable",
    "pharmaceuticals", "bulk_commodity", "hazmat", "vehicles", "live_animals",
  ];

  Future<Map<String, String>> _authHeaders() async {
    String? token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return {"Authorization": "Bearer $token", "Content-Type": "application/json"};
  }

  // Step 1: Find route options
  Future<void> _findRoutes() async {
    final origin = _originController.text.trim();
    final dest = _destinationController.text.trim();
    if (origin.isEmpty || dest.isEmpty) {
      setState(() => _statusMessage = "❌ Please enter both origin and destination cities.");
      return;
    }

    setState(() { _isLoadingRoute = true; _statusMessage = "🔍 Finding best routes from $origin to $dest..."; _routeResult = null; _selectedRouteKey = null; });

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/alternate-route"),
        headers: await _authHeaders(),
        body: jsonEncode({"start": origin, "end": dest, "blocked": [], "cargo_type": _cargoType}),
      );

      if (response.statusCode == 200) {
        var body = jsonDecode(response.body);
        var decoded = body["result"] ?? body;
        setState(() { _routeResult = decoded; _statusMessage = "✅ Found route options! Select one to simulate."; });
      } else {
        setState(() => _statusMessage = "❌ Server error: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _statusMessage = "❌ Network Error: $e");
    } finally {
      setState(() => _isLoadingRoute = false);
    }
  }

  // Step 2: Simulate a specific path
  Future<void> _simulatePath(String routeKey) async {
    final routeData = _routeResult?[routeKey];
    if (routeData == null || routeData.containsKey("error")) return;

    setState(() { _isLoadingSim = true; _simResult = null; _statusMessage = "⚙️ Running Monte Carlo simulation on ${routeKey.toUpperCase()} route..."; });

    try {
      final waypoints = routeData["waypoints"] as List? ?? [];
      final pathEdges = routeData["path_edges"] as List? ?? [];

      List<String> cities = [];
      List<String> modes = [];

      if (waypoints.isNotEmpty) {
        cities = waypoints.map<String>((wp) => wp["name"].toString()).toList();
      }
      if (pathEdges.isNotEmpty) {
        final modeMap = {"HIGHWAY": "road", "SEA": "ship", "AIR": "air"};
        modes = pathEdges.map<String>((e) => modeMap[e["mode"]] ?? "road").toList();
      }

      if (cities.length < 2 || modes.isEmpty) {
        setState(() => _statusMessage = "❌ Could not extract route data for simulation.");
        return;
      }

      final response = await http.post(
        Uri.parse("$baseUrl/api/simulate"),
        headers: await _authHeaders(),
        body: jsonEncode({"cities": cities, "modes": modes, "cargo_type": _cargoType}),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        _simJobId = decoded["job_id"];
        setState(() => _statusMessage = "⏳ Simulation running... Results will appear here shortly.");
        // Start polling for results
        _startPolling();
      } else {
        setState(() => _statusMessage = "❌ Simulation failed: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _statusMessage = "❌ Error: $e");
    } finally {
      setState(() => _isLoadingSim = false);
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _checkSimResult());
  }

  Future<void> _checkSimResult() async {
    if (_simJobId == null) return;
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/history"),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final jobs = decoded["history"] as List? ?? [];
        final job = jobs.firstWhere((j) => j["job_id"] == _simJobId, orElse: () => null);
        if (job != null && job["status"] == "completed") {
          _pollTimer?.cancel();
          setState(() {
            _simResult = job;
            _statusMessage = "✅ Simulation complete! See results below.";
          });
        } else if (job != null && job["status"] == "failed") {
          _pollTimer?.cancel();
          setState(() => _statusMessage = "❌ Simulation failed. Try again.");
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Input panel
          Expanded(flex: 2, child: SingleChildScrollView(child: _buildInputPanel())),
          const SizedBox(width: 32),
          // Right: Route results
          Expanded(flex: 3, child: _routeResult != null ? _buildRouteResults() : _buildEmptyState()),
        ],
      ),
    );
  }

  Widget _buildInputPanel() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Header
      Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: GlassTheme.accentNeonGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.rocket_launch, color: GlassTheme.accentNeonGreen, size: 28)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Route Simulation', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('Enter where your shipment starts and where it needs to go.', style: Theme.of(context).textTheme.bodyMedium),
        ])),
      ]),
      const SizedBox(height: 28),

      // Step 1: Origin
      GlassContainer(
        borderColor: GlassTheme.accentNeonGreen.withOpacity(0.3),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionLabel("STEP 1", "Where is your shipment?", Icons.flight_takeoff, GlassTheme.accentNeonGreen),
          const SizedBox(height: 16),
          TextField(controller: _originController, decoration: const InputDecoration(labelText: "Origin City", prefixIcon: Icon(Icons.my_location, color: GlassTheme.accentNeonGreen), hintText: "e.g. Mumbai, Shanghai, New York")),
          const SizedBox(height: 16),
          TextField(controller: _destinationController, decoration: const InputDecoration(labelText: "Destination City", prefixIcon: Icon(Icons.location_on, color: GlassTheme.accentCyan), hintText: "e.g. London, Tokyo, Dubai")),
        ]),
      ),
      const SizedBox(height: 20),

      // Step 2: Cargo type
      GlassContainer(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionLabel("STEP 2", "What are you shipping?", Icons.inventory_2, GlassTheme.accentCyan),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: _cargoTypes.map((type) {
            final isSelected = _cargoType == type;
            return InkWell(
              onTap: () => setState(() => _cargoType = type),
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? GlassTheme.accentCyan.withOpacity(0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? GlassTheme.accentCyan : Colors.white.withOpacity(0.1)),
                ),
                child: Text(type.replaceAll("_", " ").toUpperCase(), style: TextStyle(color: isSelected ? GlassTheme.accentCyan : GlassTheme.textSecondary, fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
              ),
            );
          }).toList()),
        ]),
      ),
      const SizedBox(height: 24),

      // Find Routes button
      SizedBox(
        height: 56,
        child: ElevatedButton.icon(
          onPressed: _isLoadingRoute ? null : _findRoutes,
          icon: _isLoadingRoute
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: GlassTheme.backgroundDark))
              : const Icon(Icons.search, size: 22),
          label: Text(_isLoadingRoute ? "FINDING ROUTES..." : "FIND ROUTES", style: const TextStyle(fontSize: 16, letterSpacing: 1.0)),
        ),
      ),

      // Status message
      if (_statusMessage.isNotEmpty) ...[
        const SizedBox(height: 20),
        GlassContainer(
          borderColor: _statusMessage.contains("❌") ? GlassTheme.danger : _statusMessage.contains("✅") ? GlassTheme.accentNeonGreen : GlassTheme.accentCyan,
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Icon(_statusMessage.contains("❌") ? Icons.error_outline : _statusMessage.contains("✅") ? Icons.check_circle_outline : Icons.info_outline,
              color: _statusMessage.contains("❌") ? GlassTheme.danger : _statusMessage.contains("✅") ? GlassTheme.accentNeonGreen : GlassTheme.accentCyan, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(_statusMessage, style: TextStyle(color: _statusMessage.contains("❌") ? GlassTheme.danger : GlassTheme.textPrimary, fontSize: 14))),
          ]),
        ),
      ],
    ]);
  }

  Widget _sectionLabel(String step, String title, IconData icon, Color color) {
    return Row(children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
        child: Text(step, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1))),
      const SizedBox(width: 10),
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 6),
      Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
    ]);
  }

  Widget _buildEmptyState() {
    return GlassContainer(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.route, size: 80, color: GlassTheme.accentNeonGreen.withOpacity(0.2)),
        const SizedBox(height: 24),
        Text("How it works", style: Theme.of(context).textTheme.titleLarge?.copyWith(color: GlassTheme.textSecondary)),
        const SizedBox(height: 20),
        _howItWorksStep("1", "Enter your origin and destination cities", Icons.edit_location_alt),
        const SizedBox(height: 12),
        _howItWorksStep("2", "Pick your cargo type (electronics, food, etc.)", Icons.inventory_2),
        const SizedBox(height: 12),
        _howItWorksStep("3", "Click 'Find Routes' — we find the best paths", Icons.search),
        const SizedBox(height: 12),
        _howItWorksStep("4", "Choose a route and click 'Simulate' to run Monte Carlo analysis", Icons.analytics),
        const SizedBox(height: 12),
        _howItWorksStep("5", "Check the History tab for detailed delay & cost forecasts", Icons.history),
      ]),
    );
  }

  Widget _howItWorksStep(String num, String text, IconData icon) {
    return Row(children: [
      Container(width: 28, height: 28, alignment: Alignment.center, decoration: BoxDecoration(color: GlassTheme.accentNeonGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
        child: Text(num, style: TextStyle(color: GlassTheme.accentNeonGreen, fontWeight: FontWeight.bold, fontSize: 13))),
      const SizedBox(width: 12),
      Icon(icon, size: 18, color: GlassTheme.textSecondary),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 13))),
    ]);
  }

  Widget _buildRouteResults() {
    final origin = _routeResult?["origin"] ?? _originController.text;
    final dest = _routeResult?["destination"] ?? _destinationController.text;

    return SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Icon(Icons.alt_route, color: GlassTheme.accentCyan, size: 24),
        const SizedBox(width: 12),
        Text("Route Options", style: Theme.of(context).textTheme.titleLarge),
        const Spacer(),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: GlassTheme.accentCyan.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
          child: Text("$origin → $dest", style: const TextStyle(color: GlassTheme.accentCyan, fontSize: 12, fontWeight: FontWeight.bold))),
      ]),
      const SizedBox(height: 8),
      Text("We found 3 route options. Pick one and click 'Simulate' to run a full disruption analysis.", style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 20),

      _routeOptionCard("fastest", "⚡ Fastest Route", "Minimizes travel time", Icons.speed, Colors.orangeAccent),
      const SizedBox(height: 12),
      _routeOptionCard("cheapest", "💰 Cheapest Route", "Minimizes shipping cost", Icons.savings, GlassTheme.accentNeonGreen),
      const SizedBox(height: 12),
      _routeOptionCard("balanced", "⚖️ Balanced Route", "Best mix of time & cost", Icons.balance, GlassTheme.accentCyan),

      // Simulation results inline
      if (_simResult != null) ...[
        const SizedBox(height: 24),
        _buildSimResultCard(),
      ],
    ]));
  }

  Widget _buildSimResultCard() {
    final result = _simResult!["result"] ?? _simResult!;
    final simTime = result["mean_total_time_h"] ?? result["total_time_h"];
    final simCost = result["mean_total_cost"] ?? result["total_cost_usd"];
    final riskScore = result["risk"]?["combined_risk_score"] ?? result["combined_risk_score"];
    final riskLevel = result["risk"]?["risk_level"] ?? result["risk_level"] ?? "Unknown";
    final recommendation = result["risk"]?["recommendation"] ?? result["recommendation"] ?? "";

    // Get route estimate for comparison
    final routeData = (_selectedRouteKey != null && _routeResult != null) ? _routeResult![_selectedRouteKey!] : null;
    final routeCost = routeData != null ? routeData["total_cost_usd"] : null;
    final routeTime = routeData != null ? routeData["total_time_readable"] : null;

    Color riskColor = GlassTheme.accentNeonGreen;
    if (riskLevel == "HIGH" || riskLevel == "CRITICAL") riskColor = GlassTheme.danger;
    else if (riskLevel == "MODERATE") riskColor = Colors.orangeAccent;

    return GlassContainer(
      borderColor: riskColor.withOpacity(0.4),
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: riskColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.analytics, color: riskColor, size: 24)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Simulation Results", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            Text("Monte Carlo disruption forecast", style: TextStyle(color: GlassTheme.textSecondary, fontSize: 12)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: riskColor.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
            child: Text(riskLevel.toString(), style: TextStyle(color: riskColor, fontSize: 12, fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 20),

        // Comparison: Route Estimate vs Simulation
        Row(children: [
          Expanded(child: _comparisonColumn("📋 Route Estimate", routeTime ?? "—", "\$${routeCost ?? '—'}", GlassTheme.accentCyan)),
          Container(width: 1, height: 60, color: Colors.white.withOpacity(0.1)),
          Expanded(child: _comparisonColumn("🎲 Simulation Forecast", simTime != null ? "${(simTime as num).toStringAsFixed(1)} hrs" : "—", simCost != null ? "\$${(simCost as num).toStringAsFixed(2)}" : "—", Colors.orangeAccent)),
        ]),

        if (riskScore != null) ...[
          const SizedBox(height: 16),
          Row(children: [
            Text("Risk Score: ", style: TextStyle(color: GlassTheme.textSecondary, fontSize: 13)),
            Text("${((riskScore as num) * 100).toStringAsFixed(1)}%", style: TextStyle(color: riskColor, fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: (riskScore as num).toDouble(), backgroundColor: Colors.white.withOpacity(0.1), color: riskColor, minHeight: 6)),
        ],

        if (recommendation.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: riskColor.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: riskColor.withOpacity(0.2))),
            child: Row(children: [
              Icon(Icons.lightbulb_outline, color: riskColor, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(recommendation.toString(), style: TextStyle(color: GlassTheme.textPrimary, fontSize: 12))),
            ])),
        ],
      ]),
    );
  }

  Widget _comparisonColumn(String label, String time, String cost, Color color) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(time, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: GlassTheme.textPrimary)),
        Text(cost, style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.bold)),
      ]));
  }

  Widget _routeOptionCard(String key, String title, String subtitle, IconData icon, Color color) {
    final data = _routeResult?[key];
    final hasRoute = data != null && !data.containsKey("error");
    final isSelected = _selectedRouteKey == key;

    return InkWell(
      onTap: hasRoute ? () => setState(() => _selectedRouteKey = key) : null,
      borderRadius: BorderRadius.circular(16),
      child: GlassContainer(
        borderColor: isSelected ? color.withOpacity(0.6) : hasRoute ? color.withOpacity(0.2) : GlassTheme.danger.withOpacity(0.2),
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: hasRoute ? GlassTheme.textPrimary : GlassTheme.textSecondary)),
              Text(subtitle, style: const TextStyle(color: GlassTheme.textSecondary, fontSize: 12)),
            ])),
            if (isSelected) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
              child: Text("SELECTED", style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold))),
          ]),
          if (hasRoute) ...[
            const SizedBox(height: 16),
            Row(children: [
              _metricChip("${data['total_distance_km']} km", Icons.straighten, color),
              const SizedBox(width: 8),
              _metricChip("${data['total_time_readable']}", Icons.access_time, color),
              const SizedBox(width: 8),
              _metricChip("\$${data['total_cost_usd']}", Icons.attach_money, color),
              const SizedBox(width: 8),
              _metricChip("${data['num_hops']} hops", Icons.linear_scale, color),
            ]),
            if (data['modes_used'] != null) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 6, children: (data['modes_used'] as List).map<Widget>((mode) {
                final modeIcons = {"HIGHWAY": "🚛", "SEA": "🚢", "AIR": "✈️"};
                return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(6)),
                  child: Text("${modeIcons[mode] ?? '📦'} $mode", style: const TextStyle(fontSize: 11, color: GlassTheme.textSecondary)));
              }).toList()),
            ],
            if (isSelected) ...[
              const SizedBox(height: 16),
              SizedBox(height: 44, child: ElevatedButton.icon(
                onPressed: _isLoadingSim ? null : () => _simulatePath(key),
                icon: _isLoadingSim ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: GlassTheme.backgroundDark)) : const Icon(Icons.analytics, size: 18),
                label: Text(_isLoadingSim ? "SIMULATING..." : "SIMULATE THIS ROUTE", style: const TextStyle(fontSize: 13, letterSpacing: 0.5)),
                style: ElevatedButton.styleFrom(backgroundColor: color),
              )),
            ],
          ] else
            Padding(padding: const EdgeInsets.only(top: 12), child: Text(data?["error"] ?? "No route found", style: const TextStyle(color: GlassTheme.danger, fontSize: 13))),
        ]),
      ),
    );
  }

  Widget _metricChip(String value, IconData icon, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Icon(icon, size: 14, color: color.withOpacity(0.7)),
        const SizedBox(height: 4),
        Text(value, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: GlassTheme.textPrimary)),
      ]),
    ));
  }
}

