// lib/education/education_farming_tips.dart
// ignore_for_file: use_build_context_synchronously, deprecated_member_use, unused_element

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:kilimomkononi/utils/firestore_helper.dart';
import '../utils/class_id_notifier.dart';
import '../models/education_user.dart';
import 'simulations/farm_planting_simulation.dart';
import 'quiz/shared_quiz_widgets.dart';

const Color primaryGreen = Color(0xFF032704);

extension StringExt on String {
  String capitalize() =>
      isNotEmpty ? '${this[0].toUpperCase()}${substring(1)}' : this;
}

extension TextEditingControllerExt on TextEditingController {
  String get safeText => text.trim();
}

class EducationFarmingTips extends StatefulWidget {
  final EduRole role;
  final String  schoolName;
  final String  classId;

  const EducationFarmingTips({
    super.key,
    required this.role,
    required this.schoolName,
    required this.classId,
  });

  @override
  State<EducationFarmingTips> createState() => _EducationFarmingTipsState();
}

class _EducationFarmingTipsState extends State<EducationFarmingTips> {
  late String _schoolId;
  late String _gradeId;
  final String _contentType = 'farming_content';
  late Future<Map<String, dynamic>> _tipsFuture;
  final Map<String, bool> _expandedCrops = {};
  String? _selectedCrop;

  bool get _isPrimary {
    if (widget.classId.contains('cbcPrimary')) return true;
    final match = RegExp(r'_(\d+)$').firstMatch(widget.classId);
    return match != null && (int.tryParse(match.group(1)!) ?? 7) <= 6;
  }

  String get _gradeLabel {
    final match = RegExp(r'_(\d+)$').firstMatch(widget.classId);
    if (match != null) {
      final n = match.group(1)!;
      if (widget.classId.contains('eightfourfour')) {
        final num = int.tryParse(n) ?? 1;
        return num <= 8 ? 'Standard $n' : 'Form ${num - 8}';
      }
      return 'Grade $n';
    }
    return widget.classId;
  }

  @override
  void initState() {
    super.initState();
    final match = RegExp(r'^(.*)_(\d+)$').firstMatch(widget.classId);
    if (match != null) {
      _schoolId = match.group(1)!;
      _gradeId  = match.group(2)!;
      classIdNotifier.value = widget.classId;
    }
    _tipsFuture = rootBundle
        .loadString('assets/farming_tips/farming_tips.json')
        .then((s) => json.decode(s) as Map<String, dynamic>);
  }

  void _showQuizBuilder() => showDialog(
        context: context,
        builder: (_) => EduQuizBuilder(
          onSave:        (d) => _save('quiz', d),
          topicLabel:    (_selectedCrop ?? 'Crop').capitalize(),
          geminiSubject: '${_selectedCrop ?? 'crop'} farming in Kenya',
          grade:         _gradeLabel,
          isPrimary:     _isPrimary,
        ),
      );

  void _showSimBuilder() {
    if (_selectedCrop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please expand a crop first')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FarmPlantingSimulation(
          classId: widget.classId,
          module: 'Farming Tips',
          studentName: FirebaseAuth.instance.currentUser!.displayName ?? 'Unknown',
          cropName: _selectedCrop!,
          cropData: {
            'schoolId': _schoolId,
            'gradeId':  _gradeId,
            'classId':  widget.classId,
          },
          onComplete: () {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$_selectedCrop simulation completed!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Future<void> _save(String type, Map<String, dynamic> data) async {
    if (_selectedCrop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please expand a crop first')),
      );
      return;
    }
    final String title = data['title'] as String? ?? '$_selectedCrop ${type.capitalize()}';
    await FirestoreHelper.ensureGradeExists(widget.classId);
    final collection = FirestoreHelper.getContentFromClassId(widget.classId, _contentType);
    if (collection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid class configuration')),
      );
      return;
    }
    try {
      await collection.add({
        'type':      type,
        'title':     title,
        'crop':      _selectedCrop,
        'data':      jsonEncode(type == 'quiz' ? data['questions'] : data['steps']),
        'createdAt': FieldValue.serverTimestamp(),
        'userId':    FirebaseAuth.instance.currentUser!.uid,
        'schoolId':  _schoolId,
        'gradeId':   _gradeId,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title saved!'), backgroundColor: Colors.green),
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

  // ── Launch a quiz or simulation from Firestore ───────────────────────────

  Future<void> _launchContent(String type, String docId, {bool essayOnly = false}) async {
    final rawCollection = FirestoreHelper.getContentFromClassId(widget.classId, _contentType);
    if (rawCollection == null) return;
    try {
      final doc    = await rawCollection.doc(docId).get();
      final dataMap = doc.data() as Map<String, dynamic>?;
      if (dataMap == null) return;

      final title = dataMap['title'] is String &&
              (dataMap['title'] as String).trim().isNotEmpty
          ? (dataMap['title'] as String).trim()
          : '$_selectedCrop ${type.capitalize()}';

      final allQuestions = jsonDecode(dataMap['data'] as String) as List;

      // Filter to MCQ or essay questions based on which button was tapped
      final questions = essayOnly
          ? allQuestions.where((q) => (q as Map<String, dynamic>)['type'] == 'essay').toList()
          : allQuestions.where((q) => (q as Map<String, dynamic>)['type'] != 'essay').toList();

      if (type == 'quiz') {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EduQuizScreen(
              payload: {
                'id':        docId,
                'title':     title,
                'crop':      _selectedCrop,
                'grade':     _gradeLabel,
                'questions': questions,
                'module':    'Farming Tips',
              },
              classId:       widget.classId,
              isPrimary:     _isPrimary,
              geminiSubject: '${_selectedCrop ?? 'crop'} farming in Kenya',
            ),
          ),
        );
      } else {
        final fullPayload = {
          'id':    docId,
          'title': title,
          'crop':  _selectedCrop,
          'grade': _gradeLabel,
          'steps': allQuestions,
        };
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FarmingSimulationScreen(payload: fullPayload, classId: widget.classId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7)  return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildImage(String assetPath, double maxHeight) {
    final fullPath = 'assets/$assetPath';
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: maxHeight),
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            fullPath,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, error, _) => Container(
              height: 180,
              color: Colors.grey[200],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text('Image not found: $fullPath', style: const TextStyle(color: Colors.grey)),
                  Text('Error: $error', style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _markdownCard(String text) => Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: MarkdownBody(
            data: text,
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(fontSize: 15.5, height: 1.6),
              listBullet: const TextStyle(fontSize: 15.5),
            ),
          ),
        ),
      );

  // ── Separate quiz / essay buttons ────────────────────────────────────────

  Widget _buildQuizSection() {
    final raw = FirestoreHelper.getContentFromClassId(widget.classId, _contentType);
    if (raw == null || _selectedCrop == null) {
      return _SplitActivityButtons(
        mcqCount:   0,
        essayCount: 0,
        onMcqTap:   null,
        onEssayTap: null,
      );
    }

    final coll = raw.withConverter<Map<String, dynamic>>(
      fromFirestore: (s, _) => s.data()!,
      toFirestore:   (d, _) => d,
    );

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: coll
          .where('type', isEqualTo: 'quiz')
          .where('crop', isEqualTo: _selectedCrop)
          .snapshots(),
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
          onMcqTap:   mcqDocs   == 0 ? null : () => _showActivityList('quiz', essayOnly: false),
          onEssayTap: essayDocs == 0 ? null : () => _showActivityList('quiz', essayOnly: true),
        );
      },
    );
  }

  void _showActivityList(String type, {bool essayOnly = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize:     0.95,
        minChildSize:     0.6,
        expand: false,
        builder: (_, controller) =>
            _buildContentList(type, scrollController: controller, essayOnly: essayOnly),
      ),
    );
  }

  Widget _buildContentList(String type,
      {ScrollController? scrollController, bool essayOnly = false}) {
    final rawCollection = FirestoreHelper.getContentFromClassId(widget.classId, _contentType);
    if (rawCollection == null) return const Center(child: Text('Invalid configuration'));

    final collection = rawCollection.withConverter<Map<String, dynamic>>(
      fromFirestore: (s, _) => s.data()!,
      toFirestore:   (d, _) => d,
    );

    final sheetTitle = essayOnly
        ? 'Essay assignments — $_selectedCrop'
        : 'Quizzes — $_selectedCrop';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Icon(essayOnly ? Icons.edit_note : Icons.check_circle_outline,
                color: essayOnly ? Colors.purple : Colors.blue, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(sheetTitle,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryGreen)),
            ),
          ]),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: collection
                .where('type', isEqualTo: type)
                .where('crop', isEqualTo: _selectedCrop)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: primaryGreen));
              }

              final allDocs = snapshot.data?.docs ?? [];
              // Filter client-side by question type
              final filteredDocs = allDocs.where((doc) {
                final data = doc.data();
                List<dynamic> qs = [];
                try {
                  final raw = data['data'];
                  qs = raw is String ? (jsonDecode(raw) as List? ?? []) : (raw as List? ?? []);
                } catch (_) {}
                return essayOnly
                    ? qs.any((q) => (q as Map<String, dynamic>?)!['type'] == 'essay')
                    : qs.any((q) => (q as Map<String, dynamic>?)!['type'] != 'essay');
              }).toList();

              if (filteredDocs.isEmpty) {
                return Center(
                  child: Text(
                    essayOnly ? 'No essay assignments yet' : 'No quizzes yet',
                    style: const TextStyle(fontSize: 18, fontStyle: FontStyle.italic, color: Colors.grey),
                  ),
                );
              }

              final userId        = FirebaseAuth.instance.currentUser!.uid;
              final submissionsColl = FirestoreHelper.getSubmissionsFromClassId(widget.classId);

              return FutureBuilder<Set<String>>(
                future: submissionsColl == null
                    ? Future.value(<String>{})
                    : submissionsColl
                        .where('userId', isEqualTo: userId)
                        .where('type', isEqualTo: type)
                        .get()
                        .then((s) => s.docs
                            .map((d) {
                              final data = d.data();
                              if (data is Map<String, dynamic>) return data['${type}Id'] as String?;
                              return null;
                            })
                            .whereType<String>()
                            .toSet()),
                builder: (context, completedSnap) {
                  final completedIds = completedSnap.data ?? <String>{};
                  final isTeacher    = widget.role == EduRole.teacher;
                  final availableDocs = isTeacher
                      ? filteredDocs
                      : filteredDocs.where((doc) => !completedIds.contains(doc.id)).toList();

                  if (availableDocs.isEmpty) {
                    return Center(
                      child: Text(
                        isTeacher ? 'None created yet' : 'All completed! Great job! 🎉',
                        style: const TextStyle(fontSize: 18),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: availableDocs.length,
                    itemBuilder: (context, index) {
                      final doc       = availableDocs[index];
                      final data      = doc.data();
                      final title     = data['title'] as String? ?? 'Untitled';
                      final createdAt = data['createdAt'] as Timestamp?;

                      return Card(
                        margin:    const EdgeInsets.only(bottom: 12),
                        elevation: 4,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: essayOnly ? Colors.purple : Colors.blue,
                            child: Icon(
                              essayOnly ? Icons.edit_note : Icons.quiz,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(title,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: createdAt != null
                              ? Text('Created: ${_formatDate(createdAt.toDate())}')
                              : null,
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            Navigator.pop(context);
                            _launchContent(type, doc.id, essayOnly: essayOnly);
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

  @override
  Widget build(BuildContext context) {
    final double width       = MediaQuery.of(context).size.width;
    final double imageHeight = width > 1000 ? 400.0 : width > 600 ? 320.0 : 260.0;
    final bool   isMobile    = width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Farming Tips'),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 4,
        automaticallyImplyLeading: false,
        leading: isMobile
            ? IconButton(
                icon:     const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _tipsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: primaryGreen));

          final tipsData = snapshot.data!;
          return ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: width > 1000 ? 64 : 16, vertical: 16),
            itemCount: tipsData.keys.length,
            itemBuilder: (context, index) {
              final cropKey   = tipsData.keys.elementAt(index);
              final crop      = tipsData[cropKey] as Map<String, dynamic>;
              final isExpanded = _expandedCrops[cropKey] ?? false;

              return Card(
                margin:    const EdgeInsets.only(bottom: 16),
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ExpansionTile(
                  initiallyExpanded: isExpanded,
                  onExpansionChanged: (expanded) {
                    setState(() {
                      _expandedCrops[cropKey] = expanded;
                      _selectedCrop = expanded ? cropKey : (_selectedCrop == cropKey ? null : _selectedCrop);
                    });
                  },
                  leading: CircleAvatar(
                    backgroundColor: primaryGreen.withValues(alpha: 0.15),
                    child: Text(crop['icon'] ?? '🌱', style: const TextStyle(fontSize: 32)),
                  ),
                  title: Text(
                    cropKey.capitalize(),
                    style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: primaryGreen),
                  ),
                  childrenPadding: EdgeInsets.symmetric(
                      horizontal: width > 800 ? 32 : 20, vertical: 12),
                  children: [
                    // ── Practice Activities card ────────────────────────────
                    if (widget.role != EduRole.headteacher && isExpanded)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Card(
                          color:     Colors.green.shade50,
                          elevation: 6,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: primaryGreen, width: 2),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Icon(Icons.assignment_turned_in, size: 28, color: primaryGreen),
                                  const SizedBox(width: 10),
                                  Text('Practice Activities',
                                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryGreen)),
                                ]),
                                const SizedBox(height: 6),
                                Text('Test your knowledge on $_selectedCrop!',
                                    style: const TextStyle(fontSize: 14, color: Colors.black54)),
                                const SizedBox(height: 14),
                                _buildQuizSection(),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Row(children: [
                                    const Expanded(child: Divider(thickness: 1)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      child: Text('or try',
                                          style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                                    ),
                                    const Expanded(child: Divider(thickness: 1)),
                                  ]),
                                ),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: _selectedCrop == null ? null : _showSimBuilder,
                                    icon: const Icon(Icons.play_circle_outline, size: 22),
                                    label: const Text('Run Interactive Simulation',
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: primaryGreen,
                                      side: const BorderSide(color: primaryGreen, width: 1.5),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // ── Content sections ────────────────────────────────────
                    if (crop['general'] != null) ...[
                      const Text('General Tips',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryGreen)),
                      const SizedBox(height: 12),
                      if (crop['image_general'] != null)
                        _buildImage(crop['image_general'] as String, imageHeight),
                      const SizedBox(height: 12),
                      _markdownCard(crop['general'] as String),
                      const Divider(height: 40),
                    ],
                    if (crop['stages'] != null) ...[
                      const Text('Growth Stages',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryGreen)),
                      const SizedBox(height: 16),
                      ...(crop['stages'] as Map<String, dynamic>).entries.map((e) {
                        final stageName = e.key;
                        final value     = e.value as Map<String, dynamic>;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(stageName,
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: primaryGreen)),
                              const SizedBox(height: 10),
                              if (value['image'] != null) _buildImage(value['image'] as String, imageHeight * 0.9),
                              const SizedBox(height: 12),
                              _markdownCard(value['tips'] as String),
                            ],
                          ),
                        );
                      }),
                      const Divider(height: 40),
                    ],
                    if (crop['varieties'] != null) ...[
                      const Text('Popular Varieties in Kenya',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryGreen)),
                      const SizedBox(height: 16),
                      ...(crop['varieties'] as Map<String, dynamic>).entries.map((e) {
                        final name    = e.key;
                        final v       = e.value as Map<String, dynamic>;
                        final bestFor = v['best_for'] as String? ?? '';
                        final tips    = v['tips'] as String? ?? '';
                        final image   = v['image'] as String?;
                        return Card(
                          color:  Colors.green.shade50,
                          shape:  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ExpansionTile(
                            title:    Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: bestFor.isNotEmpty
                                ? Text('Best for: $bestFor', style: const TextStyle(color: Colors.green))
                                : null,
                            children: [
                              if (image != null)
                                Padding(padding: const EdgeInsets.all(16), child: _buildImage(image, imageHeight)),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                child: _markdownCard(tips),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 12),
                  ],
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: (widget.role == EduRole.headteacher || widget.role == EduRole.student)
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              color:   Colors.grey[50],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: _selectedCrop == null ? null : _showQuizBuilder,
                    icon:  const Icon(Icons.auto_awesome, color: Colors.amber),
                    label: Text('Create ${_selectedCrop ?? ''} Quiz with AI'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TeacherEssayReviewScreen(
                          classId:    widget.classId,
                          schoolName: widget.schoolName,
                        ),
                      ),
                    ),
                    icon:  const Icon(Icons.rate_review_outlined),
                    label: const Text('Review essay submissions'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryGreen,
                      side: const BorderSide(color: primaryGreen),
                      minimumSize: const Size(double.infinity, 44),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ─── Shared split-button widget used by all 3 content modules ───────────────

class _SplitActivityButtons extends StatelessWidget {
  final int         mcqCount;
  final int         essayCount;
  final VoidCallback? onMcqTap;
  final VoidCallback? onEssayTap;

  const _SplitActivityButtons({
    required this.mcqCount,
    required this.essayCount,
    required this.onMcqTap,
    required this.onEssayTap,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _btn(
            icon:    Icons.check_circle_outline,
            label:   'Quizzes',
            count:   mcqCount,
            color:   Colors.blue.shade600,
            bgColor: Colors.blue.shade50,
            onTap:   onMcqTap,
          ),
          const SizedBox(height: 8),
          _btn(
            icon:    Icons.edit_note,
            label:   'Essay assignments',
            count:   essayCount,
            color:   Colors.purple.shade600,
            bgColor: Colors.purple.shade50,
            onTap:   onEssayTap,
          ),
        ],
      );

  Widget _btn({
    required IconData    icon,
    required String      label,
    required int         count,
    required Color       color,
    required Color       bgColor,
    required VoidCallback? onTap,
  }) =>
      InkWell(
        onTap:         onTap,
        borderRadius:  BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color:        onTap == null ? Colors.grey.shade100 : bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: onTap == null
                    ? Colors.grey.shade300
                    : color.withOpacity(0.35)),
          ),
          child: Row(children: [
            Icon(icon, color: onTap == null ? Colors.grey : color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize:   14,
                      color: onTap == null ? Colors.grey : color)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color:        onTap == null
                    ? Colors.grey.shade200
                    : color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                count == 0 ? 'None yet' : '$count available',
                style: TextStyle(
                    fontSize:   11,
                    fontWeight: FontWeight.w600,
                    color: onTap == null ? Colors.grey.shade500 : color),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_ios,
                size:  13,
                color: onTap == null ? Colors.grey.shade300 : color.withOpacity(0.6)),
          ]),
        ),
      );
}

// ─── Farming simulation screen (unchanged from original) ────────────────────

class FarmingSimulationScreen extends StatefulWidget {
  final Map<String, dynamic> payload;
  final String classId;
  const FarmingSimulationScreen({super.key, required this.payload, required this.classId});
  @override
  State<FarmingSimulationScreen> createState() => _FarmingSimulationScreenState();
}

class _FarmingSimulationScreenState extends State<FarmingSimulationScreen> {
  int  _step = 0;
  int? _sel;
  bool _show = false;

  void _submit() {
    if (_sel == null) return;
    final s       = widget.payload['steps'][_step];
    final correct = (s['options'] as List).indexWhere((o) => o['correct'] == true);
    if (_sel == correct) {
      if (_step < widget.payload['steps'].length - 1) {
        setState(() { _step++; _sel = null; _show = false; });
      } else {
        _submitSimulation();
      }
    } else {
      setState(() => _show = true);
    }
  }

  Future<void> _submitSimulation() async {
    final coll = FirestoreHelper.getSubmissionsFromClassId(widget.classId);
    if (coll != null) {
      await coll.add({
        'type':         'simulation',
        'simulationId': widget.payload['id'],
        'crop':         widget.payload['crop'],
        'title':        widget.payload['title'],
        'completed':    true,
        'userId':       FirebaseAuth.instance.currentUser!.uid,
        'createdAt':    FieldValue.serverTimestamp(),
      });
    }
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title:   Text('${widget.payload['crop']} Simulation Complete!'),
          content: const Text('Excellent! Your submission has been saved!'),
          actions: [
            TextButton(
                onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                child: const Text('Done'))
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.payload['steps'][_step];
    return Scaffold(
      appBar: AppBar(
          title: Text('${widget.payload['crop']} Simulation'),
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          const SizedBox(height: 30),
          Text(s['prompt'],
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 40),
          ...(s['options'] as List).asMap().entries.map((e) => RadioListTile<int>(
                value:       e.key,
                groupValue:  _sel,
                onChanged:   (v) => setState(() => _sel = v),
                title:       Text(e.value['text']),
                activeColor: primaryGreen,
              )),
          if (_show)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                child: Text(s['explanation']?.isNotEmpty == true ? s['explanation'] : 'Try again!',
                    style: const TextStyle(color: Colors.red)),
              ),
            ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56)),
            child: const Text('Submit Choice', style: TextStyle(fontSize: 18)),
          ),
        ]),
      ),
    );
  }
}