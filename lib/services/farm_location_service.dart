// lib/services/farm_location_service.dart
//
// Single source of truth for "what GPS coordinates should API calls use?"
//
// PRIORITY ORDER (highest wins):
//   1. Selected plot GPS   — farmer picked a specific plot that has lat/lon
//   2. County centroid     — selected/first plot has no GPS yet
//   3. Registration county — no plots at all; fall back to registration county
//
// BACKWARD COMPATIBILITY:
//   All existing callers use FarmLocationService.getLocation() which still
//   works exactly as before — it now returns the best available location
//   instead of always returning the registration county.
//
//   FarmLocation gains two new optional fields (plotId, isPlotGps) that
//   existing callers can ignore.
//
// NEW CALLERS (satellite screen, weather screen) additionally use:
//   • loadPlots(userId)         — for the plot-switcher dropdown
//   • selectPlot(userId, plotId) — user changes which farm to view
//   • getSelectedPlotId()        — read the persisted selection
//   • savePlotGps(userId, plotId, lat, lon) — called from plot_input_form
//


import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kilimomkononi/data/kenya_coordinates.dart';

import 'package:flutter/foundation.dart';
// ── FarmLocation ─────────────────────────────────────────────────────────────
// Returned by getLocation() / getEffectiveLocation().
// Existing fields are unchanged so existing callers keep compiling.

class FarmLocation {
  final double latitude;
  final double longitude;

  /// County name exactly as stored in Firestore (used for IoT node matching).
  final String county;

  /// Constituency saved at registration (may be empty).
  final String constituency;

  /// Human-readable label for UI banners — same as before.
  final String displayLabel;

  // ── New fields (optional — ignored by existing callers) ──────────────────

  /// The plotId whose GPS is being used, or null if county centroid.
  final String? plotId;

  /// Plot name for the switcher dropdown.
  final String? plotName;

  /// true = real plot GPS pin; false = county centroid estimate.
  final bool isPlotGps;

  const FarmLocation({
    required this.latitude,
    required this.longitude,
    required this.county,
    required this.constituency,
    required this.displayLabel,
    this.plotId,
    this.plotName,
    this.isPlotGps = false,
  });

  bool get isDefault => displayLabel.contains('default');

  @override
  String toString() =>
      'FarmLocation($displayLabel · '
      '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}'
      '${isPlotGps ? " [GPS]" : " [county]"})';
}

// ── PlotSummary ───────────────────────────────────────────────────────────────
// Lightweight object used in the plot-switcher dropdown.

class PlotSummary {
  final String  id;
  final String  name;
  final double? latitude;
  final double? longitude;
  final String  county;

  const PlotSummary({
    required this.id,
    required this.name,
    this.latitude,
    this.longitude,
    this.county = '',
  });

  bool get hasGps => latitude != null && longitude != null;

  String get locationLabel {
    if (hasGps) {
      return '${latitude!.toStringAsFixed(4)}°, ${longitude!.toStringAsFixed(4)}°';
    }
    return county.isNotEmpty ? county : 'No location set';
  }

  factory PlotSummary.fromMap(String docId, Map<String, dynamic> m) =>
      PlotSummary(
        id:        docId,
        name:      (m['name']      as String?) ?? docId,
        latitude:  (m['latitude']  as num?)?.toDouble(),
        longitude: (m['longitude'] as num?)?.toDouble(),
        county:    (m['county']    as String?) ?? '',
      );
}

// ── Kenya county centroids ────────────────────────────────────────────────────
// Used when a plot exists but has no GPS pin yet.

const _kCentroids = <String, (double, double)>{
  'Nairobi City':     (-1.2921,  36.8219),
  'Mombasa':          (-4.0435,  39.6682),
  'Kisumu':           (-0.0917,  34.7679),
  'Nakuru':           (-0.3031,  36.0800),
  'Uasin Gishu':      ( 0.5143,  35.2698),
  'Kakamega':         ( 0.2827,  34.7519),
  'Meru':             ( 0.0500,  37.6500),
  'Embu':             (-0.5300,  37.4500),
  'Nyeri':            (-0.4167,  36.9500),
  'Kirinyaga':        (-0.5600,  37.2700),
  "Murang'a":         (-0.7167,  37.1500),
  'Kiambu':           (-1.0300,  36.8300),
  'Machakos':         (-1.5177,  37.2634),
  'Makueni':          (-2.2559,  37.8945),
  'Kitui':            (-1.3672,  38.0104),
  'Kajiado':          (-1.8516,  36.7820),
  'Narok':            (-1.0833,  35.8700),
  'Kericho':          (-0.3669,  35.2863),
  'Bomet':            (-0.7830,  35.3419),
  'Nandi':            ( 0.1833,  35.1000),
  'Trans Nzoia':      ( 1.0564,  34.9506),
  'Bungoma':          ( 0.5635,  34.5606),
  'Busia':            ( 0.4606,  34.1110),
  'Siaya':            (-0.0625,  34.2879),
  'Kisii':            (-0.6817,  34.7667),
  'Nyamira':          (-0.5700,  34.9300),
  'Homa Bay':         (-0.5273,  34.4571),
  'Migori':           (-1.0634,  34.4731),
  'Vihiga':           ( 0.0706,  34.7238),
  'Laikipia':         ( 0.3600,  36.7800),
  'Nyandarua':        (-0.4500,  36.5500),
  'Tharaka Nithi':    (-0.2990,  37.9256),
  'Isiolo':           ( 0.3542,  37.5822),
  'Marsabit':         ( 2.3284,  37.9899),
  'Samburu':          ( 1.2000,  36.8000),
  'Turkana':          ( 3.3192,  35.5657),
  'West Pokot':       ( 1.7400,  35.1200),
  'Baringo':          ( 0.6667,  35.9667),
  'Elgeyo Marakwet':  ( 0.7167,  35.5167),
  'Kwale':            (-4.1833,  39.4500),
  'Kilifi':           (-3.6297,  39.8509),
  'Tana River':       (-1.4000,  40.0000),
  'Lamu':             (-2.2694,  40.9021),
  'Taita Taveta':     (-3.4000,  38.5000),
  'Garissa':          (-0.4532,  39.6460),
  'Wajir':            ( 1.7500,  40.0573),
  'Mandera':          ( 3.9366,  41.8670),
};

(double, double) _centroidFor(String county) {
  if (_kCentroids.containsKey(county)) return _kCentroids[county]!;
  // Fuzzy match — handles slight name differences
  for (final e in _kCentroids.entries) {
    if (county.toLowerCase().contains(e.key.toLowerCase()) ||
        e.key.toLowerCase().contains(county.toLowerCase())) {
      return e.value;
    }
  }
  return (-1.2921, 36.8219); // Nairobi fallback
}

// ── FarmLocationService ───────────────────────────────────────────────────────

class FarmLocationService {
  FarmLocationService._();

  // SharedPreferences keys
  static const _latKey          = 'farm_lat';
  static const _lngKey          = 'farm_lng';
  static const _countyKey       = 'farm_county';
  static const _constituencyKey = 'farm_constituency';
  static const _labelKey        = 'farm_label';
  static const _selectedPlotKey = 'selected_farm_plot_id';

  static FarmLocation? _cached;

  // ── Primary API (used by ALL screens) ─────────────────────────────────────

  /// Returns the best available farm location.
  /// Priority: selected plot GPS → county centroid → registration county.
  /// Never throws. Falls back to Nairobi so callers always get valid coords.
  static Future<FarmLocation> getLocation() async {
    // Try plot-GPS path first
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        final plotLoc = await _locationFromSelectedPlot(uid);
        if (plotLoc != null) return plotLoc;
      } catch (_) {}
    }

    // Fall back to old county-based path
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

  // ── Plot-switcher API (used by satellite & weather screens) ───────────────

  /// Load all plots for the switcher dropdown.
  static Future<List<PlotSummary>> loadPlots(String userId) async {
    if (userId.isEmpty) return [];
    try {
      final snap = await FirebaseFirestore.instance
          .collection('fielddata')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();

      // Deduplicate by plotId — keep most recent entry per plot
      final seen = <String>{};
      final summaries = <PlotSummary>[];
      for (final doc in snap.docs) {
        final d     = doc.data();
        final id    = (d['plotId'] as String?) ?? doc.id;
        if (seen.contains(id)) continue;
        seen.add(id);
        summaries.add(PlotSummary(
          id:        id,
          name:      (d['plotName'] as String?) ?? id,
          latitude:  (d['latitude']  as num?)?.toDouble(),
          longitude: (d['longitude'] as num?)?.toDouble(),
          county:    (d['county']    as String?) ?? '',
        ));
      }
      return summaries;
    } catch (e) {
      debugPrint('FarmLocationService.loadPlots error: $e');
      return [];
    }
  }

  /// Persist which plot the user is currently viewing.
  static Future<void> selectPlot(String plotId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedPlotKey, plotId);
    // Clear NASA cache so next fetch uses new coordinates
    _cached = null;
  }

  static Future<String?> getSelectedPlotId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedPlotKey);
  }

  static Future<void> clearSelection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_selectedPlotKey);
    _cached = null;
  }

  /// Save plot GPS to Firestore — called from plot_input_form after pin confirmed.
  static Future<void> savePlotGps(
      String userId, String plotId, double lat, double lon) async {
    if (userId.isEmpty || plotId.isEmpty) return;
    try {
      // Update ALL field data documents for this plot
      final snap = await FirebaseFirestore.instance
          .collection('fielddata')
          .where('userId', isEqualTo: userId)
          .where('plotId', isEqualTo: plotId)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {
          'latitude':  lat,
          'longitude': lon,
          'locationUpdatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      // If this is the currently selected plot, bust the cache
      final selectedId = await getSelectedPlotId();
      if (selectedId == plotId || selectedId == null) {
        _cached = null;
      }

      debugPrint('FarmLocationService: saved GPS ($lat, $lon) to $plotId');
    } catch (e) {
      debugPrint('FarmLocationService.savePlotGps error: $e');
    }
  }

  // ── Cache management ──────────────────────────────────────────────────────

  static Future<FarmLocation> refresh() async {
    _cached = null;
    final prefs = await SharedPreferences.getInstance();
    for (final k in [_latKey, _lngKey, _countyKey, _constituencyKey, _labelKey]) {
      await prefs.remove(k);
    }
    return getLocation();
  }

  static Future<void> clear() async {
    _cached = null;
    final prefs = await SharedPreferences.getInstance();
    for (final k in [
      _latKey, _lngKey, _countyKey, _constituencyKey, _labelKey,
      _selectedPlotKey,
    ]) {
      await prefs.remove(k);
    }
  }

  // ── Private ───────────────────────────────────────────────────────────────

  /// Tries to resolve a FarmLocation from the user's selected (or first) plot.
  static Future<FarmLocation?> _locationFromSelectedPlot(String uid) async {
    final plots = await loadPlots(uid);
    if (plots.isEmpty) return null;

    final selectedId = await getSelectedPlotId();

    // Find selected plot, fall back to first
    PlotSummary? plot;
    if (selectedId != null) {
      plot = plots.where((p) => p.id == selectedId).firstOrNull;
    }
    plot ??= plots.first;

    if (plot.hasGps) {
      return FarmLocation(
        latitude:     plot.latitude!,
        longitude:    plot.longitude!,
        county:       plot.county,
        constituency: '',
        displayLabel: '${plot.name} · GPS',
        plotId:       plot.id,
        plotName:     plot.name,
        isPlotGps:    true,
      );
    }

    // Plot exists but no GPS — use county centroid with a note
    final county = plot.county.isNotEmpty ? plot.county : 'Nairobi City';
    final c = _centroidFor(county);
    return FarmLocation(
      latitude:     c.$1,
      longitude:    c.$2,
      county:       county,
      constituency: '',
      displayLabel: '${plot.name} · $county (estimate)',
      plotId:       plot.id,
      plotName:     plot.name,
      isPlotGps:    false,
    );
  }

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