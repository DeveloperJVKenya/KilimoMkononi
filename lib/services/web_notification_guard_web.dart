// lib/services/web_notification_guard_web.dart
//
// flutter_local_notifications_web sets `navigator.serviceWorker.onmessage`
// to a handler that treats EVERY service-worker message as one of its own
// notification clicks ({id, payload, action, reply}) and reads `id` as a
// non-null String. Firebase Messaging's service worker also posts messages to
// the page (a push received while the tab is open, a push clicked), which
// have no `id` — so each one threw
//   TypeError: null: type 'Null' is not a subtype of type 'String'
//   (JSNotificationData.response, flutter_local_notifications_web)
//
// After the plugin initialises, this replaces that handler with one that only
// handles the plugin's click messages and ignores everything else. Firebase
// Messaging listens with addEventListener('message'), so it is unaffected.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// The plugin's click message → the notification's payload ('' / missing →
/// null); null for any other message (e.g. Firebase Messaging's).
@visibleForTesting
({String? payload})? notificationClickOf(JSAny? data) {
  if (data == null || !data.isA<JSObject>()) return null;
  final o = data as JSObject;
  final id = o.getProperty<JSAny?>('id'.toJS);
  if (id == null || !id.isA<JSString>()) return null;
  final p = o.getProperty<JSAny?>('payload'.toJS);
  final payload = p != null && p.isA<JSString>() ? (p as JSString).toDart : null;
  return (payload: payload == null || payload.isEmpty ? null : payload);
}

void guardWebNotificationClicks(void Function(String? payload) onClick) {
  try {
    if (!web.window.navigator.has('serviceWorker')) return;
    web.window.navigator.serviceWorker.onmessage = ((web.MessageEvent e) {
      final click = notificationClickOf(e.data);
      if (click != null) onClick(click.payload);
    }).toJS;
  } catch (e) {
    debugPrint('[NotificationService] web click guard: $e');
  }
}
