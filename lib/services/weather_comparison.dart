// lib/services/weather_comparison.dart
//
// Google's weather vs. the farm's own weather station, side by side — for
// the Weather screen's "Compare with weather station" view and its Excel /
// CSV download (lib/utils/weather_comparison_export.dart).
//
//   Now        Google current conditions vs. the station's latest reading
//   Hourly     the last 24 h, hour by hour: Google's recorded history
//              (history/hours:lookup) vs. the station's hourly readings —
//              both RECORDED values, at the station's own location, so the
//              pairs compare like with like (a forecast would not).
//
// Units: °C, %, km/h (station wind is m/s → × 3.6), mm. Difference =
// station − Google.

import 'package:kilimomkononi/services/farm_location_service.dart';
import 'package:kilimomkononi/services/google_weather_service.dart';
import 'package:kilimomkononi/services/nuasense_service.dart';

/// One measured quantity in the comparison.
enum ComparedMetric {
  temp('Temperature', '°C'),
  humidity('Humidity', '%'),
  dewPoint('Dew point', '°C'),
  wind('Wind speed', 'km/h'),
  gust('Wind gusts', 'km/h'),
  rain('Rain', 'mm');

  final String label;
  final String unit;
  const ComparedMetric(this.label, this.unit);

  String get heading => '$label ($unit)';
}

/// Google vs. station for one metric (either side may be missing).
class MetricPair {
  final double? google;
  final double? station;
  const MetricPair(this.google, this.station);

  /// Station − Google, or null when either is missing.
  double? get difference => google == null || station == null ? null : station! - google!;
}

/// One hour (or "now") of paired values.
class ComparisonRow {
  final DateTime time;
  final Map<ComparedMetric, MetricPair> values;
  const ComparisonRow(this.time, this.values);

  MetricPair operator [](ComparedMetric m) => values[m] ?? const MetricPair(null, null);

  bool get hasGoogle => values.values.any((p) => p.google != null);
  bool get hasStation => values.values.any((p) => p.station != null);
}

/// How far apart the two sources were over the hourly rows.
class MetricSummary {
  final ComparedMetric metric;
  final int pairs;

  /// Average of (station − Google): + = the station reads higher.
  final double? meanDifference;

  /// Average size of the gap, ignoring direction.
  final double? meanAbsDifference;
  final double? maxAbsDifference;

  const MetricSummary(this.metric, this.pairs, this.meanDifference, this.meanAbsDifference, this.maxAbsDifference);
}

class WeatherComparison {
  final String stationName;
  final String? gatewayId;
  final String place;
  final double? lat;
  final double? lon;

  /// True when the station had no coordinates and the farm's were used.
  final bool usedFarmLocation;
  final DateTime generatedAt;
  final ComparisonRow? now;
  final List<ComparisonRow> hourly;

  const WeatherComparison({
    required this.stationName,
    this.gatewayId,
    required this.place,
    this.lat,
    this.lon,
    this.usedFarmLocation = false,
    required this.generatedAt,
    this.now,
    this.hourly = const [],
  });

  /// Metrics shown hour by hour (the station's hourly series has no dew
  /// point or gusts — those are in the "now" comparison).
  static const hourlyMetrics = [ComparedMetric.temp, ComparedMetric.humidity, ComparedMetric.wind, ComparedMetric.rain];

  List<MetricSummary> get summaries => [
    for (final m in hourlyMetrics) summarise(m, hourly),
  ];

  static MetricSummary summarise(ComparedMetric m, List<ComparisonRow> rows) {
    final diffs = rows.map((r) => r[m].difference).whereType<double>().toList();
    if (diffs.isEmpty) return MetricSummary(m, 0, null, null, null);
    final abs = diffs.map((d) => d.abs()).toList();
    return MetricSummary(
      m,
      diffs.length,
      diffs.reduce((a, b) => a + b) / diffs.length,
      abs.reduce((a, b) => a + b) / abs.length,
      abs.reduce((a, b) => a > b ? a : b),
    );
  }
}

const _msToKmh = 3.6;

/// Start of the hour in UTC — how the two sources' hours are matched.
DateTime _hourKey(DateTime t) {
  final u = t.toUtc();
  return DateTime.utc(u.year, u.month, u.day, u.hour);
}

/// Pairs Google's history with the station's hourly readings by hour
/// (oldest first). Hours only one side has are kept, with the other blank.
List<ComparisonRow> pairHourly(List<GoogleHistoryHour> google, List<NuaSenseHourPoint> station) {
  final g = {for (final h in google) _hourKey(h.time): h};
  final s = {for (final p in station) _hourKey(p.time): p};
  final hours = {...g.keys, ...s.keys}.toList()..sort();
  return [
    for (final h in hours)
      ComparisonRow(h.toLocal(), {
        ComparedMetric.temp: MetricPair(g[h]?.temp, s[h]?.airTemp),
        ComparedMetric.humidity: MetricPair(g[h]?.humidity.toDouble(), s[h]?.humidity),
        ComparedMetric.wind: MetricPair(g[h]?.windKmh, s[h] == null ? null : s[h]!.windSpeed * _msToKmh),
        ComparedMetric.rain: MetricPair(g[h]?.rainMm, s[h]?.rainfall),
      }),
  ];
}

/// Google current conditions vs. the station's latest reading.
ComparisonRow pairNow(GoogleCurrentWeather? google, NuaSenseReading? station) {
  final st = station != null && station.isProvisioned && station.hasData ? station : null;
  return ComparisonRow(st?.timestamp.toLocal() ?? DateTime.now(), {
    ComparedMetric.temp: MetricPair(google?.temp, st?.airTemp),
    ComparedMetric.humidity: MetricPair(google?.humidity.toDouble(), st?.humidity),
    ComparedMetric.dewPoint: MetricPair(google?.dewPoint, st?.dewPoint),
    ComparedMetric.wind: MetricPair(google?.windKmh, st == null ? null : st.windSpeed * _msToKmh),
    ComparedMetric.gust: MetricPair(google?.gustKmh, st == null ? null : st.windGusts * _msToKmh),
    ComparedMetric.rain: MetricPair(google?.rainMm, st?.rainfall),
  });
}

class NoStationForComparison implements Exception {
  @override
  String toString() =>
      'Your account isn\'t connected to a weather station yet, so there is nothing to compare with. '
      'Ask the Kilimo Mkononi team to connect your farm\'s station.';
}

class WeatherComparisonService {
  WeatherComparisonService._();

  /// Builds the comparison for the station of the farm in view (the
  /// farmer's own choice — see StationPreferences), at the station's
  /// location (the farm's, if the station reports none).
  static Future<WeatherComparison> build({String? stationId}) async {
    final plot = await FarmLocationService.getSelectedPlotId();
    final stations = await NuaSenseService.getStations();
    if (stations.isEmpty) throw NoStationForComparison();
    final id = stationId ?? await NuaSenseService.stationIdForPlot(plot);
    final station = stations.where((s) => s.id == id).firstOrNull ?? stations.first;

    double? lat = station.lat;
    double? lon = station.lon;
    var usedFarm = false;
    var place = '';
    if (lat == null || lon == null) {
      final farm = await FarmLocationService.getLocation();
      lat = farm.latitude;
      lon = farm.longitude;
      place = farm.displayLabel;
      usedFarm = true;
    }

    final results = await Future.wait<Object?>([
      NuaSenseService.getLatestReading(stationId: station.id).then<Object?>((r) => r).catchError((_) => null),
      NuaSenseService.get24hHistory(stationId: station.id).then<Object?>((r) => r).catchError((_) => const <NuaSenseHourPoint>[]),
      GoogleWeatherService.forLocation(lat, lon).then<Object?>((r) => r).catchError((_) => null),
      GoogleWeatherService.historyForLocation(lat, lon).then<Object?>((r) => r).catchError((_) => const <GoogleHistoryHour>[]),
      if (!usedFarm) GoogleWeatherService.placeName(lat, lon),
    ]);
    final reading = results[0] as NuaSenseReading?;
    final history = results[1] as List<NuaSenseHourPoint>;
    final google = results[2] as GoogleWeather?;
    final googleHistory = results[3] as List<GoogleHistoryHour>;
    if (!usedFarm) place = (results[4] as String?) ?? 'the station area';

    return WeatherComparison(
      stationName: station.name,
      gatewayId: station.id,
      place: place,
      lat: lat,
      lon: lon,
      usedFarmLocation: usedFarm,
      generatedAt: DateTime.now(),
      now: pairNow(google?.current, reading),
      hourly: pairHourly(googleHistory, history),
    );
  }
}
