// lib/settings/about_kilimo_mkononi_screen.dart
//
// Settings → About: app identity and version, mission, what the app does,
// who builds it, how to reach us, legal documents and open-source licences.

import 'package:flutter/material.dart';
import 'package:kilimomkononi/settings/contact_us_screen.dart';
import 'package:kilimomkononi/settings/licenses_screen.dart';
import 'package:kilimomkononi/settings/privacy_policy_screen.dart';
import 'package:kilimomkononi/settings/terms_and_conditions_screen.dart';
import 'package:kilimomkononi/settings/widgets/settings_kit.dart';

class AboutKilimoMkononiScreen extends StatelessWidget {
  const AboutKilimoMkononiScreen({super.key});

  static const _features = <(IconData, Color, String, String)>[
    (Icons.cloud_rounded, Color(0xFF1E88E5), 'Weather & stations', 'Forecasts for your farm plus live station readings and verified advice.'),
    (Icons.edit_note_rounded, Color(0xFF2E7D32), 'Field data', 'Record plots, crops, soil tests and activities — even offline.'),
    (Icons.bug_report_rounded, Color(0xFFE53935), 'Pests & diseases', 'Diagnose problems from a photo and plan treatment.'),
    (Icons.account_balance_wallet_rounded, Color(0xFF8E24AA), 'Farm management', 'Track costs, harvests, revenue, profit and loans.'),
    (Icons.price_check_rounded, Color(0xFF00897B), 'Market prices', 'Farmer-reported prices with trends, plus official KAMIS prices.'),
    (Icons.lightbulb_rounded, Color(0xFFEF8F00), 'Tips & manuals', 'Step-by-step crop guides and downloadable manuals.'),
  ];

  @override
  Widget build(BuildContext context) {
    void push(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    return SettingsPage(
      title: 'About',
      subtitle: 'Kilimo Mkononi — Farming in your hands',
      children: [
        // Hero.
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0B3D1E), Color(0xFF1B5E20), Color(0xFF00897B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(children: [
              Positioned(right: -40, top: -40, child: _Bubble(150, Colors.white.withValues(alpha: 0.08))),
              Positioned(left: -30, bottom: -50, child: _Bubble(130, Colors.white.withValues(alpha: 0.06))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
                child: Column(children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6))],
                    ),
                    child: const Icon(Icons.eco_rounded, color: kSetGreen, size: 48),
                  ),
                  const SizedBox(height: 14),
                  const Text('Kilimo Mkononi', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                  const Text('Farming in your hands', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 12),
                  Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: const [
                    _HeroChip(Icons.new_releases_rounded, 'Version $kAppVersion'),
                    _HeroChip(Icons.build_rounded, 'Build $kAppBuild'),
                    _HeroChip(Icons.flag_rounded, 'Made in Kenya'),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 18),
        // Mission.
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(colors: [Color(0xFFE8F5E9), Color(0xFFE0F2F1)]),
          ),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.format_quote_rounded, color: kSetGreen, size: 32),
            SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Our mission', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: kSetGreenDark)),
                SizedBox(height: 6),
                Text(
                  'To give every Kenyan farmer reliable, practical information — weather, crop advice, market prices '
                  'and farm records — in their pocket, so they can grow more, spend less and adapt to a changing climate.',
                  style: TextStyle(height: 1.5, color: kSetInk),
                ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(children: [
            Container(width: 4, height: 15, decoration: BoxDecoration(color: const Color(0xFF1E88E5), borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            const Text('WHAT YOU CAN DO',
                style: TextStyle(color: Color(0xFF1E88E5), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
          ]),
        ),
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth >= 520 ? 3 : 2;
          final w = (c.maxWidth - (cols - 1) * 10) / cols;
          return Wrap(spacing: 10, runSpacing: 10, children: [
            for (final (icon, color, title, text) in _features)
              Container(
                width: w,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, 4))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.white, 0.35)!]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(height: 10),
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: kSetInk)),
                  const SizedBox(height: 4),
                  Text(text, style: const TextStyle(color: kSetMuted, fontSize: 12.5, height: 1.35)),
                ]),
              ),
          ]);
        }),
        const SizedBox(height: 20),
        SettingsSection(title: 'Who we are', color: const Color(0xFF00897B), children: [
          const SettingsTile(
            icon: Icons.business_rounded,
            color: Color(0xFF00897B),
            title: KmContact.company,
            subtitle: 'Builds and runs Kilimo Mkononi, with agricultural content partners including KALRO.',
          ),
          SettingsTile(
            icon: Icons.language_rounded,
            color: const Color(0xFF6A1B9A),
            title: 'Website',
            value: KmContact.website,
            onTap: () => openExternal(context, KmContact.websiteUrl),
          ),
          SettingsTile(
            icon: Icons.support_agent_rounded,
            color: const Color(0xFFB26A00),
            title: 'Contact us',
            subtitle: '${KmContact.phone} · ${KmContact.email}',
            onTap: () => push(const ContactUsScreen()),
          ),
        ]),
        SettingsSection(title: 'Legal', color: const Color(0xFF5E35B1), children: [
          SettingsTile(
            icon: Icons.description_rounded,
            color: const Color(0xFF5E35B1),
            title: 'Terms and conditions',
            onTap: () => push(const TermsAndConditionsScreen()),
          ),
          SettingsTile(
            icon: Icons.privacy_tip_rounded,
            color: const Color(0xFF00838F),
            title: 'Privacy policy',
            onTap: () => push(const PrivacyPolicyScreen()),
          ),
          SettingsTile(
            icon: Icons.code_rounded,
            color: const Color(0xFF3949AB),
            title: 'Open-source licences',
            subtitle: 'Packages the app is built with',
            onTap: () => push(const LicensesScreen()),
          ),
        ]),
        Center(
          child: Text('© ${DateTime.now().year} ${KmContact.company}. All rights reserved.',
              style: const TextStyle(color: kSetMuted, fontSize: 12)),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  final double size;
  final Color color;
  const _Bubble(this.size, this.color);

  @override
  Widget build(BuildContext context) =>
      Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeroChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
        ]),
      );
}
