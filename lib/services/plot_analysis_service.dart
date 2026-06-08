// lib/services/plot_analysis_service.dart
// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

const String _geminiApiKey = 'AIzaSyDW-YIRD8p3cdveFgKG2o6KBEKWXP7mp7U';
const String _flash   = 'gemini-2.5-flash';
const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

// ─── Input containers ─────────────────────────────────────────────────────────

class FieldAnalysisInput {
  final List<Map<String, dynamic>> fieldEntries;
  final List<Map<String, dynamic>> soilTests;
  final String plotLabel;
  final String? season;
  const FieldAnalysisInput({
    required this.fieldEntries,
    required this.soilTests,
    required this.plotLabel,
    this.season,
  });
}

class PestDiseaseAnalysisInput {
  final List<Map<String, dynamic>> pestInterventions;
  final List<Map<String, dynamic>> diseaseInterventions;
  final String plotLabel;
  final String? season;
  const PestDiseaseAnalysisInput({
    required this.pestInterventions,
    required this.diseaseInterventions,
    required this.plotLabel,
    this.season,
  });
}

class FarmManagementAnalysisInput {
  final List<Map<String, dynamic>> labourActivities;
  final List<Map<String, dynamic>> equipmentCosts;
  final List<Map<String, dynamic>> inputCosts;
  final List<Map<String, dynamic>> miscCosts;
  final List<Map<String, dynamic>> revenues;
  final List<Map<String, dynamic>> loans;
  final String cropGrown;
  final String cycleName;
  const FarmManagementAnalysisInput({
    required this.labourActivities,
    required this.equipmentCosts,
    required this.inputCosts,
    required this.miscCosts,
    required this.revenues,
    required this.loans,
    required this.cropGrown,
    required this.cycleName,
  });
}

// ─── Result model ─────────────────────────────────────────────────────────────

class PlotAnalysisResult {
  final String soilSummary;
  final String cropPerformance;
  final String cropRotationAdvice;
  final String pestDiseaseSummary;
  final String financialSummary;
  final String keyLessons;
  final String newStudentBriefing;
  final DateTime generatedAt;

  const PlotAnalysisResult({
    required this.soilSummary,
    required this.cropPerformance,
    required this.cropRotationAdvice,
    required this.pestDiseaseSummary,
    required this.financialSummary,
    required this.keyLessons,
    required this.newStudentBriefing,
    required this.generatedAt,
  });

  Map<String, dynamic> toMap() => {
    'soilSummary':        soilSummary,
    'cropPerformance':    cropPerformance,
    'cropRotationAdvice': cropRotationAdvice,
    'pestDiseaseSummary': pestDiseaseSummary,
    'financialSummary':   financialSummary,
    'keyLessons':         keyLessons,
    'newUserBriefing':    newStudentBriefing,
    'generatedAt':        generatedAt.toIso8601String(),
  };

  factory PlotAnalysisResult.fromMap(Map<String, dynamic> m) => PlotAnalysisResult(
    soilSummary:        m['soilSummary']        as String? ?? '',
    cropPerformance:    m['cropPerformance']    as String? ?? '',
    cropRotationAdvice: m['cropRotationAdvice'] as String? ?? '',
    pestDiseaseSummary: m['pestDiseaseSummary'] as String? ?? '',
    financialSummary:   m['financialSummary']   as String? ?? '',
    keyLessons:         m['keyLessons']         as String? ?? '',
    newStudentBriefing: m['newUserBriefing']    as String? ?? '',
    generatedAt: m['generatedAt'] != null
        ? DateTime.tryParse(m['generatedAt'] as String) ?? DateTime.now()
        : DateTime.now(),
  );
}

// ─── Service ─────────────────────────────────────────────────────────────────

class PlotAnalysisService {
  const PlotAnalysisService();

  Future<PlotAnalysisResult?> generateFullAnalysis({
    FieldAnalysisInput? fieldData,
    PestDiseaseAnalysisInput? pestDiseaseData,
    FarmManagementAnalysisInput? farmManagementData,
    bool isEducation = true,
  }) async {
    final soilResult    = fieldData != null
        ? await _analyseField(fieldData, isEducation: isEducation) : null;
    final pestResult    = pestDiseaseData != null
        ? await _analysePestDisease(pestDiseaseData, isEducation: isEducation) : null;
    final financeResult = farmManagementData != null
        ? await _analyseFinance(farmManagementData, isEducation: isEducation) : null;

    final briefing = await _generateBriefing(
      soilSummary:        soilResult?['soilSummary']        ?? '',
      cropPerformance:    soilResult?['cropPerformance']    ?? '',
      pestDiseaseSummary: pestResult?['pestDiseaseSummary'] ?? '',
      financialSummary:   financeResult?['financialSummary'] ?? '',
      cropRotation:       soilResult?['cropRotationAdvice'] ?? '',
      isEducation:        isEducation,
    );

    return PlotAnalysisResult(
      soilSummary:        soilResult?['soilSummary']        ?? '',
      cropPerformance:    soilResult?['cropPerformance']    ?? '',
      cropRotationAdvice: soilResult?['cropRotationAdvice'] ?? '',
      pestDiseaseSummary: pestResult?['pestDiseaseSummary'] ?? '',
      financialSummary:   financeResult?['financialSummary'] ?? '',
      keyLessons:         soilResult?['keyLessons']         ?? '',
      newStudentBriefing: briefing ?? '',
      generatedAt:        DateTime.now(),
    );
  }

  Future<Map<String, String>?> _analyseField(
    FieldAnalysisInput input, {required bool isEducation}) async {
    final langNote = isEducation
        ? 'Students are secondary school level in Kenya. Use simple clear English.'
        : 'The audience is a Kenyan smallholder farmer. Be practical and direct.';
    final prompt = '''
You are an agricultural analyst for Kenyan farms. $langNote
PLOT: ${input.plotLabel}   SEASON: ${input.season ?? DateTime.now().year}
SOIL TEST DATA: ${jsonEncode(input.soilTests.take(20).toList())}
FIELD ISSUE DATA: ${jsonEncode(input.fieldEntries.take(20).toList())}
Respond ONLY with valid JSON, no markdown:
{
  "soilSummary": "2-4 sentences on soil health, nutrients, pH, corrections made",
  "cropPerformance": "2-4 sentences on crops grown, issues by stage, what worked",
  "cropRotationAdvice": "1-2 sentences: recommended next crop and why",
  "keyLessons": "3 bullet points as single string, each starting with • "
}
Keep each field under 80 words. Use Kenyan crop and fertilizer names.''';
    final raw = await _callGemini(prompt);
    if (raw == null) return null;
    try {
      return (jsonDecode(_extractJson(raw)) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v.toString()));
    } catch (e) { print('[PlotAnalysisService] field parse error: $e'); return null; }
  }

  Future<Map<String, String>?> _analysePestDisease(
    PestDiseaseAnalysisInput input, {required bool isEducation}) async {
    final langNote = isEducation
        ? 'Students are secondary school level in Kenya.'
        : 'The audience is a Kenyan smallholder farmer.';
    final prompt = '''
You are an agricultural analyst for Kenyan farms. $langNote
PLOT: ${input.plotLabel}   SEASON: ${input.season ?? DateTime.now().year}
PEST DATA: ${jsonEncode(input.pestInterventions.take(20).toList())}
DISEASE DATA: ${jsonEncode(input.diseaseInterventions.take(20).toList())}
Respond ONLY with valid JSON, no markdown:
{
  "pestDiseaseSummary": "3-5 sentences: pests/diseases found, crop stages affected, interventions used, what was most effective, what to watch next season"
}
Under 120 words. Reference specific names from the data.''';
    final raw = await _callGemini(prompt);
    if (raw == null) return null;
    try {
      return (jsonDecode(_extractJson(raw)) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v.toString()));
    } catch (e) { print('[PlotAnalysisService] pest parse error: $e'); return null; }
  }

  Future<Map<String, String>?> _analyseFinance(
    FarmManagementAnalysisInput input, {required bool isEducation}) async {
    final langNote = isEducation
        ? 'Students are secondary school level in Kenya.'
        : 'The audience is a Kenyan smallholder farmer.';
    final totalCosts   = _sumList([...input.labourActivities, ...input.equipmentCosts,
                                   ...input.inputCosts,       ...input.miscCosts]);
    final totalRevenue = _sumRevenue(input.revenues);
    final profitLoss   = totalRevenue - totalCosts;
    final prompt = '''
You are an agricultural financial analyst for Kenyan farms. $langNote
CYCLE: ${input.cycleName}   CROP: ${input.cropGrown}
Total costs: KES ${totalCosts.toStringAsFixed(0)}
Total revenue: KES ${totalRevenue.toStringAsFixed(0)}
Net: KES ${profitLoss.toStringAsFixed(0)} ${profitLoss >= 0 ? '(PROFIT)' : '(LOSS)'}
LABOUR: ${jsonEncode(input.labourActivities.take(8).toList())}
INPUTS: ${jsonEncode(input.inputCosts.take(8).toList())}
REVENUES: ${jsonEncode(input.revenues.take(8).toList())}
Respond ONLY with valid JSON, no markdown:
{
  "financialSummary": "3-5 sentences: crop grown, costs vs revenue, profit/loss, biggest cost driver, biggest revenue source, one recommendation for next cycle"
}
Under 100 words. Use KES currency.''';
    final raw = await _callGemini(prompt);
    if (raw == null) return null;
    try {
      return (jsonDecode(_extractJson(raw)) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v.toString()));
    } catch (e) { print('[PlotAnalysisService] finance parse error: $e'); return null; }
  }

  Future<String?> _generateBriefing({
    required String soilSummary,
    required String cropPerformance,
    required String pestDiseaseSummary,
    required String financialSummary,
    required String cropRotation,
    required bool   isEducation,
  }) async {
    final audience = isEducation
        ? 'a new student taking over this school farm plot'
        : 'a farmer planning their next season on this plot';
    final prompt = '''
Write a short friendly handover briefing for $audience.
Plain English. Maximum 150 words. No bullet points or headers.
SOIL: $soilSummary
CROP PERFORMANCE: $cropPerformance
PESTS & DISEASES: $pestDiseaseSummary
FINANCES: $financialSummary
RECOMMENDED NEXT CROP: $cropRotation
Start with "Welcome to this plot." End with the recommended next crop.''';
    return await _callGemini(prompt, maxTokens: 400);
  }

  double _sumList(List<Map<String, dynamic>> entries) => entries.fold(0.0, (s, e) {
    final v = e['cost'] ?? e['amount'] ?? e['value'] ?? 0;
    return s + (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);
  });

  double _sumRevenue(List<Map<String, dynamic>> entries) => entries.fold(0.0, (s, e) {
    final v = e['revenue'] ?? e['amount'] ?? e['value'] ?? 0;
    return s + (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);
  });

  String _extractJson(String raw) {
    raw = raw.trim();
    final m = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```', multiLine: true).firstMatch(raw);
    if (m != null) return m.group(1)!.trim();
    raw = raw.replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
             .replaceAll(RegExp(r'\s*```$',   multiLine: true), '');
    final s = raw.indexOf(RegExp(r'[\[{]'));
    final e = raw.lastIndexOf(RegExp(r'[\]}]'));
    return (s != -1 && e > s) ? raw.substring(s, e + 1).trim() : raw;
  }

  Future<String?> _callGemini(String prompt, {int maxTokens = 1024}) async {
    final url = Uri.parse('$_baseUrl/$_flash:generateContent?key=$_geminiApiKey');
    try {
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{'parts': [{'text': prompt}]}],
          'generationConfig': {'temperature': 0.2, 'maxOutputTokens': maxTokens},
        }),
      ).timeout(const Duration(seconds: 60));
      if (resp.statusCode != 200) {
        print('[PlotAnalysisService] HTTP ${resp.statusCode}');
        return null;
      }
      final body  = jsonDecode(resp.body) as Map<String, dynamic>;
      final cands = body['candidates'] as List?;
      if (cands == null || cands.isEmpty) return null;
      final parts = (cands[0]['content'] as Map?)?['parts'] as List?;
      if (parts == null || parts.isEmpty) return null;
      return (parts[0] as Map<String, dynamic>)['text'] as String?;
    } on TimeoutException {
      print('[PlotAnalysisService] Timed out');
      return null;
    } catch (e) {
      print('[PlotAnalysisService] Error: $e');
      return null;
    }
  }
}