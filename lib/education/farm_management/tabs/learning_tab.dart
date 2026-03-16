// lib/education/farm_management/tabs/learning_tab.dart

import 'package:flutter/material.dart';
import 'package:kilimomkononi/models/education_user.dart';
import '../farm_quiz.dart';
import '../simulations/farm_financial_management_simulation.dart';

const Color primaryGreen = Color(0xFF003900);

class LearningTab extends StatefulWidget {
  final EduRole role;
  final String classId;
  final String schoolName;

  const LearningTab({
    super.key,
    required this.role,
    required this.classId,
    required this.schoolName,
  });

  @override
  State<LearningTab> createState() => _LearningTabState();
}

class _LearningTabState extends State<LearningTab> {
  void _launchSimulation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) => FarmFinancialManagementSimulation(
          onComplete: () {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Farm management simulation completed! 🎉'),
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
  Widget build(BuildContext context) {
    final bool _ = widget.role == EduRole.teacher;

    // LearningTab lives inside FarmManagementScreen's IndexedStack.
    // FarmQuizScreen has its own Scaffold with a smart back button (canPop check).
    // We wrap it in a Column so the simulation button sits below the quiz screen.
    return Column(
      children: [
        Expanded(
          child: FarmQuizScreen(
            role: widget.role,
            schoolName: widget.schoolName,
            classId: widget.classId,
          ),
        ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[50],
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _launchSimulation,
                icon: const Icon(Icons.play_circle, size: 24),
                label: const Text('Launch Farm Management Simulation',
                    style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}