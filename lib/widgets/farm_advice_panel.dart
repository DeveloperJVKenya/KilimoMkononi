// lib/widgets/farm_advice_panel.dart
//
// Farm advice, categorised the same way on Home and in Notifications:
//   1. Farm alerts      — today's plan from the station + live condition alerts
//   2. Verified advice  — Field Agronomist advisories for the farmer's crops
//   3. AI advice        — the AI advisor (labelled "not verified")
// Each advice opens AdvisoryDetailScreen, where the farmer confirms pests /
// diseases and logs soil, pest or disease actions as interventions.
//
// SectionAlertsPanel / SectionAlertsStrip show the same alerts and advice
// split by farm section (Soil, Pests, Diseases) inside Field Data Input and
// Pest / Disease Management. State: settings/notifications/advice_providers.dart.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_actions.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_detail_screen.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_widgets.dart';
import 'package:kilimomkononi/enterprise/features/weather/agronomic_advisory.dart';
import 'package:kilimomkononi/enterprise/features/weather/agronomic_advisory_service.dart';
import 'package:kilimomkononi/screens/Field%20Data%20Input/satellite_data_screen.dart'
    show ConditionRisk;
import 'package:kilimomkononi/screens/Field%20Data%20Input/weather_station_screen.dart';
import 'package:kilimomkononi/services/farm_advice_service.dart';
import 'package:kilimomkononi/services/notification_service.dart';
import 'package:kilimomkononi/services/weather_day_plan.dart';
import 'package:kilimomkononi/settings/notifications/advice_providers.dart';
import 'package:kilimomkononi/settings/notifications/farm_alerts.dart';
import 'package:kilimomkononi/settings/notifications/notification_providers.dart';
import 'package:kilimomkononi/settings/notifications/notification_style.dart';

const _alertsColor = Color(0xFFEF6C00);
const _verifiedColor = AdvisoryColors.verified;
const _aiColor = Color(0xFF6A1B9A);

Color _riskColor(ConditionRisk r) => switch (r) {
      ConditionRisk.critical => const Color(0xFFC62828),
      ConditionRisk.high => const Color(0xFFEF6C00),
      ConditionRisk.moderate => const Color(0xFFF9A825),
      ConditionRisk.low => AdvisoryColors.midGreen,
    };

void openAdvisory(BuildContext context, {String? id, AgronomicAdvisory? advisory, String? alertTitle}) =>
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdvisoryDetailScreen(advisoryId: id, advisory: advisory, alertTitle: alertTitle),
      ),
    );

// ═════════════════════════════════════════════════════════════════════════════
//  Home / Notifications panel
// ═════════════════════════════════════════════════════════════════════════════

class FarmAdvicePanel extends ConsumerWidget {
  /// Home: a few items per category and a "see all" link.
  final bool compact;
  final VoidCallback? onSeeAll;

  const FarmAdvicePanel({super.key, this.compact = false, this.onSeeAll});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(farmAdviceProvider);
    return async.when(
      loading: () => const _LoadingCard('Checking your farm…'),
      error: (e, _) => _InfoCard(
        icon: Icons.wifi_off_rounded,
        color: KmColors.red,
        text: 'Could not load farm advice. Pull down to try again.',
        onTap: () => ref.invalidate(farmAdviceProvider),
      ),
      data: (a) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _StationLine(a, onRefresh: () => ref.invalidate(farmAdviceProvider)),
        const SizedBox(height: 10),
        _CategoryHeader('Farm alerts', Icons.warning_amber_rounded, _alertsColor,
            count: (a.alerts?.alerts.length ?? 0), subtitle: 'From your weather station, soil sensor and satellite'),
        _FarmAlertsBlock(a, compact: compact),
        const SizedBox(height: 14),
        _CategoryHeader('Verified advice', Icons.verified_rounded, _verifiedColor,
            count: a.verified.length, subtitle: 'Reviewed by a Field Agronomist for your crops'),
        _VerifiedBlock(a, compact: compact),
        const SizedBox(height: 14),
        const _CategoryHeader('AI advice', Icons.auto_awesome_rounded, _aiColor,
            subtitle: 'Generated from live station data · not verified'),
        const _AiBlock(),
        if (compact && onSeeAll != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onSeeAll,
              icon: const Icon(Icons.notifications_rounded, size: 18),
              label: const Text('All alerts & advice in Notifications'),
              style: TextButton.styleFrom(
                foregroundColor: AdvisoryColors.verified,
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
      ]),
    );
  }
}

class _StationLine extends StatelessWidget {
  final FarmAdvice a;
  final VoidCallback onRefresh;
  const _StationLine(this.a, {required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final r = a.reading;
    final (text, color) = !a.hasStation
        ? ('No weather station on your farm — general advice only', Colors.black54)
        : !r!.hasData
            ? ('Weather station offline (no readings in 2 h) — general advice only', KmColors.orange)
            : ('Weather station${a.stationName.isEmpty ? '' : ' ${a.stationName}'} · live · ${relativeTime(r.timestamp)}',
                AdvisoryColors.midGreen);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: a.hasStation
            ? () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => WeatherStationScreen(initialStationId: a.stationId)))
            : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 2, 6),
          child: Row(children: [
            Icon(Icons.sensors_rounded, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color))),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Check again',
              icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.black54),
              onPressed: onRefresh,
            ),
          ]),
        ),
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final int? count;
  final String? subtitle;
  const _CategoryHeader(this.title, this.icon, this.color, {this.count, this.subtitle});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Container(width: 4, height: subtitle == null ? 18 : 30, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(count == null || count == 0 ? title : '$title ($count)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
              if (subtitle != null)
                Text(subtitle!, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: Colors.black54)),
            ]),
          ),
        ]),
      );
}

class _LoadingCard extends StatelessWidget {
  final String text;
  const _LoadingCard(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdvisoryColors.border),
        ),
        child: Row(children: [
          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AdvisoryColors.midGreen)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.black54)),
          ),
        ]),
      );
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final VoidCallback? onTap;
  const _InfoCard({required this.icon, required this.color, required this.text, this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: color, height: 1.35)),
              ),
              if (onTap != null) Icon(Icons.chevron_right_rounded, size: 18, color: color),
            ]),
          ),
        ),
      );
}

// ── 1. Farm alerts ───────────────────────────────────────────────────────────

class _FarmAlertsBlock extends StatelessWidget {
  final FarmAdvice a;
  final bool compact;
  const _FarmAlertsBlock(this.a, {required this.compact});

  @override
  Widget build(BuildContext context) {
    final alerts = a.alerts?.alerts ?? const <FarmAlert>[];
    final shown = compact ? alerts.take(3).toList() : alerts;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (a.plan != null) _PlanCard(a.plan!),
      for (final f in shown) FarmAlertTile(f, readingAt: a.alerts?.readingTimeFor(f.source)),
      if (compact && alerts.length > shown.length)
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text('+${alerts.length - shown.length} more farm alerts in Notifications',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _alertsColor)),
        ),
      if (a.plan == null && alerts.isEmpty)
        const _InfoCard(
          icon: Icons.check_circle_rounded,
          color: AdvisoryColors.midGreen,
          text: 'No farm alerts right now.',
        ),
    ]);
  }
}

class _PlanCard extends StatelessWidget {
  final WeatherDayPlan plan;
  const _PlanCard(this.plan);

  @override
  Widget build(BuildContext context) {
    final (color, bg, icon) = switch (plan.mood) {
      DayMood.good => (AdvisoryColors.midGreen, AdvisoryColors.verifiedBg, Icons.check_circle_outline_rounded),
      DayMood.caution => (AdvisoryColors.amber, AdvisoryColors.lightAmber, Icons.warning_amber_rounded),
      DayMood.hold => (AdvisoryColors.red, const Color(0xFFFFEBEE), Icons.pause_circle_outline_rounded),
    };
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("TODAY'S PLAN", style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: color)),
            const SizedBox(height: 4),
            Text(plan.mainAdvice,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87, height: 1.35)),
            if (plan.doToday.isNotEmpty) ...[
              const SizedBox(height: 6),
              _bullets('Do', plan.doToday.take(3), AdvisoryColors.midGreen),
            ],
            if (plan.avoidToday.isNotEmpty) ...[
              const SizedBox(height: 4),
              _bullets('Avoid', plan.avoidToday.take(3), AdvisoryColors.red),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _bullets(String label, Iterable<String> items, Color c) => Text.rich(
        TextSpan(children: [
          TextSpan(text: '$label: ', style: TextStyle(fontWeight: FontWeight.w800, color: c)),
          TextSpan(text: items.join(' · ')),
        ]),
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: Colors.black87, height: 1.35),
      );
}

/// One live farm alert (risk colour, sections, source).
class FarmAlertTile extends StatelessWidget {
  final FarmAlert alert;
  final DateTime? readingAt;
  const FarmAlertTile(this.alert, {super.key, this.readingAt});

  @override
  Widget build(BuildContext context) {
    final c = _riskColor(alert.risk);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(width: 5, color: c),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(alert.icon, size: 16, color: c),
                  const SizedBox(width: 6),
                  Expanded(child: Text(alert.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800))),
                  KmTag(riskLabel(alert.risk), c),
                ]),
                const SizedBox(height: 4),
                Text(alert.body, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, height: 1.4)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  for (final s in alert.sections) SectionChip(s, dense: true),
                  KmTag(alert.source.label, KmColors.blue, icon: alert.source.icon),
                  if (readingAt != null && alert.source != FarmAlertSource.satellite)
                    Text('reading ${relativeTime(readingAt!)}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── 2. Verified advice ───────────────────────────────────────────────────────

class _VerifiedBlock extends StatelessWidget {
  final FarmAdvice a;
  final bool compact;
  const _VerifiedBlock(this.a, {required this.compact});

  @override
  Widget build(BuildContext context) {
    if (a.verified.isEmpty) {
      return const _InfoCard(
        icon: Icons.support_agent_rounded,
        color: Colors.black54,
        text: 'No verified advice for your crops and today\'s weather yet. '
            'When a Field Agronomist publishes some, it appears here and you get a notification.',
      );
    }
    final shown = compact ? a.verified.take(2) : a.verified;
    return Column(children: [
      for (final v in shown)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: VerifiedAdvisoryCard.fromAdvisory(v, onOpen: () => openAdvisory(context, advisory: v)),
        ),
      if (compact && a.verified.length > 2)
        Text('+${a.verified.length - 2} more verified advice in Notifications',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _verifiedColor)),
    ]);
  }
}

// ── 3. AI advice ─────────────────────────────────────────────────────────────

class _AiBlock extends ConsumerWidget {
  const _AiBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(aiAdviceProvider);
    return async.when(
      loading: () => const _LoadingCard("AI is thinking through today's conditions…"),
      error: (e, _) => const _InfoCard(
        icon: Icons.cloud_off_rounded,
        color: Colors.black54,
        text: 'AI advice is unavailable right now.',
      ),
      data: (ai) {
        if (ai == null) {
          return const _InfoCard(
            icon: Icons.sensors_off_rounded,
            color: Colors.black54,
            text: 'AI advice needs live readings from your weather station.',
          );
        }
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _aiColor.withValues(alpha: 0.3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.auto_awesome_rounded, size: 16, color: _aiColor),
                SizedBox(width: 6),
                Text('AI Farm Advisor', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
              ]),
              Pill(ai.fallback ? 'Offline advice' : 'AI-generated · not verified',
                  icon: ai.fallback ? Icons.cloud_off_rounded : Icons.info_outline_rounded,
                  flexible: true,
                  fg: AdvisoryColors.amber,
                  bg: AdvisoryColors.lightAmber),
            ]),
            const SizedBox(height: 10),
            AdviceBody(advice: ai.advice),
            if (!ai.advice.actions.isEmpty) ...[
              const SizedBox(height: 10),
              AdviceActionsSummary(ai.advice.actions),
            ],
            const SizedBox(height: 8),
            Text(
              ai.fallback
                  ? 'AI was unreachable, so this is the station\'s own plan.'
                  : 'Not reviewed by an agronomist. Where verified advice is shown, follow it first.',
              style: const TextStyle(fontSize: 11, color: Colors.black54, height: 1.35),
            ),
            if (!ai.advice.actions.isEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _aiColor,
                    side: const BorderSide(color: _aiColor),
                  ),
                  onPressed: () => openAdvisory(context, advisory: ai.asAdvisory),
                  icon: const Icon(Icons.playlist_add_check_rounded, size: 18),
                  label: const Text('Check my farm & log actions'),
                ),
              ),
            ],
          ]),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  Per-section alerts (Field Data Input, Pest / Disease Management)
// ═════════════════════════════════════════════════════════════════════════════

/// Opens what a feed item points to.
void openFeedItem(BuildContext context, WidgetRef ref, SectionFeedItem item) {
  final inbox = item.inbox;
  if (inbox != null && !inbox.read) ref.read(inboxControllerProvider).setRead(inbox, true);
  if (item.advisory != null) {
    openAdvisory(context, advisory: item.advisory);
  } else if (item.advisoryId != null) {
    openAdvisory(context, id: item.advisoryId,
        alertTitle: inbox?.kind == InboxKind.weather ? inbox?.title : null);
  } else if (inbox?.route != null) {
    NotificationService.routeHandler?.call(inbox!.route!, inbox.args);
  } else if (item.alert != null) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: FarmAlertTile(item.alert!),
      ),
    );
  }
}

class _FeedTile extends ConsumerWidget {
  final SectionFeedItem item;
  const _FeedTile(this.item);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (icon, color, kind) = switch (item.source) {
      FeedSource.verified => (Icons.verified_rounded, _verifiedColor, 'Verified advice'),
      FeedSource.farmAlert => (Icons.radar_rounded, _alertsColor, 'Farm alert'),
      FeedSource.notification => item.inbox!.kind == InboxKind.weather
          ? (Icons.thunderstorm_rounded, item.severity == 'critical' ? KmColors.red : _alertsColor, 'Weather alert')
          : (item.inbox!.kind.icon, item.inbox!.kind.color, item.inbox!.kind.label),
    };
    final unread = item.inbox != null && !item.inbox!.read;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => openFeedItem(context, ref, item),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text(kind, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
                  if (item.severity == 'critical') const KmTag('Critical', KmColors.red, filled: true),
                  if (item.severity == 'high') const KmTag('High', KmColors.orange, filled: true),
                  for (final s in item.sections) SectionChip(s, dense: true),
                ]),
                const SizedBox(height: 4),
                Text(item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.5, fontWeight: unread ? FontWeight.w800 : FontWeight.w700)),
                if (item.body.isNotEmpty)
                  Text(item.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
                if (item.at != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(fullStamp(item.at!), style: const TextStyle(fontSize: 10.5, color: Colors.black54)),
                  ),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.black38),
          ]),
        ),
      ),
    );
  }
}

/// Alerts and advice for [sections] (and [crops], if given).
class SectionAlertsPanel extends ConsumerWidget {
  final Set<AdviceSection> sections;
  final List<String> crops;
  final String title;
  final int max;

  const SectionAlertsPanel({
    super.key,
    required this.sections,
    this.crops = const [],
    required this.title,
    this.max = 4,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(sectionFeedProvider(sectionFeedKey(sections, crops)));
    final color = sections.length == 1 ? sections.first.color : AdvisoryColors.verified;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(sections.length == 1 ? sections.first.icon : Icons.notifications_active_rounded, size: 18, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            feed.value == null || feed.value!.isEmpty ? title : '$title (${feed.value!.length})',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Check again',
          icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.black54),
          onPressed: () => ref.invalidate(farmAdviceProvider),
        ),
      ]),
      const SizedBox(height: 4),
      feed.when(
        loading: () => const _LoadingCard('Loading alerts…'),
        error: (e, _) => const _InfoCard(icon: Icons.wifi_off_rounded, color: KmColors.red, text: 'Could not load alerts.'),
        data: (items) {
          if (items.isEmpty) {
            return _InfoCard(
              icon: Icons.check_circle_rounded,
              color: AdvisoryColors.midGreen,
              text: crops.isEmpty
                  ? 'No alerts or advice right now.'
                  : 'No alerts or advice for ${crops.join(', ')} right now.',
            );
          }
          final shown = items.take(max).toList();
          return Column(children: [
            for (final i in shown) Padding(padding: const EdgeInsets.only(bottom: 8), child: _FeedTile(i)),
            if (items.length > shown.length)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => showSectionAlertsSheet(context, sections: sections, crops: crops, title: title),
                  style: TextButton.styleFrom(foregroundColor: color),
                  child: Text('See all ${items.length}', style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
          ]);
        },
      ),
    ]);
  }
}

void showSectionAlertsSheet(
  BuildContext context, {
  required Set<AdviceSection> sections,
  List<String> crops = const [],
  required String title,
}) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: SectionAlertsPanel(sections: sections, crops: crops, title: title, max: 200),
        ),
      ),
    );

/// Compact "Alerts for this plot: Soil 1 · Pests 2 · Diseases 0" bar for the
/// Field Data Input plot forms; each chip opens that section's list.
class SectionAlertsStrip extends ConsumerStatefulWidget {
  final String plotId;
  const SectionAlertsStrip({super.key, required this.plotId});

  @override
  ConsumerState<SectionAlertsStrip> createState() => _SectionAlertsStripState();
}

class _SectionAlertsStripState extends ConsumerState<SectionAlertsStrip> {
  List<String>? _crops;

  @override
  void initState() {
    super.initState();
    _loadCrops();
  }

  Future<void> _loadCrops() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final c = await AgronomicAdvisoryService.farmerCrops(uid, plotId: widget.plotId);
      if (mounted) setState(() => _crops = c);
    } catch (_) {
      if (mounted) setState(() => _crops = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crops = _crops ?? const <String>[];
    final feed = ref.watch(sectionFeedProvider(sectionFeedKey(AdviceSection.values.toSet(), crops))).value ?? const [];
    int count(AdviceSection s) => feed.where((i) => i.sections.contains(s)).length;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdvisoryColors.border),
      ),
      child: Row(children: [
        const Icon(Icons.notifications_active_rounded, size: 18, color: AdvisoryColors.verified),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              crops.isEmpty ? 'Alerts & advice for this plot' : 'Alerts & advice · ${crops.join(', ')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 4, children: [
              for (final s in AdviceSection.values)
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => showSectionAlertsSheet(context, sections: {s}, crops: crops, title: '${s.label} alerts'),
                  child: SectionChip(s, count: count(s)),
                ),
            ]),
          ]),
        ),
      ]),
    );
  }
}
