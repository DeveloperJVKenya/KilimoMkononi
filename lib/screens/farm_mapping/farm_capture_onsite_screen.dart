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

enum _LocState { checking, ready, serviceOff, permDenied, permPermanent }

class FarmCaptureOnsiteScreen extends StatefulWidget {
  const FarmCaptureOnsiteScreen({super.key});

  @override
  State<FarmCaptureOnsiteScreen> createState() => _FarmCaptureOnsiteScreenState();
}

class _FarmCaptureOnsiteScreenState extends State<FarmCaptureOnsiteScreen>
    with WidgetsBindingObserver {
  final _mapCtrl = MapController();
  final _service = FarmPlotService();

  final List<LatLng> _points = [];
  final List<double> _altitudes = [];
  LatLng? _currentPos;
  double _currentAlt = 0.0;
  bool _tracking = false;
  bool _saving = false;
  _LocState _locState = _LocState.checking;
  bool _awaitingSettings = false;

  StreamSubscription<Position>? _posStream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _posStream?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check location when the user returns from device settings.
    if (state == AppLifecycleState.resumed && _awaitingSettings) {
      _awaitingSettings = false;
      _initLocation();
    }
  }

  Future<void> _initLocation() async {
    if (mounted) setState(() => _locState = _LocState.checking);

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _locState = _LocState.serviceOff);
      return;
    }

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      if (mounted) setState(() => _locState = _LocState.permPermanent);
      return;
    }
    if (perm == LocationPermission.denied) {
      if (mounted) setState(() => _locState = _LocState.permDenied);
      return;
    }

    if (mounted) setState(() => _locState = _LocState.ready);
    _startPositionStream();
  }

  Future<void> _openSettings() async {
    _awaitingSettings = true;
    if (_locState == _LocState.serviceOff) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }

  void _startPositionStream() {
    _posStream?.cancel();
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
    }, onError: (Object _) {
      if (mounted) setState(() => _locState = _LocState.serviceOff);
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

        // ── Location gate overlay ────────────────────────────────────────────
        if (_locState != _LocState.ready && _locState != _LocState.checking)
          _LocationGate(state: _locState, onAction: _openSettings, onRetry: _initLocation),
        if (_locState == _LocState.checking)
          const Positioned(
            bottom: 180,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
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

/// Full-screen overlay shown when GPS is unavailable — actionable, not passive.
class _LocationGate extends StatelessWidget {
  final _LocState state;
  final VoidCallback onAction;
  final VoidCallback onRetry;

  const _LocationGate({
    required this.state,
    required this.onAction,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isPermanent = state == _LocState.permPermanent;
    final isServiceOff = state == _LocState.serviceOff;

    final icon = isServiceOff ? Icons.location_off_rounded : Icons.lock_outlined;
    final title = isServiceOff
        ? 'Location services are off'
        : isPermanent
            ? 'Location access blocked'
            : 'Location permission needed';
    final body = isServiceOff
        ? 'Enable GPS on your device so the app can track your walk and record the farm boundary.'
        : isPermanent
            ? 'Location access was permanently denied. Open app settings and allow location access to use on-site mapping.'
            : 'This feature needs location access to record your position as you walk around the farm.';
    final btnLabel = isServiceOff ? 'Enable GPS' : 'Open app settings';

    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.15),
              Colors.black.withValues(alpha: 0.82),
            ],
          ),
        ),
        alignment: Alignment.bottomCenter,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1B2820),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.6)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: const Color(0xFF66BB6A), size: 26),
                  ),
                  const SizedBox(height: 14),
                  Text(title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(body,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 13,
                          height: 1.45)),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: onAction,
                      icon: Icon(
                        isServiceOff
                            ? Icons.settings_rounded
                            : Icons.app_settings_alt_rounded,
                        size: 18,
                      ),
                      label: Text(btnLabel,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: onRetry,
                    child: Text('Retry',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
