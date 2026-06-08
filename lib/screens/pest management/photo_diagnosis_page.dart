// lib/screens/pest_management/photo_diagnosis_page.dart
//
// v3 FIXES:
//  • Web-safe: Uint8List + Image.memory everywhere — no dart:io File
//  • Plot loading from FieldCostService.loadFarmPlots (SharedPreferences)
//    — same key FarmManagementScreen writes, real plots appear immediately
//  • Cost saved to field_costs via FieldCostService (source: pest/disease_management)
//  • Plot + cost in one amber card matching intervention_page.dart exactly
//  • Stepper layout — sections don't pile up on one long page

// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kilimomkononi/education/pest/gemini_vision_helper.dart';
import 'package:kilimomkononi/services/field_cost_bridge.dart';

class PhotoDiagnosisPage extends StatefulWidget {
  final String? issueType; // 'pest' or 'disease' (optional hint)
  const PhotoDiagnosisPage({super.key, this.issueType});

  @override
  State<PhotoDiagnosisPage> createState() => _PhotoDiagnosisPageState();
}

class _PhotoDiagnosisPageState extends State<PhotoDiagnosisPage> {
  static const _dark  = Color.fromARGB(255, 3, 39, 4);
  static const _accent = Color(0xFF2A6B2A);
  static const _light  = Color(0xFFE8F5E9);
  static const _bg     = Color(0xFFF4F6F3);

  // ── Stepper ───────────────────────────────────────────────────────────────
  int _step = 0;

  // ── Crop / Stage selection ─────────────────────────────────────────────────
  String? _selectedCrop;
  String? _selectedStage;

  // ── Photo — Uint8List everywhere (web + mobile, no dart:io) ──────────────
  Uint8List? _photoBytes;
  bool _analyzing = false;

  // ── AI result ─────────────────────────────────────────────────────────────
  GeminiDiagResult? _result;

  // ── Farm plots — from SharedPreferences (${uid}_v2_plots) ─────────────────
  List<Map<String, String>> _farmPlots = [];
  bool _loadingPlots = false;
  String? _selectedPlotId;

  // ── Intervention & cost ────────────────────────────────────────────────────
  String? _intervention;
  double? _dosage;
  String? _unit;
  double? _area;
  String  _areaUnit     = 'Acres';
  double  _costAmount   = 0.0;
  bool    _saveToCosts  = true;
  String  _costCategory = 'Pesticide / Herbicide';
  bool    _saving       = false;

  final _interventionCtrl = TextEditingController();
  final _dosageCtrl       = TextEditingController();
  final _unitCtrl         = TextEditingController();
  final _areaCtrl         = TextEditingController();
  final _costCtrl         = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  final List<String> _crops = ['Beans','Maize','Cabbages/Kales','Carrots','Tomatoes','Onions','Irish Potatoes'];
  final Map<String, List<String>> _cropStages = {
    'Beans':          ['Germination/Seedling','Vegetative Growth/Weeding','Flowering/Reproductive','Maturation/Harvesting','Storage'],
    'Maize':          ['Germination/Seedling','Vegetative Growth/Weeding','Flowering/Reproductive','Maturation/Harvesting','Storage'],
    'Cabbages/Kales': ['Germination/Seedling','Vegetative Growth/Weeding','Flowering/Reproductive','Maturation/Harvesting','Storage'],
    'Carrots':        ['Germination/Seedling','Vegetative Growth/Weeding','Maturation/Harvesting','Storage'],
    'Tomatoes':       ['Germination/Seedling','Vegetative Growth/Weeding','Flowering/Reproductive','Maturation/Harvesting','Storage'],
    'Onions':         ['Germination/Seedling','Vegetative Growth/Weeding','Bulb Formation/Reproductive','Bulbing/Maturation','Harvesting/Storage'],
    'Irish Potatoes': ['Early Growth','Tuber Initiation','Tuber Bulking','Maturation/Harvesting'],
  };

  @override
  void initState() {
    super.initState();
    _loadFarmPlots();
  }

  @override
  void dispose() {
    _interventionCtrl.dispose();
    _dosageCtrl.dispose();
    _unitCtrl.dispose();
    _areaCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  // ── Load plots from SharedPreferences — exact same key FarmManagement writes ──

  Future<void> _loadFarmPlots() async {
    setState(() => _loadingPlots = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final plots = await FieldCostService.loadFarmPlots(uid);
        if (mounted) setState(() {
          _farmPlots      = plots;
          _selectedPlotId = plots.isNotEmpty ? plots.first['id'] : null;
        });
      }
    } finally {
      if (mounted) setState(() => _loadingPlots = false);
    }
  }

  String _inferCat(String t) => inferCostCategory(t);

  // ── Photo picker — Uint8List (web + mobile, no dart:io) ──────────────────

  Future<void> _pick(ImageSource src) async {
    final xf = await _picker.pickImage(source: src, imageQuality: 82, maxWidth: 1200);
    if (xf == null) return;
    final bytes = await xf.readAsBytes();
    setState(() {
      _photoBytes = bytes;
      _result     = null;
      _step       = 1;
    });
  }

  // ── Gemini Vision diagnosis ───────────────────────────────────────────────

  Future<void> _analyze() async {
    if (_photoBytes == null || _selectedCrop == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a crop and upload a photo first')));
      return;
    }
    setState(() { _analyzing = true; _result = null; });
    try {
      final r = await runGeminiVisionDiagnosis(imageBytes: _photoBytes!, crop: _selectedCrop!);
      if (mounted) setState(() { _result = r; _step = _result!.isRejected ? 1 : 2; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  // ── Save record + cost ────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_result == null || _intervention == null || _intervention!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please run diagnosis and enter what you applied')));
      return;
    }
    setState(() => _saving = true);
    try {
      final uid    = FirebaseAuth.instance.currentUser!.uid;
      final now    = Timestamp.now();
      final isDisease = _result!.type == 'disease';
      final plotName  = _selectedPlotId != null
          ? (_farmPlots.where((p) => p['id'] == _selectedPlotId).firstOrNull?['name'] ?? _selectedPlotId!)
          : 'General';

      // 1. Save diagnosis record to farmer_diagnoses (keeps existing AI history)
      await FirebaseFirestore.instance.collection('farmer_diagnoses').doc(uid).collection('records').add({
        'userId':       uid,
        'plotId':       _selectedPlotId,
        'issueName':    _result!.name,
        'issueType':    _result!.type,
        'cropName':     _selectedCrop,
        'cropStage':    _selectedStage,
        'interventionText': _intervention,
        'dosage':       _dosage,
        'dosageUnit':   _unit,
        'area':         _area,
        'areaUnit':     _areaUnit,
        'confidence':   _result!.confidence,
        'description':  _result!.description,
        'recommendation': _result!.recommendation,
        'timestamp':    now,
        'source':       'photo_diagnosis',
        'isDeleted':    false,
      });

      // 2. Save cost to field_costs (appears in Farm Management › Costs)
      if (_costAmount > 0 && _saveToCosts) {
        final entry = FieldCostEntry(
          id:              '${uid}_photo_${now.millisecondsSinceEpoch}',
          userId:          uid,
          plotId:          _selectedPlotId ?? 'general',
          description:     '$_intervention — ${_result!.name} on ${_selectedCrop ?? ''} ($plotName)',
          category:        _costCategory,
          amount:          _costAmount,
          date:            now.toDate(),
          source:          isDisease ? 'disease_management' : 'pest_management',
          interventionType: _result!.type,
        );
        await FieldCostService.saveFromFieldData(entry);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(_costAmount > 0 && _saveToCosts
                ? 'Saved ✓  KES ${_costAmount.toStringAsFixed(0)} linked to $plotName'
                : 'Diagnosis saved ✓',
              style: const TextStyle(color: Colors.white)),
          ]),
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _dark, foregroundColor: Colors.white, elevation: 0,
        title: const Text('AI Photo Diagnosis', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Container(
            color: _dark, padding: const EdgeInsets.only(left: 16, bottom: 10),
            alignment: Alignment.centerLeft,
            child: Text(_progressText(), style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _tile(0, 'Select Crop & Stage',   _s0()),
          _tile(1, 'Upload & Diagnose',      _s1()),
          if (_result != null && !_result!.isRejected && !_result!.isHealthy)
            _tile(2, 'Log Intervention & Cost', _s2()),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  String _progressText() {
    if (_selectedCrop == null) return 'Step 1 of 3 — Select crop';
    if (_photoBytes == null)   return 'Step 2 of 3 — Upload photo';
    if (_result == null)       return 'Step 2 of 3 — Ready to diagnose';
    return _result!.isRejected ? 'Photo not suitable — try again' : 'Step 3 of 3 — Log what you applied';
  }

  // ── Stepper tile ──────────────────────────────────────────────────────────

  Widget _tile(int s, String title, Widget content) {
    final isActive   = _step == s;
    final isComplete = _step > s;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTap: () => setState(() => _step = s),
        child: Container(
          margin: EdgeInsets.only(bottom: isActive ? 0 : 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : const Color(0xFFF7F8F6),
            borderRadius: isActive ? const BorderRadius.vertical(top: Radius.circular(12)) : BorderRadius.circular(12),
            border: Border.all(color: isActive ? _accent : (isComplete ? const Color(0xFFA5D6A7) : Colors.grey.shade300), width: isActive ? 2 : 1.5),
          ),
          child: Row(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(color: isComplete ? _accent : (isActive ? _dark : Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
              child: Center(child: isComplete ? const Icon(Icons.check, color: Colors.white, size: 16) : Text('${s + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: TextStyle(fontSize: 14, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500, color: isActive ? _dark : Colors.black54))),
            Icon(isActive ? Icons.expand_less : Icons.expand_more, color: Colors.grey.shade400, size: 20),
          ]),
        ),
      ),
      if (isActive) Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
          border: Border.all(color: _accent, width: 2),
        ),
        child: content,
      ),
    ]);
  }

  // ── Step 0: Crop & Stage ──────────────────────────────────────────────────

  Widget _s0() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _lbl('Select Crop'),
    const SizedBox(height: 10),
    Wrap(spacing: 8, runSpacing: 8,
      children: _crops.map((c) => _chip(c, c == _selectedCrop, () {
        setState(() { _selectedCrop = _selectedCrop == c ? null : c; _selectedStage = null; });
      })).toList(),
    ),
    if (_selectedCrop != null) ...[
      const SizedBox(height: 16),
      _lbl('Select Growth Stage'),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8,
        children: (_cropStages[_selectedCrop] ?? []).map((s) => _chip(s, s == _selectedStage, () {
          setState(() => _selectedStage = _selectedStage == s ? null : s);
        })).toList(),
      ),
    ],
    const SizedBox(height: 16),
    _nextBtn('Next: Upload Photo', enabled: _selectedCrop != null, onTap: () => setState(() => _step = 1)),
  ]);

  // ── Step 1: Photo upload + AI diagnosis ───────────────────────────────────

  Widget _s1() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (_photoBytes != null) ...[
      // Image preview — Image.memory (web-safe, no Image.file)
      Stack(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(_photoBytes!, width: double.infinity, height: 220, fit: BoxFit.cover),
        ),
        Positioned(top: 8, right: 8,
          child: GestureDetector(
            onTap: () => setState(() { _photoBytes = null; _result = null; }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.refresh, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text('Change', style: TextStyle(color: Colors.white, fontSize: 12)),
              ]),
            ),
          ),
        ),
      ]),
      const SizedBox(height: 14),
    ],

    // Upload buttons
    Row(children: [
      Expanded(child: ElevatedButton.icon(
        onPressed: () => _pick(ImageSource.camera),
        icon: const Icon(Icons.camera_alt, size: 18),
        label: const Text('Camera'),
        style: ElevatedButton.styleFrom(backgroundColor: _dark, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13)),
      )),
      const SizedBox(width: 10),
      Expanded(child: OutlinedButton.icon(
        onPressed: () => _pick(ImageSource.gallery),
        icon: const Icon(Icons.image, size: 18),
        label: const Text('Gallery'),
        style: OutlinedButton.styleFrom(foregroundColor: _accent, side: const BorderSide(color: _accent), padding: const EdgeInsets.symmetric(vertical: 13)),
      )),
    ]),
    const SizedBox(height: 14),

    // Diagnose button
    SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: (_photoBytes != null && _selectedCrop != null && !_analyzing) ? _analyze : null,
        icon: _analyzing
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.search_rounded),
        label: Text(_analyzing ? 'Analysing…' : 'Diagnose with AI'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE65100), foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    ),

    // AI result
    if (_result != null) ...[
      const SizedBox(height: 16),
      _resultCard(),
    ],
  ]);

  Widget _resultCard() {
    final r = _result!;

    if (r.isRejected) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFFFF3CD), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE6A817), width: 1.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFB97000)),
            SizedBox(width: 8),
            Text('Image not suitable', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
          const SizedBox(height: 8),
          Text(r.rejectionReason, style: const TextStyle(fontSize: 13, height: 1.5)),
        ]),
      );
    }

    if (r.isHealthy) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _light, borderRadius: BorderRadius.circular(10)),
        child: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Color(0xFF1B5E20), size: 28),
          SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Healthy Plant', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
            SizedBox(height: 4),
            Text('No pest or disease damage detected. Continue monitoring.', style: TextStyle(fontSize: 13)),
          ])),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _light, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(r.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: r.confColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: r.confColor.withOpacity(0.4))),
            child: Text(r.confidence.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: r.confColor)),
          ),
        ]),
        const SizedBox(height: 4),
        Text(r.confLabel, style: TextStyle(fontSize: 11, color: r.confColor)),
        if (r.imageSubject.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Observed: ${r.imageSubject}', style: const TextStyle(fontSize: 12, color: Colors.black54, fontStyle: FontStyle.italic)),
        ],
        if (r.description.isNotEmpty) ...[const SizedBox(height: 12), _hint('Why this happened', r.description, Icons.info_outline)],
        if (r.recommendation.isNotEmpty) ...[const SizedBox(height: 8), _hint('What to do now', r.recommendation, Icons.healing_rounded)],
        if (r.alternatives.isNotEmpty) ...[const SizedBox(height: 8), _hint('Alternative diagnosis', r.alternatives.join('\n• '), Icons.help_outline)],
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber.shade300)),
          child: const Row(children: [
            Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFB97000)),
            SizedBox(width: 6),
            Expanded(child: Text('AI results are a guide — always triple-check dosages on product labels before applying.', style: TextStyle(fontSize: 11, color: Color(0xFF7A4F00), height: 1.4))),
          ]),
        ),
        if (!r.isRejected && !r.isHealthy) ...[
          const SizedBox(height: 12),
          _nextBtn('Next: Log Intervention & Cost', onTap: () => setState(() => _step = 2)),
        ],
      ]),
    );
  }

  Widget _hint(String title, String body, IconData icon) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, color: _accent, size: 16), const SizedBox(width: 6), Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1B5E20)))]),
      const SizedBox(height: 5),
      Text(body, style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.5)),
    ]),
  );

  // ── Step 2: Intervention + Plot + Cost ────────────────────────────────────

  Widget _s2() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _lbl('Intervention Applied'),
    const SizedBox(height: 8),
    TextField(
      controller: _interventionCtrl,
      onChanged: (v) => setState(() { _intervention = v; if (v.isNotEmpty) _costCategory = _inferCat(v); }),
      decoration: InputDecoration(hintText: 'e.g., Spray Ridomil 2.5g/L', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
    ),
    const SizedBox(height: 14),

    _lbl('Dosage (Optional)'),
    const SizedBox(height: 8),
    Row(children: [
      Expanded(child: TextField(controller: _dosageCtrl, keyboardType: TextInputType.number, onChanged: (v) => setState(() => _dosage = double.tryParse(v)), decoration: InputDecoration(hintText: 'Amount', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)))),
      const SizedBox(width: 8),
      Expanded(child: TextField(controller: _unitCtrl, onChanged: (v) => setState(() => _unit = v), decoration: InputDecoration(hintText: 'Unit', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)))),
    ]),
    const SizedBox(height: 14),

    _lbl('Area Treated (Optional)'),
    const SizedBox(height: 8),
    Row(children: [
      Expanded(child: TextField(controller: _areaCtrl, keyboardType: TextInputType.number, onChanged: (v) => setState(() => _area = double.tryParse(v)), decoration: InputDecoration(hintText: 'Area', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)))),
      const SizedBox(width: 8),
      Expanded(child: DropdownButtonFormField<String>(
        value: _areaUnit,
        items: const [DropdownMenuItem(value: 'Acres', child: Text('Acres')), DropdownMenuItem(value: 'SQM', child: Text('SQM'))],
        onChanged: (v) => setState(() => _areaUnit = v ?? 'Acres'),
        decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
      )),
    ]),
    const SizedBox(height: 16),

    // ── Plot + Cost card (matching intervention_page.dart exactly) ─────────
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFFFF3CD), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE6A817), width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.payments_outlined, size: 16, color: Color(0xFFB97000)),
          SizedBox(width: 8),
          Text('Cost & Farm Plot (optional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF7A4F00))),
        ]),
        const SizedBox(height: 14),
        const Text('WHICH FARM PLOT?', style: TextStyle(fontSize: 11, color: Colors.black45, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
        const SizedBox(height: 6),
        if (_loadingPlots)
          const Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)))
        else if (_farmPlots.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFECEEEB), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFBBBFBA), width: 1.5)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedPlotId,
                isExpanded: true,
                style: const TextStyle(fontSize: 14, color: Color(0xFF111A10)),
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
            decoration: BoxDecoration(color: const Color(0xFFDCEEFB), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF90CAF9), width: 1.5)),
            child: const Row(children: [
              Icon(Icons.info_outline, size: 14, color: Color(0xFF1565C0)),
              SizedBox(width: 8),
              Expanded(child: Text('No plots found. Add plots in Farm Management, then re-open this screen.', style: TextStyle(fontSize: 11, color: Color(0xFF1565C0)))),
            ]),
          ),
        const SizedBox(height: 4),
        const Text('Cost will be linked to this plot in Farm Management.', style: TextStyle(fontSize: 11, color: Colors.black45)),
        const SizedBox(height: 14),
        TextField(
          controller: _costCtrl,
          keyboardType: TextInputType.number,
          onChanged: (v) => setState(() => _costAmount = double.tryParse(v) ?? 0),
          decoration: InputDecoration(
            labelText: 'Amount spent (KES)', prefixText: 'KES ',
            helperText: 'Will appear under the selected plot in Farm Management',
            filled: true, fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE6A817))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE6A817))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: _light, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFA5D6A7), width: 1.5)),
          child: Row(children: [
            const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF2A6B2A)),
            const SizedBox(width: 6),
            Text('Category: $_costCategory', style: const TextStyle(fontSize: 12, color: Color(0xFF1B5E20))),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Switch(value: _saveToCosts, onChanged: (v) => setState(() => _saveToCosts = v), activeColor: _accent, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
          const SizedBox(width: 8),
          const Expanded(child: Text('Save to Farm Management costs', style: TextStyle(fontSize: 13, color: Color(0xFF111A10)))),
        ]),
      ]),
    ),
    const SizedBox(height: 20),

    SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (_intervention != null && _intervention!.isNotEmpty && !_saving) ? _save : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _dark, foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: _saving
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white), strokeWidth: 2))
            : const Text('Save Diagnosis & Intervention', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      ),
    ),
  ]);

  // ── Shared helpers ─────────────────────────────────────────────────────────

  Widget _chip(String label, bool sel, VoidCallback onTap) => FilterChip(
    label: Text(label), selected: sel, onSelected: (_) => onTap(),
    backgroundColor: Colors.white, selectedColor: _light,
    labelStyle: TextStyle(color: sel ? _accent : Colors.black54, fontWeight: sel ? FontWeight.w600 : FontWeight.normal),
    side: BorderSide(color: sel ? _accent : Colors.grey.shade300),
  );

  Widget _lbl(String t) => Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54));

  Widget _nextBtn(String label, {required VoidCallback onTap, bool enabled = true}) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: enabled ? onTap : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: _dark, foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.shade300,
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
    ),
  );
}