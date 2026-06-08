// lib/education/simulations/gemini_simulation_service.dart
// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

// ─── Secure backend (same as GeminiQuizService) ─────────────────────────────
const String _baseUrl = "https://us-central1-kilimomkononi-e1031.cloudfunctions.net/askGemini";

// ─── Data model returned for every simulation ────────────────────────────────

class SimulationFeedback {
  final int score;          // 0–100
  final int maxScore;       // always 100
  final String grade;       // Excellent / Good / Satisfactory / Needs Work
  final String summary;     // 2-3 sentence overall assessment
  final List<String> strengths;
  final List<String> improvements;
  final String hint;
  final String cbcStrand;

  const SimulationFeedback({
    required this.score,
    required this.maxScore,
    required this.grade,
    required this.summary,
    required this.strengths,
    required this.improvements,
    required this.hint,
    required this.cbcStrand,
  });

  factory SimulationFeedback.fromJson(Map<String, dynamic> j) =>
      SimulationFeedback(
        score: (j['score'] as num?)?.toInt() ?? 50,
        maxScore: (j['maxScore'] as num?)?.toInt() ?? 100,
        grade: j['grade'] as String? ?? 'Satisfactory',
        summary: j['summary'] as String? ?? '',
        strengths: List<String>.from(j['strengths'] as List? ?? []),
        improvements: List<String>.from(j['improvements'] as List? ?? []),
        hint: j['hint'] as String? ?? '',
        cbcStrand: j['cbcStrand'] as String? ?? '',
      );

  int get gradeLevel {
    switch (grade) {
      case 'Excellent': return 4;
      case 'Good': return 3;
      case 'Satisfactory': return 2;
      default: return 1;
    }
  }
}

// ─── Service ─────────────────────────────────────────────────────────────────

class GeminiSimulationService {
  const GeminiSimulationService();

  // ══════════════════════════════════════════════════════════════════════════
  //  1. FARM PLANTING
  // ══════════════════════════════════════════════════════════════════════════
  Future<SimulationFeedback?> evaluateFarmPlanting({
    required String cropName,
    required List<String> completedTasks,
    required int waterLevel,
    required int fertilizerLevel,
    required bool pestControlApplied,
    required int daysElapsed,
    required int rawScore,
  }) async {
    final prompt = '''
You are a CBC Kenya Agricultural Education expert evaluating a student's farm planting simulation.

Crop: $cropName
Days elapsed: $daysElapsed
Completed tasks: ${completedTasks.join(', ')}
Final water level: $waterLevel%
Fertilizer applications: $fertilizerLevel
Pest control applied: $pestControlApplied
Rule-based score: $rawScore/100

CBC Strand: Crop Production

Evaluate the student's planting decisions. Consider:
- Was soil preparation done before planting?
- Was watering level appropriate (50–75% is optimal)?
- Was fertilizer applied?
- Was pest control applied?
- What was the sequence of tasks?

Return ONLY this JSON (no markdown, no extra text):
{
  "score": <integer 0-100>,
  "maxScore": 100,
  "grade": "Excellent|Good|Satisfactory|Needs Work",
  "summary": "<2-3 sentences about overall performance>",
  "strengths": ["<strength 1>", "<strength 2>"],
  "improvements": ["<improvement 1>", "<improvement 2>"],
  "hint": "<one actionable sentence max 20 words>",
  "cbcStrand": "Crop Production"
}
''';
    return _callAndParse(prompt);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  2. MARKET TRADING
  // ══════════════════════════════════════════════════════════════════════════
  Future<SimulationFeedback?> evaluateMarketTrading({
    required double startingCash,
    required double finalCash,
    required double netProfit,
    required double profitPercent,
    required int totalTransactions,
    required List<Map<String, dynamic>> transactionHistory,
  }) async {
    final txSummary = transactionHistory.take(8).map((t) =>
      '${t['type']} ${t['quantity']}x ${t['crop']} @ ${(t['price'] as double?)?.toStringAsFixed(0) ?? '?'} Ksh'
    ).join('; ');

    final prompt = '''
You are a CBC Kenya Agricultural Education expert evaluating a student's market trading simulation.

Starting capital: ${startingCash.toStringAsFixed(0)} Ksh
Final cash: ${finalCash.toStringAsFixed(0)} Ksh
Net profit/loss: ${netProfit.toStringAsFixed(0)} Ksh
Profit %: ${profitPercent.toStringAsFixed(1)}%
Total transactions: $totalTransactions
Transaction log (most recent first): $txSummary

CBC Strand: Agricultural Economics

Evaluate the student's trading strategy. Consider:
- Did they buy low and sell high?
- Did they over-concentrate on one crop?
- Did they react to price trends sensibly?
- Did they make too many or too few transactions?

Return ONLY this JSON (no markdown, no extra text):
{
  "score": <integer 0-100>,
  "maxScore": 100,
  "grade": "Excellent|Good|Satisfactory|Needs Work",
  "summary": "<2-3 sentences about overall strategy>",
  "strengths": ["<strength 1>", "<strength 2>"],
  "improvements": ["<improvement 1>", "<improvement 2>"],
  "hint": "<one actionable sentence max 20 words>",
  "cbcStrand": "Agricultural Economics"
}
''';
    return _callAndParse(prompt);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  3. WEATHER PREDICTION
  // ══════════════════════════════════════════════════════════════════════════
  Future<SimulationFeedback?> evaluateWeatherPrediction({
    required int correctPredictions,
    required int totalPredictions,
    required double accuracy,
    required List<Map<String, dynamic>> weatherHistory,
  }) async {
    final histSummary = weatherHistory.map((d) =>
      'Day ${d['day']}: actual=${d['weather'].toString().split('.').last}, '
      'predicted=${(d['prediction'] as String?) ?? 'none'}, '
      'correct=${d['correct'] ?? false}'
    ).join('; ');

    final prompt = '''
You are a CBC Kenya Agricultural Education expert evaluating a student's weather prediction simulation.

Correct predictions: $correctPredictions / $totalPredictions
Accuracy: ${accuracy.toStringAsFixed(1)}%
Day-by-day history: $histSummary

CBC Strand: Weather and Climate in Agriculture

Evaluate the student's ability to read weather patterns and make predictions relevant to Kenyan farming. Consider:
- Did they identify patterns (humidity, temperature, cloud cover)?
- Were their errors random or systematic?
- Did accuracy improve over the 7 days?

Return ONLY this JSON (no markdown, no extra text):
{
  "score": <integer 0-100>,
  "maxScore": 100,
  "grade": "Excellent|Good|Satisfactory|Needs Work",
  "summary": "<2-3 sentences about pattern reading ability>",
  "strengths": ["<strength 1>", "<strength 2>"],
  "improvements": ["<improvement 1>", "<improvement 2>"],
  "hint": "<one actionable sentence max 20 words>",
  "cbcStrand": "Weather and Climate in Agriculture"
}
''';
    return _callAndParse(prompt);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  4. DISEASE MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════
  Future<SimulationFeedback?> evaluateDiseaseManagement({
    required String crop,
    required int plantHealth,
    required int soilHealth,
    required int diseaseInfection,
    required int fungicideCount,
    required int culturalPracticeCount,
    required int resistantVarietyUsed,
    required List<String> actionsLog,
    required int rawScore,
  }) async {
    final logSummary = actionsLog.take(8).join('; ');

    final prompt = '''
You are a CBC Kenya Agricultural Education expert evaluating a student's disease management simulation.

Crop: $crop
Final plant health: $plantHealth%
Final soil health: $soilHealth%
Disease infection level: $diseaseInfection%
Fungicide applications: $fungicideCount
Cultural practices applied: $culturalPracticeCount
Resistant variety used: ${resistantVarietyUsed > 0 ? 'Yes' : 'No'}
Rule-based score: $rawScore/100
Actions log: $logSummary

CBC Strand: Pest and Disease Management

Evaluate whether the student used Integrated Disease Management (IDM) principles. Consider:
- Balance between chemical and cultural approaches
- Soil health protection
- Plant health maintenance
- Over-reliance on fungicides (more than 4 applications is poor IDM)

Return ONLY this JSON (no markdown, no extra text):
{
  "score": <integer 0-100>,
  "maxScore": 100,
  "grade": "Excellent|Good|Satisfactory|Needs Work",
  "summary": "<2-3 sentences about IDM approach>",
  "strengths": ["<strength 1>", "<strength 2>"],
  "improvements": ["<improvement 1>", "<improvement 2>"],
  "hint": "<one actionable sentence max 20 words>",
  "cbcStrand": "Pest and Disease Management"
}
''';
    return _callAndParse(prompt);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  5. PEST MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════
  Future<SimulationFeedback?> evaluatePestManagement({
    required String crop,
    required int cropHealth,
    required int pestPopulation,
    required int beneficialInsects,
    required int chemicalSprayCount,
    required int organicTreatmentCount,
    required int biocontrolCount,
    required List<String> actionsLog,
    required int rawScore,
  }) async {
    final logSummary = actionsLog.take(8).join('; ');

    final prompt = '''
You are a CBC Kenya Agricultural Education expert evaluating a student's pest management simulation.

Crop: $crop
Final crop health: $cropHealth%
Final pest population: $pestPopulation%
Beneficial insect population: $beneficialInsects%
Chemical sprays used: $chemicalSprayCount
Organic treatments: $organicTreatmentCount
Biocontrol applications: $biocontrolCount
Rule-based score: $rawScore/100
Actions log: $logSummary

CBC Strand: Pest and Disease Management

Evaluate whether the student followed Integrated Pest Management (IPM) principles. Consider:
- Did they protect beneficial insects?
- Did they over-rely on chemical sprays (harmful to beneficial insects)?
- Did they use biocontrol and organic methods?
- Final pest population and crop health balance

Return ONLY this JSON (no markdown, no extra text):
{
  "score": <integer 0-100>,
  "maxScore": 100,
  "grade": "Excellent|Good|Satisfactory|Needs Work",
  "summary": "<2-3 sentences about IPM approach>",
  "strengths": ["<strength 1>", "<strength 2>"],
  "improvements": ["<improvement 1>", "<improvement 2>"],
  "hint": "<one actionable sentence max 20 words>",
  "cbcStrand": "Pest and Disease Management"
}
''';
    return _callAndParse(prompt);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  6. FIELD OPERATIONS
  // ══════════════════════════════════════════════════════════════════════════
  Future<SimulationFeedback?> evaluateFieldOperations({
    required String cropType,
    required int cropHealth,
    required int soilFertility,
    required int weedLevel,
    required int tillageCount,
    required int fertilizationCount,
    required int weedingCount,
    required int irrigationCount,
    required String finalGrowthStage,
    required List<String> actionsLog,
    required int rawScore,
  }) async {
    final logSummary = actionsLog.take(8).join('; ');

    final prompt = '''
You are a CBC Kenya Agricultural Education expert evaluating a student's field operations simulation.

Crop: $cropType
Final growth stage reached: $finalGrowthStage
Final crop health: $cropHealth%
Final soil fertility: $soilFertility%
Final weed level: $weedLevel%
Tillage operations: $tillageCount
Fertilization applications: $fertilizationCount
Weeding operations: $weedingCount
Irrigation events: $irrigationCount
Rule-based score: $rawScore/100
Operations log: $logSummary

CBC Strand: Soil and Water Management / Crop Production

Evaluate the student's field management decisions. Consider:
- Was tillage done at appropriate times?
- Was fertilization balanced (not over/under applied)?
- Was weeding timely (low weed level is good)?
- Was irrigation used appropriately for Kenyan conditions?

Return ONLY this JSON (no markdown, no extra text):
{
  "score": <integer 0-100>,
  "maxScore": 100,
  "grade": "Excellent|Good|Satisfactory|Needs Work",
  "summary": "<2-3 sentences about field management>",
  "strengths": ["<strength 1>", "<strength 2>"],
  "improvements": ["<improvement 1>", "<improvement 2>"],
  "hint": "<one actionable sentence max 20 words>",
  "cbcStrand": "Soil and Water Management"
}
''';
    return _callAndParse(prompt);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  7. FARM FINANCIAL MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════
  Future<SimulationFeedback?> evaluateFarmFinancial({
    required double startingBalance,
    required double finalBalance,
    required double totalRevenue,
    required double totalExpenses,
    required double landSize,
    required String currentCrop,
    required List<String> decisionsLog,
    required int rawScore,
  }) async {
    final logSummary = decisionsLog.take(8).join('; ');
    final netProfit = finalBalance - startingBalance;
    final roi = startingBalance > 0
        ? ((netProfit / startingBalance) * 100).toStringAsFixed(1)
        : '0';

    final prompt = '''
You are a CBC Kenya Agricultural Education expert evaluating a student's farm financial management simulation.

Starting balance: ${startingBalance.toStringAsFixed(0)} KES
Final balance: ${finalBalance.toStringAsFixed(0)} KES
Net profit/loss: ${netProfit.toStringAsFixed(0)} KES
ROI: $roi%
Total revenue: ${totalRevenue.toStringAsFixed(0)} KES
Total expenses: ${totalExpenses.toStringAsFixed(0)} KES
Farm size: $landSize acres
Crop grown: $currentCrop
Rule-based score: $rawScore/100
Decisions log: $logSummary

CBC Strand: Agricultural Economics / Farm Tools and Equipment

Evaluate the student's financial decision-making. Consider:
- Did they grow their balance?
- Were loans used wisely?
- Did they invest in farm expansion at appropriate times?
- Were expenses managed against revenue?

Return ONLY this JSON (no markdown, no extra text):
{
  "score": <integer 0-100>,
  "maxScore": 100,
  "grade": "Excellent|Good|Satisfactory|Needs Work",
  "summary": "<2-3 sentences about financial decisions>",
  "strengths": ["<strength 1>", "<strength 2>"],
  "improvements": ["<improvement 1>", "<improvement 2>"],
  "hint": "<one actionable sentence max 20 words>",
  "cbcStrand": "Agricultural Economics"
}
''';
    return _callAndParse(prompt);
  }

  // ─── Internal helpers ─────────────────────────────────────────────────────

  Future<SimulationFeedback?> _callAndParse(String prompt) async {
    final raw = await _callBackend(prompt);
    if (raw == null) return null;
    try {
      final cleaned = _extractJson(raw);
      return SimulationFeedback.fromJson(
          jsonDecode(cleaned) as Map<String, dynamic>);
    } catch (e) {
      print('[GeminiSimulationService] parse error: $e');
      return null;
    }
  }

  String _extractJson(String raw) {
    raw = raw.trim();
    final fenced = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```', multiLine: true);
    final match = fenced.firstMatch(raw);
    if (match != null) return match.group(1)!.trim();

    raw = raw.replaceAll(RegExp(r'^```json\s*', multiLine: true), '');
    raw = raw.replaceAll(RegExp(r'\s*```$', multiLine: true), '');

    final start = raw.indexOf(RegExp(r'[\[{]'));
    final end = raw.lastIndexOf(RegExp(r'[\]}]'));
    if (start != -1 && end != -1 && end > start) {
      return raw.substring(start, end + 1).trim();
    }
    return raw;
  }

  // ── Secure call to your Firebase Cloud Function ───────────────────────────
  Future<String?> _callBackend(String prompt) async {
    try {
      final res = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'prompt': prompt}),
      ).timeout(const Duration(seconds: 60));

      if (res.statusCode != 200) {
        print('[GeminiSimulationService] Backend error: ${res.statusCode}');
        return null;
      }

      final jsonBody = jsonDecode(res.body);
      final candidates = jsonBody['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return null;

      final text = candidates[0]['content']?['parts']?[0]?['text'] as String?;
      return text;
    } catch (e) {
      print('[GeminiSimulationService] Network error: $e');
      return null;
    }
  }
}