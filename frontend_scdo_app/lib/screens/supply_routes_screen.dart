import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:scdo_app/theme/glass_theme.dart';
import 'package:scdo_app/widgets/glass_container.dart';
import '../app_config.dart';

class SupplyRoutesScreen extends StatefulWidget {
  final void Function(Map<String, dynamic> data)? onResultsReady;

  const SupplyRoutesScreen({super.key, this.onResultsReady});

  @override
  State<SupplyRoutesScreen> createState() => _SupplyRoutesScreenState();
}

class _SupplyRoutesScreenState extends State<SupplyRoutesScreen>
    with SingleTickerProviderStateMixin {
  final String baseUrl = AppConfig.gatewayBaseUrl;

  final TextEditingController _buyerController =
      TextEditingController(text: "London");
  final TextEditingController _blockedController =
      TextEditingController(text: "");
  String _cargoType = "general";

  final List<TextEditingController> _supplierControllers = [
    TextEditingController(text: "Mumbai"),
    TextEditingController(text: "Shanghai"),
  ];

  bool _isLoading = false;
  String _statusMessage = "";
  Map<String, dynamic>? _lastResult;

  late AnimationController _pulseController;

  final List<String> _cargoTypes = [
    "general",
    "electronics",
    "frozen_food",
    "perishable",
    "pharmaceuticals",
    "bulk_commodity",
    "hazmat",
    "vehicles",
    "live_animals",
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _buyerController.dispose();
    _blockedController.dispose();
    for (var c in _supplierControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addSupplier() {
    setState(() {
      _supplierControllers.add(TextEditingController());
    });
  }

  void _removeSupplier(int index) {
    if (_supplierControllers.length <= 1) return;
    setState(() {
      _supplierControllers[index].dispose();
      _supplierControllers.removeAt(index);
    });
  }

  Future<Map<String, String>> _authHeaders() async {
    String? token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    };
  }

  Future<void> _findMultiSupplierRoutes() async {
    final buyer = _buyerController.text.trim();
    final suppliers = _supplierControllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (buyer.isEmpty) {
      setState(() => _statusMessage = "❌ Please enter a buyer city.");
      return;
    }
    if (suppliers.isEmpty) {
      setState(
          () => _statusMessage = "❌ Please add at least one supplier city.");
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = "🔍 Finding routes from ${suppliers.length} supplier(s) to $buyer...";
      _lastResult = null;
    });

    try {
      final blocked = _blockedController.text
          .split(",")
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final response = await http.post(
        Uri.parse("$baseUrl/api/multi-supplier-routes"),
        headers: await _authHeaders(),
        body: jsonEncode({
          "buyer": buyer,
          "suppliers": suppliers,
          "blocked": blocked,
          "cargo_type": _cargoType,
        }),
      );

      if (response.statusCode == 200) {
        var decoded = jsonDecode(response.body);
        if (decoded["status"] == "ok") {
          setState(() {
            _lastResult = decoded;
            _statusMessage =
                "✅ Found routes for ${decoded['supplier_count']} supplier(s)";
          });
          widget.onResultsReady?.call(decoded);
        } else {
          setState(() {
            _statusMessage = "⚠️ ${decoded['error'] ?? 'Unknown error'}";
          });
        }
      } else {
        setState(() {
          _statusMessage = "❌ Server error: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = "❌ Network Error: $e";
      });
    } finally {
      setState(() => _isLoading = false);
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
            flex: 2,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: GlassTheme.accentCyan.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.hub,
                            color: GlassTheme.accentCyan, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Multi-Supplier Routing',
                                style: Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(height: 4),
                            Text(
                              'Define your buyer location and add multiple suppliers to compare routes.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  GlassContainer(
                    borderColor: GlassTheme.accentNeonGreen.withOpacity(0.3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.store, color: GlassTheme.accentNeonGreen, size: 20),
                            const SizedBox(width: 8),
                            Text("BUYER (Destination)",
                                style: TextStyle(
                                  color: GlassTheme.accentNeonGreen,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  letterSpacing: 1.2,
                                )),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _buyerController,
                          decoration: const InputDecoration(
                            labelText: "Buyer City",
                            prefixIcon: Icon(Icons.location_city, color: GlassTheme.accentNeonGreen),
                            hintText: "e.g. London, New York, Tokyo",
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  GlassContainer(
                    borderColor: GlassTheme.accentCyan.withOpacity(0.3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.factory, color: GlassTheme.accentCyan, size: 20),
                            const SizedBox(width: 8),
                            Text("SUPPLIERS (Origins)",
                                style: TextStyle(
                                  color: GlassTheme.accentCyan,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  letterSpacing: 1.2,
                                )),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: GlassTheme.accentCyan.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "${_supplierControllers.length} supplier(s)",
                                style: TextStyle(color: GlassTheme.accentCyan, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ..._supplierControllers.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final controller = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: GlassTheme.accentCyan.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text("${idx + 1}",
                                      style: TextStyle(
                                          color: GlassTheme.accentCyan,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: controller,
                                    decoration: InputDecoration(
                                      labelText: "Supplier ${idx + 1}",
                                      prefixIcon: const Icon(Icons.local_shipping, color: GlassTheme.accentCyan),
                                      hintText: "e.g. Mumbai, Shanghai",
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (_supplierControllers.length > 1)
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: GlassTheme.danger, size: 22),
                                    onPressed: () => _removeSupplier(idx),
                                  ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _addSupplier,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text("Add Supplier"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: GlassTheme.accentCyan,
                            side: BorderSide(color: GlassTheme.accentCyan.withOpacity(0.3)),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  GlassContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.tune, color: GlassTheme.textSecondary, size: 20),
                            const SizedBox(width: 8),
                            Text("OPTIONS",
                                style: TextStyle(
                                  color: GlassTheme.textSecondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  letterSpacing: 1.2,
                                )),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _blockedController,
                          decoration: const InputDecoration(
                            labelText: "Blocked Cities (comma separated)",
                            prefixIcon: Icon(Icons.block, color: GlassTheme.danger),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _cargoType,
                          decoration: const InputDecoration(
                            labelText: "Cargo Type",
                            prefixIcon: Icon(Icons.inventory_2),
                          ),
                          dropdownColor: GlassTheme.backgroundCard,
                          items: _cargoTypes.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(type.replaceAll("_", " ").toUpperCase(), style: const TextStyle(fontSize: 14)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _cargoType = val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        decoration: _isLoading
                            ? null
                            : BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: GlassTheme.accentNeonGreen.withOpacity(0.15 + _pulseController.value * 0.1),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                        child: child,
                      );
                    },
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _findMultiSupplierRoutes,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: GlassTheme.backgroundDark),
                              )
                            : const Icon(Icons.search, size: 22),
                        label: Text(
                          _isLoading ? "FINDING ROUTES..." : "FIND ALL SUPPLY ROUTES",
                          style: const TextStyle(fontSize: 16, letterSpacing: 1.0),
                        ),
                      ),
                    ),
                  ),
                  if (_statusMessage.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    GlassContainer(
                      borderColor: _statusMessage.contains("❌")
                          ? GlassTheme.danger
                          : _statusMessage.contains("✅") ? GlassTheme.accentNeonGreen : GlassTheme.accentCyan,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            _statusMessage.contains("❌")
                                ? Icons.error_outline
                                : _statusMessage.contains("✅") ? Icons.check_circle_outline : Icons.info_outline,
                            color: _statusMessage.contains("❌")
                                ? GlassTheme.danger
                                : _statusMessage.contains("✅") ? GlassTheme.accentNeonGreen : GlassTheme.accentCyan,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _statusMessage,
                              style: TextStyle(
                                color: _statusMessage.contains("❌") ? GlassTheme.danger : GlassTheme.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            flex: 3,
            child: _lastResult != null
                ? _buildQuickSummary()
                : GlassContainer(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.hub, size: 80, color: GlassTheme.accentCyan.withOpacity(0.2)),
                        const SizedBox(height: 24),
                        Text(
                          "Multi-Supplier Route Discovery",
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: GlassTheme.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Add your buyer destination and multiple supplier origins,\nthen find and compare the best routes for each.",
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSummary() {
    final comparison = (_lastResult!["comparison"] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final buyer = _lastResult!["buyer"] ?? "";

    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics, color: GlassTheme.accentCyan, size: 24),
              const SizedBox(width: 12),
              Text("Quick Summary", style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: GlassTheme.accentNeonGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text("Buyer: $buyer", style: const TextStyle(color: GlassTheme.accentNeonGreen, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Switch to the Route Comparison tab for full side-by-side analysis.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: comparison.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = comparison[index];
                final supplier = item["supplier"] ?? "Unknown";
                final balanced = item["balanced"];
                final hasRoute = balanced != null && !balanced.containsKey("error");

                return GlassContainer(
                  borderColor: hasRoute ? GlassTheme.accentCyan.withOpacity(0.3) : GlassTheme.danger.withOpacity(0.3),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (hasRoute ? GlassTheme.accentCyan : GlassTheme.danger).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              hasRoute ? Icons.factory : Icons.error_outline,
                              color: hasRoute ? GlassTheme.accentCyan : GlassTheme.danger,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(supplier, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 2),
                                Text("→ $buyer", style: const TextStyle(color: GlassTheme.textSecondary, fontSize: 12)),
                              ],
                            ),
                          ),
                          if (hasRoute)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: GlassTheme.accentNeonGreen.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text("Route Found",
                                  style: TextStyle(color: GlassTheme.accentNeonGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      if (hasRoute) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _summaryMetric("Distance", "${balanced['total_distance_km']} km", Icons.straighten),
                            const SizedBox(width: 20),
                            _summaryMetric("Time", "${balanced['total_time_readable']}", Icons.access_time),
                            const SizedBox(width: 20),
                            _summaryMetric("Cost", "\$${balanced['total_cost_usd']}", Icons.attach_money),
                            const SizedBox(width: 20),
                            _summaryMetric("Hops", "${balanced['num_hops']}", Icons.linear_scale),
                          ],
                        ),
                      ] else
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(balanced?["error"] ?? "No route found", style: const TextStyle(color: GlassTheme.danger, fontSize: 13)),
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

  Widget _summaryMetric(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: GlassTheme.textSecondary),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: GlassTheme.textPrimary)),
          Text(label, style: const TextStyle(fontSize: 10, color: GlassTheme.textSecondary)),
        ],
      ),
    );
  }
}
