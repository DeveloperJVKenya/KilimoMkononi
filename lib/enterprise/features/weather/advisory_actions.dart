// lib/enterprise/features/weather/advisory_actions.dart
//
// The actionable parts of an advisory, beyond MAIN / DO / AVOID / WHY:
//
//   soilActions    fertiliser / soil decisions per nutrient, with what to do
//                  when the farmer's level is Low, Moderate or High. Every
//                  band is optional, and the farmer's level is never
//                  required — someone who hasn't tested picks the band that
//                  fits (or the general action).
//   pestChecks     pests to look for in these conditions: the signs, and
//   diseaseChecks  what to do if they are found (with product / rate).
//
// Farmers confirm each check on their farm and log the action as an
// intervention in the Soil (Field Data), Pest or Disease records — see
// advisory_detail_screen.dart. The same shapes come out of the AI advisor,
// so AI suggestions and verified advice are handled alike (AI is labelled).
//
// Firestore (on agronomic_advisories/{id}):
//   soilActions:   [{nutrient, general, low, moderate, high}]
//                  each band: {action, product, rate, method}
//   pestChecks:    [{name, signs, ifFound, product, rate}]
//   diseaseChecks: [{name, signs, ifFound, product, rate}]

import 'package:flutter/material.dart';
import 'package:kilimomkononi/services/nutrient_levels.dart';

/// The farm sections advice and alerts are filed under.
enum AdviceSection {
  soil('Soil & fertiliser', 'Soil', Icons.grass_rounded, Color(0xFF6D4C41)),
  pests('Pests', 'Pests', Icons.bug_report_rounded, Color(0xFFEF6C00)),
  diseases('Diseases', 'Diseases', Icons.coronavirus_rounded, Color(0xFFC62828));

  final String label;
  final String short;
  final IconData icon;
  final Color color;
  const AdviceSection(this.label, this.short, this.icon, this.color);

  static AdviceSection? fromName(String s) =>
      AdviceSection.values.where((v) => v.name == s.trim()).firstOrNull;

  /// "soil,pests" → {soil, pests}
  static Set<AdviceSection> parseList(String? s) => {
    for (final p in (s ?? '').split(',')) ?AdviceSection.fromName(p),
  };
}

String _str(dynamic v) => v == null ? '' : '$v'.trim();

/// What to do for one level band.
class BandAction {
  final String action;
  final String product;
  final String rate;
  final String method;

  const BandAction({
    this.action = '',
    this.product = '',
    this.rate = '',
    this.method = '',
  });

  bool get isEmpty =>
      action.isEmpty && product.isEmpty && rate.isEmpty && method.isEmpty;

  /// "Apply CAN · 50 kg/acre · top-dress after rain"
  String get summary => [
    action,
    product,
    rate,
    method,
  ].where((s) => s.isNotEmpty).join(' · ');

  factory BandAction.fromMap(dynamic m) {
    if (m is! Map) return const BandAction();
    return BandAction(
      action: _str(m['action']),
      product: _str(m['product']),
      rate: _str(m['rate']),
      method: _str(m['method']),
    );
  }

  Map<String, dynamic>? toMap() => isEmpty
      ? null
      : {'action': action, 'product': product, 'rate': rate, 'method': method};
}

/// Nutrient keys an advisory can address.
const kSoilNutrients = {
  'N': 'Nitrogen (N)',
  'P': 'Phosphorus (P)',
  'K': 'Potassium (K)',
  'pH': 'Soil pH / acidity',
  'OM': 'Organic matter',
  'general': 'General soil care',
};

/// A soil / fertiliser decision for one nutrient.
class SoilAction {
  final String nutrient;

  /// Applies whatever the level (or when the farmer doesn't know it).
  final BandAction general;
  final BandAction low;
  final BandAction moderate;
  final BandAction high;

  const SoilAction({
    required this.nutrient,
    this.general = const BandAction(),
    this.low = const BandAction(),
    this.moderate = const BandAction(),
    this.high = const BandAction(),
  });

  String get label => kSoilNutrients[nutrient] ?? nutrient;

  /// Whether the farmer's level can be measured in Field Data (N/P/K).
  bool get isMeasured => const {'N', 'P', 'K'}.contains(nutrient);

  BandAction forBand(NutrientBand? b) => switch (b) {
    NutrientBand.low => low,
    NutrientBand.moderate => moderate,
    NutrientBand.high => high,
    null => general,
  };

  /// Bands the agronomist filled in.
  List<NutrientBand> get bands => [
    for (final b in NutrientBand.values)
      if (!forBand(b).isEmpty) b,
  ];

  bool get isEmpty => general.isEmpty && bands.isEmpty;

  factory SoilAction.fromMap(dynamic m) {
    final d = m is Map ? m : const {};
    return SoilAction(
      nutrient: _str(d['nutrient']).isEmpty ? 'general' : _str(d['nutrient']),
      general: BandAction.fromMap(d['general']),
      low: BandAction.fromMap(d['low']),
      moderate: BandAction.fromMap(d['moderate']),
      high: BandAction.fromMap(d['high']),
    );
  }

  Map<String, dynamic> toMap() => {
    'nutrient': nutrient,
    'general': general.toMap(),
    'low': low.toMap(),
    'moderate': moderate.toMap(),
    'high': high.toMap(),
  };
}

/// A pest or disease to look for.
class CropCheck {
  final String name;
  final String signs;
  final String ifFound;
  final String product;
  final String rate;

  const CropCheck({
    required this.name,
    this.signs = '',
    this.ifFound = '',
    this.product = '',
    this.rate = '',
  });

  bool get isEmpty => name.isEmpty;

  /// What the farmer logs as the intervention if found.
  String get interventionText {
    final what = ifFound.isNotEmpty ? ifFound : 'Treated $name';
    return product.isEmpty ? what : '$what ($product)';
  }

  factory CropCheck.fromMap(dynamic m) {
    final d = m is Map ? m : const {};
    return CropCheck(
      name: _str(d['name']),
      signs: _str(d['signs']),
      ifFound: _str(d['ifFound']),
      product: _str(d['product']),
      rate: _str(d['rate']),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'signs': signs,
    'ifFound': ifFound,
    'product': product,
    'rate': rate,
  };

  /// AI line "Aphids — curled sticky leaves — spray neem if colonies seen".
  factory CropCheck.fromLine(String line) {
    final parts = line
        .split(RegExp(r'\s+[—–-]\s+|\s*\|\s*'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return CropCheck(
      name: parts.isEmpty ? line.trim() : parts[0],
      signs: parts.length > 1 ? parts[1] : '',
      ifFound: parts.length > 2 ? parts.sublist(2).join(' — ') : '',
    );
  }
}

/// All the actionable content of one piece of advice.
class AdviceActions {
  final List<SoilAction> soil;
  final List<CropCheck> pests;
  final List<CropCheck> diseases;

  const AdviceActions({
    this.soil = const [],
    this.pests = const [],
    this.diseases = const [],
  });

  static const empty = AdviceActions();

  bool get isEmpty => soil.isEmpty && pests.isEmpty && diseases.isEmpty;

  Set<AdviceSection> get sections => {
    if (soil.isNotEmpty) AdviceSection.soil,
    if (pests.isNotEmpty) AdviceSection.pests,
    if (diseases.isNotEmpty) AdviceSection.diseases,
  };

  int countFor(AdviceSection s) => switch (s) {
    AdviceSection.soil => soil.length,
    AdviceSection.pests => pests.length,
    AdviceSection.diseases => diseases.length,
  };

  factory AdviceActions.fromDoc(Map<String, dynamic> d) => AdviceActions(
    soil: ((d['soilActions'] as List?) ?? const [])
        .map(SoilAction.fromMap)
        .where((a) => !a.isEmpty)
        .toList(),
    pests: ((d['pestChecks'] as List?) ?? const [])
        .map(CropCheck.fromMap)
        .where((c) => !c.isEmpty)
        .toList(),
    diseases: ((d['diseaseChecks'] as List?) ?? const [])
        .map(CropCheck.fromMap)
        .where((c) => !c.isEmpty)
        .toList(),
  );

  Map<String, dynamic> toMap() => {
    'soilActions': soil.map((a) => a.toMap()).toList(),
    'pestChecks': pests.map((c) => c.toMap()).toList(),
    'diseaseChecks': diseases.map((c) => c.toMap()).toList(),
  };
}

/// Sections a server weather-alert category belongs to. Mirrors
/// ALERT_SECTIONS in functions/notifications.js.
const kAlertCategorySections = <String, Set<AdviceSection>>{
  'heavy_rain': {AdviceSection.soil},
  'heat': {AdviceSection.soil},
  'frost': {AdviceSection.soil},
  'fungal': {AdviceSection.diseases},
  'strong_wind': {AdviceSection.pests, AdviceSection.diseases},
};
