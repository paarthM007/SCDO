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

  Future<Map<String, String>> _authHeaders() async {
    String? token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return {
      "Authorization": "Bearer $token",
      "X-API-Key": apiKey,
      "Content-Type": "application/json",
    };
  }

  Future<void> _fetchHistory({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _error = "";
      });
    }
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/history"),
        headers: await _authHeaders(),
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
      final response = await http.post(
        Uri.parse("$baseUrl/api/history/$jobId"),
        headers: await _authHeaders(),
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

  Future<void> _downloadReport(Map<String, dynamic> job) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating report...'), duration: Duration(seconds: 1)),
      );

      final response = await http.post(
        Uri.parse("$baseUrl/api/report"),
        headers: await _authHeaders(),
        body: jsonEncode(job),
      );

      if (response.statusCode == 200) {
        // In Flutter Web, we can trigger a download by creating an anchor element.
        // For mobile, you'd use path_provider and open_file.
        // Since the user is on Chrome, we use the web approach.
        // Note: For a real production app, use a package like 'universal_html' or conditional imports.
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report generated! (Check console for raw bytes in this demo)'), backgroundColor: GlassTheme.accentNeonGreen),
        );
        print("PDF Bytes received: ${response.bodyBytes.length}");
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Report failed: ${response.statusCode}'), backgroundColor: GlassTheme.danger),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report error: $e'), backgroundColor: GlassTheme.danger),
      );
    }
  }

  // ── Feedback dialog for community risk reporting ────────────
  void _showFeedbackDialog(Map<String, dynamic> job) {
    List<String> cities = List<String>.from(job['cities'] ?? []);
    if (cities.isEmpty) return;

    Map<String, double> ratings = { for (var c in cities) c: 5.0 };

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: GlassTheme.backgroundCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(children: [
                Icon(Icons.feedback, color: Colors.amberAccent),
                const SizedBox(width: 10),
                Text("Rate City Risks", style: TextStyle(color: Colors.amberAccent)),
              ]),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "How risky did each city feel on this route?\n(1 = Safe, 10 = Very Risky)",
                        style: TextStyle(color: GlassTheme.textSecondary, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ...cities.map((city) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 100,
                                child: Text(city,
                                    style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 13),
                                    overflow: TextOverflow.ellipsis),
                              ),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(ctx).copyWith(
                                    activeTrackColor: Colors.amberAccent,
                                    inactiveTrackColor: Colors.amberAccent.withOpacity(0.2),
                                    thumbColor: Colors.amberAccent,
                                    overlayColor: Colors.amberAccent.withOpacity(0.1),
                                  ),
                                  child: Slider(
                                    value: ratings[city]!,
                                    min: 1, max: 10, divisions: 9,
                                    label: ratings[city]!.round().toString(),
                                    onChanged: (v) => setDialogState(() => ratings[city] = v),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 30,
                                child: Text(
                                  ratings[city]!.round().toString(),
                                  style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 15),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel", style: TextStyle(color: GlassTheme.textSecondary)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amberAccent,
                    foregroundColor: GlassTheme.backgroundDark,
                  ),
                  icon: const Icon(Icons.send, size: 18),
                  label: const Text("Submit"),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _submitFeedback(ratings, job['job_id']);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitFeedback(Map<String, double> ratings, String? jobId) async {
    Map<String, int> intRatings = ratings.map((k, v) => MapEntry(k, v.round()));
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/feedback"),
        headers: await _authHeaders(),
        body: jsonEncode({
          "ratings": intRatings,
          "job_id": jobId,
        }),
      );
      var decoded = jsonDecode(response.body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ ${decoded['message'] ?? 'Feedback submitted!'}"),
            backgroundColor: GlassTheme.accentNeonGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Feedback error: $e'), backgroundColor: GlassTheme.danger),
        );
      }
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
                              final cities = job['cities'] as List?;
                              
                              return GlassContainer(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
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
                                                cities != null ? cities.join(' → ') : "Job ID: ${job['job_id']}",
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
                                        if (isCompleted) ...[
                                          IconButton(
                                            icon: const Icon(Icons.picture_as_pdf, color: GlassTheme.accentCyan, size: 22),
                                            tooltip: "Download PDF Report",
                                            onPressed: () => _downloadReport(job),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.rate_review, color: Colors.amberAccent, size: 22),
                                            tooltip: "Rate city risks",
                                            onPressed: () => _showFeedbackDialog(job),
                                          ),
                                        ],
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: GlassTheme.danger),
                                          onPressed: () => _deleteJob(job['job_id']),
                                          tooltip: 'Delete Job',
                                        ),
                                      ],
                                    ),
                                    if (isCompleted && job['summary'] != null) ...[
                                      const Divider(color: Colors.white12, height: 24),
                                      _buildSummaryGrid(job['summary']),
                                    ],
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
  Widget _buildSummaryGrid(Map<String, dynamic> summary) {
    final riskLevel = summary['risk_level'] ?? 'Unknown';
    Color riskColor = GlassTheme.accentNeonGreen;
    if (riskLevel == 'High') riskColor = GlassTheme.danger;
    if (riskLevel == 'Medium') riskColor = Colors.orange;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStatItem(Icons.timer, "Time", "${summary['time_mean']?.toStringAsFixed(1) ?? 'N/A'} hrs"),
        _buildStatItem(Icons.attach_money, "Cost", "\$${summary['cost_mean']?.toStringAsFixed(2) ?? 'N/A'}"),
        _buildStatItem(Icons.warning_amber, "Risk", riskLevel, valueColor: riskColor),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: GlassTheme.textSecondary),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: GlassTheme.textSecondary, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? GlassTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
