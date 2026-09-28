import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kilimomkononi/screens/Field%20Data%20Input/satellite_data_screen.dart' show ConditionRisk;
import 'package:kilimomkononi/services/notification_prefs.dart';
import 'package:kilimomkononi/services/nuasense_service.dart';
import 'package:kilimomkononi/services/reminder_service.dart';
import 'package:kilimomkononi/settings/notifications/farm_alerts.dart';
import 'package:kilimomkononi/settings/notifications/notification_providers.dart';
import 'package:kilimomkononi/settings/notifications/notification_style.dart';
import 'package:kilimomkononi/settings/notifications_screen.dart';
import 'package:kilimomkononi/settings/notifications_settings_screen.dart';

NuaSenseReading station({double humidity = 60, double airTemp = 22, int lwdHour = 0, double vpd = 1.0}) =>
    NuaSenseReading(
      airTemp: airTemp, humidity: humidity, rainfall: 0, windSpeed: 1, windGusts: 0, windDirection: 0,
      sunlight: 0, airPressure: 0, dewPoint: 0, dewPointDepression: 5, vpd: vpd, et0Hour: 0,
      lwdHour: lwdHour, lwdReason: '', lwdConsecutiveHours: 0, pressureTrend6h: 0,
      sprayQualityIndex: 80, sprayQualityLabel: 'Good', sprayLimitingFactor: '', deltaT: 0, inversionRisk: '',
      ddAphidHour: 0, ddWhiteflyHour: 0, ddPtmHour: 0, ddFawHour: 0, ddDbmHour: 0, ddTutaHour: 0,
      ddThripsHour: 0, ddArmywormHour: 0, ddCbbHour: 0,
      timestamp: DateTime(2026, 9, 28, 9, 30),
    );

class _FakePrefs extends NotificationPrefsController {
  _FakePrefs(this.initial);
  final NotificationPrefs initial;
  @override
  Future<NotificationPrefs> build() async => initial;
  @override
  Future<void> save(NotificationPrefs next) async => state = AsyncData(next);
}

void main() {
  group('NotificationPrefs', () {
    test('missing or malformed values fall back to defaults (all on, 07:00)', () {
      expect(NotificationPrefs.fromMap(null), NotificationPrefs.defaults);
      final p = NotificationPrefs.fromMap({'push': 'yes', 'taskReminderHour': 30, 'pestReminders': false});
      expect(p.push, isTrue);
      expect(p.taskReminderHour, 7);
      expect(p.pestReminders, isFalse);
    });
    test('round-trips through its map; advice topics need push AND advice', () {
      const p = NotificationPrefs(weatherAlerts: false, taskReminderHour: 18, taskReminderMinute: 45);
      expect(NotificationPrefs.fromMap(p.toMap()), p);
      expect(const NotificationPrefs(push: false).wantsAdvicePushes, isFalse);
      expect(const NotificationPrefs(advisories: false).wantsAdvicePushes, isFalse);
      expect(NotificationPrefs.defaults.wantsAdvicePushes, isTrue);
    });
    test('field names match the server and the rules', () {
      expect(NotificationPrefs.defaults.toMap().keys.toSet(), {
        'push', 'weatherAlerts', 'advisories', 'approvals', 'fieldReminders', 'pestReminders',
        'diseaseReminders', 'taskReminders', 'taskReminderHour', 'taskReminderMinute',
      });
    });
  });

  group('ReminderService helpers', () {
    test('notification ids are stable, positive 31-bit', () {
      expect(stableNotificationId('task_abc'), stableNotificationId('task_abc'));
      expect(stableNotificationId('task_abc'), isNot(stableNotificationId('task_abd')));
      expect(stableNotificationId('x') >= 0 && stableNotificationId('x') <= 0x7FFFFFFF, isTrue);
    });
    test('section: stored value first, else inferred like the old screen', () {
      expect(sectionOfReminder({'section': 'disease'}), ReminderSection.disease);
      expect(sectionOfReminder({'plotId': 'p1', 'title': 'x'}), ReminderSection.field);
      expect(sectionOfReminder({'title': 'Re-spray — Maize'}), ReminderSection.pest);
      expect(sectionOfReminder({'title': 'Disease follow-up'}), ReminderSection.disease);
      expect(sectionOfReminder({'title': 'Call the vet'}), ReminderSection.other);
    });
    test('each section obeys its own switch', () {
      const p = NotificationPrefs(pestReminders: false, taskReminders: false);
      expect(ReminderSection.pest.enabledIn(p), isFalse);
      expect(ReminderSection.farmTask.enabledIn(p), isFalse);
      expect(ReminderSection.field.enabledIn(p), isTrue);
      expect(ReminderSection.other.enabledIn(p), isTrue);
    });
    test('farm tasks ring on the due date at the chosen time', () {
      expect(taskReminderTime(DateTime(2026, 10, 2, 15), const NotificationPrefs(taskReminderHour: 6, taskReminderMinute: 30)),
          DateTime(2026, 10, 2, 6, 30));
    });
  });

  test('farm tasks split into overdue / today / upcoming; done tasks hidden', () {
    FarmTaskEntry t(String id, DateTime due, {bool done = false}) => FarmTaskEntry(
        id: id, title: id, description: '', plotId: 'p1', priority: 'normal', category: 'weeding',
        dueDate: due, isDone: done);
    final now = DateTime(2026, 9, 28, 10);
    final s = splitFarmTasks([
      t('late', DateTime(2026, 9, 25)),
      t('today', DateTime(2026, 9, 28)),
      t('soon', DateTime(2026, 10, 1)),
      t('done', DateTime(2026, 9, 20), done: true),
    ], {'p1': 'Maize plot'}, now);
    expect(s.overdue.map((e) => e.id), ['late']);
    expect(s.today.map((e) => e.id), ['today']);
    expect(s.upcoming.map((e) => e.id), ['soon']);
    expect(s.openCount, 3);
    expect(s.plotLabel('p1'), 'Maize plot');
    expect(s.plotLabel('all'), isNull);
  });

  test('farm alerts record their source and reading time', () {
    final checked = DateTime(2026, 9, 28, 9, 41);
    final r = computeFarmAlerts(ws: station(humidity: 90, airTemp: 24, lwdHour: 1), checkedAt: checked);
    expect(r.alerts, isNotEmpty);
    expect(r.alerts.first.risk.index >= r.alerts.last.risk.index, isTrue); // most severe first
    expect(r.alerts.any((a) => a.source == FarmAlertSource.weatherStation), isTrue);
    expect(r.readingTimeFor(FarmAlertSource.weatherStation), DateTime(2026, 9, 28, 9, 30));
    expect(r.readingTimeFor(FarmAlertSource.iotSensor), isNull);
    expect(r.checkedAt, checked);
    expect(riskLabel(ConditionRisk.critical), 'Critical');
  });

  group('timestamps', () {
    final now = DateTime(2026, 9, 28, 12);
    test('full stamp, day headings, relative time', () {
      expect(fullStamp(DateTime(2026, 9, 28, 9, 41)), 'Mon 28 Sep 2026 · 09:41');
      expect(dayHeading(DateTime(2026, 9, 28, 1), now: now), 'Today');
      expect(dayHeading(DateTime(2026, 9, 27, 23), now: now), 'Yesterday');
      expect(dayHeading(DateTime(2026, 9, 29), now: now), 'Tomorrow');
      expect(dayHeading(DateTime(2026, 9, 30), now: now), 'Wednesday 30 Sep 2026');
      expect(relativeTime(now.subtract(const Duration(minutes: 5)), now: now), '5 min ago');
      expect(relativeTime(now.add(const Duration(hours: 3)), now: now), 'in 3 h');
      expect(relativeTime(now.subtract(const Duration(days: 2)), now: now), '2 days ago');
    });
    test('groups consecutive items by day', () {
      final g = groupByDay([DateTime(2026, 9, 28, 9), DateTime(2026, 9, 28, 8), DateTime(2026, 9, 27)], (d) => d,
          now: now);
      expect(g.map((e) => (e.$1, e.$2.length)).toList(), [('Today', 2), ('Yesterday', 1)]);
    });
  });

  group('screens at 360px', () {
    Future<void> phone(WidgetTester tester) async {
      tester.view.physicalSize = const Size(360 * 3, 780 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    final received = DateTime.now().subtract(const Duration(minutes: 5));
    final overrides = [
      notifUidProvider.overrideWithValue('u1'),
      notificationPrefsProvider.overrideWith(() => _FakePrefs(const NotificationPrefs(pestReminders: false))),
      inboxProvider.overrideWith((ref) => Stream.value([
            InboxItem(
                id: 'a', type: 'weather_alert', channel: 'km_weather_alerts', title: 'Heavy rain at your farm',
                body: '12 mm in the last hour.', severity: 'high', createdAt: received),
            InboxItem(
                id: 'b', type: 'advisory', channel: 'km_advisories', title: 'Verified advice · Wet leaves',
                body: 'Maize: hold spraying', read: true, createdAt: received),
          ])),
      remindersProvider.overrideWith((ref) => Stream.value([
            ReminderEntry(
                id: 'r1', title: 'Re-spray — Maize', body: 'Apply again', section: ReminderSection.pest,
                at: DateTime.now().add(const Duration(hours: 5)), createdAt: received),
          ])),
      farmTasksProvider.overrideWith((ref) async => splitFarmTasks([
            FarmTaskEntry(
                id: 't', title: 'Weed plot A', description: '', plotId: '', priority: 'high',
                category: 'weeding', dueDate: DateTime.now().subtract(const Duration(days: 2)), isDone: false),
          ], const {}, DateTime.now())),
      farmAlertsProvider.overrideWith((ref) async =>
          computeFarmAlerts(ws: station(humidity: 90, lwdHour: 1), checkedAt: DateTime.now())),
    ];

    testWidgets('Notifications: every tab renders with exact times', (tester) async {
      await phone(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: overrides,
        child: const MaterialApp(home: NotificationsScreen()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Heavy rain at your farm'), findsOneWidget);
      expect(find.textContaining('Received'), findsNWidgets(2));
      expect(find.textContaining(fullStamp(received)), findsNWidgets(2));
      expect(find.text('1 unread · 1 reminder coming up'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('Reminders'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reminders'));
      await tester.pumpAndSettle();
      expect(find.text('Re-spray — Maize'), findsOneWidget);
      expect(find.text('Muted in settings'), findsOneWidget); // pest reminders are off
      expect(find.textContaining('Set on'), findsOneWidget);

      await tester.ensureVisible(find.text('Farm tasks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Farm tasks'));
      await tester.pumpAndSettle();
      expect(find.text('Weed plot A'), findsOneWidget);
      expect(find.textContaining('overdue by 2 days'), findsOneWidget);

      await tester.ensureVisible(find.text('Farm alerts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Farm alerts'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Checked'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Settings: real sections, white back button, no overflow', (tester) async {
      await phone(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          ...overrides,
          notificationPermissionProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (c) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                    c, MaterialPageRoute(builder: (_) => const NotificationsSettingsScreen())),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Alerts & advice'), findsOneWidget);
      expect(find.text('Weather alerts'), findsOneWidget);
      final back = tester.widget<BackButton>(find.byType(BackButton));
      expect(back.color, Colors.white);
      await tester.scrollUntilVisible(find.text('Farm task reminder time'), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('7:00'), findsOneWidget); // 07:00 or 7:00 AM by locale
      expect(tester.takeException(), isNull);

      // Toggling saves through the controller and updates the switch.
      await tester.ensureVisible(find.text('Pest Management'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pest Management'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Pest reminders on'), findsOneWidget);
    });
  });
}
