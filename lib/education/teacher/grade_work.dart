/*// lib/education/teacher/grade_work.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kilimomkononi/education/utils/class_id_notifier.dart';
import 'package:kilimomkononi/education/utils/education_utils.dart';

class GradeWorkScreen extends StatefulWidget {
  const GradeWorkScreen({super.key});

  @override
  State<GradeWorkScreen> createState() => _GradeWorkScreenState();
}

class _GradeWorkScreenState extends State<GradeWorkScreen> {
  final Map<String, Map<String, dynamic>> _contentCache = {};
  String? _currentSchoolName;

  @override
  void initState() {
    super.initState();
    classIdNotifier.addListener(_refresh);
    _refresh();
  }

  @override
  void dispose() {
    classIdNotifier.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() async {
  final classId = classIdNotifier.value;
  if (classId == null) {
    setState(() => _contentCache.clear());
    return;
  }

  // ---- FIXED ----
  final (schoolId, gradeId, _) = parseClassIdAndModule(classId, 'farming');
  final String parsedSchoolId = schoolId as String;   // explicit cast
  final String parsedGradeId = gradeId as String;

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final userDoc = await FirebaseFirestore.instance
      .collection('EducationUsers')
      .doc(user.uid)
      .get();

  final schoolName = userDoc['schoolName'] as String?;
  if (schoolName == null) return;

  setState(() => _currentSchoolName = schoolName);

  await _loadContentCache(parsedSchoolId, parsedGradeId);
}

  Future<void> _loadContentCache(String schoolId, String gradeId) async {
    final collections = [
      'farming_content',
      'market_content',
      'weather_content',
      'farm_management_content',
    ];
    final Map<String, Map<String, dynamic>> cache = {};

    for (final coll in collections) {
      final snap = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('grades')
          .doc(gradeId)
          .collection(coll)
          .where('type', whereIn: ['quiz', 'simulation'])
          .get();

      for (final doc in snap.docs) {
        final data = doc.data();
        final title = _extractTitle(data, coll);
        cache[doc.id] = {
          'title': title,
          'module': _moduleName(coll),
          'type': data['type'],
        };
      }
    }

    if (mounted) {
      setState(() => _contentCache
        ..clear()
        ..addAll(cache));
    }
  }

  String _extractTitle(Map<String, dynamic> data, String coll) {
    final jsonData = data['data'] as String?;
    if (jsonData == null) return 'Untitled';

    try {
      final parsed = json.decode(jsonData);
      if (parsed is List && parsed.isNotEmpty) {
        return (parsed[0] as Map)['q']?.toString() ?? 'Untitled Quiz';
      } else if (parsed is Map) {
        return (parsed['title'] as String?) ?? 'Untitled Simulation';
      }
    } catch (e) {
      debugPrint('JSON parse error: $e');
    }
    return 'Untitled';
  }

  String _moduleName(String coll) {
    return switch (coll) {
      'farming_content' => 'Farming Tips',
      'market_content' => 'Market Price',
      'weather_content' => 'Weather Forecast',
      'farm_management_content' => 'Farm Management',
      _ => coll,
    };
  }

  // -----------------------------------------------------------------
  // UI (unchanged – only the parsing above was fixed)
  // -----------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (_currentSchoolName == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grade Work'),
        backgroundColor: const Color.fromARGB(255, 3, 39, 4),
        foregroundColor: Colors.white,
      ),
      body: _contentCache.isEmpty
          ? const Center(child: Text('Select a class to view submissions'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('submissions')
                  .where('module', whereIn: [
                    'farming_content',
                    'market_content',
                    'weather_content',
                    'farm_management_content',
                  ])
                  .snapshots(),
              builder: (ctx, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No submissions yet'));
                }

                final docs = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    final sub = docs[i].data() as Map<String, dynamic>;
                    final contentInfo = _contentCache[sub['contentId']];
                    if (contentInfo == null) return const SizedBox.shrink();

                    final title = contentInfo['title'] ?? 'Unknown';
                    final module = contentInfo['module'] ?? '';
                    final type = contentInfo['type'] ?? '';
                    final score = sub['score'] as int?;

                    return Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal.shade100,
                          child: Text((sub['studentName'] as String?)
                                  ?.isNotEmpty ==
                              true
                              ? sub['studentName'][0]
                              : '?'),
                        ),
                        title: Text('${sub['studentName']} – $title'),
                        subtitle: Text(
                            '$module • ${type.capitalize()} • ${timeAgo(sub['submittedAt'])}'),
                        trailing: score == null
                            ? ElevatedButton(
                                onPressed: () => _showGradingDialog(
                                    context, docs[i].reference, sub),
                                child: const Text('Grade'),
                              )
                            : Chip(
                                label: Text('Score: $score',
                                    style:
                                        const TextStyle(color: Colors.white)),
                                backgroundColor: Colors.green,
                              ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  void _showGradingDialog(
      BuildContext context, DocumentReference ref, Map<String, dynamic> sub) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Score'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: '0 – 100'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final raw = controller.text.trim();
              if (raw.isEmpty) return;
              final score = int.tryParse(raw);
              if (score == null || score < 0 || score > 100) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a number 0-100')),
                );
                return;
              }
              await ref.update({
                'score': score,
                'gradedBy': FirebaseAuth.instance.currentUser!.uid,
                'gradedAt': FieldValue.serverTimestamp(),
              });
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String timeAgo(Timestamp? ts) {
    if (ts == null) return 'unknown';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

extension StringX on String {
  String capitalize() =>
      isEmpty ? this : this[0].toUpperCase() + substring(1);
}*/