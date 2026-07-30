// lib/education/simulations/simulation_result_screen.dart

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kilimomkononi/utils/firestore_helper.dart';
import 'gemini_simulation_service.dart';

const Color _green = Color(0xFF032704);

// ═══════════════════════════════════════════════════════════════════════════
//  SimulationResultScreen
//  Shows AI feedback after a simulation completes.
//  Saves a submission doc to Firestore (same structure as essay submissions
//  so the teacher's essay review card picks it up automatically).
// ═══════════════════════════════════════════════════════════════════════════

class SimulationResultScreen extends StatefulWidget {
  /// The classId used to resolve the submissions Firestore path.
  final String classId;

  /// Human-readable module name e.g. 'Farming Tips', 'Pest', 'Field Data'.
  final String module;

  /// A short title shown in the teacher's review list.
  final String simulationTitle;

  /// The pre-computed AI feedback (may be null if Gemini was unavailable).
  final SimulationFeedback? feedback;

  /// Raw rule-based score (0–100) used as fallback if AI is unavailable.
  final int fallbackScore;

  /// Full decision/action log serialised as a list of strings.
  final List<String> decisionLog;

  /// Any extra structured data you want to store alongside the submission
  /// (e.g. finalCash, completedTasks). Shown to the teacher.
  final Map<String, dynamic> summaryData;

  /// Called when the student taps "Done" so the parent can pop routes.
  final VoidCallback onDone;

  const SimulationResultScreen({
    super.key,
    required this.classId,
    required this.module,
    required this.simulationTitle,
    required this.feedback,
    required this.fallbackScore,
    required this.decisionLog,
    required this.summaryData,
    required this.onDone,
  });

  @override
  State<SimulationResultScreen> createState() => _SimulationResultScreenState();
}

class _SimulationResultScreenState extends State<SimulationResultScreen> {
  bool _saved = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _saveSubmission();
  }

  Future<void> _saveSubmission() async {
    if (_saved || _saving) return;
    setState(() => _saving = true);

    final coll = FirestoreHelper.getSubmissionsFromClassId(widget.classId);
    if (coll == null) {
      setState(() => _saving = false);
      return;
    }

    final user        = FirebaseAuth.instance.currentUser;
    final studentName = (user?.displayName?.trim().isNotEmpty == true)
        ? user!.displayName!
        : 'Student';
    final feedback    = widget.feedback;
    final score       = feedback?.score ?? widget.fallbackScore;

    try {
      await coll.add({
        // ── Core fields (queried by teacher dashboard & essay review card) ──
        'type':             'simulation',
        'hasEssayAnswers':  true,   // reuses essay review pipeline for AI feedback
        'teacherReviewed':  false,
        'module':           widget.module,
        'simulationTitle':  widget.simulationTitle,
        'studentName':      studentName,
        'studentId':        user?.uid ?? '',
        'userId':           user?.uid ?? '',
        'createdAt':        FieldValue.serverTimestamp(),

        // ── AI feedback ───────────────────────────────────────────────────
        'aiScore':          score,
        'aiGrade':          feedback?.grade    ?? 'Not marked',
        'aiSummary':        feedback?.summary  ?? '',
        'aiStrengths':      feedback?.strengths    ?? [],
        'aiImprovements':   feedback?.improvements ?? [],
        'aiHint':           feedback?.hint     ?? '',
        'cbcStrand':        feedback?.cbcStrand ?? '',
        'aiMarked':         feedback != null,

        // ── Decision log (visible to teacher) ────────────────────────────
        'decisionLog':      widget.decisionLog,
        'summaryData':      widget.summaryData,

        // ── Stored as essayAnswers so TeacherEssayReviewScreen renders it ─
        'essayAnswers': jsonEncode([
          {
            'question':        'Simulation: ${widget.simulationTitle}',
            'answer':          widget.decisionLog.join('\n'),
            'aiScore':         score,
            'aiGrade':         feedback?.grade    ?? 'Not marked',
            'aiFeedback':      feedback?.summary  ?? 'AI marking unavailable.',
            'aiHint':          feedback?.hint     ?? '',
            'aiMarked':        feedback != null,
            'teacherApproved': false,
          }
        ]),
      });

      if (mounted) setState(() { _saved = true; _saving = false; });
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      debugPrint('[SimulationResultScreen] save error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedback = widget.feedback;
    final score    = feedback?.score ?? widget.fallbackScore;
    final grade    = feedback?.grade ?? _fallbackGrade(widget.fallbackScore);

    final gradeColor = _gradeColor(grade);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(widget.simulationTitle),
        backgroundColor: _green,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Score banner ────────────────────────────────────────────
            _ScoreBanner(score: score, grade: grade, gradeColor: gradeColor),

            const SizedBox(height: 20),

            // ── AI feedback card ─────────────────────────────────────────
            if (feedback != null) ...[
              _FeedbackCard(feedback: feedback, gradeColor: gradeColor),
              const SizedBox(height: 16),
            ] else ...[
              _NoAiFeedbackCard(fallbackScore: widget.fallbackScore),
              const SizedBox(height: 16),
            ],

            // ── Decision log ─────────────────────────────────────────────
            if (widget.decisionLog.isNotEmpty)
              _DecisionLogCard(log: widget.decisionLog),

            const SizedBox(height: 16),

            // ── Save status ──────────────────────────────────────────────
            _SaveStatusBar(saving: _saving, saved: _saved),

            const SizedBox(height: 24),

            // ── Done button ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.onDone,
                icon: const Icon(Icons.check_circle, size: 22),
                label: const Text('Done',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
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

  String _fallbackGrade(int score) {
    if (score >= 85) return 'Excellent';
    if (score >= 70) return 'Good';
    if (score >= 50) return 'Satisfactory';
    return 'Needs Work';
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _ScoreBanner extends StatelessWidget {
  final int score;
  final String grade;
  final Color gradeColor;
  const _ScoreBanner({required this.score, required this.grade, required this.gradeColor});

  @override
  Widget build(BuildContext context) => Card(
    elevation: 4,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [_green, Colors.green.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(children: [
        const Icon(Icons.emoji_events, size: 48, color: Colors.amber),
        const SizedBox(height: 12),
        Text('$score / 100',
            style: const TextStyle(
                fontSize: 42, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(grade,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ]),
    ),
  );
}

class _FeedbackCard extends StatelessWidget {
  final SimulationFeedback feedback;
  final Color gradeColor;
  const _FeedbackCard({required this.feedback, required this.gradeColor});

  @override
  Widget build(BuildContext context) => Card(
    elevation: 3,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
          const SizedBox(width: 8),
          const Text('AI Feedback',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Spacer(),
          if (feedback.cbcStrand.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Text(feedback.cbcStrand,
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.w600)),
            ),
        ]),
        const SizedBox(height: 12),

        // Summary
        Text(feedback.summary,
            style: const TextStyle(fontSize: 14, height: 1.5)),
        const SizedBox(height: 16),

        // Score bar
        Row(children: [
          Text('${feedback.score}/100',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: gradeColor)),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: feedback.score / 100,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(gradeColor),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 16),

        // Strengths
        if (feedback.strengths.isNotEmpty) ...[
          _SectionHeader(icon: Icons.check_circle_outline, label: 'Strengths', color: Colors.green.shade700),
          const SizedBox(height: 6),
          ...feedback.strengths.map((s) => _BulletRow(text: s, color: Colors.green.shade700)),
          const SizedBox(height: 12),
        ],

        // Improvements
        if (feedback.improvements.isNotEmpty) ...[
          _SectionHeader(icon: Icons.trending_up, label: 'Improvements', color: Colors.orange.shade700),
          const SizedBox(height: 6),
          ...feedback.improvements.map((s) => _BulletRow(text: s, color: Colors.orange.shade700)),
          const SizedBox(height: 12),
        ],

        // Hint
        if (feedback.hint.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.lightbulb_outline, size: 16, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(feedback.hint,
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade800,
                        fontStyle: FontStyle.italic)),
              ),
            ]),
          ),
      ]),
    ),
  );
}

class _NoAiFeedbackCard extends StatelessWidget {
  final int fallbackScore;
  const _NoAiFeedbackCard({required this.fallbackScore});

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.blue.shade50,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Icon(Icons.info_outline, color: Colors.blue.shade700),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'AI marking was unavailable. Your score of $fallbackScore/100 has been saved. '
            'Your teacher will review and finalise your result.',
            style: TextStyle(color: Colors.blue.shade800, fontSize: 14, height: 1.5),
          ),
        ),
      ]),
    ),
  );
}

class _DecisionLogCard extends StatefulWidget {
  final List<String> log;
  const _DecisionLogCard({required this.log});
  @override
  State<_DecisionLogCard> createState() => _DecisionLogCardState();
}

class _DecisionLogCardState extends State<_DecisionLogCard> {
  @override
  Widget build(BuildContext context) => Card(
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(Icons.list_alt, color: Colors.grey.shade600),
      title: const Text('Decision Log',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text('${widget.log.length} entries',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      children: widget.log.map((entry) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('• ', style: TextStyle(color: Colors.grey.shade500)),
          Expanded(
            child: Text(entry,
                style: const TextStyle(fontSize: 12, height: 1.4)),
          ),
        ]),
      )).toList(),
    ),
  );
}

class _SaveStatusBar extends StatelessWidget {
  final bool saving;
  final bool saved;
  const _SaveStatusBar({required this.saving, required this.saved});

  @override
  Widget build(BuildContext context) {
    if (saving) {
      return const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: _green)),
        SizedBox(width: 10),
        Text('Saving your results…',
            style: TextStyle(fontSize: 13, color: Colors.grey)),
      ]);
    }
    if (saved) {
      return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.cloud_done, color: Colors.green.shade600, size: 18),
        const SizedBox(width: 8),
        Text('Saved — your teacher can now review your results.',
            style: TextStyle(fontSize: 13, color: Colors.green.shade700)),
      ]);
    }
    return const SizedBox.shrink();
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SectionHeader({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 15, color: color),
    const SizedBox(width: 6),
    Text(label,
        style: TextStyle(
            fontWeight: FontWeight.w600, fontSize: 13, color: color)),
  ]);
}

class _BulletRow extends StatelessWidget {
  final String text;
  final Color color;
  const _BulletRow({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.circle, size: 6, color: color),
      const SizedBox(width: 8),
      Expanded(
        child: Text(text,
            style: const TextStyle(fontSize: 13, height: 1.4)),
      ),
    ]),
  );
}