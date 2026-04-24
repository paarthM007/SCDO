import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:scdo_app/theme/glass_theme.dart';
import 'package:scdo_app/widgets/glass_container.dart';

class AltRouteScreen extends StatefulWidget {
  const AltRouteScreen({super.key});

  @override
  State<AltRouteScreen> createState() => _AltRouteScreenState();
}

class _AltRouteScreenState extends State<AltRouteScreen> {
  final String baseUrl = "http://localhost:7860";
  final String apiKey = "scdo-dev-key-change-me";

  final TextEditingController _altStart = TextEditingController(text: "Mumbai");
  final TextEditingController _altEnd = TextEditingController(text: "London");
  final TextEditingController _altBlocked = TextEditingController(text: "Dubai, Istanbul");
  
  bool _isLoading = false;
  String _result = "";

  Future<void> _findAltRoute() async {
    setState(() {
      _isLoading = true;
      _result = "Calculating optimal path...";
    });

    try {
      String? token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final body = {
        "start": _altStart.text.trim(),
        "end": _altEnd.text.trim(),
        "blocked": _altBlocked.text.split(",").map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
      };

      final response = await http.post(
        Uri.parse("$baseUrl/api/alternate-route"),
        headers: {
          "Authorization": "Bearer $token",
          "X-API-Key": apiKey,
          "Content-Type": "application/json"
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        var decoded = jsonDecode(response.body);
        setState(() {
          _result = const JsonEncoder.withIndent('  ').convert(decoded);
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 1,
            child: GlassContainer(
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
                  ElevatedButton(
                    onPressed: _isLoading ? null : _findAltRoute,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: GlassTheme.backgroundDark),
                          )
                        : const Text("FIND ROUTE"),
                  ),
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
                        child: Text(
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
