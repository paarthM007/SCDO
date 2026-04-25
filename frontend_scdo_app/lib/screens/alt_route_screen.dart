import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:scdo_app/theme/glass_theme.dart';
import 'package:scdo_app/widgets/glass_container.dart';
import 'package:scdo_app/widgets/route_graph_painter.dart';
import '../app_config.dart';

class AltRouteScreen extends StatefulWidget {
  const AltRouteScreen({super.key});

  @override
  State<AltRouteScreen> createState() => _AltRouteScreenState();
}

class _AltRouteScreenState extends State<AltRouteScreen>
    with TickerProviderStateMixin {
  final String baseUrl = AppConfig.gatewayBaseUrl;
  final String apiKey = AppConfig.gatewayApiKey;

  final TextEditingController _altStart = TextEditingController(text: "Mumbai");
  final TextEditingController _altEnd = TextEditingController(text: "London");
  final TextEditingController _altBlocked =
      TextEditingController(text: "Dubai, Istanbul");

  // ── v3.0 CTR Shipment Parameters ──────────────────────────
  final TextEditingController _quantityCtrl =
      TextEditingController(text: "500");
  final TextEditingController _budgetCtrl =
      TextEditingController(text: "5000");
  final TextEditingController _deadlineCtrl =
      TextEditingController(text: "120");
  String _productType = "general";
  double _omega = 0.5;

  static const List<String> _productTypes = [
    "general",
    "perishable",
    "hazmat",
    "electronics",
    "bulk_commodity",
    "frozen_food",
    "pharmaceuticals",
    "live_animals",
    "vehicles",
  ];

  bool _isLoading = false;
  String _result = "";

  // ── Route selection state ──────────────────────────────────
  Map<String, dynamic>? _altRouteResult;
  Map<String, bool> _simulatingPath = {};

  // ── Shipment Animation State ──────────────────────────────
  AnimationController? _animController;
  String? _animatingKey;

  // ── Graph Visualization State ─────────────────────────────
  Map<String, dynamic>? _selectedRouteData;
  bool _showGraph = true;

  Future<Map<String, String>> _authHeaders() async {
    String? token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    };
  }

  Future<void> _findAltRoute() async {
    setState(() {
      _isLoading = true;
      _result = "Calculating CTR-optimized paths...";
      _altRouteResult = null;
      _simulatingPath = {};
      _animatingKey = null;
    });

    try {
      final body = {
        "start": _altStart.text.trim(),
        "end": _altEnd.text.trim(),
        "blocked": _altBlocked.text
            .split(",")
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        // v3.0 CTR parameters
        "quantity": double.tryParse(_quantityCtrl.text),
        "product_type": _productType,
        "budget": double.tryParse(_budgetCtrl.text),
        "deadline_h": double.tryParse(_deadlineCtrl.text),
        "omega": _omega,
      };

      final response = await http.post(
        Uri.parse("$baseUrl/api/alternate-route"),
        headers: await _authHeaders(),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        var decoded = jsonDecode(response.body);
        setState(() {
          _result = const JsonEncoder.withIndent('  ').convert(decoded);
          if (decoded["status"] == "ok") {
            _altRouteResult = decoded["result"];
          }
        });
      } else {
        setState(() {
          _result = "Error: ${response.statusCode}\n${response.body}";
        });
      }
    } catch (e) {
      setState(() {
        _result = "Network Error: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _simulatePath(String routeKey) async {
    setState(() {
      _simulatingPath[routeKey] = true;
    });
    try {
      final routeData = _altRouteResult?[routeKey];
      if (routeData == null || routeData.containsKey("error")) {
        throw Exception("Invalid route selected.");
      }

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

      final response = await http.post(
        Uri.parse("$baseUrl/api/simulate"),
        headers: await _authHeaders(),
        body: jsonEncode({
          "cities": cities,
          "modes": modes,
          "path_edges": pathEdges,
          "cargo_type": _productType, // using product type as cargo type since we merged them in the backend logic
          "quantity": double.tryParse(_quantityCtrl.text),
          "product_type": _productType,
          "source": "alternate_route_$routeKey",
        }),
      );
      var decoded = jsonDecode(response.body);
      setState(() {
        _result = const JsonEncoder.withIndent('  ').convert(decoded);
      });
      if (decoded["status"] == "ok" && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "✅ Simulation queued for '${routeKey.toUpperCase()}' path"),
            backgroundColor: GlassTheme.accentNeonGreen,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _result = "Simulation Error: $e";
      });
    } finally {
      setState(() {
        _simulatingPath[routeKey] = false;
      });
    }
  }

  // ── v3.0: Start Shipment Playback Animation (§3.I) ─────────
  /// Uses TweenSequence with each segment duration proportional to time_h.
  void _startPlayback(String key, Map<String, dynamic> pathData) {
    final waypoints = pathData["waypoints"] as List?;
    final pathEdges =
        (pathData["path_edges"] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (waypoints == null || waypoints.length < 2 || pathEdges.isEmpty) return;

    // Select this route for graph visualization
    setState(() {
      _selectedRouteData = pathData;
      _showGraph = true;
    });

    _animController?.dispose();

    // Calculate total time to derive proportional segment weights
    final totalTimeH = pathEdges.fold<double>(
        0.0, (sum, e) => sum + ((e['time_h'] as num?)?.toDouble() ?? 1.0));
    // Animation runs for (totalTimeH * 0.5) seconds, clamped to 3-20s
    final durationSec =
        (totalTimeH * 0.5).clamp(3.0, 20.0).round();

    _animController = AnimationController(
      vsync: this,
      duration: Duration(seconds: durationSec),
    );

    setState(() {
      _animatingKey = key;
    });

    // Listen to rebuild graph with progress
    _animController!.addListener(() => setState(() {}));
    _animController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _animatingKey = null;
        });
      }
    });
    _animController!.forward();
  }

  // ── Select route for graph visualization ────────────────────
  void _visualizeRoute(Map<String, dynamic> pathData) {
    setState(() {
      _selectedRouteData = pathData;
      _showGraph = true;
    });
  }

  // ── Feasibility Badge Widget ───────────────────────────────
  Widget _feasibilityBadge(Map<String, dynamic> pathData) {
    final fIdx = (pathData["feasibility_index"] ?? 1.0).toDouble();
    final warnings = pathData["feasibility_warnings"] as List? ?? [];

    Color badgeColor;
    String label;
    IconData icon;

    if (fIdx >= 1.0) {
      badgeColor = GlassTheme.accentNeonGreen;
      label = "FEASIBLE";
      icon = Icons.check_circle;
    } else if (fIdx >= 0.7) {
      badgeColor = Colors.orangeAccent;
      label = "TIGHT (${(fIdx * 100).toStringAsFixed(0)}%)";
      icon = Icons.warning_amber;
    } else {
      badgeColor = GlassTheme.danger;
      label = "INFEASIBLE (${(fIdx * 100).toStringAsFixed(0)}%)";
      icon = Icons.error;
    }

    return Tooltip(
      message: warnings.isNotEmpty ? warnings.join("\n") : "Route is feasible",
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: badgeColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: badgeColor.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: badgeColor),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: badgeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // ── Route card widget ──────────────────────────────────────
  Widget _routeCard(String key, Map<String, dynamic>? pathData) {
    if (pathData == null || pathData.containsKey("error")) {
      return GlassContainer(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: GlassTheme.danger, size: 20),
            const SizedBox(width: 8),
            Text(key.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Expanded(
                child: Text(
              pathData?["error"] ?? "No route found",
              style:
                  const TextStyle(color: GlassTheme.danger, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            )),
          ],
        ),
      );
    }

    final dist = pathData["total_distance_km"] ?? "-";
    final time = pathData["total_time_readable"] ?? "-";
    final cost = pathData["total_cost_usd"] ?? "-";
    final hops = pathData["num_hops"] ?? "-";
    final modes = (pathData["modes_used"] as List?)?.join(", ") ?? "-";
    final isSim = _simulatingPath[key] == true;
    final isAnimating = _animatingKey == key;

    Color accentColor;
    IconData icon;
    switch (key) {
      case "fastest":
        accentColor = Colors.orangeAccent;
        icon = Icons.speed;
        break;
      case "cheapest":
        accentColor = GlassTheme.accentNeonGreen;
        icon = Icons.savings;
        break;
      default:
        accentColor = GlassTheme.accentCyan;
        icon = Icons.balance;
    }

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: accentColor, size: 22),
            const SizedBox(width: 10),
            Text(key.toUpperCase(),
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                    fontSize: 15)),
            const SizedBox(width: 8),
            _feasibilityBadge(pathData),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text("$hops hops",
                  style: TextStyle(color: accentColor, fontSize: 11)),
            ),
          ]),
          const SizedBox(height: 12),
          // ── v3.0: Display Path Waypoints ──
          if (pathData["waypoints"] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                (pathData["waypoints"] as List)
                    .map((w) => w["name"])
                    .join(" → "),
                style: GoogleFonts.firaCode(
                  fontSize: 11,
                  color: accentColor.withOpacity(0.9),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          Row(
            children: [
              _statChip(Icons.straighten, "$dist km", Colors.white70),
              const SizedBox(width: 16),
              _statChip(
                  Icons.access_time, time.toString(), Colors.white70),
              const SizedBox(width: 16),
              _statChip(
                  Icons.attach_money, "\$$cost", Colors.white70),
            ],
          ),
          const SizedBox(height: 6),
          Text("Modes: $modes",
              style: const TextStyle(
                  fontSize: 11, color: GlassTheme.textSecondary)),
          // ── v3.0 Shipment Playback Progress ──
          if (isAnimating && _animController != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: AnimatedBuilder(
                animation: _animController!,
                builder: (_, __) => Column(
                  children: [
                    LinearProgressIndicator(
                      value: _animController!.value,
                      backgroundColor: Colors.white12,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(accentColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "📦 Shipment in transit... ${(_animController!.value * 100).toStringAsFixed(0)}%",
                      style: TextStyle(
                          fontSize: 10, color: accentColor),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),
          // Row 1: Visualize + View JSON
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: GlassTheme.accentCyan,
                  side: BorderSide(color: GlassTheme.accentCyan.withOpacity(0.3)),
                ),
                icon: const Icon(Icons.auto_graph, size: 16),
                label: const Text("Visualize"),
                onPressed: () => _visualizeRoute(pathData),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: GlassTheme.textSecondary,
                  side: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                icon: const Icon(Icons.code, size: 16),
                label: const Text("JSON"),
                onPressed: () {
                  setState(() {
                    _result = const JsonEncoder.withIndent('  ')
                        .convert(pathData);
                    _showGraph = false;
                  });
                },
              ),
            ),
          ]),
          const SizedBox(height: 6),
          // Row 2: Playback + Simulate
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: accentColor,
                  side: BorderSide(color: accentColor.withOpacity(0.3)),
                ),
                icon: Icon(
                    isAnimating ? Icons.pause : Icons.play_arrow,
                    size: 16),
                label: Text(isAnimating ? "Playing..." : "Playback"),
                onPressed:
                    isAnimating ? null : () => _startPlayback(key, pathData),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor.withOpacity(0.2),
                  foregroundColor: accentColor,
                ),
                icon: isSim
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: accentColor))
                    : const Icon(Icons.science, size: 18),
                label: Text(isSim ? "Running..." : "Simulate"),
                onPressed: isSim ? null : () => _simulatePath(key),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }

  @override
  void dispose() {
    _animController?.dispose();
    _quantityCtrl.dispose();
    _budgetCtrl.dispose();
    _deadlineCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GlassContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Route Parameters',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _altStart,
                          decoration: const InputDecoration(
                            labelText: "Start City",
                            prefixIcon: Icon(Icons.flight_takeoff),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _altEnd,
                          decoration: const InputDecoration(
                            labelText: "End City",
                            prefixIcon: Icon(Icons.flight_land),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _altBlocked,
                          decoration: const InputDecoration(
                            labelText: "Blocked Nodes (comma separated)",
                            prefixIcon:
                                Icon(Icons.block, color: GlassTheme.danger),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // ── v3.0: Cargo Parameters ──
                        Text("Cargo Parameters",
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                    color: GlassTheme.accentCyan)),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                            child: TextField(
                              controller: _quantityCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: "Quantity (units)",
                                prefixIcon: Icon(Icons.inventory_2),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: _productType,
                              decoration: const InputDecoration(
                                labelText: "Product Type",
                                prefixIcon: Icon(Icons.category),
                              ),
                              dropdownColor: const Color(0xFF1a1a2e),
                              items: _productTypes
                                  .map((t) => DropdownMenuItem(
                                      value: t, child: Text(t)))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _productType = v!),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                            child: TextField(
                              controller: _budgetCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: "Max Budget (\$)",
                                prefixIcon: Icon(Icons.account_balance_wallet),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _deadlineCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: "Deadline (hours)",
                                prefixIcon: Icon(Icons.timer),
                              ),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        // ── Omega Slider ──
                        Row(children: [
                          const Icon(Icons.speed,
                              size: 16, color: Colors.orangeAccent),
                          const SizedBox(width: 4),
                          const Text("Time",
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orangeAccent)),
                          Expanded(
                            child: Slider(
                              value: _omega,
                              onChanged: (v) =>
                                  setState(() => _omega = v),
                              activeColor: Color.lerp(
                                  Colors.orangeAccent,
                                  GlassTheme.accentNeonGreen,
                                  _omega),
                              inactiveColor: Colors.white12,
                            ),
                          ),
                          const Text("Cost",
                              style: TextStyle(
                                  fontSize: 11,
                                  color: GlassTheme.accentNeonGreen)),
                          const SizedBox(width: 4),
                          const Icon(Icons.savings,
                              size: 16,
                              color: GlassTheme.accentNeonGreen),
                        ]),
                        Text(
                          "ω = ${_omega.toStringAsFixed(2)} — ${_omega < 0.3 ? 'Time Optimized' : _omega > 0.7 ? 'Cost Optimized' : 'Balanced'}",
                          style: const TextStyle(
                              fontSize: 10,
                              color: GlassTheme.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _findAltRoute,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: GlassTheme.backgroundDark),
                                )
                              : const Icon(Icons.route),
                          label: Text(_isLoading
                              ? "COMPUTING CTR..."
                              : "FIND ROUTES"),
                        ),
                      ],
                    ),
                  ),
                  // ── Route cards ─────────────────────────────
                  if (_altRouteResult != null) ...[
                    const SizedBox(height: 24),
                    Text("Route Options",
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    _routeCard("fastest", _altRouteResult!["fastest"]),
                    const SizedBox(height: 12),
                    _routeCard("cheapest", _altRouteResult!["cheapest"]),
                    const SizedBox(height: 12),
                    _routeCard("balanced", _altRouteResult!["balanced"]),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            flex: 2,
            child: GlassContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header with Graph/JSON toggle ──
                  Row(children: [
                    Text(
                      _showGraph ? 'Route Graph' : 'Result JSON',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        _showGraph ? Icons.code : Icons.auto_graph,
                        color: GlassTheme.accentCyan,
                        size: 20,
                      ),
                      tooltip: _showGraph ? 'Show JSON' : 'Show Graph',
                      onPressed: () =>
                          setState(() => _showGraph = !_showGraph),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _showGraph
                          ? InteractiveRouteGraph(
                              routeData: _selectedRouteData,
                              shipmentProgress: _animatingKey != null &&
                                      _animController != null
                                  ? _animController!.value
                                  : -1,
                            )
                          : SingleChildScrollView(
                              child: SelectableText(
                                _result.isEmpty
                                    ? "Configure cargo parameters and run a query to see CTR-optimized route JSON."
                                    : _result,
                                style: GoogleFonts.firaCode(
                                  color: _result.contains('Error')
                                      ? GlassTheme.danger
                                      : GlassTheme.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
