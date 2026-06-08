import 'package:flutter/material.dart';

class TermsAndConditionsScreen extends StatelessWidget {
   final bool isEducation;
  const TermsAndConditionsScreen({super.key, this.isEducation = false});

  static const Color customGreen = Color(0xFF003900);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Terms and Conditions',
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
              // ── Header ──────────────────────────────────────────────
              _buildPageTitle(context, 'Terms and Conditions'),
              const SizedBox(height: 8),
              _buildMeta(
                  'Last Updated: 2025  |  Document Ref: KM-LEGAL-001  |  Version 1.0'),
              const SizedBox(height: 16),

              // ── Introduction ────────────────────────────────────────
              _buildBody(
                'These Terms and Conditions ("Terms") govern your access to and use of the Kilimo Mkononi '
                'mobile application ("the App"), operated by JV ALMA CIS Kenya ("JV", "we", "us", or "our"), '
                'a company registered in Kenya. By downloading, installing, or using the App, you agree to '
                'be bound by these Terms. If you do not agree, do not use the App.',
              ),
              const SizedBox(height: 24),

              // ── Table of Contents ───────────────────────────────────
              _buildSectionTitle(context, 'Contents'),
              _buildTocItem('1.  About Kilimo Mkononi'),
              _buildTocItem('2.  Who May Use the App'),
              _buildTocItem('3.  Account Registration'),
              _buildTocItem('4.  Permitted and Prohibited Conduct'),
              _buildTocItem('5.  Education Module — Institutional Obligations'),
              _buildTocItem('6.  Content and Agricultural Information'),
              _buildTocItem('7.  KALRO Content Collaboration'),
              _buildTocItem('8.  Intellectual Property'),
              _buildTocItem('9.  Service Availability'),
              _buildTocItem('10. Privacy'),
              _buildTocItem('11. Third-Party Services'),
              _buildTocItem('12. Limitation of Liability'),
              _buildTocItem('13. Termination'),
              _buildTocItem('14. Governing Law'),
              _buildTocItem('15. Changes to These Terms'),
              _buildTocItem('16. Contact Us'),
              const SizedBox(height: 24),

              // ── 1 ───────────────────────────────────────────────────
              _buildSectionTitle(context, '1.  About Kilimo Mkononi'),
              _buildBody(
                'Kilimo Mkononi ("Farming in Your Hands") is an AgriTech mobile application designed to '
                'support smallholder farmers, agricultural students, and educational institutions across '
                'Kenya. The App provides farming tips, market price information, weather forecasts, pest '
                'and disease management guidance, farm management tools, and — through the Education '
                'Module — a structured learning environment for students and teachers.',
              ),
              const SizedBox(height: 24),

              // ── 2 ───────────────────────────────────────────────────
              _buildSectionTitle(context, '2.  Who May Use the App'),
              _buildUserTypeCard(
                icon: Icons.agriculture,
                title: 'General Users (Farmers)',
                description:
                    'Any individual aged 18 and above may register as a general user to access '
                    'farming tools, market data, and weather features.',
              ),
              _buildUserTypeCard(
                icon: Icons.school,
                title: 'Education Module — Students',
                description:
                    'Students may only access the App under the supervision and explicit approval '
                    'of a registered Teacher at a registered institution. Students under 18 are '
                    'considered minor users and are subject to additional protections.',
              ),
              _buildUserTypeCard(
                icon: Icons.person,
                title: 'Education Module — Teachers',
                description:
                    'Teachers must be registered and approved by the Head Teacher of a registered '
                    'educational institution before they may create or manage student accounts.',
              ),
              _buildUserTypeCard(
                icon: Icons.admin_panel_settings,
                title: 'Head Teachers / Administrators',
                description:
                    'Institutional administrators are responsible for approving Teachers and for '
                    'the proper use of the App within their institution. By registering on behalf '
                    'of an institution, the institution accepts these Terms on behalf of all users '
                    'it onboards, including minor students.',
              ),
              const SizedBox(height: 24),

              // ── 3 ───────────────────────────────────────────────────
              _buildSectionTitle(context, '3.  Account Registration'),
              _buildBullet(
                'You must provide accurate, complete, and current information at registration.',
              ),
              _buildBullet(
                'You are responsible for maintaining the confidentiality of your login credentials. '
                'Do not share your password with any other person.',
              ),
              _buildBullet(
                'You must notify us immediately at support@jvalmacis.co.ke if you suspect any '
                'unauthorised access to your account.',
              ),
              _buildBullet(
                'JV reserves the right to suspend or terminate accounts that provide false '
                'information or violate these Terms.',
              ),
              const SizedBox(height: 24),

              // ── 4 ───────────────────────────────────────────────────
              _buildSectionTitle(context, '4.  Permitted and Prohibited Conduct'),
              _buildSubtitle('4.1  Permitted Use'),
              _buildBody(
                'The App is provided for personal, non-commercial agricultural education and farm '
                'management purposes. You may access and use the features available to your registered role.',
              ),
              _buildSubtitle('4.2  Prohibited Conduct'),
              _buildBullet(
                  'Using the App for any purpose other than agricultural education or farm management.'),
              _buildBullet(
                  'Attempting to access another user\'s account, data, or features beyond your assigned role.'),
              _buildBullet('Uploading false, misleading, or harmful information to the App.'),
              _buildBullet(
                  'Attempting to reverse-engineer, copy, distribute, or exploit the App\'s source code.'),
              _buildBullet(
                  'Using the App to send unsolicited communications or spam to other users.'),
              _buildBullet(
                  'Attempting to bypass, circumvent, or disable any security control within the App.'),
              _buildBullet(
                  'Allowing a minor student to create an account independently, without Teacher and '
                  'Head Teacher approval.'),
              _buildBullet(
                  'Accessing the App from any device using someone else\'s credentials.'),
              const SizedBox(height: 24),

              // ── 5 ───────────────────────────────────────────────────
              _buildSectionTitle(context, '5.  Education Module — Institutional Obligations'),
              _buildBody(
                'By registering their institution on the Education Module, the Head Teacher and the '
                'institution agree to:',
              ),
              _buildBullet(
                  'Ensure all student accounts are for genuine enrolled students only.'),
              _buildBullet(
                  'Obtain written parental or guardian consent for each minor student before '
                  'creating their account. JV will provide a consent form template upon registration.'),
              _buildBullet(
                  'Notify JV immediately if a student leaves the institution, so the account can '
                  'be deactivated.'),
              _buildBullet(
                  'Report any concern, complaint, or incident relating to a minor user\'s safety '
                  'or data to JV immediately at support@jvalmacis.co.ke.'),
              _buildBullet(
                  'Ensure no direct communication is facilitated between minor students and adult '
                  'users outside the defined teacher-student class structure.'),
              const SizedBox(height: 24),

              // ── 6 ───────────────────────────────────────────────────
              _buildSectionTitle(context, '6.  Content and Agricultural Information'),
              _buildBody(
                'Farming tips, market prices, weather data, pest and disease information, and '
                'agronomic content are provided for informational and educational purposes only.',
              ),
              _buildHighlight(
                'JV does not guarantee the accuracy, completeness, or timeliness of any content '
                'provided in the App. Farmers and agricultural professionals should exercise '
                'independent judgement before making farming decisions based on App content. JV is '
                'not liable for any agricultural loss, crop failure, or financial loss resulting '
                'from reliance on App information.',
              ),
              const SizedBox(height: 24),

              // ── 7 ───────────────────────────────────────────────────
              _buildSectionTitle(context, '7.  KALRO Content Collaboration'),
              _buildBody(
                'Certain agronomic content within the App is developed in collaboration with the Kenya '
                'Agricultural and Livestock Research Organisation (KALRO) under a formal Memorandum of '
                'Understanding. Such content is provided for educational purposes only and is the '
                'intellectual property of KALRO. You may not reproduce or commercially exploit KALRO '
                'content outside the App.',
              ),
              _buildBody(
                'JV does NOT share your personal data with KALRO. See the Privacy Policy (accessible '
                'from Settings) for full details.',
              ),
              const SizedBox(height: 24),

              // ── 8 ───────────────────────────────────────────────────
              _buildSectionTitle(context, '8.  Intellectual Property'),
              _buildBody(
                'All content, software, design, trademarks, and data within the App are the '
                'intellectual property of JV ALMA CIS Kenya or its licensed partners (including KALRO '
                'for agronomic content). You may not reproduce, distribute, modify, or create '
                'derivative works from any App content without prior written permission from JV. '
                'The App is licensed to you for personal use only — it is not sold to you.',
              ),
              const SizedBox(height: 24),

              // ── 9 ───────────────────────────────────────────────────
              _buildSectionTitle(context, '9.  Service Availability'),
              _buildBody(
                'JV targets 98% App uptime but does not guarantee uninterrupted service. The App '
                'may be temporarily unavailable due to:',
              ),
              _buildBullet(
                  'Planned maintenance (notified via in-app message at least 24 hours in advance)'),
              _buildBullet('Google Firebase infrastructure issues'),
              _buildBullet('Network outages or force majeure events'),
              _buildBullet('Emergency security updates'),
              _buildBody(
                'JV is not liable for any loss or inconvenience arising from App unavailability.',
              ),
              const SizedBox(height: 24),

              // ── 10 ──────────────────────────────────────────────────
              _buildSectionTitle(context, '10.  Privacy'),
              _buildBody(
                'Your use of Kilimo Mkononi is governed by our Privacy Policy, which is accessible '
                'from the Settings menu. The Privacy Policy explains how we collect, use, store, and '
                'protect your personal data in accordance with the Kenya Data Protection Act, 2019. '
                'By using the App, you consent to data collection and processing as outlined in the '
                'Privacy Policy.',
              ),
              const SizedBox(height: 24),

              // ── 11 ──────────────────────────────────────────────────
              _buildSectionTitle(context, '11.  Third-Party Services'),
              _buildBody(
                'The App relies on third-party services including:',
              ),
              _buildBullet(
                'Google Firebase (Google LLC) — database, authentication, storage, and hosting. '
                'Subject to Google\'s Terms of Service and Privacy Policy.',
              ),
              _buildBullet(
                'OpenWeather API — weather forecast data. Market price data may be sourced from '
                'publicly available data sets and is provided without warranty of accuracy.',
              ),
              _buildBody(
                'JV is not responsible for any data loss, outage, or security incident caused by '
                'these third-party services.',
              ),
              const SizedBox(height: 24),

              // ── 12 ──────────────────────────────────────────────────
              _buildSectionTitle(context, '12.  Limitation of Liability'),
              _buildBody(
                'To the fullest extent permitted by Kenyan law, JV ALMA CIS Kenya shall not be '
                'liable for:',
              ),
              _buildBullet(
                  'Any indirect, incidental, special, or consequential loss arising from use of the App'),
              _buildBullet(
                  'Agricultural or financial loss arising from reliance on App content or weather data'),
              _buildBullet(
                  'Loss of data due to infrastructure outages beyond JV\'s reasonable control'),
              _buildBullet(
                  'Unauthorized access caused by a user\'s breach of these Terms (e.g., sharing credentials)'),
              _buildBody(
                'JV\'s total aggregate liability to you for any claim shall not exceed the amount '
                '(if any) paid by you for the App in the twelve months preceding the claim.',
              ),
              const SizedBox(height: 24),

              // ── 13 ──────────────────────────────────────────────────
              _buildSectionTitle(context, '13.  Termination'),
              _buildBody(
                'JV reserves the right to suspend or permanently terminate your access to the App if you:',
              ),
              _buildBullet('Violate any of these Terms'),
              _buildBullet('Provide false registration information'),
              _buildBullet(
                  'Engage in conduct harmful to other users, to the App, or to the integrity of its data'),
              _buildBullet('Breach the minor user protection requirements in Section 5'),
              _buildBody(
                'Upon termination, your personal data will be handled in accordance with the '
                'Privacy Policy. You may request deletion of your account and data at any time by '
                'contacting support@jvalmacis.co.ke.',
              ),
              const SizedBox(height: 24),

              // ── 14 ──────────────────────────────────────────────────
              _buildSectionTitle(context, '14.  Governing Law'),
              _buildBody(
                'These Terms are governed by and construed in accordance with the laws of Kenya. '
                'Any dispute arising from or relating to these Terms shall be subject to the '
                'exclusive jurisdiction of the Kenyan courts.',
              ),
              const SizedBox(height: 24),

              // ── 15 ──────────────────────────────────────────────────
              _buildSectionTitle(context, '15.  Changes to These Terms'),
              _buildBody(
                'JV may update these Terms from time to time. We will notify users of material '
                'changes via in-app notification at least 14 days before the change takes effect. '
                'Continued use of the App after the effective date of the revised Terms constitutes '
                'your acceptance of those changes.',
              ),
              const SizedBox(height: 24),

              // ── 16 ──────────────────────────────────────────────────
              _buildSectionTitle(context, '16.  Contact Us'),
              _buildBody(
                'For questions about these Terms or to exercise your rights, please contact us:',
              ),
              _buildContactRow(Icons.email, 'support@jvalmacis.co.ke'),
              _buildContactRow(Icons.phone, '+254 795 802 020'),
              _buildContactRow(Icons.language, 'www.jvalmacis.co.ke'),
              _buildContactRow(
                Icons.location_on,
                'Kin\'gara Heights, James Gichuru Rd, Nairobi, Kenya',
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

  // ── Widget Helpers ─────────────────────────────────────────────────────────

  Widget _buildPageTitle(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: customGreen,
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildMeta(String text) {
    return Text(
      text,
      style: TextStyle(
          fontSize: 13, color: Colors.grey[600], fontStyle: FontStyle.italic),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: customGreen,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const Divider(color: Color(0xFF003900), thickness: 1),
        ],
      ),
    );
  }

  Widget _buildSubtitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 10.0, bottom: 4.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: customGreen,
        ),
      ),
    );
  }

  Widget _buildBody(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 15, height: 1.6, color: Color(0xFF333333)),
      ),
    );
  }

  Widget _buildHighlight(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E6),
        borderRadius: BorderRadius.circular(8.0),
        border: const Border(left: BorderSide(color: Color(0xFFE6A817), width: 3)),
      ),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 15, height: 1.6, color: Color(0xFF333333)),
      ),
    );
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ',
              style: TextStyle(
                  fontSize: 16, color: customGreen, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 15, height: 1.6, color: Color(0xFF333333)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTocItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, bottom: 6.0),
      child: Row(
        children: [
          const Icon(Icons.chevron_right, size: 16, color: customGreen),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 14, color: customGreen),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTypeCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: customGreen,
            ),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: customGreen)),
                const SizedBox(height: 4),
                Text(description,
                    style: const TextStyle(
                        fontSize: 14, height: 1.5, color: Color(0xFF333333))),
              ],
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: customGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 15, height: 1.5, color: Color(0xFF333333)),
            ),
          ),
        ],
      ),
    );
  }
}