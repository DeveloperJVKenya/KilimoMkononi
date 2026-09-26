// lib/services/function_auth.dart
//
// Headers for calling our own HTTP Cloud Functions (askGemini /
// askGeminiVision). Those functions reject any request without a valid
// Firebase ID token, so the Gemini quota can't be used by anyone who finds
// the URL. Callable functions (httpsCallable) attach auth automatically and
// don't need this.

import 'package:firebase_auth/firebase_auth.dart';

/// JSON headers plus `Authorization: Bearer <Firebase ID token>` for the
/// signed-in user. Without a signed-in user the header is omitted and the
/// function answers 401.
Future<Map<String, String>> authJsonHeaders() async {
  final token = await FirebaseAuth.instance.currentUser?.getIdToken();
  return {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };
}
