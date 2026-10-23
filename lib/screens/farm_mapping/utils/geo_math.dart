import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

class GeoMath {
  static const double _earthRadius = 6371000.0;

  static double haversineDistanceMeters(LatLng a, LatLng b) {
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final sinLat = math.sin(dLat / 2);
    final sinLon = math.sin(dLon / 2);
    final c = sinLat * sinLat +
        math.cos(_rad(a.latitude)) * math.cos(_rad(b.latitude)) * sinLon * sinLon;
    return 2 * _earthRadius * math.atan2(math.sqrt(c), math.sqrt(1 - c));
  }

  // Equirectangular shoelace — accurate for sub-1000 ha farm scale.
  static double shoelaceAreaHectares(List<LatLng> pts) {
    final n = pts.length;
    if (n < 3) return 0;
    final latC = pts.map((p) => p.latitude).reduce((a, b) => a + b) / n;
    final cosLat = math.cos(_rad(latC));
    double area = 0;
    for (int i = 0; i < n; i++) {
      final j = (i + 1) % n;
      final xi = _rad(pts[i].longitude) * _earthRadius * cosLat;
      final yi = _rad(pts[i].latitude) * _earthRadius;
      final xj = _rad(pts[j].longitude) * _earthRadius * cosLat;
      final yj = _rad(pts[j].latitude) * _earthRadius;
      area += xi * yj - xj * yi;
    }
    return area.abs() / 2 / 10000;
  }

  static double haversinePerimeterMeters(List<LatLng> pts) {
    if (pts.length < 2) return 0;
    double total = 0;
    for (int i = 0; i < pts.length; i++) {
      total += haversineDistanceMeters(pts[i], pts[(i + 1) % pts.length]);
    }
    return total;
  }

  static LatLng centroid(List<LatLng> pts) {
    if (pts.isEmpty) return const LatLng(-1.2921, 36.8219);
    final lat = pts.map((p) => p.latitude).reduce((a, b) => a + b) / pts.length;
    final lng = pts.map((p) => p.longitude).reduce((a, b) => a + b) / pts.length;
    return LatLng(lat, lng);
  }

  static String areaLabel(double ha) {
    if (ha >= 1.0) return '${ha.toStringAsFixed(2)} ha';
    if (ha > 0) return '${(ha * 10000).toStringAsFixed(0)} m²';
    return '—';
  }

  static String perimeterLabel(double m) {
    if (m >= 1000) return '${(m / 1000).toStringAsFixed(2)} km';
    if (m > 0) return '${m.toStringAsFixed(0)} m';
    return '—';
  }

  // Index to splice a new point into with minimum extra perimeter (autoFit mode).
  static int bestInsertionIndex(List<LatLng> pts, LatLng p) {
    final n = pts.length;
    if (n < 3) return n;
    double best = double.infinity;
    int idx = n;
    for (int i = 0; i < n; i++) {
      final a = pts[i], b = pts[(i + 1) % n];
      final cost = haversineDistanceMeters(a, p) +
          haversineDistanceMeters(p, b) -
          haversineDistanceMeters(a, b);
      if (cost < best) {
        best = cost;
        idx = i + 1;
      }
    }
    return idx;
  }

  // ── Topography helpers ────────────────────────────────────────────────────

  /// Slope as a percentage: rise/run × 100 (always positive).
  static double slopePercent(double altA, double altB, double horizontalDistM) {
    if (horizontalDistM <= 0) return 0;
    return ((altB - altA).abs() / horizontalDistM) * 100;
  }

  /// Compass bearing from [from] to [to] in degrees (0 = N, 90 = E …).
  static double bearingDegrees(LatLng from, LatLng to) {
    final dLng = _rad(to.longitude - from.longitude);
    final lat1 = _rad(from.latitude);
    final lat2 = _rad(to.latitude);
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  /// Converts a bearing (0–360°) to a compass label: N, NE, E … NW.
  static String bearingLabel(double degrees) {
    const labels = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW', 'N'];
    return labels[((degrees + 22.5) / 45).floor().clamp(0, 8)];
  }

  /// Human description of terrain relief from the altitude range in metres.
  static String terrainDescription(double rangeM) {
    if (rangeM < 3) return 'Relatively flat terrain';
    if (rangeM < 10) return 'Gently undulating terrain';
    if (rangeM < 25) return 'Moderately sloping terrain';
    return 'Steeply sloping terrain';
  }

  /// Average slope % across all consecutive boundary point pairs.
  static double averageSlopePercent(List<LatLng> pts, List<double> alts) {
    if (pts.length < 2 || alts.length < pts.length) return 0;
    double total = 0;
    int count = 0;
    for (int i = 0; i < pts.length - 1; i++) {
      final d = haversineDistanceMeters(pts[i], pts[i + 1]);
      if (d > 0.1) {
        total += slopePercent(alts[i], alts[i + 1], d);
        count++;
      }
    }
    return count > 0 ? total / count : 0;
  }

  /// Bearing from lowest to highest point — dominant "uphill" direction.
  static double uphillBearing(List<LatLng> pts, List<double> alts) {
    if (pts.isEmpty || alts.length < pts.length) return 0;
    int minIdx = 0, maxIdx = 0;
    for (int i = 1; i < alts.length; i++) {
      if (alts[i] < alts[minIdx]) minIdx = i;
      if (alts[i] > alts[maxIdx]) maxIdx = i;
    }
    return bearingDegrees(pts[minIdx], pts[maxIdx]);
  }

  /// Cumulative distances (metres) from the first point — for profile chart X-axis.
  static List<double> cumulativeDistances(List<LatLng> pts) {
    final result = <double>[0];
    for (int i = 1; i < pts.length; i++) {
      result.add(result.last + haversineDistanceMeters(pts[i - 1], pts[i]));
    }
    return result;
  }

  static double _rad(double d) => d * math.pi / 180;
}
