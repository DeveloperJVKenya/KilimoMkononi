// Web only: the notification click guard handles the local-notifications
// plugin's click messages and ignores Firebase Messaging's service-worker
// messages (which used to crash the plugin's handler).
//   flutter test --platform chrome test/web_notification_guard_test.dart
@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:flutter_test/flutter_test.dart';
import 'package:kilimomkononi/services/web_notification_guard_web.dart';

void main() {
  test("the plugin's click message → its payload", () {
    final click = notificationClickOf(
      {'id': '42', 'payload': '{"route":"advisory"}', 'action': '', 'reply': ''}.jsify(),
    );
    expect(click, isNotNull);
    expect(click!.payload, '{"route":"advisory"}');
    expect(notificationClickOf({'id': '7', 'payload': ''}.jsify())!.payload, isNull);
  });

  test("Firebase Messaging's messages and junk are ignored, not thrown on", () {
    // What firebase-messaging's service worker posts to open pages.
    expect(
      notificationClickOf({
        'firebaseMessaging': {
          'type': 'push-received',
          'payload': {'notification': {'title': 'Heavy rain'}},
        },
      }.jsify()),
      isNull,
    );
    expect(notificationClickOf({'messageType': 'notification-clicked', 'data': {}}.jsify()), isNull);
    expect(notificationClickOf({'id': 5}.jsify()), isNull); // id not a string
    expect(notificationClickOf('hello'.toJS), isNull);
    expect(notificationClickOf(null), isNull);
  });
}
