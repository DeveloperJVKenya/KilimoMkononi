// lib/education/farm_management/farm_management_screen.dart

import 'package:flutter/material.dart';
import 'package:kilimomkononi/education/farm_management/farm_management_data_input.dart';
import 'package:kilimomkononi/education/farm_management/tabs/learning_tab.dart';
import 'package:kilimomkononi/models/education_user.dart';

class FarmManagementScreen extends StatefulWidget {
  final EduRole role;
  final String classId;
  final String schoolName;
  /// Set to false when embedded inside a parent that already has an AppBar.
  final bool showAppBar;

  const FarmManagementScreen({
    super.key,
    required this.role,
    required this.classId,
    required this.schoolName,
    this.showAppBar = true,
  });

  @override
  State<FarmManagementScreen> createState() => _FarmManagementScreenState();
}

class _FarmManagementScreenState extends State<FarmManagementScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens;
  late final List<BottomNavigationBarItem> _navItems;

  @override
  void initState() {
    super.initState();

    final bool isHeadteacher = widget.role == EduRole.headteacher;

    if (isHeadteacher) {
      // Headteacher: Only Financials (read-only)
      _screens = [
        FarmManagementDataInput(
          role: widget.role,
          schoolName: widget.schoolName,
          classId: widget.classId,
        ),
      ];
      _navItems = const [
        BottomNavigationBarItem(
          icon: Icon(Icons.account_balance_wallet_outlined),
          activeIcon: Icon(Icons.account_balance_wallet),
          label: 'Financials',
        ),
      ];
    } else {
      // Teacher/Student: Financials + Learning
      _screens = [
        FarmManagementDataInput(
          role: widget.role,
          schoolName: widget.schoolName,
          classId: widget.classId,
        ),
        LearningTab(
          role: widget.role,
          classId: widget.classId,
          schoolName: widget.schoolName,
        ),
      ];
      _navItems = const [
        BottomNavigationBarItem(
          icon: Icon(Icons.account_balance_wallet_outlined),
          activeIcon: Icon(Icons.account_balance_wallet),
          label: 'Financials',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.school_outlined),
          activeIcon: Icon(Icons.school),
          label: 'Learning',
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar removed completely - title and tabs now come from farm_management_data_input.dart
      appBar: null,

      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),

      bottomNavigationBar: _navItems.length > 1 || widget.role != EduRole.headteacher
          ? BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              selectedItemColor: const Color(0xFF003900),
              unselectedItemColor: Colors.grey.shade600,
              selectedFontSize: 14,
              unselectedFontSize: 12,
              currentIndex: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
              items: _navItems,
            )
          : null,
    );
  }
}