// lib/education/education_home.dart
// ignore_for_file: avoid_types_as_parameter_names

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kilimomkononi/education/approval_management_screen.dart';
import 'package:kilimomkononi/education/education_farming_tips.dart';
import 'package:kilimomkononi/education/education_manuals.dart';
import 'package:kilimomkononi/education/education_market_price.dart';
import 'package:kilimomkononi/education/education_weather_forecast.dart';
import 'package:kilimomkononi/education/farm_management/farm_management_screen.dart';
import 'package:kilimomkononi/education/field/field_home.dart';
import 'package:kilimomkononi/education/pest/pest_disease_home.dart';
import 'package:kilimomkononi/education/quiz/quiz_home.dart';
import 'package:kilimomkononi/education/simulation/simulation_home.dart';
import 'package:kilimomkononi/education/teacher/view_students.dart';
import 'package:kilimomkononi/education/utils/class_id_notifier.dart';
import 'package:kilimomkononi/models/education_user.dart';
import 'package:kilimomkononi/screens/user_profile.dart';
import 'package:kilimomkononi/settings/settings_screen.dart';
import 'package:kilimomkononi/widgets/grade_selector.dart';
import 'package:logger/logger.dart';
import 'package:lottie/lottie.dart';
import 'package:rxdart/rxdart.dart';
import 'package:kilimomkononi/education/education_login.dart';
import 'package:kilimomkononi/utils/firestore_helper.dart';
import 'package:kilimomkononi/education/education_resources.dart';
import 'package:kilimomkononi/education/education_chat.dart';

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
        'eightFourFour': [
          'Standard 1', 'Standard 2', 'Standard 3', 'Standard 4',
          'Standard 5', 'Standard 6', 'Standard 7', 'Standard 8',
          'Form 1', 'Form 2', 'Form 3', 'Form 4',
        ],
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
        prefix = int.parse(num!) <= 8 ? 'Standard' : 'Form';
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
  final ValueNotifier<List<Map<String, dynamic>>> _simList = ValueNotifier([]);
  final ValueNotifier<int> _studentCount = ValueNotifier(0);
  final ValueNotifier<List<Map<String, dynamic>>> _feedList = ValueNotifier([]);

  bool _isLoading = true;
  String? _errorMessage;

  StreamSubscription? _quizSub;
  StreamSubscription? _simSub;
  StreamSubscription<QuerySnapshot>? _studentSub;

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
    _simList.dispose();
    _studentCount.dispose();
    _feedList.dispose();
    _quizSub?.cancel();
    _simSub?.cancel();
    _studentSub?.cancel();
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

      final featuresLocked = (parsedRole == EduRole.headteacher && approvalStatus != ApprovalStatus.approved) ||
          (parsedRole == EduRole.mainadmin && approvalStatus != ApprovalStatus.approved) ||
          (parsedRole == null || approvalStatus != ApprovalStatus.approved);

      setState(() {
        _userData = data;
        _profileImageBytes = imgBytes;
        _role = parsedRole;
        _selectedClassId = data['currentClassId'] as String?;
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
      final docRef = FirebaseFirestore.instance.collection('EducationUsers').doc(_userId);
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) return;
        final data = snap.data() as Map<String, dynamic>;
        final List<String> classIds = List<String>.from(data['classIds'] ?? []);
        if (!classIds.contains(classId)) classIds.add(classId);
        tx.update(docRef, {
          'currentClassId': classId,
          'classIds': classIds,
          'lastClassSwitch': FieldValue.serverTimestamp(),
        });
      });
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
      _simList.value = [];
      _studentCount.value = 0;
      _feedList.value = [];
      return;
    }

    _quizSub?.cancel();
    _simSub?.cancel();
    _studentSub?.cancel();

    _listenQuizzes(id);
    _listenSimulations(id);
    if (_role == EduRole.teacher) _listenStudentCount(id);
    _buildFeed();
  }

  void _listenQuizzes(String classId) {
    const collections = [
      'farming_content',
      'market_content',
      'weather_content',
      'manuals_content',
      'farm_management_content',
      'field_content',
      'pest_content',
      'disease_content',
    ];

    final moduleNames = {
      'farming_content': 'Farming Tips',
      'market_content': 'Market Price',
      'weather_content': 'Weather Forecast',
      'manuals_content': 'Manuals',
      'farm_management_content': 'Farm Management',
      'field_content': 'Field Data',
      'pest_content': 'Pest',
      'disease_content': 'Disease',
    };

    final streams = <Stream<List<Map<String, dynamic>>>>[];

    for (final coll in collections) {
      final collection = FirestoreHelper.getContentFromClassId(classId, coll);
      if (collection == null) continue;

      streams.add(
        collection
            .where('type', isEqualTo: 'quiz')
            .orderBy('createdAt', descending: true)
            .snapshots()
            .map((snapshot) => snapshot.docs.map((doc) {
                  final dataMap = doc.data() as Map<String, dynamic>?;
                  if (dataMap == null) return null;

                  return {
                    'id': doc.id,
                    'title': (dataMap['title'] as String?)?.trim().isNotEmpty == true
                        ? dataMap['title'] as String
                        : 'Untitled Quiz',
                    'module': moduleNames[coll] ?? 'Unknown',
                    'type': 'quiz',
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

  void _listenSimulations(String classId) {
    const collections = [
      'farming_content',
      'market_content',
      'weather_content',
      'manuals_content',
      'farm_management_content',
      'field_content',
      'pest_content',
      'disease_content',
    ];

    final moduleNames = {
      'farming_content': 'Farming Tips',
      'market_content': 'Market Price',
      'weather_content': 'Weather Forecast',
      'manuals_content': 'Manuals',
      'farm_management_content': 'Farm Management',
      'field_content': 'Field Data',
      'pest_content': 'Pest',
      'disease_content': 'Disease',
    };

    final streams = <Stream<List<Map<String, dynamic>>>>[];

    for (final coll in collections) {
      final collection = FirestoreHelper.getContentFromClassId(classId, coll);
      if (collection == null) continue;

      streams.add(
        collection
            .where('type', isEqualTo: 'simulation')
            .orderBy('createdAt', descending: true)
            .snapshots()
            .map((snapshot) => snapshot.docs.map((doc) {
                  final dataMap = doc.data() as Map<String, dynamic>?;
                  if (dataMap == null) return null;

                  return {
                    'id': doc.id,
                    'title': (dataMap['title'] as String?)?.trim().isNotEmpty == true
                        ? dataMap['title'] as String
                        : 'Untitled Simulation',
                    'module': moduleNames[coll] ?? 'Unknown',
                    'type': 'simulation',
                    'createdAt': dataMap['createdAt'] as Timestamp?,
                  };
                }).whereType<Map<String, dynamic>>().toList()),
      );
    }

    _simSub?.cancel();
    _simSub = CombineLatestStream.list(streams).listen((listOfLists) {
      final flatList = listOfLists.expand((list) => list).toList();
      flatList.sort((a, b) {
        final aTime = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
        final bTime = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });
      _simList.value = flatList;
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
      if (mounted) {
        _studentCount.value = snapshot.size;
      }
    }, onError: (error) {
      logger.e('Student count error: $error');
      if (mounted) _studentCount.value = 0;
    });
  }

  void _buildFeed() {
    final List<Map<String, dynamic>> all = [..._quizList.value, ..._simList.value];
    all.sort((a, b) {
      final Timestamp? timeA = a['createdAt'] as Timestamp?;
      final Timestamp? timeB = b['createdAt'] as Timestamp?;
      return (timeB?.toDate() ?? DateTime(1970))
          .compareTo(timeA?.toDate() ?? DateTime(1970));
    });
    _feedList.value = all.take(5).toList();
  }

  Future<void> _editProfile() async {
    if (_userData == null || _role == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          profileImageBytes: _profileImageBytes,
          fullName: _userData?['fullName'],
          schoolName: _userData?['schoolName'],
          role: _role!.name,
        ),
      ),
    ).then((_) => _fetchUserData());
  }

  void _onBottomNavTapped(int index) {
  setState(() {
    _selectedBottomIndex = index;
  });

  if (index == 0) {
    // Home - show dashboard
    setState(() {
      _selectedFeature = null;
      _selectedRailIndex = -1;
    });
  } else if (index == 1) {
    // Resources - navigate to it
    final resourcesScreen = EducationResources(
      role: _role ?? EduRole.student,
      schoolName: _userData?['schoolName'] ?? 'Unknown',
      classId: classIdNotifier.value ?? '',
    );
    
    // On mobile: push new screen, on tablet/desktop: open in right pane
    if (_getScreenType(context) == ScreenType.mobile) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => resourcesScreen));
    } else {
      setState(() => _selectedFeature = resourcesScreen);
    }
  } else if (index == 2) {
    // Chat - navigate to it
    final chatScreen = EducationChat(
      role: _role ?? EduRole.student,
      schoolName: _userData?['schoolName'] ?? 'Unknown',
      classId: classIdNotifier.value ?? '',
      userName: _userData?['fullName'] ?? 'User',
    );
    
    // On mobile: push new screen, on tablet/desktop: open in right pane
    if (_getScreenType(context) == ScreenType.mobile) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => chatScreen));
    } else {
      setState(() => _selectedFeature = chatScreen);
    }
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

  Widget _buildWelcomeImage(String assetPath) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.asset(
        assetPath,
        width: 280,
        height: 180,
        fit: BoxFit.cover,
      ),
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
        const SizedBox(width: 12),
        _buildWelcomeImage('assets/lottie/images/online_agri.jpg'),
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
    );
  }


  Widget _buildMainDashboard(String schoolName, String fullName) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(colors: [Color(0xFF43A047), Color(0xFF66BB6A)]),
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
                            _animCtrl
                              ..duration = comp.duration
                              ..repeat();
                          },
                          height: 150,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hello, ${fullName.split(' ').first}!',
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Welcome to Kilimomkononi Education — learn smart farming through interactive tools!',
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
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
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            if (_role == EduRole.headteacher || _role == EduRole.teacher || _role == EduRole.mainadmin)
              Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: _buildApprovalAccessCard(),
              ),

            if (_role == EduRole.teacher) ...[
              Row(
                children: [
                  const Icon(Icons.class_, size: 36, color: Colors.green),
                  const SizedBox(width: 12),
                  Text('Class Selection', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              GradeSelector(
                schoolName: schoolName,
                onGradeSelected: (id) {
                  if (id == null) return;
                  classIdNotifier.value = id;
                  _saveCurrentClassId(id);
                },
                useWhiteText: false,
              ),
              const SizedBox(height: 32),
            ],

            Row(
              children: [
                const Icon(Icons.dashboard_customize, size: 36, color: Colors.green),
                const SizedBox(width: 12),
                Text('Quick Access', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
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
                      Expanded(child: Text('Please select a class to view content.', style: TextStyle(fontWeight: FontWeight.w600))),
                    ],
                  ),
                ),
              ),

            if (classIdNotifier.value != null) ...[
              _buildSummaryCard(
                title: 'Quizzes',
                listNotifier: _quizList,
                onTap: () => _openScreen(
                  QuizHome(
                    classId: classIdNotifier.value!,
                    schoolName: schoolName,
                    onClose: () => setState(() => _selectedFeature = null),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildSummaryCard(
                title: 'Simulations',
                listNotifier: _simList,
                onTap: () => _openScreen(
                  SimulationHome(
                    classId: classIdNotifier.value!,
                    schoolName: schoolName,
                    onClose: () => setState(() => _selectedFeature = null),
                  ),
                ),
              ),
              if (_role == EduRole.teacher) ...[
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
            Row(
              children: [
                const Icon(Icons.rss_feed, size: 36, color: Colors.green),
                const SizedBox(width: 12),
                Text('Recent Activity', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ValueListenableBuilder<List<Map<String, dynamic>>>(
                valueListenable: _feedList,
                builder: (_, feed, _) {
                  if (feed.isEmpty) {
                    return const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No recent activity yet', style: TextStyle(color: Colors.grey))));
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: feed.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final item = feed[i];
                      final isQuiz = item['type'] == 'quiz';
                      final time = (item['createdAt'] as Timestamp?)?.toDate();
                      final ago = time != null ? _formatDate(time) : 'Just now';
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: isQuiz ? Colors.blue.shade50 : Colors.orange.shade50,
                          child: Icon(isQuiz ? Icons.quiz_outlined : Icons.science_outlined, color: isQuiz ? Colors.blue.shade700 : Colors.orange.shade700),
                        ),
                        title: Text(item['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('$ago • ${item['module']}'),
                        trailing: const Icon(Icons.chevron_right),
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

  Widget _buildApprovalAccessCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ApprovalManagementScreen(
                schoolName: _userData!['schoolName'],
                currentUserRole: _role!,
                classId: _role == EduRole.teacher ? classIdNotifier.value : null,
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
                child: Icon(Icons.approval, size: 28, color: Colors.purple.shade700),
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
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(colors: [Color(0xFF43A047), Color(0xFF66BB6A)]),
                ),
                child: Column(
                  children: [
                    Text('Hello, $fullName!', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 12),
                    Text('Your account is being reviewed.', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(statusIcon, size: 80, color: statusColor),
                    const SizedBox(height: 16),
                    Text(statusMessage, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: statusColor)),
                    const SizedBox(height: 12),
                    Text(actionMessage, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
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
    IconData icon;
    Color iconColor;
    Color bgColor;

    if (title == 'Quizzes') {
      icon = Icons.quiz;
      iconColor = Colors.blue.shade700;
      bgColor = Colors.blue.shade50;
    } else if (title == 'Simulations') {
      icon = Icons.science;
      iconColor = Colors.orange.shade700;
      bgColor = Colors.orange.shade50;
    } else {
      icon = Icons.group;
      iconColor = Colors.green.shade700;
      bgColor = Colors.green.shade50;
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  CircleAvatar(radius: 24, backgroundColor: bgColor, child: Icon(icon, size: 28, color: iconColor)),
                  const SizedBox(width: 16),
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                  const Icon(Icons.arrow_forward_ios, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 16),
              if (listNotifier != null)
                ValueListenableBuilder<List<Map<String, dynamic>>>(
                  valueListenable: listNotifier,
                  builder: (_, data, _) {
                    if (data.isEmpty) return const Text('No items yet', style: TextStyle(color: Colors.grey));
                    final grouped = <String, int>{};
                    for (var item in data) {
                      final module = item['module'] ?? 'Unknown';
                      grouped.update(module, (v) => v + 1, ifAbsent: () => 1);
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: grouped.entries.take(3).map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text('• ${e.key}: ${e.value}', style: const TextStyle(fontSize: 14)),
                      )).toList(),
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
                        color: count > 0 ? Colors.green.shade700 : Colors.grey.shade600,
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

  Widget _buildDrawer(String schoolName) {
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
            decoration: const BoxDecoration(color: Color(0xFF003900)),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _editProfile,
                  child: CircleAvatar(
                    radius: 42,
                    backgroundImage: _profileImageBytes != null ? MemoryImage(_profileImageBytes!) : null,
                    child: _profileImageBytes == null
                        ? const Icon(Icons.person, size: 50, color: Colors.white70)
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _userData?['fullName'] ?? 'User',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  '${_capitalize(_role?.name ?? 'User')} • $schoolName',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
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
      _buildDrawerItem(Icons.lightbulb, 'Farming Tips', () => _navigateOrOpen(EducationFarmingTips(role: _role!, schoolName: schoolName, classId: classId))),
      _buildDrawerItem(Icons.cloud, 'Weather Forecast', () => _navigateOrOpen(EducationWeatherForecast(role: _role!, schoolName: schoolName, classId: classId))),
      _buildDrawerItem(Icons.terrain, 'Field Data Input', () => _navigateOrOpen(FieldHome(role: _role!, schoolName: schoolName, classId: classId))),
      _buildDrawerItem(Icons.bug_report, 'Pest & Disease', () => _navigateOrOpen(PestDiseaseHome(role: _role!, schoolName: schoolName, classId: classId))),
      _buildDrawerItem(Icons.account_balance_wallet, 'Farm Management', () => _navigateOrOpen(FarmManagementScreen(role: _role!, classId: classId, schoolName: schoolName))),
      _buildDrawerItem(Icons.price_check, 'Market Tips', () => _navigateOrOpen(EducationMarketPrice(role: _role!, schoolName: schoolName, classId: classId))),
      _buildDrawerItem(Icons.book, 'Manuals', () => _navigateOrOpen(EducationManuals(role: _role!, schoolName: schoolName, classId: classId))),
      // NEW: Resources
    _buildDrawerItem(Icons.folder, 'Resources', () => _navigateOrOpen(EducationResources(
      role: _role ?? EduRole.student,
      schoolName: schoolName,
      classId: classId,
    ))),
    
    // NEW: Chat
    _buildDrawerItem(Icons.chat, 'Chat', () => _navigateOrOpen(EducationChat(
      role: _role ?? EduRole.student,
      schoolName: schoolName,
      classId: classId,
      userName: _userData?['fullName'] ?? 'User',
    ))),
     _buildDrawerItem(Icons.settings, 'Settings', () => _navigateOrOpen(const SettingsScreen(isEducation: true))),
    ];
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(leading: Icon(icon), title: Text(title), onTap: onTap);
  }

  void _navigateOrOpen(Widget page) {
    Navigator.pop(context);
    if (_getScreenType(context) == ScreenType.mobile) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    } else {
      setState(() => _selectedFeature = page);
    }
  }

  Widget _buildLeftRail(String schoolName, String classId, ScreenType type) {
    final width = type == ScreenType.desktop ? 280.0 : 240.0;
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
                    backgroundImage: _profileImageBytes != null ? MemoryImage(_profileImageBytes!) : null,
                    child: _profileImageBytes == null
                        ? const Icon(Icons.person, size: 50, color: Colors.white70)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _userData?['fullName'] ?? 'User',
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    '${_capitalize(_role?.name ?? 'User')} • $schoolName',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const Divider(color: Colors.white24),
          Expanded(
            child: ListView(
              children: [
                _railItem(Icons.lightbulb, 'Farming Tips', 0, () => _openInRightPane(EducationFarmingTips(role: _role!, schoolName: schoolName, classId: classId))),
                _railItem(Icons.cloud, 'Weather Forecast', 1, () => _openInRightPane(EducationWeatherForecast(role: _role!, schoolName: schoolName, classId: classId))),
                _railItem(Icons.terrain, 'Field Data Input', 2, () => _openInRightPane(FieldHome(role: _role!, schoolName: schoolName, classId: classId))),
                _railItem(Icons.bug_report, 'Pest & Disease', 3, () => _openInRightPane(PestDiseaseHome(role: _role!, schoolName: schoolName, classId: classId))),
                _railItem(Icons.account_balance_wallet, 'Farm Management', 4, () => _openInRightPane(FarmManagementScreen(role: _role!, classId: classId, schoolName: schoolName))),
                _railItem(Icons.price_check, 'Market Tips', 5, () => _openInRightPane(EducationMarketPrice(role: _role!, schoolName: schoolName, classId: classId))),
                _railItem(Icons.book, 'Manuals', 6, () => _openInRightPane(EducationManuals(role: _role!, schoolName: schoolName, classId: classId))),
               // NEW: Resources
              _railItem(Icons.folder, 'Resources', 7, () => _openInRightPane(EducationResources(
                role: _role ?? EduRole.student,  // Safe null fallback
                schoolName: schoolName,
                classId: classId,
              ))),
              // NEW: Chat
              _railItem(Icons.chat, 'Chat', 8, () => _openInRightPane(EducationChat(
                role: _role ?? EduRole.student,  // Safe null fallback
                schoolName: schoolName,
                classId: classId,
                userName: _userData?['fullName'] ?? 'User',
              ))),
                _railItem(Icons.settings, 'Settings', 9, () => _openInRightPane(const SettingsScreen(isEducation: true))),
              ],
            ),
          ),
          const Divider(color: Colors.white24),
          _railItem(Icons.logout, 'Logout', 10, _handleLogout),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _railItem(IconData icon, String title, int index, VoidCallback onTap) {
    final selected = _selectedRailIndex == index;
    return ListTile(
      leading: Icon(icon, color: selected ? Colors.yellow : Colors.white70),
      title: Text(title, style: TextStyle(color: selected ? Colors.yellow : Colors.white, fontSize: 15)),
      selected: selected,
      selectedTileColor: Colors.white10,
      onTap: () {
        setState(() => _selectedRailIndex = index);
        onTap();
      },
    );
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