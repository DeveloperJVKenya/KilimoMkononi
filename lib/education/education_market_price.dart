// education_market_price.dart - FIXED IMAGE LOADING + SYNTAX ERROR RESOLVED + SAVE CONTENT ADDED + SIMULATION BUTTON ENABLED
// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:kilimomkononi/utils/firestore_helper.dart';
import '../models/education_user.dart';
import 'simulations/market_trading_simulation.dart';

const Color primaryGreen = Color(0xFF003900);

extension StringExt on String {
  String capitalize() => isNotEmpty ? '${this[0].toUpperCase()}${substring(1)}' : this;
}

extension TextEditingControllerExt on TextEditingController {
  String get safeText => text.trim();
}

class EducationMarketPrice extends StatefulWidget {
  final EduRole role;
  final String schoolName;
  final String classId;

  const EducationMarketPrice({
    super.key,
    required this.role,
    required this.schoolName,
    required this.classId,
  });

  @override
  State<EducationMarketPrice> createState() => _EducationMarketPriceState();
}

class _EducationMarketPriceState extends State<EducationMarketPrice> {
  final String _contentType = 'market_content';
  final String _system = 'cbcJunior';

  List<Map<String, dynamic>> _topics = [];
  Map<String, dynamic>? _selectedTopic;
  bool _loading = true;

  void _showSimBuilder() {
    if (_selectedTopic == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a topic first')),
      );
      return;
    }

    final topicTitle = _selectedTopic!['title'] as String? ?? 'Market Trading';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) => MarketTradingSimulation(
          topic: topicTitle,
          onComplete: () {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$topicTitle simulation completed!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
        ),
      ),
    );
  }


  @override
  void initState() {
    super.initState();
    _loadMarketContent();
  }

  Future<void> _loadMarketContent() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/market_tips/market_tips.json');
      final Map<String, dynamic> data = json.decode(jsonString);

      setState(() {
        _topics = List<Map<String, dynamic>>.from(data[_system] ?? []);
        _selectedTopic = _topics.isNotEmpty ? _topics[0] : null;
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

  IconData _parseIconData(String iconString) {
    final map = {
      'Icons.store': Icons.store,
      'Icons.swap_horiz': Icons.swap_horiz,
      'Icons.attach_money': Icons.attach_money,
      'Icons.savings': Icons.savings,
      'Icons.storefront': Icons.storefront,
      'Icons.balance': Icons.balance,
      'Icons.inventory_2': Icons.inventory_2,
      'Icons.receipt_long': Icons.receipt_long,
      'Icons.trending_up': Icons.trending_up,
      'Icons.price_check': Icons.price_check,
      'Icons.groups': Icons.groups,
      'Icons.phone_android': Icons.phone_android,
      'Icons.flight_takeoff': Icons.flight_takeoff,
    };
    return map[iconString] ?? Icons.help_outline;
  }

  Widget _buildImage(String assetPath, double maxHeight) {
    final fullPath = 'assets/$assetPath'; // ← FIXED: Added 'assets/' prefix like farming tips
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: maxHeight),
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

  Widget _keyPointsCard(List<String> points) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Key Learning Points", style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: primaryGreen)),
            const SizedBox(height: 12),
            ...points.map((point) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 22),
                      const SizedBox(width: 12),
                      Expanded(child: Text(point, style: const TextStyle(fontSize: 16, height: 1.5))),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: MarkdownBody(
          data: text,
          styleSheet: MarkdownStyleSheet(
            p: const TextStyle(fontSize: 16.5, height: 1.7),
            listBullet: const TextStyle(fontSize: 16.5, color: primaryGreen),
            strong: const TextStyle(fontWeight: FontWeight.bold, color: primaryGreen),
            h1: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold, color: primaryGreen),
            h2: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryGreen),
            blockquote: TextStyle(color: Colors.brown.shade700, fontStyle: FontStyle.italic),
          ),
        ),
      ),
    );
  }

  Future<void> _saveContent(String type, Map<String, dynamic> data) async {
    if (_selectedTopic == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a topic first')),
      );
      return;
    }

    final String topicTitle = _selectedTopic!['title'];
    final String title = data['title'] as String? ?? '$topicTitle ${type.capitalize()}';

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
        'type': type,
        'title': title,
        'topic': topicTitle,
        'data': jsonEncode(type == 'quiz' ? data['questions'] : data['steps']),
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

  Future<void> _launchContent(String type, String docId) async {
    final rawCollection = FirestoreHelper.getContentFromClassId(widget.classId, _contentType);
    if (rawCollection == null) return;

    try {
      final doc = await rawCollection.doc(docId).get();
      final dataMap = doc.data() as Map<String, dynamic>?;

      if (dataMap == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load content')),
        );
        return;
      }

      final String title = dataMap['title'] is String && (dataMap['title'] as String).trim().isNotEmpty
          ? (dataMap['title'] as String).trim()
          : '${dataMap['topic']} ${type.capitalize()}';

      final payload = jsonDecode(dataMap['data'] as String);

      final fullPayload = {
        'id': doc.id,
        'title': title,
        'topic': dataMap['topic'],
        if (type == 'quiz') 'questions': payload,
      };

      if (mounted) {
        final screen = type == 'quiz'
            ? MarketQuizScreen(payload: fullPayload, classId: widget.classId)
            : const SizedBox();

        Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final double imageHeight = width > 1000 ? 400.0 : width > 600 ? 340.0 : 280.0;
    final bool isTeacher = widget.role == EduRole.teacher;
    final bool isMobile = width < 600;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: primaryGreen)),
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
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: width > 1000 ? 64 : 16, vertical: 16),
        itemCount: _topics.length,
        itemBuilder: (context, index) {
          final topic = _topics[index];
          final bool isExpanded = _selectedTopic == topic;

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ExpansionTile(
              initiallyExpanded: isExpanded,
              onExpansionChanged: (expanded) {
                setState(() {
                  _selectedTopic = expanded ? topic : null;
                });
              },
              leading: CircleAvatar(
                backgroundColor: primaryGreen.withValues(alpha: 0.15),
                child: Icon(_parseIconData(topic['icon'] ?? 'Icons.help_outline'), color: primaryGreen),
              ),
              title: Text(
                topic['title'],
                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: primaryGreen),
              ),
              childrenPadding: EdgeInsets.symmetric(horizontal: width > 800 ? 32 : 20, vertical: 12),
              children: [
                // PROMINENT ACTIVITIES SECTION FOR STUDENTS
                if (widget.role == EduRole.student)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Card(
                      color: Colors.green.shade50,
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
                            Text(
                              'Test your knowledge on ${topic['title']}!',
                              style: const TextStyle(fontSize: 16, color: Colors.black87),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildActivitySection('quiz', Icons.quiz),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildActivitySection('simulation', Icons.play_circle_outline),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                if (topic['explanation'] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      topic['explanation'] as String,
                      style: const TextStyle(fontSize: 16, height: 1.6),
                    ),
                  ),

                if (topic['full_content'] != null) _markdownCard(topic['full_content'] as String),

                if (topic['image'] != null) _buildImage(topic['image'] as String, imageHeight),

                if (topic['key_points'] != null) _keyPointsCard(List<String>.from(topic['key_points'])),

                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: widget.role == EduRole.headteacher
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[50],
              child: Row(
                children: isTeacher
                    ? [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _selectedTopic == null
                                ? null
                                : () => showDialog(
                                      context: context,
                                      builder: (_) => MarketQuizBuilder(onSave: (d) => _saveContent('quiz', d)),
                                    ),
                            icon: const Icon(Icons.quiz),
                            label: Text('Create ${_selectedTopic?['title'] ?? ''} Quiz'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryGreen,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _selectedTopic == null ? null : _showSimBuilder,
                            icon: const Icon(Icons.play_circle),
                            label: Text('Run ${_selectedTopic?["title"] ?? ""} Simulation'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryGreen,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                            ),
                          ),
                        ),
                      ]
                    : [],
              ),
            ),
    );
  }

  Widget _buildActivitySection(String type, IconData icon) {
    final raw = FirestoreHelper.getContentFromClassId(widget.classId, _contentType);
    if (raw == null || _selectedTopic == null) {
      return ElevatedButton.icon(
        onPressed: null,
        icon: Icon(icon),
        label: const Text('Quizzes'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
      );
    }

    final coll = raw.withConverter<Map<String, dynamic>>(
      fromFirestore: (s, _) => s.data()!,
      toFirestore: (d, _) => d,
    );

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: coll
          .where('type', isEqualTo: type)
          .where('topic', isEqualTo: _selectedTopic!['title'])
          .snapshots(),
      builder: (context, snapshot) {
        int total = snapshot.data?.docs.length ?? 0;

        return ElevatedButton.icon(
          onPressed: total == 0 ? null : () => _showActivityList(type),
          icon: Icon(icon, size: 28),
          label: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${type.capitalize()}s', style: const TextStyle(fontSize: 18)),
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

  void _showActivityList(String type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.6,
        expand: false,
        builder: (_, controller) => _buildContentList(type, scrollController: controller),
      ),
    );
  }

  Widget _buildContentList(String type, {required ScrollController scrollController}) {
    final rawCollection = FirestoreHelper.getContentFromClassId(widget.classId, _contentType);
    if (rawCollection == null || _selectedTopic == null) {
      return const Center(child: Text('Invalid configuration'));
    }

    final CollectionReference<Map<String, dynamic>> collection = rawCollection.withConverter<Map<String, dynamic>>(
      fromFirestore: (snapshot, _) => snapshot.data()!,
      toFirestore: (data, _) => data,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '${type.capitalize()}s for ${_selectedTopic!['title']}',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryGreen),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: collection
                .where('type', isEqualTo: type)
                .where('topic', isEqualTo: _selectedTopic!['title'])
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: primaryGreen));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Text(
                    'No ${type}s available yet',
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
                        .where('type', isEqualTo: type)
                        .get()
                        .then((s) => s.docs
                            .map((d) {
                              final data = d.data();
                              if (data is Map<String, dynamic>) {
                                return data['${type}Id'] as String?;
                              }
                              return null;
                            })
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
                      final title = data['title'] as String? ?? 'Untitled ${type.capitalize()}';
                      final createdAt = data['createdAt'] as Timestamp?;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 4,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: primaryGreen,
                            child: Icon(type == 'quiz' ? Icons.quiz : Icons.play_circle, color: Colors.white),
                          ),
                          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: createdAt != null ? Text('Created: ${_formatDate(createdAt.toDate())}') : null,
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            Navigator.pop(context);
                            _launchContent(type, doc.id);
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
}

// ──────────────────────────────────────────────────────────────────────────────
// QUIZ SCREENS + BUILDERS
// ──────────────────────────────────────────────────────────────────────────────

class MarketQuizScreen extends StatefulWidget {
  final Map<String, dynamic> payload;
  final String classId;

  const MarketQuizScreen({super.key, required this.payload, required this.classId});

  @override
  State<MarketQuizScreen> createState() => _MarketQuizScreenState();
}

class _MarketQuizScreenState extends State<MarketQuizScreen> {
  int _idx = 0;
  int _score = 0;
  late final ConfettiController _conf = ConfettiController(duration: const Duration(seconds: 2));

  void _ans(int sel) {
    final correct = (widget.payload['questions'][_idx]['correct'] as num).toInt();
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
        'topic': widget.payload['topic'],
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
          content: Text('Score: $_score / ${widget.payload['questions'].length}'),
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
        child: Column(children: [
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
        ]),
      ),
    );
  }
}


class MarketQuizBuilder extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;
  const MarketQuizBuilder({super.key, required this.onSave});
  @override State<MarketQuizBuilder> createState() => _MarketQuizBuilderState();
}

class _MarketQuizBuilderState extends State<MarketQuizBuilder> {
  final _titleCtrl = TextEditingController();
  final List<Map<String, dynamic>> _questions = [];

  void _addQuestion() {
    final qCtrl = TextEditingController();
    final opts = List.generate(4, (_) => TextEditingController());
    int correct = 0;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Question'),
        content: StatefulBuilder(builder: (c, set) => SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: qCtrl, decoration: const InputDecoration(labelText: 'Question')),
          ...opts.asMap().entries.map((e) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
            Radio<int>(value: e.key, groupValue: correct, onChanged: (v) => set(() => correct = v!)),
            Expanded(child: TextField(controller: e.value, decoration: InputDecoration(labelText: 'Option ${e.key + 1}'))),
          ]))),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
            onPressed: () {
              final filled = opts.where((c) => c.safeText.isNotEmpty).toList();
              if (qCtrl.safeText.isEmpty || filled.isEmpty) return;
              setState(() => _questions.add({
                'question': qCtrl.safeText,
                'options': filled.map((c) => c.safeText).toList(),
                'correct': correct,
              }));
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
        title: const Text('Create Market Quiz'),
        content: SizedBox(width: double.maxFinite, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Title (optional)')),
          ElevatedButton.icon(onPressed: _addQuestion, icon: const Icon(Icons.add), label: const Text('Add Question')),
          ..._questions.asMap().entries.map((e) {
            final correctIndex = (e.value['correct'] as num).toInt();
            final correctLetter = String.fromCharCode(65 + correctIndex);
            return Card(child: ListTile(
              title: Text(e.value['question']),
              subtitle: Text('Correct: $correctLetter. ${(e.value['options'] as List)[correctIndex]}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () => setState(() => _questions.removeAt(e.key))),
            ));
          }),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
            onPressed: _questions.isEmpty ? null : () {
              widget.onSave({'title': _titleCtrl.safeText.isEmpty ? 'Market Quiz' : _titleCtrl.safeText, 'questions': _questions});
              Navigator.pop(context);
            },
            child: const Text('Save Quiz', style: TextStyle(color: Colors.white)),
          ),
        ],
      );
}