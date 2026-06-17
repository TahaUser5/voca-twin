import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'screens/main/starting_screen.dart';
import 'screens/main/onboarding_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/verify_email_screen.dart';
import 'screens/main/home_screen.dart';
import 'screens/main/voice_cloning_screen.dart';
import 'screens/main/save_audio_screen.dart';
import 'screens/main/welcome_screen.dart';
import 'screens/microphone/recent_played_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/profile/profile_settings_screen.dart';
import 'screens/main/face_scan_screen.dart';
import 'screens/profile/saved_avatars_screen.dart';
import 'screens/main/chatbot_screen.dart';

Map<String, WidgetBuilder> appRoutes = {
  '/saved_avatars': (context) => const SavedAvatarsScreen(),
  '/starting': (context) => const StartingScreen(),
  '/onboarding': (context) => const OnboardingScreen(),
  '/login': (context) => const LoginScreen(),
  '/signup': (context) => const SignUpScreen(),
  '/verify-email': (context) => const VerifyEmailScreen(),
  '/welcome': (context) => WelcomeScreen(),
  '/home': (context) => HomeScreen(),
  '/voice_cloning': (context) => const VoiceCloningScreen(),
  '/save_audio': (context) => SaveAudioScreen(audioData: {}),
  '/recent_played': (context) => const RecentPlayedScreen(),
  '/edit_profile': (context) => const ProfileSetupScreen(),
  '/profile_settings': (context) => const ProfileSettingsScreen(),
  '/face_scan': (context) => const FaceScanScreen(),
  '/chatbot': (context) => const ChatbotScreen(),
};
