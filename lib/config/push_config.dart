// lib/config/push_config.dart
//
// Web Push (VAPID) key for Firebase Cloud Messaging on the web build.
//
// This is a PUBLIC key — it's sent to every browser anyway, like the Firebase
// web config in firebase_options.dart — so it belongs in the code, set once
// for the whole project. Every build and every user then uses it; nobody has
// to create or pass a key per run.
//
// Where it comes from (one time): Firebase Console → Project settings →
// Cloud Messaging → Web configuration → Web Push certificates → copy the
// "Key pair" value into [_projectVapidKey] below.
//
// While it's empty, the Firebase JS SDK uses its built-in default VAPID key,
// which FCM also accepts — web push still works. Setting the project's own
// key is recommended so tokens are tied to this project's certificate.
//
// A build can still override it:  --dart-define=FCM_VAPID_KEY=<key>

const String _projectVapidKey = '';

/// The VAPID key passed to `FirebaseMessaging.getToken` on web, or null to
/// use the SDK default.
String? get fcmWebVapidKey {
  const override = String.fromEnvironment('FCM_VAPID_KEY');
  final key = override.isNotEmpty ? override : _projectVapidKey;
  return key.isEmpty ? null : key;
}
