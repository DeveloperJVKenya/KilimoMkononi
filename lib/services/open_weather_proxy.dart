// lib/services/open_weather_proxy.dart
//
// OpenWeatherMap via the `getOpenWeather` Cloud Function, so the API key
// stays in Secret Manager instead of shipping inside the app (it used to be
// hard-coded in lib/config.dart).
//
// Returns an http.Response carrying OpenWeatherMap's own status code and JSON
// body, so callers keep their existing statusCode / jsonDecode(body) logic.

import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;

class OpenWeatherProxy {
  OpenWeatherProxy._();

  /// Geocode a place name — mirrors /geo/1.0/direct.
  static Future<http.Response> geocode(String query, {int limit = 1}) =>
      _call('geo', {'q': query, 'limit': limit});

  /// Current conditions — mirrors /data/2.5/weather (metric units).
  static Future<http.Response> current(double lat, double lon) =>
      _call('weather', {'lat': lat, 'lon': lon, 'units': 'metric'});

  /// 5-day / 3-hour forecast — mirrors /data/2.5/forecast (metric units).
  static Future<http.Response> forecast(double lat, double lon) =>
      _call('forecast', {'lat': lat, 'lon': lon, 'units': 'metric'});

  static Future<http.Response> _call(
      String endpoint, Map<String, dynamic> params) async {
    final fn = FirebaseFunctions.instance.httpsCallable(
      'getOpenWeather',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
    );
    final res = await fn.call({'endpoint': endpoint, 'params': params});
    final data = Map<String, dynamic>.from(res.data as Map);
    return http.Response(
      jsonEncode(data['data']),
      (data['status'] as num?)?.toInt() ?? 500,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}
