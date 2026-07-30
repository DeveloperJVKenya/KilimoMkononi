// lib/education/primary/primary_ai_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const String _geminiApiKey = 'AIzaSyDW-YIRD8p3cdveFgKG2o6KBEKWXP7mp7U';
const String _flashLite    = 'gemini-2.5-flash-lite';
const String _flash        = 'gemini-2.5-flash';
const String _baseUrl      = 'https://generativelanguage.googleapis.com/v1beta/models';

// ─── Language enum ────────────────────────────────────────────────────────
enum PrimaryLanguage { english, swahili }

// ─── Data Models ─────────────────────────────────────────────────────────

class PrimaryQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String funExplanation;

  const PrimaryQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.funExplanation,
  });

  factory PrimaryQuestion.fromJson(Map<String, dynamic> j) => PrimaryQuestion(
        question:       j['question'] as String,
        options:        List<String>.from(j['options'] as List),
        correctIndex:   (j['correct'] as num).toInt(),
        funExplanation: j['funExplanation'] as String? ?? '',
      );
}

class SpotMistakeItem {
  final String sentence, wrongWord, correction, explanation;
  const SpotMistakeItem({
    required this.sentence, required this.wrongWord,
    required this.correction, required this.explanation,
  });
  factory SpotMistakeItem.fromJson(Map<String, dynamic> j) => SpotMistakeItem(
        sentence:    j['sentence']    as String,
        wrongWord:   j['wrongWord']   as String,
        correction:  j['correction']  as String,
        explanation: j['explanation'] as String,
      );
}

class FarmingStory {
  final String story, question, answer;
  const FarmingStory({required this.story, required this.question, required this.answer});
  factory FarmingStory.fromJson(Map<String, dynamic> j) => FarmingStory(
        story:    j['story']    as String,
        question: j['question'] as String,
        answer:   j['answer']   as String,
      );
}

/// Three progressively revealing clues for the "What am I?" game.
class WhatAmIClues {
  final String item;         // the answer
  final List<String> clues;  // exactly 3, hardest-first
  const WhatAmIClues({required this.item, required this.clues});
  factory WhatAmIClues.fromJson(Map<String, dynamic> j) => WhatAmIClues(
        item:  j['item']  as String,
        clues: List<String>.from(j['clues'] as List),
      );
}

/// A fill-in-the-blank sentence with 3 word choices.
class FillBlankItem {
  final String sentence;      // sentence with "___" where the blank is
  final String blankWord;     // correct answer (already hidden in sentence)
  final List<String> choices; // exactly 3 options incl. correct
  final int correctIndex;     // 0-based index in choices
  final String explanation;   // why blankWord is correct
  const FillBlankItem({
    required this.sentence, required this.blankWord,
    required this.choices, required this.correctIndex,
    required this.explanation,
  });
  factory FillBlankItem.fromJson(Map<String, dynamic> j) => FillBlankItem(
        sentence:      j['sentence']     as String,
        blankWord:     j['blankWord']    as String,
        choices:       List<String>.from(j['choices'] as List),
        correctIndex:  (j['correctIndex'] as num).toInt(),
        explanation:   j['explanation']  as String,
      );
}

/// A structured 40-minute CBC lesson plan.
class LessonPlan {
  final String topic, objective, materials, activity, assessment;
  const LessonPlan({
    required this.topic, required this.objective, required this.materials,
    required this.activity, required this.assessment,
  });
  factory LessonPlan.fromJson(Map<String, dynamic> j) => LessonPlan(
        topic:      j['topic']      as String,
        objective:  j['objective']  as String,
        materials:  j['materials']  as String,
        activity:   j['activity']   as String,
        assessment: j['assessment'] as String,
      );
}

/// Weekly class summary for teachers.
class ClassSummary {
  final String summary;      // plain English paragraph
  final String topTopic;     // most-completed topic
  final String weakTopic;    // lowest-scoring topic
  final List<String> tips;   // 2-3 actionable teaching tips
  const ClassSummary({
    required this.summary, required this.topTopic,
    required this.weakTopic, required this.tips,
  });
  factory ClassSummary.fromJson(Map<String, dynamic> j) => ClassSummary(
        summary:   j['summary']   as String,
        topTopic:  j['topTopic']  as String,
        weakTopic: j['weakTopic'] as String,
        tips:      List<String>.from(j['tips'] as List),
      );
}

/// Per-student differentiation hint for the teacher.
class StudentHint {
  final String weakTopic;   // e.g. "Soil & Water"
  final String hint;        // one actionable sentence for the teacher
  const StudentHint({required this.weakTopic, required this.hint});
  factory StudentHint.fromJson(Map<String, dynamic> j) => StudentHint(
        weakTopic: j['weakTopic'] as String,
        hint:      j['hint']      as String,
      );
}

// ─── Service ─────────────────────────────────────────────────────────────

class PrimaryAiService {
  const PrimaryAiService();

  // ── 1. Tap-to-explain ─────────────────────────────────────────────────
  Future<String> explainForChild({
    required String topic,
    required String question,
    required String grade,
    PrimaryLanguage language = PrimaryLanguage.english,
  }) async {
    final langLine = language == PrimaryLanguage.swahili
        ? 'Answer in simple Kiswahili that a $grade pupil understands.'
        : 'Use very simple English a $grade pupil understands.';

    final prompt = '''
You are a friendly teacher at a Kenyan primary school.
A $grade pupil just read about "$topic" and asked: "$question"
Answer in exactly 2-3 short sentences.
$langLine
Add one comparison to something the child sees in daily Kenyan life.
Do NOT start with praise. Return only plain answer text.
''';
    final raw = await _call(prompt, model: _flashLite, maxTokens: 256);
    return raw?.trim() ?? 'Ask your teacher to explain more about $topic.';
  }

  // ── 2. Mini quiz ──────────────────────────────────────────────────────
  Future<List<PrimaryQuestion>> generateMiniQuiz({
    required String topic,
    required String grade,
    int count = 3,
    PrimaryLanguage language = PrimaryLanguage.english,
  }) async {
    final langLine = language == PrimaryLanguage.swahili
        ? 'Write questions and options in simple Kiswahili.'
        : 'Use very simple English suitable for primary pupils.';

    final prompt = '''
You are a CBC Kenya Agricultural Education expert.
Generate exactly $count MCQ questions about "$topic" for $grade pupils in Kenya.
$langLine
Each question: exactly 4 options, "correct" is 0-based index, "funExplanation" max 20 words.
All content must relate to Kenyan farming context.
Return ONLY a valid JSON array. No markdown, no backticks.
[{"question":"...","options":["...","...","...","..."],"correct":0,"funExplanation":"..."}]
''';
    final raw = await _call(prompt, model: _flashLite, maxTokens: 1024);
    if (raw == null) return [];
    try {
      final list = jsonDecode(_extractJson(raw)) as List;
      return list.map((e) => PrimaryQuestion.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[PrimaryAiService] generateMiniQuiz parse error: $e');
      return [];
    }
  }

  // ── 3. Spot the mistake ───────────────────────────────────────────────
  Future<SpotMistakeItem?> generateSpotMistake({
    required String topic,
    required String grade,
    PrimaryLanguage language = PrimaryLanguage.english,
  }) async {
    final langLine = language == PrimaryLanguage.swahili
        ? 'Write the sentence and explanation in simple Kiswahili.'
        : 'Write in simple English.';

    final prompt = '''
CBC Kenya Agricultural Education expert creating a learning game.
Write ONE short sentence (max 20 words) about "$topic" with EXACTLY ONE factual mistake.
$langLine
Return ONLY this JSON object:
{"sentence":"...","wrongWord":"...","correction":"...","explanation":"..."}
''';
    final raw = await _call(prompt, model: _flashLite, maxTokens: 512);
    if (raw == null) return null;
    try {
      return SpotMistakeItem.fromJson(jsonDecode(_extractJson(raw)) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[PrimaryAiService] generateSpotMistake parse error: $e');
      return null;
    }
  }

  // ── 4. Farming story ──────────────────────────────────────────────────
  Future<FarmingStory?> generateFarmingStory({
    required String strand,
    required String grade,
    PrimaryLanguage language = PrimaryLanguage.english,
  }) async {
    final langLine = language == PrimaryLanguage.swahili
        ? 'Write the story and question in simple Kiswahili.'
        : 'Use very simple English a $grade pupil understands.';

    final prompt = '''
CBC Kenya Agricultural Education teacher.
Write a short farming story for $grade pupils about "$strand".
The hero is a Kenyan child (Amina, Kamau, Wanjiku, Opiyo or Aisha).
Exactly 4-5 sentences. Kenyan village setting.
$langLine
Return ONLY: {"story":"...","question":"...","answer":"..."}
''';
    final raw = await _call(prompt, model: _flash, maxTokens: 1024);
    if (raw == null) return null;
    try {
      return FarmingStory.fromJson(jsonDecode(_extractJson(raw)) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[PrimaryAiService] generateFarmingStory parse error: $e');
      return null;
    }
  }

  // ── 5. Fun fact refresh ───────────────────────────────────────────────
  Future<String?> generateNewFunFact({
    required String item,
    required String existingFact,
    PrimaryLanguage language = PrimaryLanguage.english,
  }) async {
    final langLine = language == PrimaryLanguage.swahili
        ? 'Write the fact in simple Kiswahili.'
        : 'Write for primary school pupils in simple English.';

    final prompt = '''
Give ONE surprising fun fact about "$item" relevant to Kenyan farming.
Maximum 30 words. Different from: "$existingFact"
$langLine
Return only the plain fact text.
''';
    final raw = await _call(prompt, model: _flashLite, maxTokens: 128);
    return raw?.trim();
  }

  // ── 6. "What am I?" guessing game ─────────────────────────────────────
  /// Generates 3 clues for a random item within [topic]. Clues go from
  /// hardest (most vague) to easiest (most specific) — index 0 = hardest.
  Future<WhatAmIClues?> generateWhatAmIClues({
    required String topic,
    required String grade,
    PrimaryLanguage language = PrimaryLanguage.english,
  }) async {
    final langLine = language == PrimaryLanguage.swahili
        ? 'Write all clues in simple Kiswahili.'
        : 'Write in very simple English a $grade pupil understands.';

    final prompt = '''
CBC Kenya Agricultural Education expert.
Pick ONE specific item that belongs to the topic "$topic" (e.g. a specific animal, tool, crop, or soil type).
Write 3 clues about it. Clue 1 is vague/hard, clue 3 is easy/obvious.
$langLine
All clues must be short (max 15 words each). Kenyan farming context.
Return ONLY: {"item":"exact name","clues":["hardest clue","medium clue","easiest clue"]}
''';
    final raw = await _call(prompt, model: _flashLite, maxTokens: 512);
    if (raw == null) return null;
    try {
      return WhatAmIClues.fromJson(jsonDecode(_extractJson(raw)) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[PrimaryAiService] generateWhatAmIClues parse error: $e');
      return null;
    }
  }

  // ── 7. Fill-in-the-blank ──────────────────────────────────────────────
  Future<FillBlankItem?> generateFillBlank({
    required String topic,
    required String grade,
    PrimaryLanguage language = PrimaryLanguage.english,
  }) async {
    final langLine = language == PrimaryLanguage.swahili
        ? 'Write the sentence and choices in simple Kiswahili.'
        : 'Use very simple English suitable for $grade pupils.';

    final prompt = '''
CBC Kenya Agricultural Education expert.
Write ONE sentence about "$topic" with one key word replaced by "___".
$langLine
Provide exactly 3 word choices (including the correct one).
"correctIndex" is the 0-based index of the correct word in "choices".
"explanation" is one short sentence (max 15 words) explaining why it is correct.
Return ONLY:
{"sentence":"Farmers use ___ to dig the soil.","blankWord":"jembe","choices":["jembe","maji","mbegu"],"correctIndex":0,"explanation":"A jembe is the hoe used to dig."}
''';
    final raw = await _call(prompt, model: _flashLite, maxTokens: 512);
    if (raw == null) return null;
    try {
      return FillBlankItem.fromJson(jsonDecode(_extractJson(raw)) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[PrimaryAiService] generateFillBlank parse error: $e');
      return null;
    }
  }

  // ── 8. Daily challenge (teacher generates, cached per class/day) ──────
  /// Returns a challenge type + topic combination as a JSON map.
  /// The caller is responsible for caching in Firestore.
  Future<Map<String, String>?> generateDailyChallenge({
    required String grade,
    required List<String> topics,
  }) async {
    final topicList = topics.join(', ');
    final prompt = '''
CBC Kenya Agricultural Education expert.
Pick ONE activity for $grade pupils today.
Available topics: $topicList
Available activity types: quiz, spotMistake, fillBlank, whatAmI
Return ONLY: {"type":"quiz","topic":"Farm Animals","emoji":"🐄","title":"Farm Animals Quiz","subtitle":"Test what you know about farm animals!"}
''';
    final raw = await _call(prompt, model: _flashLite, maxTokens: 256);
    if (raw == null) return null;
    try {
      return Map<String, String>.from(jsonDecode(_extractJson(raw)) as Map);
    } catch (e) {
      debugPrint('[PrimaryAiService] generateDailyChallenge parse error: $e');
      return null;
    }
  }

  // ── 9. Lesson plan (teacher) ──────────────────────────────────────────
  Future<LessonPlan?> generateLessonPlan({
    required String topic,
    required String grade,
  }) async {
    final prompt = '''
CBC Kenya Agricultural Education teacher trainer.
Write a 40-minute lesson plan for $grade on "$topic".

Return ONLY this JSON (no markdown):
{
  "topic": "$topic",
  "objective": "By the end of the lesson pupils will be able to… (1-2 sentences)",
  "materials": "Comma-separated list of materials needed",
  "activity": "Step-by-step activity sequence (3-5 steps, each max 30 words)",
  "assessment": "Two simple assessment questions the teacher can ask at the end"
}
Keep each field concise. Use plain simple language.
''';
    final raw = await _call(prompt, model: _flash, maxTokens: 1024);
    if (raw == null) return null;
    try {
      return LessonPlan.fromJson(jsonDecode(_extractJson(raw)) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[PrimaryAiService] generateLessonPlan parse error: $e');
      return null;
    }
  }

  // ── 10. Weekly class summary (teacher) ───────────────────────────────
  /// [activityData] is a map of topic → {quizAvg, completions}
  Future<ClassSummary?> generateClassSummary({
    required String grade,
    required String schoolName,
    required Map<String, Map<String, dynamic>> activityData,
  }) async {
    final dataStr = activityData.entries
        .map((e) => '${e.key}: ${e.value['completions']} completions, avg score ${e.value['quizAvg']}%')
        .join('\n');

    final prompt = '''
CBC Kenya Agricultural Education analyst.
Write a brief weekly summary for a $grade teacher at $schoolName.

Activity data this week:
$dataStr

Return ONLY this JSON:
{
  "summary": "2-3 sentence plain English summary of the week",
  "topTopic": "topic with most completions",
  "weakTopic": "topic with lowest avg score",
  "tips": ["tip 1 max 20 words", "tip 2 max 20 words"]
}
Be encouraging and practical. Keep each field concise.
''';
    final raw = await _call(prompt, model: _flash, maxTokens: 768);
    if (raw == null) return null;
    try {
      return ClassSummary.fromJson(jsonDecode(_extractJson(raw)) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[PrimaryAiService] generateClassSummary parse error: $e');
      return null;
    }
  }

  // ── 11. Per-student differentiation hint (teacher) ───────────────────
  /// [scoresByTopic] is a map of topic → average score 0-100
  Future<StudentHint?> generateStudentHint({
    required String studentName,
    required String grade,
    required Map<String, int> scoresByTopic,
  }) async {
    final dataStr = scoresByTopic.entries
        .map((e) => '${e.key}: ${e.value}%')
        .join(', ');

    final prompt = '''
CBC Kenya primary school teacher advisor.
Student: $studentName, $grade
Scores this week: $dataStr

Return ONLY this JSON:
{"weakTopic":"topic with lowest score","hint":"One practical teaching suggestion max 20 words for the teacher."}
''';
    final raw = await _call(prompt, model: _flashLite, maxTokens: 256);
    if (raw == null) return null;
    try {
      return StudentHint.fromJson(jsonDecode(_extractJson(raw)) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[PrimaryAiService] generateStudentHint parse error: $e');
      return null;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────
  String _extractJson(String raw) {
    raw = raw.trim();
    final fenced = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```', multiLine: true);
    final match = fenced.firstMatch(raw);
    if (match != null) return match.group(1)!.trim();
    raw = raw.replaceAll(RegExp(r'^```json\s*', multiLine: true), '');
    raw = raw.replaceAll(RegExp(r'\s*```$', multiLine: true), '');
    final start = raw.indexOf(RegExp(r'[\[{]'));
    final end   = raw.lastIndexOf(RegExp(r'[\]}]'));
    if (start != -1 && end != -1 && end > start) return raw.substring(start, end + 1).trim();
    return raw;
  }

  Future<String?> _call(String prompt, {String model = _flashLite, int maxTokens = 512}) async {
    final url = Uri.parse('$_baseUrl/$model:generateContent?key=$_geminiApiKey');
    try {
      final response = await http.post(url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{'parts': [{'text': prompt}]}],
          'generationConfig': {'temperature': 0.4, 'maxOutputTokens': maxTokens},
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 429) { debugPrint('[PrimaryAiService] Rate limited.'); return null; }
      if (response.statusCode != 200) { debugPrint('[PrimaryAiService] HTTP ${response.statusCode}'); return null; }

      final body       = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = body['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return null;
      final content = candidates[0]['content'] as Map<String, dynamic>?;
      final parts   = content?['parts'] as List?;
      if (parts == null || parts.isEmpty) return null;
      return (parts[0] as Map<String, dynamic>)['text'] as String?;
    } on TimeoutException {
      debugPrint('[PrimaryAiService] Timed out.');
      return null;
    } catch (e) {
      debugPrint('[PrimaryAiService] Network error: $e');
      return null;
    }
  }
}