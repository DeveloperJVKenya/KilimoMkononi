// lib/services/reminder_service.dart
//
// The one place activity reminders are scheduled, so Notification Settings
// really controls them.
//
//   • Reminders set in Field Data Input, Pest and Disease Management are
//     stored in field_reminders/{id} (with their `section`, when they're due
//     and when they were set) and scheduled as local notifications on the
//     reminders channel — unless that section is turned off in settings, in
//     which case they're still listed but don't ring.
//   • applyPrefs() re-applies the settings to everything already scheduled:
//     cancels a turned-off section's future reminders, re-schedules them when
//     it's turned back on.
//   • Farm Management tasks (due DATE only, stored on the device) get a
//     reminder on the due date at the time chosen in settings.
//
// Local notifications can't be scheduled in a browser: on web, reminders are
// stored and listed but only ring in the phone app.

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:kilimomkononi/services/notification_prefs.dart';
import 'package:kilimomkononi/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

enum ReminderSection {
  field('Field Data Input'),
  pest('Pest Management'),
  disease('Disease Management'),
  farmTask('Farm Management'),
  other('Activity reminder');

  final String label;
  const ReminderSection(this.label);

  static ReminderSection fromName(String? name) =>
      ReminderSection.values.firstWhere((s) => s.name == name, orElse: () => ReminderSection.other);

  bool enabledIn(NotificationPrefs p) => switch (this) {
        ReminderSection.field => p.fieldReminders,
        ReminderSection.pest => p.pestReminders,
        ReminderSection.disease => p.diseaseReminders,
        ReminderSection.farmTask => p.taskReminders,
        ReminderSection.other => true,
      };
}

/// Stable 31-bit id (FNV-1a) — String.hashCode isn't guaranteed stable.
int stableNotificationId(String key) {
  var h = 0x811c9dc5;
  for (final c in key.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h & 0x7FFFFFFF;
}

/// Section of a stored reminder. Older docs have no `section`; infer it the
/// way the Notifications screen used to (plot → field; title keywords).
ReminderSection sectionOfReminder(Map<String, dynamic> data) {
  final s = data['section'] as String?;
  if (s != null) return ReminderSection.fromName(s);
  final plot = data['plotId'] as String?;
  if (plot != null && plot.isNotEmpty && plot != 'general') return ReminderSection.field;
  final t = ((data['title'] as String?) ?? '').toLowerCase();
  if (t.contains('disease')) return ReminderSection.disease;
  if (t.contains('pest') || t.contains('spray') || t.contains('scout') || t.contains('weed')) {
    return ReminderSection.pest;
  }
  if (t.contains('field') || t.contains('fertili')) return ReminderSection.field;
  if (t.contains('farm')) return ReminderSection.farmTask;
  return ReminderSection.other;
}

/// When a farm task due on [due] should ring, given the chosen time of day.
DateTime taskReminderTime(DateTime due, NotificationPrefs p) =>
    DateTime(due.year, due.month, due.day, p.taskReminderHour, p.taskReminderMinute);

class ReminderService {
  ReminderService._();

  static final _col = FirebaseFirestore.instance.collection('field_reminders');
  static String _taskIdsKey(String uid) => 'km_task_reminder_ids_$uid';

  static bool get canRing => !kIsWeb;

  static Future<void> _ring(int notifId, String title, String body, DateTime at) async {
    if (!canRing || !at.isAfter(DateTime.now())) return;
    await NotificationService.plugin.zonedSchedule(
      id: notifId,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: NotificationService.details(KmChannel.reminders, body: body),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: jsonEncode({'route': KmRoute.notifications}),
    );
  }

  static Future<void> _silence(int notifId) async {
    if (!canRing) return;
    try {
      await NotificationService.plugin.cancel(id: notifId);
    } catch (_) {}
  }

  /// Stores and schedules a reminder. Past dates are ignored. Returns false
  /// when it was stored but not scheduled (section turned off, or web).
  static Future<bool> schedule({
    required String id,
    required ReminderSection section,
    required String title,
    required String body,
    required DateTime date,
    required String userId,
    String? plotId,
  }) async {
    if (!date.isAfter(DateTime.now())) return false;
    final notifId = stableNotificationId(id);
    await _col.doc(id).set({
      'userId': userId,
      'plotId': ?plotId,
      'title': title,
      'body': body,
      'section': section.name,
      'scheduledDate': Timestamp.fromDate(date),
      'createdAt': FieldValue.serverTimestamp(),
      'notifId': notifId,
    });
    final prefs = await NotificationPrefsRepository.cached(userId);
    if (!section.enabledIn(prefs) || !canRing) return false;
    try {
      await _ring(notifId, title, body, date);
      return true;
    } catch (e) {
      debugPrint('[ReminderService] schedule failed: $e');
      return false;
    }
  }

  /// Cancels the phone notification and deletes the stored reminder.
  static Future<void> remove(String docId, int? notifId) async {
    if (notifId != null) await _silence(notifId);
    await _col.doc(docId).delete();
  }

  /// Re-applies [prefs] to everything already scheduled for [uid].
  static Future<void> applyPrefs(String uid, NotificationPrefs prefs) async {
    if (!canRing) return;
    try {
      final snap = await _col.where('userId', isEqualTo: uid).get();
      final now = DateTime.now();
      for (final d in snap.docs) {
        final data = d.data();
        final at = (data['scheduledDate'] as Timestamp?)?.toDate() ??
            (data['scheduleDate'] as Timestamp?)?.toDate();
        final notifId = (data['notifId'] as num?)?.toInt();
        if (at == null || notifId == null || !at.isAfter(now)) continue;
        if (sectionOfReminder(data).enabledIn(prefs)) {
          await _ring(notifId, (data['title'] as String?) ?? 'Reminder', (data['body'] as String?) ?? '', at);
        } else {
          await _silence(notifId);
        }
      }
    } catch (e) {
      debugPrint('[ReminderService] applyPrefs failed: $e');
    }
    await syncFarmTaskReminders(uid, prefs: prefs);
  }

  /// Schedules a reminder for each open Farm Management task on its due date
  /// (at the chosen time), and cancels ones for tasks that are done, deleted,
  /// or when farm task reminders are off. Call after tasks change.
  static Future<void> syncFarmTaskReminders(String uid, {NotificationPrefs? prefs}) async {
    if (!canRing) return;
    try {
      final p = prefs ?? await NotificationPrefsRepository.cached(uid);
      final sp = await SharedPreferences.getInstance();
      final previous = (sp.getStringList(_taskIdsKey(uid)) ?? const []).map(int.parse).toSet();
      final wanted = <int>{};
      final raw = sp.getString('${uid}_v2_tasks');
      if (p.taskReminders && raw != null && raw.isNotEmpty) {
        for (final j in (jsonDecode(raw) as List)) {
          final m = Map<String, dynamic>.from(j as Map);
          final due = DateTime.tryParse('${m['dueDate']}');
          if (due == null || m['isDone'] == true) continue;
          final at = taskReminderTime(due, p);
          if (!at.isAfter(DateTime.now())) continue;
          final notifId = stableNotificationId('task_${m['id']}');
          wanted.add(notifId);
          final title = 'Farm task due: ${m['title'] ?? 'Task'}';
          final desc = '${m['description'] ?? ''}'.trim();
          await _ring(notifId, title, desc.isEmpty ? 'Due today.' : desc, at);
        }
      }
      for (final id in previous.difference(wanted)) {
        await _silence(id);
      }
      await sp.setStringList(_taskIdsKey(uid), wanted.map((e) => '$e').toList());
    } catch (e) {
      debugPrint('[ReminderService] farm task sync failed: $e');
    }
  }
}
