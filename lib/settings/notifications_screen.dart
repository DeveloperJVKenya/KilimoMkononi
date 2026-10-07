// lib/settings/notifications_screen.dart
//
// Notifications — four tabs, all live via Riverpod
// (lib/settings/notifications/notification_providers.dart, advice_providers.dart):
//   Inbox        every push the server sent (weather alerts, verified advice,
//                approvals), filterable — also by farm section (Soil / Pests /
//                Diseases) — with the exact time received. Advice opens the
//                action screen (check pests / diseases, log soil actions).
//   Farm advice  categorised like Home: Farm alerts (today's plan + condition
//                alerts with when each reading was taken), Verified advice,
//                AI advice
//   Reminders    activity reminders (Field, Pest, Disease…), with when they
//                are due and when they were set; muted sections are marked
//   Farm tasks   Farm Management tasks by due date, with their reminder time
//
// Every item carries its full date and time ("Mon 28 Sep 2026 · 09:41") plus
// a relative time, for traceability.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_detail_screen.dart';
import 'package:kilimomkononi/screens/Field%20Data%20Input/satellite_data_screen.dart' show ConditionRisk;
import 'package:kilimomkononi/services/notification_prefs.dart';
import 'package:kilimomkononi/services/notification_service.dart';
import 'package:kilimomkononi/services/reminder_service.dart';
import 'package:kilimomkononi/settings/notifications/advice_providers.dart';
import 'package:kilimomkononi/settings/notifications/farm_alerts.dart';
import 'package:kilimomkononi/settings/notifications/notification_providers.dart';
import 'package:kilimomkononi/settings/notifications/notification_style.dart';
import 'package:kilimomkononi/settings/notifications_settings_screen.dart';
import 'package:kilimomkononi/widgets/farm_advice_panel.dart';
import 'package:kilimomkononi/utils/friendly_error.dart';

enum NotificationsTab { inbox, advice, reminders, tasks }

class NotificationsScreen extends ConsumerStatefulWidget {
  final NotificationsTab initialTab;
  const NotificationsScreen({super.key, this.initialTab = NotificationsTab.inbox});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 4, vsync: this, initialIndex: widget.initialTab.index)
    ..addListener(() {
      if (!_tab.indexIsChanging && mounted) setState(() {});
    });

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _openSettings() => Navigator.push(
      context, MaterialPageRoute(builder: (_) => const NotificationsSettingsScreen()));

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(unreadCountProvider);
    final upcoming = ref.watch(upcomingReminderCountProvider);
    final advice = ref.watch(farmAdviceProvider).value;
    final alerts = (advice?.alerts?.alerts.length ?? 0) + (advice?.verified.length ?? 0);
    final tasks = ref.watch(farmTasksProvider).value;
    final overdue = tasks?.overdue.length ?? 0;

    return Scaffold(
      backgroundColor: KmColors.page,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: Navigator.canPop(context) ? const BackButton(color: Colors.white) : null,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: KmColors.appBarGradient)),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Notifications',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 19)),
          Text(
            '${unread == 0 ? 'All caught up' : '$unread unread'} · $upcoming reminder${upcoming == 1 ? '' : 's'} coming up',
            style: const TextStyle(color: Colors.white70, fontSize: 11.5),
          ),
        ]),
        actions: [
          if (_tab.index == 0 && unread > 0)
            IconButton(
              icon: const Icon(Icons.done_all_rounded),
              tooltip: 'Mark all as read',
              onPressed: () => ref.read(inboxControllerProvider).markAllRead(),
            ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Notification settings',
            onPressed: _openSettings,
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: KmColors.amber,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
          tabs: [
            _TabLabel(Icons.inbox_rounded, 'Inbox', unread, KmColors.blue),
            _TabLabel(Icons.tips_and_updates_rounded, 'Farm advice', alerts, KmColors.orange),
            _TabLabel(Icons.alarm_rounded, 'Reminders', upcoming, KmColors.purple),
            _TabLabel(Icons.task_alt_rounded, 'Farm tasks', overdue > 0 ? overdue : (tasks?.openCount ?? 0),
                overdue > 0 ? KmColors.red : KmColors.teal),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          const _InboxTab(),
          const _AdviceTab(),
          _RemindersTab(onOpenSettings: _openSettings),
          _TasksTab(onOpenSettings: _openSettings),
        ],
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  final int count;
  final Color badge;
  const _TabLabel(this.icon, this.text, this.count, this.badge);

  @override
  Widget build(BuildContext context) => Tab(
        height: 44,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 17),
          const SizedBox(width: 6),
          Text(text),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: badge, borderRadius: BorderRadius.circular(10)),
              child: Text(count > 99 ? '99+' : '$count',
                  style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
            ),
          ],
        ]),
      );
}

// ── Shared pieces ────────────────────────────────────────────────────────────

class _DayHeader extends StatelessWidget {
  final String text;
  final int count;
  final Color color;
  const _DayHeader(this.text, this.count, {this.color = KmColors.green});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
        child: Row(children: [
          Container(width: 4, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Flexible(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
                TextSpan(text: '  ($count)', style: const TextStyle(fontSize: 12, color: KmColors.muted)),
              ]),
            ),
          ),
        ]),
      );
}

/// White card with a coloured stripe on the left.
class _StripeCard extends StatelessWidget {
  final Color color;
  final Widget child;
  final VoidCallback? onTap;
  final bool faded;
  const _StripeCard({required this.color, required this.child, this.onTap, this.faded = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: faded ? const Color(0xFFF9FAF9) : Colors.white,
          elevation: faded ? 0 : 1,
          shadowColor: Colors.black12,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(width: 5, color: faded ? Colors.grey.shade300 : color),
                Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(12, 12, 8, 12), child: child)),
              ]),
            ),
          ),
        ),
      );
}

class _IconBubble extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _IconBubble(this.icon, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
        child: Icon(icon, size: 20, color: color),
      );
}

Widget _chips<T>({
  required List<T> values,
  required T selected,
  required String Function(T) label,
  required Color Function(T) color,
  required ValueChanged<T> onSelect,
}) =>
    SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        children: [
          for (final v in values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(label(v)),
                selected: v == selected,
                onSelected: (_) => onSelect(v),
                showCheckmark: false,
                labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: v == selected ? Colors.white : color(v)),
                selectedColor: color(v),
                backgroundColor: Colors.white,
                side: BorderSide(color: color(v).withValues(alpha: 0.35)),
              ),
            ),
        ],
      ),
    );

Widget _error(Object e) => KmEmptyState(
    icon: Icons.error_outline_rounded, title: 'Could not load', message: friendlyError(e), color: KmColors.red);

Future<bool> _confirm(BuildContext context, String title, String message, String action) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: KmColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

// ═════════════════════════════════════════════════════════════════════════════
//  Inbox
// ═════════════════════════════════════════════════════════════════════════════

class _InboxTab extends ConsumerWidget {
  const _InboxTab();

  Color _filterColor(InboxFilter f) => switch (f) {
        InboxFilter.all => KmColors.green,
        InboxFilter.unread => KmColors.blue,
        InboxFilter.weather => KmColors.orange,
        InboxFilter.advice => KmColors.greenMid,
        InboxFilter.soil => const Color(0xFF6D4C41),
        InboxFilter.pests => KmColors.orange,
        InboxFilter.diseases => KmColors.red,
        InboxFilter.approvals => KmColors.purple,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(inboxFilterProvider);
    final items = ref.watch(filteredInboxProvider);
    return Column(children: [
      _chips<InboxFilter>(
        values: InboxFilter.values,
        selected: filter,
        label: (f) => f.label,
        color: _filterColor,
        onSelect: ref.read(inboxFilterProvider.notifier).set,
      ),
      Expanded(
        child: items.when(
          loading: () => const Center(child: CircularProgressIndicator(color: KmColors.green)),
          error: (e, _) => _error(e),
          data: (list) {
            if (list.isEmpty) {
              return KmEmptyState(
                icon: Icons.inbox_rounded,
                color: KmColors.blue,
                title: filter == InboxFilter.all ? 'Your inbox is empty' : 'Nothing under "${filter.label}"',
                message: 'Weather alerts from your station, verified advice from Field Agronomists '
                    'and account approvals appear here, with the exact time they arrived.',
              );
            }
            final groups = groupByDay(list, (InboxItem i) => i.createdAt ?? DateTime.now());
            return RefreshIndicator(
              color: KmColors.green,
              onRefresh: () async => ref.invalidate(inboxProvider),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                children: [
                  for (final (day, dayItems) in groups) ...[
                    _DayHeader(day, dayItems.length),
                    for (final i in dayItems) _InboxCard(i),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    ]);
  }
}

class _InboxCard extends ConsumerWidget {
  final InboxItem item;
  const _InboxCard(this.item);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(inboxControllerProvider);
    final c = item.color;
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirm(context, 'Delete notification?',
          'It will be removed from your inbox on all your devices.', 'Delete'),
      onDismissed: (_) => ctrl.delete(item),
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: KmColors.red, borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      child: _StripeCard(
        color: c,
        onTap: () {
          if (!item.read) ctrl.setRead(item, true);
          // Advice (or an alert that carries advice) opens the action screen.
          if (item.advisoryId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdvisoryDetailScreen(
                  advisoryId: item.advisoryId,
                  alertTitle: item.kind == InboxKind.weather ? item.title : null,
                ),
              ),
            );
            return;
          }
          final route = item.route;
          if (route != null) NotificationService.routeHandler?.call(route, item.args);
        },
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _IconBubble(item.kind.icon, c),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 6, runSpacing: 4, children: [
                KmTag(item.kind.label, c),
                if (item.severity == 'critical') const KmTag('Critical', KmColors.red, filled: true),
                if (item.severity == 'high') const KmTag('High', KmColors.orange, filled: true),
                if (item.isTest) const KmTag('TEST', KmColors.purple),
                for (final s in item.sections) SectionChip(s, dense: true),
              ]),
              const SizedBox(height: 6),
              Text(item.title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: item.read ? FontWeight.w600 : FontWeight.w800,
                      color: Colors.black87)),
              if (item.body.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(item.body, style: const TextStyle(fontSize: 12.5, height: 1.4, color: Color(0xFF374151))),
              ],
              if (item.advisoryId != null) ...[
                const SizedBox(height: 6),
                const Text('Tap to check your farm and log actions',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: KmColors.green)),
              ],
              const SizedBox(height: 8),
              if (item.createdAt != null)
                KmTimestamp(item.createdAt!, prefix: 'Received', color: item.read ? KmColors.muted : c),
            ]),
          ),
          Column(children: [
            if (!item.read)
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 4, bottom: 4),
                decoration: const BoxDecoration(color: KmColors.blue, shape: BoxShape.circle),
              ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, size: 18, color: KmColors.muted),
              tooltip: 'More',
              onSelected: (v) async {
                if (v == 'read') ctrl.setRead(item, !item.read);
                if (v == 'delete' &&
                    await _confirm(context, 'Delete notification?',
                        'It will be removed from your inbox on all your devices.', 'Delete')) {
                  ctrl.delete(item);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'read', child: Text(item.read ? 'Mark as unread' : 'Mark as read')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ]),
        ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  Farm alerts
// ═════════════════════════════════════════════════════════════════════════════

Color riskColor(ConditionRisk r) => switch (r) {
      ConditionRisk.critical => KmColors.red,
      ConditionRisk.high => KmColors.orange,
      ConditionRisk.moderate => KmColors.amber,
      ConditionRisk.low => KmColors.green,
    };

Color _sourceColor(FarmAlertSource s) => switch (s) {
      FarmAlertSource.weatherStation => KmColors.blue,
      FarmAlertSource.iotSensor => KmColors.teal,
      FarmAlertSource.satellite => KmColors.purple,
    };

class _AdviceTab extends ConsumerWidget {
  const _AdviceTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(farmAdviceProvider).value?.alerts;
    Future<void> refresh() async {
      ref.invalidate(farmAdviceProvider);
      await ref.read(farmAdviceProvider.future);
    }

    return RefreshIndicator(
      color: KmColors.green,
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          if (r != null) _AlertsHeader(r, onRefresh: refresh),
          const FarmAdvicePanel(),
        ],
      ),
    );
  }
}

class _AlertsHeader extends StatelessWidget {
  final FarmAlertsResult r;
  final VoidCallback onRefresh;
  const _AlertsHeader(this.r, {required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    int count(ConditionRisk k) => r.alerts.where((a) => a.risk == k).length;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KmColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const _IconBubble(Icons.radar_rounded, KmColors.green),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Live farm check', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              Text('Checked ${fullStamp(r.checkedAt)}',
                  style: const TextStyle(fontSize: 11.5, color: KmColors.muted)),
            ]),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: KmColors.green),
            tooltip: 'Check again',
            onPressed: onRefresh,
          ),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          KmTag('${count(ConditionRisk.critical)} critical', KmColors.red),
          KmTag('${count(ConditionRisk.high)} high', KmColors.orange),
          KmTag('${count(ConditionRisk.moderate)} moderate', KmColors.amber),
        ]),
        const Divider(height: 20),
        for (final s in FarmAlertSource.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(s.icon, size: 14, color: _sourceColor(s)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: '${s.label}: ',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
                    TextSpan(
                      text: r.readingTimeFor(s) == null
                          ? 'not available'
                          : s == FarmAlertSource.satellite
                              ? 'model estimate for today'
                              : 'reading ${fullStamp(r.readingTimeFor(s)!)} · ${relativeTime(r.readingTimeFor(s)!)}',
                    ),
                  ]),
                  style: const TextStyle(fontSize: 11.5, color: KmColors.muted, height: 1.35),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  Reminders
// ═════════════════════════════════════════════════════════════════════════════

class _RemindersTab extends ConsumerWidget {
  final VoidCallback onOpenSettings;
  const _RemindersTab({required this.onOpenSettings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(remindersProvider);
    final section = ref.watch(reminderFilterProvider);
    final prefs = ref.watch(notificationPrefsProvider).value ?? NotificationPrefs.defaults;
    final sections = <ReminderSection?>[
      null,
      ReminderSection.field,
      ReminderSection.pest,
      ReminderSection.disease,
      ReminderSection.other,
    ];
    return Column(children: [
      _chips<ReminderSection?>(
        values: sections,
        selected: section,
        label: (s) => s == null ? 'All' : s.label,
        color: (s) => s == null ? KmColors.purple : sectionColor(s),
        onSelect: ref.read(reminderFilterProvider.notifier).set,
      ),
      Expanded(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator(color: KmColors.green)),
          error: (e, _) => _error(e),
          data: (all) {
            final list = section == null ? all : all.where((r) => r.section == section).toList();
            if (list.isEmpty) {
              return const KmEmptyState(
                icon: Icons.alarm_off_rounded,
                color: KmColors.purple,
                title: 'No reminders',
                message: 'Reminders you set in Field Data Input, Pest and Disease Management '
                    'appear here with the exact date and time they are due.',
              );
            }
            final upcoming = list.where((r) => !r.isPast).toList();
            final past = list.where((r) => r.isPast).toList().reversed.toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              children: [
                if (kIsWeb)
                  const _InfoBanner(
                    'Reminders ring in the Kilimo Mkononi phone app. In the browser they are listed here.',
                    KmColors.blue,
                  ),
                if (upcoming.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Nothing coming up.', style: TextStyle(color: KmColors.muted)),
                  ),
                for (final (day, items) in groupByDay(upcoming, (ReminderEntry r) => r.at)) ...[
                  _DayHeader(day, items.length, color: KmColors.purple),
                  for (final r in items)
                    _ReminderCard(r, muted: !r.section.enabledIn(prefs), onOpenSettings: onOpenSettings),
                ],
                if (past.isNotEmpty)
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                      title: Text('Past reminders (${past.length})',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: KmColors.muted)),
                      children: [for (final r in past) _ReminderCard(r, muted: false, onOpenSettings: onOpenSettings)],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ]);
  }
}

class _InfoBanner extends StatelessWidget {
  final String text;
  final Color color;
  final VoidCallback? onTap;
  const _InfoBanner(this.text, this.color, {this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Material(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, size: 16, color: color),
                const SizedBox(width: 8),
                Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: color, height: 1.35))),
                if (onTap != null) Icon(Icons.chevron_right_rounded, size: 18, color: color),
              ]),
            ),
          ),
        ),
      );
}

class _ReminderCard extends StatelessWidget {
  final ReminderEntry r;
  final bool muted;
  final VoidCallback onOpenSettings;
  const _ReminderCard(this.r, {required this.muted, required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    final c = sectionColor(r.section);
    final soon = !r.isPast && r.at.difference(DateTime.now()).inHours < 24;
    return _StripeCard(
      color: c,
      faded: r.isPast,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 58,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: (r.isPast ? Colors.grey : c).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(children: [
            Text(clockTime(r.at),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: r.isPast ? Colors.grey : c)),
            Text(DateFormat('d MMM').format(r.at), style: const TextStyle(fontSize: 10.5, color: KmColors.muted)),
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, runSpacing: 4, children: [
              KmTag(r.section.label, c, icon: sectionIcon(r.section)),
              if (r.plotId != null) KmTag('Plot ${r.plotId}', KmColors.teal),
              if (soon && !muted) const KmTag('Due soon', KmColors.orange, filled: true),
              if (muted && !r.isPast)
                GestureDetector(
                  onTap: onOpenSettings,
                  child: const KmTag('Muted in settings', KmColors.orange, icon: Icons.notifications_off_rounded),
                ),
            ]),
            const SizedBox(height: 6),
            Text(r.title,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: r.isPast ? KmColors.muted : Colors.black87)),
            if (r.body.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(r.body, style: const TextStyle(fontSize: 12.5, height: 1.4, color: Color(0xFF374151))),
            ],
            const SizedBox(height: 8),
            KmTimestamp(r.at, prefix: r.isPast ? 'Was due' : 'Due', color: r.isPast ? KmColors.muted : c),
            if (r.createdAt != null) ...[
              const SizedBox(height: 3),
              Text('Set on ${fullStamp(r.createdAt!)}', style: const TextStyle(fontSize: 11, color: KmColors.muted)),
            ],
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 18, color: KmColors.muted),
          tooltip: 'Remove reminder',
          onPressed: () async {
            if (await _confirm(context, 'Remove reminder?',
                    '"${r.title}" will be cancelled on this phone and removed.', 'Remove') &&
                context.mounted) {
              await ReminderService.remove(r.id, r.notifId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reminder removed')));
              }
            }
          },
        ),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  Farm tasks
// ═════════════════════════════════════════════════════════════════════════════

class _TasksTab extends ConsumerWidget {
  final VoidCallback onOpenSettings;
  const _TasksTab({required this.onOpenSettings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(farmTasksProvider);
    final prefs = ref.watch(notificationPrefsProvider).value ?? NotificationPrefs.defaults;
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator(color: KmColors.green)),
      error: (e, _) => _error(e),
      data: (t) {
        if (t.openCount == 0) {
          return RefreshIndicator(
            color: KmColors.green,
            onRefresh: () async => ref.invalidate(farmTasksProvider),
            child: ListView(children: const [
              SizedBox(height: 60),
              KmEmptyState(
                icon: Icons.task_alt_rounded,
                color: KmColors.teal,
                title: 'No open farm tasks',
                message: 'Tasks you add in Farm Management — planting, weeding, spraying, '
                    'harvesting — appear here by due date.',
              ),
            ]),
          );
        }
        final reminderAt = TimeOfDay(hour: prefs.taskReminderHour, minute: prefs.taskReminderMinute);
        return RefreshIndicator(
          color: KmColors.green,
          onRefresh: () async => ref.invalidate(farmTasksProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            children: [
              Row(children: [
                Expanded(child: _CountTile('Overdue', t.overdue.length, KmColors.red, Icons.warning_amber_rounded)),
                const SizedBox(width: 8),
                Expanded(child: _CountTile('Due today', t.today.length, KmColors.orange, Icons.today_rounded)),
                const SizedBox(width: 8),
                Expanded(child: _CountTile('Upcoming', t.upcoming.length, KmColors.teal, Icons.event_rounded)),
              ]),
              _InfoBanner(
                prefs.taskReminders
                    ? 'Reminders ring at ${reminderAt.format(context)} on each due date${kIsWeb ? ' (in the phone app)' : ''}. Tap to change.'
                    : 'Farm task reminders are off. Tap to turn them on.',
                prefs.taskReminders ? KmColors.teal : KmColors.orange,
                onTap: onOpenSettings,
              ),
              if (t.overdue.isNotEmpty) ...[
                _DayHeader('Overdue', t.overdue.length, color: KmColors.red),
                for (final x in t.overdue) _TaskCard(x, t, prefs),
              ],
              if (t.today.isNotEmpty) ...[
                _DayHeader('Due today', t.today.length, color: KmColors.orange),
                for (final x in t.today) _TaskCard(x, t, prefs),
              ],
              if (t.upcoming.isNotEmpty) ...[
                _DayHeader('Upcoming', t.upcoming.length, color: KmColors.teal),
                for (final x in t.upcoming) _TaskCard(x, t, prefs),
              ],
              const SizedBox(height: 8),
              Text('Loaded ${fullStamp(t.loadedAt)}',
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: KmColors.muted)),
            ],
          ),
        );
      },
    );
  }
}

class _CountTile extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  const _CountTile(this.label, this.count, this.color, this.icon);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(children: [
          Icon(icon, size: 18, color: color),
          Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: const TextStyle(fontSize: 11, color: KmColors.muted)),
        ]),
      );
}

class _TaskCard extends StatelessWidget {
  final FarmTaskEntry task;
  final FarmTasksSnapshot snap;
  final NotificationPrefs prefs;
  const _TaskCard(this.task, this.snap, this.prefs);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
    final days = dueDay.difference(today).inDays;
    final overdue = days < 0;
    final c = overdue ? KmColors.red : (days == 0 ? KmColors.orange : KmColors.teal);
    final priorityColor = switch (task.priority) {
      'high' => KmColors.red,
      'medium' => KmColors.amber,
      _ => KmColors.green,
    };
    final plot = snap.plotLabel(task.plotId);
    final remindAt = taskReminderTime(task.dueDate, prefs);
    return _StripeCard(
      color: c,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 52,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(color: c.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
          child: Column(children: [
            Text(DateFormat('d').format(task.dueDate),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c)),
            Text(DateFormat('MMM').format(task.dueDate).toUpperCase(),
                style: const TextStyle(fontSize: 10, color: KmColors.muted, fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, runSpacing: 4, children: [
              KmTag(task.categoryLabel, KmColors.blue),
              KmTag('${task.priority[0].toUpperCase()}${task.priority.substring(1)} priority', priorityColor),
              if (plot != null) KmTag(plot, KmColors.teal, icon: Icons.crop_square_rounded),
            ]),
            const SizedBox(height: 6),
            Text(task.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(task.description, style: const TextStyle(fontSize: 12.5, height: 1.4, color: Color(0xFF374151))),
            ],
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.event_rounded, size: 13, color: c),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Due ${DateFormat('EEE d MMM yyyy').format(task.dueDate)}  ·  '
                  '${overdue ? 'overdue by ${-days} day${days == -1 ? '' : 's'}' : days == 0 ? 'today' : days == 1 ? 'tomorrow' : 'in $days days'}',
                  style: TextStyle(fontSize: 11.5, color: c, fontWeight: FontWeight.w700),
                ),
              ),
            ]),
            const SizedBox(height: 3),
            Row(children: [
              Icon(prefs.taskReminders ? Icons.alarm_rounded : Icons.alarm_off_rounded,
                  size: 13, color: KmColors.muted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  !prefs.taskReminders
                      ? 'Reminders off'
                      : remindAt.isAfter(now)
                          ? 'Reminder ${fullStamp(remindAt)}'
                          : 'Reminder time passed (${fullStamp(remindAt)})',
                  style: const TextStyle(fontSize: 11, color: KmColors.muted),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}
