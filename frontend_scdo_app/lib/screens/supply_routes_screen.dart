import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:scdo_app/theme/glass_theme.dart';
import 'package:scdo_app/widgets/glass_container.dart';
import '../app_config.dart';

class SupplyRoutesScreen extends StatefulWidget {
  final void Function(Map<String, dynamic> data)? onResultsReady;
  const SupplyRoutesScreen({super.key, this.onResultsReady});
  @override
  State<SupplyRoutesScreen> createState() => _SupplyRoutesScreenState();
}

class _SupplyRoutesScreenState extends State<SupplyRoutesScreen>
    with SingleTickerProviderStateMixin {
  final String baseUrl = AppConfig.gatewayBaseUrl;
  final TextEditingController _buyerController = TextEditingController(text: "London");
  String _cargoType = "general";

  final List<TextEditingController> _supplierControllers = [
    TextEditingController(text: "Mumbai"),
    TextEditingController(text: "Shanghai"),
  ];

  // Smart disruption controls
  bool _avoidDisruptions = true;
  double _riskThreshold = 0.65; // 0.45=Low, 0.65=Medium, 0.85=High tolerance

  bool _isLoading = false;
  String _statusMessage = "";
  Map<String, dynamic>? _lastResult;
  late AnimationController _pulseController;

  final List<String> _cargoTypes = [
    "general", "electronics", "frozen_food", "perishable",
    "pharmaceuticals", "bulk_commodity", "hazmat", "vehicles", "live_animals",
  ];

  String get _riskLabel {
    if (_riskThreshold <= 0.35) return "STRICT";
    if (_riskThreshold <= 0.55) return "CAUTIOUS";
    if (_riskThreshold <= 0.75) return "BALANCED";
    return "AGGRESSIVE";
  }

  Color get _riskColor {
    if (_riskThreshold <= 0.35) return GlassTheme.danger;
    if (_riskThreshold <= 0.55) return Colors.orangeAccent;
    if (_riskThreshold <= 0.75) return GlassTheme.accentCyan;
    return GlassTheme.accentNeonGreen;
  }

  String get _riskDescription {
    if (_riskThreshold <= 0.35) return "Avoid even slightly risky cities. Safest routes, may be longer.";
    if (_riskThreshold <= 0.55) return "Avoid moderately risky cities. Good balance of safety.";
    if (_riskThreshold <= 0.75) return "Only avoid high-risk cities. Standard routing.";
    return "Only avoid extreme disruptions. Fastest/cheapest routes.";
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _buyerController.dispose();
    for (var c in _supplierControllers) { c.dispose(); }
    super.dispose();
  }

  void _addSupplier() => setState(() => _supplierControllers.add(TextEditingController()));

  void _removeSupplier(int index) {
    if (_supplierControllers.length <= 1) return;
    setState(() { _supplierControllers[index].dispose(); _supplierControllers.removeAt(index); });
  }

  Future<Map<String, String>> _authHeaders() async {
    String? token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return { "Authorization": "Bearer $token", "Content-Type": "application/json" };
  }

  Future<void> _findMultiSupplierRoutes() async {
    final buyer = _buyerController.text.trim();
    final suppliers = _supplierControllers.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    if (buyer.isEmpty) { setState(() => _statusMessage = "❌ Please enter a buyer city."); return; }
    if (suppliers.isEmpty) { setState(() => _statusMessage = "❌ Please add at least one supplier city."); return; }

    setState(() { _isLoading = true; _statusMessage = "🔍 Scanning disruptions & finding routes..."; _lastResult = null; });

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/multi-supplier-routes"),
        headers: await _authHeaders(),
        body: jsonEncode({
          "buyer": buyer,
          "suppliers": suppliers,
          "cargo_type": _cargoType,
          "risk_threshold": _riskThreshold,
          "avoid_disruptions": _avoidDisruptions,
        }),
      );

      if (response.statusCode == 200) {
        var decoded = jsonDecode(response.body);
        if (decoded["status"] == "ok") {
          setState(() { _lastResult = decoded; _statusMessage = "✅ Found routes for ${decoded['supplier_count']} supplier(s)"; });
          widget.onResultsReady?.call(decoded);
        } else {
          setState(() => _statusMessage = "⚠️ ${decoded['error'] ?? 'Unknown error'}");
        }
      } else {
        setState(() => _statusMessage = "❌ Server error: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _statusMessage = "❌ Network Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
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
          Expanded(flex: 3, child: _lastResult != null ? _buildQuickSummary() : _buildEmptyState()),
        ],
      ),
    );
  }

  Widget _buildInputPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: GlassTheme.accentCyan.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.hub, color: GlassTheme.accentCyan, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Multi-Supplier Routing', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text('Smart disruption-aware route finding across multiple suppliers.', style: Theme.of(context).textTheme.bodyMedium),
          ])),
        ]),
        const SizedBox(height: 28),

        // Buyer
        GlassContainer(
          borderColor: GlassTheme.accentNeonGreen.withOpacity(0.3),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.store, color: GlassTheme.accentNeonGreen, size: 20),
              const SizedBox(width: 8),
              Text("BUYER (Destination)", style: TextStyle(color: GlassTheme.accentNeonGreen, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2)),
            ]),
            const SizedBox(height: 16),
            TextField(controller: _buyerController, decoration: const InputDecoration(labelText: "Buyer City", prefixIcon: Icon(Icons.location_city, color: GlassTheme.accentNeonGreen), hintText: "e.g. London, New York, Tokyo")),
          ]),
        ),
        const SizedBox(height: 20),

        // Suppliers
        GlassContainer(
          borderColor: GlassTheme.accentCyan.withOpacity(0.3),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.factory, color: GlassTheme.accentCyan, size: 20),
              const SizedBox(width: 8),
              Text("SUPPLIERS (Origins)", style: TextStyle(color: GlassTheme.accentCyan, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: GlassTheme.accentCyan.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                child: Text("${_supplierControllers.length} supplier(s)", style: TextStyle(color: GlassTheme.accentCyan, fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 16),
            ..._supplierControllers.asMap().entries.map((entry) {
              final idx = entry.key;
              final controller = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(children: [
                  Container(width: 28, height: 28, alignment: Alignment.center, decoration: BoxDecoration(color: GlassTheme.accentCyan.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                    child: Text("${idx + 1}", style: TextStyle(color: GlassTheme.accentCyan, fontWeight: FontWeight.bold, fontSize: 13))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: controller, decoration: InputDecoration(labelText: "Supplier ${idx + 1}", prefixIcon: const Icon(Icons.local_shipping, color: GlassTheme.accentCyan), hintText: "e.g. Mumbai, Shanghai"))),
                  const SizedBox(width: 8),
                  if (_supplierControllers.length > 1)
                    IconButton(icon: const Icon(Icons.remove_circle_outline, color: GlassTheme.danger, size: 22), onPressed: () => _removeSupplier(idx)),
                ]),
              );
            }),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: _addSupplier, icon: const Icon(Icons.add, size: 18), label: const Text("Add Supplier"),
              style: OutlinedButton.styleFrom(foregroundColor: GlassTheme.accentCyan, side: BorderSide(color: GlassTheme.accentCyan.withOpacity(0.3)), padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20))),
          ]),
        ),
        const SizedBox(height: 20),

        // Smart Disruption Controls
        GlassContainer(
          borderColor: _avoidDisruptions ? _riskColor.withOpacity(0.3) : Colors.white.withOpacity(0.1),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.shield, color: _avoidDisruptions ? _riskColor : GlassTheme.textSecondary, size: 20),
              const SizedBox(width: 8),
              Text("DISRUPTION AVOIDANCE", style: TextStyle(color: _avoidDisruptions ? _riskColor : GlassTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2)),
              const Spacer(),
              Switch(
                value: _avoidDisruptions,
                onChanged: (v) => setState(() => _avoidDisruptions = v),
                activeColor: _riskColor,
              ),
            ]),
            if (_avoidDisruptions) ...[
              const SizedBox(height: 12),
              Row(children: [
                Text("Risk Tolerance:", style: TextStyle(color: GlassTheme.textSecondary, fontSize: 13)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _riskColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                  child: Text(_riskLabel, style: TextStyle(color: _riskColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ]),
              const SizedBox(height: 8),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(activeTrackColor: _riskColor, thumbColor: _riskColor, inactiveTrackColor: Colors.white.withOpacity(0.1), overlayColor: _riskColor.withOpacity(0.1)),
                child: Slider(value: _riskThreshold, min: 0.2, max: 0.9, divisions: 14, onChanged: (v) => setState(() => _riskThreshold = v)),
              ),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text("Strict", style: TextStyle(fontSize: 10, color: GlassTheme.danger.withOpacity(0.7))),
                Text("Aggressive", style: TextStyle(fontSize: 10, color: GlassTheme.accentNeonGreen.withOpacity(0.7))),
              ]),
              const SizedBox(height: 8),
              Text(_riskDescription, style: TextStyle(color: GlassTheme.textSecondary, fontSize: 12, fontStyle: FontStyle.italic)),
            ],
          ]),
        ),
        const SizedBox(height: 20),

        // Cargo Type
        GlassContainer(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.tune, color: GlassTheme.textSecondary, size: 20),
              const SizedBox(width: 8),
              Text("CARGO TYPE", style: TextStyle(color: GlassTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2)),
            ]),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _cargoType,
              decoration: const InputDecoration(labelText: "Cargo Type", prefixIcon: Icon(Icons.inventory_2)),
              dropdownColor: GlassTheme.backgroundCard,
              items: _cargoTypes.map((type) => DropdownMenuItem(value: type, child: Text(type.replaceAll("_", " ").toUpperCase(), style: const TextStyle(fontSize: 14)))).toList(),
              onChanged: (val) { if (val != null) setState(() => _cargoType = val); },
            ),
          ]),
        ),
        const SizedBox(height: 24),

        // Find button
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) => Container(
            decoration: _isLoading ? null : BoxDecoration(borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: GlassTheme.accentNeonGreen.withOpacity(0.15 + _pulseController.value * 0.1), blurRadius: 20, spreadRadius: 2)]),
            child: child,
          ),
          child: SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _findMultiSupplierRoutes,
              icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: GlassTheme.backgroundDark)) : const Icon(Icons.search, size: 22),
              label: Text(_isLoading ? "SCANNING & ROUTING..." : "FIND ALL SUPPLY ROUTES", style: const TextStyle(fontSize: 16, letterSpacing: 1.0)),
            ),
          ),
        ),

        // Status
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
      ],
    );
  }

  Widget _buildEmptyState() {
    return GlassContainer(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.hub, size: 80, color: GlassTheme.accentCyan.withOpacity(0.2)),
        const SizedBox(height: 24),
        Text("Smart Supply Route Discovery", style: Theme.of(context).textTheme.titleLarge?.copyWith(color: GlassTheme.textSecondary)),
        const SizedBox(height: 12),
        Text("The system automatically scans for weather, news, and\ncommunity-reported disruptions along your routes.", textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _featureChip(Icons.cloud, "Weather Risk"),
          const SizedBox(width: 8),
          _featureChip(Icons.newspaper, "News Sentiment"),
          const SizedBox(width: 8),
          _featureChip(Icons.people, "Community Intel"),
        ]),
      ]),
    );
  }

  Widget _featureChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: GlassTheme.accentCyan.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: GlassTheme.accentCyan.withOpacity(0.2))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: GlassTheme.accentCyan),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: GlassTheme.accentCyan, fontSize: 11)),
      ]),
    );
  }

  Widget _buildQuickSummary() {
    final comparison = (_lastResult!["comparison"] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final buyer = _lastResult!["buyer"] ?? "";

    return GlassContainer(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.analytics, color: GlassTheme.accentCyan, size: 24),
          const SizedBox(width: 12),
          Text("Quick Summary", style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: GlassTheme.accentNeonGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
            child: Text("Buyer: $buyer", style: const TextStyle(color: GlassTheme.accentNeonGreen, fontSize: 13)),
          ),
        ]),
        const SizedBox(height: 8),
        Text("Switch to the Route Comparison tab for full analysis.", style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 20),
        Expanded(
          child: ListView.separated(
            itemCount: comparison.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = comparison[index];
              final supplier = item["supplier"] ?? "Unknown";
              final balanced = item["balanced"];
              final hasRoute = balanced != null && !balanced.containsKey("error");
              final disruptions = item["disruptions"] as Map<String, dynamic>? ?? {};
              final avoidedCount = disruptions["avoided_count"] ?? 0;
              final flaggedCities = (disruptions["flagged_cities"] as List?)?.cast<Map<String, dynamic>>() ?? [];

              return GlassContainer(
                borderColor: hasRoute ? GlassTheme.accentCyan.withOpacity(0.3) : GlassTheme.danger.withOpacity(0.3),
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: (hasRoute ? GlassTheme.accentCyan : GlassTheme.danger).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                      child: Icon(hasRoute ? Icons.factory : Icons.error_outline, color: hasRoute ? GlassTheme.accentCyan : GlassTheme.danger, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(supplier, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text("→ $buyer", style: const TextStyle(color: GlassTheme.textSecondary, fontSize: 12)),
                    ])),
                    if (avoidedCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.warning_amber, size: 12, color: Colors.orangeAccent),
                          const SizedBox(width: 4),
                          Text("$avoidedCount avoided", style: const TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    const SizedBox(width: 8),
                    if (hasRoute)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: GlassTheme.accentNeonGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                        child: const Text("Route Found", style: TextStyle(color: GlassTheme.accentNeonGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                  ]),
                  // Disruption badges
                  if (flaggedCities.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(spacing: 6, runSpacing: 4, children: flaggedCities.map((fc) {
                      final isAvoided = fc["action"] == "auto_avoided";
                      final color = isAvoided ? GlassTheme.danger : Colors.orangeAccent;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(isAvoided ? Icons.block : Icons.warning, size: 10, color: color),
                          const SizedBox(width: 4),
                          Text("${fc['city']}", style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                        ]),
                      );
                    }).toList()),
                  ],
                  if (hasRoute) ...[
                    const SizedBox(height: 14),
                    Row(children: [
                      _summaryMetric("Distance", "${balanced['total_distance_km']} km", Icons.straighten),
                      const SizedBox(width: 20),
                      _summaryMetric("Time", "${balanced['total_time_readable']}", Icons.access_time),
                      const SizedBox(width: 20),
                      _summaryMetric("Cost", "\$${balanced['total_cost_usd']}", Icons.attach_money),
                      const SizedBox(width: 20),
                      _summaryMetric("Hops", "${balanced['num_hops']}", Icons.linear_scale),
                    ]),
                  ] else
                    Padding(padding: const EdgeInsets.only(top: 10), child: Text(balanced?["error"] ?? "No route found", style: const TextStyle(color: GlassTheme.danger, fontSize: 13))),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _summaryMetric(String label, String value, IconData icon) {
    return Expanded(child: Column(children: [
      Icon(icon, size: 16, color: GlassTheme.textSecondary),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: GlassTheme.textPrimary)),
      Text(label, style: const TextStyle(fontSize: 10, color: GlassTheme.textSecondary)),
    ]));
  }
}
