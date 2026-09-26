// lib/enterprise/features/weather/advisory_conditions.dart
//
// Weather conditions a Field Agronomist can target an advisory at, and how a
// live NuaSense reading maps onto them. Thresholds match
// lib/services/weather_day_plan.dart so verified advice lines up with the
// day plan farmers already see.

import 'package:flutter/material.dart';
import 'package:kilimomkononi/services/nuasense_service.dart';

class AdvisoryCondition {
  final String key;
  final String label;
  final String description;
  final IconData icon;

  const AdvisoryCondition(this.key, this.label, this.description, this.icon);
}

/// Stored in Firestore by [key] — never rename a key, only add new ones
/// (firestore.rules validates against this list too).
const List<AdvisoryCondition> kAdvisoryConditions = [
  AdvisoryCondition(
    'general',
    'Any conditions',
    'Shown whatever the weather',
    Icons.eco_outlined,
  ),
  AdvisoryCondition(
    'raining',
    'Raining now',
    'Rain in the last hour',
    Icons.grain_rounded,
  ),
  AdvisoryCondition(
    'wet_leaves',
    'Wet leaves',
    'Leaf wetness sensor wet, or wet 6h+',
    Icons.water_drop_rounded,
  ),
  AdvisoryCondition(
    'high_humidity',
    'Very humid',
    'Humidity above 80% — fungal risk',
    Icons.cloud_rounded,
  ),
  AdvisoryCondition(
    'high_wind',
    'Windy',
    'Wind above 5 m/s — spray drift',
    Icons.air_rounded,
  ),
  AdvisoryCondition(
    'heat',
    'Hot',
    'Air temperature above 32°C',
    Icons.wb_sunny_rounded,
  ),
  AdvisoryCondition(
    'cool',
    'Cool',
    'Air temperature below 15°C',
    Icons.ac_unit_rounded,
  ),
  AdvisoryCondition(
    'frost',
    'Frost risk',
    'Air temperature 4°C or below',
    Icons.severe_cold_rounded,
  ),
  AdvisoryCondition(
    'dry_stress',
    'Dry air / water stress',
    'VPD above 2.5 kPa or humidity below 40%',
    Icons.local_fire_department_outlined,
  ),
  AdvisoryCondition(
    'good_spray',
    'Good spray window',
    'Spray-quality score good (or calm and dry)',
    Icons.check_circle_outline_rounded,
  ),
];

AdvisoryCondition conditionFor(String key) => kAdvisoryConditions.firstWhere(
  (c) => c.key == key,
  orElse: () => kAdvisoryConditions.first,
);

/// Condition keys active for this reading. Always includes 'general'.
///
/// An offline station ([NuaSenseReading.hasData] false) reports placeholder
/// zeros — 0°C, 0% humidity, no wind — which would otherwise light up
/// 'cool', 'frost', 'dry_stress' and 'good_spray'. Only 'general' applies.
Set<String> activeConditionKeys(NuaSenseReading r) {
  final keys = <String>{'general'};
  if (!r.hasData) return keys;
  final raining = r.rainingNow;
  if (raining) keys.add('raining');
  if (r.leafIsWet || r.lwdConsecutiveHours >= 6) keys.add('wet_leaves');
  if (r.humidity > 80) keys.add('high_humidity');
  if (r.windSpeed > 5) keys.add('high_wind');
  if (r.airTemp > 32) keys.add('heat');
  if (r.airTemp < 15) keys.add('cool');
  if (r.airTemp <= 4) keys.add('frost');
  if (r.vpd > 2.5 || r.humidity < 40) keys.add('dry_stress');
  final goodSpray = r.sprayQualityLabel.isNotEmpty
      ? r.sprayQualityGood
      : (r.goodSprayWind && !raining);
  if (goodSpray && !raining) keys.add('good_spray');
  return keys;
}

// ── Crops ──────────────────────────────────────────────────────────────────

/// Matches `_kCropTypes` in plot_input_form.dart — the names farmers record
/// in fielddata — so advisories and farmer crops line up exactly.
const String kAllCrops = 'All crops';
const List<String> kAdvisoryCrops = [
  'Beans',
  'Maize',
  'Tomatoes',
  'Cabbages/Kales',
  'Carrots',
  'Irish Potatoes',
  'Wheat',
  'Sugarcane',
  'Rice',
  'Onions',
];

String _norm(String s) => s.trim().toLowerCase();

/// True when the advisory targets every crop.
bool isForAllCrops(List<String> advisoryCrops) =>
    advisoryCrops.any((c) => _norm(c) == _norm(kAllCrops));

/// True when an advisory for [advisoryCrops] applies to a farmer growing
/// [farmerCrops]. Unknown farmer crops (empty) match everything, so a farmer
/// who hasn't recorded field data still sees verified advice.
bool cropsMatch(List<String> advisoryCrops, List<String> farmerCrops) {
  if (isForAllCrops(advisoryCrops)) return true;
  if (farmerCrops.isEmpty) return true;
  final mine = farmerCrops.map(_norm).toSet();
  return advisoryCrops.any((c) => mine.contains(_norm(c)));
}
