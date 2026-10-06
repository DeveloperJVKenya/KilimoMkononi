// lib/services/google_weather_service.dart
//
// Google Weather (the same source Coffeecore uses) via the `getGoogleWeather`
// Cloud Function — the API key stays in Secret Manager.
//
// This is an AREA FORECAST from Google's weather model: current conditions,
// the next 24 hours and 7 days for any point. It complements — never
// replaces — the farm's own NuaSense station, which measures the actual
// conditions on the farm. Verified advice and weather alerts come ONLY from
// station readings; screens label the two sources clearly.
//
// The last result per location (~1 km cell) is cached on the device, so the
// forecast still shows (marked as saved) when the farmer is offline.

import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
int _i(dynamic v) => (v as num?)?.round() ?? 0;
Map<String, dynamic> _m(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};

/// Google's weather condition, e.g. type LIGHT_RAIN, "Light rain", icon URL.
class GoogleCondition {
  final String type;
  final String description;
  final String iconBaseUri;

  const GoogleCondition({this.type = '', this.description = '', this.iconBaseUri = ''});

  factory GoogleCondition.fromJson(dynamic j) {
    final m = _m(j);
    return GoogleCondition(
      type: (m['type'] as String?) ?? '',
      description: (_m(m['description'])['text'] as String?) ?? '',
      iconBaseUri: (m['iconBaseUri'] as String?) ?? '',
    );
  }

  /// Google's icon as a PNG (append ".png"; "_dark" for dark backgrounds).
  String? iconUrl({bool dark = false}) =>
      iconBaseUri.isEmpty ? null : '$iconBaseUri${dark ? '_dark' : ''}.png';

  /// Coarse bucket for fallback icons: storm, rain, snow, fog, wind, clouds, clear.
  String get bucket {
    final t = type.toLowerCase();
    if (t.contains('thunder')) return 'storm';
    if (t.contains('snow') || t.contains('hail')) return 'snow';
    if (t.contains('rain') || t.contains('shower') || t.contains('drizzle')) return 'rain';
    if (t.contains('wind')) return 'wind';
    if (t.contains('fog') || t.contains('haze') || t.contains('mist')) return 'fog';
    if (t.contains('cloud')) return 'clouds';
    if (t.contains('clear') || t.contains('sun')) return 'clear';
    return 'unknown';
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'description': {'text': description},
        'iconBaseUri': iconBaseUri,
      };
}

class GoogleCurrentWeather {
  final double temp;
  final double feelsLike;
  final int humidity;
  final double dewPoint;
  final double windKmh;
  final double gustKmh;
  final String windDirection; // e.g. "NE"
  final int uvIndex;
  final int cloudCover;
  final int rainChance; // %
  final double rainMm; // expected precipitation, mm
  final bool isDaytime;
  final GoogleCondition condition;

  const GoogleCurrentWeather({
    required this.temp,
    required this.feelsLike,
    required this.humidity,
    required this.dewPoint,
    required this.windKmh,
    required this.gustKmh,
    required this.windDirection,
    required this.uvIndex,
    required this.cloudCover,
    required this.rainChance,
    required this.rainMm,
    required this.isDaytime,
    required this.condition,
  });

  factory GoogleCurrentWeather.fromJson(Map<String, dynamic> j) {
    final wind = _m(j['wind']);
    final precip = _m(j['precipitation']);
    return GoogleCurrentWeather(
      temp: _d(_m(j['temperature'])['degrees']),
      feelsLike: _d(_m(j['feelsLikeTemperature'])['degrees']),
      humidity: _i(j['relativeHumidity']),
      dewPoint: _d(_m(j['dewPoint'])['degrees']),
      windKmh: _d(_m(wind['speed'])['value']),
      gustKmh: _d(_m(wind['gust'])['value']),
      windDirection: (_m(wind['direction'])['cardinal'] as String?)?.replaceAll('_', ' ') ?? '',
      uvIndex: _i(j['uvIndex']),
      cloudCover: _i(j['cloudCover']),
      rainChance: _i(_m(precip['probability'])['percent']),
      rainMm: _d(_m(precip['qpf'])['quantity']),
      isDaytime: j['isDaytime'] as bool? ?? true,
      condition: GoogleCondition.fromJson(j['weatherCondition']),
    );
  }
}

class GoogleHourlyForecast {
  final DateTime time; // local
  final double temp;
  final int rainChance;
  final double rainMm;
  final GoogleCondition condition;

  const GoogleHourlyForecast({
    required this.time,
    required this.temp,
    required this.rainChance,
    required this.rainMm,
    required this.condition,
  });

  static GoogleHourlyForecast? fromJson(Map<String, dynamic> j) {
    final start = DateTime.tryParse(_m(j['interval'])['startTime']?.toString() ?? '');
    if (start == null) return null;
    final precip = _m(j['precipitation']);
    return GoogleHourlyForecast(
      time: start.toLocal(),
      temp: _d(_m(j['temperature'])['degrees']),
      rainChance: _i(_m(precip['probability'])['percent']),
      rainMm: _d(_m(precip['qpf'])['quantity']),
      condition: GoogleCondition.fromJson(j['weatherCondition']),
    );
  }
}

class GoogleDailyForecast {
  final DateTime date;
  final double maxTemp;
  final double minTemp;
  final int rainChance;
  final double rainMm;
  final int humidity;
  final double windKmh;
  final GoogleCondition condition;

  const GoogleDailyForecast({
    required this.date,
    required this.maxTemp,
    required this.minTemp,
    required this.rainChance,
    required this.rainMm,
    required this.humidity,
    required this.windKmh,
    required this.condition,
  });

  static GoogleDailyForecast? fromJson(Map<String, dynamic> j) {
    final dd = _m(j['displayDate']);
    if (dd['year'] == null) return null;
    final day = _m(j['daytimeForecast']);
    final night = _m(j['nighttimeForecast']);
    final dayPrecip = _m(day['precipitation']);
    final nightPrecip = _m(night['precipitation']);
    final dayChance = _i(_m(dayPrecip['probability'])['percent']);
    final nightChance = _i(_m(nightPrecip['probability'])['percent']);
    return GoogleDailyForecast(
      date: DateTime(_i(dd['year']), _i(dd['month']), _i(dd['day'])),
      maxTemp: _d(_m(j['maxTemperature'])['degrees']),
      minTemp: _d(_m(j['minTemperature'])['degrees']),
      rainChance: dayChance > nightChance ? dayChance : nightChance,
      rainMm: _d(_m(dayPrecip['qpf'])['quantity']) + _d(_m(nightPrecip['qpf'])['quantity']),
      humidity: _i(day['relativeHumidity']),
      windKmh: _d(_m(_m(day['wind'])['speed'])['value']),
      condition: GoogleCondition.fromJson(day['weatherCondition']),
    );
  }
}

/// One location's Google weather.
class GoogleWeather {
  final GoogleCurrentWeather current;
  final List<GoogleHourlyForecast> hours;
  final List<GoogleDailyForecast> days;
  final DateTime fetchedAt;

  /// True when this came from the device cache (offline / service down).
  final bool fromCache;

  const GoogleWeather({
    required this.current,
    required this.hours,
    required this.days,
    required this.fetchedAt,
    this.fromCache = false,
  });

  /// Parses the `getGoogleWeather` "weather" response (raw Google objects).
  factory GoogleWeather.fromResponse(Map<String, dynamic> r, {bool fromCache = false}) =>
      GoogleWeather(
        current: GoogleCurrentWeather.fromJson(_m(r['current'])),
        hours: ((r['hours'] as List?) ?? const [])
            .map((h) => GoogleHourlyForecast.fromJson(_m(h)))
            .whereType<GoogleHourlyForecast>()
            .toList(),
        days: ((r['days'] as List?) ?? const [])
            .map((d) => GoogleDailyForecast.fromJson(_m(d)))
            .whereType<GoogleDailyForecast>()
            .toList(),
        fetchedAt: DateTime.tryParse(r['fetchedAt']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
        fromCache: fromCache,
      );
}

/// One hour of Google's recorded conditions (history/hours:lookup) — what
/// Google's model says the weather WAS, for comparing with a station.
class GoogleHistoryHour {
  final DateTime time; // start of the hour, local
  final double temp;
  final int humidity;
  final double dewPoint;
  final double windKmh;
  final double gustKmh;
  final double rainMm;

  const GoogleHistoryHour({
    required this.time,
    required this.temp,
    required this.humidity,
    required this.dewPoint,
    required this.windKmh,
    required this.gustKmh,
    required this.rainMm,
  });

  static GoogleHistoryHour? fromJson(Map<String, dynamic> j) {
    final start = DateTime.tryParse(_m(j['interval'])['startTime']?.toString() ?? '');
    if (start == null) return null;
    final wind = _m(j['wind']);
    return GoogleHistoryHour(
      time: start.toLocal(),
      temp: _d(_m(j['temperature'])['degrees']),
      humidity: _i(j['relativeHumidity']),
      dewPoint: _d(_m(j['dewPoint'])['degrees']),
      windKmh: _d(_m(wind['speed'])['value']),
      gustKmh: _d(_m(wind['gust'])['value']),
      rainMm: _d(_m(_m(j['precipitation'])['qpf'])['quantity']),
    );
  }
}

/// A place found by name or from coordinates.
class GooglePlace {
  final double lat;
  final double lon;
  final String label;
  const GooglePlace(this.lat, this.lon, this.label);
}

class GoogleWeatherService {
  GoogleWeatherService._();

  static const _cachePrefix = 'gweather_v1_';

  static Future<Map<String, dynamic>> _call(Map<String, dynamic> data) async {
    final res = await FirebaseFunctions.instance
        .httpsCallable('getGoogleWeather',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 30)))
        .call(data);
    return Map<String, dynamic>.from(res.data as Map);
  }

  @visibleForTesting
  static String cellKey(double lat, double lon) =>
      '$_cachePrefix${lat.toStringAsFixed(2)}_${lon.toStringAsFixed(2)}';

  /// Current, 24-hour and 7-day weather for a point. Falls back to the last
  /// saved result for that area (fromCache: true) if the network fails;
  /// rethrows only when there's nothing saved.
  static Future<GoogleWeather> forLocation(double lat, double lon) async {
    final key = cellKey(lat, lon);
    try {
      final r = await _call({'action': 'weather', 'lat': lat, 'lon': lon});
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(key, jsonEncode(r));
      } catch (_) {}
      return GoogleWeather.fromResponse(r);
    } catch (e) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(key);
        if (raw != null) {
          return GoogleWeather.fromResponse(
              Map<String, dynamic>.from(jsonDecode(raw) as Map),
              fromCache: true);
        }
      } catch (_) {}
      rethrow;
    }
  }

  /// Google's recorded hourly conditions for the last 24 h at a point,
  /// oldest first (for comparing with a weather station's readings).
  static Future<List<GoogleHistoryHour>> historyForLocation(double lat, double lon) async {
    final r = await _call({'action': 'history', 'lat': lat, 'lon': lon});
    return ((r['hours'] as List?) ?? const [])
        .map((h) => GoogleHistoryHour.fromJson(_m(h)))
        .whereType<GoogleHistoryHour>()
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
  }

  /// Finds a place by name (biased to Kenya). Null when nothing matches.
  static Future<GooglePlace?> search(String query) async {
    final r = await _call({'action': 'geocode', 'query': query});
    if (r['notFound'] == true) return null;
    return GooglePlace(_d(r['lat']), _d(r['lon']), (r['label'] as String?) ?? query);
  }

  /// A short place name for coordinates, or null.
  static Future<String?> placeName(double lat, double lon) async {
    try {
      final r = await _call({'action': 'reverse', 'lat': lat, 'lon': lon});
      return r['label'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// User-facing message for a failed call.
  static String friendlyError(Object e) {
    if (e is FirebaseFunctionsException) {
      if (e.code == 'unavailable' || e.code == 'invalid-argument') {
        return e.message ?? 'The weather service is not available right now.';
      }
      if (e.code == 'unauthenticated') return 'Please sign in again to load the weather.';
    }
    return 'Could not load the weather — check your internet connection.';
  }
}
