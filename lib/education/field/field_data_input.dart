// lib/education/field/field_data_input.dart
// ═══════════════════════════════════════════════════════════════
// PART 1 of 3 — Imports, Constants, Class Setup, Field Issues Tab
// ═══════════════════════════════════════════════════════════════

// ignore_for_file: use_build_context_synchronously, deprecated_member_use, unused_local_variable

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kilimomkononi/models/education_user.dart';
import 'package:kilimomkononi/education/data/field_management_tips.dart';
import 'package:kilimomkononi/education/data/soil_optimal_ranges.dart';
import 'package:kilimomkononi/education/data/fertilizer_recommendations.dart';

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

// ═══════════════════════════════════════════════════════════════
// WIDGET
// ═══════════════════════════════════════════════════════════════

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
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  late TabController _tabController;

  // ── Field Issues ── (shared: crop/stage also used by Soil Test)
  final _studentNameCtrl   = TextEditingController();
  final _observationsCtrl  = TextEditingController();
  final _studentIdeaCtrl   = TextEditingController();

  String? _selectedCrop;
  String? _selectedStage;
  String? _selectedIssue;

  // ── Soil Test ── (crop & stage come from _selectedCrop / _selectedStage)
  final _soilTestStudentNameCtrl   = TextEditingController();
  final _soilTestFieldLocationCtrl = TextEditingController();
  DateTime _soilTestDate = DateTime.now();

  // Soil nutrient inputs
  final _nitrogenCtrl      = TextEditingController();
  final _phosphorusCtrl    = TextEditingController();
  final _potassiumCtrl     = TextEditingController();
  final _pHCtrl            = TextEditingController();
  final _organicMatterCtrl = TextEditingController();

  // Student soil test idea/solution
  final _soilObservationsCtrl = TextEditingController();
  final _soilStudentIdeaCtrl  = TextEditingController();

  CollectionReference? _fieldSubmissionsCollection;
  CollectionReference? _soilTestResultsCollection;

  String? _currentUserId;
  Map<String, dynamic>? _soilAnalysis;

  // ─────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: isTeacher ? 3 : 2, vsync: this);
    _initializeFirestore();
    // Rebuild when any text controller changes that affects the UI
    for (final c in [
      _nitrogenCtrl, _phosphorusCtrl, _potassiumCtrl, _pHCtrl, _organicMatterCtrl,
      // Name controllers: trigger rebuild so submission lists appear without extra interaction
      _studentNameCtrl, _soilTestStudentNameCtrl,
    ]) {
      c.addListener(() => setState(() {}));
    }
  }

  Future<void> _initializeFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) setState(() => _currentUserId = user.uid);

    final parts = widget.classId.split('_');
    if (parts.length >= 3) {
      final ref = FirebaseFirestore.instance
          .collection('schools').doc(parts[0])
          .collection('systems').doc(parts[1])
          .collection('grades').doc(parts.sublist(2).join('_'));
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
    // Only clear the text answers — keep crop & stage so the student can
    // move straight to Soil Testing without re-selecting everything.
    // Also clear the issue selection so they can log a new issue for the
    // same crop/stage if needed.
    _observationsCtrl.clear();
    _studentIdeaCtrl.clear();
    setState(() => _selectedIssue = null);
  }

  bool get isTeacher => widget.role == EduRole.teacher || widget.role == EduRole.headteacher;
  bool get isStudent  => widget.role == EduRole.student;

  // ═══════════════════════════════════════════════════════════════
  // FIELD ISSUES TAB
  // ═══════════════════════════════════════════════════════════════

  Widget _buildFieldIssuesTab() {
    // Stage items depend on selected crop; empty list = disabled dropdown
    final stageItems = _selectedCrop != null
        ? cropStages[_selectedCrop]!.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList()
        : <DropdownMenuItem<String>>[];

    // Issue items depend on selected crop+stage
    final issueItems = (_selectedCrop != null &&
            _selectedStage != null &&
            cropStageIssues[_selectedCrop]?[_selectedStage] != null)
        ? cropStageIssues[_selectedCrop]![_selectedStage]!
            .map((i) => DropdownMenuItem(value: i, child: Text(i)))
            .toList()
        : <DropdownMenuItem<String>>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🌾 Field Issue Reporting',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryGreen),
            ),
            const SizedBox(height: 12),

            // Student name (students only)
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

            // ── All three dropdowns always visible ──
            // Crop
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

            // Stage — always rendered; disabled until crop chosen
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

            // Issue — always rendered; disabled until stage chosen
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

            // ── Hints panel (always rendered; disappears if no issue selected) ──
            _buildHintsPanel(),
            if (_selectedIssue != null) const SizedBox(height: 12),

            // Observations + Idea (students only)
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

            // Submit button
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

            // Student submissions list
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

  // ─────────────────────────────────────────
  // Hints panel
  // Teacher → full blue panel
  // Student → locked blue banner
  // Hidden when no issue selected
  // ─────────────────────────────────────────

  Widget _buildHintsPanel() {
    if (_selectedCrop == null || _selectedStage == null || _selectedIssue == null) {
      return const SizedBox.shrink();
    }
    final key  = '${_selectedCrop}_${_selectedStage}_$_selectedIssue';
    final tips = fieldManagementTips[key];
    if (tips == null) return const SizedBox.shrink();

    if (isTeacher) {
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
          ],
        ),
      );
    }

    // Student locked banner
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

  // ─────────────────────────────────────────
  // Submit Field Issue
  // ─────────────────────────────────────────

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
      // Capture name BEFORE reset clears observations (crop/stage are kept but name is in a separate ctrl)
      final submittedName = isStudent ? _studentNameCtrl.text.trim() : '';
      _resetFieldForm();
      // Mirror student name to soil test tab so they don't have to type it again
      if (isStudent && submittedName.isNotEmpty && _soilTestStudentNameCtrl.text.trim().isEmpty) {
        _soilTestStudentNameCtrl.text = submittedName;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Submission sent! Now go to Soil Testing to record nutrients.'),
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

  // ═══════════════════════════════════════════════════════════════
  // STUDENT SUBMISSION CARDS — Field Issues
  // ═══════════════════════════════════════════════════════════════

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
      stream: _fieldSubmissionsCollection
          ?.where('submittedBy', isEqualTo: 'student')
          .orderBy('submittedAt', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData) return const Text('No data available');

        final mine = snapshot.data!.docs.where((doc) {
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
              decoration: BoxDecoration(
                  color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
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
              // First reply — teacher commented, student hasn't replied yet
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
              // Second reply — teacher posted follow-up, student hasn't replied again
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
            ]),
          ],
        ),
      ),
    );
  }

  // Reusable coloured info box
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

  // ─────────────────────────────────────────
  // Student Reply Dialog
  // ─────────────────────────────────────────

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

  // ─────────────────────────────────────────
  // Expert Hints Dialog (unlocked for students)
  // ─────────────────────────────────────────

  void _showHintsDialog(Map<String, dynamic> data) {
    final key  = '${data['crop']}_${data['stage']}_${data['issue']}';
    final tips = fieldManagementTips[key];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.lightbulb, color: Colors.amber), SizedBox(width: 8),
          Expanded(child: Text('Expert Hints')),
        ]),
        content: tips == null
            ? const Text('No expert hints available for this issue.')
            : SingleChildScrollView(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Issue: ${data['issue']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 14),
                  if (tips['chemicalControl'] != null) ...[
                    const Text('🧪 Chemical Control:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    ...(tips['chemicalControl'] as List).map((i) =>
                        Padding(padding: const EdgeInsets.only(bottom: 3), child: Text('• ${i.toString()}'))),
                    const SizedBox(height: 10),
                  ],
                  if (tips['organicControl'] != null) ...[
                    const Text('🌱 Organic Solution:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    ...(tips['organicControl'] as List).map((i) =>
                        Padding(padding: const EdgeInsets.only(bottom: 3), child: Text('• ${i.toString()}'))),
                    const SizedBox(height: 10),
                  ],
                  if (tips['culturalControl'] != null) ...[
                    const Text('👨‍🌾 Cultural Practice:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    ...(tips['culturalControl'] as List).map((i) =>
                        Padding(padding: const EdgeInsets.only(bottom: 3), child: Text('• ${i.toString()}'))),
                  ],
                ],
              )),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

// ═══════════════════════════════════════════════════════════════
// END OF PART 1 — Continue with part2
// ═══════════════════════════════════════════════════════════════// ═══════════════════════════════════════════════════════════════
// PART 2 of 3 — Soil Testing Tab + Submission
// Paste DIRECTLY after Part 1 (inside the class body)
// ═══════════════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════════════
  // SOIL TESTING TAB
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSoilTestingTab() {
    final crop  = _selectedCrop;
    final stage = _selectedStage;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🧪 Soil Testing',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryGreen),
          ),
          const SizedBox(height: 12),

          // ── Crop/Stage banner — pulled from Field Issues tab ──
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
                        'Please go to the Field Issues tab first and select your crop and growth stage.',
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

          // Student name
          if (isStudent) ...[
            TextField(
              controller: _soilTestStudentNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Your Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
          ],

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

          // Nutrient heading
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

          // ── Student: soil observations + corrective idea ──
          if (isStudent) ...[
            const Divider(),
            const SizedBox(height: 10),
            const Text(
              '📝 Your Soil Observations & Corrective Measures',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryGreen),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _soilObservationsCtrl,
              decoration: const InputDecoration(
                labelText: 'Soil Observations *',
                hintText: 'Describe what you notice about the soil (colour, texture, smell…)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.visibility),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _soilStudentIdeaCtrl,
              decoration: const InputDecoration(
                labelText: 'Your Corrective Measures *',
                hintText: 'What would you do to improve the soil?',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lightbulb),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
          ],

          if (isTeacher) const SizedBox(height: 4),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _submitSoilTest,
              icon: _isSaving
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send),
              label: Text(_isSaving ? 'Submitting...' : 'Submit Soil Test'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.all(14),
              ),
            ),
          ),

          // Student soil submissions list
          if (isStudent) ...[
            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 12),
            const Text(
              '📋 My Soil Tests',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryGreen),
            ),
            const SizedBox(height: 10),
            _buildStudentSoilSubmissions(),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // Nutrient field with colour + optimal hint
  // ─────────────────────────────────────────

  Widget _buildNutrientField(
    String label,
    TextEditingController ctrl,
    String nutrientKey,
    String unit,
  ) {
    final crop  = _selectedCrop;
    final stage = _selectedStage;
    final hasCtx = crop != null && stage != null;

    Color fillColor   = Colors.grey.shade100;
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

  // ─────────────────────────────────────────
  // Submit Soil Test
  // ─────────────────────────────────────────

  Future<void> _submitSoilTest() async {
    final crop  = _selectedCrop;
    final stage = _selectedStage;
    if (crop == null || stage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select crop and growth stage in the Field Issues tab first'),
        ),
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
        'crop':                crop,
        'stage':               stage,
        'testDate':            Timestamp.fromDate(_soilTestDate),
        'fieldLocation':       _soilTestFieldLocationCtrl.text.trim(),
        'submittedBy':         isStudent ? 'student' : 'teacher',
        'studentName':         isStudent ? _soilTestStudentNameCtrl.text.trim() : 'Teacher Test',
        'schoolName':          widget.schoolName,
        'className':           widget.classId,
        'nitrogen':            {'value': nVal,  'unit': 'ppm', 'status': nStatus},
        'phosphorus':          {'value': pVal,  'unit': 'ppm', 'status': pStatus},
        'potassium':           {'value': kVal,  'unit': 'ppm', 'status': kStatus},
        'pH':                  {'value': phVal, 'status': phStatus},
        'organicMatter':       {'value': omVal, 'unit': '%',   'status': omStatus},
        'deficiencies':        deficiencies,
        // Student observations & corrective measures
        'soilObservations':    isStudent ? _soilObservationsCtrl.text.trim() : '',
        'soilStudentIdea':     isStudent ? _soilStudentIdeaCtrl.text.trim()  : '',
        'reviewStatus':        'pending',
        'submittedAt':         FieldValue.serverTimestamp(),
      });

      for (final c in [
        _nitrogenCtrl, _phosphorusCtrl, _potassiumCtrl,
        _pHCtrl, _organicMatterCtrl, _soilTestFieldLocationCtrl,
        _soilObservationsCtrl, _soilStudentIdeaCtrl,
      ]) { c.clear(); }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Soil test submitted!'), backgroundColor: Colors.green),
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

  // ─────────────────────────────────────────
  // Student Soil Submissions
  // ─────────────────────────────────────────

  Widget _buildStudentSoilSubmissions() {
    final studentName = _soilTestStudentNameCtrl.text.trim();

    // Show a clear prompt rather than silently hiding the section
    if (studentName.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
        child: const Text('👆 Enter your name above to see your soil tests'),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _soilTestResultsCollection
          ?.where('submittedBy', isEqualTo: 'student')
          .orderBy('submittedAt', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData) return const Text('No data available');

        final mine = snapshot.data!.docs.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          return d['studentName']?.toString().trim() == studentName;
        }).toList();

        if (mine.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
            child: Column(children: [
              const Icon(Icons.inbox_outlined, size: 40, color: Colors.grey),
              const SizedBox(height: 8),
              const Text('No soil tests submitted yet'),
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
              decoration: BoxDecoration(
                  color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
              child: Text(
                '${mine.length} soil test${mine.length == 1 ? '' : 's'} found',
                style: TextStyle(
                    fontSize: 12, color: Colors.green.shade900, fontWeight: FontWeight.bold),
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
    final deficiencies            = (data['deficiencies'] as List<dynamic>?) ?? [];
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
            // Header row
            Row(children: [
              Icon(Icons.science, color: Colors.green.shade700),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'Soil Test – ${(data['submittedAt'] as Timestamp?)?.toDate().toString().substring(0, 16) ?? 'Unknown'}',
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

            // Nutrient summary
            Text('N: ${data['nitrogen']?['value']} ppm  (${data['nitrogen']?['status']})'),
            Text('P: ${data['phosphorus']?['value']} ppm  (${data['phosphorus']?['status']})'),
            Text('K: ${data['potassium']?['value']} ppm  (${data['potassium']?['status']})'),
            Text('pH: ${data['pH']?['value']}  (${data['pH']?['status']})'),
            Text('Organic Matter: ${data['organicMatter']?['value']}%  (${data['organicMatter']?['status']})'),

            // Deficiencies banner
            if (deficiencies.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(4)),
                child: Text('Issues: ${deficiencies.join(', ')}',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade900)),
              ),
            ],

            // Student's own observations & corrective idea
            if (soilObs != null && soilObs.isNotEmpty) ...[
              const SizedBox(height: 8),
              _colorBox(Colors.blue, 'Your soil observations:', Icons.visibility, soilObs),
            ],
            if (soilIdea != null && soilIdea.isNotEmpty) ...[
              const SizedBox(height: 8),
              _colorBox(Colors.teal, 'Your corrective measures:', Icons.lightbulb, soilIdea),
            ],

            // Teacher comment (if unlocked)
            if (isReviewed && reviewUnlocked && teacherComment != null) ...[
              const SizedBox(height: 8),
              _colorBox(Colors.green, 'Teacher notes:', Icons.school, teacherComment),
            ],

            // Student reply to teacher
            if (studentReply != null) ...[
              const SizedBox(height: 8),
              _colorBox(Colors.purple, 'Your reply:', Icons.reply, studentReply),
            ],

            // Teacher follow-up after student reply
            if (teacherFollowUp != null) ...[
              const SizedBox(height: 8),
              _colorBox(Colors.amber, 'Teacher follow-up:', Icons.chat_bubble_outline, teacherFollowUp),
            ],

            // Student reply 2
            if (studentReply2 != null) ...[
              const SizedBox(height: 8),
              _colorBox(Colors.purple, 'Your reply:', Icons.reply, studentReply2),
            ],

            // Teacher follow-up 2
            if (teacherFollowUp2 != null) ...[
              const SizedBox(height: 8),
              _colorBox(Colors.amber, 'Teacher follow-up:', Icons.chat_bubble_outline, teacherFollowUp2),
            ],

            // Action buttons
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: [
              // First reply — teacher commented but student hasn't replied yet
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
              // Second reply — teacher posted follow-up, student hasn't replied again
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
              // Recommendations button
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
            ]),
          ],
        ),
      ),
    );
  }

  // Student reply dialog — Soil Test version
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

  // ─────────────────────────────────────────
  // Fertilizer Recommendations Dialog
  // ─────────────────────────────────────────

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

// ═══════════════════════════════════════════════════════════════
// END OF PART 2 — Continue with part3
// ═══════════════════════════════════════════════════════════════// ═══════════════════════════════════════════════════════════════
// PART 3 of 3 — Reviews Tab, Grade Helpers, build()
// Paste DIRECTLY after Part 2 (inside the class body)
// ═══════════════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════════════
  // REVIEWS TAB (teachers only)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildReviewsTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: primaryGreen,
            unselectedLabelColor: Colors.grey,
            indicatorColor: primaryGreen,
            tabs: const [Tab(text: 'Field Issues'), Tab(text: 'Soil Tests')],
          ),
          Expanded(
            child: TabBarView(children: [_buildFieldReviewsList(), _buildSoilReviewsList()]),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // Field Reviews List
  // ─────────────────────────────────────────

  Widget _buildFieldReviewsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _fieldSubmissionsCollection
          ?.where('submittedBy', isEqualTo: 'student')
          .orderBy('submittedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) {
          return const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No field issue submissions yet')));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (ctx, i) {
            final doc = snapshot.data!.docs[i];
            return _buildFieldReviewCard(doc.id, doc.data() as Map<String, dynamic>);
          },
        );
      },
    );
  }

  Widget _buildFieldReviewCard(String docId, Map<String, dynamic> data) {
    final isReviewed     = data['reviewStatus'] == 'reviewed';
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

  // ─────────────────────────────────────────
  // Field Review Dialog (teacher)
  // ─────────────────────────────────────────

  Future<void> _showFieldReviewDialog(String docId, Map<String, dynamic> data) async {
    String? selectedGrade = data['teacherGrade'];
    final commentCtrl     = TextEditingController(text: data['teacherComment']  ?? '');
    final followUpCtrl    = TextEditingController(text: data['teacherFollowUp'] ?? '');
    bool unlockReview     = data['reviewUnlocked'] ?? false;
    bool unlockHints      = data['hintsUnlocked']  ?? false;
    final hasStudentReply = data['studentReply'] != null;

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
                title: const Text('Unlock Review (grade + comment)'),
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
                    'reviewStatus':   'reviewed',
                    'teacherGrade':   selectedGrade,
                    'teacherComment': commentCtrl.text,
                    'reviewUnlocked': unlockReview,
                    'hintsUnlocked':  unlockHints,
                    'reviewedAt':     FieldValue.serverTimestamp(),
                    'reviewedBy':     _currentUserId,
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

  // ─────────────────────────────────────────
  // Soil Reviews List
  // ─────────────────────────────────────────

  Widget _buildSoilReviewsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _soilTestResultsCollection
          ?.where('submittedBy', isEqualTo: 'student')
          .orderBy('submittedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) {
          return const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No soil test submissions yet')));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (ctx, i) {
            final doc = snapshot.data!.docs[i];
            return _buildSoilReviewCard(doc.id, doc.data() as Map<String, dynamic>);
          },
        );
      },
    );
  }

  Widget _buildSoilReviewCard(String docId, Map<String, dynamic> data) {
    final isReviewed   = data['reviewStatus'] == 'reviewed';
    final deficiencies = (data['deficiencies'] as List<dynamic>?) ?? [];
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
                Text('Soil Test – ${data['crop']}',
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
            Text('N: ${data['nitrogen']?['value']}  (${data['nitrogen']?['status']})'),
            Text('P: ${data['phosphorus']?['value']}  (${data['phosphorus']?['status']})'),
            Text('K: ${data['potassium']?['value']}  (${data['potassium']?['status']})'),
            if (deficiencies.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Issues: ${deficiencies.join(', ')}',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade700)),
              ),
            if ((data['soilStudentIdea'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Student corrective idea: ${data['soilStudentIdea']}',
                style: const TextStyle(fontSize: 12),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ],
            if (hasStudentReply) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(4)),
                child: Text('Student replied: ${data['soilStudentReply']}',
                    style: TextStyle(fontSize: 12, color: Colors.purple.shade900),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // Soil Review Dialog (teacher)
  // ─────────────────────────────────────────

  Future<void> _showSoilReviewDialog(String docId, Map<String, dynamic> data) async {
    String? selectedGrade      = data['teacherGrade'];
    final commentCtrl          = TextEditingController(text: data['teacherComment'] ?? '');
    final followUpCtrl         = TextEditingController(text: data['soilTeacherFollowUp'] ?? '');
    bool unlockReview          = data['reviewUnlocked']          ?? false;
    bool unlockRecommendations = data['recommendationsUnlocked'] ?? false;
    final hasStudentReply      = data['soilStudentReply'] != null;

    await showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlg) => AlertDialog(
          title: const Text('Review Soil Test'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Student: ${data['studentName'] ?? ''}'),
              Text('Crop: ${data['crop'] ?? ''}'),
              const SizedBox(height: 12),
              Text('N:  ${data['nitrogen']?['value']} ppm  (${data['nitrogen']?['status']})'),
              Text('P:  ${data['phosphorus']?['value']} ppm  (${data['phosphorus']?['status']})'),
              Text('K:  ${data['potassium']?['value']} ppm  (${data['potassium']?['status']})'),
              Text('pH: ${data['pH']?['value']}  (${data['pH']?['status']})'),

              // Student's soil observations
              if ((data['soilObservations'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Student observations:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(data['soilObservations'] ?? '', style: const TextStyle(fontSize: 13)),
                  ]),
                ),
              ],

              // Student's corrective measures
              if ((data['soilStudentIdea'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(6)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Student corrective measures:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(data['soilStudentIdea'] ?? '', style: const TextStyle(fontSize: 13)),
                  ]),
                ),
              ],

              // Student reply (if any)
              if (hasStudentReply) ...[
                const SizedBox(height: 10),
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

              // Follow-up field — shown once student has replied
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

  // ─────────────────────────────────────────
  // Grade Helpers
  // ─────────────────────────────────────────

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

  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        // Compact tab bar — no extra title bar above it
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: TabBar(
            controller: _tabController,
            tabs: [
              const Tab(icon: Icon(Icons.report_problem, size: 18), text: 'Field Issues'),
              const Tab(icon: Icon(Icons.science, size: 18),        text: 'Soil Testing'),
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

// ═══════════════════════════════════════════════════════════════
// END OF FILE ✅
// ═══════════════════════════════════════════════════════════════