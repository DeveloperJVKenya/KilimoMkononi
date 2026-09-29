// lib/settings/settings_screen.dart
//
// Settings (farmer and education): profile card, account, notifications,
// appearance (text size, font, bold text, motion, density — applied app-wide),
// offline uploads, help & legal, and log out (with confirmation).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kilimomkononi/screens/user_profile.dart';
import 'package:kilimomkononi/services/offline_queue_service.dart';
import 'package:kilimomkononi/settings/about_kilimo_mkononi_screen.dart';
import 'package:kilimomkononi/settings/account_settings_screen.dart';
import 'package:kilimomkononi/settings/appearance/appearance.dart';
import 'package:kilimomkononi/settings/appearance/appearance_screen.dart';
import 'package:kilimomkononi/settings/contact_us_screen.dart';
import 'package:kilimomkononi/settings/faq_screen.dart';
import 'package:kilimomkononi/settings/notifications_settings_screen.dart';
import 'package:kilimomkononi/settings/privacy_policy_screen.dart';
import 'package:kilimomkononi/settings/profile_edit_screen.dart';
import 'package:kilimomkononi/settings/settings_providers.dart';
import 'package:kilimomkononi/settings/terms_and_conditions_screen.dart';
import 'package:kilimomkononi/settings/widgets/settings_kit.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  /// True when opened from the Education platform (profile lives in
  /// EducationUsers; logout returns to the education sign-in).
  final bool isEducation;

  /// True when shown as a Home tab (no back button).
  final bool embedded;

  const SettingsScreen({super.key, this.isEducation = false, this.embedded = false});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int? _pending; // offline uploads waiting
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isEducation) _loadPending();
  }

  Future<void> _loadPending() async {
    try {
      final n = await OfflineQueueService.pendingCount();
      if (mounted) setState(() => _pending = n);
    } catch (_) {}
  }

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    try {
      final done = await OfflineQueueService.trySync();
      await _loadPending();
      if (!mounted) return;
      final left = _pending ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(left == 0
            ? (done > 0 ? 'Uploaded $done record${done == 1 ? '' : 's'} — all synced' : 'Everything is already synced')
            : 'Still offline — $left record${left == 1 ? '' : 's'} will upload when you\'re connected'),
      ));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _push(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  void _editProfile(ProfileSummary? p) {
    if (widget.isEducation) {
      _push(UserProfileScreen(profileImageBytes: p?.imageBytes, fullName: p?.fullName ?? '', role: p?.role));
    } else {
      _push(const ProfileEditScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(settingsProfileProvider(widget.isEducation)).value;
    final look = ref.watch(appearanceProvider);
    final lookN = ref.read(appearanceProvider.notifier);
    final edu = widget.isEducation;

    return SettingsPage(
      title: 'Settings',
      subtitle: 'Your account, display and help',
      showBack: !widget.embedded,
      onBack: () {
        final nav = Navigator.of(context);
        if (nav.canPop()) {
          nav.pop();
        } else {
          nav.pushReplacementNamed(edu ? '/edu_home' : '/home');
        }
      },
      children: [
        _ProfileCard(profile: profile, onEdit: () => _editProfile(profile)),
        const SizedBox(height: 18),
        SettingsSection(title: 'Account', children: [
          SettingsTile(
            icon: Icons.person_rounded,
            title: 'Edit profile',
            subtitle: 'Name, photo, phone and location',
            onTap: () => _editProfile(profile),
          ),
          SettingsTile(
            icon: Icons.shield_rounded,
            color: const Color(0xFF1565C0),
            title: 'Account & security',
            subtitle: 'Email, password and account deletion',
            onTap: () => _push(AccountSettingsScreen(isEducation: edu)),
          ),
          SettingsTile(
            icon: Icons.notifications_rounded,
            color: const Color(0xFF6A1B9A),
            title: 'Notifications',
            subtitle: 'Weather alerts, advice and reminders',
            onTap: () => _push(NotificationsSettingsScreen(isEducation: edu)),
          ),
        ]),
        SettingsSection(
          title: 'Appearance',
          footer: 'Changes apply straight away across the whole app and are saved on this device.',
          children: [
            SettingsTile(
              icon: Icons.format_size_rounded,
              color: const Color(0xFF00695C),
              title: 'Text size',
              value: look.textSizeLabel,
              onTap: () => _push(const AppearanceScreen()),
            ),
            SettingsTile(
              icon: Icons.font_download_rounded,
              color: const Color(0xFF00695C),
              title: 'Font',
              value: look.font.label,
              onTap: () => _push(const AppearanceScreen()),
            ),
            SettingsSwitchTile(
              icon: Icons.format_bold_rounded,
              color: const Color(0xFF00695C),
              title: 'Bold text',
              subtitle: 'Easier to read in bright sunlight',
              value: look.boldText,
              onChanged: (v) => lookN.update((s) => s.copyWith(boldText: v)),
            ),
            SettingsSwitchTile(
              icon: Icons.animation_rounded,
              color: const Color(0xFF00695C),
              title: 'Reduce motion',
              subtitle: 'Fewer animations and transitions',
              value: look.reduceMotion,
              onChanged: (v) => lookN.update((s) => s.copyWith(reduceMotion: v)),
            ),
          ],
        ),
        if (!edu)
          SettingsSection(title: 'Offline data', children: [
            SettingsTile(
              icon: _pending == 0 ? Icons.cloud_done_rounded : Icons.cloud_upload_rounded,
              color: _pending == null || _pending == 0 ? kSetGreen : const Color(0xFFB26A00),
              title: 'Uploads waiting',
              subtitle: _pending == null
                  ? 'Checking…'
                  : _pending == 0
                      ? 'Everything you recorded is saved online'
                      : '$_pending record${_pending == 1 ? '' : 's'} saved on this phone — tap to upload now',
              trailing: _syncing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : TextButton(onPressed: _syncNow, child: const Text('Sync now')),
              onTap: _syncing ? null : _syncNow,
            ),
          ]),
        SettingsSection(title: 'Help & support', children: [
          SettingsTile(
            icon: Icons.support_agent_rounded,
            color: const Color(0xFFB26A00),
            title: 'Contact us',
            subtitle: 'Call, WhatsApp, email or send a message',
            onTap: () => _push(const ContactUsScreen()),
          ),
          SettingsTile(
            icon: Icons.help_rounded,
            color: const Color(0xFFB26A00),
            title: 'Help centre (FAQ)',
            subtitle: 'Answers on weather, field data, prices and more',
            onTap: () => _push(FAQScreen(isEducation: edu)),
          ),
          SettingsTile(
            icon: Icons.bug_report_rounded,
            color: const Color(0xFFB26A00),
            title: 'Report a problem',
            subtitle: 'Tell us what went wrong',
            onTap: () => _push(const ContactUsScreen(initialTopic: SupportTopic.problem)),
          ),
        ]),
        SettingsSection(title: 'Legal & about', children: [
          SettingsTile(
            icon: Icons.description_rounded,
            color: kSetMuted,
            title: 'Terms and conditions',
            onTap: () => _push(TermsAndConditionsScreen(isEducation: edu)),
          ),
          SettingsTile(
            icon: Icons.privacy_tip_rounded,
            color: kSetMuted,
            title: 'Privacy policy',
            subtitle: 'How we handle your data (Kenya Data Protection Act)',
            onTap: () => _push(PrivacyPolicyScreen(isEducation: edu)),
          ),
          SettingsTile(
            icon: Icons.info_rounded,
            color: kSetMuted,
            title: 'About Kilimo Mkononi',
            value: 'v$kAppVersion',
            onTap: () => _push(const AboutKilimoMkononiScreen()),
          ),
        ]),
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: kSetRed,
              side: const BorderSide(color: kSetRed),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            onPressed: () => confirmAndLogOut(context, isEducation: edu),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Log out'),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text('Kilimo Mkononi v$kAppVersion ($kAppBuild) · ${KmContact.company}',
              textAlign: TextAlign.center, style: const TextStyle(color: kSetMuted, fontSize: 12)),
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final ProfileSummary? profile;
  final VoidCallback onEdit;
  const _ProfileCard({required this.profile, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final bytes = p?.imageBytes;
    return Material(
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [kSetGreenDark, kSetGreen, Color(0xFF2E7D32)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: Colors.white24,
              backgroundImage: bytes != null ? MemoryImage(bytes) : null,
              child: bytes == null
                  ? Text(p?.initials ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800))
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p == null ? 'Loading…' : (p.fullName.isEmpty ? 'Your name' : p.fullName),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                if (p != null && p.email.isNotEmpty)
                  Text(p.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  if (p != null) _Chip(Icons.badge_rounded, p.roleLabel),
                  if (p != null && (p.location.isNotEmpty || p.schoolName.isNotEmpty))
                    _Chip(Icons.place_rounded, p.schoolName.isNotEmpty ? p.schoolName : p.county),
                ]),
              ]),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.edit_rounded, size: 15, color: kSetGreen),
                SizedBox(width: 4),
                Text('Edit', style: TextStyle(color: kSetGreen, fontWeight: FontWeight.w800, fontSize: 12.5)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip(this.icon, this.label);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
          ),
        ]),
      );
}
