// lib/education/education_market_price.dart

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:kilimomkononi/utils/firestore_helper.dart';
import '../models/education_user.dart';
import 'simulations/market_trading_simulation.dart';
import 'quiz/shared_quiz_widgets.dart';

const Color primaryGreen = Color(0xFF003900);

extension StringExt on String {
  String capitalize() =>
      isNotEmpty ? '${this[0].toUpperCase()}${substring(1)}' : this;
}

extension TextEditingControllerExt on TextEditingController {
  String get safeText => text.trim();
}

class EducationMarketPrice extends StatefulWidget {
  final EduRole role;
  final String  schoolName;
  final String  classId;

  const EducationMarketPrice({
    super.key,
    required this.role,
    required this.schoolName,
    required this.classId,
  });

  @override
  State<EducationMarketPrice> createState() =>
      _EducationMarketPriceState();
}

class _EducationMarketPriceState
    extends State<EducationMarketPrice> {
  final String _contentType = 'market_content';
  final String _system      = 'cbcJunior';

  List<Map<String, dynamic>> _topics      = [];
  Map<String, dynamic>?      _selectedTopic;
  bool                       _loading     = true;

  // ── Grade helpers ────────────────────────────────────────────────

  bool get _isPrimary {
    if (widget.classId.contains('cbcPrimary')) return true;
    final match = RegExp(r'_(\d+)$').firstMatch(widget.classId);
    if (match != null) {
      return (int.tryParse(match.group(1)!) ?? 7) <= 6;
    }
    return false;
  }

  String get _gradeLabel {
    final match =
        RegExp(r'_(\d+)$').firstMatch(widget.classId);
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

  String get _topicTitle =>
      _selectedTopic?['title'] as String? ?? 'Market Topic';

  /// Subject string passed to Gemini — more descriptive than just the title.
  String get _geminiSubject =>
      '${_topicTitle.toLowerCase()} in Kenyan agricultural markets';

  @override
  void initState() {
    super.initState();
    _loadMarketContent();
  }

  Future<void> _loadMarketContent() async {
    try {
      final String jsonString = await rootBundle
          .loadString('assets/market_tips/market_tips.json');
      final Map<String, dynamic> data =
          json.decode(jsonString);

      setState(() {
        _topics = List<Map<String, dynamic>>.from(
            data[_system] ?? []);
        _selectedTopic =
            _topics.isNotEmpty ? _topics[0] : null;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading content: $e')),
        );
      }
    }
  }

  // ── Quiz builder ─────────────────────────────────────────────────

  void _showQuizBuilder() {
    if (_selectedTopic == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a topic first')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (_) => EduQuizBuilder(
        onSave:        (d) => _saveContent('quiz', d),
        topicLabel:    _topicTitle,
        geminiSubject: _geminiSubject,
        grade:         _gradeLabel,
        isPrimary:     _isPrimary,
      ),
    );
  }

  void _showSimBuilder() {
    if (_selectedTopic == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a topic first')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MarketTradingSimulation(
          topic: _topicTitle,
          classId: widget.classId,
          module: 'Market Price',
          studentName:
              FirebaseAuth.instance.currentUser?.displayName ??
                  'Student',
          onComplete: () {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('$_topicTitle simulation completed!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
        ),
      ),
    );
  }

  IconData _parseIconData(String iconString) {
    final map = {
      'Icons.store':         Icons.store,
      'Icons.swap_horiz':    Icons.swap_horiz,
      'Icons.attach_money':  Icons.attach_money,
      'Icons.savings':       Icons.savings,
      'Icons.storefront':    Icons.storefront,
      'Icons.balance':       Icons.balance,
      'Icons.inventory_2':   Icons.inventory_2,
      'Icons.receipt_long':  Icons.receipt_long,
      'Icons.trending_up':   Icons.trending_up,
      'Icons.price_check':   Icons.price_check,
      'Icons.groups':        Icons.groups,
      'Icons.phone_android': Icons.phone_android,
      'Icons.flight_takeoff': Icons.flight_takeoff,
    };
    return map[iconString] ?? Icons.help_outline;
  }

  Widget _buildImage(String assetPath, double maxHeight) {
    final fullPath = 'assets/$assetPath';
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: maxHeight),
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            fullPath,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, error, _) => Container(
              height: 200,
              color: Colors.grey[200],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.broken_image,
                      size: 48, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text('Image not found: $fullPath',
                      style:
                          const TextStyle(color: Colors.grey)),
                  Text('Error: $error',
                      style: const TextStyle(
                          color: Colors.red, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _keyPointsCard(List<String> points) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Key Learning Points',
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: primaryGreen)),
            const SizedBox(height: 12),
            ...points.map((point) => Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(point,
                              style: const TextStyle(
                                  fontSize: 16, height: 1.5))),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _markdownCard(String text) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: MarkdownBody(
          data: text,
          styleSheet: MarkdownStyleSheet(
            p: const TextStyle(fontSize: 16.5, height: 1.7),
            listBullet: const TextStyle(
                fontSize: 16.5, color: primaryGreen),
            strong: const TextStyle(
                fontWeight: FontWeight.bold,
                color: primaryGreen),
            h1: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
                color: primaryGreen),
            h2: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: primaryGreen),
            blockquote: TextStyle(
                color: Colors.brown.shade700,
                fontStyle: FontStyle.italic),
          ),
        ),
      ),
    );
  }

  Future<void> _saveContent(
      String type, Map<String, dynamic> data) async {
    if (_selectedTopic == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a topic first')),
      );
      return;
    }

    final String title = data['title'] as String? ??
        '$_topicTitle ${type.capitalize()}';

    await FirestoreHelper.ensureGradeExists(widget.classId);
    if (!mounted) return;
    final collection = FirestoreHelper.getContentFromClassId(
        widget.classId, _contentType);
    if (collection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Invalid class configuration')),
      );
      return;
    }

    try {
      await collection.add({
        'type':      type,
        'title':     title,
        'topic':     _topicTitle,
        'data':      jsonEncode(type == 'quiz'
            ? data['questions']
            : data['steps']),
        'createdAt': FieldValue.serverTimestamp(),
        'userId':
            FirebaseAuth.instance.currentUser!.uid,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('$title saved successfully!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to save: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _launchContent(
      String type, String docId, {bool essayOnly = false}) async {
    final rawCollection = FirestoreHelper.getContentFromClassId(
        widget.classId, _contentType);
    if (rawCollection == null) return;

    try {
      final doc    = await rawCollection.doc(docId).get();
      if (!mounted) return;
      final dataMap =
          doc.data() as Map<String, dynamic>?;

      if (dataMap == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to load content')),
        );
        return;
      }

      final String title = dataMap['title'] is String &&
              (dataMap['title'] as String).trim().isNotEmpty
          ? (dataMap['title'] as String).trim()
          : '${dataMap['topic']} ${type.capitalize()}';

      final allQuestions = jsonDecode(dataMap['data'] as String) as List;
      final questions = essayOnly
          ? allQuestions.where((q) => (q as Map<String, dynamic>)['type'] == 'essay').toList()
          : allQuestions.where((q) => (q as Map<String, dynamic>)['type'] != 'essay').toList();

      final fullPayload = {
        'id':        doc.id,
        'title':     title,
        'topic':     dataMap['topic'],
        'grade':     _gradeLabel,
        'questions': questions,
        'module':    'Market Price',
      };

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EduQuizScreen(
              payload:       fullPayload,
              classId:       widget.classId,
              isPrimary:     _isPrimary,
              geminiSubject: _geminiSubject,
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

  String _formatDate(DateTime date) {
    final now  = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7)  return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final double imageHeight =
        width > 1000 ? 400.0 : width > 600 ? 340.0 : 280.0;
    final bool isMobile = width < 600;

    if (_loading) {
      return const Scaffold(
        body: Center(
            child: CircularProgressIndicator(
                color: primaryGreen)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Market & Pricing'),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 4,
        automaticallyImplyLeading: false,
        leading: isMobile
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: ListView.builder(
        padding: EdgeInsets.symmetric(
            horizontal: width > 1000 ? 64 : 16,
            vertical: 16),
        itemCount: _topics.length,
        itemBuilder: (context, index) {
          final topic      = _topics[index];
          final bool isExpanded =
              _selectedTopic == topic;

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 8,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: ExpansionTile(
              initiallyExpanded: isExpanded,
              onExpansionChanged: (expanded) {
                setState(() {
                  _selectedTopic = expanded ? topic : null;
                });
              },
              leading: CircleAvatar(
                backgroundColor:
                    primaryGreen.withValues(alpha: 0.15),
                child: Icon(
                    _parseIconData(
                        topic['icon'] ?? 'Icons.help_outline'),
                    color: primaryGreen),
              ),
              title: Text(
                topic['title'],
                style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: primaryGreen),
              ),
              childrenPadding: EdgeInsets.symmetric(
                  horizontal: width > 800 ? 32 : 20,
                  vertical: 12),
              children: [
                // ACTIVITIES SECTION
                if (widget.role != EduRole.headteacher)
                  Padding(
                    padding:
                        const EdgeInsets.only(bottom: 24),
                    child: Card(
                      color: Colors.green.shade50,
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(16),
                        side: BorderSide(
                            color: primaryGreen, width: 2),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(
                                  Icons.assignment_turned_in,
                                  size: 28,
                                  color: primaryGreen),
                              const SizedBox(width: 10),
                              Text('Practice Activities',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight:
                                          FontWeight.bold,
                                      color: primaryGreen)),
                            ]),
                            const SizedBox(height: 6),
                            Text(
                                'Test your knowledge on ${topic['title']}!',
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black54)),
                            const SizedBox(height: 14),
                            SizedBox(
                                width: double.infinity,
                                child: _buildQuizSection()),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(
                                      vertical: 12),
                              child: Row(children: [
                                const Expanded(
                                    child: Divider(
                                        thickness: 1)),
                                Padding(
                                  padding: const EdgeInsets
                                      .symmetric(
                                          horizontal: 10),
                                  child: Text('or try',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Colors
                                              .grey.shade500)),
                                ),
                                const Expanded(
                                    child: Divider(
                                        thickness: 1)),
                              ]),
                            ),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _showSimBuilder,
                                icon: const Icon(
                                    Icons.play_circle_outline,
                                    size: 22),
                                label: const Text(
                                    'Run Interactive Simulation',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight:
                                            FontWeight.w600)),
                                style:
                                    OutlinedButton.styleFrom(
                                  foregroundColor:
                                      primaryGreen,
                                  side: const BorderSide(
                                      color: primaryGreen,
                                      width: 1.5),
                                  padding:
                                      const EdgeInsets.symmetric(
                                          vertical: 14),
                                  shape:
                                      RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius
                                                  .circular(10)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                if (topic['explanation'] != null)
                  Padding(
                    padding:
                        const EdgeInsets.only(bottom: 12),
                    child: Text(topic['explanation'] as String,
                        style: const TextStyle(
                            fontSize: 16, height: 1.6)),
                  ),

                if (topic['full_content'] != null)
                  _markdownCard(
                      topic['full_content'] as String),

                if (topic['image'] != null)
                  _buildImage(
                      topic['image'] as String, imageHeight),

                if (topic['key_points'] != null)
                  _keyPointsCard(
                      List<String>.from(topic['key_points'])),

                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar:
          (widget.role == EduRole.headteacher ||
                  widget.role == EduRole.student)
              ? null
              : Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey[50],
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _selectedTopic == null
                            ? null
                            : _showQuizBuilder,

                        label: Text(
                            'Create $_topicTitle Quiz'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          foregroundColor: Colors.white,
                          minimumSize:
                              const Size(double.infinity, 52),
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                TeacherEssayReviewScreen(
                              classId:    widget.classId,
                              schoolName: widget.schoolName,
                            ),
                          ),
                        ),
                        icon: const Icon(
                            Icons.rate_review_outlined),
                        label: const Text(
                            'Review essay submissions'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryGreen,
                          side: const BorderSide(
                              color: primaryGreen),
                          minimumSize:
                              const Size(double.infinity, 44),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildQuizSection() {
    final raw = FirestoreHelper.getContentFromClassId(widget.classId, _contentType);
    if (raw == null || _selectedTopic == null) {
      return _SplitActivityButtons(mcqCount: 0, essayCount: 0, onMcqTap: null, onEssayTap: null);
    }
    final coll = raw.withConverter<Map<String, dynamic>>(
      fromFirestore: (s, _) => s.data()!,
      toFirestore:   (d, _) => d,
    );
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: coll.where('type', isEqualTo: 'quiz').where('topic', isEqualTo: _topicTitle).snapshots(),
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
    if (rawCollection == null || _selectedTopic == null) {
      return const Center(child: Text('Invalid configuration'));
    }
    final collection = rawCollection.withConverter<Map<String, dynamic>>(
      fromFirestore: (s, _) => s.data()!,
      toFirestore:   (d, _) => d,
    );
    final sheetTitle = essayOnly ? 'Essay assignments — $_topicTitle' : 'Quizzes — $_topicTitle';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Icon(essayOnly ? Icons.edit_note : Icons.check_circle_outline,
                color: essayOnly ? Colors.purple : Colors.blue, size: 22),
            const SizedBox(width: 10),
            Expanded(child: Text(sheetTitle,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryGreen))),
          ]),
        ),
        Expanded(
          child:
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: collection
                .where('type', isEqualTo: type)
                .where('topic', isEqualTo: _topicTitle)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: primaryGreen));
              }
              final allDocs = snapshot.data?.docs ?? [];
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
                return Center(child: Text(
                  essayOnly ? 'No essay assignments yet' : 'No quizzes yet',
                  style: const TextStyle(fontSize: 18, fontStyle: FontStyle.italic, color: Colors.grey),
                ));
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
                        .then((s) => s.docs.map((d) {
                              final data = d.data();
                              if (data is Map<String, dynamic>) return data['${type}Id'] as String?;
                              return null;
                            }).whereType<String>().toSet()),
                builder: (context, completedSnap) {
                  final completedIds  = completedSnap.data ?? <String>{};
                  final isTeacher     = widget.role == EduRole.teacher;
                  final availableDocs = isTeacher
                      ? filteredDocs
                      : filteredDocs.where((doc) => !completedIds.contains(doc.id)).toList();
                  if (availableDocs.isEmpty) {
                    return Center(child: Text(
                      isTeacher ? 'None created yet' : 'All completed! Great job! 🎉',
                      style: const TextStyle(fontSize: 18),
                    ));
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
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 4,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: essayOnly ? Colors.purple : Colors.blue,
                            child: Icon(essayOnly ? Icons.edit_note : Icons.quiz, color: Colors.white),
                          ),
                          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: createdAt != null
                              ? Text('Created: ${_formatDate(createdAt.toDate())}') : null,
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