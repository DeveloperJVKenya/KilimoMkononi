// lib/utils/friendly_error.dart
//
// Turns any error into a short message a farmer, teacher or student can act
// on — never a stack trace, exception class or Firebase code. Use it
// wherever an error reaches the screen:
//
//   _snack(friendlyError(e, 'Couldn\'t save'));
//   // → "Couldn't save. Check your internet connection and try again."
//
// The technical error still goes to the debug log for developers.
//
// A message a service wrote for people (e.g. throw StateError('This
// advisory no longer exists.')) is shown as it is; anything that looks
// technical becomes a plain explanation.

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:http/http.dart' as http;

const kOfflineMessage =
    'You seem to be offline. Check your internet connection and try again.';
const kSlowMessage =
    'This is taking too long. Check your internet connection and try again.';
const kGenericMessage = 'Something went wrong. Please try again.';
const kPermissionMessage =
    'You don\'t have permission to do that. If you think you should, '
    'contact support from Settings.';
const kSessionMessage =
    'Your session has expired. Please sign out and sign in again.';
const kBusyMessage =
    'The service is busy right now. Please try again in a few minutes.';

/// A friendly message for [error]. With [what] (e.g. "Couldn't save") the
/// message reads "Couldn't save. (reason)".
String friendlyError(Object? error, [String? what]) {
  if (error != null) debugPrint('[error] ${what ?? ''} $error');
  final reason = friendlyReason(error);
  final prefix = (what ?? '').trim();
  if (prefix.isEmpty) return reason;
  return '${prefix.endsWith('.') ? prefix : '$prefix.'} $reason';
}

/// Just the explanation part of [friendlyError].
String friendlyReason(Object? error) {
  if (error == null) return kGenericMessage;
  if (error is TimeoutException) return kSlowMessage;
  if (error is FirebaseAuthException) {
    return authCodeMessage(error.code) ?? _fromText('$error');
  }
  if (error is FirebaseException) {
    return _firebaseCodeMessage(error.code) ?? _fromText(error.message ?? '');
  }
  if (error is http.ClientException) return kOfflineMessage;
  if (error is PlatformException) {
    final code = error.code.toLowerCase();
    if (code.contains('denied') || code.contains('permission')) {
      return 'Permission was refused. Allow access in your phone\'s settings '
          'and try again.';
    }
    if (code.contains('network')) return kOfflineMessage;
    return _fromText(error.message ?? '');
  }
  if (error is FormatException) {
    return 'We got a reply we couldn\'t read. Please try again.';
  }
  return _fromText('$error');
}

/// Firebase Auth error codes → friendly text (null = not an auth code).
String? authCodeMessage(String code) => switch (code) {
  'user-not-found' => 'No account found with this email.',
  'wrong-password' || 'invalid-credential' || 'INVALID_LOGIN_CREDENTIALS' =>
    'The email or password is incorrect.',
  'invalid-email' => 'That email address is not valid.',
  'user-disabled' =>
    'This account has been disabled. Contact the administrator.',
  'too-many-requests' =>
    'Too many attempts. Please wait a few minutes and try again.',
  'network-request-failed' => kOfflineMessage,
  'email-already-in-use' =>
    'An account already exists for this email. Sign in instead.',
  'weak-password' => 'That password is too weak — use at least 8 characters.',
  'requires-recent-login' =>
    'For your security, sign out and sign in again, then try once more.',
  'account-exists-with-different-credential' =>
    'This email is already registered with another sign-in method. '
        'Sign in the way you did before.',
  'credential-already-in-use' =>
    'That account is already linked to another user.',
  'popup-closed-by-user' || 'cancelled-popup-request' || 'web-context-canceled' =>
    'Sign-in was cancelled.',
  'popup-blocked' =>
    'Your browser blocked the sign-in window. Allow pop-ups and try again.',
  'expired-action-code' => 'This link has expired. Ask for a new one.',
  'invalid-action-code' =>
    'This link is no longer valid. Ask for a new one.',
  'operation-not-allowed' => 'This sign-in method isn\'t available right now.',
  'user-token-expired' || 'invalid-user-token' => kSessionMessage,
  'missing-email' => 'Enter your email address.',
  'missing-password' => 'Enter your password.',
  _ => null,
};

/// Firestore / Storage / Cloud Functions codes → friendly text.
String? _firebaseCodeMessage(String code) => switch (code) {
  'permission-denied' || 'unauthorized' => kPermissionMessage,
  'unauthenticated' => kSessionMessage,
  'unavailable' || 'network-request-failed' => kOfflineMessage,
  'deadline-exceeded' || 'retry-limit-exceeded' => kSlowMessage,
  'not-found' || 'object-not-found' =>
    'We couldn\'t find that — it may have been removed.',
  'already-exists' => 'That already exists.',
  'resource-exhausted' || 'quota-exceeded' => kBusyMessage,
  'cancelled' || 'canceled' || 'aborted' =>
    'That was interrupted. Please try again.',
  'invalid-argument' || 'failed-precondition' || 'out-of-range' =>
    'Some of the details aren\'t accepted. Check them and try again.',
  'internal' || 'unknown' || 'data-loss' || 'unimplemented' =>
    kGenericMessage,
  _ => null,
};

final _technical = RegExp(
  r'exception|error:|bad state|null|instance of|type .* is not|dart:|'
  r'package:|http|status|code|stack|socket|firebase|firestore|json|'
  r'[{}\[\]<>_=#]',
  caseSensitive: false,
);

String _fromText(String raw) {
  var text = raw.trim();
  for (final p in const ['Exception: ', 'Bad state: ', 'Error: ']) {
    if (text.startsWith(p)) text = text.substring(p.length).trim();
  }
  final lower = text.toLowerCase();
  if (_isNetwork(lower)) return kOfflineMessage;
  if (lower.contains('timeout') || lower.contains('timed out')) {
    return kSlowMessage;
  }
  final status = RegExp(r'\b(?:http|status)\D{0,3}(\d{3})\b')
      .firstMatch(lower)
      ?.group(1);
  if (status != null) {
    final s = int.parse(status);
    if (s == 401) return kSessionMessage;
    if (s == 403) return kPermissionMessage;
    if (s == 404) return 'We couldn\'t find that — it may have been removed.';
    if (s == 429 || s >= 500) return kBusyMessage;
    return kGenericMessage;
  }
  if (lower.contains('permission-denied') || lower.contains('permission denied')) {
    return kPermissionMessage;
  }
  // A message written for people: short, a sentence, nothing technical.
  if (text.isNotEmpty &&
      text.length <= 180 &&
      RegExp(r'^[A-Z]').hasMatch(text) &&
      !_technical.hasMatch(text)) {
    return RegExp(r'[.!?]$').hasMatch(text) ? text : '$text.';
  }
  return kGenericMessage;
}

bool _isNetwork(String lower) => const [
  'socketexception',
  'clientexception',
  'failed host lookup',
  'network is unreachable',
  'connection refused',
  'connection reset',
  'connection closed',
  'connection failed',
  'xmlhttprequest error',
  'failed to fetch',
  'no internet',
  'network-request-failed',
  'network error',
].any(lower.contains);
