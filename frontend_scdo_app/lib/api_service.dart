import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

class ApiService {
  static const String baseUrl = "https://paarthm007-scdo-api.hf.space/api";
  // static const String baseUrl = "http://localhost:7860/api";

  Future<void> dispatchShipment(String cargoType) async {
    final response = await http.post(
      Uri.parse('$baseUrl/dispatch'),
      headers: {"Content-Type": "application/json"},
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
      headers: {"Content-Type": "application/json"},
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
      headers: {"Content-Type": "application/json"},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to sync OSINT: ${response.body}');
    }
  }
}
