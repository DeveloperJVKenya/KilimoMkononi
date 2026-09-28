// lib/services/google_auth_service.dart
//
// Shared Google Sign-In helper for both the Farmer (Enterprise) and
// Education apps. Both apps share the same Firebase project, so this
// just handles the Google OAuth + Firebase Auth handshake — the caller
// is responsible for checking/creating the right Firestore document
// (Users vs EducationUsers) afterwards.
//
//   Web      Firebase's own popup (signInWithPopup). The page's domain must
//            be in Firebase Auth → Settings → Authorized domains (localhost,
//            kilimomkononi-e1031.web.app and .firebaseapp.com are).
//   Android  google_sign_in v7 (Credential Manager) → ID token → Firebase.
//            Needs the app's signing SHA-1/SHA-256 registered on the
//            Android app in Firebase (debug + release keys are), and the
//            project's WEB client ID as serverClientId (below).
//
// Errors come back as [GoogleAuthCancelledException] (user closed the
// picker — show nothing) or [GoogleAuthException] with a message that can
// be shown to the user as-is.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthResult {
  final UserCredential credential;
  final bool isNewFirebaseUser; // brand new to Firebase Auth entirely
  GoogleAuthResult({required this.credential, required this.isNewFirebaseUser});

  String get uid => credential.user!.uid;
  String get email => credential.user?.email ?? '';
  String get displayName => credential.user?.displayName ?? '';
}

/// The user closed the account picker / popup.
class GoogleAuthCancelledException implements Exception {}

/// A Google sign-in failure with a user-facing [message].
class GoogleAuthException implements Exception {
  final String message;
  final String? code;
  const GoogleAuthException(this.message, {this.code});
  @override
  String toString() => message;
}

class GoogleAuthService {
  GoogleAuthService._();

  /// The project's OAuth WEB client (Firebase Console → Authentication →
  /// Sign-in method → Google → Web SDK configuration). Public identifier,
  /// not a secret. Android uses it as serverClientId to get an ID token.
  static const String webClientId =
      '865770087354-gsoarh994chr3os4vvvb8p0enqg8dvvf.apps.googleusercontent.com';

  // Only needed to override the iOS client instead of GoogleService-Info.plist.
  static const String? iosClientId = null;

  static bool _initialized = false;

  static Future<void> _ensureInitialized() async {
    if (_initialized || kIsWeb) return;
    await GoogleSignIn.instance.initialize(
      clientId: iosClientId,
      serverClientId: webClientId,
    );
    _initialized = true;
  }

  /// Runs the Google flow and signs the result into Firebase Auth.
  static Future<GoogleAuthResult> signIn() async {
    try {
      final UserCredential credential;
      if (kIsWeb) {
        final provider = GoogleAuthProvider()
          ..addScope('email')
          ..addScope('profile')
          // Always show the account chooser, so a shared computer doesn't
          // silently reuse the last Google account.
          ..setCustomParameters({'prompt': 'select_account'});
        credential = await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        await _ensureInitialized();
        final googleUser = await GoogleSignIn.instance.authenticate();
        final idToken = googleUser.authentication.idToken;
        if (idToken == null) {
          throw const GoogleAuthException(
              'Google didn\'t return a sign-in token. Please try again.', code: 'no-id-token');
        }
        credential = await FirebaseAuth.instance
            .signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
      }
      return GoogleAuthResult(
        credential: credential,
        isNewFirebaseUser: credential.additionalUserInfo?.isNewUser ?? false,
      );
    } on GoogleSignInException catch (e) {
      debugPrint('[GoogleAuth] ${e.code}: ${e.description}');
      switch (e.code) {
        case GoogleSignInExceptionCode.canceled:
        case GoogleSignInExceptionCode.interrupted:
          throw GoogleAuthCancelledException();
        case GoogleSignInExceptionCode.clientConfigurationError:
        case GoogleSignInExceptionCode.providerConfigurationError:
          throw GoogleAuthException(
              'Google sign-in isn\'t set up for this build of the app yet. '
              'Please sign in with email and password for now.',
              code: e.code.name);
        case GoogleSignInExceptionCode.uiUnavailable:
          throw GoogleAuthException('Google sign-in couldn\'t open on this device. Please try again.',
              code: e.code.name);
        default:
          throw GoogleAuthException('Google sign-in failed. Please try again.', code: e.code.name);
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('[GoogleAuth] firebase ${e.code}: ${e.message}');
      switch (e.code) {
        case 'popup-closed-by-user':
        case 'cancelled-popup-request':
        case 'user-cancelled':
          throw GoogleAuthCancelledException();
        case 'popup-blocked':
          throw GoogleAuthException(
              'Your browser blocked the Google sign-in window. Allow pop-ups for this site and try again.',
              code: e.code);
        case 'unauthorized-domain':
          throw GoogleAuthException(
              'Google sign-in isn\'t allowed on this web address. Use the official Kilimo Mkononi site.',
              code: e.code);
        case 'network-request-failed':
          throw GoogleAuthException('No internet connection. Check your connection and try again.',
              code: e.code);
        case 'user-disabled':
          throw GoogleAuthException('This account has been disabled. Contact the administrator.', code: e.code);
        case 'account-exists-with-different-credential':
          throw GoogleAuthException(
              'An account already uses this email with a different sign-in method. '
              'Sign in with your email and password instead.',
              code: e.code);
        default:
          throw GoogleAuthException('Google sign-in failed: ${e.message ?? e.code}', code: e.code);
      }
    }
  }

  /// Signs out of Firebase AND the Google account on this device, so the
  /// next "Continue with Google" shows the account chooser again.
  static Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    if (kIsWeb) return;
    try {
      await _ensureInitialized();
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('[GoogleAuth] Google sign-out: $e');
    }
  }
}
