import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:scdo_app/theme/glass_theme.dart';
import 'package:scdo_app/screens/app_scaffold.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const SCDOTesterApp());
}

class SCDOTesterApp extends StatelessWidget {
  const SCDOTesterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SCDO Dashboard',
      theme: GlassTheme.darkTheme,
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return const AppScaffold();
        }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("SCDO Login")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_error.isNotEmpty) Text(_error, style: TextStyle(color: Colors.red)),
            TextField(controller: _email, decoration: InputDecoration(labelText: "Email")),
            TextField(controller: _password, decoration: InputDecoration(labelText: "Password"), obscureText: true),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(onPressed: _signIn, child: Text("Sign In")),
                ElevatedButton(onPressed: _signUp, child: Text("Sign Up")),
              ],
            )
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
  
  final String baseUrl = "http://localhost:7860";
  final String apiKey = "scdo-dev-key-change-me";

  String rawJsonResponse = "Output will appear here...";
  List<dynamic> history = [];
  bool isLoading = false;

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

  Future<void> _callApi(String endpoint, Map<String, dynamic> body) async {
    setState(() { isLoading = true; rawJsonResponse = "Calling $baseUrl$endpoint..."; });
    try {
      String? token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.post(
        Uri.parse("$baseUrl$endpoint"),
        headers: {
          "Authorization": "Bearer $token",
          "X-API-Key": apiKey,
          "Content-Type": "application/json"
        },
        body: jsonEncode(body),
      );
      
      String bodyString = response.body;
      try {
        var decoded = jsonDecode(bodyString);
        rawJsonResponse = JsonEncoder.withIndent('  ').convert(decoded);
        // If we just triggered a simulation or alt route, refresh history shortly after
        if (endpoint.contains("simulate") || endpoint.contains("alternate")) {
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

  Future<void> _fetchHistory() async {
    setState(() { isLoading = true; });
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
                // TAB 2: Alt Route
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(controller: _altStart, decoration: InputDecoration(labelText: "Start")),
                      TextField(controller: _altEnd, decoration: InputDecoration(labelText: "End")),
                      TextField(controller: _altBlocked, decoration: InputDecoration(labelText: "Blocked")),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => _callApi("/api/alternate-route", {
                          "start": _altStart.text.trim(),
                          "end": _altEnd.text.trim(),
                          "blocked": _altBlocked.text.split(',').map((e) => e.trim()).toList()
                        }),
                        child: Text("FIND ALT + SIMULATE"),
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
