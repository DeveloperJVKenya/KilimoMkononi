// lib/education/quiz/quiz_home.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kilimomkononi/utils/firestore_helper.dart';
import 'package:rxdart/rxdart.dart';

class QuizHome extends StatefulWidget {
  final String classId;
  final String schoolName;
  final VoidCallback? onClose; // ← Added for tablet/desktop close support

  const QuizHome({
    super.key,
    required this.classId,
    required this.schoolName,
    this.onClose,
  });

  @override
  State<QuizHome> createState() => _QuizHomeState();
}

class _QuizHomeState extends State<QuizHome> {
  static const Map<String, Map<String, Object>> moduleInfo = {
    'farming_content': {'name': 'Farming Tips', 'icon': Icons.agriculture, 'color': Colors.green},
    'market_content': {'name': 'Market Price', 'icon': Icons.store, 'color': Colors.orange},
    'weather_content': {'name': 'Weather Forecast', 'icon': Icons.cloud, 'color': Colors.blue},
    'manuals_content': {'name': 'Manuals', 'icon': Icons.book, 'color': Colors.brown},
    'farm_management_content': {'name': 'Farm Management', 'icon': Icons.account_balance_wallet, 'color': Colors.purple},
    'field_content': {'name': 'Field Data', 'icon': Icons.terrain, 'color': Colors.greenAccent},
    'pest_content': {'name': 'Pest', 'icon': Icons.bug_report, 'color': Colors.red},
    'disease_content': {'name': 'Disease', 'icon': Icons.local_hospital, 'color': Colors.deepOrange},
  };

  Stream<Map<String, List<Map<String, dynamic>>>> _quizStream() {
    final collections = moduleInfo.keys.toList();

    final streams = collections.map((coll) {
      final collection = FirestoreHelper.getContentFromClassId(widget.classId, coll);
      if (collection == null) {
        return Stream.value(<Map<String, dynamic>>[]);
      }
      return collection
          .where('type', isEqualTo: 'quiz')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) {
                final dataMap = doc.data() as Map<String, dynamic>?;
                if (dataMap == null) return null;

                return {
                  'id': doc.id,
                  'title': (dataMap['title'] as String?)?.trim().isNotEmpty == true
                      ? dataMap['title'] as String
                      : 'Untitled Quiz',
                  'questions': dataMap['data'] is String ? jsonDecode(dataMap['data']) : dataMap['data'],
                  'createdAt': dataMap['createdAt'] as Timestamp?,
                };
              }).whereType<Map<String, dynamic>>().toList());
    });

    return CombineLatestStream.list(streams).map((listOfLists) {
      final grouped = <String, List<Map<String, dynamic>>>{};

      for (var i = 0; i < listOfLists.length; i++) {
        final coll = collections[i];
        final quizzes = listOfLists[i];
        grouped[coll] = quizzes;
      }

      return grouped;
    });
  }

  String _formatGradeDisplay(String classId) {
    if (classId.contains('|')) {
      final parts = classId.split('|');
      final shortId = parts[0];
      final systemName = parts.length > 1 ? parts[1] : 'cbcJunior';
      final systemGrades = {
        'cbcPrimary': ['Grade 1', 'Grade 2', 'Grade 3', 'Grade 4', 'Grade 5', 'Grade 6'],
        'cbcJunior': ['Grade 7', 'Grade 8', 'Grade 9'],
        'cbcSenior': ['Grade 10', 'Grade 11', 'Grade 12'],
        'eightFourFour': [
          'Standard 1', 'Standard 2', 'Standard 3', 'Standard 4',
          'Standard 5', 'Standard 6', 'Standard 7', 'Standard 8',
          'Form 1', 'Form 2', 'Form 3', 'Form 4',
        ],
      };
      final grades = systemGrades[systemName] ?? systemGrades['cbcJunior']!;
      final gradeText = grades.firstWhere((g) => g.split(' ').last == shortId, orElse: () => 'Grade $shortId');
      return gradeText;
    }

    final match = RegExp(r'_(\d+)$').firstMatch(classId);
    if (match != null) {
      final num = match.group(1);
      final prefix = classId.contains('primary') || classId.contains('junior') || classId.contains('senior')
          ? 'Grade'
          : (int.parse(num!) <= 8 ? 'Standard' : 'Form');
      return '$prefix $num';
    }
    return classId;
  }

  @override
  Widget build(BuildContext context) {
    final niceGrade = _formatGradeDisplay(widget.classId);
    final isLargeScreen = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      appBar: AppBar(
        title: Text('Quizzes – $niceGrade'),
        backgroundColor: const Color(0xFF003900),
        foregroundColor: Colors.white,
        leading: isLargeScreen
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close',
                onPressed: widget.onClose, // ← Uses the callback from parent
              )
            : null, // Mobile: automatic back button
      ),
      body: StreamBuilder<Map<String, List<Map<String, dynamic>>>>( 
        stream: _quizStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF003900)));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No quizzes available yet'));
          }

          final grouped = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: grouped.entries.map((entry) {
              final mod = entry.key;
              final quizzes = entry.value;
              final info = moduleInfo[mod] ?? {'name': mod, 'icon': Icons.help, 'color': Colors.grey};

              if (quizzes.isEmpty) return const SizedBox.shrink();

              return Card(
                child: ExpansionTile(
                  leading: Icon(info['icon'] as IconData, color: info['color'] as Color),
                  title: Text(info['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                  children: quizzes.map((q) => ListTile(
                    title: Text(q['title'] as String),
                    subtitle: q['createdAt'] != null
                        ? Text('Created: ${(q['createdAt'] as Timestamp).toDate().toLocal().toString().split(' ')[0]}')
                        : null,
                    trailing: const Icon(Icons.play_arrow),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GenericQuizPlayer(
                          title: q['title'] as String,
                          questions: q['questions'] as List<dynamic>,
                          module: info['name'] as String,
                          onClose: widget.onClose, // Pass down to player
                        ),
                      ),
                    ),
                  )).toList(),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class GenericQuizPlayer extends StatefulWidget {
  final String title;
  final List<dynamic> questions;
  final String module;
  final VoidCallback? onClose; // ← Added

  const GenericQuizPlayer({
    super.key,
    required this.title,
    required this.questions,
    required this.module,
    this.onClose,
  });

  @override
  State<GenericQuizPlayer> createState() => _GenericQuizPlayerState();
}

class _GenericQuizPlayerState extends State<GenericQuizPlayer> {
  int _current = 0;
  int _score = 0;

  void _answer(int selectedIndex) {
    final q = widget.questions[_current] as Map<String, dynamic>;
    if (selectedIndex == (q['correct'] as num?)?.toInt()) {
      _score++;
    }

    if (_current < widget.questions.length - 1) {
      setState(() => _current++);
    } else {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Quiz Complete!'),
          content: Text('Your score: $_score / ${widget.questions.length}'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // close dialog
                if (widget.onClose != null) {
                  widget.onClose!(); // Return to dashboard on large screens
                } else {
                  Navigator.of(context).pop(); // fallback for mobile
                }
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.questions[_current] as Map<String, dynamic>;
    final options = (q['options'] as List?) ?? [];
    final isLargeScreen = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xFF003900),
        foregroundColor: Colors.white,
        leading: isLargeScreen
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: widget.onClose ?? () => Navigator.of(context).pop(),
                tooltip: 'Close',
              )
            : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Question ${_current + 1} of ${widget.questions.length}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Text(
              q['question']?.toString() ?? 'No question',
              style: const TextStyle(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ...options.asMap().entries.map((e) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _answer(e.key),
                    child: Text(
                      e.value.toString(),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              );
            }),
            if (q['explanation']?.toString().isNotEmpty == true) ...[
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  'Hint: ${q['explanation']}',
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}