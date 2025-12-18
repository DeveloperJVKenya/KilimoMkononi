// lib/education/pest/pest_home.dart

import 'package:flutter/material.dart';
import 'package:kilimomkononi/models/education_user.dart';
import 'pest_data_input.dart';
import 'pest_quiz.dart';
import 'pest_simulation.dart';
import 'pest_disease_all_school_data.dart';

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

  @override
  Widget build(BuildContext context) {
    final bool isHeadteacher = widget.role == EduRole.headteacher;

    late final List<Widget> tabs;
    late final List<BottomNavigationBarItem> navItems;
    late final String appBarTitle;

    if (isHeadteacher) {
      tabs = [
        PestDataInput(
          role: widget.role,
          schoolName: widget.schoolName,
          classId: '',
          prefillData: null,
        ),
        PestDiseaseAllSchoolData(
          schoolName: widget.schoolName,
          contentType: 'pest_data',
        ),
      ];
      navItems = const [
        BottomNavigationBarItem(icon: Icon(Icons.visibility), label: 'View Form'),
        BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'All Entries'),
      ];
      appBarTitle = _currentTab == 0 ? 'View Pest Form' : 'All Pest Entries';
    } else {
      tabs = [
        PestDataInput(
          role: widget.role,
          schoolName: widget.schoolName,
          classId: widget.classId,
          prefillData: widget.prefillData,
        ),
        PestQuizScreen(role: widget.role, schoolName: widget.schoolName, classId: widget.classId),
        PestSimulationScreen(role: widget.role, schoolName: widget.schoolName, classId: widget.classId),
      ];
      navItems = const [
        BottomNavigationBarItem(icon: Icon(Icons.note_add), label: 'Pest Data'),
        BottomNavigationBarItem(icon: Icon(Icons.quiz), label: 'Quiz'),
        BottomNavigationBarItem(icon: Icon(Icons.science), label: 'Simulation'),
      ];
      appBarTitle = _currentTab == 0
          ? 'Pest Data Entry'
          : _currentTab == 1
              ? 'Pest Quiz'
              : 'Pest Simulation';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // Removes the back arrow completely
      ),
      body: IndexedStack(
        index: _currentTab,
        children: tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (i) => setState(() => _currentTab = i),
        items: navItems,
        selectedItemColor: primaryGreen,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}