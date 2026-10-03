// lib/settings/notifications_settings_screen.dart
//
// Notification Settings. Every switch is saved to the user's account
// (notificationPrefs/{uid}, see lib/services/notification_prefs.dart) and
// takes effect for real:
//   • Alerts & advice — the Cloud Functions check these before pushing to
//     the user's phones; the Inbox still keeps a dated record.
//   • Activity reminders — reminders already scheduled on this device are
//     cancelled / restored straight away (ReminderService.applyPrefs).
//   • Farm task reminder time — when Farm Management task reminders ring on
//     the due date.
// The phone's own notification permission is shown too: if it's blocked,
// nothing can appear whatever the settings say.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kilimomkononi/services/notification_prefs.dart';
import 'package:kilimomkononi/services/notification_service.dart';
import 'package:kilimomkononi/settings/notifications/notification_providers.dart';
import 'package:kilimomkononi/settings/notifications/notification_style.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:kilimomkononi/utils/friendly_error.dart';

/// The phone's notification permission (null = unknown on this platform).
final notificationPermissionProvider = FutureProvider.autoDispose<PermissionStatus?>((ref) async {
  try {
    return await Permission.notification.status;
  } catch (_) {
    return null;
  }
});

class NotificationsSettingsScreen extends ConsumerWidget {
  final bool isEducation;
  const NotificationsSettingsScreen({super.key, this.isEducation = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationPrefsProvider);
    return Scaffold(
      backgroundColor: KmColors.page,
      appBar: AppBar(
        leading: Navigator.canPop(context) ? const BackButton(color: Colors.white) : null,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: KmColors.appBarGradient)),
        title: const Text('Notification Settings',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: KmColors.green)),
        error: (e, _) => KmEmptyState(
            icon: Icons.error_outline_rounded, title: 'Could not load settings', message: friendlyError(e), color: KmColors.red),
        data: (p) => _SettingsBody(prefs: p, isEducation: isEducation),
      ),
    );
  }
}

class _SettingsBody extends ConsumerWidget {
  final NotificationPrefs prefs;
  final bool isEducation;
  const _SettingsBody({required this.prefs, required this.isEducation});

  Future<void> _save(BuildContext context, WidgetRef ref, NotificationPrefs next, String what) async {
    try {
      await ref.read(notificationPrefsProvider.notifier).save(next);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text('$what — saved to your account'),
            backgroundColor: KmColors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(friendlyError(e, 'Could not save')),
          backgroundColor: KmColors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _pickTime(BuildContext context, WidgetRef ref) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: prefs.taskReminderHour, minute: prefs.taskReminderMinute),
      helpText: 'Farm task reminder time',
    );
    if (picked == null || !context.mounted) return;
    await _save(
      context,
      ref,
      prefs.copyWith(taskReminderHour: picked.hour, taskReminderMinute: picked.minute),
      'Task reminders at ${picked.format(context)}',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = prefs;
    String onOff(bool v) => v ? 'on' : 'off';
    final time = TimeOfDay(hour: p.taskReminderHour, minute: p.taskReminderMinute);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const _PermissionCard(),
        const SizedBox(height: 16),
        _Section(
          title: 'Alerts & advice',
          subtitle: 'Sent by Kilimo Mkononi to your phone. Turning one off stops the phone alert — '
              'your Inbox still keeps a dated record.',
          color: KmColors.blue,
          icon: Icons.campaign_rounded,
          children: [
            _SwitchRow(
              icon: Icons.notifications_active_rounded,
              color: KmColors.green,
              title: 'Phone notifications',
              subtitle: 'Master switch for everything sent to your phone',
              value: p.push,
              onChanged: (v) => _save(context, ref, p.copyWith(push: v), 'Phone notifications ${onOff(v)}'),
            ),
            if (!isEducation) ...[
              _SwitchRow(
                icon: Icons.thunderstorm_rounded,
                color: KmColors.orange,
                title: 'Weather alerts',
                subtitle: 'Heavy rain, strong wind, heat, frost and disease risk from your station',
                value: p.weatherAlerts,
                enabled: p.push,
                onChanged: (v) => _save(context, ref, p.copyWith(weatherAlerts: v), 'Weather alerts ${onOff(v)}'),
              ),
              _SwitchRow(
                icon: Icons.verified_rounded,
                color: KmColors.greenMid,
                title: 'Verified advice',
                subtitle: 'New advice from Field Agronomists for your crops and conditions',
                value: p.advisories,
                enabled: p.push,
                onChanged: (v) => _save(context, ref, p.copyWith(advisories: v), 'Verified advice ${onOff(v)}'),
              ),
            ],
            _SwitchRow(
              icon: Icons.how_to_reg_rounded,
              color: KmColors.blue,
              title: 'Account approvals',
              subtitle: isEducation
                  ? 'Requests waiting for your approval, and decisions on your account'
                  : 'Decisions on education accounts you requested',
              value: p.approvals,
              enabled: p.push,
              onChanged: (v) => _save(context, ref, p.copyWith(approvals: v), 'Approval notifications ${onOff(v)}'),
            ),
          ],
        ),
        if (!isEducation) ...[
          const SizedBox(height: 16),
          _Section(
            title: 'Activity reminders',
            subtitle: kIsWeb
                ? 'Reminders you set ring in the phone app. Changes here apply on your phone next time it opens.'
                : 'Reminders you set ring on this phone. Turning a section off silences its reminders '
                    'straight away; turning it back on restores them.',
            color: KmColors.purple,
            icon: Icons.alarm_rounded,
            children: [
              _SwitchRow(
                icon: Icons.grass_rounded,
                color: KmColors.green,
                title: 'Field Data Input',
                subtitle: 'Fertiliser, irrigation and field follow-ups',
                value: p.fieldReminders,
                onChanged: (v) => _save(context, ref, p.copyWith(fieldReminders: v), 'Field reminders ${onOff(v)}'),
              ),
              _SwitchRow(
                icon: Icons.bug_report_rounded,
                color: KmColors.orange,
                title: 'Pest Management',
                subtitle: 'Re-spray, scouting, weeding and follow-up checks',
                value: p.pestReminders,
                onChanged: (v) => _save(context, ref, p.copyWith(pestReminders: v), 'Pest reminders ${onOff(v)}'),
              ),
              _SwitchRow(
                icon: Icons.coronavirus_rounded,
                color: KmColors.red,
                title: 'Disease Management',
                subtitle: 'Treatment follow-ups and repeat applications',
                value: p.diseaseReminders,
                onChanged: (v) =>
                    _save(context, ref, p.copyWith(diseaseReminders: v), 'Disease reminders ${onOff(v)}'),
              ),
              _SwitchRow(
                icon: Icons.agriculture_rounded,
                color: KmColors.teal,
                title: 'Farm Management tasks',
                subtitle: 'A reminder on each task\'s due date',
                value: p.taskReminders,
                onChanged: (v) => _save(context, ref, p.copyWith(taskReminders: v), 'Farm task reminders ${onOff(v)}'),
              ),
              _TapRow(
                icon: Icons.schedule_rounded,
                color: KmColors.teal,
                title: 'Farm task reminder time',
                subtitle: 'Tasks have a due date only — this is when they ring',
                value: time.format(context),
                enabled: p.taskReminders,
                onTap: () => _pickTime(context, ref),
              ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        const Row(children: [
          Icon(Icons.cloud_done_rounded, size: 16, color: KmColors.green),
          SizedBox(width: 6),
          Expanded(
            child: Text('Saved to your account — applies on all your devices.',
                style: TextStyle(fontSize: 12, color: KmColors.muted)),
          ),
        ]),
      ],
    );
  }
}

class _PermissionCard extends ConsumerWidget {
  const _PermissionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(notificationPermissionProvider).value;
    final allowed = status == null || status.isGranted || status.isProvisional;
    final unknown = status == null;
    final color = allowed ? KmColors.green : KmColors.orange;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: allowed
              ? [KmColors.greenTint, const Color(0xFFF1F8E9)]
              : [KmColors.orangeTint, KmColors.amberTint],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(allowed ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
              color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              unknown
                  ? 'Notifications on this device'
                  : allowed
                      ? 'Notifications are allowed on this device'
                      : 'Notifications are blocked on this device',
              style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 14),
            ),
            const SizedBox(height: 3),
            Text(
              allowed
                  ? 'Alerts and reminders can appear here, following your settings below.'
                  : 'Nothing can appear until you allow notifications for Kilimo Mkononi.',
              style: const TextStyle(fontSize: 12, height: 1.35),
            ),
          ]),
        ),
        if (!allowed)
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: KmColors.orange),
            onPressed: () async {
              await NotificationService.requestPermission();
              if (!kIsWeb && (await Permission.notification.status).isPermanentlyDenied) {
                await openAppSettings();
              }
              ref.invalidate(notificationPermissionProvider);
            },
            child: const Text('Allow'),
          ),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final List<Widget> children;
  const _Section(
      {required this.title, required this.subtitle, required this.color, required this.icon, required this.children});

  @override
  // Material (not a coloured Container) so the rows' ink ripples show.
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        elevation: 1,
        shadowColor: const Color(0x33000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: KmColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.07),
              border: Border(left: BorderSide(color: color, width: 4)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(fontSize: 11.5, color: KmColors.muted, height: 1.35)),
                ]),
              ),
            ]),
          ),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 62),
            children[i],
          ],
        ]),
      );
}

class _RowIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool enabled;
  const _RowIcon(this.icon, this.color, this.enabled);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (enabled ? color : Colors.grey).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: enabled ? color : Colors.grey, size: 20),
      );
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        secondary: _RowIcon(icon, color, enabled),
        title: Text(title,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: enabled ? Colors.black87 : Colors.grey)),
        subtitle: Text(enabled ? subtitle : '$subtitle\n(Turn on phone notifications first)',
            style: const TextStyle(fontSize: 11.5, color: KmColors.muted, height: 1.3)),
        value: value && enabled,
        activeThumbColor: Colors.white,
        activeTrackColor: color,
        onChanged: enabled ? onChanged : null,
      );
}

class _TapRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String value;
  final bool enabled;
  final VoidCallback onTap;
  const _TapRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        enabled: enabled,
        leading: _RowIcon(icon, color, enabled),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11.5, color: KmColors.muted)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: (enabled ? color : Colors.grey).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(value,
              style: TextStyle(fontWeight: FontWeight.w800, color: enabled ? color : Colors.grey, fontSize: 13)),
        ),
        onTap: enabled ? onTap : null,
      );
}
