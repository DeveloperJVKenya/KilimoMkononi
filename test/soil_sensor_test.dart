// Soil sensor: parsing NuaSense's /soil replies (shapes as the API returned
// them in Oct 2026), when the section shows, and the card at phone width.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilimomkononi/services/nuasense_service.dart';
import 'package:kilimomkononi/services/soil_sensor_service.dart';
import 'package:kilimomkononi/services/weather_station_admin_service.dart';
import 'package:kilimomkononi/widgets/soil_sensor_card.dart';

Map<String, dynamic> _series(String type, String level, List<(String, num)> pts) => {
      'id': '0000100006080002 $type L$level (level $level)',
      'devEui': '0000100006080002',
      'nodeId': 'new_cw_2',
      'sensorType': type,
      'level': level,
      'field': 'x',
      'depth': 'Level $level',
      'data': [for (final p in pts) {'x': p.$1, 'y': p.$2}],
    };

final _checked = DateTime.utc(2026, 10, 15, 7, 0);

final _latest = <String, dynamic>{
  'meta': {'gatewayId': 'b4bfe9fffe06d0d8'},
  'series': [
    _series('soil_ec', '1', [('2026-10-15T06:38:58.846Z', 178), ('2026-10-15T06:53:58.846Z', 177)]),
    _series('soil_moisture', '1', [('2026-10-15T06:38:58.846Z', 26.0), ('2026-10-15T06:53:58.846Z', 25.9)]),
    _series('soil_temperature', '1', [('2026-10-15T06:53:58.846Z', 20.6), ('2026-10-15T06:38:58.846Z', 20.7)]),
  ],
  'provisioned': true,
};

final _history = <String, dynamic>{
  'series': [
    _series('soil_ec', '1', [('2026-10-14T13:00:00.000Z', 251.25), ('2026-10-15T06:00:00.000Z', 177.5)]),
    _series('soil_moisture', '1', [('2026-10-14T13:00:00.000Z', 28.225), ('2026-10-15T06:00:00.000Z', 25.975)]),
    _series('soil_temperature', '1', [('2026-10-14T13:00:00.000Z', 23.975), ('2026-10-15T06:00:00.000Z', 20.6)]),
  ],
  'provisioned': true,
};

void main() {
  group('parsing', () {
    test('one probe with moisture, temperature and EC, values as recorded', () {
      final d = SoilSensorData.parse(latest: _latest, history: _history, checkedAt: _checked);
      expect(d.failed, isFalse);
      expect(d.provisioned, isTrue);
      expect(d.probes, hasLength(1));
      final p = d.probes.single;
      expect(p.label, 'Probe 1');
      expect(p.metrics, [SoilMetric.moisture, SoilMetric.temperature, SoilMetric.ec]);
      // Latest = newest raw point, even when the API's points are unsorted.
      expect(p.current(SoilMetric.moisture)!.value, 25.9);
      expect(p.current(SoilMetric.temperature)!.value, 20.6);
      expect(p.current(SoilMetric.ec)!.value, 177);
      expect(p.range24h(SoilMetric.moisture), (min: 25.975, max: 28.225));
      expect(p.change24h(SoilMetric.ec), closeTo(177 - 251.25, 1e-9));
      expect(d.lastReading, DateTime.parse('2026-10-15T06:53:58.846Z'));
      expect(d.isLive, isTrue);
    });

    test('several probe channels are kept apart and ordered', () {
      final d = SoilSensorData.parse(
        latest: {
          'series': [
            _series('soil_moisture', '2', [('2026-10-15T06:50:00Z', 31)]),
            _series('soil_moisture', '1', [('2026-10-15T06:50:00Z', 25)]),
          ],
        },
        history: const {'series': []},
        checkedAt: _checked,
      );
      expect(d.probes.map((p) => p.label), ['Probe 1', 'Probe 2']);
      expect(d.probes.last.current(SoilMetric.moisture)!.value, 31);
    });

    test('unknown sensor types and broken points are skipped, never zero-filled', () {
      final d = SoilSensorData.parse(
        latest: {
          'series': [
            _series('soil_ph', '1', [('2026-10-15T06:50:00Z', 6.5)]),
            {
              ..._series('soil_moisture', '1', const []),
              'data': [
                {'x': 'not a date', 'y': 5},
                {'x': '2026-10-15T06:50:00Z', 'y': null},
                {'x': '2026-10-15T06:55:00Z', 'y': 24.5},
              ],
            },
          ],
        },
        history: const {},
        checkedAt: _checked,
      );
      expect(d.probes.single.metrics, [SoilMetric.moisture]);
      expect(d.probes.single.current(SoilMetric.moisture)!.value, 24.5);
    });

    test('an old last reading is not live', () {
      final d = SoilSensorData.parse(
        latest: const {'series': []},
        history: {
          'series': [_series('soil_moisture', '1', [('2026-10-15T03:00:00Z', 26)])],
        },
        checkedAt: _checked,
      );
      expect(d.hasReadings, isTrue);
      expect(d.isLive, isFalse);
    });

    test('no station / failed request / no readings', () {
      expect(
        SoilSensorData.parse(latest: {'provisioned': false}, history: {'provisioned': false}, checkedAt: _checked)
            .provisioned,
        isFalse,
      );
      // The proxy returns {} when the call fails.
      expect(SoilSensorData.parse(latest: const {}, history: const {}, checkedAt: _checked).failed, isTrue);
      final none = SoilSensorData.parse(
          latest: const {'series': []}, history: const {'series': []}, checkedAt: _checked);
      expect(none.failed, isFalse);
      expect(none.hasReadings, isFalse);
      expect(none.lastReading, isNull);
    });

    test('every request asks for all three metrics (EC only comes when named)', () {
      expect(kSoilMetricsParam, 'soil_moisture,soil_temperature,soil_ec');
      expect(SoilMetric.moisture.format(25.94), '25.9 % VWC');
      expect(SoilMetric.ec.format(177.5), '178 µS/cm');
      expect(SoilMetric.temperature.unit, '°C');
    });
  });

  group('which stations show soil data', () {
    final withData = SoilSensorData.parse(latest: _latest, history: _history, checkedAt: _checked);
    final empty = SoilSensorData(checkedAt: _checked);

    test('confirmed attached: always (even before the first reading)', () {
      expect(SoilSensorService.shouldFetch(true), isTrue);
      expect(SoilSensorService.shouldShow(true, empty), isTrue);
    });
    test('confirmed none: never asked for', () {
      expect(SoilSensorService.shouldFetch(false), isFalse);
      expect(SoilSensorService.shouldShow(false, withData), isFalse);
    });
    test('not confirmed (stations from before): only when it sends readings', () {
      expect(SoilSensorService.shouldFetch(null), isTrue);
      expect(SoilSensorService.shouldShow(null, withData), isTrue);
      expect(SoilSensorService.shouldShow(null, empty), isFalse);
      expect(SoilSensorService.shouldShow(null, null), isFalse);
    });

    test('station listings carry the admin\'s answer', () {
      expect(NuaStation.fromJson({'gateway_id': 'a', 'soil_sensor': true}).soilSensor, isTrue);
      expect(NuaStation.fromJson({'gateway_id': 'a', 'soil_sensor': false}).soilSensor, isFalse);
      expect(NuaStation.fromJson({'gateway_id': 'a', 'soil_sensor': null}).soilSensor, isNull);
      expect(NuaStation.fromJson({'gateway_id': 'a'}).soilSensor, isNull);
    });

    test('admin overview reads the answer and the live check', () {
      final s = AdminStation.fromMap({
        'gatewayId': 'b4bfe9fffe06d0d8',
        'displayName': 'Office',
        'providerId': 'nuasense',
        'providerName': 'NuaSense',
        'soilSensor': 'attached',
        'soilSensorCheck': {
          'supported': true,
          'found': true,
          'devEuis': ['0000100006080002'],
          'probes': 1,
          'sensorTypes': ['soil_ec', 'soil_moisture', 'soil_temperature'],
          'firstReading': '2026-10-14T13:10:41.956Z',
        },
      });
      expect(s.soilSensor, SoilSensorAnswer.attached);
      expect(s.soilSensorCheck!.found, isTrue);
      expect(s.soilSensorCheck!.metricsLabel, 'Soil EC, moisture, temperature');
      expect(AdminStation.fromMap({'gatewayId': 'x'}).soilSensor, SoilSensorAnswer.unconfirmed);
      expect(SoilSensorAnswer.from('maybe'), SoilSensorAnswer.unconfirmed);
    });
  });

  group('card', () {
    Future<void> pump(WidgetTester tester, Widget card, {double width = 360, double textScale = 1}) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, 900), textScaler: TextScaler.linear(textScale)),
          child: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: card)),
        ),
      ));
    }

    testWidgets('shows the three readings with units at 360 px, no overflow', (tester) async {
      final d = SoilSensorData.parse(latest: _latest, history: _history, checkedAt: _checked);
      await pump(tester, SoilSensorCard(data: d, confirmed: true, now: _checked));
      expect(tester.takeException(), isNull);
      expect(find.text('Soil sensor'), findsOneWidget);
      expect(find.textContaining('Live'), findsOneWidget);
      expect(find.text('Soil moisture'), findsOneWidget);
      expect(find.text('Soil EC'), findsOneWidget);
      expect(find.textContaining('25.9'), findsWidgets);
      expect(find.textContaining('µS/cm'), findsWidgets);
      expect(find.text('24 h: 26.0 – 28.2'), findsOneWidget);
    });

    testWidgets('large text on a small phone still fits', (tester) async {
      final d = SoilSensorData.parse(latest: _latest, history: _history, checkedAt: _checked);
      await pump(tester, SoilSensorCard(data: d, now: _checked), width: 320, textScale: 1.6);
      expect(tester.takeException(), isNull);
    });

    testWidgets('confirmed sensor without readings says so', (tester) async {
      await pump(tester, SoilSensorCard(data: SoilSensorData(checkedAt: _checked), confirmed: true, now: _checked));
      expect(tester.takeException(), isNull);
      expect(find.textContaining('hasn\'t sent any readings yet'), findsOneWidget);
    });

    testWidgets('an old reading is shown with its time, as not reporting', (tester) async {
      final d = SoilSensorData.parse(
        latest: const {'series': []},
        history: {
          'series': [_series('soil_moisture', '1', [('2026-10-15T03:00:00Z', 26)])],
        },
        checkedAt: _checked,
      );
      await pump(tester, SoilSensorCard(data: d, now: _checked));
      expect(find.textContaining('Not reporting · last reading 4 h ago'), findsOneWidget);
    });
  });
}
