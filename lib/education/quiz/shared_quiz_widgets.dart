// lib/education/quiz/shared_quiz_widgets.dart
//
// Reusable quiz builder + quiz screen + teacher essay review

// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kilimomkononi/utils/firestore_helper.dart';
import 'package:kilimomkononi/education/tutor/tutor_chat_screen.dart';
import 'gemini_quiz_service.dart';

const Color _green = Color(0xFF032704);

// ═══════════════════════════════════════════════════════════════════════════
//  EduQuizBuilder
// ═══════════════════════════════════════════════════════════════════════════

class EduQuizBuilder extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;
  final String topicLabel;
  final String geminiSubject;
  final String grade;
  final bool isPrimary;

  const EduQuizBuilder({
    super.key,
    required this.onSave,
    required this.topicLabel,
    required this.geminiSubject,
    required this.grade,
    required this.isPrimary,
  });

  @override
  State<EduQuizBuilder> createState() => _EduQuizBuilderState();
}

class _EduQuizBuilderState extends State<EduQuizBuilder> {
  final _titleCtrl = TextEditingController();
  final _aiSubjectCtrl = TextEditingController();

  final List<QuizQuestion> _questions = [];
  final _service = const GeminiQuizService();

  bool _isGenerating = false;
  String _selectedStrand = cbcAgriculturalStrands[0];
  String _aiDifficulty = 'medium';
  String _quizType = 'mcq';        // ← 'mcq', 'essay', 'mixed'
  final int _aiCount = 5;

  @override
  void initState() {
    super.initState();
    _aiSubjectCtrl.text = widget.geminiSubject;
  }

  @override
  void dispose() {
    _aiSubjectCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  // ── AI Generation ─────────────────────────────────────────────────────
  Future<void> _generateWithAI() async {
    setState(() => _isGenerating = true);

    final subjectToUse = _aiSubjectCtrl.text.trim().isNotEmpty
        ? _aiSubjectCtrl.text.trim()
        : widget.geminiSubject;

    final generated = await _service.generateQuestions(
      subject: subjectToUse,
      strand: _selectedStrand,
      grade: widget.grade,
      isPrimary: widget.isPrimary,
      questionType: widget.isPrimary ? 'mcq' : _quizType,
      count: _aiCount,
      difficulty: _aiDifficulty,
    );

    setState(() => _isGenerating = false);

    if (!mounted) return;

    if (generated.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI generation failed — check connection.'), backgroundColor: Colors.red),
      );
      return;
    }

    _showAiReviewDialog(generated);
  }

  void _showAiReviewDialog(List<QuizQuestion> candidates) {
    final selected = List<bool>.filled(candidates.length, true);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8, maxWidth: 600),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(color: _green, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
                          SizedBox(width: 8),
                          Text('AI-generated questions', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text('Review and select which to add.', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: candidates.length,
                    itemBuilder: (_, i) {
                      final q = candidates[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: CheckboxListTile(
                          value: selected[i],
                          onChanged: (v) => setInner(() => selected[i] = v ?? true),
                          activeColor: _green,
                          title: Text(q.question, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                _Badge(label: q.type == QuestionType.essay ? 'Essay' : 'MCQ', color: q.type == QuestionType.essay ? Colors.purple : Colors.blue),
                                const SizedBox(width: 8),
                                _Badge(label: q.difficulty, color: _diffColor(q.difficulty)),
                              ]),
                              if (q.type == QuestionType.essay && q.rubric != null)
                                Text('Rubric: ${q.rubric}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Row(
                    children: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Discard all')),
                      const Spacer(),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add_task),
                        label: Text('Add ${selected.where((b) => b).length} question(s)'),
                        style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white),
                        onPressed: () {
                          final toAdd = [for (int i = 0; i < candidates.length; i++) if (selected[i]) candidates[i]];
                          setState(() => _questions.addAll(toAdd));
                          Navigator.pop(ctx);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Manual Add Question ───────────────────────────────────────────────
  void _addManualQuestion() {
    final questionCtrl = TextEditingController();
    final optionCtrls = List.generate(4, (_) => TextEditingController());
    final modelAnsCtrl = TextEditingController();
    final rubricCtrl = TextEditingController();

    QuestionType selType = QuestionType.mcq;
    String selDifficulty = 'medium';
    int correctIndex = 0;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Question Manually'),
        content: StatefulBuilder(
          builder: (ctx, setInner) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: questionCtrl, decoration: const InputDecoration(labelText: 'Question text'), maxLines: 3),
                const SizedBox(height: 16),

                if (!widget.isPrimary) ...[
                  const Text('Question Type', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SegmentedButton<QuestionType>(
                    segments: const [
                      ButtonSegment(value: QuestionType.mcq, label: Text('MCQ')),
                      ButtonSegment(value: QuestionType.essay, label: Text('Essay')),
                    ],
                    selected: {selType},
                    onSelectionChanged: (s) => setInner(() => selType = s.first),
                  ),
                  const SizedBox(height: 16),
                ],

                if (selType == QuestionType.mcq) ...[
                  const Text('Options (select correct one)', style: TextStyle(fontWeight: FontWeight.w600)),
                  ...optionCtrls.asMap().entries.map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Radio<int>(value: e.key, groupValue: correctIndex, onChanged: (v) => setInner(() => correctIndex = v ?? 0), activeColor: _green),
                            Expanded(child: TextField(controller: e.value, decoration: InputDecoration(labelText: 'Option ${e.key + 1}'))),
                          ],
                        ),
                      )),
                ],

                if (selType == QuestionType.essay) ...[
                  TextField(
                    controller: modelAnsCtrl,
                    decoration: const InputDecoration(labelText: 'Model Answer', hintText: 'Ideal answer from a top student'),
                    maxLines: 5,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: rubricCtrl,
                    decoration: const InputDecoration(labelText: 'Marking Rubric', hintText: 'Award marks for: 1. ... 2. ...'),
                    maxLines: 4,
                  ),
                ],

                const SizedBox(height: 16),
                const Text('Difficulty', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [ButtonSegment(value: 'easy', label: Text('Easy')), ButtonSegment(value: 'medium', label: Text('Medium')), ButtonSegment(value: 'hard', label: Text('Hard'))],
                  selected: {selDifficulty},
                  onSelectionChanged: (s) => setInner(() => selDifficulty = s.first),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _green),
            onPressed: () {
              if (questionCtrl.text.trim().isEmpty) return;

              QuizQuestion? q;
              if (selType == QuestionType.mcq) {
                final opts = optionCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
                if (opts.length < 2) return;
                q = QuizQuestion(
                  question: questionCtrl.text.trim(),
                  type: QuestionType.mcq,
                  difficulty: selDifficulty,
                  strand: _selectedStrand,
                  options: opts,
                  correctIndex: correctIndex.clamp(0, opts.length - 1),
                );
              } else {
                q = QuizQuestion(
                  question: questionCtrl.text.trim(),
                  type: QuestionType.essay,
                  difficulty: selDifficulty,
                  strand: _selectedStrand,
                  modelAnswer: modelAnsCtrl.text.trim().isEmpty ? null : modelAnsCtrl.text.trim(),
                  rubric: rubricCtrl.text.trim().isEmpty ? null : rubricCtrl.text.trim(),
                );
              }

              setState(() => _questions.add(q!));
              Navigator.pop(context);
            },
            child: const Text('Add Question', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── AI Config Sheet ───────────────────────────────────────────────────
  void _showAiConfigSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setInner) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Create Quiz with AI', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('About ${widget.topicLabel}', style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 24),

                const Text('What would you like to generate?', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'mcq', label: Text('MCQ Quiz')),
                    ButtonSegment(value: 'essay', label: Text('Essay Only')),
                    ButtonSegment(value: 'mixed', label: Text('Mixed')),
                  ],
                  selected: {_quizType},
                  onSelectionChanged: (s) => setInner(() => _quizType = s.first),
                ),

                const SizedBox(height: 24),

                const Text('Topic / Subject for AI', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: _aiSubjectCtrl,
                  decoration: InputDecoration(
                    hintText: 'e.g. maize farming, soil conservation techniques...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),

                const SizedBox(height: 16),

                // CBC Strand
                const Text('CBC strand', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedStrand,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: cbcAgriculturalStrands.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 14)))).toList(),
                  onChanged: (v) => setInner(() => _selectedStrand = v!),
                ),

                const SizedBox(height: 8),
                Text(
                  '💡 Tip: Choose the strand that best matches your topic above.\n'
                  '• Maize / tomatoes → Crop Production\n'
                  '• Market prices → Agricultural Economics\n'
                  '• Rainfall → Weather and Climate in Agriculture',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.4),
                ),

                const SizedBox(height: 16),

                // Difficulty
                const Text('Difficulty', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  segments: const [ButtonSegment(value: 'easy', label: Text('Easy')), ButtonSegment(value: 'medium', label: Text('Medium')), ButtonSegment(value: 'hard', label: Text('Hard'))],
                  selected: {_aiDifficulty},
                  onSelectionChanged: (s) => setInner(() => _aiDifficulty = s.first),
                ),

                const SizedBox(height: 24),

                // Generate Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: _isGenerating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.auto_awesome),
                    label: Text(_isGenerating ? 'Generating…' : 'Generate Questions'),
                    style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                    onPressed: _isGenerating
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            _generateWithAI();
                          },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Build Method ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85, maxWidth: 600),
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(color: _green, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Create ${widget.topicLabel} quiz', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('${widget.grade} · ${_questions.length} question(s)', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                  ],
                ),
              ),

              // Title + Action Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  children: [
                    TextField(
                      controller: _titleCtrl,
                      decoration: InputDecoration(
                        labelText: 'Quiz title',
                        hintText: '${widget.topicLabel} Quiz',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: _isGenerating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome, color: Colors.amber, size: 18),
                            label: Text(_isGenerating ? 'Generating…' : 'Generate with AI'),
                            style: OutlinedButton.styleFrom(foregroundColor: _green, side: const BorderSide(color: _green)),
                            onPressed: _isGenerating ? null : _showAiConfigSheet,
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Manual'),
                          onPressed: _addManualQuestion,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Question List
              Expanded(
                child: _questions.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.quiz_outlined, size: 48, color: Colors.grey),
                            SizedBox(height: 12),
                            Text('No questions yet.\nGenerate with AI or add manually.', textAlign: TextAlign.center),
                          ],
                        ),
                      )
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _questions.length,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) newIndex--;
                            final item = _questions.removeAt(oldIndex);
                            _questions.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (_, i) => _QuestionCard(
                          key: ValueKey(i),
                          index: i,
                          question: _questions[i],
                          onDelete: () => setState(() => _questions.removeAt(i)),
                        ),
                      ),
              ),

              // Footer
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    const Spacer(),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save, size: 18),
                      label: Text('Save quiz (${_questions.length})'),
                      style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white),
                      onPressed: _questions.isEmpty
                          ? null
                          : () {
                              widget.onSave({
                                'title': _titleCtrl.text.trim().isEmpty ? '${widget.topicLabel} Quiz' : _titleCtrl.text.trim(),
                                'questions': _questions.map((q) => q.toJson()).toList(),
                              });
                              Navigator.pop(context);
                            },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
//  EduQuizScreen
//  Drop-in replacement for any XxxQuizScreen.
//  Adaptive difficulty + essay support + instant MCQ feedback.
// ═══════════════════════════════════════════════════════════════════════════

class EduQuizScreen extends StatefulWidget {
  final Map<String, dynamic> payload;
  final String classId;
  final bool   isPrimary;

  /// The subject label passed to Gemini for adaptive question generation.
  final String geminiSubject;

  const EduQuizScreen({
    super.key,
    required this.payload,
    required this.classId,
    required this.geminiSubject,
    this.isPrimary = false,
  });

  @override
  State<EduQuizScreen> createState() => _EduQuizScreenState();
}

class _EduQuizScreenState extends State<EduQuizScreen> {
  int _idx = 0;
  int _score = 0;

  final List<bool> _answerHistory = [];
  String _currentDifficulty = 'medium';
  bool _isLoadingAdaptive = false;
  bool _isSubmitting = false;           // ← Added for loading state

  QuizQuestion? _adaptiveQuestion;

  // MCQ state
  int? _selectedOption;
  bool _showMcqFeedback = false;
  String _mcqFeedbackText = '';
  bool _isLoadingFeedback = false;

  // Essay state
  final TextEditingController _essayCtrl = TextEditingController();
  EssayFeedback? _essayFeedback;
  bool _isMarkingEssay = false;
  bool _essaySubmitted = false;

  // Accumulates every answered essay during the session; saved to Firestore at quiz end
  final List<Map<String, dynamic>> _essayAnswers = [];

  late final ConfettiController _conf =
      ConfettiController(duration: const Duration(seconds: 2));
  final _service = const GeminiQuizService();

  List<dynamic> get _rawQuestions =>
      widget.payload['questions'] as List? ?? [];

  int get _totalQuestions => _rawQuestions.length;

  QuizQuestion get _currentQuestion {
    if (_adaptiveQuestion != null) return _adaptiveQuestion!;
    final raw = _rawQuestions[_idx] as Map<String, dynamic>;
    return QuizQuestion.fromJson(raw);
  }

  bool get _isLastQuestion => _idx >= _totalQuestions - 1;

  // ── MCQ ───────────────────────────────────────────────────────────────
  // ── MCQ ───────────────────────────────────────────────────────────────
Future<void> _onMcqTap(int sel) async {
  if (_showMcqFeedback) return;

  final q = _currentQuestion;
  final isCorrect = sel == q.correctIndex;

  setState(() {
    _selectedOption = sel;
    _showMcqFeedback = true;
    _isLoadingFeedback = true;   // We'll load explanation for both correct & wrong
  });

  String explanation = '';

  if (isCorrect) {
    _score++;
    _conf.play();

    // Get a short positive explanation for correct answer
    explanation = await _service.explainWrongAnswer(
      question: q.question,
      wrongOption: '',                    // not used for correct
      correctOption: (q.options ?? [])[q.correctIndex ?? 0],
      subject: widget.geminiSubject,
    );

    // Make it more positive
    if (explanation.isEmpty || explanation.contains("The correct answer")) {
      explanation = "Great choice! This is the best practice for Kenyan farmers.";
    }
  } else {
    explanation = await _service.explainWrongAnswer(
      question: q.question,
      wrongOption: (q.options ?? [])[sel],
      correctOption: (q.options ?? [])[q.correctIndex ?? 0],
      subject: widget.geminiSubject,
    );
  }

  if (mounted) {
    setState(() {
      _mcqFeedbackText = explanation;
      _isLoadingFeedback = false;
    });
  }

  _answerHistory.add(isCorrect);

    // Success feedback so student knows their answer was recorded
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isCorrect ? '✅ Correct! Well done.' : 'Answer recorded. Review the explanation above.',
          ),
          backgroundColor: isCorrect ? Colors.green : Colors.blueGrey,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _onMcqNext() => _isLastQuestion ? _submitQuiz() : _advanceToNext();

  // ── Launch Shamba AI Tutor ────────────────────────────────────────────
  void _launchTutor({required String questionText, required bool wrongAnswer}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TutorChatScreen(
          topic:           widget.geminiSubject,
          grade:           widget.payload['grade'] as String? ?? '',
          classId:         widget.classId,
          isPrimary:       widget.isPrimary,
          contextQuestion: questionText,
          contextModule:   widget.payload['contentType'] as String?,
          wrongAnswer:     wrongAnswer,
        ),
      ),
    );
  }

  // ── Essay ─────────────────────────────────────────────────────────────
  Future<void> _onSubmitEssay() async {
    final answer = _essayCtrl.text.trim();
    if (answer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write your answer before submitting.')),
      );
      return;
    }

    setState(() => _isMarkingEssay = true);

    final q = _currentQuestion;

    // 60-second timeout — Gemini Flash can be slow under load
    EssayFeedback? feedback;
    try {
      feedback = await _service.markEssay(
        question:      q.question,
        modelAnswer:   q.modelAnswer ?? '',
        rubric:        q.rubric ?? '',
        studentAnswer: answer,
        grade:         widget.payload['grade'] as String? ?? '',
        strand:        q.strand,
      ).timeout(const Duration(seconds: 60), onTimeout: () => null);
    } catch (_) {
      feedback = null;
    }

    if (!mounted) return;

    // Accumulate — saved to Firestore when the whole quiz finishes
    _essayAnswers.add({
      'question':        q.question,
      'answer':          answer,
      'aiScore':         feedback?.score    ?? 0,
      'aiGrade':         feedback?.grade    ?? 'Not marked',
      'aiFeedback':      feedback?.feedback ?? 'AI unavailable — teacher will mark manually.',
      'aiHint':          feedback?.hint     ?? '',
      'aiMarked':        feedback != null,
      'teacherApproved': false,
    });

    setState(() {
      _isMarkingEssay = false;
      _essayFeedback  = feedback;
      _essaySubmitted = true;
    });

    if (feedback != null) {
      final partial = (feedback.score / feedback.maxScore * 3).round();
      _score += partial;
    }

    _answerHistory.add(
        feedback != null && feedback.score >= feedback.maxScore * 0.6);
  }

  void _onEssayNext() => _isLastQuestion ? _submitQuiz() : _advanceToNext();

  // ── Adaptive advance ─────────────────────────────────────────────────
  Future<void> _advanceToNext() async {
    setState(() {
      _selectedOption = null;
      _showMcqFeedback = false;
      _mcqFeedbackText = '';
      _essayCtrl.clear();
      _essayFeedback = null;
      _essaySubmitted = false;
      _adaptiveQuestion = null;
      _idx++;
    });

    if (_answerHistory.length >= 2 && _rawQuestions.isNotEmpty) {
      setState(() => _isLoadingAdaptive = true);

      final q = _currentQuestion;
      final adaptive = await _service.generateAdaptiveQuestion(
        subject: widget.geminiSubject,
        strand: q.strand.isNotEmpty ? q.strand : 'Crop Production',
        grade: widget.payload['grade'] as String? ?? '',
        isPrimary: widget.isPrimary,
        answeredCorrectly: _answerHistory,
        currentDifficulty: _currentDifficulty,
        preferredType: q.type,
      );

      if (!mounted) return;
      setState(() {
        _isLoadingAdaptive = false;
        if (adaptive != null) {
          _adaptiveQuestion = adaptive;
          _currentDifficulty = adaptive.difficulty;
        }
      });
    }
  }

  // ── Submit Quiz ──────────────────────────────────────────────────────
  Future<void> _submitQuiz() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    final coll = FirestoreHelper.getSubmissionsFromClassId(widget.classId);
    if (coll != null) {
      try {
        final hasEssays = _essayAnswers.isNotEmpty;
        await coll.add({
          'type':             'quiz',
          'quizId':           widget.payload['id'],
          'title':            widget.payload['title'],
          'score':            _score,
          'total':            _totalQuestions,
          'userId':           FirebaseAuth.instance.currentUser!.uid,
          'createdAt':        FieldValue.serverTimestamp(),
          'answerHistory':    _answerHistory,
          'adaptiveUsed':     _answerHistory.length > 2,
          // Required by TeacherEssayReviewScreen query and update logic
          'hasEssayAnswers':  hasEssays,
          'teacherReviewed':  false,
          if (hasEssays) 'essayAnswers': jsonEncode(_essayAnswers),
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save quiz: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isSubmitting = false);
        return;
      }
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    _conf.play();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Text('🎉 ', style: TextStyle(fontSize: 28)),
            Text('Quiz Submitted Successfully!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your score: $_score / $_totalQuestions',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _green),
            ),
            const SizedBox(height: 12),
            Text(_scoreMessage(_score, _totalQuestions)),
            const SizedBox(height: 16),
            const Text(
              '✅ All your answers have been saved.\nYour teacher can now view your results.',
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(context)..pop()..pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  // ←←← ADD THIS METHOD (it was missing)
  String _scoreMessage(int score, int total) {
    if (total == 0) return '';
    final pct = score / total;
    if (pct >= 0.8) return 'Excellent work! You really know your stuff.';
    if (pct >= 0.6) return 'Good job! A bit more practice will get you there.';
    if (pct >= 0.4) return 'Keep going — review the content and try again.';
    return 'Don\'t give up! Review the study material and have another go.';
  }

  @override
  void dispose() {
    _conf.dispose();
    _essayCtrl.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.payload['title'] as String? ?? 'Quiz'),
        backgroundColor: _green,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: LinearProgressIndicator(
            value: _totalQuestions == 0 ? 0 : (_idx + 1) / _totalQuestions,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.lightGreenAccent),
          ),
        ),
      ),
      body: Stack(
        children: [
          ConfettiWidget(
            confettiController: _conf,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 30,
          ),
          if (_isLoadingAdaptive)
            const Center(child: CircularProgressIndicator(color: _green)),
          if (!_isLoadingAdaptive)
            _currentQuestion.type == QuestionType.essay
                ? _buildEssayView(_currentQuestion)
                : _buildMcqView(_currentQuestion),
        ],
      ),
    );
  }

  // ── MCQ view ──────────────────────────────────────────────────────────
  Widget _buildMcqView(QuizQuestion q) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Question ${_idx + 1} of $_totalQuestions',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const Spacer(),
            _DiffChip(difficulty: q.difficulty),
            if (_adaptiveQuestion != null) ...[
              const SizedBox(width: 6),
              const _AdaptiveBadge(),
            ],
          ]),
          const SizedBox(height: 16),
          Text(q.question, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 28),

          ...(q.options ?? []).asMap().entries.map((e) {
            final isSelected = _selectedOption == e.key;
            final isCorrect = e.key == q.correctIndex;
            Color? tileColor;

            if (_showMcqFeedback) {
              if (isSelected && isCorrect) tileColor = Colors.green.shade50;
              if (isSelected && !isCorrect) tileColor = Colors.red.shade50;
              if (!isSelected && isCorrect) tileColor = Colors.green.shade50;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: _showMcqFeedback ? null : () => _onMcqTap(e.key),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: tileColor ?? (isSelected ? _green.withValues(alpha: 0.08) : Colors.grey.shade50),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _showMcqFeedback
                          ? (isCorrect ? Colors.green : isSelected ? Colors.red : Colors.grey.shade200)
                          : isSelected ? _green : Colors.grey.shade200,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: _showMcqFeedback
                          ? (isCorrect ? Colors.green : isSelected ? Colors.red : Colors.grey.shade300)
                          : isSelected ? _green : Colors.grey.shade300,
                      child: Text(
                        String.fromCharCode(65 + e.key),
                        style: TextStyle(
                          color: isSelected || (_showMcqFeedback && isCorrect) ? Colors.white : Colors.black87,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        e.value,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected || (_showMcqFeedback && isCorrect)
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (_showMcqFeedback && isCorrect)
                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    if (_showMcqFeedback && isSelected && !isCorrect)
                      const Icon(Icons.cancel, color: Colors.red, size: 20),
                  ]),
                ),
              ),
            );
          }),

          if (_showMcqFeedback) ...[
  const SizedBox(height: 12),

  // Improved Feedback Panel
  _FeedbackPanel(
    isCorrect: _selectedOption == q.correctIndex,
    isLoading: _isLoadingFeedback,
    feedbackText: _mcqFeedbackText,
  ),

  // Ask Tutor button — shown once feedback loads, always visible
  if (!_isLoadingFeedback) ...[
    const SizedBox(height: 10),
    _AskTutorButton(
      label: _selectedOption == q.correctIndex
          ? 'Want to explore this topic further?'
          : "I still don't understand — ask Shamba AI",
      onTap: () => _launchTutor(
        questionText: q.question,
        wrongAnswer: _selectedOption != q.correctIndex,
      ),
    ),
  ],

  const SizedBox(height: 20),

  // Clear Next Button with better label when it's the last question
  SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: _isSubmitting ? null : _onMcqNext,
      style: ElevatedButton.styleFrom(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _isSubmitting
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
          : Text(
              _isLastQuestion ? 'Finish Quiz & See Results' : 'Continue to Next Question',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
    ),
  ),
],
        ],
      ),
    );
  }

  // ── Essay View (Updated & Improved) ───────────────────────────────────
  Widget _buildEssayView(QuizQuestion q) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Question ${_idx + 1} of $_totalQuestions',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const Spacer(),
            _DiffChip(difficulty: q.difficulty),
            const SizedBox(width: 6),
            const _Badge(label: 'Essay', color: Colors.purple),
          ]),
          const SizedBox(height: 16),

          Text(q.question, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),

          const SizedBox(height: 12),
          const Text(
            'Write your detailed answer below. Be clear and use examples from Kenyan agriculture where possible.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),

          const SizedBox(height: 20),

          TextField(
            controller: _essayCtrl,
            enabled: !_essaySubmitted,
            maxLines: 12,
            textAlignVertical: TextAlignVertical.top,
            decoration: InputDecoration(
              hintText: 'Start writing your answer here...\n\nExample:\nIn Kenya, soil conservation is important because...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _green, width: 2),
              ),
              filled: _essaySubmitted,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),

          const SizedBox(height: 20),

          if (!_essaySubmitted)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isMarkingEssay
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    : const Icon(Icons.send),
                label: Text(_isMarkingEssay ? 'Saving & marking your answer…' : 'Submit Answer for Marking'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isMarkingEssay ? null : _onSubmitEssay,
              ),
            ),

          // AI marked successfully
          if (_essaySubmitted && _essayFeedback != null) ...[
            const SizedBox(height: 16),
            _EssayFeedbackCard(feedback: _essayFeedback!),
            const SizedBox(height: 10),
            // Ask Tutor button — always shown after essay is marked
            _AskTutorButton(
              label: 'Explore this topic with Shamba AI',
              onTap: () => _launchTutor(
                questionText: q.question,
                wrongAnswer: (_essayFeedback!.score / _essayFeedback!.maxScore) < 0.6,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: const Text(
                '✅ Answer saved. Your teacher will review the AI marking before finalising your score.',
                style: TextStyle(color: Colors.amber, fontSize: 14),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _onEssayNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(_isLastQuestion ? 'Finish Quiz' : 'Next Question'),
              ),
            ),
          ],

          // AI timed out or unavailable — answer still saved for teacher
          if (_essaySubmitted && _essayFeedback == null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Row(children: [
                Icon(Icons.check_circle, color: Colors.blue, size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '✅ Answer saved.\nAI marking was unavailable — your teacher will mark it manually.',
                    style: TextStyle(color: Colors.blue, fontSize: 14, height: 1.5),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _onEssayNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(_isLastQuestion ? 'Finish Quiz' : 'Next Question'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TeacherEssayReviewScreen
//  Unified teacher dashboard for reviewing AI-marked quiz essays AND
//  AI-marked simulation submissions. Two tabs — Essays | Simulations.
// ═══════════════════════════════════════════════════════════════════════════

class TeacherEssayReviewScreen extends StatefulWidget {
  final String classId;
  final String schoolName;

  const TeacherEssayReviewScreen({
    super.key,
    required this.classId,
    required this.schoolName,
  });

  @override
  State<TeacherEssayReviewScreen> createState() =>
      _TeacherEssayReviewScreenState();
}

class _TeacherEssayReviewScreenState extends State<TeacherEssayReviewScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coll = FirestoreHelper.getSubmissionsFromClassId(widget.classId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Submissions'),
        backgroundColor: _green,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.edit_note),      text: 'Essay Answers'),
            Tab(icon: Icon(Icons.sports_esports), text: 'Simulations'),
          ],
        ),
      ),
      body: coll == null
          ? const Center(child: Text('Invalid class configuration'))
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _SubmissionList(
                  coll:        coll,
                  classId:     widget.classId,
                  typeFilter:  'quiz',
                  emptyIcon:   Icons.edit_note,
                  emptyTitle:  'No essay submissions yet',
                  emptyMsg:    'Student essay answers will appear here once submitted.',
                ),
                _SubmissionList(
                  coll:        coll,
                  classId:     widget.classId,
                  typeFilter:  'simulation',
                  emptyIcon:   Icons.sports_esports,
                  emptyTitle:  'No simulation submissions yet',
                  emptyMsg:    'AI-marked simulation results will appear here after students complete them.',
                ),
              ],
            ),
    );
  }
}

// ── Reusable submission list (works for both quiz and simulation) ───────────

class _SubmissionList extends StatelessWidget {
  final CollectionReference coll;
  final String classId;
  final String typeFilter;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMsg;

  const _SubmissionList({
    required this.coll,
    required this.classId,
    required this.typeFilter,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMsg,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: coll
          .where('type', isEqualTo: typeFilter)
          .where('hasEssayAnswers', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _green));
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.info_outline,
                    size: 48, color: Colors.orange),
                const SizedBox(height: 16),
                const Text('Index still building…',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  'A Firestore index is being created. This takes a few minutes on first use. Please try again shortly.',
                  style: TextStyle(color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.grey)),
              ]),
            ),
          );
        }

        final allDocs = snapshot.data?.docs ?? [];

        if (allDocs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(emptyIcon, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(emptyTitle,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(emptyMsg,
                    style:
                        TextStyle(color: Colors.grey.shade600),
                    textAlign: TextAlign.center),
              ]),
            ),
          );
        }

        final pendingDocs = allDocs
            .where((d) =>
                (d.data() as Map)['teacherReviewed'] != true)
            .toList();
        final reviewedDocs = allDocs
            .where((d) =>
                (d.data() as Map)['teacherReviewed'] == true)
            .toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (pendingDocs.isNotEmpty) ...[
              _ReviewSectionLabel(
                  label: '${pendingDocs.length} pending review',
                  color: Colors.orange),
              const SizedBox(height: 8),
              ...pendingDocs.map((doc) => _EssaySubmissionCard(
                    docId:   doc.id,
                    data:    doc.data() as Map<String, dynamic>,
                    classId: classId,
                    coll:    coll,
                  )),
            ],
            if (reviewedDocs.isNotEmpty) ...[
              if (pendingDocs.isNotEmpty) const SizedBox(height: 8),
              _ReviewSectionLabel(
                  label: '${reviewedDocs.length} reviewed',
                  color: Colors.green),
              const SizedBox(height: 8),
              ...reviewedDocs.map((doc) => _EssaySubmissionCard(
                    docId:   doc.id,
                    data:    doc.data() as Map<String, dynamic>,
                    classId: classId,
                    coll:    coll,
                  )),
            ],
          ],
        );
      },
    );
  }
}

class _ReviewSectionLabel extends StatelessWidget {
  final String label;
  final Color  color;
  const _ReviewSectionLabel({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:        color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border:       Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      );
}

class _EssaySubmissionCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final String classId;
  final CollectionReference coll;

  const _EssaySubmissionCard({
    required this.docId,
    required this.data,
    required this.classId,
    required this.coll,
  });

  @override
  Widget build(BuildContext context) {
    final isSimulation   = data['type'] == 'simulation';
    final studentName    = data['studentName']    as String? ?? 'Unknown Student';
    final module         = data['module']         as String? ?? '';
    final reviewed       = data['teacherReviewed'] == true;
    final submittedAt    = (data['createdAt'] as Timestamp?)?.toDate();

    // ── For simulations: use top-level AI fields ──────────────────────
    final simTitle       = data['simulationTitle'] as String? ?? data['title'] as String? ?? 'Simulation';
    final simAiScore     = (data['aiScore']    as num?)?.toInt();
    final simAiGrade     = data['aiGrade']     as String?;
    final simAiSummary   = data['aiSummary']   as String?;
    final simStrengths   = List<String>.from(data['aiStrengths']    as List? ?? []);
    final simImprovements= List<String>.from(data['aiImprovements'] as List? ?? []);
    final simHint        = data['aiHint']      as String?;
    final simCbcStrand   = data['cbcStrand']   as String?;
    final decisionLog    = List<String>.from(data['decisionLog']    as List? ?? []);
    final summaryData    = data['summaryData']  as Map<String, dynamic>?;

    // ── For quiz essays: use essayAnswers list ────────────────────────
    final essayDataRaw   = data['essayAnswers'] as String?;
    List<Map<String, dynamic>> essays = [];
    if (essayDataRaw != null) {
      try {
        essays = List<Map<String, dynamic>>.from(jsonDecode(essayDataRaw) as List);
      } catch (_) {}
    }

    final approvedCount  = essays.where((e) => e['teacherApproved'] == true).length;
    final pendingCount   = essays.isEmpty ? 0 : essays.length - approvedCount;

    String fmt(DateTime dt) {
      final diff = DateTime.now().difference(dt);
      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7)  return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    }

    // Status colour
    final statusColor = reviewed ? Colors.green : Colors.orange;

    return Card(
      margin:    const EdgeInsets.only(bottom: 14),
      shape:     RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: isSimulation
              ? Colors.teal.shade50
              : (reviewed ? Colors.green.shade50 : Colors.orange.shade50),
          child: Icon(
            isSimulation
                ? Icons.sports_esports
                : (reviewed ? Icons.check_circle : Icons.pending_outlined),
            color: isSimulation
                ? Colors.teal.shade700
                : (reviewed ? Colors.green.shade700 : Colors.orange.shade700),
            size: 22,
          ),
        ),
        title: Row(children: [
          Expanded(
            child: Text(studentName,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          // AI score pill (shown for simulations with AI result)
          if (isSimulation && simAiScore != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Text('AI: $simAiScore/100',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.teal.shade800)),
            ),
          const SizedBox(width: 6),
          // Review status pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color:  statusColor.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusColor.shade200),
            ),
            child: Text(
              reviewed
                  ? 'Reviewed'
                  : isSimulation
                      ? 'Pending'
                      : '$pendingCount to review',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: statusColor.shade800),
            ),
          ),
        ]),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(spacing: 6, children: [
            Text(isSimulation ? simTitle : (data['title'] as String? ?? 'Quiz'),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            if (module.isNotEmpty)
              Text('· $module',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            if (submittedAt != null)
              Text('· ${fmt(submittedAt)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
          ]),
        ),
        children: isSimulation
            // ── Simulation result content ──────────────────────────────
            ? [_SimulationReviewPanel(
                docId:        docId,
                coll:         coll,
                aiScore:      simAiScore,
                aiGrade:      simAiGrade,
                aiSummary:    simAiSummary,
                strengths:    simStrengths,
                improvements: simImprovements,
                hint:         simHint,
                cbcStrand:    simCbcStrand,
                decisionLog:  decisionLog,
                summaryData:  summaryData,
                reviewed:     reviewed,
              )]
            // ── Quiz essay content ─────────────────────────────────────
            : essays.isEmpty
                ? [const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No essay answers in this submission.',
                        style: TextStyle(color: Colors.grey)),
                  )]
                : essays.asMap().entries.map((e) =>
                    _EssayAnswerReviewTile(
                      index:     e.key,
                      essay:     e.value,
                      docId:     docId,
                      coll:      coll,
                      allEssays: essays,
                    )).toList(),
      ),
    );
  }
}

// ── Simulation review panel (shown when a simulation card is expanded) ──────

class _SimulationReviewPanel extends StatefulWidget {
  final String  docId;
  final CollectionReference coll;
  final int?    aiScore;
  final String? aiGrade;
  final String? aiSummary;
  final List<String> strengths;
  final List<String> improvements;
  final String? hint;
  final String? cbcStrand;
  final List<String> decisionLog;
  final Map<String, dynamic>? summaryData;
  final bool    reviewed;

  const _SimulationReviewPanel({
    required this.docId,
    required this.coll,
    required this.aiScore,
    required this.aiGrade,
    required this.aiSummary,
    required this.strengths,
    required this.improvements,
    required this.hint,
    required this.cbcStrand,
    required this.decisionLog,
    required this.summaryData,
    required this.reviewed,
  });

  @override
  State<_SimulationReviewPanel> createState() => _SimulationReviewPanelState();
}

class _SimulationReviewPanelState extends State<_SimulationReviewPanel> {
  late int _finalScore;
  late final TextEditingController _commentCtrl;
  bool _isSaving = false;
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _finalScore  = widget.aiScore ?? 50;
    _confirmed   = widget.reviewed;
    _commentCtrl = TextEditingController(
        text: widget.summaryData?['teacherComment'] as String? ?? '');
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _finalise() async {
    setState(() => _isSaving = true);
    try {
      await widget.coll.doc(widget.docId).update({
        'finalScore':      _finalScore,
        'teacherComment':  _commentCtrl.text.trim(),
        'teacherReviewed': true,
        'approvedBy':      FirebaseAuth.instance.currentUser?.uid,
        'approvedAt':      DateTime.now().toIso8601String(),
        // Update essay answers list to match so _EssayAnswerReviewTile picks it up
        'essayAnswers': jsonEncode([
          {
            'question':        'Simulation Performance',
            'answer':          widget.decisionLog.join('\n'),
            'aiScore':         widget.aiScore ?? 0,
            'aiGrade':         widget.aiGrade ?? '',
            'aiFeedback':      widget.aiSummary ?? '',
            'aiHint':          widget.hint ?? '',
            'aiMarked':        widget.aiScore != null,
            'teacherApproved': true,
            'finalScore':      _finalScore,
            'teacherComment':  _commentCtrl.text.trim(),
          }
        ]),
      });
      if (mounted) setState(() { _isSaving = false; _confirmed = true; });
    } catch (e) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradeColor = _gradeColor(widget.aiGrade ?? '');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── AI analysis header ──────────────────────────────────────
          if (widget.aiScore != null) ...[
            Row(children: [
              const Icon(Icons.auto_awesome, color: Colors.amber, size: 16),
              const SizedBox(width: 6),
              const Text('AI Analysis',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const Spacer(),
              if (widget.cbcStrand != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(widget.cbcStrand!,
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.w600)),
                ),
            ]),
            const SizedBox(height: 10),

            // Score bar
            Row(children: [
              Text('${widget.aiScore}/100',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: gradeColor)),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (widget.aiScore ?? 0) / 100,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(gradeColor),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: gradeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(widget.aiGrade ?? '',
                    style: TextStyle(
                        color: gradeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 10),

            // Summary
            if (widget.aiSummary?.isNotEmpty == true) ...[
              Text(widget.aiSummary!,
                  style: const TextStyle(fontSize: 13, height: 1.5)),
              const SizedBox(height: 10),
            ],

            // Strengths
            if (widget.strengths.isNotEmpty) ...[
              _SimPanelSection(
                  icon: Icons.check_circle_outline,
                  label: 'Strengths',
                  color: Colors.green.shade700,
                  items: widget.strengths),
              const SizedBox(height: 8),
            ],

            // Improvements
            if (widget.improvements.isNotEmpty) ...[
              _SimPanelSection(
                  icon: Icons.trending_up,
                  label: 'Improvements',
                  color: Colors.orange.shade700,
                  items: widget.improvements),
              const SizedBox(height: 8),
            ],

            // Hint
            if (widget.hint?.isNotEmpty == true)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(children: [
                  Icon(Icons.lightbulb_outline,
                      size: 15, color: Colors.blue.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(widget.hint!,
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade800,
                            fontStyle: FontStyle.italic)),
                  ),
                ]),
              ),

            const Divider(),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'AI marking was unavailable. Please mark this simulation manually.',
                    style: TextStyle(color: Colors.blue.shade800, fontSize: 13),
                  ),
                ),
              ]),
            ),
          ],

          // ── Decision log (collapsed) ────────────────────────────────
          if (widget.decisionLog.isNotEmpty) ...[
            Theme(
              data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(Icons.list_alt,
                    size: 16, color: Colors.grey.shade600),
                title: Text('Decision Log (${widget.decisionLog.length} entries)',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                children: widget.decisionLog.map((e) => Padding(
                  padding: const EdgeInsets.fromLTRB(0, 2, 0, 2),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('• ', style: TextStyle(color: Colors.grey.shade400)),
                    Expanded(
                      child: Text(e,
                          style: const TextStyle(fontSize: 11, height: 1.4)),
                    ),
                  ]),
                )).toList(),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // ── Teacher finalise controls ───────────────────────────────
          if (_confirmed)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Finalised: $_finalScore/100',
                    style: const TextStyle(
                        color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _confirmed = false),
                  child: const Text('Edit', style: TextStyle(fontSize: 12)),
                ),
              ]),
            )
          else ...[
            Row(children: [
              const Text('Final mark:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                color: _green,
                onPressed: _finalScore > 0
                    ? () => setState(() => _finalScore--)
                    : null,
                iconSize: 22,
              ),
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$_finalScore',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                color: _green,
                onPressed: _finalScore < 100
                    ? () => setState(() => _finalScore++)
                    : null,
                iconSize: 22,
              ),
              Text('/100',
                  style: TextStyle(color: Colors.grey.shade600)),
              if (widget.aiScore != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    _finalScore == widget.aiScore
                        ? 'Same as AI'
                        : _finalScore > widget.aiScore!
                            ? '+${_finalScore - widget.aiScore!} from AI'
                            : '${_finalScore - widget.aiScore!} from AI',
                    style: TextStyle(
                        fontSize: 11,
                        color: _finalScore == widget.aiScore
                            ? Colors.grey
                            : _finalScore > widget.aiScore!
                                ? Colors.green
                                : Colors.red),
                  ),
                ),
            ]),
            const SizedBox(height: 8),
            TextField(
              controller: _commentCtrl,
              decoration: InputDecoration(
                labelText: 'Comment to student (optional)',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isSaving
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check, size: 18),
                label: Text(_isSaving
                    ? 'Saving…'
                    : 'Finalise mark ($_finalScore/100)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding:
                      const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _isSaving ? null : _finalise,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _gradeColor(String grade) {
    switch (grade) {
      case 'Excellent':    return Colors.green.shade700;
      case 'Good':         return Colors.blue.shade700;
      case 'Satisfactory': return Colors.orange.shade700;
      default:             return Colors.red.shade700;
    }
  }
}

class _SimPanelSection extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final List<String> items;
  const _SimPanelSection({
    required this.icon, required this.label,
    required this.color, required this.items,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ]),
      const SizedBox(height: 4),
      ...items.map((s) => Padding(
        padding: const EdgeInsets.only(left: 6, bottom: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.circle, size: 5, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(s,
              style: const TextStyle(fontSize: 12, height: 1.4))),
        ]),
      )),
    ],
  );
}

class _EssayAnswerReviewTile extends StatefulWidget {
  final int index;
  final Map<String, dynamic> essay;
  final String docId;
  final CollectionReference coll;
  final List<Map<String, dynamic>> allEssays;

  const _EssayAnswerReviewTile({
    required this.index,
    required this.essay,
    required this.docId,
    required this.coll,
    required this.allEssays,
  });

  @override
  State<_EssayAnswerReviewTile> createState() =>
      _EssayAnswerReviewTileState();
}

class _EssayAnswerReviewTileState
    extends State<_EssayAnswerReviewTile> {
  late int _score;
  late final TextEditingController _commentCtrl;
  bool _isSaving = false;
  bool _approved = false;

  @override
  void initState() {
    super.initState();
    _score =
        (widget.essay['aiScore'] as num?)?.toInt() ?? 5;
    _commentCtrl = TextEditingController(
        text: widget.essay['teacherComment'] as String? ?? '');
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _approve() async {
    setState(() => _isSaving = true);

    final updatedEssays =
        List<Map<String, dynamic>>.from(widget.allEssays);
    updatedEssays[widget.index] = {
      ...widget.essay,
      'finalScore':      _score,
      'teacherComment':  _commentCtrl.text.trim(),
      'teacherApproved': true,
      'approvedBy':
          FirebaseAuth.instance.currentUser?.uid,
      'approvedAt': DateTime.now().toIso8601String(),
    };

    final allApproved = updatedEssays
        .every((e) => e['teacherApproved'] == true);

    await widget.coll.doc(widget.docId).update({
      'essayAnswers':    jsonEncode(updatedEssays),
      'teacherReviewed': allApproved,
    });

    if (mounted) {
      setState(() {
        _isSaving = false;
        _approved = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_approved) {
      return ListTile(
        leading:
            const Icon(Icons.check_circle, color: Colors.green),
        title: Text('Q${widget.index + 1}: approved ($_score/10)',
            style: const TextStyle(color: Colors.green)),
      );
    }

    final question   = widget.essay['question']   as String? ?? '';
    final answer     = widget.essay['answer']     as String? ?? '';
    final aiScore    = (widget.essay['aiScore'] as num?)?.toInt() ?? 0;
    final aiGrade    = widget.essay['aiGrade']    as String? ?? '';
    final aiFeedback = widget.essay['aiFeedback'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.index > 0) const Divider(),
          Text('Q${widget.index + 1}: $question',
              style:
                  const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(answer,
                style: const TextStyle(fontSize: 14)),
          ),
          const SizedBox(height: 10),

          Builder(builder: (_) {
            final aiMarked = widget.essay['aiMarked'] as bool?
                ?? (aiGrade.isNotEmpty && aiGrade != 'Not marked');
            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:        aiMarked ? Colors.amber.shade50 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border:       Border.all(color: aiMarked ? Colors.amber.shade200 : Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(aiMarked ? Icons.auto_awesome : Icons.person_outline,
                        color: aiMarked ? Colors.amber : Colors.blue.shade700, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      aiMarked ? 'AI: $aiScore/10 — $aiGrade' : 'Needs manual marking',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ]),
                  if (aiFeedback.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(aiFeedback,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                  ],
                ],
              ),
            );
          }),
          const SizedBox(height: 14),

          Row(children: [
            const Text('Your mark:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              color: _green,
              onPressed: _score > 0
                  ? () => setState(() => _score--)
                  : null,
            ),
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$_score',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              color: _green,
              onPressed: _score < 10
                  ? () => setState(() => _score++)
                  : null,
            ),
            Text('/10',
                style:
                    TextStyle(color: Colors.grey.shade600)),
            const Spacer(),
            Text(
              _score == aiScore
                  ? 'Same as AI'
                  : _score > aiScore
                      ? '+${_score - aiScore} from AI'
                      : '${_score - aiScore} from AI',
              style: TextStyle(
                  fontSize: 12,
                  color: _score == aiScore
                      ? Colors.grey
                      : _score > aiScore
                          ? Colors.green
                          : Colors.red),
            ),
          ]),
          const SizedBox(height: 10),

          TextField(
            controller: _commentCtrl,
            decoration: InputDecoration(
              labelText:
                  'Additional comment to student (optional)',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check, size: 18),
              label: Text(_isSaving
                  ? 'Saving…'
                  : 'Approve mark ($_score/10)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding:
                    const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _isSaving ? null : _approve,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Small reusable sub-widgets
// ═══════════════════════════════════════════════════════════════════════════

class _FeedbackPanel extends StatelessWidget {
  final bool isCorrect;
  final bool isLoading;
  final String feedbackText;

  const _FeedbackPanel({
    required this.isCorrect,
    required this.isLoading,
    required this.feedbackText,
  });

  @override
  Widget build(BuildContext context) {
    final color = isCorrect ? Colors.green : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.info_outline,
                color: color,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                isCorrect ? 'Correct! Well done 👍' : 'Not quite, but you can improve',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else
            Text(
              feedbackText.isNotEmpty
                  ? feedbackText
                  : (isCorrect
                      ? "This is the recommended practice in Kenyan agriculture."
                      : "Review this topic again."),
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
        ],
      ),
    );
  }
}

class _EssayFeedbackCard extends StatelessWidget {
  final EssayFeedback feedback;
  const _EssayFeedbackCard({required this.feedback});

  @override
  Widget build(BuildContext context) {
    final gradeColor = switch (feedback.grade) {
      'Excellent'    => Colors.green,
      'Good'         => Colors.teal,
      'Satisfactory' => Colors.orange,
      _              => Colors.red,
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: gradeColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: gradeColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.auto_awesome,
                color: Colors.amber, size: 18),
            const SizedBox(width: 6),
            const Text('AI marking result',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: gradeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(feedback.grade,
                  style: TextStyle(
                      color: gradeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Text('${feedback.score}/${feedback.maxScore}',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: gradeColor)),
            const SizedBox(width: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: feedback.score / feedback.maxScore,
                  backgroundColor: Colors.grey.shade200,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(gradeColor),
                  minHeight: 8,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Text(feedback.feedback,
              style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8)),
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Icon(Icons.lightbulb_outline,
                  size: 16, color: Colors.blue.shade700),
              const SizedBox(width: 6),
              Expanded(
                child: Text(feedback.hint,
                    style: TextStyle(
                        color: Colors.blue.shade800,
                        fontSize: 13)),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _DiffChip extends StatelessWidget {
  final String difficulty;
  const _DiffChip({required this.difficulty});
  @override
  Widget build(BuildContext context) {
    final color = _diffColor(difficulty);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12)),
      child: Text(difficulty,
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold)),
    );
  }
}

class _AdaptiveBadge extends StatelessWidget {
  const _AdaptiveBadge();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.auto_awesome, size: 10, color: Colors.amber),
          SizedBox(width: 3),
          Text('adaptive',
              style: TextStyle(
                  color: Colors.amber,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ]),
      );
}

class _Badge extends StatelessWidget {
  final String label;
  final Color  color;
  const _Badge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12)),
        child: Text(label,
            style: TextStyle(
                color: color.withValues(alpha: 0.9),
                fontSize: 11,
                fontWeight: FontWeight.bold)),
      );
}

class _QuestionCard extends StatelessWidget {
  final int index;
  final QuizQuestion question;
  final VoidCallback onDelete;
  const _QuestionCard(
      {super.key,
      required this.index,
      required this.question,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isEssay = question.type == QuestionType.essay;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isEssay
              ? Colors.purple.shade100
              : Colors.blue.shade100,
          radius: 18,
          child: Text('${index + 1}',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isEssay ? Colors.purple : Colors.blue,
                  fontSize: 13)),
        ),
        title: Text(question.question,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        subtitle: Row(children: [
          _Badge(
              label: isEssay ? 'Essay' : 'MCQ',
              color: isEssay ? Colors.purple : Colors.blue),
          const SizedBox(width: 4),
          _Badge(
              label: question.difficulty,
              color: _diffColor(question.difficulty)),
          if (!isEssay && question.correctIndex != null) ...[
            const SizedBox(width: 4),
            Text(
              '✓ ${String.fromCharCode(65 + question.correctIndex!)}',
              style: const TextStyle(
                  color: Colors.green,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ]),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.drag_handle, color: Colors.grey),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: Colors.red),
            onPressed: onDelete,
            iconSize: 20,
          ),
        ]),
      ),
    );
  }
}

Color _diffColor(String d) => switch (d) {
      'easy' => Colors.green,
      'hard' => Colors.red,
      _      => Colors.orange,
    };

// ═══════════════════════════════════════════════════════════════════════════
//  _AskTutorButton — reusable "Ask Shamba AI" outlined button
//  Used in both MCQ feedback and essay feedback sections.
// ═══════════════════════════════════════════════════════════════════════════

class _AskTutorButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;

  const _AskTutorButton({
    required this.onTap,
    this.label = "I still don't understand — ask Shamba AI",
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.psychology_outlined, size: 20),
        label: Text(label, style: const TextStyle(fontSize: 14)),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF003900),
          side: const BorderSide(color: Color(0xFF003900)),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}