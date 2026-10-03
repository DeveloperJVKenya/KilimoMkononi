// lib/enterprise/features/weather/advisory_conditions.dart
//
// Weather conditions a Field Agronomist can target an advisory at, and how a
// live NuaSense reading maps onto them. Thresholds match
// lib/services/weather_day_plan.dart so verified advice lines up with the
// day plan farmers already see.

import 'package:flutter/material.dart';
import 'package:kilimomkononi/services/nuasense_service.dart';
import 'package:kilimomkononi/services/nutrient_levels.dart';

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
  AdvisoryCondition(
    'moderate',
    'Moderate weather',
    'Mild and calm: 15–32°C, humidity 40–80%, wind up to 5 m/s, no rain',
    Icons.wb_cloudy_outlined,
  ),
  AdvisoryCondition(
    kCustomCondition,
    'Other (type your own)',
    'Name the condition and set the ranges it applies to',
    Icons.edit_note_rounded,
  ),
];

/// The condition key for one an agronomist typed (see [CustomCondition]).
const kCustomCondition = 'custom';

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
  if (!raining &&
      r.airTemp >= 15 && r.airTemp <= 32 &&
      r.humidity >= 40 && r.humidity <= 80 &&
      r.windSpeed <= 5) {
    keys.add('moderate');
  }
  return keys;
}

// ── Custom (typed) condition ───────────────────────────────────────────────

/// A condition an agronomist typed, stored on the advisory as
/// `customCondition: {label, tempMin, tempMax, humidityMin, humidityMax,
/// windMin, windMax, rainMin, rainMax}` (each range end optional).
///
/// With no ranges it applies whatever the weather (like "Any conditions",
/// under its own name). With ranges it applies when the station reading is
/// inside all of them — the same check as customConditionApplies() in
/// functions/notifications.js.
class CustomCondition {
  final String label;
  final double? tempMin, tempMax;
  final double? humidityMin, humidityMax;
  final double? windMin, windMax;
  final double? rainMin, rainMax;

  const CustomCondition({
    required this.label,
    this.tempMin,
    this.tempMax,
    this.humidityMin,
    this.humidityMax,
    this.windMin,
    this.windMax,
    this.rainMin,
    this.rainMax,
  });

  static double? _num(dynamic v) => v is num ? v.toDouble() : null;

  static CustomCondition? fromMap(dynamic m) {
    if (m is! Map) return null;
    final label = '${m['label'] ?? ''}'.trim();
    return CustomCondition(
      label: label.isEmpty ? 'Custom condition' : label,
      tempMin: _num(m['tempMin']),
      tempMax: _num(m['tempMax']),
      humidityMin: _num(m['humidityMin']),
      humidityMax: _num(m['humidityMax']),
      windMin: _num(m['windMin']),
      windMax: _num(m['windMax']),
      rainMin: _num(m['rainMin']),
      rainMax: _num(m['rainMax']),
    );
  }

  Map<String, dynamic> toMap() => {
    'label': label.trim(),
    'tempMin': tempMin,
    'tempMax': tempMax,
    'humidityMin': humidityMin,
    'humidityMax': humidityMax,
    'windMin': windMin,
    'windMax': windMax,
    'rainMin': rainMin,
    'rainMax': rainMax,
  };

  List<double?> get _bounds => [
    tempMin, tempMax, humidityMin, humidityMax, windMin, windMax, rainMin, rainMax,
  ];

  /// False = applies in any weather.
  bool get hasRanges => _bounds.any((b) => b != null);

  /// A range whose minimum is above its maximum, if any (for the editor).
  String? get invalidRange {
    bool bad(double? lo, double? hi) => lo != null && hi != null && lo > hi;
    if (bad(tempMin, tempMax)) return 'temperature';
    if (bad(humidityMin, humidityMax)) return 'humidity';
    if (bad(windMin, windMax)) return 'wind';
    if (bad(rainMin, rainMax)) return 'rain';
    return null;
  }

  /// Does it apply to [r]? Ranges need live data (an offline station's
  /// placeholder zeros never count).
  bool appliesTo(NuaSenseReading? r) {
    if (!hasRanges) return true;
    if (r == null || !r.hasData) return false;
    bool inRange(double v, double? lo, double? hi) =>
        (lo == null || v >= lo) && (hi == null || v <= hi);
    return inRange(r.airTemp, tempMin, tempMax) &&
        inRange(r.humidity, humidityMin, humidityMax) &&
        inRange(r.windSpeed, windMin, windMax) &&
        inRange(r.rainfall, rainMin, rainMax);
  }

  /// "18–28°C · humidity 60%+ · no wind limit" style summary.
  String get description {
    String range(double? lo, double? hi, String unit, String name) {
      String f(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
      if (lo != null && hi != null) return '$name ${f(lo)}–${f(hi)}$unit';
      if (lo != null) return '$name ${f(lo)}$unit or more';
      if (hi != null) return '$name up to ${f(hi)}$unit';
      return '';
    }
    final parts = [
      range(tempMin, tempMax, '°C', 'temp'),
      range(humidityMin, humidityMax, '%', 'humidity'),
      range(windMin, windMax, ' m/s', 'wind'),
      range(rainMin, rainMax, ' mm/h', 'rain'),
    ].where((s) => s.isNotEmpty);
    return parts.isEmpty ? 'Shown whatever the weather' : parts.join(' · ');
  }
}

// ── Crops ──────────────────────────────────────────────────────────────────

/// The crops farmers record in Field Data (kFieldCropTypes), so advisories
/// and farmer crops line up exactly. Agronomists can also type others.
const String kAllCrops = 'All crops';
const List<String> kAdvisoryCrops = kFieldCropTypes;

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
  // "Cabbages/Kales" (older records / advice) matches Cabbages and Kales.
  final mine = farmerCrops.expand(cropNameParts).toSet();
  return advisoryCrops.any((c) => cropNameParts(c).any(mine.contains));
}
