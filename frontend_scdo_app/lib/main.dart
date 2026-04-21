import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';

// ═══════════════════════════════════════════════════════════════
//  CONFIGURATION
// ═══════════════════════════════════════════════════════════════


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const SCDOApp());
}

// ═══════════════════════════════════════════════════════════════
//  APP ROOT
// ═══════════════════════════════════════════════════════════════
class SCDOApp extends StatelessWidget {
  const SCDOApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SCDO Simulator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorSchemeSeed: const Color(0xFF58A6FF),
        fontFamily: 'Roboto',
        cardTheme: CardTheme(
          color: const Color(0xFF161B22),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0D1117),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF30363D)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF30363D)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: Color(0xFF58A6FF), width: 1.5),
          ),
          labelStyle: const TextStyle(color: Color(0xFF8B949E)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF238636),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      home: const SimulationScreen(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SIMULATION SCREEN — Input + Firestore Listener
// ═══════════════════════════════════════════════════════════════
class SimulationScreen extends StatefulWidget {
  const SimulationScreen({super.key});

  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen> {
  final _citiesController = TextEditingController(text: 'Mumbai, Delhi, Dubai');
  final _modesController = TextEditingController(text: 'Road, Ship');
  String _cargoType = 'general';
  final _dateController = TextEditingController();

  bool _isSubmitting = false;
  String? _activeJobId;

  // ── Cargo type options ──────────────────────────────────────
  final List<String> _cargoOptions = [
    'general',
    'frozen_food',
    'perishable',
    'electronics',
    'pharmaceuticals',
    'heavy_machinery',
    'fragile',
    'chemicals',
  ];

  // ── Submit job ──────────────────────────────────────────────
  Future<void> _submitSimulation() async {
    final cities = _citiesController.text
        .split(',')
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();
    final modes = _modesController.text
        .split(',')
        .map((m) => m.trim())
        .where((m) => m.isNotEmpty)
        .toList();

    if (cities.length < 2) {
      _showSnackBar('Enter at least 2 cities');
      return;
    }
    if (modes.length != cities.length - 1) {
      _showSnackBar(
          'Modes must be exactly ${cities.length - 1} (cities - 1)');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // ── Direct Firestore Write (No-Card Mode) ────────────────
      final jobData = {
        'cities': cities,
        'modes': modes,
        'cargo_type': _cargoType,
        'n_iterations': 50,
        'status': 'pending',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'result': null,
        'error': null,
      };

      if (_dateController.text.trim().isNotEmpty) {
        jobData['date'] = _dateController.text.trim();
      }

      // Add document to Firestore
      final docRef = await FirebaseFirestore.instance
          .collection('sim_jobs')
          .add(jobData);

      setState(() {
        _activeJobId = docRef.id;
        _isSubmitting = false;
      });
      _showSnackBar('Job created in Firestore: ${docRef.id}');

    } catch (e) {
      _showSnackBar('Firestore error: $e');
      setState(() => _isSubmitting = false);
    }
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _citiesController.dispose();
    _modesController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── App Bar ────────────────────────────────────────
          SliverAppBar(
            floating: true,
            pinned: true,
            expandedHeight: 120,
            backgroundColor: const Color(0xFF161B22),
            flexibleSpace: FlexibleSpaceBar(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF58A6FF), Color(0xFF238636)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.route, size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'SCDO Simulator',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              centerTitle: true,
            ),
          ),

          // ── Input Form ─────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NEW SIMULATION',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF58A6FF),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _citiesController,
                        decoration: const InputDecoration(
                          labelText: 'Cities (comma-separated)',
                          prefixIcon: Icon(Icons.location_city,
                              color: Color(0xFF58A6FF)),
                          hintText: 'Mumbai, Delhi, Dubai',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _modesController,
                        decoration: const InputDecoration(
                          labelText: 'Transport Modes (comma-separated)',
                          prefixIcon: Icon(Icons.local_shipping,
                              color: Color(0xFF58A6FF)),
                          hintText: 'Road, Ship',
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _cargoType,
                        decoration: const InputDecoration(
                          labelText: 'Cargo Type',
                          prefixIcon: Icon(Icons.inventory_2,
                              color: Color(0xFF58A6FF)),
                        ),
                        dropdownColor: const Color(0xFF161B22),
                        items: _cargoOptions.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type.replaceAll('_', ' ').toUpperCase(),
                                style: const TextStyle(fontSize: 14)),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setState(() => _cargoType = val ?? 'general'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _dateController,
                        decoration: const InputDecoration(
                          labelText: 'Target Date (optional)',
                          prefixIcon: Icon(Icons.calendar_today,
                              color: Color(0xFF58A6FF)),
                          hintText: 'YYYY-MM-DD',
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              _isSubmitting ? null : _submitSimulation,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ))
                              : const Icon(Icons.play_arrow),
                          label: Text(_isSubmitting
                              ? 'Submitting...'
                              : 'Run Simulation'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Active Job Firestore Listener ──────────────────
          if (_activeJobId != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _JobStatusCard(jobId: _activeJobId!),
              ),
            ),

          // ── Recent Jobs List (Firestore Listener) ──────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RECENT JOBS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8B949E),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _RecentJobsList(
                    onJobTap: (jobId) {
                      setState(() => _activeJobId = jobId);
                    },
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

// ═══════════════════════════════════════════════════════════════
//  JOB STATUS CARD — Real-time Firestore Listener
// ═══════════════════════════════════════════════════════════════
class _JobStatusCard extends StatelessWidget {
  final String jobId;
  const _JobStatusCard({required this.jobId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sim_jobs')
          .doc(jobId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildCard(
            status: 'error',
            child: Text('Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent)),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildCard(
            status: 'waiting',
            child: const Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Waiting for document...'),
              ],
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final status = data['status'] ?? 'unknown';

        return _buildCard(
          status: status,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ────────────────────────────────────
              Row(
                children: [
                  _StatusBadge(status: status),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      jobId,
                      style: const TextStyle(
                        fontSize: 13,
                        fontFamily: 'monospace',
                        color: Color(0xFF8B949E),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              // ── Route info ────────────────────────────────
              if (data['cities'] != null) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (int i = 0;
                        i < (data['cities'] as List).length;
                        i++) ...[
                      if (i > 0)
                        const Icon(Icons.arrow_forward,
                            size: 16, color: Color(0xFF58A6FF)),
                      Chip(
                        label: Text(data['cities'][i],
                            style: const TextStyle(fontSize: 12)),
                        backgroundColor: const Color(0xFF0D1117),
                        side:
                            const BorderSide(color: Color(0xFF30363D)),
                      ),
                    ],
                  ],
                ),
              ],

              // ── Processing indicator ──────────────────────
              if (status == 'pending' || status == 'processing') ...[
                const SizedBox(height: 20),
                const LinearProgressIndicator(
                  backgroundColor: Color(0xFF30363D),
                  valueColor:
                      AlwaysStoppedAnimation(Color(0xFF58A6FF)),
                ),
                const SizedBox(height: 8),
                Text(
                  status == 'pending'
                      ? 'Queued — waiting for worker...'
                      : 'Processing — running Monte Carlo simulation...',
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF8B949E)),
                ),
              ],

              // ── Results ───────────────────────────────────
              if (status == 'completed' && data['result'] != null)
                _ResultsDisplay(result: data['result']),

              // ── Error ─────────────────────────────────────
              if (status == 'failed' && data['error'] != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3D1117),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.redAccent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${data['error']}',
                            style: const TextStyle(
                                color: Colors.redAccent, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCard({required String status, required Widget child}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ACTIVE JOB',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF58A6FF),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  RESULTS DISPLAY
// ═══════════════════════════════════════════════════════════════
class _ResultsDisplay extends StatelessWidget {
  final Map<String, dynamic> result;
  const _ResultsDisplay({required this.result});

  @override
  Widget build(BuildContext context) {
    final risk = result['combined_risk'] as Map<String, dynamic>?;
    final stats = result['simulation_stats'] as Map<String, dynamic>?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Divider(color: Color(0xFF30363D)),
        const SizedBox(height: 12),

        // ── Combined Risk Score ──────────────────────────
        if (risk != null) ...[
          Row(
            children: [
              const Text('COMBINED RISK',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8B949E),
                    letterSpacing: 1,
                  )),
              const Spacer(),
              _RiskBadge(
                score: (risk['score'] as num?)?.toDouble() ?? 0,
                level: risk['level']?.toString() ?? 'UNKNOWN',
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (risk['score'] as num?)?.toDouble() ?? 0,
              minHeight: 8,
              backgroundColor: const Color(0xFF30363D),
              valueColor: AlwaysStoppedAnimation(
                _riskColor((risk['score'] as num?)?.toDouble() ?? 0),
              ),
            ),
          ),
          if (risk['recommendation'] != null) ...[
            const SizedBox(height: 8),
            Text(
              risk['recommendation'].toString(),
              style: const TextStyle(fontSize: 13, color: Color(0xFFC9D1D9)),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              _MiniStat(
                label: 'Weather',
                value: _fmtScore(risk['weather_risk']?['score']),
                icon: Icons.cloud,
              ),
              const SizedBox(width: 16),
              _MiniStat(
                label: 'Sentiment',
                value: _fmtScore(risk['sentiment_risk']?['score']),
                icon: Icons.newspaper,
              ),
            ],
          ),
        ],

        // ── Simulation Stats ─────────────────────────────
        if (stats != null) ...[
          const SizedBox(height: 20),
          const Divider(color: Color(0xFF30363D)),
          const SizedBox(height: 12),
          const Text('SIMULATION RESULTS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF8B949E),
                letterSpacing: 1,
              )),
          const SizedBox(height: 12),
          _buildStatsGrid(stats),
        ],
      ],
    );
  }

  Widget _buildStatsGrid(Map<String, dynamic> stats) {
    final time = stats['time'] as Map<String, dynamic>?;
    final cost = stats['cost'] as Map<String, dynamic>?;

    return Column(
      children: [
        if (time != null)
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.schedule,
                  label: 'Lead Time (avg)',
                  value:
                      '${_fmtNum(time['mean'])} h',
                  subtitle:
                      '${(_fmtNum((time['mean'] as num?) != null ? (time['mean'] as num) / 24 : 0))} days',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  icon: Icons.show_chart,
                  label: 'P95 Lead Time',
                  value: '${_fmtNum(time['p95'])} h',
                  subtitle: 'worst 5%',
                ),
              ),
            ],
          ),
        const SizedBox(height: 12),
        if (cost != null)
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.attach_money,
                  label: 'Cost (avg)',
                  value: '\$${_fmtNum(cost['mean'])}',
                  subtitle: 'std: \$${_fmtNum(cost['std'])}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  icon: Icons.trending_up,
                  label: 'P95 Cost',
                  value: '\$${_fmtNum(cost['p95'])}',
                  subtitle: 'worst 5%',
                ),
              ),
            ],
          ),
      ],
    );
  }

  String _fmtNum(dynamic val) {
    if (val == null) return '—';
    if (val is num) return val.toStringAsFixed(1);
    return val.toString();
  }

  String _fmtScore(dynamic val) {
    if (val == null) return '—';
    if (val is num) return val.toStringAsFixed(3);
    return val.toString();
  }

  static Color _riskColor(double score) {
    if (score >= 0.7) return const Color(0xFFDA3633);
    if (score >= 0.45) return const Color(0xFFD29922);
    if (score >= 0.25) return const Color(0xFF58A6FF);
    return const Color(0xFF238636);
  }
}

// ═══════════════════════════════════════════════════════════════
//  RECENT JOBS LIST — Firestore Stream
// ═══════════════════════════════════════════════════════════════
class _RecentJobsList extends StatelessWidget {
  final void Function(String jobId) onJobTap;
  const _RecentJobsList({required this.onJobTap});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sim_jobs')
          .orderBy('created_at', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Error loading jobs: ${snapshot.error}',
              style: const TextStyle(color: Colors.redAccent));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: const Center(
              child: Text('No simulation jobs yet. Submit one above!',
                  style: TextStyle(color: Color(0xFF8B949E))),
            ),
          );
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'unknown';
            final cities = (data['cities'] as List?)?.join(' → ') ?? '—';

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onTap: () => onJobTap(doc.id),
                leading: _StatusDot(status: status),
                title: Text(
                  cities,
                  style: const TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  doc.id,
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: Color(0xFF8B949E),
                  ),
                ),
                trailing: _StatusBadge(status: status),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SMALL UI COMPONENTS
// ═══════════════════════════════════════════════════════════════

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      'pending' => (const Color(0xFFD29922), Icons.hourglass_empty),
      'processing' => (const Color(0xFF58A6FF), Icons.sync),
      'completed' => (const Color(0xFF238636), Icons.check_circle),
      'failed' => (const Color(0xFFDA3633), Icons.error),
      _ => (const Color(0xFF8B949E), Icons.help_outline),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final String status;
  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'pending' => const Color(0xFFD29922),
      'processing' => const Color(0xFF58A6FF),
      'completed' => const Color(0xFF238636),
      'failed' => const Color(0xFFDA3633),
      _ => const Color(0xFF8B949E),
    };

    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)],
      ),
    );
  }
}

class _RiskBadge extends StatelessWidget {
  final double score;
  final String level;
  const _RiskBadge({required this.score, required this.level});

  @override
  Widget build(BuildContext context) {
    final color = _ResultsDisplay._riskColor(score);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        '${(score * 100).toStringAsFixed(0)}% $level',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _MiniStat(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF8B949E)),
        const SizedBox(width: 6),
        Text('$label: ',
            style:
                const TextStyle(fontSize: 12, color: Color(0xFF8B949E))),
        Text(value,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFFC9D1D9))),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF58A6FF)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8B949E),
                        letterSpacing: 0.3),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFC9D1D9))),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF8B949E))),
        ],
      ),
    );
  }
}
