// Past dates: station vs. NASA POWER satellite — pairing, Kenyan days and
// the Excel / CSV downloads (weather_history_comparison.dart,
// weather_history_export.dart).

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilimomkononi/services/weather_comparison.dart' show ComparedMetric;
import 'package:kilimomkononi/services/weather_history_comparison.dart';
import 'package:kilimomkononi/utils/weather_history_export.dart';

int utc(int d, int h) => DateTime.utc(2026, 10, d, h).millisecondsSinceEpoch;

Map<String, dynamic> response() => {
      'stationName': 'Njoro station',
      'start': '2026-10-03',
      'end': '2026-10-04',
      'station': [
        {'t': utc(3, 0), 'temp': 14.0, 'humidity': 80.0, 'wind': 1.0, 'rain': 0.5},
        {'t': utc(3, 1), 'temp': 16.0, 'humidity': 70.0, 'wind': 2.0, 'rain': 1.0},
        // 21:00 UTC = midnight in Kenya → the next Kenyan day
        {'t': utc(3, 21), 'temp': 10.0, 'humidity': 90.0, 'wind': 0.0, 'rain': 0.0},
      ],
      'satellite': [
        {'t': utc(3, 0), 'temp': 13.0, 'humidity': 85.0, 'wind': 1.5, 'rain': 0.0},
        {'t': utc(3, 2), 'temp': 15.0, 'humidity': null, 'wind': 1.0, 'rain': 0.2},
      ],
      'satelliteAvailable': true,
      'satelliteLatest': utc(3, 2),
    };

void main() {
  test('hour by hour: matched by hour, one-sided hours kept, wind in km/h', () {
    final c = historyFromResponse(response(), resolution: HistoryResolution.hourly);
    expect(c.rows.length, 4); // 00, 01, 02, 21
    final first = c.rows.first;
    expect(first.station.temp, 14.0);
    expect(first.satellite.temp, 13.0);
    expect(first.difference(ComparedMetric.temp), closeTo(1.0, 1e-9));
    expect(first.station.wind, closeTo(3.6, 1e-9));
    expect(first.satellite.wind, closeTo(5.4, 1e-9));
    expect(c.rows[1].satellite.isEmpty, isTrue); // satellite had no 01:00
    expect(c.rows[1].difference(ComparedMetric.temp), isNull);
  });

  test('day by day: Kenyan days, averages and rain totals from each side\'s own hours', () {
    final c = historyFromResponse(response(), resolution: HistoryResolution.daily);
    expect(c.rows.length, 2); // 3 Oct EAT, 4 Oct EAT
    final day = c.rows.first;
    expect(day.time, DateTime(2026, 10, 3));
    expect(day.station.temp, 15.0);
    expect(day.station.rain, 1.5); // total
    expect(day.station.hours, 2);
    expect(day.satellite.temp, 14.0);
    expect(day.satellite.humidity, 85.0); // the null hour is skipped
    expect(day.satellite.hours, 2);
    expect(c.rows.last.time, DateTime(2026, 10, 4));
    expect(c.rows.last.satellite.isEmpty, isTrue);
  });

  test('switching view re-pairs the same hours without a download', () {
    final hourly = historyFromResponse(response(), resolution: HistoryResolution.hourly);
    final daily = hourly.withResolution(HistoryResolution.daily);
    expect(daily.rows.length, 2);
    expect(daily.withResolution(HistoryResolution.hourly).rows.length, 4);
  });

  test('summary per measure: station − satellite', () {
    final c = historyFromResponse(response(), resolution: HistoryResolution.hourly);
    final t = c.summaries.firstWhere((s) => s.metric == ComparedMetric.temp);
    expect(t.pairs, 1);
    expect(t.meanDifference, closeTo(1.0, 1e-9));
    expect(t.stationMean, closeTo((14 + 16 + 10) / 3, 1e-9));
  });

  test('downloads: file name from the dates; Excel opens; CSV has every row', () {
    final c = historyFromResponse(response(), resolution: HistoryResolution.daily);
    expect(historyFileBaseName(c), 'Station to Satellite Comparison data --2026-10-03_to_2026-10-04');

    final xlsx = buildHistoryXlsx(c);
    final zip = ZipDecoder().decodeBytes(xlsx);
    final names = zip.files.map((f) => f.name).toSet();
    expect(names, containsAll(['xl/workbook.xml', 'xl/styles.xml', 'xl/worksheets/sheet1.xml', 'xl/worksheets/sheet2.xml']));
    final workbook = utf8.decode(zip.findFile('xl/workbook.xml')!.content as List<int>);
    expect(workbook, contains('Daily comparison'));

    final csv = utf8.decode(buildHistoryCsv(c).sublist(3));
    expect(csv, contains('Day (EAT),Temperature (°C) Station,Temperature (°C) Satellite'));
    expect(csv, contains('2026-10-03,15.0,14.0,1.0'));
    expect(csv, contains('2026-10-04'));
  });

  test('in-service date and the latest recorded hour come through; switching view keeps them', () {
    final c = historyFromResponse({
      ...response(),
      'stationLatest': utc(3, 21),
      'inServiceFrom': '2026-10-02',
      'clippedToService': true,
    }, resolution: HistoryResolution.hourly);
    expect(c.stationLatest, DateTime.fromMillisecondsSinceEpoch(utc(3, 21)));
    expect(c.inServiceFrom, DateTime(2026, 10, 2));
    expect(c.clippedToService, isTrue);
    final daily = c.withResolution(HistoryResolution.daily);
    expect(daily.inServiceFrom, DateTime(2026, 10, 2));
    expect(daily.stationLatest, c.stationLatest);
    expect(daily.clippedToService, isTrue);
  });
}
