// lib/services/notification_prefs.dart
//
// A user's notification preferences — what the Notification Settings screen
// edits, and what actually decides what reaches them:
//
//   push, weatherAlerts, advisories, approvals
//       → read by the Cloud Functions before pushing to the user's devices
//         (functions/notifications.js → deliverToUsers). Turning one off stops
//         the push; the in-app Inbox still keeps a dated record of it.
//         Advice sent to crop topics is also controlled on the device: the
//         app unsubscribes from those topics (NotificationService).
//   fieldReminders, pestReminders, diseaseReminders, taskReminders,
//   taskReminderHour/Minute
//       → applied on each device by ReminderService: scheduled reminders for
//         a section are cancelled when it's turned off and re-scheduled when
//         it's turned back on. Farm tasks (which have a due DATE only) are
//         reminded on the due date at taskReminderHour:taskReminderMinute.
//
// Stored at notificationPrefs/{uid} (firestore.rules validates the fields) so
// they follow the user across devices, and cached in SharedPreferences so
// they work offline.

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class NotificationPrefs {
  final bool push;
  final bool weatherAlerts;
  final bool advisories;
  final bool approvals;
  final bool fieldReminders;
  final bool pestReminders;
  final bool diseaseReminders;
  final bool taskReminders;
  final int taskReminderHour;
  final int taskReminderMinute;

  const NotificationPrefs({
    this.push = true,
    this.weatherAlerts = true,
    this.advisories = true,
    this.approvals = true,
    this.fieldReminders = true,
    this.pestReminders = true,
    this.diseaseReminders = true,
    this.taskReminders = true,
    this.taskReminderHour = 7,
    this.taskReminderMinute = 0,
  });

  static const defaults = NotificationPrefs();

  NotificationPrefs copyWith({
    bool? push,
    bool? weatherAlerts,
    bool? advisories,
    bool? approvals,
    bool? fieldReminders,
    bool? pestReminders,
    bool? diseaseReminders,
    bool? taskReminders,
    int? taskReminderHour,
    int? taskReminderMinute,
  }) =>
      NotificationPrefs(
        push: push ?? this.push,
        weatherAlerts: weatherAlerts ?? this.weatherAlerts,
        advisories: advisories ?? this.advisories,
        approvals: approvals ?? this.approvals,
        fieldReminders: fieldReminders ?? this.fieldReminders,
        pestReminders: pestReminders ?? this.pestReminders,
        diseaseReminders: diseaseReminders ?? this.diseaseReminders,
        taskReminders: taskReminders ?? this.taskReminders,
        taskReminderHour: taskReminderHour ?? this.taskReminderHour,
        taskReminderMinute: taskReminderMinute ?? this.taskReminderMinute,
      );

  /// Push for the advice crop topics is wanted only if both are on.
  bool get wantsAdvicePushes => push && advisories;

  Map<String, dynamic> toMap() => {
        'push': push,
        'weatherAlerts': weatherAlerts,
        'advisories': advisories,
        'approvals': approvals,
        'fieldReminders': fieldReminders,
        'pestReminders': pestReminders,
        'diseaseReminders': diseaseReminders,
        'taskReminders': taskReminders,
        'taskReminderHour': taskReminderHour,
        'taskReminderMinute': taskReminderMinute,
      };

  factory NotificationPrefs.fromMap(Map<String, dynamic>? m) {
    if (m == null) return defaults;
    bool b(String k) => m[k] is bool ? m[k] as bool : true;
    int i(String k, int d, int max) {
      final v = m[k];
      return v is num && v >= 0 && v <= max ? v.toInt() : d;
    }

    return NotificationPrefs(
      push: b('push'),
      weatherAlerts: b('weatherAlerts'),
      advisories: b('advisories'),
      approvals: b('approvals'),
      fieldReminders: b('fieldReminders'),
      pestReminders: b('pestReminders'),
      diseaseReminders: b('diseaseReminders'),
      taskReminders: b('taskReminders'),
      taskReminderHour: i('taskReminderHour', 7, 23),
      taskReminderMinute: i('taskReminderMinute', 0, 59),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationPrefs && mapEquals(other.toMap(), toMap());

  @override
  int get hashCode => Object.hashAll(toMap().values);
}

/// Loads and saves [NotificationPrefs] (Firestore + device cache).
class NotificationPrefsRepository {
  NotificationPrefsRepository._();

  static String _cacheKey(String uid) => 'km_notification_prefs_$uid';

  static DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      FirebaseFirestore.instance.collection('notificationPrefs').doc(uid);

  /// The device cache (instant, offline). Defaults if never saved.
  static Future<NotificationPrefs> cached(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey(uid));
      if (raw != null) {
        return NotificationPrefs.fromMap(
            Map<String, dynamic>.from(jsonDecode(raw) as Map));
      }
    } catch (_) {}
    return NotificationPrefs.defaults;
  }

  static Future<void> _cache(String uid, NotificationPrefs p) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey(uid), jsonEncode(p.toMap()));
    } catch (_) {}
  }

  /// Firestore first (so changes made on another device apply here), then
  /// the device cache when offline.
  static Future<NotificationPrefs> load(String uid) async {
    try {
      final snap = await _doc(uid).get();
      final p = NotificationPrefs.fromMap(snap.data());
      await _cache(uid, p);
      return p;
    } catch (_) {
      return cached(uid);
    }
  }

  /// Saves on the device immediately and to Firestore. Offline, Firestore
  /// queues the write and only completes it on reconnect — so don't wait
  /// more than a few seconds; the device copy already applies.
  static Future<void> save(String uid, NotificationPrefs p) async {
    await _cache(uid, p);
    await _doc(uid)
        .set({...p.toMap(), 'updatedAt': FieldValue.serverTimestamp()})
        .timeout(const Duration(seconds: 8), onTimeout: () {});
  }
}
