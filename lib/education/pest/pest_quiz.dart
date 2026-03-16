// lib/education/pest/pest_quiz.dart

// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kilimomkononi/models/education_user.dart';
import 'package:kilimomkononi/utils/firestore_helper.dart';

const Color primaryGreen = Color(0xFF003900);

class PestQuizScreen extends StatefulWidget {
  final EduRole role;
  final String schoolName;
  final String classId;

  const PestQuizScreen({
    super.key,
    required this.role,
    required this.schoolName,
    required this.classId,
  });

  @override
  State<PestQuizScreen> createState() => _PestQuizScreenState();
}

class _PestQuizScreenState extends State<PestQuizScreen> {
  final String _contentType = 'pest_content';

  Future<void> _launchQuiz(String docId) async {
    final collection = FirestoreHelper.getContentFromClassId(widget.classId, _contentType);
    if (collection == null) return;

    try {
      final doc = await collection.doc(docId).get();
      final dataMap = doc.data() as Map<String, dynamic>?;

      if (dataMap == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load quiz')),
        );
        return;
      }

      final String title = dataMap['title'] is String && (dataMap['title'] as String).trim().isNotEmpty
          ? (dataMap['title'] as String).trim()
          : 'Pest Quiz';

      final payload = jsonDecode(dataMap['data'] as String);

      final fullPayload = {
        'id': doc.id,
        'title': title,
        'questions': payload,
      };

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PestQuizPlayScreen(
              payload: fullPayload,
              classId: widget.classId,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showQuizBuilder() {
    showDialog(
      context: context,
      builder: (_) => PestQuizBuilderDialog(
        classId: widget.classId,
        contentType: _contentType,
      ),
    );
  }

  Widget _buildActivityButton() {
    final raw = FirestoreHelper.getContentFromClassId(widget.classId, _contentType);
    if (raw == null) {
      return ElevatedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.quiz),
        label: const Text('Quizzes'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
      );
    }

    final coll = raw.withConverter<Map<String, dynamic>>(
      fromFirestore: (s, _) => s.data()!,
      toFirestore: (d, _) => d,
    );

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: coll.where('type', isEqualTo: 'quiz').snapshots(),
      builder: (context, snapshot) {
        int total = snapshot.data?.docs.length ?? 0;

        return ElevatedButton.icon(
          onPressed: total == 0 ? null : () => _showQuizList(),
          icon: const Icon(Icons.quiz, size: 28),
          label: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Quizzes', style: TextStyle(fontSize: 18)),
              if (total > 0) Text('$total available', style: const TextStyle(fontSize: 14)),
            ],
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
    );
  }

  void _showQuizList() {
    final coll = FirestoreHelper.getContentFromClassId(widget.classId, _contentType);
    if (coll == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        builder: (_, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Available Quizzes', style: Theme.of(context).textTheme.titleLarge),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: coll.where('type', isEqualTo: 'quiz').orderBy('createdAt', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: primaryGreen));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No quizzes available yet'));
                  }

                  return ListView.builder(
                    controller: controller,
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (_, i) {
                      final doc = snapshot.data!.docs[i];
                      final data = doc.data() as Map<String, dynamic>;
                      final title = data['title'] as String? ?? 'Pest Quiz';
                      final createdAt = data['createdAt'] as Timestamp?;

                      return ListTile(
                        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: createdAt != null
                            ? Text('Created: ${_formatDate(createdAt.toDate())}')
                            : null,
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          Navigator.pop(context);
                          _launchQuiz(doc.id);
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
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final bool isTeacher = widget.role == EduRole.teacher;

    // No AppBar - parent (pest_home) provides title and back button
    return SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bug_report, size: 100, color: primaryGreen.withOpacity(0.8)),
                      const SizedBox(height: 30),
                      const Text(
                        'Test your pest management knowledge',
                        style: TextStyle(fontSize: 20),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),

                      if (!isTeacher)
                        Card(
                          color: Colors.green.shade50,
                          elevation: 6,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: primaryGreen, width: 2),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.assignment_turned_in, size: 36, color: primaryGreen),
                                    const SizedBox(width: 16),
                                    const Text(
                                      'Practice Quiz',
                                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryGreen),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Choose a quiz to test your knowledge!',
                                  style: TextStyle(fontSize: 16),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                _buildActivityButton(),
                              ],
                            ),
                          ),
                        ),

                      if (isTeacher) ...[
                        const SizedBox(height: 40),
                        ElevatedButton.icon(
                          onPressed: _showQuizBuilder,
                          icon: const Icon(Icons.add, size: 28),
                          label: const Text(
                            'Create New Quiz',
                            style: TextStyle(fontSize: 20),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryGreen,
                            padding: const EdgeInsets.all(20),
                            minimumSize: const Size(double.infinity, 60),
                          ),
                        ),
                      ],

                      const Spacer(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
  }
}

// ==================== QUIZ PLAY SCREEN ====================
class PestQuizPlayScreen extends StatefulWidget {
  final Map<String, dynamic> payload;
  final String classId;

  const PestQuizPlayScreen({
    super.key,
    required this.payload,
    required this.classId,
  });

  @override
  State<PestQuizPlayScreen> createState() => _PestQuizPlayScreenState();
}

class _PestQuizPlayScreenState extends State<PestQuizPlayScreen> {
  int _idx = 0;
  int _score = 0;
  late final ConfettiController _conf = ConfettiController(duration: const Duration(seconds: 2));

  void _ans(int sel) {
    final correct = widget.payload['questions'][_idx]['correct'] as int;
    if (sel == correct) {
      _score++;
      _conf.play();
    }
    if (_idx < widget.payload['questions'].length - 1) {
      setState(() => _idx++);
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    final coll = FirestoreHelper.getSubmissionsFromClassId(widget.classId);
    if (coll != null) {
      await coll.add({
        'type': 'pest_quiz',
        'quizId': widget.payload['id'],
        'title': widget.payload['title'],
        'score': _score,
        'total': widget.payload['questions'].length,
        'userId': FirebaseAuth.instance.currentUser!.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Quiz Complete!'),
          content: Text('Score: $_score / ${widget.payload['questions'].length}\n\nSaved!'),
          actions: [TextButton(onPressed: () => Navigator.of(context)..pop()..pop(), child: const Text('Done'))],
        ),
      );
    }
  }

  @override
  void dispose() {
    _conf.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.payload['questions'][_idx];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.payload['title']),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ConfettiWidget(confettiController: _conf, blastDirectionality: BlastDirectionality.explosive),
            const SizedBox(height: 30),
            Text(q['question'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 40),
            ...(q['options'] as List).asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: ElevatedButton(
                    onPressed: () => _ans(e.key),
                    style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, minimumSize: const Size(double.infinity, 56)),
                    child: Text('${String.fromCharCode(65 + e.key)}. ${e.value}', style: const TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

// ==================== QUIZ BUILDER DIALOG ====================
class PestQuizBuilderDialog extends StatefulWidget {
  final String classId;
  final String contentType;

  const PestQuizBuilderDialog({
    super.key,
    required this.classId,
    required this.contentType,
  });

  @override
  State<PestQuizBuilderDialog> createState() => _PestQuizBuilderDialogState();
}

class _PestQuizBuilderDialogState extends State<PestQuizBuilderDialog> {
  final _titleCtrl = TextEditingController();
  final List<Map<String, dynamic>> _questions = [];

  void _addQuestion() {
    final questionCtrl = TextEditingController();
    final optionCtrls = List.generate(4, (_) => TextEditingController());
    int correctIndex = 0;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Question'),
        content: StatefulBuilder(
          builder: (context, setStateInner) => SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: questionCtrl, decoration: const InputDecoration(labelText: 'Question')),
              const SizedBox(height: 12),
              ...optionCtrls.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Radio<int>(value: e.key, groupValue: correctIndex, onChanged: (v) => setStateInner(() => correctIndex = v ?? 0)),
                      Expanded(child: TextField(controller: e.value, decoration: InputDecoration(labelText: 'Option ${e.key + 1}'))),
                    ]),
                  )),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
            onPressed: () {
              final filled = optionCtrls.where((c) => c.text.trim().isNotEmpty).toList();
              if (questionCtrl.text.trim().isEmpty || filled.length < 2) return;
              setState(() {
                _questions.add({
                  'question': questionCtrl.text.trim(),
                  'options': filled.map((c) => c.text.trim()).toList(),
                  'correct': correctIndex,
                });
              });
              Navigator.pop(context);
            },
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveQuiz() async {
    if (_questions.isEmpty) return;

    await FirestoreHelper.addContentToClass(
      widget.classId,
      widget.contentType,
      {
        'type': 'quiz',
        'title': _titleCtrl.text.trim().isEmpty ? 'Pest Quiz' : _titleCtrl.text.trim(),
        'data': jsonEncode(_questions),
        'createdAt': FieldValue.serverTimestamp(),
        'userId': FirebaseAuth.instance.currentUser!.uid,
      },
    );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quiz created successfully!'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Create Pest Quiz'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Quiz Title (optional)')),
            const SizedBox(height: 16),
            ElevatedButton.icon(onPressed: _addQuestion, icon: const Icon(Icons.add), label: const Text('Add Question')),
            const SizedBox(height: 16),
            ..._questions.asMap().entries.map((e) {
              final q = e.value;
              final correctLetter = String.fromCharCode(65 + (q['correct'] as int));
              return Card(
                child: ListTile(
                  title: Text(q['question']),
                  subtitle: Text('Correct: $correctLetter. ${(q['options'] as List)[q['correct']]}',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () => setState(() => _questions.removeAt(e.key))),
                ),
              );
            }),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
            onPressed: _questions.isEmpty ? null : _saveQuiz,
            child: const Text('Save Quiz', style: TextStyle(color: Colors.white)),
          ),
        ],
      );
}