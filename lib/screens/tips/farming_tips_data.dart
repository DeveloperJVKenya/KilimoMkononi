// lib/screens/tips/farming_tips_data.dart
//
// Farming Tips library: crop guides bundled in
// assets/farming_tips/kilimo_farming_tips.json (overview, growth stages,
// varieties), plus the farmer's own crops (from `fielddata.crops[].type`) and
// saved guides (SharedPreferences). Parsing and matching are pure functions so
// they can be unit-tested.

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kTipsAsset = 'assets/farming_tips/kilimo_farming_tips.json';

/// One bullet ("- text") with optional sub-points ("  • text").
@immutable
class TipItem {
  final String text;
  final List<String> subs;
  const TipItem(this.text, [this.subs = const []]);
}

@immutable
class TipStage {
  final String name;
  final List<TipItem> tips;
  final String? image; // asset path, may be missing on disk
  const TipStage(this.name, this.tips, this.image);
}

@immutable
class TipVariety {
  final String name;
  final String bestFor;
  final List<TipItem> tips;
  final String? image;
  const TipVariety(this.name, this.bestFor, this.tips, this.image);
}

@immutable
class CropGuide {
  final String key; // json key, e.g. irish_potatoes
  final String name; // Irish Potatoes
  final String emoji;
  final List<TipItem> general;
  final String? image;
  final List<TipStage> stages;
  final List<TipVariety> varieties;
  const CropGuide({
    required this.key,
    required this.name,
    required this.emoji,
    required this.general,
    required this.image,
    required this.stages,
    required this.varieties,
  });

  int get tipCount =>
      general.length +
      stages.fold<int>(0, (n, s) => n + s.tips.length) +
      varieties.fold<int>(0, (n, v) => n + v.tips.length);

  /// Whole guide as plain text (for copy / share).
  String asText() {
    final b = StringBuffer('$emoji $name — farming guide\n\n');
    void items(List<TipItem> list) {
      for (final t in list) {
        b.writeln('• ${t.text}');
        for (final s in t.subs) {
          b.writeln('   – $s');
        }
      }
    }

    b.writeln('Key points');
    items(general);
    for (final s in stages) {
      b.writeln('\n${s.name}');
      items(s.tips);
    }
    if (varieties.isNotEmpty) {
      b.writeln('\nVarieties');
      for (final v in varieties) {
        b.writeln('\n${v.name}${v.bestFor.isEmpty ? '' : ' — best for: ${v.bestFor}'}');
        items(v.tips);
      }
    }
    b.writeln('\nFrom Kilimo Mkononi');
    return b.toString();
  }

  /// Search across the name, variety names and every tip.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    bool inItems(List<TipItem> l) => l.any((t) => t.text.toLowerCase().contains(q) || t.subs.any((s) => s.toLowerCase().contains(q)));
    return name.toLowerCase().contains(q) ||
        inItems(general) ||
        stages.any((s) => s.name.toLowerCase().contains(q) || inItems(s.tips)) ||
        varieties.any((v) => v.name.toLowerCase().contains(q) || v.bestFor.toLowerCase().contains(q) || inItems(v.tips));
  }
}

/// "- a\n  • b\n- c" → [TipItem(a,[b]), TipItem(c)].
List<TipItem> parseTips(String? raw) {
  if (raw == null) return const [];
  final out = <TipItem>[];
  for (final line in const LineSplitter().convert(raw)) {
    final t = line.trim();
    if (t.isEmpty) continue;
    final isSub = t.startsWith('•') || (line.startsWith(' ') && !t.startsWith('-'));
    final text = t.replaceFirst(RegExp(r'^[-•*]\s*'), '').trim();
    if (text.isEmpty) continue;
    if (isSub && out.isNotEmpty) {
      final last = out.removeLast();
      out.add(TipItem(last.text, [...last.subs, text]));
    } else {
      out.add(TipItem(text));
    }
  }
  return out;
}

String cropDisplayName(String key) => key
    .split('_')
    .where((w) => w.isNotEmpty)
    .map((w) => w[0].toUpperCase() + w.substring(1))
    .join(' ');

String? _asset(Object? p) {
  final s = p?.toString().trim() ?? '';
  if (s.isEmpty) return null;
  return s.startsWith('assets/') ? s : 'assets/$s';
}

/// Parses the bundled JSON into guides, in file order.
List<CropGuide> parseTipsLibrary(Map<String, dynamic> json) {
  final out = <CropGuide>[];
  json.forEach((key, value) {
    if (value is! Map) return;
    final stages = <TipStage>[];
    final st = value['stages'];
    if (st is Map) {
      st.forEach((name, d) {
        if (d is Map) stages.add(TipStage('$name', parseTips(d['tips']?.toString()), _asset(d['image'])));
      });
    }
    final varieties = <TipVariety>[];
    final va = value['varieties'];
    if (va is Map) {
      va.forEach((name, d) {
        if (d is Map) {
          varieties.add(TipVariety('$name', '${d['best_for'] ?? ''}'.trim(), parseTips(d['tips']?.toString()), _asset(d['image'])));
        }
      });
    }
    out.add(CropGuide(
      key: key,
      name: cropDisplayName(key),
      emoji: '${value['icon'] ?? '🌱'}',
      general: parseTips(value['general']?.toString()),
      image: _asset(value['image_general']),
      stages: stages,
      varieties: varieties,
    ));
  });
  return out;
}

String _stem(String s) {
  var w = s.trim().toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
  if (w.endsWith('oes')) return w.substring(0, w.length - 2); // tomatoes → tomato
  if (w.endsWith('s') && !w.endsWith('ss')) w = w.substring(0, w.length - 1);
  return w;
}

/// Guide keys for a crop name recorded in field data, e.g.
/// "Cabbages/Kales" → {cabbage, kales}, "Irish Potatoes" → {irish_potatoes}.
Set<String> guideKeysForCrop(String crop, Iterable<String> keys) {
  final parts = crop.split(RegExp(r'[/,&]')).map(_stem).where((p) => p.isNotEmpty).toSet();
  return keys.where((k) {
    final sk = _stem(k);
    return parts.any((p) => p == sk || (p.contains('potato') && sk.contains('potato')));
  }).toSet();
}

// ── Riverpod ────────────────────────────────────────────────────────────────

final tipsLibraryProvider = FutureProvider<List<CropGuide>>((ref) async {
  final raw = await rootBundle.loadString(kTipsAsset);
  return parseTipsLibrary(jsonDecode(raw) as Map<String, dynamic>);
});

/// Crop names the farmer recorded in field data ([] when signed out/offline).
final myFieldCropsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return const [];
  try {
    final snap = await FirebaseFirestore.instance.collection('fielddata').where('userId', isEqualTo: uid).get();
    final crops = <String>{};
    for (final d in snap.docs) {
      final list = d.data()['crops'];
      if (list is! List) continue;
      for (final c in list) {
        final t = c is Map ? '${c['type'] ?? ''}'.trim() : '';
        if (t.isNotEmpty) crops.add(t);
      }
    }
    return crops.toList();
  } catch (_) {
    return const [];
  }
});

/// Guide keys matching the farmer's field crops.
final myGuideKeysProvider = Provider.autoDispose<Set<String>>((ref) {
  final guides = ref.watch(tipsLibraryProvider).value ?? const [];
  final crops = ref.watch(myFieldCropsProvider).value ?? const [];
  final keys = guides.map((g) => g.key).toList();
  return {for (final c in crops) ...guideKeysForCrop(c, keys)};
});

class SavedGuidesNotifier extends Notifier<Set<String>> {
  static const prefsKey = 'farming_tips_saved';

  @override
  Set<String> build() {
    _load();
    return const {};
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      state = (p.getStringList(prefsKey) ?? const []).toSet();
    } catch (_) {}
  }

  Future<void> toggle(String key) async {
    final next = {...state};
    if (!next.remove(key)) next.add(key);
    state = next;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(prefsKey, next.toList());
    } catch (_) {}
  }
}

final savedGuidesProvider = NotifierProvider<SavedGuidesNotifier, Set<String>>(SavedGuidesNotifier.new);
