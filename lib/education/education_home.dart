// lib/education/education_home.dart
// Changes:
//  1. _ClassPickerSheet now has "Add a new class" option — teachers can
//     self-assign to any class in their school without headteacher involvement.
//  2. School code shown in drawer header and left-rail for headteachers.
// ignore_for_file: use_build_context_synchronously, deprecated_member_use, avoid_types_as_parameter_names

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kilimomkononi/education/approval_management_screen.dart';
import 'package:kilimomkononi/education/education_farming_tips.dart';
import 'package:kilimomkononi/education/education_manuals.dart';
import 'package:kilimomkononi/education/education_market_price.dart';
import 'package:kilimomkononi/education/education_weather_forecast.dart';
import 'package:kilimomkononi/education/farm_management/farm_management_screen.dart';
import 'package:kilimomkononi/education/field/field_home.dart';
import 'package:kilimomkononi/education/pest/pest_disease_home.dart';
import 'package:kilimomkononi/education/simulation/simulation_home.dart';
import 'package:kilimomkononi/education/quiz/quiz_home.dart';
import 'package:kilimomkononi/education/quiz/shared_quiz_widgets.dart';
import 'package:kilimomkononi/education/teacher/view_students.dart';
import 'package:kilimomkononi/education/utils/class_id_notifier.dart';
import 'package:kilimomkononi/models/education_user.dart';
import 'package:kilimomkononi/screens/user_profile.dart';
import 'package:kilimomkononi/settings/settings_screen.dart';
import 'package:logger/logger.dart';
import 'package:lottie/lottie.dart';
import 'package:rxdart/rxdart.dart';
import 'package:kilimomkononi/education/education_login.dart';
import 'package:kilimomkononi/education/primary/primary_home_screen.dart';
import 'package:kilimomkononi/utils/firestore_helper.dart';
import 'package:kilimomkononi/education/education_resources.dart';
import 'package:kilimomkononi/education/education_chat.dart';
import 'package:kilimomkononi/education/tutor/tutor_chat_screen.dart';
import 'package:kilimomkononi/education/tutor/tutor_fab.dart';
import 'package:kilimomkononi/education/analysis/education_plot_analysis_screen.dart';

enum ScreenType { mobile, tablet, desktop }

class EducationHomeScreen extends StatefulWidget {
  const EducationHomeScreen({super.key});
  @override
  State<EducationHomeScreen> createState() => _EducationHomeScreenState();
}

class _EducationHomeScreenState extends State<EducationHomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _animCtrl;

  String _capitalize(String s) => s.isNotEmpty
      ? '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}'
      : s;

  String _formatGradeDisplay(String? classId) {
    if (classId == null || classId.isEmpty) return 'Not selected';
    if (classId.contains('|')) {
      final parts = classId.split('|');
      final shortId = parts[0];
      final systemName = parts.length > 1 ? parts[1] : 'cbcJunior';
      final systemGrades = {
        'cbcPrimary': ['Grade 1', 'Grade 2', 'Grade 3', 'Grade 4', 'Grade 5', 'Grade 6'],
        'cbcJunior': ['Grade 7', 'Grade 8', 'Grade 9'],
        'cbcSenior': ['Grade 10', 'Grade 11', 'Grade 12'],
        'eightFourFour': ['Form 1', 'Form 2', 'Form 3', 'Form 4'],
      };
      final grades = systemGrades[systemName] ?? systemGrades['cbcJunior']!;
      final gradeText = grades.firstWhereOrNull((g) => g.split(' ').last == shortId);
      return gradeText ?? 'Grade $shortId';
    }
    final match = RegExp(r'_(\d+)$').firstMatch(classId);
    if (match != null) {
      final num = match.group(1);
      String prefix = 'Grade';
      if (classId.contains('eightfourfour')) {
        prefix = int.parse(num!) <= 8 ? 'Grade' : 'Form';
      }
      return '$prefix $num';
    }
    return classId;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  Map<String, dynamic>? _userData;
  Uint8List? _profileImageBytes;
  final logger = Logger(printer: PrettyPrinter());

  String? _userId;
  EduRole? _role;
  ApprovalStatus _approvalStatus = ApprovalStatus.pending;
  bool _featuresLocked = true;

  String? _selectedClassId;
  int _selectedBottomIndex = 0;
  int _selectedRailIndex = -1;
  Widget? _selectedFeature;

  final ValueNotifier<List<Map<String, dynamic>>> _quizList = ValueNotifier([]);
  final ValueNotifier<int> _studentCount = ValueNotifier(0);
  final ValueNotifier<List<Map<String, dynamic>>> _feedList = ValueNotifier([]);

  bool _isLoading = true;
  String? _errorMessage;

  StreamSubscription? _quizSub;
  StreamSubscription<QuerySnapshot>? _studentSub;
  StreamSubscription<QuerySnapshot>? _essaySubSub;
  StreamSubscription<QuerySnapshot>? _simSubSub;

  // Groups essay submissions by module name → { pending: N, total: N }
  final ValueNotifier<Map<String, Map<String, int>>> _essaySubmissionGroups =
      ValueNotifier({});
  // Groups simulation submissions by module name → { pending: N, total: N }
  final ValueNotifier<Map<String, Map<String, int>>> _simSubmissionGroups =
      ValueNotifier({});

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this);
    _fetchUserData();

    classIdNotifier.addListener(() {
      if (mounted) {
        setState(() => _selectedClassId = classIdNotifier.value);
        _refreshContent();
      }
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    classIdNotifier.removeListener(_refreshContent);
    _quizList.dispose();
    _studentCount.dispose();
    _feedList.dispose();
    _essaySubmissionGroups.dispose();
    _simSubmissionGroups.dispose();
    _quizSub?.cancel();
    _studentSub?.cancel();
    _essaySubSub?.cancel();
    _simSubSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _errorMessage = 'No user logged in.');
        return;
      }
      _userId = user.uid;

      final snap = await FirebaseFirestore.instance
          .collection('EducationUsers')
          .doc(user.uid)
          .get();

      if (!snap.exists) {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => const EducationLoginScreen()));
        }
        return;
      }

      final data = snap.data() as Map<String, dynamic>;

      if (data['isDisabled'] == true) {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => const EducationLoginScreen()));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account disabled. Contact admin.')),
          );
        }
        return;
      }

      final imgBase64 = data['profileImage'] as String?;
      Uint8List? imgBytes;
      if (imgBase64 != null && imgBase64.isNotEmpty) {
        try {
          imgBytes = base64Decode(imgBase64);
        } catch (e) {
          logger.e("Image decode error: $e");
        }
      }

      final roleStr = data['role'] as String?;
      EduRole? parsedRole;
      if (roleStr != null) {
        parsedRole = EduRole.values.firstWhere(
          (e) => e.name == roleStr,
          orElse: () => EduRole.student,
        );
      }

      final approvalStatusStr = data['approvalStatus'] as String?;
      final approvalStatus = approvalStatusStr != null
          ? ApprovalStatus.values.firstWhere(
              (e) => e.name == approvalStatusStr,
              orElse: () => ApprovalStatus.pending,
            )
          : ApprovalStatus.pending;

      final featuresLocked =
          (parsedRole == EduRole.headteacher && approvalStatus != ApprovalStatus.approved) ||
          (parsedRole == EduRole.mainadmin && approvalStatus != ApprovalStatus.approved) ||
          (parsedRole == null || approvalStatus != ApprovalStatus.approved);

      // ── Primary routing check ─────────────────────────────────
      // Do this BEFORE setState so we never render EducationHomeScreen
      // for a primary user even for a single frame.
      //
      // A user is "primary" if their currentClassId contains '_primary_'
      // Students: always routed to PrimaryHomeScreen if in a primary class
      // Teachers: routed to PrimaryHomeScreen only if their ACTIVE class
      //           (currentClassId) is primary. They can switch back to
      //           other systems via the "Switch Class" button on PrimaryHomeScreen.
      final currentClassId = data['currentClassId'] as String?;
      final isPrimary = currentClassId != null &&
          currentClassId.toLowerCase().contains('_primary_');

      if (isPrimary &&
          (parsedRole == EduRole.student ||
           parsedRole == EduRole.teacher) &&
          mounted) {
        // Redirect to PrimaryHomeScreen — handles both pending and approved
        // states internally (its own _buildPendingScreen).
        // classIdNotifier must be set first so PrimaryHomeScreen
        // knows the active class immediately.
        classIdNotifier.value = currentClassId;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PrimaryHomeScreen()),
        );
        return;
      }
      // ─────────────────────────────────────────────────────────

      setState(() {
        _userData = data;
        _profileImageBytes = imgBytes;
        _role = parsedRole;
        _selectedClassId = currentClassId;
        _approvalStatus = approvalStatus;
        _featuresLocked = featuresLocked;
        _isLoading = false;
      });

      if (classIdNotifier.value == null && _selectedClassId != null) {
        classIdNotifier.value = _selectedClassId;
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load user data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveCurrentClassId(String classId) async {
  if (_userId == null) return;
  try {
    // ✅ Simple update — no transaction needed for a class switch
    await FirebaseFirestore.instance
        .collection('EducationUsers')
        .doc(_userId)
        .update({
      'currentClassId': classId,
      'classIds': FieldValue.arrayUnion([classId]), // safe: only adds if missing
      'lastClassSwitch': FieldValue.serverTimestamp(),
    });

    final isPrimary = classId.toLowerCase().contains('_primary_');
    if (isPrimary && mounted &&
        (_role == EduRole.teacher || _role == EduRole.student)) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PrimaryHomeScreen()),
      );
    }
  } catch (e) {
    logger.e('Save failed: $e');
  }
}

  Future<void> _handleLogout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const EducationLoginScreen()));
    }
  }

  void _refreshContent() {
    final id = classIdNotifier.value;
    if (id == null || _featuresLocked) {
      _quizList.value = [];
      _studentCount.value = 0;
      _feedList.value = [];
      _essaySubmissionGroups.value = {};
      _simSubmissionGroups.value   = {};
      return;
    }
    _quizSub?.cancel();
    _studentSub?.cancel();
    _essaySubSub?.cancel();
    _simSubSub?.cancel();
    _listenQuizzes(id);
    if (_role == EduRole.teacher) _listenStudentCount(id);
    if (_role == EduRole.teacher) _listenEssaySubmissions(id);
    if (_role == EduRole.teacher) _listenSimulationSubmissions(id);
    _buildFeed();
  }

  void _listenQuizzes(String classId) {
    const collections = [
      'farming_content', 'market_content', 'weather_content',
      'manuals_content', 'farm_management_content',
      'field_content', 'pest_content', 'disease_content',
    ];
    final moduleNames = {
      'farming_content': 'Farming Tips', 'market_content': 'Market Price',
      'weather_content': 'Weather Forecast', 'manuals_content': 'Manuals',
      'farm_management_content': 'Farm Management', 'field_content': 'Field Data',
      'pest_content': 'Pest', 'disease_content': 'Disease',
    };
    final streams = <Stream<List<Map<String, dynamic>>>>[];
    for (final coll in collections) {
      final collection = FirestoreHelper.getContentFromClassId(classId, coll);
      if (collection == null) continue;
      streams.add(
        collection.where('type', isEqualTo: 'quiz')
            .snapshots()
            .map((snapshot) {
              // Sort client-side — avoids requiring a composite index on every content collection
              final sorted = List.of(snapshot.docs)
                ..sort((a, b) {
                  final aT = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                  final bT = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                  return (bT?.millisecondsSinceEpoch ?? 0)
                      .compareTo(aT?.millisecondsSinceEpoch ?? 0);
                });
              return sorted;
            })
            .map((docs) => docs.map((doc) {
                  final dataMap = doc.data() as Map<String, dynamic>?;
                  if (dataMap == null) return null;

                  // Parse the encoded questions to detect essay vs mcq
                  List<dynamic> questions = [];
                  try {
                    final raw = dataMap['data'];
                    questions = raw is String
                        ? (jsonDecode(raw) as List? ?? [])
                        : (raw as List? ?? []);
                  } catch (_) {}
                  final hasEssay = questions.any(
                      (q) => (q as Map<String, dynamic>?)?['type'] == 'essay');
                  final hasMcq = questions.any(
                      (q) => (q as Map<String, dynamic>?)?['type'] != 'essay');
                  final quizType = hasEssay && hasMcq
                      ? 'mixed'
                      : hasEssay
                          ? 'essay'
                          : 'mcq';

                  return {
                    'id': doc.id,
                    'title': (dataMap['title'] as String?)?.trim().isNotEmpty == true
                        ? dataMap['title'] as String : 'Untitled Quiz',
                    'module': moduleNames[coll] ?? 'Unknown',
                    'contentType': coll,
                    'type': 'quiz',
                    'quizType': quizType,
                    'createdAt': dataMap['createdAt'] as Timestamp?,
                  };
                }).whereType<Map<String, dynamic>>().toList()),
      );
    }
    _quizSub?.cancel();
    _quizSub = CombineLatestStream.list(streams).listen((listOfLists) {
      final flatList = listOfLists.expand((list) => list).toList();
      flatList.sort((a, b) {
        final aTime = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
        final bTime = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });
      _quizList.value = flatList;
      _buildFeed();
    });
  }

  void _listenStudentCount(String classId) {
    _studentSub?.cancel();
    if (classId.isEmpty || _userData?['schoolName'] == null) {
      _studentCount.value = 0;
      return;
    }
    final query = FirebaseFirestore.instance
        .collection('EducationUsers')
        .where('role', isEqualTo: 'student')
        .where('schoolName', isEqualTo: _userData!['schoolName'])
        .where('currentClassId', isEqualTo: classId);
    _studentSub = query.snapshots().listen((snapshot) {
      if (mounted) _studentCount.value = snapshot.size;
    }, onError: (error) {
      logger.e('Student count error: $error');
      if (mounted) _studentCount.value = 0;
    });
  }


 // ── Essay Submissions Listener (ONLY quiz essays) ──────────────────────
void _listenEssaySubmissions(String classId) {
  _essaySubSub?.cancel();
  final coll = FirestoreHelper.getSubmissionsFromClassId(classId);
  if (coll == null) {
    _essaySubmissionGroups.value = {};
    return;
  }

  _essaySubSub = coll
      .where('type', isEqualTo: 'quiz')                    // ← ONLY quizzes
      .where('hasEssayAnswers', isEqualTo: true)
      .snapshots()
      .listen((snapshot) {
    final groups = <String, Map<String, int>>{};
    for (final doc in snapshot.docs) {
      final d = doc.data() as Map<String, dynamic>;
      final module = d['module'] as String? ?? 'Unknown';
      final reviewed = d['teacherReviewed'] == true;

      groups.update(
        module,
        (v) => {
          'total': (v['total'] ?? 0) + 1,
          'pending': (v['pending'] ?? 0) + (reviewed ? 0 : 1),
        },
        ifAbsent: () => {'total': 1, 'pending': reviewed ? 0 : 1},
      );
    }
    if (mounted) _essaySubmissionGroups.value = groups;
  });
}

// ── Simulation Submissions Listener (ONLY simulations) ─────────────────
void _listenSimulationSubmissions(String classId) {
  _simSubSub?.cancel();
  final coll = FirestoreHelper.getSubmissionsFromClassId(classId);
  if (coll == null) {
    _simSubmissionGroups.value = {};
    return;
  }

  _simSubSub = coll
      .where('type', isEqualTo: 'simulation')              // ← ONLY simulations
      .snapshots()                                         // No need for hasEssayAnswers
      .listen((snapshot) {
    final groups = <String, Map<String, int>>{};
    for (final doc in snapshot.docs) {
      final d = doc.data() as Map<String, dynamic>;
      final module = d['module'] as String? ?? 'Unknown';
      final reviewed = d['teacherReviewed'] == true;

      groups.update(
        module,
        (v) => {
          'total': (v['total'] ?? 0) + 1,
          'pending': (v['pending'] ?? 0) + (reviewed ? 0 : 1),
        },
        ifAbsent: () => {'total': 1, 'pending': reviewed ? 0 : 1},
      );
    }
    if (mounted) _simSubmissionGroups.value = groups;
  });
}

  void _buildFeed() {
    final List<Map<String, dynamic>> all = [..._quizList.value];
    all.sort((a, b) {
      final Timestamp? timeA = a['createdAt'] as Timestamp?;
      final Timestamp? timeB = b['createdAt'] as Timestamp?;
      return (timeB?.toDate() ?? DateTime(1970))
          .compareTo(timeA?.toDate() ?? DateTime(1970));
    });
    _feedList.value = all.take(5).toList();
  }

  void _editProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          profileImageBytes: _profileImageBytes,
          fullName: _userData?['fullName'],
          schoolName: _userData?['schoolName'],
          role: _role?.name,
        ),
      ),
    );
  }

  void _openChat() {
    final schoolName = _userData?['schoolName'] ?? '';
    final chatScreen = EducationChat(
      role: _role ?? EduRole.student,
      schoolName: schoolName,
      classId: classIdNotifier.value ?? '',
      userName: _userData?['fullName'] ?? 'User',
    );
    if (_getScreenType(context) == ScreenType.mobile) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => chatScreen));
    } else {
      setState(() => _selectedFeature = chatScreen);
    }
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      backgroundColor: const Color(0xFF003900),
      selectedItemColor: Colors.white,
      unselectedItemColor: Colors.white70,
      currentIndex: _selectedBottomIndex,
      onTap: _onBottomNavTapped,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Resources'),
        BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'Chat'),
      ],
    );
  }

  void _onBottomNavTapped(int index) {
    setState(() => _selectedBottomIndex = index);
    final schoolName = _userData?['schoolName'] ?? '';
    final classId = classIdNotifier.value ?? '';
    switch (index) {
      case 0:
        setState(() => _selectedFeature = null);
        break;
      case 1:
        _openScreen(EducationResources(
          role: _role ?? EduRole.student,
          schoolName: schoolName,
          classId: classId,
        ));
        break;
      case 2:
        _openChat();
        break;
    }
  }

  Widget _buildWelcomeImage(String assetPath) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.asset(assetPath, width: 280, height: 180, fit: BoxFit.cover),
    );
  }

  List<Widget> _getRoleImages() {
    if (_role == EduRole.headteacher) {
      return [
        _buildWelcomeImage('assets/lottie/images/training_online1.jpg'),
        const SizedBox(width: 12),
        _buildWelcomeImage('assets/lottie/images/school_manager.jpg'),
        const SizedBox(width: 12),
        _buildWelcomeImage('assets/lottie/images/school_manager1.jpg'),
      ];
    } else if (_role == EduRole.teacher) {
      return [
        _buildWelcomeImage('assets/lottie/images/teacher_in_class.jpg'),
        const SizedBox(width: 12),
        _buildWelcomeImage('assets/lottie/images/teacher_with_students.jpg'),
        const SizedBox(width: 12),
        _buildWelcomeImage('assets/lottie/images/online_class.jpg'),
        const SizedBox(width: 12),
        _buildWelcomeImage('assets/lottie/images/agri_tips.jpg'),
      ];
    } else {
      return [
        _buildWelcomeImage('assets/lottie/images/student_backpack.jpg'),
        const SizedBox(width: 12),
        _buildWelcomeImage('assets/lottie/images/student_in_class.jpg'),
        const SizedBox(width: 12),
        _buildWelcomeImage('assets/lottie/images/students_with_books.jpg'),
        const SizedBox(width: 12),
        _buildWelcomeImage('assets/lottie/images/student_online.jpg'),
        const SizedBox(width: 12),
        _buildWelcomeImage('assets/lottie/images/students_gardening.jpg'),
      ];
    }
  }

  ScreenType _getScreenType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return ScreenType.mobile;
    if (width < 1200) return ScreenType.tablet;
    return ScreenType.desktop;
  }

  void _openScreen(Widget page) {
    final screenType = _getScreenType(context);
    if (screenType == ScreenType.mobile) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    } else {
      setState(() {
        _selectedFeature = page;
        _selectedRailIndex = -1;
      });
    }
  }

  void _openInRightPane(Widget page) {
    setState(() {
      _selectedFeature = page;
      _selectedRailIndex = -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage!),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _fetchUserData, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final screenType = _getScreenType(context);
    final schoolName = _userData?['schoolName'] ?? 'Unknown School';
    final fullName = _userData?['fullName'] ?? 'User';

    final appBar = AppBar(
      backgroundColor: const Color(0xFF003900),
      foregroundColor: Colors.white,
      centerTitle: true,
      title: const Text('Kilimomkononi Education'),
      automaticallyImplyLeading: screenType == ScreenType.mobile,
    );

    Widget bodyContent = _featuresLocked
        ? _buildPendingApprovalScreen(schoolName, fullName)
        : _buildMainDashboard(schoolName, fullName);

    Widget mainBody = screenType == ScreenType.mobile
        ? bodyContent
        : Row(
            children: [
              _buildLeftRail(schoolName, classIdNotifier.value ?? '', screenType),
              Expanded(child: _selectedFeature ?? bodyContent),
            ],
          );

    return Scaffold(
      appBar: appBar,
      drawer: screenType == ScreenType.mobile ? _buildDrawer(schoolName) : null,
      body: mainBody,
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _featuresLocked
          ? null
          : TutorFab(
              topic:     _currentModuleTopic(),
              grade:     _formatGradeDisplay(classIdNotifier.value),
              classId:   classIdNotifier.value ?? '',
              isPrimary: _isPrimaryClassId(classIdNotifier.value ?? ''),
            ),
    );
  }

  Widget _buildMainDashboard(String schoolName, String fullName) {
  return SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome card (unchanged)
          Card(
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                    colors: [Color(0xFF43A047), Color(0xFF66BB6A)]),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Lottie.asset(
                        _role == EduRole.teacher || _role == EduRole.headteacher
                            ? 'assets/lottie/learning.json'
                            : 'assets/lottie/hello_student.json',
                        controller: _animCtrl,
                        onLoaded: (comp) {
                          _animCtrl..duration = comp.duration..repeat();
                        },
                        height: 150,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Hello, ${fullName.split(' ').first}!',
                                style: const TextStyle(
                                    fontSize: 28, fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                            const SizedBox(height: 12),
                            const Text(
                              'Welcome to Kilimomkononi Education — learn smart farming!',
                              style: TextStyle(fontSize: 15, color: Colors.white70),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _role == EduRole.headteacher
                                  ? 'Lead with vision today'
                                  : _role == EduRole.teacher
                                      ? 'Ready to inspire today?'
                                      : 'Ready to grow your future?',
                              style: const TextStyle(fontSize: 17, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 180,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _getRoleImages(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      '${_capitalize(_role?.name ?? 'User')} • $schoolName',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  if (classIdNotifier.value != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Class: ${_formatGradeDisplay(classIdNotifier.value)}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 15),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          if (_role == EduRole.headteacher ||
              _role == EduRole.teacher ||
              _role == EduRole.mainadmin)
            Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: _buildApprovalAccessCard(),
            ),

          if (_role == EduRole.teacher || _role == EduRole.headteacher) ...[
            _buildClassSelectorButton(schoolName),
            const SizedBox(height: 24),
          ],

          Row(
            children: [
              const Icon(Icons.dashboard_customize, size: 36, color: Colors.green),
              const SizedBox(width: 12),
              Text('Quick Access',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),

          if (classIdNotifier.value == null)
            Card(
              color: Colors.orange.shade50,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange),
                    SizedBox(width: 12),
                    Expanded(
                        child: Text(
                            'Please select a class to view content.',
                            style: TextStyle(fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
            ),

          if (classIdNotifier.value != null) ...[
            _buildQuizSummaryCard(schoolName),

            // ←←← THIS WAS MISSING FOR STUDENTS ←←←
            if (_role == EduRole.student) ...[
              const SizedBox(height: 12),
              _buildStudentSimulationsCard(schoolName),
            ],

            if (_role == EduRole.teacher) ...[
              const SizedBox(height: 12),
              _buildEssaySubmissionsCard(schoolName),
              const SizedBox(height: 12),
              _buildSimulationSubmissionsCard(schoolName),
              const SizedBox(height: 12),
              _buildSummaryCard(
                title: 'View Students',
                studentCountNotifier: _studentCount,
                onTap: () => _openScreen(
                  ViewStudentsScreen(
                    schoolName: schoolName,
                    classIdNotifier: classIdNotifier,
                    onClose: () => setState(() => _selectedFeature = null),
                  ),
                ),
              ),
            ],
          ],

          const SizedBox(height: 32),
          // Recent Activity card (unchanged)
          Row(
            children: [
              const Icon(Icons.rss_feed, size: 36, color: Colors.green),
              const SizedBox(width: 12),
              Text('Recent Activity',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable: _feedList,
              builder: (_, feed, _) {
                if (feed.isEmpty) {
                  return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                          child: Text('No recent activity yet',
                              style: TextStyle(color: Colors.grey))));
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: feed.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final item = feed[i];
                    final isQuiz = item['type'] == 'quiz';
                    final isEssay = item['quizType'] == 'essay';
                    final time = (item['createdAt'] as Timestamp?)?.toDate();
                    final ago = time != null ? _formatDate(time) : 'Just now';
                    final schoolName = _userData?['schoolName'] as String? ?? '';
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: isEssay
                            ? Colors.purple.shade50
                            : isQuiz
                                ? Colors.blue.shade50
                                : Colors.orange.shade50,
                        child: Icon(
                          isEssay
                              ? Icons.edit_note
                              : isQuiz
                                  ? Icons.quiz_outlined
                                  : Icons.science_outlined,
                          color: isEssay
                              ? Colors.purple.shade700
                              : isQuiz
                                  ? Colors.blue.shade700
                                  : Colors.orange.shade700,
                        ),
                      ),
                      title: Text(item['title'] ?? 'Untitled',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                      subtitle: Text('$ago • ${item['module'] ?? ''}'),
                      trailing: Icon(Icons.chevron_right,
                          color: Colors.grey.shade400),
                      onTap: classIdNotifier.value == null
                          ? null
                          : () => _openScreen(QuizHome(
                                classId: classIdNotifier.value!,
                                schoolName: schoolName,
                                initialTab: isEssay
                                    ? QuizHomeTab.essays
                                    : QuizHomeTab.quizzes,
                                onClose: () => setState(
                                    () => _selectedFeature = null),
                              )),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    ),
  );
}

  // ── School code pill widget (reused in header + drawer + rail) ──────
  Widget _buildSchoolCodePill(String code) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: GestureDetector(
        onTap: () {
          Clipboard.setData(ClipboardData(text: code));
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('School code $code copied!'),
            backgroundColor: Colors.green.shade700,
          ));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white30, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.vpn_key, color: Colors.white70, size: 15),
              const SizedBox(width: 6),
              Text(code,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5)),
              const SizedBox(width: 6),
              const Icon(Icons.copy, color: Colors.white54, size: 13),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApprovalAccessCard() {
    return Card(
      elevation: 4,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ApprovalManagementScreen(
                schoolName: _userData!['schoolName'],
                currentUserRole: _role!,
                classId: _role == EduRole.teacher
                    ? classIdNotifier.value
                    : null,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.purple.shade50,
                child: Icon(Icons.approval,
                    size: 28, color: Colors.purple.shade700),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _role == EduRole.mainadmin
                          ? 'Manage Headteacher Approvals'
                          : _role == EduRole.headteacher
                              ? 'Manage Teacher Approvals'
                              : 'Manage Student Approvals',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _role == EduRole.mainadmin
                          ? 'Review headteachers for your school'
                          : _role == EduRole.headteacher
                              ? 'Review teachers in your school'
                              : 'Approve students in your class',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingApprovalScreen(String schoolName, String fullName) {
    String statusMessage, actionMessage;
    IconData statusIcon;
    Color statusColor = Colors.orange;

    if (_approvalStatus == ApprovalStatus.pending) {
      statusMessage = 'Approval Pending';
      statusIcon = Icons.hourglass_empty;
      final requestedRole = _userData?['requestedRole'] ?? 'user';
      actionMessage = requestedRole == 'teacher'
          ? 'Your teacher account is awaiting headteacher approval.'
          : requestedRole == 'student'
              ? 'Your student account is awaiting teacher approval.'
              : 'Your account is awaiting approval.';
    } else if (_approvalStatus == ApprovalStatus.denied) {
      statusMessage = 'Access Denied';
      statusIcon = Icons.cancel;
      statusColor = Colors.red;
      actionMessage = 'Your request was denied. Contact your school admin.';
    } else {
      statusMessage = 'Account Setup';
      statusIcon = Icons.settings;
      statusColor = Colors.blue;
      actionMessage = 'Complete your profile to get started.';
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 24, horizontal: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                      colors: [Color(0xFF43A047), Color(0xFF66BB6A)]),
                ),
                child: Column(
                  children: [
                    Text('Hello, $fullName!',
                        style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(height: 12),
                    Text('Your account is being reviewed.',
                        style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(statusIcon, size: 80, color: statusColor),
                    const SizedBox(height: 16),
                    Text(statusMessage,
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: statusColor)),
                    const SizedBox(height: 12),
                    Text(actionMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    ValueNotifier<List<Map<String, dynamic>>>? listNotifier,
    ValueNotifier<int>? studentCountNotifier,
    required VoidCallback onTap,
  }) {
    final isStudents = title == 'View Students';
    final icon = isStudents ? Icons.group : Icons.quiz;
    final iconColor =
        isStudents ? Colors.green.shade700 : Colors.blue.shade700;
    final bgColor =
        isStudents ? Colors.green.shade50 : Colors.blue.shade50;

    return Card(
      elevation: 4,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                      radius: 24,
                      backgroundColor: bgColor,
                      child: Icon(icon, size: 28, color: iconColor)),
                  const SizedBox(width: 16),
                  Expanded(
                      child: Text(title,
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold))),
                  const Icon(Icons.arrow_forward_ios, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 16),
              if (listNotifier != null)
                ValueListenableBuilder<List<Map<String, dynamic>>>(
                  valueListenable: listNotifier,
                  builder: (_, data, _) {
                    if (data.isEmpty) {
                      return const Text('No items yet',
                          style: TextStyle(color: Colors.grey));
                    }
                    final grouped = <String, int>{};
                    for (var item in data) {
                      final module = item['module'] ?? 'Unknown';
                      grouped.update(module, (v) => v + 1,
                          ifAbsent: () => 1);
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: grouped.entries
                          .take(3)
                          .map((e) => Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 2),
                                child: Text('• ${e.key}: ${e.value}',
                                    style:
                                        const TextStyle(fontSize: 14)),
                              ))
                          .toList(),
                    );
                  },
                )
              else if (studentCountNotifier != null)
                ValueListenableBuilder<int>(
                  valueListenable: studentCountNotifier,
                  builder: (_, count, _) {
                    return Text(
                      '$count ${count == 1 ? 'student' : 'students'} enrolled',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: count > 0
                            ? Colors.green.shade700
                            : Colors.grey.shade600,
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Class selector button ──────────────────────────────────────────
  Widget _buildClassSelectorButton(String schoolName) {
    final currentId = classIdNotifier.value;
    final currentLabel =
        currentId != null ? _formatGradeDisplay(currentId) : 'Select Class';
    final tierLabel = currentId != null ? _getTierLabel(currentId) : '';

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _ClassPickerSheet(
          schoolName: schoolName,
          currentClassId: classIdNotifier.value,
          userRole: _role ?? EduRole.student,
          // FIX #1 — pass school data so teacher can add new classes
          schoolData: _userData,
          onClassSelected: (id) {
            classIdNotifier.value = id;
            _saveCurrentClassId(id);
            setState(() => _selectedClassId = id);
          },
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: currentId != null
                ? const Color(0xFF003900)
                : Colors.grey.shade300,
            width: currentId != null ? 2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF003900).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.class_,
                color: Color(0xFF003900), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentId != null ? 'Active Class' : 'No Class Selected',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(currentLabel,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A))),
                if (tierLabel.isNotEmpty)
                  Text(tierLabel,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Icon(Icons.keyboard_arrow_down_rounded,
              color: Colors.grey.shade500, size: 26),
        ]),
      ),
    );
  }

  String _getTierLabel(String classId) {
  if (classId.contains('|')) {
    final sys = classId.split('|').length > 1
        ? classId.split('|')[1]
        : 'cbcJunior';
    switch (sys) {
      case 'cbcPrimary': return 'Primary • CBC';
      case 'cbcJunior':  return 'Junior Secondary • CBC';
      case 'cbcSenior':  return 'Senior Secondary • CBC';
      case 'eightFourFour': return '8-4-4 System (Form 1–4)'; // ← improved
      default: return sys;
    }
  }
  if (classId.toLowerCase().contains('_eightfourfour_')) {
    return '8-4-4 System (Form 1–4)';
  }
    if (classId.toLowerCase().contains('_junior_')) {
      return 'Junior Secondary • CBC';
    }
    if (classId.toLowerCase().contains('_senior_')) {
      return 'Senior Secondary • CBC';
    }
    if (classId.toLowerCase().contains('_primary_')) return 'Primary • CBC';
    return '';
  }

  Widget _buildQuizSummaryCard(String schoolName) {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: _quizList,
      builder: (_, quizzes, _) {
        final mcqCount = quizzes.where((q) => 
          q['quizType'] == 'mcq' || q['quizType'] == 'mixed').length;
        final essayCount = quizzes.where((q) => 
          q['quizType'] == 'essay' || q['quizType'] == 'mixed').length;

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.blue.shade50,
                    child: const Icon(Icons.quiz, size: 28, color: Colors.blue),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text('Quizzes & Essay Assignments',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 16),

                if (quizzes.isEmpty)
                  const Text('No quizzes created yet', style: TextStyle(color: Colors.grey))
                else ...[
                  InkWell(
                    onTap: () => _openScreen(QuizHome(
                      classId: classIdNotifier.value!,
                      schoolName: schoolName,
                      initialTab: QuizHomeTab.quizzes,
                    )),
                    child: _quizRow('Multiple Choice Quizzes', mcqCount, Colors.blue),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _openScreen(QuizHome(
                      classId: classIdNotifier.value!,
                      schoolName: schoolName,
                      initialTab: QuizHomeTab.essays,
                    )),
                    child: _quizRow('Essay Assignments', essayCount, Colors.purple),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _quizRow(String title, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color))),
          Text('$count', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_ios, size: 14, color: color.withOpacity(0.6)),
        ],
      ),
    );
  }

  // ── NEW: Student Simulations Card (under Quick Access for students) ─────
  Widget _buildStudentSimulationsCard(String schoolName) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openScreen(SimulationHome(
          classId: classIdNotifier.value ?? '',
          schoolName: schoolName,
          role: _role ?? EduRole.student,
        )),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.teal.shade50,
                child: const Icon(Icons.sports_esports, size: 28, color: Colors.teal),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text('My Simulations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  // ── Essay Submissions Card (teacher dashboard) ──────────────────────
  Widget _buildEssaySubmissionsCard(String schoolName) {
    return ValueListenableBuilder<Map<String, Map<String, int>>>(
      valueListenable: _essaySubmissionGroups,
      builder: (_, groups, _) {
        final totalPending =
            groups.values.fold(0, (s, v) => s + (v['pending'] ?? 0));
        final totalAll =
            groups.values.fold(0, (s, v) => s + (v['total'] ?? 0));

        // Module display-name order (mirrors quiz card)
        const moduleOrder = [
          'Farming Tips', 'Market Price', 'Weather Forecast', 'Manuals',
          'Farm Management', 'Field Data', 'Pest', 'Disease',
        ];
        final sortedEntries = groups.entries.toList()
          ..sort((a, b) {
            final ai = moduleOrder.indexOf(a.key);
            final bi = moduleOrder.indexOf(b.key);
            if (ai == -1 && bi == -1) return a.key.compareTo(b.key);
            if (ai == -1) return 1;
            if (bi == -1) return -1;
            return ai.compareTo(bi);
          });

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: classIdNotifier.value == null
                ? null
                : () => _openScreen(
                      TeacherEssayReviewScreen(
                        classId:    classIdNotifier.value!,
                        schoolName: schoolName,
                      ),
                    ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header row ────────────────────────────────────
                  Row(children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.deepOrange.shade50,
                      child: Icon(Icons.rate_review,
                          size: 28, color: Colors.deepOrange.shade600),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Essay Submissions',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(
                            totalAll == 0
                                ? 'No submissions yet'
                                : totalPending > 0
                                    ? '$totalPending of $totalAll awaiting your review'
                                    : 'All $totalAll submissions reviewed ✓',
                            style: TextStyle(
                              fontSize: 12,
                              color: totalPending > 0
                                  ? Colors.deepOrange.shade700
                                  : Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Pending badge
                    if (totalPending > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.deepOrange.shade600,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$totalPending',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                        ),
                      ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_ios,
                        color: Colors.grey, size: 15),
                  ]),

                  // ── Module breakdown rows ─────────────────────────
                  if (groups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text('Students have not submitted any essay answers yet.',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 13)),
                    )
                  else ...[
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    ...sortedEntries.map((e) {
                      final module  = e.key;
                      final pending = e.value['pending'] ?? 0;
                      final total   = e.value['total']   ?? 0;
                      final allDone = pending == 0;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(children: [
                          Icon(
                            allDone
                                ? Icons.check_circle_outline
                                : Icons.pending_outlined,
                            size: 15,
                            color: allDone
                                ? Colors.green.shade400
                                : Colors.deepOrange.shade400,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(module,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500)),
                          ),
                          // Right-side badge
                          if (!allDone)
                            _ReviewBadge(
                              label: '$pending pending',
                              color: Colors.deepOrange,
                            )
                          else
                            _ReviewBadge(
                              label: '$total reviewed',
                              color: Colors.green,
                            ),
                        ]),
                      );
                    }),
                    const SizedBox(height: 6),
                    // Tap hint
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Tap to review & finalise scores →',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.deepOrange.shade400,
                            fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Simulation Submissions Card (teacher dashboard) ─────────────────
  Widget _buildSimulationSubmissionsCard(String schoolName) {
    return ValueListenableBuilder<Map<String, Map<String, int>>>(
      valueListenable: _simSubmissionGroups,
      builder: (_, groups, _) {
        final totalPending =
            groups.values.fold(0, (s, v) => s + (v['pending'] ?? 0));
        final totalAll =
            groups.values.fold(0, (s, v) => s + (v['total'] ?? 0));

        const moduleOrder = [
          'Farming Tips', 'Market Price', 'Weather Forecast', 'Manuals',
          'Farm Management', 'Field Data', 'Pest', 'Disease',
        ];
        final sortedEntries = groups.entries.toList()
          ..sort((a, b) {
            final ai = moduleOrder.indexOf(a.key);
            final bi = moduleOrder.indexOf(b.key);
            if (ai == -1 && bi == -1) return a.key.compareTo(b.key);
            if (ai == -1) return 1;
            if (bi == -1) return -1;
            return ai.compareTo(bi);
          });

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: classIdNotifier.value == null
                ? null
                : () => _openScreen(
                      TeacherEssayReviewScreen(
                        classId:    classIdNotifier.value!,
                        schoolName: schoolName,
                      ),
                    ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──────────────────────────────────────────
                  Row(children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.teal.shade50,
                      child: Icon(Icons.sports_esports,
                          size: 28, color: Colors.teal.shade700),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Simulation Results',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(
                            totalAll == 0
                                ? 'No simulation results yet'
                                : totalPending > 0
                                    ? '$totalPending of $totalAll awaiting your review'
                                    : 'All $totalAll results reviewed ✓',
                            style: TextStyle(
                              fontSize: 12,
                              color: totalPending > 0
                                  ? Colors.teal.shade700
                                  : Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (totalPending > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade600,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('$totalPending',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                      ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_ios,
                        color: Colors.grey, size: 15),
                  ]),

                  // ── Module breakdown ─────────────────────────────────
                  if (groups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                          'Students have not completed any simulations yet.',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 13)),
                    )
                  else ...[
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    ...sortedEntries.map((e) {
                      final pending = e.value['pending'] ?? 0;
                      final total   = e.value['total']   ?? 0;
                      final allDone = pending == 0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(children: [
                          Icon(
                            allDone
                                ? Icons.check_circle_outline
                                : Icons.pending_outlined,
                            size: 15,
                            color: allDone
                                ? Colors.green.shade400
                                : Colors.teal.shade400,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(e.key,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500)),
                          ),
                          _ReviewBadge(
                            label: allDone
                                ? '$total reviewed'
                                : '$pending pending',
                            color:
                                allDone ? Colors.green : Colors.teal,
                          ),
                        ]),
                      );
                    }),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Tap to review AI marks & finalise →',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.teal.shade400,
                            fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Drawer ─────────────────────────────────────────────────────────
  Widget _buildDrawer(String schoolName) {
    final schoolCode = _userData?['schoolCode'] as String? ?? '';
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
            decoration:
                const BoxDecoration(color: Color(0xFF003900)),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _editProfile,
                  child: CircleAvatar(
                    radius: 42,
                    backgroundImage: _profileImageBytes != null
                        ? MemoryImage(_profileImageBytes!)
                        : null,
                    child: _profileImageBytes == null
                        ? const Icon(Icons.person,
                            size: 50, color: Colors.white70)
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _userData?['fullName'] ?? 'User',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  '${_capitalize(_role?.name ?? 'User')} • $schoolName',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                // FIX #2 — school code in drawer for headteachers
                if (_role == EduRole.headteacher && schoolCode.isNotEmpty)
                  _buildSchoolCodePill(schoolCode),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ..._drawerItems(schoolName, classIdNotifier.value ?? ''),
                const Divider(height: 1),
                _buildDrawerItem(Icons.logout, 'Logout', _handleLogout),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _drawerItems(String schoolName, String classId) {
    return [
      _buildDrawerItem(Icons.lightbulb, 'Farming Tips',
          () => _navigateOrOpen(EducationFarmingTips(
              role: _role!, schoolName: schoolName, classId: classId))),
      _buildDrawerItem(Icons.cloud, 'Weather Forecast',
          () => _navigateOrOpen(EducationWeatherForecast(
              role: _role!, schoolName: schoolName, classId: classId))),
      _buildDrawerItem(Icons.terrain, 'Field Data Input',
          () => _navigateOrOpen(FieldHome(
              role: _role!, schoolName: schoolName, classId: classId))),
      _buildDrawerItem(Icons.bug_report, 'Pest & Disease',
          () => _navigateOrOpen(PestDiseaseHome(
              role: _role!, schoolName: schoolName, classId: classId))),
      _buildDrawerItem(Icons.account_balance_wallet, 'Farm Management',
          () => _navigateOrOpen(FarmManagementScreen(
              role: _role!, classId: classId, schoolName: schoolName))),
      _buildDrawerItem(Icons.price_check, 'Market Tips',
          () => _navigateOrOpen(EducationMarketPrice(
              role: _role!, schoolName: schoolName, classId: classId))),
      _buildDrawerItem(Icons.book, 'Manuals',
          () => _navigateOrOpen(EducationManuals(
              role: _role!, schoolName: schoolName, classId: classId))),
      _buildDrawerItem(
          Icons.folder,
          'Resources',
          () => _navigateOrOpen(EducationResources(
              role: _role ?? EduRole.student,
              schoolName: schoolName,
              classId: classId))),
      _buildDrawerItem(
          Icons.chat,
          'Chat',
          () => _navigateOrOpen(EducationChat(
              role: _role ?? EduRole.student,
              schoolName: schoolName,
              classId: classId,
              userName: _userData?['fullName'] ?? 'User'))),
      _buildDrawerItem(
          Icons.psychology_outlined,
          'Shamba AI Tutor',
          () => _navigateOrOpen(TutorChatScreen(
              topic:     _currentModuleTopic(),
              grade:     _formatGradeDisplay(classId),
              classId:   classId,
              isPrimary: _isPrimaryClassId(classId)))),
      _buildDrawerItem(
          Icons.analytics_outlined,
          'Plot Analysis',
          () => _navigateOrOpen(EducationPlotAnalysisScreen(
              role: _role ?? EduRole.student, schoolName: schoolName,
              classId:    classId))),
      _buildDrawerItem(Icons.settings, 'Settings',
          () => _navigateOrOpen(const SettingsScreen(isEducation: true))),
    ];
  }

  Widget _buildDrawerItem(
      IconData icon, String title, VoidCallback onTap) {
    return ListTile(
        leading: Icon(icon), title: Text(title), onTap: onTap);
  }

  void _navigateOrOpen(Widget page) {
    Navigator.pop(context);
    if (_getScreenType(context) == ScreenType.mobile) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    } else {
      setState(() => _selectedFeature = page);
    }
  }

  // ── Left rail (tablet/desktop) ─────────────────────────────────────
  Widget _buildLeftRail(
      String schoolName, String classId, ScreenType type) {
    final width = type == ScreenType.desktop ? 280.0 : 240.0;
    final schoolCode = _userData?['schoolCode'] as String? ?? '';
    return Container(
      width: width,
      color: const Color(0xFF003900),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
            child: GestureDetector(
              onTap: _editProfile,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: _profileImageBytes != null
                        ? MemoryImage(_profileImageBytes!)
                        : null,
                    child: _profileImageBytes == null
                        ? const Icon(Icons.person,
                            size: 50, color: Colors.white70)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _userData?['fullName'] ?? 'User',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    '${_capitalize(_role?.name ?? 'User')} • $schoolName',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  // FIX #2 — school code in left rail for headteachers
                  if (_role == EduRole.headteacher && schoolCode.isNotEmpty)
                    _buildSchoolCodePill(schoolCode),
                ],
              ),
            ),
          ),
          const Divider(color: Colors.white24),
          Expanded(
            child: ListView(
              children: [
                _railItem(Icons.lightbulb, 'Farming Tips', 0,
                    () => _openInRightPane(EducationFarmingTips(
                        role: _role!, schoolName: schoolName, classId: classId))),
                _railItem(Icons.cloud, 'Weather Forecast', 1,
                    () => _openInRightPane(EducationWeatherForecast(
                        role: _role!, schoolName: schoolName, classId: classId))),
                _railItem(Icons.terrain, 'Field Data Input', 2,
                    () => _openInRightPane(FieldHome(
                        role: _role!, schoolName: schoolName, classId: classId,
                        showAppBar: false))),
                _railItem(Icons.bug_report, 'Pest & Disease', 3,
                    () => _openInRightPane(PestDiseaseHome(
                        role: _role!, schoolName: schoolName, classId: classId))),
                _railItem(Icons.account_balance_wallet, 'Farm Management', 4,
                    () => _openInRightPane(FarmManagementScreen(
                        role: _role!, classId: classId, schoolName: schoolName,
                        showAppBar: false))),
                _railItem(Icons.price_check, 'Market Tips', 5,
                    () => _openInRightPane(EducationMarketPrice(
                        role: _role!, schoolName: schoolName, classId: classId))),
                _railItem(Icons.book, 'Manuals', 6,
                    () => _openInRightPane(EducationManuals(
                        role: _role!, schoolName: schoolName, classId: classId))),
                _railItem(Icons.folder, 'Resources', 7,
                    () => _openInRightPane(EducationResources(
                        role: _role ?? EduRole.student,
                        schoolName: schoolName,
                        classId: classId))),
                _railItem(Icons.chat, 'Chat', 8,
                    () => _openInRightPane(EducationChat(
                        role: _role ?? EduRole.student,
                        schoolName: schoolName,
                        classId: classId,
                        userName: _userData?['fullName'] ?? 'User'))),
                _railItem(Icons.psychology_outlined, 'Shamba AI Tutor', 9,
                    () => _openInRightPane(TutorChatScreen(
                        topic:     _currentModuleTopic(),
                        grade:     _formatGradeDisplay(classId),
                        classId:   classId,
                        isPrimary: _isPrimaryClassId(classId)))),
                _railItem(Icons.analytics_outlined, 'Plot Analysis', 10,
                    () => _openInRightPane(EducationPlotAnalysisScreen(
                        role: _role ?? EduRole.student, schoolName: schoolName,
                        classId:    classId))),
                _railItem(Icons.settings, 'Settings', 11,
                    () => _openInRightPane(const SettingsScreen(isEducation: true))),
              ],
            ),
          ),
          const Divider(color: Colors.white24),
          _railItem(Icons.logout, 'Logout', 12, _handleLogout),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _railItem(
      IconData icon, String title, int index, VoidCallback onTap) {
    final selected = _selectedRailIndex == index;
    return ListTile(
      leading: Icon(icon,
          color: selected ? Colors.yellow : Colors.white70),
      title: Text(title,
          style: TextStyle(
              color: selected ? Colors.yellow : Colors.white,
              fontSize: 15)),
      selected: selected,
      selectedTileColor: Colors.white10,
      onTap: () {
        setState(() => _selectedRailIndex = index);
        onTap();
      },
    );
  }

  // ── Tutor helpers ──────────────────────────────────────────────────
  bool _isPrimaryClassId(String classId) {
    if (classId.contains('cbcPrimary') ||
        classId.toLowerCase().contains('_primary_')) {
      return true;
    }
    final match = RegExp(r'_(\d+)$').firstMatch(classId);
    return match != null && (int.tryParse(match.group(1)!) ?? 7) <= 6;
  }

  String _currentModuleTopic() {
    final feature = _selectedFeature?.toString().toLowerCase() ?? '';
    const topicMap = {
      'pest':      'Pest Management',
      'disease':   'Disease Management',
      'field':     'Field Data & Operations',
      'market':    'Market Trading',
      'weather':   'Weather & Climate',
      'farm':      'Farm Financial Management',
      'planting':  'Crop Planting & Farm Setup',
      'manuals':   'Agricultural Manuals',
      'farming':   'Farming Tips',
      'quiz':      'Agricultural Science',
      'simulation':'Agricultural Science',
    };
    for (final entry in topicMap.entries) {
      if (feature.contains(entry.key)) return entry.value;
    }
    return 'Agricultural Science';
  }
}

extension _FirstWhereOrNull<E> on List<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}

// ═══════════════════════════════════════════════════════════════════
//  _ReviewBadge — small pill used in the essay submissions card
// ═══════════════════════════════════════════════════════════════════
class _ReviewBadge extends StatelessWidget {
  final String label;
  final Color  color;
  const _ReviewBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color:        color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize:   11,
                color:      color.withOpacity(0.9),
                fontWeight: FontWeight.w600)),
      );
}

// ═══════════════════════════════════════════════════════════════════
//  CLASS SELECTOR BOTTOM SHEET
//  FIX #1 — Teachers can add themselves to a new class from here.
//  They are approved users; they don't need headteacher involvement
//  for class switching/adding. The sheet reads their existing classIds
//  for switching, AND shows all available school classes so they can
//  join one they haven't been assigned to yet.
// ═══════════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════
//  CLASS PICKER BOTTOM SHEET
//  Groups classes by tier with expandable accordion sections.
//  Fixes: overflow, Standard names, primary routing, teacher self-add.
// ═══════════════════════════════════════════════════════════════
class _ClassPickerSheet extends StatefulWidget {
  final String schoolName;
  final String? currentClassId;
  final EduRole userRole;
  final void Function(String classId) onClassSelected;

  const _ClassPickerSheet({
    required this.schoolName,
    required this.currentClassId,
    required this.userRole,
    required this.onClassSelected, Map<String, dynamic>? schoolData,
  });

  @override
  State<_ClassPickerSheet> createState() => _ClassPickerSheetState();
}

class _ClassPickerSheetState extends State<_ClassPickerSheet> {
  late Future<_ClassPickerData> _dataFuture;
  // Which tier accordion is open
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadClasses();
    // Auto-expand the tier of the current class
    if (widget.currentClassId != null) {
      _expanded.add(_fmtTier(widget.currentClassId!));
    }
  }

  Future<_ClassPickerData> _loadClasses() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return _ClassPickerData(assigned: [], available: []);

  final doc = await FirebaseFirestore.instance
      .collection('EducationUsers').doc(uid).get();
  final data = doc.data() ?? {};
  final List<dynamic> rawClassIds = data['classIds'] ?? [];
  final schoolName = data['schoolName'] as String? ?? '';

  // ✅ Fetch all assigned student counts IN PARALLEL
  final assignedCounts = await Future.wait(
    rawClassIds.map((id) => _countStudents(schoolName, id as String)),
  );
  final assigned = <_ClassInfo>[
    for (var i = 0; i < rawClassIds.length; i++)
      _ClassInfo(
        id: rawClassIds[i] as String,
        label: _fmtGrade(rawClassIds[i] as String),
        tier: _fmtTier(rawClassIds[i] as String),
        studentCount: assignedCounts[i],
      ),
  ];
  assigned.sort((a, b) => _tierOrder(a.tier).compareTo(_tierOrder(b.tier)));

  List<_ClassInfo> available = [];
  if (widget.userRole == EduRole.teacher) {
    final assignedSet = rawClassIds.cast<String>().toSet();
    final allIds = await _loadAllSchoolClasses(schoolName);
    final unassigned = allIds.where((id) => !assignedSet.contains(id)).toList();

    // ✅ Fetch all available student counts IN PARALLEL
    final availableCounts = await Future.wait(
      unassigned.map((id) => _countStudents(schoolName, id)),
    );
    available = [
      for (var i = 0; i < unassigned.length; i++)
        _ClassInfo(
          id: unassigned[i],
          label: _fmtGrade(unassigned[i]),
          tier: _fmtTier(unassigned[i]),
          studentCount: availableCounts[i],
        ),
    ];
    available.sort((a, b) => _tierOrder(a.tier).compareTo(_tierOrder(b.tier)));
  }

  return _ClassPickerData(assigned: assigned, available: available);
}

  int _tierOrder(String tier) {
    if (tier.contains('Primary')) return 0;
    if (tier.contains('Junior')) return 1;
    if (tier.contains('Senior')) return 2;
    if (tier.contains('8-4-4')) return 3;
    return 4;
  }

  Future<int> _countStudents(String schoolName, String classId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('EducationUsers')
          .where('role', isEqualTo: 'student')
          .where('schoolName', isEqualTo: schoolName)
          .where('currentClassId', isEqualTo: classId)
          .count().get();
      return snap.count ?? 0;
    } catch (_) { return 0; }
  }

  Future<List<String>> _loadAllSchoolClasses(String schoolName) async {
    final Set<String> ids = {};
    try {
      final snap = await FirebaseFirestore.instance
          .collection('Schools')
          .where('schoolName', isEqualTo: schoolName)
          .limit(1).get();
      if (snap.docs.isNotEmpty) {
        final sd = snap.docs.first.data();
        final tiers = List<String>.from(sd['educationTiers'] ?? []);
        final normalized = schoolName.replaceAll(' ', '_');
        final tierGrades = {
          'primary': ['1','2','3','4','5','6'],
          'junior':  ['7','8','9'],
          'senior':  ['10','11','12'],
          '844':     ['1','2','3','4'],
        };
        for (final tier in tiers) {
          for (final grade in (tierGrades[tier] ?? [])) {
            final sys = tier == '844' ? 'eightfourfour' : tier;
            ids.add('${normalized}_${sys}_$grade');
          }
        }
      }
    } catch (_) {}
    return ids.toList()..sort();
  }

  // ── Grade label helpers ───────────────────────────────────────
 static String _fmtGrade(String classId) {
  final match = RegExp(r'_(primary|junior|senior|eightfourfour)_(\d+)$')
      .firstMatch(classId.toLowerCase());
  if (match != null) {
    final sys = match.group(1)!;
    final num = match.group(2)!;
    if (sys == 'eightfourfour') {
      return 'Form $num';
    }
    return 'Grade $num';
  }

  // Pipe format fallback (cbc...)
  if (classId.contains('|')) {
    final parts = classId.split('|');
    final num = parts[0];
    final sys = parts.length > 1 ? parts[1] : 'cbcJunior';
    if (sys == 'eightFourFour') return 'Form $num';
    return 'Grade $num';
  }
  return classId;
}

  static String _fmtTier(String classId) {
    if (classId.toLowerCase().contains('_primary_')) return 'Primary CBC';
    if (classId.toLowerCase().contains('_junior_'))  return 'Junior Secondary CBC';
    if (classId.toLowerCase().contains('_senior_'))  return 'Senior Secondary CBC';
    if (classId.toLowerCase().contains('_eightfourfour_')) return '8-4-4 System';
    if (classId.contains('cbcPrimary'))   return 'Primary CBC';
    if (classId.contains('cbcJunior'))    return 'Junior Secondary CBC';
    if (classId.contains('cbcSenior'))    return 'Senior Secondary CBC';
    if (classId.contains('eightFourFour')) return '8-4-4 System';
    return 'Class';
  }

  static Color _tierColor(String tier) {
    if (tier.contains('Primary'))  return const Color(0xFFFF8C00);
    if (tier.contains('Junior'))   return const Color(0xFF00897B);
    if (tier.contains('Senior'))   return const Color(0xFF1565C0);
    if (tier.contains('8-4-4'))    return const Color(0xFF6A1B9A);
    return Colors.grey;
  }

  static IconData _tierIcon(String tier) {
    if (tier.contains('Primary')) return Icons.child_care;
    if (tier.contains('Junior'))  return Icons.menu_book;
    if (tier.contains('Senior'))  return Icons.school;
    if (tier.contains('8-4-4'))   return Icons.account_balance;
    return Icons.class_;
  }

  bool _isPrimary(String classId) =>
      classId.toLowerCase().contains('_primary_') ||
      classId.contains('cbcPrimary');

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      // KEY FIX: constrain max height so it never overflows
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Switch Class',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    SizedBox(height: 2),
                    Text('Tap a tier to expand, then select your class',
                        style: TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),

          // Scrollable content — KEY FIX: Expanded so it doesn't overflow
          Expanded(
            child: FutureBuilder<_ClassPickerData>(
              future: _dataFuture,
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final pickerData = snap.data ??
                    _ClassPickerData(assigned: [], available: []);

                // Merge assigned + available for display
                // Group both by tier
                final allGrouped = <String, _TierGroup>{};

                for (final cls in pickerData.assigned) {
                  allGrouped.putIfAbsent(cls.tier, () =>
                      _TierGroup(tier: cls.tier)).assigned.add(cls);
                }
                for (final cls in pickerData.available) {
                  allGrouped.putIfAbsent(cls.tier, () =>
                      _TierGroup(tier: cls.tier)).available.add(cls);
                }

                final groups = allGrouped.values.toList()
                  ..sort((a, b) =>
                      _tierOrder(a.tier).compareTo(_tierOrder(b.tier)));

                if (groups.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.class_outlined,
                            size: 56, color: Colors.grey.shade300),
                        const SizedBox(height: 14),
                        const Text(
                          'No classes available yet. Contact your headteacher.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ]),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: groups.length,
                  itemBuilder: (_, i) => _buildTierAccordion(groups[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierAccordion(_TierGroup group) {
    final color = _tierColor(group.tier);
    final icon = _tierIcon(group.tier);
    final isOpen = _expanded.contains(group.tier);
    final hasAssigned = group.assigned.isNotEmpty;
    final hasAvailable = group.available.isNotEmpty;
    final total = group.assigned.length + group.available.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOpen ? color : Colors.grey.shade200,
          width: isOpen ? 2 : 1,
        ),
        color: isOpen ? color.withOpacity(0.03) : Colors.white,
      ),
      child: Column(
        children: [
          // Accordion header — always visible
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() {
              if (isOpen) {
                _expanded.remove(group.tier);
              } else {
                _expanded.add(group.tier);
              }
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: isOpen ? color : color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon,
                      color: isOpen ? Colors.white : color,
                      size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group.tier,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isOpen ? color : const Color(0xFF1A1A1A),
                          )),
                      Text(
                        hasAssigned
                            ? '${group.assigned.length} of your class${group.assigned.length == 1 ? '' : 'es'}'
                            : '$total available',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: isOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_down,
                      color: isOpen ? color : Colors.grey),
                ),
              ]),
            ),
          ),

          // Expanded content
          if (isOpen) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),

            // Assigned classes
            if (hasAssigned) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Row(children: [
                  Icon(Icons.check_circle_outline,
                      size: 13, color: color),
                  const SizedBox(width: 5),
                  Text('Your classes',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color)),
                ]),
              ),
              ...group.assigned.map((cls) =>
                  _buildClassTile(cls, color, isAdd: false)),
            ],

            // Available classes (teacher add mode)
            if (widget.userRole == EduRole.teacher && hasAvailable) ...[
              if (hasAssigned)
                const Divider(height: 1, indent: 16, endIndent: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Row(children: [
                  Icon(Icons.add_circle_outline,
                      size: 13, color: Colors.teal.shade600),
                  const SizedBox(width: 5),
                  Text('Add a class',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.teal.shade600)),
                ]),
              ),
              ...group.available.map((cls) =>
                  _buildClassTile(cls, Colors.teal, isAdd: true)),
            ],

            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

Widget _buildClassTile(_ClassInfo cls, Color color, {required bool isAdd}) {
  final isActive = cls.id == widget.currentClassId && !isAdd;
  final canRemove = !isAdd && !isActive && widget.userRole == EduRole.teacher;

  return GestureDetector(
    onTap: () {
      if (isAdd) {
        _addClassAndSwitch(cls.id);
      } else {
        widget.onClassSelected(cls.id);
        Navigator.pop(context);
        if (_isPrimary(cls.id)) {
          Future.microtask(() {
            if (context.mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil(
                  '/primary_home_screen', (_) => false);
            }
          });
        }
      }
    },
    child: Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isActive
            ? color.withOpacity(0.08)
            : isAdd
                ? Colors.teal.withOpacity(0.04)
                : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive
              ? color
              : isAdd
                  ? Colors.teal.shade200
                  : Colors.grey.shade200,
          width: isActive ? 2 : 1,
        ),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: isActive
                ? color
                : isAdd
                    ? Colors.teal.withOpacity(0.1)
                    : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isAdd ? Icons.add : Icons.class_,
            color: isActive ? Colors.white : isAdd ? Colors.teal : color,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(cls.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isActive
                        ? color
                        : isAdd
                            ? Colors.teal.shade700
                            : const Color(0xFF1A1A1A),
                  )),
              Text(
                isAdd
                    ? 'Tap to add & switch'
                    : '${cls.studentCount} student${cls.studentCount == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
        if (isActive)
          Icon(Icons.check_circle, color: color, size: 20),
        if (isAdd)
          Icon(Icons.arrow_forward_ios, color: Colors.teal.shade300, size: 14),
        // ── Remove button for non-active assigned classes ──
        if (canRemove)
          GestureDetector(
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Remove Class'),
                  content: Text(
                    'Remove ${cls.label} from your class list? '
                    'You can always re-add it later.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(
                          foregroundColor: Colors.red),
                      child: const Text('Remove'),
                    ),
                  ],
                ),
              );
              if (confirm == true) _removeClassFromTeacher(cls.id);
            },
            child: Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Icon(Icons.remove_circle_outline,
                  color: Colors.red.shade400, size: 18),
            ),
          ),
      ]),
    ),
  );
}

  Future<void> _addClassAndSwitch(String classId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('EducationUsers')
          .doc(uid)
          .update({
        'classIds': FieldValue.arrayUnion([classId]),
        'currentClassId': classId,
        'lastClassSwitch': FieldValue.serverTimestamp(),
      });
      widget.onClassSelected(classId);
      if (context.mounted) Navigator.pop(context);
      if (_isPrimary(classId) && context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
            '/primary_home_screen', (_) => false);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }


Future<void> _removeClassFromTeacher(String classId) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  // Don't allow removing the currently active class
  if (classId == widget.currentClassId) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot remove your active class. Switch to another class first.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
    return;
  }

  try {
    await FirebaseFirestore.instance
        .collection('EducationUsers')
        .doc(uid)
        .update({
      'classIds': FieldValue.arrayRemove([classId]),
    });
    // Refresh the sheet
    if (mounted) {
      setState(() => _dataFuture = _loadClasses());
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing class: $e')),
      );
    }
  }
}
}

class _TierGroup {
  final String tier;
  final List<_ClassInfo> assigned = [];
  final List<_ClassInfo> available = [];
  _TierGroup({required this.tier});
}

class _ClassPickerData {
  final List<_ClassInfo> assigned;
  final List<_ClassInfo> available;
  const _ClassPickerData({required this.assigned, required this.available});
}

class _ClassInfo {
  final String id;
  final String label;
  final String tier;
  final int studentCount;
  const _ClassInfo({
    required this.id,
    required this.label,
    required this.tier,
    required this.studentCount,
  });
}