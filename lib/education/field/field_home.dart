// lib/education/field/field_home.dart

import 'package:flutter/material.dart';
import 'package:kilimomkononi/models/education_user.dart';
import 'field_data_input.dart';
import 'field_quiz.dart';
import 'field_simulation.dart';
import 'field_all_school_data.dart';

const Color primaryGreen = Color(0xFF032704);

class FieldHome extends StatefulWidget {
  final EduRole role;
  final String schoolName;
  final String classId;

  const FieldHome({
    super.key,
    required this.role,
    required this.schoolName,
    required this.classId,
  });

  @override
  State<FieldHome> createState() => _FieldHomeState();
}

class _FieldHomeState extends State<FieldHome> {
  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    final bool isHeadteacher = widget.role == EduRole.headteacher;

    late final List<Widget> tabs;
    late final List<BottomNavigationBarItem> navItems;
    late final String appBarTitle;

    if (isHeadteacher) {
      // Headteacher: 2 tabs
      tabs = [
        FieldDataInput(
          role: widget.role,
          schoolName: widget.schoolName,
          classId: '', // Read-only, classId not needed
        ),
        FieldAllSchoolData(
          schoolName: widget.schoolName, // Only schoolName needed for dropdown + data
        ),
      ];
      navItems = const [
        BottomNavigationBarItem(
          icon: Icon(Icons.visibility),
          label: 'View Form',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.list_alt),
          label: 'All Entries',
        ),
      ];
      appBarTitle = _currentTab == 0 ? 'View Field Data Form' : 'All School Entries';
    } else {
      // Teacher & Student: Original 3 tabs
      tabs = [
        FieldDataInput(
          role: widget.role,
          schoolName: widget.schoolName,
          classId: widget.classId,
        ),
        FieldQuizScreen(
          role: widget.role,
          schoolName: widget.schoolName,
          classId: widget.classId,
        ),
        FieldSimulationScreen(
          role: widget.role,
          schoolName: widget.schoolName,
          classId: widget.classId,
        ),
      ];
      navItems = const [
        BottomNavigationBarItem(icon: Icon(Icons.note_add), label: 'Field Data'),
        BottomNavigationBarItem(icon: Icon(Icons.quiz), label: 'Quiz'),
        BottomNavigationBarItem(icon: Icon(Icons.science), label: 'Simulation'),
      ];
      appBarTitle = _currentTab == 0
          ? 'Field Data Entry'
          : _currentTab == 1
              ? 'Field Quiz'
              : 'Field Simulation';
    }

    return WillPopScope(
      onWillPop: () async {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(appBarTitle),
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
        ),
        body: IndexedStack(
          index: _currentTab,
          children: tabs,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentTab,
          onTap: (index) => setState(() => _currentTab = index),
          items: navItems,
          selectedItemColor: primaryGreen,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
        ),
      ),
    );
  }
}