// lib/screens/pest management/intervention_page.dart
//
// Saves to:
//   • farmer_issues/{userId}/records  (new unified collection via FarmerIssueService)
//   • pestinterventiondata            (legacy write kept for backward compat)
//   • field_costs                     (if cost amount > 0 and saveToCosts = true)
//   • field_reminders                 (if follow-up reminder is enabled)

// ignore_for_file: library_prefixes, deprecated_member_use, curly_braces_in_flow_control_structures

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:http/http.dart' as http;
import 'package:timezone/data/latest.dart' as tzData;
import 'package:timezone/timezone.dart' as tz;
import 'package:kilimomkononi/models/pest_disease_model.dart';
import 'package:kilimomkononi/models/farmer_issue_record.dart';
import 'package:kilimomkononi/screens/pest%20management/view_interventions_page.dart';
import 'package:kilimomkononi/services/farmer_issue_service.dart';
import 'package:kilimomkononi/services/field_cost_bridge.dart';

// ── Outdoor-readable theme ────────────────────────────────────────────────
class _T {
  static const pageBg      = Color(0xFFF0F2EF);
  static const cardBg      = Color(0xFFF7F8F6);
  static const inputBg     = Color(0xFFECEEEB);
  static const borderDef   = Color(0xFFBBBFBA);
  static const brandDark   = Color.fromARGB(255, 3, 39, 4);
  static const brandMid    = Color(0xFF1B5E20);
  static const brandLight  = Color(0xFF2E7D32);
  static const textPrimary = Color(0xFF111A10);
  static const textSec     = Color(0xFF3D4A3C);
  static const textHint    = Color(0xFF5C6B5A);
  static const okBg        = Color(0xFFDFF2DF);
  static const okBorder    = Color(0xFF2E7D32);
  static const costBg      = Color(0xFFFFF3CD);
  static const costBorder  = Color(0xFFE6A817);
  static const costIcon    = Color(0xFFB97000);
  static const costText    = Color(0xFF7A4F00);
  static const aiGradA     = Color(0xFF0D2B0E);
  static const aiGradB     = Color(0xFF1B5E20);
  static const infoBg      = Color(0xFFDCEEFB);
  static const infoBorder  = Color(0xFF1565C0);
  static const infoText    = Color(0xFF0D3C7A);

  static BoxDecoration card({Color? border}) => BoxDecoration(
        color: cardBg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border ?? borderDef, width: 1.5));

  static InputDecoration field(String label, {String? hint}) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: textSec, fontWeight: FontWeight.w500),
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: textHint),
        filled: true, fillColor: inputBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: borderDef, width: 1.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: borderDef, width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: brandLight, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14));
}

const _kAskGeminiUrl    = 'https://us-central1-kilimomkononi-e1031.cloudfunctions.net/askGeminiVision';
const _kNotifChannel    = 'pest_reminders_v2';
const _kNotifChanName   = 'Pest Activity Reminders';

class InterventionPage extends StatefulWidget {
  final PestData pestData;
  final String cropType;
  final String cropStage;
  
  final FlutterLocalNotificationsPlugin notificationsPlugin;

  const InterventionPage({
    required this.pestData,
    required this.cropType,
    required this.cropStage,
    required this.notificationsPlugin,
    super.key,
  });

  @override
  State<InterventionPage> createState() => _InterventionPageState();
}

class _InterventionPageState extends State<InterventionPage> {
  final _cycleCtrl        = TextEditingController(text: 'A');
  final _interventionCtrl = TextEditingController();
  final _amountCtrl       = TextEditingController();
  final _areaCtrl         = TextEditingController();
  final _costCtrl         = TextEditingController();
  String _areaUnit        = 'Acres';
  bool   _saveToCosts     = true;
  String _costCategory    = 'Pesticide / Herbicide';

  List<Map<String, String>> _farmPlots       = [];
  String?                   _selectedPlotId;

  bool   _aiLoading  = false;
  String? _aiAdvice;
  List<Map<String, dynamic>> _aiSuggestions = [];

  bool     _followUp     = true;
  DateTime _reminderDate = DateTime.now().add(const Duration(days: 7));
  bool     _tzReady      = false;
  bool     _saving       = false;

  @override
  void initState() {
    super.initState();
    _initTz();
    _loadPlots();
    _interventionCtrl.addListener(
        () => setState(() => _costCategory = inferCostCategory(_interventionCtrl.text)));
  }

  @override
  void dispose() {
    for (final c in [_cycleCtrl, _interventionCtrl, _amountCtrl, _areaCtrl, _costCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _initTz() async {
    if (_tzReady) return;
    try {
      tzData.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation((await FlutterTimezone.getLocalTimezone()) as String));
      _tzReady = true;
    } catch (_) {}
  }

  Future<void> _loadPlots() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final plots = await FieldCostService.loadFarmPlots(uid);
    if (mounted) setState(() {
      _farmPlots = plots;
      if (plots.isNotEmpty) _selectedPlotId = plots.first['id'];
    });
  }

  // ── AI advisor ────────────────────────────────────────────────────────────

  Future<void> _fetchAiAdvice() async {
    setState(() { _aiLoading = true; _aiAdvice = null; _aiSuggestions = []; });

    final prompt = '''
You are an agronomist advising smallholder farmers in Kenya and East Africa.

Pest: ${widget.pestData.name}
Crop: ${widget.cropType}  |  Stage: ${widget.cropStage}
Known pesticides: ${widget.pestData.herbicides.join(', ')}
Known organic interventions: ${widget.pestData.organicInterventions.join(', ')}

Provide:
1. Brief diagnosis of the threat at this stage (2 sentences).
2. Up to 3 specific interventions available in Kenya — product name, quantity per acre, timing and method.
3. One organic alternative for each chemical.
4. Critical warnings (pre-harvest intervals, mixing restrictions).
5. Single most urgent action today.

Plain English, under 220 words, numbered lists only.

Then on a new line:
INTERVENTIONS_JSON:
[{"type":"Spray Imidacloprid 70 WG","quantity":2.0,"unit":"g/L","category":"Pesticide / Herbicide"}]
If none: INTERVENTIONS_JSON: []
''';

    try {
      final resp = await http.post(Uri.parse(_kAskGeminiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'prompt': prompt}),
      ).timeout(const Duration(seconds: 35));

      if (resp.statusCode == 200) {
        final raw = (jsonDecode(resp.body)['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?) ?? '';
        final idx = raw.indexOf('INTERVENTIONS_JSON:');
        String advice = idx >= 0 ? raw.substring(0, idx).trim() : raw.trim();
        List<Map<String, dynamic>> parsed = [];
        if (idx >= 0) {
          try { parsed = (jsonDecode(raw.substring(idx + 18).trim()) as List)
              .map((e) => Map<String, dynamic>.from(e)).toList(); } catch (_) {}
        }
        if (mounted) setState(() { _aiAdvice = advice.isNotEmpty ? advice : 'No advice returned.'; _aiSuggestions = parsed; _aiLoading = false; });
      } else {
        if (mounted) setState(() { _aiAdvice = 'AI error (${resp.statusCode}). Try again.'; _aiLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() {
        _aiAdvice = e.toString().contains('Timeout') ? 'Request timed out. Check connection.' : 'AI unavailable offline. Use manual hints above.';
        _aiLoading = false;
      });
    }
  }

  void _acceptSuggestion(Map<String, dynamic> s) {
    setState(() {
      _interventionCtrl.text = s['type'] as String? ?? '';
      if (s['quantity'] != null) _amountCtrl.text = '${(s['quantity'] as num).toStringAsFixed(1)} ${s['unit'] ?? ''}';
      _costCategory = s['category'] as String? ?? 'Pesticide / Herbicide';
    });
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    final msg  = ScaffoldMessenger.of(context);
    if (user == null) { msg.showSnackBar(const SnackBar(content: Text('Please log in'))); return; }
    if (_interventionCtrl.text.isEmpty && _amountCtrl.text.isEmpty && _areaCtrl.text.isEmpty) {
      msg.showSnackBar(const SnackBar(content: Text('Please fill at least one field'))); return;
    }

    setState(() => _saving = true);
    final now = Timestamp.now();

    try {
      // ── 1. Save to new unified FarmerIssueRecord collection ──────────────
      final record = FarmerIssueRecord(
        userId:           user.uid,
        cycle:            _cycleCtrl.text.trim().isEmpty ? 'A' : _cycleCtrl.text.trim(),
        cropName:         widget.cropType,
        cropStage:        widget.cropStage,
        issueType:        'pest',
        issueName:        widget.pestData.name,
        source:           DiagnosisSource.manual,
        interventionText: _interventionCtrl.text.isNotEmpty ? _interventionCtrl.text : null,
        amountText:       _amountCtrl.text.isNotEmpty ? _amountCtrl.text : null,
        area:             _areaCtrl.text.isNotEmpty ? double.tryParse(_areaCtrl.text) : null,
        areaUnit:         _areaUnit,
        timestamp:        now,
        aiAdvice:         _aiAdvice,
      );
      await FarmerIssueService.saveRecord(record);

      // ── 2. Legacy write (kept for backward compat / admin reporting) ──────
      try {
        await FirebaseFirestore.instance.collection('pestinterventiondata').add({
          'pestName': widget.pestData.name, 'cropType': widget.cropType,
          'cropStage': widget.cropStage,
          'cycle': record.cycle, 'intervention': _interventionCtrl.text,
          'area': record.area, 'areaUnit': _areaUnit,
          'timestamp': now, 'userId': user.uid,
          'isDeleted': false, 'amount': record.amountText,
        });
      } catch (_) {} // non-fatal

      // ── 3. Cost capture ───────────────────────────────────────────────────
      final cost = double.tryParse(_costCtrl.text) ?? 0.0;
      if (cost > 0 && _saveToCosts) {
        final entry = FieldCostEntry(
          id:              '${user.uid}_pest_${now.millisecondsSinceEpoch}',
          userId:          user.uid,
          plotId:          _selectedPlotId ?? 'unlinked',
          description:     '${_interventionCtrl.text} — ${widget.pestData.name} (${widget.cropType})',
          category:        _costCategory,
          amount:          cost,
          date:            now.toDate(),
          source:          'pest_management',
          interventionType:'pest',
        );
        try { await FieldCostService.saveFromFieldData(entry); } catch (_) {}
      }

      // ── 4. Reminder ───────────────────────────────────────────────────────
      if (_followUp) {
        await _scheduleReminder(
          id:     'pest_${widget.pestData.name}_${_reminderDate.millisecondsSinceEpoch}',
          title:  'Follow-up: ${widget.pestData.name}',
          body:   'Evaluate intervention on ${widget.cropType}.',
          date:   _reminderDate,
          userId: user.uid,
        );
      }

      if (mounted) {
        _reset();
        msg.showSnackBar(SnackBar(
          backgroundColor: _T.brandLight, behavior: SnackBarBehavior.floating,
          content: const Row(children: [
            Icon(Icons.check_circle, color: Colors.white, size: 16), SizedBox(width: 8),
            Text('Intervention saved', style: TextStyle(color: Colors.white)),
          ]),
        ));
      }
    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        if (mounted) { _reset(); msg.showSnackBar(SnackBar(backgroundColor: _T.brandLight, behavior: SnackBarBehavior.floating, content: const Text('Intervention saved', style: TextStyle(color: Colors.white)))); }
      } else {
        if (mounted) msg.showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
Future<void> _scheduleReminder({
    required String id,
    required String title,
    required String body,
    required DateTime date,
    required String userId,
  }) async {
    if (date.isBefore(DateTime.now())) return;
    try {
      if (!_tzReady) await _initTz();
      final tzDate = tz.TZDateTime.from(date, tz.local);

      await FirebaseFirestore.instance.collection('field_reminders').doc(id).set({
        'userId': userId,
        'title': title,
        'body': body,
        'scheduledDate': Timestamp.fromDate(date),
        'notifId': id.hashCode,
      });

      await widget.notificationsPlugin.zonedSchedule(
        id: id.hashCode,
        title: title,
        body: body,
        scheduledDate: tzDate,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _kNotifChannel,
            _kNotifChanName,
            channelDescription: 'Pest activity reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {}
  }

  void _reset() {
    setState(() {
      _cycleCtrl.text = 'A';
      for (final c in [_interventionCtrl, _amountCtrl, _areaCtrl, _costCtrl]) c.clear();
      _areaUnit = 'Acres'; _saveToCosts = true; _costCategory = 'Pesticide / Herbicide';
      _followUp = true; _reminderDate = DateTime.now().add(const Duration(days: 7));
      _aiAdvice = null; _aiSuggestions = [];
    });
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.pageBg,
      appBar: AppBar(
        backgroundColor: _T.brandDark, foregroundColor: Colors.white, elevation: 0,
        title: const Text('Pest Intervention',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Context ────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: _T.card(border: _T.okBorder),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.bug_report_outlined, size: 16, color: _T.brandMid),
                const SizedBox(width: 6),
                Expanded(child: Text(widget.pestData.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _T.textPrimary))),
              ]),
              const SizedBox(height: 4),
              Text('${widget.cropType}  ·  ${widget.cropStage}',
                  style: const TextStyle(fontSize: 13, color: _T.textSec)),
            ]),
          ),
          const SizedBox(height: 16),

          // ── AI advisor ─────────────────────────────────────────────────────
          _aiAdvisorCard(),
          const SizedBox(height: 20),

          // ── Form ───────────────────────────────────────────────────────────
          _label('SEASON / CYCLE'),
          const SizedBox(height: 6),
          TextField(controller: _cycleCtrl, style: const TextStyle(fontSize: 14, color: _T.textPrimary),
              decoration: _T.field('Season / Cycle', hint: 'e.g. A, Season 1, March 2025')),
          const SizedBox(height: 14),

          _label('INTERVENTION USED'),
          const SizedBox(height: 6),
          TextField(controller: _interventionCtrl, style: const TextStyle(fontSize: 14, color: _T.textPrimary),
              decoration: _T.field('Intervention used', hint: 'e.g. Spray Imidacloprid')),
          const SizedBox(height: 14),

          _label('AMOUNT APPLIED'),
          const SizedBox(height: 6),
          TextField(controller: _amountCtrl, style: const TextStyle(fontSize: 14, color: _T.textPrimary),
              decoration: _T.field('Amount applied', hint: 'e.g. 2 ml/L')),
          const SizedBox(height: 14),

          _label('AREA AFFECTED'),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: TextField(controller: _areaCtrl, keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 14, color: _T.textPrimary),
                decoration: _T.field('Area'))),
            const SizedBox(width: 10),
            _unitBtn('Acres'), const SizedBox(width: 6), _unitBtn('SQM'),
          ]),
          const SizedBox(height: 20),

          // ── Cost ───────────────────────────────────────────────────────────
          _costCard(),
          const SizedBox(height: 20),

          // ── Reminder ───────────────────────────────────────────────────────
          _reminderCard(),
          const SizedBox(height: 24),

          // ── Actions ────────────────────────────────────────────────────────
          ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(backgroundColor: _T.brandDark, foregroundColor: Colors.white,
                elevation: 0, padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('Save Intervention', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => ViewInterventionsPage(pestData: widget.pestData, notificationsPlugin: widget.notificationsPlugin))),
            style: OutlinedButton.styleFrom(foregroundColor: _T.brandDark,
                side: const BorderSide(color: _T.borderDef, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('View All Saved Interventions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Sub-widgets ───────────────────────────────────────────────────────────

  Widget _aiAdvisorCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_T.aiGradA, _T.aiGradB], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14), border: Border.all(color: _T.brandLight, width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 18)),
          const SizedBox(width: 10),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('AI Pest Advisor', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
            Text('Powered by Gemini · No setup required', style: TextStyle(color: Colors.white70, fontSize: 11)),
          ]),
        ]),
        const SizedBox(height: 12),
        if (_aiLoading)
          const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 8),
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)))
        else if (_aiAdvice != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.10), borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.25))),
            child: Text(_aiAdvice!, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.6)),
          ),
          if (_aiSuggestions.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('SUGGESTED INTERVENTIONS', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            const SizedBox(height: 6),
            ..._aiSuggestions.map((s) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.10), borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.2))),
              child: Row(children: [
                Expanded(child: Text(
                  '${s['type']}${s['quantity'] != null ? '  ·  ${(s['quantity'] as num).toStringAsFixed(1)} ${s['unit']}' : ''}',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500))),
                GestureDetector(
                  onTap: () => _acceptSuggestion(s),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                      child: const Text('Use', style: TextStyle(fontSize: 12, color: _T.brandDark, fontWeight: FontWeight.w700))),
                ),
              ]),
            )),
          ],
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _fetchAiAdvice,
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.refresh_rounded, size: 13, color: Colors.white60), SizedBox(width: 4),
              Text('Refresh advice', style: TextStyle(color: Colors.white60, fontSize: 12,
                  decoration: TextDecoration.underline, decorationColor: Colors.white38)),
            ]),
          ),
        ] else ...[
          const Text('Get product names, quantities and timing tailored to this pest, crop and stage.',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _fetchAiAdvice,
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('Get AI pest advice', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: _T.brandDark,
                  elevation: 0, padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _costCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _T.costBg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _T.costBorder, width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.payments_outlined, size: 16, color: _T.costIcon),
          const SizedBox(width: 8),
          const Text('Cost (optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _T.costText)),
        ]),
        const SizedBox(height: 10),
        TextField(controller: _costCtrl, keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 14, color: _T.textPrimary),
            decoration: _T.field('Amount (KES)')),
        const SizedBox(height: 10),
        // Auto-category
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: _T.okBg, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _T.okBorder, width: 1.5)),
          child: Row(children: [
            const Icon(Icons.auto_awesome, size: 13, color: _T.brandMid), const SizedBox(width: 6),
            Text('Category: $_costCategory', style: const TextStyle(fontSize: 12, color: _T.brandMid)),
          ]),
        ),
        const SizedBox(height: 10),
        // Farm plot linkage
        _label('LINK TO FARM PLOT'),
        const SizedBox(height: 6),
        if (_farmPlots.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(color: _T.inputBg, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _T.borderDef, width: 1.5)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedPlotId, isExpanded: true,
                style: const TextStyle(fontSize: 13, color: _T.textPrimary),
                items: [
                  const DropdownMenuItem(value: null, child: Text('General / no specific plot')),
                  ..._farmPlots.map((p) => DropdownMenuItem(value: p['id'], child: Text(p['name'] ?? p['id']!))),
                ],
                onChanged: (v) => setState(() => _selectedPlotId = v),
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _T.infoBg, borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _T.infoBorder, width: 1.5)),
            child: const Row(children: [
              Icon(Icons.info_outline, size: 14, color: _T.infoText), SizedBox(width: 8),
              Expanded(child: Text('Add plots in Farm Management to link costs to a specific plot.',
                  style: TextStyle(fontSize: 11, color: _T.infoText))),
            ]),
          ),
        const SizedBox(height: 4),
        const Text('Cost will be linked to this farm management plot.',
            style: TextStyle(fontSize: 11, color: _T.textHint)),
        const SizedBox(height: 10),
        Row(children: [
          Switch(value: _saveToCosts, onChanged: (v) => setState(() => _saveToCosts = v),
              activeColor: _T.brandLight, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
          const SizedBox(width: 8),
          const Expanded(child: Text('Save to Farm Management costs',
              style: TextStyle(fontSize: 13, color: _T.textPrimary))),
        ]),
      ]),
    );
  }

  Widget _reminderCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: _T.card(),
      child: Column(children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Follow-up reminder',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _T.textPrimary)),
            const SizedBox(height: 2),
            Text('${_reminderDate.day}/${_reminderDate.month}/${_reminderDate.year}',
                style: const TextStyle(fontSize: 12, color: _T.textHint)),
          ])),
          Switch(value: _followUp, onChanged: (v) => setState(() => _followUp = v),
              activeColor: _T.brandLight, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
        ]),
        if (_followUp) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final p = await showDatePicker(context: context,
                  initialDate: _reminderDate, firstDate: DateTime.now(), lastDate: DateTime(2030));
              if (p != null) setState(() => _reminderDate = p);
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(color: _T.inputBg, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _T.borderDef, width: 1.5)),
              child: Row(children: [
                const Icon(Icons.calendar_today_rounded, size: 18, color: _T.textSec), const SizedBox(width: 10),
                Text('${_reminderDate.day}/${_reminderDate.month}/${_reminderDate.year}',
                    style: const TextStyle(fontSize: 14, color: _T.textPrimary)),
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _label(String t) => Text(t,
      style: const TextStyle(fontSize: 10, color: _T.textHint, fontWeight: FontWeight.w700, letterSpacing: 0.8));

  Widget _unitBtn(String val) {
    final sel = _areaUnit == val;
    return GestureDetector(
      onTap: () => setState(() => _areaUnit = val),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? _T.brandMid : _T.cardBg, borderRadius: BorderRadius.circular(8),
          border: Border.all(color: sel ? _T.brandMid : _T.borderDef, width: 1.5)),
        child: Text(val, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
            color: sel ? Colors.white : _T.textSec)),
      ),
    );
  }
}