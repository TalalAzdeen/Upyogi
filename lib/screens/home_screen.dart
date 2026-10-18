import '../l10n/app_language.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const LText("Home")),
      body: const Center(
        child: LText(
          "Login successful! 🎉\nHome screen coming next.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
