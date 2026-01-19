import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'backoffice_home.dart';
import '../firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? errorMessage;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("Backoffice: Firebase Initialized");

    // Authenticate anonymously to satisfy security rules
    await FirebaseAuth.instance.signInAnonymously();
    print("Backoffice: Signed in anonymously");
  } catch (e) {
    print("Backoffice: Initialization/Auth Error: $e");
    errorMessage = e.toString();
  }

  runApp(BackofficeApp(initError: errorMessage));
}

class BackofficeApp extends StatelessWidget {
  final String? initError;
  const BackofficeApp({super.key, this.initError});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zonber Backoffice',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF00FF88),
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FF88),
          secondary: Colors.blueAccent,
          surface: Color(0xFF2C2C2C),
        ),
        useMaterial3: true,
      ),
      home: initError != null
          ? ErrorScreen(error: initError!)
          : const BackofficeHome(),
    );
  }
}

class ErrorScreen extends StatelessWidget {
  final String error;
  const ErrorScreen({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 24),
              const Text(
                "Firebase Initialization Failed",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                "To run on Web, you must configure Firebase Options.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              SelectableText(
                error,
                style: const TextStyle(color: Colors.redAccent),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              const Text("Run: flutterfire configure"),
            ],
          ),
        ),
      ),
    );
  }
}
