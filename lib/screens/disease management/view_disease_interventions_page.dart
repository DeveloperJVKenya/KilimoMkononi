// lib/screens/disease management/view_disease_interventions_page.dart
//
// Shows ALL records for this specific disease — both manual entries and
// AI photo diagnoses — via the unified FarmerIssueService.
// No longer depends on FarmerDiagnosisRecord or DiagnosisService.
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:kilimomkononi/screens/disease%20management/disease_model.dart';
import 'package:kilimomkononi/models/farmer_issue_record.dart';
import 'package:kilimomkononi/services/farmer_issue_service.dart';
import 'package:timezone/timezone.dart' as tz;

// ── Theme ─────────────────────────────────────────────────────────────────
const _kDark    = Color.fromARGB(255, 3, 39, 4);
const _kMid     = Color(0xFF1B5E20);
const _kBg      = Color(0xFFF0F2EF);
const _kCardBg  = Color(0xFFF7F8F6);
const _kBorder  = Color(0xFFBBBFBA);
const _kHint    = Color(0xFF5C6B5A);
const _kText    = Color(0xFF111A10);
const _kTextSec = Color(0xFF3D4A3C);

class ViewDiseaseInterventionsPage extends StatefulWidget {
  final DiseaseData diseaseData;
  final FlutterLocalNotificationsPlugin notificationsPlugin;

  const ViewDiseaseInterventionsPage({
    required this.diseaseData,
    required this.notificationsPlugin,
    super.key,
  });

  @override
  State<ViewDiseaseInterventionsPage> createState() =>
      _ViewDiseaseInterventionsPageState();
}

class _ViewDiseaseInterventionsPageState
    extends State<ViewDiseaseInterventionsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  List<FarmerIssueRecord> _records = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final all = await FarmerIssueService.getSimilarCases(
        cropName:  '',
        issueName: widget.diseaseData.name,
      );
      if (mounted) setState(() { _records = all; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<FarmerIssueRecord> get _manual => _records.where((r) => !r.isAI).toList();
  List<FarmerIssueRecord> get _ai     => _records.where((r) =>  r.isAI).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kDark, foregroundColor: Colors.white, elevation: 0,
        title: Text(widget.diseaseData.name,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: const Color(0xFF6AB04C),
          indicatorWeight: 2.5,
          tabs: [
            Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.edit_note, size: 15), const SizedBox(width: 5),
              Text('Manual (${_manual.length})', style: const TextStyle(fontSize: 13)),
            ])),
            Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.psychology, size: 15), const SizedBox(width: 5),
              Text('AI Scan (${_ai.length})', style: const TextStyle(fontSize: 13)),
            ])),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : TabBarView(
                  controller: _tab,
                  children: [
                    _listView(_manual, isAI: false),
                    _listView(_ai, isAI: true),
                  ],
                ),
    );
  }

  Widget _errorView() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.wifi_off_rounded, size: 40, color: Colors.black26),
    const SizedBox(height: 12),
    Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
    const SizedBox(height: 12),
    ElevatedButton(onPressed: _load,
        style: ElevatedButton.styleFrom(backgroundColor: _kDark, foregroundColor: Colors.white),
        child: const Text('Retry')),
  ]));

  Widget _listView(List<FarmerIssueRecord> list, {required bool isAI}) {
    if (list.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(isAI ? Icons.psychology_outlined : Icons.edit_note_rounded,
              size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            isAI
                ? 'No AI photo diagnoses for this disease yet.\nUse the AI Photo Diagnosis tab to analyse a photo.'
                : 'No manual interventions recorded yet.\nSave one from the previous screen.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ]),
      ));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _RecordCard(
        record: list[i],
        notificationsPlugin: widget.notificationsPlugin,
        onDelete: () async {
          if (list[i].id != null) {
            await FarmerIssueService.softDelete(list[i].id!);
            _load();
          }
        },
        onEdit: (updated) async {
          if (list[i].id == null) return;
          await FarmerIssueService.updateIntervention(list[i].id!, updated);
          _load();
        },
      ),
    );
  }
}

// ── Record Card (same structure as pest version) ──────────────────────────
class _RecordCard extends StatefulWidget {
  final FarmerIssueRecord record;
  final FlutterLocalNotificationsPlugin notificationsPlugin;
  final VoidCallback onDelete;
  final ValueChanged<String> onEdit;

  const _RecordCard({
    required this.record,
    required this.notificationsPlugin,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  State<_RecordCard> createState() => _RecordCardState();
}

class _RecordCardState extends State<_RecordCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final accentColor = r.isAI ? const Color(0xFF6A1B9A) : const Color(0xFF1565C0);

    return Container(
      decoration: BoxDecoration(
        color: _kCardBg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1.5)),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(r.isAI ? Icons.psychology : Icons.local_hospital_outlined,
                    color: accentColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(r.issueName,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kText))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: accentColor.withValues(alpha: 0.3))),
                    child: Text(r.isAI ? 'AI Scan' : 'By Eye',
                        style: TextStyle(fontSize: 10, color: accentColor, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 3),
                Text('${r.cropName}  ·  ${r.cropStage}  ·  Cycle ${r.cycle}',
                    style: const TextStyle(fontSize: 12, color: _kTextSec)),
                const SizedBox(height: 4),
                Row(children: [
                  if (r.aiConfidence != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: _confColor(r.aiConfidence!).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _confColor(r.aiConfidence!).withValues(alpha: 0.4))),
                      child: Text(r.aiConfidence!.toUpperCase(),
                          style: TextStyle(fontSize: 9, color: _confColor(r.aiConfidence!), fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(_timeAgo(r.timestamp.toDate()),
                      style: const TextStyle(fontSize: 11, color: _kHint)),
                ]),
              ])),
              Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.grey[400], size: 20),
            ]),
          ),
        ),

        if (_expanded)
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12))),
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              if (r.aiDescription != null && r.aiDescription!.isNotEmpty) ...[
                _secLabel('🔍  What the AI saw'),
                const SizedBox(height: 4),
                Text(r.aiDescription!, style: const TextStyle(fontSize: 13, height: 1.5, color: _kText)),
                const SizedBox(height: 12),
              ],

              if (r.aiRecommendation != null && r.aiRecommendation!.isNotEmpty) ...[
                _secLabel('💡  AI Recommendation'),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFE082))),
                  child: Text(r.aiRecommendation!, style: const TextStyle(fontSize: 13, color: Color(0xFF7A4F00))),
                ),
                const SizedBox(height: 12),
              ],

              if (r.hasIntervention) ...[
                _secLabel('✅  What was done'),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFDFF2DF), borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF2E7D32))),
                  child: Text(r.interventionText!, style: const TextStyle(fontSize: 13, color: _kText)),
                ),
                const SizedBox(height: 12),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFFFF3CD), borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE6A817))),
                  child: const Row(children: [
                    Icon(Icons.info_outline, size: 15, color: Color(0xFFB97000)), SizedBox(width: 8),
                    Text('No intervention recorded yet',
                        style: TextStyle(fontSize: 13, color: Color(0xFF7A4F00))),
                  ]),
                ),
                const SizedBox(height: 12),
              ],

              if (r.dosage != null || r.area != null) ...[
                _secLabel('📏  Application details'),
                const SizedBox(height: 4),
                if (r.dosage != null) _detailRow('Dosage', '${r.dosage} ${r.dosageUnit ?? ''}'),
                if (r.area != null)   _detailRow('Area', '${r.area} ${r.areaUnit}'),
                const SizedBox(height: 12),
              ],

              if (r.photoUrl != null) ...[
                ClipRRect(borderRadius: BorderRadius.circular(8),
                    child: Image.network(r.photoUrl!, height: 160, width: double.infinity, fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox())),
                const SizedBox(height: 12),
              ],

              Row(children: [
                if (!r.isAI) ...[
                  _actionBtn(icon: Icons.edit_outlined, label: 'Edit', color: const Color(0xFF1565C0),
                      onTap: () => _showEditDialog()),
                  const SizedBox(width: 8),
                ],
                _actionBtn(icon: Icons.notifications_outlined, label: 'Reminder', color: _kMid,
                    onTap: () => _showReminderDialog()),
                const SizedBox(width: 8),
                _actionBtn(icon: Icons.delete_outline, label: 'Delete', color: Colors.red.shade700,
                    onTap: () => _confirmDelete(context)),
              ]),
            ]),
          ),
      ]),
    );
  }

  Widget _secLabel(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kMid)));

  Widget _detailRow(String label, String val) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(children: [
          Text('$label: ', style: const TextStyle(fontSize: 12, color: _kHint)),
          Text(val, style: const TextStyle(fontSize: 12, color: _kText)),
        ]));

  Widget _actionBtn({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color), const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Color _confColor(String c) {
    switch (c.toLowerCase()) {
      case 'high':   return Colors.green.shade700;
      case 'medium': return Colors.orange.shade700;
      default:       return Colors.red.shade600;
    }
  }

  String _timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7)  return '${diff.inDays}d ago';
    return '${d.day}/${d.month}/${d.year}';
  }

  Future<void> _showEditDialog() async {
    final ctrl = TextEditingController(text: widget.record.interventionText ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: Colors.white,
        title: const Text('Edit intervention',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        content: TextField(controller: ctrl, maxLines: 4,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(labelText: 'What was done',
                filled: true, fillColor: const Color(0xFFECEEEB),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: _kDark, foregroundColor: Colors.white,
                elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && mounted) widget.onEdit(result);
  }

  Future<void> _showReminderDialog() async {
    DateTime date = DateTime.now().add(const Duration(days: 7));
    final result = await showDialog<DateTime>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: Colors.white,
          title: const Text('Set follow-up reminder',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          content: InkWell(
            onTap: () async {
              final picked = await showDatePicker(context: ctx,
                  initialDate: date, firstDate: DateTime.now(), lastDate: DateTime(2030));
              if (picked != null) setS(() => date = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(color: const Color(0xFFECEEEB), borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kBorder, width: 1.5)),
              child: Row(children: [
                const Icon(Icons.calendar_today_rounded, size: 18, color: _kHint), const SizedBox(width: 10),
                Text('${date.day}/${date.month}/${date.year}',
                    style: const TextStyle(fontSize: 14, color: _kText)),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, date),
              style: ElevatedButton.styleFrom(backgroundColor: _kDark, foregroundColor: Colors.white,
                  elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('Set'),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      try {
        final tzDate = tz.TZDateTime.from(result, tz.local);

        await widget.notificationsPlugin.zonedSchedule(
          id: widget.record.id.hashCode,
          title: 'Follow-up: ${widget.record.issueName}',
          body: 'Evaluate intervention on ${widget.record.cropName}.',
          scheduledDate: tzDate,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'pest_followup_v2',
              'Pest Follow-Up Reminders',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Follow-up reminder set')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error setting reminder: $e')));
        }
      }
    }
  }
  
  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete record?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        content: const Text('This record will be hidden. It can be restored by an admin.',
            style: TextStyle(fontSize: 13, color: Colors.black54)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) widget.onDelete();
  }
}