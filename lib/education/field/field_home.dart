// lib/education/field/field_home.dart

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:kilimomkononi/models/education_user.dart';
import 'field_data_input.dart';
import 'field_quiz.dart';
import 'simulations/field_operations_simulation.dart';
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

  void _launchSimulation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) => FieldOperationsSimulation(
          onComplete: () {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Field operations simulation completed! 🎉'),
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
    final bool isMobile = width < 600;

    // When on the quiz tab, back button goes to data entry (not menu)
    final bool onQuizTab = !isHeadteacher && _currentTab == 1;

    late final List<Widget> tabs;
    late final String appBarTitle;

    if (isHeadteacher) {
      tabs = [
        FieldDataInput(role: widget.role, schoolName: widget.schoolName, classId: ''),
        FieldAllSchoolData(schoolName: widget.schoolName),
      ];
      appBarTitle = _currentTab == 0 ? 'View Field Data Form' : 'All School Entries';
    } else {
      tabs = [
        FieldDataInput(role: widget.role, schoolName: widget.schoolName, classId: widget.classId),
        FieldQuizScreen(role: widget.role, schoolName: widget.schoolName, classId: widget.classId),
      ];
      appBarTitle = _currentTab == 0 ? 'Field Data Entry' : 'Field Quiz';
    }

    return WillPopScope(
      onWillPop: () async {
        // Android back gesture: on quiz tab → go to data tab first
        if (onQuizTab && isMobile) {
          setState(() => _currentTab = 0);
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(appBarTitle),
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          leading: isMobile
              ? (onQuizTab
                  // Quiz tab → back to data entry tab
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Back to Field Data',
                      onPressed: () => setState(() => _currentTab = 0),
                    )
                  // Data tab → back to menu/sidebar
                  : IconButton(
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).pop(),
                    ))
              : null, // Desktop/tablet: sidebar handles navigation
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
                  if (i == 2) {
                    _launchSimulation();
                  } else if (i < 2) {
                    setState(() => _currentTab = i);
                  }
                },
                items: [
                  const BottomNavigationBarItem(icon: Icon(Icons.note_add), label: 'Field Data'),
                  const BottomNavigationBarItem(icon: Icon(Icons.quiz), label: 'Quiz'),
                  const BottomNavigationBarItem(icon: Icon(Icons.play_circle), label: 'Simulation'),
                ],
                selectedItemColor: primaryGreen,
                unselectedItemColor: Colors.grey,
                type: BottomNavigationBarType.fixed,
              ),
      ),
    );
  }
}