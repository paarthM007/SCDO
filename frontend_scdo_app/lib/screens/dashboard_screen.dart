import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:scdo_app/theme/glass_theme.dart';
import 'package:scdo_app/widgets/glass_container.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final String baseUrl = "http://localhost:7860";
  final String apiKey = "scdo-dev-key-change-me";

  final TextEditingController _simCities = TextEditingController(text: "Mumbai, Delhi");
  final TextEditingController _simModes = TextEditingController(text: "Road");
  
  bool _isLoading = false;
  String _result = "";

  Future<void> _runSimulation() async {
    setState(() {
      _isLoading = true;
      _result = "Enqueuing simulation...";
    });

    try {
      String? token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final body = {
        "cities": _simCities.text.split(",").map((s) => s.trim()).toList(),
        "modes": _simModes.text.split(",").map((s) => s.trim()).toList(),
      };

      final response = await http.post(
        Uri.parse("$baseUrl/api/simulate"),
        headers: {
          "Authorization": "Bearer $token",
          "X-API-Key": apiKey,
          "Content-Type": "application/json"
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        setState(() {
          _result = "Simulation Queued Successfully!\nCheck the History tab for results in a few moments.";
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
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'New Simulation',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Configure your logistics parameters to forecast delays and costs.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              GlassContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _simCities,
                      decoration: const InputDecoration(
                        labelText: "Route Cities (comma separated)",
                        prefixIcon: Icon(Icons.location_on),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _simModes,
                      decoration: const InputDecoration(
                        labelText: "Transport Modes (comma separated)",
                        prefixIcon: Icon(Icons.local_shipping),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _runSimulation,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: GlassTheme.backgroundDark),
                            )
                          : const Text("RUN SIMULATION"),
                    ),
                  ],
                ),
              ),
              if (_result.isNotEmpty) ...[
                const SizedBox(height: 24),
                GlassContainer(
                  borderColor: _result.contains('Error') ? GlassTheme.danger : GlassTheme.accentNeonGreen,
                  child: Text(
                    _result,
                    style: TextStyle(
                      color: _result.contains('Error') ? GlassTheme.danger : GlassTheme.accentNeonGreen,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
