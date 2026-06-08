// lib/education/field/field_data_input.dart
// ignore_for_file: unused_element, avoid_print, use_build_context_synchronously, deprecated_member_use, unused_local_variable

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:kilimomkononi/models/education_user.dart';
import 'package:kilimomkononi/education/data/field_management_tips.dart';
import 'package:kilimomkononi/education/data/soil_optimal_ranges.dart';
import 'package:kilimomkononi/education/data/fertilizer_recommendations.dart';
import 'package:kilimomkononi/education/tutor/tutor_suppressor.dart';
import 'package:kilimomkononi/services/plot_analysis_service.dart';
import 'package:kilimomkononi/widgets/plot_history_card.dart';

const String baseUrl = "https://us-central1-kilimomkononi-e1031.cloudfunctions.net/askGemini";

const Color primaryGreen = Color(0xFF032704);

final Map<String, List<String>> cropStages = {
  'Beans':    ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Flowering/Reproductive', 'Maturation/Harvesting', 'Storage'],
  'Maize':    ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Flowering/Reproductive', 'Maturation/Harvesting', 'Storage'],
  'Cabbage':  ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Flowering/Reproductive', 'Maturation/Harvesting', 'Storage'],
  'Carrots':  ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Maturation/Harvesting', 'Storage'],
  'Tomatoes': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Flowering/Reproductive', 'Maturation/Harvesting', 'Storage'],
  'Onions':   ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Bulb Formation/Reproductive', 'Bulbing/Maturation', 'Harvesting/Storage'],
};

final List<String> cropList = cropStages.keys.toList();

final Map<String, Map<String, List<String>>> cropStageIssues = {
  'Beans': {
    'Germination/Seedling':      ['Poor Germination', 'Damping Off', 'Slow Growth'],
    'Vegetative Growth/Weeding': ['Nutrient Deficiency', 'Weed Pressure', 'Lodging'],
    'Flowering/Reproductive':    ['Flower Drop', 'Poor Pod Set'],
    'Maturation/Harvesting':     ['Uneven Maturity', 'Low Yield'],
    'Storage':                   ['High Moisture Content'],
  },
  'Maize': {
    'Germination/Seedling':      ['Poor Germination', 'Uneven Germination', 'Slow Growth'],
    'Vegetative Growth/Weeding': ['Nutrient Deficiency', 'Weed Pressure', 'Lodging', 'Stunted Growth'],
    'Flowering/Reproductive':    ['Poor Pollination', 'Barrenness (No Ears)', 'Ear Rot'],
    'Maturation/Harvesting':     ['Delayed Maturity', 'Low Grain Fill'],
    'Storage':                   ['High Moisture Content'],
  },
  'Cabbage': {
    'Germination/Seedling':      ['Poor Germination', 'Leggy Seedlings'],
    'Vegetative Growth/Weeding': ['Nutrient Deficiency', 'Weed Pressure', 'Bolting (Premature Flowering)', 'Loose Heads'],
    'Maturation/Harvesting':     ['Head Splitting', 'Small Heads'],
    'Storage':                   ['Poor Storage Life'],
  },
  'Carrots': {
    'Germination/Seedling':      ['Poor Germination', 'Slow Germination'],
    'Vegetative Growth/Weeding': ['Nutrient Deficiency', 'Weed Pressure', 'Forked Roots', 'Stunted Growth'],
    'Maturation/Harvesting':     ['Cracking', 'Green Shoulders'],
    'Storage':                   ['Poor Storage Life'],
  },
  'Tomatoes': {
    'Germination/Seedling':      ['Poor Germination', 'Leggy Seedlings'],
    'Vegetative Growth/Weeding': ['Nutrient Deficiency', 'Weed Pressure', 'Excessive Vegetative Growth'],
    'Flowering/Reproductive':    ['Flower Drop', 'Poor Fruit Set', 'Blossom End Rot'],
    'Maturation/Harvesting':     ['Fruit Cracking', 'Sunscald'],
    'Storage':                   ['Poor Storage Life'],
  },
  'Onions': {
    'Germination/Seedling':      ['Poor Germination'],
    'Vegetative Growth/Weeding': ['Nutrient Deficiency', 'Weed Pressure', 'Bolting (Premature Flowering)'],
    'Bulbing/Maturation':        ['Small Bulbs', 'Thick Necks'],
    'Harvesting/Storage':        ['Poor Curing', 'Poor Storage Life'],
  },
};

// ─────────────────────────────────────────────────────────────────────────────
// ─── AI helper — Gemini via Firebase Function ────────────────────────────────
// Use your secure Gemini backend instead of direct Anthropic call
Future<String> _callAI(String prompt) async {
  try {
    final response = await http.post(
      Uri.parse("https://us-central1-kilimomkononi-e1031.cloudfunctions.net/askGemini"),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'prompt': prompt}),
    ).timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      print('AI backend error: ${response.statusCode} ${response.body}');
      return 'AI service is temporarily unavailable. Please try again.';
    }

    final data = jsonDecode(response.body);
    // Support both old full response and new clean {text: "..."} format
    final text = data['text'] ?? 
                 data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? 
                 "Sorry, I could not generate an analysis at this time.";

    return text.toString().trim();
  } catch (e) {
    print('AI call error: $e');
    return 'Could not reach AI service. Please check your connection.';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  WIDGET
// ═══════════════════════════════════════════════════════════════════════════
class FieldDataInput extends StatefulWidget {
  final EduRole role;
  final String schoolName;
  final String classId;

  const FieldDataInput({
    super.key,
    required this.role,
    required this.schoolName,
    required this.classId,
  });

  @override
  State<FieldDataInput> createState() => _FieldDataInputState();
}

class _FieldDataInputState extends State<FieldDataInput>
    with SingleTickerProviderStateMixin, TutorSuppressorMixin {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Scroll controllers – preserve position during AI setState rebuilds
  final _fieldTabScrollCtrl = ScrollController();
  final _soilTabScrollCtrl  = ScrollController();

  PlotAnalysisResult? _previousAnalysis;
  late TabController _tabController;

  // ── Field Issues ──
  final _studentNameCtrl  = TextEditingController();
  final _observationsCtrl = TextEditingController();
  final _studentIdeaCtrl  = TextEditingController();

  String? _selectedCrop;
  String? _selectedStage;
  String? _selectedIssue;

  // ── Soil Test (teacher-entered) ──
  final _soilTestFieldLocationCtrl = TextEditingController();
  DateTime _soilTestDate = DateTime.now();

  final _nitrogenCtrl      = TextEditingController();
  final _phosphorusCtrl    = TextEditingController();
  final _potassiumCtrl     = TextEditingController();
  final _pHCtrl            = TextEditingController();
  final _organicMatterCtrl = TextEditingController();

  // ── Student soil tab (read-only view) ──
  // Students no longer fill in NPK. They only select crop/stage to view teacher data
  // and write their own observations/ideas underneath.
  final _soilTestStudentNameCtrl  = TextEditingController();
  final _soilObservationsCtrl     = TextEditingController();
  final _soilStudentIdeaCtrl      = TextEditingController();

  CollectionReference? _fieldSubmissionsCollection;
  CollectionReference? _soilTestResultsCollection;

  String? _currentUserId;
  Map<String, dynamic>? _soilAnalysis;

  // AI state — per-card loading keys so only the tapped card spins
  final Set<String> _aiLoadingKeys = {};

  bool get _aiAnalysisLoading => _aiLoadingKeys.isNotEmpty;

  bool _isCardLoading(String key) => _aiLoadingKeys.contains(key);

  void _setCardLoading(String key, bool loading) {
    setState(() {
      if (loading) {
        _aiLoadingKeys.add(key);
      } else {
        _aiLoadingKeys.remove(key);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: isTeacher ? 3 : 2, vsync: this);
    _initializeFirestore();
    _loadPreviousAnalysis();
    for (final c in [
      _nitrogenCtrl, _phosphorusCtrl, _potassiumCtrl, _pHCtrl, _organicMatterCtrl,
      _studentNameCtrl, _soilTestStudentNameCtrl,
    ]) {
      c.addListener(() => setState(() {}));
    }
  }

  Future<void> _loadPreviousAnalysis() async {
    final p = _parseClassId(widget.classId);
    if (p['school']!.isEmpty || p['system']!.isEmpty || p['grade']!.isEmpty) return;
    final year = DateTime.now().year.toString();
    try {
      final snap = await FirebaseFirestore.instance
          .collection('schools').doc(p['school'])
          .collection('systems').doc(p['system'])
          .collection('grades').doc(p['grade'])
          .collection('plot_analyses').doc(year)
          .get();
      if (snap.exists && mounted) {
        setState(() => _previousAnalysis =
            PlotAnalysisResult.fromMap(snap.data() as Map<String, dynamic>));
      }
    } catch (_) {}
  }

  Future<void> _initializeFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) setState(() => _currentUserId = user.uid);

    final p = _parseClassId(widget.classId);
    if (p['school']!.isNotEmpty && p['system']!.isNotEmpty && p['grade']!.isNotEmpty) {
      final ref = FirebaseFirestore.instance
          .collection('schools').doc(p['school'])
          .collection('systems').doc(p['system'])
          .collection('grades').doc(p['grade']);
      setState(() {
        _fieldSubmissionsCollection = ref.collection('field_submissions');
        _soilTestResultsCollection  = ref.collection('soil_test_results');
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final c in [
      _studentNameCtrl, _observationsCtrl, _studentIdeaCtrl,
      _soilTestStudentNameCtrl, _soilTestFieldLocationCtrl,
      _nitrogenCtrl, _phosphorusCtrl, _potassiumCtrl, _pHCtrl, _organicMatterCtrl,
      _soilObservationsCtrl, _soilStudentIdeaCtrl,
    ]) { c.dispose(); }
    super.dispose();
  }

  void _resetFieldForm() {
    _observationsCtrl.clear();
    _studentIdeaCtrl.clear();
    setState(() => _selectedIssue = null);
  }

  // ── Parse classId correctly regardless of how many '_' are in schoolName ──
  // classId format: "School_Name_With_Spaces_system_grade"
  // system keyword is one of: primary, junior, senior, eightfourfour
  Map<String, String> _parseClassId(String classId) {
    const systems = ['eightfourfour', 'senior', 'junior', 'primary'];
    for (final sys in systems) {
      final marker = '_${sys}_';
      final idx = classId.toLowerCase().indexOf(marker);
      if (idx != -1) {
        return {
          'school': classId.substring(0, idx),
          'system': classId.substring(idx + 1, idx + marker.length - 1),
          'grade':  classId.substring(idx + marker.length),
        };
      }
    }
    // Fallback for unexpected formats
    final parts = classId.split('_');
    return {
      'school': parts.isNotEmpty ? parts[0] : classId,
      'system': parts.length > 1 ? parts[1] : '',
      'grade':  parts.length > 2 ? parts.sublist(2).join('_') : '',
    };
  }

  DocumentReference _gradeDocRef() {
    final p = _parseClassId(widget.classId);
    return FirebaseFirestore.instance
        .collection('schools').doc(p['school'])
        .collection('systems').doc(p['system'])
        .collection('grades').doc(p['grade']);
  }

  bool get isTeacher => widget.role == EduRole.teacher || widget.role == EduRole.headteacher;
  bool get isStudent  => widget.role == EduRole.student;

  // ═══════════════════════════════════════════════════════════════════════════
  //  FIELD ISSUES TAB
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildFieldIssuesTab() {
    final stageItems = _selectedCrop != null
        ? cropStages[_selectedCrop]!.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList()
        : <DropdownMenuItem<String>>[];

    final issueItems = (_selectedCrop != null &&
            _selectedStage != null &&
            cropStageIssues[_selectedCrop]?[_selectedStage] != null)
        ? cropStageIssues[_selectedCrop]![_selectedStage]!
            .map((i) => DropdownMenuItem(value: i, child: Text(i)))
            .toList()
        : <DropdownMenuItem<String>>[];

    return SingleChildScrollView(
      controller: _fieldTabScrollCtrl,
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PlotHistoryCard(
              analysis:    _previousAnalysis,
              seasonLabel: '${DateTime.now().year - 1} Season',
              isEducation: true,
            ),

            const Text(
              '🌾 Field Issue Reporting',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryGreen),
            ),
            const SizedBox(height: 12),

            if (isStudent) ...[
              TextFormField(
                controller: _studentNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Your Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) => v == null || v.trim().isEmpty ? 'Name required' : null,
              ),
              const SizedBox(height: 12),
            ],

            DropdownButtonFormField<String>(
              value: _selectedCrop,
              decoration: const InputDecoration(
                labelText: 'Select Crop *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.grass),
              ),
              items: cropList.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() {
                _selectedCrop  = v;
                _selectedStage = null;
                _selectedIssue = null;
              }),
              validator: (v) => v == null ? 'Please select a crop' : null,
            ),
            const SizedBox(height: 12),

            IgnorePointer(
              ignoring: _selectedCrop == null,
              child: Opacity(
                opacity: _selectedCrop == null ? 0.45 : 1.0,
                child: DropdownButtonFormField<String>(
                  value: _selectedStage,
                  decoration: const InputDecoration(
                    labelText: 'Growth Stage *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.timeline),
                  ),
                  items: stageItems,
                  onChanged: (v) => setState(() { _selectedStage = v; _selectedIssue = null; }),
                  validator: (v) => v == null ? 'Please select stage' : null,
                ),
              ),
            ),
            const SizedBox(height: 12),

            IgnorePointer(
              ignoring: _selectedStage == null,
              child: Opacity(
                opacity: _selectedStage == null ? 0.45 : 1.0,
                child: DropdownButtonFormField<String>(
                  value: _selectedIssue,
                  decoration: const InputDecoration(
                    labelText: 'Field Issue *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.warning_amber),
                  ),
                  items: issueItems,
                  onChanged: (v) => setState(() => _selectedIssue = v),
                  validator: (v) => v == null ? 'Please select issue' : null,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Hints / AI hints panel ──
            _buildHintsPanel(),
            if (_selectedIssue != null) const SizedBox(height: 12),

            if (isStudent) ...[
              TextFormField(
                controller: _observationsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Your Observations *',
                  hintText: 'Describe what you see in the field',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.visibility),
                ),
                maxLines: 3,
                validator: (v) => v == null || v.trim().isEmpty ? 'Observations required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _studentIdeaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Your Idea / Solution *',
                  hintText: 'What would you do to solve this?',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lightbulb),
                ),
                maxLines: 3,
                validator: (v) => v == null || v.trim().isEmpty ? 'Solution required' : null,
              ),
              const SizedBox(height: 16),
            ],

            if (isTeacher) const SizedBox(height: 4),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _submitFieldIssue,
                icon: _isSaving
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send),
                label: Text(_isSaving ? 'Submitting...' : 'Submit Issue'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.all(14),
                ),
              ),
            ),

            if (isStudent) ...[
              const SizedBox(height: 28),
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                '📋 My Submissions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryGreen),
              ),
              const SizedBox(height: 10),
              _buildStudentSubmissions(),
            ],
          ],
        ),
      ),
    );
  }

  // ── Hints panel — AI-powered for teachers; locked banner for students ──
  Widget _buildHintsPanel() {
    if (_selectedCrop == null || _selectedStage == null || _selectedIssue == null) {
      return const SizedBox.shrink();
    }

    // Teacher: show static tips + AI analysis button
    if (isTeacher) {
      final key  = '${_selectedCrop}_${_selectedStage}_$_selectedIssue';
      final tips = fieldManagementTips[key];

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade300, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.lightbulb, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Text('Management Recommendations',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue.shade900)),
            ]),
            const SizedBox(height: 10),
            if (tips != null) ...[
              if (tips['chemicalControl'] != null && (tips['chemicalControl'] as List).isNotEmpty) ...[
                _hintSection('🧪 Chemical Control', tips['chemicalControl'] as List),
                const SizedBox(height: 8),
              ],
              if (tips['organicControl'] != null && (tips['organicControl'] as List).isNotEmpty) ...[
                _hintSection('🌱 Organic Solution', tips['organicControl'] as List),
                const SizedBox(height: 8),
              ],
              if (tips['culturalControl'] != null && (tips['culturalControl'] as List).isNotEmpty)
                _hintSection('👨‍🌾 Cultural Practice', tips['culturalControl'] as List),
              const SizedBox(height: 12),
            ],
            // AI analysis button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isCardLoading('field_general_${_selectedCrop}_$_selectedIssue')
                    ? null
                    : () => _runAiFieldAnalysis(null),
                icon: _isCardLoading('field_general_${_selectedCrop}_$_selectedIssue')
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome, size: 16),
                label: Text(_isCardLoading('field_general_${_selectedCrop}_$_selectedIssue')
                    ? 'Analysing…'
                    : '🤖 Get AI Analysis for this Issue'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.blue.shade400),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Student: locked banner
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.blue.shade100],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade300),
      ),
      child: Row(children: [
        Icon(Icons.lock_outline, color: Colors.blue.shade700),
        const SizedBox(width: 8),
        Expanded(child: Text(
          'Expert management hints will be available after teacher review',
          style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
        )),
      ]),
    );
  }

  Widget _hintSection(String title, List items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
          const SizedBox(height: 4),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(left: 10, top: 2, bottom: 2),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('• ', style: TextStyle(fontSize: 13, color: Colors.blue.shade900)),
                  Expanded(child: Text(item.toString(),
                      style: TextStyle(fontSize: 13, color: Colors.blue.shade900))),
                ]),
              )),
        ],
      );

  // ── AI field-issue analysis ──────────────────────────────────────────────
  // studentData = null when called from teacher hints panel (general analysis).
  // studentData = submission map when called from a specific student submission card.
  Future<void> _runAiFieldAnalysis(Map<String, dynamic>? studentData) async {
    final crop  = studentData?['crop']  ?? _selectedCrop  ?? '';
    final stage = studentData?['stage'] ?? _selectedStage ?? '';
    final issue = studentData?['issue'] ?? _selectedIssue ?? '';

    String userMsg;
    if (studentData != null) {
      userMsg = '''
Crop: $crop
Growth Stage: $stage
Identified Issue: $issue
Student Observations: ${studentData['studentObservation'] ?? '(none)'}
Student Proposed Solution: ${studentData['studentIdea'] ?? '(none)'}

Analyse the student's observations and proposed solution. Explain:
1. Whether the student's identification of the issue is accurate given the observations.
2. What the actual cause likely is and what signs confirm it.
3. Whether the student's proposed solution would work, and what the best interventions are (chemical, organic, cultural).
4. A teaching question to deepen the student's understanding.
Keep the language appropriate for Kenyan secondary school agriculture students.
''';
    } else {
      userMsg = '''
Crop: $crop
Growth Stage: $stage
Field Issue: $issue

Provide a comprehensive agronomic analysis of this field issue including:
1. Root causes and contributing factors.
2. Diagnostic signs to confirm the issue.
3. Best management interventions (chemical, organic, cultural) ranked by effectiveness.
4. Preventive measures for future seasons.
Keep language practical for Kenyan secondary school teachers.
''';
    }

    final loadKey = 'field_${studentData?['docId'] ?? 'general'}_${crop}_$issue';
    final savedPos = _fieldTabScrollCtrl.hasClients ? _fieldTabScrollCtrl.offset : 0.0;
    _setCardLoading(loadKey, true);
    final result = await _callAI(
      'You are an expert Kenyan agronomist and secondary school agriculture teacher. '
      'Provide concise, practical, evidence-based advice appropriate for the Kenyan context.\n\n'
      '$userMsg',
    );
    _setCardLoading(loadKey, false);
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted && _fieldTabScrollCtrl.hasClients) {
        _fieldTabScrollCtrl.jumpTo(savedPos);
      }
    });

    if (!mounted) return;
    _showAiResultDialog(
      title: studentData != null
          ? '🤖 AI Analysis: ${studentData['studentName'] ?? 'Student'}\'s Submission'
          : '🤖 AI Field Issue Analysis',
      result: result,
    );
  }

  void _showAiResultDialog({required String title, required String result}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)]),
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold))),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: const Icon(Icons.close,
                      color: Colors.white70, size: 20),
                ),
              ]),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _AiMarkdownCard(content: result),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Got it!'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Submit Field Issue ───────────────────────────────────────────────────
  Future<void> _submitFieldIssue() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await _fieldSubmissionsCollection?.add({
        'crop':               _selectedCrop,
        'stage':              _selectedStage,
        'issue':              _selectedIssue,
        'studentObservation': isStudent ? _observationsCtrl.text.trim() : '',
        'studentIdea':        isStudent ? _studentIdeaCtrl.text.trim()  : '',
        'studentName':        isStudent ? _studentNameCtrl.text.trim()  : 'Teacher Observation',
        'submittedBy':        isStudent ? 'student' : 'teacher',
        'schoolName':         widget.schoolName,
        'className':          widget.classId,
        'reviewStatus':       'pending',
        'submittedAt':        FieldValue.serverTimestamp(),
      });
      final submittedName = isStudent ? _studentNameCtrl.text.trim() : '';
      _resetFieldForm();
      if (isStudent && submittedName.isNotEmpty && _soilTestStudentNameCtrl.text.trim().isEmpty) {
        _soilTestStudentNameCtrl.text = submittedName;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Submission sent! Go to Soil Testing to view soil data.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // ── Student submission cards — Field Issues ──────────────────────────────
  Widget _buildStudentSubmissions() {
    final studentName = _studentNameCtrl.text.trim();
    if (studentName.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
        child: const Text('👆 Enter your name above to see your submissions'),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      // No orderBy → no composite index needed. Sorted client-side below.
      stream: _fieldSubmissionsCollection
          ?.where('submittedBy', isEqualTo: 'student')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData) return const Text('No data available');

        final allDocs = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final aTs = (a.data() as Map<String, dynamic>)['submittedAt'];
            final bTs = (b.data() as Map<String, dynamic>)['submittedAt'];
            if (aTs == null || bTs == null) return 0;
            return (bTs as Timestamp).compareTo(aTs as Timestamp);
          });

        final mine = allDocs.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          return d['studentName']?.toString().trim() == studentName;
        }).toList();

        if (mine.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
            child: Column(children: [
              const Icon(Icons.inbox_outlined, size: 40, color: Colors.grey),
              const SizedBox(height: 8),
              const Text('No submissions yet'),
              Text('Looking for: "$studentName"',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ]),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
              child: Text(
                '${mine.length} submission${mine.length == 1 ? '' : 's'} found',
                style: TextStyle(fontSize: 12, color: Colors.green.shade900, fontWeight: FontWeight.bold),
              ),
            ),
            ...mine.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['docId'] = doc.id;
              return _buildStudentSubmissionCard(data);
            }),
          ],
        );
      },
    );
  }

  Widget _buildStudentSubmissionCard(Map<String, dynamic> data) {
    final isReviewed      = data['reviewStatus'] == 'reviewed';
    final hintsUnlocked   = data['hintsUnlocked'] == true;
    final reviewUnlocked  = data['reviewUnlocked'] == true;
    final teacherComment  = data['teacherComment']?.toString();
    final studentReply    = data['studentReply']?.toString();
    final teacherFollowUp = data['teacherFollowUp']?.toString();
    final studentReply2   = data['studentReply2']?.toString();
    final teacherFollowUp2= data['teacherFollowUp2']?.toString();
    final docId           = data['docId']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(isReviewed ? Icons.check_circle : Icons.pending,
                  color: isReviewed ? Colors.green : Colors.orange),
              const SizedBox(width: 8),
              Expanded(child: Text('${data['crop']} – ${data['issue']}',
                  style: const TextStyle(fontWeight: FontWeight.bold))),
              if (isReviewed && reviewUnlocked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: _getGradeColor(data['teacherGrade']),
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(_getGradeLabel(data['teacherGrade']),
                      style: const TextStyle(color: Colors.white, fontSize: 11)),
                ),
            ]),
            const SizedBox(height: 10),
            _colorBox(Colors.blue, 'Your idea:', Icons.lightbulb_outline, data['studentIdea'] ?? ''),
            if (isReviewed && reviewUnlocked && teacherComment != null) ...[
              const SizedBox(height: 8),
              _colorBox(Colors.green, 'Teacher feedback:', Icons.school, teacherComment),
            ],
            if (studentReply != null) ...[
              const SizedBox(height: 8),
              _colorBox(Colors.purple, 'Your reply:', Icons.reply, studentReply),
            ],
            if (teacherFollowUp != null) ...[
              const SizedBox(height: 8),
              _colorBox(Colors.amber, 'Teacher follow-up:', Icons.chat_bubble_outline, teacherFollowUp),
            ],
            if (studentReply2 != null) ...[
              const SizedBox(height: 8),
              _colorBox(Colors.purple, 'Your reply:', Icons.reply, studentReply2),
            ],
            if (teacherFollowUp2 != null) ...[
              const SizedBox(height: 8),
              _colorBox(Colors.amber, 'Teacher follow-up:', Icons.chat_bubble_outline, teacherFollowUp2),
            ],
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: [
              if (isReviewed && reviewUnlocked && teacherComment != null && studentReply == null)
                ElevatedButton.icon(
                  onPressed: () => _showStudentReplyDialog(docId, data, replyNumber: 1),
                  icon: const Icon(Icons.reply, size: 15),
                  label: const Text('Reply to Teacher', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  ),
                ),
              if (teacherFollowUp != null && studentReply2 == null)
                ElevatedButton.icon(
                  onPressed: () => _showStudentReplyDialog(docId, data, replyNumber: 2),
                  icon: const Icon(Icons.reply, size: 15),
                  label: const Text('Reply to Follow-up', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  ),
                ),
              if (hintsUnlocked)
                ElevatedButton.icon(
                  onPressed: () => _showHintsDialog(data),
                  icon: const Icon(Icons.lightbulb, size: 15),
                  label: const Text('View Expert Hints', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  ),
                ),
              // AI analysis button — visible to students once submission is reviewed
              if (isReviewed)
                ElevatedButton.icon(
                  onPressed: _isCardLoading('field_${data['docId']}_${data['crop']}_${data['issue']}')
                      ? null
                      : () => _runAiFieldAnalysis(data),
                  icon: _isCardLoading('field_${data['docId']}_${data['crop']}_${data['issue']}')
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.auto_awesome, size: 15),
                  label: const Text('AI Analysis', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  ),
                ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _colorBox(MaterialColor color, String label, IconData icon, String body) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 15, color: color.shade700),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color.shade900)),
        ]),
        const SizedBox(height: 3),
        Text(body, style: TextStyle(fontSize: 13, color: color.shade900)),
      ]),
    );
  }

  Future<void> _showStudentReplyDialog(String? docId, Map<String, dynamic> data,
      {int replyNumber = 1}) async {
    if (docId == null) return;
    final ctrl = TextEditingController();
    final isSecond     = replyNumber == 2;
    final contextText  = isSecond ? (data['teacherFollowUp'] ?? '') : (data['teacherComment'] ?? '');
    final contextLabel = isSecond ? 'Teacher follow-up:' : 'Teacher asked:';
    final dialogTitle  = isSecond ? 'Reply to Follow-up' : 'Reply to Teacher';
    final buttonColor  = isSecond ? Colors.deepPurple : Colors.purple;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.reply, color: buttonColor), const SizedBox(width: 8),
          Expanded(child: Text(dialogTitle)),
        ]),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          _colorBox(Colors.green, contextLabel, Icons.school, contextText),
          const SizedBox(height: 14),
          TextField(
            controller: ctrl,
            decoration: InputDecoration(
              labelText: 'Your Reply',
              hintText: isSecond
                  ? "Respond to the teacher's follow-up..."
                  : "Answer the teacher's question...",
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.edit),
            ),
            maxLines: 4, autofocus: true,
          ),
          const SizedBox(height: 6),
          Text('The teacher will see your reply and can respond.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () async {
              final reply = ctrl.text.trim();
              if (reply.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a reply')));
                return;
              }
              try {
                final fields = isSecond
                    ? {'studentReply2': reply, 'studentRepliedAt2': FieldValue.serverTimestamp()}
                    : {'studentReply': reply, 'studentRepliedAt': FieldValue.serverTimestamp()};
                await _fieldSubmissionsCollection?.doc(docId).update(fields);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Reply sent!'), backgroundColor: Colors.green),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
              }
            },
            icon: const Icon(Icons.send),
            label: const Text('Send Reply'),
            style: ElevatedButton.styleFrom(backgroundColor: buttonColor, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  void _showHintsDialog(Map<String, dynamic> data) {
    final key  = '${data['crop']}_${data['stage']}_${data['issue']}';
    final tips = fieldManagementTips[key];
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFFF57F17), Color(0xFFFF8F00)]),
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.lightbulb,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('Expert Hints',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      Text('${data['issue'] ?? ''}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ])),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: const Icon(Icons.close,
                      color: Colors.white70, size: 20),
                ),
              ]),
            ),
            Flexible(
              child: tips == null
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No expert hints available for this issue.',
                          textAlign: TextAlign.center),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        if (tips['chemicalControl'] != null)
                          _hintsCategory(
                            '🧪 Chemical Control',
                            tips['chemicalControl'] as List,
                            const Color(0xFFFFEBEE),
                            const Color(0xFFB71C1C),
                            const Color(0xFFC62828),
                          ),
                        if (tips['organicControl'] != null) ...[
                          const SizedBox(height: 10),
                          _hintsCategory(
                            '🌿 Organic Solution',
                            tips['organicControl'] as List,
                            const Color(0xFFE8F5E9),
                            const Color(0xFF1B5E20),
                            const Color(0xFF2E7D32),
                          ),
                        ],
                        if (tips['culturalControl'] != null) ...[
                          const SizedBox(height: 10),
                          _hintsCategory(
                            '👨‍🌾 Cultural Practice',
                            tips['culturalControl'] as List,
                            const Color(0xFFE3F2FD),
                            const Color(0xFF0D47A1),
                            const Color(0xFF1565C0),
                          ),
                        ],
                      ]),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Got it!'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8F00),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hintsCategory(
      String label, List items, Color bg, Color titleColor, Color borderColor) {
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: borderColor.withOpacity(0.4), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: borderColor.withOpacity(0.12),
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11)),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: titleColor)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items
                  .map<Widget>((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.check_circle,
                                  size: 14, color: borderColor),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(item.toString(),
                                      style: const TextStyle(
                                          fontSize: 13, height: 1.4))),
                            ]),
                      ))
                  .toList()),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SOIL TESTING TAB
  //  • Teachers: enter NPK data + save + "Generate Quiz" button
  //  • Students: read-only view of teacher-saved soil data for their crop/stage
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSoilTestingTab() {
    return isTeacher ? _buildTeacherSoilTab() : _buildStudentSoilViewTab();
  }

  // ── TEACHER: data entry form ─────────────────────────────────────────────
  Widget _buildTeacherSoilTab() {
    final crop  = _selectedCrop;
    final stage = _selectedStage;

    return SingleChildScrollView(
      controller: _soilTabScrollCtrl,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🧪 Soil Testing – Teacher Data Entry',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryGreen),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(children: [
              Icon(Icons.info_outline, color: Colors.amber.shade700, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Only teachers can enter soil data. Students will see the saved data in their read-only view for monitoring.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),

          // Crop/Stage banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: (crop != null && stage != null) ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (crop != null && stage != null) ? Colors.green.shade300 : Colors.orange.shade300,
              ),
            ),
            child: (crop == null || stage == null)
                ? Row(children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Please go to the Field Issues tab first and select crop and growth stage.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ])
                : Row(children: [
                    Icon(Icons.grass, color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(fontSize: 13, color: Colors.green.shade900),
                          children: [
                            const TextSpan(text: 'Crop: ', style: TextStyle(fontWeight: FontWeight.bold)),
                            TextSpan(text: '$crop   '),
                            const TextSpan(text: 'Stage: ', style: TextStyle(fontWeight: FontWeight.bold)),
                            TextSpan(text: stage),
                          ],
                        ),
                      ),
                    ),
                  ]),
          ),
          const SizedBox(height: 14),

          // Field location
          TextField(
            controller: _soilTestFieldLocationCtrl,
            decoration: const InputDecoration(
              labelText: 'Field Location',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_on),
            ),
          ),
          const SizedBox(height: 12),

          // Date picker
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today, color: primaryGreen),
            title: const Text('Test Date'),
            subtitle: Text('${_soilTestDate.day}/${_soilTestDate.month}/${_soilTestDate.year}'),
            trailing: const Icon(Icons.edit, size: 18),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _soilTestDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (date != null) setState(() => _soilTestDate = date);
            },
          ),
          const Divider(),
          const SizedBox(height: 8),

          Row(children: [
            const Text('Nutrient Levels',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Text('(ppm / %)', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ]),
          const SizedBox(height: 4),
          Text(
            crop != null
                ? 'Background colour shows status vs optimal range for $crop'
                : 'Select crop in Field Issues tab to see optimal ranges',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 10),

          _buildNutrientField('Nitrogen (N)',    _nitrogenCtrl,     'nitrogen',     'ppm'),
          const SizedBox(height: 10),
          _buildNutrientField('Phosphorus (P)',  _phosphorusCtrl,   'phosphorus',   'ppm'),
          const SizedBox(height: 10),
          _buildNutrientField('Potassium (K)',   _potassiumCtrl,    'potassium',    'ppm'),
          const SizedBox(height: 10),
          _buildNutrientField('pH Level',        _pHCtrl,           'pH',           'pH'),
          const SizedBox(height: 10),
          _buildNutrientField('Organic Matter',  _organicMatterCtrl,'organicMatter','%'),
          const SizedBox(height: 20),

          // Save soil data button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _submitSoilTestByTeacher,
              icon: _isSaving
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'Saving…' : 'Save Soil Data for Class'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(14),
              ),
            ),
          ),

          // ── Saved soil tests list with quiz generation button ──
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 12),
          const Text(
            '📋 Saved Soil Tests',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryGreen),
          ),
          const SizedBox(height: 10),
          _buildTeacherSavedSoilList(),
        ],
      ),
    );
  }

  // List of teacher-saved soil tests with quiz generation button
  Widget _buildTeacherSavedSoilList() {
    return StreamBuilder<QuerySnapshot>(
      // No orderBy → no composite index needed. Sort client-side below.
      stream: _soilTestResultsCollection
          ?.where('submittedBy', isEqualTo: 'teacher')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
            child: Text('⚠️ Could not load data: ${snapshot.error}',
                style: TextStyle(color: Colors.red.shade800, fontSize: 12)),
          );
        }
        final rawDocs = snapshot.data?.docs ?? [];
        final docs = rawDocs.toList()
          ..sort((a, b) {
            final aTs = (a.data() as Map<String, dynamic>)['submittedAt'];
            final bTs = (b.data() as Map<String, dynamic>)['submittedAt'];
            if (aTs == null || bTs == null) return 0;
            return (bTs as Timestamp).compareTo(aTs as Timestamp);
          });
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
            child: const Text('No soil data saved yet. Fill in the form above and save.'),
          );
        }
        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return _buildTeacherSoilCard(doc.id, data);
          }).toList(),
        );
      },
    );
  }

  Widget _buildTeacherSoilCard(String docId, Map<String, dynamic> data) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.science, color: Colors.green.shade700),
              const SizedBox(width: 8),
              Expanded(child: Text(
                '${data['crop'] ?? ''} – ${data['stage'] ?? ''}'
                ' (${(data['submittedAt'] as Timestamp?)?.toDate().toString().substring(0, 10) ?? ''})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              )),
            ]),
            const SizedBox(height: 8),
            Text('N: ${data['nitrogen']?['value']} ppm  (${data['nitrogen']?['status']})'),
            Text('P: ${data['phosphorus']?['value']} ppm  (${data['phosphorus']?['status']})'),
            Text('K: ${data['potassium']?['value']} ppm  (${data['potassium']?['status']})'),
            Text('pH: ${data['pH']?['value']}  (${data['pH']?['status']})'),
            Text('Organic Matter: ${data['organicMatter']?['value']}%  (${data['organicMatter']?['status']})'),
            if (data['fieldLocation'] != null && (data['fieldLocation'] as String).isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Location: ${data['fieldLocation']}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
            const SizedBox(height: 10),
            // ── Generate Quiz button ──
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isCardLoading('soilquiz_$docId')
                    ? null
                    : () => _generateSoilQuizFromData(data, docId),
                icon: _isCardLoading('soilquiz_$docId')
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.quiz, size: 16, color: Colors.deepPurple),
                label: const Text('📝 Generate Quiz/Essay from this Soil Data',
                    style: TextStyle(fontSize: 12, color: Colors.deepPurple)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.deepPurple),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Generate quiz/essay from saved soil test data ───────────────────────
  Future<void> _generateSoilQuizFromData(Map<String, dynamic> soilData, String docId) async {
    final crop  = soilData['crop']  ?? '';
    final stage = soilData['stage'] ?? '';
    final n     = soilData['nitrogen']?['value'];
    final p     = soilData['phosphorus']?['value'];
    final k     = soilData['potassium']?['value'];
    final ph    = soilData['pH']?['value'];
    final om    = soilData['organicMatter']?['value'];
    final nSt   = soilData['nitrogen']?['status'];
    final pSt   = soilData['phosphorus']?['status'];
    final kSt   = soilData['potassium']?['status'];
    final phSt  = soilData['pH']?['status'];
    final omSt  = soilData['organicMatter']?['status'];
    final defs  = (soilData['deficiencies'] as List<dynamic>?)?.join(', ') ?? 'None';

    // Ask Gemini to return structured JSON so we can let teacher pick questions
    final prompt = '''
You are an expert Kenyan secondary school agriculture teacher and curriculum developer.

Based on the real soil test results below, generate exactly 5 MCQ questions and 2 essay questions
for Kenyan secondary school agriculture students (Form 1-4 level).

SOIL TEST DATA:
Crop: $crop  |  Growth Stage: $stage
- Nitrogen (N): $n ppm – Status: $nSt
- Phosphorus (P): $p ppm – Status: $pSt
- Potassium (K): $k ppm – Status: $kSt
- pH: $ph – Status: $phSt
- Organic Matter: $om% – Status: $omSt
- Identified Deficiencies: $defs

REQUIREMENTS:
1. MCQ questions must test: nutrient interpretation, deficiency identification,
   corrective amendments, and optimal ranges for $crop at $stage.
2. Essay questions: (a) analyse overall soil health and recommend specific amendments,
   (b) explain how these nutrient levels affect $crop performance at $stage.
3. Language must be clear and appropriate for Kenyan secondary school level.

Return ONLY a valid JSON array — no markdown, no code fences, no extra text.
Each element must be one of these two shapes:

MCQ:
{"type":"mcq","question":"...","options":["A. ...","B. ...","C. ...","D. ..."],"correct":0}

Essay:
{"type":"essay","question":"...","modelAnswer":"..."}

Return exactly 7 items: 5 MCQ followed by 2 essay.
''';

    final loadKey = 'soilquiz_$docId';
    final savedPos = _soilTabScrollCtrl.hasClients ? _soilTabScrollCtrl.offset : 0.0;
    _setCardLoading(loadKey, true);

    final raw = await _callAI(
      'You are a Kenyan secondary school agriculture teacher. '
      'Return ONLY a JSON array — no prose, no markdown fences.\n\n$prompt',
    );

    _setCardLoading(loadKey, false);
    // Restore scroll position after setState rebuild settles
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted && _soilTabScrollCtrl.hasClients) {
        _soilTabScrollCtrl.jumpTo(savedPos);
      }
    });

    if (!mounted) return;

    // Parse the JSON; fall back to plain-text display on parse error
    List<Map<String, dynamic>> questions = [];
    try {
      final cleaned = raw
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      final decoded = jsonDecode(cleaned) as List<dynamic>;
      questions = decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      // JSON parse failed — show plain markdown dialog (graceful fallback)
      _showPlainQuizDialog(crop: crop, stage: stage, raw: raw);
      return;
    }

    _showSaveQuizDialog(crop: crop, stage: stage, questions: questions);
  }

  // ── Plain-text fallback when JSON parse fails ────────────────────────────
  void _showPlainQuizDialog({
    required String crop,
    required String stage,
    required String raw,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.quiz, color: Colors.deepPurple),
          const SizedBox(width: 8),
          Expanded(child: Text('Quiz/Essay: $crop ($stage)',
              style: const TextStyle(fontSize: 14))),
        ]),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(child: _AiMarkdownCard(content: raw)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  // ── Structured save-to-quiz-tab dialog ───────────────────────────────────
  void _showSaveQuizDialog({
    required String crop,
    required String stage,
    required List<Map<String, dynamic>> questions,
  }) {
    // Build initial selection state: all selected by default
    final selected = List<bool>.filled(questions.length, true);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          final mcqs   = questions.where((q) => q['type'] == 'mcq').toList();
          final essays = questions.where((q) => q['type'] == 'essay').toList();
          final selectedCount = selected.where((v) => v).length;

          return AlertDialog(
            title: Row(children: [
              const Icon(Icons.quiz, color: Colors.deepPurple),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'Save to Quiz Tab — $crop ($stage)',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              )),
            ]),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Instructions banner
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.deepPurple.shade200),
                      ),
                      child: Row(children: [
                        Icon(Icons.info_outline, color: Colors.deepPurple.shade700, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          'Select the questions you want to add to your class Quiz tab, '
                          'then tap Save. Questions go live immediately for students.',
                          style: TextStyle(fontSize: 12, color: Colors.deepPurple.shade800),
                        )),
                      ]),
                    ),
                    const SizedBox(height: 14),

                    // Select all / none row
                    Row(children: [
                      TextButton(
                        onPressed: () => setDlg(() {
                          for (var i = 0; i < selected.length; i++) {
                            selected[i] = true;
                          }
                        }),
                        child: const Text('Select all'),
                      ),
                      TextButton(
                        onPressed: () => setDlg(() {
                          for (var i = 0; i < selected.length; i++) {
                            selected[i] = false;
                          }
                        }),
                        child: const Text('None'),
                      ),
                      const Spacer(),
                      Text('$selectedCount selected',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ]),

                    // MCQ section
                    if (mcqs.isNotEmpty) ...[
                      _quizSectionHeader('📝 Multiple Choice Questions (MCQ)', Colors.blue),
                      const SizedBox(height: 6),
                      ...mcqs.map((q) {
                        final idx = questions.indexOf(q);
                        return _questionTile(
                          index: idx,
                          question: q,
                          isSelected: selected[idx],
                          onToggle: (v) => setDlg(() => selected[idx] = v ?? false),
                        );
                      }),
                    ],

                    // Essay section
                    if (essays.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _quizSectionHeader('✍️ Essay Questions', Colors.purple),
                      const SizedBox(height: 6),
                      ...essays.map((q) {
                        final idx = questions.indexOf(q);
                        return _questionTile(
                          index: idx,
                          question: q,
                          isSelected: selected[idx],
                          onToggle: (v) => setDlg(() => selected[idx] = v ?? false),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: selectedCount == 0
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        await _saveQuestionsToQuizTab(
                          crop: crop,
                          stage: stage,
                          questions: [
                            for (var i = 0; i < questions.length; i++)
                              if (selected[i]) questions[i],
                          ],
                        );
                      },
                icon: const Icon(Icons.save, size: 16),
                label: Text('Save $selectedCount to Quiz Tab'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _quizSectionHeader(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      );

  Widget _questionTile({
    required int index,
    required Map<String, dynamic> question,
    required bool isSelected,
    required ValueChanged<bool?> onToggle,
  }) {
    final isMcq    = question['type'] == 'mcq';
    final qText    = question['question'] as String? ?? '';
    final options     = (question['options'] as List<dynamic>?)?.cast<String>() ?? [];
    // 'correct' is an int index (0-based) matching QuizQuestion.fromJson format
    final correctIdx  = question['correct'] as int?;
    final correctLetter = correctIdx != null && correctIdx < options.length
        ? String.fromCharCode(65 + correctIdx)   // 0→'A', 1→'B', etc.
        : (question['answer'] as String? ?? ''); // legacy fallback
    final modelAns    = question['modelAnswer'] as String? ?? '';
    final color    = isMcq ? Colors.blue : Colors.purple;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? color.withOpacity(0.5) : Colors.grey.shade300,
          width: isSelected ? 1.5 : 1,
        ),
        color: isSelected ? color.withOpacity(0.04) : Colors.grey.shade50,
      ),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: onToggle,
        activeColor: color,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(qText,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isMcq && options.isNotEmpty) ...[
              const SizedBox(height: 4),
              ...options.map((o) => Text('  $o',
                  style: const TextStyle(fontSize: 12, height: 1.4))),
              const SizedBox(height: 2),
              Text('✓ Answer: $correctLetter',
                  style: TextStyle(fontSize: 12, color: Colors.green.shade700,
                      fontWeight: FontWeight.w600)),
            ],
            if (!isMcq && modelAns.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Model answer: $modelAns',
                  style: TextStyle(fontSize: 12, color: Colors.purple.shade700,
                      fontStyle: FontStyle.italic),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }

  // ── Save selected questions to Firestore field_content ───────────────────
  Future<void> _saveQuestionsToQuizTab({
    required String crop,
    required String stage,
    required List<Map<String, dynamic>> questions,
  }) async {
    if (questions.isEmpty) return;

    // Use _gradeDocRef() so the path is parsed correctly regardless of
    // how many underscores are in the school name.
    final p = _parseClassId(widget.classId);
    if (p['school']!.isEmpty || p['system']!.isEmpty || p['grade']!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot save: invalid class ID'),
              backgroundColor: Colors.red),
        );
      }
      return;
    }
    final contentCol = FirebaseFirestore.instance
        .collection('schools').doc(p['school'])
        .collection('systems').doc(p['system'])
        .collection('grades').doc(p['grade'])
        .collection('field_content');

    // Separate MCQ and essay
    final mcqs   = questions.where((q) => q['type'] == 'mcq').toList();
    final essays = questions.where((q) => q['type'] == 'essay').toList();

    try {
      // Save MCQs as one quiz document (if any selected)
      if (mcqs.isNotEmpty) {
        final hasMixed = essays.isNotEmpty;
        await contentCol.add({
          'type':       'quiz',
          'quizType':   hasMixed ? 'mixed' : 'mcq',
          'title':      'Soil Test MCQ – $crop ($stage)',
          'module':     'Field Data',
          'data':       jsonEncode(mcqs),
          'uploadedBy': _currentUserId ?? '',
          'schoolName': widget.schoolName,
          'classId':    widget.classId,
          'createdAt':  FieldValue.serverTimestamp(),
        });
      }

      // Save essays as a separate quiz document (if any selected)
      if (essays.isNotEmpty && mcqs.isEmpty) {
        await contentCol.add({
          'type':       'quiz',
          'quizType':   'essay',
          'title':      'Soil Test Essay – $crop ($stage)',
          'module':     'Field Data',
          'data':       jsonEncode(essays),
          'uploadedBy': _currentUserId ?? '',
          'schoolName': widget.schoolName,
          'classId':    widget.classId,
          'createdAt':  FieldValue.serverTimestamp(),
        });
      } else if (essays.isNotEmpty && mcqs.isNotEmpty) {
        // Mixed: already saved together above — add essay doc separately so
        // teachers can assign them independently
        await contentCol.add({
          'type':       'quiz',
          'quizType':   'essay',
          'title':      'Soil Test Essay – $crop ($stage)',
          'module':     'Field Data',
          'data':       jsonEncode(essays),
          'uploadedBy': _currentUserId ?? '',
          'schoolName': widget.schoolName,
          'classId':    widget.classId,
          'createdAt':  FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ ${questions.length} question${questions.length == 1 ? '' : 's'} '
              'saved to the Quiz tab!',
            ),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── STUDENT: read-only soil monitoring view ──────────────────────────────
  Widget _buildStudentSoilViewTab() {
    final crop  = _selectedCrop;
    final stage = _selectedStage;

    return SingleChildScrollView(
      controller: _soilTabScrollCtrl,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🧪 Soil Test Monitoring',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryGreen),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade300),
            ),
            child: Row(children: [
              Icon(Icons.visibility, color: Colors.blue.shade700, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'This is a read-only view of soil data entered by your teacher. '
                  'Select a crop and growth stage from the Field Issues tab to see the relevant soil data.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),

          // Crop/Stage banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: (crop != null && stage != null) ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (crop != null && stage != null) ? Colors.green.shade300 : Colors.orange.shade300,
              ),
            ),
            child: (crop == null || stage == null)
                ? Row(children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Go to Field Issues tab → select crop and growth stage first.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ])
                : Row(children: [
                    Icon(Icons.grass, color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(fontSize: 13, color: Colors.green.shade900),
                          children: [
                            const TextSpan(text: 'Crop: ', style: TextStyle(fontWeight: FontWeight.bold)),
                            TextSpan(text: '$crop   '),
                            const TextSpan(text: 'Stage: ', style: TextStyle(fontWeight: FontWeight.bold)),
                            TextSpan(text: stage),
                          ],
                        ),
                      ),
                    ),
                  ]),
          ),
          const SizedBox(height: 16),

          // Teacher soil data for this crop/stage
          if (crop != null && stage != null)
            _buildTeacherSoilDataForStudent(crop, stage),

          // Student name for own observations
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 10),
          const Text(
            '📝 Your Soil Observations (Optional)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryGreen),
          ),
          const SizedBox(height: 4),
          Text(
            'After reviewing the soil data above, record your own observations and ideas.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _soilTestStudentNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Your Name *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _soilObservationsCtrl,
            decoration: const InputDecoration(
              labelText: 'Soil Observations',
              hintText: 'What do you notice about the soil data? What concerns you?',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.visibility),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _soilStudentIdeaCtrl,
            decoration: const InputDecoration(
              labelText: 'Your Corrective Measures',
              hintText: 'What would you recommend to improve the soil?',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lightbulb),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _submitStudentSoilObservation,
              icon: _isSaving
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send),
              label: Text(_isSaving ? 'Submitting…' : 'Submit My Observations'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.all(14),
              ),
            ),
          ),

          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 12),
          const Text(
            '📋 My Soil Observations',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryGreen),
          ),
          const SizedBox(height: 10),
          _buildStudentSoilSubmissions(),
        ],
      ),
    );
  }

  // Shows teacher-entered soil data for the selected crop/stage (student view)
  Widget _buildTeacherSoilDataForStudent(String crop, String stage) {
    return StreamBuilder<QuerySnapshot>(
      // No orderBy → no composite index needed. Sort client-side below.
      stream: _soilTestResultsCollection
          ?.where('submittedBy', isEqualTo: 'teacher')
          .where('crop', isEqualTo: crop)
          .where('stage', isEqualTo: stage)
          .snapshots(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
            child: Text(
              '⚠️ Could not load soil data: ${snapshot.error}',
              style: TextStyle(color: Colors.red.shade800, fontSize: 12),
            ),
          );
        }
        // Sort client-side by submittedAt descending, take latest 5
        final rawDocs = snapshot.data?.docs ?? [];
        final docs = rawDocs.toList()
          ..sort((a, b) {
            final aTs = (a.data() as Map<String, dynamic>)['submittedAt'];
            final bTs = (b.data() as Map<String, dynamic>)['submittedAt'];
            if (aTs == null || bTs == null) return 0;
            return (bTs as Timestamp).compareTo(aTs as Timestamp);
          });
        final limited = docs.take(5).toList();
        if (limited.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
            child: const Text(
              '📭 No soil data entered by your teacher yet for this crop and growth stage.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                  color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
              child: Text(
                '${limited.length} soil test${limited.length == 1 ? '' : 's'} from teacher',
                style: TextStyle(fontSize: 12, color: Colors.green.shade900, fontWeight: FontWeight.bold),
              ),
            ),
            ...limited.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _buildStudentSoilReadOnlyCard(data);
            }),
          ],
        );
      },
    );
  }

  Widget _buildStudentSoilReadOnlyCard(Map<String, dynamic> data) {
    final deficiencies = (data['deficiencies'] as List<dynamic>?) ?? [];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.science, color: Colors.green.shade700),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'Soil Test – ${(data['submittedAt'] as Timestamp?)?.toDate().toString().substring(0, 10) ?? 'Date unknown'}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              )),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: primaryGreen, borderRadius: BorderRadius.circular(12)),
                child: const Text('Teacher Data',
                    style: TextStyle(color: Colors.white, fontSize: 10)),
              ),
            ]),
            const SizedBox(height: 10),
            _soilValueRow('Nitrogen (N)', '${data['nitrogen']?['value']} ppm', data['nitrogen']?['status']),
            _soilValueRow('Phosphorus (P)', '${data['phosphorus']?['value']} ppm', data['phosphorus']?['status']),
            _soilValueRow('Potassium (K)', '${data['potassium']?['value']} ppm', data['potassium']?['status']),
            _soilValueRow('pH', '${data['pH']?['value']}', data['pH']?['status']),
            _soilValueRow('Organic Matter', '${data['organicMatter']?['value']}%', data['organicMatter']?['status']),
            if (deficiencies.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(4)),
                child: Text('⚠️ Deficiencies: ${deficiencies.join(', ')}',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade900, fontWeight: FontWeight.bold)),
              ),
            ],
            if (data['fieldLocation'] != null && (data['fieldLocation'] as String).isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('📍 ${data['fieldLocation']}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _soilValueRow(String label, String value, String? status) {
    Color statusColor;
    switch (status?.toLowerCase()) {
      case 'optimal': statusColor = Colors.green; break;
      case 'low':
      case 'slightly acidic':
      case 'slightly alkaline': statusColor = Colors.orange; break;
      case 'deficient':
      case 'too acidic':
      case 'too alkaline': statusColor = Colors.red; break;
      case 'high':
      case 'excess': statusColor = Colors.deepOrange; break;
      default: statusColor = Colors.grey;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 13))),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        if (status != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(status, style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold)),
          ),
      ]),
    );
  }

  // ── Submit soil test by TEACHER ──────────────────────────────────────────
  Future<void> _submitSoilTestByTeacher() async {
    final crop  = _selectedCrop;
    final stage = _selectedStage;
    if (crop == null || stage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select crop and growth stage in Field Issues tab first')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final nVal  = double.tryParse(_nitrogenCtrl.text)      ?? 0;
      final pVal  = double.tryParse(_phosphorusCtrl.text)    ?? 0;
      final kVal  = double.tryParse(_potassiumCtrl.text)     ?? 0;
      final phVal = double.tryParse(_pHCtrl.text)            ?? 7.0;
      final omVal = double.tryParse(_organicMatterCtrl.text) ?? 0;

      final nStatus  = analyzeNutrientStatus(nVal,  'nitrogen',     crop, stage);
      final pStatus  = analyzeNutrientStatus(pVal,  'phosphorus',   crop, stage);
      final kStatus  = analyzeNutrientStatus(kVal,  'potassium',    crop, stage);
      final phStatus = _getpHStatus(phVal);
      final omStatus = _getOMStatus(omVal);

      final deficiencies = <String>[
        if (nStatus == 'low' || nStatus == 'deficient') 'Nitrogen',
        if (pStatus == 'low' || pStatus == 'deficient') 'Phosphorus',
        if (kStatus == 'low' || kStatus == 'deficient') 'Potassium',
      ];

      await _soilTestResultsCollection?.add({
        'crop':            crop,
        'stage':           stage,
        'testDate':        Timestamp.fromDate(_soilTestDate),
        'fieldLocation':   _soilTestFieldLocationCtrl.text.trim(),
        'submittedBy':     'teacher',
        'savedBy':         _currentUserId,
        'schoolName':      widget.schoolName,
        'className':       widget.classId,
        'nitrogen':        {'value': nVal,  'unit': 'ppm', 'status': nStatus},
        'phosphorus':      {'value': pVal,  'unit': 'ppm', 'status': pStatus},
        'potassium':       {'value': kVal,  'unit': 'ppm', 'status': kStatus},
        'pH':              {'value': phVal, 'status': phStatus},
        'organicMatter':   {'value': omVal, 'unit': '%',   'status': omStatus},
        'deficiencies':    deficiencies,
        'submittedAt':     FieldValue.serverTimestamp(),
      });

      for (final c in [
        _nitrogenCtrl, _phosphorusCtrl, _potassiumCtrl,
        _pHCtrl, _organicMatterCtrl, _soilTestFieldLocationCtrl,
      ]) { c.clear(); }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Soil data saved! Students can now view it.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // ── Submit student's own soil observations (response to teacher data) ──
  Future<void> _submitStudentSoilObservation() async {
    final name = _soilTestStudentNameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name first')),
      );
      return;
    }
    final obs  = _soilObservationsCtrl.text.trim();
    final idea = _soilStudentIdeaCtrl.text.trim();
    if (obs.isEmpty && idea.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your observations or corrective measures')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _soilTestResultsCollection?.add({
        'crop':             _selectedCrop ?? '',
        'stage':            _selectedStage ?? '',
        'submittedBy':      'student',
        'studentName':      name,
        'schoolName':       widget.schoolName,
        'className':        widget.classId,
        'soilObservations': obs,
        'soilStudentIdea':  idea,
        'reviewStatus':     'pending',
        'submittedAt':      FieldValue.serverTimestamp(),
        // NPK fields empty — teacher fills those
        'nitrogen':         null,
        'phosphorus':       null,
        'potassium':        null,
        'pH':               null,
        'organicMatter':    null,
        'deficiencies':     [],
      });

      _soilObservationsCtrl.clear();
      _soilStudentIdeaCtrl.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Observations submitted!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  String _getpHStatus(double v) {
    if (v < 5.5) return 'Too Acidic';
    if (v < 6.0) return 'Slightly Acidic';
    if (v <= 7.0) return 'Optimal';
    if (v <= 7.5) return 'Slightly Alkaline';
    return 'Too Alkaline';
  }

  String _getOMStatus(double v) {
    if (v < 2) return 'Low';
    if (v <= 5) return 'Moderate';
    return 'High';
  }

  // ── Nutrient field with colour + optimal hint ────────────────────────────
  Widget _buildNutrientField(
    String label,
    TextEditingController ctrl,
    String nutrientKey,
    String unit,
  ) {
    final crop  = _selectedCrop;
    final stage = _selectedStage;
    final hasCtx = crop != null && stage != null;

    Color fillColor    = Colors.grey.shade100;
    String statusLabel = '';
    String optimalHint = '';

    if (hasCtx && ctrl.text.isNotEmpty) {
      final val = double.tryParse(ctrl.text);
      if (val != null) {
        final status = analyzeNutrientStatus(val, nutrientKey, crop, stage);
        statusLabel = _statusLabel(status);
        fillColor   = _statusColor(status);
      }
    }

    if (hasCtx) {
      final ranges = getOptimalRanges(crop, stage);
      if (ranges != null && ranges.containsKey(nutrientKey)) {
        final r   = ranges[nutrientKey]!;
        final mn  = r['min'];
        final mx  = r['max'];
        final opt = r['optimal'];
        optimalHint = 'Optimal: $opt $unit   Range: $mn – $mx $unit';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: ctrl,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.science),
            suffixText: unit,
            fillColor: fillColor,
            filled: true,
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        if (optimalHint.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 3, left: 12),
            child: Text(optimalHint,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ),
        if (statusLabel.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 12),
            child: Text(statusLabel,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'deficient': return Colors.red.shade100;
      case 'low':       return Colors.orange.shade100;
      case 'optimal':   return Colors.green.shade100;
      case 'high':      return Colors.yellow.shade100;
      case 'excess':    return Colors.deepOrange.shade100;
      default:          return Colors.grey.shade100;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'deficient': return '❌ Deficient';
      case 'low':       return '⚠️ Low';
      case 'optimal':   return '✅ Optimal';
      case 'high':      return '⚡ High';
      case 'excess':    return '🔴 Excess';
      default:          return '';
    }
  }

  // ── Student soil submissions (observation responses) ─────────────────────
  Widget _buildStudentSoilSubmissions() {
    final studentName = _soilTestStudentNameCtrl.text.trim();

    if (studentName.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
        child: const Text('👆 Enter your name above to see your submitted observations'),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      // No orderBy → no composite index needed. Sorted client-side below.
      stream: _soilTestResultsCollection
          ?.where('submittedBy', isEqualTo: 'student')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData) return const Text('No data available');

        final allDocs = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final aTs = (a.data() as Map<String, dynamic>)['submittedAt'];
            final bTs = (b.data() as Map<String, dynamic>)['submittedAt'];
            if (aTs == null || bTs == null) return 0;
            return (bTs as Timestamp).compareTo(aTs as Timestamp);
          });

        final mine = allDocs.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          return d['studentName']?.toString().trim() == studentName;
        }).toList();

        if (mine.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
            child: Column(children: [
              const Icon(Icons.inbox_outlined, size: 40, color: Colors.grey),
              const SizedBox(height: 8),
              const Text('No observations submitted yet'),
              Text('Looking for: "$studentName"',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ]),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
              child: Text(
                '${mine.length} observation${mine.length == 1 ? '' : 's'} submitted',
                style: TextStyle(fontSize: 12, color: Colors.green.shade900, fontWeight: FontWeight.bold),
              ),
            ),
            ...mine.map((doc) =>
                _buildStudentSoilCard(doc.id, doc.data() as Map<String, dynamic>)),
          ],
        );
      },
    );
  }

  Widget _buildStudentSoilCard(String docId, Map<String, dynamic> data) {
    final isReviewed              = data['reviewStatus'] == 'reviewed';
    final reviewUnlocked          = data['reviewUnlocked'] == true;
    final recommendationsUnlocked = data['recommendationsUnlocked'] == true;
    final soilObs                 = data['soilObservations']?.toString();
    final soilIdea                = data['soilStudentIdea']?.toString();
    final teacherComment          = data['teacherComment']?.toString();
    final studentReply            = data['soilStudentReply']?.toString();
    final teacherFollowUp         = data['soilTeacherFollowUp']?.toString();
    final studentReply2           = data['soilStudentReply2']?.toString();
    final teacherFollowUp2        = data['soilTeacherFollowUp2']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.science, color: Colors.green.shade700),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'Observation – ${(data['submittedAt'] as Timestamp?)?.toDate().toString().substring(0, 16) ?? 'Unknown'}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              )),
              if (isReviewed && reviewUnlocked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: _getGradeColor(data['teacherGrade']),
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(_getGradeLabel(data['teacherGrade']),
                      style: const TextStyle(color: Colors.white, fontSize: 11)),
                ),
            ]),
            const SizedBox(height: 10),

            if (soilObs != null && soilObs.isNotEmpty)
              _colorBox(Colors.blue, 'Your soil observations:', Icons.visibility, soilObs),
            if (soilIdea != null && soilIdea.isNotEmpty) ...[
              const SizedBox(height: 8),
              _colorBox(Colors.teal, 'Your corrective measures:', Icons.lightbulb, soilIdea),
            ],
            if (isReviewed && reviewUnlocked && teacherComment != null) ...[
              const SizedBox(height: 8),
              _colorBox(Colors.green, 'Teacher notes:', Icons.school, teacherComment),
            ],
            if (studentReply != null) ...[
              const SizedBox(height: 8),
              _colorBox(Colors.purple, 'Your reply:', Icons.reply, studentReply),
            ],
            if (teacherFollowUp != null) ...[
              const SizedBox(height: 8),
              _colorBox(Colors.amber, 'Teacher follow-up:', Icons.chat_bubble_outline, teacherFollowUp),
            ],
            if (studentReply2 != null) ...[
              const SizedBox(height: 8),
              _colorBox(Colors.purple, 'Your reply:', Icons.reply, studentReply2),
            ],
            if (teacherFollowUp2 != null) ...[
              const SizedBox(height: 8),
              _colorBox(Colors.amber, 'Teacher follow-up:', Icons.chat_bubble_outline, teacherFollowUp2),
            ],

            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: [
              if (isReviewed && reviewUnlocked && teacherComment != null && studentReply == null)
                ElevatedButton.icon(
                  onPressed: () => _showSoilStudentReplyDialog(docId, data, replyNumber: 1),
                  icon: const Icon(Icons.reply, size: 15),
                  label: const Text('Reply to Teacher', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  ),
                ),
              if (teacherFollowUp != null && studentReply2 == null)
                ElevatedButton.icon(
                  onPressed: () => _showSoilStudentReplyDialog(docId, data, replyNumber: 2),
                  icon: const Icon(Icons.reply, size: 15),
                  label: const Text('Reply to Follow-up', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  ),
                ),
              if (recommendationsUnlocked)
                ElevatedButton.icon(
                  onPressed: () { setState(() => _soilAnalysis = data); _showRecommendationsDialog(); },
                  icon: const Icon(Icons.lightbulb, size: 15),
                  label: const Text('View Recommendations', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  ),
                ),
              // AI analysis button for student soil observations
              if (isReviewed)
                ElevatedButton.icon(
                  onPressed: _isCardLoading('soilstudent_$docId')
                      ? null
                      : () => _runAiSoilAnalysisForStudent(data, docId),
                  icon: _isCardLoading('soilstudent_$docId')
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.auto_awesome, size: 15),
                  label: const Text('AI Analysis', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  ),
                ),
            ]),
          ],
        ),
      ),
    );
  }

  // AI analysis for student soil observation response
  Future<void> _runAiSoilAnalysisForStudent(Map<String, dynamic> data, String docId) async {
    final prompt = '''
A Kenyan secondary school student submitted soil monitoring observations. Provide educational feedback.

Crop: ${data['crop'] ?? ''}
Growth Stage: ${data['stage'] ?? ''}
Student's Soil Observations: ${data['soilObservations'] ?? '(none)'}
Student's Proposed Corrective Measures: ${data['soilStudentIdea'] ?? '(none)'}
Teacher's Notes: ${data['teacherComment'] ?? '(none)'}

Please:
1. Evaluate whether the student's observations show good understanding of what to look for in soil assessment.
2. Assess whether their proposed corrective measures are appropriate.
3. Explain the science behind the best corrective actions for this crop and stage.
4. Suggest one follow-up activity or experiment the student can do to deepen their understanding.
5. Use encouraging, educational language appropriate for secondary school students in Kenya.
''';

    final loadKey = 'soilstudent_$docId';
    final savedPos = _soilTabScrollCtrl.hasClients ? _soilTabScrollCtrl.offset : 0.0;
    _setCardLoading(loadKey, true);
    final result = await _callAI(
      'You are a friendly Kenyan agriculture teacher and soil scientist. '
      'Provide encouraging, educational feedback on student work.\n\n'
      '$prompt',
    );
    _setCardLoading(loadKey, false);
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted && _soilTabScrollCtrl.hasClients) {
        _soilTabScrollCtrl.jumpTo(savedPos);
      }
    });

    if (!mounted) return;
    _showAiResultDialog(
      title: '🤖 AI Soil Observation Feedback',
      result: result,
    );
  }

  Future<void> _showSoilStudentReplyDialog(String docId, Map<String, dynamic> data,
      {int replyNumber = 1}) async {
    final ctrl = TextEditingController();
    final isSecond     = replyNumber == 2;
    final contextText  = isSecond ? (data['soilTeacherFollowUp'] ?? '') : (data['teacherComment'] ?? '');
    final contextLabel = isSecond ? 'Teacher follow-up:' : 'Teacher notes:';
    final dialogTitle  = isSecond ? 'Reply to Follow-up' : 'Reply to Teacher';
    final buttonColor  = isSecond ? Colors.deepPurple : Colors.purple;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.reply, color: buttonColor), const SizedBox(width: 8),
          Expanded(child: Text(dialogTitle)),
        ]),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          _colorBox(Colors.green, contextLabel, Icons.school, contextText),
          const SizedBox(height: 14),
          TextField(
            controller: ctrl,
            decoration: InputDecoration(
              labelText: 'Your Reply',
              hintText: isSecond
                  ? "Respond to the teacher's follow-up…"
                  : "Ask a question or respond to the teacher's notes…",
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.edit),
            ),
            maxLines: 4,
            autofocus: true,
          ),
          const SizedBox(height: 6),
          Text('The teacher will see your reply.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () async {
              final reply = ctrl.text.trim();
              if (reply.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a reply')));
                return;
              }
              try {
                final fields = isSecond
                    ? {'soilStudentReply2': reply, 'soilStudentRepliedAt2': FieldValue.serverTimestamp()}
                    : {'soilStudentReply': reply, 'soilStudentRepliedAt': FieldValue.serverTimestamp()};
                await _soilTestResultsCollection?.doc(docId).update(fields);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Reply sent to teacher!'), backgroundColor: Colors.green),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                );
              }
            },
            icon: const Icon(Icons.send),
            label: const Text('Send Reply'),
            style: ElevatedButton.styleFrom(backgroundColor: buttonColor, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  void _showRecommendationsDialog() {
    if (_soilAnalysis == null) return;
    final crop         = _soilAnalysis!['crop'];
    final deficiencies = (_soilAnalysis!['deficiencies'] as List<dynamic>?) ?? [];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.recommend, color: Colors.green), SizedBox(width: 8),
          Expanded(child: Text('Fertilizer Recommendations')),
        ]),
        content: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('Crop: $crop', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            if (deficiencies.isEmpty)
              const Text('✅ No deficiencies detected. Soil is in good condition!')
            else ...[
              Text('Deficiencies: ${deficiencies.join(', ')}',
                  style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              ...deficiencies.map((def) {
                final key  = '${def.toString().toLowerCase()}_deficient';
                final recs = fertilizerRecommendations[key];
                return recs == null ? const SizedBox.shrink() : _buildFertilizerSection(def.toString(), recs);
              }),
            ],
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  Widget _buildFertilizerSection(String nutrient, Map<String, dynamic> recs) {
    final chemical = recs['chemical'] as List<dynamic>?;
    final organic  = recs['organic']  as List<dynamic>?;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('💊 For $nutrient Deficiency:',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      const SizedBox(height: 8),
      if (chemical != null && chemical.isNotEmpty) ...[
        const Text('🧪 Chemical Options:', style: TextStyle(fontWeight: FontWeight.bold)),
        ...chemical.map((c) => Padding(
              padding: const EdgeInsets.only(left: 14, top: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('• ${c['name']}', style: const TextStyle(fontWeight: FontWeight.w500)),
                Text('  Rate: ${c['rate']}', style: const TextStyle(fontSize: 12)),
                Text('  ${c['timing']}',     style: const TextStyle(fontSize: 12)),
              ]),
            )),
        const SizedBox(height: 10),
      ],
      if (organic != null && organic.isNotEmpty) ...[
        const Text('🌿 Organic Solutions:', style: TextStyle(fontWeight: FontWeight.bold)),
        ...organic.map((o) => Padding(
              padding: const EdgeInsets.only(left: 14, top: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('• ${o['name']}', style: const TextStyle(fontWeight: FontWeight.w500)),
                Text('  Rate: ${o['rate']}', style: const TextStyle(fontSize: 12)),
                Text('  ${o['timing']}',     style: const TextStyle(fontSize: 12)),
              ]),
            )),
      ],
      const SizedBox(height: 14),
      const Divider(),
      const SizedBox(height: 6),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  REVIEWS TAB (teachers only)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildReviewsTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: primaryGreen,
            unselectedLabelColor: Colors.grey,
            indicatorColor: primaryGreen,
            tabs: const [Tab(text: 'Field Issues'), Tab(text: 'Soil Observations')],
          ),
          Expanded(
            child: TabBarView(children: [_buildFieldReviewsList(), _buildSoilReviewsList()]),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldReviewsList() {
    return StreamBuilder<QuerySnapshot>(
      // No orderBy → no composite index needed. Sorted client-side below.
      stream: _fieldSubmissionsCollection
          ?.where('submittedBy', isEqualTo: 'student')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final sorted = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final aTs = (a.data() as Map<String, dynamic>)['submittedAt'];
            final bTs = (b.data() as Map<String, dynamic>)['submittedAt'];
            if (aTs == null || bTs == null) return 0;
            return (bTs as Timestamp).compareTo(aTs as Timestamp);
          });
        if (sorted.isEmpty) {
          return const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No field issue submissions yet')));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: sorted.length,
          itemBuilder: (ctx, i) {
            final doc = sorted[i];
            return _buildFieldReviewCard(doc.id, doc.data() as Map<String, dynamic>);
          },
        );
      },
    );
  }

  Widget _buildFieldReviewCard(String docId, Map<String, dynamic> data) {
    final isReviewed      = data['reviewStatus'] == 'reviewed';
    final hasStudentReply = data['studentReply'] != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _showFieldReviewDialog(docId, data),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(isReviewed ? Icons.check_circle : Icons.pending,
                  color: isReviewed ? Colors.green : Colors.orange),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(data['studentName'] ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${data['crop']} – ${data['issue']}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ])),
              if (hasStudentReply)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.purple, borderRadius: BorderRadius.circular(12)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.reply, size: 11, color: Colors.white),
                    SizedBox(width: 3),
                    Text('Replied', style: TextStyle(color: Colors.white, fontSize: 11)),
                  ]),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: isReviewed ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(12)),
                child: Text(isReviewed ? 'Reviewed' : 'Pending',
                    style: const TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ]),
            const SizedBox(height: 8),
            Text('Student idea: ${data['studentIdea'] ?? ''}',
                style: const TextStyle(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
            if (hasStudentReply) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(4)),
                child: Text('Student replied: ${data['studentReply']}',
                    style: TextStyle(fontSize: 12, color: Colors.purple.shade900),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Future<void> _showFieldReviewDialog(String docId, Map<String, dynamic> data) async {
    String? selectedGrade = data['teacherGrade'];
    final commentCtrl     = TextEditingController(text: data['teacherComment']  ?? '');
    final followUpCtrl    = TextEditingController(text: data['teacherFollowUp'] ?? '');
    bool unlockReview     = data['reviewUnlocked'] ?? false;
    bool unlockHints      = data['hintsUnlocked']  ?? false;
    final hasStudentReply = data['studentReply'] != null;
    bool localAiLoading   = false;
    String aiDraft        = '';

    await showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlg) => AlertDialog(
          title: const Text('Review Field Issue'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Student: ${data['studentName'] ?? ''}'),
              Text('Issue: ${data['crop']} – ${data['issue']}'),
              const SizedBox(height: 12),
              Text('Observation: ${data['studentObservation'] ?? ''}'),
              const SizedBox(height: 6),
              Text("Student's idea: ${data['studentIdea'] ?? ''}",
                  style: const TextStyle(fontWeight: FontWeight.bold)),

              if (hasStudentReply) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.purple.shade200)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.reply, size: 15, color: Colors.purple.shade700),
                      const SizedBox(width: 4),
                      Text('Student replied:',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple.shade900)),
                    ]),
                    const SizedBox(height: 6),
                    Text(data['studentReply'] ?? ''),
                  ]),
                ),
              ],

              const SizedBox(height: 12),
              // AI draft button
              if (aiDraft.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.auto_awesome, size: 14, color: Colors.deepPurple),
                      const SizedBox(width: 4),
                      const Text('AI draft (tap to use):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => setDlg(() { commentCtrl.text = aiDraft; }),
                      child: Text(aiDraft, style: const TextStyle(fontSize: 12)),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton.icon(
                onPressed: localAiLoading ? null : () async {
                  setDlg(() => localAiLoading = true);
                  final draft = await _callAI(
                    'You are an experienced Kenyan secondary school agriculture teacher. '
                    'Write concise, educational, encouraging feedback for a student.\n\n'
                    '''Student: ${data['studentName'] ?? ''}
Crop: ${data['crop']}  Stage: ${data['stage']}  Issue: ${data['issue']}
Student observation: ${data['studentObservation'] ?? ''}
Student idea: ${data['studentIdea'] ?? ''}
${hasStudentReply ? 'Student reply: ${data['studentReply']}' : ''}

Write a 2–3 sentence teaching comment/question for this student. Be encouraging.''',
                  );
                  setDlg(() { localAiLoading = false; aiDraft = draft; });
                },
                icon: localAiLoading
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome, size: 14),
                label: const Text('🤖 AI Draft Comment', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.deepPurple)),
              ),

              const SizedBox(height: 14),
              const Text('Grade:', style: TextStyle(fontWeight: FontWeight.bold)),
              Row(children: [
                _buildGradeButton('correct',   selectedGrade, (g) => setDlg(() => selectedGrade = g)),
                const SizedBox(width: 8),
                _buildGradeButton('needsWork', selectedGrade, (g) => setDlg(() => selectedGrade = g)),
                const SizedBox(width: 8),
                _buildGradeButton('incorrect', selectedGrade, (g) => setDlg(() => selectedGrade = g)),
              ]),
              const SizedBox(height: 14),

              TextField(
                controller: commentCtrl,
                decoration: const InputDecoration(
                  labelText: 'Teaching Notes / Question',
                  border: OutlineInputBorder(),
                  hintText: 'Ask a follow-up question or provide feedback',
                ),
                maxLines: 3,
              ),

              if (hasStudentReply) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: followUpCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Follow-up Response',
                    border: OutlineInputBorder(),
                    hintText: "Respond to student's reply",
                    prefixIcon: Icon(Icons.chat_bubble_outline),
                  ),
                  maxLines: 3,
                ),
              ],

              const SizedBox(height: 12),
              CheckboxListTile(
                title: const Text('Unlock Review'),
                value: unlockReview,
                onChanged: (v) => setDlg(() => unlockReview = v ?? false),
                dense: true,
              ),
              CheckboxListTile(
                title: const Text('Unlock Expert Hints'),
                value: unlockHints,
                onChanged: (v) => setDlg(() => unlockHints = v ?? false),
                dense: true,
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (selectedGrade == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a grade')));
                  return;
                }
                try {
                  final Map<String, dynamic> update = {
                    'reviewStatus':  'reviewed',
                    'teacherGrade':  selectedGrade,
                    'teacherComment': commentCtrl.text,
                    'reviewUnlocked': unlockReview,
                    'hintsUnlocked':  unlockHints,
                    'reviewedAt':    FieldValue.serverTimestamp(),
                    'reviewedBy':    _currentUserId,
                  };
                  if (hasStudentReply && followUpCtrl.text.trim().isNotEmpty) {
                    update['teacherFollowUp']   = followUpCtrl.text.trim();
                    update['teacherFollowUpAt'] = FieldValue.serverTimestamp();
                  }
                  await _fieldSubmissionsCollection?.doc(docId).update(update);
                  Navigator.pop(dlgCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Review saved!'), backgroundColor: Colors.green),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Save Review'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoilReviewsList() {
    return StreamBuilder<QuerySnapshot>(
      // No orderBy → no composite index needed. Sorted client-side below.
      stream: _soilTestResultsCollection
          ?.where('submittedBy', isEqualTo: 'student')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final sorted = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final aTs = (a.data() as Map<String, dynamic>)['submittedAt'];
            final bTs = (b.data() as Map<String, dynamic>)['submittedAt'];
            if (aTs == null || bTs == null) return 0;
            return (bTs as Timestamp).compareTo(aTs as Timestamp);
          });
        if (sorted.isEmpty) {
          return const Center(
            child: Padding(padding: EdgeInsets.all(32), child: Text('No student soil observations yet')),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: sorted.length,
          itemBuilder: (ctx, i) {
            final doc = sorted[i];
            return _buildSoilReviewCard(doc.id, doc.data() as Map<String, dynamic>);
          },
        );
      },
    );
  }

  Widget _buildSoilReviewCard(String docId, Map<String, dynamic> data) {
    final isReviewed      = data['reviewStatus'] == 'reviewed';
    final hasStudentReply = data['soilStudentReply'] != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _showSoilReviewDialog(docId, data),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(isReviewed ? Icons.check_circle : Icons.pending,
                  color: isReviewed ? Colors.green : Colors.orange),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(data['studentName'] ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${data['crop']} – ${data['stage']}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ])),
              if (hasStudentReply)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.purple, borderRadius: BorderRadius.circular(12)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.reply, size: 11, color: Colors.white),
                    SizedBox(width: 3),
                    Text('Replied', style: TextStyle(color: Colors.white, fontSize: 11)),
                  ]),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: isReviewed ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(12)),
                child: Text(isReviewed ? 'Reviewed' : 'Pending',
                    style: const TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ]),
            const SizedBox(height: 8),
            if (data['soilObservations'] != null)
              Text('Observations: ${data['soilObservations']}',
                  style: const TextStyle(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ),
    );
  }

  Future<void> _showSoilReviewDialog(String docId, Map<String, dynamic> data) async {
    String? selectedGrade           = data['teacherGrade'];
    final commentCtrl               = TextEditingController(text: data['teacherComment']     ?? '');
    final followUpCtrl              = TextEditingController(text: data['soilTeacherFollowUp'] ?? '');
    bool unlockReview               = data['reviewUnlocked']          ?? false;
    bool unlockRecommendations      = data['recommendationsUnlocked'] ?? false;
    final hasStudentReply           = data['soilStudentReply'] != null;
    bool localAiLoading             = false;
    String aiDraft                  = '';

    await showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlg) => AlertDialog(
          title: const Text('Review Soil Observation'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Student: ${data['studentName'] ?? ''}'),
              Text('Crop: ${data['crop']} – ${data['stage']}'),
              const SizedBox(height: 12),

              if (data['soilObservations'] != null) ...[
                const Text('Soil Observations:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(data['soilObservations'] ?? ''),
                const SizedBox(height: 8),
              ],
              if (data['soilStudentIdea'] != null) ...[
                const Text("Student's corrective measures:", style: TextStyle(fontWeight: FontWeight.bold)),
                Text(data['soilStudentIdea'] ?? ''),
              ],

              if (hasStudentReply) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.purple.shade200)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.reply, size: 15, color: Colors.purple.shade700),
                      const SizedBox(width: 4),
                      Text('Student replied:',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple.shade900)),
                    ]),
                    const SizedBox(height: 6),
                    Text(data['soilStudentReply'] ?? ''),
                  ]),
                ),
              ],

              const SizedBox(height: 12),
              // AI draft
              if (aiDraft.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.auto_awesome, size: 14, color: Colors.deepPurple),
                      const SizedBox(width: 4),
                      const Text('AI draft (tap to use):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => setDlg(() { commentCtrl.text = aiDraft; }),
                      child: Text(aiDraft, style: const TextStyle(fontSize: 12)),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton.icon(
                onPressed: localAiLoading ? null : () async {
                  setDlg(() => localAiLoading = true);
                  final draft = await _callAI(
                    'You are an experienced Kenyan secondary school agriculture teacher and soil scientist.\n\n'
                    '''Student: ${data['studentName'] ?? ''}
Crop: ${data['crop']}  Stage: ${data['stage']}
Student soil observations: ${data['soilObservations'] ?? ''}
Student corrective measures: ${data['soilStudentIdea'] ?? ''}
${hasStudentReply ? 'Student reply: ${data['soilStudentReply']}' : ''}

Write a 2–3 sentence teaching comment for this student's soil observation. Be encouraging and educational.''',
                  );
                  setDlg(() { localAiLoading = false; aiDraft = draft; });
                },
                icon: localAiLoading
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome, size: 14),
                label: const Text('🤖 AI Draft Comment', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.deepPurple)),
              ),

              const SizedBox(height: 14),
              const Text('Grade:', style: TextStyle(fontWeight: FontWeight.bold)),
              Row(children: [
                _buildGradeButton('correct',   selectedGrade, (g) => setDlg(() => selectedGrade = g)),
                const SizedBox(width: 8),
                _buildGradeButton('needsWork', selectedGrade, (g) => setDlg(() => selectedGrade = g)),
                const SizedBox(width: 8),
                _buildGradeButton('incorrect', selectedGrade, (g) => setDlg(() => selectedGrade = g)),
              ]),
              const SizedBox(height: 14),

              TextField(
                controller: commentCtrl,
                decoration: const InputDecoration(
                  labelText: 'Teaching Notes / Question',
                  border: OutlineInputBorder(),
                  hintText: 'Ask a follow-up question or provide feedback',
                ),
                maxLines: 3,
              ),

              if (hasStudentReply) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: followUpCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Follow-up Response',
                    border: OutlineInputBorder(),
                    hintText: "Respond to student's reply",
                    prefixIcon: Icon(Icons.chat_bubble_outline),
                  ),
                  maxLines: 3,
                ),
              ],

              const SizedBox(height: 12),
              CheckboxListTile(
                title: const Text('Unlock Review'),
                value: unlockReview,
                onChanged: (v) => setDlg(() => unlockReview = v ?? false),
                dense: true,
              ),
              CheckboxListTile(
                title: const Text('Unlock Recommendations'),
                value: unlockRecommendations,
                onChanged: (v) => setDlg(() => unlockRecommendations = v ?? false),
                dense: true,
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (selectedGrade == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a grade')));
                  return;
                }
                try {
                  final Map<String, dynamic> update = {
                    'reviewStatus':            'reviewed',
                    'teacherGrade':            selectedGrade,
                    'teacherComment':          commentCtrl.text,
                    'reviewUnlocked':          unlockReview,
                    'recommendationsUnlocked': unlockRecommendations,
                    'reviewedAt':              FieldValue.serverTimestamp(),
                    'reviewedBy':              _currentUserId,
                  };
                  if (hasStudentReply && followUpCtrl.text.trim().isNotEmpty) {
                    update['soilTeacherFollowUp']   = followUpCtrl.text.trim();
                    update['soilTeacherFollowUpAt'] = FieldValue.serverTimestamp();
                  }
                  await _soilTestResultsCollection?.doc(docId).update(update);
                  Navigator.pop(dlgCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Review saved!'), backgroundColor: Colors.green),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Save Review'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Grade helpers ────────────────────────────────────────────────────────
  Widget _buildGradeButton(String grade, String? selectedGrade, void Function(String) onSelect) {
    final isSelected = selectedGrade == grade;
    Color color; String label; IconData icon;
    switch (grade) {
      case 'correct':   color = Colors.green;  label = '✅'; icon = Icons.check_circle; break;
      case 'needsWork': color = Colors.orange; label = '⚠️'; icon = Icons.warning;      break;
      case 'incorrect': color = Colors.red;    label = '❌'; icon = Icons.cancel;        break;
      default:          color = Colors.grey;   label = '?';  icon = Icons.help;
    }
    return Expanded(
      child: OutlinedButton(
        onPressed: () => onSelect(grade),
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected ? color.withOpacity(0.1) : null,
          side: BorderSide(color: isSelected ? color : Colors.grey, width: isSelected ? 2 : 1),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 3),
          Text(_getGradeWordLabel(grade), style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  Color _getGradeColor(String? grade) {
    switch (grade) {
      case 'correct':   return Colors.green;
      case 'needsWork': return Colors.orange;
      case 'incorrect': return Colors.red;
      default:          return Colors.grey;
    }
  }

  String _getGradeWordLabel(String grade) {
    switch (grade) {
      case 'correct':   return 'Correct';
      case 'needsWork': return 'Needs Work';
      case 'incorrect': return 'Incorrect';
      default:          return grade;
    }
  }

  String _getGradeLabel(String? grade) {
    switch (grade) {
      case 'correct':   return '✅ Correct';
      case 'needsWork': return '⚠️ Needs Work';
      case 'incorrect': return '❌ Incorrect';
      default:          return 'Pending';
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: const Text(
          'Field Data Input',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: TabBar(
            controller: _tabController,
            tabs: [
              const Tab(icon: Icon(Icons.report_problem, size: 18), text: 'Field Issues'),
              Tab(
                icon: Icon(isTeacher ? Icons.science : Icons.visibility, size: 18),
                text: isTeacher ? 'Soil Testing' : 'Soil Data',
              ),
              if (isTeacher)
                const Tab(icon: Icon(Icons.rate_review, size: 18), text: 'Reviews'),
            ],
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            labelStyle: const TextStyle(fontSize: 11),
            tabAlignment: TabAlignment.fill,
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFieldIssuesTab(),
          _buildSoilTestingTab(),
          if (isTeacher) _buildReviewsTab(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  _AiMarkdownCard — renders Gemini markdown responses beautifully
// ═══════════════════════════════════════════════════════════════════════════
class _AiMarkdownCard extends StatelessWidget {
  final String content;
  const _AiMarkdownCard({required this.content});

  static const List<Color> _sectionBg = [
    Color(0xFFE8F5E9), Color(0xFFE3F2FD), Color(0xFFFFF8E1),
    Color(0xFFFCE4EC), Color(0xFFEDE7F6), Color(0xFFE0F7FA),
  ];
  static const List<Color> _sectionBorder = [
    Color(0xFF2E7D32), Color(0xFF1565C0), Color(0xFFF9A825),
    Color(0xFFC62828), Color(0xFF6A1B9A), Color(0xFF00695C),
  ];
  static const List<Color> _sectionTitle = [
    Color(0xFF1B5E20), Color(0xFF0D47A1), Color(0xFFE65100),
    Color(0xFFB71C1C), Color(0xFF4A148C), Color(0xFF004D40),
  ];

  @override
  Widget build(BuildContext context) {
    final sections = _parseSections(content);
    if (sections.isEmpty) return _plainText(content);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections.asMap().entries.map((entry) {
        final i = entry.key % _sectionBg.length;
        final s = entry.value;
        if (s['type'] == 'intro') {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8E9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF81C784)),
              ),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline,
                        color: Color(0xFF2E7D32), size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: _renderBody(s['body'] ?? '')),
                  ]),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Container(
            decoration: BoxDecoration(
              color: _sectionBg[i],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _sectionBorder[i].withOpacity(0.5), width: 1.5),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _sectionBorder[i].withOpacity(0.12),
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(11),
                      topRight: Radius.circular(11)),
                ),
                child: Row(children: [
                  Icon(_sectionIcon(s['title'] ?? ''),
                      color: _sectionTitle[i], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(
                    _cleanTitle(s['title'] ?? ''),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _sectionTitle[i]),
                  )),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: _renderBody(s['body'] ?? ''),
              ),
            ]),
          ),
        );
      }).toList(),
    );
  }

  List<Map<String, String>> _parseSections(String raw) {
    final lines = raw.split('\n');
    final sections = <Map<String, String>>[];
    String? currentTitle;
    final bodyBuf = StringBuffer();

    void flush() {
      final body = bodyBuf.toString().trim();
      if (body.isEmpty && currentTitle == null) return;
      sections.add({
        'type': currentTitle == null ? 'intro' : 'section',
        'title': currentTitle ?? '',
        'body': body,
      });
      bodyBuf.clear();
      currentTitle = null;
    }

    for (final line in lines) {
      if (RegExp(r'^#{1,3}\s').hasMatch(line)) {
        flush();
        currentTitle = line.replaceFirst(RegExp(r'^#+\s*'), '');
      } else {
        bodyBuf.writeln(line);
      }
    }
    flush();
    return sections;
  }

  Widget _renderBody(String text) {
    final lines = text.split('\n');
    final widgets = <Widget>[];
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) { widgets.add(const SizedBox(height: 4)); continue; }
      final numMatch = RegExp(r'^(\d+)\.\s+(.+)').firstMatch(line);
      if (numMatch != null) {
        widgets.add(_bulletRow(
            '${numMatch.group(1)}.',  numMatch.group(2)!, numbered: true));
        continue;
      }
      if (line.startsWith('- ') || line.startsWith('* ') ||
          line.startsWith('• ')) {
        final t = line.replaceFirst(RegExp(r'^[-*•]\s+'), '');
        widgets.add(_bulletRow('•', t, numbered: false));
        continue;
      }
      if (line.startsWith('**') && line.endsWith('**') && line.length > 4) {
        final inner = line.substring(2, line.length - 2);
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(inner,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.black87)),
        ));
        continue;
      }
      widgets.add(
          Padding(padding: const EdgeInsets.only(bottom: 3), child: _inlineBold(line)));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  Widget _bulletRow(String marker, String text, {required bool numbered}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 5, left: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: numbered ? 22 : 16,
            child: Text(marker,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        numbered ? FontWeight.bold : FontWeight.normal,
                    color: numbered
                        ? const Color(0xFF1B5E20)
                        : Colors.black54)),
          ),
          Expanded(child: _inlineBold(text)),
        ]),
      );

  Widget _inlineBold(String text) {
    final spans = <TextSpan>[];
    final re = RegExp(r'\*\*(.+?)\*\*');
    int last = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      spans.add(TextSpan(
          text: m.group(1),
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Colors.black87)));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return RichText(
        text: TextSpan(
            style: const TextStyle(
                fontSize: 13, color: Colors.black87, height: 1.45),
            children: spans));
  }

  Widget _plainText(String t) =>
      Text(t, style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.45));

  String _cleanTitle(String t) => t.replaceAll(RegExp(r'^[#*]+\s*'), '').trim();

  IconData _sectionIcon(String title) {
    final t = title.toLowerCase();
    if (t.contains('chemical') || t.contains('pesticide') || t.contains('fungicid')) return Icons.science;
    if (t.contains('organic') || t.contains('bio') || t.contains('natural')) return Icons.eco;
    if (t.contains('cultural') || t.contains('prevent') || t.contains('practice')) return Icons.agriculture;
    if (t.contains('diagnos') || t.contains('symptom') || t.contains('sign')) return Icons.search;
    if (t.contains('soil') || t.contains('nutrient') || t.contains('fertiliz')) return Icons.grass;
    if (t.contains('economic') || t.contains('threshold')) return Icons.trending_up;
    if (t.contains('safety') || t.contains('warning') || t.contains('caution')) return Icons.warning_amber;
    if (t.contains('recommend') || t.contains('action')) return Icons.recommend;
    if (t.contains('question') || t.contains('reflect')) return Icons.psychology;
    if (t.contains('assessment') || t.contains('evaluat') || t.contains('feedback')) return Icons.grading;
    if (t.contains('rotation') || t.contains('next crop')) return Icons.loop;
    if (t.contains('biology') || t.contains('life cycle')) return Icons.biotech;
    if (t.contains('assessment') || t.contains('evaluat')) return Icons.grading;
    return Icons.info_outline;
  }
}