import 'package:flutter/material.dart';
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
