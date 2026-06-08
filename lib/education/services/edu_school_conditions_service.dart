// lib/education/services/edu_school_conditions_service.dart
//
// Fetches satellite (NASA POWER) + IoT sensor data for a school's location.
// Education-only — zero dependency on enterprise services.
//
// ── ENTERPRISE vs EDUCATION ────────────────────────────────────────────────
// Enterprise: FarmLocationService → NasaPowerService → IotSensorService
//   Uses: Users/{uid} for GPS, iot_nodes/{nodeId} tagged by county+farmerId
//
// Education:  EduFarmLocationService → EduSchoolConditionsService
//   Uses: Schools/{schoolId} for GPS, iot_nodes/{nodeId} tagged by schoolName
//   NASA POWER called directly with school lat/lng — no shared cache with enterprise.
//
// ── NASA POWER (education path) ───────────────────────────────────────────
// Called directly with school GPS coordinates.
// Does NOT go through FarmLocationService or SharedPreferences — the school
// GPS is kept entirely separate from the farmer's cached location.
//
// ── IOT SENSOR (education path) ───────────────────────────────────────────
// Phase 1: Returns realistic simulated data for the school's county.
//   Reuses the same regional data table as IotSensorService but instantiates
//   it independently so no static state is shared.
// Phase 2: Reads from iot_nodes where schoolName == schoolName.
//
// ── CACHING ───────────────────────────────────────────────────────────────
// In-memory cache per schoolId. TTL: 6 hours (same as NASA POWER).
// Cleared on sign-out via EduSchoolConditionsService.clearAll().

// ignore_for_file: unused_import

import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kilimomkononi/education/services/edu_farm_location_service.dart';

// ── Satellite reading model (education-namespaced) ─────────────────────────

class EduSatelliteReading {
  final DateTime date;
  final String county;
  final String schoolName;
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

  const EduSatelliteReading({
    required this.date,
    required this.county,
    required this.schoolName,
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

  static double totalPrecipitation(List<EduSatelliteReading> readings) =>
      readings.fold(0.0, (s, r) => s + r.precipitation);
}

// ── IoT reading model (education-namespaced) ───────────────────────────────

class EduIotReading {
  final String nodeLabel;
  final DateTime timestamp;
  final double n;           // mg/kg
  final double p;           // mg/kg
  final double k;           // mg/kg
  final double ph;
  final double temperature; // °C
  final double humidity;    // %
  final double ec;          // µS/cm
  final bool isSimulated;

  const EduIotReading({
    required this.nodeLabel,
    required this.timestamp,
    required this.n,
    required this.p,
    required this.k,
    required this.ph,
    required this.temperature,
    required this.humidity,
    required this.ec,
    required this.isSimulated,
  });
}

// ── Bundle returned to widgets ─────────────────────────────────────────────

class EduConditionsBundle {
  final EduSatelliteReading? sat;
  final EduIotReading? iot;
  final double rain7d;
  final EduSchoolLocation location;

  const EduConditionsBundle({
    required this.sat,
    required this.iot,
    required this.rain7d,
    required this.location,
  });

  bool get hasData => sat != null || iot != null;
}

// ── Regional simulated soil data (duplicated from enterprise for independence)
// Representative N/P/K/pH/temp/humidity/EC values per Kenya county.
// Source: published soil health data for Kenyan agricultural zones.

const Map<String, List<double>> _eduRegionData = {
  'Nairobi City': [18.2, 12.4, 95.0, 6.2, 22.1, 62.0, 145.0],
  'Kiambu':       [22.5, 14.8, 110.0, 6.4, 21.5, 65.0, 132.0],
  'Murang\'a':    [24.1, 13.2, 105.0, 6.1, 20.8, 68.0, 128.0],
  'Kirinyaga':    [26.3, 15.6, 118.0, 6.3, 20.2, 70.0, 140.0],
  'Nyeri':        [21.8, 13.9, 102.0, 6.2, 19.5, 67.0, 135.0],
  'Nyandarua':    [19.4, 11.8, 98.0,  5.9, 17.2, 72.0, 118.0],
  'Nakuru':       [20.6, 13.1, 108.0, 6.5, 23.4, 58.0, 155.0],
  'Laikipia':     [14.2, 8.6,  78.0,  6.8, 24.8, 42.0, 190.0],
  'Narok':        [16.8, 10.2, 88.0,  6.6, 22.6, 52.0, 162.0],
  'Kajiado':      [10.4, 6.8,  62.0,  7.1, 27.3, 35.0, 225.0],
  'Kericho':      [28.4, 16.2, 125.0, 5.8, 19.8, 75.0, 122.0],
  'Bomet':        [26.1, 15.4, 120.0, 5.9, 20.1, 73.0, 128.0],
  'Baringo':      [12.8, 7.4,  72.0,  7.2, 28.6, 38.0, 210.0],
  'West Pokot':   [11.6, 6.9,  68.0,  6.9, 26.4, 44.0, 195.0],
  'Elgeyo Marakwet': [18.4, 11.5, 95.0, 6.3, 22.0, 60.0, 148.0],
  'Uasin Gishu':  [23.8, 14.5, 112.0, 6.2, 21.2, 64.0, 138.0],
  'Nandi':        [25.2, 15.1, 115.0, 6.0, 20.6, 68.0, 130.0],
  'Trans Nzoia':  [27.6, 16.8, 122.0, 6.1, 21.0, 66.0, 125.0],
  'Kakamega':     [22.4, 11.8, 92.0,  5.6, 24.2, 72.0, 115.0],
  'Vihiga':       [21.8, 11.2, 88.0,  5.7, 23.8, 74.0, 112.0],
  'Bungoma':      [24.6, 13.4, 98.0,  5.8, 23.5, 70.0, 118.0],
  'Busia':        [20.2, 10.8, 85.0,  5.9, 25.4, 68.0, 125.0],
  'Kisumu':       [18.6, 10.4, 82.0,  6.4, 26.8, 65.0, 138.0],
  'Siaya':        [17.4, 9.8,  78.0,  6.5, 26.2, 64.0, 142.0],
  'Homa Bay':     [16.8, 9.4,  75.0,  6.6, 27.4, 62.0, 148.0],
  'Migori':       [19.2, 10.6, 84.0,  6.3, 26.6, 66.0, 135.0],
  'Kisii':        [24.8, 13.8, 105.0, 5.8, 22.4, 72.0, 122.0],
  'Nyamira':      [23.6, 13.2, 102.0, 5.9, 22.1, 73.0, 125.0],
  'Machakos':     [12.4, 7.2,  68.0,  6.8, 26.8, 40.0, 205.0],
  'Kitui':        [10.8, 6.4,  58.0,  7.0, 28.2, 35.0, 225.0],
  'Makueni':      [11.6, 6.8,  62.0,  7.1, 28.8, 34.0, 230.0],
  'Embu':         [22.8, 14.2, 108.0, 6.2, 22.4, 63.0, 140.0],
  'Meru':         [24.4, 14.8, 112.0, 6.1, 21.8, 62.0, 135.0],
  'Tharaka Nithi':[18.6, 11.4, 92.0,  6.4, 24.2, 55.0, 158.0],
  'Mombasa':      [8.4,  5.2,  48.0,  7.2, 31.8, 75.0, 285.0],
  'Kwale':        [9.2,  5.8,  52.0,  7.1, 30.4, 72.0, 265.0],
  'Kilifi':       [8.8,  5.4,  50.0,  7.2, 31.2, 70.0, 275.0],
  'Taita Taveta': [14.6, 8.8,  75.0,  6.8, 27.6, 52.0, 195.0],
  'Tana River':   [8.2,  4.8,  44.0,  7.4, 32.4, 42.0, 310.0],
  'Lamu':         [7.8,  4.6,  42.0,  7.5, 32.8, 76.0, 320.0],
  'Garissa':      [6.2,  3.8,  35.0,  7.8, 34.6, 28.0, 385.0],
  'Wajir':        [5.4,  3.2,  30.0,  8.0, 35.8, 24.0, 420.0],
  'Mandera':      [5.0,  3.0,  28.0,  8.1, 36.4, 22.0, 445.0],
  'Marsabit':     [7.6,  4.4,  42.0,  7.6, 30.2, 38.0, 295.0],
  'Isiolo':       [8.8,  5.2,  48.0,  7.4, 29.8, 36.0, 268.0],
  'Samburu':      [9.4,  5.6,  52.0,  7.3, 28.4, 40.0, 248.0],
  'Turkana':      [5.8,  3.4,  32.0,  7.9, 36.2, 20.0, 405.0],
};

const List<double> _eduDefaultData = [15.0, 10.0, 85.0, 6.5, 25.0, 55.0, 175.0];

// ── Service ────────────────────────────────────────────────────────────────

class EduSchoolConditionsService {
  EduSchoolConditionsService._();

  static const _baseUrl =
      'https://power.larc.nasa.gov/api/temporal/daily/point';
  static const _params = [
    'T2M', 'T2M_MAX', 'T2M_MIN', 'T2MDEW', 'RH2M',
    'PRECTOTCORR', 'WS2M', 'CLOUD_AMT', 'ALLSKY_SFC_UV_INDEX',
    'GWETROOT', 'GWETTOP', 'TSOIL1', 'ALLSKY_SFC_PAR_TOT',
  ];

  // Separate in-memory cache — never shared with enterprise NasaPowerService
  static final Map<String, _CachedBundle> _cache = {};
  static const _ttl = Duration(hours: 6);

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns conditions bundle for a school.
  /// Never throws — returns bundle with nulls if everything fails.
  static Future<EduConditionsBundle> getBundle(String schoolName) async {
    // Check cache
    final cached = _cache[schoolName];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _ttl) {
      return cached.bundle;
    }

    // Resolve school location independently
    final location = await EduFarmLocationService.getLocation(
        schoolName: schoolName);

    // Fetch satellite data directly — no shared state with enterprise
    EduSatelliteReading? today;
    List<EduSatelliteReading> history = [];
    try {
      final now        = DateTime.now().toUtc();
      final fetchDate  = now.hour < 12
          ? now.subtract(const Duration(days: 1))
          : now;
      today   = await _fetchOne(location, fetchDate);
      history = await _fetchRange(
          location,
          fetchDate.subtract(const Duration(days: 6)),
          fetchDate.subtract(const Duration(days: 1)));
    } catch (_) {}

    // IoT sensor for school
    final iot = _simulatedReading(location);

    final rain7d = EduSatelliteReading.totalPrecipitation(history);
    final bundle = EduConditionsBundle(
      sat:      today,
      iot:      iot,
      rain7d:   rain7d,
      location: location,
    );

    _cache[schoolName] = _CachedBundle(bundle: bundle,
        fetchedAt: DateTime.now());
    return bundle;
  }

  /// Force refresh for a school — call after location update.
  static Future<EduConditionsBundle> refresh(String schoolName) {
    _cache.remove(schoolName);
    EduFarmLocationService.invalidate(schoolName);
    return getBundle(schoolName);
  }

  /// Clear all caches — call on sign-out.
  static void clearAll() {
    _cache.clear();
    EduFarmLocationService.clearAll();
  }

  // ── NASA POWER fetch (education path, no shared state) ────────────────────

  static Future<EduSatelliteReading?> _fetchOne(
      EduSchoolLocation loc, DateTime date) async {
    final results = await _fetchNasa(loc, date, date);
    return results.isEmpty ? null : results.first;
  }

  static Future<List<EduSatelliteReading>> _fetchRange(
      EduSchoolLocation loc, DateTime start, DateTime end) async {
    try {
      return await _fetchNasa(loc, start, end);
    } catch (_) {
      return [];
    }
  }

  static Future<List<EduSatelliteReading>> _fetchNasa(
      EduSchoolLocation loc, DateTime start, DateTime end) async {
    final uri = Uri.parse(
      '$_baseUrl'
      '?parameters=${_params.join(',')}'
      '&community=AG'
      '&longitude=${loc.longitude.toStringAsFixed(4)}'
      '&latitude=${loc.latitude.toStringAsFixed(4)}'
      '&start=${_fmt(start)}'
      '&end=${_fmt(end)}'
      '&format=JSON',
    );

    final response =
        await http.get(uri).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw Exception('NASA POWER ${response.statusCode}');
    }

    final body  = jsonDecode(response.body) as Map<String, dynamic>;
    final props = body['properties']?['parameter'] as Map<String, dynamic>?;
    if (props == null) throw Exception('Unexpected NASA POWER format');

    final dates = (props.values.first as Map<String, dynamic>).keys.toList()
      ..sort();
    final readings = <EduSatelliteReading>[];

    for (final dk in dates) {
      final d = _parseDate(dk);
      if (d == null) continue;

      double g(String p) {
        final v = props[p]?[dk];
        if (v == null) return 0;
        final n = v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
        return n < -900 ? 0 : n;
      }

      double r(double v, int decimals) {
        final f = pow(10, decimals).toDouble();
        return (v * f).round() / f;
      }

      readings.add(EduSatelliteReading(
        date:             d,
        county:           loc.county,
        schoolName:       loc.schoolId,
        airTemp:          r(g('T2M'),              1),
        airTempMax:       r(g('T2M_MAX'),          1),
        airTempMin:       r(g('T2M_MIN'),          1),
        dewPoint:         r(g('T2MDEW'),           1),
        humidity:         r(g('RH2M'),             1),
        precipitation:    r(g('PRECTOTCORR'),      2),
        windSpeed:        r(g('WS2M'),             1),
        cloudCover:       r(g('CLOUD_AMT'),        1),
        uvIndex:          r(g('ALLSKY_SFC_UV_INDEX'), 1),
        rootZoneMoisture: r(g('GWETROOT'),         3),
        surfaceMoisture:  r(g('GWETTOP'),          3),
        soilTempLayer1:   r(g('TSOIL1'),           1),
        par:              r(g('ALLSKY_SFC_PAR_TOT'), 1),
      ));
    }
    return readings;
  }

  // ── Simulated IoT reading for school county (Phase 1) ─────────────────────

  static EduIotReading _simulatedReading(EduSchoolLocation loc) {
    final data = _eduRegionData[loc.county] ?? _eduDefaultData;
    final rng  = Random(loc.county.hashCode + DateTime.now().day);

    double vary(double base) {
      final pct = 0.95 + rng.nextDouble() * 0.10;
      return double.parse((base * pct).toStringAsFixed(1));
    }

    return EduIotReading(
      nodeLabel:   '${loc.county} school farm sensor (simulated)',
      timestamp:   DateTime.now()
          .subtract(Duration(minutes: rng.nextInt(10) + 1)),
      n:           vary(data[0]),
      p:           vary(data[1]),
      k:           vary(data[2]),
      ph:          double.parse(
          (data[3] + (rng.nextDouble() * 0.2 - 0.1)).toStringAsFixed(2)),
      temperature: vary(data[4]),
      humidity:    vary(data[5]),
      ec:          vary(data[6]),
      isSimulated: true,
    );
  }

  // ── Utilities ──────────────────────────────────────────────────────────────

  static String _fmt(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime? _parseDate(String s) {
    if (s.length != 8) return null;
    try {
      return DateTime(int.parse(s.substring(0, 4)),
          int.parse(s.substring(4, 6)), int.parse(s.substring(6, 8)));
    } catch (_) {
      return null;
    }
  }
}

// ── Internal cache entry ───────────────────────────────────────────────────

class _CachedBundle {
  final EduConditionsBundle bundle;
  final DateTime fetchedAt;
  const _CachedBundle({required this.bundle, required this.fetchedAt});
}