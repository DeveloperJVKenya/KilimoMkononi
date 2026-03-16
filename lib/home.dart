// lib/screens/home.dart
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:kilimomkononi/models/user_model.dart';
import 'package:kilimomkononi/screens/Field%20Data%20Input/field_data_input_home_page.dart';
import 'package:kilimomkononi/screens/admin/admin_management_screen.dart';
import 'package:kilimomkononi/screens/farm_management_screen.dart';
import 'package:kilimomkononi/screens/farming_tips_widget.dart';
import 'package:kilimomkononi/screens/market_price_screen.dart';
import 'package:kilimomkononi/screens/manuals_screen.dart';
import 'package:kilimomkononi/screens/pests_diseases_home.dart';
import 'package:kilimomkononi/screens/weather_screen.dart';
import 'package:kilimomkononi/authentication/login.dart';
import 'package:kilimomkononi/settings/notifications_settings_screen.dart';
import 'package:kilimomkononi/settings/settings_screen.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
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

  // Use GlobalKey to control the Scaffold (fixes Scaffold.of() error)
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
        }
        return;
      }

      final appUser = AppUser.fromFirestore(userSnapshot, null);

      if (appUser.isDisabled == true) {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Your account has been disabled by admin.')),
          );
        }
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
      }
    } catch (e) {
      logger.e('Error fetching user data: $e');
    }
  }

  void _listenToUserAndAdminStatus() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance.collection('Users').doc(user.uid).snapshots().listen((snapshot) {
      if (!snapshot.exists || !mounted) return;
      final appUser = AppUser.fromFirestore(snapshot, null);
      if (appUser.isDisabled == true) {
        FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account disabled by admin.')),
          );
        }
      } else {
        if (mounted) setState(() => _userData = appUser.toMap());
      }
    });

    FirebaseFirestore.instance.collection('Admins').doc(user.uid).snapshots().listen((snapshot) {
      if (mounted) setState(() => _isMainAdmin = snapshot.exists);
    });
  }

  void _listenToAuthState() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null && mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    });
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  Future<void> _handleLogout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userData == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final fullName = _userData!['fullName'] ?? 'Farmer';

    return Scaffold(
      key: _scaffoldKey, // This is the fix!
      appBar: AppBar(
        title: const Text('Kilimo Mkononi'),
        backgroundColor: const Color.fromARGB(255, 3, 39, 4),
        foregroundColor: Colors.white,
        actions: [
          if (_isMainAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              tooltip: 'Admin Panel',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminManagementScreen())),
            ),
        ],
      ),
      drawer: _buildDrawer(fullName),
      body: [
        _buildHomeContent(fullName),
        const SettingsScreen(isEducation: false), 
        const NotificationsSettingsScreen(),
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
          // Greeting
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
                Text('Welcome back to Kilimo Mkononi', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
              ],
            ),
          ),

          // Carousel
          CarouselSlider(
            options: CarouselOptions(
            height: _getResponsiveValue(mobile: 200, tablet: 300, desktop: 400),
            autoPlay: true,
            enlargeCenterPage: true,
            viewportFraction: _getResponsiveValue(mobile: 0.85, tablet: 0.6, desktop: 0.5),
          ),
          items: _carouselImages.map((path) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(path, fit: BoxFit.cover, width: double.infinity),
            ),
          )).toList(),
        ),

          const SizedBox(height: 30),

          // Quick Access Title
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Quick Access', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),

          // Only TWO cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _card(Icons.lightbulb, 'Farming Tips', () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const FarmingTipsWidget()));
                })),
                const SizedBox(width: 16),
                Expanded(child: _card(Icons.price_check, 'Market Price', () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MarketPriceScreen()));
                })),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // "More Features" Button – Opens Drawer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer(); // Now works!
                },
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
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  // Full-featured drawer
  Widget _buildDrawer(String fullName) {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Color.fromARGB(255, 3, 39, 4)),
              accountName: Text(fullName, style: const TextStyle(fontSize: 18)),
              currentAccountPicture: CircleAvatar(
                radius: 40,
                backgroundImage: _profileImageBytes != null ? MemoryImage(_profileImageBytes!) : null,
                child: _profileImageBytes == null ? const Icon(Icons.person, size: 40, color: Colors.white70) : null,
              ),
              accountEmail: null,
            ),
            _drawerItem(Icons.home, 'Home', () => Navigator.pop(context)),
            _drawerItem(Icons.cloud, 'Weather Forecast', () => _navigateTo(const WeatherScreen())),
            _drawerItem(Icons.input, 'Field Data Input', () => _navigateTo(const FieldDataInputHomePage())),
            _drawerItem(Icons.bug_report, 'Pests & Diseases', () => _navigateTo(const PestDiseaseHomePage())),
            _drawerItem(Icons.account_balance_wallet, 'Farm Management', () => _navigateTo(const FarmManagementScreen())),
            _drawerItem(Icons.book, 'Manuals', () => _navigateTo(const ManualsScreen())),
            _drawerItem(Icons.settings, 'Settings', () => _navigateTo(const SettingsScreen(isEducation: false))),
            const Divider(),
            _drawerItem(Icons.logout, 'Logout', _handleLogout),
          ],
        ),
      ),
    );
  }

  void _navigateTo(Widget page) {
    Navigator.pop(context); // Close drawer first
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  ListTile _drawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: const Color.fromARGB(255, 3, 39, 4)),
      title: Text(title),
      onTap: onTap,
    );
  }
}