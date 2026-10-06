// lib/utils/weather_comparison_export.dart
//
// The Google vs. weather-station comparison as a formatted Excel workbook
// (for agronomists and analysis) or a plain CSV:
//
//   Sheet "Summary"   title, station / area / when, the "right now" pairing,
//                     how far apart the two sources were over 24 h, notes
//   Sheet "Hourly comparison"  one row per hour: Google | Station |
//                     Difference for each metric — grouped, colour-coded
//                     column bands, frozen header, filter buttons
//
// File name: "Google to Weather station Comparison data --YYYY-MM-DD".

import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:kilimomkononi/services/weather_comparison.dart';
import 'package:kilimomkononi/utils/xlsx_writer.dart';

const kXlsxMime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
const kCsvMime = 'text/csv';

/// "Google to Weather station Comparison data --2026-10-06" (no extension).
String comparisonFileBaseName(DateTime day) =>
    'Google to Weather station Comparison data --${DateFormat('yyyy-MM-dd').format(day)}';

final _stamp = DateFormat('EEE d MMM yyyy · HH:mm');
final _hour = DateFormat('EEE d MMM · HH:00');

double? _r(double? v) => v == null ? null : (v * 10).round() / 10;

const _notes = [
  'Google values are Google Weather\'s model for the station area (current conditions and recorded hourly history).',
  'Station values are measured on the farm by the weather station (hourly averages for the 24-hour sheet).',
  'Difference = Station − Google. A positive number means the station read higher than Google.',
  'Wind is in km/h for both (the station reports m/s; converted × 3.6). Rain is in mm.',
  'Hours that only one source reported are kept, with the other side left blank.',
  'Advice and alerts in Kilimo Mkononi come from the station\'s readings, not from Google.',
];

Uint8List buildComparisonXlsx(WeatherComparison c) {
  final x = XlsxWorkbook(title: comparisonFileBaseName(c.generatedAt));
  final metrics = WeatherComparison.hourlyMetrics;
  final lastCol = metrics.length * 3; // Hour + 3 per metric
  final subtitle = 'Station: ${c.stationName}   ·   Area: ${c.place}   ·   Generated ${_stamp.format(c.generatedAt)}';

  // ── Summary ───────────────────────────────────────────────────────────────
  final s = x.sheet('Summary', widths: [30, 18, 18, 22, 18]);
  var r = s.row([const XCell('Google to Weather station Comparison data', XStyle.title)]);
  s.merge(r, 0, 4);
  r = s.row([XCell(subtitle, XStyle.subtitle)]);
  s.merge(r, 0, 4);
  s.blank();

  final now = c.now;
  if (now != null) {
    r = s.row([XCell('Right now  (station reading ${_stamp.format(now.time)})', XStyle.label)]);
    s.merge(r, 0, 3);
    s.row(const [
      XCell('Measure', XStyle.header),
      XCell('Google', XStyle.headerGoogle),
      XCell('Weather station', XStyle.headerStation),
      XCell('Difference (station − Google)', XStyle.headerDiff),
    ]);
    var i = 0;
    for (final m in ComparedMetric.values) {
      final p = now[m];
      if (p.google == null && p.station == null) continue;
      final alt = (i++).isOdd;
      s.row([
        XCell(m.heading, alt ? XStyle.textAlt : XStyle.text),
        XCell(_r(p.google), alt ? XStyle.numberAlt : XStyle.number),
        XCell(_r(p.station), alt ? XStyle.numberAlt : XStyle.number),
        XCell(_r(p.difference), alt ? XStyle.diffAlt : XStyle.diff),
      ]);
    }
    s.blank();
  }

  r = s.row([XCell('Last 24 hours  (${c.hourly.length} hours)', XStyle.label)]);
  s.merge(r, 0, 4);
  s.row(const [
    XCell('Measure', XStyle.header),
    XCell('Hours compared', XStyle.header),
    XCell('Average difference', XStyle.headerDiff),
    XCell('Average gap (either way)', XStyle.headerDiff),
    XCell('Largest gap', XStyle.headerDiff),
  ]);
  var i = 0;
  for (final m in c.summaries) {
    final alt = (i++).isOdd;
    s.row([
      XCell(m.metric.heading, alt ? XStyle.textAlt : XStyle.text),
      XCell(m.pairs, alt ? XStyle.numberAlt : XStyle.number),
      XCell(_r(m.meanDifference), alt ? XStyle.diffAlt : XStyle.diff),
      XCell(_r(m.meanAbsDifference), alt ? XStyle.numberAlt : XStyle.number),
      XCell(_r(m.maxAbsDifference), alt ? XStyle.numberAlt : XStyle.number),
    ]);
  }
  s.blank();
  r = s.row([const XCell('Notes', XStyle.label)]);
  s.merge(r, 0, 4);
  for (final n in _notes) {
    r = s.row([XCell('•  $n', XStyle.note)]);
    s.merge(r, 0, 4);
  }

  // ── Hourly comparison ─────────────────────────────────────────────────────
  final h = x.sheet('Hourly comparison', widths: [22, for (var k = 0; k < metrics.length; k++) ...[12, 12, 13]]);
  r = h.row([const XCell('Google to Weather station Comparison data — hour by hour', XStyle.title)]);
  h.merge(r, 0, lastCol);
  r = h.row([XCell(subtitle, XStyle.subtitle)]);
  h.merge(r, 0, lastCol);
  h.blank();
  // Metric bands (merged across Google | Station | Difference).
  final bandRow = h.row([
    const XCell('Hour', XStyle.header),
    for (final m in metrics) ...[XCell(m.heading, XStyle.header), const XCell(null, XStyle.header), const XCell(null, XStyle.header)],
  ]);
  for (var k = 0; k < metrics.length; k++) {
    h.merge(bandRow, 1 + k * 3, 3 + k * 3);
  }
  final headRow = h.row([
    const XCell('(local time)', XStyle.header),
    for (var k = 0; k < metrics.length; k++) ...const [
      XCell('Google', XStyle.headerGoogle),
      XCell('Station', XStyle.headerStation),
      XCell('Difference', XStyle.headerDiff),
    ],
  ]);
  h.freezeRows = headRow;
  i = 0;
  for (final row in c.hourly) {
    final alt = (i++).isOdd;
    h.row([
      XCell(_hour.format(row.time), alt ? XStyle.textAlt : XStyle.text),
      for (final m in metrics) ...[
        XCell(_r(row[m].google), alt ? XStyle.numberAlt : XStyle.number),
        XCell(_r(row[m].station), alt ? XStyle.numberAlt : XStyle.number),
        XCell(_r(row[m].difference), alt ? XStyle.diffAlt : XStyle.diff),
      ],
    ]);
  }
  if (c.hourly.isNotEmpty) {
    h.autoFilter = 'A$headRow:${colName(lastCol)}${headRow + c.hourly.length}';
  } else {
    r = h.row([const XCell('No hourly data from one or both sources for the last 24 hours.', XStyle.note)]);
    h.merge(r, 0, lastCol);
  }
  return x.encode();
}

String _csv(Object? v) {
  final s = v == null ? '' : (v is double ? v.toStringAsFixed(1) : '$v');
  return RegExp(r'[",\n]').hasMatch(s) ? '"${s.replaceAll('"', '""')}"' : s;
}

/// The same data as one flat table (UTF-8 with BOM so Excel reads °C).
Uint8List buildComparisonCsv(WeatherComparison c) {
  final b = StringBuffer();
  void line(List<Object?> cells) => b.writeln(cells.map(_csv).join(','));
  line(['Google to Weather station Comparison data']);
  line(['Station', c.stationName]);
  line(['Area', c.place]);
  line(['Generated', _stamp.format(c.generatedAt)]);
  line([]);
  const metrics = ComparedMetric.values;
  line([
    'Time',
    for (final m in metrics) ...['${m.heading} Google', '${m.heading} Station', '${m.heading} Difference'],
  ]);
  final now = c.now;
  if (now != null) {
    line([
      'Now (${_stamp.format(now.time)})',
      for (final m in metrics) ...[_r(now[m].google), _r(now[m].station), _r(now[m].difference)],
    ]);
  }
  for (final row in c.hourly) {
    line([
      _hour.format(row.time),
      for (final m in metrics) ...[_r(row[m].google), _r(row[m].station), _r(row[m].difference)],
    ]);
  }
  line([]);
  for (final n in _notes) {
    line(['Note', n]);
  }
  return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(b.toString())]);
}
