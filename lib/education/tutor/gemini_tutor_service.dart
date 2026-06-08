// lib/education/tutor/gemini_tutor_service.dart
// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// Reuse the same secure backend as GeminiQuizService
const String _baseUrl = "https://us-central1-kilimomkononi-e1031.cloudfunctions.net/askGemini";

// ─── Data Models ─────────────────────────────────────────────────────────

class TutorMessage {
  final String role;        // 'user' | 'assistant'
  final String text;
  final DateTime timestamp;

  const TutorMessage({
    required this.role,
    required this.text,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'role': role,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
      };

  factory TutorMessage.fromJson(Map<String, dynamic> j) => TutorMessage(
        role: j['role'] as String,
        text: j['text'] as String,
        timestamp: DateTime.parse(j['timestamp'] as String),
      );

  /// Converts to Gemini-compatible content part
  Map<String, dynamic> toGeminiPart() => {
        'role': role == 'assistant' ? 'model' : 'user',
        'parts': [{'text': text}],
      };
}

// ─── Service ─────────────────────────────────────────────────────────────

class GeminiTutorService {
  const GeminiTutorService();

  // ── System prompt ─────────────────────────────────────────────────────
  static const String _systemPrompt = '''
You are Shamba AI, a friendly agricultural tutor for Kenyan students following the CBC curriculum.

YOUR CORE RULES — never break these:
1. NEVER give the full answer directly. Always ask a guiding question that leads the student to the answer themselves.
2. If the student is clearly stuck after 2-3 attempts, give ONE small concrete hint — still not the full answer.
3. Respond in the SAME LANGUAGE the student used. If they write in Swahili, respond in Swahili. If English, respond in English. If mixed, mirror their mix.
4. Keep every response SHORT — maximum 3 sentences plus ONE guiding question at the end.
5. Always relate explanations to Kenyan farming: use local crop names (maize/mahindi, beans/maharagwe, tea, coffee, pyrethrum), Kenyan seasons (long rains/masika, short rains/vuli), and local context.
6. If asked something completely unrelated to agriculture or science, gently redirect: "That's outside my farming expertise! Let me help you with something agricultural instead."
7. NEVER write essays, complete assignments, or do homework for the student.
8. NEVER reveal the model answer even if the student asks directly. Say: "I'm here to help you discover the answer yourself!"
9. Be warm, encouraging, and patient. Celebrate small progress with short phrases like "Vizuri sana!" or "Good thinking!"
10. End EVERY response with exactly ONE question that moves the student one step forward.
''';

  // ── 1. Send a message ─────────────────────────────────────────────────
  Future<String?> sendMessage({
    required String userMessage,
    required List<TutorMessage> history,
    required String topic,
    required String grade,
    required bool isPrimary,
    String? contextQuestion,
    String? contextModule,
  }) async {
    // Build full prompt with system + history + new message
    final fullPrompt = _buildFullPrompt(
      userMessage: userMessage,
      history: history,
      topic: topic,
      grade: grade,
      isPrimary: isPrimary,
      contextQuestion: contextQuestion,
      contextModule: contextModule,
    );

    final raw = await _callBackend(fullPrompt);
    if (raw == null) return _fallbackMessage(isPrimary);

    return raw.trim();
  }

  // ── 2. Generate context-aware opener ──────────────────────────────────
  Future<String?> generateContextOpener({
    required String questionText,
    required String module,
    required String grade,
    required bool isPrimary,
    bool wrongAnswer = false,
  }) async {
    final prompt = wrongAnswer
        ? '''
A $grade student just answered this question incorrectly:
"$questionText"

Write ONE short, warm Socratic opener (2 sentences max) that:
- Does NOT reveal the answer
- Encourages the student to think about WHY their answer might not be right
- Ends with a guiding question
Kenya agriculture context. Keep it very simple${isPrimary ? ' for a primary pupil' : ''}.
'''
        : '''
A $grade student wants to explore this topic further:
"$questionText"

Write ONE short, curious Socratic opener (2 sentences max) that:
- Sparks their thinking about the topic
- Ends with ONE open question to get them started
Kenya agriculture context. Keep it very simple${isPrimary ? ' for a primary pupil' : ''}.
''';

    final raw = await _callBackend(prompt);
    return raw?.trim();
  }

  // ── Backend Call (reuses your secure askGemini function) ──────────────
  Future<String?> _callBackend(String prompt) async {
    try {
      final res = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'prompt': prompt}),
      ).timeout(const Duration(seconds: 60));

      debugPrint('[Tutor] status: ${res.statusCode}');
      debugPrint('[Tutor] body: ${res.body.substring(0, res.body.length.clamp(0, 500))}');

      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      }

      final jsonBody = jsonDecode(res.body);

      if (jsonBody is Map<String, dynamic>) {
        if (jsonBody['candidates'] != null) {
          return jsonBody['candidates'][0]['content']['parts'][0]['text'];
        }

        if (jsonBody['text'] != null) {
          return jsonBody['text'];
        }

        if (jsonBody['response'] != null) {
          return jsonBody['response'];
        }
      }
    } catch (e) {
      debugPrint('[Tutor] Error: $e');
    }
    return null;
  }
  // ── Build full prompt with history ────────────────────────────────────
  String _buildFullPrompt({
    required String userMessage,
    required List<TutorMessage> history,
    required String topic,
    required String grade,
    required bool isPrimary,
    String? contextQuestion,
    String? contextModule,
  }) {
    final contextSection = contextQuestion != null
        ? '\nCONTEXT: The student came from a $contextModule activity. The specific question/scenario was: "$contextQuestion". Help them understand the concept behind it without giving the answer.'
        : '';

    final gradeNote = isPrimary
        ? 'This is a PRIMARY school student ($grade). Use very simple words and short sentences.'
        : 'This is a SECONDARY/JUNIOR school student ($grade). You can use slightly more advanced agricultural terminology but still explain clearly.';

    final systemTurn = '$_systemPrompt\n\nCURRENT SESSION:\n- Topic: $topic\n- Grade: $grade\n- $gradeNote$contextSection';

    // Build conversation history
    final buffer = StringBuffer();
    buffer.writeln(systemTurn);
    buffer.writeln('\n--- Conversation History ---');

    for (final msg in history) {
      final role = msg.role == 'user' ? 'Student' : 'Shamba AI';
      buffer.writeln('$role: ${msg.text}');
    }

    buffer.writeln('\nStudent: $userMessage');
    buffer.writeln('\nShamba AI:');

    return buffer.toString();
  }

  String _fallbackMessage(bool isPrimary) {
    return isPrimary
        ? "Samahani, nilikuwa na tatizo kidogo! Jaribu tena. (Sorry, I had a small problem! Try again.) 🌱"
        : "I'm having a connection issue right now. Please try again in a moment — I'm here to help! 🌿";
  }
}