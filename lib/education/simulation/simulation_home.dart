// lib/education/simulation/simulation_home.dart
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kilimomkononi/utils/firestore_helper.dart';
import 'package:kilimomkononi/models/education_user.dart';
import 'package:kilimomkononi/education/quiz/shared_quiz_widgets.dart';
import 'package:kilimomkononi/education/simulations/farm_planting_simulation.dart';
import 'package:kilimomkononi/education/simulations/market_trading_simulation.dart';
import 'package:kilimomkononi/education/simulations/weather_prediction_simulation.dart';
import 'package:kilimomkononi/education/pest/simulations/disease_management_interactive_simulation.dart';
import 'package:kilimomkononi/education/pest/simulations/pest_management_interactive_simulation.dart';
import 'package:kilimomkononi/education/field/simulations/field_operations_simulation.dart';
import 'package:kilimomkononi/education/farm_management/simulations/farm_financial_management_simulation.dart';
import 'package:kilimomkononi/education/simulations/crop_crisis_simulation.dart';
import 'package:kilimomkononi/education/simulation/student_simulation_result_screen.dart';
import 'package:kilimomkononi/education/education_farming_tips.dart';

// In simulation_home.dart — replace the existing getSimulationWidget

Widget? getSimulationWidget({
  required String module,
  required String classId,
  required String studentName,
  required VoidCallback onComplete,
  String? cropName,           // ← New optional parameter for Farming Tips
}) {
  switch (module) {
    case 'Market Price':
      return MarketTradingSimulation(
        topic: 'Agricultural Market Trading',
        classId: classId,
        module: module,
        studentName: studentName,
        onComplete: onComplete,
      );
    case 'Weather Forecast':
      return WeatherPredictionSimulation(
        classId: classId,
        module: module,
        studentName: studentName,
        onComplete: onComplete,
      );
    case 'Disease':
      return DiseaseManagementInteractiveSimulation(
        classId: classId,
        module: module,
        studentName: studentName,
        onComplete: onComplete,
      );
    case 'Pest':
      return PestManagementInteractiveSimulation(
        classId: classId,
        module: module,
        studentName: studentName,
        onComplete: onComplete,
      );
    case 'Field Data':
      return FieldOperationsSimulation(
        classId: classId,
        module: module,
        studentName: studentName,
        onComplete: onComplete,
      );
    case 'Farm Management':
      return FarmFinancialManagementSimulation(
        classId: classId,
        module: module,
        studentName: studentName,
        onComplete: onComplete,
      );

    // === Farming Tips (Crop-specific) ===
    case 'Farming Tips':
      if (cropName != null && cropName.isNotEmpty) {
        return FarmPlantingSimulation(
          classId: classId,
          module: module,
          studentName: studentName,
          cropName: cropName,
          cropData: {
            'classId': classId,
          },
          onComplete: onComplete,
        );
      }
      return null;

    case 'Crop Crisis':
      return CropCrisisSetupScreen(classId: classId, schoolName: '');

    default:
      return null;
  }
}

const Color _simGreen = Color(0xFF003900);

// ── Interactive simulations catalogue ────────────────────────────────────────
class _InteractiveSim {
  final String key;
  final String module;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final Widget Function(String classId, String studentName, VoidCallback onDone)? builder;
  final bool isFarmingTips;

  const _InteractiveSim({
    required this.key,
    required this.module,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.builder,
    this.isFarmingTips = false,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
//  SimulationHome — Two Tabs
// ═══════════════════════════════════════════════════════════════════════════

class SimulationHome extends StatefulWidget {
  final String classId;
  final String schoolName;
  final EduRole role;
  final VoidCallback? onClose;

  const SimulationHome({
    super.key,
    required this.classId,
    required this.schoolName,
    required this.role,
    this.onClose,
  });

  @override
  State<SimulationHome> createState() => _SimulationHomeState();
}

class _SimulationHomeState extends State<SimulationHome> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  // Core Simulations
  List<_InteractiveSim> _coreSimulations(String classId) => [
        _InteractiveSim(
          key: 'farm_planting',
          module: 'Farming Tips',
          title: 'Farm Planting',
          description: 'Grow different crops. Learn soil prep, watering, fertilising and pest control.',
          icon: Icons.energy_savings_leaf,
          color: Colors.green,
          isFarmingTips: true,
        ),
        _InteractiveSim(
          key: 'market_trading',
          module: 'Market Price',
          title: 'Market Trading',
          description: 'Trade Kenyan crops over 10 days. Buy low, sell high.',
          icon: Icons.store,
          color: Colors.orange,
          builder: (classId, name, done) => MarketTradingSimulation(
            topic: 'Agricultural Market Trading',
            classId: classId,
            module: 'Market Price',
            studentName: name,
            onComplete: done,
          ),
        ),
        _InteractiveSim(
          key: 'weather_prediction',
          module: 'Weather Forecast',
          title: 'Weather Prediction',
          description: 'Study sensor data for 7 days and predict tomorrow\'s weather.',
          icon: Icons.cloud,
          color: Colors.blue,
          builder: (classId, name, done) => WeatherPredictionSimulation(
            classId: classId,
            module: 'Weather Forecast',
            studentName: name,
            onComplete: done,
          ),
        ),
        _InteractiveSim(
          key: 'disease_management',
          module: 'Disease',
          title: 'Disease Management',
          description: 'Apply Integrated Disease Management over 10 days.',
          icon: Icons.local_hospital,
          color: Colors.deepOrange,
          builder: (classId, name, done) => DiseaseManagementInteractiveSimulation(
            classId: classId,
            module: 'Disease',
            studentName: name,
            onComplete: done,
          ),
        ),
        _InteractiveSim(
          key: 'pest_management',
          module: 'Pest',
          title: 'Pest Management',
          description: 'Use IPM over 8 weeks to control pests while protecting beneficial insects.',
          icon: Icons.bug_report,
          color: Colors.red,
          builder: (classId, name, done) => PestManagementInteractiveSimulation(
            classId: classId,
            module: 'Pest',
            studentName: name,
            onComplete: done,
          ),
        ),
        _InteractiveSim(
          key: 'field_operations',
          module: 'Field Data',
          title: 'Field Operations',
          description: 'Manage tillage, fertilisation, weeding and irrigation across 10 weeks.',
          icon: Icons.terrain,
          color: Colors.teal,
          builder: (classId, name, done) => FieldOperationsSimulation(
            classId: classId,
            module: 'Field Data',
            studentName: name,
            onComplete: done,
          ),
        ),
        _InteractiveSim(
          key: 'farm_financial',
          module: 'Farm Management',
          title: 'Farm Financial Management',
          description: 'Run a farm for 12 months. Make investment, loan and crop decisions.',
          icon: Icons.account_balance_wallet,
          color: Colors.purple,
          builder: (classId, name, done) => FarmFinancialManagementSimulation(
            classId: classId,
            module: 'Farm Management',
            studentName: name,
            onComplete: done,
          ),
        ),
      ];

  // Special Scenarios
  List<_InteractiveSim> _specialSimulations(String classId) => [
        _InteractiveSim(
          key: 'crop_crisis',
          module: 'Crop Crisis',
          title: 'Crop Crisis Scenario',
          description: 'AI-generates a unique 5-stage crisis tailored to a real Kenyan crop and county.',
          icon: Icons.auto_awesome,
          color: Colors.deepPurple,
          builder: (classId, name, done) => CropCrisisSetupScreen(
            classId: classId,
            schoolName: '',
          ),
        ),
      ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  String _getGradeLabel() {
    final id = widget.classId;
    if (id.contains('|')) {
      final parts = id.split('|');
      final num = parts[0];
      final sys = parts.length > 1 ? parts[1] : 'cbcJunior';
      const grades = {
        'cbcPrimary': ['Grade 1', 'Grade 2', 'Grade 3', 'Grade 4', 'Grade 5', 'Grade 6'],
        'cbcJunior': ['Grade 7', 'Grade 8', 'Grade 9'],
        'cbcSenior': ['Grade 10', 'Grade 11', 'Grade 12'],
        'eightFourFour': ['Standard 1', 'Standard 2', 'Standard 3', 'Standard 4', 'Standard 5', 'Standard 6', 'Standard 7', 'Standard 8', 'Form 1', 'Form 2', 'Form 3', 'Form 4'],
      };
      final list = grades[sys] ?? grades['cbcJunior']!;
      return list.firstWhere((g) => g.split(' ').last == num, orElse: () => 'Grade $num');
    }
    final m = RegExp(r'_(\d+)$').firstMatch(id);
    if (m != null) {
      final n = m.group(1)!;
      final pfx = id.contains('primary') || id.contains('junior') || id.contains('senior') ? 'Grade' : int.parse(n) <= 8 ? 'Standard' : 'Form';
      return '$pfx $n';
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    final isLarge = MediaQuery.of(context).size.width >= 600;
    final isTeacher = widget.role == EduRole.teacher;

    return Scaffold(
      appBar: AppBar(
        title: Text('Simulations – ${_getGradeLabel()}'),
        backgroundColor: _simGreen,
        foregroundColor: Colors.white,
        leading: isLarge
            ? IconButton(icon: const Icon(Icons.close), tooltip: 'Close', onPressed: widget.onClose)
            : null,
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.sports_esports), text: 'Core Simulations'),
            Tab(icon: Icon(Icons.auto_awesome), text: 'Special Scenarios'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildCoreTab(isTeacher),
          _buildSpecialTab(isTeacher),
        ],
      ),
    );
  }

  // ... (_buildCoreTab, _buildSpecialTab, _studentSimulationStatusStream remain the same as you had)

  Widget _buildCoreTab(bool isTeacher) {
    final coreSims = _coreSimulations(widget.classId);

    if (isTeacher) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: coreSims.map((sim) => _TeacherSimCard(
              sim: sim,
              classId: widget.classId,
              schoolName: widget.schoolName,
            )).toList(),
      );
    }

    return StreamBuilder<Map<String, Map<String, dynamic>>>(
      stream: _studentSimulationStatusStream(),
      builder: (context, snap) {
        final statusMap = snap.data ?? {};
        return ListView(
          padding: const EdgeInsets.all(16),
          children: coreSims.map((sim) => _StudentSimCard(
                sim: sim,
                isDone: statusMap[sim.module]?['completed'] == true,
                isReviewed: statusMap[sim.module]?['reviewed'] == true,
                score: statusMap[sim.module]?['score'] ?? 0,
                classId: widget.classId,
              )).toList(),
        );
      },
    );
  }

  Widget _buildSpecialTab(bool isTeacher) {
    final specialSims = _specialSimulations(widget.classId);

    if (isTeacher) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: specialSims.map((sim) => _TeacherSimCard(
              sim: sim,
              classId: widget.classId,
              schoolName: widget.schoolName,
            )).toList(),
      );
    }

    return StreamBuilder<Map<String, Map<String, dynamic>>>(
      stream: _studentSimulationStatusStream(),
      builder: (context, snap) {
        final statusMap = snap.data ?? {};
        return ListView(
          padding: const EdgeInsets.all(16),
          children: specialSims.map((sim) => _StudentSimCard(
                sim: sim,
                isDone: statusMap[sim.module]?['completed'] == true,
                isReviewed: statusMap[sim.module]?['reviewed'] == true,
                score: statusMap[sim.module]?['score'] ?? 0,
                classId: widget.classId,
              )).toList(),
        );
      },
    );
  }

  Stream<Map<String, Map<String, dynamic>>> _studentSimulationStatusStream() {
    final coll = FirestoreHelper.getSubmissionsFromClassId(widget.classId);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (coll == null || uid == null) return Stream.value({});

    return coll
        .where('type', isEqualTo: 'simulation')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((snap) {
      final result = <String, Map<String, dynamic>>{};
      for (final doc in snap.docs) {
        final d = doc.data() as Map<String, dynamic>;
        final module = d['module'] as String? ?? '';
        if (module.isEmpty) continue;

        int displayScore = (d['aiScore'] as num?)?.toInt() ?? (d['fallbackScore'] as num?)?.toInt() ?? 0;

        final essayRaw = d['essayAnswers'] as String?;
        if (essayRaw != null) {
          try {
            final list = jsonDecode(essayRaw) as List?;
            if (list != null && list.isNotEmpty) {
              final essay = list[0] as Map<String, dynamic>;
              if (essay['teacherApproved'] == true) {
                final ts = (essay['finalScore'] as num?)?.toInt();
                if (ts != null) displayScore = ts;
              }
            }
          } catch (_) {}
        }

        result[module] = {
          'completed': true,
          'reviewed': d['teacherReviewed'] == true,
          'score': displayScore,
        };
      }
      return result;
    });
  }
}
// ═══════════════════════════════════════════════════════════════════════════
//  _StudentSimCard — Now fully clickable
// ═══════════════════════════════════════════════════════════════════════════
class _StudentSimCard extends StatelessWidget {
  final _InteractiveSim sim;
  final bool isDone;
  final bool isReviewed;
  final int score;
  final String classId;

  const _StudentSimCard({
    required this.sim,
    required this.isDone,
    this.isReviewed = false,
    this.score = 0,
    required this.classId,
  });

  @override
  Widget build(BuildContext context) {
    final bool showReviewed = isDone && isReviewed;
    final bool showPending = isDone && !isReviewed;

    return GestureDetector(
      onTap: () {
        if (!isDone) {
          _launchInteractive(context);        // Not started → Start it
        } else if (showReviewed) {
          _openStudentResult(context);        // Reviewed → Show result
        } else if (showPending) {
          // Optional: show a message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Waiting for teacher review')),
          );
        }
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: isDone ? 1 : 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: isDone
                      ? (isReviewed ? Colors.green.shade50 : Colors.orange.shade50)
                      : sim.color.withOpacity(0.12),
                  child: Icon(
                    isDone ? (isReviewed ? Icons.check_circle : Icons.pending) : sim.icon,
                    color: isDone ? (isReviewed ? Colors.green.shade600 : Colors.orange.shade600) : sim.color,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Text(sim.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                        if (isDone) ...[
                          if (showReviewed)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Text('Reviewed • $score%',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.green)),
                            )
                          else if (showPending)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange.shade200),
                              ),
                              child: const Text('Pending Review',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.orange)),
                            ),
                        ],
                      ]),
                      const SizedBox(height: 4),
                      Text(sim.description, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4)),
                    ],
                  ),
                ),
              ]),

              if (showReviewed) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.visibility, size: 16),
                        label: const Text('View Results'),
                        onPressed: () => _openStudentResult(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                          side: const BorderSide(color: Colors.green),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.replay, size: 16),
                        label: const Text('Tap to start →'),
                        onPressed: () => _launchInteractive(context),
                        style: ElevatedButton.styleFrom(backgroundColor: _simGreen),
                      ),
                    ),
                  ],
                ),
              ] else if (!isDone)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Tap to start →', style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600)),
                )
              else if (showPending)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Waiting for teacher review', style: TextStyle(fontSize: 12, color: Colors.orange)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openStudentResult(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentSimulationResultScreen(
          classId: classId,
          module: sim.module,
          title: sim.title,
        ),
      ),
    );
  }

  void _launchInteractive(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName?.trim().isNotEmpty == true ? user!.displayName! : 'Student';

    if (sim.isFarmingTips) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EducationFarmingTips(
            role: EduRole.student,
            schoolName: '',
            classId: classId,
          ),
        ),
      );
      return;
    }

    if (sim.key == 'crop_crisis') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CropCrisisSetupScreen(
            classId: classId,
            schoolName: '',
          ),
        ),
      );
      return;
    }

    if (sim.builder != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => sim.builder!(
            classId,
            name,
            () => Navigator.of(context).popUntil((r) => r.isFirst),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Simulation not implemented yet')),
      );
    }
  }
}

class _TeacherSimCard extends StatelessWidget {
  final _InteractiveSim sim;
  final String classId;
  final String schoolName;

  const _TeacherSimCard({required this.sim, required this.classId, required this.schoolName});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: sim.color.withOpacity(0.12),
            child: Icon(sim.icon, color: sim.color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sim.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 3),
                Text(sim.description,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TeacherEssayReviewScreen(
                  classId: classId,
                  schoolName: schoolName,
                ),
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: sim.color,
              side: BorderSide(color: sim.color.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            child: const Text('Review'),
          ),
        ]),
      ),
    );
  }
}