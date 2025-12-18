// lib/education/farm_management/tabs/learning_tab.dart
import 'package:flutter/material.dart';
import 'package:kilimomkononi/models/education_user.dart';
import '../farm_quiz.dart';
import '../farm_simulation.dart';

class LearningTab extends StatefulWidget {
  final EduRole role;
  final String classId;
  final String schoolName;

  const LearningTab({
    super.key,
    required this.role,
    required this.schoolName,
    required this.classId,
  });

  @override
  State<LearningTab> createState() => _LearningTabState();
}

class _LearningTabState extends State<LearningTab> {
  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Removed AppBar → no more double header!
      body: SafeArea(
        child: IndexedStack(
          index: _currentTab,
          children: [
            // These now have their own AppBar only when opened alone
            FarmQuizScreen(
              role: widget.role,
              schoolName: widget.schoolName,
              classId: widget.classId,
            ),
            FarmSimulationScreen(
              role: widget.role,
              schoolName: widget.schoolName,
              classId: widget.classId,
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        selectedItemColor: const Color(0xFF003900),
        unselectedItemColor: Colors.grey,
        onTap: (i) => setState(() => _currentTab = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.quiz), label: 'Quiz'),
          BottomNavigationBarItem(icon: Icon(Icons.science), label: 'Simulation'),
        ],
      ),
    );
  }
}