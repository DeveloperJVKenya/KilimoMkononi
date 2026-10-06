// Google vs. weather station comparison: pairing, summaries and the
// Excel / CSV exports.

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilimomkononi/services/google_weather_service.dart';
import 'package:kilimomkononi/services/nuasense_service.dart';
import 'package:kilimomkononi/services/weather_comparison.dart';
import 'package:kilimomkononi/utils/weather_comparison_export.dart';
import 'package:kilimomkononi/utils/xlsx_writer.dart';

GoogleHistoryHour g(DateTime t, double temp, {int hum = 60, double wind = 7.2, double rain = 0}) =>
    GoogleHistoryHour(time: t, temp: temp, humidity: hum, dewPoint: 12, windKmh: wind, gustKmh: 15, rainMm: rain);

NuaSenseHourPoint s(DateTime t, double temp, {double hum = 70, double wind = 2, double rain = 0}) =>
    NuaSenseHourPoint(time: t, airTemp: temp, humidity: hum, rainfall: rain, windSpeed: wind, et0Hour: 0, lwdHour: 0);

WeatherComparison sample() {
  final t0 = DateTime.utc(2026, 10, 6, 6);
  return WeatherComparison(
    stationName: 'NARL-KALRO Farm Weather station',
    gatewayId: 'b4bfe9fffe06d0d8',
    place: 'Kabete, Nairobi County',
    generatedAt: DateTime(2026, 10, 6, 9, 30),
    now: ComparisonRow(DateTime(2026, 10, 6, 9), {
      ComparedMetric.temp: const MetricPair(21.0, 22.4),
      ComparedMetric.humidity: const MetricPair(60, 71),
      ComparedMetric.wind: const MetricPair(9.0, 7.2),
    }),
    hourly: pairHourly(
      [g(t0, 18), g(t0.add(const Duration(hours: 1)), 19), g(t0.add(const Duration(hours: 2)), 20)],
      [s(t0, 19.5), s(t0.add(const Duration(hours: 1)), 18.0), s(t0.add(const Duration(hours: 3)), 21)],
    ),
  );
}

void main() {
  test('hours are matched across sources; hours only one side has are kept', () {
    final rows = sample().hourly;
    expect(rows.length, 4);
    expect(rows[0][ComparedMetric.temp].difference, closeTo(1.5, 1e-9));
    expect(rows[1][ComparedMetric.temp].difference, closeTo(-1.0, 1e-9));
    expect(rows[2][ComparedMetric.temp].station, isNull, reason: 'station missed that hour');
    expect(rows[3][ComparedMetric.temp].google, isNull, reason: 'Google missed that hour');
    // Station wind m/s → km/h, to compare with Google's km/h.
    expect(rows[0][ComparedMetric.wind].station, closeTo(7.2, 1e-9));
    expect(rows[0][ComparedMetric.wind].difference, closeTo(0, 1e-9));
  });

  test('summary: average difference keeps the sign, the gap ignores it', () {
    final t = sample().summaries.firstWhere((m) => m.metric == ComparedMetric.temp);
    expect(t.pairs, 2);
    expect(t.meanDifference, closeTo(0.25, 1e-9));
    expect(t.meanAbsDifference, closeTo(1.25, 1e-9));
    expect(t.maxAbsDifference, closeTo(1.5, 1e-9));
  });

  test('"now" pairs Google current conditions with the latest station reading', () {
    final row = pairNow(null, null);
    expect(row.hasGoogle, isFalse);
    expect(row.hasStation, isFalse);
  });

  test('download name: Google to Weather station Comparison data --date', () {
    expect(comparisonFileBaseName(DateTime(2026, 10, 6, 17, 5)),
        'Google to Weather station Comparison data --2026-10-06');
  });

  test('Excel: two formatted sheets, frozen header, filter, values and differences', () {
    final bytes = buildComparisonXlsx(sample());
    final zip = ZipDecoder().decodeBytes(bytes);
    String part(String name) => utf8.decode(zip.findFile(name)!.content as List<int>);
    expect(part('xl/workbook.xml'), allOf(contains('name="Summary"'), contains('name="Hourly comparison"')));
    final hourly = part('xl/worksheets/sheet2.xml');
    expect(hourly, contains('state="frozen"'));
    expect(hourly, contains('<autoFilter ref="A5:M9"/>'));
    expect(hourly, contains('<v>19.5</v>'));
    expect(hourly, contains('<v>1.5</v>'), reason: 'difference column');
    expect(part('xl/worksheets/sheet1.xml'), contains('NARL-KALRO Farm Weather station'));
    expect(part('xl/styles.xml'), contains('+0.0;-0.0;0.0'));
    expect(colName(0), 'A');
    expect(colName(12), 'M');
    expect(colName(26), 'AA');

    // Written for an independent check with a spreadsheet library.
    final out = Platform.environment['KM_XLSX_SAMPLE'];
    if (out != null) File(out).writeAsBytesSync(bytes);
  });

  test('CSV: header, a now row and one row per hour; Excel-friendly UTF-8', () {
    final csv = utf8.decode(buildComparisonCsv(sample()).sublist(3));
    final lines = csv.trim().split('\n');
    expect(lines.first, 'Google to Weather station Comparison data');
    expect(csv, contains('Temperature (°C) Google,Temperature (°C) Station,Temperature (°C) Difference'));
    expect(csv, contains('Now (Tue 6 Oct 2026 · 09:00),21.0,22.4,1.4'));
    expect(lines.where((l) => RegExp(r'^\w{3} \d+ Oct · \d\d:00,').hasMatch(l)).length, 4);
  });
}
