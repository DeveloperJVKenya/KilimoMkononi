import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:kilimomkononi/screens/farm_mapping/models/farm_plot_model.dart';
import 'package:kilimomkononi/screens/farm_mapping/utils/geo_math.dart';
import 'package:latlong2/latlong.dart';

// ── Elevation colour ramp  (blue → cyan → green → yellow → red) ──────────────

Color _elevationColor(double t) {
  t = t.clamp(0.0, 1.0);
  if (t < 0.25) return Color.lerp(const Color(0xFF1565C0), const Color(0xFF00838F), t / 0.25)!;
  if (t < 0.50) return Color.lerp(const Color(0xFF00838F), const Color(0xFF558B2F), (t - 0.25) / 0.25)!;
  if (t < 0.75) return Color.lerp(const Color(0xFF558B2F), const Color(0xFFF9A825), (t - 0.50) / 0.25)!;
  return Color.lerp(const Color(0xFFF9A825), const Color(0xFFC62828), (t - 0.75) / 0.25)!;
}

// ── Public widget ─────────────────────────────────────────────────────────────

class FarmTopoWidget extends StatefulWidget {
  final FarmPlot farm;
  const FarmTopoWidget({super.key, required this.farm});

  @override
  State<FarmTopoWidget> createState() => _FarmTopoWidgetState();
}

class _FarmTopoWidgetState extends State<FarmTopoWidget> {
  bool? _extended; // null=checking, false=farmer, true=agronomist/admin

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _extended = false);
      return;
    }
    final agro = await FirebaseFirestore.instance
        .collection('Agronomists').doc(uid).get();
    if (agro.exists) {
      setState(() => _extended = true);
      return;
    }
    final admin = await FirebaseFirestore.instance
        .collection('Admins').doc(uid).get();
    setState(() => _extended = admin.exists);
  }

  @override
  Widget build(BuildContext context) {
    final farm = widget.farm;

    if (!farm.hasTopoData) return _NoTopoData(farmName: farm.farmName);

    final alts = farm.altitudes;
    final minAlt = alts.reduce(math.min);
    final maxAlt = alts.reduce(math.max);
    final range = maxAlt - minAlt;
    final meanAlt = alts.reduce((a, b) => a + b) / alts.length;
    final uphillBearing = GeoMath.uphillBearing(farm.coordinates, alts);
    final avgSlope = GeoMath.averageSlopePercent(farm.coordinates, alts);
    final distances = GeoMath.cumulativeDistances(farm.coordinates);

    // Find highest/lowest point coordinates for directional labels
    int minIdx = 0, maxIdx = 0;
    for (int i = 1; i < alts.length; i++) {
      if (alts[i] < alts[minIdx]) minIdx = i;
      if (alts[i] > alts[maxIdx]) maxIdx = i;
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Heat-map elevation view ─────────────────────────────────────────
      _TopoMapView(farm: farm, alts: alts, minAlt: minAlt, maxAlt: maxAlt),
      const SizedBox(height: 12),

      // ── Terrain summary (farmer sees this) ─────────────────────────────
      _TerrainSummaryCard(
        range: range,
        uphillBearing: uphillBearing,
        avgSlope: avgSlope,
        highIdx: maxIdx,
        lowIdx: minIdx,
        coords: farm.coordinates,
      ),

      // ── Extended panel (agronomist / admin) ─────────────────────────────
      if (_extended == true) ...[
        const SizedBox(height: 10),
        _ExtendedTopoPanel(
          alts: alts,
          distances: distances,
          minAlt: minAlt,
          maxAlt: maxAlt,
          meanAlt: meanAlt,
          range: range,
          avgSlope: avgSlope,
          uphillBearing: uphillBearing,
        ),
      ],
    ]);
  }
}

// ── Heat-map on flutter_map ───────────────────────────────────────────────────

class _TopoMapView extends StatelessWidget {
  final FarmPlot farm;
  final List<double> alts;
  final double minAlt;
  final double maxAlt;
  const _TopoMapView({
    required this.farm, required this.alts,
    required this.minAlt, required this.maxAlt,
  });

  @override
  Widget build(BuildContext context) {
    final range = maxAlt - minAlt;

    return Container(
      height: 220,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)]),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        FlutterMap(
          options: MapOptions(
            initialCameraFit: farm.coordinates.isNotEmpty
                ? CameraFit.coordinates(
                    coordinates: farm.coordinates,
                    padding: const EdgeInsets.all(28))
                : null,
            interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/'
                  'World_Imagery/MapServer/tile/{z}/{y}/{x}',
              userAgentPackageName: 'com.jva.kilimomkononi',
            ),
            // Farm boundary
            if (farm.coordinates.length >= 3)
              PolygonLayer(polygons: [
                Polygon(
                  points: farm.coordinates,
                  color: Colors.transparent,
                  borderColor: Colors.white.withValues(alpha: 0.6),
                  borderStrokeWidth: 1.5,
                ),
              ]),
            // Elevation heat blobs at every recorded GPS point
            CircleLayer(
              circles: List.generate(
                math.min(farm.coordinates.length, alts.length),
                (i) {
                  final t = range > 0 ? (alts[i] - minAlt) / range : 0.5;
                  return CircleMarker(
                    point: farm.coordinates[i],
                    radius: 18,
                    useRadiusInMeter: false,
                    color: _elevationColor(t).withValues(alpha: 0.55),
                    borderColor: Colors.transparent,
                    borderStrokeWidth: 0,
                  );
                },
              ),
            ),
          ],
        ),
        // Legend bar
        Positioned(
          bottom: 8,
          left: 10,
          right: 10,
          child: _LegendBar(),
        ),
      ]),
    );
  }
}

// ── Colour legend ─────────────────────────────────────────────────────────────

class _LegendBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(
          colors: [
            _elevationColor(0.0),
            _elevationColor(0.25),
            _elevationColor(0.5),
            _elevationColor(0.75),
            _elevationColor(1.0),
          ],
        ),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text('Lower', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text('Higher', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── Terrain summary card (visible to all farmers) ─────────────────────────────

class _TerrainSummaryCard extends StatelessWidget {
  final double range;
  final double uphillBearing;
  final double avgSlope;
  final int highIdx;
  final int lowIdx;
  final List<LatLng> coords;

  const _TerrainSummaryCard({
    required this.range, required this.uphillBearing,
    required this.avgSlope, required this.highIdx,
    required this.lowIdx, required this.coords,
  });

  @override
  Widget build(BuildContext context) {
    final terrainType = GeoMath.terrainDescription(range);
    final uphillDir = GeoMath.bearingLabel(uphillBearing);
    final downhillDir = GeoMath.bearingLabel((uphillBearing + 180) % 360);

    final String slopeDesc;
    if (avgSlope < 2) {
      slopeDesc = 'Almost level';
    } else if (avgSlope < 8) {
      slopeDesc = 'Gentle slope';
    } else if (avgSlope < 15) {
      slopeDesc = 'Moderate slope';
    } else {
      slopeDesc = 'Steep slope';
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.terrain_rounded, color: Color(0xFF2E7D32), size: 20),
            const SizedBox(width: 8),
            const Text('Terrain overview',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          ]),
          const SizedBox(height: 12),
          _TerrainRow(Icons.landscape_rounded, 'Terrain type', terrainType, const Color(0xFF2E7D32)),
          const SizedBox(height: 8),
          _TerrainRow(Icons.arrow_upward_rounded, 'Higher ground',
              '$uphillDir side of the farm', const Color(0xFFC62828)),
          const SizedBox(height: 8),
          _TerrainRow(Icons.arrow_downward_rounded, 'Lower ground',
              '$downhillDir side of the farm', const Color(0xFF1565C0)),
          const SizedBox(height: 8),
          _TerrainRow(Icons.swap_vert_rounded, 'Slope profile', slopeDesc, const Color(0xFF5D4037)),
        ]),
      ),
    );
  }
}

class _TerrainRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _TerrainRow(this.icon, this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.black45,
                  fontWeight: FontWeight.w600)),
          Text(value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
      ]);
}

// ── Extended panel (agronomist / admin only) ──────────────────────────────────

class _ExtendedTopoPanel extends StatelessWidget {
  final List<double> alts;
  final List<double> distances;
  final double minAlt;
  final double maxAlt;
  final double meanAlt;
  final double range;
  final double avgSlope;
  final double uphillBearing;

  const _ExtendedTopoPanel({
    required this.alts, required this.distances,
    required this.minAlt, required this.maxAlt,
    required this.meanAlt, required this.range,
    required this.avgSlope, required this.uphillBearing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(Icons.bar_chart_rounded, color: Color(0xFF1565C0)),
          title: const Text('Elevation details',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          subtitle: const Text('Agronomist / admin view',
              style: TextStyle(fontSize: 11, color: Colors.black45)),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [
            // Stats grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 2.8,
              children: [
                _StatTile('Min elevation', '${minAlt.toStringAsFixed(1)} m', const Color(0xFF1565C0)),
                _StatTile('Max elevation', '${maxAlt.toStringAsFixed(1)} m', const Color(0xFFC62828)),
                _StatTile('Mean elevation', '${meanAlt.toStringAsFixed(1)} m', const Color(0xFF2E7D32)),
                _StatTile('Relief (range)', '${range.toStringAsFixed(1)} m', const Color(0xFF5D4037)),
                _StatTile('Avg slope', '${avgSlope.toStringAsFixed(1)} %', const Color(0xFF6A1B9A)),
                _StatTile('Uphill bearing',
                    '${uphillBearing.toStringAsFixed(0)}° ${GeoMath.bearingLabel(uphillBearing)}',
                    const Color(0xFF00838F)),
              ],
            ),
            const SizedBox(height: 14),
            // Elevation profile
            const Text('Elevation profile',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: Colors.black54)),
            const SizedBox(height: 6),
            SizedBox(
              height: 120,
              child: CustomPaint(
                painter: _ElevationProfilePainter(
                    alts: alts, distances: distances,
                    minAlt: minAlt, maxAlt: maxAlt),
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatTile(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600)),
          Text(value, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w800)),
        ]),
      );
}

// ── Elevation profile custom painter ─────────────────────────────────────────

class _ElevationProfilePainter extends CustomPainter {
  final List<double> alts;
  final List<double> distances;
  final double minAlt;
  final double maxAlt;

  _ElevationProfilePainter({
    required this.alts, required this.distances,
    required this.minAlt, required this.maxAlt,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (alts.length < 2) return;

    const hPad = 4.0;
    const vPad = 10.0;
    final w = size.width - hPad * 2;
    final h = size.height - vPad * 2;
    final totalDist = distances.last == 0 ? 1.0 : distances.last;
    final altRange = (maxAlt - minAlt).abs() < 0.01 ? 1.0 : maxAlt - minAlt;

    // Project a point to canvas coords
    Offset project(int i) {
      final x = hPad + (distances[i] / totalDist) * w;
      final y = vPad + h - ((alts[i] - minAlt) / altRange) * h;
      return Offset(x, y);
    }

    // Build path
    final path = ui.Path();
    final first = project(0);
    path.moveTo(first.dx, size.height - vPad);
    path.lineTo(first.dx, first.dy);
    for (int i = 1; i < alts.length; i++) {
      final p = project(i);
      path.lineTo(p.dx, p.dy);
    }
    final last = project(alts.length - 1);
    path.lineTo(last.dx, size.height - vPad);
    path.close();

    // Gradient fill
    final gradient = ui.Gradient.linear(
      Offset(0, size.height - vPad),
      Offset(0, vPad),
      [
        _elevationColor(0.0).withValues(alpha: 0.5),
        _elevationColor(0.5).withValues(alpha: 0.6),
        _elevationColor(1.0).withValues(alpha: 0.7),
      ],
      [0.0, 0.5, 1.0],
    );
    canvas.drawPath(path, Paint()..shader = gradient);

    // Stroke line
    final strokePath = ui.Path();
    strokePath.moveTo(first.dx, first.dy);
    for (int i = 1; i < alts.length; i++) {
      strokePath.lineTo(project(i).dx, project(i).dy);
    }
    canvas.drawPath(strokePath, Paint()
      ..color = const Color(0xFF1565C0)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round);

    // X-axis labels: start / mid / end distance
    _drawLabel(canvas, size, '0', hPad, size.height - 2, Alignment.bottomLeft);
    final midDist = totalDist / 2;
    final midLabel = midDist >= 1000
        ? '${(midDist / 1000).toStringAsFixed(1)} km'
        : '${midDist.toStringAsFixed(0)} m';
    _drawLabel(canvas, size, midLabel, size.width / 2, size.height - 2, Alignment.bottomCenter);
    final endLabel = totalDist >= 1000
        ? '${(totalDist / 1000).toStringAsFixed(1)} km'
        : '${totalDist.toStringAsFixed(0)} m';
    _drawLabel(canvas, size, endLabel, size.width - hPad, size.height - 2, Alignment.bottomRight);
  }

  void _drawLabel(Canvas canvas, Size size, String text, double x, double y, Alignment align) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: const TextStyle(color: Colors.black45, fontSize: 8.5,
              fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout();
    double dx = x;
    if (align == Alignment.bottomCenter) { dx -= tp.width / 2; }
    if (align == Alignment.bottomRight) { dx -= tp.width; }
    tp.paint(canvas, Offset(dx, y - tp.height));
  }

  @override
  bool shouldRepaint(_ElevationProfilePainter old) =>
      old.alts != alts || old.minAlt != minAlt || old.maxAlt != maxAlt;
}

// ── No-data placeholder ───────────────────────────────────────────────────────

class _NoTopoData extends StatelessWidget {
  final String farmName;
  const _NoTopoData({required this.farmName});

  @override
  Widget build(BuildContext context) => Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            const Icon(Icons.terrain_rounded, color: Colors.black26, size: 28),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'Terrain data not available.\n'
                'Map this farm on-site (GPS walk-around) to auto-capture elevation.',
                style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.5),
              ),
            ),
          ]),
        ),
      );
}
