// lib/screens/home.dart
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
import 'package:kilimomkononi/screens/Field%20Data%20Input/weather_station_screen.dart';
import 'package:kilimomkononi/settings/profile_edit_screen.dart';
import 'package:kilimomkononi/settings/widgets/settings_kit.dart';
import 'package:kilimomkononi/authentication/login.dart';
import 'package:kilimomkononi/settings/notifications_screen.dart';
import 'package:kilimomkononi/settings/notifications/notification_providers.dart';
import 'package:kilimomkononi/settings/settings_screen.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:kilimomkononi/services/farm_location_service.dart';
import 'package:kilimomkononi/services/iot_sensor_service.dart';
import 'package:kilimomkononi/widgets/farm_advice_panel.dart';
import 'package:kilimomkononi/services/notification_prefs.dart';
import 'package:kilimomkononi/services/reminder_service.dart';
import 'package:kilimomkononi/services/notification_service.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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

  /// Notifications live behind the app-bar bell (not a tab or menu item).
  void _openNotifications() => _open(const NotificationsScreen());

  /// Asks first (a mis-tap no longer logs you out), stops the listeners so
  /// they don't hit permission errors, then signs out and opens sign-in.
  Future<void> _handleLogout() => confirmAndLogOut(context, beforeSignOut: _cancelSubscriptions);

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
      backgroundColor: _kPage,
      appBar: AppBar(
        title: Text(const ['Kilimo Mkononi', 'Farming manuals', 'Settings'][_selectedIndex],
            style: const TextStyle(fontWeight: FontWeight.w800)),
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0B3D1E), _kGreen])),
        ),
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
          _NotificationBell(onTap: _openNotifications),
          const SizedBox(width: 4),
        ],
      ),
      drawer: _buildDrawer(fullName),
      body: [
        _buildHomeContent(fullName),
        const ManualsScreen(embedded: true),
        const SettingsScreen(isEducation: false, embedded: true),
      ][_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        height: 66,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFD8EFD9),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded, color: _kGreen), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book_rounded, color: _kGreen),
              label: 'Manuals'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded, color: _kGreen),
              label: 'Settings'),
        ],
      ),
    );
  }

  /// Home: greeting, a carousel of the app's sections (each slide opens its
  /// section), farm alerts and the Season Analysis highlight. Content is
  /// centred and capped at 1100 px so nothing stretches on wide screens.
  Widget _buildHomeContent(String fullName) {
    final slides = <_Slide>[
      _Slide('assets/weather_forecast.jpg', 'Weather', 'Forecast for your farm or any place',
          Icons.wb_cloudy_rounded, () => _open(const WeatherScreen())),
      _Slide('assets/field_data_collection.jpg', 'Field Data', 'Record plots, soil tests and crops',
          Icons.edit_note_rounded, () => _open(const FieldDataInputHomePage())),
      _Slide('assets/pest_management.jpg', 'Pests & Diseases', 'Diagnose problems and plan treatment',
          Icons.bug_report_rounded, () => _open(const PestDiseaseHomePage())),
      _Slide('assets/farm_management.jpg', 'Farm Management', 'Tasks, costs, harvests and loans',
          Icons.account_balance_wallet_rounded, () => _open(const FarmManagementScreen())),
      _Slide('assets/soil.png', 'Weather Station', 'Rainfall, soil moisture, temperature & spray windows',
          Icons.sensors_rounded, () => _open(const WeatherStationScreen())),
      _Slide('assets/manuals.jpg', 'Manuals', 'Guides and documents to download',
          Icons.menu_book_rounded, () => _open(const ManualsScreen())),
    ];

    return LayoutBuilder(builder: (context, c) {
      final side = c.maxWidth > 1132 ? (c.maxWidth - 1100) / 2 : 16.0;
      return CustomScrollView(slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(side, 16, side, 0),
          sliver: SliverToBoxAdapter(child: _heroCard(fullName)),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(side, 20, side, 10),
          sliver: SliverToBoxAdapter(
            child: _SectionTitle(
              'Explore',
              Icons.explore_rounded,
              action: TextButton.icon(
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                icon: const Icon(Icons.menu_rounded, size: 18),
                label: const Text('Full menu'),
                style: TextButton.styleFrom(foregroundColor: _kGreen),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: side),
          sliver: SliverToBoxAdapter(child: _SectionCarousel(slides: slides, width: c.maxWidth - 2 * side)),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(side, 22, side, 10),
          sliver: const SliverToBoxAdapter(child: _SectionTitle('Farm advice', Icons.tips_and_updates_rounded)),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: side),
          sliver: SliverToBoxAdapter(
            child: FarmAdvicePanel(
              compact: true,
              onSeeAll: () => _open(const NotificationsScreen(initialTab: NotificationsTab.advice)),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(side, 22, side, 10),
          sliver: const SliverToBoxAdapter(child: _SectionTitle('Market & tips', Icons.storefront_rounded)),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: side),
          sliver: SliverToBoxAdapter(
            child: _TwoUp(children: [
              _ToolCard(
                title: 'Market Prices',
                subtitle: 'Latest crop prices from markets near you',
                icon: Icons.price_check_rounded,
                colors: const [Color(0xFF1F4D44), Color(0xFF2E6A5E), Color(0xFF4E8577)],
                onTap: () => _open(const MarketPriceScreen()),
              ),
              _ToolCard(
                title: 'Farming Tips',
                subtitle: 'Practical guidance for every season',
                icon: Icons.lightbulb_rounded,
                image: 'assets/farming_tips.png',
                colors: const [Color(0xFF1B5E20), Color(0xFF558B2F), Color(0xFF9E9D24)],
                onTap: () => _open(const FarmingTipsWidget()),
              ),
            ]),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(side, 16, side, 32),
          sliver: SliverToBoxAdapter(child: _seasonAnalysisCard()),
        ),
      ]);
    });
  }

  void _open(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  Widget _heroCard(String fullName) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');
    final first = fullName.trim().split(RegExp(r'\s+')).first;
    final county = (_userData?['county'] as String?)?.trim() ?? '';
    final ward = (_userData?['ward'] as String?)?.trim() ?? '';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B3D1E), _kGreen, Color(0xFF00695C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _kGreen.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(DateFormat('EEEE d MMMM').format(DateTime.now()),
                style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
            const SizedBox(height: 4),
            Text('$greeting, $first!',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Here\'s what\'s happening on your farm today.',
                style: TextStyle(color: Colors.white70, fontSize: 13.5)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (county.isNotEmpty)
                _HeroChip(Icons.place_rounded, ward.isEmpty ? county : '$ward, $county'),
              _HeroChip(Icons.bar_chart_rounded, 'Season analysis', onTap: _openSeasonAnalysis),
              if (_isMainAdmin)
                _HeroChip(Icons.admin_panel_settings_rounded, 'Admin panel',
                    onTap: () => _open(const AdminManagementScreen())),
            ]),
          ]),
        ),
        const SizedBox(width: 12),
        InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _openUserProfileFromHome(fullName),
          child: CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white24,
            backgroundImage: _profileImageBytes != null ? MemoryImage(_profileImageBytes!) : null,
            child: _profileImageBytes == null ? const Icon(Icons.person_rounded, size: 32, color: Colors.white) : null,
          ),
        ),
      ]),
    );
  }

  void _openUserProfileFromHome(String fullName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProfileEditScreen(),
      ),
    ).then((_) => _fetchUserData());
  }

  /// Season Analysis highlight (inside the capped content width).
  Widget _seasonAnalysisCard() {
    return Material(
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _openSeasonAnalysis,
        child: Ink(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF3949AB), Color(0xFF00897B)]),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: const Icon(Icons.insights_rounded, size: 28, color: Colors.white),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Season Analysis',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
                SizedBox(height: 3),
                Text('AI insights on your field data, pests, diseases and finances',
                    style: TextStyle(fontSize: 12.5, color: Colors.white70)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: const Text('Open',
                  style: TextStyle(color: Color(0xFF1A237E), fontWeight: FontWeight.w800, fontSize: 12.5)),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Drawer ────────────────────────────────────────────────────────────
  Widget _buildDrawer(String fullName) {
    final email = '${_userData?['email'] ?? ''}';
    final county = '${_userData?['county'] ?? ''}';
    final ward = '${_userData?['ward'] ?? ''}';
    final place = [ward, county].where((p) => p.isNotEmpty).join(', ');
    return Drawer(
      backgroundColor: Colors.white,
      width: 304,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(24))),
      child: Column(children: [
        // Header: who is signed in; tap to edit the profile.
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openUserProfile(fullName),
            child: Ink(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0B3D1E), _kGreen, Color(0xFF2E7D32)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(topRight: Radius.circular(24)),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 10, 18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white24,
                        backgroundImage: _profileImageBytes != null ? MemoryImage(_profileImageBytes!) : null,
                        child: _profileImageBytes == null
                            ? const Icon(Icons.person_rounded, size: 32, color: Colors.white)
                            : null,
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Close menu',
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Text(fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    if (email.isNotEmpty)
                      Text(email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                    const SizedBox(height: 10),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      if (place.isNotEmpty) _HeroChip(Icons.place_rounded, place),
                      const _HeroChip(Icons.edit_rounded, 'Edit profile'),
                    ]),
                  ]),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(10, 8, 10, 12), children: [
            const _DrawerLabel('Farm', Color(0xFF2E7D32)),
            _DrawerItem(Icons.home_rounded, 'Home',
                color: const Color(0xFF2E7D32), selected: _selectedIndex == 0, onTap: () => _goTab(0)),
            _DrawerItem(Icons.wb_cloudy_rounded, 'Weather forecast',
                color: const Color(0xFF1E88E5), onTap: () => _navigateTo(const WeatherScreen())),
            _DrawerItem(Icons.edit_note_rounded, 'Field data input',
                color: const Color(0xFF00897B),
                subtitle: 'Plots, crops & weather station',
                onTap: () => _navigateTo(const FieldDataInputHomePage())),
            _DrawerItem(Icons.bug_report_rounded, 'Pests & diseases',
                color: const Color(0xFFE53935), onTap: () => _navigateTo(const PestDiseaseHomePage())),
            _DrawerItem(Icons.account_balance_wallet_rounded, 'Farm management',
                color: const Color(0xFF8E24AA),
                subtitle: 'Costs, harvests & loans',
                onTap: () => _navigateTo(const FarmManagementScreen())),
            const _DrawerLabel('Insights & learning', Color(0xFF3949AB)),
            _DrawerItem(Icons.insights_rounded, 'Season analysis',
                color: const Color(0xFF3949AB),
                onTap: () => _navigateTo(FarmerPlotAnalysisScreen(
                      plotId: 'All',
                      cycleName: 'Season ${DateTime.now().year}',
                    ))),
            _DrawerItem(Icons.menu_book_rounded, 'Manuals',
                color: const Color(0xFF6D4C41), selected: _selectedIndex == 1, onTap: () => _goTab(1)),
            const _DrawerLabel('Account', Color(0xFF546E7A)),
            _DrawerItem(Icons.settings_rounded, 'Settings',
                color: const Color(0xFF546E7A), selected: _selectedIndex == 2, onTap: () => _goTab(2)),
            if (_isMainAdmin)
              _DrawerItem(Icons.admin_panel_settings_rounded, 'Admin panel',
                  color: const Color(0xFFF4511E), onTap: () => _navigateTo(const AdminManagementScreen())),
          ]),
        ),
        const Divider(height: 1),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            child: Column(children: [
              _DrawerItem(Icons.logout_rounded, 'Log out',
                  color: const Color(0xFFB3261E), danger: true, onTap: _handleLogout),
              const Padding(
                padding: EdgeInsets.only(top: 2, bottom: 4),
                child: Text('Kilimo Mkononi v$kAppVersion', style: TextStyle(color: Colors.black45, fontSize: 11.5)),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  /// Close the drawer and show a bottom-nav tab (Home / Manuals / Settings).
  void _goTab(int index) {
    Navigator.pop(context);
    setState(() => _selectedIndex = index);
  }

  /// Opens a page from the menu. Coming back lands on Home with the menu
  /// open again (not on whichever tab was showing behind the menu).
  Future<void> _navigateTo(Widget page) async {
    Navigator.pop(context);
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (!mounted) return;
    setState(() => _selectedIndex = 0);
    _scaffoldKey.currentState?.openDrawer();
  }

  void _openUserProfile(String fullName) {
    Navigator.pop(context); // close the drawer first
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProfileEditScreen(),
      ),
    ).then((_) {
      // In case the realtime listener hasn't caught up yet, refresh
      // immediately when they come back from editing.
      _fetchUserData();
    });
  }
}

const _kGreen = Color(0xFF1B5E20);
const _kPage = Color(0xFFF4F6F3);

class _Slide {
  final String image;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const _Slide(this.image, this.title, this.subtitle, this.icon, this.onTap);
}

/// Auto-playing carousel of the app's sections; each slide opens its
/// section. Dots show the position; arrows on wide screens.
class _SectionCarousel extends StatefulWidget {
  final List<_Slide> slides;
  final double width;
  const _SectionCarousel({required this.slides, required this.width});

  @override
  State<_SectionCarousel> createState() => _SectionCarouselState();
}

class _SectionCarouselState extends State<_SectionCarousel> {
  final _controller = CarouselSliderController();
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    final wide = w >= 700;
    final height = wide ? 280.0 : (w < 380 ? 180.0 : 200.0);
    return Column(children: [
      Stack(alignment: Alignment.center, children: [
        CarouselSlider(
          carouselController: _controller,
          options: CarouselOptions(
            height: height,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 5),
            enlargeCenterPage: true,
            enlargeFactor: 0.18,
            viewportFraction: wide ? 0.62 : 0.9,
            onPageChanged: (i, _) => setState(() => _index = i),
          ),
          items: [for (final s in widget.slides) _SlideCard(s)],
        ),
        if (wide) ...[
          Positioned(left: 4, child: _ArrowButton(Icons.chevron_left_rounded, _controller.previousPage)),
          Positioned(right: 4, child: _ArrowButton(Icons.chevron_right_rounded, _controller.nextPage)),
        ],
      ]),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < widget.slides.length; i++)
          GestureDetector(
            onTap: () => _controller.animateToPage(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _index ? 20 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: i == _index ? _kGreen : const Color(0xFFC8D6CA),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
      ]),
    ]);
  }
}

class _SlideCard extends StatelessWidget {
  final _Slide s;
  const _SlideCard(this.s);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          elevation: 3,
          shadowColor: Colors.black26,
          child: InkWell(
            onTap: s.onTap,
            child: Stack(fit: StackFit.expand, children: [
              Image.asset(s.image, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: _kGreen)),
              // Legibility gradient.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0x33000000), Color(0xCC000000)],
                    stops: [0.35, 0.6, 1],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                    child: Icon(s.icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(s.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                      Text(s.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('Open', style: TextStyle(color: _kGreen, fontWeight: FontWeight.w800, fontSize: 12.5)),
                      Icon(Icons.chevron_right_rounded, color: _kGreen, size: 16),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      );
}

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final Future<void> Function({Duration duration, Curve curve}) go;
  const _ArrowButton(this.icon, this.go);

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 3,
        child: IconButton(
          icon: Icon(icon, color: _kGreen),
          onPressed: () => go(duration: const Duration(milliseconds: 350), curve: Curves.easeOut),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? action;
  const _SectionTitle(this.title, this.icon, {this.action});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 20, color: _kGreen),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1B2A1B))),
        ),
        ?action,
      ]);
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _HeroChip(this.icon, this.label, {this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 14, color: Colors.white),
              const SizedBox(width: 5),
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ),
      );
}

/// Two cards side by side on wider screens, stacked on narrow phones.
class _TwoUp extends StatelessWidget {
  final List<Widget> children;
  const _TwoUp({required this.children});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) => c.maxWidth < 360
            ? Column(children: [
                for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 12), children[i]],
              ])
            : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: children[i]),
                ],
              ]),
      );
}

class _ToolCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final String? image;
  final VoidCallback onTap;
  const _ToolCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.onTap,
    this.image,
  });

  @override
  Widget build(BuildContext context) {
    final ts = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.4);
    return SizedBox(
      height: 132 * ts,
      child: Material(
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        shadowColor: Colors.black26,
        child: InkWell(
          onTap: onTap,
          child: Stack(fit: StackFit.expand, children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
            ),
            if (image != null)
              Opacity(
                opacity: 0.22,
                child: Image.asset(image!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox()),
              ),
            // Soft decorative circle.
            Positioned(
              right: -24,
              top: -24,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.10), shape: BoxShape.circle),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const Spacer(),
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.3)),
              ]),
            ),
            const Positioned(
              right: 12,
              bottom: 12,
              child: Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
            ),
          ]),
        ),
      ),
    );
  }
}

/// App-bar bell with the number of unread notifications.
class _NotificationBell extends ConsumerWidget {
  final VoidCallback onTap;
  const _NotificationBell({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);
    return IconButton(
      tooltip: unread == 0 ? 'Notifications' : 'Notifications ($unread unread)',
      onPressed: onTap,
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 99 ? '99+' : '$unread'),
        backgroundColor: const Color(0xFFEF6C00),
        child: const Icon(Icons.notifications_rounded),
      ),
    );
  }
}

class _DrawerLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _DrawerLabel(this.text, this.color);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 6),
        child: Row(children: [
          Container(width: 4, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(text.toUpperCase(),
              style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.9)),
        ]),
      );
}

/// Menu row: coloured icon tile, rounded highlight for the current page,
/// optional subtitle; red for Log out.
class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String? subtitle;
  final bool selected;
  final bool danger;
  final VoidCallback onTap;
  const _DrawerItem(this.icon, this.label,
      {required this.onTap, required this.color, this.subtitle, this.selected = false, this.danger = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: selected ? color : color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: selected ? Colors.white : color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label,
                      style: TextStyle(
                          color: danger || selected ? color : const Color(0xFF1F2937),
                          fontSize: 14.5,
                          fontWeight: selected || danger ? FontWeight.w800 : FontWeight.w600)),
                  if (subtitle != null)
                    Text(subtitle!, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11.5)),
                ]),
              ),
              if (selected) Icon(Icons.chevron_right_rounded, color: color),
            ]),
          ),
        ),
      ),
    );
  }
}
