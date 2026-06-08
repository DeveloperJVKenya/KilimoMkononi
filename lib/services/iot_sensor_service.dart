// lib/services/iot_sensor_service.dart
//
// Fetches real-time IoT soil sensor data from Firestore for the farmer's county.
//
// ── HOW THE REAL SYSTEM WORKS ──────────────────────────────────────────────
//
// Physical IoT sensors are deployed at specific locations across Kenya.
// Each sensor device writes a reading to Firestore every ~1 minute:
//
//   iot_nodes/{nodeId}/readings/{autoId}
//   {
//     county:       "Nakuru",
//     timestamp:    Timestamp,
//     n:  12.4,  p: 8.1,  k: 22.0,   // mg/kg
//     ph: 6.4,   tem: 28.1,
//     hum: 45.2, ec: 120.0
//   }
//
// ── DATA SOURCE PHASES ─────────────────────────────────────────────────────
//
// Phase 1 (NOW — simulated):
//   Returns realistic hardcoded values per Kenya region. Never fails.
//   No CSV files, no Firestore needed. The UI shows sensor tiles correctly.
//   Change _dataSource to switch phases — no other code changes needed.
//
// WHY NOT CSV ASSETS?
//   CSV bundling caused "asset not found" errors on Android (case-sensitive
//   paths, build pipeline re-encoding). Simulated in-code values are more
//   reliable for the pre-partner demo phase and never go stale.
//
// Phase 2 (beta):   IotDataSource.firestore
//   IoT partner deploys nodes, writes to iot_nodes/{id}/readings.
//   Change _dataSource constant below — nothing else changes.

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kilimomkononi/services/farm_location_service.dart';

// ── Data source toggle ─────────────────────────────────────────────────────
const IotDataSource _dataSource = IotDataSource.simulated;
// const IotDataSource _dataSource = IotDataSource.firestore; // ← Phase 2

// ── Models ─────────────────────────────────────────────────────────────────

enum IotDataSource { simulated, firestore }

class IotSensorReading {
  final String nodeId;
  final String nodeLabel;
  final DateTime timestamp;
  final double n;           // mg/kg
  final double p;           // mg/kg
  final double k;           // mg/kg
  final double ph;
  final double temperature; // °C
  final double humidity;    // %
  final double ec;          // µs/cm
  final int sampleCount;
  final IotDataSource source;
  final FarmLocation farmLocation;

  const IotSensorReading({
    required this.nodeId,
    required this.nodeLabel,
    required this.timestamp,
    required this.n,
    required this.p,
    required this.k,
    required this.ph,
    required this.temperature,
    required this.humidity,
    required this.ec,
    required this.sampleCount,
    required this.source,
    required this.farmLocation,
  });

  Map<String, dynamic> toMap() => {
    'nodeId':       nodeId,
    'nodeLabel':    nodeLabel,
    'readingTime':  timestamp.toIso8601String(),
    'n':            n,
    'p':            p,
    'k':            k,
    'ph':           ph,
    'temperature':  temperature,
    'humidity':     humidity,
    'ec':           ec,
    'sampleCount':  sampleCount,
    'source':       source.name,
    'county':       farmLocation.county,
    'farmLabel':    farmLocation.displayLabel,
  };
}

// ── Simulated regional data ────────────────────────────────────────────────
//
// Representative soil + climate values for each Kenya region.
// Based on published soil health data for Kenyan agricultural zones.
// These are used in Phase 1 so the UI always shows realistic sensor tiles.
//
// Structure: county → (n, p, k, ph, temperature, humidity, ec)
const Map<String, List<double>> _simulatedRegionData = {
  // Central highlands — fertile volcanic soils, moderate temps
  'Nairobi City': [18.2, 12.4, 95.0, 6.2, 22.1, 62.0, 145.0],
  'Kiambu':       [22.5, 14.8, 110.0, 6.4, 21.5, 65.0, 132.0],
  'Murang\'a':    [24.1, 13.2, 105.0, 6.1, 20.8, 68.0, 128.0],
  'Kirinyaga':    [26.3, 15.6, 118.0, 6.3, 20.2, 70.0, 140.0],
  'Nyeri':        [21.8, 13.9, 102.0, 6.2, 19.5, 67.0, 135.0],
  'Nyandarua':    [19.4, 11.8, 98.0,  5.9, 17.2, 72.0, 118.0],

  // Rift Valley — mixed soils, varied rainfall
  'Nakuru':           [20.6, 13.1, 108.0, 6.5, 23.4, 58.0, 155.0],
  'Laikipia':         [14.2, 8.6,  78.0,  6.8, 24.8, 42.0, 190.0],
  'Narok':            [16.8, 10.2, 88.0,  6.6, 22.6, 52.0, 162.0],
  'Kajiado':          [10.4, 6.8,  62.0,  7.1, 27.3, 35.0, 225.0],
  'Kericho':          [28.4, 16.2, 125.0, 5.8, 19.8, 75.0, 122.0],
  'Bomet':            [26.1, 15.4, 120.0, 5.9, 20.1, 73.0, 128.0],
  'Baringo':          [12.8, 7.4,  72.0,  7.2, 28.6, 38.0, 210.0],
  'West Pokot':       [11.6, 6.9,  68.0,  6.9, 26.4, 44.0, 195.0],
  'Elgeyo Marakwet':  [18.4, 11.5, 95.0,  6.3, 22.0, 60.0, 148.0],
  'Uasin Gishu':      [23.8, 14.5, 112.0, 6.2, 21.2, 64.0, 138.0],
  'Nandi':            [25.2, 15.1, 115.0, 6.0, 20.6, 68.0, 130.0],
  'Trans Nzoia':      [27.6, 16.8, 122.0, 6.1, 21.0, 66.0, 125.0],

  // Western Kenya — high rainfall, leached soils
  'Kakamega':         [22.4, 11.8, 92.0,  5.6, 24.2, 72.0, 115.0],
  'Vihiga':           [21.8, 11.2, 88.0,  5.7, 23.8, 74.0, 112.0],
  'Bungoma':          [24.6, 13.4, 98.0,  5.8, 23.5, 70.0, 118.0],
  'Busia':            [20.2, 10.8, 85.0,  5.9, 25.4, 68.0, 125.0],

  // Nyanza — Lake Victoria basin
  'Kisumu':   [18.6, 10.4, 82.0, 6.4, 26.8, 65.0, 138.0],
  'Siaya':    [17.4, 9.8,  78.0, 6.5, 26.2, 64.0, 142.0],
  'Homa Bay': [16.8, 9.4,  75.0, 6.6, 27.4, 62.0, 148.0],
  'Migori':   [19.2, 10.6, 84.0, 6.3, 26.6, 66.0, 135.0],
  'Kisii':    [24.8, 13.8, 105.0, 5.8, 22.4, 72.0, 122.0],
  'Nyamira':  [23.6, 13.2, 102.0, 5.9, 22.1, 73.0, 125.0],

  // Eastern Kenya — semi-arid, nutrient-poor
  'Machakos':    [12.4, 7.2, 68.0, 6.8, 26.8, 40.0, 205.0],
  'Kitui':       [10.8, 6.4, 58.0, 7.0, 28.2, 35.0, 225.0],
  'Makueni':     [11.6, 6.8, 62.0, 7.1, 28.8, 34.0, 230.0],
  'Embu':        [22.8, 14.2, 108.0, 6.2, 22.4, 63.0, 140.0],
  'Meru':        [24.4, 14.8, 112.0, 6.1, 21.8, 62.0, 135.0],
  'Tharaka Nithi': [18.6, 11.4, 92.0, 6.4, 24.2, 55.0, 158.0],

  // Coast — sandy soils, high temps
  'Mombasa':      [8.4,  5.2, 48.0, 7.2, 31.8, 75.0, 285.0],
  'Kwale':        [9.2,  5.8, 52.0, 7.1, 30.4, 72.0, 265.0],
  'Kilifi':       [8.8,  5.4, 50.0, 7.2, 31.2, 70.0, 275.0],
  'Taita Taveta': [14.6, 8.8, 75.0, 6.8, 27.6, 52.0, 195.0],
  'Tana River':   [8.2,  4.8, 44.0, 7.4, 32.4, 42.0, 310.0],
  'Lamu':         [7.8,  4.6, 42.0, 7.5, 32.8, 76.0, 320.0],

  // North Eastern — arid
  'Garissa':  [6.2, 3.8, 35.0, 7.8, 34.6, 28.0, 385.0],
  'Wajir':    [5.4, 3.2, 30.0, 8.0, 35.8, 24.0, 420.0],
  'Mandera':  [5.0, 3.0, 28.0, 8.1, 36.4, 22.0, 445.0],
  'Marsabit': [7.6, 4.4, 42.0, 7.6, 30.2, 38.0, 295.0],
  'Isiolo':   [8.8, 5.2, 48.0, 7.4, 29.8, 36.0, 268.0],
  'Samburu':  [9.4, 5.6, 52.0, 7.3, 28.4, 40.0, 248.0],
  'Turkana':  [5.8, 3.4, 32.0, 7.9, 36.2, 20.0, 405.0],
};

// Fallback values for any county not in the map above
const List<double> _defaultRegionData = [15.0, 10.0, 85.0, 6.5, 25.0, 55.0, 175.0];

// ── Service ────────────────────────────────────────────────────────────────

class IotSensorService {
  IotSensorService._();

  static final Map<String, IotSensorReading> _cache = {};

  // ── Public API ────────────────────────────────────────────────────────────

  /// Returns the latest soil sensor reading for this farmer's county.
  /// In Phase 1: returns realistic simulated values — never fails.
  /// In Phase 2: reads from Firestore iot_nodes collection.
  static Future<IotSensorReading> getReadingForFarm() async {
    final location = await FarmLocationService.getLocation();

    switch (_dataSource) {
      case IotDataSource.firestore:
        return _loadFromFirestore(location);
      case IotDataSource.simulated:
        return _simulatedReading(location);
    }
  }

  /// Clears in-memory cache — call after location change or sign-out.
  static void clearCache() => _cache.clear();

  // ── Simulated path (Phase 1) ───────────────────────────────────────────

  static IotSensorReading _simulatedReading(FarmLocation location) {
    final cacheKey = 'sim_${location.county}';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    final data = _simulatedRegionData[location.county] ?? _defaultRegionData;

    // Add a small random variation (±5%) so values feel live, not hardcoded
    final rng = Random(location.county.hashCode + DateTime.now().day);
    double vary(double base) {
      final pct = 0.95 + rng.nextDouble() * 0.10; // 95%–105%
      return double.parse((base * pct).toStringAsFixed(1));
    }

    final reading = IotSensorReading(
      nodeId:      'sim_${location.county.toLowerCase().replaceAll(' ', '_')}',
      nodeLabel:   '${location.county} regional sensor (simulated)',
      timestamp:   DateTime.now().subtract(Duration(minutes: rng.nextInt(10) + 1)),
      n:           vary(data[0]),
      p:           vary(data[1]),
      k:           vary(data[2]),
      ph:          double.parse((data[3] + (rng.nextDouble() * 0.2 - 0.1)).toStringAsFixed(2)),
      temperature: vary(data[4]),
      humidity:    vary(data[5]),
      ec:          vary(data[6]),
      sampleCount: 30,
      source:      IotDataSource.simulated,
      farmLocation: location,
    );

    _cache[cacheKey] = reading;
    return reading;
  }

  // ── Firestore path (Phase 2+) ──────────────────────────────────────────

  static Future<IotSensorReading> _loadFromFirestore(FarmLocation location) async {
    final cacheKey = 'firestore_${location.county}';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    // Find active node for this county
    final nodesSnap = await FirebaseFirestore.instance
        .collection('iot_nodes')
        .where('county', isEqualTo: location.county)
        .where('active', isEqualTo: true)
        .limit(1)
        .get();

    if (nodesSnap.docs.isEmpty) {
      // No live node yet — fall back to simulated so the UI never errors
      return _simulatedReading(location);
    }

    final nodeDoc   = nodesSnap.docs.first;
    final nodeId    = nodeDoc.id;
    final nodeLabel = (nodeDoc.data()['label'] as String?) ?? nodeId;

    final readingsSnap = await FirebaseFirestore.instance
        .collection('iot_nodes')
        .doc(nodeId)
        .collection('readings')
        .orderBy('timestamp', descending: true)
        .limit(30)
        .get();

    if (readingsSnap.docs.isEmpty) {
      return _simulatedReading(location);
    }

    final rows = readingsSnap.docs.map((d) {
      final m = d.data();
      return _FirestoreRow(
        n:   _toDouble(m['n']),
        p:   _toDouble(m['p']),
        k:   _toDouble(m['k']),
        ph:  _toDouble(m['ph']),
        tem: _toDouble(m['tem']),
        hum: _toDouble(m['hum']),
        ec:  _toDouble(m['ec']),
        ts:  (m['timestamp'] as Timestamp).toDate(),
      );
    }).toList();

    final reading = _aggregateFirestore(rows, nodeId, nodeLabel, location);
    _cache[cacheKey] = reading;
    return reading;
  }

  // ── Aggregation ────────────────────────────────────────────────────────

  static IotSensorReading _aggregateFirestore(
    List<_FirestoreRow> rows, String nodeId, String nodeLabel, FarmLocation location,
  ) {
    return IotSensorReading(
      nodeId:      nodeId,
      nodeLabel:   nodeLabel,
      timestamp:   rows.first.ts,
      n:           _med(rows.map((r) => r.n).toList()),
      p:           _med(rows.map((r) => r.p).toList()),
      k:           _med(rows.map((r) => r.k).toList()),
      ph:          _r(_med(rows.map((r) => r.ph).toList()), 2),
      temperature: _r(_med(rows.map((r) => r.tem).toList()), 1),
      humidity:    _r(_med(rows.map((r) => r.hum).toList()), 1),
      ec:          _med(rows.map((r) => r.ec).toList()),
      sampleCount: rows.length,
      source:      IotDataSource.firestore,
      farmLocation: location,
    );
  }

  // ── Utilities ──────────────────────────────────────────────────────────

  static double _med(List<double> v) {
    if (v.isEmpty) return 0;
    final s = List<double>.from(v)..sort();
    final m = s.length ~/ 2;
    return s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2;
  }

  static double _r(double v, int d) {
    final f = pow(10, d).toDouble();
    return (v * f).round() / f;
  }

  static double _toDouble(dynamic v) =>
      v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);
}

// ── Internal row model ─────────────────────────────────────────────────────

class _FirestoreRow {
  final double n, p, k, ph, tem, hum, ec;
  final DateTime ts;
  const _FirestoreRow({
    required this.n, required this.p, required this.k,
    required this.ph, required this.tem, required this.hum, required this.ec,
    required this.ts,
  });
}