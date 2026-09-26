// lib/services/weather_day_plan.dart
//
// "Today on this farm" plan built on-device from NuaSense readings.
// NuaSense = data only. This file = Kilimo Mkononi advice rules
// (spray / fungal risk / irrigate / plough / grain drying).
// No NuaSense pest degree-day names.

import 'package:kilimomkononi/services/nuasense_service.dart';

enum DayMood { good, caution, hold }

class WeatherDayPlan {
  final String mainAdvice;
  final List<String> doToday;
  final List<String> avoidToday;
  final List<String> conditionLabels;
  final DayMood mood;

  const WeatherDayPlan({
    required this.mainAdvice,
    required this.doToday,
    required this.avoidToday,
    required this.conditionLabels,
    required this.mood,
  });

  /// Single paragraph for AI fallback / short summaries.
  String get asAdviceParagraph {
    final buf = StringBuffer(mainAdvice);
    if (doToday.isNotEmpty) {
      buf.write(' Do today: ${doToday.join(', ')}.');
    }
    if (avoidToday.isNotEmpty) {
      buf.write(' Avoid: ${avoidToday.join(', ')}.');
    }
    return buf.toString();
  }
}

List<String> conditionLabelsFor(NuaSenseReading r) {
  final labels = <String>[];
  if (r.airTemp > 32) {
    labels.add('Hot');
  } else if (r.airTemp < 15) {
    labels.add('Cool');
  } else {
    labels.add('Temp OK');
  }
  if (r.humidity > 80) {
    labels.add('Air very humid');
  } else if (r.humidity < 40) {
    labels.add('Air dry');
  } else {
    labels.add('Air normal');
  }
  if (r.windSpeed > 5) {
    labels.add('Windy');
  } else if (r.windSpeed > 2) {
    labels.add('Breezy');
  } else {
    labels.add('Low wind');
  }
  if (r.rainingNow) {
    labels.add('Raining now');
  } else if (r.rainfall > 0) {
    labels.add('Recent rain');
  } else {
    labels.add('No rain');
  }
  labels.add(r.leafIsWet ? 'Leaves wet' : 'Leaves dry');
  return labels;
}

/// Builds today's work plan from station parameters only.
WeatherDayPlan buildKmDayPlan(
  NuaSenseReading r, {
  List<String> cropNames = const [],
}) {
  final doToday = <String>[];
  final avoidToday = <String>[];
  late String main;
  late DayMood mood;

  final raining = r.rainingNow;
  final wetLeaves = r.leafIsWet;
  final longWet = r.lwdConsecutiveHours >= 6;
  final hasSprayScore = r.sprayQualityLabel.isNotEmpty;
  final goodSpray =
      hasSprayScore ? r.sprayQualityGood : (r.goodSprayWind && !raining);
  final marginalSpray = hasSprayScore ? r.sprayQualityMarginal : false;
  final cropStr =
      cropNames.isEmpty ? '' : ' for ${cropNames.take(2).join(" and ")}';

  final fungalPressure = wetLeaves ||
      longWet ||
      r.humidity > 80 ||
      (r.vpd < 0.5 && !raining);

  if (raining) {
    main =
        "It's raining right now — hold off spraying, fertiliser and heavy "
        'field work$cropStr until it clears.';
    mood = DayMood.hold;
    doToday.add('After rain: scout for pests and fungal disease');
    doToday.add('Check drainage in low-lying plots');
    avoidToday.add('Spraying pesticide or fungicide');
    avoidToday.add('Applying urea or top-dressing');
    avoidToday.add('Ploughing or heavy field work');
  } else if (wetLeaves || longWet) {
    main = 'Leaves are still wet'
        '${longWet ? " (${r.lwdConsecutiveHours}h so far)" : ""}'
        ' — high fungal disease risk$cropStr. Hold spraying and fertiliser '
        'until leaves dry.';
    mood = DayMood.hold;
    doToday.add('Scout leaves and stems for early disease signs');
    doToday.add('Wait for leaves to dry before any spray');
    avoidToday.add('Spraying pesticide or fungicide');
    avoidToday.add('Foliar feed or fertiliser application');
  } else if (goodSpray) {
    main =
        'Good conditions today$cropStr for spraying if you already see pests '
        'or disease — best early morning or late afternoon.';
    mood = DayMood.good;
    doToday.add('Spray only if pests or disease are confirmed in the field');
    doToday.add('Scout pests and disease while in the plot');
    if (fungalPressure) {
      doToday.add('Watch for fungal disease — humidity still favours it');
    }
    doToday.add('Foliar feed or top-dress if due');
  } else if (marginalSpray) {
    main =
        'Conditions are only average for spraying$cropStr — usable but not '
        "ideal. Prefer scouting unless the job can't wait.";
    mood = DayMood.caution;
    doToday.add('Scout pests and disease');
    doToday.add('Prepare for a better spray window');
    avoidToday.add('Spraying if the job can wait');
  } else {
    main =
        'Hold off spraying$cropStr — wind or conditions work against you. '
        'Focus on scouting and other tasks.';
    mood = DayMood.hold;
    doToday.add('Scout pests and disease');
    doToday.add('Plan for a calmer spray window');
    avoidToday.add('Spraying pesticide or fungicide');
  }

  if (r.windSpeed > 5 && !avoidToday.any((a) => a.startsWith('Spraying'))) {
    avoidToday.add('Spraying in windy hours');
  }

  if (r.vpd > 2.5) {
    doToday.add('Check soil moisture / irrigate if dry');
  } else if (r.vpd < 0.5 && !wetLeaves && !raining) {
    avoidToday.add('Irrigating — air is already humid');
    if (!doToday.any((d) => d.contains('fungal') || d.contains('disease'))) {
      doToday.add('Humid air — scout for fungal disease');
    }
  }

  if (!raining && r.humidity < 60 && r.sunlight > 20000) {
    doToday.add('Good day to dry harvested grain if you have stock');
  } else if (raining || r.humidity > 80) {
    avoidToday.add('Drying grain outdoors');
  }

  if (!raining && r.rainfall < 1 && r.et0Hour > 0.15) {
    doToday.add('Good day for ploughing or heavy field work');
  } else if ((raining || r.rainfall > 5) &&
      !avoidToday.contains('Ploughing or heavy field work')) {
    avoidToday.add('Ploughing — soil likely too wet');
  }

  return WeatherDayPlan(
    mainAdvice: main,
    doToday: doToday.toSet().take(5).toList(),
    avoidToday: avoidToday.toSet().take(5).toList(),
    conditionLabels: conditionLabelsFor(r),
    mood: mood,
  );
}