import 'package:flutter/material.dart';
import 'package:scdo_app/theme/glass_theme.dart';
import 'package:scdo_app/widgets/glass_container.dart';
import 'package:scdo_app/widgets/path_visualizer.dart';
import 'package:scdo_app/widgets/route_graph_painter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class RouteComparisonScreen extends StatefulWidget {
  final Map<String, dynamic>? routeData;
  final String? productType;

  const RouteComparisonScreen({super.key, this.routeData, this.productType});

  @override
  State<RouteComparisonScreen> createState() => RouteComparisonScreenState();
}

class RouteComparisonScreenState extends State<RouteComparisonScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? _data;
  String _selectedObjective = "balanced";
  
  // ── Animation & Simulation State ──
  AnimationController? _animController;
  Map<String, dynamic>? _selectedRouteData;
  String? _animatingKey;
  Map<String, bool> _simulatingPath = {};
  String _result = "";

  @override
  void initState() {
    super.initState();
    _data = widget.routeData;
  }

  @override
  void dispose() {
    _animController?.dispose();
    super.dispose();
  }

  void updateData(Map<String, dynamic> data) {
    setState(() {
      _data = data;
    });
  }

  // ── Simulation Logic (Adapted from AltRouteScreen) ──
  Future<void> _simulatePath(String supplierName, String objective, Map<String, dynamic> routeData) async {
    final key = "${supplierName}_$objective";
    setState(() => _simulatingPath[key] = true);
    try {
      final pathEdges = routeData["path_edges"] as List? ?? [];
      final waypoints = routeData["waypoints"] as List? ?? [];
      
      List<String> cities = waypoints.map<String>((wp) => wp["name"].toString()).toList();
      final modeMap = {"HIGHWAY": "road", "SEA": "ship", "AIR": "air"};
      List<String> modes = pathEdges.map<String>((e) => modeMap[e["mode"]] ?? "road").toList();

      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.post(
        Uri.parse("${AppConfig.gatewayBaseUrl}/api/simulate"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "cities": cities,
          "modes": modes,
          "path_edges": pathEdges,
          "product_type": widget.productType ?? "general",
          "source": "multi_supplier_$key",
        }),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ Simulation queued for $supplierName ($objective)")),
        );
      }
    } catch (e) {
      print("Simulation Error: $e");
    } finally {
      setState(() => _simulatingPath[key] = false);
    }
  }

  void _startPlayback(String key, Map<String, dynamic> pathData) {
    setState(() {
      _selectedRouteData = pathData;
      _animatingKey = key;
    });

    _animController?.dispose();
    final pathEdges = (pathData["path_edges"] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (pathEdges.isEmpty) return;

    final totalTimeH = pathEdges.fold<double>(0.0, (sum, e) => sum + ((e['time_h'] as num?)?.toDouble() ?? 1.0));
    final durationSec = (totalTimeH * 0.5).clamp(3.0, 20.0).round();

    _animController = AnimationController(vsync: this, duration: Duration(seconds: durationSec));
    _animController!.addListener(() => setState(() {}));
    _animController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) setState(() => _animatingKey = null);
    });
    _animController!.forward();
  }

  @override
  Widget build(BuildContext context) {
    if (_data == null) {
      return _buildEmptyState(context);
    }

    final buyer = _data!["buyer"] ?? "Unknown";
    final supplierRoutes = (_data!["supplier_routes"] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final comparison = (_data!["comparison"] as List?)?.cast<Map<String, dynamic>>() ?? [];

    if (supplierRoutes.isEmpty) {
      return _buildEmptyState(context);
    }

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.purpleAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.compare_arrows, color: Colors.purpleAccent, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Route Comparison', style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 4),
                          Text('Comparing ${supplierRoutes.length} supplier route(s) to $buyer', style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    _objectiveChip("fastest", Icons.speed, Colors.orangeAccent),
                    const SizedBox(width: 8),
                    _objectiveChip("cheapest", Icons.savings, GlassTheme.accentNeonGreen),
                    const SizedBox(width: 8),
                    _objectiveChip("balanced", Icons.balance, GlassTheme.accentCyan),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildComparisonHeader(),
                        const SizedBox(height: 8),
                        ...comparison.asMap().entries.map((entry) {
                          return _buildComparisonRow(entry.key, entry.value, supplierRoutes);
                        }),
                        const SizedBox(height: 32),
                        Text("Detailed Route Breakdown", style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 16),
                        ...supplierRoutes.asMap().entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildDetailedCard(entry.key, entry.value),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 32),
          // ── Right Side Graph ──
          Expanded(
            flex: 1,
            child: GlassContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text("Route Visualization", style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
                      child: InteractiveRouteGraph(
                        routeData: _selectedRouteData,
                        shipmentProgress: _animatingKey != null ? _animController?.value ?? -1 : -1,
                      ),
                    ),
                  ),
                  if (_selectedRouteData != null) ...[
                    const SizedBox(height: 16),
                    Text("Selected: ${_selectedRouteData?['origin']} → ${_selectedRouteData?['destination']}", 
                      style: TextStyle(color: GlassTheme.accentCyan, fontWeight: FontWeight.bold)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _objectiveChip(String key, IconData icon, Color color) {
    final isSelected = _selectedObjective == key;
    return InkWell(
      onTap: () => setState(() => _selectedObjective = key),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? color : Colors.white.withOpacity(0.1), width: isSelected ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? color : GlassTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              key.toUpperCase(),
              style: TextStyle(
                color: isSelected ? color : GlassTheme.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonHeader() {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      borderColor: Colors.white.withOpacity(0.15),
      child: Row(
        children: [
          const SizedBox(width: 40, child: Text("#", style: TextStyle(fontWeight: FontWeight.bold, color: GlassTheme.textSecondary, fontSize: 13))),
          const Expanded(flex: 3, child: Text("SUPPLIER", style: TextStyle(fontWeight: FontWeight.bold, color: GlassTheme.textSecondary, fontSize: 13, letterSpacing: 1))),
          _headerCell("DISTANCE"),
          _headerCell("TIME"),
          _headerCell("COST"),
          _headerCell("HOPS"),
          _headerCell("MODES"),
          const SizedBox(width: 80, child: Text("STATUS", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: GlassTheme.textSecondary, fontSize: 13, letterSpacing: 1))),
        ],
      ),
    );
  }

  Widget _headerCell(String label) {
    return Expanded(
      flex: 2,
      child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: GlassTheme.textSecondary, fontSize: 13, letterSpacing: 1)),
    );
  }

  Widget _buildComparisonRow(int index, Map<String, dynamic> item, List<Map<String, dynamic>> allRoutes) {
    final supplier = item["supplier"] ?? "Unknown";
    final routeData = item[_selectedObjective];
    final hasRoute = routeData != null && !routeData.containsKey("error");

    final rowColors = [GlassTheme.accentCyan, Colors.purpleAccent, Colors.orangeAccent, GlassTheme.accentNeonGreen, Colors.pinkAccent, Colors.tealAccent];
    final rowColor = rowColors[index % rowColors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        borderColor: Colors.white.withOpacity(0.05),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: rowColor.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: Text("${index + 1}", style: TextStyle(color: rowColor, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(supplier, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            _dataCell(hasRoute ? "${routeData['total_distance_km']} km" : "—"),
            _dataCell(hasRoute ? "${routeData['total_time_readable']}" : "—"),
            _dataCell(hasRoute ? "\$${routeData['total_cost_usd']}" : "—"),
            _dataCell(hasRoute ? "${routeData['num_hops']}" : "—"),
            _dataCell(hasRoute ? (routeData['modes_used'] as List?)?.join(", ") ?? "—" : "—"),
            SizedBox(
              width: 80,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (hasRoute ? GlassTheme.accentNeonGreen : GlassTheme.danger).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    hasRoute ? "OK" : "FAIL",
                    style: TextStyle(color: hasRoute ? GlassTheme.accentNeonGreen : GlassTheme.danger, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dataCell(String text) {
    return Expanded(
      flex: 2,
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: GlassTheme.textPrimary)),
    );
  }

  Widget _buildDetailedCard(int index, Map<String, dynamic> supplierRoute) {
    final supplier = supplierRoute["supplier"] ?? "Unknown";
    final buyer = supplierRoute["buyer"] ?? "Unknown";
    final routes = supplierRoute["routes"] as Map<String, dynamic>? ?? {};

    final rowColors = [GlassTheme.accentCyan, Colors.purpleAccent, Colors.orangeAccent, GlassTheme.accentNeonGreen, Colors.pinkAccent, Colors.tealAccent];
    final accentColor = rowColors[index % rowColors.length];

    return GlassContainer(
      borderColor: accentColor.withOpacity(0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: accentColor.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.factory, color: accentColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(supplier, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: accentColor)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.arrow_forward, size: 14, color: GlassTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(buyer, style: const TextStyle(color: GlassTheme.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _variantMini(supplier, "Fastest", Icons.speed, Colors.orangeAccent, routes["fastest"])),
              const SizedBox(width: 12),
              Expanded(child: _variantMini(supplier, "Cheapest", Icons.savings, GlassTheme.accentNeonGreen, routes["cheapest"])),
              const SizedBox(width: 12),
              Expanded(child: _variantMini(supplier, "Balanced", Icons.balance, GlassTheme.accentCyan, routes["balanced"])),
            ],
          ),
          if (routes["balanced"] != null && routes["balanced"]["path_edges"] != null) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white10),
            const SizedBox(height: 8),
            Text("DETAILED PATHS", style: TextStyle(color: GlassTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 12),
            _buildPathRow("FASTEST", routes["fastest"], Colors.orangeAccent),
            const SizedBox(height: 12),
            _buildPathRow("CHEAPEST", routes["cheapest"], GlassTheme.accentNeonGreen),
            const SizedBox(height: 12),
            _buildPathRow("BALANCED", routes["balanced"], GlassTheme.accentCyan),
          ],
        ],
      ),
    );
  }

  Widget _buildPathRow(String label, Map<String, dynamic>? data, Color color) {
    if (data == null || data.containsKey("error")) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        PathVisualizer(pathEdges: data["path_edges"], accentColor: color),
      ],
    );
  }

  Widget _variantMini(String supplier, String label, IconData icon, Color color, Map<String, dynamic>? data) {
    final hasRoute = data != null && !data.containsKey("error");
    final key = "${supplier}_${label.toLowerCase()}";
    final isAnimating = _animatingKey == key;
    final isSimulating = _simulatingPath[key] == true;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          if (hasRoute) ...[
            _metricRow("Dist", "${data!['total_distance_km']} km"),
            _metricRow("Time", "${data['total_time_readable']}"),
            _metricRow("Cost", "\$${data['total_cost_usd']}"),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _startPlayback(key, data),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: Icon(isAnimating ? Icons.pause : Icons.play_arrow, size: 16, color: color),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: InkWell(
                    onTap: isSimulating ? null : () => _simulatePath(supplier, label.toLowerCase(), data),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: isSimulating 
                        ? SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: color))
                        : Icon(Icons.science, size: 14, color: color),
                    ),
                  ),
                ),
              ],
            ),
          ] else
            Text(data?["error"] ?? "No route", style: const TextStyle(color: GlassTheme.danger, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _metricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: GlassTheme.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: GlassTheme.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: GlassContainer(
        width: 500,
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.compare_arrows, size: 80, color: Colors.purpleAccent.withOpacity(0.3)),
            const SizedBox(height: 24),
            Text("No Routes to Compare", style: Theme.of(context).textTheme.titleLarge?.copyWith(color: GlassTheme.textSecondary)),
            const SizedBox(height: 12),
            Text("Go to the Supply Routes tab, add suppliers and a buyer,\nthen click 'Find All Supply Routes' to see comparisons here.", textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
