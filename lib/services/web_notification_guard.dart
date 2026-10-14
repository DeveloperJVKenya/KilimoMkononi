// lib/services/web_notification_guard.dart
//
// Web: keeps notification clicks working without crashing on Firebase
// Messaging's own service-worker messages. See web_notification_guard_web.dart.
// Other platforms: nothing to do.

export 'web_notification_guard_stub.dart'
    if (dart.library.js_interop) 'web_notification_guard_web.dart';
