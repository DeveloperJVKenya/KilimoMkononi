// lib/education/field/field_home.dart
import 'package:flutter/material.dart';
import 'package:kilimomkononi/models/education_user.dart';
import 'field_data_input.dart';
import 'field_quiz.dart';
import 'simulations/field_operations_simulation.dart';
import 'field_all_school_data.dart';
import 'package:kilimomkononi/education/edu_farm_conditions_screen.dart';

const Color primaryGreen = Color(0xFF032704);

class FieldHome extends StatefulWidget {
  final EduRole role;
  final String schoolName;
  final String classId;
  /// Set to false when FieldHome is embedded inside a parent screen
  /// that already provides an AppBar (e.g. education_home right-pane).
  final bool showAppBar;

  const FieldHome({
    super.key,
    required this.role,
    required this.schoolName,
    required this.classId,
    this.showAppBar = true,
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
          classId: widget.classId,
          module: 'field_operations',
          studentName: 'Student',
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
        EduFarmConditionsScreen(
          role:        widget.role,
          schoolName:  widget.schoolName,
          classId:     widget.classId,
          contentType: 'field_submissions',
        ),
      ];
      appBarTitle = _currentTab == 0 ? 'Field Data Entry'
          : _currentTab == 1 ? 'Field Quiz'
          : 'Farm Conditions';
    }

    return PopScope(
      // Android back gesture: on quiz tab → go to data tab first
      canPop: !(onQuizTab && isMobile),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() => _currentTab = 0);
      },
      child: Scaffold(
        appBar: widget.showAppBar
            ? AppBar(
                title: Text(appBarTitle),
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                automaticallyImplyLeading: false,
                leading: isMobile
                    ? (onQuizTab
                        ? IconButton(
                            icon: const Icon(Icons.arrow_back),
                            tooltip: 'Back to Field Data',
                            onPressed: () => setState(() => _currentTab = 0),
                          )
                        : IconButton(
                            icon: const Icon(Icons.arrow_back),
                            tooltip: 'Back',
                            onPressed: () => Navigator.of(context).pop(),
                          ))
                    : null,
              )
            : null,
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
                  if (i == 3) {
                    _launchSimulation();
                  } else if (i < 3) {
                    setState(() => _currentTab = i);
                  }
                },
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.note_add), label: 'Field Data'),
                  BottomNavigationBarItem(icon: Icon(Icons.quiz), label: 'Quiz'),
                  BottomNavigationBarItem(icon: Icon(Icons.sensors_rounded), label: 'Farm Data'),
                  BottomNavigationBarItem(icon: Icon(Icons.play_circle), label: 'Simulation'),
                ],
                selectedItemColor: primaryGreen,
                unselectedItemColor: Colors.grey,
                type: BottomNavigationBarType.fixed,
              ),
      ),
    );
  }
}