// lib/settings/about_kilimo_mkononi_screen.dart
//
// Settings → About: app identity and version, mission, what the app does
// (each feature card explains itself), who builds it, how to reach us, and
// the open-source licences.

import 'package:flutter/material.dart';
import 'package:kilimomkononi/settings/contact_us_screen.dart';
import 'package:kilimomkononi/settings/privacy_policy_screen.dart';
import 'package:kilimomkononi/settings/terms_and_conditions_screen.dart';
import 'package:kilimomkononi/settings/widgets/settings_kit.dart';

class AboutKilimoMkononiScreen extends StatelessWidget {
  const AboutKilimoMkononiScreen({super.key});

  static const _features = <(IconData, Color, String, String)>[
    (Icons.cloud_rounded, Color(0xFF1565C0), 'Weather & stations', 'Forecasts for your farm plus live readings and verified advice from weather stations.'),
    (Icons.edit_note_rounded, Color(0xFF2E7D32), 'Field data', 'Record plots, crops, soil tests and activities — even offline.'),
    (Icons.bug_report_rounded, Color(0xFFC62828), 'Pests & diseases', 'Diagnose problems from a photo and plan treatment.'),
    (Icons.account_balance_wallet_rounded, Color(0xFF6A1B9A), 'Farm management', 'Track costs, harvests, revenue, profit and loans.'),
    (Icons.price_check_rounded, Color(0xFF2E6A5E), 'Market prices', 'Farmer-reported prices with trends, plus official KAMIS prices.'),
    (Icons.lightbulb_rounded, Color(0xFF9E9D24), 'Tips & manuals', 'Step-by-step crop guides and downloadable manuals.'),
  ];

  @override
  Widget build(BuildContext context) {
    void push(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    return SettingsPage(
      title: 'About',
      subtitle: 'Kilimo Mkononi — Farming in your hands',
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [kSetGreenDark, kSetGreen, Color(0xFF2E7D32)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(22)),
              child: const Icon(Icons.eco_rounded, color: Colors.white, size: 44),
            ),
            const SizedBox(height: 12),
            const Text('Kilimo Mkononi', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            const Text('Farming in your hands', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
              child: const Text('Version $kAppVersion (build $kAppBuild)',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5)),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        const SettingsSection(title: 'Our mission', children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'To give every Kenyan farmer reliable, practical information — weather, crop advice, market prices and '
              'farm records — in their pocket, so they can grow more, spend less and adapt to a changing climate.',
              style: TextStyle(height: 1.5, color: kSetInk),
            ),
          ),
        ]),
        const Padding(
          padding: EdgeInsets.only(left: 6, bottom: 8),
          child: Text('WHAT YOU CAN DO',
              style: TextStyle(color: kSetMuted, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
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
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kSetBorder),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SettingsIcon(icon, color: color),
                  const SizedBox(height: 10),
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: kSetInk)),
                  const SizedBox(height: 4),
                  Text(text, style: const TextStyle(color: kSetMuted, fontSize: 12.5, height: 1.35)),
                ]),
              ),
          ]);
        }),
        const SizedBox(height: 18),
        SettingsSection(title: 'Who we are', children: [
          const SettingsTile(
            icon: Icons.business_rounded,
            title: KmContact.company,
            subtitle: 'Builds and runs Kilimo Mkononi, with agricultural content partners including KALRO.',
          ),
          SettingsTile(
            icon: Icons.language_rounded,
            title: 'Website',
            value: KmContact.website,
            onTap: () => openExternal(context, KmContact.websiteUrl),
          ),
          SettingsTile(
            icon: Icons.support_agent_rounded,
            title: 'Contact us',
            subtitle: '${KmContact.phone} · ${KmContact.email}',
            onTap: () => push(const ContactUsScreen()),
          ),
        ]),
        SettingsSection(title: 'Legal', children: [
          SettingsTile(
            icon: Icons.description_rounded,
            color: kSetMuted,
            title: 'Terms and conditions',
            onTap: () => push(const TermsAndConditionsScreen()),
          ),
          SettingsTile(
            icon: Icons.privacy_tip_rounded,
            color: kSetMuted,
            title: 'Privacy policy',
            onTap: () => push(const PrivacyPolicyScreen()),
          ),
          SettingsTile(
            icon: Icons.code_rounded,
            color: kSetMuted,
            title: 'Open-source licences',
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Kilimo Mkononi',
              applicationVersion: '$kAppVersion ($kAppBuild)',
              applicationLegalese: '© ${DateTime.now().year} ${KmContact.company}',
            ),
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
