// lib/screens/analysis/farmer_plot_analysis_screen.dart
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ─── Gemini Firebase Function URL ────────────────────────────────────────────
const String _geminiUrl =
    'https://us-central1-kilimomkononi-e1031.cloudfunctions.net/askGemini';

const Color _appGreen = Color(0xFF003900);

// ═══════════════════════════════════════════════════════════════════════════
//  FarmerPlotAnalysisScreen
//
//  Full seasonal analysis for the Farmer/Enterprise platform.
//  Pulls from ALL data sources:
//    • fielddata               Firestore — plot data, soil nutrients
//    • pestinterventiondata    Firestore — pest records
//    • diseaseinterventiondata Firestore — disease records
//    • SharedPreferences       — farm management costs, revenues, loans
//
//  Saves result to: farmer_plot_analyses/{uid}/seasons/{plotId_cycleName}
// ═══════════════════════════════════════════════════════════════════════════

class FarmerPlotAnalysisScreen extends StatefulWidget {
  final String plotId;
  final String cycleName;

  const FarmerPlotAnalysisScreen({
    super.key,
    required this.plotId,
    required this.cycleName,
  });

  @override
  State<FarmerPlotAnalysisScreen> createState() =>
      _FarmerPlotAnalysisScreenState();
}

class _FarmerPlotAnalysisScreenState extends State<FarmerPlotAnalysisScreen> {
  bool   _isGenerating = false;
  String _statusMsg    = '';

  String get _uid =>
      FirebaseAuth.instance.currentUser?.uid ?? 'unknown';

  String get _docKey =>
      '${widget.plotId}_${widget.cycleName}'.replaceAll(' ', '_');

  DocumentReference get _analysisDoc => FirebaseFirestore.instance
      .collection('farmer_plot_analyses')
      .doc(_uid)
      .collection('seasons')
      .doc(_docKey);

  // ── Direct Gemini call via Firebase Function ──────────────────────────
  Future<String?> _callGemini(String prompt) async {
    try {
      final res = await http.post(
        Uri.parse(_geminiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'prompt': prompt}),
      ).timeout(const Duration(seconds: 90));

      if (res.statusCode != 200) return null;

      final body = jsonDecode(res.body);
      return body['text'] as String? ??
          body['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
    } catch (_) {
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
    setState(() { _isGenerating = true; _statusMsg = 'Collecting field data…'; });
    try {
      // 1. Field data
      final fieldSnap = await FirebaseFirestore.instance
          .collection('fielddata')
          .where('userId', isEqualTo: _uid)
          .where('plotId', isEqualTo: widget.plotId)
          .get();

      // 2. Pest interventions
      setState(() => _statusMsg = 'Collecting pest records…');
      final pestSnap = await FirebaseFirestore.instance
          .collection('pestinterventiondata')
          .where('userId', isEqualTo: _uid)
          .where('isDeleted', isEqualTo: false)
          .get();

      // 3. Disease interventions
      setState(() => _statusMsg = 'Collecting disease records…');
      final diseaseSnap = await FirebaseFirestore.instance
          .collection('diseaseinterventiondata')
          .where('userId', isEqualTo: _uid)
          .where('isDeleted', isEqualTo: false)
          .get();

      // 4. Farm management from SharedPreferences
      setState(() => _statusMsg = 'Reading farm management records…');
      final prefs = await SharedPreferences.getInstance();
      final cycle = widget.cycleName;

      List<Map<String, dynamic>> decode(String key) {
        final raw = prefs.getString(key);
        if (raw == null) return [];
        try { return List<Map<String, dynamic>>.from(jsonDecode(raw)); }
        catch (_) { return []; }
      }

      final labour    = decode('labourActivities_$cycle');
      final equipment = decode('mechanicalCosts_$cycle');
      final inputs    = decode('inputCosts_$cycle');
      final misc      = decode('miscellaneousCosts_$cycle');
      final revenues  = decode('revenues_$cycle');
      final loans     = decode('paymentHistory_$cycle');
      final cropGrown = prefs.getString('cropGrown_$cycle') ?? '';

      // ── Build prompt context ──────────────────────────────────────────
      final fieldSummary = fieldSnap.docs.isEmpty
          ? 'No field data recorded.'
          : fieldSnap.docs.map((d) {
              final data = d.data();
              return '- Plot: ${data['plotId'] ?? widget.plotId}, '
                  'Crop: ${data['crop'] ?? 'N/A'}, '
                  'Stage: ${data['stage'] ?? 'N/A'}, '
                  'pH: ${data['pH'] ?? 'N/A'}, '
                  'N: ${data['nitrogen'] ?? 'N/A'}, '
                  'P: ${data['phosphorus'] ?? 'N/A'}, '
                  'K: ${data['potassium'] ?? 'N/A'}';
            }).join('\n');

      final pestSummary = pestSnap.docs.isEmpty
          ? 'No pest interventions recorded.'
          : pestSnap.docs.map((d) {
              final data = d.data();
              return '- Pest: ${data['pestName'] ?? data['pest'] ?? 'Unknown'}, '
                  'Crop: ${data['crop'] ?? 'N/A'}, '
                  'Severity: ${data['severity'] ?? 'N/A'}, '
                  'Treatment: ${data['treatment'] ?? data['intervention'] ?? 'N/A'}';
            }).join('\n');

      final diseaseSummary = diseaseSnap.docs.isEmpty
          ? 'No disease interventions recorded.'
          : diseaseSnap.docs.map((d) {
              final data = d.data();
              return '- Disease: ${data['diseaseName'] ?? data['disease'] ?? 'Unknown'}, '
                  'Crop: ${data['crop'] ?? 'N/A'}, '
                  'Severity: ${data['severity'] ?? 'N/A'}, '
                  'Treatment: ${data['treatment'] ?? data['intervention'] ?? 'N/A'}';
            }).join('\n');

      final totalCost = [labour, equipment, inputs, misc]
          .expand((l) => l)
          .fold(0.0, (s, item) =>
              s + (double.tryParse(item['cost']?.toString() ?? '0') ?? 0));
      final totalRevenue = revenues.fold(0.0, (s, r) =>
          s + (double.tryParse(r['amount']?.toString() ?? '0') ?? 0));

      final financeSummary =
          'Crop Grown: $cropGrown\n'
          'Labour entries: ${labour.length}, Equipment: ${equipment.length}, '
          'Inputs: ${inputs.length}, Misc: ${misc.length}\n'
          'Total Cost: KES ${totalCost.toStringAsFixed(0)}\n'
          'Total Revenue: KES ${totalRevenue.toStringAsFixed(0)}\n'
          'Net: KES ${(totalRevenue - totalCost).toStringAsFixed(0)}\n'
          'Loan payments: ${loans.length}';

      // 5. Call Gemini
      setState(() => _statusMsg = 'Shamba AI is analysing your season…');

      final prompt = '''
You are an expert Kenyan agricultural analyst and farm business advisor.
Analyse this farmer's seasonal data and return ONLY valid JSON — no markdown, no preamble.

SEASON: $cycle  |  PLOT: ${widget.plotId}

FIELD & SOIL DATA:
$fieldSummary

PEST RECORDS:
$pestSummary

DISEASE RECORDS:
$diseaseSummary

FARM FINANCIALS:
$financeSummary

Return this exact JSON:
{
  "summary": "2-3 sentence overall season summary",
  "fieldAnalysis": {
    "soilHealth": "soil nutrient and pH assessment",
    "cropPerformance": "how the crop performed",
    "keyObservations": ["obs 1", "obs 2", "obs 3"]
  },
  "pestDiseaseAnalysis": {
    "overallPressure": "low/medium/high",
    "majorThreats": ["threat 1", "threat 2"],
    "managementEffectiveness": "effectiveness assessment",
    "recommendations": ["rec 1", "rec 2"]
  },
  "financialAnalysis": {
    "profitabilityStatus": "profitable/break-even/loss",
    "costEfficiency": "cost management assessment",
    "revenueInsights": "key revenue observations",
    "topCostDriver": "highest cost category",
    "financialRecommendations": ["rec 1", "rec 2"]
  },
  "cropRotationAdvice": {
    "recommendedNextCrop": "specific crop name",
    "rationale": "why this crop",
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
                  backgroundColor: Colors.red));
        }
        return;
      }

      Map<String, dynamic> analysisMap;
      try {
        analysisMap = jsonDecode(_extractJson(raw)) as Map<String, dynamic>;
      } catch (_) {
        analysisMap = {'summary': raw};
      }

      // 6. Save
      setState(() => _statusMsg = 'Saving analysis…');
      await _analysisDoc.set({
        ...analysisMap,
        'userId':      _uid,
        'plotId':      widget.plotId,
        'cycleName':   widget.cycleName,
        'generatedAt': FieldValue.serverTimestamp(),
        'dataSnapshot': {
          'fieldRecords':   fieldSnap.docs.length,
          'pestRecords':    pestSnap.docs.length,
          'diseaseRecords': diseaseSnap.docs.length,
          'totalCost':      totalCost,
          'totalRevenue':   totalRevenue,
        },
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('✅ Season analysis saved successfully.'),
                backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
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
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Season Analysis',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(widget.cycleName,
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ]),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _analysisDoc.snapshots(),
        builder: (context, snap) {
          Map<String, dynamic>? existing;
          if (snap.hasData && snap.data!.exists) {
            existing = snap.data!.data() as Map<String, dynamic>?;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _FarmerGenerateCard(
                plotId:       widget.plotId,
                cycleName:    widget.cycleName,
                isGenerating: _isGenerating,
                statusMsg:    _statusMsg,
                hasExisting:  existing != null,
                onGenerate:   _generate,
              ),
              const SizedBox(height: 20),
              if (existing != null)
                _AnalysisResultCard(
                    data: existing, cycleName: widget.cycleName)
              else
                _EmptyState(
                    plotId: widget.plotId, cycleName: widget.cycleName),
            ]),
          );
        },
      ),
    );
  }
}

// ─── Rich analysis result display ────────────────────────────────────────────

class _AnalysisResultCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String cycleName;
  const _AnalysisResultCard({required this.data, required this.cycleName});

  @override
  Widget build(BuildContext context) {
    final summary       = data['summary']             as String?;
    final fieldAn       = data['fieldAnalysis']       as Map<String, dynamic>?;
    final pestAn        = data['pestDiseaseAnalysis'] as Map<String, dynamic>?;
    final finance       = data['financialAnalysis']   as Map<String, dynamic>?;
    final rotation      = data['cropRotationAdvice']  as Map<String, dynamic>?;
    final handover      = data['seasonHandover']      as Map<String, dynamic>?;
    final rating        = data['overallRating'];
    final ratingJust    = data['ratingJustification'] as String?;
    final snapshot      = data['dataSnapshot']        as Map<String, dynamic>?;

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
          Expanded(child: Text('AI Analysis — $cycleName',
              style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 14))),
          if (rating != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('$rating/10',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ]),
      ),
      if (ratingJust != null) ...[
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(ratingJust,
              style: TextStyle(fontSize: 12,
                  color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
        ),
      ],

      // ── Data chips ──
      if (snapshot != null) ...[
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 6, children: [
          _chip('${snapshot['fieldRecords'] ?? 0} field records',
              Icons.grass, Colors.green),
          _chip('${snapshot['pestRecords'] ?? 0} pest records',
              Icons.bug_report, Colors.orange),
          _chip('${snapshot['diseaseRecords'] ?? 0} disease records',
              Icons.coronavirus, Colors.red),
          _chip(
              'KES ${((snapshot['totalRevenue'] ?? 0.0) as num).toStringAsFixed(0)} revenue',
              Icons.attach_money, Colors.teal),
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

      if (finance != null) ...[
        const SizedBox(height: 10),
        _expandable('💰 Financial Analysis',
            Colors.teal.shade50, Colors.teal.shade800, [
          if (finance['profitabilityStatus'] != null)
            _kv('Profitability', finance['profitabilityStatus']),
          if (finance['costEfficiency'] != null)
            _kv('Cost Efficiency', finance['costEfficiency']),
          if (finance['revenueInsights'] != null)
            _kv('Revenue Insights', finance['revenueInsights']),
          if (finance['topCostDriver'] != null)
            _kv('Top Cost Driver', finance['topCostDriver']),
          if (finance['financialRecommendations'] is List)
            _bullets('Recommendations',
                List<String>.from(finance['financialRecommendations'])),
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
            Colors.indigo.shade50, Colors.indigo.shade800, [
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(
          fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _section(String title, String body, Color bg, Color tc) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(
          fontWeight: FontWeight.bold, fontSize: 14, color: tc)),
      const SizedBox(height: 6),
      Text(body, style: const TextStyle(fontSize: 13, height: 1.45)),
    ]),
  );

  Widget _expandable(String title, Color bg, Color tc, List<Widget> children) =>
      Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Theme(
          data: ThemeData().copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            childrenPadding:
                const EdgeInsets.fromLTRB(14, 0, 14, 14),
            backgroundColor: bg,
            collapsedBackgroundColor: bg,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            collapsedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            title: Text(title, style: TextStyle(
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
          TextSpan(text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: value.toString()),
        ],
      ),
    ),
  );

  Widget _bullets(String label, List<String> items) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$label:', style: const TextStyle(
          fontWeight: FontWeight.bold, fontSize: 13)),
      const SizedBox(height: 4),
      ...items.map((item) => Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('• ', style: TextStyle(fontSize: 13)),
          Expanded(child: Text(item,
              style: const TextStyle(fontSize: 13, height: 1.35))),
        ]),
      )),
    ]),
  );
}

// ─── Generate card ────────────────────────────────────────────────────────────

class _FarmerGenerateCard extends StatelessWidget {
  final String plotId;
  final String cycleName;
  final bool isGenerating;
  final String statusMsg;
  final bool hasExisting;
  final VoidCallback onGenerate;

  const _FarmerGenerateCard({
    required this.plotId,
    required this.cycleName,
    required this.isGenerating,
    required this.statusMsg,
    required this.hasExisting,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) => Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: _appGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.auto_awesome,
                      color: _appGreen, size: 24)),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('AI Season Analysis',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('$plotId · $cycleName',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                  ])),
            ]),
            const SizedBox(height: 12),
            Text(
                'Analyses your field data, soil nutrients, pest & disease records, '
                'and farm finances for this plot and season. '
                'Includes crop rotation advice and a handover summary for planning next season.',
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    height: 1.4)),
            const SizedBox(height: 16),
            if (hasExisting)
              Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: Colors.amber.shade300)),
                  child: Row(children: [
                    Icon(Icons.warning_amber,
                        size: 16, color: Colors.amber.shade700),
                    const SizedBox(width: 8),
                    const Expanded(
                        child: Text(
                            'An analysis already exists. Re-generating will overwrite it.',
                            style: TextStyle(fontSize: 12))),
                  ])),
            if (isGenerating) ...[
              ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(
                      backgroundColor: Color(0xFFE0E0E0),
                      valueColor: AlwaysStoppedAnimation<Color>(_appGreen))),
              const SizedBox(height: 8),
              Text(statusMsg,
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade600)),
            ] else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onGenerate,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: Text(
                      hasExisting
                          ? 'Re-generate Analysis'
                          : 'Generate Season Analysis',
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

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String plotId;
  final String cycleName;
  const _EmptyState({required this.plotId, required this.cycleName});

  @override
  Widget build(BuildContext context) => Container(
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
              'Tap "Generate Season Analysis" above to get AI insights on your '
              'field data, pests, diseases, and farm finances for $plotId — $cycleName.',
              style: TextStyle(
                  color: Colors.grey.shade600, height: 1.4),
              textAlign: TextAlign.center),
        ]),
      );
}