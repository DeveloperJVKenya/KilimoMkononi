import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:kilimomkononi/screens/farm_mapping/farm_topo_widget.dart';
import 'package:kilimomkononi/screens/farm_mapping/farm_section_capture_screen.dart';
import 'package:kilimomkononi/screens/farm_mapping/models/farm_plot_model.dart';
import 'package:kilimomkononi/screens/farm_mapping/services/farm_plot_service.dart';
import 'package:kilimomkononi/utils/friendly_error.dart';
import 'package:latlong2/latlong.dart';

const _kGreen = Color(0xFF1B5E20);
const _kGreenLight = Color(0xFF2E7D32);

class FarmDetailScreen extends StatefulWidget {
  final String farmId;
  const FarmDetailScreen({super.key, required this.farmId});

  @override
  State<FarmDetailScreen> createState() => _FarmDetailScreenState();
}

class _FarmDetailScreenState extends State<FarmDetailScreen> {
  final _service = FarmPlotService();

  Stream<FarmPlot?> get _farmStream => FirebaseFirestore.instance
      .collection('farmPlots')
      .doc(widget.farmId)
      .snapshots()
      .map((s) => s.exists ? FarmPlot.fromFirestore(s) : null);

  Future<void> _renameDialog(FarmPlot farm) async {
    final ctrl = TextEditingController(text: farm.farmName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename farm'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Farm name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    ctrl.dispose();
    if (ok != true || !mounted) return;
    final name = ctrl.text.trim();
    if (name.isEmpty || name == farm.farmName) return;
    try {
      await _service.renameFarm(widget.farmId, name);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e, "Couldn't rename farm"))));
    }
  }

  Future<void> _confirmDeleteFarm(FarmPlot farm) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete farm?'),
        content: Text('Remove "${farm.farmName}" and all its sections permanently?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _service.deleteFarm(widget.farmId);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e, "Couldn't delete farm"))));
    }
  }

  Future<void> _confirmDeleteSection(FarmPlot farm, FarmSection section) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete section?'),
        content: Text('Remove "${section.sectionName}" from "${farm.farmName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final updated =
          farm.sections.where((s) => s.sectionId != section.sectionId).toList();
      await _service.saveSections(widget.farmId, updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e, "Couldn't delete section"))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<FarmPlot?>(
      stream: _farmStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final farm = snap.data;
        if (farm == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Farm')),
            body: const Center(child: Text('Farm not found.')),
          );
        }
        return _FarmDetailView(
          farm: farm,
          onRename: () => _renameDialog(farm),
          onDelete: () => _confirmDeleteFarm(farm),
          onDeleteSection: (s) => _confirmDeleteSection(farm, s),
          onAddSection: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    FarmSectionCaptureScreen(farmId: widget.farmId, farm: farm)),
          ),
        );
      },
    );
  }
}

// ── Detail view ───────────────────────────────────────────────────────────────

class _FarmDetailView extends StatefulWidget {
  final FarmPlot farm;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final ValueChanged<FarmSection> onDeleteSection;
  final VoidCallback onAddSection;

  const _FarmDetailView({
    required this.farm,
    required this.onRename,
    required this.onDelete,
    required this.onDeleteSection,
    required this.onAddSection,
  });

  @override
  State<_FarmDetailView> createState() => _FarmDetailViewState();
}

class _FarmDetailViewState extends State<_FarmDetailView> {
  final _mapCtrl = MapController();

  @override
  Widget build(BuildContext context) {
    final farm = widget.farm;
    final hasCoords = farm.coordinates.length >= 3;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F3),
      appBar: AppBar(
        title: Text(farm.farmName,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF0B3D1E), _kGreen]),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Rename farm',
            onPressed: widget.onRename,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'delete') widget.onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete farm', style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.onAddSection,
        backgroundColor: _kGreenLight,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add section', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // ── Map preview ───────────────────────────────────────────────────
          if (hasCoords)
            Container(
              height: 260,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)]),
              clipBehavior: Clip.antiAlias,
              child: FlutterMap(
                mapController: _mapCtrl,
                options: MapOptions(
                  initialCameraFit: CameraFit.coordinates(
                      coordinates: farm.coordinates, padding: const EdgeInsets.all(28)),
                  interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://server.arcgisonline.com/ArcGIS/rest/services/'
                        'World_Imagery/MapServer/tile/{z}/{y}/{x}',
                    userAgentPackageName: 'com.jva.kilimomkononi',
                  ),
                  // Main farm polygon
                  PolygonLayer(polygons: [
                    Polygon(
                      points: farm.coordinates,
                      color: _kGreenLight.withValues(alpha: 0.25),
                      borderColor: _kGreenLight,
                      borderStrokeWidth: 2.5,
                    ),
                    // Section polygons
                    ...farm.sections.map((s) => Polygon(
                          points: s.coordinates,
                          color: s.color.withValues(alpha: 0.35),
                          borderColor: s.color,
                          borderStrokeWidth: 2,
                        )),
                  ]),
                  // Section labels
                  MarkerLayer(
                    markers: farm.sections.map((s) {
                      final c = s.coordinates;
                      if (c.isEmpty) return null;
                      final lat = c.map((p) => p.latitude).reduce((a, b) => a + b) / c.length;
                      final lng = c.map((p) => p.longitude).reduce((a, b) => a + b) / c.length;
                      return Marker(
                        point: LatLng(lat, lng),
                        width: 80,
                        height: 24,
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: s.color.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(6)),
                          child: Text(s.sectionName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                        ),
                      );
                    }).whereType<Marker>().toList(),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // ── Stats ─────────────────────────────────────────────────────────
          _StatsRow(farm: farm),

          const SizedBox(height: 20),

          // ── Description ───────────────────────────────────────────────────
          if (farm.description != null && farm.description!.isNotEmpty) ...[
            _SectionHeader('About this farm'),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(farm.description!,
                    style: const TextStyle(fontSize: 14, height: 1.5)),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Sections list ─────────────────────────────────────────────────
          _SectionHeader('Farm sections (${farm.sections.length})'),
          if (farm.sections.isEmpty)
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No sections yet. Add a section to divide your farm by crop or area.',
                  style: TextStyle(color: Colors.black54, fontSize: 13, height: 1.5),
                ),
              ),
            )
          else
            ...farm.sections.map((s) => _SectionCard(
                  section: s,
                  onDelete: () => widget.onDeleteSection(s),
                )),

          const SizedBox(height: 20),

          // ── Terrain / topography ──────────────────────────────────────────
          _SectionHeader('Terrain'),
          FarmTopoWidget(farm: farm),
        ],
      ),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final FarmPlot farm;
  const _StatsRow({required this.farm});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: _StatCard(Icons.straighten_rounded, 'Area', farm.areaLabel, _kGreenLight)),
      const SizedBox(width: 10),
      Expanded(
          child: _StatCard(
              Icons.timeline_rounded, 'Perimeter', farm.perimeterLabel, const Color(0xFF1565C0))),
      const SizedBox(width: 10),
      Expanded(
          child: _StatCard(Icons.place_rounded, 'Points',
              '${farm.coordinates.length}', const Color(0xFF5D4037))),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard(this.icon, this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.25))),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 14, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 10)),
        ]),
      );
}

// ── Section card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final FarmSection section;
  final VoidCallback onDelete;
  const _SectionCard({required this.section, required this.onDelete});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(
                width: 14,
                height: 40,
                decoration: BoxDecoration(
                    color: section.color, borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(section.sectionName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  if (section.cropType != null && section.cropType!.isNotEmpty)
                    Text('Crop: ${section.cropType}',
                        style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  Text(section.areaLabel,
                      style: const TextStyle(fontSize: 12, color: Colors.black45)),
                ]),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                onPressed: onDelete,
              ),
            ]),
          ),
        ),
      );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1B2A1B))),
      );
}
