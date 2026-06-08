import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CookiesSettingsScreen extends StatefulWidget {
   final bool isEducation;
  const CookiesSettingsScreen({super.key, this.isEducation = false});

  @override
  State<CookiesSettingsScreen> createState() => _CookiesSettingsScreenState();
}

class _CookiesSettingsScreenState extends State<CookiesSettingsScreen> {
  static const Color customGreen = Color(0xFF003900);

  // Cookie preference state
  // Strictly necessary: always true, cannot be toggled
  bool _analyticsCookies = true;
  bool _performanceCookies = true;

  // SharedPreferences keys
  static const String _analyticsKey = 'cookies_analytics';
  static const String _performanceKey = 'cookies_performance';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _analyticsCookies = prefs.getBool(_analyticsKey) ?? true;
      _performanceCookies = prefs.getBool(_performanceKey) ?? true;
    });
  }

  Future<void> _savePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Widget _buildIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: customGreen,
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double cardWidth = screenWidth - 32.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Cookie Preferences',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: customGreen,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Page title ───────────────────────────────────────────
              Text(
                'Cookie Preferences',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: customGreen,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Last Updated: 2025  |  Document Ref: KM-LEGAL-001',
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 16),

              // ── What are cookies ─────────────────────────────────────
              _buildInfoCard(
                context,
                icon: Icons.info_outline,
                title: 'About Cookies',
                content:
                    'Cookies are small data files placed on your device that help the App '
                    'recognise your session, remember your preferences, and understand how '
                    'you use its features. This App uses only essential, analytics, and '
                    'performance-related data — never advertising or tracking cookies.',
              ),
              const SizedBox(height: 16),

              // ── Strictly Necessary ───────────────────────────────────
              Card(
                elevation: 4,
                child: SizedBox(
                  width: cardWidth,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildIcon(Icons.lock),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Strictly Necessary',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: customGreen,
                                ),
                              ),
                            ),
                            // Always-on chip
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: customGreen,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Always On',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'These are essential for the App to function. They manage your login '
                          'session, secure your account, protect against session hijacking, and '
                          'remember your cookie consent choice. They cannot be disabled.',
                          style: TextStyle(
                              fontSize: 14,
                              height: 1.6,
                              color: Color(0xFF444444)),
                        ),
                        const SizedBox(height: 10),
                        _buildCookieDetailRow(
                            'Session token', 'Keeps you logged in'),
                        _buildCookieDetailRow(
                            'CSRF token', 'Protects against request forgery'),
                        _buildCookieDetailRow(
                            'Consent record', 'Remembers your cookie choices'),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Duration: Session (deleted when you close the App) or up to 1 year '
                            'for consent record.',
                            style: TextStyle(
                                fontSize: 13,
                                color: customGreen,
                                fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Analytics ────────────────────────────────────────────
              Card(
                elevation: 4,
                child: SizedBox(
                  width: cardWidth,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          secondary: _buildIcon(Icons.bar_chart),
                          title: const Text(
                            'Analytics',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: customGreen),
                          ),
                          value: _analyticsCookies,
                          activeThumbColor: customGreen,
                          onChanged: (bool value) {
                            setState(() => _analyticsCookies = value);
                            _savePreference(_analyticsKey, value);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(value
                                    ? 'Analytics enabled'
                                    : 'Analytics disabled'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            'Helps us understand how you use the App — which features you access '
                            'most, how long sessions last, and which parts of the App need '
                            'improvement. All data is anonymised: no personally identifiable '
                            'information is collected or shared.',
                            style: TextStyle(
                                fontSize: 14,
                                height: 1.6,
                                color: Color(0xFF444444)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: _buildCookieDetailRow(
                              'Usage patterns', 'Anonymised feature usage data'),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: _buildCookieDetailRow(
                              'Session duration', 'How long each App session lasts'),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Duration: Up to 12 months. You can opt out at any time by '
                              'toggling this switch off.',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: customGreen,
                                  fontStyle: FontStyle.italic),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Performance ──────────────────────────────────────────
              Card(
                elevation: 4,
                child: SizedBox(
                  width: cardWidth,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          secondary: _buildIcon(Icons.speed),
                          title: const Text(
                            'Performance',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: customGreen),
                          ),
                          value: _performanceCookies,
                          activeThumbColor: customGreen,
                          onChanged: (bool value) {
                            setState(() => _performanceCookies = value);
                            _savePreference(_performanceKey, value);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(value
                                    ? 'Performance monitoring enabled'
                                    : 'Performance monitoring disabled'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            'Monitors App load times, screen rendering speed, and technical errors. '
                            'Helps the IT team identify and fix performance issues before they '
                            'affect your experience. No personally identifiable data is collected.',
                            style: TextStyle(
                                fontSize: 14,
                                height: 1.6,
                                color: Color(0xFF444444)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: _buildCookieDetailRow(
                              'Load times', 'Screen and data load duration'),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: _buildCookieDetailRow(
                              'Crash reports', 'Anonymous technical error logs'),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Duration: Session only — cleared when you close the App.',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: customGreen,
                                  fontStyle: FontStyle.italic),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── What We Don't Use ────────────────────────────────────
              _buildInfoCard(
                context,
                icon: Icons.block,
                title: 'What We Do NOT Use',
                content:
                    'Kilimo Mkononi does not use:\n'
                    '• Advertising or tracking cookies\n'
                    '• Social media tracking pixels\n'
                    '• Any cookie that shares your personal data with a third party for '
                    'commercial purposes\n'
                    '• Fingerprinting or device tracking technologies',
              ),
              const SizedBox(height: 16),

              // ── Third-party note ─────────────────────────────────────
              Card(
                elevation: 4,
                child: SizedBox(
                  width: cardWidth,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildIcon(Icons.people_outline),
                            const SizedBox(width: 10),
                            Text(
                              'Third-Party Services',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: customGreen,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'The App uses Google Firebase for database and authentication services. '
                          'Firebase may use its own technical identifiers (not marketing cookies) '
                          'to maintain your authenticated session. These operate under Google\'s '
                          'Privacy Policy and are strictly necessary for App functionality.',
                          style: TextStyle(
                              fontSize: 14,
                              height: 1.6,
                              color: Color(0xFF444444)),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Weather data is provided via the OpenWeather API. Only your '
                          'county-level location is used for weather queries — no personally '
                          'identifiable data is transmitted to the weather provider.',
                          style: TextStyle(
                              fontSize: 14,
                              height: 1.6,
                              color: Color(0xFF444444)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Changes ──────────────────────────────────────────────
              _buildInfoCard(
                context,
                icon: Icons.update,
                title: 'Changes to These Preferences',
                content:
                    'We may update our cookie practices from time to time. If we make material '
                    'changes, you will be notified via an in-app notification. Your preferences '
                    'will be respected unless you choose to update them here.',
              ),
              const SizedBox(height: 16),

              // ── Contact ──────────────────────────────────────────────
              Card(
                elevation: 4,
                child: SizedBox(
                  width: cardWidth,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildIcon(Icons.mail_outline),
                            const SizedBox(width: 10),
                            Text(
                              'Questions About Cookies?',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: customGreen,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildContactRow(Icons.email, 'support@jvalmacis.co.ke'),
                        _buildContactRow(Icons.phone, '+254 795 802 020'),
                        _buildContactRow(
                            Icons.language, 'www.jvalmacis.co.ke'),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Footer ───────────────────────────────────────────────
              const Center(
                child: Text(
                  '© 2025 JV ALMA CIS Kenya / Kilimo Mkononi. All rights reserved.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── Widget helpers ─────────────────────────────────────────────────────────

  Widget _buildInfoCard(BuildContext context,
      {required IconData icon,
      required String title,
      required String content}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: const Color(0xFFB2DFDB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: customGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: customGreen),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
                fontSize: 14, height: 1.6, color: Color(0xFF333333)),
          ),
        ],
      ),
    );
  }

  Widget _buildCookieDetailRow(String name, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ',
              style: TextStyle(
                  fontSize: 14,
                  color: customGreen,
                  fontWeight: FontWeight.bold)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                    fontSize: 13, height: 1.5, color: Color(0xFF444444)),
                children: [
                  TextSpan(
                      text: '$name: ',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: description),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: customGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 14, height: 1.5, color: Color(0xFF333333)),
            ),
          ),
        ],
      ),
    );
  }
}