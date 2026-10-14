// lib/utils/weather_history_export.dart
//
// Past dates: weather station vs. NASA POWER satellite as a formatted Excel
// workbook or a plain CSV (lib/services/weather_history_comparison.dart):
//
//   Sheet "Summary"   station, dates, view, how far apart the two sources
//                     were per measure (and each source's average), notes
//   Sheet "Hourly comparison" / "Daily comparison"
//                     one row per hour / day: Station | Satellite | Difference
//                     for each measure, plus how many hours each side had
//                     (daily) — colour-coded bands, frozen header, filters
//
// File name: "Station to Satellite Comparison data --<start>_to_<end>".

import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:kilimomkononi/services/weather_comparison.dart' show ComparedMetric;
import 'package:kilimomkononi/services/weather_history_comparison.dart';
import 'package:kilimomkononi/utils/xlsx_writer.dart';

final _day = DateFormat('yyyy-MM-dd');
final _stamp = DateFormat('EEE d MMM yyyy · HH:mm');
final _hourFmt = DateFormat('EEE d MMM yyyy · HH:00');
final _dayFmt = DateFormat('EEE d MMM yyyy');

/// "Station to Satellite Comparison data --2026-10-01_to_2026-10-07".
String historyFileBaseName(HistoryComparison c) =>
    'Station to Satellite Comparison data --${_day.format(c.start)}_to_${_day.format(c.end)}';

double? _r(double? v) => v == null ? null : (v * 10).round() / 10;

String _when(HistoryComparison c, HistoryRow row) =>
    c.resolution == HistoryResolution.hourly ? _hourFmt.format(row.time) : _dayFmt.format(row.time);

List<String> _notes(HistoryComparison c) => [
      'Station values are measured on the farm by the weather station.',
      'Satellite values are NASA POWER (MERRA-2 / GEOS based) for the station\'s location, '
          '~0.5° grid — an area estimate, not a farm measurement.',
      'Difference = Station − Satellite. A positive number means the station read higher.',
      'Wind is in km/h for both (both report m/s; converted × 3.6). Rain is in mm.',
      if (c.resolution == HistoryResolution.daily)
        'Daily rows are Kenyan days (EAT, UTC+3): temperature, humidity and wind are the average of the day\'s hours, '
            'rain is the day\'s total — each source from its own hours. "Hours" columns show how complete each day was.',
      'NASA POWER publishes data about 2–3 days after the fact, so the latest days have no satellite values.',
      'Rows that only one source has are kept, with the other side left blank.',
      if (c.usedFarmLocation) 'This station reports no location, so satellite data is for the farm\'s location.',
    ];

Uint8List buildHistoryXlsx(HistoryComparison c) {
  final x = XlsxWorkbook(title: historyFileBaseName(c));
  const metrics = HistoryComparison.metrics;
  final daily = c.resolution == HistoryResolution.daily;
  final perMetric = 3;
  final extra = daily ? 2 : 0; // hours columns
  final lastCol = metrics.length * perMetric + extra;
  final subtitle = 'Station: ${c.stationName}   ·   ${_dayFmt.format(c.start)} – ${_dayFmt.format(c.end)} '
      '(${c.days} day${c.days == 1 ? '' : 's'})   ·   ${c.resolution.label}   ·   Generated ${_stamp.format(c.generatedAt)}';

  // ── Summary ───────────────────────────────────────────────────────────────
  final s = x.sheet('Summary', widths: [30, 16, 18, 22, 16, 16, 16]);
  var r = s.row([const XCell('Weather station vs. satellite (NASA POWER)', XStyle.title)]);
  s.merge(r, 0, 6);
  r = s.row([XCell(subtitle, XStyle.subtitle)]);
  s.merge(r, 0, 6);
  s.blank();
  r = s.row([XCell('Over the period  (${c.rows.length} ${daily ? 'days' : 'hours'})', XStyle.label)]);
  s.merge(r, 0, 6);
  s.row(const [
    XCell('Measure', XStyle.header),
    XCell('Pairs compared', XStyle.header),
    XCell('Average difference', XStyle.headerDiff),
    XCell('Average gap (either way)', XStyle.headerDiff),
    XCell('Largest gap', XStyle.headerDiff),
    XCell('Station average', XStyle.headerStation),
    XCell('Satellite average', XStyle.headerSatellite),
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
      XCell(_r(m.stationMean), alt ? XStyle.numberAlt : XStyle.number),
      XCell(_r(m.satelliteMean), alt ? XStyle.numberAlt : XStyle.number),
    ]);
  }
  s.blank();
  r = s.row([const XCell('Notes', XStyle.label)]);
  s.merge(r, 0, 6);
  for (final n in _notes(c)) {
    r = s.row([XCell('•  $n', XStyle.note)]);
    s.merge(r, 0, 6);
  }

  // ── Rows ──────────────────────────────────────────────────────────────────
  final h = x.sheet(daily ? 'Daily comparison' : 'Hourly comparison', widths: [
    24,
    for (var k = 0; k < metrics.length; k++) ...[12, 12, 13],
    if (daily) ...[11, 11],
  ]);
  r = h.row([XCell('Weather station vs. satellite — ${daily ? 'day by day' : 'hour by hour'}', XStyle.title)]);
  h.merge(r, 0, lastCol);
  r = h.row([XCell(subtitle, XStyle.subtitle)]);
  h.merge(r, 0, lastCol);
  h.blank();
  final bandRow = h.row([
    XCell(daily ? 'Day' : 'Hour', XStyle.header),
    for (final m in metrics) ...[
      XCell(m == ComparedMetric.rain && daily ? 'Rain total (mm)' : m.heading, XStyle.header),
      const XCell(null, XStyle.header),
      const XCell(null, XStyle.header),
    ],
    if (daily) ...[const XCell('Hours with data', XStyle.header), const XCell(null, XStyle.header)],
  ]);
  for (var k = 0; k < metrics.length; k++) {
    h.merge(bandRow, 1 + k * 3, 3 + k * 3);
  }
  if (daily) h.merge(bandRow, 1 + metrics.length * 3, 2 + metrics.length * 3);
  final headRow = h.row([
    XCell(daily ? '(Kenyan day)' : '(local time)', XStyle.header),
    for (var k = 0; k < metrics.length; k++) ...const [
      XCell('Station', XStyle.headerStation),
      XCell('Satellite', XStyle.headerSatellite),
      XCell('Difference', XStyle.headerDiff),
    ],
    if (daily) ...const [XCell('Station', XStyle.headerStation), XCell('Satellite', XStyle.headerSatellite)],
  ]);
  h.freezeRows = headRow;
  i = 0;
  for (final row in c.rows) {
    final alt = (i++).isOdd;
    h.row([
      XCell(_when(c, row), alt ? XStyle.textAlt : XStyle.text),
      for (final m in metrics) ...[
        XCell(_r(row.station[m]), alt ? XStyle.numberAlt : XStyle.number),
        XCell(_r(row.satellite[m]), alt ? XStyle.numberAlt : XStyle.number),
        XCell(_r(row.difference(m)), alt ? XStyle.diffAlt : XStyle.diff),
      ],
      if (daily) ...[
        XCell(row.station.hours, alt ? XStyle.numberAlt : XStyle.number),
        XCell(row.satellite.hours, alt ? XStyle.numberAlt : XStyle.number),
      ],
    ]);
  }
  if (c.rows.isNotEmpty) {
    h.autoFilter = 'A$headRow:${colName(lastCol)}${headRow + c.rows.length}';
  } else {
    r = h.row([const XCell('No data from either source for these dates.', XStyle.note)]);
    h.merge(r, 0, lastCol);
  }
  return x.encode();
}

String _csv(Object? v) {
  final s = v == null ? '' : (v is double ? v.toStringAsFixed(1) : '$v');
  return RegExp(r'[",\n]').hasMatch(s) ? '"${s.replaceAll('"', '""')}"' : s;
}

/// The same data as one flat table (UTF-8 with BOM so Excel reads °C).
Uint8List buildHistoryCsv(HistoryComparison c) {
  final b = StringBuffer();
  void line(List<Object?> cells) => b.writeln(cells.map(_csv).join(','));
  final daily = c.resolution == HistoryResolution.daily;
  line(['Weather station vs. satellite (NASA POWER)']);
  line(['Station', c.stationName]);
  line(['From', _day.format(c.start), 'To', _day.format(c.end)]);
  line(['View', c.resolution.label]);
  line(['Generated', _stamp.format(c.generatedAt)]);
  line([]);
  const metrics = HistoryComparison.metrics;
  line([
    daily ? 'Day (EAT)' : 'Hour (local)',
    for (final m in metrics) ...['${m.heading} Station', '${m.heading} Satellite', '${m.heading} Difference'],
    if (daily) ...['Station hours', 'Satellite hours'],
  ]);
  for (final row in c.rows) {
    line([
      daily ? _day.format(row.time) : DateFormat('yyyy-MM-dd HH:00').format(row.time),
      for (final m in metrics) ...[_r(row.station[m]), _r(row.satellite[m]), _r(row.difference(m))],
      if (daily) ...[row.station.hours, row.satellite.hours],
    ]);
  }
  line([]);
  for (final n in _notes(c)) {
    line(['Note', n]);
  }
  return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(b.toString())]);
}
