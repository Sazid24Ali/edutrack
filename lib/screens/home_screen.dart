import 'package:flutter/material.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // final geminiApiKey = dotenv.env['GEMINI_API_KEY'] ?? "Not Found";
    return Scaffold(
      appBar: AppBar(title: const Text("EduTrack"), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Welcome to EduTrack 🚀"),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
