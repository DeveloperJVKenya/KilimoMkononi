// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kilimomkononi/models/field_data_model.dart';
import 'package:kilimomkononi/screens/analysis/farmer_plot_analysis_screen.dart';

class PlotSummaryTab extends StatefulWidget {
  final String userId;
  const PlotSummaryTab({required this.userId, super.key});

  @override
  State<PlotSummaryTab> createState() => _PlotSummaryTabState();
}

class _PlotSummaryTabState extends State<PlotSummaryTab>
    with SingleTickerProviderStateMixin {
  static const _darkGreen = Color.fromARGB(255, 3, 39, 4);
  static const _accentGreen = Color(0xFF2A6B2A);

  late TabController _tabController;
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Single', 'Intercrop', 'Multiple'];

  // Track which card is expanded
  String? _expandedDocId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  String _plotStatus(FieldData d) {
    final n = d.npk['N'];
    final p = d.npk['P'];
    final k = d.npk['K'];
    if (n == null && p == null && k == null) return 'Incomplete';
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

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }

  bool _matchesFilter(FieldData d) {
    if (_selectedFilter == 'All') return true;
    return d.structureType.toLowerCase() ==
        _selectedFilter.toLowerCase();
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F3),
      appBar: AppBar(
        backgroundColor: _darkGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Plot history',
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: const Color(0xFF6AB04C),
          indicatorWeight: 2.5,
          labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          tabs: const [
            Tab(text: 'Records'),
            Tab(text: 'Timeline'),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('fielddata')
            .where('userId', isEqualTo: widget.userId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _errorView(snapshot.error.toString());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _emptyView();
          }

          List<({FieldData data, String docId})> entries;
          try {
            entries = snapshot.data!.docs
                .map((doc) => (
                      data: FieldData.fromMap(
                          doc.data() as Map<String, dynamic>),
                      docId: doc.id,
                    ))
                .toList();
          } catch (e) {
            return _errorView('Error parsing records: $e');
          }

          final filtered =
              entries.where((e) => _matchesFilter(e.data)).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildRecordsTab(entries, filtered),
              _buildTimelineTab(entries),
            ],
          );
        },
      ),
    );
  }

  // ─── Records tab ───────────────────────────────────────────────────────────

  Widget _buildRecordsTab(
    List<({FieldData data, String docId})> all,
    List<({FieldData data, String docId})> filtered,
  ) {
    return Column(
      children: [
        // Stats bar
        _statsBar(all),
        // Filter chips
        _filterRow(),
        // List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No records match "$_selectedFilter"',
                    style: const TextStyle(
                        fontSize: 14, color: Colors.black45),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _plotCard(
                      filtered[i].data, filtered[i].docId),
                ),
        ),
      ],
    );
  }

  Widget _statsBar(List<({FieldData data, String docId})> entries) {
    final good =
        entries.where((e) => _plotStatus(e.data) == 'Good').length;
    final attention = entries
        .where((e) => _plotStatus(e.data) == 'Needs attention')
        .length;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _statChip('${entries.length}', 'total', Colors.black54,
              Colors.grey[100]!),
          const SizedBox(width: 8),
          _statChip('$good', 'good', const Color(0xFF1B5E20),
              const Color(0xFFE8F5E9)),
          const SizedBox(width: 8),
          _statChip('$attention', 'attention', const Color(0xFFE65100),
              const Color(0xFFFFF8E1)),
        ],
      ),
    );
  }

  Widget _statChip(
      String val, String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(val,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: textColor)),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(fontSize: 11, color: textColor)),
        ],
      ),
    );
  }

  Widget _filterRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filters.map((f) {
            final selected = _selectedFilter == f;
            return GestureDetector(
              onTap: () => setState(() => _selectedFilter = f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 7),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFF4F6F3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFFA5D6A7)
                        : Colors.grey[300]!,
                  ),
                ),
                child: Text(
                  f,
                  style: TextStyle(
                    fontSize: 12,
                    color: selected
                        ? const Color(0xFF1B5E20)
                        : Colors.black54,
                    fontWeight: selected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _plotCard(FieldData entry, String docId) {
    final status = _plotStatus(entry);
    final isExpanded = _expandedDocId == docId;
    final cropLabel = entry.crops.isNotEmpty &&
            (entry.crops.first['type'] ?? '').isNotEmpty
        ? entry.crops
            .map((c) => '${c['type']} · ${c['stage'] ?? ''}')
            .join(', ')
        : 'No crop recorded';
    final date = entry.timestamp.toDate();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          // Header — always visible
          InkWell(
            onTap: () => setState(() =>
                _expandedDocId = isExpanded ? null : docId),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              entry.plotId,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: _statusBg(status),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: _statusColor(status),
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          cropLabel,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (entry.area != null) ...[
                              const Icon(Icons.crop_square_rounded,
                                  size: 11, color: Colors.black38),
                              const SizedBox(width: 3),
                              Text(
                                '${entry.area?.toStringAsFixed(1)} ac',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.black38),
                              ),
                              const SizedBox(width: 8),
                            ],
                            const Icon(Icons.access_time_rounded,
                                size: 11, color: Colors.black38),
                            const SizedBox(width: 3),
                            Text(
                              _timeAgo(date),
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.black38),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: Colors.black26,
                  ),
                ],
              ),
            ),
          ),

          // Expanded detail
          if (isExpanded) ...[
            Divider(height: 1, color: Colors.grey[200]),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // NPK chips
                  if (entry.npk['N'] != null ||
                      entry.npk['P'] != null ||
                      entry.npk['K'] != null)
                    _npkChips(entry),

                  // Micro-nutrients
                  if (entry.microNutrients.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _detailRow('Micronutrients',
                        entry.microNutrients.join(', ')),
                  ],

                  // Interventions
                  if (entry.interventions.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _sectionLabel('Interventions'),
                    ...entry.interventions.map((i) => _interventionRow(i)),
                  ],

                  // Reminders
                  if (entry.reminders.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _sectionLabel('Reminders'),
                    ...entry.reminders.map((r) => _reminderRow(r)),
                  ],

                  // Fertiliser recommendation
                  if ((entry.fertilizerRecommendation ?? '').isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFFA5D6A7)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.eco_outlined,
                              size: 14,
                              color: _accentGreen),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              entry.fertilizerRecommendation!,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF1B5E20)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _editPlot(context, entry, docId),
                          icon: const Icon(Icons.edit_outlined, size: 14),
                          label: const Text('Edit',
                              style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _darkGreen,
                            side: const BorderSide(
                                color: Color(0xFFA5D6A7)),
                            padding:
                                const EdgeInsets.symmetric(vertical: 9),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _deletePlot(context, docId),
                          icon: const Icon(Icons.delete_outline, size: 14),
                          label: const Text('Delete',
                              style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red[700],
                            side: BorderSide(color: Colors.red[200]!),
                            padding:
                                const EdgeInsets.symmetric(vertical: 9),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FarmerPlotAnalysisScreen(
                            plotId: entry.plotId,
                            cycleName: entry.crops.isNotEmpty
                                ? '${entry.crops.first['type'] ?? 'Farm'} ${date.year}'
                                : 'Season ${date.year}',
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.analytics_outlined, size: 14),
                      label: const Text('View / Generate Season Analysis',
                          style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _darkGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding:
                            const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _npkChips(FieldData entry) {
    return Row(
      children: [
        if (entry.npk['N'] != null)
          _npkPill('N', entry.npk['N']!.toStringAsFixed(0)),
        if (entry.npk['P'] != null) ...[
          const SizedBox(width: 6),
          _npkPill('P', entry.npk['P']!.toStringAsFixed(0)),
        ],
        if (entry.npk['K'] != null) ...[
          const SizedBox(width: 6),
          _npkPill('K', entry.npk['K']!.toStringAsFixed(0)),
        ],
      ],
    );
  }

  Widget _npkPill(String key, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6F3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Text(
        '$key: $value',
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.black54),
      ),
    );
  }

  Widget _interventionRow(Map<String, dynamic> item) {
    final date = (item['date'] as dynamic)?.toDate?.call();
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFF57C00),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${item['type']}'
              '${item['quantity'] != null ? '  ·  ${(item['quantity'] as num).toStringAsFixed(1)} ${item['unit'] ?? ''}' : ''}'
              '${date != null ? '  ·  ${date.toString().substring(0, 10)}' : ''}',
              style: const TextStyle(
                  fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reminderRow(Map<String, dynamic> r) {
    final date = (r['date'] as dynamic)?.toDate?.call();
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          const Icon(Icons.notifications_outlined,
              size: 13, color: Colors.black38),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${r['activity'] ?? '—'}${date != null ? '  ·  ${date.toString().substring(0, 10)}' : ''}',
              style: const TextStyle(
                  fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: Colors.black45)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12, color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  // ─── Timeline tab ──────────────────────────────────────────────────────────

  Widget _buildTimelineTab(
      List<({FieldData data, String docId})> entries) {
    // Flatten all interventions + reminders into timeline events
    final events = <({DateTime date, String title, String sub, Color dot})>[];

    for (final e in entries) {
      // Record saved event
      events.add((
        date: e.data.timestamp.toDate(),
        title: '${e.data.plotId} — record saved',
        sub: e.data.crops.isNotEmpty
            ? (e.data.crops.first['type'] ?? '')
            : e.data.structureType,
        dot: _accentGreen,
      ));

      for (final i in e.data.interventions) {
        final d = (i['date'] as dynamic)?.toDate?.call() as DateTime?;
        if (d != null) {
          events.add((
            date: d,
            title: '${i['type']}',
            sub: '${e.data.plotId}  ·  ${i['quantity'] != null ? '${(i['quantity'] as num).toStringAsFixed(1)} ${i['unit'] ?? ''}' : ''}',
            dot: const Color(0xFFF57C00),
          ));
        }
      }

      for (final r in e.data.reminders) {
        final d = (r['date'] as dynamic)?.toDate?.call() as DateTime?;
        if (d != null) {
          events.add((
            date: d,
            title: '${r['activity'] ?? 'Reminder'}',
            sub: e.data.plotId,
            dot: const Color(0xFF1565C0),
          ));
        }
      }
    }

    // Sort by date descending
    events.sort((a, b) => b.date.compareTo(a.date));

    if (events.isEmpty) {
      return _emptyView();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: events.length,
      itemBuilder: (_, i) {
        final ev = events[i];
        final isLast = i == events.length - 1;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline line + dot
            SizedBox(
              width: 24,
              child: Column(
                children: [
                  const SizedBox(height: 4),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ev.dot,
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 1.5,
                      height: 44,
                      color: Colors.grey[200],
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ev.title,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${ev.sub}  ·  ${_timeAgo(ev.date)}',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.black45),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── Empty / error ──────────────────────────────────────────────────────────

  Widget _emptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.grass_rounded, size: 52, color: Colors.grey[300]),
            const SizedBox(height: 14),
            const Text(
              'No saved records yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54),
            ),
            const SizedBox(height: 8),
            const Text(
              'Go back and fill in your first plot to see it here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black38),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 40, color: Colors.black26),
            const SizedBox(height: 12),
            Text(
              msg,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => setState(() {}),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _darkGreen, foregroundColor: Colors.white),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Section label ─────────────────────────────────────────────────────────

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            color: Colors.black38,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      );

  // ─── Edit ──────────────────────────────────────────────────────────────────

  Future<void> _editPlot(
      BuildContext context, FieldData plot, String docId) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Controllers pre-filled
    final cropControllers =
        plot.crops.map((c) => TextEditingController(text: c['type'])).toList();
    final stageControllers =
        plot.crops.map((c) => TextEditingController(text: c['stage'])).toList();
    final areaCtrl =
        TextEditingController(text: plot.area?.toString() ?? '');
    final nCtrl = TextEditingController(text: plot.npk['N']?.toString() ?? '');
    final pCtrl = TextEditingController(text: plot.npk['P']?.toString() ?? '');
    final kCtrl = TextEditingController(text: plot.npk['K']?.toString() ?? '');

    List<Map<String, String>> editedCrops = List.from(plot.crops);

    final result = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        title: Text(
          'Edit ${plot.plotId}',
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _darkGreen),
        ),
        content: StatefulBuilder(
          builder: (ctx, setS) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...cropControllers.asMap().entries.map((entry) {
                  final idx = entry.key;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Crop ${idx + 1}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.black45)),
                      const SizedBox(height: 4),
                      _editField('Crop type', cropControllers[idx]),
                      const SizedBox(height: 6),
                      _editField('Growth stage', stageControllers[idx]),
                      const SizedBox(height: 12),
                    ],
                  );
                }),
                _editField('Area (Acres)', areaCtrl,
                    keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                      child: _editField('N (kg/ha)', nCtrl,
                          keyboardType: TextInputType.number)),
                  const SizedBox(width: 6),
                  Expanded(
                      child: _editField('P (kg/ha)', pCtrl,
                          keyboardType: TextInputType.number)),
                  const SizedBox(width: 6),
                  Expanded(
                      child: _editField('K (kg/ha)', kCtrl,
                          keyboardType: TextInputType.number)),
                ]),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.black45)),
          ),
          ElevatedButton(
            onPressed: () {
              editedCrops = cropControllers.asMap().entries
                  .map((e) => {
                        'type': cropControllers[e.key].text,
                        'stage': stageControllers[e.key].text,
                      })
                  .where((c) => c['type']!.isNotEmpty)
                  .toList();
              Navigator.pop(dCtx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _darkGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final updated = FieldData(
        userId: widget.userId,
        plotId: plot.plotId,
        crops: editedCrops,
        area: areaCtrl.text.isNotEmpty
            ? double.tryParse(areaCtrl.text)
            : null,
        npk: {
          'N': nCtrl.text.isNotEmpty ? double.tryParse(nCtrl.text) : null,
          'P': pCtrl.text.isNotEmpty ? double.tryParse(pCtrl.text) : null,
          'K': kCtrl.text.isNotEmpty ? double.tryParse(kCtrl.text) : null,
        },
        microNutrients: plot.microNutrients,
        interventions: plot.interventions,
        reminders: plot.reminders,
        timestamp: Timestamp.now(),
        structureType: plot.structureType,
        fertilizerRecommendation: plot.fertilizerRecommendation,
      );

      try {
        await FirebaseFirestore.instance
            .collection('fielddata')
            .doc(docId)
            .set(updated.toMap());
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF2E7D32),
              behavior: SnackBarBehavior.floating,
              content: Text('Record updated'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
              SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Widget _editField(
    String label,
    TextEditingController ctrl, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        isDense: true,
      ),
    );
  }

  // ─── Delete ────────────────────────────────────────────────────────────────

  Future<void> _deletePlot(BuildContext context, String docId) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete record',
            style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        content: const Text(
            'This record will be permanently deleted. This cannot be undone.',
            style: TextStyle(fontSize: 13, color: Colors.black54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.black45)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await FirebaseFirestore.instance
            .collection('fielddata')
            .doc(docId)
            .delete();
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text('Record deleted'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(
              SnackBar(content: Text('Error deleting: $e')));
        }
      }
    }
  }
}