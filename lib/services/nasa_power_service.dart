// lib/services/nasa_power_service.dart
//
// Fetches satellite agrometeorological data from NASA POWER API
// for the farmer's registered farm county.
//
// ── KEY POINT: LOCATION IS AUTOMATIC ──────────────────────────────────────
// The farmer never selects a location for satellite data.
// FarmLocationService provides the coordinates from their registered county.
// A farmer in Mombasa gets Mombasa satellite data.
// A farmer in Nakuru gets Nakuru satellite data. Always automatic.
//
// ── WHAT DATA IS FETCHED ──────────────────────────────────────────────────
// 13 agricultural parameters:
//
//   WEATHER (pest & disease risk):
//     T2M            Air temperature at 2 m, °C
//     T2M_MAX        Daily max temperature, °C
//     T2M_MIN        Daily min temperature, °C
//     T2MDEW         Dew point, °C  — leaf wetness proxy for fungal risk
//     RH2M           Relative humidity, %
//     PRECTOTCORR    Precipitation (bias-corrected), mm
//     WS2M           Wind speed at 2 m, m/s  — spray timing guidance
//     CLOUD_AMT      Cloud cover, %  — low light = fungal conditions
//     ALLSKY_SFC_UV_INDEX  UV index
//
//   SOIL (field data enrichment):
//     GWETROOT       Root zone soil wetness, 0–1
//     GWETTOP        Surface soil wetness top 5 cm, 0–1
//     TSOIL1         Soil temperature layer 1 (0–9.9 cm), °C
//     ALLSKY_SFC_PAR_TOT  Photosynthetically active radiation, W/m²
//
// ── CACHING ────────────────────────────────────────────────────────────────
//   Today's data:    cached 6 hours  (NASA POWER updates daily)
//   7-day history:   cached 24 hours
//   Stale cache:     returned with isStale=true if API is unreachable
//
// ── API DETAILS ────────────────────────────────────────────────────────────
//   Endpoint: https://power.larc.nasa.gov/api/temporal/daily/point
//   Auth:     None required — free public API
//   Grid:     0.5° × 0.5° (~55 km) — county centroid is precise enough
//   Latency:  ~24 hours (yesterday's data is latest available)

import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kilimomkononi/services/farm_location_service.dart';

// ── Model ──────────────────────────────────────────────────────────────────

class SatelliteReading {
  final DateTime date;
  final FarmLocation farmLocation;
  final double airTemp;
  final double airTempMax;
  final double airTempMin;
  final double dewPoint;
  final double humidity;
  final double precipitation;
  final double windSpeed;
  final double cloudCover;
  final double uvIndex;
  final double rootZoneMoisture;
  final double surfaceMoisture;
  final double soilTempLayer1;
  final double par;
  final bool isStale;

  const SatelliteReading({
    required this.date,
    required this.farmLocation,
    required this.airTemp,
    required this.airTempMax,
    required this.airTempMin,
    required this.dewPoint,
    required this.humidity,
    required this.precipitation,
    required this.windSpeed,
    required this.cloudCover,
    required this.uvIndex,
    required this.rootZoneMoisture,
    required this.surfaceMoisture,
    required this.soilTempLayer1,
    required this.par,
    this.isStale = false,
  });

  static double totalPrecipitation(List<SatelliteReading> readings) =>
      readings.fold(0.0, (s, r) => s + r.precipitation);

  Map<String, dynamic> toMap() => {
    'date':             date.toIso8601String(),
    'county':           farmLocation.county,
    'farmLabel':        farmLocation.displayLabel,
    'farmLat':          farmLocation.latitude,
    'farmLng':          farmLocation.longitude,
    'airTemp':          airTemp,
    'airTempMax':       airTempMax,
    'airTempMin':       airTempMin,
    'dewPoint':         dewPoint,
    'humidity':         humidity,
    'precipitation':    precipitation,
    'windSpeed':        windSpeed,
    'cloudCover':       cloudCover,
    'uvIndex':          uvIndex,
    'rootZoneMoisture': rootZoneMoisture,
    'surfaceMoisture':  surfaceMoisture,
    'soilTempLayer1':   soilTempLayer1,
    'par':              par,
    'isStale':          isStale,
  };
}

// ── Service ────────────────────────────────────────────────────────────────

class NasaPowerService {
  NasaPowerService._();

  static const _baseUrl = 'https://power.larc.nasa.gov/api/temporal/daily/point';

  static const _params = [
    'T2M', 'T2M_MAX', 'T2M_MIN', 'T2MDEW', 'RH2M',
    'PRECTOTCORR', 'WS2M', 'CLOUD_AMT', 'ALLSKY_SFC_UV_INDEX',
    'GWETROOT', 'GWETTOP', 'TSOIL1', 'ALLSKY_SFC_PAR_TOT',
  ];

  // Cache keys — include county so different farmers don't share cache
  static String _todayKey(String county)   => 'nasa_today_$county';
  static String _todayTsKey(String county) => 'nasa_today_ts_$county';
  static String _histKey(String county)    => 'nasa_hist_$county';
  static String _histTsKey(String county)  => 'nasa_hist_ts_$county';

  static const _todayTtl   = Duration(hours: 6);
  static const _historyTtl = Duration(hours: 24);

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns today's satellite reading for the farmer's registered county.
  /// Automatically uses the correct farm location — no user input needed.
  static Future<SatelliteReading?> getToday() async {
    final location = await FarmLocationService.getLocation();
    final prefs    = await SharedPreferences.getInstance();

    final cached = _loadTodayCache(prefs, location);
    if (cached != null) return cached;

    // NASA POWER data has ~24h latency — fetch yesterday if before noon UTC
    final now       = DateTime.now().toUtc();
    final fetchDate = now.hour < 12
        ? now.subtract(const Duration(days: 1))
        : now;

    try {
      final readings = await _fetch(location: location, start: fetchDate, end: fetchDate);
      if (readings.isEmpty) return null;
      _saveTodayCache(prefs, readings.first, location.county);
      return readings.first;
    } catch (_) {
      return _loadTodayCache(prefs, location, allowStale: true);
    }
  }

  /// Returns the last [days] days of satellite data for the farm.
  static Future<List<SatelliteReading>> getHistory({int days = 7}) async {
    final location = await FarmLocationService.getLocation();
    final prefs    = await SharedPreferences.getInstance();

    final cached = _loadHistoryCache(prefs, location, days);
    if (cached != null) return cached;

    final end   = DateTime.now().subtract(const Duration(days: 1));
    final start = end.subtract(Duration(days: days - 1));

    try {
      final readings = await _fetch(location: location, start: start, end: end);
      _saveHistoryCache(prefs, readings, location.county);
      return readings;
    } catch (_) {
      return _loadHistoryCache(prefs, location, days, allowStale: true) ?? [];
    }
  }

  /// Convenience: today + 7-day history in one call.
  static Future<({SatelliteReading? today, List<SatelliteReading> history})>
      getBundle() async {
    final results = await Future.wait([getToday(), getHistory(days: 7)]);
    return (
      today:   results[0] as SatelliteReading?,
      history: results[1] as List<SatelliteReading>,
    );
  }

  /// Force refresh — clears county-specific cache and re-fetches.
  static Future<SatelliteReading?> refresh() async {
    final location = await FarmLocationService.getLocation();
    final prefs    = await SharedPreferences.getInstance();
    await prefs.remove(_todayKey(location.county));
    await prefs.remove(_todayTsKey(location.county));
    await prefs.remove(_histKey(location.county));
    await prefs.remove(_histTsKey(location.county));
    return getToday();
  }

  // ── HTTP fetch ─────────────────────────────────────────────────────────────

  static Future<List<SatelliteReading>> _fetch({
    required FarmLocation location,
    required DateTime start,
    required DateTime end,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl'
      '?parameters=${_params.join(',')}'
      '&community=AG'
      '&longitude=${location.longitude.toStringAsFixed(4)}'
      '&latitude=${location.latitude.toStringAsFixed(4)}'
      '&start=${_fmt(start)}'
      '&end=${_fmt(end)}'
      '&format=JSON',
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw Exception('NASA POWER ${response.statusCode}');
    }

    final body  = jsonDecode(response.body) as Map<String, dynamic>;
    final props = body['properties']?['parameter'] as Map<String, dynamic>?;
    if (props == null) throw Exception('Unexpected NASA POWER format');

    final dates = (props.values.first as Map<String, dynamic>).keys.toList()..sort();
    final readings = <SatelliteReading>[];

    for (final dk in dates) {
      final d = _parseDate(dk);
      if (d == null) continue;

      double g(String p) {
        final v = props[p]?[dk];
        if (v == null) return 0;
        final n = v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
        return n < -900 ? 0 : n;
      }

      readings.add(SatelliteReading(
        date:             d,
        farmLocation:     location,
        airTemp:          _r(g('T2M'),          1),
        airTempMax:       _r(g('T2M_MAX'),      1),
        airTempMin:       _r(g('T2M_MIN'),      1),
        dewPoint:         _r(g('T2MDEW'),       1),
        humidity:         _r(g('RH2M'),         1),
        precipitation:    _r(g('PRECTOTCORR'),  2),
        windSpeed:        _r(g('WS2M'),         1),
        cloudCover:       _r(g('CLOUD_AMT'),    1),
        uvIndex:          _r(g('ALLSKY_SFC_UV_INDEX'), 1),
        rootZoneMoisture: _r(g('GWETROOT'),     3),
        surfaceMoisture:  _r(g('GWETTOP'),      3),
        soilTempLayer1:   _r(g('TSOIL1'),       1),
        par:              _r(g('ALLSKY_SFC_PAR_TOT'), 1),
      ));
    }
    return readings;
  }

  // ── Cache ──────────────────────────────────────────────────────────────────

  static SatelliteReading? _loadTodayCache(
    SharedPreferences prefs, FarmLocation location, {bool allowStale = false}
  ) {
    final ts  = prefs.getInt(_todayTsKey(location.county));
    final raw = prefs.getString(_todayKey(location.county));
    if (ts == null || raw == null) return null;
    final age = DateTime.now().millisecondsSinceEpoch - ts;
    if (!allowStale && age > _todayTtl.inMilliseconds) return null;
    try {
      return _fromMap(jsonDecode(raw) as Map<String, dynamic>, location,
          isStale: allowStale && age > _todayTtl.inMilliseconds);
    } catch (_) { return null; }
  }

  static void _saveTodayCache(SharedPreferences prefs, SatelliteReading r, String county) {
    prefs.setString(_todayKey(county), jsonEncode(r.toMap()));
    prefs.setInt(_todayTsKey(county), DateTime.now().millisecondsSinceEpoch);
  }

  static List<SatelliteReading>? _loadHistoryCache(
    SharedPreferences prefs, FarmLocation location, int days, {bool allowStale = false}
  ) {
    final ts  = prefs.getInt(_histTsKey(location.county));
    final raw = prefs.getString(_histKey(location.county));
    if (ts == null || raw == null) return null;
    final age = DateTime.now().millisecondsSinceEpoch - ts;
    if (!allowStale && age > _historyTtl.inMilliseconds) return null;
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => _fromMap(e as Map<String, dynamic>, location,
              isStale: allowStale && age > _historyTtl.inMilliseconds))
          .toList();
    } catch (_) { return null; }
  }

  static void _saveHistoryCache(
      SharedPreferences prefs, List<SatelliteReading> readings, String county) {
    prefs.setString(_histKey(county), jsonEncode(readings.map((r) => r.toMap()).toList()));
    prefs.setInt(_histTsKey(county), DateTime.now().millisecondsSinceEpoch);
  }

  static SatelliteReading _fromMap(Map<String, dynamic> m, FarmLocation loc,
      {bool isStale = false}) {
    double g(String k) => (m[k] as num?)?.toDouble() ?? 0;
    return SatelliteReading(
      date:             DateTime.tryParse(m['date'] as String? ?? '') ?? DateTime.now(),
      farmLocation:     loc,
      airTemp:          g('airTemp'),
      airTempMax:       g('airTempMax'),
      airTempMin:       g('airTempMin'),
      dewPoint:         g('dewPoint'),
      humidity:         g('humidity'),
      precipitation:    g('precipitation'),
      windSpeed:        g('windSpeed'),
      cloudCover:       g('cloudCover'),
      uvIndex:          g('uvIndex'),
      rootZoneMoisture: g('rootZoneMoisture'),
      surfaceMoisture:  g('surfaceMoisture'),
      soilTempLayer1:   g('soilTempLayer1'),
      par:              g('par'),
      isStale:          isStale,
    );
  }

  // ── Utilities ──────────────────────────────────────────────────────────────

  static String _fmt(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2,'0')}${d.day.toString().padLeft(2,'0')}';

  static DateTime? _parseDate(String s) {
    if (s.length != 8) return null;
    try {
      return DateTime(int.parse(s.substring(0,4)),
          int.parse(s.substring(4,6)), int.parse(s.substring(6,8)));
    } catch (_) { return null; }
  }

  static double _r(double v, int d) {
    final f = pow(10, d).toDouble();
    return (v * f).round() / f;
  }
}