// lib/settings/notifications/advice_providers.dart
//
// Riverpod state for farm advice (Home + Notifications) and for the
// per-section alert lists in Field Data, Pests and Diseases:
//
//   farmAdviceProvider    today's plan, farm alerts and verified advisories
//   aiAdviceProvider      the AI advisor's answer for the same conditions
//   sectionFeedProvider   received notifications + advice in effect + farm
//                         alerts, filtered to sections and crops. Key:
//                         sectionFeedKey({AdviceSection.pests}, ['Maize'])

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_actions.dart';
import 'package:kilimomkononi/enterprise/features/weather/agronomic_advisory.dart';
import 'package:kilimomkononi/screens/Field%20Data%20Input/satellite_data_screen.dart'
    show ConditionRisk;
import 'package:kilimomkononi/services/farm_advice_service.dart';
import 'package:kilimomkononi/settings/notifications/farm_alerts.dart';
import 'package:kilimomkononi/settings/notifications/notification_providers.dart';

final farmAdviceProvider = FutureProvider.autoDispose<FarmAdvice>((ref) {
  // Rebuilt for whoever is signed in — another account on the same phone
  // never sees the previous one's station data.
  ref.watch(notifUidProvider);
  // Keep it while the app moves between Home and Notifications.
  final link = ref.keepAlive();
  final timer = Future.delayed(const Duration(minutes: 10), link.close);
  ref.onDispose(() => timer.ignore());
  return FarmAdviceService.load();
});

final aiAdviceProvider = FutureProvider.autoDispose<AiAdvice?>((ref) async {
  final a = await ref.watch(farmAdviceProvider.future);
  return FarmAdviceService.ai(a);
});

enum FeedSource { notification, verified, farmAlert }

/// One entry in a section's alert list.
class SectionFeedItem {
  final Set<AdviceSection> sections;
  final String title;
  final String body;
  final DateTime? at;
  final FeedSource source;

  /// 'critical' | 'high' | 'moderate' | null
  final String? severity;
  final InboxItem? inbox;
  final AgronomicAdvisory? advisory;
  final FarmAlert? alert;

  const SectionFeedItem({
    required this.sections,
    required this.title,
    required this.body,
    required this.source,
    this.at,
    this.severity,
    this.inbox,
    this.advisory,
    this.alert,
  });

  /// Advisory id to open the action screen with, if any.
  String? get advisoryId => advisory?.id ?? inbox?.advisoryId;
}

String sectionFeedKey(Set<AdviceSection> sections, List<String> crops) =>
    '${sections.map((s) => s.name).join(',')}|${crops.join(',')}';

bool _cropsMatch(List<String> target, List<String> mine) {
  if (mine.isEmpty || target.isEmpty) return true;
  final t = target.map((c) => c.trim().toLowerCase()).toSet();
  if (t.contains('all crops')) return true;
  return mine.any((c) => t.contains(c.trim().toLowerCase()));
}

String _riskName(ConditionRisk r) => switch (r) {
      ConditionRisk.critical => 'critical',
      ConditionRisk.high => 'high',
      ConditionRisk.moderate => 'moderate',
      ConditionRisk.low => 'low',
    };

final sectionFeedProvider =
    Provider.autoDispose.family<AsyncValue<List<SectionFeedItem>>, String>((ref, key) {
  final parts = key.split('|');
  final want = AdviceSection.parseList(parts.first);
  final crops = parts.length > 1 && parts[1].isNotEmpty ? parts[1].split(',') : const <String>[];
  final inbox = ref.watch(inboxProvider);
  final advice = ref.watch(farmAdviceProvider);
  if (inbox.isLoading && advice.isLoading) return const AsyncLoading();

  bool hits(Set<AdviceSection> s) => s.any(want.contains);
  final cutoff = DateTime.now().subtract(const Duration(days: 30));
  final out = <SectionFeedItem>[];
  final seenAdvisories = <String>{};

  // Advice in effect now, and live farm alerts.
  final a = advice.value;
  if (a != null) {
    for (final v in a.verified) {
      if (!hits(v.sections) || !_cropsMatch(v.crops, crops)) continue;
      seenAdvisories.add(v.id);
      out.add(SectionFeedItem(
        sections: v.sections,
        title: v.advice.main,
        body: v.crops.join(', '),
        source: FeedSource.verified,
        at: v.publishedAt,
        advisory: v,
      ));
    }
    for (final f in a.alerts?.alerts ?? const <FarmAlert>[]) {
      if (!hits(f.sections)) continue;
      out.add(SectionFeedItem(
        sections: f.sections,
        title: f.title,
        body: f.body,
        source: FeedSource.farmAlert,
        at: a.alerts!.checkedAt,
        severity: _riskName(f.risk),
        alert: f,
      ));
    }
  }

  // What the farmer actually received (last 30 days).
  for (final i in inbox.value ?? const <InboxItem>[]) {
    if (!hits(i.sections) || !_cropsMatch(i.crops, crops)) continue;
    if (i.createdAt != null && i.createdAt!.isBefore(cutoff)) continue;
    if (i.advisoryId != null && i.kind == InboxKind.advice && seenAdvisories.contains(i.advisoryId)) continue;
    out.add(SectionFeedItem(
      sections: i.sections,
      title: i.title,
      body: i.body,
      source: FeedSource.notification,
      at: i.createdAt,
      severity: i.severity,
      inbox: i,
    ));
  }
  return AsyncData(out);
});
