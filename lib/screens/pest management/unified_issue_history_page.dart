// lib/screens/pest management/unified_issue_history_page.dart
//
// UNIFIED history page — shows ALL farmer pest/disease records in one place:
//   • AI photo diagnosis results
//   • Manual (by-eye) pest interventions
//   • Manual disease interventions
//
// Replaces: UserPestHistoryPage + UserDiseaseHistoryPage + DiagnosisHistoryPage
// Route from: PestDiseaseHomePage, after photo diagnosis, after manual entry
//
// ignore_for_file: unused_element, unnecessary_underscores, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:kilimomkononi/models/farmer_issue_record.dart';
import 'package:kilimomkononi/services/farmer_issue_service.dart';

const _kGreen = Color.fromARGB(255, 3, 39, 4);

class UnifiedIssueHistoryPage extends StatefulWidget {
  /// Optional filters — pass to pre-filter the list
  final String? cropName;
  final String? cycle;
  final String? issueType; // 'pest' | 'disease' | null = all

  const UnifiedIssueHistoryPage({
    super.key,
    this.cropName,
    this.cycle,
    this.issueType,
  });

  @override
  State<UnifiedIssueHistoryPage> createState() =>
      _UnifiedIssueHistoryPageState();
}

class _UnifiedIssueHistoryPageState
    extends State<UnifiedIssueHistoryPage> {
  List<FarmerIssueRecord>? _records;
  bool _loading = true;
  String? _error;

  // Filters
  String? _filterCrop;
  String? _filterCycle;
  String? _filterType; // 'pest' | 'disease' | 'ai' | null

  @override
  void initState() {
    super.initState();
    _filterCrop  = widget.cropName;
    _filterCycle = widget.cycle;
    _filterType  = widget.issueType;
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final records = await FarmerIssueService.fetchAll(
        cropName: _filterCrop,
        cycle:    _filterCycle,
      );
      setState(() {
        _records = records;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<FarmerIssueRecord> get _filtered {
    if (_records == null) return [];
    return _records!.where((r) {
      if (_filterType == 'pest'    && !r.isPest)    return false;
      if (_filterType == 'disease' && !r.isDisease) return false;
      if (_filterType == 'ai'      && !r.isAI)      return false;
      return true;
    }).toList();
  }

  // Unique values for filter chips
  List<String> get _crops  =>
      _records?.map((r) => r.cropName).toSet().toList() ?? [];
  List<String> get _cycles =>
      _records?.map((r) => r.cycle).toSet().toList() ?? [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Farm Issue History',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _kGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(children: [
        _buildFilterBar(),
        Expanded(child: _buildBody()),
      ]),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: _kGreen.withOpacity(0.04),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          // Type filter
          _chip('All',     null,      _filterType == null),
          _chip('Pests',   'pest',    _filterType == 'pest'),
          _chip('Diseases','disease', _filterType == 'disease'),
          _chip('AI Scan', 'ai',      _filterType == 'ai'),
          const SizedBox(width: 12),
          const VerticalDivider(width: 1, thickness: 1),
          const SizedBox(width: 12),
          // Crop filter
          ..._crops.map((c) => _cropChip(c)),
        ]),
      ),
    );
  }

  Widget _chip(String label, String? value, bool selected) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 12,
            color: selected ? Colors.white : Colors.black87)),
        selected: selected,
        selectedColor: _kGreen,
        checkmarkColor: Colors.white,
        onSelected: (_) => setState(() {
          _filterType = value;
        }),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  Widget _cropChip(String crop) {
    final selected = _filterCrop == crop;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(crop, style: TextStyle(fontSize: 12,
            color: selected ? Colors.white : Colors.black87)),
        selected: selected,
        selectedColor: Colors.teal[700],
        checkmarkColor: Colors.white,
        onSelected: (_) => setState(() {
          _filterCrop = selected ? null : crop;
          _load();
        }),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 40),
        const SizedBox(height: 8),
        Text(_error!, textAlign: TextAlign.center),
        TextButton(onPressed: _load, child: const Text('Retry')),
      ]));
    }
    final list = _filtered;
    if (list.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.history, size: 56, color: Colors.grey[300]),
        const SizedBox(height: 12),
        const Text('No records found', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 4),
        Text('Records from AI scans and manual entries\nwill all appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[500])),
      ]));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _IssueCard(
        record:   list[i],
        onDelete: () async {
          if (list[i].id != null) {
            await FarmerIssueService.softDelete(list[i].id!);
            _load();
          }
        },
      ),
    );
  }
}

// ─── Issue Card ───────────────────────────────────────────────────────────────
class _IssueCard extends StatefulWidget {
  final FarmerIssueRecord record;
  final VoidCallback onDelete;
  const _IssueCard({required this.record, required this.onDelete});
  @override
  State<_IssueCard> createState() => _IssueCardState();
}

class _IssueCardState extends State<_IssueCard> {
  bool _expanded = false;

  Color get _typeColor =>
      widget.record.isPest ? const Color(0xFF2E7D32) : const Color(0xFF1565C0);

  Color get _sourceColor =>
      widget.record.isAI ? const Color(0xFF6A1B9A) : const Color(0xFF455A64);

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _typeColor.withOpacity(0.3), width: 1),
      ),
      child: Column(children: [
        // ── Header ────────────────────────────────────────────────────────────
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Type icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _typeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  r.isPest ? Icons.bug_report : Icons.local_hospital,
                  color: _typeColor, size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Issue name
                  Text(r.issueName,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  // Crop · Stage · Cycle
                  Text('${r.cropName} · ${r.cropStage} · ${r.cycle}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 4),
                  Row(children: [
                    // Source badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _sourceColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                            color: _sourceColor.withOpacity(0.3)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          r.isAI ? Icons.psychology : Icons.visibility,
                          size: 11, color: _sourceColor,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          r.isAI ? 'AI Scan' : 'By Eye',
                          style: TextStyle(
                              fontSize: 10,
                              color: _sourceColor,
                              fontWeight: FontWeight.w600),
                        ),
                      ]),
                    ),
                    // AI confidence badge
                    if (r.isAI && r.aiConfidence != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _confColor(r.aiConfidence!).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                              color: _confColor(r.aiConfidence!)
                                  .withOpacity(0.4)),
                        ),
                        child: Text(r.aiConfidence!.toUpperCase(),
                            style: TextStyle(
                                fontSize: 10,
                                color: _confColor(r.aiConfidence!),
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                    const Spacer(),
                    // Date
                    Text(
                      _fmt(r.timestamp.toDate()),
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[500]),
                    ),
                  ]),
                ]),
              ),
              Icon(
                _expanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: Colors.grey[400], size: 20,
              ),
            ]),
          ),
        ),

        // ── Expanded detail ───────────────────────────────────────────────────
        if (_expanded)
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(
                  top: BorderSide(color: Colors.grey[200]!)),
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12)),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [

              // AI description
              if (r.aiDescription != null &&
                  r.aiDescription!.isNotEmpty) ...[
                _sectionLabel('🔍 What the AI saw'),
                const SizedBox(height: 4),
                Text(r.aiDescription!,
                    style: const TextStyle(fontSize: 13, height: 1.5)),
                const SizedBox(height: 12),
              ],

              // AI recommendation
              if (r.aiRecommendation != null &&
                  r.aiRecommendation!.isNotEmpty) ...[
                _sectionLabel('💡 AI Recommendation'),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Text(r.aiRecommendation!,
                      style: TextStyle(
                          fontSize: 13, color: Colors.amber[900])),
                ),
                const SizedBox(height: 12),
              ],

              // What farmer did
              if (r.hasIntervention) ...[
                _sectionLabel('✅ What was done'),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(r.interventionText!,
                      style: const TextStyle(fontSize: 13)),
                ),
                const SizedBox(height: 12),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: const Row(children: [
                    Icon(Icons.info_outline,
                        color: Colors.orange, size: 16),
                    SizedBox(width: 8),
                    Text('No intervention recorded yet',
                        style: TextStyle(fontSize: 13)),
                  ]),
                ),
                const SizedBox(height: 12),
              ],

              // Dosage / area
              if (r.dosage != null || r.amountText != null ||
                  r.area != null) ...[
                _sectionLabel('📏 Application details'),
                const SizedBox(height: 4),
                if (r.dosage != null)
                  _detail('Dosage',
                      '${r.dosage} ${r.dosageUnit ?? ''}'),
                if (r.amountText != null)
                  _detail('Amount', r.amountText!),
                if (r.area != null)
                  _detail('Area', '${r.area} ${r.areaUnit}'),
                const SizedBox(height: 12),
              ],

              // Photo
              if (r.photoUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(r.photoUrl!,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox()),
                ),
                const SizedBox(height: 12),
              ],

              // Delete
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _confirmDelete(context),
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 16),
                  label: const Text('Delete',
                      style: TextStyle(color: Colors.red, fontSize: 13)),
                ),
              ),
            ]),
          ),
      ]),
    );
  }

  Widget _sectionLabel(String t) => Text(t,
      style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600, color: _kGreen));

  Widget _detail(String label, String val) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(children: [
      Text('$label: ',
          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      Text(val, style: const TextStyle(fontSize: 12)),
    ]),
  );

  Color _confColor(String c) {
    switch (c.toLowerCase()) {
      case 'high':   return Colors.green[700]!;
      case 'medium': return Colors.orange[700]!;
      default:       return Colors.red[600]!;
    }
  }

  String _fmt(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    if (diff.inDays == 1)    return 'Yesterday';
    return '${d.day}/${d.month}/${d.year}';
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this record?'),
        content: const Text(
            'This record will be hidden. It can be restored by an admin.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) widget.onDelete();
  }
}