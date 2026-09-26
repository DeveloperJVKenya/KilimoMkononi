// lib/enterprise/features/weather/structured_advice.dart
//
// The MAIN / DO / AVOID / WHY advice shape shared by the live AI Farm
// Advisor card, AI drafts in the Field Agronomist panel, and published
// (verified) advisories — so all three read the same way to farmers.

class StructuredAdvice {
  final String main;
  final List<String> doList;
  final List<String> avoidList;
  final String why;

  const StructuredAdvice({
    required this.main,
    this.doList = const [],
    this.avoidList = const [],
    this.why = '',
  });

  bool get isEmpty =>
      main.trim().isEmpty &&
      doList.isEmpty &&
      avoidList.isEmpty &&
      why.trim().isEmpty;
}

final _bullet = RegExp(r'^[-•*]\s*');

/// Parses Gemini's plain-text reply:
///   MAIN: …   DO: - …   AVOID: - …   WHY: …
/// Returns null for empty input.
StructuredAdvice? parseStructuredAdvice(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;

  String main = '';
  final doList = <String>[];
  final avoidList = <String>[];
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
  );
}
