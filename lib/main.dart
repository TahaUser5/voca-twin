import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart'; // Ensure this file exists
import 'screens/main/home_screen.dart';
import 'screens/main/auth_screen.dart';
import 'services/auth_service.dart';
import 'routes.dart'; // Import the routes file

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase only if it hasn't been initialized already
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    print("Firebase initialization error: $e");
  }

  // Check if the user is already logged in
  final authService = AuthService();
  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
  final hasCurrentUser = authService.currentUser != null;

  // Debug logging
  print('=== AUTO-LOGIN DEBUG ===');
  print('isLoggedIn from SharedPrefs: $isLoggedIn');
  print('hasCurrentUser from Firebase: $hasCurrentUser');
  print('user_name: ${prefs.getString('user_name')}');
  print('user_email: ${prefs.getString('user_email')}');

  // User is considered logged in if either SharedPreferences says so OR Firebase has a current user
  final shouldAutoLogin = isLoggedIn || hasCurrentUser;

  // If Firebase has user but SharedPrefs is missing, restore the data
  if (hasCurrentUser && !isLoggedIn) {
    final user = authService.currentUser!;
    print('=== RESTORING USER DATA FROM FIREBASE ===');
    await prefs.setBool('is_logged_in', true);
    await prefs.setString('user_name', user.displayName ?? 'User');
    await prefs.setString('user_email', user.email ?? '');
    if (user.photoURL != null) {
      await prefs.setString('user_image_path', user.photoURL!);
    }
    print('User data restored from Firebase Auth');
  }

  print('shouldAutoLogin: $shouldAutoLogin');
  print('=======================');

  runApp(VoiceAvatarApp(isLoggedIn: shouldAutoLogin));
}

class VoiceAvatarApp extends StatelessWidget {
  final bool isLoggedIn;

  const VoiceAvatarApp(
      {super.key, required this.isLoggedIn}); // Constructor remains const

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Avatar App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Arial',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F3CFA)),
      ),
      // Auto-login: If user is logged in, go to home, otherwise start from beginning
      initialRoute: isLoggedIn ? '/home' : '/starting',
      routes: appRoutes, // Use the routes defined in routes.dart
    );
  }
}
