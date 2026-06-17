import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../../services/auth_service.dart';
import '../profile/edit_profile_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  Future<void> _signUp(
      BuildContext context, String email, String password) async {
    try {
      // Create user and send verification email
      final userCred =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await userCred.user!.sendEmailVerification();
      // Navigate to email verification screen
      Navigator.pushReplacementNamed(context, '/verify-email');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _performSocialSignIn(
      Future<User?> Function() signInMethod) async {
    setState(() => _isLoading = true);
    try {
      final user = await signInMethod();
      if (user != null) {
        // Check if this email is already registered (user has logged in before)
        final prefs = await SharedPreferences.getInstance();
        final isLoggedInBefore = prefs.getBool('is_logged_in') ?? false;
        final savedEmail = prefs.getString('user_email') ?? '';

        if (isLoggedInBefore && savedEmail == user.email) {
          // User is already registered, show error message
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  'This email is already registered. Please use login instead.'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
          return; // Stop the signup process
        }

        // Save user info from Google/Apple to SharedPreferences (first time signup)
        await prefs.setString('user_name', user.displayName ?? 'User');
        await prefs.setString('user_email', user.email ?? '');
        if (user.photoURL != null) {
          await prefs.setString('user_image_path', user.photoURL!);
        }
        await prefs.setBool('is_logged_in', true);

        if (!mounted) return;
        // First time signup, go to profile setup
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileSetupScreen(
              email: user.email,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                      'Create Account',
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Register to get started',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 25),

                    // Username Field
                    const Text('Username',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'john',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Email Field
                    const Text('Email',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: emailController,
                      decoration: InputDecoration(
                        hintText: 'johnmiles@example.com',
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
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: '********',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
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
                          _signUp(context, emailController.text,
                              passwordController.text);
                        },
                        child: const Text('SIGN UP',
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

                    // Sign Up with Google Button (Matching LoginScreen)
                    _buildSocialButton(
                      "Sign Up with Google",
                      'assets/images/google_logo.png',
                      () => _performSocialSignIn(_authService.signInWithGoogle),
                    ),
                    const SizedBox(height: 10),

                    // Already have an account? Login
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(
                              context); // Navigate back to the login screen
                        },
                        child: RichText(
                          text: const TextSpan(
                            text: "Already have an account? ",
                            style: TextStyle(color: Colors.black),
                            children: [
                              TextSpan(
                                text: 'Login',
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

  // Reusable method for social buttons (updated to receive onPressed)
  Widget _buildSocialButton(String text, String asset, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Image.asset(
          asset,
          height: 24,
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
