// lib/education/pest/disease_home.dart

import 'package:flutter/material.dart';
import 'package:kilimomkononi/models/education_user.dart';
import 'disease_data_input.dart';
import 'disease_quiz.dart';
import 'simulations/disease_management_interactive_simulation.dart';
import 'pest_disease_all_school_data.dart';

const Color primaryGreen = Color(0xFF388E3C);

class DiseaseHome extends StatefulWidget {
  final EduRole role;
  final String schoolName;
  final String classId;
  final Map<String, String>? prefillData;

  const DiseaseHome({
    super.key,
    required this.role,
    required this.schoolName,
    required this.classId,
    this.prefillData,
  });

  @override
  State<DiseaseHome> createState() => _DiseaseHomeState();
}

class _DiseaseHomeState extends State<DiseaseHome> {
  int _currentTab = 0;

  void _launchSimulation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) => DiseaseManagementInteractiveSimulation(
          onComplete: () {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Disease management simulation completed! 🎉'),
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
    final bool isHeadteacher = widget.role == EduRole.headteacher;
    final bool _ = widget.role == EduRole.teacher;
    final double width = MediaQuery.of(context).size.width;
    final bool _ = width < 600;

    final bool _ = !isHeadteacher && _currentTab == 1;

    late final List<Widget> tabs;
    late final String appBarTitle;

    if (isHeadteacher) {
      tabs = [
        DiseaseDataInput(role: widget.role, schoolName: widget.schoolName, classId: '', prefillData: null),
        PestDiseaseAllSchoolData(schoolName: widget.schoolName, contentType: 'disease_data'),
      ];
      appBarTitle = _currentTab == 0 ? 'View Disease Form' : 'All Disease Entries';
    } else {
      tabs = [
        DiseaseDataInput(
          role: widget.role,
          schoolName: widget.schoolName,
          classId: widget.classId,
          prefillData: widget.prefillData,
        ),
        DiseaseQuizScreen(role: widget.role, schoolName: widget.schoolName, classId: widget.classId),
      ];
      appBarTitle = _currentTab == 0 ? 'Disease Data Entry' : 'Disease Quiz';
    }

    return Scaffold(
        appBar: AppBar(
          title: Text(appBarTitle),
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          // No back button - parent pest_disease_home has X button
        ),
      body: IndexedStack(index: _currentTab, children: tabs),
      bottomNavigationBar: isHeadteacher
          ? BottomNavigationBar(
              currentIndex: _currentTab,
              onTap: (i) => setState(() => _currentTab = i),
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.visibility), label: 'View Form'),
                BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'All Entries'),
              ],
              selectedItemColor: primaryGreen,
              unselectedItemColor: Colors.grey,
              type: BottomNavigationBarType.fixed,
            )
          : BottomNavigationBar(
              currentIndex: _currentTab,
              onTap: (i) {
                if (i == 2 ) {
                  _launchSimulation();
                } else if (i < 2) {
                  setState(() => _currentTab = i);
                }
              },
              items: [
                const BottomNavigationBarItem(icon: Icon(Icons.note_add), label: 'Disease Data'),
                const BottomNavigationBarItem(icon: Icon(Icons.quiz), label: 'Quiz'),
                const BottomNavigationBarItem(icon: Icon(Icons.play_circle), label: 'Simulation'),
              ],
              selectedItemColor: primaryGreen,
              unselectedItemColor: Colors.grey,
              type: BottomNavigationBarType.fixed,
            ),
    );
  }
}