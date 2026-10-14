// lib/enterprise/features/agronomist/farmer_findings.dart
//
// What stands out in one farmer's records — shown at the top of the
// farmer's page in the Agronomist panel, each with "Advise" to answer it:
//
//   • unidentified problems (last 90 days)
//   • the same pest / disease reported more than once (last 90 days)
//   • problems reported with nothing done about them
//   • nutrients that test Low on a plot's latest soil test
//   • a soil test older than a year, or no soil test at all
//   • no records for 60 days
//
// Pure — test/agronomist_insights_test.dart.

import 'package:kilimomkononi/enterprise/features/agronomist/farmer_advice.dart';
import 'package:kilimomkononi/enterprise/features/agronomist/farmer_records.dart';

enum FindingLevel { high, medium, info }

class Finding {
  final FindingLevel level;
  final String text;
  final String? detail;

  /// What "Advise" pre-fills: the record it answers, crop, check.
  final AdviceBasis basis;
  final String? crop;
  final String? checkName;
  final String? checkType;

  const Finding({
    required this.level,
    required this.text,
    required this.basis,
    this.detail,
    this.crop,
    this.checkName,
    this.checkType,
  });
}

List<Finding> farmerFindings(FarmerRecord r, {DateTime? now}) {
  final t = now ?? DateTime.now();
  final recent = r.issues.where((i) => t.difference(i.at).inDays <= 90).toList();
  final out = <Finding>[];

  final unknown = recent.where((i) => i.unidentified).toList();
  for (final i in unknown.take(3)) {
    out.add(Finding(
      level: FindingLevel.high,
      text: '${i.label}${i.crop.isEmpty ? '' : ' on ${i.crop}'}',
      detail: 'Reported ${_date(i.at)}${i.source == 'photo' ? ' · photo ID${i.confidence == null ? '' : ' (${i.confidence} confidence)'}' : ''}',
      basis: AdviceBasis(kind: i.type, id: i.id, label: 'Unidentified ${i.type} problem${i.crop.isEmpty ? '' : ' on your ${i.crop}'}'),
      crop: i.crop.isEmpty ? null : i.crop,
    ));
  }

  final byName = <String, List<IssueRow>>{};
  for (final i in recent.where((i) => !i.unidentified && i.name.isNotEmpty)) {
    (byName['${i.type}|${i.name.toLowerCase()}'] ??= []).add(i);
  }
  for (final l in byName.values.where((l) => l.length >= 2)) {
    final i = l.first;
    out.add(Finding(
      level: FindingLevel.high,
      text: '${i.name} reported ${l.length} times',
      detail: 'Last ${_date(i.at)}${i.crop.isEmpty ? '' : ' on ${i.crop}'} — the problem keeps coming back',
      basis: AdviceBasis(kind: i.type, id: i.id, label: '${i.name} keeps coming back on your farm'),
      crop: i.crop.isEmpty ? null : i.crop,
      checkName: i.name,
      checkType: i.type,
    ));
  }

  final untreated = recent.where((i) => !i.unidentified && i.intervention == null).toList();
  final repeatedNames = {for (final l in byName.values.where((l) => l.length >= 2)) l.first.name.toLowerCase()};
  for (final i in untreated.where((i) => !repeatedNames.contains(i.name.toLowerCase())).take(3)) {
    out.add(Finding(
      level: FindingLevel.medium,
      text: '${i.name}${i.crop.isEmpty ? '' : ' on ${i.crop}'} — nothing logged as done',
      detail: 'Reported ${_date(i.at)}',
      basis: AdviceBasis(kind: i.type, id: i.id, label: '${i.name} on your ${i.crop.isEmpty ? 'farm' : i.crop}'),
      crop: i.crop.isEmpty ? null : i.crop,
      checkName: i.name,
      checkType: i.type,
    ));
  }

  final plots = r.latestPlots;
  for (final p in plots) {
    final low = p.lowNutrients;
    if (low.isNotEmpty) {
      out.add(Finding(
        level: FindingLevel.medium,
        text: '${p.plot.isEmpty ? 'A plot' : p.plot}: ${low.join(', ')} low',
        detail: '${p.cropNames.isEmpty ? 'No crop recorded' : p.cropNames.join(', ')} · soil test ${_date(p.at)}',
        basis: AdviceBasis(kind: 'soil', label: 'Soil test on ${p.plot.isEmpty ? 'your plot' : p.plot}: ${low.join(', ')} low'),
        crop: p.cropNames.isEmpty ? null : p.cropNames.first,
      ));
    }
    if (p.npk.isEmpty) {
      out.add(Finding(
        level: FindingLevel.info,
        text: '${p.plot.isEmpty ? 'A plot' : p.plot}: no soil test recorded',
        basis: AdviceBasis(kind: 'soil', label: 'Soil testing for ${p.plot.isEmpty ? 'your plot' : p.plot}'),
        crop: p.cropNames.isEmpty ? null : p.cropNames.first,
      ));
    } else if (p.at != null && t.difference(p.at!).inDays > 365) {
      out.add(Finding(
        level: FindingLevel.info,
        text: '${p.plot.isEmpty ? 'A plot' : p.plot}: soil test over a year old',
        detail: 'Last tested ${_date(p.at)}',
        basis: AdviceBasis(kind: 'soil', label: 'Re-testing the soil on ${p.plot.isEmpty ? 'your plot' : p.plot}'),
        crop: p.cropNames.isEmpty ? null : p.cropNames.first,
      ));
    }
  }

  final times = [
    ...r.issues.map((i) => i.at),
    for (final f in r.fieldRecords)
      if (f['timestamp'] is num) DateTime.fromMillisecondsSinceEpoch((f['timestamp'] as num).toInt()),
  ];
  final last = times.isEmpty ? null : times.reduce((a, b) => a.isAfter(b) ? a : b);
  if (last == null) {
    out.add(const Finding(
      level: FindingLevel.info,
      text: 'No farm records yet',
      detail: 'The farmer hasn\'t recorded a plot, soil test, pest or disease',
      basis: AdviceBasis(kind: 'insight', label: 'Getting started with your farm records'),
    ));
  } else if (t.difference(last).inDays > 60) {
    out.add(Finding(
      level: FindingLevel.info,
      text: 'No records for ${t.difference(last).inDays} days',
      detail: 'Last entry ${_date(last)}',
      basis: const AdviceBasis(kind: 'insight', label: 'Checking in on your farm'),
    ));
  }
  return out;
}

String _date(DateTime? d) {
  if (d == null) return '—';
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}
