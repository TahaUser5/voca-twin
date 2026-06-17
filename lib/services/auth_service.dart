import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<User?> signInWithGoogle() async {
    try {
      await _googleSignIn.signOut();

      if (kIsWeb) {
        // Web flow using signInWithPopup
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        UserCredential userCredential =
            await _auth.signInWithPopup(googleProvider);
        return userCredential.user;
      } else if (Platform.isAndroid) {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          throw Exception('Sign-in aborted by user');
        }
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        UserCredential userCredential =
            await _auth.signInWithCredential(credential);
        return userCredential.user;
      } else {
        // iOS / macOS
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          throw Exception('Sign-in aborted by user');
        }
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        UserCredential userCredential =
            await _auth.signInWithCredential(credential);
        return userCredential.user;
      }
    } catch (e) {
      // Re-throw so UI can handle
      rethrow;
    }
  }

  Future<User?> signInWithApple() async {
    try {
      if (Platform.isIOS || Platform.isMacOS) {
        final AuthorizationCredentialAppleID appleCredential =
            await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
        );

        final OAuthProvider oAuthProvider = OAuthProvider("apple.com");
        final AuthCredential credential = oAuthProvider.credential(
          idToken: appleCredential.identityToken,
          accessToken: appleCredential.authorizationCode,
        );

        UserCredential userCredential =
            await _auth.signInWithCredential(credential);
        return userCredential.user;
      } else {
        throw Exception('Apple Sign-In is not supported on this platform.');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<User?> signUp(String email, String password) async {
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      print("Sign-up error: $e");
      return null;
    }
  }

  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      print("Sign-in error: $e");
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    await prefs.remove('user_image_path');
    await prefs.remove('is_logged_in');
  }

  User? get currentUser => _auth.currentUser;

  // New method to always show account picker
  Future<User?> signInWithGoogleAndForcePicker() async {
    await _googleSignIn.signOut();
    return await signInWithGoogle();
  }
}
