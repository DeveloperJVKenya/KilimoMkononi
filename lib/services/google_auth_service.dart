// lib/services/google_auth_service.dart
//
// Shared Google Sign-In helper for both the Farmer (Enterprise) and
// Education apps. Both apps share the same Firebase project, so this
// just handles the Google OAuth + Firebase Auth handshake — the caller
// is responsible for checking/creating the right Firestore document
// (Users vs EducationUsers) afterwards.
//
// Requires: google_sign_in ^7.0.0 (this package had a breaking rewrite
// in v7 — singleton instance, explicit initialize(), authenticate()
// instead of signIn(), synchronous .authentication, cancellation is
// now a thrown GoogleSignInException instead of a null return).

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class GoogleAuthResult {
  final UserCredential credential;
  final bool isNewFirebaseUser; // brand new to Firebase Auth entirely
  GoogleAuthResult({required this.credential, required this.isNewFirebaseUser});

  String get uid => credential.user!.uid;
  String get email => credential.user?.email ?? '';
  String get displayName => credential.user?.displayName ?? '';
}

class GoogleAuthCancelledException implements Exception {}

class GoogleAuthService {
  // On Web, pass your OAuth Web Client ID here (from Firebase Console →
  // Authentication → Sign-in method → Google → Web SDK configuration).
  static const String? webClientId = null; // e.g. '1234567890-abc.apps.googleusercontent.com'

  // Optional: only needed if you want to override the iOS client ID
  // instead of relying on GoogleService-Info.plist. Leave null normally.
  static const String? iosClientId = null;

  static bool _initialized = false;

  /// v7 requires an explicit initialize() call before authenticate().
  /// Safe to call this multiple times — it's a no-op after the first
  /// successful call. For a snappier first sign-in, you can also call
  /// this once in main() at app startup instead of lazily here.
  static Future<void> _ensureInitialized() async {
    if (_initialized || kIsWeb) return;
    await GoogleSignIn.instance.initialize(
      clientId: iosClientId,
    );
    _initialized = true;
  }

  /// Runs the Google OAuth flow and signs the result into Firebase Auth.
  /// Throws [GoogleAuthCancelledException] if the user closes the picker.
  static Future<GoogleAuthResult> signIn() async {
    UserCredential credential;

    if (kIsWeb) {
      // Web: use Firebase's own popup flow — much simpler than wiring
      // up google_sign_in_web's renderButton()/event-stream API, and
      // avoids the v7 platform differences entirely.
      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile');
      credential = await FirebaseAuth.instance.signInWithPopup(provider);
    } else {
      await _ensureInitialized();
      try {
        final googleUser = await GoogleSignIn.instance.authenticate();
        final idToken = googleUser.authentication.idToken;
        final oauthCredential = GoogleAuthProvider.credential(idToken: idToken);
        credential = await FirebaseAuth.instance.signInWithCredential(oauthCredential);
      } on GoogleSignInException catch (e) {
        if (e.code == GoogleSignInExceptionCode.canceled) {
          throw GoogleAuthCancelledException();
        }
        rethrow;
      }
    }

    return GoogleAuthResult(
      credential: credential,
      isNewFirebaseUser: credential.additionalUserInfo?.isNewUser ?? false,
    );
  }

  static Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!kIsWeb) {
      await _ensureInitialized();
      await GoogleSignIn.instance.signOut();
    }
  }
}