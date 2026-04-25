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

  List<TextEditingController> _cityControllers = [
    TextEditingController(text: "Mumbai"),
    TextEditingController(text: "London"),
  ];
  List<String> _modes = ["ship"];

  String _cargoType = "general";

  bool _isLoadingSim = false;
  String _statusMessage = "";

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

  void _addWaypoint() {
    setState(() {
      _cityControllers.insert(_cityControllers.length - 1, TextEditingController(text: ""));
      _modes.add("road");
    });
  }

  void _removeWaypoint(int index) {
    if (_cityControllers.length <= 2) return;
    setState(() {
      _cityControllers.removeAt(index);
      if (index == _cityControllers.length) {
        _modes.removeLast();
      } else {
        _modes.removeAt(index);
      }
    });
  }

  Future<void> _simulateManualRoute() async {
    List<String> cities = _cityControllers.map((c) => c.text.trim()).toList();
    if (cities.any((c) => c.isEmpty)) {
      setState(() => _statusMessage = "❌ Please fill in all city names.");
      return;
    }

    setState(() {
      _isLoadingSim = true;
      _simResult = null;
      _statusMessage = "⚙️ Running Monte Carlo simulation on custom route...";
    });

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/simulate"),
        headers: await _authHeaders(),
        body: jsonEncode({
          "cities": cities,
          "modes": _modes,
          "cargo_type": _cargoType,
          "source": "manual_builder"
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        _simJobId = decoded["job_id"];
        setState(() => _statusMessage = "⏳ Simulation running... Results will appear here shortly.");
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
        final jobs = decoded["jobs"] as List? ?? [];
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
    for (var c in _cityControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: SingleChildScrollView(child: _buildInputPanel())),
          const SizedBox(width: 32),
          Expanded(flex: 3, child: _simResult != null ? _buildSimResultCard() : _buildEmptyState()),
        ],
      ),
    );
  }

  Widget _buildInputPanel() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: GlassTheme.accentNeonGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.edit_road, color: GlassTheme.accentNeonGreen, size: 28)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Custom Route Builder', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('Manually define every stop and transport mode.', style: Theme.of(context).textTheme.bodyMedium),
        ])),
      ]),
      const SizedBox(height: 28),

      GlassContainer(
        borderColor: GlassTheme.accentNeonGreen.withOpacity(0.3),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionLabel("ROUTE", "Define Cities & Modes", Icons.map, GlassTheme.accentNeonGreen),
          const SizedBox(height: 24),
          
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _cityControllers.length,
            itemBuilder: (context, index) {
              final isFirst = index == 0;
              final isLast = index == _cityControllers.length - 1;
              return Column(
                children: [
                  Row(
                    children: [
                      Icon(isFirst ? Icons.my_location : isLast ? Icons.location_on : Icons.circle, 
                           color: isFirst ? GlassTheme.accentNeonGreen : isLast ? GlassTheme.accentCyan : Colors.white54, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _cityControllers[index],
                          decoration: InputDecoration(
                            labelText: isFirst ? "Origin City" : isLast ? "Destination City" : "Waypoint ${index}",
                            hintText: "City name",
                          ),
                        ),
                      ),
                      if (!isFirst && !isLast)
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: GlassTheme.danger),
                          onPressed: () => _removeWaypoint(index),
                        )
                    ],
                  ),
                  if (!isLast)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                      child: Row(
                        children: [
                          Container(width: 2, height: 40, color: Colors.white12, margin: const EdgeInsets.symmetric(horizontal: 10)),
                          const SizedBox(width: 20),
                          const Text("Via: ", style: TextStyle(color: GlassTheme.textSecondary, fontSize: 12)),
                          const SizedBox(width: 12),
                          _modeSelector(index, "road", Icons.local_shipping),
                          const SizedBox(width: 8),
                          _modeSelector(index, "air", Icons.flight),
                          const SizedBox(width: 8),
                          _modeSelector(index, "ship", Icons.directions_boat),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          
          const SizedBox(height: 20),
          Center(
            child: TextButton.icon(
              onPressed: _addWaypoint,
              icon: const Icon(Icons.add, color: GlassTheme.accentCyan),
              label: const Text("ADD WAYPOINT", style: TextStyle(color: GlassTheme.accentCyan)),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 20),

      GlassContainer(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionLabel("CARGO", "What are you shipping?", Icons.inventory_2, GlassTheme.accentCyan),
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

      SizedBox(
        height: 56,
        child: ElevatedButton.icon(
          onPressed: _isLoadingSim ? null : _simulateManualRoute,
          icon: _isLoadingSim
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: GlassTheme.backgroundDark))
              : const Icon(Icons.play_arrow, size: 22),
          label: Text(_isLoadingSim ? "SIMULATING..." : "RUN SIMULATION", style: const TextStyle(fontSize: 16, letterSpacing: 1.0)),
          style: ElevatedButton.styleFrom(backgroundColor: GlassTheme.accentNeonGreen, foregroundColor: Colors.black),
        ),
      ),

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

  Widget _modeSelector(int index, String mode, IconData icon) {
    final isSelected = _modes[index] == mode;
    return InkWell(
      onTap: () => setState(() => _modes[index] = mode),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white24 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? Colors.white54 : Colors.white10),
        ),
        child: Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.white54),
      ),
    );
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
        Icon(Icons.precision_manufacturing, size: 80, color: GlassTheme.accentNeonGreen.withOpacity(0.2)),
        const SizedBox(height: 24),
        Text("Manual Route Simulation", style: Theme.of(context).textTheme.titleLarge?.copyWith(color: GlassTheme.textSecondary)),
        const SizedBox(height: 20),
        _howItWorksStep("1", "Add all intermediate cities you want to route through", Icons.add_location),
        const SizedBox(height: 12),
        _howItWorksStep("2", "Select the specific transport mode between each stop", Icons.directions_boat),
        const SizedBox(height: 12),
        _howItWorksStep("3", "Click 'Run Simulation' to execute Monte Carlo analysis", Icons.play_arrow),
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

  Widget _buildSimResultCard() {
    final result = _simResult!["summary"] ?? _simResult!["result"] ?? _simResult!;
    final simTime = result["time_mean"] ?? result["mean_total_time_h"] ?? result["total_time_h"] ?? 0.0;
    final simCost = result["cost_mean"] ?? result["mean_total_cost"] ?? result["total_cost_usd"] ?? 0.0;
    final riskScore = result["risk_score"] ?? result["risk"]?["combined_risk_score"] ?? 0.0;
    final riskLevel = result["risk_level"] ?? result["risk"]?["risk_level"] ?? "Unknown";

    Color riskColor = GlassTheme.accentNeonGreen;
    if (riskLevel == "HIGH" || riskLevel == "CRITICAL" || riskLevel == "High") riskColor = GlassTheme.danger;
    else if (riskLevel == "MODERATE" || riskLevel == "Medium") riskColor = Colors.orangeAccent;

    return SingleChildScrollView(
      child: GlassContainer(
        borderColor: riskColor.withOpacity(0.4),
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: riskColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.analytics, color: riskColor, size: 24)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Simulation Complete", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              Text("Monte Carlo disruption forecast for custom route", style: TextStyle(color: GlassTheme.textSecondary, fontSize: 12)),
            ])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: riskColor.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
              child: Text(riskLevel.toString(), style: TextStyle(color: riskColor, fontSize: 12, fontWeight: FontWeight.bold))),
          ]),
          const SizedBox(height: 32),

          Row(children: [
            Expanded(child: _comparisonColumn("⏱️ Estimated Time", "${(simTime as num).toStringAsFixed(1)} hrs", Colors.orangeAccent)),
            Container(width: 1, height: 60, color: Colors.white.withOpacity(0.1)),
            Expanded(child: _comparisonColumn("💰 Estimated Cost", "\$${(simCost as num).toStringAsFixed(2)}", GlassTheme.accentNeonGreen)),
          ]),

          if (riskScore != null) ...[
            const SizedBox(height: 24),
            Row(children: [
              Text("Combined Risk Score: ", style: TextStyle(color: GlassTheme.textSecondary, fontSize: 13)),
              Text("${((riskScore as num) * 100).toStringAsFixed(1)}%", style: TextStyle(color: riskColor, fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
            const SizedBox(height: 8),
            ClipRRect(borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: (riskScore as num).toDouble(), backgroundColor: Colors.white.withOpacity(0.1), color: riskColor, minHeight: 6)),
          ],
          
          const SizedBox(height: 32),
          const Text("Note: This route was saved to your History tab. You can view the full interactive map and detailed breakdown there.", 
            style: TextStyle(color: GlassTheme.textSecondary, fontSize: 12, fontStyle: FontStyle.italic)),
        ]),
      ),
    );
  }

  Widget _comparisonColumn(String label, String value, Color color) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        Text(label, style: TextStyle(color: GlassTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: color)),
      ]));
  }
}

