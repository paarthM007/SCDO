import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'app_config.dart';
import 'package:scdo_app/theme/glass_theme.dart';
import 'package:scdo_app/screens/app_scaffold.dart';
import 'orchestrator_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Set persistence to LOCAL explicitly for web stability
  try {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    // Explicitly handle any pending redirect results from a Google Sign-in fallback
    await FirebaseAuth.instance.getRedirectResult();
  } catch (e) {
    debugPrint("AUTH_DEBUG: Initialization error: $e");
  }

  runApp(const SCDOTesterApp());
}

class SCDOTesterApp extends StatelessWidget {
  const SCDOTesterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      // OrchestratorController lives as long as the app is running.
      create: (_) => OrchestratorController(),
      child: MaterialApp(
        title: 'SCDO Dashboard',
        theme: GlassTheme.darkTheme,
        home: const AuthWrapper(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // userChanges() is more robust than authStateChanges() as it captures token refreshes
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        // Handle waiting state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A0A0A),
            body: Center(child: CircularProgressIndicator(color: Color(0xFF00FFCC))),
          );
        }

        final user = snapshot.data;
        if (user != null) {
          debugPrint("AUTH_DEBUG: User session active: ${user.uid}");
          return const AppScaffold();
        }

        debugPrint("AUTH_DEBUG: No active session. Showing login.");
        return const LoginScreen();
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  String _error = "";
  bool _isLoading = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutQuart),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() { _isLoading = true; _error = ""; });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUp() async {
    setState(() { _isLoading = true; _error = ""; });
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _isLoading = true; _error = ""; });
    try {
      GoogleAuthProvider googleProvider = GoogleAuthProvider();
      // Use signInWithPopup for all environments as it's more stable on Flutter Web
      await FirebaseAuth.instance.signInWithPopup(googleProvider);
    } catch (e) {
      setState(() => _error = "Google Sign-In Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          // Background animated glowing orbs
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF00FFCC),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF0066FF),
              ),
            ),
          ),
          // Blur filter to create glass background
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
            child: Container(color: Colors.transparent),
          ),
          
          // Main UI
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo / Title
                        const Icon(Icons.hub_rounded, size: 64, color: Color(0xFF00FFCC)),
                        const SizedBox(height: 16),
                        const Text(
                          "SCDO Core",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Authenticate to access network routing",
                          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        
                        if (_error.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Text(_error, style: const TextStyle(color: Colors.redAccent)),
                          ),
                          
                        // Inputs
                        TextField(
                          controller: _email,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Access Identifier (Email)",
                            labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                            prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF00FFCC)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF00FFCC)),
                            ),
                            filled: true,
                            fillColor: Colors.black.withOpacity(0.2),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _password,
                          obscureText: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Decryption Key (Password)",
                            labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                            prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF00FFCC)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF00FFCC)),
                            ),
                            filled: true,
                            fillColor: Colors.black.withOpacity(0.2),
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Action Buttons
                        if (_isLoading)
                          const Center(child: CircularProgressIndicator(color: Color(0xFF00FFCC)))
                        else
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _signIn,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00FFCC),
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text("INITIALIZE", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _signUp,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Color(0xFF00FFCC)),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text("REGISTER", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                                ),
                              ),
                            ],
                          ),
                        
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Expanded(child: Divider(color: Colors.white.withOpacity(0.2))),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text("OR", style: TextStyle(color: Colors.white.withOpacity(0.5))),
                            ),
                            Expanded(child: Divider(color: Colors.white.withOpacity(0.2))),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        // Google Auth
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.login_rounded),
                            label: const Text("ACCESS WITH GOOGLE", style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: _isLoading ? null : _signInWithGoogle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SCDOHome extends StatefulWidget {
  @override
  _SCDOHomeState createState() => _SCDOHomeState();
}

class _SCDOHomeState extends State<SCDOHome> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  final String baseUrl = "http://localhost:7860";
  final String apiKey = "scdo-dev-key-change-me";

  String rawJsonResponse = "Output will appear here...";
  List<dynamic> history = [];
  bool isLoading = false;

  // ── Alternate-route state ──────────────────────────────────
  Map<String, dynamic>? altRouteResult; // holds the 3-path result
  Map<String, bool> simulatingPath = {};  // track per-key loading

  final TextEditingController _simCities = TextEditingController(text: "Mumbai, Delhi");
  final TextEditingController _simModes = TextEditingController(text: "Road");
  final TextEditingController _altStart = TextEditingController(text: "Mumbai");
  final TextEditingController _altEnd = TextEditingController(text: "London");
  final TextEditingController _altBlocked = TextEditingController(text: "Dubai, Istanbul");

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  Future<Map<String, String>> _authHeaders() async {
    String? token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return {
      "Authorization": "Bearer $token",
      "X-API-Key": apiKey,
      "Content-Type": "application/json",
    };
  }

  Future<void> _callApi(String endpoint, Map<String, dynamic> body) async {
    setState(() { isLoading = true; rawJsonResponse = "Calling $baseUrl$endpoint..."; });
    try {
      final response = await http.post(
        Uri.parse("$baseUrl$endpoint"),
        headers: await _authHeaders(),
        body: jsonEncode(body),
      );
      
      String bodyString = response.body;
      try {
        var decoded = jsonDecode(bodyString);
        rawJsonResponse = JsonEncoder.withIndent('  ').convert(decoded);
        // If we just triggered a simulation, refresh history shortly after
        if (endpoint.contains("simulate")) {
          Future.delayed(Duration(seconds: 2), () => _fetchHistory());
        }
      } catch (e) {
        rawJsonResponse = "CRITICAL: SERVER ERROR\n\nStatus: ${response.statusCode}\n$bodyString";
      }
      setState(() {});
    } catch (e) {
      setState(() { rawJsonResponse = "Network Error: $e"; });
    } finally {
      setState(() { isLoading = false; });
    }
  }

  // ── Find alternate routes (discovery only, no simulation) ──
  Future<void> _findAlternateRoutes() async {
    setState(() {
      isLoading = true;
      altRouteResult = null;
      simulatingPath = {};
      rawJsonResponse = "Finding alternate routes...";
    });
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/alternate-route"),
        headers: await _authHeaders(),
        body: jsonEncode({
          "start": _altStart.text.trim(),
          "end": _altEnd.text.trim(),
          "blocked": _altBlocked.text.split(',').map((e) => e.trim()).toList(),
        }),
      );
      var decoded = jsonDecode(response.body);
      rawJsonResponse = JsonEncoder.withIndent('  ').convert(decoded);
      if (decoded["status"] == "ok") {
        altRouteResult = decoded["result"];
      }
    } catch (e) {
      rawJsonResponse = "Network Error: $e";
    } finally {
      setState(() { isLoading = false; });
    }
  }

  // ── Simulate a single chosen path ──────────────────────────
  Future<void> _simulatePath(String routeKey) async {
    setState(() { simulatingPath[routeKey] = true; });
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/simulate-path"),
        headers: await _authHeaders(),
        body: jsonEncode({
          "start": _altStart.text.trim(),
          "end": _altEnd.text.trim(),
          "blocked": _altBlocked.text.split(',').map((e) => e.trim()).toList(),
          "route_key": routeKey,
        }),
      );
      var decoded = jsonDecode(response.body);
      rawJsonResponse = JsonEncoder.withIndent('  ').convert(decoded);
      if (decoded["status"] == "ok") {
        Future.delayed(Duration(seconds: 2), () => _fetchHistory());
      }
    } catch (e) {
      rawJsonResponse = "Simulation Error: $e";
    } finally {
      setState(() { simulatingPath[routeKey] = false; });
    }
  }

  Future<void> _fetchHistory() async {
    setState(() { isLoading = true; });
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/history"),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 200) {
        var decoded = jsonDecode(response.body);
        setState(() {
          history = decoded["jobs"] ?? [];
          rawJsonResponse = "History synced: ${history.length} jobs found.";
        });
      }
    } catch (e) {
      setState(() { rawJsonResponse = "History Error: $e"; });
    } finally {
      setState(() { isLoading = false; });
    }
  }

  // ── Build a route summary card ─────────────────────────────
  Widget _routeCard(String key, Map<String, dynamic>? pathData) {
    if (pathData == null || pathData.containsKey("error")) {
      return Card(
        color: Colors.grey[900],
        margin: EdgeInsets.symmetric(vertical: 6),
        child: ListTile(
          title: Text(key.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(pathData?["error"] ?? "No route", style: TextStyle(color: Colors.redAccent)),
        ),
      );
    }

    final dist = pathData["total_distance_km"] ?? "-";
    final time = pathData["total_time_readable"] ?? "-";
    final cost = pathData["total_cost_usd"] ?? "-";
    final hops = pathData["num_hops"] ?? "-";
    final modes = (pathData["modes_used"] as List?)?.join(", ") ?? "-";
    final isSim = simulatingPath[key] == true;

    Color accentColor;
    IconData icon;
    switch (key) {
      case "fastest":
        accentColor = Colors.orangeAccent;
        icon = Icons.speed;
        break;
      case "cheapest":
        accentColor = Colors.greenAccent;
        icon = Icons.savings;
        break;
      default:
        accentColor = Colors.cyanAccent;
        icon = Icons.balance;
    }

    return Card(
      color: Colors.grey[900],
      margin: EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: accentColor.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: accentColor, size: 20),
              SizedBox(width: 8),
              Text(key.toUpperCase(),
                  style: TextStyle(fontWeight: FontWeight.bold, color: accentColor, fontSize: 14)),
            ]),
            SizedBox(height: 8),
            Text("📏 $dist km  ·  ⏱ $time  ·  💲\$$cost",
                style: TextStyle(fontSize: 12, color: Colors.white70)),
            Text("🔗 $hops hops  ·  $modes",
                style: TextStyle(fontSize: 12, color: Colors.white54)),
            SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(color: Colors.white24),
                  ),
                  icon: Icon(Icons.visibility, size: 16),
                  label: Text("View JSON"),
                  onPressed: () {
                    setState(() {
                      rawJsonResponse = JsonEncoder.withIndent('  ').convert(pathData);
                    });
                  },
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor.withOpacity(0.2),
                    foregroundColor: accentColor,
                  ),
                  icon: isSim
                      ? SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: accentColor))
                      : Icon(Icons.play_arrow, size: 18),
                  label: Text(isSim ? "Simulating..." : "Simulate"),
                  onPressed: isSim ? null : () => _simulatePath(key),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("SCDO v2.0 Dashboard"),
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _fetchHistory),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [Tab(text: "Simulation"), Tab(text: "Alt Route"), Tab(text: "History")],
        ),
      ),
      body: Row(
        children: [
          Container(
            width: 380,
            color: Colors.black26,
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: Simulation
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(controller: _simCities, decoration: InputDecoration(labelText: "Cities")),
                      TextField(controller: _simModes, decoration: InputDecoration(labelText: "Modes")),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => _callApi("/api/simulate", {
                          "cities": _simCities.text.split(',').map((e) => e.trim()).toList(),
                          "modes": _simModes.text.split(',').map((e) => e.trim()).toList(),
                        }),
                        child: Text("QUEUE SIMULATION"),
                      ),
                    ],
                  ),
                ),
                // TAB 2: Alt Route — Discovery + per-path simulate
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(controller: _altStart, decoration: InputDecoration(labelText: "Start")),
                      TextField(controller: _altEnd, decoration: InputDecoration(labelText: "End")),
                      TextField(controller: _altBlocked, decoration: InputDecoration(labelText: "Blocked")),
                      SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.route),
                          label: Text("FIND ROUTES"),
                          onPressed: isLoading ? null : _findAlternateRoutes,
                        ),
                      ),
                      SizedBox(height: 12),
                      // Show route cards when available
                      if (altRouteResult != null)
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                _routeCard("fastest", altRouteResult!["fastest"]),
                                _routeCard("cheapest", altRouteResult!["cheapest"]),
                                _routeCard("balanced", altRouteResult!["balanced"]),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // TAB 3: History
                ListView.builder(
                  itemCount: history.length,
                  itemBuilder: (context, i) {
                    var job = history[i];
                    return ListTile(
                      title: Text("${job['cities']?.join(' → ') ?? 'Route'}"),
                      subtitle: Text("Status: ${job['status']} | ${job['created_at']}"),
                      trailing: Icon(
                        job['status'] == 'completed' ? Icons.check_circle : Icons.hourglass_empty,
                        color: job['status'] == 'completed' ? Colors.green : Colors.orange,
                      ),
                      onTap: () {
                        setState(() {
                          rawJsonResponse = JsonEncoder.withIndent('  ').convert(job);
                        });
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              padding: EdgeInsets.all(16),
              color: Colors.black,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("CONSOLE / JOB RESULTS", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      if (isLoading) CircularProgressIndicator(color: Colors.green, strokeWidth: 2),
                    ],
                  ),
                  Divider(color: Colors.green),
                  Expanded(child: SingleChildScrollView(child: SelectableText(rawJsonResponse, style: TextStyle(fontFamily: 'monospace', color: Colors.greenAccent)))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
