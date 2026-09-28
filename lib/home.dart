// lib/screens/home.dart
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:kilimomkononi/models/user_model.dart';
import 'package:kilimomkononi/screens/Field%20Data%20Input/field_data_input_home_page.dart';
import 'package:kilimomkononi/screens/admin/admin_management_screen.dart';
import 'package:kilimomkononi/screens/analysis/farmer_plot_analysis_screen.dart';
import 'package:kilimomkononi/screens/farm_management_screen.dart';
import 'package:kilimomkononi/screens/farming_tips_widget.dart';
import 'package:kilimomkononi/screens/market_price_screen.dart';
import 'package:kilimomkononi/screens/manuals_screen.dart';
import 'package:kilimomkononi/screens/pests_diseases_home.dart';
import 'package:kilimomkononi/screens/weather_screen.dart';
import 'package:kilimomkononi/screens/user_profile.dart';
import 'package:kilimomkononi/authentication/login.dart';
import 'package:kilimomkononi/settings/notifications_screen.dart';
import 'package:kilimomkononi/settings/settings_screen.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:kilimomkononi/services/farm_location_service.dart';
import 'package:kilimomkononi/services/iot_sensor_service.dart';
import 'package:kilimomkononi/widgets/farm_alerts_home_widget.dart';
import 'package:kilimomkononi/services/notification_prefs.dart';
import 'package:kilimomkononi/services/reminder_service.dart';
import 'package:kilimomkononi/services/session_service.dart';
import 'package:kilimomkononi/services/notification_service.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

enum ScreenType { mobile, tablet, desktop }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  Map<String, dynamic>? _userData;
  Uint8List? _profileImageBytes;
  bool _isMainAdmin = false;
  final logger = Logger(printer: PrettyPrinter());

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Live listeners — cancelled in dispose() and before sign-out so they don't
  // outlive the page (leaked Firestore listeners + permission errors after
  // sign-out) or trigger a second navigation to LoginScreen.
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _navigatedToLogin = false;

  final List<String> _carouselImages = [
    'assets/weather_forecast.jpg',
    'assets/field_data_collection.jpg',
    'assets/pest_management.jpg',
    'assets/farm_management.jpg',
    'assets/manuals.jpg',
    'assets/farming_tips.png',
    'assets/soil.png',
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _listenToUserAndAdminStatus();
    _listenToAuthState();
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }

  void _cancelSubscriptions() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }

  /// Single exit point to the login screen. Several paths (logout button,
  /// auth-state listener, disabled-account checks) can fire for the same
  /// sign-out; without the guard each one pushed its own LoginScreen.
  void _goToLogin({String? message}) {
    if (!mounted || _navigatedToLogin) return;
    _navigatedToLogin = true;
    _cancelSubscriptions();
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    if (message != null) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  ScreenType _getScreenType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return ScreenType.mobile;
    if (width < 1200) return ScreenType.tablet;
    return ScreenType.desktop;
  }

  double _getResponsiveValue({
    required double mobile,
    required double tablet,
    required double desktop,
  }) {
    switch (_getScreenType(context)) {
      case ScreenType.mobile:
        return mobile;
      case ScreenType.tablet:
        return tablet;
      case ScreenType.desktop:
        return desktop;
    }
  }

  // ────────────────────────────── USER DATA ──────────────────────────────
  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userSnapshot = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .get();

      if (!userSnapshot.exists) {
        _cancelSubscriptions();
        await FarmLocationService.clear();
        IotSensorService.clearCache();
        await FirebaseAuth.instance.signOut();
        _goToLogin();
        return;
      }

      final appUser = AppUser.fromFirestore(userSnapshot, null);

      if (appUser.isDisabled == true) {
        _cancelSubscriptions();
        await FarmLocationService.clear();
        IotSensorService.clearCache();
        await FirebaseAuth.instance.signOut();
        _goToLogin(message: 'Your account has been disabled by admin.');
        return;
      }

      final adminSnapshot = await FirebaseFirestore.instance
          .collection('Admins')
          .doc(user.uid)
          .get();

      Uint8List? decodedImage;
      if (appUser.profileImage != null && appUser.profileImage!.isNotEmpty) {
        try {
          decodedImage = base64Decode(appUser.profileImage!);
        } catch (e) {
          logger.e('Failed to decode profile image: $e');
        }
      }

      if (mounted) {
        setState(() {
          _userData = appUser.toMap();
          _profileImageBytes = decodedImage;
          _isMainAdmin = adminSnapshot.exists;
        });
        // Verified-advice pushes go to crop topics; then open whatever
        // notification launched the app, now that the user is signed in.
        // Notification Settings may have changed on another device: load
        // them, then apply to scheduled reminders and advice topics.
        NotificationPrefsRepository.load(user.uid).then((p) {
          ReminderService.applyPrefs(user.uid, p);
          NotificationService.syncFarmerTopics(user.uid);
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationService.consumePendingRoute();
          if (mounted) NotificationService.maybeShowBackgroundTip(context);
        });
      }
    } catch (e) {
      logger.e('Error fetching user data: $e');
    }
  }

  void _listenToUserAndAdminStatus() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _subscriptions.add(FirebaseFirestore.instance.collection('Users').doc(user.uid).snapshots().listen((snapshot) {
      if (!snapshot.exists || !mounted) return;
      final appUser = AppUser.fromFirestore(snapshot, null);
      if (appUser.isDisabled == true) {
        _goToLogin(message: 'Account disabled by admin.');
        FirebaseAuth.instance.signOut();
      } else {
        // Also refresh the profile photo — previously only the name/data
        // map was updated here, so a new photo saved in UserProfileScreen
        // wouldn't show up in the drawer avatar until the next cold start.
        Uint8List? decodedImage = _profileImageBytes;
        if (appUser.profileImage != null && appUser.profileImage!.isNotEmpty) {
          try {
            decodedImage = base64Decode(appUser.profileImage!);
          } catch (e) {
            logger.e('Failed to decode profile image: $e');
          }
        } else {
          decodedImage = null;
        }
        if (mounted) {
          setState(() {
            _userData = appUser.toMap();
            _profileImageBytes = decodedImage;
          });
        }
      }
    }, onError: (Object e) => logger.e('User doc listener error: $e')));

    _subscriptions.add(FirebaseFirestore.instance.collection('Admins').doc(user.uid).snapshots().listen((snapshot) {
      if (mounted) setState(() => _isMainAdmin = snapshot.exists);
    }, onError: (Object e) => logger.e('Admin doc listener error: $e')));
  }

  void _listenToAuthState() {
    _subscriptions.add(FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) _goToLogin();
    }));
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  Future<void> _handleLogout() async {
    // Stop listeners first so they don't hit permission errors after sign-out
    _cancelSubscriptions();
    // Clears per-user caches, then signs out of Firebase and Google.
    await SessionService.signOut();
    _goToLogin();
  }

  // ── Navigate to Season Analysis with top-level defaults ──────────────
  void _openSeasonAnalysis() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FarmerPlotAnalysisScreen(
          plotId: 'All',
          cycleName: 'Season ${DateTime.now().year}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_userData == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final fullName = _userData!['fullName'] ?? 'Farmer';

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Kilimo Mkononi'),
        backgroundColor: const Color.fromARGB(255, 3, 39, 4),
        foregroundColor: Colors.white,
        actions: [
          if (_isMainAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              tooltip: 'Admin Panel',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminManagementScreen()),
              ),
            ),
        ],
      ),
      drawer: _buildDrawer(fullName),
      body: [
        _buildHomeContent(fullName),
        const SettingsScreen(isEducation: false),
        const NotificationsScreen(),
      ][_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Notifications'),
        ],
      ),
    );
  }

  Widget _buildHomeContent(String fullName) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Greeting ────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.all(_getResponsiveValue(mobile: 16, tablet: 24, desktop: 32)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, $fullName!',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Welcome back to Kilimo Mkononi',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          ),

          // ── Carousel ─────────────────────────────────────────────
          CarouselSlider(
            options: CarouselOptions(
              height: _getResponsiveValue(mobile: 200, tablet: 300, desktop: 400),
              autoPlay: true,
              enlargeCenterPage: true,
              viewportFraction: _getResponsiveValue(mobile: 0.85, tablet: 0.6, desktop: 0.5),
            ),
            items: _carouselImages
                .map((path) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(path, fit: BoxFit.cover, width: double.infinity),
                      ),
                    ))
                .toList(),
          ),

          const SizedBox(height: 30),

          // ── Farm Alerts (IoT + Satellite) ────────────────────────
          // Auto-loads conditions for the farmer's registered county.
          // Shows flood, drought, fungal, spray-window alerts.
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Farm Alerts',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: FarmAlertsHomeWidget(),
          ),

          const SizedBox(height: 24),

          // ── Quick Access ─────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Quick Access',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),

          // Row 1: Farming Tips + Market Price
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _card(Icons.lightbulb, 'Farming Tips', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FarmingTipsWidget()),
                    );
                  }),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _card(Icons.price_check, 'Market Price', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MarketPriceScreen()),
                    );
                  }),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Row 2: Season Analysis (full-width highlight card)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _seasonAnalysisCard(),
          ),

          const SizedBox(height: 30),

          // ── More Features Button ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                icon: const Icon(Icons.menu, size: 28),
                label: const Text('More Features', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 6,
                ),
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── Standard quick-access card ────────────────────────────────────────
  Widget _card(IconData icon, String title, VoidCallback onTap) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 50, color: const Color.fromARGB(255, 3, 39, 4)),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Season Analysis highlighted card (full-width) ─────────────────────
  Widget _seasonAnalysisCard() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _openSeasonAnalysis,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                const Color.fromARGB(255, 3, 39, 4),
                Colors.green[700]!,
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            children: [
              const Icon(Icons.bar_chart_rounded, size: 48, color: Colors.white),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Season Analysis',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'AI insights on your field data, pests, diseases & finances',
                      style: TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  // ── Drawer ────────────────────────────────────────────────────────────
  Widget _buildDrawer(String fullName) {
    // White comes from the Drawer's own Material. A coloured Container here
    // hid the menu items' tap ripples (and raised a ListTile assertion).
    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
          padding: EdgeInsets.zero,
          children: [
            GestureDetector(
              onTap: () => _openUserProfile(fullName),
              child: UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: Color.fromARGB(255, 3, 39, 4)),
                accountName: Text(fullName, style: const TextStyle(fontSize: 18)),
                currentAccountPicture: CircleAvatar(
                  radius: 40,
                  backgroundImage:
                      _profileImageBytes != null ? MemoryImage(_profileImageBytes!) : null,
                  child: _profileImageBytes == null
                      ? const Icon(Icons.person, size: 40, color: Colors.white70)
                      : null,
                ),
                accountEmail: const Text('Tap to edit your profile',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ),
            ),
            _drawerItem(Icons.home, 'Home', () => Navigator.pop(context)),
            _drawerItem(Icons.cloud, 'Weather Forecast',
                () => _navigateTo(const WeatherScreen())),
            _drawerItem(Icons.input, 'Field Data Input',
                () => _navigateTo(const FieldDataInputHomePage())),
            _drawerItem(Icons.bug_report, 'Pests & Diseases',
                () => _navigateTo(const PestDiseaseHomePage())),
            _drawerItem(Icons.account_balance_wallet, 'Farm Management',
                () => _navigateTo(const FarmManagementScreen())),
            _drawerItem(Icons.book, 'Manuals',
                () => _navigateTo(const ManualsScreen())),
            // ── Season Analysis drawer entry ──────────────────────
            _drawerItem(
              Icons.bar_chart_rounded,
              'Season Analysis',
              () {
                Navigator.pop(context);
                _openSeasonAnalysis();
              },
            ),
            _drawerItem(Icons.settings, 'Settings',
                () => _navigateTo(const SettingsScreen(isEducation: false))),
            const Divider(),
            _drawerItem(Icons.logout, 'Logout', _handleLogout),
          ],
      ),
    );
  }

  void _navigateTo(Widget page) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  void _openUserProfile(String fullName) {
    Navigator.pop(context); // close the drawer first
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          profileImageBytes: _profileImageBytes,
          fullName: fullName,
          role: null, // farmer flow — UserProfileScreen loads the rest from Firestore
        ),
      ),
    ).then((_) {
      // In case the realtime listener hasn't caught up yet, refresh
      // immediately when they come back from editing.
      _fetchUserData();
    });
  }

  ListTile _drawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: const Color.fromARGB(255, 3, 39, 4)),
      title: Text(title),
      onTap: onTap,
    );
  }
}