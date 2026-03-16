import 'package:flutter/material.dart';
import 'package:kilimomkononi/settings/edit_profile_screen.dart';
import 'package:kilimomkononi/settings/account_settings_screen.dart';
import 'package:kilimomkononi/settings/notifications_settings_screen.dart';
import 'package:kilimomkononi/settings/privacy_policy_screen.dart';
import 'package:kilimomkononi/settings/cookies_settings_screen.dart';
import 'package:kilimomkononi/settings/contact_us_screen.dart';
import 'package:kilimomkononi/settings/faq_screen.dart';
import 'package:kilimomkononi/settings/terms_and_conditions_screen.dart';
import 'package:kilimomkononi/settings/about_kilimo_mkononi_screen.dart';

class SettingsScreen extends StatelessWidget {
  /// Set to true when navigating here from the Education platform.
  /// Determines where the back button returns the user.
  final bool isEducation;

  const SettingsScreen({super.key, this.isEducation = false});

  static const Color _green  = Color(0xFF003900);
  static const Color _darkRed = Color(0xFF8B0000);

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _icon(IconData icon) => Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(shape: BoxShape.circle, color: _green),
        child: Icon(icon, color: Colors.white, size: 20),
      );

  void _push(BuildContext ctx, Widget screen) =>
      Navigator.push(ctx, MaterialPageRoute(builder: (_) => screen));

  /// Back from Settings → correct home platform.
  void _goHome(BuildContext ctx) {
    // If Settings was pushed onto the nav stack (drawer/rail path),
    // pop back to the home screen that is already on the stack.
    // If Settings is embedded as a bottom-nav tab in HomePage (Enterprise),
    // pushReplacementNamed resets to the home route cleanly.
    if (Navigator.of(ctx).canPop()) {
      Navigator.of(ctx).pop();
    } else {
      // Fallback for bottom-nav tab usage: replace current route.
      Navigator.pushReplacementNamed(ctx, isEducation ? '/edu_home' : '/home');
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final double cardWidth   = MediaQuery.of(context).size.width - 32;
    final double profileWidth = cardWidth * 0.75;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => _goHome(context),
        ),
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        backgroundColor: _green,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Profile header ──────────────────────────────────
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80, height: 80,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: _green),
                      child: const Icon(Icons.person, size: 40, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _push(context, EditProfileScreen(isEducation: isEducation)),
                      child: Container(
                        width: profileWidth,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(20)),
                        child: const Center(
                          child: Text('Edit Profile',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── General card ────────────────────────────────────
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('General',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _green)),
                      const SizedBox(height: 10),
                      ListTile(
                        leading: _icon(Icons.account_circle),
                        title: const Text('Account', style: TextStyle(color: _green)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: _green),
                        onTap: () => _push(context, AccountSettingsScreen(isEducation: isEducation)),
                      ),
                      const Divider(height: 1, thickness: 1, indent: 50),
                      ListTile(
                        leading: _icon(Icons.notifications),
                        title: const Text('Notification Settings', style: TextStyle(color: _green)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: _green),
                        onTap: () => _push(context, NotificationsSettingsScreen(isEducation: isEducation)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Help & Legal card ───────────────────────────────
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Help & Legal',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _green)),
                      const SizedBox(height: 10),
                      ListTile(
                        leading: _icon(Icons.contact_support),
                        title: const Text('Contact Us', style: TextStyle(color: _green)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: _green),
                        onTap: () => _push(context, const ContactUsScreen()),
                      ),
                      const Divider(height: 1, thickness: 1, indent: 50),
                      ListTile(
                        leading: _icon(Icons.help),
                        title: const Text('Knowledge Base / FAQ', style: TextStyle(color: _green)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: _green),
                        onTap: () => _push(context, FAQScreen(isEducation: isEducation)),
                      ),
                      const Divider(height: 1, thickness: 1, indent: 50),
                      ListTile(
                        leading: _icon(Icons.description),
                        title: const Text('Terms and Conditions', style: TextStyle(color: _green)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: _green),
                        onTap: () => _push(context, TermsAndConditionsScreen(isEducation: isEducation)),
                      ),
                      const Divider(height: 1, thickness: 1, indent: 50),
                      ListTile(
                        leading: _icon(Icons.privacy_tip),
                        title: const Text('Privacy Policy', style: TextStyle(color: _green)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: _green),
                        onTap: () => _push(context, PrivacyPolicyScreen(isEducation: isEducation)),
                      ),
                      const Divider(height: 1, thickness: 1, indent: 50),
                      ListTile(
                        leading: _icon(Icons.cookie),
                        title: const Text('Cookie Preferences', style: TextStyle(color: _green)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: _green),
                        onTap: () => _push(context, const CookiesSettingsScreen()),
                      ),
                      const Divider(height: 1, thickness: 1, indent: 50),
                      ListTile(
                        leading: _icon(Icons.info),
                        title: const Text('About Kilimo Mkononi', style: TextStyle(color: _green)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: _green),
                        onTap: () => _push(context, const AboutKilimoMkononiScreen()),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Logout ──────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                    color: _darkRed, borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: GestureDetector(
                  onTap: () => ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Logout tapped'))),
                  child: const Center(
                    child: Text('Logout',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
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