// lib/enterprise/features/agronomist/insights_engine.dart
//
// Turns every farmer's records (InsightsData) into what the Agronomist panel
// shows, for a period and optional county / crop:
//
//   • headline counts, each against the period before
//   • top pests and diseases, with a trend over the period
//   • emerging problems — NEW (none in the period before), RISING (at least
//     doubled), SPREADING (reported in more counties than before)
//   • unidentified problems, and clusters of them (the same crop in the same
//     county more than once — a possible unknown pest or disease)
//   • soil nutrients — how many plots of each crop test Low / Moderate / High
//   • farmers needing attention, with the reasons
//
// Pure functions — test/agronomist_insights_test.dart.

import 'package:kilimomkononi/enterprise/features/agronomist/farmer_records.dart';
import 'package:kilimomkononi/services/nutrient_levels.dart';

enum TrendTag {
  newIssue('New'),
  rising('Rising'),
  spreading('Spreading');

  final String label;
  const TrendTag(this.label);
}

class IssueTrend {
  final String type;
  final String name;
  final int current;
  final int previous;
  final int farmers;
  final Set<String> counties;
  final Set<String> previousCounties;
  final Map<String, int> crops;

  /// Reports per slice of the period, oldest first.
  final List<int> buckets;
  final DateTime? lastAt;

  /// Sharing farmers who reported it this period (for "Advise them").
  final Set<String> farmerUids;
  final Set<TrendTag> tags;

  const IssueTrend({
    required this.type,
    required this.name,
    required this.current,
    required this.previous,
    required this.farmers,
    required this.counties,
    required this.previousCounties,
    required this.crops,
    required this.buckets,
    required this.farmerUids,
    required this.tags,
    this.lastAt,
  });

  bool get isEmerging => tags.isNotEmpty;
  bool get isPest => type == 'pest';

  /// +n / −n against the period before.
  int get change => current - previous;

  List<String> get topCrops =>
      (crops.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).map((e) => e.key).toList();
}

/// Unidentified problems on one crop in one county (≥ 2 = worth a look).
class UnknownCluster {
  final String type;
  final String crop;
  final String county;
  final List<IssueRow> rows;
  const UnknownCluster(this.type, this.crop, this.county, this.rows);

  int get farmers => rows.map((r) => r.farmerUid ?? 'anon${r.at.millisecondsSinceEpoch}').toSet().length;
  Set<String> get farmerUids => {for (final r in rows) if (r.farmerUid != null) r.farmerUid!};
}

class NutrientStat {
  final String crop;
  final String nutrient;
  final int low;
  final int moderate;
  final int high;
  final Set<String> lowFarmerUids;

  const NutrientStat(this.crop, this.nutrient, this.low, this.moderate, this.high, this.lowFarmerUids);

  int get total => low + moderate + high;
  double get lowShare => total == 0 ? 0 : low / total;
}

class AttentionFarmer {
  final FarmerRow farmer;
  final int score;
  final List<String> reasons;
  final DateTime? lastAt;
  const AttentionFarmer(this.farmer, this.score, this.reasons, this.lastAt);
}

/// Per-farmer summary for the Farmers tab.
class FarmerSummary {
  final FarmerRow farmer;
  final Set<String> crops;
  final int pests;
  final int diseases;
  final int unidentified;
  final List<String> lowNutrients;
  final DateTime? lastAt;
  final int attentionScore;

  const FarmerSummary({
    required this.farmer,
    this.crops = const {},
    this.pests = 0,
    this.diseases = 0,
    this.unidentified = 0,
    this.lowNutrients = const [],
    this.lastAt,
    this.attentionScore = 0,
  });

  int get reports => pests + diseases;
}

class Headline {
  final int current;
  final int previous;
  const Headline(this.current, this.previous);
  int get change => current - previous;
}

class Insights {
  final int days;
  final Headline activeFarmers;
  final Headline pestReports;
  final Headline diseaseReports;
  final Headline unidentified;
  final int plotsTested;
  final int lowNutrientPlots;
  final List<IssueTrend> pests;
  final List<IssueTrend> diseases;
  final List<IssueTrend> emerging;
  final List<UnknownCluster> unknownClusters;
  final List<IssueRow> unidentifiedRows;
  final Map<String, int> byCounty;
  final List<NutrientStat> nutrients;
  final List<AttentionFarmer> attention;

  /// Filter options found in the data.
  final List<String> counties;
  final List<String> crops;

  const Insights({
    required this.days,
    required this.activeFarmers,
    required this.pestReports,
    required this.diseaseReports,
    required this.unidentified,
    required this.plotsTested,
    required this.lowNutrientPlots,
    required this.pests,
    required this.diseases,
    required this.emerging,
    required this.unknownClusters,
    required this.unidentifiedRows,
    required this.byCounty,
    required this.nutrients,
    required this.attention,
    required this.counties,
    required this.crops,
  });

  bool get isEmpty => pestReports.current + diseaseReports.current == 0 && plotsTested == 0;
}

int bucketCount(int days) => days <= 7 ? 7 : (days <= 30 ? 6 : 13);

String _norm(String s) => s.trim().toLowerCase();

bool _cropIs(String recorded, String wanted) {
  if (wanted.isEmpty) return true;
  final parts = cropNameParts(recorded);
  return parts.contains(_norm(wanted)) || cropNameParts(wanted).any(parts.contains);
}

/// Everything the Insights tab shows. [now] defaults to the data's time.
Insights computeInsights(
  InsightsData data, {
  String? county,
  String? crop,
  DateTime? now,
}) {
  final end = now ?? data.generatedAt;
  final period = Duration(days: data.days);
  final start = end.subtract(period);
  final prevStart = start.subtract(period);
  final c = (county ?? '').trim();
  final cr = (crop ?? '').trim();

  bool place(String rowCounty) => c.isEmpty || _norm(rowCounty) == _norm(c);
  final rows = data.issues.where((r) => place(r.county) && _cropIs(r.crop, cr)).toList();
  final cur = rows.where((r) => !r.at.isBefore(start) && !r.at.isAfter(end)).toList();
  final prev = rows.where((r) => !r.at.isBefore(prevStart) && r.at.isBefore(start)).toList();

  final plots = data.plots
      .where((p) => place(p.county) && (cr.isEmpty || p.cropNames.any((x) => _cropIs(x, cr))))
      .toList();

  // ── Trends per named pest / disease ─────────────────────────────────────
  final n = bucketCount(data.days);
  final slice = period.inMilliseconds / n;
  String key(IssueRow r) => '${r.type}|${_norm(r.name)}';
  Iterable<IssueRow> named(List<IssueRow> l) => l.where((r) => !r.unidentified && r.name.isNotEmpty);
  final prevBy = <String, List<IssueRow>>{};
  for (final r in named(prev)) {
    (prevBy[key(r)] ??= []).add(r);
  }
  final curBy = <String, List<IssueRow>>{};
  for (final r in named(cur)) {
    (curBy[key(r)] ??= []).add(r);
  }

  final trends = <IssueTrend>[];
  for (final e in curBy.entries) {
    final list = e.value;
    final before = prevBy[e.key] ?? const <IssueRow>[];
    final buckets = List.filled(n, 0);
    for (final r in list) {
      final i = ((r.at.difference(start).inMilliseconds) / slice).floor().clamp(0, n - 1);
      buckets[i]++;
    }
    final counties = {for (final r in list) if (r.county.isNotEmpty) r.county};
    final prevCounties = {for (final r in before) if (r.county.isNotEmpty) r.county};
    final crops = <String, int>{};
    for (final r in list) {
      if (r.crop.isNotEmpty) crops[r.crop] = (crops[r.crop] ?? 0) + 1;
    }
    final farmerKeys = {for (final r in list) r.farmerUid ?? 'anon:${r.county}:${r.at.millisecondsSinceEpoch}'};
    final tags = <TrendTag>{
      if (before.isEmpty && list.length >= 2) TrendTag.newIssue,
      if (before.isNotEmpty && list.length >= before.length * 2 && list.length - before.length >= 2) TrendTag.rising,
      if (counties.length > prevCounties.length && counties.length >= 2 && list.length >= 3) TrendTag.spreading,
    };
    trends.add(IssueTrend(
      type: list.first.type,
      name: list.first.name,
      current: list.length,
      previous: before.length,
      farmers: farmerKeys.length,
      counties: counties,
      previousCounties: prevCounties,
      crops: crops,
      buckets: buckets,
      farmerUids: {for (final r in list) if (r.farmerUid != null) r.farmerUid!},
      tags: tags,
      lastAt: list.map((r) => r.at).reduce((a, b) => a.isAfter(b) ? a : b),
    ));
  }
  int byCount(IssueTrend a, IssueTrend b) {
    final x = b.current.compareTo(a.current);
    return x != 0 ? x : a.name.compareTo(b.name);
  }

  final pests = trends.where((t) => t.isPest).toList()..sort(byCount);
  final diseases = trends.where((t) => !t.isPest).toList()..sort(byCount);
  final emerging = trends.where((t) => t.isEmerging).toList()
    ..sort((a, b) {
      final x = b.tags.length.compareTo(a.tags.length);
      return x != 0 ? x : byCount(a, b);
    });

  // ── Unidentified problems ───────────────────────────────────────────────
  final unknown = cur.where((r) => r.unidentified).toList()..sort((a, b) => b.at.compareTo(a.at));
  final clusterBy = <String, List<IssueRow>>{};
  for (final r in unknown) {
    (clusterBy['${r.type}|${_norm(r.crop)}|${_norm(r.county)}'] ??= []).add(r);
  }
  final clusters = [
    for (final l in clusterBy.values)
      if (l.length >= 2) UnknownCluster(l.first.type, l.first.crop, l.first.county, l),
  ]..sort((a, b) => b.rows.length.compareTo(a.rows.length));

  // ── Where ───────────────────────────────────────────────────────────────
  final byCounty = <String, int>{};
  for (final r in cur) {
    final k = r.county.isEmpty ? 'Not set' : r.county;
    byCounty[k] = (byCounty[k] ?? 0) + 1;
  }

  // ── Soil nutrients by crop ──────────────────────────────────────────────
  final stat = <String, List<int>>{};
  final lowUids = <String, Set<String>>{};
  var lowPlots = 0;
  var tested = 0;
  for (final p in plots) {
    if (p.bands.isEmpty) continue;
    tested++;
    if (p.lowNutrients.isNotEmpty) lowPlots++;
    for (final cropName in p.cropNames.isEmpty ? ['No crop recorded'] : p.cropNames) {
      if (cr.isNotEmpty && !_cropIs(cropName, cr)) continue;
      for (final e in p.bands.entries) {
        final k = '$cropName|${e.key}';
        final s = stat[k] ??= [0, 0, 0];
        s[e.value.index]++;
        if (e.value == NutrientBand.low && p.farmerUid != null) (lowUids[k] ??= {}).add(p.farmerUid!);
      }
    }
  }
  const order = ['N', 'P', 'K'];
  final nutrients = [
    for (final e in stat.entries)
      NutrientStat(e.key.split('|')[0], e.key.split('|')[1], e.value[0], e.value[1], e.value[2],
          lowUids[e.key] ?? const {}),
  ]..sort((a, b) {
      final x = b.lowShare.compareTo(a.lowShare);
      if (x != 0) return x;
      final y = a.crop.compareTo(b.crop);
      return y != 0 ? y : order.indexOf(a.nutrient).compareTo(order.indexOf(b.nutrient));
    });

  // ── Farmers needing attention ───────────────────────────────────────────
  final summaries = summarizeFarmers(data, county: c, crop: cr, now: end);
  final attention = [
    for (final s in summaries)
      if (s.attentionScore > 0) AttentionFarmer(s.farmer, s.attentionScore, attentionReasons(s, data, end), s.lastAt),
  ]..sort((a, b) => b.score.compareTo(a.score));

  // ── Headline counts ─────────────────────────────────────────────────────
  Set<String> active(List<IssueRow> l, DateTime from, DateTime to) => {
        for (final r in l) if (r.farmerUid != null) r.farmerUid!,
        for (final p in plots)
          if (p.farmerUid != null && p.at != null && !p.at!.isBefore(from) && p.at!.isBefore(to)) p.farmerUid!,
      };

  final counties = {
    for (final r in data.issues) if (r.county.isNotEmpty) r.county,
    for (final p in data.plots) if (p.county.isNotEmpty) p.county,
    for (final f in data.farmers) if (f.county.isNotEmpty) f.county,
  }.toList()
    ..sort();
  final crops = {
    for (final r in data.issues) if (r.crop.isNotEmpty) r.crop,
    for (final p in data.plots) ...p.cropNames,
  }.toList()
    ..sort();

  return Insights(
    days: data.days,
    activeFarmers: Headline(active(cur, start, end.add(const Duration(seconds: 1))).length,
        active(prev, prevStart, start).length),
    pestReports: Headline(cur.where((r) => r.isPest).length, prev.where((r) => r.isPest).length),
    diseaseReports: Headline(cur.where((r) => r.isDisease).length, prev.where((r) => r.isDisease).length),
    unidentified: Headline(unknown.length, prev.where((r) => r.unidentified).length),
    plotsTested: tested,
    lowNutrientPlots: lowPlots,
    pests: pests,
    diseases: diseases,
    emerging: emerging,
    unknownClusters: clusters,
    unidentifiedRows: unknown,
    byCounty: byCounty,
    nutrients: nutrients,
    attention: attention.take(20).toList(),
    counties: counties,
    crops: crops,
  );
}

/// One row per sharing farmer: crops, this period's reports, latest soil
/// problems, last activity and an attention score.
List<FarmerSummary> summarizeFarmers(
  InsightsData data, {
  String? county,
  String? crop,
  DateTime? now,
}) {
  final end = now ?? data.generatedAt;
  final start = end.subtract(Duration(days: data.days));
  final c = (county ?? '').trim();
  final cr = (crop ?? '').trim();
  final issuesBy = <String, List<IssueRow>>{};
  for (final r in data.issues) {
    if (r.farmerUid != null) (issuesBy[r.farmerUid!] ??= []).add(r);
  }
  final plotsBy = <String, List<PlotRow>>{};
  for (final p in data.plots) {
    if (p.farmerUid != null) (plotsBy[p.farmerUid!] ??= []).add(p);
  }

  final out = <FarmerSummary>[];
  for (final f in data.farmers) {
    if (c.isNotEmpty && _norm(f.county) != _norm(c)) continue;
    final issues = issuesBy[f.uid] ?? const <IssueRow>[];
    final plots = plotsBy[f.uid] ?? const <PlotRow>[];
    final crops = {for (final p in plots) ...p.cropNames, for (final r in issues) if (r.crop.isNotEmpty) r.crop};
    if (cr.isNotEmpty && !crops.any((x) => _cropIs(x, cr))) continue;
    final recent = issues.where((r) => !r.at.isBefore(start)).toList();
    final low = {for (final p in plots) ...p.lowNutrients}.toList()..sort();
    final times = [...issues.map((r) => r.at), ...plots.map((p) => p.at).whereType<DateTime>()];
    final last = times.isEmpty ? null : times.reduce((a, b) => a.isAfter(b) ? a : b);

    final unknown = recent.where((r) => r.unidentified).length;
    final repeats = _repeated(recent).length;
    final score = unknown * 3 +
        recent.where((r) => r.isDisease && !r.unidentified).length * 2 +
        recent.where((r) => r.isPest && !r.unidentified).length +
        repeats * 2 +
        low.length;
    out.add(FarmerSummary(
      farmer: f,
      crops: crops,
      pests: recent.where((r) => r.isPest).length,
      diseases: recent.where((r) => r.isDisease).length,
      unidentified: unknown,
      lowNutrients: low,
      lastAt: last,
      attentionScore: score,
    ));
  }
  return out;
}

/// Problems reported more than once (same type and name).
Map<String, int> _repeated(List<IssueRow> rows) {
  final by = <String, int>{};
  for (final r in rows.where((r) => !r.unidentified && r.name.isNotEmpty)) {
    by[r.name] = (by[r.name] ?? 0) + 1;
  }
  by.removeWhere((_, v) => v < 2);
  return by;
}

/// Why a farmer needs attention, in plain words.
List<String> attentionReasons(FarmerSummary s, InsightsData data, DateTime now) {
  final start = now.subtract(Duration(days: data.days));
  final recent = data.issues.where((r) => r.farmerUid == s.farmer.uid && !r.at.isBefore(start)).toList();
  return [
    if (s.unidentified > 0) '${s.unidentified} unidentified problem${s.unidentified > 1 ? 's' : ''}',
    for (final e in _repeated(recent).entries) '${e.key} ×${e.value}',
    if (s.diseases > 0) '${s.diseases} disease report${s.diseases > 1 ? 's' : ''}',
    if (s.pests > 0) '${s.pests} pest report${s.pests > 1 ? 's' : ''}',
    if (s.lowNutrients.isNotEmpty) 'Low ${s.lowNutrients.join(', ')}',
  ];
}
