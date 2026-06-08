// lib/services/farm_location_service.dart
//
// Resolves a farmer's GPS coordinates from the county saved at registration.
//
// HOW IT WORKS:
//   Registration saves:  Users/{uid} → { county: "Nakuru", constituency: "Naivasha", ward: "..." }
//   This service reads that county, looks it up in kenya_coordinates.dart,
//   and returns a FarmLocation with lat/lng.
//
// The coordinates are used by:
//   - NasaPowerService  → fetches satellite weather for THIS farm's county
//   - IotSensorService  → queries Firestore for IoT nodes tagged to THIS county
//
// COUNTY NAMES must match kenya_locations.dart exactly:
//   'Nairobi City'  'Taita Taveta'  'Trans Nzoia'
//   'Tharaka Nithi'  "Murang'a"  'Elgeyo Marakwet'

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kilimomkononi/data/kenya_coordinates.dart';

class FarmLocation {
  final double latitude;
  final double longitude;

  /// County name exactly as stored in Firestore — used for IoT node matching.
  final String county;

  /// Constituency saved at registration (may be empty string).
  final String constituency;

  /// Human-readable label for UI banners.
  final String displayLabel;

  const FarmLocation({
    required this.latitude,
    required this.longitude,
    required this.county,
    required this.constituency,
    required this.displayLabel,
  });

  bool get isDefault => displayLabel.contains('default');

  @override
  String toString() =>
      'FarmLocation($displayLabel · '
      '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)})';
}

class FarmLocationService {
  FarmLocationService._();

  static const _latKey          = 'farm_lat';
  static const _lngKey          = 'farm_lng';
  static const _countyKey       = 'farm_county';
  static const _constituencyKey = 'farm_constituency';
  static const _labelKey        = 'farm_label';

  static FarmLocation? _cached;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns the farmer's location.
  /// Order: in-memory → SharedPreferences → Firestore.
  /// Never throws — falls back to Nairobi City so callers always get valid coords.
  static Future<FarmLocation> getLocation() async {
    if (_cached != null) return _cached!;

    final prefs = await SharedPreferences.getInstance();
    final cachedLat    = prefs.getDouble(_latKey);
    final cachedLng    = prefs.getDouble(_lngKey);
    final cachedCounty = prefs.getString(_countyKey);
    final cachedLabel  = prefs.getString(_labelKey);

    if (cachedLat != null && cachedLng != null &&
        cachedCounty != null && cachedLabel != null) {
      _cached = FarmLocation(
        latitude:     cachedLat,
        longitude:    cachedLng,
        county:       cachedCounty,
        constituency: prefs.getString(_constituencyKey) ?? '',
        displayLabel: cachedLabel,
      );
      return _cached!;
    }

    return _fetchAndCache(prefs);
  }

  /// Force re-read from Firestore — call after user updates their county in profile.
  static Future<FarmLocation> refresh() async {
    _cached = null;
    final prefs = await SharedPreferences.getInstance();
    for (final k in [_latKey, _lngKey, _countyKey, _constituencyKey, _labelKey]) {
      await prefs.remove(k);
    }
    return _fetchAndCache(prefs);
  }

  /// Clear all caches — MUST be called on sign-out so the next user gets their own farm data.
  static Future<void> clear() async {
    _cached = null;
    final prefs = await SharedPreferences.getInstance();
    for (final k in [_latKey, _lngKey, _countyKey, _constituencyKey, _labelKey]) {
      await prefs.remove(k);
    }
  }

  // ── Private ────────────────────────────────────────────────────────────────

  static Future<FarmLocation> _fetchAndCache(SharedPreferences prefs) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return _fallback();

      final doc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(uid)
          .get();

      if (!doc.exists) return _fallback();

      final data         = doc.data()!;
      final county       = ((data['county']       as String?) ?? '').trim();
      final constituency = ((data['constituency'] as String?) ?? '').trim();
      final ward         = ((data['ward']         as String?) ?? '').trim();

      if (county.isEmpty) return _fallback();

      final coords = coordinatesForCounty(county);
      if (coords == null) return _fallback();

      // Build label — most specific available
      final label = ward.isNotEmpty
          ? '$ward, $constituency'
          : constituency.isNotEmpty
              ? '$constituency, $county'
              : county;

      final location = FarmLocation(
        latitude:     coords.lat,
        longitude:    coords.lng,
        county:       county,
        constituency: constituency,
        displayLabel: label,
      );

      await prefs.setDouble(_latKey,          location.latitude);
      await prefs.setDouble(_lngKey,          location.longitude);
      await prefs.setString(_countyKey,       location.county);
      await prefs.setString(_constituencyKey, location.constituency);
      await prefs.setString(_labelKey,        location.displayLabel);

      _cached = location;
      return location;
    } catch (_) {
      return _fallback();
    }
  }

  static FarmLocation _fallback() => const FarmLocation(
        latitude:     -1.2921,
        longitude:    36.8219,
        county:       'Nairobi City',
        constituency: '',
        displayLabel: 'Nairobi City (default)',
      );
}