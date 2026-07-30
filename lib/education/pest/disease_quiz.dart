// lib/education/pest/disease_quiz.dart

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kilimomkononi/models/education_user.dart';
import 'package:kilimomkononi/utils/firestore_helper.dart';
import 'package:kilimomkononi/education/quiz/shared_quiz_widgets.dart';

const Color primaryGreen = Color(0xFF388E3C);

// ─── Grade helpers ────────────────────────────────────────────────────────

bool _isPrimaryClass(String classId) {
  if (classId.contains('cbcPrimary')) return true;
  final match = RegExp(r'_(\d+)$').firstMatch(classId);
  return match != null && (int.tryParse(match.group(1)!) ?? 7) <= 6;
}

String _gradeLabel(String classId) {
  final match = RegExp(r'_(\d+)$').firstMatch(classId);
  if (match != null) {
    final n = match.group(1)!;
    if (classId.contains('eightfourfour')) {
      final num = int.tryParse(n) ?? 1;
      return num <= 8 ? 'Standard $n' : 'Form ${num - 8}';
    }
    return 'Grade $n';
  }
  return classId;
}

// ═══════════════════════════════════════════════════════════════════════════
//  DiseaseQuizScreen
//  Hub — no AppBar (parent disease_home provides it).
// ═══════════════════════════════════════════════════════════════════════════

class DiseaseQuizScreen extends StatefulWidget {
  final EduRole role;
  final String  schoolName;
  final String  classId;

  const DiseaseQuizScreen({
    super.key,
    required this.role,
    required this.schoolName,
    required this.classId,
  });

  @override
  State<DiseaseQuizScreen> createState() => _DiseaseQuizScreenState();
}

class _DiseaseQuizScreenState extends State<DiseaseQuizScreen> {
  final String _contentType = 'disease_content';

  // ── Teacher: AI quiz builder ──────────────────────────────────────

  void _showQuizBuilder() => showDialog(
        context: context,
        builder: (_) => EduQuizBuilder(
          onSave:        (d) => _saveQuiz(d),
          topicLabel:    'Plant Disease Management',
          geminiSubject: 'plant disease identification, symptoms, prevention and management in Kenyan crops including maize, beans, tomatoes and other common crops',
          grade:         _gradeLabel(widget.classId),
          isPrimary:     _isPrimaryClass(widget.classId),
        ),
      );

  Future<void> _saveQuiz(Map<String, dynamic> data) async {
    await FirestoreHelper.addContentToClass(
      widget.classId,
      _contentType,
      {
        'type':      'quiz',
        'title':     data['title'] as String? ?? 'Disease Quiz',
        'data':      jsonEncode(data['questions']),
        'createdAt': FieldValue.serverTimestamp(),
        'userId':    FirebaseAuth.instance.currentUser!.uid,
      },
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:         Text('Quiz created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _openEssayReview() => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TeacherEssayReviewScreen(
            classId:    widget.classId,
            schoolName: widget.schoolName,
          ),
        ),
      );

  // ── Student: launch quiz ──────────────────────────────────────────

  Future<void> _launchQuiz(String docId, {bool essayOnly = false}) async {
    final collection =
        FirestoreHelper.getContentFromClassId(widget.classId, _contentType);
    if (collection == null) return;

    try {
      final doc    = await collection.doc(docId).get();
      final dataMap = doc.data() as Map<String, dynamic>?;
      if (dataMap == null) return;

      final title = dataMap['title'] is String &&
              (dataMap['title'] as String).trim().isNotEmpty
          ? (dataMap['title'] as String).trim()
          : 'Disease Quiz';

      final payload = jsonDecode(dataMap['data'] as String);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EduQuizScreen(
              payload: {
                'id':        docId,
                'title':     title,
                'grade':     _gradeLabel(widget.classId),
                'questions': payload,
                'module':    'Disease',
              },
              classId:       widget.classId,
              isPrimary:     _isPrimaryClass(widget.classId),
              geminiSubject: 'plant disease identification, symptoms, prevention and management in Kenyan crops',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ── Streaming split quiz/essay buttons ──────────────────────────

  Widget _buildActivityButton() {
    final raw = FirestoreHelper.getContentFromClassId(widget.classId, _contentType);
    if (raw == null) {
      return _SplitActivityButtons(mcqCount: 0, essayCount: 0, onMcqTap: null, onEssayTap: null);
    }
    final coll = raw.withConverter<Map<String, dynamic>>(
      fromFirestore: (s, _) => s.data()!,
      toFirestore:   (d, _) => d,
    );
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: coll.where('type', isEqualTo: 'quiz').snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        int mcqDocs = 0, essayDocs = 0;
        for (final doc in docs) {
          final data = doc.data();
          List<dynamic> qs = [];
          try {
            final raw = data['data'];
            qs = raw is String ? (jsonDecode(raw) as List? ?? []) : (raw as List? ?? []);
          } catch (_) {}
          if (qs.any((q) => (q as Map<String, dynamic>?)?['type'] != 'essay')) mcqDocs++;
          if (qs.any((q) => (q as Map<String, dynamic>?)?['type'] == 'essay')) essayDocs++;
        }
        return _SplitActivityButtons(
          mcqCount:   mcqDocs,
          essayCount: essayDocs,
          onMcqTap:   mcqDocs   == 0 ? null : () => _showQuizListFiltered(essayOnly: false),
          onEssayTap: essayDocs == 0 ? null : () => _showQuizListFiltered(essayOnly: true),
        );
      },
    );
  }

  void _showQuizListFiltered({bool essayOnly = false}) {
    final coll = FirestoreHelper.getContentFromClassId(widget.classId, _contentType);
    if (coll == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize:     0.95,
        builder: (_, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Icon(essayOnly ? Icons.edit_note : Icons.check_circle_outline,
                    color: essayOnly ? Colors.purple : Colors.blue, size: 22),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  essayOnly ? 'Essay assignments' : 'Available Quizzes',
                  style: Theme.of(context).textTheme.titleLarge,
                )),
              ]),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: coll
                    .where('type', isEqualTo: 'quiz')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: primaryGreen));
                  }
                  final allDocs = snapshot.data?.docs ?? [];
                  final filteredDocs = allDocs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    List<dynamic> qs = [];
                    try {
                      final raw = data['data'];
                      qs = raw is String ? (jsonDecode(raw) as List? ?? []) : (raw as List? ?? []);
                    } catch (_) {}
                    return essayOnly
                        ? qs.any((q) => (q as Map<String, dynamic>?)?['type'] == 'essay')
                        : qs.any((q) => (q as Map<String, dynamic>?)?['type'] != 'essay');
                  }).toList();
                  if (filteredDocs.isEmpty) {
                    return Center(child: Text(
                      essayOnly ? 'No essay assignments yet' : 'No quizzes available yet',
                    ));
                  }
                  return ListView.builder(
                    controller: controller,
                    itemCount: filteredDocs.length,
                    itemBuilder: (_, i) {
                      final doc       = filteredDocs[i];
                      final data      = doc.data() as Map<String, dynamic>;
                      final title     = data['title'] as String? ?? 'Disease Quiz';
                      final createdAt = data['createdAt'] as Timestamp?;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: essayOnly ? Colors.purple : Colors.blue,
                          child: Icon(essayOnly ? Icons.edit_note : Icons.quiz,
                              color: Colors.white, size: 20),
                        ),
                        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: createdAt != null
                            ? Text(_formatDate(createdAt.toDate())) : null,
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.pop(context);
                          _launchQuiz(doc.id, essayOnly: essayOnly);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }



  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7)  return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final bool isTeacher = widget.role == EduRole.teacher;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
                minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_hospital,
                      size: 100,
                      color: primaryGreen.withValues(alpha: 0.8)),
                  const SizedBox(height: 30),
                  const Text(
                    'Test your disease management knowledge',
                    style:     TextStyle(fontSize: 20),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // ── Student view ─────────────────────────
                  if (!isTeacher)
                    Card(
                      color:     Colors.green.shade50,
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                            color: primaryGreen, width: 2),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Icon(Icons.assignment_turned_in,
                                  size: 36,
                                  color: primaryGreen),
                              const SizedBox(width: 16),
                              const Text('Practice Quiz',
                                  style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: primaryGreen)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                              'Choose a quiz to test your knowledge!',
                              style:     TextStyle(fontSize: 16),
                              textAlign: TextAlign.center),
                          const SizedBox(height: 24),
                          _buildActivityButton(),
                        ]),
                      ),
                    ),

                  // ── Teacher view ─────────────────────────
                  if (isTeacher) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _showQuizBuilder,
                      icon: const Icon(Icons.auto_awesome,
                          color: Colors.amber, size: 24),
                      label: const Text('Create Quiz with AI',
                          style: TextStyle(fontSize: 18)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(20),
                        minimumSize:
                            const Size(double.infinity, 60),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _openEssayReview,
                      icon: const Icon(
                          Icons.rate_review_outlined),
                      label: const Text(
                          'Review essay submissions'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryGreen,
                        side: const BorderSide(
                            color: primaryGreen),
                        minimumSize:
                            const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _showQuizListFiltered(),
                      icon: const Icon(Icons.list_alt),
                      label: const Text(
                          'View existing quizzes'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        side: BorderSide(
                            color: Colors.grey.shade400),
                        minimumSize:
                            const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(12)),
                      ),
                    ),
                  ],

                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Shared split-button widget ──────────────────────────────────────────────

class _SplitActivityButtons extends StatelessWidget {
  final int mcqCount, essayCount;
  final VoidCallback? onMcqTap, onEssayTap;
  const _SplitActivityButtons({required this.mcqCount, required this.essayCount, required this.onMcqTap, required this.onEssayTap});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _btn(icon: Icons.check_circle_outline, label: 'Quizzes', count: mcqCount,
              color: Colors.blue.shade600, bgColor: Colors.blue.shade50, onTap: onMcqTap),
          const SizedBox(height: 8),
          _btn(icon: Icons.edit_note, label: 'Essay assignments', count: essayCount,
              color: Colors.purple.shade600, bgColor: Colors.purple.shade50, onTap: onEssayTap),
        ],
      );

  Widget _btn({required IconData icon, required String label, required int count,
      required Color color, required Color bgColor, required VoidCallback? onTap}) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: onTap == null ? Colors.grey.shade100 : bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: onTap == null ? Colors.grey.shade300 : color.withValues(alpha: 0.35)),
          ),
          child: Row(children: [
            Icon(icon, color: onTap == null ? Colors.grey : color, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14,
                color: onTap == null ? Colors.grey : color))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: onTap == null ? Colors.grey.shade200 : color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(count == 0 ? 'None yet' : '$count available',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: onTap == null ? Colors.grey.shade500 : color)),
            ),
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_ios, size: 13,
                color: onTap == null ? Colors.grey.shade300 : color.withValues(alpha: 0.6)),
          ]),
        ),
      );
}