// lib/screens/disease management/intervention_page.dart
//
// Saves to:
//   • farmer_issues/{userId}/records  (new unified collection via FarmerIssueService)
//   • diseaseinterventiondata          (legacy write kept for backward compat)
//   • field_costs                      (if cost amount > 0 and saveToCosts = true)
//   • field_reminders                  (if follow-up reminder is enabled)

// ignore_for_file: library_prefixes, curly_braces_in_flow_control_structures, deprecated_member_use

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:http/http.dart' as http;
import 'package:timezone/data/latest.dart' as tzData;
import 'package:timezone/timezone.dart' as tz;
import 'package:kilimomkononi/screens/disease%20management/disease_model.dart';
import 'package:kilimomkononi/screens/disease%20management/user_disease_history_page.dart';
import 'package:kilimomkononi/models/farmer_issue_record.dart';
import 'package:kilimomkononi/services/farmer_issue_service.dart';
import 'package:kilimomkononi/services/field_cost_bridge.dart';
import 'package:kilimomkononi/services/offline_queue_service.dart';

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

const _kAskGeminiUrl  = 'https://us-central1-kilimomkononi-e1031.cloudfunctions.net/askGeminiVision';
const _kNotifChannel  = 'disease_reminders_v2';
const _kNotifChanName = 'Disease Activity Reminders';

// ── Step-progress AppBar — shows step number, name, and progress bar ──────────
PreferredSizeWidget _diseaseStepHeader(int current, int total) {
  const stepNames = ['Select Crop, Stage & Disease', 'Disease Info & Hints', 'Intervention, Cost & Reminder'];
  final name = (current >= 1 && current <= stepNames.length) ? stepNames[current - 1] : '';
  return PreferredSize(
    preferredSize: const Size.fromHeight(kToolbarHeight + 62),
    child: AppBar(
      backgroundColor: const Color.fromARGB(255, 3, 39, 4),
      foregroundColor: Colors.white,
      elevation: 0,
      title: const Text('Disease Management',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(62),
        child: Container(
          color: const Color.fromARGB(255, 3, 39, 4),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Step $current of $total  · ',
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
              Expanded(child: Text(name,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 6),
            Row(
              children: List.generate(total, (i) => Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < total - 1 ? 4 : 0),
                  height: 4,
                  decoration: BoxDecoration(
                    color: i < current ? Colors.white : Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              )),
            ),
          ]),
        ),
      ),
    ),
  );
}

// ── Load plots: SharedPrefs first, Firestore fallback ─────────────────────────
Future<List<Map<String, String>>> _loadFarmPlotsWithFallback(String uid) async {
  // 1. SharedPreferences — written by FarmManagementScreen._writeLocalPrefs()
  final fromPrefs = await FieldCostService.loadFarmPlots(uid);
  if (fromPrefs.isNotEmpty) return fromPrefs;

  // 2. Firestore fallback — farm_management_data/{uid}/plots subcollection
  try {
    final snap = await FirebaseFirestore.instance
        .collection('farm_management_data')
        .doc(uid)
        .collection('plots')
        .get();
    if (snap.docs.isNotEmpty) {
      return snap.docs
          .map((d) => {
                'id':   d.id,
                'name': (d.data()['name'] as String?) ?? d.id,
              })
          .toList();
    }
  } catch (_) {}

  // 3. Firestore fallback — top-level farm_management_data where userId == uid
  try {
    final snap = await FirebaseFirestore.instance
        .collection('farm_management_data')
        .where('userId', isEqualTo: uid)
        .get();
    return snap.docs
        .map((d) => {
              'id':   (d.data()['plotId'] as String?) ?? d.id,
              'name': (d.data()['name'] as String?) ?? (d.data()['plotId'] as String?) ?? d.id,
            })
        .where((m) => m['id']!.isNotEmpty)
        .toList();
  } catch (_) {}

  return [];
}

class InterventionPage extends StatefulWidget {
  final DiseaseData diseaseData;
  final String cropType;
  final String cropStage;
  final FlutterLocalNotificationsPlugin notificationsPlugin;

  const InterventionPage({
    required this.diseaseData,
    required this.cropType,
    required this.cropStage,
    required this.notificationsPlugin,
    super.key,
  });

  @override
  State<InterventionPage> createState() => _InterventionPageState();
}

class _InterventionPageState extends State<InterventionPage> {
  final _interventionCtrl   = TextEditingController();
  final _dosageCtrl         = TextEditingController();
  final _unitCtrl           = TextEditingController();
  final _areaCtrl           = TextEditingController();
  final _costCtrl           = TextEditingController();
  final _customReminderCtrl = TextEditingController();
  String _areaUnit    = 'Acres';
  bool   _saveToCosts = true;
  String _costCategory = 'Pesticide / Herbicide';

  List<Map<String, String>> _farmPlots    = [];
  bool                      _plotsLoading = false;
  String?                   _selectedPlotId; // null = user must pick explicitly

  bool   _aiLoading  = false;
  Map<String, dynamic>? _aiAdviceJson;
  List<Map<String, dynamic>> _aiSuggestions = [];

  // ── Reminders — system suggested + custom (mirrors PestInterventionPage) ──
  bool     _followUp          = true;
  DateTime _reminderDate      = DateTime.now().add(const Duration(days: 7));
  bool     _addSprayReminder  = false;
  bool     _addWeedReminder   = false;
  bool     _addScoutReminder  = true;
  bool     _addCustomReminder = false;
  DateTime _sprayDate  = DateTime.now().add(const Duration(days: 14));
  DateTime _weedDate   = DateTime.now().add(const Duration(days: 7));
  DateTime _scoutDate  = DateTime.now().add(const Duration(days: 7));
  DateTime _customDate = DateTime.now().add(const Duration(days: 3));

  bool _tzReady = false;
  bool _saving  = false;

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
    for (final c in [_interventionCtrl, _dosageCtrl, _unitCtrl, _areaCtrl, _costCtrl, _customReminderCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

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
    setState(() => _plotsLoading = true);
    try {
      // Uses SharedPrefs first, then Firestore fallback — always finds real plots
      final plots = await _loadFarmPlotsWithFallback(uid);
      if (mounted) setState(() {
        _farmPlots      = plots;
        _selectedPlotId = null; // user must explicitly pick their plot
      });
    } finally {
      if (mounted) setState(() => _plotsLoading = false);
    }
  }

  // ── AI Advisor ────────────────────────────────────────────────────────────

  Future<void> _fetchAiAdvice() async {
    setState(() { _aiLoading = true; _aiAdviceJson = null; _aiSuggestions = []; });

    final prompt = '''
You are an agronomist advising smallholder farmers in Kenya and East Africa.
Respond ONLY with valid JSON — no markdown, no backticks, no extra text.

Disease: ${widget.diseaseData.name}
Crop: ${widget.cropType}  |  Stage: ${widget.cropStage}
Active agent: ${widget.diseaseData.activeAgent}
Known fungicides: ${widget.diseaseData.fungicides.join(', ')}
Known organic interventions: ${widget.diseaseData.organicInterventions.join(', ')}

Return exactly this JSON structure:
{
  "diagnosis": "2-sentence description of how this disease spreads and damages the crop at this stage.",
  "urgentAction": "The single most important thing to do today.",
  "chemicals": [
    {"product":"Ridomil Gold","activeIngredient":"Metalaxyl + Mancozeb","dosage":"2.5 g per litre","timing":"At first sign of infection","method":"Foliar spray"}
  ],
  "organics": [
    {"name":"Copper oxychloride","dosage":"3 g per litre","notes":"Apply every 7-10 days as preventive"}
  ],
  "warnings": ["Pre-harvest interval: 14 days","Do not spray in direct sun or rain","Rotate fungicide classes to prevent resistance"],
  "interventions": [
    {"type":"Spray Ridomil Gold","quantity":2.5,"unit":"g/L","category":"Pesticide / Herbicide"}
  ]
}
''';

    try {
      final resp = await http.post(Uri.parse(_kAskGeminiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'prompt': prompt}),
      ).timeout(const Duration(seconds: 35));

      if (resp.statusCode == 200) {
        final raw = (jsonDecode(resp.body)['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?) ?? '';
        final cleaned = raw.replaceAll(RegExp(r'```json|```'), '').trim();
        try {
          final j = jsonDecode(cleaned) as Map<String, dynamic>;
          final interventions = (j['interventions'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
          if (mounted) setState(() {
            _aiAdviceJson = j;
            _aiSuggestions = interventions;
            _aiLoading = false;
          });
        } catch (_) {
          if (mounted) setState(() { _aiAdviceJson = {'_raw': cleaned}; _aiLoading = false; });
        }
      } else {
        if (mounted) setState(() { _aiAdviceJson = {'_error': 'AI error (${resp.statusCode}). Try again.'}; _aiLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() {
        _aiAdviceJson = {'_error': e.toString().contains('Timeout') ? 'Request timed out.' : 'AI unavailable offline.'};
        _aiLoading = false;
      });
    }
  }

  void _acceptSuggestion(Map<String, dynamic> s) {
    setState(() {
      _interventionCtrl.text = s['type'] as String? ?? '';
      if (s['quantity'] != null) {
        _dosageCtrl.text = (s['quantity'] as num).toStringAsFixed(1);
        _unitCtrl.text   = s['unit'] as String? ?? '';
      }
      _costCategory = s['category'] as String? ?? 'Pesticide / Herbicide';
    });
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    final msg  = ScaffoldMessenger.of(context);
    if (user == null) { msg.showSnackBar(const SnackBar(content: Text('Please log in'))); return; }
    if (_interventionCtrl.text.isEmpty && _dosageCtrl.text.isEmpty &&
        _unitCtrl.text.isEmpty && _areaCtrl.text.isEmpty) {
      msg.showSnackBar(const SnackBar(content: Text('Please fill at least one field'))); return;
    }

    setState(() => _saving = true);
    final now    = Timestamp.now();
    final dosage = _dosageCtrl.text.isNotEmpty ? double.tryParse(_dosageCtrl.text) : null;

    try {
      // ── 1. New unified FarmerIssueRecord ────────────────────────────────
      final record = FarmerIssueRecord(
        userId:           user.uid,
        cycle:            'A',
        cropName:         widget.cropType,
        cropStage:        widget.cropStage,
        issueType:        'disease',
        issueName:        widget.diseaseData.name,
        source:           DiagnosisSource.manual,
        interventionText: _interventionCtrl.text.isNotEmpty ? _interventionCtrl.text : null,
        dosage:           dosage,
        dosageUnit:       _unitCtrl.text.isNotEmpty ? _unitCtrl.text : null,
        area:             _areaCtrl.text.isNotEmpty ? double.tryParse(_areaCtrl.text) : null,
        areaUnit:         _areaUnit,
        timestamp:        now,
        aiAdvice:         _aiAdviceJson != null ? jsonEncode(_aiAdviceJson) : null,
      );

      bool savedOnline = false;
      try {
        await FarmerIssueService.saveRecord(record);
        savedOnline = true;
      } catch (_) {
        await OfflineQueueService.enqueue(
          id:         'disease_${user.uid}_${now.millisecondsSinceEpoch}',
          collection: 'farmer_issue_records',
          payload:    record.toMap(),
        );
      }

      // ── 2. Legacy write ─────────────────────────────────────────────────
      if (savedOnline) {
        try {
          await FirebaseFirestore.instance.collection('diseaseinterventiondata').add({
            'diseaseName': widget.diseaseData.name, 'cropType': widget.cropType,
            'cropStage': widget.cropStage, 'cycle': 'A',
            'intervention': _interventionCtrl.text, 'dosage': dosage,
            'unit': _unitCtrl.text.isNotEmpty ? _unitCtrl.text : null,
            'area': record.area, 'areaUnit': _areaUnit,
            'timestamp': now, 'userId': user.uid, 'isDeleted': false,
            'plotId': _selectedPlotId,
          });
        } catch (_) {} // non-fatal legacy write
      } else {
        // Queue the legacy record too
        await OfflineQueueService.enqueue(
          id:         'disease_legacy_${user.uid}_${now.millisecondsSinceEpoch}',
          collection: 'diseaseinterventiondata',
          payload: {
            'diseaseName': widget.diseaseData.name, 'cropType': widget.cropType,
            'cropStage': widget.cropStage, 'cycle': 'A',
            'intervention': _interventionCtrl.text, 'dosage': dosage,
            'unit': _unitCtrl.text.isNotEmpty ? _unitCtrl.text : null,
            'area': record.area, 'areaUnit': _areaUnit,
            'timestamp': now, 'userId': user.uid, 'isDeleted': false,
            'plotId': _selectedPlotId,
          },
        );
      }

      // ── 3. Cost capture ─────────────────────────────────────────────────
      final cost = double.tryParse(_costCtrl.text) ?? 0.0;
      if (cost > 0 && _saveToCosts) {
        final entry = FieldCostEntry(
          id:              '${user.uid}_disease_${now.millisecondsSinceEpoch}',
          userId:          user.uid,
          plotId:          _selectedPlotId ?? 'unlinked',
          description:     '${_interventionCtrl.text} — ${widget.diseaseData.name} (${widget.cropType})',
          category:        _costCategory,
          amount:          cost,
          date:            now.toDate(),
          source:          'disease_management',
          interventionType:'disease',
        );
        try {
          await FieldCostService.saveFromFieldData(entry);
        } catch (_) {
          await OfflineQueueService.enqueue(
            id:         'diseasecost_${user.uid}_${now.millisecondsSinceEpoch}',
            collection: 'field_costs',
            payload:    entry.toMap(),
          );
        }
      }

      // ── 4. All reminders — scheduled locally regardless of connectivity ──
      if (_followUp) {
        await _scheduleReminder(
          id: 'disease_followup_${now.millisecondsSinceEpoch}',
          title: 'Follow-up: ${widget.diseaseData.name}',
          body: 'Evaluate treatment on ${widget.cropType}.',
          date: _reminderDate, userId: user.uid,
        );
      }
      if (_addSprayReminder) {
        await _scheduleReminder(
          id: 'disease_spray_${now.millisecondsSinceEpoch}',
          title: 'Re-spray — ${widget.cropType}',
          body: 'Time to re-apply ${_interventionCtrl.text} for ${widget.diseaseData.name}.',
          date: _sprayDate, userId: user.uid,
        );
      }
      if (_addWeedReminder) {
        await _scheduleReminder(
          id: 'disease_weed_${now.millisecondsSinceEpoch}',
          title: 'Weeding — ${widget.cropType}',
          body: 'Weeds harbour disease — time to weed your plot.',
          date: _weedDate, userId: user.uid,
        );
      }
      if (_addScoutReminder) {
        await _scheduleReminder(
          id: 'disease_scout_${now.millisecondsSinceEpoch}',
          title: 'Scouting — ${widget.cropType}',
          body: 'Check for ${widget.diseaseData.name} signs. Early detection saves crops.',
          date: _scoutDate, userId: user.uid,
        );
      }
      if (_addCustomReminder && _customReminderCtrl.text.isNotEmpty) {
        await _scheduleReminder(
          id: 'disease_custom_${now.millisecondsSinceEpoch}',
          title: 'Custom reminder — ${widget.cropType}',
          body: _customReminderCtrl.text,
          date: _customDate, userId: user.uid,
        );
      }

      if (mounted) {
        _reset();
        msg.showSnackBar(SnackBar(
          backgroundColor: _T.brandLight, behavior: SnackBarBehavior.floating,
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 16), const SizedBox(width: 8),
            Text(
              savedOnline
                  ? 'Intervention saved'
                  : 'Saved offline — syncs when connected',
              style: const TextStyle(color: Colors.white),
            ),
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
      for (final c in [_interventionCtrl, _dosageCtrl, _unitCtrl, _areaCtrl, _costCtrl, _customReminderCtrl]) c.clear();
      _areaUnit = 'Acres'; _saveToCosts = true; _costCategory = 'Pesticide / Herbicide';
      _followUp = true; _reminderDate = DateTime.now().add(const Duration(days: 7));
      _addSprayReminder = false; _sprayDate = DateTime.now().add(const Duration(days: 14));
      _addWeedReminder  = false; _weedDate  = DateTime.now().add(const Duration(days: 7));
      _addScoutReminder = true;  _scoutDate = DateTime.now().add(const Duration(days: 7));
      _addCustomReminder = false; _customDate = DateTime.now().add(const Duration(days: 3));
      _aiAdviceJson = null; _aiSuggestions = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.pageBg,
      appBar: _diseaseStepHeader(3, 3),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Context ────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: _T.card(border: _T.okBorder),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.local_hospital_outlined, size: 16, color: _T.brandMid),
                const SizedBox(width: 6),
                Expanded(child: Text(widget.diseaseData.name,
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
          _label('INTERVENTION USED'),
          const SizedBox(height: 6),
          TextField(controller: _interventionCtrl, style: const TextStyle(fontSize: 14, color: _T.textPrimary),
              decoration: _T.field('Intervention used', hint: 'e.g. Spray Ridomil Gold')),
          const SizedBox(height: 14),

          _label('DOSAGE'),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(flex: 2, child: TextField(controller: _dosageCtrl, keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 14, color: _T.textPrimary),
                decoration: _T.field('Dosage'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _unitCtrl,
                style: const TextStyle(fontSize: 14, color: _T.textPrimary),
                decoration: _T.field('Unit', hint: 'g/L'))),
          ]),
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
                builder: (_) => const UserDiseaseHistoryPage())),
            style: OutlinedButton.styleFrom(foregroundColor: _T.brandDark,
                side: const BorderSide(color: _T.borderDef, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('View Intervention History',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Sub-widgets ───────────────────────────────────────────────────────────

  Widget _aiAdvisorCard() {
    final hasResults = _aiAdviceJson != null && !_aiLoading;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Dark green header row ────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_T.aiGradA, _T.aiGradB],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.vertical(
            top: const Radius.circular(14),
            bottom: hasResults ? Radius.zero : const Radius.circular(14),
          ),
          border: Border.all(color: _T.brandLight, width: 1.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('AI Disease Advisor', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              Text('Powered by Gemini · Triple-check on product labels',
                  style: TextStyle(color: Colors.white70, fontSize: 11)),
            ]),
          ]),
          if (!hasResults && !_aiLoading) ...[
            const SizedBox(height: 12),
            const Text('Get fungicide names, dosages and timing for this exact disease, crop and stage.',
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _fetchAiAdvice,
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('Get AI Disease Advice', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white, foregroundColor: _T.brandDark,
                  elevation: 0, padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              )),
          ],
          if (_aiLoading) ...[
            const SizedBox(height: 12),
            const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
            const SizedBox(height: 8),
          ],
        ]),
      ),

      // ── Results on light background so coloured cards pop ────────────────
      if (hasResults)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F6F3),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
            border: Border.all(color: _T.brandLight, width: 1.5),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildAiJsonCards(_aiAdviceJson!),

            // Tap-to-fill suggestions
            if (_aiSuggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('TAP TO FILL FORM',
                  style: TextStyle(fontSize: 10, color: _T.textHint,
                      fontWeight: FontWeight.w700, letterSpacing: 0.8)),
              const SizedBox(height: 6),
              ..._aiSuggestions.map((s) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _T.borderDef, width: 1.5),
                ),
                child: Row(children: [
                  const Icon(Icons.science_outlined, size: 16, color: _T.brandMid),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    '${s['type']}${s['quantity'] != null ? '  ·  ${(s['quantity'] as num).toStringAsFixed(1)} ${s['unit']}' : ''}',
                    style: const TextStyle(color: _T.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                  )),
                  GestureDetector(
                    onTap: () => _acceptSuggestion(s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(color: _T.brandDark, borderRadius: BorderRadius.circular(8)),
                      child: const Text('Use', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700)),
                    )),
                ]),
              )),
            ],

            const SizedBox(height: 4),
            GestureDetector(
              onTap: _fetchAiAdvice,
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.refresh_rounded, size: 13, color: _T.textHint),
                SizedBox(width: 4),
                Text('Refresh advice', style: TextStyle(color: _T.textHint, fontSize: 12,
                    decoration: TextDecoration.underline, decorationColor: _T.borderDef)),
              ]),
            ),
          ]),
        ),
    ]);
  }

  Widget _costCard() {
    final plotName = _selectedPlotId != null
        ? (_farmPlots.where((p) => p['id'] == _selectedPlotId).firstOrNull?['name'] ?? _selectedPlotId!)
        : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _T.costBg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _T.costBorder, width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.payments_outlined, size: 16, color: _T.costIcon), SizedBox(width: 8),
          Text('Cost (optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _T.costText)),
        ]),
        const SizedBox(height: 10),
        // Amount field
        TextField(controller: _costCtrl, keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 14, color: _T.textPrimary),
            decoration: _T.field('Amount (KES)')),
        const SizedBox(height: 10),
        // Auto-category chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: _T.okBg, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _T.okBorder, width: 1.5)),
          child: Row(children: [
            const Icon(Icons.auto_awesome, size: 13, color: _T.brandMid), const SizedBox(width: 6),
            Text('Category: $_costCategory', style: const TextStyle(fontSize: 12, color: _T.brandMid)),
          ]),
        ),
        const SizedBox(height: 14),

        // Plot selector
        _label('LINK TO FARM PLOT'),
        const SizedBox(height: 6),
        if (_plotsLoading)
          const Center(child: SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2)))
        else if (_farmPlots.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(color: _T.inputBg, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _T.borderDef, width: 1.5)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedPlotId, isExpanded: true,
                style: const TextStyle(fontSize: 13, color: _T.textPrimary),
                hint: const Text('Select a farm plot',
                    style: TextStyle(fontSize: 13, color: _T.textHint)),
                items: [
                  const DropdownMenuItem(value: null, child: Text('General / no specific plot')),
                  ..._farmPlots.map((p) => DropdownMenuItem(
                      value: p['id'], child: Text(p['name'] ?? p['id']!))),
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
              Expanded(child: Text(
                  'Open Farm Management once to register your plots, then they will appear here.',
                  style: TextStyle(fontSize: 11, color: _T.infoText))),
            ]),
          ),

        // ── Confirmation: where cost will be saved ──────────────────────────
        const SizedBox(height: 8),
        if (plotName != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _T.okBg, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _T.okBorder, width: 1.5),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle_outline, size: 14, color: _T.brandMid),
              const SizedBox(width: 6),
              Expanded(child: Text('Saving cost to: $plotName',
                  style: const TextStyle(fontSize: 12, color: _T.brandMid, fontWeight: FontWeight.w600))),
            ]),
          )
        else
          const Text('No plot selected — cost will not be linked to a specific plot.',
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
      padding: const EdgeInsets.all(14),
      decoration: _T.card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Reminders', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _T.textPrimary)),
        const SizedBox(height: 4),
        const Text('System-suggested and custom reminders for follow-up activities.',
            style: TextStyle(fontSize: 11, color: _T.textHint, height: 1.4)),
        const SizedBox(height: 14),

        // Follow-up check
        _remRow('Follow-up check',
            'Evaluate treatment effectiveness',
            _followUp, (v) => setState(() => _followUp = v),
            _reminderDate, (d) => setState(() => _reminderDate = d)),
        const Divider(height: 20),

        // System suggestions
        const Text('SUGGESTED FOR THIS DISEASE', style: TextStyle(
            fontSize: 10, color: _T.textHint, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
        const SizedBox(height: 10),

        _remRow('Re-spray in 2 weeks',
            'Most fungicides require repeat application to break the cycle',
            _addSprayReminder, (v) => setState(() => _addSprayReminder = v),
            _sprayDate, (d) => setState(() => _sprayDate = d)),
        const SizedBox(height: 8),
        _remRow('Weed your plot',
            'Weeds harbour disease spores and reduce air circulation',
            _addWeedReminder, (v) => setState(() => _addWeedReminder = v),
            _weedDate, (d) => setState(() => _weedDate = d)),
        const SizedBox(height: 8),
        _remRow('Field scouting check',
            'Monitor for disease re-emergence — early detection is key',
            _addScoutReminder, (v) => setState(() => _addScoutReminder = v),
            _scoutDate, (d) => setState(() => _scoutDate = d)),
        const Divider(height: 20),

        // Custom reminder
        const Text('CUSTOM REMINDER', style: TextStyle(
            fontSize: 10, color: _T.textHint, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
        const SizedBox(height: 8),
        Row(children: [
          Switch(value: _addCustomReminder, onChanged: (v) => setState(() => _addCustomReminder = v),
              activeColor: _T.brandLight, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
          const SizedBox(width: 8),
          const Expanded(child: Text('Add custom reminder',
              style: TextStyle(fontSize: 13, color: _T.textPrimary))),
        ]),
        if (_addCustomReminder) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _customReminderCtrl,
            style: const TextStyle(fontSize: 14, color: _T.textPrimary),
            decoration: _T.field('Reminder message',
                hint: 'e.g., Apply second dose of Ridomil'),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final p = await showDatePicker(context: context,
                  initialDate: _customDate, firstDate: DateTime.now(), lastDate: DateTime(2030));
              if (p != null) setState(() => _customDate = p);
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(color: _T.inputBg, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _T.borderDef, width: 1.5)),
              child: Row(children: [
                const Icon(Icons.calendar_today_rounded, size: 18, color: _T.textSec),
                const SizedBox(width: 10),
                Text('${_customDate.day}/${_customDate.month}/${_customDate.year}',
                    style: const TextStyle(fontSize: 14, color: _T.textPrimary)),
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  // Row for a single reminder toggle with date picker
  Widget _remRow(String title, String sub, bool val,
      ValueChanged<bool> onToggle, DateTime date, ValueChanged<DateTime> onDate) {
    return Row(children: [
      Expanded(child: InkWell(
        onTap: val ? () async {
          final p = await showDatePicker(context: context,
              initialDate: date, firstDate: DateTime.now(), lastDate: DateTime(2030));
          if (p != null) onDate(p);
        } : null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
              color: val ? _T.textPrimary : Colors.grey.shade400)),
          const SizedBox(height: 2),
          Text(val ? '${date.day}/${date.month}/${date.year}  ·  $sub' : sub,
              style: TextStyle(fontSize: 11,
                  color: val ? _T.textHint : Colors.grey.shade400)),
        ]),
      )),
      Switch(value: val, onChanged: onToggle,
          activeColor: _T.brandLight, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
    ]);
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

  // ── AI advice card renderer — structured JSON → beautiful coloured cards ──
  // No **, no numbered lists, no raw markdown. Each section in its own card.

  Widget _buildAiJsonCards(Map<String, dynamic> j) {
    if (j.containsKey('_error')) {
      return _aiCardBlock(Colors.red.shade800, Colors.red.shade100,
          Icons.error_outline, 'Error', j['_error'] as String);
    }
    if (j.containsKey('_raw')) {
      final clean = (j['_raw'] as String)
          .replaceAll(RegExp(r'\*+'), '').replaceAll(RegExp(r'#+\s*'), '').trim();
      return _aiCardBlock(const Color(0xFF1B5E20), const Color(0xFFE8F5E9),
          Icons.info_outline, 'AI Advice', clean);
    }
    final cards = <Widget>[];

    final diagnosis = j['diagnosis'] as String? ?? '';
    if (diagnosis.isNotEmpty) {
      cards.add(_aiCardBlock(const Color(0xFF0D47A1), const Color(0xFFE3F2FD),
          Icons.biotech_outlined, 'What This Disease Does', diagnosis));
    }

    final urgent = j['urgentAction'] as String? ?? '';
    if (urgent.isNotEmpty) {
      cards.add(_aiCardBlock(const Color(0xFFBF360C), const Color(0xFFFBE9E7),
          Icons.bolt, 'Most Urgent Action', urgent));
    }

    final chemicals = (j['chemicals'] as List<dynamic>?) ?? [];
    if (chemicals.isNotEmpty) cards.add(_aiChemicalBlock(chemicals));

    final organics = (j['organics'] as List<dynamic>?) ?? [];
    if (organics.isNotEmpty) cards.add(_aiOrganicBlock(organics));

    final warnings = (j['warnings'] as List<dynamic>?) ?? [];
    if (warnings.isNotEmpty) cards.add(_aiWarningsBlock(warnings));

    if (cards.isEmpty) {
      cards.add(_aiCardBlock(const Color(0xFF1B5E20), const Color(0xFFE8F5E9),
          Icons.info_outline, 'AI Advice', 'No structured advice returned. Try again.'));
    }
    return Column(children: cards);
  }

  Widget _aiCardBlock(Color hdr, Color bg, IconData icon, String title, String body) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hdr.withOpacity(0.35), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: hdr, borderRadius: const BorderRadius.vertical(top: Radius.circular(11))),
          child: Row(children: [
            Icon(icon, color: Colors.white, size: 15),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(body, style: TextStyle(fontSize: 13, color: hdr.withOpacity(0.85), height: 1.6)),
        ),
      ]),
    );
  }

  Widget _aiChemicalBlock(List<dynamic> chemicals) {
    const hdr = Color(0xFF4A148C);
    const bg  = Color(0xFFF3E5F5);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hdr.withOpacity(0.35), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: const BoxDecoration(
            color: hdr, borderRadius: BorderRadius.vertical(top: Radius.circular(11))),
          child: const Row(children: [
            Icon(Icons.science_outlined, color: Colors.white, size: 15),
            SizedBox(width: 8),
            Text('Fungicide / Chemical Interventions',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
        ),
        ...chemicals.asMap().entries.map((e) {
          final c = e.value as Map<String, dynamic>;
          return Container(
            margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: hdr.withOpacity(0.2)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Option ${e.key + 1}: ${c['product'] ?? ''}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: hdr)),
              const SizedBox(height: 4),
              _fieldLine('Active Ingredient', c['activeIngredient']),
              _fieldLine('Dosage',    c['dosage']),
              _fieldLine('Timing',    c['timing']),
              _fieldLine('Method',    c['method']),
            ]),
          );
        }),
        const SizedBox(height: 10),
      ]),
    );
  }

  Widget _aiOrganicBlock(List<dynamic> organics) {
    const hdr = Color(0xFF1B5E20);
    const bg  = Color(0xFFE8F5E9);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hdr.withOpacity(0.35), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: const BoxDecoration(
            color: hdr, borderRadius: BorderRadius.vertical(top: Radius.circular(11))),
          child: const Row(children: [
            Icon(Icons.eco_outlined, color: Colors.white, size: 15),
            SizedBox(width: 8),
            Text('Organic Alternatives',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
        ),
        ...organics.asMap().entries.map((e) {
          final o = e.value as Map<String, dynamic>;
          return Container(
            margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: hdr.withOpacity(0.2)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Option ${e.key + 1}: ${o['name'] ?? ''}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: hdr)),
              const SizedBox(height: 4),
              _fieldLine('Dosage', o['dosage']),
              _fieldLine('Notes',  o['notes']),
            ]),
          );
        }),
        const SizedBox(height: 10),
      ]),
    );
  }

  Widget _aiWarningsBlock(List<dynamic> warnings) {
    const hdr = Color(0xFFE65100);
    const bg  = Color(0xFFFFF3E0);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hdr.withOpacity(0.35), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: const BoxDecoration(
            color: hdr, borderRadius: BorderRadius.vertical(top: Radius.circular(11))),
          child: const Row(children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white, size: 15),
            SizedBox(width: 8),
            Text('Safety Warnings',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: warnings.map((w) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.circle, size: 6, color: hdr),
                const SizedBox(width: 8),
                Expanded(child: Text(w as String,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF7A4F00), height: 1.5))),
              ]),
            )).toList()),
        ),
      ]),
    );
  }

  Widget _fieldLine(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: RichText(text: TextSpan(
        style: const TextStyle(fontSize: 12, height: 1.5),
        children: [
          TextSpan(text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
          TextSpan(text: value,
              style: const TextStyle(color: Colors.black54)),
        ],
      )),
    );
  }
}