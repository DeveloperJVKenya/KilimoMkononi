// The app (lib/services/notification_service.dart) and the Cloud Functions
// (functions/notifications.js) must agree on channel ids, routes and crop
// topic names — otherwise pushes land on the wrong channel, open nothing, or
// never reach the farmers subscribed to a crop.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
    expect({KmRoute.weatherStation, KmRoute.notifications, KmRoute.eduHome}, containsAll(routes));
  });

  test('crop topics use the same slug as the server', () {
    // Mirrors functions/test/notifications.test.js "cropTopic".
    expect(NotificationService.cropTopic('Cabbages/Kales'), 'km_crop_cabbages_kales');
    expect(NotificationService.cropTopic('Irish Potatoes'), 'km_crop_irish_potatoes');
    expect(NotificationService.cropTopic(' Maize '), 'km_crop_maize');
  });

  test('status-bar icon exists for Android', () {
    expect(File('android/app/src/main/res/drawable/ic_stat_km.xml').existsSync(), isTrue);
    expect(server, contains('const ICON = "ic_stat_km"'));
  });
}
