// lib/education/pest/disease_home.dart

import 'package:flutter/material.dart';
import 'package:kilimomkononi/models/education_user.dart';
import 'disease_data_input.dart';
import 'disease_quiz.dart';
import 'disease_simulation.dart';
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

  @override
  Widget build(BuildContext context) {
    final bool isHeadteacher = widget.role == EduRole.headteacher;

    late final List<Widget> tabs;
    late final List<BottomNavigationBarItem> navItems;
    late final String appBarTitle;

    if (isHeadteacher) {
      tabs = [
        DiseaseDataInput(
          role: widget.role,
          schoolName: widget.schoolName,
          classId: '',
          prefillData: null,
        ),
        PestDiseaseAllSchoolData(
          schoolName: widget.schoolName,
          contentType: 'disease_data',
        ),
      ];
      navItems = const [
        BottomNavigationBarItem(icon: Icon(Icons.visibility), label: 'View Form'),
        BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'All Entries'),
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
        DiseaseSimulationScreen(role: widget.role, schoolName: widget.schoolName, classId: widget.classId),
      ];
      navItems = const [
        BottomNavigationBarItem(icon: Icon(Icons.note_add), label: 'Disease Data'),
        BottomNavigationBarItem(icon: Icon(Icons.quiz), label: 'Quiz'),
        BottomNavigationBarItem(icon: Icon(Icons.science), label: 'Simulation'),
      ];
      appBarTitle = _currentTab == 0
          ? 'Disease Data Entry'
          : _currentTab == 1
              ? 'Disease Quiz'
              : 'Disease Simulation';
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