import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StartingScreen extends StatefulWidget {
  const StartingScreen({super.key});

  @override
  _StartingScreenState createState() => _StartingScreenState();
}

class _StartingScreenState extends State<StartingScreen>
    with SingleTickerProviderStateMixin {
  int _currentDot = 0;
  late Timer _timer;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _startDotAnimation();

    // Initialize the animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..forward();

    // Define the scale animation
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // Navigate after splash based on remember me flag
    _navigateAfterDelay();
  }

  void _startDotAnimation() {
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      setState(() {
        _currentDot = (_currentDot + 1) % 3; // Loops through 0, 1, 2
      });
    });
  }

  Future<void> _navigateAfterDelay() async {
    await Future.delayed(const Duration(seconds: 2));
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    final remember = prefs.getBool('remember_me') ?? false;

    // Check if user is already logged in (auto-login)
    if (isLoggedIn || FirebaseAuth.instance.currentUser != null) {
      Navigator.pushReplacementNamed(context, '/home');
      return;
    }

    // Check remember me for stored credentials
    if (remember) {
      final email = prefs.getString('user_email');
      final password = prefs.getString('user_password');
      if (email != null && password != null) {
        try {
          await FirebaseAuth.instance
              .signInWithEmailAndPassword(email: email, password: password);
          await prefs.setBool('is_logged_in', true); // Mark as logged in
          Navigator.pushReplacementNamed(context, '/home');
          return;
        } catch (_) {
          // Clear invalid remember state
          await prefs.setBool('remember_me', false);
          await prefs.remove('user_email');
          await prefs.remove('user_password');
        }
      }
    }
    // Fallback to onboarding
    Navigator.pushReplacementNamed(context, '/onboarding');
  }

  @override
  void dispose() {
    _timer.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFDDE9FF)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Center(
              child: Column(
                children: [
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 120,
                      height: 120,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentDot == index ? 12 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentDot == index
                          ? Colors.blueAccent
                          : Colors.grey,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
