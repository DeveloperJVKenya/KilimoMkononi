// lib/settings/widgets/settings_kit.dart
//
// Shared look for Settings and its pages: a green app bar with a white back
// button, content capped at a readable width, grouped rounded cards of rows
// (icon in a tinted square, title, value/subtitle, chevron), and the
// log-out confirmation used by the menu and Settings.

import 'package:flutter/material.dart';
import 'package:kilimomkononi/services/session_service.dart';

const kSetGreen = Color(0xFF1B5E20);
const kSetGreenDark = Color(0xFF0B3D1E);
const kSetPage = Color(0xFFF4F6F3);
const kSetInk = Color(0xFF1F2937);
const kSetMuted = Color(0xFF6B7280);
const kSetBorder = Color(0xFFE3E8E1);
const kSetRed = Color(0xFFB3261E);

/// App version shown in Settings / About — keep in step with pubspec.yaml
/// (test/settings_test.dart checks).
const kAppVersion = '1.1.3';
const kAppBuild = 12;

/// Real contact details (Contact us, About, legal pages).
class KmContact {
  static const email = 'support@jvalmacis.co.ke';
  static const phone = '+254 795 802 020';
  static const phoneDial = '+254795802020';
  static const whatsapp = '254795802020';
  static const website = 'jvalmacis.com';
  static const websiteUrl = 'https://jvalmacis.com';
  static const address = 'Kin\'gara Heights, James Gichuru Rd, Nairobi, Kenya';
  static const hours = 'Monday – Friday, 8:00 am – 5:00 pm (EAT)';
  static const company = 'JV ALMA CIS Kenya';
}

class SettingsPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  /// False when shown as a tab (no back button).
  final bool showBack;

  /// False when the page is a tab under the Home app bar (one app bar
  /// across the app).
  final bool showAppBar;
  final VoidCallback? onBack;
  final double maxWidth;

  const SettingsPage({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.actions,
    this.floatingActionButton,
    this.showBack = true,
    this.showAppBar = true,
    this.onBack,
    this.maxWidth = 720,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kSetPage,
    floatingActionButton: floatingActionButton,
    appBar: !showAppBar
        ? null
        : AppBar(
            automaticallyImplyLeading: false,
            foregroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.white),
            leading: showBack
                ? IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: onBack ?? () => Navigator.maybePop(context),
                  )
                : null,
            flexibleSpace: Container(
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [kSetGreenDark, kSetGreen])),
            ),
            title: subtitle == null
                ? Text(title, style: const TextStyle(fontWeight: FontWeight.w800))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                      Text(subtitle!, style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
                    ],
                  ),
            actions: actions,
          ),
    body: SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: children),
        ),
      ),
    ),
  );
}

/// A titled group of rows on a rounded white card.
class SettingsSection extends StatelessWidget {
  final String? title;
  final String? footer;
  final List<Widget> children;

  /// Accent for the heading (the section's theme colour).
  final Color color;
  const SettingsSection({super.key, this.title, this.footer, required this.children, this.color = kSetGreen});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(const Divider(height: 1, indent: 64, color: kSetBorder));
      rows.add(children[i]);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Row(children: [
                Container(width: 4, height: 15, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                Text(
                  title!.toUpperCase(),
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                ),
              ]),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 14, offset: Offset(0, 4))],
            ),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: Column(children: rows),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
              child: Text(footer!, style: const TextStyle(color: kSetMuted, fontSize: 12, height: 1.4)),
            ),
        ],
      ),
    );
  }
}

/// Icon in a tinted rounded square.
class SettingsIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  const SettingsIcon(this.icon, {super.key, this.color = kSetGreen});

  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
    child: Icon(icon, color: color, size: 21),
  );
}

class SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.color = kSetGreen,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = destructive ? kSetRed : color;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            SettingsIcon(icon, color: c),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      color: destructive ? kSetRed : kSetInk,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: const TextStyle(color: kSetMuted, fontSize: 12.5, height: 1.3)),
                  ],
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: Text(
                  value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: const TextStyle(color: kSetMuted, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
            if (trailing != null) ...[
              const SizedBox(width: 6),
              trailing!,
            ] else if (onTap != null)
              const Icon(Icons.chevron_right_rounded, color: kSetMuted),
          ],
        ),
      ),
    );
  }
}

class SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const SettingsSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.color = kSetGreen,
  });

  @override
  Widget build(BuildContext context) => SettingsTile(
    icon: icon,
    color: color,
    title: title,
    subtitle: subtitle,
    onTap: () => onChanged(!value),
    trailing: Switch(value: value, onChanged: onChanged, activeTrackColor: kSetGreen),
  );
}

/// Asks before signing out; true when the user confirmed.
Future<bool> confirmLogout(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.logout_rounded, color: kSetRed, size: 32),
        title: const Text('Log out of Kilimo Mkononi?'),
        content: const Text(
          'You\'ll need your email and password (or Google) to sign in again on this device.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay signed in')),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: kSetRed),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Log out'),
          ),
        ],
      ),
    ) ==
    true;

/// Confirm → sign out (caches, Firebase, Google) → the right sign-in screen.
/// [beforeSignOut] lets a screen stop its listeners first.
Future<void> confirmAndLogOut(BuildContext context, {bool isEducation = false, VoidCallback? beforeSignOut}) async {
  if (!await confirmLogout(context) || !context.mounted) return;
  final navigator = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)),
  );
  beforeSignOut?.call();
  try {
    await SessionService.signOut();
  } finally {
    navigator.pushNamedAndRemoveUntil(isEducation ? '/edu_login' : '/login', (_) => false);
  }
}

/// A button sized to its label (never stretched edge to edge), centred.
class CompactButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final bool outlined;
  final bool busy;
  const CompactButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color = kSetGreen,
    this.outlined = false,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    const pad = EdgeInsets.symmetric(horizontal: 22, vertical: 14);
    final iconW = busy
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: outlined ? color : Colors.white),
          )
        : Icon(icon, size: 19);
    return outlined
        ? OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color.withValues(alpha: 0.6)),
              backgroundColor: Colors.white,
              shape: shape,
              padding: pad,
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
            onPressed: busy ? null : onPressed,
            icon: iconW,
            label: Text(label),
          )
        : FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: color,
              shape: shape,
              padding: pad,
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
            onPressed: busy ? null : onPressed,
            icon: iconW,
            label: Text(label),
          );
  }
}

/// Asks before an important change (password, email, reset link …);
/// true when confirmed.
Future<bool> confirmAction(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String message,
  required String confirmLabel,
  Color color = kSetGreen,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: CircleAvatar(
          radius: 26,
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(message, textAlign: TextAlign.center, style: const TextStyle(height: 1.4)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: color),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ) ==
    true;
