import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WelcomeScreen extends StatefulWidget {
  final String? imagePath;
  const WelcomeScreen({super.key, this.imagePath});

  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String _userNameLocal = '';

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      setState(() {
        _userNameLocal = prefs.getString('user_name') ?? '';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Extract and truncate last name
    String displayFirstName = '';
    if (_userNameLocal.isNotEmpty) {
      final parts = _userNameLocal.split(' ');
      displayFirstName = parts.length > 1 ? parts[1] : parts[0];
      if (displayFirstName.length > 8)
        displayFirstName = displayFirstName.substring(0, 8);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF2E00AC),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3E00C0), Color(0xFF00009C)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              const Text(
                "WELCOME",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              if (displayFirstName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    displayFirstName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              const Text(
                "Digitize your voice, amplify your identity",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                "Let your unique sound live, speak, and connect through the power of AI.",
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              if (widget.imagePath != null &&
                  File(widget.imagePath!).existsSync())
                CircleAvatar(
                  radius: 100,
                  backgroundImage: FileImage(File(widget.imagePath!)),
                )
              else
                Image.asset(
                  'assets/images/mic.png',
                  height: 200,
                ),
              const SizedBox(height: 60),
              const Text(
                "READY TO BEGIN YOUR VOICE JOURNEY?",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                "CLICK THE BUTTON — LET'S GET YOUR VOICE HEARD",
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF00D4FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/home');
                  },
                  child: const Text(
                    "EXPLORE",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
