import 'package:flutter/material.dart';
import 'package:scdo_app/theme/glass_theme.dart';
import 'package:scdo_app/widgets/glass_container.dart';

class RouteComparisonScreen extends StatefulWidget {
  final Map<String, dynamic>? routeData;

  const RouteComparisonScreen({super.key, this.routeData});

  @override
  State<RouteComparisonScreen> createState() => RouteComparisonScreenState();
}

class RouteComparisonScreenState extends State<RouteComparisonScreen> {
  Map<String, dynamic>? _data;
  String _selectedObjective = "balanced";

  @override
  void initState() {
    super.initState();
    _data = widget.routeData;
  }

  void updateData(Map<String, dynamic> data) {
    setState(() {
      _data = data;
    });
  }

  @override
  void didUpdateWidget(covariant RouteComparisonScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.routeData != oldWidget.routeData && widget.routeData != null) {
      _data = widget.routeData;
    }
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
              Expanded(child: _variantMini("Fastest", Icons.speed, Colors.orangeAccent, routes["fastest"])),
              const SizedBox(width: 12),
              Expanded(child: _variantMini("Cheapest", Icons.savings, GlassTheme.accentNeonGreen, routes["cheapest"])),
              const SizedBox(width: 12),
              Expanded(child: _variantMini("Balanced", Icons.balance, GlassTheme.accentCyan, routes["balanced"])),
            ],
          ),
          if (routes["balanced"] != null && routes["balanced"]["waypoints"] != null) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white10),
            const SizedBox(height: 8),
            Text("Balanced Route Waypoints", style: TextStyle(color: GlassTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: (routes["balanced"]["waypoints"] as List).asMap().entries.map((e) {
                final wp = e.value;
                final isLast = e.key == (routes["balanced"]["waypoints"] as List).length - 1;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: accentColor.withOpacity(0.2)),
                      ),
                      child: Text(wp["name"] ?? "", style: TextStyle(fontSize: 11, color: accentColor, fontWeight: FontWeight.w500)),
                    ),
                    if (!isLast) Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Icon(Icons.chevron_right, size: 14, color: Colors.white24)),
                  ],
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _variantMini(String label, IconData icon, Color color, Map<String, dynamic>? data) {
    final hasRoute = data != null && !data.containsKey("error");
    return Container(
      padding: const EdgeInsets.all(14),
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
            _metricRow("Distance", "${data!['total_distance_km']} km"),
            _metricRow("Time", "${data['total_time_readable']}"),
            _metricRow("Cost", "\$${data['total_cost_usd']}"),
            _metricRow("Hops", "${data['num_hops']}"),
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
