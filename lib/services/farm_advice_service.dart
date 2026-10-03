// lib/services/farm_advice_service.dart
//
// Everything the farmer is advised to do today, in three categories:
//
//   Farm alerts      today's plan from the station (buildKmDayPlan) plus the
//                    live condition alerts (station, soil sensor, satellite)
//   Verified advice  advisories a Field Agronomist published for the
//                    farmer's crops and the station's current conditions
//   AI advice        Gemini's suggestions for the same conditions — soil,
//                    pests and diseases to check — labelled "not verified"
//
// Shown on Home and in Notifications (lib/widgets/farm_advice_panel.dart);
// the Weather Station screen only shows the station's data. Each farm
// section (Soil in Field Data, Pests, Diseases) shows its own share via
// lib/settings/notifications/advice_providers.dart.

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kilimomkononi/enterprise/features/weather/advisory_conditions.dart';
import 'package:kilimomkononi/enterprise/features/weather/agronomic_advisory.dart';
import 'package:kilimomkononi/enterprise/features/weather/agronomic_advisory_service.dart';
import 'package:kilimomkononi/enterprise/features/weather/structured_advice.dart';
import 'package:kilimomkononi/services/farm_location_service.dart';
import 'package:kilimomkononi/services/function_auth.dart';
import 'package:kilimomkononi/services/nuasense_service.dart';
import 'package:kilimomkononi/services/weather_day_plan.dart';
import 'package:kilimomkononi/settings/notifications/farm_alerts.dart';

const _kAskGeminiUrl =
    'https://us-central1-kilimomkononi-e1031.cloudfunctions.net/askGemini';

/// Today's advice snapshot (without AI, which loads separately).
class FarmAdvice {
  /// Null when the station couldn't be reached.
  final NuaSenseReading? reading;
  final String? stationId;
  final String stationName;

  /// Null without live station data (none installed, or offline).
  final WeatherDayPlan? plan;
  final FarmAlertsResult? alerts;
  final List<AgronomicAdvisory> verified;
  final List<String> crops;
  final DateTime loadedAt;

  const FarmAdvice({
    this.reading,
    this.stationId,
    this.stationName = '',
    this.plan,
    this.alerts,
    this.verified = const [],
    this.crops = const [],
    required this.loadedAt,
  });

  bool get hasStation => reading?.isProvisioned ?? false;
  bool get hasLiveData => hasStation && reading!.hasData;
}

/// The AI advisor's answer for today.
class AiAdvice {
  final StructuredAdvice advice;

  /// True when Gemini was unreachable and the local day plan is shown.
  final bool fallback;
  final AgronomicAdvisory asAdvisory;
  final DateTime at;

  const AiAdvice({
    required this.advice,
    required this.fallback,
    required this.asAdvisory,
    required this.at,
  });
}

class FarmAdviceService {
  FarmAdviceService._();

  // One AI answer per station + crops + hour — Home and Notifications share it.
  static final Map<String, AiAdvice> _aiCache = {};

  static Future<FarmAdvice> load() async {
    final now = DateTime.now();
    String? stationId;
    var stationName = '';
    try {
      final stations = await NuaSenseService.getStations();
      if (stations.isNotEmpty) {
        stationId = stations.first.id;
        stationName = stations.first.name;
      }
    } catch (_) {}

    NuaSenseReading? reading;
    try {
      reading = await NuaSenseService.getLatestReading(stationId: stationId);
    } catch (e) {
      debugPrint('[FarmAdviceService] station: $e');
    }

    List<String>? crops;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        crops = await AgronomicAdvisoryService.farmerCrops(uid,
            plotId: await FarmLocationService.getSelectedPlotId());
      } catch (_) {}
    }

    final provisioned = reading?.isProvisioned ?? false;
    final live = provisioned && reading!.hasData;

    final results = await Future.wait<Object?>([
      loadFarmAlerts(stationId: stationId).then<Object?>((r) => r).catchError((_) => null),
      AgronomicAdvisoryService.publishedFor(
        conditions: provisioned ? activeConditionKeys(reading!) : {'general'},
        farmerCrops: crops,
        gatewayId: provisioned ? stationId : null,
      ).then<Object?>((r) => r).catchError((Object e) {
        debugPrint('[FarmAdviceService] verified: $e');
        return const <AgronomicAdvisory>[];
      }),
    ]);

    return FarmAdvice(
      reading: reading,
      stationId: stationId,
      stationName: stationName,
      plan: live ? buildKmDayPlan(reading, cropNames: crops ?? const []) : null,
      alerts: results[0] as FarmAlertsResult?,
      verified: (results[1] as List<AgronomicAdvisory>?) ?? const [],
      crops: crops ?? const [],
      loadedAt: now,
    );
  }

  /// AI advice for [a]'s live conditions; null without live station data.
  static Future<AiAdvice?> ai(FarmAdvice a, {bool refresh = false}) async {
    if (!a.hasLiveData) return null;
    final r = a.reading!;
    final now = DateTime.now();
    final key =
        '${a.stationId}|${a.crops.join(',')}|${now.year}-${now.month}-${now.day}-${now.hour}';
    if (!refresh && _aiCache.containsKey(key)) return _aiCache[key];

    final condition = _mainCondition(r);
    final id = 'ai_${a.stationId ?? 'farm'}_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    StructuredAdvice advice;
    var fallback = false;
    try {
      final res = await http
          .post(
            Uri.parse(_kAskGeminiUrl),
            headers: await authJsonHeaders(),
            body: jsonEncode({'prompt': _prompt(r, a.crops)}),
          )
          .timeout(const Duration(seconds: 45));
      if (res.statusCode != 200) throw Exception('askGemini HTTP ${res.statusCode}');
      final data = jsonDecode(res.body);
      final text = (data['candidates']?[0]?['content']?['parts']?[0]?['text'] ??
              data['text'] ??
              '')
          .toString()
          .trim();
      advice = parseStructuredAdvice(text) ?? _fromPlan(a.plan!);
    } catch (e) {
      debugPrint('[FarmAdviceService] AI unavailable, local plan: $e');
      advice = _fromPlan(a.plan!);
      fallback = true;
    }
    final out = AiAdvice(
      advice: advice,
      fallback: fallback,
      at: now,
      asAdvisory: AgronomicAdvisory.fromAi(
        id: id,
        advice: advice,
        crops: a.crops,
        condition: condition,
        gatewayId: a.stationId,
      ),
    );
    if (!fallback) _aiCache[key] = out;
    return out;
  }

  static StructuredAdvice _fromPlan(WeatherDayPlan p) => StructuredAdvice(
        main: p.mainAdvice,
        doList: p.doToday,
        avoidList: p.avoidToday,
      );

  /// Most specific active condition, for labelling the AI advice.
  static String _mainCondition(NuaSenseReading r) {
    final keys = activeConditionKeys(r)..remove('general');
    return keys.isEmpty ? 'general' : keys.first;
  }

  static String _prompt(NuaSenseReading r, List<String> crops) {
    final cropText = crops.isEmpty
        ? 'common smallholder crops (maize, beans, tomatoes, cabbage/kale, potatoes, onions, carrots)'
        : crops.join(', ');
    return '''
You are an agronomy advisor for smallholder farmers in Kenya.
The farmer grows: $cropText.

Farmers read this outdoors and have little time — be extremely scannable.

Reply in EXACTLY this format (plain text, no markdown):
MAIN: <one short action, max 12 words>
DO:
- <action>
- <action>
AVOID:
- <action>
WHY: <one short sentence>
PESTS:
- <pest name> — <signs to look for> — <what to do if found>
DISEASES:
- <disease name> — <signs to look for> — <what to do if found>
SOIL:
- <N|P|K|pH|general> | Low: <action> | Moderate: <action> | High: <action>

Rules:
- MAIN is the single most important action right now.
- DO and AVOID: max 3 bullets each, short phrases, start with a verb.
- PESTS and DISEASES: at most 2 each, only ones these crops commonly get in
  these exact conditions. Write "none" if nothing is likely.
- SOIL: at most 2 lines, about fertiliser/soil decisions these conditions
  affect (e.g. leaching after heavy rain). The farmer may not know their
  soil level, so give an action for each level. Write "none" if not relevant.
- Do not invent chemical brand names; name active ingredients only if essential.
- Do not lead with sensor numbers; only mention a number in WHY if it explains the action.

Farm conditions (context only — do not list these back):
- Spray quality: ${r.sprayQualityLabel.isNotEmpty ? "${r.sprayQualityLabel} (${r.sprayQualityIndex.toStringAsFixed(0)}/100)" : "not available"}
- Leaf wetness: ${r.leafIsWet ? "wet" : "dry"}${r.leafIsWet && r.lwdConsecutiveHours > 0 ? " (${r.lwdConsecutiveHours}h in a row)" : ""}
- VPD: ${r.vpd.toStringAsFixed(2)} kPa
- ET0: ${r.et0Hour.toStringAsFixed(2)} mm/h
- Rain: ${r.rainfall.toStringAsFixed(1)} mm this hour
- Wind: ${r.windSpeed.toStringAsFixed(1)} m/s
- Temp: ${r.airTemp.toStringAsFixed(1)}°C, humidity: ${r.humidity.toStringAsFixed(0)}%
''';
  }
}
