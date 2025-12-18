// lib/education/simulation/simulation_home.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kilimomkononi/utils/firestore_helper.dart';
import 'package:rxdart/rxdart.dart';

class SimulationHome extends StatefulWidget {
  final String classId;
  final String schoolName;
  final VoidCallback? onClose; // ← ADD THIS

  const SimulationHome({
    super.key,
    required this.classId,
    required this.schoolName,
    this.onClose, // ← AND THIS
  });

  @override
  State<SimulationHome> createState() => _SimulationHomeState();
}

class _SimulationHomeState extends State<SimulationHome> {
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

  Stream<Map<String, List<Map<String, dynamic>>>> _simulationStream() {
    final collections = moduleInfo.keys.toList();

    final streams = collections.map((coll) {
      final collection = FirestoreHelper.getContentFromClassId(widget.classId, coll);
      if (collection == null) {
        return Stream.value(<Map<String, dynamic>>[]);
      }
      return collection
          .where('type', isEqualTo: 'simulation')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) {
                final dataMap = doc.data() as Map<String, dynamic>?;
                if (dataMap == null) return null;

                return {
                  'id': doc.id,
                  'title': (dataMap['title'] as String?)?.trim().isNotEmpty == true
                      ? dataMap['title'] as String
                      : 'Untitled Simulation',
                  'steps': dataMap['data'] is String ? jsonDecode(dataMap['data']) : dataMap['data'],
                  'createdAt': dataMap['createdAt'] as Timestamp?,
                };
              }).whereType<Map<String, dynamic>>().toList());
    });

    return CombineLatestStream.list(streams).map((listOfLists) {
      final grouped = <String, List<Map<String, dynamic>>>{};

      for (var i = 0; i < listOfLists.length; i++) {
        final coll = collections[i];
        final sims = listOfLists[i];
        grouped[coll] = sims;
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
        title: Text('Simulations – $niceGrade'),
        backgroundColor: const Color(0xFF003900),
        foregroundColor: Colors.white,
        leading: isLargeScreen
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close',
                onPressed: widget.onClose, // ← NOW THIS WORKS!
              )
            : null, // Mobile: automatic back button
      ),
      body: StreamBuilder<Map<String, List<Map<String, dynamic>>>>(
        stream: _simulationStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF003900)));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No simulations available yet'));
          }

          final grouped = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: grouped.entries.map((entry) {
              final mod = entry.key;
              final sims = entry.value;
              final info = moduleInfo[mod] ?? {'name': mod, 'icon': Icons.help, 'color': Colors.grey};

              if (sims.isEmpty) return const SizedBox.shrink();

              return Card(
                child: ExpansionTile(
                  leading: Icon(info['icon'] as IconData, color: info['color'] as Color),
                  title: Text(info['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                  children: sims.map((s) => ListTile(
                    title: Text(s['title'] as String),
                    subtitle: s['createdAt'] != null
                        ? Text('Created: ${(s['createdAt'] as Timestamp).toDate().toLocal().toString().split(' ')[0]}')
                        : null,
                    trailing: const Icon(Icons.play_arrow),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GenericSimulationPlayer(
                          title: s['title'] as String,
                          steps: s['steps'] as List<dynamic>,
                          module: info['name'] as String,
                          onClose: widget.onClose, // Optional: pass to player if needed
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

class GenericSimulationPlayer extends StatefulWidget {
  final String title;
  final List<dynamic> steps;
  final String module;
  final VoidCallback? onClose; // Optional for consistency

  const GenericSimulationPlayer({
    super.key,
    required this.title,
    required this.steps,
    required this.module,
    this.onClose,
  });

  @override
  State<GenericSimulationPlayer> createState() => _GenericSimulationPlayerState();
}

class _GenericSimulationPlayerState extends State<GenericSimulationPlayer> {
  int _step = 0;

  void _choose(int i) {
    final currentStep = widget.steps[_step] as Map<String, dynamic>;
    final option = currentStep['options'][i] as Map<String, dynamic>;

    if (option['explanation']?.toString().isNotEmpty == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(option['explanation'])),
      );
    }

    if (_step < widget.steps.length - 1) {
      setState(() => _step++);
    } else {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Complete!'),
          content: Text('You finished "${widget.title}"'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // close dialog
                if (widget.onClose != null) {
                  widget.onClose!(); // Use onClose on large screens
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
    final step = widget.steps[_step] as Map<String, dynamic>;
    final options = (step['options'] as List).map((e) => e as Map<String, dynamic>).toList();
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Step ${_step + 1}/${widget.steps.length}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              step['prompt']?.toString() ?? '',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ...options.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: ElevatedButton(
                    onPressed: () => _choose(e.key),
                    child: Text(e.value['text']?.toString() ?? 'Option ${e.key + 1}'),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}