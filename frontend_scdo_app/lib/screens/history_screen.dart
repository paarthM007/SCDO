import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:scdo_app/theme/glass_theme.dart';
import 'package:scdo_app/widgets/glass_container.dart';
import '../app_config.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final String baseUrl = AppConfig.gatewayBaseUrl;
  final String apiKey = AppConfig.gatewayApiKey;

  List<dynamic> _history = [];
  bool _isLoading = true;
  String _error = "";
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
    // Auto-refresh every 5 seconds if there are pending jobs
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      bool hasPending = _history.any((job) => job['status'] == 'pending');
      if (hasPending) {
        _fetchHistory(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchHistory({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _error = "";
      });
    }
    try {
      String? token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.get(
        Uri.parse("$baseUrl/api/history"),
        headers: {
          "Authorization": "Bearer $token",
          "X-API-Key": apiKey,
        },
      );
      if (response.statusCode == 200) {
        var decoded = jsonDecode(response.body);
        setState(() {
          _history = decoded["jobs"] ?? [];
        });
      } else {
        setState(() {
          _error = "Failed to load history: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _error = "Network Error: $e";
      });
    } finally {
      if (showLoading && mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteJob(String jobId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GlassTheme.backgroundCard,
        title: const Text("Delete Simulation"),
        content: const Text("Are you sure you want to delete this record?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GlassTheme.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      String? token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.post(
        Uri.parse("$baseUrl/api/history/$jobId"),
        headers: {
          "Authorization": "Bearer $token",
          "X-API-Key": apiKey,
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _history.removeWhere((job) => job['job_id'] == jobId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job deleted successfully'), backgroundColor: GlassTheme.accentNeonGreen),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: ${response.statusCode}'), backgroundColor: GlassTheme.danger),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e'), backgroundColor: GlassTheme.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Simulations',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => _fetchHistory(showLoading: true),
                tooltip: 'Refresh History',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: GlassTheme.accentNeonGreen))
                : _error.isNotEmpty
                    ? Center(child: Text(_error, style: const TextStyle(color: GlassTheme.danger)))
                    : _history.isEmpty
                        ? const Center(child: Text("No simulation history found.", style: TextStyle(color: GlassTheme.textSecondary)))
                        : ListView.separated(
                            itemCount: _history.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final job = _history[index];
                              final status = job['status'] ?? 'unknown';
                              final isCompleted = status == 'completed';
                              
                              return GlassContainer(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isCompleted ? GlassTheme.accentNeonGreen : Colors.orange,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Job ID: ${job['job_id']}",
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "Status: ${status.toUpperCase()}",
                                            style: TextStyle(
                                              color: GlassTheme.textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: GlassTheme.danger),
                                      onPressed: () => _deleteJob(job['job_id']),
                                      tooltip: 'Delete Job',
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
