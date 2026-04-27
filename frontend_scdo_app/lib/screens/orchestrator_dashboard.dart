import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import '../models.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_container.dart';

// ═══════════════════════════════════════════════════════════════════
// OrchestratorDashboard — The main "Control Room" screen.
// Accepts ShipmentState and GlobalState to drive the entire UI.
// ═══════════════════════════════════════════════════════════════════
class OrchestratorDashboard extends StatefulWidget {
  /// The current state of the active shipment (null before dispatch).
  final ShipmentState? shipmentState;

  /// Global system state (crises, telemetry).
  final GlobalState? globalState;

  /// Accumulated decision logs for the audit trail.
  final List<String> allLogs;

  /// Callback when user selects cargo and hits "Run Scenario".
  final void Function(String cargoType)? onDispatch;

  /// Callback when the simulation tick button is pressed.
  final void Function(double hours)? onTick;

  /// Callback to trigger OSINT sync.
  final VoidCallback? onSyncOsint;

  const OrchestratorDashboard({
    super.key,
    this.shipmentState,
    this.globalState,
    this.allLogs = const [],
    this.onDispatch,
    this.onTick,
    this.onSyncOsint,
  });

  @override
  State<OrchestratorDashboard> createState() => _OrchestratorDashboardState();
}

class _OrchestratorDashboardState extends State<OrchestratorDashboard> {
  String _selectedCargo = 'PERISHABLE';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GlassTheme.backgroundDark,
      body: Column(
        children: [
          // ── TOP CONTROL BAR ──
          _buildControlBar(),
          // ── MAIN CONTENT: Map (65%) + Sidebar (35%) ──
          Expanded(
            child: Row(
              children: [
                // Left: Schematic Map
                Expanded(flex: 65, child: _buildMapZone()),
                // Right: Telemetry + Audit
                Expanded(flex: 35, child: _buildSidebar()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TASK 1: TOP CONTROL BAR
  // ═══════════════════════════════════════════════════════════════
  Widget _buildControlBar() {
    final cargoOptions = {
      'PERISHABLE': '🐟 PERISHABLE',
      'HAZMAT': '🛢️ HAZMAT',
      'BULK': '🧱 BULK',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: GlassTheme.backgroundCard,
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
          // Title
          Icon(Icons.radar, color: GlassTheme.accentCyan, size: 28),
          const SizedBox(width: 12),
          Text('SCDO: Live Orchestrator',
              style: GoogleFonts.outfit(color: GlassTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          // Status pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (widget.shipmentState != null ? GlassTheme.accentNeonGreen : Colors.grey).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.shipmentState?.status ?? 'IDLE',
              style: TextStyle(
                color: widget.shipmentState != null ? GlassTheme.accentNeonGreen : Colors.grey,
                fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(width: 24),
          // Cargo selector chips
          ...cargoOptions.entries.map((e) {
            final isSelected = _selectedCargo == e.key;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                label: Text(e.value, style: TextStyle(
                  color: isSelected ? GlassTheme.backgroundDark : GlassTheme.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 12,
                )),
                backgroundColor: isSelected ? GlassTheme.accentCyan : Colors.white.withOpacity(0.06),
                side: BorderSide(color: isSelected ? GlassTheme.accentCyan : Colors.white.withOpacity(0.1)),
                onPressed: () => setState(() => _selectedCargo = e.key),
              ),
            );
          }),
          const SizedBox(width: 8),
          // Run Scenario button
          ElevatedButton.icon(
            onPressed: widget.onDispatch != null ? () => widget.onDispatch!(_selectedCargo) : null,
            icon: const Icon(Icons.play_arrow, size: 20),
            label: const Text('Run Scenario', style: TextStyle(fontSize: 13, letterSpacing: 0.5)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2ECC71),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(width: 12),
          // Sync OSINT button
          OutlinedButton.icon(
            onPressed: (widget.shipmentState != null && widget.onSyncOsint != null) ? widget.onSyncOsint : null,
            icon: const Icon(Icons.sync, size: 18),
            label: const Text('Sync OSINT', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: GlassTheme.accentCyan,
              side: BorderSide(color: GlassTheme.accentCyan.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TASK 2: SCHEMATIC MAP ZONE
  // ═══════════════════════════════════════════════════════════════
  Widget _buildMapZone() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GlassContainer(
        padding: const EdgeInsets.all(0),
        child: SchematicMapWidget(
          shipmentState: widget.shipmentState,
          activeCrises: widget.globalState?.activeCrises ?? [],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TASK 3: SIDEBAR (Telemetry + Audit Trail)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSidebar() {
    return Padding(
      padding: const EdgeInsets.only(top: 16, right: 16, bottom: 16),
      child: Column(
        children: [
          // Top half: Telemetry Chart
          Expanded(
            flex: 1,
            child: GlassContainer(
              padding: const EdgeInsets.all(16),
              child: TelemetryChartWidget(
                globalState: widget.globalState,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Bottom half: Audit Trail / Thought Process
          Expanded(
            flex: 1,
            child: AuditTrailWidget(
              logs: widget.allLogs,
              onTick: widget.onTick,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SchematicMapWidget — Abstract network map with animated truck.
// ═══════════════════════════════════════════════════════════════════
class SchematicMapWidget extends StatelessWidget {
  final ShipmentState? shipmentState;
  final List<String> activeCrises;

  // Node positions as fraction of container (x: left→right, y: top→bottom)
  // Layout: Delhi (far left), inland cities cascade right, ports cluster middle-right, Dubai (far right)
  static const _nodes = {
    // Origin
    'New Delhi':   Offset(0.08, 0.55),
    // Inland northern corridor (STANDARD/BULK route)
    'Jaipur':      Offset(0.22, 0.40),
    'Rajsamand':   Offset(0.35, 0.28),
    'Banaskantha': Offset(0.48, 0.22),
    'Kandla':      Offset(0.62, 0.18),
    // Inland western corridor
    'Ahmedabad':   Offset(0.42, 0.42),
    'Inland Depot':Offset(0.38, 0.55),
    'Surat':       Offset(0.52, 0.58),
    // Ports
    'Mumbai':      Offset(0.62, 0.70),
    'Mundra':      Offset(0.72, 0.30),
    'JNPT':        Offset(0.62, 0.70), // Positioned at Mumbai's spot for the demo
    // Destination
    'Dubai':       Offset(0.92, 0.45),
  };

  static const _edges = [
    // Northern inland corridor
    ['New Delhi', 'Jaipur'],
    ['Jaipur', 'Rajsamand'],
    ['Rajsamand', 'Banaskantha'],
    ['Banaskantha', 'Kandla'],
    ['Kandla', 'Dubai'],
    // Via Ahmedabad
    ['New Delhi', 'Ahmedabad'],
    ['Ahmedabad', 'Mumbai'],
    ['Ahmedabad', 'Mundra'],
    // Via Surat / Inland Depot
    ['New Delhi', 'Inland Depot'],
    ['Inland Depot', 'Surat'],
    ['Surat', 'Mumbai'],
    // Direct sea legs
    ['Mumbai', 'Dubai'],
    ['Mundra', 'Dubai'],
    // Presentation direct legs
    ['New Delhi', 'JNPT'],
    ['JNPT', 'Dubai'],
    // Direct air leg
    ['New Delhi', 'Dubai'],
  ];

  const SchematicMapWidget({super.key, this.shipmentState, this.activeCrises = const []});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;

      // Determine which node is the "current" and "next" for the truck
      final currentName = shipmentState?.currentStepName ?? '';
      final nextName = shipmentState?.nextStepName ?? '';
      final progress = shipmentState?.progressPercentage ?? 0.0;
      final routePlan = shipmentState?.routePlan ?? [];

      // Find closest matching node keys
      final currentKey = _findNodeKey(currentName);
      final nextKey = _findNodeKey(nextName);

      return Stack(
        children: [
          // Grid background pattern
          CustomPaint(size: Size(w, h), painter: _GridPainter()),
          // Draw edges
          ..._edges.map((edge) {
            final from = _nodes[edge[0]]!;
            final to = _nodes[edge[1]]!;
            final isCrisis = activeCrises.any((c) => edge[0].contains(c) || edge[1].contains(c));
            // Check if this edge is part of the active route
            final isActive = routePlan.isNotEmpty && _edgeInRoute(edge[0], edge[1], routePlan);
            Color lineColor = Colors.white.withOpacity(0.12);
            if (isCrisis) lineColor = GlassTheme.danger.withOpacity(0.7);
            else if (isActive) lineColor = GlassTheme.accentCyan.withOpacity(0.5);

            return CustomPaint(
              size: Size(w, h),
              painter: _EdgePainter(
                Offset(from.dx * w, from.dy * h),
                Offset(to.dx * w, to.dy * h),
                lineColor,
                isActive ? 2.5 : 1.5,
              ),
            );
          }),
          // Draw nodes
          ..._nodes.entries.map((entry) {
            final pos = entry.value;
            final name = entry.key;
            final isCrisis = activeCrises.any((c) => name.contains(c));
            final isCurrent = currentKey == name;
            Color nodeColor = Colors.white.withOpacity(0.4);
            if (isCrisis) nodeColor = GlassTheme.danger;
            else if (isCurrent) nodeColor = GlassTheme.accentCyan;
            else if (routePlan.any((r) => name.contains(r) || r.contains(name))) {
              nodeColor = GlassTheme.accentNeonGreen;
            }

            return Positioned(
              left: pos.dx * w - 28,
              top: pos.dy * h - 28,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Glow effect for active/crisis nodes
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: nodeColor.withOpacity(0.1),
                    border: Border.all(color: nodeColor.withOpacity(0.6), width: isCurrent ? 2.5 : 1.5),
                    boxShadow: [
                      if (isCrisis || isCurrent)
                        BoxShadow(color: nodeColor.withOpacity(0.4), blurRadius: 20, spreadRadius: 2),
                    ],
                  ),
                  child: Icon(
                    _nodeIcon(name),
                    color: nodeColor,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: GlassTheme.backgroundDark.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(name,
                    style: GoogleFonts.inter(color: nodeColor, fontSize: 10, fontWeight: FontWeight.w600)),
                ),
              ]),
            );
          }),
          // Legend
          Positioned(
            bottom: 16, left: 16,
            child: Row(children: [
              _legendDot(GlassTheme.accentCyan, 'Active'),
              const SizedBox(width: 12),
              _legendDot(GlassTheme.accentNeonGreen, 'On Route'),
              const SizedBox(width: 12),
              _legendDot(GlassTheme.danger, 'Crisis'),
              const SizedBox(width: 12),
              _legendDot(Colors.white.withOpacity(0.4), 'Idle'),
            ]),
          ),
          // ── TRUCK ANIMATION ──
          Builder(
            builder: (context) {
              final truckPos = _calculateTruckPosition(constraints);
              return AnimatedPositioned(
                duration: const Duration(milliseconds: 1000), // Matches your 1-sec tick!
                curve: Curves.linear, // Linear keeps the speed constant
                left: truckPos.dx - 16, // -16 centers the 32px icon
                top: truckPos.dy - 16,
                child: const Icon(Icons.local_shipping, color: Colors.greenAccent, size: 32),
              );
            }
          ),
        ],
      );
    });
  }

  Offset _calculateTruckPosition(BoxConstraints constraints) {
    final w = constraints.maxWidth;
    final h = constraints.maxHeight;

    // 1. Before dispatch: hide truck off-screen
    if (shipmentState == null || shipmentState!.routePlan.isEmpty) {
      return const Offset(-100, -100);
    }

    // 2. Lookup node keys
    final currentKey = _findNodeKey(shipmentState!.currentStepName);
    final nextKey = _findNodeKey(shipmentState!.nextStepName);

    // 3. Fallback: park truck at the source node (New Delhi)
    if (currentKey == null || nextKey == null) {
      final srcOffset = _nodes['New Delhi']!;
      return Offset(srcOffset.dx * w, srcOffset.dy * h);
    }

    final startOffset = _nodes[currentKey]!;
    final endOffset = _nodes[nextKey]!;

    // 4. Cap the percentage between 0.0 and 1.0
    final double safePercentage = shipmentState!.progressPercentage.clamp(0.0, 1.0);

    // 5. Lerp between the two nodes
    final pos = Offset.lerp(startOffset, endOffset, safePercentage)!;

    // 6. Convert relative → pixel coords
    return Offset(pos.dx * w, pos.dy * h);
  }

  Widget _legendDot(Color c, String label) {
    return Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: c)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9)),
    ]);
  }

  IconData _nodeIcon(String name) {
    if (name == 'New Delhi') return Icons.home_work;
    if (name == 'Dubai') return Icons.flag;
    if (name == 'Mumbai' || name == 'Mundra' || name == 'Kandla') return Icons.directions_boat;
    if (name == 'Inland Depot') return Icons.warehouse;
    return Icons.location_on;
  }

  String? _findNodeKey(String stepName) {
    if (stepName.isEmpty) return null;
    for (final key in _nodes.keys) {
      if (key.toLowerCase().contains(stepName.toLowerCase()) ||
          stepName.toLowerCase().contains(key.toLowerCase())) {
        return key;
      }
    }
    return null;
  }

  bool _edgeInRoute(String from, String to, List<String> route) {
    for (int i = 0; i < route.length - 1; i++) {
      if ((from.contains(route[i]) || route[i].contains(from)) &&
          (to.contains(route[i + 1]) || route[i + 1].contains(to))) return true;
    }
    return false;
  }
}


// ── Grid Background Painter ──
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 0.5;
    const spacing = 30.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Edge Line Painter ──
class _EdgePainter extends CustomPainter {
  final Offset from;
  final Offset to;
  final Color color;
  final double width;

  _EdgePainter(this.from, this.to, this.color, this.width);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;
    canvas.drawLine(from, to, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ═══════════════════════════════════════════════════════════════════
// TelemetryChartWidget — fl_chart LineChart for dwell time monitoring.
// ═══════════════════════════════════════════════════════════════════
class TelemetryChartWidget extends StatefulWidget {
  final GlobalState? globalState;
  const TelemetryChartWidget({super.key, this.globalState});
  @override
  State<TelemetryChartWidget> createState() => _TelemetryChartWidgetState();
}

class _TelemetryChartWidgetState extends State<TelemetryChartWidget> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final charts = widget.globalState?.telemetryCharts ?? {};

    // If no live data yet, show an animated "waiting" placeholder
    if (charts.isEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.show_chart, color: GlassTheme.accentCyan, size: 18),
          const SizedBox(width: 8),
          Text('Dwell Time Monitor',
            style: GoogleFonts.outfit(color: GlassTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 4),
        Text('Awaiting first node arrival...', style: TextStyle(color: GlassTheme.textSecondary, fontSize: 10)),
        const Spacer(),
        Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.sensors, color: GlassTheme.accentCyan.withOpacity(0.3), size: 48),
          const SizedBox(height: 8),
          Text('No telemetry yet', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 11)),
        ])),
        const Spacer(),
      ]);
    }

    // Clamp selection to valid index
    final nodeNames = charts.keys.toList();
    if (_selectedIndex >= nodeNames.length) _selectedIndex = 0;
    final selectedNode = nodeNames[_selectedIndex];
    final data = charts[selectedNode]!;
    final isCrisis = data.isCrisis;
    final chartColor = isCrisis ? GlassTheme.danger : GlassTheme.accentCyan;
    final history = data.history;
    final threshold = data.threshold;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header + node selector
      Row(children: [
        Icon(Icons.show_chart, color: chartColor, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text('$selectedNode Dwell Time',
          style: GoogleFonts.outfit(color: GlassTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        )),
        if (isCrisis)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: GlassTheme.danger.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
            child: Text('⚡ ANOMALY', style: TextStyle(color: GlassTheme.danger, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
      ]),
      const SizedBox(height: 4),
      // Node tab pills
      if (nodeNames.length > 1)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: List.generate(nodeNames.length, (i) {
            final isSelected = i == _selectedIndex;
            final nodeIsCrisis = charts[nodeNames[i]]!.isCrisis;
            return GestureDetector(
              onTap: () => setState(() => _selectedIndex = i),
              child: Container(
                margin: const EdgeInsets.only(right: 6, top: 4, bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isSelected ? chartColor.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isSelected ? chartColor : Colors.white.withOpacity(0.1)),
                ),
                child: Text(nodeNames[i],
                  style: TextStyle(
                    color: nodeIsCrisis ? GlassTheme.danger : (isSelected ? chartColor : Colors.white.withOpacity(0.5)),
                    fontSize: 9, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  )),
              ),
            );
          })),
        ),
      const SizedBox(height: 8),
      // Rolling mean indicator
      Row(children: [
        Text('Rolling Mean: ', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9)),
        Text('${data.rollingMean.toStringAsFixed(1)}h',
          style: TextStyle(color: chartColor, fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(width: 12),
        Text('Threshold: ', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9)),
        Text('${threshold.toStringAsFixed(1)}h',
          style: TextStyle(color: GlassTheme.danger.withOpacity(0.7), fontSize: 9)),
      ]),
      const SizedBox(height: 8),
      // The chart
      Expanded(
        child: history.isEmpty
          ? Center(child: Text('Recording...', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 10)))
          : LineChart(
            LineChartData(
              minY: 0,
              maxY: max(history.reduce(max) * 1.4, threshold * 1.2).clamp(0.0, 100.0),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 0.5),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30,
                  getTitlesWidget: (v, _) => Text('${v.toStringAsFixed(0)}h',
                    style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9)))),
                bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              extraLinesData: ExtraLinesData(horizontalLines: [
                HorizontalLine(
                  y: threshold,
                  color: GlassTheme.danger.withOpacity(0.7),
                  strokeWidth: 1.5,
                  dashArray: [6, 4],
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    style: TextStyle(color: GlassTheme.danger, fontSize: 9, fontWeight: FontWeight.bold),
                    labelResolver: (_) => '+3σ',
                  ),
                ),
              ]),
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(history.length, (i) => FlSpot(i.toDouble(), history[i])),
                  isCurved: true,
                  curveSmoothness: 0.3,
                  color: chartColor,
                  barWidth: 2.5,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, _, __, ___) {
                      final isAbove = spot.y > threshold;
                      return FlDotCirclePainter(
                        radius: isAbove ? 5 : 3,
                        color: isAbove ? GlassTheme.danger : chartColor,
                        strokeWidth: 0,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [chartColor.withOpacity(0.4), chartColor.withOpacity(0.0)],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ),
    ]);
  }
}


// ═══════════════════════════════════════════════════════════════════
// AuditTrailWidget — Terminal-style "Thought Process" log viewer.
// ═══════════════════════════════════════════════════════════════════
class AuditTrailWidget extends StatelessWidget {
  final List<String> logs;
  final void Function(double hours)? onTick;

  const AuditTrailWidget({super.key, this.logs = const [], this.onTick});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GlassTheme.accentNeonGreen.withOpacity(0.15)),
      ),
      child: Column(children: [
        // Terminal header bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: GlassTheme.accentNeonGreen.withOpacity(0.05),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(bottom: BorderSide(color: GlassTheme.accentNeonGreen.withOpacity(0.1))),
          ),
          child: Row(children: [
            // Fake traffic light dots
            _dot(const Color(0xFFFF5F57)), const SizedBox(width: 6),
            _dot(const Color(0xFFFFBD2E)), const SizedBox(width: 6),
            _dot(const Color(0xFF27C93F)), const SizedBox(width: 12),
            Icon(Icons.terminal, color: GlassTheme.accentNeonGreen.withOpacity(0.6), size: 14),
            const SizedBox(width: 6),
            Text('Thought Process', style: GoogleFonts.jetBrainsMono(
              color: GlassTheme.accentNeonGreen.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w600)),
            const Spacer(),
            // Tick button inside the terminal
            if (onTick != null)
              InkWell(
                onTap: () => onTick!(1.0),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: GlassTheme.accentCyan.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: GlassTheme.accentCyan.withOpacity(0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.fast_forward, color: GlassTheme.accentCyan, size: 12),
                    const SizedBox(width: 4),
                    Text('+1h Tick', style: GoogleFonts.jetBrainsMono(
                      color: GlassTheme.accentCyan, fontSize: 10, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
          ]),
        ),
        // Log lines
        Expanded(
          child: logs.isEmpty
              ? Center(child: Text('> Awaiting dispatch...',
                  style: GoogleFonts.jetBrainsMono(color: GlassTheme.accentNeonGreen.withOpacity(0.3), fontSize: 12)))
              : ListView.builder(
                  reverse: true, // newest at bottom, scroll from bottom
                  padding: const EdgeInsets.all(12),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    final isAlert = log.contains('ALERT') || log.contains('CRISIS') || log.contains('FAILED') || log.contains('CRITICAL') || log.contains('TELEMETRY');
                    final isSuccess = log.contains('SUCCESS') || log.contains('DISPATCHED') || log.contains('REASONING');
                    Color logColor = GlassTheme.accentNeonGreen.withOpacity(0.7);
                    if (isAlert) logColor = GlassTheme.danger.withOpacity(0.9);
                    else if (isSuccess) logColor = GlassTheme.accentCyan;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '> $log',
                        style: GoogleFonts.jetBrainsMono(color: logColor, fontSize: 11, height: 1.5),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  Widget _dot(Color c) => Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: c));
}
