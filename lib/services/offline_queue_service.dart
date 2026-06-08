// lib/services/offline_queue_service.dart
//
// Central offline queue for all farmer data writes.
// Handles: field data, pest interventions, disease interventions,
//          reminders, and cost entries.
//
// ── HOW IT WORKS ──────────────────────────────────────────────────────────
//
// WRITE PATH (farmer taps Save):
//   1. Try Firestore directly (fast path, online).
//   2. If Firestore throws (offline/timeout/network error):
//      → Serialise the payload to SharedPreferences queue.
//      → Show "Saved offline — will sync when connected" snackbar.
//      → Schedule a local notification: "Sync pending — open app to sync."
//
// SYNC PATH (triggered automatically):
//   Three triggers run trySync():
//     a. App foreground (AppLifecycleState.resumed)
//     b. connectivity_plus: onConnectivityChanged fires when WiFi/data connects
//     c. User manually taps the sync banner
//
// QUEUE STORAGE FORMAT (SharedPreferences):
//   Key:   'ofq_pending_count'  → int, number of queued items
//   Key:   'ofq_item_$n'        → JSON string per item
//
//   Each item JSON:
//   {
//     "id":          "unique string (userId_timestamp_collection)",
//     "collection":  "fielddata" | "pestinterventiondata" | "diseaseinterventiondata"
//                    | "field_reminders" | "field_costs" | "pest_costs",
//     "docId":       "optional doc ID for .doc(id).set() — null = .add()",
//     "payload":     { ... Firestore map ... },
//     "queuedAt":    "2025-06-01T08:14:00Z",
//     "retries":     0
//   }
//
// ── WHAT THIS DOES NOT HANDLE ─────────────────────────────────────────────
//
// Farm Management screen already has its own offline-first architecture
// (SharedPreferences primary, Firestore is just a backup). It does NOT need
// this queue. Do not route farm_management writes through here.
//
// ── DEPENDENCIES ─────────────────────────────────────────────────────────
//   shared_preferences: ^2.x
//   connectivity_plus: ^6.x   (add to pubspec if not already present)
//   cloud_firestore: ^5.x
//   flutter_local_notifications: ^17.x  (already in project)

import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Queue item model ──────────────────────────────────────────────────────

class OfflineQueueItem {
  final String id;
  final String collection;
  final String? docId;           // null → Firestore .add(); set → .doc(id).set()
  final Map<String, dynamic> payload;
  final DateTime queuedAt;
  final int retries;

  const OfflineQueueItem({
    required this.id,
    required this.collection,
    this.docId,
    required this.payload,
    required this.queuedAt,
    this.retries = 0,
  });

  Map<String, dynamic> toJson() => {
    'id':         id,
    'collection': collection,
    'docId':      docId,
    'payload':    payload,
    'queuedAt':   queuedAt.toIso8601String(),
    'retries':    retries,
  };

  factory OfflineQueueItem.fromJson(Map<String, dynamic> j) =>
      OfflineQueueItem(
        id:         j['id'] as String,
        collection: j['collection'] as String,
        docId:      j['docId'] as String?,
        payload:    Map<String, dynamic>.from(j['payload'] as Map),
        queuedAt:   DateTime.tryParse(j['queuedAt'] as String? ?? '') ??
            DateTime.now(),
        retries:    (j['retries'] as int?) ?? 0,
      );

  OfflineQueueItem withRetry() => OfflineQueueItem(
    id:         id,
    collection: collection,
    docId:      docId,
    payload:    payload,
    queuedAt:   queuedAt,
    retries:    retries + 1,
  );
}

// ── Service ────────────────────────────────────────────────────────────────

class OfflineQueueService {
  OfflineQueueService._();

  static const _countKey = 'ofq_pending_count';
  static const _itemKey  = 'ofq_item_';
  static const _maxRetries = 5;
  static const _notifChannel = 'offline_sync';

  static bool _syncing = false;
  static StreamSubscription? _connectivitySub;
  static FlutterLocalNotificationsPlugin? _notifs;

  // ── Initialise ─────────────────────────────────────────────────────────────
  //
  // Call once from main.dart or App.initState().
  // Sets up connectivity listener so syncing happens automatically when
  // the device reconnects — farmer doesn't have to do anything.

  static Future<void> init({
    FlutterLocalNotificationsPlugin? notificationsPlugin,
  }) async {
    _notifs = notificationsPlugin;

    // Listen for connectivity changes
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi    ||
          r == ConnectivityResult.ethernet);
      if (isOnline) trySync();
    });

    // Attempt sync immediately on init (catches app reopens)
    trySync();
  }

  static void dispose() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Add a Firestore write to the offline queue.
  /// [docId] = null → Firestore .add() (auto-ID)
  /// [docId] = string → Firestore .doc(docId).set(payload)
  static Future<void> enqueue({
    required String id,
    required String collection,
    String? docId,
    required Map<String, dynamic> payload,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_countKey) ?? 0;

    final item = OfflineQueueItem(
      id:         id,
      collection: collection,
      docId:      docId,
      payload:    _sanitiseForJson(payload),
      queuedAt:   DateTime.now(),
    );

    await prefs.setString('$_itemKey$count', jsonEncode(item.toJson()));
    await prefs.setInt(_countKey, count + 1);

    await _notifyPending(count + 1);
  }

  /// Returns the number of items waiting to sync.
  static Future<int> pendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadItems(prefs).length;
  }

  /// Attempt to sync all queued items to Firestore.
  /// Safe to call multiple times — only one sync runs at a time.
  /// Returns the number of items successfully synced.
  static Future<int> trySync() async {
    if (_syncing) return 0;
    _syncing = true;
    int synced = 0;

    try {
      final prefs = await SharedPreferences.getInstance();
      final items = _loadItems(prefs);
      if (items.isEmpty) return 0;

      // Check connectivity first — avoids repeated Firestore timeouts
      final conn = await Connectivity().checkConnectivity();
      final isOnline = conn.any((r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi    ||
          r == ConnectivityResult.ethernet);
      if (!isOnline) return 0;

      final remaining = <OfflineQueueItem>[];

      for (final item in items) {
        if (item.retries >= _maxRetries) continue; // discard after max retries

        bool ok = false;
        try {
          final payload = _restoreTimestamps(item.payload);
          if (item.docId != null) {
            await FirebaseFirestore.instance
                .collection(item.collection)
                .doc(item.docId)
                .set(payload);
          } else {
            await FirebaseFirestore.instance
                .collection(item.collection)
                .add(payload);
          }
          ok = true;
          synced++;
        } catch (_) {
          remaining.add(item.withRetry());
        }

        if (!ok && item.retries < _maxRetries) {
          // Already added in the catch above
        }
      }

      // Rewrite queue with only remaining items
      await _writeItems(prefs, remaining);

      if (synced > 0) {
        await _notifyComplete(synced);
      }
    } finally {
      _syncing = false;
    }

    return synced;
  }

  /// Clear the entire queue — call after sign-out.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await _writeItems(prefs, []);
  }

  // ── SharedPreferences helpers ─────────────────────────────────────────────

  static List<OfflineQueueItem> _loadItems(SharedPreferences prefs) {
    final count = prefs.getInt(_countKey) ?? 0;
    final items = <OfflineQueueItem>[];
    for (var i = 0; i < count; i++) {
      final raw = prefs.getString('$_itemKey$i');
      if (raw == null) continue;
      try {
        items.add(OfflineQueueItem.fromJson(
            jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {}
    }
    return items;
  }

  static Future<void> _writeItems(
      SharedPreferences prefs, List<OfflineQueueItem> items) async {
    // Clear old keys
    final oldCount = prefs.getInt(_countKey) ?? 0;
    for (var i = 0; i < oldCount; i++) {
      await prefs.remove('$_itemKey$i');
    }
    // Write new
    for (var i = 0; i < items.length; i++) {
      await prefs.setString('$_itemKey$i', jsonEncode(items[i].toJson()));
    }
    await prefs.setInt(_countKey, items.length);
  }

  // ── Firestore Timestamp ↔ JSON ─────────────────────────────────────────────
  //
  // Firestore Timestamps are not JSON-serialisable. We convert them to
  // ISO strings when queuing and back to Timestamps when syncing.

  static Map<String, dynamic> _sanitiseForJson(Map<String, dynamic> map) {
    return map.map((k, v) {
      if (v is Timestamp) {
        return MapEntry(k, {'_type': 'Timestamp', 'iso': v.toDate().toIso8601String()});
      }
      if (v is Map<String, dynamic>) {
        return MapEntry(k, _sanitiseForJson(v));
      }
      if (v is List) {
        return MapEntry(k, v.map((e) {
          if (e is Map<String, dynamic>) return _sanitiseForJson(e);
          if (e is Timestamp) return {'_type': 'Timestamp', 'iso': e.toDate().toIso8601String()};
          return e;
        }).toList());
      }
      return MapEntry(k, v);
    });
  }

  static Map<String, dynamic> _restoreTimestamps(Map<String, dynamic> map) {
    return map.map((k, v) {
      if (v is Map<String, dynamic> && v['_type'] == 'Timestamp') {
        final iso = v['iso'] as String?;
        final dt  = iso != null ? DateTime.tryParse(iso) : null;
        return MapEntry(k, dt != null ? Timestamp.fromDate(dt) : Timestamp.now());
      }
      if (v is Map<String, dynamic>) {
        return MapEntry(k, _restoreTimestamps(v));
      }
      if (v is List) {
        return MapEntry(k, v.map((e) {
          if (e is Map<String, dynamic> && e['_type'] == 'Timestamp') {
            final iso = e['iso'] as String?;
            final dt  = iso != null ? DateTime.tryParse(iso) : null;
            return dt != null ? Timestamp.fromDate(dt) : Timestamp.now();
          }
          if (e is Map<String, dynamic>) return _restoreTimestamps(e);
          return e;
        }).toList());
      }
      return MapEntry(k, v);
    });
  }

  // ── Local notifications ────────────────────────────────────────────────────

  static Future<void> _notifyPending(int count) async {
    final n = _notifs;
    if (n == null) return;
    try {
      await n.show(
        id: 9901,
        title: 'Data saved offline',
        body: '$count record${count == 1 ? '' : 's'} will sync automatically when connected.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _notifChannel,
            'Offline sync',
            channelDescription: 'Notifies when records are saved offline',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            ongoing: false,
          ),
        ),
      );
    } catch (_) {}
  }

  static Future<void> _notifyComplete(int count) async {
    final n = _notifs;
    if (n == null) return;
    try {
      await n.cancel(id: 9901);
      await n.show(
        id: 9902,
        title: 'Sync complete ✓',
        body: '$count record${count == 1 ? '' : 's'} synced to your account.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _notifChannel,
            'Offline sync',
            channelDescription: 'Notifies when records are synced',
            importance: Importance.low,
            priority: Priority.low,
          ),
        ),
      );
    } catch (_) {}
  }
}