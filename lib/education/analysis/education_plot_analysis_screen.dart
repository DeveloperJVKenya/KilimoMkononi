// lib/education/analysis/education_plot_analysis_screen.dart

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:kilimomkononi/models/education_user.dart';

const Color _appGreen = Color(0xFF003900);

// ── Gemini Firebase Function URL ─────────────────────────────────────────────
const String _geminiUrl =
    'https://us-central1-kilimomkononi-e1031.cloudfunctions.net/askGemini';

class EducationPlotAnalysisScreen extends StatefulWidget {
  final EduRole role;
  final String  schoolName;
  final String  classId;

  const EducationPlotAnalysisScreen({
    super.key,
    required this.role,
    required this.schoolName,
    required this.classId,
  });

  @override
  State<EducationPlotAnalysisScreen> createState() =>
      _EducationPlotAnalysisScreenState();
}

class _EducationPlotAnalysisScreenState
    extends State<EducationPlotAnalysisScreen> {
  bool get _isTeacher =>
      widget.role == EduRole.teacher || widget.role == EduRole.headteacher;

  bool   _isGenerating = false;
  String _statusMsg    = '';

  // ── Firestore path helpers ────────────────────────────────────────────
  Map<String, String> get _pathParts {
    final parts  = widget.classId.split('_');
    final school = parts.isNotEmpty ? parts[0] : widget.schoolName.replaceAll(' ', '_');
    final system = parts.length > 1 ? parts[1] : 'junior';
    final grade  = parts.length > 2 ? parts.sublist(2).join('_') : parts.last;
    return {'school': school, 'system': system, 'grade': grade};
  }

  DocumentReference get _analysisDoc {
    final p = _pathParts;
    return FirebaseFirestore.instance
        .collection('schools').doc(p['school'])
        .collection('systems').doc(p['system'])
        .collection('grades').doc(p['grade'])
        .collection('plot_analyses').doc(DateTime.now().year.toString());
  }

  CollectionReference _sub(String name) {
    final p = _pathParts;
    return FirebaseFirestore.instance
        .collection('schools').doc(p['school'])
        .collection('systems').doc(p['system'])
        .collection('grades').doc(p['grade'])
        .collection(name);
  }

  // ── Gemini call ───────────────────────────────────────────────────────
  Future<String?> _callGemini(String prompt) async {
    try {
      final res = await http.post(
        Uri.parse(_geminiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'prompt': prompt}),
      ).timeout(const Duration(seconds: 90));

      if (res.statusCode != 200) {
        debugPrint('[PlotAnalysis] HTTP ${res.statusCode}: ${res.body.substring(0, res.body.length.clamp(0, 200))}');
        return null;
      }
      // Cloud function returns raw Gemini API response:
      // { candidates: [ { content: { parts: [ { text: "..." } ] } } ] }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final candidates = body['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) return null;
      return candidates[0]?['content']?['parts']?[0]?['text'] as String?;
    } catch (e) {
      debugPrint('[PlotAnalysis] error: $e');
      return null;
    }
  }

  String _extractJson(String raw) {
    final start = raw.indexOf(RegExp(r'[\[{]'));
    final end   = raw.lastIndexOf(RegExp(r'[\]}]'));
    return (start != -1 && end != -1) ? raw.substring(start, end + 1) : raw;
  }

  // ── Generate ──────────────────────────────────────────────────────────
  Future<void> _generate() async {
    setState(() { _isGenerating = true; _statusMsg = 'Collecting data…'; });
    try {
      // 1. Field & soil records
      setState(() => _statusMsg = 'Reading field & soil records…');
      final fieldSnap = await _sub('field_submissions').get();
      final soilSnap  = await _sub('soil_test_results').get();

      // 2. Pest & disease records
      setState(() => _statusMsg = 'Reading pest & disease records…');
      final submColl = FirebaseFirestore.instance
          .collection('ClassSubmissions_${widget.classId}');

      QuerySnapshot pestSnap;
      QuerySnapshot diseaseSnap;
      try {
        pestSnap    = await submColl.where('type', isEqualTo: 'pest').get();
        diseaseSnap = await submColl.where('type', isEqualTo: 'disease').get();
      } catch (_) {
        pestSnap    = await FirebaseFirestore.instance.collection('_empty').get();
        diseaseSnap = await FirebaseFirestore.instance.collection('_empty').get();
      }

      // 3. Build summaries
      final fieldSummary = fieldSnap.docs.isEmpty
          ? 'No field data recorded.'
          : fieldSnap.docs.map((d) {
              final data = d.data() as Map<String, dynamic>;
              return '- Crop: ${data['crop'] ?? 'N/A'}, '
                  'Stage: ${data['stage'] ?? 'N/A'}, '
                  'pH: ${data['pH'] ?? 'N/A'}, '
                  'N: ${data['nitrogen'] ?? 'N/A'}, '
                  'P: ${data['phosphorus'] ?? 'N/A'}, '
                  'K: ${data['potassium'] ?? 'N/A'}';
            }).join('\n');

      final soilSummary = soilSnap.docs.isEmpty
          ? 'No soil test results recorded.'
          : soilSnap.docs.map((d) {
              final data = d.data() as Map<String, dynamic>;
              return '- ${data.entries.map((e) => '${e.key}: ${e.value}').join(', ')}';
            }).join('\n');

      final pestSummary = pestSnap.docs.isEmpty
          ? 'No pest interventions recorded.'
          : pestSnap.docs.map((d) {
              final data = d.data() as Map<String, dynamic>;
              return '- Pest: ${data['pestName'] ?? data['pest'] ?? 'Unknown'}, '
                  'Crop: ${data['crop'] ?? 'N/A'}, '
                  'Severity: ${data['severity'] ?? 'N/A'}, '
                  'Treatment: ${data['treatment'] ?? data['intervention'] ?? 'N/A'}';
            }).join('\n');

      final diseaseSummary = diseaseSnap.docs.isEmpty
          ? 'No disease interventions recorded.'
          : diseaseSnap.docs.map((d) {
              final data = d.data() as Map<String, dynamic>;
              return '- Disease: ${data['diseaseName'] ?? data['disease'] ?? 'Unknown'}, '
                  'Crop: ${data['crop'] ?? 'N/A'}, '
                  'Severity: ${data['severity'] ?? 'N/A'}, '
                  'Treatment: ${data['treatment'] ?? data['intervention'] ?? 'N/A'}';
            }).join('\n');

      // 4. Call Gemini
      setState(() => _statusMsg = 'Shamba AI is analysing…');

      final year    = DateTime.now().year;
      final classId = widget.classId;
      final school  = widget.schoolName;

      final prompt = '''
You are an expert Kenyan agricultural educator and farm analyst.
Analyse this school farming plot data and return ONLY valid JSON — no markdown, no preamble.

CLASS / PLOT: $classId  |  SCHOOL: $school  |  YEAR: $year

FIELD & CROP DATA:
$fieldSummary

SOIL TEST RESULTS:
$soilSummary

PEST RECORDS:
$pestSummary

DISEASE RECORDS:
$diseaseSummary

Return this exact JSON structure:
{
  "summary": "2-3 sentence overall season summary suitable for a school farming plot",
  "fieldAnalysis": {
    "soilHealth": "soil nutrient and pH assessment",
    "cropPerformance": "how the crop performed this season",
    "keyObservations": ["obs 1", "obs 2", "obs 3"]
  },
  "pestDiseaseAnalysis": {
    "overallPressure": "low/medium/high",
    "majorThreats": ["threat 1", "threat 2"],
    "managementEffectiveness": "effectiveness assessment",
    "recommendations": ["rec 1", "rec 2"]
  },
  "learningOutcomes": {
    "whatStudentsLearned": ["learning 1", "learning 2", "learning 3"],
    "practicalSkillsGained": ["skill 1", "skill 2"],
    "areasForImprovement": ["area 1", "area 2"]
  },
  "cropRotationAdvice": {
    "recommendedNextCrop": "specific crop name",
    "rationale": "why this crop suits the plot and learning goals",
    "soilAmendmentsNeeded": ["amendment 1", "amendment 2"]
  },
  "seasonHandover": {
    "lessonsLearned": ["lesson 1", "lesson 2", "lesson 3"],
    "prioritiesForNextSeason": ["priority 1", "priority 2", "priority 3"],
    "warningsForNextSeason": ["warning 1", "warning 2"]
  },
  "overallRating": 7,
  "ratingJustification": "one sentence score explanation"
}
''';

      final raw = await _callGemini(prompt);

      if (raw == null || raw.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('AI analysis failed. Check connection.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      Map<String, dynamic> analysisMap;
      try {
        analysisMap = jsonDecode(_extractJson(raw)) as Map<String, dynamic>;
      } catch (_) {
        analysisMap = {'summary': raw};
      }

      // 5. Save
      setState(() => _statusMsg = 'Saving…');
      await _analysisDoc.set({
        ...analysisMap,
        'generatedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
        'classId':     widget.classId,
        'schoolName':  widget.schoolName,
        'year':        year,
        'generatedAt': FieldValue.serverTimestamp(),
        'dataSnapshot': {
          'fieldRecords':   fieldSnap.docs.length,
          'soilRecords':    soilSnap.docs.length,
          'pestRecords':    pestSnap.docs.length,
          'diseaseRecords': diseaseSnap.docs.length,
        },
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Analysis saved. Students can now view it.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() { _isGenerating = false; _statusMsg = ''; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: AppBar(
        backgroundColor: _appGreen,
        foregroundColor: Colors.white,
        title: const Text('Plot Analysis',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _analysisDoc.snapshots(),
        builder: (context, snap) {
          Map<String, dynamic>? existing;
          if (snap.hasData && snap.data!.exists) {
            try {
              existing = snap.data!.data() as Map<String, dynamic>?;
            } catch (_) {}
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isTeacher) ...[
                  _GenerateCard(
                    isGenerating: _isGenerating,
                    statusMsg:    _statusMsg,
                    hasExisting:  existing != null,
                    onGenerate:   _generate,
                  ),
                  const SizedBox(height: 20),
                ],
                if (existing != null)
                  _AnalysisResultCard(
                    data:        existing,
                    seasonLabel: '${DateTime.now().year} Analysis',
                  )
                else if (!_isTeacher)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12)),
                    child: Column(children: [
                      Icon(Icons.pending_outlined,
                          size: 48, color: Colors.blue.shade300),
                      const SizedBox(height: 12),
                      const Text('No analysis yet for this plot.',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Text(
                          'Your teacher will generate an analysis after the season.',
                          style: TextStyle(color: Colors.grey.shade600),
                          textAlign: TextAlign.center),
                    ]),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200)),
                    child: Column(children: [
                      Icon(Icons.analytics_outlined,
                          size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      const Text('No analysis yet for this season.',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 6),
                      Text(
                          'Tap "Generate Plot Analysis" above to get AI insights '
                          'for ${widget.classId}.',
                          style: TextStyle(
                              color: Colors.grey.shade600, height: 1.4),
                          textAlign: TextAlign.center),
                    ]),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Teacher generate card ────────────────────────────────────────────────────

class _GenerateCard extends StatelessWidget {
  final bool isGenerating;
  final String statusMsg;
  final bool hasExisting;
  final VoidCallback onGenerate;

  const _GenerateCard({
    required this.isGenerating,
    required this.statusMsg,
    required this.hasExisting,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) => Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: _appGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.auto_awesome, color: _appGreen, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Generate Plot Analysis',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    SizedBox(height: 2),
                    Text(
                        'AI analyses all field, soil, pest & disease data for this class',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 16),
            if (hasExisting)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300)),
                child: Row(children: [
                  Icon(Icons.warning_amber, size: 16, color: Colors.amber.shade700),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                        'An analysis already exists. Re-generating will overwrite it.',
                        style: TextStyle(fontSize: 12)),
                  ),
                ]),
              ),
            if (isGenerating) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(
                  backgroundColor: Color(0xFFE0E0E0),
                  valueColor: AlwaysStoppedAnimation<Color>(_appGreen),
                ),
              ),
              const SizedBox(height: 8),
              Text(statusMsg,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            ] else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onGenerate,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: Text(
                      hasExisting ? 'Re-generate Analysis' : 'Generate Plot Analysis',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _appGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
          ]),
        ),
      );
}

// ─── Rich analysis result card ────────────────────────────────────────────────

class _AnalysisResultCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String seasonLabel;

  const _AnalysisResultCard({required this.data, required this.seasonLabel});

  @override
  Widget build(BuildContext context) {
    final summary  = data['summary']             as String?;
    final fieldAn  = data['fieldAnalysis']       as Map<String, dynamic>?;
    final pestAn   = data['pestDiseaseAnalysis'] as Map<String, dynamic>?;
    final learning = data['learningOutcomes']    as Map<String, dynamic>?;
    final rotation = data['cropRotationAdvice']  as Map<String, dynamic>?;
    final handover = data['seasonHandover']      as Map<String, dynamic>?;
    final rating   = data['overallRating'];
    final ratingJ  = data['ratingJustification'] as String?;
    final snapshot = data['dataSnapshot']        as Map<String, dynamic>?;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Header banner ──
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
            color: _appGreen, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text('AI Analysis — $seasonLabel',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ),
          if (rating != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('$rating/10',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ]),
      ),
      if (ratingJ != null) ...[
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(ratingJ,
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic)),
        ),
      ],

      // ── Data chips ──
      if (snapshot != null) ...[
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 6, children: [
          _chip('${snapshot['fieldRecords'] ?? 0} field records',
              Icons.grass, Colors.green),
          _chip('${snapshot['soilRecords'] ?? 0} soil records',
              Icons.science, Colors.brown),
          _chip('${snapshot['pestRecords'] ?? 0} pest records',
              Icons.bug_report, Colors.orange),
          _chip('${snapshot['diseaseRecords'] ?? 0} disease records',
              Icons.coronavirus, Colors.red),
        ]),
      ],

      if (summary != null) ...[
        const SizedBox(height: 14),
        _section('📋 Season Summary', summary,
            Colors.blue.shade50, Colors.blue.shade800),
      ],

      if (fieldAn != null) ...[
        const SizedBox(height: 10),
        _expandable('🌱 Field & Soil Analysis',
            Colors.green.shade50, Colors.green.shade800, [
          if (fieldAn['soilHealth'] != null)
            _kv('Soil Health', fieldAn['soilHealth']),
          if (fieldAn['cropPerformance'] != null)
            _kv('Crop Performance', fieldAn['cropPerformance']),
          if (fieldAn['keyObservations'] is List)
            _bullets('Key Observations',
                List<String>.from(fieldAn['keyObservations'])),
        ]),
      ],

      if (pestAn != null) ...[
        const SizedBox(height: 10),
        _expandable('🐛 Pest & Disease Analysis',
            Colors.orange.shade50, Colors.orange.shade800, [
          if (pestAn['overallPressure'] != null)
            _kv('Overall Pressure', pestAn['overallPressure']),
          if (pestAn['majorThreats'] is List)
            _bullets('Major Threats',
                List<String>.from(pestAn['majorThreats'])),
          if (pestAn['managementEffectiveness'] != null)
            _kv('Management Effectiveness',
                pestAn['managementEffectiveness']),
          if (pestAn['recommendations'] is List)
            _bullets('Recommendations',
                List<String>.from(pestAn['recommendations'])),
        ]),
      ],

      if (learning != null) ...[
        const SizedBox(height: 10),
        _expandable('🎓 Learning Outcomes',
            Colors.indigo.shade50, Colors.indigo.shade800, [
          if (learning['whatStudentsLearned'] is List)
            _bullets('What Students Learned',
                List<String>.from(learning['whatStudentsLearned'])),
          if (learning['practicalSkillsGained'] is List)
            _bullets('Practical Skills Gained',
                List<String>.from(learning['practicalSkillsGained'])),
          if (learning['areasForImprovement'] is List)
            _bullets('Areas for Improvement',
                List<String>.from(learning['areasForImprovement'])),
        ]),
      ],

      if (rotation != null) ...[
        const SizedBox(height: 10),
        _expandable('🔄 Crop Rotation Advice',
            Colors.purple.shade50, Colors.purple.shade800, [
          if (rotation['recommendedNextCrop'] != null)
            _kv('Recommended Next Crop', rotation['recommendedNextCrop']),
          if (rotation['rationale'] != null)
            _kv('Rationale', rotation['rationale']),
          if (rotation['soilAmendmentsNeeded'] is List)
            _bullets('Soil Amendments Needed',
                List<String>.from(rotation['soilAmendmentsNeeded'])),
        ]),
      ],

      if (handover != null) ...[
        const SizedBox(height: 10),
        _expandable('📦 Season Handover',
            Colors.teal.shade50, Colors.teal.shade800, [
          if (handover['lessonsLearned'] is List)
            _bullets('Lessons Learned',
                List<String>.from(handover['lessonsLearned'])),
          if (handover['prioritiesForNextSeason'] is List)
            _bullets('Priorities for Next Season',
                List<String>.from(handover['prioritiesForNextSeason'])),
          if (handover['warningsForNextSeason'] is List)
            _bullets('⚠️ Warnings',
                List<String>.from(handover['warningsForNextSeason'])),
        ]),
      ],
      const SizedBox(height: 16),
    ]);
  }

  Widget _chip(String label, IconData icon, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.3))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _section(String title, String body, Color bg, Color tc) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14, color: tc)),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(fontSize: 13, height: 1.45)),
        ]),
      );

  Widget _expandable(
          String title, Color bg, Color tc, List<Widget> children) =>
      Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Theme(
          data: ThemeData().copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            backgroundColor: bg,
            collapsedBackgroundColor: bg,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            collapsedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            title: Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14, color: tc)),
            initiallyExpanded: true,
            children: children,
          ),
        ),
      );

  Widget _kv(String label, dynamic value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(
                fontSize: 13, color: Colors.black87, height: 1.4),
            children: [
              TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              TextSpan(text: value.toString()),
            ],
          ),
        ),
      );

  Widget _bullets(String label, List<String> items) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$label:',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 3),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontSize: 13)),
                      Expanded(
                          child: Text(item,
                              style: const TextStyle(
                                  fontSize: 13, height: 1.35))),
                    ]),
              )),
        ]),
      );
}