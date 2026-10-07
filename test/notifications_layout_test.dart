// Notifications must never overflow: every tab is rendered with long,
// realistic content at narrow phone widths and up to the largest text size
// the app allows (phone size x Settings -> Appearance, capped at 2x), with
// and without bold text. Any overflow fails the test and names the widget.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_actions.dart';
import 'package:kilimomkononi/enterprise/features/weather/agronomic_advisory.dart';
import 'package:kilimomkononi/enterprise/features/weather/structured_advice.dart';
import 'package:kilimomkononi/services/farm_advice_service.dart';
import 'package:kilimomkononi/services/notification_prefs.dart';
import 'package:kilimomkononi/services/nuasense_service.dart';
import 'package:kilimomkononi/services/reminder_service.dart';
import 'package:kilimomkononi/services/weather_day_plan.dart';
import 'package:kilimomkononi/settings/notifications/advice_providers.dart';
import 'package:kilimomkononi/settings/notifications/farm_alerts.dart';
import 'package:kilimomkononi/settings/notifications/notification_providers.dart';
import 'package:kilimomkononi/settings/notifications_screen.dart';

NuaSenseReading station() => NuaSenseReading(
      airTemp: 24, humidity: 92, rainfall: 22, windSpeed: 9, windGusts: 14, windDirection: 0,
      sunlight: 0, airPressure: 0, dewPoint: 0, dewPointDepression: 1, vpd: 2.8, et0Hour: 0,
      lwdHour: 1, lwdReason: 'high_humidity', lwdConsecutiveHours: 12, pressureTrend6h: 0,
      sprayQualityIndex: 20, sprayQualityLabel: 'Poor', sprayLimitingFactor: '', deltaT: 0, inversionRisk: '',
      ddAphidHour: 1.5, ddWhiteflyHour: 1, ddPtmHour: 1.2, ddFawHour: 0, ddDbmHour: 0, ddTutaHour: 0,
      ddThripsHour: 0, ddArmywormHour: 0, ddCbbHour: 0,
      timestamp: DateTime.now().subtract(const Duration(minutes: 20)),
    );

class _Prefs extends NotificationPrefsController {
  @override
  Future<NotificationPrefs> build() async => const NotificationPrefs(pestReminders: false);
}

const _actions = AdviceActions(
  soil: [SoilAction(nutrient: 'N', low: BandAction(action: 'Top-dress with calcium ammonium nitrate after the rain'))],
  pests: [CropCheck(name: 'Fall Armyworm (Spodoptera frugiperda)'), CropCheck(name: 'Aphids')],
  diseases: [CropCheck(name: 'Northern Corn Leaf Blight'), CropCheck(name: 'Gray Leaf Spot')],
);

void main() {
  final received = DateTime.now().subtract(const Duration(minutes: 5));
  final long = 'Very heavy rain at NARL-KALRO Farm Weather station — check drainage on every plot now';
  final overrides = [
    notifUidProvider.overrideWithValue('u1'),
    notificationPrefsProvider.overrideWith(_Prefs.new),
    inboxProvider.overrideWith((ref) => Stream.value([
          InboxItem(id: 'a', type: 'weather_alert', channel: 'km_weather_alerts', title: '⚠ $long',
              body: '34.2 mm in the last hour. Check drainage and hold spraying, fertiliser and field work.\nVerified advice: Open furrows\nCheck for: Fall Armyworm, Northern Corn Leaf Blight · Soil: N, P',
              severity: 'critical', createdAt: received,
              args: {'advisoryId': 'x', 'sections': 'soil,pests,diseases', 'testOnly': 'true', 'category': 'heavy_rain'}),
          InboxItem(id: 'b', type: 'advisory', channel: 'km_advisories', title: 'Updated verified advice · Dry air / water stress',
              body: 'Maize, Beans, Tomatoes, Cabbages/Kales, Irish Potatoes: irrigate early in the morning', read: true,
              createdAt: received, args: {'advisoryId': 'y', 'sections': 'soil,pests'}),
          InboxItem(id: 'c', type: 'approval_request', channel: 'km_approvals', title: 'New account waiting for approval',
              body: 'Someone (student) at St. Mary\'s Secondary School is waiting.', createdAt: received),
        ])),
    remindersProvider.overrideWith((ref) => Stream.value([
          ReminderEntry(id: 'r1', title: 'Re-spray — Cabbages/Kales against Diamondback Moth', body: 'Apply again with a long explanation of the product',
              section: ReminderSection.pest, plotId: 'Upper terrace plot number two',
              at: DateTime.now().add(const Duration(hours: 5)), createdAt: received),
          ReminderEntry(id: 'r2', title: 'Past', body: 'x', section: ReminderSection.field,
              at: DateTime.now().subtract(const Duration(hours: 5)), createdAt: received),
        ])),
    farmTasksProvider.overrideWith((ref) async => splitFarmTasks([
          FarmTaskEntry(id: 't', title: 'Weed the upper terrace maize plot before the rains', description: 'Long description of the task here',
              plotId: 'p1', priority: 'medium', category: 'fertilising',
              dueDate: DateTime.now().subtract(const Duration(days: 12)), isDone: false),
          FarmTaskEntry(id: 't2', title: 'Spray', description: '', plotId: '', priority: 'high', category: 'spraying',
              dueDate: DateTime.now(), isDone: false),
        ], const {'p1': 'Upper terrace maize and beans intercrop plot'}, DateTime.now())),
    farmAdviceProvider.overrideWith((ref) async => FarmAdvice(
          reading: station(),
          stationId: 'gw',
          stationName: 'NARL-KALRO Farm Weather station',
          plan: buildKmDayPlan(station(), cropNames: const ['Maize']),
          alerts: computeFarmAlerts(ws: station(), checkedAt: DateTime.now()),
          verified: [
            AgronomicAdvisory(
              id: 'v', title: 't',
              advice: const StructuredAdvice(main: 'Hold all spraying until leaves dry and scout lower leaves for blight',
                  doList: ['Open drainage furrows between the rows'], avoidList: ['Top-dressing before rain'],
                  why: 'Wet leaves spread fungal spores quickly.'),
              crops: const ['Maize', 'Beans', 'Tomatoes', 'Cabbages/Kales'], condition: 'wet_leaves',
              status: AdvisoryStatus.published, version: 1, publishedByName: 'Dr. Jane Wanjiku Kamau (KALRO)',
              publishedAt: DateTime.now(), actions: _actions, gatewayId: 'gw'),
          ],
          crops: const ['Maize'],
          loadedAt: DateTime.now(),
        )),
    aiAdviceProvider.overrideWith((ref) async {
      final a = parseStructuredAdvice('MAIN: Hold spraying today\nDO:\n- Scout\nPESTS:\n- Aphids — sticky leaves — neem\nSOIL:\n- N | Low: top-dress');
      return AiAdvice(advice: a!, fallback: false, at: DateTime.now(),
          asAdvisory: AgronomicAdvisory.fromAi(id: 'ai', advice: a, crops: const ['Maize'], condition: 'raining'));
    }),
  ];

  const cases = [
    (320.0, 1.0, false), (320.0, 1.5, false), (320.0, 2.0, false), (320.0, 2.0, true),
    (360.0, 1.0, false), (360.0, 1.3, false), (360.0, 2.0, true),
    (412.0, 1.5, false), (412.0, 2.0, false),
  ];
  for (final (width, scale, bold) in cases) {
    testWidgets('no overflow at ${width.toInt()}px, text x$scale${bold ? ', bold' : ''}', (tester) async {
      // Very tall view: every item of every list is laid out (off-screen
      // items in a ListView would otherwise never be checked).
      tester.view.physicalSize = Size(width * 2, 6000 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final found = <String>[];
      final old = FlutterError.onError;
      FlutterError.onError = (d) {
        final s = d.toString();
        final what = RegExp(r'overflowed by [\d.]+ pixels on the \w+').firstMatch(s)?.group(0) ?? s.split('\n').first;
        final where = RegExp(r'relevant error-causing widget was:[\s\S]*?(lib/[^\s:]+\.dart:\d+)').firstMatch(s)?.group(1) ??
            RegExp(r'lib/[^\s:]+\.dart:\d+').firstMatch(s)?.group(0) ?? '?';
        found.add('$what @ $where');
      };
      addTearDown(() => FlutterError.onError = old);
      await tester.pumpWidget(ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          builder: (c, child) => MediaQuery(
              data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale), boldText: bold), child: child!),
          home: const NotificationsScreen(),
        ),
      ));
      await tester.pumpAndSettle();
      for (final tab in ['Inbox', 'Farm advice', 'Reminders', 'Farm tasks']) {
        final f = find.textContaining(tab).first;
        await tester.ensureVisible(f);
        await tester.pumpAndSettle();
        await tester.tap(f);
        await tester.pumpAndSettle();
      }
      FlutterError.onError = old;
      expect(found.toSet(), isEmpty);
    });
  }
}
