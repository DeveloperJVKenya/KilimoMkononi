import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:kilimomkononi/screens/farm_mapping/models/farm_plot_model.dart';
import 'package:kilimomkononi/screens/farm_mapping/services/farm_plot_service.dart';
import 'package:kilimomkononi/screens/farm_mapping/utils/geo_math.dart';
import 'package:kilimomkononi/utils/friendly_error.dart';
import 'package:latlong2/latlong.dart';

class FarmSectionCaptureScreen extends StatefulWidget {
  final String farmId;
  final FarmPlot farm;

  const FarmSectionCaptureScreen({
    super.key,
    required this.farmId,
    required this.farm,
  });

  @override
  State<FarmSectionCaptureScreen> createState() => _FarmSectionCaptureScreenState();
}

class _FarmSectionCaptureScreenState extends State<FarmSectionCaptureScreen> {
  final _mapCtrl = MapController();
  final _service = FarmPlotService();

  final List<LatLng> _points = [];
  bool _saving = false;

  // Auto-pick next section colour not yet used
  int get _nextColorIndex {
    final used = widget.farm.sections.map((s) => s.colorIndex).toSet();
    for (int i = 0; i < kSectionColors.length; i++) {
      if (!used.contains(i)) return i;
    }
    return widget.farm.sections.length % kSectionColors.length;
  }

  void _onMapLongPress(TapPosition _, LatLng ll) {
    setState(() {
      if (_points.length < 3) {
        _points.add(ll);
      } else {
        final idx = GeoMath.bestInsertionIndex(_points, ll);
        _points.insert(idx, ll);
      }
    });
  }

  void _undoPoint() => setState(() { if (_points.isNotEmpty) _points.removeLast(); });
  void _clearPoints() => setState(() => _points.clear());

  double get _area => GeoMath.shoelaceAreaHectares(_points);

  Future<void> _saveDialog() async {
    if (_points.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Need at least 3 points to define a section.')));
      return;
    }
    final nameCtrl = TextEditingController();
    final cropCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save section'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  labelText: 'Section name *', hintText: 'e.g. North Maize Plot'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: cropCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  labelText: 'Crop (optional)', hintText: 'e.g. Maize, Tomatoes'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: notesCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Notes (optional)', hintText: 'e.g. Near the borehole'),
            ),
            const SizedBox(height: 12),
            Text('Area: ${GeoMath.areaLabel(_area)}  ·  ${_points.length} points',
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != true || !mounted) return;
    final name = nameCtrl.text.trim();
    final crop = cropCtrl.text.trim();
    final notes = notesCtrl.text.trim();
    nameCtrl.dispose();
    cropCtrl.dispose();
    notesCtrl.dispose();
    if (name.isEmpty) return;

    setState(() => _saving = true);
    try {
      final section = FarmSection(
        sectionName: name,
        cropType: crop.isEmpty ? null : crop,
        notes: notes.isEmpty ? null : notes,
        coordinates: List.of(_points),
        areaHectares: _area,
        colorIndex: _nextColorIndex,
      );
      final updatedSections = [...widget.farm.sections, section];
      await _service.saveSections(widget.farmId, updatedSections);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('"$name" saved!')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e, "Couldn't save section"))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPoints = _points.length >= 3;
    final sectionColor = kSectionColors[_nextColorIndex];

    return Scaffold(
      body: Stack(children: [
        // ── Map ──────────────────────────────────────────────────────────────
        FlutterMap(
          mapController: _mapCtrl,
          options: widget.farm.coordinates.isNotEmpty
              ? MapOptions(
                  initialCameraFit: CameraFit.coordinates(
                      coordinates: widget.farm.coordinates,
                      padding: const EdgeInsets.all(32)),
                  onLongPress: _onMapLongPress,
                )
              : MapOptions(
                  initialCenter: const LatLng(-1.2921, 36.8219),
                  initialZoom: 15.0,
                  onLongPress: _onMapLongPress,
                ),
          children: [
            TileLayer(
              urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/'
                  'World_Imagery/MapServer/tile/{z}/{y}/{x}',
              userAgentPackageName: 'com.jva.kilimomkononi',
            ),
            // Parent farm boundary (context, non-interactive visual)
            if (widget.farm.coordinates.length >= 3)
              PolygonLayer(polygons: [
                Polygon(
                  points: widget.farm.coordinates,
                  color: Colors.transparent,
                  borderColor: Colors.white.withValues(alpha: 0.5),
                  borderStrokeWidth: 1.5,
                ),
              ]),
            // Existing sections
            PolygonLayer(
              polygons: widget.farm.sections.map((s) => Polygon(
                    points: s.coordinates,
                    color: s.color.withValues(alpha: 0.3),
                    borderColor: s.color,
                    borderStrokeWidth: 1.5,
                  )).toList(),
            ),
            // New section being drawn
            if (hasPoints)
              PolygonLayer(polygons: [
                Polygon(
                  points: _points,
                  color: sectionColor.withValues(alpha: 0.35),
                  borderColor: sectionColor,
                  borderStrokeWidth: 2.5,
                ),
              ]),
            if (_points.length >= 2)
              PolylineLayer(polylines: [
                Polyline(points: _points, color: sectionColor, strokeWidth: 2.5),
              ]),
            // New section vertex markers
            MarkerLayer(
              markers: _points
                  .map((p) => Marker(
                        point: p,
                        width: 12,
                        height: 12,
                        child: Container(
                          decoration: BoxDecoration(
                            color: sectionColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),

        // ── App bar overlay ──────────────────────────────────────────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent]),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text('Add section · ${widget.farm.farmName}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
            ),
          ),
        ),

        // ── Hint ─────────────────────────────────────────────────────────────
        if (_points.isEmpty)
          Positioned(
            bottom: 120,
            left: 24,
            right: 24,
            child: Material(
              borderRadius: BorderRadius.circular(12),
              color: Colors.black.withValues(alpha: 0.65),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Long-press inside the farm to place section boundary points.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                ),
              ),
            ),
          ),

        // ── Stats bar ────────────────────────────────────────────────────────
        if (_points.isNotEmpty)
          Positioned(
            bottom: 120,
            left: 16,
            right: 16,
            child: Material(
              borderRadius: BorderRadius.circular(12),
              color: Colors.black.withValues(alpha: 0.75),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _Stat('Points', '${_points.length}'),
                  _Stat('Area', GeoMath.areaLabel(_area)),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 10, height: 10,
                        decoration: BoxDecoration(color: sectionColor, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text('Section color', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ]),
                ]),
              ),
            ),
          ),

        // ── Bottom controls ───────────────────────────────────────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent]),
            ),
            padding: EdgeInsets.fromLTRB(
                16, 8, 16, MediaQuery.of(context).padding.bottom + 12),
            child: Row(children: [
              Expanded(
                child: _CtrlBtn(
                    icon: Icons.undo_rounded,
                    label: 'Undo',
                    color: const Color(0xFF5D4037),
                    onTap: _points.isNotEmpty ? _undoPoint : null),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CtrlBtn(
                    icon: Icons.clear_all_rounded,
                    label: 'Clear',
                    color: Colors.red.shade700,
                    onTap: _points.isNotEmpty ? _clearPoints : null),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _CtrlBtn(
                    icon: Icons.save_rounded,
                    label: _saving ? 'Saving…' : 'Save section',
                    color: hasPoints ? sectionColor : Colors.grey,
                    onTap: (!_saving && hasPoints) ? _saveDialog : null),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ]);
}

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _CtrlBtn({required this.icon, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: onTap != null ? 1.0 : 0.45,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 5),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}
