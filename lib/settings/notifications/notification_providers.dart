// lib/settings/notifications/notification_providers.dart
//
// Riverpod state for the Notifications screen and Notification Settings.
//
//   inboxProvider              — live userNotifications/{uid}/items (pushes
//                                the server sent, with exact times)
//   inboxFilterProvider        — All / Unread / Weather / Advice / Approvals
//   filteredInboxProvider, unreadCountProvider
//   inboxControllerProvider    — mark read / all read, delete
//   remindersProvider          — live field_reminders for the user
//   reminderFilterProvider     — by section
//   farmTasksProvider          — Farm Management tasks (device storage)
//   farmAlertsProvider         — live farm condition alerts (refreshable)
//   notificationPrefsProvider  — Notification Settings; saving applies them
//                                (server push filter, reminders, topics)

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kilimomkononi/services/notification_prefs.dart';
import 'package:kilimomkononi/services/notification_service.dart';
import 'package:kilimomkononi/services/reminder_service.dart';
import 'package:kilimomkononi/settings/notifications/farm_alerts.dart';
import 'package:kilimomkononi/settings/notifications/notification_style.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Live sign-in state, so the inbox, badge and settings switch with the
/// account (a shared browser can sign out and in without restarting).
final _authUserProvider = StreamProvider<User?>((ref) => FirebaseAuth.instance.authStateChanges());

final notifUidProvider = Provider<String?>(
    (ref) => ref.watch(_authUserProvider).value?.uid ?? FirebaseAuth.instance.currentUser?.uid);

DateTime? _ts(dynamic v) => v is Timestamp ? v.toDate() : null;

// ═════════════════════════════════════════════════════════════════════════════
//  Inbox
// ═════════════════════════════════════════════════════════════════════════════

enum InboxKind {
  weather('Weather alert', Icons.thunderstorm_rounded, KmColors.orange),
  advice('Verified advice', Icons.verified_rounded, KmColors.green),
  approval('Approvals', Icons.how_to_reg_rounded, KmColors.blue),
  reminder('Reminder', Icons.alarm_rounded, KmColors.purple),
  general('General', Icons.notifications_rounded, KmColors.teal);

  final String label;
  final IconData icon;
  final Color color;
  const InboxKind(this.label, this.icon, this.color);
}

class InboxItem {
  final String id;
  final String type;
  final String channel;
  final String title;
  final String body;
  final String? route;
  final Map<String, String> args;
  final String? severity;
  final bool read;
  final DateTime? createdAt;

  const InboxItem({
    required this.id,
    required this.type,
    required this.channel,
    required this.title,
    required this.body,
    this.route,
    this.args = const {},
    this.severity,
    this.read = false,
    this.createdAt,
  });

  factory InboxItem.fromMap(String id, Map<String, dynamic> d) => InboxItem(
        id: id,
        type: (d['type'] as String?) ?? 'general',
        channel: (d['channel'] as String?) ?? KmChannel.general.id,
        title: (d['title'] as String?) ?? '',
        body: (d['body'] as String?) ?? '',
        route: d['route'] as String?,
        args: {
          for (final e in ((d['data'] as Map?) ?? const {}).entries) '${e.key}': '${e.value}',
        },
        severity: d['severity'] as String?,
        read: d['read'] == true,
        createdAt: _ts(d['createdAt']),
      );

  InboxKind get kind {
    if (type == 'weather_alert' || channel == KmChannel.weatherAlerts.id) return InboxKind.weather;
    if (type == 'advisory' || channel == KmChannel.advisories.id) return InboxKind.advice;
    if (type.startsWith('approval') || channel == KmChannel.approvals.id) return InboxKind.approval;
    if (channel == KmChannel.reminders.id) return InboxKind.reminder;
    return InboxKind.general;
  }

  /// Accent: critical weather is red, otherwise the kind's colour.
  Color get color => kind == InboxKind.weather && severity == 'critical' ? KmColors.red : kind.color;

  bool get isTest => args['testOnly'] == 'true';
}

final inboxProvider = StreamProvider.autoDispose<List<InboxItem>>((ref) {
  final uid = ref.watch(notifUidProvider);
  if (uid == null) return Stream.value(const []);
  return FirebaseFirestore.instance
      .collection('userNotifications')
      .doc(uid)
      .collection('items')
      .orderBy('createdAt', descending: true)
      .limit(200)
      .snapshots()
      .map((s) => s.docs.map((d) => InboxItem.fromMap(d.id, d.data())).toList());
});

enum InboxFilter {
  all('All'),
  unread('Unread'),
  weather('Weather'),
  advice('Advice'),
  approvals('Approvals');

  final String label;
  const InboxFilter(this.label);

  bool matches(InboxItem i) => switch (this) {
        InboxFilter.all => true,
        InboxFilter.unread => !i.read,
        InboxFilter.weather => i.kind == InboxKind.weather,
        InboxFilter.advice => i.kind == InboxKind.advice,
        InboxFilter.approvals => i.kind == InboxKind.approval,
      };
}

class InboxFilterNotifier extends Notifier<InboxFilter> {
  @override
  InboxFilter build() => InboxFilter.all;
  void set(InboxFilter f) => state = f;
}

final inboxFilterProvider = NotifierProvider<InboxFilterNotifier, InboxFilter>(InboxFilterNotifier.new);

final filteredInboxProvider = Provider.autoDispose<AsyncValue<List<InboxItem>>>((ref) {
  final filter = ref.watch(inboxFilterProvider);
  return ref.watch(inboxProvider).whenData((l) => l.where(filter.matches).toList());
});

final unreadCountProvider = Provider.autoDispose<int>(
    (ref) => ref.watch(inboxProvider).value?.where((i) => !i.read).length ?? 0);

class InboxController {
  InboxController(this.ref);
  final Ref ref;

  CollectionReference<Map<String, dynamic>>? get _col {
    final uid = ref.read(notifUidProvider);
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('userNotifications').doc(uid).collection('items');
  }

  Future<void> setRead(InboxItem i, bool read) async => _col?.doc(i.id).update({'read': read});

  Future<void> markAllRead() async {
    final col = _col;
    final unread = ref.read(inboxProvider).value?.where((i) => !i.read).toList() ?? const [];
    if (col == null || unread.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final i in unread) {
      batch.update(col.doc(i.id), {'read': true});
    }
    await batch.commit();
  }

  Future<void> delete(InboxItem i) async => _col?.doc(i.id).delete();
}

final inboxControllerProvider = Provider.autoDispose<InboxController>(InboxController.new);

// ═════════════════════════════════════════════════════════════════════════════
//  Reminders
// ═════════════════════════════════════════════════════════════════════════════

class ReminderEntry {
  final String id;
  final String title;
  final String body;
  final DateTime at;
  final DateTime? createdAt;
  final ReminderSection section;
  final String? plotId;
  final int? notifId;

  const ReminderEntry({
    required this.id,
    required this.title,
    required this.body,
    required this.at,
    this.createdAt,
    required this.section,
    this.plotId,
    this.notifId,
  });

  static ReminderEntry? fromMap(String id, Map<String, dynamic> d) {
    final at = _ts(d['scheduledDate']) ?? _ts(d['scheduleDate']);
    if (at == null) return null;
    final plot = d['plotId'] as String?;
    return ReminderEntry(
      id: id,
      title: (d['title'] as String?) ?? 'Reminder',
      body: (d['body'] as String?) ?? '',
      at: at,
      createdAt: _ts(d['createdAt']),
      section: sectionOfReminder(d),
      plotId: plot == null || plot.isEmpty || plot == 'general' ? null : plot,
      notifId: (d['notifId'] as num?)?.toInt(),
    );
  }

  bool get isPast => !at.isAfter(DateTime.now());
}

Color sectionColor(ReminderSection s) => switch (s) {
      ReminderSection.field => KmColors.green,
      ReminderSection.pest => KmColors.orange,
      ReminderSection.disease => KmColors.red,
      ReminderSection.farmTask => KmColors.teal,
      ReminderSection.other => KmColors.purple,
    };

IconData sectionIcon(ReminderSection s) => switch (s) {
      ReminderSection.field => Icons.grass_rounded,
      ReminderSection.pest => Icons.bug_report_rounded,
      ReminderSection.disease => Icons.coronavirus_rounded,
      ReminderSection.farmTask => Icons.agriculture_rounded,
      ReminderSection.other => Icons.alarm_rounded,
    };

final remindersProvider = StreamProvider.autoDispose<List<ReminderEntry>>((ref) {
  final uid = ref.watch(notifUidProvider);
  if (uid == null) return Stream.value(const []);
  // No orderBy → no composite index needed; sorted here.
  return FirebaseFirestore.instance
      .collection('field_reminders')
      .where('userId', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs.map((d) => ReminderEntry.fromMap(d.id, d.data())).whereType<ReminderEntry>().toList()
        ..sort((a, b) => a.at.compareTo(b.at)));
});

class ReminderFilterNotifier extends Notifier<ReminderSection?> {
  @override
  ReminderSection? build() => null; // null = all sections
  void set(ReminderSection? s) => state = s;
}

final reminderFilterProvider =
    NotifierProvider<ReminderFilterNotifier, ReminderSection?>(ReminderFilterNotifier.new);

final upcomingReminderCountProvider = Provider.autoDispose<int>(
    (ref) => ref.watch(remindersProvider).value?.where((r) => !r.isPast).length ?? 0);

// ═════════════════════════════════════════════════════════════════════════════
//  Farm tasks (Farm Management, stored on the device)
// ═════════════════════════════════════════════════════════════════════════════

class FarmTaskEntry {
  final String id;
  final String title;
  final String description;
  final String plotId;
  final String priority;
  final String category;
  final DateTime dueDate;
  final bool isDone;

  const FarmTaskEntry({
    required this.id,
    required this.title,
    required this.description,
    required this.plotId,
    required this.priority,
    required this.category,
    required this.dueDate,
    required this.isDone,
  });

  static FarmTaskEntry? fromJson(Map<String, dynamic> j) {
    final due = DateTime.tryParse('${j['dueDate']}');
    if (due == null) return null;
    return FarmTaskEntry(
      id: (j['id'] as String?) ?? '',
      title: (j['title'] as String?) ?? 'Task',
      description: (j['description'] as String?) ?? '',
      plotId: (j['plotId'] as String?) ?? '',
      priority: (j['priority'] as String?) ?? 'normal',
      category: (j['category'] as String?) ?? 'other',
      dueDate: due,
      isDone: j['isDone'] == true,
    );
  }

  String get categoryLabel => switch (category) {
        'planting' => 'Planting',
        'watering' => 'Watering',
        'weeding' => 'Weeding',
        'spraying' => 'Spraying',
        'fertilising' => 'Fertilising',
        'harvesting' => 'Harvesting',
        'scouting' => 'Scouting',
        _ => category.isEmpty ? 'General' : category[0].toUpperCase() + category.substring(1),
      };
}

class FarmTasksSnapshot {
  final List<FarmTaskEntry> overdue;
  final List<FarmTaskEntry> today;
  final List<FarmTaskEntry> upcoming;
  final Map<String, String> plotNames;
  final DateTime loadedAt;

  const FarmTasksSnapshot({
    required this.overdue,
    required this.today,
    required this.upcoming,
    required this.plotNames,
    required this.loadedAt,
  });

  int get openCount => overdue.length + today.length + upcoming.length;

  String? plotLabel(String id) => id.isEmpty || id == 'all' ? null : plotNames[id] ?? id;
}

/// Splits open tasks into overdue / due today / upcoming (pure; tested).
FarmTasksSnapshot splitFarmTasks(List<FarmTaskEntry> tasks, Map<String, String> plots, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
  final open = tasks.where((t) => !t.isDone).toList();
  return FarmTasksSnapshot(
    overdue: open.where((t) => day(t.dueDate).isBefore(today)).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate)),
    today: open.where((t) => day(t.dueDate) == today).toList(),
    upcoming: open.where((t) => day(t.dueDate).isAfter(today)).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate)),
    plotNames: plots,
    loadedAt: now,
  );
}

final farmTasksProvider = FutureProvider.autoDispose<FarmTasksSnapshot>((ref) async {
  final uid = ref.watch(notifUidProvider);
  final now = DateTime.now();
  if (uid == null) return splitFarmTasks(const [], const {}, now);
  final sp = await SharedPreferences.getInstance();
  final plots = <String, String>{};
  try {
    for (final p in (jsonDecode(sp.getString('${uid}_v2_plots') ?? '[]') as List)) {
      final m = Map<String, dynamic>.from(p as Map);
      final id = (m['id'] as String?) ?? '';
      if (id.isNotEmpty) plots[id] = (m['name'] as String?) ?? id;
    }
  } catch (_) {}
  final tasks = <FarmTaskEntry>[];
  try {
    for (final j in (jsonDecode(sp.getString('${uid}_v2_tasks') ?? '[]') as List)) {
      final t = FarmTaskEntry.fromJson(Map<String, dynamic>.from(j as Map));
      if (t != null) tasks.add(t);
    }
  } catch (_) {}
  return splitFarmTasks(tasks, plots, now);
});

// ═════════════════════════════════════════════════════════════════════════════
//  Farm alerts
// ═════════════════════════════════════════════════════════════════════════════

final farmAlertsProvider = FutureProvider.autoDispose<FarmAlertsResult>((ref) => loadFarmAlerts());

// ═════════════════════════════════════════════════════════════════════════════
//  Notification Settings
// ═════════════════════════════════════════════════════════════════════════════

class NotificationPrefsController extends AsyncNotifier<NotificationPrefs> {
  @override
  Future<NotificationPrefs> build() async {
    final uid = ref.watch(notifUidProvider);
    if (uid == null) return NotificationPrefs.defaults;
    return NotificationPrefsRepository.load(uid);
  }

  /// Saves [next] and applies it: the server reads it before pushing;
  /// reminders on this device are re-scheduled / cancelled; advice topics
  /// are (un)subscribed. Reverts and rethrows if saving fails.
  Future<void> save(NotificationPrefs next) async {
    final uid = ref.read(notifUidProvider);
    final previous = state.value ?? NotificationPrefs.defaults;
    if (uid == null || next == previous) return;
    state = AsyncData(next);
    try {
      await NotificationPrefsRepository.save(uid, next);
    } catch (e) {
      state = AsyncData(previous);
      rethrow;
    }
    unawaited(ReminderService.applyPrefs(uid, next));
    if (next.wantsAdvicePushes != previous.wantsAdvicePushes) {
      unawaited(NotificationService.syncFarmerTopics(uid));
    }
  }
}

final notificationPrefsProvider =
    AsyncNotifierProvider<NotificationPrefsController, NotificationPrefs>(NotificationPrefsController.new);
