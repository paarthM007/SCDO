import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart'; // Ensure you have this file generated

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
  
  // !!! TRY THIS URL - ALL LOWERCASE !!!
  final String baseUrl = "https://paarthm007-scdo-api.hf.space";
  final String apiKey = "scdo-dev-key-change-me";

  String rawJsonResponse = "Output will appear here...";
  bool isLoading = false;

  final TextEditingController _simCities = TextEditingController(text: "Mumbai, Delhi");
  final TextEditingController _simModes = TextEditingController(text: "Road");
  final TextEditingController _altStart = TextEditingController(text: "Mumbai");
  final TextEditingController _altEnd = TextEditingController(text: "London");
  final TextEditingController _altBlocked = TextEditingController(text: "Dubai, Istanbul");

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      
      // If the response is not JSON, we will show the raw HTML/Text
      String bodyString = response.body;
      try {
        var decoded = jsonDecode(bodyString);
        rawJsonResponse = JsonEncoder.withIndent('  ').convert(decoded);
      } catch (e) {
        rawJsonResponse = "CRITICAL: SERVER RETURNED NON-JSON (HTML ERROR)\n\n"
                          "Status: ${response.statusCode}\n"
                          "Body Preview:\n${bodyString.length > 500 ? bodyString.substring(0, 500) + '...' : bodyString}";
      }
      setState(() {});
    } catch (e) {
      setState(() { rawJsonResponse = "Network Error: $e\nCheck if $baseUrl is correct."; });
    } finally {
      setState(() { isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("SCDO v2.0 Debugger"),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [Tab(text: "Simulation"), Tab(text: "Alt Route")],
        ),
      ),
      body: Row(
        children: [
          Container(
            width: 350,
            color: Colors.black26,
            child: TabBarView(
              controller: _tabController,
              children: [
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
                        child: Text("SIMULATE"),
                      ),
                    ],
                  ),
                ),
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
                        child: Text("FIND ALT ROUTE"),
                      ),
                    ],
                  ),
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
                  Text("CONSOLE LOG", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
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
