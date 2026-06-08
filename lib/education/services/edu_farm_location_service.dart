// lib/education/services/edu_farm_location_service.dart
//
// Education-only location service. Completely separate from the enterprise
// FarmLocationService (lib/services/farm_location_service.dart).
//
// ── WHY SEPARATE ───────────────────────────────────────────────────────────
// The enterprise service reads from Users/{uid} (a farmer's registered county).
// The education service reads from Schools/{schoolId} (the school's location).
// They serve different users, different Firestore paths, and different caches.
// Mixing them would cause the wrong GPS to be used for NASA POWER requests.
//
// ── HOW SCHOOL LOCATION IS RESOLVED ───────────────────────────────────────
// Priority order:
//   1. In-memory cache (per schoolId, cleared on sign-out)
//   2. Firestore Schools/{schoolId} → lat/lng fields (set by headteacher)
//   3. Firestore Schools/{schoolId} → county field  (county centroid fallback)
//   4. classId-parsed school name → kenya_coordinates lookup
//   5. Hard fallback: Nairobi City
//
// ── FIRESTORE SCHEMA ──────────────────────────────────────────────────────
// Schools/{schoolId}
// {
//   name:         "Kiptangus Primary",
//   county:       "Nandi",
//   constituency: "Chesumei",
//   lat:          0.3541,      ← written at headteacher registration (optional)
//   lng:          35.1581,     ← written at headteacher registration (optional)
//   iotNodeId:    "sch_001"    ← optional, Phase 2
// }
//
// ── USAGE ──────────────────────────────────────────────────────────────────
// final loc = await EduFarmLocationService.getLocation(schoolName: schoolName);
// // loc.latitude, loc.longitude, loc.county, loc.displayLabel

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kilimomkononi/data/kenya_coordinates.dart';

// ── Model (mirrors FarmLocation but is education-namespaced) ───────────────

class EduSchoolLocation {
  final double latitude;
  final double longitude;
  final String county;
  final String constituency;
  final String displayLabel;
  final String schoolId;
  final bool hasRealGps; // true = actual GPS stored; false = county centroid

  const EduSchoolLocation({
    required this.latitude,
    required this.longitude,
    required this.county,
    required this.constituency,
    required this.displayLabel,
    required this.schoolId,
    required this.hasRealGps,
  });

  @override
  String toString() =>
      'EduSchoolLocation($displayLabel · '
      '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}'
      '${hasRealGps ? ' [GPS]' : ' [county centroid]'})';
}

// ── Service ────────────────────────────────────────────────────────────────

class EduFarmLocationService {
  EduFarmLocationService._();

  /// In-memory cache keyed by schoolId.
  /// Multiple tabs in the same session share one resolve call.
  static final Map<String, EduSchoolLocation> _cache = {};

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns the school's location.
  ///
  /// [schoolName] is the school identifier as it appears in the classId
  /// prefix, e.g. "Kiptangus_Primary" or "St_Marys_Lavington".
  ///
  /// Never throws — always returns a valid location.
  static Future<EduSchoolLocation> getLocation({
    required String schoolName,
  }) async {
    if (schoolName.isEmpty) return _fallback('unknown');

    // 1. In-memory cache
    if (_cache.containsKey(schoolName)) return _cache[schoolName]!;

    // 2 + 3. Firestore Schools collection
    final fromFirestore = await _resolveFromFirestore(schoolName);
    if (fromFirestore != null) {
      _cache[schoolName] = fromFirestore;
      return fromFirestore;
    }

    // 4. County name from schoolName heuristic
    final fromCounty = _resolveFromSchoolNameHeuristic(schoolName);
    if (fromCounty != null) {
      _cache[schoolName] = fromCounty;
      return fromCounty;
    }

    // 5. Hard fallback
    final fallback = _fallback(schoolName);
    _cache[schoolName] = fallback;
    return fallback;
  }

  /// Force re-resolve — call after headteacher updates school GPS.
  static Future<EduSchoolLocation> refresh({required String schoolName}) async {
    _cache.remove(schoolName);
    return getLocation(schoolName: schoolName);
  }

  /// Clear one school from cache.
  static void invalidate(String schoolName) => _cache.remove(schoolName);

  /// Clear all cached locations — call on sign-out.
  static void clearAll() => _cache.clear();

  // ── Firestore resolution ───────────────────────────────────────────────────

  static Future<EduSchoolLocation?> _resolveFromFirestore(
      String schoolName) async {
    try {
      // Try exact match on 'name' field first
      final humanName = schoolName.replaceAll('_', ' ');

      QuerySnapshot? snap;

      // Try by document ID (schoolName used as doc ID at registration)
      final byId = await FirebaseFirestore.instance
          .collection('Schools')
          .doc(schoolName)
          .get();

      if (byId.exists) {
        return _locationFromDoc(byId.data() as Map<String, dynamic>, schoolName);
      }

      // Try query by name field
      snap = await FirebaseFirestore.instance
          .collection('Schools')
          .where('name', isEqualTo: humanName)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        // Try case-insensitive partial — search by first word of school name
        final firstWord = humanName.split(' ').first;
        snap = await FirebaseFirestore.instance
            .collection('Schools')
            .where('name', isGreaterThanOrEqualTo: firstWord)
            .where('name', isLessThan: '${firstWord}z')
            .limit(3)
            .get();
      }

      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data() as Map<String, dynamic>;
        return _locationFromDoc(data, schoolName);
      }
    } catch (_) {}
    return null;
  }

  static EduSchoolLocation? _locationFromDoc(
      Map<String, dynamic> data, String schoolName) {
    final county       = ((data['county']       as String?) ?? '').trim();
    final constituency = ((data['constituency'] as String?) ?? '').trim();
    final lat          = (data['lat']  as num?)?.toDouble();
    final lng          = (data['lng']  as num?)?.toDouble();
    final name         = (data['name'] as String?) ?? schoolName.replaceAll('_', ' ');

    // GPS stored → use it
    if (lat != null && lng != null && county.isNotEmpty) {
      return EduSchoolLocation(
        latitude:     lat,
        longitude:    lng,
        county:       county,
        constituency: constituency,
        displayLabel: name,
        schoolId:     schoolName,
        hasRealGps:   true,
      );
    }

    // No GPS but county stored → county centroid
    if (county.isNotEmpty) {
      final coords = coordinatesForCounty(county);
      if (coords != null) {
        return EduSchoolLocation(
          latitude:     coords.lat,
          longitude:    coords.lng,
          county:       county,
          constituency: constituency,
          displayLabel: name,
          schoolId:     schoolName,
          hasRealGps:   false,
        );
      }
    }

    return null;
  }

  // ── Heuristic: extract county from school name ─────────────────────────────
  // Some school names embed the county/location, e.g. "Nakuru_Hills_Primary".
  // We check each word against kenya_coordinates county names.

  static EduSchoolLocation? _resolveFromSchoolNameHeuristic(String schoolName) {
    final words = schoolName.replaceAll('_', ' ').split(' ');
    for (final word in words) {
      final coords = coordinatesForCounty(word);
      if (coords != null) {
        return EduSchoolLocation(
          latitude:     coords.lat,
          longitude:    coords.lng,
          county:       word,
          constituency: '',
          displayLabel: schoolName.replaceAll('_', ' '),
          schoolId:     schoolName,
          hasRealGps:   false,
        );
      }
    }
    return null;
  }

  // ── Hard fallback ──────────────────────────────────────────────────────────

  static EduSchoolLocation _fallback(String schoolName) => EduSchoolLocation(
        latitude:     -1.2921,
        longitude:    36.8219,
        county:       'Nairobi City',
        constituency: '',
        displayLabel: schoolName.isEmpty
            ? 'Unknown School'
            : schoolName.replaceAll('_', ' '),
        schoolId:     schoolName,
        hasRealGps:   false,
      );
}