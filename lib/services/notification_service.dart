// lib/services/notification_service.dart
//
// The ONE place notifications are configured. Initialised once in main.dart.
//
//   • Channels — every notification in the app (local reminders, offline
//     sync, and pushes from Cloud Functions) uses one of [KmChannel], so they
//     share the same icon (@drawable/ic_stat_km), colour and behaviour.
//   • Push (Firebase Cloud Messaging):
//       closed / background → the system shows the push using the channel
//                             sent by the Cloud Function (functions/notifications.js)
//       open (foreground)   → FCM doesn't display it, so we show it here with
//                             the same channel and style
//     Tapping a notification opens the screen named in its `route`.
//   • Devices — the signed-in user's FCM token is stored at
//     deviceTokens/{token} {uid}. Signing out deletes the token at FCM, so a
//     shared phone stops receiving the previous user's pushes. If
//     registration fails (e.g. signed in offline) it retries with backoff and
//     as soon as the connection returns.
//   • Topics — farmers are subscribed to `km_farmers` and one topic per crop
//     they grow (from fielddata), used for verified-advice pushes. Browsers
//     can't subscribe themselves, so on web the `syncWebTopics` function does
//     it for the browser's token.
//   • Web — a tapped web push opens `/?km_route=…` (see buildMessage in
//     functions/notifications.js); init() reads that and opens the screen.
//     VAPID key: lib/config/push_config.dart (set once for the project).
//
// Every push is also written by the server to userNotifications/{uid}/items,
// which the Notifications screen shows — so what arrives on the phone and
// what the app lists stay in sync.

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:kilimomkononi/config/push_config.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Notification channels. Ids must match functions/notifications.js.
enum KmChannel {
  weatherAlerts('km_weather_alerts', 'Weather alerts',
      'Severe weather at your farm (heavy rain, strong wind, heat, frost)', Importance.max),
  advisories('km_advisories', 'Verified advice',
      'New advice verified by Field Agronomists', Importance.high),
  reminders('km_reminders', 'Farm reminders',
      'Follow-ups and field activity reminders you set', Importance.high),
  approvals('km_approvals', 'Approvals',
      'Education account approval requests and decisions', Importance.high),
  sync('km_sync', 'Offline sync', 'Records saved offline and synced later', Importance.low),
  general('km_general', 'General', 'Other Kilimo Mkononi notifications',
      Importance.defaultImportance);

  final String id;
  final String label;
  final String description;
  final Importance importance;
  const KmChannel(this.id, this.label, this.description, this.importance);

  static KmChannel fromId(String? id) =>
      KmChannel.values.firstWhere((c) => c.id == id, orElse: () => KmChannel.general);
}

/// Screens a notification can open. Must match `route` values sent by
/// functions/notifications.js.
class KmRoute {
  static const weatherStation = 'weather_station';
  static const notifications = 'notifications';
  static const eduHome = 'edu_home';
}

/// Background/terminated handler. The system already displays notification
/// messages; this only needs to exist (and initialise Firebase lazily) so
/// data-only messages don't crash. Registered in main.dart.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();

  /// Given to MaterialApp so notification taps can navigate.
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Opens a screen for a route. Set by main.dart (keeps this service free of
  /// screen imports). [args] carries the push's extra data, e.g. `gatewayId`
  /// so a station alert opens that station.
  static void Function(String route, Map<String, String> args)? routeHandler;

  static bool _initialized = false;
  static ({String route, Map<String, String> args})? _pendingRoute;
  static StreamSubscription<User?>? _authSub;
  static String? _registeredUid;
  static String? _token;

  // Registration retry (signed in offline, or a transient failure).
  static Timer? _retryTimer;
  static int _retryAttempt = 0;
  static StreamSubscription<List<ConnectivityResult>>? _connSub;

  static const _topicsPrefKey = 'km_subscribed_topics';
  static const _backgroundTipPrefKey = 'km_background_tip_shown';

  static Color get accent => const Color(0xFF2A6B2A);

  // ── Setup ─────────────────────────────────────────────────────────────────

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _initTimezone();

    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_stat_km'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (r) => _handleTap(_routeFromPayload(r.payload)),
    );

    final android =
        plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      for (final c in KmChannel.values) {
        await android.createNotificationChannel(AndroidNotificationChannel(
          c.id,
          c.label,
          description: c.description,
          importance: c.importance,
        ));
      }
    }

    // App launched by tapping a LOCAL notification.
    final launch = await plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      _pendingRoute = _routeFromPayload(launch!.notificationResponse?.payload);
    }

    // Web app opened by tapping a web push (fcmOptions.link → /?km_route=…).
    if (kIsWeb) _pendingRoute ??= _routeFromWebUrl();

    if (await _pushSupported()) await _initPush();
  }

  static Future<void> _initTimezone() async {
    try {
      tz_data.initializeTimeZones();
      final name = (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // Kenya fallback so reminders aren't 3h off if lookup fails.
      try {
        tz.setLocalLocation(tz.getLocation('Africa/Nairobi'));
      } catch (_) {}
    }
  }

  static Future<bool> _pushSupported() async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux)) {
      return false; // FCM has no Windows/Linux support
    }
    try {
      return await FirebaseMessaging.instance.isSupported();
    } catch (_) {
      return false;
    }
  }

  static Future<void> _initPush() async {
    final fm = FirebaseMessaging.instance;

    // iOS: let the system show pushes in the foreground (Android needs us to).
    await fm.setForegroundNotificationPresentationOptions(
        alert: true, badge: true, sound: true);

    FirebaseMessaging.onMessage.listen(_showForegroundPush);
    FirebaseMessaging.onMessageOpenedApp
        .listen((m) => _handleTap(_routeFromData(m.data)));
    final initial = await fm.getInitialMessage(); // app opened from a closed state
    if (initial != null) _pendingRoute = _routeFromData(initial.data);

    fm.onTokenRefresh.listen((t) => _saveToken(t));

    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  /// Asks for notification permission (Android 13+/iOS). Safe to call often.
  static Future<void> requestPermission() async {
    try {
      await plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      if (await _pushSupported()) {
        await FirebaseMessaging.instance.requestPermission();
      }
    } catch (_) {}
  }

  // ── Devices & topics ──────────────────────────────────────────────────────

  static Future<void> _onAuthChanged(User? user) async {
    if (user == null) {
      _stopRetrying();
      if (_registeredUid != null) await _forgetDevice();
      return;
    }
    if (_registeredUid == user.uid) return;
    _registeredUid = user.uid;
    await requestPermission();
    await _register();
  }

  /// Gets this device's token and stores it for the signed-in user. On
  /// failure, retries with backoff (30s → 15 min) and whenever the device
  /// comes back online, until it succeeds or the user signs out.
  static Future<void> _register() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    var ok = false;
    try {
      final token = await FirebaseMessaging.instance.getToken(vapidKey: fcmWebVapidKey);
      if (token != null) ok = await _saveToken(token);
    } catch (e) {
      debugPrint('[NotificationService] no push token yet: $e');
    }
    if (ok) {
      _stopRetrying();
    } else {
      _scheduleRetry();
    }
  }

  static void _scheduleRetry() {
    _retryTimer?.cancel();
    final seconds = (30 * (1 << _retryAttempt.clamp(0, 5))).clamp(30, 900);
    _retryAttempt++;
    _retryTimer = Timer(Duration(seconds: seconds), _register);
    _connSub ??= Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) _register();
    });
  }

  static void _stopRetrying() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryAttempt = 0;
    _connSub?.cancel();
    _connSub = null;
  }

  static Future<bool> _saveToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    _token = token;
    try {
      // One doc per device token: a new sign-in on the same phone simply
      // moves the device to the new user.
      await FirebaseFirestore.instance.collection('deviceTokens').doc(token).set({
        'uid': uid,
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('[NotificationService] token save failed: $e');
      return false;
    }
  }

  static Future<void> _forgetDevice() async {
    _registeredUid = null;
    _token = null;
    try {
      // Invalidates the token (and its topic subscriptions) at FCM. The
      // server drops the orphaned deviceTokens doc on its next send.
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_topicsPrefKey);
    } catch (_) {}
  }

  /// FCM topic for a crop — must match functions/notifications.js cropTopic().
  static String cropTopic(String crop) =>
      'km_crop_${crop.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '')}';

  /// Subscribes a farmer's device to km_farmers + their crop topics (from
  /// fielddata), unsubscribing crops they no longer grow. Call on the farmer
  /// home screen. On web the `syncWebTopics` function subscribes the
  /// browser's token (browsers can't subscribe themselves).
  static Future<void> syncFarmerTopics(String uid) async {
    if (!await _pushSupported()) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('fielddata')
          .where('userId', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();
      final wanted = <String>{'km_farmers'};
      for (final d in snap.docs) {
        for (final c in (d.data()['crops'] as List?) ?? const []) {
          final type = (c is Map ? c['type'] : null)?.toString() ?? '';
          if (type.trim().isNotEmpty) wanted.add(cropTopic(type));
        }
      }
      if (kIsWeb) {
        final token = _token ??
            await FirebaseMessaging.instance.getToken(vapidKey: fcmWebVapidKey);
        if (token == null) return;
        await _saveToken(token); // the function checks this device is yours
        await FirebaseFunctions.instance
            .httpsCallable('syncWebTopics')
            .call({'token': token, 'topics': wanted.toList()});
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final had = (prefs.getStringList(_topicsPrefKey) ?? const []).toSet();
      final fm = FirebaseMessaging.instance;
      for (final t in wanted.difference(had)) {
        await fm.subscribeToTopic(t);
      }
      for (final t in had.difference(wanted)) {
        await fm.unsubscribeFromTopic(t);
      }
      await prefs.setStringList(_topicsPrefKey, wanted.toList());
    } catch (e) {
      debugPrint('[NotificationService] topic sync failed: $e');
    }
  }

  // ── Showing notifications ─────────────────────────────────────────────────

  /// Standard look for every notification on [channel].
  static NotificationDetails details(KmChannel channel, {String? body}) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.label,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: channel.importance == Importance.low
              ? Priority.low
              : channel.importance == Importance.max
                  ? Priority.max
                  : Priority.high,
          icon: '@drawable/ic_stat_km',
          color: accent,
          styleInformation: body == null ? null : BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(
            presentAlert: true, presentBadge: true, presentSound: true),
        web: WebNotificationDetails(iconUrl: Uri.parse('/icons/Icon-192.png')),
      );

  /// Shows a notification now, in the shared style.
  static Future<void> show({
    required int id,
    required String title,
    required String body,
    KmChannel channel = KmChannel.general,
    String? route,
    Map<String, String> args = const {},
  }) async {
    try {
      await plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details(channel, body: body),
        payload: route == null ? null : jsonEncode({'route': route, 'args': args}),
      );
    } catch (e) {
      debugPrint('[NotificationService] show failed: $e');
    }
  }

  static void _showForegroundPush(RemoteMessage m) {
    // iOS already shows it (presentation options above).
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) return;
    final n = m.notification;
    if (n == null) return;
    show(
      id: m.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: n.title ?? 'Kilimo Mkononi',
      body: n.body ?? '',
      channel: KmChannel.fromId(m.data['channel'] as String? ?? n.android?.channelId),
      route: m.data['route'] as String?,
      args: _routeFromData(m.data)?.args ?? const {},
    );
  }

  // ── Taps → screens ────────────────────────────────────────────────────────

  // Keys of a push's data that are routing metadata, not screen arguments.
  static const _metaKeys = {'route', 'channel', 'type'};

  static ({String route, Map<String, String> args})? _routeFromData(
      Map<String, dynamic> data) {
    final route = data['route'] as String?;
    if (route == null) return null;
    return (
      route: route,
      args: {
        for (final e in data.entries)
          if (!_metaKeys.contains(e.key)) e.key: '${e.value}',
      },
    );
  }

  /// `/?km_route=weather_station&gatewayId=…` → that route (web only). The
  /// query is then removed from the address bar so a reload doesn't reopen it.
  static ({String route, Map<String, String> args})? _routeFromWebUrl() {
    final q = Uri.base.queryParameters;
    final route = q['km_route'];
    if (route == null || route.isEmpty) return null;
    SystemNavigator.routeInformationUpdated(uri: Uri(path: '/'), replace: true);
    return (
      route: route,
      args: {
        for (final e in q.entries)
          if (e.key != 'km_route') e.key: e.value,
      },
    );
  }

  static ({String route, Map<String, String> args})? _routeFromPayload(
      String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final m = jsonDecode(payload) as Map;
      final route = m['route'] as String?;
      if (route == null) return null;
      final args = (m['args'] as Map?) ?? const {};
      return (
        route: route,
        args: {for (final e in args.entries) '${e.key}': '${e.value}'},
      );
    } catch (_) {
      return null;
    }
  }

  static void _handleTap(({String route, Map<String, String> args})? tap) {
    if (tap == null) return;
    final handler = routeHandler;
    // Not signed in / app not ready yet → open after the home screen loads.
    if (handler == null ||
        navigatorKey.currentState == null ||
        FirebaseAuth.instance.currentUser == null) {
      _pendingRoute = tap;
      return;
    }
    handler(tap.route, tap.args);
  }

  /// Call once the signed-in home screen is showing; opens the screen of a
  /// notification that launched the app.
  static void consumePendingRoute() {
    final tap = _pendingRoute;
    _pendingRoute = null;
    _handleTap(tap);
  }

  // ── Android background delivery ───────────────────────────────────────────

  /// Once per install on Android: if battery optimisation applies to the app,
  /// explain that some phones (Tecno, Infinix, itel, Xiaomi, Oppo…) block
  /// alerts while it's closed, and offer the app's settings page. FCM itself
  /// needs nothing here — this is about the phone letting it through.
  static Future<void> maybeShowBackgroundTip(BuildContext context) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_backgroundTipPrefKey) ?? false) return;
      if (await Permission.ignoreBatteryOptimizations.isGranted) return;
      await prefs.setBool(_backgroundTipPrefKey, true);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.notifications_active_rounded),
          title: const Text('Get weather alerts when the app is closed'),
          content: const Text(
            'Some phones stop apps in the background to save battery, which '
            'can block weather alerts and farm reminders.\n\n'
            'In the app settings, open Battery and choose "Unrestricted" '
            '(or "No restrictions"), and turn on "Autostart" if you see it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                openAppSettings();
              },
              child: const Text('Open settings'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('[NotificationService] background tip failed: $e');
    }
  }

  @visibleForTesting
  static Future<void> dispose() async {
    _stopRetrying();
    await _authSub?.cancel();
  }
}
