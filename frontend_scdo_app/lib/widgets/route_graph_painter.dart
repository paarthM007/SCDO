import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:scdo_app/theme/glass_theme.dart';

/// Data model for a single graph edge used by the painter.
class GraphEdge {
  final Offset from;
  final Offset to;
  final String fromName;
  final String toName;
  final String mode;
  final double distKm;
  final double timeH;
  final double costUsd;
  final double riskScore;
  final double capacityLimit;

  const GraphEdge({
    required this.from,
    required this.to,
    required this.fromName,
    required this.toName,
    required this.mode,
    required this.distKm,
    required this.timeH,
    required this.costUsd,
    this.riskScore = 0.0,
    this.capacityLimit = 100.0,
  });
}

/// Data model for a graph node.
class GraphNode {
  final Offset position;
  final String name;
  final bool isPort;
  final bool isAirport;

  const GraphNode({
    required this.position,
    required this.name,
    this.isPort = false,
    this.isAirport = false,
  });
}

/// Converts lat/lon to screen coordinates using Mercator projection.
Offset latLonToScreen(
    double lat, double lon, Size size, List<double> bounds) {
  // bounds = [minLat, maxLat, minLon, maxLon]
  final padding = 40.0;
  final usableW = size.width - padding * 2;
  final usableH = size.height - padding * 2;

  final x = padding +
      ((lon - bounds[2]) / (bounds[3] - bounds[2]).clamp(0.001, 360)) *
          usableW;
  final y = padding +
      ((bounds[1] - lat) / (bounds[1] - bounds[0]).clamp(0.001, 180)) *
          usableH;

  return Offset(x.clamp(padding, size.width - padding),
      y.clamp(padding, size.height - padding));
}

/// Computes bounding box [minLat, maxLat, minLon, maxLon] from waypoints.
List<double> computeBounds(List<Map<String, dynamic>> waypoints) {
  if (waypoints.isEmpty) return [-90, 90, -180, 180];

  double minLat = 90, maxLat = -90, minLon = 180, maxLon = -180;
  for (final wp in waypoints) {
    final lat = (wp['lat'] as num).toDouble();
    final lon = (wp['lon'] as num).toDouble();
    if (lat < minLat) minLat = lat;
    if (lat > maxLat) maxLat = lat;
    if (lon < minLon) minLon = lon;
    if (lon > maxLon) maxLon = lon;
  }

  // Add 10% padding to bounds
  final latPad = (maxLat - minLat) * 0.1 + 2;
  final lonPad = (maxLon - minLon) * 0.1 + 2;
  return [minLat - latPad, maxLat + latPad, minLon - lonPad, maxLon + lonPad];
}

// ══════════════════════════════════════════════════════════════
// CustomPainter: Interactive Route Graph (Whitepaper §3.II)
// ══════════════════════════════════════════════════════════════

class RouteGraphPainter extends CustomPainter {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final List<GraphEdge> bgEdges;
  final Offset? hoverPosition;
  final double shipmentProgress; // 0.0 to 1.0 for animation
  final int? hoveredEdgeIndex;

  RouteGraphPainter({
    required this.nodes,
    required this.edges,
    this.bgEdges = const [],
    this.hoverPosition,
    this.shipmentProgress = -1,
    this.hoveredEdgeIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawEdges(canvas, size);
    _drawNodes(canvas, size);
    if (shipmentProgress >= 0 && shipmentProgress <= 1.0) {
      _drawShipmentIcon(canvas, size);
    }
  }

  void _drawEdges(Canvas canvas, Size size) {
    // Draw background edges first (dimmed)
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final bg in bgEdges) {
      canvas.drawLine(bg.from, bg.to, bgPaint);
    }

    for (int i = 0; i < edges.length; i++) {
      final edge = edges[i];
      final isHovered = hoveredEdgeIndex == i;

      // Color = lerp(green, red, risk_score) — Whitepaper §3.II
      final color = Color.lerp(
        GlassTheme.accentNeonGreen,
        GlassTheme.danger,
        edge.riskScore.clamp(0.0, 1.0),
      )!;

      // StrokeWidth = log(capacity_limit) — Whitepaper §3.II
      final baseWidth = log(edge.capacityLimit.clamp(2.0, 10000.0)) / ln10;
      final strokeWidth =
          isHovered ? baseWidth * 2.0 + 1.0 : baseWidth.clamp(1.5, 6.0);

      final paint = Paint()
        ..color = isHovered ? color : color.withOpacity(0.7)
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      // Draw glow effect for hovered edge
      if (isHovered) {
        final glowPaint = Paint()
          ..color = color.withOpacity(0.2)
          ..strokeWidth = strokeWidth + 6
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawLine(edge.from, edge.to, glowPaint);
      }

      canvas.drawLine(edge.from, edge.to, paint);

      // Draw mode icon at midpoint
      final mid = Offset(
        (edge.from.dx + edge.to.dx) / 2,
        (edge.from.dy + edge.to.dy) / 2,
      );
      final modeIcon = _modeToIcon(edge.mode);
      final tp = TextPainter(
        text: TextSpan(text: modeIcon, style: const TextStyle(fontSize: 14)),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, mid - Offset(tp.width / 2, tp.height / 2));

      // Draw dashed progress on edges traversed by shipment
      if (shipmentProgress >= 0) {
        // Build TweenSequence to compute exact progress on this specific edge
        final tweenItems = <TweenSequenceItem<Offset>>[];
        double totalTime = edges.fold(0.0, (sum, e) => sum + e.timeH);
        if (totalTime == 0.0) totalTime = 1.0;
        for (final e in edges) {
          tweenItems.add(TweenSequenceItem(
            tween: Tween<Offset>(begin: e.from, end: e.to),
            weight: e.timeH > 0 ? e.timeH / totalTime * 100 : 1.0,
          ));
        }
        final tweenSeq = TweenSequence<Offset>(tweenItems);
        
        // Find which edge the shipment is currently on by walking the weights
        double accumulatedWeight = 0.0;
        double targetProgress = shipmentProgress * 100;
        bool isCurrentEdge = false;
        bool isPastEdge = false;
        
        for (int j = 0; j < edges.length; j++) {
          final w = tweenItems[j].weight;
          if (j == i) {
            if (targetProgress >= accumulatedWeight + w) {
              isPastEdge = true;
            } else if (targetProgress >= accumulatedWeight) {
              isCurrentEdge = true;
            }
            break;
          }
          accumulatedWeight += w;
        }

        if (isPastEdge || isCurrentEdge) {
          final progressPoint = isPastEdge 
              ? edge.to 
              : tweenSeq.evaluate(AlwaysStoppedAnimation(shipmentProgress));
              
          final progressPaint = Paint()
            ..color = GlassTheme.accentCyan
            ..strokeWidth = strokeWidth + 1
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke;
          canvas.drawLine(edge.from, progressPoint, progressPaint);
        }
      }
    }
  }

  void _drawNodes(Canvas canvas, Size size) {
    for (final node in nodes) {
      // Outer glow
      final glowPaint = Paint()
        ..color = GlassTheme.accentCyan.withOpacity(0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(node.position, 12, glowPaint);

      // Node circle
      final fillPaint = Paint()
        ..color = node.isAirport
            ? const Color(0xFF1a1a2e)
            : const Color(0xFF1a1a2e)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(node.position, 8, fillPaint);

      // Node border
      final borderColor = node.isAirport
          ? Colors.orangeAccent
          : node.isPort
              ? GlassTheme.accentCyan
              : GlassTheme.accentNeonGreen;
      final borderPaint = Paint()
        ..color = borderColor
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(node.position, 8, borderPaint);

      // Inner dot
      canvas.drawCircle(
          node.position, 3, Paint()..color = borderColor);

      // Label
      final tp = TextPainter(
        text: TextSpan(
          text: node.name,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, node.position + const Offset(12, -6));
    }
  }

  void _drawShipmentIcon(Canvas canvas, Size size) {
    if (edges.isEmpty) return;

    // Use TweenSequence proportional to time_h for accurate shipment position
    final tweenItems = <TweenSequenceItem<Offset>>[];
    double totalTime = edges.fold(0.0, (sum, e) => sum + e.timeH);
    if (totalTime == 0.0) totalTime = 1.0;
    
    for (final edge in edges) {
      tweenItems.add(TweenSequenceItem(
        tween: Tween<Offset>(begin: edge.from, end: edge.to),
        weight: edge.timeH > 0 ? edge.timeH / totalTime * 100 : 1.0,
      ));
    }
    
    final tweenSeq = TweenSequence<Offset>(tweenItems);
    final pos = tweenSeq.evaluate(AlwaysStoppedAnimation(shipmentProgress));

    // Determine current edge for icon
    double accumulatedWeight = 0.0;
    double targetProgress = shipmentProgress * 100;
    GraphEdge currentEdge = edges.last;
    for (int i = 0; i < edges.length; i++) {
      accumulatedWeight += tweenItems[i].weight;
      if (targetProgress <= accumulatedWeight) {
        currentEdge = edges[i];
        break;
      }
    }

    // Pulse glow
    final pulse = (sin(shipmentProgress * 20) * 0.3 + 0.7).clamp(0.4, 1.0);
    final glowPaint = Paint()
      ..color = GlassTheme.accentCyan.withOpacity(0.3 * pulse)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(pos, 16, glowPaint);

    // Shipment icon
    final icon = _modeToIcon(currentEdge.mode);
    final tp = TextPainter(
      text: TextSpan(text: "📦", style: const TextStyle(fontSize: 18)),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  String _modeToIcon(String mode) {
    switch (mode.toUpperCase()) {
      case 'AIR':
        return '✈️';
      case 'SEA':
        return '🚢';
      case 'HIGHWAY':
        return '🚛';
      default:
        return '📦';
    }
  }

  @override
  bool shouldRepaint(covariant RouteGraphPainter oldDelegate) {
    return oldDelegate.shipmentProgress != shipmentProgress ||
        oldDelegate.hoveredEdgeIndex != hoveredEdgeIndex ||
        oldDelegate.nodes != nodes ||
        oldDelegate.edges != edges;
  }
}

// ══════════════════════════════════════════════════════════════
// Interactive Graph Widget (wraps CustomPainter + hover tooltips)
// ══════════════════════════════════════════════════════════════

class InteractiveRouteGraph extends StatefulWidget {
  final Map<String, dynamic>? routeData;
  final double shipmentProgress;

  const InteractiveRouteGraph({
    super.key,
    this.routeData,
    this.shipmentProgress = -1,
  });

  @override
  State<InteractiveRouteGraph> createState() => _InteractiveRouteGraphState();
}

class _InteractiveRouteGraphState extends State<InteractiveRouteGraph> {
  int? _hoveredEdgeIdx;
  Offset? _hoverPos;

  List<GraphNode> _nodes = [];
  List<GraphEdge> _edges = [];
  List<double> _bounds = [-90, 90, -180, 180];

  @override
  void didUpdateWidget(covariant InteractiveRouteGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.routeData != oldWidget.routeData) {
      _buildGraphData();
    }
  }

  @override
  void initState() {
    super.initState();
    _buildGraphData();
  }

  void _buildGraphData() {
    final data = widget.routeData;
    if (data == null) {
      _nodes = [];
      _edges = [];
      return;
    }

    final waypoints = (data['waypoints'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final pathEdges = (data['path_edges'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final riskScore = ((data['shipment'] as Map?)?['risk_score'] ?? 0.0) as num;

    if (waypoints.isEmpty) return;

    _bounds = computeBounds(waypoints);
    // Nodes and edges are built in build() using LayoutBuilder for size
  }

  int? _hitTestEdge(Offset pos, Size size) {
    final data = widget.routeData;
    if (data == null) return null;

    final pathEdges = (data['path_edges'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final waypoints = (data['waypoints'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (waypoints.length < 2) return null;

    for (int i = 0; i < pathEdges.length && i + 1 < waypoints.length; i++) {
      final wp0 = waypoints[i];
      final wp1 = waypoints[i + 1];
      final p0 = latLonToScreen(
          (wp0['lat'] as num).toDouble(), (wp0['lon'] as num).toDouble(),
          size, _bounds);
      final p1 = latLonToScreen(
          (wp1['lat'] as num).toDouble(), (wp1['lon'] as num).toDouble(),
          size, _bounds);

      // Distance from point to line segment
      final d = _pointToSegmentDist(pos, p0, p1);
      if (d < 12.0) return i;
    }
    return null;
  }

  double _pointToSegmentDist(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final ap = p - a;
    final t = (ap.dx * ab.dx + ap.dy * ab.dy) /
        (ab.dx * ab.dx + ab.dy * ab.dy + 0.0001);
    final tClamped = t.clamp(0.0, 1.0);
    final closest = Offset(a.dx + ab.dx * tClamped, a.dy + ab.dy * tClamped);
    return (p - closest).distance;
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.routeData;

    if (data == null) {
      return Center(
        child: Text(
          'Select a route to visualize the graph',
          style: TextStyle(color: Colors.white38, fontSize: 14),
        ),
      );
    }

    final waypoints = (data['waypoints'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final pathEdges = (data['path_edges'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final riskScore = ((data['shipment'] as Map?)?['risk_score'] ?? 0.0) as num;

    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);

      // Build nodes from waypoints
      final graphNodes = <GraphNode>[];
      for (final wp in waypoints) {
        graphNodes.add(GraphNode(
          position: latLonToScreen(
              (wp['lat'] as num).toDouble(),
              (wp['lon'] as num).toDouble(),
              size, _bounds),
          name: wp['name'] ?? '',
          isPort: wp['is_port'] == true,
          isAirport: wp['is_airport'] == true,
        ));
      }

      // Build edges from path_edges
      final graphEdges = <GraphEdge>[];
      for (int i = 0; i < pathEdges.length && i + 1 < waypoints.length; i++) {
        final e = pathEdges[i];
        final wp0 = waypoints[i];
        final wp1 = waypoints[i + 1];
        graphEdges.add(GraphEdge(
          from: latLonToScreen(
              (wp0['lat'] as num).toDouble(),
              (wp0['lon'] as num).toDouble(), size, _bounds),
          to: latLonToScreen(
              (wp1['lat'] as num).toDouble(),
              (wp1['lon'] as num).toDouble(), size, _bounds),
          fromName: e['from'] ?? '',
          toName: e['to'] ?? '',
          mode: e['mode'] ?? 'HIGHWAY',
          distKm: (e['dist_km'] as num?)?.toDouble() ?? 0,
          timeH: (e['time_h'] as num?)?.toDouble() ?? 0,
          costUsd: (e['cost_usd'] as num?)?.toDouble() ?? 0,
          riskScore: riskScore.toDouble(),
          capacityLimit: (e['capacity_limit'] as num?)?.toDouble() ?? 100.0,
        ));
      }

      // Build background edges
      final bgEdgesList = <GraphEdge>[];
      final rawBgEdges = (data['background_edges'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      for (final bg in rawBgEdges) {
        bgEdgesList.add(GraphEdge(
          from: latLonToScreen((bg['from_lat'] as num).toDouble(), (bg['from_lon'] as num).toDouble(), size, _bounds),
          to: latLonToScreen((bg['to_lat'] as num).toDouble(), (bg['to_lon'] as num).toDouble(), size, _bounds),
          fromName: '', toName: '', mode: bg['mode'] ?? 'HIGHWAY',
          distKm: 0, timeH: 0, costUsd: 0, capacityLimit: 50.0,
        ));
      }

      return MouseRegion(
        onHover: (event) {
          final idx = _hitTestEdge(event.localPosition, size);
          if (idx != _hoveredEdgeIdx) {
            setState(() {
              _hoveredEdgeIdx = idx;
              _hoverPos = event.localPosition;
            });
          }
        },
        onExit: (_) => setState(() {
          _hoveredEdgeIdx = null;
          _hoverPos = null;
        }),
        child: Stack(
          children: [
            CustomPaint(
              size: size,
              painter: RouteGraphPainter(
                nodes: graphNodes,
                edges: graphEdges,
                bgEdges: bgEdgesList,
                shipmentProgress: widget.shipmentProgress,
                hoveredEdgeIndex: _hoveredEdgeIdx,
              ),
            ),
            // ── Hover Tooltip (Whitepaper §3.II) ──
            if (_hoveredEdgeIdx != null &&
                _hoverPos != null &&
                _hoveredEdgeIdx! < graphEdges.length)
              Positioned(
                left: _hoverPos!.dx + 16,
                top: _hoverPos!.dy - 60,
                child: _EdgeTooltip(edge: graphEdges[_hoveredEdgeIdx!]),
              ),
          ],
        ),
      );
    });
  }
}

/// Micro-frontend tooltip showing live Cost/Time math for a hovered edge.
class _EdgeTooltip extends StatelessWidget {
  final GraphEdge edge;
  const _EdgeTooltip({required this.edge});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xE01a1a2e),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GlassTheme.accentCyan.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: GlassTheme.accentCyan.withOpacity(0.1),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${edge.fromName} → ${edge.toName}',
            style: const TextStyle(
              color: GlassTheme.accentCyan,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          _tooltipRow('Mode', _modeLabel(edge.mode)),
          _tooltipRow('Distance', '${edge.distKm.toStringAsFixed(0)} km'),
          const Divider(color: Colors.white24, height: 12),
          _tooltipRow('Time Math', '${edge.timeH.toStringAsFixed(1)} h total'),
          if (edge.riskScore > 0)
            _tooltipRow(' • Transit', 'includes +${(edge.riskScore * 35).toStringAsFixed(1)}% risk delay'),
          const SizedBox(height: 2),
          _tooltipRow('Cost Math', '\$${edge.costUsd.toStringAsFixed(0)} total'),
          if (edge.riskScore > 0)
            _tooltipRow(' • Hazard', 'includes +${(edge.riskScore * 25).toStringAsFixed(1)}% risk premium'),
        ],
      ),
    );
  }

  Widget _tooltipRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ',
              style: TextStyle(color: Colors.white54, fontSize: 10)),
          Text(value,
              style: const TextStyle(color: Colors.white, fontSize: 10)),
        ],
      ),
    );
  }

  String _modeLabel(String mode) {
    switch (mode.toUpperCase()) {
      case 'AIR':
        return '✈️ Air';
      case 'SEA':
        return '🚢 Sea';
      case 'HIGHWAY':
        return '🚛 Road';
      default:
        return mode;
    }
  }
}
