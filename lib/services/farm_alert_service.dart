// lib/services/farm_alert_service.dart
//
// Generates proactive farm alerts from IoT sensor + satellite + NuaSense
// weather station data.
//
// ── WHAT CHANGED ──────────────────────────────────────────────────────────
//
// NuaSense weather station data (NuaSenseReading) is now a third input
// alongside IoT soil sensor (IotSensorReading) and NASA satellite
// (SatelliteReading). When a NuaSense reading is available it enriches or
// replaces the satellite-derived values for:
//   • Air temperature / humidity      → sharper fungal & heat risk
//   • Wind speed                      → more accurate spray window
//   • Rainfall (current hour)         → real-time flood / spray decisions
//   • Leaf wetness flag (lwd_hour)    → direct fungal signal, no inference
//   • VPD                             → new irrigation / crop stress alert
//   • Degree-days (aphid/whitefly/PTM)→ new pest pressure alerts
//
// Priority: NuaSense > NASA satellite > IoT (for atmospheric fields).
// Soil NPK/pH/EC still comes exclusively from IotSensorReading.
//
// ── FIRESTORE ALERT PERSISTENCE ────────────────────────────────────────────
//
//   farm_alerts/{userId}/alerts/{alertId}
//   {
//     userId, county, category, severity, title, message,
//     createdAt: Timestamp, sent: false
//   }
//
// Cloud Function reads `sent: false` docs and pushes FCM notifications.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kilimomkononi/services/iot_sensor_service.dart';
import 'package:kilimomkononi/services/nasa_power_service.dart';
import 'package:kilimomkononi/services/farm_location_service.dart';
import 'package:kilimomkononi/services/nuasense_service.dart';

// ── Models ─────────────────────────────────────────────────────────────────

enum AlertSeverity { info, warning, high, critical }

enum AlertCategory {
  flood,
  drought,
  irrigate,
  fertilise,
  fungal,
  heat,
  spray,
  // New categories from NuaSense
  leafWetness,   // direct lwd_hour flag
  pestPressure,  // degree-day threshold crossed
  vpd,           // crop water stress
}

class FarmAlert {
  final AlertCategory category;
  final AlertSeverity severity;
  final String title;
  final String message;
  final String actionLabel;
  final DateTime generatedAt;
  /// Which data source(s) contributed to this alert.
  final String source;

  const FarmAlert({
    required this.category,
    required this.severity,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.generatedAt,
    this.source = 'satellite',
  });

  Map<String, dynamic> toFirestoreMap(String userId, String county) => {
    'userId':    userId,
    'county':    county,
    'category':  category.name,
    'severity':  severity.name,
    'title':     title,
    'message':   message,
    'source':    source,
    'createdAt': Timestamp.fromDate(generatedAt),
    'sent':      false,
  };
}

// ── Service ────────────────────────────────────────────────────────────────

class FarmAlertService {
  FarmAlertService._();

  /// Evaluates current IoT + satellite + NuaSense data and returns all
  /// active alerts sorted by severity (critical first).
  /// Also persists high/critical alerts to Firestore for push notification.
  static Future<List<FarmAlert>> evaluateAlerts() async {
    IotSensorReading?        iot;
    SatelliteReading?        sat;
    NuaSenseReading?         ws;        // weather station
    List<SatelliteReading>   history = [];

    // Fetch all three sources concurrently; any can fail without crashing.
    await Future.wait([
      IotSensorService.getReadingForFarm()
          .then<IotSensorReading?>((v) => iot = v).catchError((_) => null),
      NasaPowerService.getToday()
          .then((v) => sat = v).catchError((_) => null),
      NasaPowerService.getHistory(days: 7)
          .then((v) => history = v).catchError((_) => <SatelliteReading>[]),
      NuaSenseService.getLatestReading()
          .then((v) {
            // Only use NuaSense if the station returned real data
            // (timestamp is not the epoch zero-value from empty())
            if (v.timestamp.millisecondsSinceEpoch > 0) ws = v;
          }).catchError((_) {}),
    ]);

    final rain7d = SatelliteReading.totalPrecipitation(history);
    final alerts = _compute(iot, sat, ws, rain7d);

    // Persist high/critical to Firestore for FCM
    final uid      = FirebaseAuth.instance.currentUser?.uid;
    final location = await FarmLocationService.getLocation();
    if (uid != null) {
      await _persistAlerts(alerts, uid, location.county);
    }

    return alerts;
  }

  // ── Alert computation ──────────────────────────────────────────────────────
  //
  // For each atmospheric field we pick the best available source:
  //   ws (NuaSense live station) > sat (NASA) > iot (soil sensor)
  //
  // This means:
  //   • Farmers with a weather station get precise, real-time alerts.
  //   • Farmers without one still get the full alert set from satellite.

  static List<FarmAlert> _compute(
    IotSensorReading?  iot,
    SatelliteReading?  sat,
    NuaSenseReading?   ws,
    double             rain7d,
  ) {
    final now    = DateTime.now();
    final alerts = <FarmAlert>[];

    // ── Resolved atmospheric values ──────────────────────────────────────────
    // Each value prefers ws → sat → iot → 0/fallback
    final airTemp    = ws?.airTemp     ?? sat?.airTemp     ?? 0.0;
    final airTempMax = sat?.airTempMax ?? ws?.airTemp      ?? 0.0;
    final humidity   = ws?.humidity    ?? sat?.humidity    ?? iot?.humidity ?? 0.0;
    final dewPoint   = ws?.dewPoint    ?? sat?.dewPoint    ?? 0.0;
    final cloudCover = sat?.cloudCover ?? 0.0;
    final windSpeed  = ws?.windSpeed   ?? sat?.windSpeed   ?? 99.0;
    final rainToday  = ws?.rainfall    ?? sat?.precipitation ?? 0.0;
    final rootMoist  = sat?.rootZoneMoisture ?? 0.5;       // satellite only
    final soilTemp   = iot?.temperature ?? 0.0;            // IoT sensor only

    // NuaSense-specific agronomic values
    final leafWet    = ws?.leafIsWet   ?? false;
    final vpd        = ws?.vpd         ?? 0.0;
    final et0        = ws?.et0Hour     ?? 0.0;
    final ddAphid    = ws?.ddAphidHour    ?? 0.0;
    final ddWhitefly = ws?.ddWhiteflyHour ?? 0.0;
    final ddPtm      = ws?.ddPtmHour      ?? 0.0;
    final dpDepression = ws?.dewPointDepression ?? 99.0;

    final hasWeatherStation = ws != null;

    // ── 1. FLOOD RISK ────────────────────────────────────────────────────────
    final heavyRain   = rainToday > 25;
    final saturated   = rootMoist  > 0.85;
    final veryWetSoil = (iot?.humidity ?? 0) > 85;
    if (heavyRain && (saturated || veryWetSoil)) {
      alerts.add(FarmAlert(
        category:    AlertCategory.flood,
        severity:    saturated && heavyRain
            ? AlertSeverity.critical : AlertSeverity.high,
        title:       'Flood risk on your farm',
        message:     'Heavy rainfall (${rainToday.toStringAsFixed(0)} mm today) '
                     'combined with ${saturated ? 'saturated root zone' : 'high soil moisture'}. '
                     'Check drainage channels and hold fertiliser — nutrients will wash away.',
        actionLabel: 'Check drainage',
        generatedAt: now,
        source:      hasWeatherStation ? 'weather_station' : 'satellite',
      ));
    }

    // ── 2. DROUGHT RISK ──────────────────────────────────────────────────────
    final noRain7d  = rain7d < 5;
    final drySoil   = rootMoist < 0.20;
    final hotAir    = airTemp > 30;
    final dryIot    = (iot?.humidity ?? 100) < 25;
    if (noRain7d && (drySoil || dryIot) && hotAir) {
      alerts.add(FarmAlert(
        category:    AlertCategory.drought,
        severity:    (drySoil && noRain7d && hotAir)
            ? AlertSeverity.critical : AlertSeverity.high,
        title:       'Drought conditions developing',
        message:     'Only ${rain7d.toStringAsFixed(1)} mm rain in the past 7 days. '
                     'Root zone moisture at ${(rootMoist * 100).toStringAsFixed(0)}%. '
                     'Crop stress likely. Consider emergency irrigation.',
        actionLabel: 'Plan irrigation',
        generatedAt: now,
        source:      'satellite',
      ));
    }

    // ── 3. IRRIGATE NOW ──────────────────────────────────────────────────────
    final lowMoisture  = rootMoist < 0.35;
    final notFlooding  = rainToday < 10;
    final warmEnough   = airTemp > 20;
    // VPD-enhanced: if weather station says high VPD, lower the moisture threshold
    final vpdStress    = vpd > 1.5;
    if (lowMoisture && notFlooding && warmEnough && !noRain7d) {
      alerts.add(FarmAlert(
        category:    AlertCategory.irrigate,
        severity:    (vpdStress && lowMoisture)
            ? AlertSeverity.high : AlertSeverity.warning,
        title:       'Soil moisture is low — consider irrigation',
        message:     'Root zone moisture at ${(rootMoist * 100).toStringAsFixed(0)}% '
                     '(optimal: 40–70%). '
                     '${vpdStress ? 'VPD ${vpd.toStringAsFixed(1)} kPa — crop experiencing active water stress. ' : ''}'
                     'Apply irrigation before the next fertiliser application for best uptake.',
        actionLabel: 'Log irrigation',
        generatedAt: now,
        source:      hasWeatherStation ? 'weather_station+satellite' : 'satellite',
      ));
    }

    // ── 4. FERTILISER NEEDED ─────────────────────────────────────────────────
    if (iot != null) {
      final lowN = iot.n > 0 && iot.n < 15;
      final lowP = iot.p > 0 && iot.p < 8;
      final lowK = iot.k > 0 && iot.k < 80;
      if (lowN || lowP || lowK) {
        final deficient = [
          if (lowN) 'Nitrogen (${iot.n.toStringAsFixed(0)} mg/kg, target >20)',
          if (lowP) 'Phosphorus (${iot.p.toStringAsFixed(0)} mg/kg, target >10)',
          if (lowK) 'Potassium (${iot.k.toStringAsFixed(0)} mg/kg, target >100)',
        ].join(', ');

        // Use weather station to advise on application timing
        final goodToApply = !hasWeatherStation
            ? rootMoist > 0.35
            : (!ws.rainingNow && ws.windSpeed < 5 && ws.humidity < 85);

        alerts.add(FarmAlert(
          category:    AlertCategory.fertilise,
          severity:    (lowN && lowP) ? AlertSeverity.high : AlertSeverity.warning,
          title:       'Soil nutrient deficiency detected',
          message:     'Low: $deficient. '
                       '${goodToApply ? 'Conditions are currently suitable for fertiliser application.' : 'Hold application — conditions not ideal right now (rain or high wind).'}',
          actionLabel: 'View fertiliser plan',
          generatedAt: now,
          source:      'iot_sensor',
        ));
      }
    }

    // ── 5. FUNGAL DISEASE RISK ───────────────────────────────────────────────
    // NuaSense gives us a direct leaf-wetness flag which is more reliable
    // than inferring from dew-point gap alone.
    final dewDiff       = (airTemp - dewPoint).abs();
    final highHumidity  = humidity > 80;
    final warmFungal    = airTemp > 18 && airTemp < 30;
    final dewNearAir    = dewDiff < 4;
    final overcast      = cloudCover > 65;

    // Use direct leaf wetness from station if available; else infer
    final fungalSignal = hasWeatherStation
        ? (leafWet && warmFungal)
        : (highHumidity && warmFungal && (dewNearAir || overcast));

    if (fungalSignal) {
      final sevLevel = (hasWeatherStation && leafWet && dpDepression <= 2)
          || (!hasWeatherStation && dewNearAir)
          ? AlertSeverity.high : AlertSeverity.warning;
      alerts.add(FarmAlert(
        category:    AlertCategory.fungal,
        severity:    sevLevel,
        title:       'High fungal disease risk',
        message:     hasWeatherStation
            ? 'Weather station confirms leaf wetness '
              '(${ws.lwdReason.isNotEmpty ? ws.lwdReason.replaceAll("_", " ") : "sensor"}). '
              'Humidity ${humidity.toStringAsFixed(0)}%, temp ${airTemp.toStringAsFixed(0)}°C. '
              'Conditions ideal for downy mildew, late blight, and grey mould. '
              'Scout crops and consider preventive fungicide.'
            : 'Humidity ${humidity.toStringAsFixed(0)}%, temp ${airTemp.toStringAsFixed(0)}°C, '
              'cloud cover ${cloudCover.toStringAsFixed(0)}%. '
              'Conditions favour fungal disease. Scout crops and consider fungicide.',
        actionLabel: 'Log disease observation',
        generatedAt: now,
        source:      hasWeatherStation ? 'weather_station' : 'satellite',
      ));
    }

    // ── 6. HEAT STRESS ───────────────────────────────────────────────────────
    final highSoilTemp = soilTemp > 36;
    final highAirTempMax = airTempMax > 38;
    final highAirNow   = airTemp > 35;
    if (highSoilTemp || highAirTempMax || highAirNow) {
      alerts.add(FarmAlert(
        category:    AlertCategory.heat,
        severity:    (highSoilTemp && (highAirTempMax || highAirNow))
            ? AlertSeverity.high : AlertSeverity.warning,
        title:       'Heat stress conditions',
        message:     [
          if (highSoilTemp)     'Soil temp ${soilTemp.toStringAsFixed(0)}°C (sensor).',
          if (highAirTempMax)   'Max air temp ${airTempMax.toStringAsFixed(0)}°C (satellite).',
          if (highAirNow && hasWeatherStation)
            'Current station air temp ${airTemp.toStringAsFixed(0)}°C.',
          'Root activity and nutrient uptake may be impaired. '
          'Consider irrigation to cool soil. Avoid spraying midday.',
        ].join(' '),
        actionLabel: 'View crop interventions',
        generatedAt: now,
        source:      hasWeatherStation ? 'weather_station+iot' : 'satellite+iot',
      ));
    }

    // ── 7. SPRAY WINDOW ──────────────────────────────────────────────────────
    final goodWind  = windSpeed < 3;
    final noRainNow = rainToday < 2;
    final daylight  = now.hour >= 6 && now.hour <= 17;
    if (goodWind && noRainNow && daylight) {
      alerts.add(FarmAlert(
        category:    AlertCategory.spray,
        severity:    AlertSeverity.info,
        title:       'Good spray window today',
        message:     'Wind ${windSpeed.toStringAsFixed(1)} m/s — '
                     'safe conditions for pesticide / fungicide application. '
                     '${hasWeatherStation ? 'No rain at station. ' : 'No rain forecast. '}'
                     'Best times: early morning (6–9am) or late afternoon (4–5pm).',
        actionLabel: 'Log intervention',
        generatedAt: now,
        source:      hasWeatherStation ? 'weather_station' : 'satellite',
      ));
    }

    // ── 8. LEAF WETNESS — NuaSense only ─────────────────────────────────────
    // Only add this as a standalone alert if fungal alert wasn't already raised
    // (to avoid duplicate messages for the same underlying condition).
    if (hasWeatherStation && leafWet &&
        !alerts.any((a) => a.category == AlertCategory.fungal)) {
      alerts.add(FarmAlert(
        category:    AlertCategory.leafWetness,
        severity:    dpDepression <= 2
            ? AlertSeverity.high : AlertSeverity.warning,
        title:       'Leaf wetness detected',
        message:     'Station reports wet leaves '
                     '(${ws.lwdReason.isNotEmpty ? ws.lwdReason.replaceAll("_", " ") : "conditions"}). '
                     'Each wet hour extends infection risk window for fungal pathogens. '
                     'Scout crops — especially if leaves have been wet for 4+ consecutive hours.',
        actionLabel: 'Log disease observation',
        generatedAt: now,
        source:      'weather_station',
      ));
    }

    // ── 9. PEST DEGREE-DAY PRESSURE — NuaSense only ──────────────────────────
    if (hasWeatherStation) {
      // Aphid threshold: 0.5 °C·d/hour is moderate; 1.2+ is high
      if (ddAphid >= 0.5) {
        alerts.add(FarmAlert(
          category:    AlertCategory.pestPressure,
          severity:    ddAphid >= 1.2 ? AlertSeverity.high : AlertSeverity.warning,
          title:       'Aphid development conditions — '
                       '${ddAphid >= 1.2 ? "High" : "Moderate"} pressure',
          message:     'Temperature is accumulating aphid degree-days '
                       '(${ddAphid.toStringAsFixed(2)} °C·d this hour, base 4.3°C). '
                       '${ddAphid >= 1.2 ? 'Scout for aphids on growing tips and undersides of leaves. Consider systemic insecticide.' : 'Monitor crops regularly. Check for early aphid colonies.'}',
          actionLabel: 'Log pest observation',
          generatedAt: now,
          source:      'weather_station',
        ));
      }

      // Whitefly threshold: 0.3 moderate; 0.8+ high
      if (ddWhitefly >= 0.3) {
        alerts.add(FarmAlert(
          category:    AlertCategory.pestPressure,
          severity:    ddWhitefly >= 0.8 ? AlertSeverity.high : AlertSeverity.warning,
          title:       'Whitefly development conditions — '
                       '${ddWhitefly >= 0.8 ? "High" : "Moderate"} pressure',
          message:     'Hot dry conditions favour whitefly '
                       '(${ddWhitefly.toStringAsFixed(2)} °C·d this hour, base 10°C). '
                       '${ddWhitefly >= 0.8 ? 'Check leaf undersides for whitefly adults and nymphs.' : 'Warm conditions — monitor for whitefly activity.'}',
          actionLabel: 'Log pest observation',
          generatedAt: now,
          source:      'weather_station',
        ));
      }

      // Potato tuber moth: 0.4 moderate; 1.0+ high
      if (ddPtm >= 0.4) {
        alerts.add(FarmAlert(
          category:    AlertCategory.pestPressure,
          severity:    ddPtm >= 1.0 ? AlertSeverity.high : AlertSeverity.warning,
          title:       'Potato tuber moth conditions — '
                       '${ddPtm >= 1.0 ? "High" : "Moderate"} pressure',
          message:     'Night temperatures are accumulating PTM degree-days '
                       '(${ddPtm.toStringAsFixed(2)} °C·d this hour, base 10.5°C). '
                       '${ddPtm >= 1.0 ? 'Check tubers for entry holes. Ensure good soil cover on potato rows.' : 'Monitor potato crops. Early hilling reduces risk.'}',
          actionLabel: 'Log pest observation',
          generatedAt: now,
          source:      'weather_station',
        ));
      }
    }

    // ── 10. VPD / CROP WATER STRESS — NuaSense only ─────────────────────────
    if (hasWeatherStation && vpd > 2.0) {
      // Only add if drought alert wasn't already raised
      if (!alerts.any((a) => a.category == AlertCategory.drought)) {
        alerts.add(FarmAlert(
          category:    AlertCategory.vpd,
          severity:    vpd > 3.0 ? AlertSeverity.high : AlertSeverity.warning,
          title:       'High crop water stress (VPD ${vpd.toStringAsFixed(1)} kPa)',
          message:     'Vapour pressure deficit is ${vpd.toStringAsFixed(1)} kPa '
                       '${vpd > 3.0 ? '— very high evaporation demand.' : '— moderate water demand.'} '
                       'ET₀ ${et0.toStringAsFixed(2)} mm/h. '
                       '${vpd > 3.0 ? 'Irrigate as soon as possible to prevent wilting. Avoid fertiliser application until stress is relieved.' : 'Consider irrigation if soil moisture is below 40%.'}',
          actionLabel: 'Log irrigation',
          generatedAt: now,
          source:      'weather_station',
        ));
      }
    }

    // Sort: critical first, then high, warning, info
    alerts.sort((a, b) => b.severity.index.compareTo(a.severity.index));
    return alerts;
  }

  // ── Firestore persistence ──────────────────────────────────────────────────

  static Future<void> _persistAlerts(
    List<FarmAlert> alerts, String userId, String county,
  ) async {
    final highPriority = alerts.where((a) =>
        a.severity == AlertSeverity.high ||
        a.severity == AlertSeverity.critical).toList();
    if (highPriority.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    final col   = FirebaseFirestore.instance
        .collection('farm_alerts')
        .doc(userId)
        .collection('alerts');

    // Clear unsent alerts for this county before writing fresh ones
    try {
      final old = await col
          .where('county', isEqualTo: county)
          .where('sent', isEqualTo: false)
          .get();
      for (final doc in old.docs) {
        batch.delete(doc.reference);
      }
    } catch (_) {}

    for (final alert in highPriority) {
      batch.set(col.doc(), alert.toFirestoreMap(userId, county));
    }

    await batch.commit();
  }
}