// lib/settings/faq_screen.dart
//
// Settings → Help centre: searchable, grouped answers about the app's real
// features, with a "still need help?" link to Contact us.

import 'package:flutter/material.dart';
import 'package:kilimomkononi/settings/contact_us_screen.dart';
import 'package:kilimomkononi/settings/widgets/settings_kit.dart';

class Faq {
  final String category;
  final IconData icon;
  final String q;
  final String a;
  const Faq(this.category, this.icon, this.q, this.a);

  bool matches(String query) {
    final t = query.trim().toLowerCase();
    return t.isEmpty || q.toLowerCase().contains(t) || a.toLowerCase().contains(t) || category.toLowerCase().contains(t);
  }
}

const kFarmerFaqs = <Faq>[
  Faq('Getting started', Icons.rocket_launch_rounded, 'What can I do with Kilimo Mkononi?',
      'Record your plots and crops (Field Data Input), check the weather and your farm\'s weather station, diagnose '
          'pests and diseases from a photo, track costs, harvests and loans (Farm Management), compare market prices, '
          'and read step-by-step farming tips and manuals.'),
  Faq('Getting started', Icons.rocket_launch_rounded, 'Does the app work without internet?',
      'Yes, for recording. Field data, pest and disease records, reminders and costs are saved on your phone when you '
          'are offline and upload automatically when you reconnect. You can see what is waiting in Settings → Offline '
          'data. Weather, prices and AI diagnosis need a connection.'),
  Faq('Weather & stations', Icons.cloud_rounded, 'Where does the weather forecast come from?',
      'The Weather screen uses Google Weather for your location, your farm or any place you type. If your farm is '
          'linked to a Kilimo Mkononi weather station, the Weather Station screen also shows the station\'s own live '
          'readings (rain, soil moisture, temperature, spray conditions). Each is clearly labelled.'),
  Faq('Weather & stations', Icons.cloud_rounded, 'How do I see my weather station?',
      'Open Field Data Input and choose Weather Station. Stations are assigned to farms by the Kilimo Mkononi team — '
          'contact us if your farm has a station but you can\'t see it.'),
  Faq('Weather & stations', Icons.cloud_rounded, 'What is "Verified advice"?',
      'Advice written and checked by a Field Agronomist for your crops and the conditions your station is recording. '
          'The AI Farm Advisor underneath is labelled "AI-generated · not verified" — use it as a guide only.'),
  Faq('Field data', Icons.edit_note_rounded, 'How do I add a plot or crop?',
      'Go to Field Data Input, create a plot, then add the crop, planting date, soil test results and activities. '
          'Your crops also decide which verified advice, alerts and farming tips you see first.'),
  Faq('Pests & diseases', Icons.bug_report_rounded, 'How does photo diagnosis work?',
      'In Pests & Diseases, take or choose a clear photo of the affected leaf, stem or insect. The app suggests the '
          'most likely problem with a confidence level and management options. Always confirm with an extension '
          'officer before spraying.'),
  Faq('Market prices', Icons.price_check_rounded, 'Where do the market prices come from?',
      'Prices are reported by farmers using the app, grouped by crop, market and county, with the average, range and '
          '30-day trend. For official daily prices, open KAMIS (Ministry of Agriculture) from the Market Prices screen.'),
  Faq('Market prices', Icons.price_check_rounded, 'How do I report or change a price?',
      'Tap "Report a price", pick the crop, market, county, price and unit, and submit. Tap any of your own reports to '
          'edit or delete it. Other farmers can see your report but not your name.'),
  Faq('Notifications', Icons.notifications_rounded, 'Why am I not getting weather alerts?',
      'Check Settings → Notifications: push notifications and weather alerts must be on, and the phone must allow '
          'notifications for Kilimo Mkononi. Alerts come from your assigned weather station, so your farm needs a '
          'station.'),
  Faq('Notifications', Icons.notifications_rounded, 'How do reminders work?',
      'When you schedule an activity (for example spraying or top-dressing) the app reminds you on the day. Turn '
          'reminder types on or off in Settings → Notifications; past alerts stay in the Notifications inbox.'),
  Faq('Account & privacy', Icons.shield_rounded, 'How do I change my password or email?',
      'Settings → Account & security. You\'ll confirm your current password first. If you signed up with Google, your '
          'password is managed by Google — or use "Send password reset link" to add one.'),
  Faq('Account & privacy', Icons.shield_rounded, 'I forgot my password',
      'On the sign-in screen tap "Forgot password?" and enter your email — we send a reset link. Check your spam folder '
          'if it doesn\'t arrive within a few minutes.'),
  Faq('Account & privacy', Icons.shield_rounded, 'How do I delete my account?',
      'Settings → Account & security → Delete account and data. Your profile and records are deleted immediately; '
          'anything else linked to you is removed by our team within 30 days.'),
  Faq('Account & privacy', Icons.shield_rounded, 'Is my data safe?',
      'Your records are stored securely on Google Firebase and only you (and authorised Kilimo Mkononi staff) can see '
          'them. We follow the Kenya Data Protection Act, 2019 — see the Privacy policy for details.'),
  Faq('Display', Icons.text_fields_rounded, 'The text is too small / hard to read outdoors',
      'Settings → Appearance: make the text larger, choose a different font, or turn on Bold text.'),
];

const kEducationFaqs = <Faq>[
  Faq('Getting started', Icons.school_rounded, 'How do I join my school?',
      'Register with your school name and choose your role. A head teacher approves teachers, and teachers approve '
          'students — you\'ll get a notification when you\'re approved.'),
  Faq('Getting started', Icons.school_rounded, 'Why can\'t I see my class content yet?',
      'Your account may still be waiting for approval. Ask your teacher (or head teacher) to approve you.'),
  Faq('Learning', Icons.menu_book_rounded, 'How does the AI tutor work?',
      'The tutor answers questions about your topics and can create practice quizzes. Check important facts with your '
          'teacher.'),
  Faq('Account & privacy', Icons.shield_rounded, 'How do I change my password?',
      'Settings → Account & security → Change password, or use "Send password reset link".'),
  Faq('Account & privacy', Icons.shield_rounded, 'How do I delete my account?',
      'Settings → Account & security → Request account deletion. Because education accounts are linked to a school, '
          'our team handles it and confirms by email.'),
  Faq('Display', Icons.text_fields_rounded, 'Can I make the text bigger?', 'Yes — Settings → Appearance.'),
];

/// Each help topic's colour.
Color faqColor(String category) => switch (category) {
      'Getting started' => const Color(0xFF2E7D32),
      'Weather & stations' => const Color(0xFF1E88E5),
      'Field data' => const Color(0xFF00897B),
      'Pests & diseases' => const Color(0xFFE53935),
      'Market prices' => const Color(0xFF2E6A5E),
      'Notifications' => const Color(0xFF8E24AA),
      'Account & privacy' => const Color(0xFF3949AB),
      'Display' => const Color(0xFFEF8F00),
      'Learning' => const Color(0xFF6D4C41),
      _ => kSetGreen,
    };

class FAQScreen extends StatefulWidget {
  final bool isEducation;
  const FAQScreen({super.key, this.isEducation = false});

  @override
  State<FAQScreen> createState() => _FAQScreenState();
}

class _FAQScreenState extends State<FAQScreen> {
  final _search = TextEditingController();
  String? _category;
  String? _open; // question currently expanded

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = widget.isEducation ? kEducationFaqs : kFarmerFaqs;
    final categories = <String, (IconData, int)>{};
    for (final f in all) {
      categories[f.category] = (f.icon, (categories[f.category]?.$2 ?? 0) + 1);
    }
    final q = _search.text;
    final shown = all.where((f) => (_category == null || f.category == _category) && f.matches(q)).toList();

    return SettingsPage(
      title: 'Help centre',
      subtitle: 'Answers to common questions',
      children: [
        // Hero with search.
        Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [Color(0xFF0B3D1E), Color(0xFF1B5E20), Color(0xFF00897B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('How can we help?', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('${all.length} answers about using Kilimo Mkononi',
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 14),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search (e.g. alerts, password, offline)',
                prefixIcon: const Icon(Icons.search_rounded, color: kSetGreen),
                suffixIcon: q.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear', icon: const Icon(Icons.close_rounded), onPressed: () => setState(_search.clear)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        // Topics.
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth >= 560 ? 4 : 2;
          final w = (c.maxWidth - (cols - 1) * 10) / cols;
          return Wrap(spacing: 10, runSpacing: 10, children: [
            for (final e in categories.entries)
              SizedBox(
                width: w,
                child: _TopicTile(
                  label: e.key,
                  icon: e.value.$1,
                  count: e.value.$2,
                  color: faqColor(e.key),
                  selected: _category == e.key,
                  onTap: () => setState(() => _category = _category == e.key ? null : e.key),
                ),
              ),
          ]);
        }),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(
            child: Text(
              _category ?? (q.isEmpty ? 'All questions' : 'Search results'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: kSetInk),
            ),
          ),
          if (_category != null)
            TextButton.icon(
              onPressed: () => setState(() => _category = null),
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text('Show all'),
            ),
        ]),
        const SizedBox(height: 8),
        if (shown.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Column(children: [
              Icon(Icons.search_off_rounded, size: 40, color: kSetMuted),
              SizedBox(height: 8),
              Text('No answers match your search', style: TextStyle(fontWeight: FontWeight.w700)),
            ]),
          )
        else
          for (final f in shown)
            _FaqCard(
              faq: f,
              color: faqColor(f.category),
              open: _open == f.q,
              onTap: () => setState(() => _open = _open == f.q ? null : f.q),
            ),
        const SizedBox(height: 16),
        // Still need help?
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(colors: [Color(0xFFFFF4E0), Color(0xFFFFE6C2)]),
          ),
          child: Row(children: [
            const CircleAvatar(
              radius: 24,
              backgroundColor: Color(0xFFB26A00),
              child: Icon(Icons.support_agent_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Still need help?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: Color(0xFF7A4A00))),
                Text('Call, WhatsApp or message our team.', style: TextStyle(color: Color(0xFF7A4A00), fontSize: 12.5)),
              ]),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB26A00)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactUsScreen())),
              child: const Text('Contact'),
            ),
          ]),
        ),
      ],
    );
  }
}

class _TopicTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _TopicTile({
    required this.label,
    required this.icon,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? color : Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: selected ? 3 : 0.5,
        shadowColor: color.withValues(alpha: 0.4),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: selected ? Colors.white.withValues(alpha: 0.2) : color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: selected ? Colors.white : color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 12.5, color: selected ? Colors.white : kSetInk)),
                  Text('$count question${count == 1 ? '' : 's'}',
                      style: TextStyle(fontSize: 11, color: selected ? Colors.white70 : kSetMuted)),
                ]),
              ),
            ]),
          ),
        ),
      );
}

class _FaqCard extends StatelessWidget {
  final Faq faq;
  final Color color;
  final bool open;
  final VoidCallback onTap;
  const _FaqCard({required this.faq, required this.color, required this.open, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: open ? color.withValues(alpha: 0.5) : Colors.transparent, width: 1.4),
            boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 10, offset: Offset(0, 3))],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: open ? color : color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(Icons.question_mark_rounded, color: open ? Colors.white : color, size: 19),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(faq.q, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: kSetInk)),
                        Text(faq.category, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                    AnimatedRotation(
                      turns: open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.expand_more_rounded, color: open ? color : kSetMuted),
                    ),
                  ]),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: !open
                        ? const SizedBox(width: double.infinity)
                        : Container(
                            width: double.infinity,
                            margin: const EdgeInsets.fromLTRB(48, 10, 6, 2),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(faq.a, style: const TextStyle(height: 1.5, color: kSetInk)),
                          ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
}
