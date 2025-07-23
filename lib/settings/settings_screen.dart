import 'package:flutter/material.dart';
import 'package:kilimomkononi/settings/edit_profile_screen.dart';
import 'package:kilimomkononi/settings/account_settings_screen.dart';
import 'package:kilimomkononi/settings/notifications_settings_screen.dart';
import 'package:kilimomkononi/settings/privacy_policy_screen.dart';
import 'package:kilimomkononi/settings/contact_us_screen.dart';
import 'package:kilimomkononi/settings/faq_screen.dart';
import 'package:kilimomkononi/settings/terms_and_conditions_screen.dart';
import 'package:kilimomkononi/settings/about_kilimo_mkononi_screen.dart';
import 'package:kilimomkononi/home.dart';

// Removed standalone main() since HomeScreen should be the entry point
class SettingsScreen extends StatelessWidget {
  final Color customGreen = const Color(0xFF003900);
  final Color darkRed = const Color(0xFF8B0000);

  const SettingsScreen({super.key});

  Widget _buildIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: customGreen,
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double cardWidth = screenWidth - 32.0;
    double editProfileWidth = cardWidth * 0.75;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => HomePage()),
            );
          },
        ),
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.white), // Changed to white for consistency
        ),
        backgroundColor: customGreen, // Changed to match HomeScreen theme
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: customGreen,
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                        );
                      },
                      child: Container(
                        width: editProfileWidth,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        decoration: BoxDecoration(
                          color: customGreen,
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                        child: const Center(
                          child: Text(
                            'Edit Profile',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'General',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: customGreen,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ListTile(
                        leading: _buildIcon(Icons.account_circle),
                        title: Text(
                          'Account',
                          style: TextStyle(color: customGreen),
                        ),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: customGreen),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AccountSettingsScreen()),
                          );
                        },
                      ),
                      const Divider(height: 1, thickness: 1, indent: 50),
                      ListTile(
                        leading: _buildIcon(Icons.notifications),
                        title: Text(
                          'Notification Settings',
                          style: TextStyle(color: customGreen),
                        ),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: customGreen),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const NotificationsSettingsScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Help',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: customGreen,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ListTile(
                        leading: _buildIcon(Icons.contact_support),
                        title: Text('Contact Us', style: TextStyle(color: customGreen)),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const ContactUsScreen()));
                        },
                      ),
                      ListTile(
                        leading: _buildIcon(Icons.help),
                        title: Text('Knowledge Base/FAQ', style: TextStyle(color: customGreen)),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const FAQScreen()));
                        },
                      ),
                      ListTile(
                        leading: _buildIcon(Icons.description),
                        title: Text('Terms and Conditions', style: TextStyle(color: customGreen)),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const TermsAndConditionsScreen()));
                        },
                      ),
                      ListTile(
                        leading: _buildIcon(Icons.privacy_tip),
                        title: Text('Privacy Policy', style: TextStyle(color: customGreen)),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()));
                        },
                      ),
                      ListTile(
                        leading: _buildIcon(Icons.info),
                        title: Text('About Kilimo Mkononi', style: TextStyle(color: customGreen)),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutKilimoMkononiScreen()));
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: darkRed,
                  borderRadius: BorderRadius.circular(20.0),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Logout tapped')),
                    );
                  },
                  child: const Center(
                    child: Text(
                      'Logout',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}