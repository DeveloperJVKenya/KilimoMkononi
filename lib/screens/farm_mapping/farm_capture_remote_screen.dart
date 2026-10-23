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

enum _InsertMode { trace, autoFit }

class FarmCaptureRemoteScreen extends StatefulWidget {
  const FarmCaptureRemoteScreen({super.key});

  @override
  State<FarmCaptureRemoteScreen> createState() => _FarmCaptureRemoteScreenState();
}

class _FarmCaptureRemoteScreenState extends State<FarmCaptureRemoteScreen> {
  final _mapCtrl = MapController();
  final _service = FarmPlotService();

  final List<LatLng> _points = [];
  _InsertMode _mode = _InsertMode.trace;
  int? _selectedIndex;
  bool _saving = false;
  bool _satelliteLayer = true;

  // ── Point management ──────────────────────────────────────────────────────

  void _onMapLongPress(TapPosition _, LatLng ll) {
    setState(() {
      _selectedIndex = null;
      if (_mode == _InsertMode.trace || _points.length < 3) {
        _points.add(ll);
      } else {
        final idx = GeoMath.bestInsertionIndex(_points, ll);
        _points.insert(idx, ll);
      }
    });
  }

  void _onMarkerTap(int i) {
    setState(() => _selectedIndex = _selectedIndex == i ? null : i);
  }

  void _deleteSelected() {
    if (_selectedIndex == null) return;
    setState(() {
      _points.removeAt(_selectedIndex!);
      _selectedIndex = null;
    });
  }

  void _undoPoint() {
    if (_points.isEmpty) return;
    setState(() {
      _selectedIndex = null;
      _points.removeLast();
    });
  }

  void _clearPoints() => setState(() {
        _points.clear();
        _selectedIndex = null;
      });

  double get _area => GeoMath.shoelaceAreaHectares(_points);
  double get _perimeter => GeoMath.haversinePerimeterMeters(_points);

  // ── Centre on device location ─────────────────────────────────────────────

  Future<void> _goToMyLocation() async {
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission not granted.')));
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      _mapCtrl.move(LatLng(pos.latitude, pos.longitude), 17);
    } catch (_) {}
  }

  // ── Save dialog ───────────────────────────────────────────────────────────

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
    final desc = descCtrl.text.trim();
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
        description: desc.isEmpty ? null : desc,
        coordinates: List.of(_points),
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hasPoints = _points.length >= 3;
    return Scaffold(
      body: Stack(children: [
        // ── Map ──────────────────────────────────────────────────────────────
        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(
            initialCenter: const LatLng(-1.2921, 36.8219),
            initialZoom: 14,
            onLongPress: _onMapLongPress,
          ),
          children: [
            TileLayer(
              urlTemplate: _satelliteLayer
                  ? 'https://server.arcgisonline.com/ArcGIS/rest/services/'
                      'World_Imagery/MapServer/tile/{z}/{y}/{x}'
                  : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.jva.kilimomkononi',
            ),
            // Filled polygon
            if (hasPoints)
              PolygonLayer(polygons: [
                Polygon(
                  points: _points,
                  color: _kGreenLight.withValues(alpha: 0.25),
                  borderColor: _kGreenLight,
                  borderStrokeWidth: 2.5,
                ),
              ]),
            // Open polyline before closure
            if (_points.length >= 2)
              PolylineLayer(polylines: [
                Polyline(
                  points: [..._points, _points.first],
                  color: _kGreenLight.withValues(alpha: 0.6),
                  strokeWidth: 1.5,
                ),
              ]),
            // Vertex markers
            MarkerLayer(
              markers: List.generate(_points.length, (i) {
                final selected = _selectedIndex == i;
                return Marker(
                  point: _points[i],
                  width: selected ? 20 : 14,
                  height: selected ? 20 : 14,
                  child: GestureDetector(
                    onTap: () => _onMarkerTap(i),
                    child: Container(
                      decoration: BoxDecoration(
                        color: selected ? Colors.orange : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: selected ? Colors.deepOrange : _kGreenLight,
                            width: selected ? 2.5 : 1.5),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
                      ),
                      child: selected
                          ? const Icon(Icons.close_rounded, size: 12, color: Colors.white)
                          : null,
                    ),
                  ),
                );
              }),
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
                  const Text('Remote satellite mapping',
                      style: TextStyle(
                          color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  // Satellite / street toggle
                  IconButton(
                    icon: Icon(
                        _satelliteLayer ? Icons.map_rounded : Icons.satellite_alt_rounded,
                        color: Colors.white),
                    tooltip: _satelliteLayer ? 'Switch to street map' : 'Switch to satellite',
                    onPressed: () => setState(() => _satelliteLayer = !_satelliteLayer),
                  ),
                  IconButton(
                    icon: const Icon(Icons.my_location_rounded, color: Colors.white),
                    tooltip: 'Go to my location',
                    onPressed: _goToMyLocation,
                  ),
                ]),
              ),
            ),
          ),
        ),

        // ── Mode selector ────────────────────────────────────────────────────
        Positioned(
          top: kToolbarHeight + MediaQuery.of(context).padding.top,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(24)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _ModeChip(
                    label: 'Trace',
                    icon: Icons.gesture_rounded,
                    active: _mode == _InsertMode.trace,
                    onTap: () => setState(() => _mode = _InsertMode.trace)),
                const SizedBox(width: 4),
                _ModeChip(
                    label: 'AutoFit',
                    icon: Icons.auto_awesome_rounded,
                    active: _mode == _InsertMode.autoFit,
                    onTap: () => setState(() => _mode = _InsertMode.autoFit)),
              ]),
            ),
          ),
        ),

        // ── Selected point action bar ────────────────────────────────────────
        if (_selectedIndex != null)
          Positioned(
            top: kToolbarHeight + MediaQuery.of(context).padding.top + 56,
            left: 16,
            right: 16,
            child: Material(
              borderRadius: BorderRadius.circular(10),
              color: Colors.orange.shade700,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                  const Icon(Icons.location_on_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text('Point ${(_selectedIndex! + 1)} selected',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _deleteSelected,
                    icon: const Icon(Icons.delete_rounded, color: Colors.white, size: 16),
                    label: const Text('Remove',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _selectedIndex = null),
                    child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                  ),
                ]),
              ),
            ),
          ),

        // ── Stats bar ────────────────────────────────────────────────────────
        if (_points.isNotEmpty)
          Positioned(
            bottom: 130,
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
                  _Stat('Perimeter', GeoMath.perimeterLabel(_perimeter)),
                ]),
              ),
            ),
          ),

        // ── Hint when empty ───────────────────────────────────────────────────
        if (_points.isEmpty)
          Positioned(
            bottom: 130,
            left: 24,
            right: 24,
            child: Material(
              borderRadius: BorderRadius.circular(12),
              color: Colors.black.withValues(alpha: 0.65),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Long-press on the map to place boundary points.\nTap a point to select and delete it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
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
                16, 8, 16, MediaQuery.of(context).padding.bottom + 12),
            child: Row(children: [
              Expanded(
                child: _CtrlBtn(
                  icon: Icons.undo_rounded,
                  label: 'Undo',
                  color: const Color(0xFF5D4037),
                  onTap: _points.isNotEmpty ? _undoPoint : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CtrlBtn(
                  icon: Icons.clear_all_rounded,
                  label: 'Clear',
                  color: Colors.red.shade700,
                  onTap: _points.isNotEmpty ? _clearPoints : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _CtrlBtn(
                  icon: Icons.save_rounded,
                  label: _saving ? 'Saving…' : 'Save farm',
                  color: hasPoints ? _kGreenLight : Colors.grey,
                  onTap: (!_saving && hasPoints) ? _saveDialog : null,
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _ModeChip({required this.label, required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
              color: active ? _kGreenLight : Colors.transparent,
              borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: active ? Colors.white : Colors.white60,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      );
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
