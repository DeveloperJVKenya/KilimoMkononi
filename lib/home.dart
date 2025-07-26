import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:kilimomkononi/models/user_model.dart';
//import 'package:kilimomkononi/screens/Alma%20Dairy/alma_dairy_home.dart';
import 'package:kilimomkononi/screens/Field%20Data%20Input/field_data_input_home_page.dart';
import 'package:kilimomkononi/screens/admin/admin_management_screen.dart';
import 'package:kilimomkononi/screens/farm_management_screen.dart';
import 'package:kilimomkononi/screens/farming_tips_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kilimomkononi/screens/manuals_screen.dart';
import 'package:kilimomkononi/screens/pests_diseases_home.dart';
import 'package:kilimomkononi/screens/user_profile.dart';
import 'package:kilimomkononi/screens/weather_screen.dart';
import 'package:kilimomkononi/screens/market_price_prediction_widget.dart';
import 'package:kilimomkononi/authentication/login.dart';
import 'package:kilimomkononi/settings/notifications_settings_screen.dart';
import 'package:kilimomkononi/settings/settings_screen.dart';
import 'package:logger/logger.dart';
import 'dart:convert';
import 'dart:typed_data';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // int _selectedIndex = 0;
  Map<String, dynamic>? _userData;
  Uint8List? _profileImageBytes;
  bool _isMainAdmin = false;
  final logger = Logger(printer: PrettyPrinter());
  String? _userId;

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
    logger.i('HomePage initState called');
    _fetchUserData();
    _listenToUserAndAdminStatus();
    _listenToAuthState();
  }

  // Helper method to determine screen type
  ScreenType _getScreenType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) {
      return ScreenType.mobile;
    } else if (width < 1200) {
      return ScreenType.tablet;
    } else {
      return ScreenType.desktop;
    }
  }

  // Helper method to get responsive values
  double _getResponsiveValue(BuildContext context, {
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

  int _getCrossAxisCount(BuildContext context) {
    switch (_getScreenType(context)) {
      case ScreenType.mobile:
        return 2;
      case ScreenType.tablet:
        return 3;
      case ScreenType.desktop:
        return 4;
    }
  }

  Future<void> _fetchUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      logger.i('Fetching data for user: ${user.email}, UID: ${user.uid}');
      _userId = user.uid;
      DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .get();

      if (userSnapshot.exists) {
        AppUser appUser = AppUser.fromFirestore(userSnapshot as DocumentSnapshot<Map<String, dynamic>>, null);
        if (appUser.isDisabled) {
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Your account is disabled. Contact an admin.')),
            );
          }
          return;
        }

        DocumentSnapshot adminSnapshot = await FirebaseFirestore.instance
            .collection('Admins')
            .doc(user.uid)
            .get();
        bool isAdmin = adminSnapshot.exists;

        String? profileImageBase64 = appUser.profileImage;
        Uint8List? decodedImage;
        if (profileImageBase64 != null) {
          try {
            decodedImage = base64Decode(profileImageBase64);
          } catch (e) {
            logger.e('Error decoding profile image: $e');
          }
        }

        setState(() {
          _userData = appUser.toMap();
          _profileImageBytes = decodedImage;
          _isMainAdmin = isAdmin;
          logger.i('Initial fetch - UserId: $_userId, UserData: $_userData, IsAdmin: $_isMainAdmin');
        });
      } else {
        logger.w('No user data found in Firestore for UID: ${user.uid}');
        setState(() {
          _userId = user.uid;
        });
      }
    } else {
      logger.w('No user logged in');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  void _listenToAuthState() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        logger.i('Auth state changed - User logged in: ${user.uid}');
        setState(() {
          _userId = user.uid;
        });
        _fetchUserData();
      } else {
        logger.w('Auth state changed - No user logged in');
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      }
    });
  }

  void _listenToUserAndAdminStatus() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .snapshots()
          .listen((userSnapshot) {
        if (userSnapshot.exists) {
          AppUser appUser = AppUser.fromFirestore(userSnapshot, null);
          if (appUser.isDisabled && mounted) {
            FirebaseAuth.instance.signOut();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Your account has been disabled. Contact an admin.')),
            );
          } else if (mounted) {
            setState(() {
              _userData = appUser.toMap();
              logger.i('User data updated: $_userData');
            });
          }
        }
      });

      FirebaseFirestore.instance
          .collection('Admins')
          .doc(user.uid)
          .snapshots()
          .listen((adminSnapshot) {
        if (mounted) {
          setState(() {
            _isMainAdmin = adminSnapshot.exists;
            logger.i('Admin status updated: $_isMainAdmin');
          });
        }
      });
    }
  }

  Future<void> _handleLogout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging out: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenType = _getScreenType(context);
    final isDesktop = screenType == ScreenType.desktop;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(_getResponsiveValue(
          context,
          mobile: MediaQuery.of(context).size.height * 0.08,
          tablet: MediaQuery.of(context).size.height * 0.07,
          desktop: MediaQuery.of(context).size.height * 0.06,
        )),
        child: AppBar(
          title: Text(
            'KilimoMkononi',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: _getResponsiveValue(
                context,
                mobile: 18,
                tablet: 20,
                desktop: 22,
              ),
            ),
          ),
          backgroundColor: const Color.fromARGB(255, 3, 39, 4),
          leading: isDesktop ? null : Builder(
            builder: (context) => IconButton(
              icon: Icon(
                Icons.menu,
                color: Colors.white,
                size: _getResponsiveValue(
                  context,
                  mobile: 40,
                  tablet: 35,
                  desktop: 30,
                ),
              ),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                Icons.notifications,
                color: Colors.white,
                size: _getResponsiveValue(
                  context,
                  mobile: 40,
                  tablet: 35,
                  desktop: 30,
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NotificationsSettingsScreen()),
                );
              },
            ),
            IconButton(
              icon: Icon(
                Icons.search,
                color: Colors.white,
                size: _getResponsiveValue(
                  context,
                  mobile: 40,
                  tablet: 35,
                  desktop: 30,
                ),
              ),
              onPressed: () {},
            ),
          ],
        ),
      ),
      drawer: isDesktop ? null : _buildDrawer(),
      body: Row(
        children: [
          // Desktop sidebar
          if (isDesktop) _buildDesktopSidebar(),
          // Main content
          Expanded(
            child: Container(
              color: Colors.grey[200],
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildCarousel(),
                    _buildClickableSections(),
                    if (_isMainAdmin)
                      _buildAdminButton()
                    else if (!isDesktop)
                      Builder(
                        builder: (context) => _buildMenuButton(context),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      //bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildDesktopSidebar() {
    return Container(
      width: 280,
      color: const Color.fromARGB(255, 3, 39, 4),
      child: Column(
        children: [
          // Profile section
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  child: _profileImageBytes != null
                      ? ClipOval(
                          child: Image.memory(
                            _profileImageBytes!,
                            fit: BoxFit.cover,
                            width: 80,
                            height: 80,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.person, size: 40, color: Color.fromARGB(255, 3, 39, 4)),
                          ),
                        )
                      : const Icon(Icons.person, size: 40, color: Color.fromARGB(255, 3, 39, 4)),
                ),
                const SizedBox(height: 10),
                Text(
                  _userData?['fullName'] ?? 'Loading...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white24),
          // Navigation items
          Expanded(
            child: ListView(
              children: [
                _buildDesktopDrawerItem(Icons.home, 'Home', () {}),
                _buildDesktopDrawerItem(Icons.cloud, 'Weather Forecast', () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const WeatherScreen()));
                }),
                _buildDesktopDrawerItem(Icons.input, 'Field Data Input', () {
                  logger.i('Navigating to FieldDataInputPage, userId: $_userId');
                  if (_userId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const FieldDataInputHomePage()),
                    );
                  } else {
                    logger.w('User ID is null, attempting refresh');
                    _fetchUserData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('User ID not available. Retrying...')),
                    );
                  }
                }),
                _buildDesktopDrawerItem(Icons.pest_control, 'Manage Pests & Diseases', () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const PestDiseaseHomePage()));
                }),
                _buildDesktopDrawerItem(Icons.supervisor_account, 'Farm Management', () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const FarmManagementScreen()));
                }),
                /*_buildDesktopDrawerItem(Icons.local_drink, 'Alma Dairy', () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AlmaDairyHome()));
                }),*/
                _buildDesktopDrawerItem(Icons.book, 'Manuals', () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ManualsScreen()));
                }),
                _buildDesktopDrawerItem(Icons.settings, 'Settings', () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
                }),
                if (_isMainAdmin)
                  _buildDesktopDrawerItem(Icons.admin_panel_settings, 'Admin Management', () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminManagementScreen()));
                  }),
                _buildDesktopDrawerItem(Icons.logout, 'Logout', _handleLogout),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: onTap,
      hoverColor: Colors.white24,
    );
  }

  Widget _buildAdminButton() {
    return Padding(
      padding: EdgeInsets.all(_getResponsiveValue(
        context,
        mobile: 16.0,
        tablet: 20.0,
        desktop: 24.0,
      )),
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AdminManagementScreen()),
          );
        },
        icon: const Icon(Icons.admin_panel_settings, color: Colors.white),
        label: Text(
          'Admin Management',
          style: TextStyle(
            color: Colors.white,
            fontSize: _getResponsiveValue(
              context,
              mobile: 14,
              tablet: 16,
              desktop: 18,
            ),
          ),
        ),
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(
            horizontal: _getResponsiveValue(
              context,
              mobile: 20,
              tablet: 25,
              desktop: 30,
            ),
            vertical: _getResponsiveValue(
              context,
              mobile: 15,
              tablet: 18,
              desktop: 20,
            ),
          ),
          backgroundColor: const Color.fromARGB(255, 3, 39, 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext scaffoldContext) {
    return Padding(
      padding: EdgeInsets.all(_getResponsiveValue(
        context,
        mobile: 16.0,
        tablet: 20.0,
        desktop: 24.0,
      )),
      child: ElevatedButton.icon(
        onPressed: () {
          Scaffold.of(scaffoldContext).openDrawer();
        },
        icon: const Icon(Icons.menu, color: Colors.white),
        label: Text(
          'MENU',
          style: TextStyle(
            color: Colors.white,
            fontSize: _getResponsiveValue(
              context,
              mobile: 14,
              tablet: 16,
              desktop: 18,
            ),
          ),
        ),
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(
            horizontal: _getResponsiveValue(
              context,
              mobile: 20,
              tablet: 25,
              desktop: 30,
            ),
            vertical: _getResponsiveValue(
              context,
              mobile: 15,
              tablet: 18,
              desktop: 20,
            ),
          ),
          backgroundColor: const Color.fromARGB(255, 3, 39, 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildCarousel() {
    final carouselHeight = _getResponsiveValue(
      context,
      mobile: MediaQuery.of(context).size.height * 0.35,
      tablet: MediaQuery.of(context).size.height * 0.4,
      desktop: MediaQuery.of(context).size.height * 0.45,
    );

    return Container(
      height: carouselHeight,
      margin: EdgeInsets.symmetric(
        vertical: _getResponsiveValue(
          context,
          mobile: 10,
          tablet: 15,
          desktop: 20,
        ),
      ),
      child: CarouselSlider(
        options: CarouselOptions(
          height: carouselHeight,
          autoPlay: true,
          enlargeCenterPage: true,
          aspectRatio: 16 / 9,
          autoPlayCurve: Curves.fastOutSlowIn,
          enableInfiniteScroll: true,
          autoPlayAnimationDuration: const Duration(milliseconds: 800),
          viewportFraction: _getResponsiveValue(
            context,
            mobile: 0.8,
            tablet: 0.7,
            desktop: 0.6,
          ),
        ),
        items: _carouselImages.map((image) {
          int index = _carouselImages.indexOf(image);
          List<String> labels = [
            'Get Weather Forecasts',
            'Record Field Data Collected',
            'Enhance Pest Management',
            'Effectively Manage Farming funds',
            'Explore Farming Information',
            'Get Better Farming Tips',
            'Understand Soil Information',
          ];

          return Stack(
            children: [
              Container(
                margin: const EdgeInsets.all(5.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.0),
                  image: DecorationImage(
                    image: AssetImage(image),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                bottom: 10,
                left: 10,
                right: 10,
                child: Container(
                  color: Colors.black54,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Text(
                    labels[index],
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: _getResponsiveValue(
                        context,
                        mobile: 14,
                        tablet: 16,
                        desktop: 18,
                      ),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildClickableSections() {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: _getResponsiveValue(
          context,
          mobile: 20,
          tablet: 25,
          desktop: 30,
        ),
        horizontal: _getResponsiveValue(
          context,
          mobile: 16,
          tablet: 20,
          desktop: 24,
        ),
      ),
      child: GridView.count(
        crossAxisCount: _getCrossAxisCount(context),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: _getResponsiveValue(
          context,
          mobile: 1.0,
          tablet: 1.1,
          desktop: 1.2,
        ),
        mainAxisSpacing: _getResponsiveValue(
          context,
          mobile: 10,
          tablet: 15,
          desktop: 20,
        ),
        crossAxisSpacing: _getResponsiveValue(
          context,
          mobile: 10,
          tablet: 15,
          desktop: 20,
        ),
        children: [
          _buildClickableCard('Farming Tips', Icons.lightbulb, () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => FarmingTipsWidget()));
          }),
          _buildClickableCard('Market Prices', Icons.shopping_cart, () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => MarketPricePredictionWidget()));
          }),
        ],
      ),
    );
  }

  Widget _buildClickableCard(String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(_getResponsiveValue(
          context,
          mobile: 15,
          tablet: 20,
          desktop: 25,
        )),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(76, 175, 80, 0.1),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: const Color.fromRGBO(128, 128, 128, 0.5),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: _getResponsiveValue(
                context,
                mobile: 35,
                tablet: 40,
                desktop: 45,
              ),
              color: const Color.fromARGB(255, 3, 39, 4),
            ),
            SizedBox(height: _getResponsiveValue(
              context,
              mobile: 8,
              tablet: 10,
              desktop: 12,
            )),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: _getResponsiveValue(
                  context,
                  mobile: 14,
                  tablet: 16,
                  desktop: 18,
                ),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /*Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Manuals'),
        BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Community'),
        BottomNavigationBarItem(icon: Icon(Icons.article), label: 'Blog'),
      ],
      currentIndex: _selectedIndex,
      selectedItemColor: const Color.fromARGB(255, 3, 39, 4),
      unselectedItemColor: Colors.grey,
      onTap: (index) {
        setState(() {
          _selectedIndex = index;
        });
      },
    );
  }*/

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const UserProfileScreen()));
            },
            child: UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Color.fromARGB(255, 3, 39, 4)),
              accountName: Text(
                _userData?['fullName'] ?? 'Loading...',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: _getResponsiveValue(
                    context,
                    mobile: 16,
                    tablet: 18,
                    desktop: 20,
                  ),
                ),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                radius: _getResponsiveValue(
                  context,
                  mobile: 30,
                  tablet: 35,
                  desktop: 40,
                ),
                child: _profileImageBytes != null
                    ? ClipOval(
                        child: Image.memory(
                          _profileImageBytes!,
                          fit: BoxFit.cover,
                          width: _getResponsiveValue(
                            context,
                            mobile: 60,
                            tablet: 70,
                            desktop: 80,
                          ),
                          height: _getResponsiveValue(
                            context,
                            mobile: 60,
                            tablet: 70,
                            desktop: 80,
                          ),
                          errorBuilder: (context, error, stackTrace) =>
                              Icon(
                                Icons.person,
                                size: _getResponsiveValue(
                                  context,
                                  mobile: 35,
                                  tablet: 40,
                                  desktop: 45,
                                ),
                                color: const Color.fromARGB(255, 3, 39, 4),
                              ),
                        ),
                      )
                    : Icon(
                        Icons.person,
                        size: _getResponsiveValue(
                          context,
                          mobile: 35,
                          tablet: 40,
                          desktop: 45,
                        ),
                        color: const Color.fromARGB(255, 3, 39, 4),
                      ),
              ),
              accountEmail: null,
            ),
          ),
          _buildDrawerItem(Icons.home, 'Home', () {
            Navigator.pop(context);
            setState(() {});
          }),
          _buildDrawerItem(Icons.cloud, 'Weather Forecast', () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const WeatherScreen()));
          }),
          _buildDrawerItem(Icons.input, 'Field Data Input', () {
            logger.i('Navigating to FieldDataInputPage, userId: $_userId');
            if (_userId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FieldDataInputHomePage()),
              );
            } else {
              logger.w('User ID is null, attempting refresh');
              _fetchUserData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('User ID not available. Retrying...')),
              );
            }
          }),
          _buildDrawerItem(Icons.pest_control, 'Manage Pests & Diseases', () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const PestDiseaseHomePage()));
          }),
          _buildDrawerItem(Icons.supervisor_account, 'Farm Management', () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const FarmManagementScreen()));
          }),
          /*_buildDrawerItem(Icons.local_drink, 'Alma Dairy', () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const AlmaDairyHome()));
          }),*/
          _buildDrawerItem(Icons.book, 'Manuals', () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ManualsScreen()));
          }),
          _buildDrawerItem(Icons.settings, 'Settings', () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
          }),
          _buildDrawerItem(Icons.logout, 'Logout', _handleLogout),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(
        icon,
        size: _getResponsiveValue(
          context,
          mobile: 24,
          tablet: 26,
          desktop: 28,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: _getResponsiveValue(
            context,
            mobile: 14,
            tablet: 16,
            desktop: 18,
          ),
        ),
      ),
      onTap: onTap,
    );
  }
}

enum ScreenType { mobile, tablet, desktop }
