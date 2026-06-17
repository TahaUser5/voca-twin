import 'package:flutter/material.dart';
import 'signup_screen.dart'; // Import the signup screen
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:voca_twin/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _rememberMe = false; // Add the _rememberMe variable
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool _obscureText = true; // Add state for password visibility
  bool _isLoading = false; // Add loading state

  final AuthService _authService = AuthService();

  Future<void> _login(
      BuildContext context, String email, String password) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_me', _rememberMe);
      await prefs.setBool('is_logged_in', true); // Mark user as logged in
      if (_rememberMe) {
        await prefs.setString('user_email', email);
        await prefs.setString('user_password', password);
      } else {
        await prefs.remove('user_email');
        await prefs.remove('user_password');
      }
      final user = await FirebaseAuth.instance.currentUser;
      if (user != null) {
        await prefs.setString('user_name', user.displayName ?? 'User');
        await prefs.setString('user_email', user.email ?? '');
        if (user.photoURL != null) {
          await prefs.setString('user_image_path', user.photoURL!);
        }
      }
      Navigator.pushReplacementNamed(
          context, '/home'); // Navigate to home screen
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _performSignIn(Future<User?> Function() signInMethod) async {
    setState(() => _isLoading = true);
    try {
      final user = await signInMethod();
      if (user != null) {
        // Save basic profile info for later screens
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', true); // Mark user as logged in
        await prefs.setString('user_name', user.displayName ?? 'User');
        await prefs.setString('user_email', user.email ?? '');
        if (user.photoURL != null) {
          await prefs.setString('user_image_path', user.photoURL!);
        }
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        // User cancelled or authentication returned null
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication cancelled or failed.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 60),
                    const Text(
                      'Login',
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Login to your account',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 25),

                    // Username Field
                    const Text('Username',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: emailController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.person_outline),
                        hintText: 'john@example.com',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Password Field
                    const Text('Password',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: passwordController,
                      obscureText: _obscureText,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureText
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureText = !_obscureText;
                            });
                          },
                        ),
                        hintText: '********',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Remember Me & Forgot Password
                    Row(
                      children: [
                        Checkbox(
                          value: _rememberMe,
                          onChanged: (value) {
                            setState(() {
                              _rememberMe = value!;
                            });
                          },
                          activeColor: Colors.blue[900],
                          checkColor: Colors.white,
                        ),
                        const Text('Remember me'),
                        const Spacer(),
                        TextButton(
                          onPressed: () async {
                            final email = emailController.text.trim();
                            if (email.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Please enter your email to reset password')),
                              );
                              return;
                            }
                            try {
                              await FirebaseAuth.instance
                                  .sendPasswordResetEmail(email: email);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Password reset email sent. Check your inbox.')),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Error: ${e.toString()}')),
                              );
                            }
                          },
                          child: const Text(
                            'Forgot Password ?',
                            style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // Continue Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[900],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          _login(context, emailController.text,
                              passwordController.text);
                        },
                        child: const Text('SIGN IN',
                            style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // OR Divider
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey.shade400)),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('or'),
                        ),
                        Expanded(child: Divider(color: Colors.grey.shade400)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Social Buttons
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSocialButton(
                          "Sign in with Google",
                          'assets/images/google_logo.png',
                          () => _performSignIn(_authService.signInWithGoogle),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // Sign Up Text
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, '/signup');
                        },
                        child: RichText(
                          text: const TextSpan(
                            text: "Don't have an account? ",
                            style: TextStyle(color: Colors.black),
                            children: [
                              TextSpan(
                                text: 'SignUp',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.white.withOpacity(0.5),
              child: Center(
                child: SpinKitFadingCircle(
                  color: Colors.blue[900],
                  size: 50.0,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSocialButton(String text, String asset, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Image.asset(
          asset,
          height: 24,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Error loading image: $asset');
            return const Icon(Icons.broken_image);
          },
        ),
        label: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF201EAA)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}
