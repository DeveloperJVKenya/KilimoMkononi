import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kilimomkononi/screens/farm_mapping/models/farm_plot_model.dart';
import 'package:kilimomkononi/screens/farm_mapping/services/farm_plot_service.dart';
import 'package:kilimomkononi/screens/farm_mapping/utils/geo_math.dart';
import 'package:kilimomkononi/utils/friendly_error.dart';
import 'package:latlong2/latlong.dart';

const _kGreenLight = Color(0xFF2E7D32);
const _minSpacingMeters = 0.5;
const _maxJumpKm = 20.0;

class FarmCaptureOnsiteScreen extends StatefulWidget {
  const FarmCaptureOnsiteScreen({super.key});

  @override
  State<FarmCaptureOnsiteScreen> createState() => _FarmCaptureOnsiteScreenState();
}

class _FarmCaptureOnsiteScreenState extends State<FarmCaptureOnsiteScreen> {
  final _mapCtrl = MapController();
  final _service = FarmPlotService();

  final List<LatLng> _points = [];
  final List<double> _altitudes = [];
  LatLng? _currentPos;
  double _currentAlt = 0.0;
  bool _tracking = false;
  bool _saving = false;
  String? _locationError;

  StreamSubscription<Position>? _posStream;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _locationError = 'Location services are disabled.');
      return;
    }
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      setState(() => _locationError = 'Location permission denied.');
      return;
    }
    _startPositionStream();
  }

  void _startPositionStream() {
    _posStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
      ),
    ).listen((pos) {
      final ll = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _currentPos = ll;
        _currentAlt = pos.altitude;
      });
      if (_currentPos != null && _points.isEmpty) {
        _mapCtrl.move(ll, 18);
      }
      if (_tracking) _maybeAddPoint(ll, pos.altitude);
    }, onError: (Object e) {
      setState(() => _locationError = 'GPS error: ${e.toString()}');
    });
  }

  void _maybeAddPoint(LatLng ll, [double alt = 0.0]) {
    if (_points.isNotEmpty) {
      final d = GeoMath.haversineDistanceMeters(_points.last, ll);
      if (d < _minSpacingMeters) return;
      if (d > _maxJumpKm * 1000) return;
    }
    setState(() {
      _points.add(ll);
      _altitudes.add(alt);
    });
  }

  void _addCurrentPoint() {
    if (_currentPos == null) return;
    _maybeAddPoint(_currentPos!, _currentAlt);
  }

  void _undoPoint() => setState(() {
        if (_points.isNotEmpty) {
          _points.removeLast();
          if (_altitudes.isNotEmpty) _altitudes.removeLast();
        }
      });

  void _clearPoints() => setState(() {
        _points.clear();
        _altitudes.clear();
      });

  double get _area => GeoMath.shoelaceAreaHectares(_points);
  double get _perimeter => GeoMath.haversinePerimeterMeters(_points);

  Future<void> _saveDialog() async {
    if (_points.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Need at least 3 points to map a farm.')));
      return;
    }
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save this farm'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: nameCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Farm name *', hintText: 'e.g. Home Farm'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: descCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'e.g. Main maize plot near the river'),
          ),
          const SizedBox(height: 12),
          Text('Area: ${GeoMath.areaLabel(_area)}  ·  '
              'Perimeter: ${GeoMath.perimeterLabel(_perimeter)}\n'
              '${_points.length} boundary points',
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ]),
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
    nameCtrl.dispose();
    descCtrl.dispose();
    if (name.isEmpty) return;

    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final now = DateTime.now();
      final farm = FarmPlot(
        userId: uid,
        farmName: name,
        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
        coordinates: List.of(_points),
        altitudes: List.of(_altitudes),
        areaHectares: _area,
        perimeterMeters: _perimeter,
        createdAt: now,
        updatedAt: now,
      );
      await _service.saveFarm(farm);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('"$name" saved successfully!')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e, "Couldn't save farm"))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _posStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasPoints = _points.length >= 3;
    return Scaffold(
      body: Stack(children: [
        // ── Map ──────────────────────────────────────────────────────────────
        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(
            initialCenter: _currentPos ?? const LatLng(-1.2921, 36.8219),
            initialZoom: 15,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/'
                  'World_Imagery/MapServer/tile/{z}/{y}/{x}',
              userAgentPackageName: 'com.jva.kilimomkononi',
            ),
            // Boundary polygon (filled)
            if (hasPoints)
              PolygonLayer(polygons: [
                Polygon(
                  points: _points,
                  color: _kGreenLight.withValues(alpha: 0.3),
                  borderColor: _kGreenLight,
                  borderStrokeWidth: 2.5,
                ),
              ]),
            // Boundary line before closure
            if (_points.length >= 2)
              PolylineLayer(polylines: [
                Polyline(
                  points: _points,
                  color: _kGreenLight,
                  strokeWidth: 2.5,
                ),
              ]),
            // Recorded waypoints
            MarkerLayer(
              markers: _points
                  .map((p) => Marker(
                        point: p,
                        width: 10,
                        height: 10,
                        child: Container(
                          decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2)]),
                        ),
                      ))
                  .toList(),
            ),
            // Current GPS position
            if (_currentPos != null)
              MarkerLayer(markers: [
                Marker(
                  point: _currentPos!,
                  width: 20,
                  height: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                  ),
                ),
              ]),
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
                  const Text('On-site GPS mapping',
                      style: TextStyle(
                          color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (_currentPos != null)
                    IconButton(
                      icon: const Icon(Icons.my_location_rounded, color: Colors.white),
                      tooltip: 'Centre on my location',
                      onPressed: () => _mapCtrl.move(_currentPos!, 18),
                    ),
                ]),
              ),
            ),
          ),
        ),

        // ── Location error banner ────────────────────────────────────────────
        if (_locationError != null)
          Positioned(
            top: kToolbarHeight + MediaQuery.of(context).padding.top,
            left: 16,
            right: 16,
            child: Material(
              borderRadius: BorderRadius.circular(10),
              color: Colors.red.shade700,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_locationError!,
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ),
          ),

        // ── Stats bar ────────────────────────────────────────────────────────
        if (_points.isNotEmpty)
          Positioned(
            bottom: 150,
            left: 16,
            right: 16,
            child: Material(
              borderRadius: BorderRadius.circular(12),
              color: Colors.black.withValues(alpha: 0.75),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _Stat('Points', '${_points.length}'),
                    _Stat('Area', GeoMath.areaLabel(_area)),
                    _Stat('Perimeter', GeoMath.perimeterLabel(_perimeter)),
                  ],
                ),
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
                16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Tracking toggle
              GestureDetector(
                onTap: () => setState(() => _tracking = !_tracking),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: _tracking ? Colors.orange : _kGreenLight,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_tracking ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(_tracking ? 'Pause tracking' : 'Start walking',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                  ]),
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                // Manual add point
                Expanded(
                  child: _CtrlBtn(
                    icon: Icons.add_location_rounded,
                    label: 'Add point',
                    color: _kGreenLight,
                    onTap: _currentPos != null ? _addCurrentPoint : null,
                  ),
                ),
                const SizedBox(width: 8),
                // Undo
                Expanded(
                  child: _CtrlBtn(
                    icon: Icons.undo_rounded,
                    label: 'Undo',
                    color: const Color(0xFF5D4037),
                    onTap: _points.isNotEmpty ? _undoPoint : null,
                  ),
                ),
                const SizedBox(width: 8),
                // Clear
                Expanded(
                  child: _CtrlBtn(
                    icon: Icons.clear_all_rounded,
                    label: 'Clear',
                    color: Colors.red.shade700,
                    onTap: _points.isNotEmpty ? _clearPoints : null,
                  ),
                ),
                const SizedBox(width: 8),
                // Save
                Expanded(
                  child: _CtrlBtn(
                    icon: Icons.save_rounded,
                    label: _saving ? 'Saving…' : 'Save',
                    color: hasPoints ? const Color(0xFF1565C0) : Colors.grey,
                    onTap: (!_saving && hasPoints) ? _saveDialog : null,
                  ),
                ),
              ]),
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
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(height: 2),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}
