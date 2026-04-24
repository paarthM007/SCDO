import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart'; // Ensure you have this file generated
// import 'package:google_sign_in/google_sign_in.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(SCDOTesterApp());
}

class SCDOTesterApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return SCDOHome();
        }
        return LoginScreen();
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  String _error = "";

  Future<void> _signIn() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _signUp() async {
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  // ─── NEW OAUTH LOGIC ──────────────────────────────────────────

 Future<void> _signInWithGoogle() async {
    try {
      // Use the built-in Firebase Web Provider instead of the buggy package
      GoogleAuthProvider googleProvider = GoogleAuthProvider();
      await FirebaseAuth.instance.signInWithPopup(googleProvider);
    } catch (e) {
      setState(() => _error = "Google Sign-In Error: $e");
    }
  }

  // Future<void> _signInWithGitHub() async {
  //   try {
  //     GithubAuthProvider githubProvider = GithubAuthProvider();
  //     await FirebaseAuth.instance.signInWithProvider(githubProvider);
  //   } catch (e) {
  //     setState(() => _error = "GitHub Sign-In Error: $e");
  //   }
  // }

  // ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("SCDO Login")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_error.isNotEmpty) 
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(_error, style: TextStyle(color: Colors.red), textAlign: TextAlign.center),
              ),
            TextField(controller: _email, decoration: InputDecoration(labelText: "Email")),
            TextField(controller: _password, decoration: InputDecoration(labelText: "Password"), obscureText: true),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(onPressed: _signIn, child: Text("Sign In")),
                ElevatedButton(onPressed: _signUp, child: Text("Sign Up")),
              ],
            ),
            SizedBox(height: 30),
            Divider(color: Colors.grey),
            SizedBox(height: 20),
            // ─── NEW OAUTH BUTTONS ────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                icon: Icon(Icons.g_mobiledata, size: 30),
                label: Text("Sign in with Google"),
                onPressed: _signInWithGoogle,
              ),
            ),
            // SizedBox(height: 10),
            // SizedBox(
            //   width: double.infinity,
            //   child: ElevatedButton.icon(
            //     style: ElevatedButton.styleFrom(backgroundColor: Colors.black38, foregroundColor: Colors.white),
            //     icon: Icon(Icons.code), // generic icon for Github
            //     label: Text("Sign in with GitHub"),
            //     onPressed: _signInWithGitHub,
            //   ),
            // ),
          ],
        ),
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
  
  // final String baseUrl = "https://paarthm007-scdo-api.hf.space";
  final String baseUrl = "http://127.0.0.1:7860";
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
