import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isSignUp = true;

  void _toggleAuthMode() {
    setState(() {
      _isSignUp = !_isSignUp;
    });
  }

  Future<void> _authenticate() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (_isSignUp) {
      await _authService.signUp(email, password);
    } else {
      await _authService.signIn(email, password);
    }

    if (_authService.currentUser != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()), // Removed const keyword
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isSignUp ? 'Sign Up' : 'Sign In')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _authenticate,
              child: Text(_isSignUp ? 'Sign Up' : 'Sign In'),
            ),
            TextButton(
              onPressed: _toggleAuthMode,
              child: Text(_isSignUp ? 'Already have an account? Sign In' : 'Don’t have an account? Sign Up'),
            ),
          ],
        ),
      ),
    );
  }
}
