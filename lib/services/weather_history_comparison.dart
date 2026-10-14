// lib/services/weather_history_comparison.dart
//
// PAST dates: a weather station's recorded data next to NASA POWER satellite
// data for the same place — the Weather comparison screen's "Past dates"
// view and its Excel / CSV downloads (lib/utils/weather_history_export.dart).
// Data comes from the `weatherHistory` Cloud Function
// (functions/weather_history.js); farmers compare their own stations, Field
// Agronomists / admins any station (NuaSenseService.seesAllStations).
//
//   Hourly   one row per hour (UTC hours, shown in local time)
//   Daily    one row per Kenyan day (EAT, UTC+3): temperature, humidity and
//            wind are the average of that day's hours, rain is the total.
//            Both sources are averaged the same way, from their hours.
//
// Accuracy: station values are exactly what the station recorded (saved
// permanently server-side, weatherArchive), satellite values exactly what NASA
// POWER published; nothing is estimated. Readings from before the station's
// in-service date are never included.
//
// Units: °C, %, km/h (both report m/s → × 3.6), mm.
// Difference = station − satellite. NASA POWER runs ~2–3 days behind, so the
// latest days have no satellite value.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:kilimomkononi/services/nuasense_service.dart';
import 'package:kilimomkononi/services/weather_comparison.dart' show ComparedMetric;

enum HistoryResolution {
  hourly('Hour by hour'),
  daily('Day by day');

  final String label;
  const HistoryResolution(this.label);
}

/// Ranges up to this many days can be shown hour by hour.
const kMaxHourlyDays = 31;

/// Kenya (EAT) has no daylight saving: days run 21:00–21:00 UTC.
const kEatOffset = Duration(hours: 3);

/// One source's values for an hour or a day.
class HistoryValues {
  final double? temp;
  final double? humidity;

  /// km/h
  final double? wind;

  /// mm in the hour / total for the day
  final double? rain;

  /// Hours behind this value (1 for an hourly row).
  final int hours;

  const HistoryValues({this.temp, this.humidity, this.wind, this.rain, this.hours = 0});

  double? operator [](ComparedMetric m) => switch (m) {
        ComparedMetric.temp => temp,
        ComparedMetric.humidity => humidity,
        ComparedMetric.wind => wind,
        ComparedMetric.rain => rain,
        _ => null,
      };

  bool get isEmpty => temp == null && humidity == null && wind == null && rain == null;

  static const none = HistoryValues();
}

/// One hour / day: station and satellite side by side.
class HistoryRow {
  /// Local time: the hour, or midnight of the (EAT) day.
  final DateTime time;
  final HistoryValues station;
  final HistoryValues satellite;
  const HistoryRow(this.time, this.station, this.satellite);

  /// Station − satellite, or null when either is missing.
  double? difference(ComparedMetric m) {
    final s = station[m];
    final r = satellite[m];
    return s == null || r == null ? null : s - r;
  }
}

class HistorySummary {
  final ComparedMetric metric;
  final int pairs;
  final double? meanDifference;
  final double? meanAbsDifference;
  final double? maxAbsDifference;
  final double? stationMean;
  final double? satelliteMean;

  const HistorySummary(this.metric, this.pairs, this.meanDifference, this.meanAbsDifference, this.maxAbsDifference,
      this.stationMean, this.satelliteMean);
}

class StationHistoryRange {
  final DateTime first;
  final DateTime last;
  final int maxSpanDays;

  /// The day the station went into service on the farm (readings before it
  /// are never shown); null when the admin hasn't set it.
  final DateTime? inServiceFrom;

  /// Time of the station's latest recorded reading.
  final DateTime? latestReading;

  const StationHistoryRange(this.first, this.last, this.maxSpanDays, {this.inServiceFrom, this.latestReading});
}

class HistoryComparison {
  final String stationName;
  final String? gatewayId;
  final DateTime start;

  /// Last day included.
  final DateTime end;
  final HistoryResolution resolution;
  final List<HistoryRow> rows;

  /// Satellite data could be fetched at all (false: no location, or NASA
  /// POWER was unreachable).
  final bool satelliteAvailable;

  /// Last hour with satellite data (local time), if any.
  final DateTime? satelliteLatest;
  final bool usedFarmLocation;
  final DateTime generatedAt;

  /// Latest recorded station hour in the range (local time).
  final DateTime? stationLatest;

  /// In-service date of the station, and whether the requested range was
  /// trimmed to start there.
  final DateTime? inServiceFrom;
  final bool clippedToService;

  /// The hours both views are built from (switching view needs no download).
  final List<SourceHour> stationHours;
  final List<SourceHour> satelliteHours;

  const HistoryComparison({
    required this.stationName,
    this.gatewayId,
    required this.start,
    required this.end,
    required this.resolution,
    required this.rows,
    this.satelliteAvailable = true,
    this.satelliteLatest,
    this.usedFarmLocation = false,
    required this.generatedAt,
    this.stationLatest,
    this.inServiceFrom,
    this.clippedToService = false,
    this.stationHours = const [],
    this.satelliteHours = const [],
  });

  /// The same data hour by hour or day by day.
  HistoryComparison withResolution(HistoryResolution r) => r == resolution
      ? this
      : HistoryComparison(
          stationName: stationName,
          gatewayId: gatewayId,
          start: start,
          end: end,
          resolution: r,
          rows: r == HistoryResolution.hourly
              ? pairHourly(stationHours, satelliteHours)
              : pairDaily(stationHours, satelliteHours),
          satelliteAvailable: satelliteAvailable,
          satelliteLatest: satelliteLatest,
          usedFarmLocation: usedFarmLocation,
          generatedAt: generatedAt,
          stationLatest: stationLatest,
          inServiceFrom: inServiceFrom,
          clippedToService: clippedToService,
          stationHours: stationHours,
          satelliteHours: satelliteHours,
        );

  static const metrics = [ComparedMetric.temp, ComparedMetric.humidity, ComparedMetric.wind, ComparedMetric.rain];

  int get days => end.difference(start).inDays + 1;

  List<HistorySummary> get summaries => [for (final m in metrics) summarise(m, rows)];

  static HistorySummary summarise(ComparedMetric m, List<HistoryRow> rows) {
    double? mean(Iterable<double> v) => v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
    final diffs = rows.map((r) => r.difference(m)).whereType<double>().toList();
    final abs = diffs.map((d) => d.abs());
    return HistorySummary(
      m,
      diffs.length,
      mean(diffs),
      mean(abs),
      abs.isEmpty ? null : abs.reduce((a, b) => a > b ? a : b),
      mean(rows.map((r) => r.station[m]).whereType<double>()),
      mean(rows.map((r) => r.satellite[m]).whereType<double>()),
    );
  }
}

// ── Pairing (pure; test/weather_history_comparison_test.dart) ────────────────

/// One source's hour as sent by the function (wind in m/s).
class SourceHour {
  final DateTime utc;
  final double? temp;
  final double? humidity;
  final double? windMs;
  final double? rain;
  const SourceHour(this.utc, {this.temp, this.humidity, this.windMs, this.rain});

  static SourceHour? fromMap(Object? o) {
    if (o is! Map) return null;
    final t = o['t'];
    if (t is! num) return null;
    double? n(String k) => (o[k] as num?)?.toDouble();
    return SourceHour(DateTime.fromMillisecondsSinceEpoch(t.toInt(), isUtc: true),
        temp: n('temp'), humidity: n('humidity'), windMs: n('wind'), rain: n('rain'));
  }

  HistoryValues get values => HistoryValues(
        temp: temp,
        humidity: humidity,
        wind: windMs == null ? null : windMs! * 3.6,
        rain: rain,
        hours: 1,
      );
}

DateTime _hourKey(DateTime t) => DateTime.utc(t.year, t.month, t.day, t.hour);

/// The EAT calendar day of a UTC instant, as a UTC-midnight key.
DateTime eatDay(DateTime utc) {
  final e = utc.toUtc().add(kEatOffset);
  return DateTime.utc(e.year, e.month, e.day);
}

/// Hour by hour; hours only one source has are kept, the other side blank.
List<HistoryRow> pairHourly(List<SourceHour> station, List<SourceHour> satellite) {
  final s = {for (final h in station) _hourKey(h.utc): h};
  final r = {for (final h in satellite) _hourKey(h.utc): h};
  final keys = {...s.keys, ...r.keys}.toList()..sort();
  return [
    for (final k in keys)
      HistoryRow(k.toLocal(), s[k]?.values ?? HistoryValues.none, r[k]?.values ?? HistoryValues.none),
  ];
}

/// Averages (rain: total) one source's hours per EAT day.
Map<DateTime, HistoryValues> dailyValues(List<SourceHour> hours) {
  final by = <DateTime, List<SourceHour>>{};
  for (final h in hours) {
    (by[eatDay(h.utc)] ??= []).add(h);
  }
  double? avg(Iterable<double?> v) {
    final x = v.whereType<double>().toList();
    return x.isEmpty ? null : x.reduce((a, b) => a + b) / x.length;
  }

  double? sum(Iterable<double?> v) {
    final x = v.whereType<double>().toList();
    return x.isEmpty ? null : x.reduce((a, b) => a + b);
  }

  return {
    for (final e in by.entries)
      e.key: HistoryValues(
        temp: avg(e.value.map((h) => h.temp)),
        humidity: avg(e.value.map((h) => h.humidity)),
        wind: (() {
          final w = avg(e.value.map((h) => h.windMs));
          return w == null ? null : w * 3.6;
        })(),
        rain: sum(e.value.map((h) => h.rain)),
        hours: e.value.length,
      ),
  };
}

/// Day by day (EAT days), each source averaged from its own hours.
List<HistoryRow> pairDaily(List<SourceHour> station, List<SourceHour> satellite) {
  final s = dailyValues(station);
  final r = dailyValues(satellite);
  final keys = {...s.keys, ...r.keys}.toList()..sort();
  return [
    for (final k in keys)
      HistoryRow(DateTime(k.year, k.month, k.day), s[k] ?? HistoryValues.none, r[k] ?? HistoryValues.none),
  ];
}

/// Builds the comparison from the function's response.
HistoryComparison historyFromResponse(
  Map<String, dynamic> m, {
  required HistoryResolution resolution,
  String? gatewayId,
  DateTime? now,
}) {
  List<SourceHour> hours(Object? v) =>
      (v is List ? v : const []).map(SourceHour.fromMap).whereType<SourceHour>().toList();
  final station = hours(m['station']);
  final satellite = hours(m['satellite']);
  DateTime day(Object? s) {
    final p = DateTime.tryParse('${s ?? ''}');
    return p == null ? DateTime.now() : DateTime(p.year, p.month, p.day);
  }

  final latest = m['satelliteLatest'];
  final stationLatest = m['stationLatest'];
  final inService = DateTime.tryParse('${m['inServiceFrom'] ?? ''}');
  return HistoryComparison(
    stationName: '${m['stationName'] ?? 'Weather station'}',
    gatewayId: gatewayId,
    start: day(m['start']),
    end: day(m['end']),
    resolution: resolution,
    rows: resolution == HistoryResolution.hourly ? pairHourly(station, satellite) : pairDaily(station, satellite),
    satelliteAvailable: m['satelliteAvailable'] != false,
    satelliteLatest: latest is num ? DateTime.fromMillisecondsSinceEpoch(latest.toInt()) : null,
    usedFarmLocation: m['usedFarmLocation'] == true,
    generatedAt: now ?? DateTime.now(),
    stationLatest: stationLatest is num ? DateTime.fromMillisecondsSinceEpoch(stationLatest.toInt()) : null,
    inServiceFrom: inService == null ? null : DateTime(inService.year, inService.month, inService.day),
    clippedToService: m['clippedToService'] == true,
    stationHours: station,
    satelliteHours: satellite,
  );
}

// ── Service ───────────────────────────────────────────────────────────────────

class WeatherHistoryService {
  WeatherHistoryService._();

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<Map<String, dynamic>> _call(Map<String, dynamic> data) async {
    // Agronomists / admins: any station, from every screen (the server checks).
    if (data['scope'] == null && await NuaSenseService.seesAllStations()) data = {...data, 'scope': 'all'};
    final res = await FirebaseFunctions.instance
        .httpsCallable('weatherHistory', options: HttpsCallableOptions(timeout: const Duration(seconds: 120)))
        .call<Object?>(data);
    final out = res.data;
    return out is Map ? out.map((k, v) => MapEntry('$k', v)) : <String, dynamic>{};
  }

  /// Dates the station has data for.
  static Future<StationHistoryRange> range(String gatewayId, {bool allStations = false}) async {
    final m = await _call({'action': 'range', 'gatewayId': gatewayId, if (allStations) 'scope': 'all'});
    final now = DateTime.now();
    final first = DateTime.tryParse('${m['minDate']}') ?? now.subtract(const Duration(days: 365));
    final last = DateTime.tryParse('${m['maxDate']}') ?? now;
    final inService = DateTime.tryParse('${m['inServiceFrom'] ?? ''}');
    return StationHistoryRange(
      DateTime(first.year, first.month, first.day),
      DateTime(last.year, last.month, last.day),
      (m['maxSpanDays'] as num?)?.toInt() ?? 366,
      inServiceFrom: inService == null ? null : DateTime(inService.year, inService.month, inService.day),
      latestReading: DateTime.tryParse('${m['latestReading'] ?? ''}')?.toLocal(),
    );
  }

  /// The station vs satellite for [start]–[end] (whole days, inclusive).
  /// [farmLat]/[farmLon] are only used for a station without coordinates.
  static Future<HistoryComparison> compare({
    required String gatewayId,
    required DateTime start,
    required DateTime end,
    required HistoryResolution resolution,
    bool allStations = false,
    double? farmLat,
    double? farmLon,
  }) async {
    final m = await _call({
      'action': 'compare',
      'gatewayId': gatewayId,
      'start': _ymd(start),
      'end': _ymd(end),
      if (allStations) 'scope': 'all',
      if (farmLat != null && farmLon != null) ...{'farmLat': farmLat, 'farmLon': farmLon},
    });
    return historyFromResponse(m, resolution: resolution, gatewayId: gatewayId);
  }
}
