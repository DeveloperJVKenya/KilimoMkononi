// lib/screens/Field Data Input/field_data_input_home_page.dart
//
// Field Data Input hub. Tabs at the top (under the app bar) switch between:
//   Record           — start a record, then your plots this season
//   Weather station  — the station's live conditions and last 24 h
//   Plot history     — every saved record
//   Season analysis  — AI season insights
// The other screens run embedded (no app bar of their own). Tabs are built
// the first time they're opened (Weather / Analysis call paid APIs) and then
// kept, so switching back and forth doesn't reload them. The app-wide
// bottom navigation stays on Home; back leaves the hub.
//
// Farm alerts and advice are on Home and in Notifications; each plot form
// shows its own soil / pest / disease alerts (SectionAlertsStrip).

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kilimomkononi/models/field_data_model.dart';
import 'package:kilimomkononi/screens/Field Data Input/field_data_input_page.dart';
import 'package:kilimomkononi/screens/Field Data Input/plot_summary_tab.dart';
import 'package:kilimomkononi/screens/analysis/farmer_plot_analysis_screen.dart';
import 'package:kilimomkononi/screens/Field Data Input/weather_station_screen.dart';
import 'package:kilimomkononi/services/offline_queue_service.dart';
import 'package:kilimomkononi/widgets/offline_sync_banner.dart';

class FieldDataInputHomePage extends StatefulWidget {
  /// Tab to open on: 0 Record, 1 Weather station, 2 Plot history, 3 Season analysis.
  final int initialTab;
  const FieldDataInputHomePage({super.key, this.initialTab = 0});

  @override
  State<FieldDataInputHomePage> createState() => _FieldDataInputHomePageState();
}

class _FieldDataInputHomePageState extends State<FieldDataInputHomePage>
    with SingleTickerProviderStateMixin {
  static const _darkGreen = Color.fromARGB(255, 3, 39, 4);
  static const _accentGreen = Color(0xFF2A6B2A);

  late final String _userId;
  List<FieldData> _recentPlots = [];
  bool _isLoading = true;

  late final TabController _tabs = TabController(
    length: 4,
    vsync: this,
    initialIndex: widget.initialTab.clamp(0, 3),
  )..addListener(() => _selectTab(_tabs.index));
  late int _tab = _tabs.index;
  // Tabs opened so far — only these are built.
  late final Set<int> _opened = {_tab};

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser!.uid;
    _loadRecentPlots();
    OfflineQueueService.init(); // start connectivity listener + attempt sync
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadRecentPlots() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('fielddata')
          .where('userId', isEqualTo: _userId)
          .orderBy('timestamp', descending: true)
          .limit(3)
          .get();
      if (mounted) {
        setState(() {
          _recentPlots = snap.docs
              .map((d) => FieldData.fromMap(d.data()))
              .toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _plotStatus(FieldData d) {
    final n = d.npk['N'];
    final p = d.npk['P'];
    final k = d.npk['K'];
    if (n == null && p == null && k == null) return 'Incomplete';
    // Simple heuristic: if all values are present and non-zero, flag as OK
    if ((n ?? 0) > 0 && (p ?? 0) > 0 && (k ?? 0) > 0) return 'Good';
    return 'Needs attention';
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'Good':
        return const Color(0xFF1B5E20);
      case 'Needs attention':
        return const Color(0xFFE65100);
      default:
        return Colors.black54;
    }
  }

  Color _statusBg(String s) {
    switch (s) {
      case 'Good':
        return const Color(0xFFE8F5E9);
      case 'Needs attention':
        return const Color(0xFFFFF8E1);
      default:
        return Colors.grey[200]!;
    }
  }

  double _plotProgress(FieldData d) {
    int filled = 0;
    if (d.crops.isNotEmpty && (d.crops.first['type'] ?? '').isNotEmpty) {
      filled++;
    }
    if (d.area != null && d.area! > 0) filled++;
    if ((d.npk['N'] ?? 0) > 0) filled++;
    if (d.interventions.isNotEmpty) filled++;
    return filled / 4;
  }

  void _selectTab(int i) {
    if (i == _tab && _opened.contains(i)) return;
    setState(() {
      _tab = i;
      _opened.add(i);
    });
  }

  Widget _tabPage(int i) {
    if (!_opened.contains(i)) return const SizedBox.shrink();
    switch (i) {
      case 1:
        return const WeatherStationScreen(embedded: true);
      case 2:
        return PlotSummaryTab(userId: _userId, embedded: true);
      case 3:
        return FarmerPlotAnalysisScreen(
          plotId: 'SingleCrop',
          cycleName: 'Season ${DateTime.now().year}',
          embedded: true,
        );
      default:
        return _buildRecordTab();
    }
  }

  static const _tabLabels = [
    (Icons.edit_note_rounded, 'Record'),
    (Icons.sensors_rounded, 'Weather station'),
    (Icons.history_rounded, 'Plot history'),
    (Icons.bar_chart_rounded, 'Season analysis'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F3),
      appBar: AppBar(
        backgroundColor: _darkGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Field Data Input',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Season ${DateTime.now().year}  ·  ${_recentPlots.length} recent plot${_recentPlots.length == 1 ? '' : 's'}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: const Color(0xFF8BC34A),
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
          tabs: [
            for (final (icon, label) in _tabLabels)
              Tab(
                height: 44,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18),
                    const SizedBox(width: 6),
                    Text(label),
                  ],
                ),
              ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _tab,
        children: [for (var i = 0; i < 4; i++) _tabPage(i)],
      ),
    );
  }

  Widget _buildRecordTab() {
    return RefreshIndicator(
      onRefresh: _loadRecentPlots,
      color: _accentGreen,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // ── Offline sync banner (hidden when queue is empty) ──────────
          const OfflineSyncBanner(),
          const SizedBox(height: 4),
          // ── Start recording ──────────────────────────────
          _sectionLabel('Start recording'),
          _structureCard(
            icon: Icons.grass,
            iconBg: const Color(0xFFE8F5E9),
            iconColor: _accentGreen,
            title: 'Single crop',
            description:
                'One crop, one plot — full nutrient & intervention tracking',
            badge: 'Most common',
            badgeColor: const Color(0xFF1B5E20),
            badgeBg: const Color(0xFFE8F5E9),
            onTap: () => _openEntry('single'),
          ),
          _structureCard(
            icon: Icons.device_hub,
            iconBg: const Color(0xFFFFF8E1),
            iconColor: const Color(0xFFF57C00),
            title: 'Intercropping',
            description: 'Multiple crops in one plot',
            onTap: () => _openEntry('intercrop'),
          ),
          _structureCard(
            icon: Icons.grid_view_rounded,
            iconBg: const Color(0xFFE3F2FD),
            iconColor: const Color(0xFF1565C0),
            title: 'Multiple plots',
            description: 'Separate plots with individual tab tracking',
            onTap: () => _openEntry('multiple'),
          ),

          // ── Your plots this season (right under the start cards) ──────
          if (!_isLoading && _recentPlots.isNotEmpty) ...[
            _sectionLabel('Your plots this season'),
            ..._recentPlots.map((plot) => _recentPlotCard(plot)),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _openEntry(String structureType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FieldDataInputPage(structureType: structureType),
      ),
    ).then((_) => _loadRecentPlots());
  }

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        color: Colors.black45,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
      ),
    ),
  );

  Widget _structureCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String description,
    String? badge,
    Color? badgeColor,
    Color? badgeBg,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                fontSize: 10,
                                color: badgeColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black26, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recentPlotCard(FieldData plot) {
    final status = _plotStatus(plot);
    final progress = _plotProgress(plot);
    final cropLabel =
        plot.crops.isNotEmpty && (plot.crops.first['type'] ?? '').isNotEmpty
        ? '${plot.crops.first['type']} · ${plot.crops.first['stage'] ?? ''}'
        : 'No crop set';
    final areaLabel = plot.area != null
        ? '${plot.area?.toStringAsFixed(1)} ac'
        : '';
    final dateLabel = _timeAgo(plot.timestamp.toDate());

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plot.plotId,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _statusBg(status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 10,
                      color: _statusColor(status),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [
                cropLabel,
                if (areaLabel.isNotEmpty) areaLabel,
                dateLabel,
              ].join(' · '),
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF2A6B2A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Updated today';
    if (diff.inDays == 1) return 'Updated yesterday';
    return 'Updated ${diff.inDays}d ago';
  }
}
