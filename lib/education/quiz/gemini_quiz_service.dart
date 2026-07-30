import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ─── Firebase Function URL ───────────────────────────────────────────────
// ─── Firebase Function URL ───────────────────────────────────────────────
const String _baseUrl =
    "https://us-central1-kilimomkononi-e1031.cloudfunctions.net/askGemini";

// ─── CBC Strands ─────────────────────────────────────────────────────────
const List<String> cbcAgriculturalStrands = [
  'Crop Production',
  'Livestock Production',
  'Soil and Water Management',
  'Pest and Disease Management',
  'Agricultural Economics',
  'Farm Tools and Equipment',
  'Post-Harvest Management',
  'Environmental Conservation',
  'Weather and Climate in Agriculture',
  'Market Systems and Trade',
];

// ─── Data Models ─────────────────────────────────────────────────────────
enum QuestionType { mcq, essay }

class QuizQuestion {
  final String question;
  final QuestionType type;
  final String difficulty;
  final String strand;

  final List<String>? options;
  final int? correctIndex;

  final String? modelAnswer;
  final String? rubric;

  const QuizQuestion({
    required this.question,
    required this.type,
    required this.difficulty,
    required this.strand,
    this.options,
    this.correctIndex,
    this.modelAnswer,
    this.rubric,
  });

  Map<String, dynamic> toJson() => {
        'question': question,
        'type': type.name,
        'difficulty': difficulty,
        'strand': strand,
        if (options != null) 'options': options,
        if (correctIndex != null) 'correct': correctIndex,
        if (modelAnswer != null) 'modelAnswer': modelAnswer,
        if (rubric != null) 'rubric': rubric,
      };

  factory QuizQuestion.fromJson(Map<String, dynamic> j) => QuizQuestion(
        question: j['question'] as String,
        type: j['type'] == 'essay' ? QuestionType.essay : QuestionType.mcq,
        difficulty: j['difficulty'] as String? ?? 'medium',
        strand: j['strand'] as String? ?? '',
        options: j['options'] != null ? List<String>.from(j['options']) : null,
        correctIndex: j['correct'] as int?,
        modelAnswer: j['modelAnswer'] as String?,
        rubric: j['rubric'] as String?,
      );
}

class EssayFeedback {
  final int score;
  final int maxScore;
  final String grade;
  final String feedback;
  final String hint;

  const EssayFeedback({
    required this.score,
    required this.maxScore,
    required this.grade,
    required this.feedback,
    required this.hint,
  });

  factory EssayFeedback.fromJson(Map<String, dynamic> j) => EssayFeedback(
        score: (j['score'] as num).toInt(),
        maxScore: (j['maxScore'] as num?)?.toInt() ?? 10,
        grade: j['grade'] as String,
        feedback: j['feedback'] as String,
        hint: j['hint'] as String,
      );
}

// ─── Service ─────────────────────────────────────────────────────────────
class GeminiQuizService {
  const GeminiQuizService();

  // ── 1. Generate questions ──────────────────────────────────────────────
  Future<List<QuizQuestion>> generateQuestions({
    required String subject,
    required String strand,
    required String grade,
    required bool isPrimary,
    String questionType = 'mcq',
    int count = 5,
    String difficulty = 'medium',
  }) async {
    final langGuide = isPrimary
        ? 'Use very simple English suitable for Grade 1–6 pupils.'
        : 'Use clear English for secondary-level agricultural students in Kenya.';

    final typeGuide = switch (questionType) {
      'essay' => 'Generate ONLY essay questions.',
      'mixed' => 'Generate a mix of MCQ and essay questions.',
      _ => 'Generate ONLY multiple choice questions with exactly 4 options each.',
    };

    final prompt = '''
You are a CBC Kenya Agricultural Education expert.

Generate exactly $count quiz question(s) about "$subject" for $grade students.
CBC Strand: $strand
Difficulty: $difficulty

$langGuide
$typeGuide

Rules:
- Kenyan agriculture context
- Return ONLY JSON array
- No markdown
- MCQ: 4 options, correct is index
- Essay: include modelAnswer + rubric
''';

    final raw = await _callBackend(prompt);
    if (raw == null) return [];

    try {
      final cleaned = _extractJson(raw);
      final list = jsonDecode(cleaned) as List;
      return list.map((e) => QuizQuestion.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Parse error: $e');
      return [];
    }
  }

  // ── 2. Mark essay ──────────────────────────────────────────────────────
  Future<EssayFeedback?> markEssay({
    required String question,
    required String modelAnswer,
    required String rubric,
    required String studentAnswer,
    required String grade,
    required String strand,
  }) async {
    final prompt = '''
Question: $question
Grade: $grade
Strand: $strand

Model Answer: $modelAnswer
Rubric: $rubric
Student Answer: $studentAnswer

Return JSON:
{
 "score": 0-10,
 "maxScore": 10,
 "grade": "...",
 "feedback": "...",
 "hint": "..."
}
''';

    final raw = await _callBackend(prompt);
    if (raw == null) return null;

    try {
      final cleaned = _extractJson(raw);
      return EssayFeedback.fromJson(jsonDecode(cleaned));
    } catch (_) {
      return null;
    }
  }

  // ── 3. Adaptive ────────────────────────────────────────────────────────
  Future<QuizQuestion?> generateAdaptiveQuestion({
    required String subject,
    required String strand,
    required String grade,
    required bool isPrimary,
    required List<bool> answeredCorrectly,
    required String currentDifficulty,
    required QuestionType preferredType,
  }) async {
    final nextDifficulty = answeredCorrectly.every((b) => b)
        ? 'hard'
        : answeredCorrectly.every((b) => !b)
            ? 'easy'
            : currentDifficulty;

    final list = await generateQuestions(
      subject: subject,
      strand: strand,
      grade: grade,
      isPrimary: isPrimary,
      questionType: preferredType == QuestionType.essay ? 'essay' : 'mcq',
      count: 1,
      difficulty: nextDifficulty,
    );

    return list.isEmpty ? null : list.first;
  }

  // ── 4. Explain wrong answer ────────────────────────────────────────────
  Future<String> explainWrongAnswer({
    required String question,
    required String wrongOption,
    required String correctOption,
    required String subject,
  }) async {
    final prompt = '''
Question: $question
Wrong: $wrongOption
Correct: $correctOption

Explain briefly (1 sentence).
''';

    final raw = await _callBackend(prompt);
    return raw?.trim() ?? "Correct answer is $correctOption.";
  }

  // ── Backend Call ───────────────────────────────────────────────────────
  Future<String?> _callBackend(String prompt) async {
    try {
      final res = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'prompt': prompt}),
      ).timeout(const Duration(seconds: 60));

      if (res.statusCode != 200) {
        debugPrint('Backend error: ${res.body}');
        return null;
      }

      final jsonBody = jsonDecode(res.body);
      final candidates = jsonBody['candidates'];

      if (candidates == null || candidates.isEmpty) return null;

      return candidates[0]['content']['parts'][0]['text'];
    } catch (e) {
      debugPrint('Network error: $e');
      return null;
    }
  }

  // ── JSON cleaner ───────────────────────────────────────────────────────
  String _extractJson(String raw) {
    final start = raw.indexOf(RegExp(r'[\[{]'));
    final end = raw.lastIndexOf(RegExp(r'[\]}]'));
    if (start != -1 && end != -1) {
      return raw.substring(start, end + 1);
    }
    return raw;
  }
}