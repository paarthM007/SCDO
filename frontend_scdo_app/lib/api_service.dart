import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'models.dart';
import 'app_config.dart';

class ApiService {
  static final String baseUrl = "${AppConfig.gatewayBaseUrl}/api";

  /// Returns auth headers with Firebase JWT token for authenticated requests.
  Future<Map<String, String>> _authHeaders() async {
    String? token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return {
      if (token != null) "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    };
  }

  Future<void> dispatchShipment(String cargoType) async {
    final response = await http.post(
      Uri.parse('$baseUrl/dispatch'),
      headers: await _authHeaders(),
      body: jsonEncode({
        "cargo_type": cargoType,
        "origin": "New Delhi", // Matches New Delhi in cities_data.py
        "destination": "Dubai"
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to dispatch shipment: ${response.body}');
    }
  }

  Future<TickResponse> tickSimulation(double hoursToAdvance) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tick'),
      headers: await _authHeaders(),
      body: jsonEncode({"hours_to_advance": hoursToAdvance}),
    );
    
    if (response.statusCode == 200) {
      return TickResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to tick simulation: ${response.body}');
    }
  }

  Future<void> triggerOsintSync({bool demoMode = true}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/sync_osint?demo_mode=$demoMode'),
      headers: await _authHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to sync OSINT: ${response.body}');
    }
  }

  Future<List<String>> fetchCities(String query) async {
    if (query.isEmpty) return [];
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/cities?q=${Uri.encodeQueryComponent(query)}'),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List cities = decoded["cities"] ?? [];
        return cities.map<String>((c) => c["name"] as String).toList();
      }
    } catch (e) {
      print("Error fetching cities: $e");
    }
    return [];
  }
}
