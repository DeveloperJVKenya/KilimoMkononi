// The app (lib/services/notification_service.dart) and the Cloud Functions
// (functions/notifications.js) must agree on channel ids, routes and crop
// topic names — otherwise pushes land on the wrong channel, open nothing, or
// never reach the farmers subscribed to a crop.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_actions.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_conditions.dart';
import 'package:kilimomkononi/services/notification_service.dart';

void main() {
  final server = File('functions/notifications.js').readAsStringSync();

  test('every server channel exists in the app', () {
    final serverChannels = RegExp(r'"(km_[a-z_]+)"')
        .allMatches(RegExp(r'const CHANNEL = \{([^}]*)\}').firstMatch(server)!.group(1)!)
        .map((m) => m.group(1)!)
        .toSet();
    final appChannels = KmChannel.values.map((c) => c.id).toSet();
    expect(appChannels, containsAll(serverChannels));
  });

  test('every server route is handled by the app', () {
    final routes = RegExp(r'"([a-z_]+)"')
        .allMatches(RegExp(r'const ROUTE = \{([^}]*)\}').firstMatch(server)!.group(1)!)
        .map((m) => m.group(1)!)
        .toSet();
    expect({KmRoute.weatherStation, KmRoute.notifications, KmRoute.eduHome, KmRoute.advisory},
        containsAll(routes));
  });

  test('weather-alert categories file under the same farm sections in the app and the functions', () {
    final block = RegExp(r'const ALERT_SECTIONS = \{([^}]*)\}').firstMatch(server)!.group(1)!;
    final fn = {
      for (final m in RegExp(r'([a-z_]+): \[([^\]]*)\]').allMatches(block))
        m.group(1)!: RegExp(r'"([a-z]+)"').allMatches(m.group(2)!).map((x) => x.group(1)!).toSet(),
    };
    final app = {
      for (final e in kAlertCategorySections.entries) e.key: e.value.map((s) => s.name).toSet(),
    };
    expect(fn, app);
    // Section names the server sends are the app's AdviceSection names.
    expect(AdviceSection.values.map((s) => s.name).toSet(), containsAll(fn.values.expand((v) => v).toSet()));
  });

  test('crop topics use the same slug as the server', () {
    // Mirrors functions/test/notifications.test.js "cropTopic".
    expect(NotificationService.cropTopic('Cabbages/Kales'), 'km_crop_cabbages_kales');
    expect(NotificationService.cropTopic('Irish Potatoes'), 'km_crop_irish_potatoes');
    expect(NotificationService.cropTopic(' Maize '), 'km_crop_maize');
  });

  test('advisory condition keys match in the app, the functions and the rules', () {
    final app = kAdvisoryConditions.map((c) => c.key).toSet();
    final fnLabels = RegExp(r'const CONDITION_LABELS = \{([^}]*)\}').firstMatch(server)!.group(1)!;
    final functions = RegExp(r'^\s*([a-z_]+):', multiLine: true)
        .allMatches(fnLabels)
        .map((m) => m.group(1)!)
        .toSet();
    final rules = File('firestore.rules').readAsStringSync();
    final ruleList = RegExp(r"d\.condition in \[([^\]]*)\]").firstMatch(rules)!.group(1)!;
    final ruleKeys = RegExp(r"'([a-z_]+)'").allMatches(ruleList).map((m) => m.group(1)!).toSet();
    expect(functions, app);
    expect(ruleKeys, app);
  });

  test('status-bar icon exists for Android', () {
    expect(File('android/app/src/main/res/drawable/ic_stat_km.xml').existsSync(), isTrue);
    expect(server, contains('const ICON = "ic_stat_km"'));
  });
}
