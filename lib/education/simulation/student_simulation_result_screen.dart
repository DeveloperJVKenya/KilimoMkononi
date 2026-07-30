// lib/education/simulation/student_simulation_result_screen.dart

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kilimomkononi/utils/firestore_helper.dart';
import 'package:kilimomkononi/education/simulation/simulation_home.dart'; // For getSimulationWidget

const Color _green = Color(0xFF032704);

// ═══════════════════════════════════════════════════════════════════════════
//  StudentSimulationResultScreen
// ═══════════════════════════════════════════════════════════════════════════

class StudentSimulationResultScreen extends StatelessWidget {
  final String classId;
  final String module;
  final String title;

  const StudentSimulationResultScreen({
    super.key,
    required this.classId,
    required this.module,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final coll = FirestoreHelper.getSubmissionsFromClassId(classId);

    if (uid == null || coll == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(title),
          backgroundColor: _green,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Unable to load result.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: _green,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: coll
            .where('type', isEqualTo: 'simulation')
            .where('module', isEqualTo: module)
            .where('userId', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _green));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    const Text('No result found.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Complete the simulation first.', style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
          return _ResultBody(
            data: data,
            title: title,
            classId: classId,
            module: module,
          );
        },
      ),
    );
  }
}

// ─── Body widget ─────────────────────────────────────────────────────────────

class _ResultBody extends StatelessWidget {
  final Map<String, dynamic> data;
  final String title;
  final String classId;
  final String module;

  const _ResultBody({
    required this.data,
    required this.title,
    required this.classId,
    required this.module,
  });

  @override
  Widget build(BuildContext context) {
    // ── Read Firestore fields ─────────────────────────────────────────
    final bool reviewed = data['teacherReviewed'] == true;
    final bool aiMarked = data['aiMarked'] == true;
    final int aiScore = (data['aiScore'] as num?)?.toInt() ?? 0;
    final int fbScore = (data['fallbackScore'] as num?)?.toInt() ?? 0;
    final String aiGrade = data['aiGrade'] as String? ?? '';
    final String aiSummary = data['aiSummary'] as String? ?? '';
    final String aiHint = data['aiHint'] as String? ?? '';
    final String cbcStrand = data['cbcStrand'] as String? ?? '';
    final String simTitle = data['simulationTitle'] as String? ?? title;
    final List<String> strengths = List<String>.from(data['aiStrengths'] as List? ?? []);
    final List<String> improvements = List<String>.from(data['aiImprovements'] as List? ?? []);
    final List<String> decisionLog = List<String>.from(data['decisionLog'] as List? ?? []);
    final Timestamp? createdAt = data['createdAt'] as Timestamp?;

    // ── Teacher's finalScore + comment ────
    int? teacherFinalScore;
    String teacherComment = '';
    final essayRaw = data['essayAnswers'] as String?;
    if (essayRaw != null) {
      try {
        final list = jsonDecode(essayRaw) as List?;
        if (list != null && list.isNotEmpty) {
          final essay = list[0] as Map<String, dynamic>;
          if (essay['teacherApproved'] == true) {
            teacherFinalScore = (essay['finalScore'] as num?)?.toInt();
            teacherComment = essay['teacherComment'] as String? ?? '';
          }
        }
      } catch (_) {}
    }

    final int displayScore = teacherFinalScore ?? (aiMarked ? aiScore : fbScore);
    final String displayGrade = teacherFinalScore != null ? _scoreToGrade(displayScore) : aiGrade;
    final Color gradeColor = _gradeColor(displayGrade);

    String fmtDate(DateTime dt) {
      final d = DateTime.now().difference(dt);
      if (d.inDays == 0) return 'Today';
      if (d.inDays == 1) return 'Yesterday';
      if (d.inDays < 7) return '${d.inDays} days ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Score banner
          Card(
            elevation: 5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: reviewed
                      ? [_green, Colors.green.shade700]
                      : [Colors.orange.shade800, Colors.orange.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(children: [
                Icon(
                  reviewed ? (teacherFinalScore != null ? Icons.verified : Icons.check_circle) : Icons.pending,
                  size: 48,
                  color: Colors.white,
                ),
                const SizedBox(height: 12),
                Text('$displayScore / 100',
                    style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    reviewed
                        ? (teacherFinalScore != null ? 'Final Score  ·  Teacher Reviewed' : 'Reviewed')
                        : (aiMarked ? 'AI Marked  ·  Awaiting Teacher Review' : 'Submitted  ·  Awaiting Review'),
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                if (displayGrade.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(displayGrade, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ],
                if (createdAt != null) ...[
                  const SizedBox(height: 4),
                  Text('Completed ${fmtDate(createdAt.toDate())}',
                      style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
                if (cbcStrand.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('CBC: $cbcStrand', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ]),
            ),
          ),
          const SizedBox(height: 16),

          if (!reviewed)
            _InfoBanner(
              icon: Icons.hourglass_top,
              color: Colors.orange,
              text: 'Your teacher will review the AI marking and finalise your score. This page updates automatically — check back soon!',
            ),

          if (reviewed && teacherComment.isNotEmpty) ...[
            _SectionHeader(icon: Icons.person, label: 'Teacher Comment', color: _green),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Text(teacherComment, style: const TextStyle(fontSize: 14, height: 1.5)),
            ),
            const SizedBox(height: 16),
          ],

          // AI Feedback Card - FULL VERSION
          if (aiMarked) ...[
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.auto_awesome, color: Colors.amber, size: 18),
                    const SizedBox(width: 8),
                    const Text('AI Feedback', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const Spacer(),
                    if (aiGrade.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: gradeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: gradeColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(aiGrade,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: gradeColor)),
                      ),
                  ]),
                  const SizedBox(height: 12),

                  // Score bar
                  Row(children: [
                    Text('$aiScore / 100',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: gradeColor)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: aiScore / 100,
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(gradeColor),
                        ),
                      ),
                    ),
                  ]),

                  if (aiSummary.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(aiSummary, style: const TextStyle(fontSize: 13, height: 1.5)),
                  ],

                  if (strengths.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _FeedbackBullets(
                      icon: Icons.check_circle_outline,
                      label: 'What you did well',
                      color: Colors.green.shade700,
                      items: strengths,
                    ),
                  ],
                  if (improvements.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _FeedbackBullets(
                      icon: Icons.trending_up,
                      label: 'How to improve',
                      color: Colors.orange.shade700,
                      items: improvements,
                    ),
                  ],
                  if (aiHint.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lightbulb_outline, size: 15, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(aiHint,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade800,
                                    fontStyle: FontStyle.italic,
                                    height: 1.4)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ]),
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            _InfoBanner(
              icon: Icons.info_outline,
              color: Colors.blue,
              text: 'AI marking was unavailable. Your teacher will mark this simulation manually.',
            ),
          ],

          // Decision Log
          if (decisionLog.isNotEmpty) ...[
            _SectionHeader(icon: Icons.list_alt, label: 'Your Decisions', color: Colors.grey.shade700),
            const SizedBox(height: 8),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: decisionLog.asMap().entries.map((e) {
                  final isPos = e.value.contains('positive');
                  final isNeg = e.value.contains('negative');
                  final lineColor = isPos ? Colors.green.shade700 : isNeg ? Colors.red.shade700 : Colors.grey.shade700;
                  final bgColor = isPos ? Colors.green.shade50 : isNeg ? Colors.red.shade50 : Colors.grey.shade50;

                  return Container(
                    decoration: BoxDecoration(
                      color: bgColor,
                      border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.5)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: lineColor.withValues(alpha: 0.15), shape: BoxShape.circle),
                          child: Text('${e.key + 1}',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: lineColor)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            e.value
                                .replaceAll(' — positive', '')
                                .replaceAll(' — negative', '')
                                .replaceAll(' — neutral', ''),
                            style: TextStyle(fontSize: 12, color: lineColor, height: 1.4),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Icon(
                            isPos ? Icons.arrow_upward : isNeg ? Icons.arrow_downward : Icons.remove,
                            size: 13,
                            color: lineColor.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Action Buttons
          const SizedBox(height: 8),

          // Try Again Button - Launches the SAME simulation again
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              // Inside the "Try This Simulation Again" ElevatedButton onPressed:
// Inside _ResultBody > Try Again button onPressed:
onPressed: () {
  final user = FirebaseAuth.instance.currentUser;
  final name = user?.displayName?.trim().isNotEmpty == true 
      ? user!.displayName! 
      : 'Student';

  String? cropName;

  // Try to extract crop name from saved data
  if (data['crop'] != null) {
    cropName = data['crop'] as String?;
  } else if (simTitle.toLowerCase().contains('maize') || 
             simTitle.toLowerCase().contains('bean') || 
             simTitle.toLowerCase().contains('maize')) {
    cropName = simTitle.split(' ').first; // rough fallback
  }

  final simWidget = getSimulationWidget(
    module: module,
    classId: classId,
    studentName: name,
    cropName: cropName,                    // ← Important for Farming Tips
    onComplete: () => Navigator.of(context).popUntil((r) => r.isFirst),
  );

  if (simWidget != null) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => simWidget),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not launch simulation. Returning to list.')),
    );
    Navigator.pop(context);
  }
},
              icon: const Icon(Icons.replay, size: 20),
              label: const Text('Try This Simulation Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Back to Simulations
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to All Simulations'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Color _gradeColor(String grade) {
    switch (grade) {
      case 'Excellent': return Colors.green.shade700;
      case 'Good': return Colors.blue.shade700;
      case 'Satisfactory': return Colors.orange.shade700;
      default: return Colors.red.shade700;
    }
  }

  String _scoreToGrade(int s) {
    if (s >= 85) return 'Excellent';
    if (s >= 70) return 'Good';
    if (s >= 50) return 'Satisfactory';
    return 'Needs Work';
  }
}

// ─── Reusable Sub-Widgets ───────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SectionHeader({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
        ]),
      );
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _InfoBanner({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: TextStyle(fontSize: 13, color: color.withValues(alpha: 0.9), height: 1.4)),
            ),
          ]),
        ),
      );
}

class _FeedbackBullets extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final List<String> items;

  const _FeedbackBullets({
    required this.icon,
    required this.label,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ]),
          const SizedBox(height: 5),
          ...items.map((s) => Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.circle, size: 5, color: color),
                  const SizedBox(width: 7),
                  Expanded(child: Text(s, style: const TextStyle(fontSize: 13, height: 1.4))),
                ]),
              )),
        ],
      );
}