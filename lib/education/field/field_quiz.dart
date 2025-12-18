// lib/education/field/field_quiz.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kilimomkononi/models/education_user.dart';
import 'package:kilimomkononi/utils/firestore_helper.dart';

const Color primaryGreen = Color(0xFF032704);

extension StringExt on String {
  String capitalize() => isNotEmpty ? '${this[0].toUpperCase()}${substring(1)}' : this;
}

class FieldQuizScreen extends StatefulWidget {
  final EduRole role;
  final String schoolName;
  final String classId;

  const FieldQuizScreen({
    super.key,
    required this.role,
    required this.schoolName,
    required this.classId,
  });

  @override
  State<FieldQuizScreen> createState() => _FieldQuizScreenState();
}

class _FieldQuizScreenState extends State<FieldQuizScreen> {
  final String _contentType = 'field_content';

  Future<void> _saveQuiz(Map<String, dynamic> data) async {
    await FirestoreHelper.ensureGradeExists(widget.classId);
    final collection = FirestoreHelper.getContentFromClassId(widget.classId, _contentType);
    if (collection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid class configuration')),
      );
      return;
    }

    final String title = data['title'] as String? ?? 'Field Quiz';

    try {
      await collection.add({
        'type': 'quiz',
        'title': title,
        'data': jsonEncode(data['questions']),
        'createdAt': FieldValue.serverTimestamp(),
        'userId': FirebaseAuth.instance.currentUser!.uid,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title saved successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _launchQuiz(String docId) async {
    final rawCollection = FirestoreHelper.getContentFromClassId(widget.classId, _contentType);
    if (rawCollection == null) return;

    try {
      final doc = await rawCollection.doc(docId).get();
      final dataMap = doc.data() as Map<String, dynamic>?;

      if (dataMap == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load quiz')),
        );
        return;
      }

      final String title = dataMap['title'] is String && (dataMap['title'] as String).trim().isNotEmpty
          ? (dataMap['title'] as String).trim()
          : 'Field Quiz';

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
            builder: (_) => FieldQuizPlayScreen(
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

  Widget _buildQuizButton() {
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
          onPressed: total == 0 ? null : () => _showActivityList(),
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

  void _showActivityList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.6,
        expand: false,
        builder: (_, controller) => _buildQuizList(scrollController: controller),
      ),
    );
  }

  Widget _buildQuizList({ScrollController? scrollController}) {
    final rawCollection = FirestoreHelper.getContentFromClassId(widget.classId, _contentType);
    if (rawCollection == null) {
      return const Center(child: Text('Invalid configuration'));
    }

    final collection = rawCollection.withConverter<Map<String, dynamic>>(
      fromFirestore: (snapshot, _) => snapshot.data()!,
      toFirestore: (data, _) => data,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Quizzes',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryGreen),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: collection.where('type', isEqualTo: 'quiz').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: primaryGreen));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Text(
                    'No quizzes available yet',
                    style: const TextStyle(fontSize: 18, fontStyle: FontStyle.italic, color: Colors.grey),
                  ),
                );
              }

              final userId = FirebaseAuth.instance.currentUser!.uid;
              final submissionsColl = FirestoreHelper.getSubmissionsFromClassId(widget.classId);

              return FutureBuilder<Set<String>>(
                future: submissionsColl == null
                    ? Future.value(<String>{})
                    : submissionsColl
                        .where('userId', isEqualTo: userId)
                        .where('type', isEqualTo: 'quiz')
                        .get()
                        .then((s) => s.docs
                            .map((d) => (d.data() as Map<String, dynamic>?)?['quizId'] as String?)
                            .whereType<String>()
                            .toSet()),
                builder: (context, completedSnap) {
                  final completedIds = completedSnap.data ?? <String>{};

                  final availableDocs = snapshot.data!.docs.where((doc) => !completedIds.contains(doc.id)).toList();

                  if (availableDocs.isEmpty) {
                    return const Center(
                      child: Text('All completed! Great job! 🎉', style: TextStyle(fontSize: 18)),
                    );
                  }

                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: availableDocs.length,
                    itemBuilder: (context, index) {
                      final doc = availableDocs[index];
                      final data = doc.data();
                      final title = data['title'] as String? ?? 'Field Quiz';
                      final createdAt = data['createdAt'] as Timestamp?;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 4,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: primaryGreen,
                            child: const Icon(Icons.quiz, color: Colors.white),
                          ),
                          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: createdAt != null ? Text('Created: ${_formatDate(createdAt.toDate())}') : null,
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            Navigator.pop(context);
                            _launchQuiz(doc.id);
                          },
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
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

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.quiz, size: 100, color: primaryGreen),
            const SizedBox(height: 24),
            const Text('Test your knowledge on field practices', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 40),

            if (!isTeacher)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Card(
                  color: Colors.green.shade50,
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: primaryGreen, width: 2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.assignment_turned_in, size: 32, color: primaryGreen),
                            const SizedBox(width: 12),
                            Text(
                              'Practice Activities',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryGreen),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text('Test your field knowledge with quizzes!', style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 20),
                        _buildQuizButton(),
                      ],
                    ),
                  ),
                ),
              ),

            if (isTeacher)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: ElevatedButton.icon(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => FieldQuizBuilderDialog(onSave: _saveQuiz),
                    ),
                    icon: const Icon(Icons.add, size: 28),
                    label: const Text('Create New Quiz', style: TextStyle(fontSize: 18)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class FieldQuizPlayScreen extends StatefulWidget {
  final Map<String, dynamic> payload;
  final String classId;

  const FieldQuizPlayScreen({super.key, required this.payload, required this.classId});

  @override
  State<FieldQuizPlayScreen> createState() => _FieldQuizPlayScreenState();
}

class _FieldQuizPlayScreenState extends State<FieldQuizPlayScreen> {
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
        'type': 'quiz',
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
      appBar: AppBar(title: Text(widget.payload['title']), backgroundColor: primaryGreen, foregroundColor: Colors.white),
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

class FieldQuizBuilderDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;
  const FieldQuizBuilderDialog({super.key, required this.onSave});

  @override
  State<FieldQuizBuilderDialog> createState() => _FieldQuizBuilderDialogState();
}

class _FieldQuizBuilderDialogState extends State<FieldQuizBuilderDialog> {
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

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Create Field Quiz'),
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
                  subtitle: Text('Correct: $correctLetter. ${(q['options'] as List)[q['correct']]}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
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
            onPressed: _questions.isEmpty ? null : () {
              widget.onSave({'title': _titleCtrl.text.trim().isEmpty ? 'Field Quiz' : _titleCtrl.text.trim(), 'questions': _questions});
              Navigator.pop(context);
            },
            child: const Text('Save Quiz', style: TextStyle(color: Colors.white)),
          ),
        ],
      );
}