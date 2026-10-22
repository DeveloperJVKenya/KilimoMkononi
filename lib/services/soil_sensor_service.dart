// lib/services/soil_sensor_service.dart
//
// The soil sensor (probe) attached to a weather station. Read through the
// same `getNuaSenseData` proxy as the station's weather (endpoint `soil`),
// so the server's rules apply unchanged: farmers get the soil data of the
// stations connected to their account, Field Agronomists / admins of every
// KM station.
//
// Values are exactly as recorded — never estimated or filled:
//   soil_moisture     % VWC (volumetric water content)
//   soil_temperature  °C
//   soil_ec           µS/cm (electrical conductivity)
// Each probe channel ("level") of each device is one [SoilProbe]. A level is
// a channel number, not a depth — "Level 1" is shown as "Probe 1". More
// levels appear only when more probes are added. soil_ec only comes back
// when asked for by name, so every request lists the metrics.
//
// Which stations show soil data (NuaStation.soilSensor, set by the admin):
//   true  — confirmed attached: always shown (no readings → "not reporting");
//   false — confirmed none: never asked for;
//   null  — not confirmed (stations from before soil sensors): shown only
//           when the station actually sends soil readings.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:kilimomkononi/services/nuasense_service.dart';

/// No soil reading for this long → the sensor is "not reporting" (it sends
/// every ~15 minutes; same window as the station's weather).
const kSoilOfflineAfter = Duration(hours: 2);

enum SoilMetric {
  moisture('soil_moisture', 'Soil moisture', '% VWC', 1),
  temperature('soil_temperature', 'Soil temperature', '°C', 1),
  ec('soil_ec', 'Soil EC', 'µS/cm', 0);

  /// The API's sensorType.
  final String apiName;
  final String label;
  final String unit;
  final int decimals;
  const SoilMetric(this.apiName, this.label, this.unit, this.decimals);

  static SoilMetric? fromApi(Object? v) {
    for (final m in values) {
      if (m.apiName == v) return m;
    }
    return null;
  }

  String format(double v) => '${v.toStringAsFixed(decimals)} $unit';
}

/// Every metric, as the API expects them in `metrics=`.
final String kSoilMetricsParam = SoilMetric.values.map((m) => m.apiName).join(',');

class SoilPoint {
  final DateTime time;
  final double value;
  const SoilPoint(this.time, this.value);
}

/// One probe channel of one soil-sensor device.
class SoilProbe {
  final String deviceId; // devEui
  final String level; // probe channel, e.g. "1"
  /// Latest raw reading per metric (last ~3 h).
  final Map<SoilMetric, SoilPoint> latest;

  /// Hourly means for the last 24 h, oldest first.
  final Map<SoilMetric, List<SoilPoint>> history;

  const SoilProbe({
    required this.deviceId,
    required this.level,
    this.latest = const {},
    this.history = const {},
  });

  String get label => level.isEmpty ? 'Probe' : 'Probe $level';

  /// Metrics this probe reports, in display order.
  List<SoilMetric> get metrics =>
      SoilMetric.values.where((m) => latest.containsKey(m) || (history[m]?.isNotEmpty ?? false)).toList();

  /// The newest value: the latest raw reading, else the last hourly mean.
  SoilPoint? current(SoilMetric m) => latest[m] ?? history[m]?.lastOrNull;

  DateTime? get lastReading {
    DateTime? t;
    for (final m in metrics) {
      final p = current(m);
      if (p != null && (t == null || p.time.isAfter(t))) t = p.time;
    }
    return t;
  }

  /// Lowest / highest hourly mean in the last 24 h.
  ({double min, double max})? range24h(SoilMetric m) {
    final pts = history[m];
    if (pts == null || pts.isEmpty) return null;
    var lo = pts.first.value, hi = pts.first.value;
    for (final p in pts) {
      if (p.value < lo) lo = p.value;
      if (p.value > hi) hi = p.value;
    }
    return (min: lo, max: hi);
  }

  /// Newest value minus the first hourly mean of the last 24 h.
  double? change24h(SoilMetric m) {
    final first = history[m]?.firstOrNull;
    final now = current(m);
    if (first == null || now == null || !now.time.isAfter(first.time)) return null;
    return now.value - first.value;
  }
}

class SoilSensorData {
  final List<SoilProbe> probes;

  /// False when the account has no station (the proxy's provisioned: false).
  final bool provisioned;

  /// The request failed (offline, provider error) — nothing is known.
  final bool failed;
  final DateTime checkedAt;

  const SoilSensorData({
    this.probes = const [],
    this.provisioned = true,
    this.failed = false,
    required this.checkedAt,
  });

  bool get hasReadings => probes.any((p) => p.metrics.isNotEmpty);

  DateTime? get lastReading {
    DateTime? t;
    for (final p in probes) {
      final l = p.lastReading;
      if (l != null && (t == null || l.isAfter(t))) t = l;
    }
    return t;
  }

  /// A reading in the last [kSoilOfflineAfter].
  bool get isLive {
    final t = lastReading;
    return t != null && checkedAt.difference(t) <= kSoilOfflineAfter;
  }

  /// Builds the data from the proxy's two `soil` replies: [latest] (raw, last
  /// ~3 h) and [history] (hourly means, last 24 h). Pure — tested.
  static SoilSensorData parse({
    required Map<String, dynamic> latest,
    required Map<String, dynamic> history,
    required DateTime checkedAt,
  }) {
    if (latest['provisioned'] == false || history['provisioned'] == false) {
      return SoilSensorData(provisioned: false, checkedAt: checkedAt);
    }
    if (latest['series'] is! List && history['series'] is! List) {
      return SoilSensorData(failed: true, checkedAt: checkedAt);
    }

    final latestBy = <String, Map<SoilMetric, SoilPoint>>{};
    final historyBy = <String, Map<SoilMetric, List<SoilPoint>>>{};
    final order = <String>[];
    final ids = <String, (String, String)>{};

    void read(Map<String, dynamic> reply, void Function(String key, SoilMetric m, List<SoilPoint> pts) put) {
      for (final s in (reply['series'] as List? ?? const [])) {
        if (s is! Map) continue;
        final m = SoilMetric.fromApi(s['sensorType']);
        if (m == null) continue;
        final device = '${s['devEui'] ?? ''}';
        final level = '${s['level'] ?? ''}';
        final key = '$device|$level';
        if (!ids.containsKey(key)) {
          ids[key] = (device, level);
          order.add(key);
        }
        final pts = <SoilPoint>[];
        for (final p in (s['data'] as List? ?? const [])) {
          if (p is! Map) continue;
          final t = DateTime.tryParse('${p['x']}');
          final y = p['y'];
          if (t == null || y is! num || !y.isFinite) continue;
          pts.add(SoilPoint(t, y.toDouble()));
        }
        pts.sort((a, b) => a.time.compareTo(b.time));
        put(key, m, pts);
      }
    }

    read(latest, (key, m, pts) {
      if (pts.isNotEmpty) (latestBy[key] ??= {})[m] = pts.last;
    });
    read(history, (key, m, pts) {
      if (pts.isNotEmpty) (historyBy[key] ??= {})[m] = pts;
    });

    final probes = [
      for (final key in order)
        SoilProbe(
          deviceId: ids[key]!.$1,
          level: ids[key]!.$2,
          latest: latestBy[key] ?? const {},
          history: historyBy[key] ?? const {},
        ),
    ]..sort((a, b) {
        final d = a.deviceId.compareTo(b.deviceId);
        return d != 0 ? d : (int.tryParse(a.level) ?? 0).compareTo(int.tryParse(b.level) ?? 0);
      });
    return SoilSensorData(probes: probes, checkedAt: checkedAt);
  }
}

class SoilSensorService {
  SoilSensorService._();

  static final Map<String, (DateTime, SoilSensorData)> _cache = {};
  static const _cacheFor = Duration(minutes: 10);

  static String _key(String stationId) {
    String uid;
    try {
      uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    } catch (_) {
      uid = '';
    }
    return '$uid|$stationId';
  }

  /// Whether to ask for soil data at all: not when the admin confirmed the
  /// station has no soil sensor.
  static bool shouldFetch(bool? confirmed) => confirmed != false;

  /// Whether to show the soil section: confirmed stations always; stations
  /// not confirmed only when they actually send soil readings.
  static bool shouldShow(bool? confirmed, SoilSensorData? data) => switch (confirmed) {
        true => true,
        false => false,
        null => data != null && data.hasReadings,
      };

  /// The station's soil readings (cached 10 min per account + station).
  static Future<SoilSensorData> load(String stationId, {bool refresh = false}) async {
    final key = _key(stationId);
    final hit = _cache[key];
    if (!refresh && hit != null && DateTime.now().difference(hit.$1) < _cacheFor) return hit.$2;
    final replies = await Future.wait([
      NuaSenseService.proxy('soil', {
        'metrics': kSoilMetricsParam,
        'start': '-3h',
        'gateway_id': stationId,
      }),
      NuaSenseService.proxy('soil', {
        'metrics': kSoilMetricsParam,
        'start': '-24h',
        'resolution': 'hourly',
        'aggregate': 'mean',
        'gateway_id': stationId,
      }),
    ]);
    final data = SoilSensorData.parse(latest: replies[0], history: replies[1], checkedAt: DateTime.now());
    if (!data.failed) _cache[key] = (DateTime.now(), data);
    debugPrint('[Soil] $stationId: ${data.failed ? 'request failed' : !data.provisioned ? 'no station' : '${data.probes.length} probe(s), '
        'metrics ${data.probes.expand((p) => p.metrics).map((m) => m.apiName).toSet().join(',')}, '
        'last ${data.lastReading?.toIso8601String() ?? 'none'}, live ${data.isLive}'}');
    return data;
  }

  static void clearCache({String? stationId}) {
    if (stationId == null) {
      _cache.clear();
    } else {
      _cache.removeWhere((k, _) => k.endsWith('|$stationId'));
    }
  }
}
