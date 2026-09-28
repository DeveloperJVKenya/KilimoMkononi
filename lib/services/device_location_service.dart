// lib/services/device_location_service.dart
//
// The device's position for "My location" features, tuned for speed:
//
//   • Low accuracy — weather needs ~1 km, not GPS precision, and a low-
//     accuracy fix (Wi-Fi / cell) arrives far faster than a GPS one.
//   • Recent fixes are reused: the browser may return a cached position up
//     to 15 min old (web default is 0 = always a fresh lookup, which on a
//     desktop can take 10–20 s); Android's last known position is used
//     when it's recent.
//   • The last fix is saved on the device, so screens can show weather for
//     it instantly while a fresh fix is found.
//   • Capped wait (10 s by default) with a clear reason when it fails.
//
// Timings are logged ([DeviceLocation] …) to diagnose slow devices.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LocationProblem { denied, blocked, serviceOff, timeout, error }

class LocationUnavailable implements Exception {
  final LocationProblem problem;
  final Object? cause;
  const LocationUnavailable(this.problem, [this.cause]);

  /// What to tell the user (the screen falls back to the farm location).
  String get message => switch (problem) {
        LocationProblem.denied => 'Location permission wasn\'t given',
        LocationProblem.blocked => kIsWeb
            ? 'Location is blocked for this site — allow it from the lock icon in the address bar'
            : 'Location is blocked for Kilimo Mkononi — allow it in the phone\'s app settings',
        LocationProblem.serviceOff => 'Location is turned off on this device',
        LocationProblem.timeout => 'Finding your location is taking too long',
        LocationProblem.error => 'Couldn\'t get your location',
      };

  @override
  String toString() => 'LocationUnavailable($problem, $cause)';
}

class DeviceFix {
  final double latitude;
  final double longitude;
  final DateTime at;

  /// Optional place name saved with the fix (e.g. "Nakuru, Nakuru County").
  final String? label;

  const DeviceFix(this.latitude, this.longitude, this.at, {this.label});

  Duration get age => DateTime.now().difference(at);

  /// Metres between two fixes.
  double distanceTo(DeviceFix o) => Geolocator.distanceBetween(latitude, longitude, o.latitude, o.longitude);

  DeviceFix withLabel(String? l) => DeviceFix(latitude, longitude, at, label: l);

  Map<String, dynamic> toJson() =>
      {'lat': latitude, 'lon': longitude, 'at': at.toIso8601String(), 'label': label};

  static DeviceFix? fromJson(Map<String, dynamic> j) {
    final at = DateTime.tryParse('${j['at']}');
    final lat = (j['lat'] as num?)?.toDouble();
    final lon = (j['lon'] as num?)?.toDouble();
    if (at == null || lat == null || lon == null) return null;
    return DeviceFix(lat, lon, at, label: j['label'] as String?);
  }
}

class DeviceLocationService {
  DeviceLocationService._();

  static const _key = 'km_last_device_fix';
  static const _reuseFor = Duration(minutes: 15);

  /// The last fix saved on this device, if any.
  static Future<DeviceFix?> lastSaved() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null) return null;
      return DeviceFix.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(DeviceFix fix) async {
    try {
      await (await SharedPreferences.getInstance()).setString(_key, jsonEncode(fix.toJson()));
    } catch (_) {}
  }

  static LocationSettings _settings(Duration timeout) {
    if (kIsWeb) {
      return WebSettings(accuracy: LocationAccuracy.low, maximumAge: _reuseFor, timeLimit: timeout);
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(accuracy: LocationAccuracy.low, timeLimit: timeout);
    }
    return LocationSettings(accuracy: LocationAccuracy.low, timeLimit: timeout);
  }

  /// A current fix (or a recent one), within [timeout]. Throws
  /// [LocationUnavailable] with the reason when it can't.
  static Future<DeviceFix> current({Duration timeout = const Duration(seconds: 10)}) async {
    final sw = Stopwatch()..start();
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      debugPrint('[DeviceLocation] permission=$permission after ${sw.elapsedMilliseconds} ms');
      if (permission == LocationPermission.deniedForever) throw const LocationUnavailable(LocationProblem.blocked);
      if (permission == LocationPermission.denied) throw const LocationUnavailable(LocationProblem.denied);
      if (!await Geolocator.isLocationServiceEnabled()) throw const LocationUnavailable(LocationProblem.serviceOff);

      // Android/iOS: a recent last-known position is instant.
      if (!kIsWeb) {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null && DateTime.now().difference(last.timestamp) < _reuseFor) {
          final fix = DeviceFix(last.latitude, last.longitude, last.timestamp);
          debugPrint('[DeviceLocation] last known position (${fix.age.inMinutes} min old) in ${sw.elapsedMilliseconds} ms');
          await save(fix);
          return fix;
        }
      }

      final p = await Geolocator.getCurrentPosition(locationSettings: _settings(timeout));
      final fix = DeviceFix(p.latitude, p.longitude, DateTime.now());
      debugPrint('[DeviceLocation] fix ±${p.accuracy.round()} m in ${sw.elapsedMilliseconds} ms');
      await save(fix);
      return fix;
    } on LocationUnavailable {
      rethrow;
    } on TimeoutException catch (e) {
      debugPrint('[DeviceLocation] timed out after ${sw.elapsedMilliseconds} ms');
      throw LocationUnavailable(LocationProblem.timeout, e);
    } on PermissionDeniedException catch (e) {
      throw LocationUnavailable(LocationProblem.denied, e);
    } on LocationServiceDisabledException catch (e) {
      throw LocationUnavailable(LocationProblem.serviceOff, e);
    } catch (e) {
      debugPrint('[DeviceLocation] failed after ${sw.elapsedMilliseconds} ms: $e');
      // Browsers report a timeout as a PositionError with code 3.
      final text = '$e'.toLowerCase();
      throw LocationUnavailable(
          text.contains('timeout') || text.contains('time out') ? LocationProblem.timeout : LocationProblem.error, e);
    }
  }
}
