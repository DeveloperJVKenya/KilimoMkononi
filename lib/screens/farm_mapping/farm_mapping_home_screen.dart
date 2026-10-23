import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kilimomkononi/screens/farm_mapping/farm_capture_onsite_screen.dart';
import 'package:kilimomkononi/screens/farm_mapping/farm_capture_remote_screen.dart';
import 'package:kilimomkononi/screens/farm_mapping/farm_detail_screen.dart';
import 'package:kilimomkononi/screens/farm_mapping/models/farm_plot_model.dart';
import 'package:kilimomkononi/screens/farm_mapping/services/farm_plot_service.dart';
import 'package:kilimomkononi/utils/friendly_error.dart';

const _kGreen = Color(0xFF1B5E20);
const _kGreenLight = Color(0xFF2E7D32);

class FarmMappingHomeScreen extends StatefulWidget {
  const FarmMappingHomeScreen({super.key});

  @override
  State<FarmMappingHomeScreen> createState() => _FarmMappingHomeScreenState();
}

class _FarmMappingHomeScreenState extends State<FarmMappingHomeScreen> {
  final _service = FarmPlotService();

  void _openAddSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddFarmSheet(
        onOnsite: () {
          Navigator.pop(context);
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const FarmCaptureOnsiteScreen()));
        },
        onRemote: () {
          Navigator.pop(context);
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const FarmCaptureRemoteScreen()));
        },
      ),
    );
  }

  Future<void> _confirmDelete(FarmPlot farm) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete farm?'),
        content: Text('Remove "${farm.farmName}" and all its sections? This cannot be undone.'),
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
      await _service.deleteFarm(farm.farmId!);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e, "Couldn't delete farm"))));
    }
  }

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
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (ok != true || !mounted) return;
    final name = ctrl.text.trim();
    if (name.isEmpty || name == farm.farmName) return;
    try {
      await _service.renameFarm(farm.farmId!, name);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e, "Couldn't rename farm"))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F3),
      appBar: AppBar(
        title: const Text('Farm Mapping',
            style: TextStyle(fontWeight: FontWeight.w800)),
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF0B3D1E), _kGreen]),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddSheet,
        backgroundColor: _kGreenLight,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Map new farm', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: StreamBuilder<List<FarmPlot>>(
        stream: _service.userFarmsStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final farms = snap.data ?? [];
          if (farms.isEmpty) return _EmptyState(onAdd: _openAddSheet);
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: farms.length,
            itemBuilder: (_, i) => _FarmCard(
              farm: farms[i],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => FarmDetailScreen(farmId: farms[i].farmId!)),
              ),
              onRename: () => _renameDialog(farms[i]),
              onDelete: () => _confirmDelete(farms[i]),
            ),
          );
        },
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.map_outlined, size: 56, color: _kGreenLight),
          ),
          const SizedBox(height: 20),
          const Text('No farms mapped yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                  color: Color(0xFF1B2A1B))),
          const SizedBox(height: 8),
          const Text(
            'Map your farm boundary on-site using GPS, or remotely\n'
            'by drawing on a satellite map.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            style: FilledButton.styleFrom(backgroundColor: _kGreenLight),
            icon: const Icon(Icons.add_location_alt_rounded),
            label: const Text('Map my first farm',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}

// ── Farm card ─────────────────────────────────────────────────────────────────

class _FarmCard extends StatelessWidget {
  final FarmPlot farm;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  const _FarmCard({
    required this.farm,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final sectionCount = farm.sections.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        shadowColor: Colors.black12,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0B3D1E), _kGreen, Color(0xFF388E3C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.map_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(farm.farmName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Wrap(spacing: 10, children: [
                    _InfoChip(Icons.straighten_rounded, farm.areaLabel),
                    _InfoChip(Icons.timeline_rounded, farm.perimeterLabel),
                    if (sectionCount > 0)
                      _InfoChip(
                          Icons.grid_view_rounded,
                          '$sectionCount section${sectionCount == 1 ? '' : 's'}'),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    '${farm.coordinates.length} boundary points  ·  '
                    'Mapped ${DateFormat('d MMM yyyy').format(farm.createdAt)}',
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 11.5),
                  ),
                ]),
              ),
              PopupMenuButton<String>(
                color: Colors.white,
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
                onSelected: (v) {
                  if (v == 'rename') onRename();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete', style: TextStyle(color: Colors.red))),
                ],
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: Colors.white70),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ]);
}

// ── Add farm method sheet ─────────────────────────────────────────────────────

class _AddFarmSheet extends StatelessWidget {
  final VoidCallback onOnsite;
  final VoidCallback onRemote;
  const _AddFarmSheet({required this.onOnsite, required this.onRemote});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('How would you like to map?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text(
            'On-site uses your GPS as you walk the boundary.\n'
            'Remote lets you draw on a satellite image from anywhere.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.5),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: _MethodCard(
                icon: Icons.my_location_rounded,
                title: 'Map on site',
                subtitle: 'Walk the boundary with GPS',
                color: _kGreenLight,
                onTap: onOnsite,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MethodCard(
                icon: Icons.satellite_alt_rounded,
                title: 'Map remotely',
                subtitle: 'Draw on satellite imagery',
                color: const Color(0xFF1565C0),
                onTap: onRemote,
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _MethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.85), color],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight)),
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 12),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.3)),
            ]),
          ),
        ),
      );
}
