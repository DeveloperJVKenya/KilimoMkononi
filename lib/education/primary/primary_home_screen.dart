// lib/education/primary/primary_home_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:kilimomkononi/education/approval_management_screen.dart';
import 'package:kilimomkononi/education/education_login.dart';
import 'package:kilimomkononi/education/education_resources.dart';
import 'package:kilimomkononi/education/education_chat.dart';
import 'package:kilimomkononi/education/teacher/view_students.dart';
import 'package:kilimomkononi/education/utils/class_id_notifier.dart';
import 'package:kilimomkononi/models/education_user.dart';
import 'package:kilimomkononi/screens/user_profile.dart';
import 'package:kilimomkononi/settings/settings_screen.dart';

// ── Topic feature screens (lib/education/primary/features/) ──────────────
import 'package:kilimomkononi/education/primary/features/primary_seeds_plants.dart';
import 'package:kilimomkononi/education/primary/features/primary_farming_tools.dart';
import 'package:kilimomkononi/education/primary/features/primary_weeds_pests.dart';
import 'package:kilimomkononi/education/primary/features/primary_farm_animals.dart';
import 'package:kilimomkononi/education/primary/features/primary_soil_water.dart';
import 'package:kilimomkononi/education/primary/features/primary_buying_selling.dart';
import 'package:kilimomkononi/education/primary/features/primary_farming_story.dart';

// ── AI activity widgets (lib/education/primary/ai/) ───────────────────────
import 'package:kilimomkononi/education/primary/ai/primary_mini_quiz_sheet.dart';
import 'package:kilimomkononi/education/primary/ai/primary_what_am_i_sheet.dart';
import 'package:kilimomkononi/education/primary/ai/primary_fill_blank_sheet.dart';
import 'package:kilimomkononi/education/primary/ai/primary_lesson_plan_sheet.dart';
import 'package:kilimomkononi/education/primary/ai/primary_class_summary_sheet.dart';
import 'package:kilimomkononi/education/primary/ai/primary_daily_challenge_service.dart';
import 'package:kilimomkononi/education/primary/ai/primary_progress_service.dart';

// ─────────────────────────────────────────────────────────────────
//  Topic definition (used by sidebar + grid + daily challenge)
// ─────────────────────────────────────────────────────────────────
class _Topic {
  final String id, label, description;
  final IconData icon;
  final Color color, lightColor;
  const _Topic({
    required this.id, required this.label, required this.description,
    required this.icon, required this.color, required this.lightColor,
  });
}

const _topics = [
  _Topic(id: 'seeds_plants',  label: 'Seeds & Plants',
    description: 'How seeds grow into plants', icon: Icons.eco,
    color: Color(0xFF2E7D32), lightColor: Color(0xFFE8F5E9)),
  _Topic(id: 'farming_tools', label: 'Farming Tools',
    description: 'Tools farmers use every day', icon: Icons.hardware,
    color: Color(0xFFBF360C), lightColor: Color(0xFFFBE9E7)),
  _Topic(id: 'weeds_pests',   label: 'Weeds & Pests',
    description: 'Plants and bugs that harm crops', icon: Icons.bug_report,
    color: Color(0xFF558B2F), lightColor: Color(0xFFF1F8E9)),
  _Topic(id: 'farm_animals',  label: 'Farm Animals',
    description: 'Animals that live on the farm', icon: Icons.pets,
    color: Color(0xFFE65100), lightColor: Color(0xFFFFF3E0)),
  _Topic(id: 'soil_water',    label: 'Soil & Water',
    description: 'Types of soil and watering crops', icon: Icons.water_drop,
    color: Color(0xFF0277BD), lightColor: Color(0xFFE1F5FE)),
  _Topic(id: 'buying_selling',label: 'Buying & Selling',
    description: 'How farmers sell their harvest', icon: Icons.storefront,
    color: Color(0xFF6A1B9A), lightColor: Color(0xFFF3E5F5)),
];

enum _ScreenType { mobile, tablet, desktop }

// ─────────────────────────────────────────────────────────────────
//  PrimaryHomeScreen
// ─────────────────────────────────────────────────────────────────
class PrimaryHomeScreen extends StatefulWidget {
  const PrimaryHomeScreen({super.key});
  @override
  State<PrimaryHomeScreen> createState() => _PrimaryHomeScreenState();
}

class _PrimaryHomeScreenState extends State<PrimaryHomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _animCtrl;

  Map<String, dynamic>? _userData;
  Uint8List? _profileImageBytes;
  bool _isLoading = true;
  String? _errorMessage;
  EduRole? _role;
  bool _featuresLocked = true;

  final ValueNotifier<int> _studentCount = ValueNotifier(0);
  StreamSubscription<QuerySnapshot>? _studentSub;
  Widget? _selectedFeature;
  int _selectedBottomIndex = 0;
  int _selectedRailIndex   = -1;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this);
    _fetchUserData();
    classIdNotifier.addListener(() {
      if (mounted) { setState(() {}); _refreshContent(); }
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    classIdNotifier.removeListener(_refreshContent);
    _studentCount.dispose();
    _studentSub?.cancel();
    super.dispose();
  }

  // ── Data ─────────────────────────────────────────────────────────
  Future<void> _fetchUserData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) { setState(() => _errorMessage = 'Not logged in.'); return; }

      final snap = await FirebaseFirestore.instance
          .collection('EducationUsers').doc(user.uid).get();
      if (!snap.exists) {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const EducationLoginScreen()));
        }
        return;
      }

      final data = snap.data()!;
      if (data['isDisabled'] == true) {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => const EducationLoginScreen()));
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Account disabled.')));
        }
        return;
      }

      Uint8List? imgBytes;
      final b64 = data['profileImage'] as String?;
      if (b64 != null && b64.isNotEmpty) {
        try { imgBytes = base64Decode(b64); } catch (_) {}
      }

      final roleStr    = data['role'] as String?;
      final parsedRole = roleStr != null
          ? EduRole.values.firstWhere((e) => e.name == roleStr, orElse: () => EduRole.student)
          : null;

      final statusStr = data['approvalStatus'] as String?;
      final status    = statusStr != null
          ? ApprovalStatus.values.firstWhere((e) => e.name == statusStr, orElse: () => ApprovalStatus.pending)
          : ApprovalStatus.pending;

      setState(() {
        _userData       = data;
        _profileImageBytes = imgBytes;
        _role           = parsedRole;
        _featuresLocked = parsedRole == null || status != ApprovalStatus.approved;
        _isLoading      = false;
      });

      final classId = data['currentClassId'] as String?;
      if (classIdNotifier.value == null && classId != null) classIdNotifier.value = classId;
      _refreshContent();
    } catch (e) {
      setState(() { _errorMessage = 'Failed to load: $e'; _isLoading = false; });
    }
  }

  void _refreshContent() {
    final id = classIdNotifier.value;
    if (id == null || _featuresLocked) { _studentCount.value = 0; return; }
    if (_role == EduRole.teacher) _listenStudentCount(id);
  }

  void _listenStudentCount(String classId) {
    _studentSub?.cancel();
    if (_userData?['schoolName'] == null) return;
    _studentSub = FirebaseFirestore.instance
        .collection('EducationUsers')
        .where('role', isEqualTo: 'student')
        .where('schoolName', isEqualTo: _userData!['schoolName'])
        .where('currentClassId', isEqualTo: classId)
        .snapshots()
        .listen((snap) { if (mounted) _studentCount.value = snap.size; });
  }

  Future<void> _handleLogout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => const EducationLoginScreen()));
    }
  }

  Future<void> _editProfile() async {
    if (_userData == null || _role == null) return;
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => UserProfileScreen(
        profileImageBytes: _profileImageBytes,
        fullName:    _userData?['fullName'],
        schoolName:  _userData?['schoolName'],
        role:        _role!.name,
      ),
    )).then((_) => _fetchUserData());
  }

  void _switchClass() {
    final schoolName = _userData?['schoolName'] ?? '';
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _PrimaryClassPickerSheet(
        schoolName:     schoolName,
        currentClassId: classIdNotifier.value,
        onClassSelected: (classId) async {
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid == null) return;
          try {
            final ref = FirebaseFirestore.instance.collection('EducationUsers').doc(uid);
            await FirebaseFirestore.instance.runTransaction((tx) async {
              final snap = await tx.get(ref);
              if (!snap.exists) return;
              final data = snap.data()!;
              final ids  = List<String>.from(data['classIds'] ?? []);
              if (!ids.contains(classId)) ids.add(classId);
              tx.update(ref, {
                'currentClassId':  classId,
                'classIds':        ids,
                'lastClassSwitch': FieldValue.serverTimestamp(),
              });
            });
          } catch (_) {}
          classIdNotifier.value = classId;
          final isPrimary = classId.toLowerCase().contains('_primary_');
          if (!isPrimary && mounted) {
            Navigator.of(context).pushReplacementNamed('/edu_home');
          } else if (mounted) { setState(() {}); }
        },
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────
  String _capitalize(String s) =>
      s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}' : s;

  String _formatGradeDisplay(String? classId) {
    if (classId == null || classId.isEmpty) return 'Not selected';
    final m = RegExp(r'_(\w+)_(\d+)$').firstMatch(classId.toLowerCase());
    if (m != null) {
      final sys = m.group(1)!; final num = m.group(2)!;
      if (sys == 'eightfourfour') return 'Form $num';
      return 'Grade $num';
    }
    return classId;
  }

  String get _grade {
    final classId = classIdNotifier.value ?? '';
    final m = RegExp(r'_(\d+)$').firstMatch(classId);
    return m != null ? 'Grade ${m.group(1)}' : 'Grade 3';
  }

  _ScreenType _getScreenType(BuildContext ctx) {
    final w = MediaQuery.of(ctx).size.width;
    if (w < 600)  return _ScreenType.mobile;
    if (w < 1200) return _ScreenType.tablet;
    return _ScreenType.desktop;
  }

  void _openScreen(Widget page) {
    if (_getScreenType(context) == _ScreenType.mobile) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    } else {
      setState(() { _selectedFeature = page; _selectedRailIndex = -1; });
    }
  }

  void _openFromSidebar(Widget page, {bool fromDrawer = false}) {
    if (fromDrawer) Navigator.pop(context);
    _openScreen(page);
  }

  /// Builds the correct topic screen for a given topic id.
  Widget _screenForId(String id, String schoolName, String classId) {
    switch (id) {
      case 'seeds_plants':
        return PrimarySeedsPlantsScreen(role: _role ?? EduRole.student,
            schoolName: schoolName, classId: classId);
      case 'farming_tools':
        return PrimaryFarmingToolsScreen(role: _role ?? EduRole.student,
            schoolName: schoolName, classId: classId);
      case 'weeds_pests':
        return PrimaryWeedsPestsScreen(role: _role ?? EduRole.student,
            schoolName: schoolName, classId: classId);
      case 'farm_animals':
        return PrimaryFarmAnimalsScreen(role: _role ?? EduRole.student,
            schoolName: schoolName, classId: classId);
      case 'soil_water':
        return PrimarySoilWaterScreen(role: _role ?? EduRole.student,
            schoolName: schoolName, classId: classId);
      case 'buying_selling':
        return PrimaryBuyingSellingScreen(role: _role ?? EduRole.student,
            schoolName: schoolName, classId: classId);
      default:
        return _PrimaryCategoryScreen(
            topic: _topics.firstWhere((t) => t.id == id,
                orElse: () => _topics.first),
            schoolName: schoolName, classId: classId);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_errorMessage != null) {
      return Scaffold(body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_errorMessage!), const SizedBox(height: 16),
        ElevatedButton(onPressed: _fetchUserData, child: const Text('Retry')),
      ])));
    }

    final screenType = _getScreenType(context);
    final schoolName = _userData?['schoolName'] ?? 'Unknown School';
    final fullName   = _userData?['fullName']   ?? 'User';

    final appBar = AppBar(
      backgroundColor: const Color(0xFF003900),
      foregroundColor: Colors.white,
      centerTitle: true,
      title: const Text('Kilimomkononi Education'),
      automaticallyImplyLeading: screenType == _ScreenType.mobile,
      actions: [
        if (_role == EduRole.teacher || _role == EduRole.headteacher)
          TextButton.icon(
            onPressed: _switchClass,
            icon: const Icon(Icons.swap_horiz, color: Colors.white70, size: 18),
            label: const Text('Switch Class',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
          ),
      ],
    );

    final body = _featuresLocked
        ? _buildPendingScreen(schoolName, fullName)
        : _buildDashboard(schoolName, fullName);

    final mainBody = screenType == _ScreenType.mobile
        ? body
        : Row(children: [
            _buildLeftRail(schoolName, screenType),
            Expanded(child: _selectedFeature ?? body),
          ]);

    return Scaffold(
      appBar: appBar,
      drawer: screenType == _ScreenType.mobile ? _buildDrawer(schoolName) : null,
      body:   mainBody,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Bottom nav ────────────────────────────────────────────────────
  Widget _buildBottomNav() => BottomNavigationBar(
    backgroundColor:      const Color(0xFF003900),
    selectedItemColor:    Colors.white,
    unselectedItemColor:  Colors.white70,
    currentIndex:         _selectedBottomIndex,
    type: BottomNavigationBarType.fixed,
    onTap: (i) {
      setState(() { _selectedBottomIndex = i; _selectedFeature = null; });
      final sn  = _userData?['schoolName'] ?? '';
      final cid = classIdNotifier.value ?? '';
      if (i == 1) {
        _openScreen(EducationResources(
          role: _role ?? EduRole.student, schoolName: sn, classId: cid));
      } else if (i == 2) {
        _openScreen(EducationChat(
          role: _role ?? EduRole.student, schoolName: sn, classId: cid,
          userName: _userData?['fullName'] ?? 'User'));
      }
    },
    items: const [
      BottomNavigationBarItem(icon: Icon(Icons.home),        label: 'Home'),
      BottomNavigationBarItem(icon: Icon(Icons.folder),      label: 'Resources'),
      BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'Chat'),
    ],
  );

  // ── Drawer (mobile) — white bg so text is visible ─────────────────
  Widget _buildDrawer(String schoolName) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
          color: const Color(0xFF003900),
          child: Column(children: [
            GestureDetector(
              onTap: _editProfile,
              child: CircleAvatar(
                radius: 42,
                backgroundImage: _profileImageBytes != null
                    ? MemoryImage(_profileImageBytes!) : null,
                child: _profileImageBytes == null
                    ? const Icon(Icons.person, size: 50, color: Colors.white70) : null,
              ),
            ),
            const SizedBox(height: 10),
            Text(_userData?['fullName'] ?? 'User', textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 17,
                    fontWeight: FontWeight.bold)),
            Text('${_capitalize(_role?.name ?? 'User')} • $schoolName',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center),
          ]),
        ),
        Expanded(child: ListView(padding: EdgeInsets.zero, children: [
          ..._sidebarItems(schoolName, fromDrawer: true),
          const Divider(height: 1, color: Color(0xFFE0E0E0)),
          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xFF555555)),
            title: const Text('Logout', style: TextStyle(color: Color(0xFF222222))),
            onTap: _handleLogout,
          ),
        ])),
      ]),
    );
  }

  // ── Left rail (tablet/desktop) ────────────────────────────────────
  Widget _buildLeftRail(String schoolName, _ScreenType type) {
    final width = type == _ScreenType.desktop ? 280.0 : 240.0;
    return Container(
      width: width, color: const Color(0xFF003900),
      child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
          child: GestureDetector(onTap: _editProfile, child: Column(children: [
            CircleAvatar(radius: 40,
              backgroundImage: _profileImageBytes != null
                  ? MemoryImage(_profileImageBytes!) : null,
              child: _profileImageBytes == null
                  ? const Icon(Icons.person, size: 48, color: Colors.white70) : null),
            const SizedBox(height: 10),
            Text(_userData?['fullName'] ?? 'User', textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15,
                    fontWeight: FontWeight.bold)),
            Text('${_capitalize(_role?.name ?? 'User')} • $schoolName',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center),
          ]))),
        const Divider(color: Colors.white24),
        Expanded(child: ListView(children: [
          ..._sidebarItems(schoolName),
          const Divider(color: Colors.white24),
          _railItem(Icons.logout, 'Logout', 99, _handleLogout),
          const SizedBox(height: 16),
        ])),
      ]),
    );
  }

  // ── Sidebar items — two modes ─────────────────────────────────────
  List<Widget> _sidebarItems(String schoolName, {bool fromDrawer = false}) {
    final classId    = classIdNotifier.value ?? '';
    final isTeacher  = _role == EduRole.teacher || _role == EduRole.headteacher;

    if (fromDrawer) {
      return [
        _drawerLabel('TOPICS'),
        ..._topics.map((t) => ListTile(
          leading:  Icon(t.icon, color: t.color, size: 22),
          title:    Text(t.label,       style: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 14)),
          subtitle: Text(t.description, style: const TextStyle(color: Color(0xFF777777), fontSize: 11)),
          onTap:    () => _openFromSidebar(_screenForId(t.id, schoolName, classId), fromDrawer: true),
        )),
        ListTile(
          leading:  const Icon(Icons.auto_stories, color: Color(0xFF2E7D32), size: 22),
          title:    const Text('Farming Stories 📖', style: TextStyle(color: Color(0xFF1A1A1A), fontSize: 14)),
          subtitle: const Text('Read and answer a story',  style: TextStyle(color: Color(0xFF777777), fontSize: 11)),
          onTap: () => _openFromSidebar(
              PrimaryFarmingStoryScreen(strand: 'Farming in Kenya', grade: _grade), fromDrawer: true),
        ),
        // Teacher-only: weekly summary
        if (isTeacher && classId.isNotEmpty)
          ListTile(
            leading:  const Icon(Icons.bar_chart_rounded, color: Color(0xFF003900), size: 22),
            title:    const Text('Class Summary', style: TextStyle(color: Color(0xFF1A1A1A), fontSize: 14)),
            subtitle: const Text('This week\'s AI analysis', style: TextStyle(color: Color(0xFF777777), fontSize: 11)),
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet(context: context, isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => DraggableScrollableSheet(
                  initialChildSize: 0.85, maxChildSize: 0.95, minChildSize: 0.4,
                  builder: (_, sc) => PrimaryClassSummarySheet(
                      classId: classId, grade: _grade, schoolName: schoolName)));
            },
          ),
        _drawerLabel('GENERAL'),
        ListTile(
          leading: const Icon(Icons.folder,   color: Color(0xFF555555), size: 22),
          title:   const Text('Resources', style: TextStyle(color: Color(0xFF1A1A1A), fontSize: 14)),
          onTap: () => _openFromSidebar(EducationResources(role: _role ?? EduRole.student,
              schoolName: schoolName, classId: classId), fromDrawer: true),
        ),
        ListTile(
          leading: const Icon(Icons.chat,     color: Color(0xFF555555), size: 22),
          title:   const Text('Chat',      style: TextStyle(color: Color(0xFF1A1A1A), fontSize: 14)),
          onTap: () => _openFromSidebar(EducationChat(role: _role ?? EduRole.student,
              schoolName: schoolName, classId: classId,
              userName: _userData?['fullName'] ?? 'User'), fromDrawer: true),
        ),
        ListTile(
          leading: const Icon(Icons.settings, color: Color(0xFF555555), size: 22),
          title:   const Text('Settings',  style: TextStyle(color: Color(0xFF1A1A1A), fontSize: 14)),
          onTap: () => _openFromSidebar(const SettingsScreen(isEducation: true), fromDrawer: true),
        ),
      ];
    } else {
      // Rail (tablet/desktop) — white text on dark
      return [
        _railLabel('TOPICS'),
        ..._topics.asMap().entries.map((e) => _railItem(e.value.icon, e.value.label, e.key,
            () => _openFromSidebar(_screenForId(e.value.id, schoolName, classId)))),
        _railItem(Icons.auto_stories, 'Farming Stories', 8,
            () => _openFromSidebar(PrimaryFarmingStoryScreen(
                strand: 'Farming in Kenya', grade: _grade))),
        if (isTeacher && classId.isNotEmpty)
          _railItem(Icons.bar_chart_rounded, 'Class Summary', 9, () {
            showModalBottomSheet(context: context, isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => DraggableScrollableSheet(
                initialChildSize: 0.85, maxChildSize: 0.95, minChildSize: 0.4,
                builder: (_, sc) => PrimaryClassSummarySheet(
                    classId: classId, grade: _grade, schoolName: schoolName)));
          }),
        _railLabel('GENERAL'),
        _railItem(Icons.folder,   'Resources', 10, () => _openFromSidebar(
            EducationResources(role: _role ?? EduRole.student,
                schoolName: schoolName, classId: classId))),
        _railItem(Icons.chat,     'Chat',      11, () => _openFromSidebar(
            EducationChat(role: _role ?? EduRole.student, schoolName: schoolName,
                classId: classId, userName: _userData?['fullName'] ?? 'User'))),
        _railItem(Icons.settings, 'Settings',  12,
            () => _openFromSidebar(const SettingsScreen(isEducation: true))),
      ];
    }
  }

  Widget _drawerLabel(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
    child: Text(text, style: const TextStyle(color: Color(0xFF999999),
        fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)));

  Widget _railLabel(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
    child: Text(text, style: const TextStyle(color: Colors.white54,
        fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)));

  Widget _railItem(IconData icon, String title, int index, VoidCallback onTap) {
    final selected = _selectedRailIndex == index;
    return ListTile(
      leading:    Icon(icon, color: selected ? Colors.yellow : Colors.white70),
      title:      Text(title, style: TextStyle(
          color: selected ? Colors.yellow : Colors.white, fontSize: 14)),
      selected:   selected,
      selectedTileColor: Colors.white10,
      onTap: () { setState(() => _selectedRailIndex = index); onTap(); },
    );
  }

  // ── Pending screen ────────────────────────────────────────────────
  Widget _buildPendingScreen(String schoolName, String fullName) =>
      SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(16),
        child: Column(children: [
          Card(elevation: 6, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(colors: [Color(0xFF43A047), Color(0xFF66BB6A)])),
              child: Text('Hello, $fullName!\nYour account is being reviewed.',
                  style: const TextStyle(color: Colors.white, fontSize: 20,
                      fontWeight: FontWeight.bold)))),
          const SizedBox(height: 32),
          Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const Padding(padding: EdgeInsets.all(24), child: Column(children: [
              Icon(Icons.hourglass_top, size: 64, color: Colors.orange),
              SizedBox(height: 16),
              Text('Approval Pending', style: TextStyle(fontSize: 22,
                  fontWeight: FontWeight.bold, color: Colors.orange)),
              SizedBox(height: 8),
              Text('Your account is awaiting approval.', textAlign: TextAlign.center),
            ]))),
        ])));

  // ── Main dashboard ────────────────────────────────────────────────
  Widget _buildDashboard(String schoolName, String fullName) {
    final isTeacher = _role == EduRole.teacher || _role == EduRole.headteacher;
    final classId   = classIdNotifier.value ?? '';

    return SingleChildScrollView(
      child: Padding(padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Welcome card ─────────────────────────────────────────
          Card(elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                    colors: [Color(0xFF43A047), Color(0xFF66BB6A)])),
              child: Column(children: [
                Row(children: [
                  Lottie.asset(
                    isTeacher ? 'assets/lottie/learning.json'
                              : 'assets/lottie/hello_student.json',
                    controller: _animCtrl,
                    onLoaded: (comp) { _animCtrl..duration = comp.duration..repeat(); },
                    height: 130,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.school, size: 80, color: Colors.white54),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Hello, ${fullName.split(' ').first}!',
                        style: const TextStyle(fontSize: 26,
                            fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 8),
                    const Text('Kilimomkononi Primary Education',
                        style: TextStyle(fontSize: 13, color: Colors.white70)),
                    const SizedBox(height: 6),
                    Text(isTeacher ? 'Ready to inspire today? 🌟' : 'Ready to learn today? 🌱',
                        style: const TextStyle(fontSize: 15, color: Colors.white70)),
                  ])),
                ]),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white24,
                      borderRadius: BorderRadius.circular(20)),
                  child: Text('${_capitalize(_role?.name ?? 'User')} • $schoolName',
                      style: const TextStyle(color: Colors.white)),
                ),
                if (classIdNotifier.value != null)
                  Padding(padding: const EdgeInsets.only(top: 8),
                    child: GestureDetector(
                      onTap: isTeacher ? _switchClass : null,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('Class: ${_formatGradeDisplay(classIdNotifier.value)}',
                            style: const TextStyle(color: Colors.white, fontSize: 15)),
                        if (isTeacher) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.swap_horiz, color: Colors.white70, size: 16),
                        ],
                      ]),
                    )),
              ]),
            )),
          const SizedBox(height: 20),

          // ── Teacher: approval + class switch + students ───────────
          if (isTeacher) ...[
            _buildApprovalCard(schoolName),
            const SizedBox(height: 16),
            _buildClassSwitchButton(schoolName),
            const SizedBox(height: 16),
          ],
          if (isTeacher && classId.isNotEmpty) ...[
            _buildViewStudentsCard(schoolName),
            const SizedBox(height: 20),
          ],

          // ─────────────────────────────────────────────────────────
          //  PHASE 3 ADDITIONS BELOW
          // ─────────────────────────────────────────────────────────

          // ── Teacher: weekly class summary card ────────────────────
          if (isTeacher && classId.isNotEmpty) ...[
            _sectionHeader('📊 Class summary', 'AI analysis of this week\'s activity'),
            const SizedBox(height: 10),
            _buildWeeklySummaryCard(classId, schoolName),
            const SizedBox(height: 20),
          ],

          // ── Daily challenge (all users) ───────────────────────────
          if (!_featuresLocked && classId.isNotEmpty) ...[
            _sectionHeader('🔥 Daily challenge', 'Same challenge for your whole class today'),
            const SizedBox(height: 10),
            _PrimaryDailyChallengeBanner(classId: classId, grade: _grade),
            const SizedBox(height: 20),
          ],

          // ── Student: today's stars earned ────────────────────────
          if (!_featuresLocked && !isTeacher) ...[
            const _PrimaryTodayStarsBanner(),
          ],

          // ── Activities horizontal scroll ──────────────────────────
          if (!_featuresLocked && classId.isNotEmpty) ...[
            _sectionHeader('🎯 Activities', 'Test what you\'ve learned in each topic'),
            const SizedBox(height: 10),
            _buildActivityRow(classId),
            const SizedBox(height: 20),
          ],

          // ── Farming Stories ────────────────────────────────────────
          if (!_featuresLocked) ...[
            _sectionHeader('📖 Farming Stories', 'Read a story, answer the question'),
            const SizedBox(height: 10),
            _buildStoriesCard(),
            const SizedBox(height: 20),
          ],

          // ── Topic grid ─────────────────────────────────────────────
          if (!_featuresLocked) ...[
            _sectionHeader('📚 Topics', isTeacher
                ? 'Tap to open · Hold for lesson plan'
                : 'Tap a topic to start learning'),
            const SizedBox(height: 10),
            _buildTopicGrid(schoolName, classId, isTeacher),
            const SizedBox(height: 32),
          ],

          if (_featuresLocked)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200)),
              child: Row(children: [
                Icon(Icons.menu, color: Colors.green.shade700, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  'Tap ☰ to explore topics: Seeds, Tools, Animals and more!',
                  style: TextStyle(fontSize: 13, color: Colors.green.shade800, height: 1.4))),
              ]),
            ),
          const SizedBox(height: 80),
        ]),
      ),
    );
  }

  // ── Section header ────────────────────────────────────────────────
  Widget _sectionHeader(String title, String sub) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A))),
        Text(sub, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      ]);

  // ── Teacher: weekly summary card ──────────────────────────────────
  Widget _buildWeeklySummaryCard(String classId, String schoolName) =>
      GestureDetector(
        onTap: () => showModalBottomSheet(
          context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
          builder: (_) => DraggableScrollableSheet(
            initialChildSize: 0.85, maxChildSize: 0.95, minChildSize: 0.4,
            builder: (_, sc) => PrimaryClassSummarySheet(
                classId: classId, grade: _grade, schoolName: schoolName))),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF003900).withValues(alpha: 0.2)),
            boxShadow: [BoxShadow(color: const Color(0xFF003900).withValues(alpha: 0.05),
                blurRadius: 6, offset: const Offset(0,3))]),
          child: Row(children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(color: const Color(0xFF003900).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.bar_chart_rounded, color: Color(0xFF003900), size: 24)),
            const SizedBox(width: 14),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("This week's class summary", style: TextStyle(fontSize: 14,
                  fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
              Text('AI analysis of quiz scores and activity completion',
                  style: TextStyle(fontSize: 12, color: Color(0xFF777777))),
            ])),
            Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400, size: 14),
          ]),
        ),
      );

  // ── Activities horizontal scroll ──────────────────────────────────
  Widget _buildActivityRow(String classId) => SizedBox(
    height: 195,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: 4),
      itemCount: _topics.length,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (ctx, i) {
        final t = _topics[i];
        return _ActivityCard(topic: t, grade: _grade, context: ctx);
      },
    ),
  );

  // ── Farming Stories card ──────────────────────────────────────────
  Widget _buildStoriesCard() => GestureDetector(
    onTap: () => _openScreen(
        PrimaryFarmingStoryScreen(strand: 'Farming in Kenya', grade: _grade)),
    child: Container(
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.25))),
      child: Row(children: [
        Container(width: 60, height: 60,
          decoration: BoxDecoration(color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14)),
          child: const Center(child: Text('📖', style: TextStyle(fontSize: 32)))),
        const SizedBox(width: 14),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Read a Farming Story', style: TextStyle(fontSize: 15,
              fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
          SizedBox(height: 4),
          Text('A short story about a Kenyan child farmer.\nRead it then answer the question!',
              style: TextStyle(fontSize: 12, color: Color(0xFF388E3C), height: 1.4)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: const Color(0xFF2E7D32),
              borderRadius: BorderRadius.circular(10)),
          child: const Text('Start 📖', style: TextStyle(color: Colors.white,
              fontSize: 12, fontWeight: FontWeight.bold))),
      ]),
    ),
  );

  // ── Topic grid — long-press for lesson plan (teacher) ─────────────
  Widget _buildTopicGrid(String schoolName, String classId, bool isTeacher) =>
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3, crossAxisSpacing: 10,
        mainAxisSpacing: 10, childAspectRatio: 0.88,
        children: _topics.map((t) => GestureDetector(
          onTap: () => _openScreen(_screenForId(t.id, schoolName, classId)),
          onLongPress: isTeacher ? () => showModalBottomSheet(
            context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
            builder: (_) => DraggableScrollableSheet(
              initialChildSize: 0.9, maxChildSize: 0.97, minChildSize: 0.5,
              builder: (_, sc) =>
                  PrimaryLessonPlanSheet(topic: t.label, grade: _grade))) : null,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.color.withValues(alpha: 0.2)),
              boxShadow: [BoxShadow(color: t.color.withValues(alpha: 0.07),
                  blurRadius: 6, offset: const Offset(0,3))]),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(width: 48, height: 48,
                decoration: BoxDecoration(color: t.lightColor,
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(t.icon, color: t.color, size: 26)),
              const SizedBox(height: 7),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Text(t.label, style: TextStyle(fontSize: 11,
                    fontWeight: FontWeight.bold, color: t.color),
                    textAlign: TextAlign.center, maxLines: 2,
                    overflow: TextOverflow.ellipsis)),
              if (isTeacher)
                Padding(padding: const EdgeInsets.only(top: 3),
                  child: Text('hold: lesson plan', style: TextStyle(fontSize: 8,
                      color: Colors.grey.shade400), textAlign: TextAlign.center)),
            ]),
          ),
        )).toList(),
      );

  // ── Approval card ─────────────────────────────────────────────────
  Widget _buildApprovalCard(String schoolName) => Card(
    elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => ApprovalManagementScreen(schoolName: schoolName,
            currentUserRole: _role!,
            classId: _role == EduRole.teacher ? classIdNotifier.value : null))),
      child: Padding(padding: const EdgeInsets.all(18),
        child: Row(children: [
          CircleAvatar(radius: 22, backgroundColor: Colors.purple.shade50,
              child: Icon(Icons.approval, color: Colors.purple.shade700, size: 24)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_role == EduRole.headteacher
                ? 'Manage Teacher Approvals' : 'Manage Student Approvals',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(_role == EduRole.headteacher
                ? 'Review teachers in your school' : 'Approve students in your class',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ])),
          const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
        ]),
      ),
    ));

  Widget _buildClassSwitchButton(String schoolName) {
    final currentId = classIdNotifier.value;
    final label     = currentId != null ? _formatGradeDisplay(currentId) : 'Select Class';
    return GestureDetector(
      onTap: _switchClass,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: currentId != null ? const Color(0xFF003900) : Colors.grey.shade300,
              width: currentId != null ? 2 : 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6, offset: const Offset(0,2))]),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFF003900).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.swap_horiz, color: Color(0xFF003900), size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(currentId != null ? 'Active Class' : 'No Class Selected',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500)),
            Text(label, style: const TextStyle(fontSize: 16,
                fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
            Text('Tap to switch between your classes',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ])),
          Icon(Icons.keyboard_arrow_right, color: Colors.grey.shade400, size: 24),
        ]),
      ),
    );
  }

  Widget _buildViewStudentsCard(String schoolName) => Card(
    elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openScreen(ViewStudentsScreen(schoolName: schoolName,
          classIdNotifier: classIdNotifier,
          onClose: () => setState(() => _selectedFeature = null))),
      child: Padding(padding: const EdgeInsets.all(18),
        child: Row(children: [
          CircleAvatar(radius: 22, backgroundColor: Colors.green.shade50,
              child: Icon(Icons.group, color: Colors.green.shade700, size: 24)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('View Students', style: TextStyle(fontSize: 16,
                fontWeight: FontWeight.bold)),
            ValueListenableBuilder<int>(
              valueListenable: _studentCount,
              builder: (_, enrolled, _) => Text(
                '$enrolled student${enrolled == 1 ? '' : 's'} enrolled',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ),
          ])),
          const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
        ]),
      ),
    ));
}

// ─────────────────────────────────────────────────────────────────
//  Daily Challenge Banner
// ─────────────────────────────────────────────────────────────────
class _PrimaryDailyChallengeBanner extends StatefulWidget {
  final String classId, grade;
  const _PrimaryDailyChallengeBanner({required this.classId, required this.grade});
  @override
  State<_PrimaryDailyChallengeBanner> createState() => _DailyChallengeState();
}

class _DailyChallengeState extends State<_PrimaryDailyChallengeBanner> {
  Map<String, String>? _challenge;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final c = await PrimaryDailyChallengeService.getOrGenerate(
        classId: widget.classId, grade: widget.grade);
    if (!mounted) return;
    setState(() { _challenge = c; _loading = false; });
  }

  static const _topicColors = {
    'Seeds & Plants':   Color(0xFF2E7D32),
    'Farming Tools':    Color(0xFFBF360C),
    'Weeds & Pests':    Color(0xFF558B2F),
    'Farm Animals':     Color(0xFFE65100),
    'Soil & Water':     Color(0xFF0277BD),
    'Buying & Selling': Color(0xFF6A1B9A),
  };

  void _openChallenge() {
    final c     = _challenge; if (c == null) return;
    final topic = c['topic']  ?? 'Farm Animals';
    final type  = c['type']   ?? 'quiz';
    final ac    = _topicColors[topic] ?? const Color(0xFF003900);

    Widget? sheet;
    switch (type) {
      case 'fillBlank':
        sheet = DraggableScrollableSheet(initialChildSize: 0.75, maxChildSize: 0.95, minChildSize: 0.5,
          builder: (_, sc) => PrimaryFillBlankSheet(topic: topic, grade: widget.grade, accentColor: ac));
      case 'whatAmI':
        sheet = DraggableScrollableSheet(initialChildSize: 0.85, maxChildSize: 0.95, minChildSize: 0.5,
          builder: (_, sc) => PrimaryWhatAmISheet(topic: topic, grade: widget.grade, accentColor: ac));
      default: // quiz
        sheet = DraggableScrollableSheet(initialChildSize: 0.85, maxChildSize: 0.95, minChildSize: 0.5,
          builder: (_, sc) => PrimaryMiniQuizSheet(topic: topic, grade: widget.grade, accentColor: ac));
    }
    showModalBottomSheet(context: context, isScrollControlled: true,
        backgroundColor: Colors.transparent, builder: (_) => sheet!);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(height: 72,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2,
            color: Color(0xFF003900))));
    }

    final emoji = _challenge?['emoji']    ?? '🌱';
    final title = _challenge?['title']    ?? "Today's Challenge";
    final sub   = _challenge?['subtitle'] ?? 'Tap to start!';

    return GestureDetector(
      onTap: _openChallenge,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: const Color(0xFF003900), borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Container(width: 52, height: 52,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14)),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 28)))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8)),
              child: const Text("Today's challenge",
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600))),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 15,
                fontWeight: FontWeight.bold)),
            Text(sub, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10)),
            child: const Text('Start!', style: TextStyle(color: Colors.white, fontSize: 13,
                fontWeight: FontWeight.bold))),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Today's Stars Banner (student)
// ─────────────────────────────────────────────────────────────────
class _PrimaryTodayStarsBanner extends StatefulWidget {
  const _PrimaryTodayStarsBanner();
  @override
  State<_PrimaryTodayStarsBanner> createState() => _TodayStarsState();
}

class _TodayStarsState extends State<_PrimaryTodayStarsBanner> {
  int  _completions = 0;
  bool _loading     = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final data = await PrimaryProgressService.getTodaySummary();
    if (!mounted) return;
    final completions = data['completions'] as Map<String, dynamic>? ?? {};
    final total = completions.values.fold<int>(0, (s, v) => s + (v as int? ?? 0));
    setState(() { _completions = total; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _completions == 0) return const SizedBox.shrink();
    final stars = _completions.clamp(0, 5);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.amber.shade200)),
      child: Row(children: [
        const Text('⭐', style: TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('You earned $stars ${stars == 1 ? 'star' : 'stars'} today!',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                  color: Colors.amber.shade800)),
          Text('$_completions activities completed — keep going!',
              style: TextStyle(fontSize: 12, color: Colors.amber.shade700)),
        ])),
        Row(children: List.generate(5, (i) => Icon(
            i < stars ? Icons.star_rounded : Icons.star_border_rounded,
            color: i < stars ? Colors.amber.shade500 : Colors.grey.shade300, size: 18))),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Activity card (horizontal scroll row on home)
// ─────────────────────────────────────────────────────────────────
class _ActivityCard extends StatelessWidget {
  final _Topic topic;
  final String grade;
  final BuildContext context;
  const _ActivityCard({required this.topic, required this.grade, required this.context});

  void _showSheet(Widget sheet) => showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => sheet);

  @override
  Widget build(BuildContext ctx) {
    final c = topic.color;
    return Container(
      width: 160,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.withValues(alpha: 0.2)),
          boxShadow: [BoxShadow(color: c.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0,3))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(height: 58,
          decoration: BoxDecoration(color: c.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
          child: Row(children: [
            const SizedBox(width: 12),
            Container(width: 36, height: 36,
              decoration: BoxDecoration(color: c.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(topic.icon, color: c, size: 20)),
            const SizedBox(width: 8),
            Expanded(child: Text(topic.label, style: TextStyle(fontSize: 11,
                fontWeight: FontWeight.bold, color: c),
                maxLines: 2, overflow: TextOverflow.ellipsis)),
          ])),
        // Quiz button
        Padding(padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: GestureDetector(
            onTap: () => _showSheet(DraggableScrollableSheet(
              initialChildSize: 0.85, maxChildSize: 0.95, minChildSize: 0.5,
              builder: (_, sc) => PrimaryMiniQuizSheet(
                  topic: topic.label, grade: grade, accentColor: c))),
            child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(8)),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.quiz_rounded, color: Colors.white, size: 13),
                SizedBox(width: 4),
                Text('Quiz 🎯', style: TextStyle(color: Colors.white, fontSize: 11,
                    fontWeight: FontWeight.bold)),
              ])))),
        // What am I
        Padding(padding: const EdgeInsets.fromLTRB(8, 5, 8, 0),
          child: GestureDetector(
            onTap: () => _showSheet(DraggableScrollableSheet(
              initialChildSize: 0.85, maxChildSize: 0.95, minChildSize: 0.5,
              builder: (_, sc) => PrimaryWhatAmISheet(
                  topic: topic.label, grade: grade, accentColor: c))),
            child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(color: c.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: c.withValues(alpha: 0.25))),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.help_outline_rounded, color: c, size: 13),
                const SizedBox(width: 4),
                Text('What am I? 🤔', style: TextStyle(color: c, fontSize: 11,
                    fontWeight: FontWeight.bold)),
              ])))),
        // Fill blank
        Padding(padding: const EdgeInsets.fromLTRB(8, 5, 8, 8),
          child: GestureDetector(
            onTap: () => _showSheet(DraggableScrollableSheet(
              initialChildSize: 0.75, maxChildSize: 0.95, minChildSize: 0.5,
              builder: (_, sc) => PrimaryFillBlankSheet(
                  topic: topic.label, grade: grade, accentColor: c))),
            child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(color: c.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: c.withValues(alpha: 0.25))),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.text_fields_rounded, color: c, size: 13),
                const SizedBox(width: 4),
                Text('Fill blank 📝', style: TextStyle(color: c, fontSize: 11,
                    fontWeight: FontWeight.bold)),
              ])))),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Fallback category screen (Firestore content)
// ─────────────────────────────────────────────────────────────────
class _PrimaryCategoryScreen extends StatelessWidget {
  final _Topic  topic;
  final String schoolName, classId;
  const _PrimaryCategoryScreen({required this.topic,
      required this.schoolName, required this.classId});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: topic.lightColor,
    appBar: AppBar(backgroundColor: topic.color, foregroundColor: Colors.white,
        title: Text(topic.label), elevation: 0),
    body: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('PrimaryContent')
          .where('categoryId',  isEqualTo: topic.id)
          .where('schoolName',  isEqualTo: schoolName)
          .orderBy('createdAt', descending: false).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: topic.color));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(child: Padding(padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(topic.icon, size: 72, color: topic.color.withValues(alpha: 0.3)),
              const SizedBox(height: 20),
              Text('Nothing here yet!', style: TextStyle(fontSize: 20,
                  fontWeight: FontWeight.bold, color: topic.color)),
              const SizedBox(height: 8),
              Text('Your teacher will add pictures and lessons here soon.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
            ])));
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, mainAxisSpacing: 12,
              crossAxisSpacing: 12, childAspectRatio: 0.85),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data   = docs[i].data() as Map<String, dynamic>;
            final label  = data['label']       as String? ?? '';
            final desc   = data['description'] as String? ?? '';
            final imgB64 = data['imageBase64'] as String?;
            return Container(
              decoration: BoxDecoration(color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: topic.color.withValues(alpha: 0.1),
                      blurRadius: 8, offset: const Offset(0,3))]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: imgB64 != null && imgB64.isNotEmpty
                      ? Image.memory(base64Decode(imgB64), fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _placeholder())
                      : _placeholder())),
                Padding(padding: const EdgeInsets.all(10), child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: TextStyle(fontWeight: FontWeight.bold,
                      fontSize: 13, color: topic.color),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(desc, style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ])),
              ]),
            );
          },
        );
      },
    ),
  );

  Widget _placeholder() => Container(color: topic.lightColor,
      child: Center(child: Icon(topic.icon, size: 48,
          color: topic.color.withValues(alpha: 0.4))));
}

// ─────────────────────────────────────────────────────────────────
//  Class picker sheet (unchanged)
// ─────────────────────────────────────────────────────────────────
class _PrimaryClassPickerSheet extends StatefulWidget {
  final String  schoolName;
  final String? currentClassId;
  final void Function(String) onClassSelected;
  const _PrimaryClassPickerSheet({required this.schoolName,
      required this.currentClassId, required this.onClassSelected});
  @override
  State<_PrimaryClassPickerSheet> createState() => _PrimaryClassPickerSheetState();
}

class _PrimaryClassPickerSheetState extends State<_PrimaryClassPickerSheet> {
  late Future<_PickerData> _future;
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _future = _load();
    if (widget.currentClassId != null) _expanded.add(_tier(widget.currentClassId!));
  }

  Future<_PickerData> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const _PickerData(assigned: [], available: []);
    final userDoc = await FirebaseFirestore.instance
        .collection('EducationUsers').doc(uid).get();
    final userData    = userDoc.data() ?? {};
    final assignedSet = Set<String>.from(
        List<String>.from(userData['classIds'] ?? []));
    final schoolName  = userData['schoolName'] as String? ?? widget.schoolName;
    final Set<String> allIds = {};
    try {
      final schoolSnap = await FirebaseFirestore.instance.collection('Schools')
          .where('schoolName', isEqualTo: schoolName).limit(1).get();
      if (schoolSnap.docs.isNotEmpty) {
        final sd    = schoolSnap.docs.first.data();
        final tiers = List<String>.from(sd['educationTiers'] ?? []);
        final norm  = schoolName.replaceAll(' ', '_');
        const tierGrades = <String, List<String>>{
          'primary': ['1','2','3','4','5','6'],
          'junior':  ['7','8','9'],
          'senior':  ['10','11','12'],
          '844':     ['1','2','3','4'],
        };
        for (final t in tiers) {
          for (final g in (tierGrades[t] ?? [])) {
            final sys = t == '844' ? 'eightfourfour' : t;
            allIds.add('${norm}_${sys}_$g');
          }
        }
      }
    } catch (_) {}
    allIds.addAll(assignedSet);
    final assigned  = assignedSet.map((id) =>
        _ClassEntry(id: id, label: _label(id), tier: _tier(id))).toList();
    final available = allIds.where((id) => !assignedSet.contains(id))
        .map((id) => _ClassEntry(id: id, label: _label(id), tier: _tier(id))).toList();
    assigned.sort( (a, b) => _sortKey(a).compareTo(_sortKey(b)));
    available.sort((a, b) => _sortKey(a).compareTo(_sortKey(b)));
    return _PickerData(assigned: assigned, available: available);
  }

  static String _label(String id) {
    final m = RegExp(r'_(primary|junior|senior|eightfourfour)_(\d+)$')
        .firstMatch(id.toLowerCase());
    if (m != null) {
      return m.group(1) == 'eightfourfour' ? 'Form ${m.group(2)}' : 'Grade ${m.group(2)}';
    }
    return id;
  }

  static String _tier(String id) {
    if (id.contains('_primary_'))       return 'Primary (Grade 1–6)';
    if (id.contains('_junior_'))        return 'Junior Secondary (Grade 7–9)';
    if (id.contains('_senior_'))        return 'Senior Secondary (Grade 10–12)';
    if (id.contains('_eightfourfour_')) return '8-4-4 System (Form 1–4)';
    return 'Class';
  }

  static int     _tierOrder(String t) {
    if (t.contains('Primary')) return 0;
    if (t.contains('Junior'))  return 1;
    if (t.contains('Senior'))  return 2;
    if (t.contains('8-4-4'))   return 3;
    return 4;
  }
  static String  _sortKey(_ClassEntry e) => '${_tierOrder(e.tier)}_${e.label.padLeft(10)}';
  static Color   _tierColor(String t) {
    if (t.contains('Primary')) return const Color(0xFFFF8C00);
    if (t.contains('Junior'))  return const Color(0xFF00897B);
    if (t.contains('Senior'))  return const Color(0xFF1565C0);
    if (t.contains('8-4-4'))   return const Color(0xFF6A1B9A);
    return Colors.grey;
  }
  static IconData _tierIcon(String t) {
    if (t.contains('Primary')) return Icons.child_care;
    if (t.contains('Junior'))  return Icons.menu_book;
    if (t.contains('Senior'))  return Icons.school;
    return Icons.account_balance;
  }

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.82),
    decoration: const BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 12),
      Center(child: Container(width: 40, height: 4,
          decoration: BoxDecoration(color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2)))),
      const SizedBox(height: 16),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Switch Class', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 2),
            Text('Tap a tier to expand, then select your class',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
          ])),
          IconButton(icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context)),
        ])),
      const SizedBox(height: 8),
      const Divider(height: 1),
      Expanded(child: FutureBuilder<_PickerData>(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: Padding(
                padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
          }
          final data   = snap.data ?? const _PickerData(assigned: [], available: []);
          final groups = <String, _TierGroup>{};
          for (final c in data.assigned) {
            groups.putIfAbsent(c.tier, () => _TierGroup(tier: c.tier)).assigned.add(c);
          }
          for (final c in data.available) {
            groups.putIfAbsent(c.tier, () => _TierGroup(tier: c.tier)).available.add(c);
          }
          final sorted = groups.values.toList()
            ..sort((a, b) => _tierOrder(a.tier).compareTo(_tierOrder(b.tier)));
          if (sorted.isEmpty) {
            return Padding(padding: const EdgeInsets.all(40),
              child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.class_outlined, size: 56, color: Colors.grey.shade300),
                const SizedBox(height: 14),
                const Text('No classes available yet.\nContact your headteacher.',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              ])));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: sorted.length,
            itemBuilder: (_, i) => _buildAccordion(sorted[i]));
        },
      )),
    ]),
  );

  Widget _buildAccordion(_TierGroup group) {
    final color = _tierColor(group.tier);
    final icon  = _tierIcon(group.tier);
    final isOpen = _expanded.contains(group.tier);
    final hasA   = group.assigned.isNotEmpty;
    final hasV   = group.available.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isOpen ? color : Colors.grey.shade200, width: isOpen ? 2 : 1),
          color: isOpen ? color.withValues(alpha: 0.03) : Colors.white),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() =>
              isOpen ? _expanded.remove(group.tier) : _expanded.add(group.tier)),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Container(width: 40, height: 40,
                decoration: BoxDecoration(
                    color: isOpen ? color : color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: isOpen ? Colors.white : color, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(group.tier, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                    color: isOpen ? color : const Color(0xFF1A1A1A))),
                Text(hasA
                    ? '${group.assigned.length} of your class${group.assigned.length == 1 ? '' : 'es'}'
                    : '${group.assigned.length + group.available.length} available',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ])),
              AnimatedRotation(turns: isOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_down, color: isOpen ? color : Colors.grey)),
            ])),
        ),
        if (isOpen) ...[
          const Divider(height: 1, indent: 16, endIndent: 16),
          if (hasA) ...[
            Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(children: [
                Icon(Icons.check_circle_outline, size: 13, color: color),
                const SizedBox(width: 5),
                Text('Your classes', style: TextStyle(fontSize: 11,
                    fontWeight: FontWeight.w700, color: color)),
              ])),
            ...group.assigned.map((c) => _buildTile(c, color, isAdd: false)),
          ],
          if (hasV) ...[
            if (hasA) const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(children: [
                Icon(Icons.add_circle_outline, size: 13, color: Colors.teal.shade600),
                const SizedBox(width: 5),
                Text('Add a class', style: TextStyle(fontSize: 11,
                    fontWeight: FontWeight.w700, color: Colors.teal.shade600)),
              ])),
            ...group.available.map((c) => _buildTile(c, Colors.teal, isAdd: true)),
          ],
          const SizedBox(height: 8),
        ],
      ]),
    );
  }

  Widget _buildTile(_ClassEntry cls, Color color, {required bool isAdd}) {
    final isActive = cls.id == widget.currentClassId && !isAdd;
    return GestureDetector(
      onTap: () {
        if (isAdd) { _addAndSwitch(cls.id); }
        else { Navigator.pop(context); widget.onClassSelected(cls.id); }
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.08)
              : isAdd ? Colors.teal.withValues(alpha: 0.04) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isActive ? color : isAdd ? Colors.teal.shade200 : Colors.grey.shade200,
              width: isActive ? 2 : 1)),
        child: Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(
              color: isActive ? color : isAdd ? Colors.teal.withValues(alpha: 0.1) : color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
            child: Icon(isAdd ? Icons.add : Icons.class_,
                color: isActive ? Colors.white : isAdd ? Colors.teal : color, size: 18)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cls.label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                color: isActive ? color : isAdd ? Colors.teal.shade700 : const Color(0xFF1A1A1A))),
            Text(isAdd ? 'Tap to add & switch' : cls.tier,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ])),
          if (isActive) Icon(Icons.check_circle, color: color, size: 20),
          if (isAdd)    Icon(Icons.arrow_forward_ios, color: Colors.teal.shade300, size: 14),
        ]),
      ),
    );
  }

  Future<void> _addAndSwitch(String classId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('EducationUsers').doc(uid).update({
        'classIds':        FieldValue.arrayUnion([classId]),
        'currentClassId':  classId,
        'lastClassSwitch': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
      widget.onClassSelected(classId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

// Supporting data classes
class _PickerData {
  final List<_ClassEntry> assigned, available;
  const _PickerData({required this.assigned, required this.available});
}
class _TierGroup {
  final String tier;
  final List<_ClassEntry> assigned = [], available = [];
  _TierGroup({required this.tier});
}
class _ClassEntry {
  final String id, label, tier;
  const _ClassEntry({required this.id, required this.label, required this.tier});
}