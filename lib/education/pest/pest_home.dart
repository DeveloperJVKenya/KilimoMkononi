// lib/education/pest/pest_home.dart

import 'package:flutter/material.dart';
import 'package:kilimomkononi/models/education_user.dart';
import 'pest_data_input.dart';
import 'pest_quiz.dart';
import 'simulations/pest_management_interactive_simulation.dart';
import 'pest_disease_all_school_data.dart';
import 'edu_ai_photo_tab.dart';
import 'package:kilimomkononi/education/edu_farm_conditions_screen.dart';

const Color primaryGreen = Color(0xFF388E3C);

class PestHome extends StatefulWidget {
  final EduRole role;
  final String schoolName;
  final String classId;
  final Map<String, String>? prefillData;

  const PestHome({
    super.key,
    required this.role,
    required this.schoolName,
    required this.classId,
    this.prefillData,
  });

  @override
  State<PestHome> createState() => _PestHomeState();
}

class _PestHomeState extends State<PestHome> {
  int _currentTab = 0;
  Map<String, String>? _prefillFromAi;

  void _launchSimulation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) => PestManagementInteractiveSimulation(
          classId: widget.classId,
          module: 'pest',
          studentName: '',
          onComplete: () {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Pest management simulation completed! 🎉'),
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
        PestDataInput(role: widget.role, schoolName: widget.schoolName, classId: '', prefillData: null),
        PestDiseaseAllSchoolData(schoolName: widget.schoolName, contentType: 'pest_data'),
      ];
      appBarTitle = _currentTab == 0 ? 'View Pest Form' : 'All Pest Entries';
    } else {
      tabs = [
        PestDataInput(
          role: widget.role,
          schoolName: widget.schoolName,
          classId: widget.classId,
          prefillData: _prefillFromAi ?? widget.prefillData,
        ),
        PestQuizScreen(role: widget.role, schoolName: widget.schoolName, classId: widget.classId),
        EduAiPhotoTab(
          isPest: false,
          classId: widget.classId,
          schoolName: widget.schoolName,
          onPrefill: (data) {
            setState(() {
              _prefillFromAi = data;
              _currentTab = 0;
            });
          },
        ),
        EduFarmConditionsScreen(
          role:        widget.role,
          schoolName:  widget.schoolName,
          classId:     widget.classId,
          contentType: 'pest_data',
        ),
      ];
      appBarTitle = _currentTab == 0
          ? 'Pest Data Entry'
          : _currentTab == 1
              ? 'Pest Quiz'
              : _currentTab == 2
                  ? 'AI Photo Diagnosis'
                  : 'Farm Conditions';
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
                if (i == 4) {
                  _launchSimulation();
                } else {
                  setState(() => _currentTab = i);
                }
              },
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.note_add), label: 'Pest Data'),
                BottomNavigationBarItem(icon: Icon(Icons.quiz), label: 'Quiz'),
                BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: 'AI Photo'),
                BottomNavigationBarItem(icon: Icon(Icons.sensors_rounded), label: 'Farm Data'),
                BottomNavigationBarItem(icon: Icon(Icons.play_circle), label: 'Simulation'),
              ],
              selectedItemColor: primaryGreen,
              unselectedItemColor: Colors.grey,
              type: BottomNavigationBarType.fixed,
            ),
    );
  }
}