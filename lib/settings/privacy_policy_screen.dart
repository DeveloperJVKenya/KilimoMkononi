import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
   final bool isEducation;
  const PrivacyPolicyScreen({super.key, this.isEducation = false});

  static const Color customGreen = Color(0xFF003900);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Privacy Policy',
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
              _buildPageTitle(context, 'Privacy Policy'),
              const SizedBox(height: 8),
              _buildMeta('Last Updated: 2025  |  Document Ref: KM-LEGAL-001'),
              const SizedBox(height: 16),

              // ── Introduction ────────────────────────────────────────
              _buildBody(
                'Kilimo Mkononi is operated by JV ALMA CIS Kenya ("JV", "we", "us", or "our"), a company '
                'registered in Kenya. This Privacy Policy explains how we collect, use, store, and protect '
                'your personal data when you use the Kilimo Mkononi mobile application ("the App"). By using '
                'the App, you consent to the practices described in this policy, in accordance with the Kenya '
                'Data Protection Act, 2019 (DPA).',
              ),
              const SizedBox(height: 24),

              // ── Table of Contents ───────────────────────────────────
              _buildSectionTitle(context, 'Contents'),
              _buildTocItem('1. Who We Are — Data Controller'),
              _buildTocItem('2. What Data We Collect'),
              _buildTocItem('3. How We Use Your Data'),
              _buildTocItem('4. Data Sharing'),
              _buildTocItem('5. Data Retention'),
              _buildTocItem('6. Your Rights Under the Kenya DPA'),
              _buildTocItem('7. Children\'s Privacy'),
              _buildTocItem('8. Security'),
              _buildTocItem('9. Third-Party Services'),
              _buildTocItem('10. Changes to This Policy'),
              _buildTocItem('11. Contact Us'),
              const SizedBox(height: 24),

              // ── 1. Who We Are ───────────────────────────────────────
              _buildSectionTitle(context, '1.  Who We Are — Data Controller'),
              _buildBody(
                'JV ALMA CIS Kenya is the Data Controller for all personal data collected through the Kilimo '
                'Mkononi application. As Data Controller, we are responsible for how your data is collected, '
                'used, stored, and protected under the Kenya Data Protection Act, 2019.',
              ),
              _buildBody('Data Controller Contact: support@jvalmacis.co.ke'),
              const SizedBox(height: 24),

              // ── 2. What Data We Collect ─────────────────────────────
              _buildSectionTitle(context, '2.  What Data We Collect'),
              _buildSubtitle('2.1  General User Registration Data'),
              _buildBullet('Full name'),
              _buildBullet('Email address'),
              _buildBullet('Phone number (adult users only)'),
              _buildBullet('County, constituency, and ward'),
              _buildBullet('Farming type and primary crops'),
              _buildBullet('Password (stored as a secure hash — never in plain text)'),

              _buildSubtitle('2.2  Education Module — Student (Minor) Data'),
              _buildBullet('Name and school-assigned email address'),
              _buildBullet('School name and class/grade'),
              _buildBullet(
                  'School contact number only — the student\'s personal phone number is NOT collected'),
              _buildBullet('No home address, photographs, or financial data is collected from minor users'),
              _buildBody(
                'Student accounts are only created under the institutional approval hierarchy (Head Teacher '
                '→ Teacher → Student). No minor may self-register.',
              ),

              _buildSubtitle('2.3  Farm Data'),
              _buildBullet('Farm location (county/sub-county level)'),
              _buildBullet('Farm size and field measurements'),
              _buildBullet('Crop types, yields, soil nutrients, and intervention records'),
              _buildBullet('Pest and disease tracking entries'),
              _buildBullet('Cost, revenue, and farm management records you enter'),

              _buildSubtitle('2.4  Usage and Technical Data'),
              _buildBullet('App features used, session duration, and device type'),
              _buildBullet('Operating system version'),
              _buildBullet('Approximate location (if location permission is granted), used for weather '
                  'forecasts and region-specific advice only'),
              _buildBullet('Market price and weather query history'),
              const SizedBox(height: 24),

              // ── 3. How We Use Your Data ─────────────────────────────
              _buildSectionTitle(context, '3.  How We Use Your Data'),
              _buildBullet(
                'To provide the App\'s features appropriate to your registered role (farming tools, '
                'education modules, market data, weather).',
              ),
              _buildBullet(
                'To manage your account, authenticate your identity, and control access in accordance '
                'with the role hierarchy (Head Teacher → Teacher → Student).',
              ),
              _buildBullet(
                'To send in-app notifications about App updates, planned maintenance, reminders you '
                'have set, and new features.',
              ),
              _buildBullet(
                'To improve the App through anonymised analytics of usage patterns.',
              ),
              _buildBullet(
                'To maintain the teacher-student approval hierarchy and ensure minor users access '
                'only content appropriate to their role.',
              ),
              _buildHighlight(
                'We do NOT use your data for marketing, advertising, or profiling outside the App. '
                'We do NOT sell, rent, or share your personal data with any commercial third party.',
              ),
              const SizedBox(height: 24),

              // ── 4. Data Sharing ─────────────────────────────────────
              _buildSectionTitle(context, '4.  Data Sharing'),
              _buildSubtitle('4.1  Google Firebase (Infrastructure)'),
              _buildBody(
                'The App is built on Google Firebase infrastructure. Your data is stored on Firebase servers '
                'operated by Google LLC, which is certified to SOC 2 Type II and ISO 27001 standards. JV has '
                'a Data Processing Agreement with Google governing this hosting arrangement.',
              ),
              _buildSubtitle('4.2  KALRO (Agricultural Content Partner)'),
              _buildBody(
                'Certain agronomic content within the App is developed in collaboration with the Kenya '
                'Agricultural and Livestock Research Organisation (KALRO). We do NOT share any individual '
                'user\'s personal data with KALRO. KALRO receives only anonymised, aggregate usage '
                'statistics (e.g., how many users accessed a pest management resource in a given county) — '
                'with no information that could identify you.',
              ),
              _buildSubtitle('4.3  Legal Disclosure'),
              _buildBody(
                'We may disclose personal data to the Kenya Police, the Office of the Data Protection '
                'Commissioner (ODPC), or other authorities where required by Kenyan law or by court order.',
              ),
              const SizedBox(height: 24),

              // ── 5. Data Retention ───────────────────────────────────
              _buildSectionTitle(context, '5.  Data Retention'),
              _buildBullet(
                'Active user accounts: retained for the duration of your use of the App, plus 2 years '
                'after account deletion.',
              ),
              _buildBullet(
                'Student/minor accounts: retained for the duration of the student\'s enrolment at their '
                'institution, or until the Head Teacher requests deletion — whichever is earlier.',
              ),
              _buildBullet(
                'Farm data: retained for the duration of your user relationship, plus 2 years.',
              ),
              _buildBullet(
                'When your account is deleted, all associated personal data is removed from Firebase '
                'within 30 days, unless retention is required by Kenyan law.',
              ),
              const SizedBox(height: 24),

              // ── 6. Your Rights ──────────────────────────────────────
              _buildSectionTitle(context, '6.  Your Rights Under the Kenya DPA, 2019'),
              _buildBody(
                'As a data subject under the Kenya Data Protection Act, 2019, you have the following rights:',
              ),
              _buildRightItem(
                icon: Icons.visibility,
                title: 'Right of Access',
                description:
                    'Request a copy of all personal data we hold about you in the App.',
              ),
              _buildRightItem(
                icon: Icons.edit,
                title: 'Right to Correction',
                description:
                    'Request correction of any inaccurate or incomplete data in your profile.',
              ),
              _buildRightItem(
                icon: Icons.delete_outline,
                title: 'Right to Deletion',
                description:
                    'Request deletion of your account and data. Certain data may be retained '
                    'where required by Kenyan law.',
              ),
              _buildRightItem(
                icon: Icons.block,
                title: 'Right to Object',
                description:
                    'Object to certain types of processing, including analytics that you have '
                    'not consented to.',
              ),
              _buildRightItem(
                icon: Icons.gavel,
                title: 'Right to Lodge a Complaint',
                description:
                    'Lodge a complaint with the Office of the Data Protection Commissioner '
                    '(ODPC) if you believe we have violated your rights.',
              ),
              _buildBody(
                'For student (minor) accounts, these rights may be exercised by the registered '
                'Teacher or by a parent/guardian on the student\'s behalf.',
              ),
              _buildBody(
                'To exercise any of these rights: support@jvalmacis.co.ke\n'
                'ODPC: info@odpc.go.ke  |  www.odpc.go.ke',
              ),
              const SizedBox(height: 24),

              // ── 7. Children's Privacy ────────────────────────────────
              _buildSectionTitle(context, '7.  Children\'s Privacy'),
              _buildBody(
                'The Education Module of the App is accessible to students who may be under 18 years of age. '
                'We apply the highest level of data protection to minor users:',
              ),
              _buildBullet(
                'We collect the minimum data necessary — name, school email, school name, and role only.',
              ),
              _buildBullet(
                'Minor accounts are only created under institutional supervision (Head Teacher → '
                'Teacher → Student). No minor may self-register.',
              ),
              _buildBullet(
                'No minor\'s personal phone number, home address, or photograph is collected.',
              ),
              _buildBullet(
                'No direct communication channel exists between minor users and any adult user '
                'outside the assigned Teacher.',
              ),
              _buildBullet(
                'Minor user data is never shared with KALRO or any third party, and is never used '
                'for marketing or analytics profiling.',
              ),
              _buildBullet(
                'A parent or legal guardian may request access to, correction of, or deletion of '
                'their child\'s data at any time: support@jvalmacis.co.ke',
              ),
              const SizedBox(height: 24),

              // ── 8. Security ─────────────────────────────────────────
              _buildSectionTitle(context, '8.  Security'),
              _buildBody('JV protects your data using the following technical measures:'),
              _buildBullet(
                'AES-256 encryption at rest for all stored data (via Google Firebase\'s default '
                'encryption standard).',
              ),
              _buildBullet(
                'TLS 1.2 or higher encryption for all data transmitted between your device and '
                'our servers.',
              ),
              _buildBullet(
                'Role-based access controls — each user can only access data relevant to their '
                'own role and account.',
              ),
              _buildBullet(
                'Data masking — unique system-generated identifiers (UIDs) are used as database '
                'keys, not your name or email address. Cross-referencing a UID to your identity '
                'requires authenticated access.',
              ),
              _buildBullet(
                'Multi-factor authentication (MFA) for administrator accounts.',
              ),
              _buildBullet(
                'Automated alerts for anomalous activity, including login attempts from '
                'unrecognised devices, unusual data access volumes, and repeated authentication '
                'failures.',
              ),
              _buildBody(
                'No system is completely secure and we cannot guarantee absolute protection against '
                'all threats. If you believe your account has been compromised, contact us immediately '
                'at support@jvalmacis.co.ke.',
              ),
              const SizedBox(height: 24),

              // ── 9. Third-Party Services ─────────────────────────────
              _buildSectionTitle(context, '9.  Third-Party Services'),
              _buildBody(
                'The following third-party services are used within the App. Each operates under its '
                'own privacy policy and is subject to a data processing arrangement with JV:',
              ),
              _buildBullet(
                'Google Firebase (Google LLC) — database, authentication, file storage, and app '
                'hosting. Firebase is SOC 2 / ISO 27001 certified.',
              ),
              _buildBullet(
                'OpenWeather API — weather forecast data displayed within the App. Location queries '
                'are made using your approximate county-level location only. No personally '
                'identifiable data is transmitted to the weather provider.',
              ),
              _buildBullet(
                'KALRO — agricultural content partner. Receives only anonymised aggregate usage '
                'data. See Section 4.2 for full details.',
              ),
              _buildBody(
                'JV does not use any advertising networks, social media trackers, or third-party '
                'analytics tools that would share your personal data with advertisers.',
              ),
              const SizedBox(height: 24),

              // ── 10. Changes ─────────────────────────────────────────
              _buildSectionTitle(context, '10.  Changes to This Policy'),
              _buildBody(
                'We may update this Privacy Policy from time to time to reflect changes in our '
                'practices, technology, or legal requirements. We will notify you of material changes '
                'via an in-app notification at least 14 days before the change takes effect. Continued '
                'use of the App after the effective date constitutes your acceptance of the updated policy.',
              ),
              const SizedBox(height: 24),

              // ── 11. Contact ─────────────────────────────────────────
              _buildSectionTitle(context, '11.  Contact Us'),
              _buildBody(
                'For questions, requests, or concerns about your privacy, or to exercise your data '
                'rights, please contact us:',
              ),
              _buildContactRow(Icons.email, 'support@jvalmacis.co.ke'),
              _buildContactRow(Icons.phone, '+254 795 802 020'),
              _buildContactRow(
                  Icons.language, 'www.jvalmacis.co.ke'),
              _buildContactRow(
                Icons.location_on,
                'Kin\'gara Heights, James Gichuru Rd, Nairobi, Kenya',
              ),
              const SizedBox(height: 8),
              _buildBody(
                'Office of the Data Protection Commissioner (ODPC):\n'
                'info@odpc.go.ke  |  www.odpc.go.ke',
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
        style: const TextStyle(fontSize: 15, height: 1.6, color: Color(0xFF333333)),
      ),
    );
  }

  Widget _buildHighlight(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(8.0),
        border: const Border(left: BorderSide(color: customGreen, width: 3)),
      ),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 15, height: 1.6, color: customGreen, fontWeight: FontWeight.w500),
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
              style: TextStyle(fontSize: 16, color: customGreen, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 15, height: 1.6, color: Color(0xFF333333)),
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

  Widget _buildRightItem(
      {required IconData icon, required String title, required String description}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6.0),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: customGreen,
            ),
            child: Icon(icon, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: customGreen)),
                const SizedBox(height: 2),
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
              style: const TextStyle(fontSize: 15, height: 1.5, color: Color(0xFF333333)),
            ),
          ),
        ],
      ),
    );
  }
}