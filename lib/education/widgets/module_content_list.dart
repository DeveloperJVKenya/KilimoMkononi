// lib/education/widgets/module_content_list.dart
// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kilimomkononi/education/simulation/simulation_home.dart';
import 'package:rxdart/rxdart.dart';
import 'package:kilimomkononi/models/education_user.dart'; // For EduRole

class ModuleQuizList extends StatelessWidget {
  final String schoolName;
  final String gradeId;

  const ModuleQuizList({
    super.key,
    required this.schoolName,
    required this.gradeId,
  });

  @override
  Widget build(BuildContext context) {
    return _ModuleContentList(
      schoolName: schoolName,
      gradeId: gradeId,
      type: 'quiz',
      emptyMessage: 'No quizzes yet – ask your teacher!',
      getTitle: (data, raw) {
        final List questions = json.decode(raw);
        return data['topic']?.toString().isNotEmpty == true
            ? data['topic']
            : (questions.isNotEmpty ? questions[0]['q'].split('?').first + '?' : 'Quiz');
      },
      getSubtitle: (data, raw) {
        final List questions = json.decode(raw);
        return '${questions.length} question${questions.length > 1 ? 's' : ''}';
      },
      onTap: (item) {
        final questions = json.decode(item['data'] as String);
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GenericQuizPlayer(
              title: item['title'],
              questions: questions,
              module: item['module'],
            ),
          ),
        );
      },
    );
  }
}

class ModuleSimulationList extends StatelessWidget {
  final String schoolName;
  final String gradeId;

  const ModuleSimulationList({
    super.key,
    required this.schoolName,
    required this.gradeId,
  });

  @override
  Widget build(BuildContext context) {
    return _ModuleContentList(
      schoolName: schoolName,
      gradeId: gradeId,
      type: 'simulation',
      emptyMessage: 'No simulations yet – ask your teacher!',
      getTitle: (data, raw) {
        final Map sim = json.decode(raw);
        return sim['title']?.toString() ?? 'Untitled Simulation';
      },
      getSubtitle: (data, raw) {
        final Map sim = json.decode(raw);
        final steps = sim['steps'] as List?;
        return '${steps?.length ?? 0} step${steps?.length == 1 ? '' : 's'}';
      },
      onTap: (item) {
        // Redirect to the new modern Simulation Home instead of old GenericSimulationPlayer
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SimulationHome(
              classId: gradeId,
              schoolName: schoolName,
              role: EduRole.student,
            ),
          ),
        );
      },
    );
  }
}

class ModuleManualList extends StatelessWidget {
  final String schoolName;
  final String gradeId;

  const ModuleManualList({
    super.key,
    required this.schoolName,
    required this.gradeId,
  });

  @override
  Widget build(BuildContext context) {
    return _ModuleContentList(
      schoolName: schoolName,
      gradeId: gradeId,
      type: 'manual',
      emptyMessage: 'No manuals uploaded yet',
      getTitle: (data, raw) => data['title']?.toString() ?? 'Manual',
      getSubtitle: (data, raw) => data['crop']?.toString().capitalize() ?? 'General',
      onTap: (item) {
        // You can open PDF viewer or download here later
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opening manual: ${item['title']}')),
        );
      },
    );
  }
}

class _ModuleContentList extends StatelessWidget {
  final String schoolName;
  final String gradeId;
  final String type;
  final String emptyMessage;
  final String Function(Map<String, dynamic>, String) getTitle;
  final String Function(Map<String, dynamic>, String) getSubtitle;
  final void Function(Map<String, dynamic>) onTap;

  const _ModuleContentList({
    required this.schoolName,
    required this.gradeId,
    required this.type,
    required this.emptyMessage,
    required this.getTitle,
    required this.getSubtitle,
    required this.onTap,
  });

  Stream<List<Map<String, dynamic>>> _contentStream() {
    final base = FirebaseFirestore.instance
        .collection('schools')
        .doc(schoolName)
        .collection('grades')
        .doc(gradeId);

    final collections = [
      'farming_content',
      'market_content',
      'weather_content',
      'manuals_content',
    ];

    final moduleInfo = {
      'farming_content': {'name': 'Farming Tips', 'icon': Icons.agriculture, 'color': Colors.green},
      'market_content': {'name': 'Market Management', 'icon': Icons.store, 'color': Colors.orange},
      'weather_content': {'name': 'Weather Forecast', 'icon': Icons.cloud, 'color': Colors.blue},
      'manuals_content': {'name': 'Manuals', 'icon': Icons.book, 'color': Colors.brown},
    };

    final streams = collections.map((coll) {
      return base
          .collection(coll)
          .where('type', isEqualTo: type)
          .snapshots()
          .map((snap) {
        final List<Map<String, dynamic>> items = [];
        for (final doc in snap.docs) {
          final data = doc.data();
          final raw = data['data'] as String?;
          if (raw == null) continue;

          final info = moduleInfo[coll] ?? moduleInfo['farming_content']!;
          items.add({
            'id': doc.id,
            'title': getTitle(data, raw),
            'subtitle': getSubtitle(data, raw),
            'data': raw,
            'module': info['name'],
            'icon': info['icon'],
            'color': info['color'],
          });
        }
        return items;
      });
    });

    return CombineLatestStream.list(streams).map((list) => list.expand((x) => x).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: type == 'quiz'
                ? Colors.purple.shade50
                : type == 'simulation'
                    ? Colors.blue.shade50
                    : Colors.brown.shade50,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            children: [
              Icon(
                type == 'quiz'
                    ? Icons.quiz
                    : type == 'simulation'
                        ? Icons.science
                        : Icons.book,
                color: type == 'quiz'
                    ? Colors.purple
                    : type == 'simulation'
                        ? Colors.blue
                        : Colors.brown,
              ),
              const SizedBox(width: 8),
              Text(
                type == 'quiz'
                    ? 'All Quizzes'
                    : type == 'simulation'
                        ? 'All Simulations'
                        : 'All Manuals',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _contentStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      emptyMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ),
                );
              }

              final items = snapshot.data!;
              final grouped = <String, List<Map<String, dynamic>>>{};
              for (var item in items) {
                grouped.putIfAbsent(item['module'], () => []).add(item);
              }

              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: grouped.length,
                itemBuilder: (_, i) {
                  final module = grouped.keys.elementAt(i);
                  final list = grouped[module]!;
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: (list[0]['color'] as Color).withOpacity(0.2),
                        child: Icon(list[0]['icon'] as IconData, color: list[0]['color']),
                      ),
                      title: Text(module, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${list.length} $type${list.length > 1 ? 's' : ''}'),
                      children: list.map((item) => ListTile(
                            title: Text(item['title']),
                            subtitle: Text(item['subtitle']),
                            trailing: const Icon(Icons.play_arrow),
                            onTap: () => onTap(item),
                          )).toList(),
                    ),
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

class GenericQuizPlayer extends StatelessWidget {
  final String title;
  final List<dynamic> questions;
  final String module;

  const GenericQuizPlayer({
    super.key,
    required this.title,
    required this.questions,
    required this.module,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          'Quiz player for $module (${questions.length} questions)',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// Helper extension
extension StringExt on String {
  String capitalize() => isNotEmpty ? '${this[0].toUpperCase()}${substring(1)}' : this;
}