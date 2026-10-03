// lib/enterprise/features/weather/structured_advice.dart
//
// The MAIN / DO / AVOID / WHY advice shape shared by the live AI Farm
// Advisor card, AI drafts in the Field Agronomist panel, and published
// (verified) advisories — so all three read the same way to farmers.
//
// AI replies may also carry PESTS / DISEASES / SOIL sections, parsed into
// [StructuredAdvice.actions] (the same shape agronomists fill in).

import 'package:kilimomkononi/enterprise/features/weather/advisory_actions.dart';

class StructuredAdvice {
  final String main;
  final List<String> doList;
  final List<String> avoidList;
  final String why;

  /// Pests / diseases to check and soil actions (AI replies only; verified
  /// advisories keep theirs on the advisory itself).
  final AdviceActions actions;

  const StructuredAdvice({
    required this.main,
    this.doList = const [],
    this.avoidList = const [],
    this.why = '',
    this.actions = AdviceActions.empty,
  });

  bool get isEmpty =>
      main.trim().isEmpty &&
      doList.isEmpty &&
      avoidList.isEmpty &&
      why.trim().isEmpty;
}

final _bullet = RegExp(r'^[-•*]\s*');

/// AI soil line: "N | Low: apply CAN 50 kg/acre | High: skip top-dressing".
/// Unlabelled parts are the general action.
SoilAction parseSoilLine(String line) {
  final parts = line.split('|').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
  var nutrient = 'general';
  if (parts.isNotEmpty) {
    final key = kSoilNutrients.keys.firstWhere(
      (k) => k.toLowerCase() == parts.first.toLowerCase(),
      orElse: () => '',
    );
    if (key.isNotEmpty) {
      nutrient = key;
      parts.removeAt(0);
    }
  }
  final bands = <String, String>{};
  final general = <String>[];
  for (final p in parts) {
    final m = RegExp(r'^(low|moderate|optimal|high|any)\s*:\s*(.*)$', caseSensitive: false).firstMatch(p);
    if (m == null) {
      general.add(p);
    } else {
      var band = m.group(1)!.toLowerCase();
      if (band == 'optimal') band = 'moderate';
      if (band == 'any') {
        general.add(m.group(2)!);
      } else {
        bands[band] = m.group(2)!.trim();
      }
    }
  }
  BandAction b(String? t) => BandAction(action: t ?? '');
  return SoilAction(
    nutrient: nutrient,
    general: b(general.join('; ')),
    low: b(bands['low']),
    moderate: b(bands['moderate']),
    high: b(bands['high']),
  );
}

/// Parses Gemini's plain-text reply:
///   MAIN: …   DO: - …   AVOID: - …   WHY: …
/// Returns null for empty input.
StructuredAdvice? parseStructuredAdvice(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;

  String main = '';
  final doList = <String>[];
  final avoidList = <String>[];
  final pests = <CropCheck>[];
  final diseases = <CropCheck>[];
  final soil = <SoilAction>[];
  String why = '';
  String section = '';

  for (final line in text.split(RegExp(r'\r?\n'))) {
    final t = line.trim();
    if (t.isEmpty) continue;
    final upper = t.toUpperCase();

    if (upper.startsWith('MAIN:')) {
      section = 'main';
      main = t.substring(5).trim();
      continue;
    }
    if (upper.startsWith('DO:')) {
      section = 'do';
      final rest = t.substring(3).trim();
      if (rest.isNotEmpty) doList.add(rest.replaceFirst(_bullet, ''));
      continue;
    }
    if (upper.startsWith('AVOID:')) {
      section = 'avoid';
      final rest = t.substring(6).trim();
      if (rest.isNotEmpty) avoidList.add(rest.replaceFirst(_bullet, ''));
      continue;
    }
    if (upper.startsWith('WHY:')) {
      section = 'why';
      why = t.substring(4).trim();
      continue;
    }
    // Extra sections: everything after the label is a list.
    final extra = RegExp(r'^(PESTS|DISEASES|SOIL)\s*:\s*(.*)$', caseSensitive: false).firstMatch(t);
    if (extra != null) {
      section = extra.group(1)!.toLowerCase();
      final rest = extra.group(2)!.trim();
      if (rest.isNotEmpty && !RegExp(r'^(none|n/a|-)$', caseSensitive: false).hasMatch(rest)) {
        _addExtra(section, rest.replaceFirst(_bullet, ''), pests, diseases, soil);
      }
      continue;
    }

    final bullet = t.replaceFirst(_bullet, '');
    if (bullet.isEmpty) continue;
    switch (section) {
      case 'do':
        doList.add(bullet);
      case 'avoid':
        avoidList.add(bullet);
      case 'why':
        why = why.isEmpty ? bullet : '$why $bullet';
      case 'main':
        if (main.isEmpty) main = bullet;
      case 'pests' || 'diseases' || 'soil':
        _addExtra(section, bullet, pests, diseases, soil);
    }
  }

  if (main.isEmpty) {
    final first = text.split(RegExp(r'[.\n]')).first.trim();
    if (first.isEmpty) return null;
    main = first;
  }

  return StructuredAdvice(
    main: main,
    doList: doList.take(4).toList(),
    avoidList: avoidList.take(4).toList(),
    why: why,
    actions: AdviceActions(
      soil: soil.where((a) => !a.isEmpty).take(4).toList(),
      pests: pests.take(4).toList(),
      diseases: diseases.take(4).toList(),
    ),
  );
}

void _addExtra(
  String section,
  String line,
  List<CropCheck> pests,
  List<CropCheck> diseases,
  List<SoilAction> soil,
) {
  if (RegExp(r'^(none|n/a)$', caseSensitive: false).hasMatch(line.trim())) return;
  switch (section) {
    case 'pests':
      pests.add(CropCheck.fromLine(line));
    case 'diseases':
      diseases.add(CropCheck.fromLine(line));
    case 'soil':
      soil.add(parseSoilLine(line));
  }
}
