import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:scdo_app/theme/glass_theme.dart';
import 'package:scdo_app/widgets/glass_container.dart';
import '../app_config.dart';

class AltRouteScreen extends StatefulWidget {
  const AltRouteScreen({super.key});

  @override
  State<AltRouteScreen> createState() => _AltRouteScreenState();
}

class _AltRouteScreenState extends State<AltRouteScreen> {
  final String baseUrl = AppConfig.gatewayBaseUrl;
  final String apiKey = AppConfig.gatewayApiKey;

  final TextEditingController _altStart = TextEditingController(text: "Mumbai");
  final TextEditingController _altEnd = TextEditingController(text: "London");
  final TextEditingController _altBlocked = TextEditingController(text: "Dubai, Istanbul");
  
  bool _isLoading = false;
  String _result = "";

  // ── Route selection state ──────────────────────────────────
  Map<String, dynamic>? _altRouteResult;
  Map<String, bool> _simulatingPath = {};

  Future<Map<String, String>> _authHeaders() async {
    String? token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return {
      "Authorization": "Bearer $token",
      "X-API-Key": apiKey,
      "Content-Type": "application/json",
    };
  }

  Future<void> _findAltRoute() async {
    setState(() {
      _isLoading = true;
      _result = "Calculating optimal paths...";
      _altRouteResult = null;
      _simulatingPath = {};
    });

    try {
      final body = {
        "start": _altStart.text.trim(),
        "end": _altEnd.text.trim(),
        "blocked": _altBlocked.text.split(",").map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
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

  // ── Simulate a single chosen path ──────────────────────────
  Future<void> _simulatePath(String routeKey) async {
    setState(() { _simulatingPath[routeKey] = true; });
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/simulate-path"),
        headers: await _authHeaders(),
        body: jsonEncode({
          "start": _altStart.text.trim(),
          "end": _altEnd.text.trim(),
          "blocked": _altBlocked.text.split(',').map((e) => e.trim()).where((s) => s.isNotEmpty).toList(),
          "route_key": routeKey,
        }),
      );
      var decoded = jsonDecode(response.body);
      setState(() {
        _result = const JsonEncoder.withIndent('  ').convert(decoded);
      });
      if (decoded["status"] == "ok" && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ Simulation queued for '${routeKey.toUpperCase()}' path"),
            backgroundColor: GlassTheme.accentNeonGreen,
          ),
        );
      }
    } catch (e) {
      setState(() { _result = "Simulation Error: $e"; });
    } finally {
      setState(() { _simulatingPath[routeKey] = false; });
    }
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
            Text(key.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Expanded(child: Text(
              pathData?["error"] ?? "No route found",
              style: const TextStyle(color: GlassTheme.danger, fontSize: 12),
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
                style: TextStyle(fontWeight: FontWeight.bold, color: accentColor, fontSize: 15)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text("$hops hops", style: TextStyle(color: accentColor, fontSize: 11)),
            ),
          ]),
          const SizedBox(height: 12),
          Row(
            children: [
              _statChip(Icons.straighten, "$dist km", Colors.white70),
              const SizedBox(width: 16),
              _statChip(Icons.access_time, time.toString(), Colors.white70),
              const SizedBox(width: 16),
              _statChip(Icons.attach_money, "\$$cost", Colors.white70),
            ],
          ),
          const SizedBox(height: 6),
          Text("Modes: $modes", style: const TextStyle(fontSize: 11, color: GlassTheme.textSecondary)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: GlassTheme.textSecondary,
                  side: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                icon: const Icon(Icons.visibility, size: 16),
                label: const Text("View JSON"),
                onPressed: () {
                  setState(() {
                    _result = const JsonEncoder.withIndent('  ').convert(pathData);
                  });
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor.withOpacity(0.2),
                  foregroundColor: accentColor,
                ),
                icon: isSim
                    ? SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: accentColor))
                    : const Icon(Icons.play_arrow, size: 18),
                label: Text(isSim ? "Simulating..." : "Simulate This Path"),
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
                            prefixIcon: Icon(Icons.block, color: GlassTheme.danger),
                          ),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _findAltRoute,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: GlassTheme.backgroundDark),
                                )
                              : const Icon(Icons.route),
                          label: Text(_isLoading ? "FINDING..." : "FIND ROUTES"),
                        ),
                      ],
                    ),
                  ),
                  // ── Route cards ─────────────────────────────
                  if (_altRouteResult != null) ...[
                    const SizedBox(height: 24),
                    Text("Route Options", style: Theme.of(context).textTheme.titleMedium),
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
                  Text(
                    'Result Graph',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          _result.isEmpty ? "Run a query to see the alternate route JSON." : _result,
                          style: GoogleFonts.firaCode(
                            color: _result.contains('Error') ? GlassTheme.danger : GlassTheme.textPrimary,
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
