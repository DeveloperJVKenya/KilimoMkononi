import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kilimomkononi/enterprise/features/weather/agronomic_advisory_service.dart';
import 'package:kilimomkononi/utils/friendly_error.dart';

void main() {
  test('Firestore / Storage / Functions codes become plain text', () {
    expect(
      friendlyError(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied',
          message: 'Missing or insufficient permissions.')),
      kPermissionMessage,
    );
    expect(
      friendlyError(FirebaseException(plugin: 'cloud_firestore', code: 'unavailable')),
      kOfflineMessage,
    );
    expect(
      friendlyError(FirebaseException(plugin: 'cloud_functions', code: 'unauthenticated')),
      kSessionMessage,
    );
  });

  test('auth codes', () {
    expect(friendlyError(FirebaseAuthException(code: 'wrong-password')),
        'The email or password is incorrect.');
    expect(friendlyError(FirebaseAuthException(code: 'network-request-failed')), kOfflineMessage);
    // Unknown code: Firebase's own (technical) text is not shown.
    expect(
      friendlyError(FirebaseAuthException(code: 'internal-error',
          message: 'An internal error has occurred. [ INTERNAL ]')),
      kGenericMessage,
    );
  });

  test('network, timeout and HTTP failures', () {
    expect(friendlyError(TimeoutException('x')), kSlowMessage);
    expect(friendlyError(http.ClientException('Failed to fetch')), kOfflineMessage);
    expect(friendlyError(Exception('SocketException: Failed host lookup: api.x.com')),
        kOfflineMessage);
    expect(friendlyError(Exception('AI draft failed (HTTP 500)')), kBusyMessage);
    expect(friendlyError(Exception('Request failed with status 401')), kSessionMessage);
  });

  test('technical text never reaches the user', () {
    expect(friendlyError(Exception("type 'Null' is not a subtype of type 'String'")),
        kGenericMessage);
    expect(friendlyError(const FormatException('Unexpected character')),
        'We got a reply we couldn\'t read. Please try again.');
    expect(friendlyError(PlatformException(code: 'photo_access_denied')),
        startsWith('Permission was refused'));
    expect(friendlyError(null), kGenericMessage);
  });

  test('messages written for people pass through', () {
    expect(friendlyError(StateError('This advisory no longer exists.')),
        'This advisory no longer exists.');
    expect(friendlyError(Exception('AI returned an empty draft')),
        'AI returned an empty draft.');
    expect(friendlyError(const AdvisoryConflictException()),
        startsWith('This advice was changed by someone else'));
  });

  test('prefix reads as two sentences', () {
    expect(
      friendlyError(TimeoutException('x'), 'Couldn\'t save'),
      'Couldn\'t save. $kSlowMessage',
    );
  });
}
