// lib/education/field/field_simulation.dart
// ignore_for_file: use_build_context_synchronously, deprecated_member_use

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

class FieldSimulationScreen extends StatefulWidget {
  final EduRole role;
  final String schoolName;
  final String classId;

  const FieldSimulationScreen({
    super.key,
    required this.role,
    required this.schoolName,
    required this.classId,
  });

  @override
  State<FieldSimulationScreen> createState() => _FieldSimulationScreenState();
}

class _FieldSimulationScreenState extends State<FieldSimulationScreen> {
  final String _contentType = 'field_content';

  Future<void> _saveSimulation(Map<String, dynamic> data) async {
    await FirestoreHelper.ensureGradeExists(widget.classId);
    final collection = FirestoreHelper.getContentFromClassId(widget.classId, _contentType);
    if (collection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid class configuration')),
      );
      return;
    }

    final String title = data['title'] as String? ?? 'Field Simulation';

    try {
      await collection.add({
        'type': 'simulation',
        'title': title,
        'data': jsonEncode(data['steps']),
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

  Future<void> _launchSimulation(String docId) async {
    final rawCollection = FirestoreHelper.getContentFromClassId(widget.classId, _contentType);
    if (rawCollection == null) return;

    try {
      final doc = await rawCollection.doc(docId).get();
      final dataMap = doc.data() as Map<String, dynamic>?;

      if (dataMap == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load simulation')),
        );
        return;
      }

      final String title = dataMap['title'] is String && (dataMap['title'] as String).trim().isNotEmpty
          ? (dataMap['title'] as String).trim()
          : 'Field Simulation';

      final payload = jsonDecode(dataMap['data'] as String);

      final fullPayload = {
        'id': doc.id,
        'title': title,
        'steps': payload,
      };

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FieldSimulationPlayScreen(
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

  Widget _buildSimulationButton() {
    final raw = FirestoreHelper.getContentFromClassId(widget.classId, _contentType);
    if (raw == null) {
      return ElevatedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.play_circle),
        label: const Text('Simulations'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
      );
    }

    final coll = raw.withConverter<Map<String, dynamic>>(
      fromFirestore: (s, _) => s.data()!,
      toFirestore: (d, _) => d,
    );

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: coll.where('type', isEqualTo: 'simulation').snapshots(),
      builder: (context, snapshot) {
        int total = snapshot.data?.docs.length ?? 0;

        return ElevatedButton.icon(
          onPressed: total == 0 ? null : () => _showActivityList(),
          icon: const Icon(Icons.play_circle, size: 28),
          label: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Simulations', style: TextStyle(fontSize: 18)),
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
        builder: (_, controller) => _buildSimulationList(scrollController: controller),
      ),
    );
  }

  Widget _buildSimulationList({ScrollController? scrollController}) {
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
            'Simulations',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryGreen),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: collection.where('type', isEqualTo: 'simulation').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: primaryGreen));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Text(
                    'No simulations available yet',
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
                        .where('type', isEqualTo: 'simulation')
                        .get()
                        .then((s) => s.docs
                            .map((d) => (d.data() as Map<String, dynamic>?)?['simulationId'] as String?)
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
                      final title = data['title'] as String? ?? 'Field Simulation';
                      final createdAt = data['createdAt'] as Timestamp?;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 4,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: primaryGreen,
                            child: const Icon(Icons.play_circle, color: Colors.white),
                          ),
                          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: createdAt != null ? Text('Created: ${_formatDate(createdAt.toDate())}') : null,
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            Navigator.pop(context);
                            _launchSimulation(doc.id);
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
            const Icon(Icons.science, size: 100, color: primaryGreen),
            const SizedBox(height: 24),
            const Text('Practice decision-making in the field', style: TextStyle(fontSize: 20)),
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
                        const Text('Practice real field scenarios!', style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 20),
                        _buildSimulationButton(),
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
                      builder: (_) => FieldSimulationBuilderDialog(onSave: _saveSimulation),
                    ),
                    icon: const Icon(Icons.add, size: 28),
                    label: const Text('Create New Simulation', style: TextStyle(fontSize: 18)),
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

// Play and Builder classes (unchanged except for type safety)
class FieldSimulationPlayScreen extends StatefulWidget {
  final Map<String, dynamic> payload;
  final String classId;

  const FieldSimulationPlayScreen({super.key, required this.payload, required this.classId});

  @override
  State<FieldSimulationPlayScreen> createState() => _FieldSimulationPlayScreenState();
}

class _FieldSimulationPlayScreenState extends State<FieldSimulationPlayScreen> {
  int _step = 0;
  int? _sel;
  bool _show = false;
  late final ConfettiController _conf = ConfettiController(duration: const Duration(seconds: 2));

  void _submit() {
    if (_sel == null) return;
    final s = widget.payload['steps'][_step];
    final correct = (s['options'] as List).indexWhere((o) => o['correct'] == true);
    if (_sel == correct) {
      _conf.play();
      if (_step < widget.payload['steps'].length - 1) {
        setState(() { _step++; _sel = null; _show = false; });
      } else {
        _complete();
      }
    } else {
      setState(() => _show = true);
    }
  }

  Future<void> _complete() async {
    final coll = FirestoreHelper.getSubmissionsFromClassId(widget.classId);
    if (coll != null) {
      await coll.add({
        'type': 'simulation',
        'simulationId': widget.payload['id'],
        'title': widget.payload['title'],
        'completed': true,
        'userId': FirebaseAuth.instance.currentUser!.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Simulation Complete!'),
          content: const Text('Well done! Your submission has been saved.'),
          actions: [TextButton(onPressed: () => Navigator.popUntil(context, (r) => r.isFirst), child: const Text('Done'))],
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
    final s = widget.payload['steps'][_step];
    return Scaffold(
      appBar: AppBar(title: Text(widget.payload['title']), backgroundColor: primaryGreen, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ConfettiWidget(confettiController: _conf, blastDirectionality: BlastDirectionality.explosive),
            const SizedBox(height: 30),
            Text(s['prompt'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 40),
            ...(s['options'] as List).asMap().entries.map((e) => RadioListTile<int>(
                  value: e.key,
                  groupValue: _sel,
                  onChanged: (v) => setState(() => _sel = v),
                  title: Text(e.value['text']),
                  activeColor: primaryGreen,
                )),
            if (_show)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Text(s['explanation']?.isNotEmpty == true ? s['explanation'] : 'Try again!', style: const TextStyle(color: Colors.red)),
                ),
              ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, minimumSize: const Size(double.infinity, 56)),
              child: const Text('Submit Choice', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class FieldSimulationBuilderDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;
  const FieldSimulationBuilderDialog({super.key, required this.onSave});

  @override
  State<FieldSimulationBuilderDialog> createState() => _FieldSimulationBuilderDialogState();
}

class _FieldSimulationBuilderDialogState extends State<FieldSimulationBuilderDialog> {
  final _titleCtrl = TextEditingController();
  final List<Map<String, dynamic>> _steps = [];

  void _addStep() {
    final promptCtrl = TextEditingController();
    final optionCtrls = List.generate(4, (_) => TextEditingController());
    int correctIndex = 0;
    final explanationCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Step'),
        content: StatefulBuilder(
          builder: (context, setStateInner) => SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: promptCtrl, decoration: const InputDecoration(labelText: 'Situation / Prompt')),
              const SizedBox(height: 12),
              ...optionCtrls.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Checkbox(value: correctIndex == e.key, onChanged: (v) => setStateInner(() => correctIndex = e.key)),
                      Expanded(child: TextField(controller: e.value, decoration: InputDecoration(labelText: 'Option ${e.key + 1}'))),
                    ]),
                  )),
              const SizedBox(height: 12),
              TextField(controller: explanationCtrl, decoration: const InputDecoration(labelText: 'Explanation if wrong (optional)'), maxLines: 3),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
            onPressed: () {
              final filled = optionCtrls.where((c) => c.text.trim().isNotEmpty).toList();
              if (promptCtrl.text.trim().isEmpty || filled.isEmpty) return;
              final options = filled.map((c) => {'text': c.text.trim(), 'correct': filled.indexOf(c) == correctIndex}).toList();
              setState(() => _steps.add({'prompt': promptCtrl.text.trim(), 'options': options, 'explanation': explanationCtrl.text.trim()}));
              Navigator.pop(context);
            },
            child: const Text('Add Step', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Create Field Simulation'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Simulation Title (optional)')),
            const SizedBox(height: 16),
            ElevatedButton.icon(onPressed: _addStep, icon: const Icon(Icons.add), label: const Text('Add Step')),
            const SizedBox(height: 16),
            ..._steps.asMap().entries.map((e) {
              final s = e.value;
              final correctOpt = (s['options'] as List).firstWhere((o) => o['correct'] == true, orElse: () => {'text': 'None'});
              final letter = String.fromCharCode(65 + (s['options'] as List).indexOf(correctOpt));
              return Card(
                child: ListTile(
                  title: Text(s['prompt']),
                  subtitle: Text('Correct: $letter. ${correctOpt['text']}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () => setState(() => _steps.removeAt(e.key))),
                ),
              );
            }),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
            onPressed: _steps.isEmpty ? null : () {
              widget.onSave({'title': _titleCtrl.text.trim().isEmpty ? 'Field Simulation' : _titleCtrl.text.trim(), 'steps': _steps});
              Navigator.pop(context);
            },
            child: const Text('Save Simulation', style: TextStyle(color: Colors.white)),
          ),
        ],
      );
}