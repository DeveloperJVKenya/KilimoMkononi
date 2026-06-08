// lib/services/farm_alert_service.dart
//
// Generates proactive farm alerts from IoT sensor + satellite data.
//
// ── HOW ALERTS WORK ────────────────────────────────────────────────────────
//
// The farmer NEVER has to open a section to check for alerts.
// FarmAlertService is called from two places:
//
//   1. App startup / home page (field_data_input_home_page.dart)
//      → Shows a badge/banner if critical alerts are active
//
//   2. Firebase Cloud Functions scheduled job (every 6 hours)
//      → Sends FCM push notifications for high/critical alerts
//      → This runs even when the app is closed
//
// Alert categories:
//   🌧  FLOOD RISK     — heavy rainfall + saturated root zone
//   ☀️  DROUGHT         — no rain + dry soil + high temp
//   💧  IRRIGATE NOW   — soil moisture below threshold for crop stage
//   🌱  FERTILISE      — N/P/K below critical thresholds
//   🍄  FUNGAL RISK    — high humidity + warm temp + dew point near air temp
//   🌡  HEAT STRESS    — soil/air temp above crop threshold
//   💨  SPRAY WINDOW   — wind < 3 m/s + no rain → safe to spray today
//
// ── FIRESTORE ALERT PERSISTENCE ────────────────────────────────────────────
//
// Alerts are also written to Firestore so the Cloud Function can send
// FCM push notifications:
//
//   farm_alerts/{userId}/alerts/{alertId}
//   {
//     userId:       "uid",
//     county:       "Nakuru",
//     category:     "drought",
//     severity:     "critical",
//     title:        "Drought risk",
//     message:      "...",
//     createdAt:    Timestamp,
//     sent:         false,    ← Cloud Function sets true after FCM send
//   }

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kilimomkononi/services/iot_sensor_service.dart';
import 'package:kilimomkononi/services/nasa_power_service.dart';
import 'package:kilimomkononi/services/farm_location_service.dart';

// ── Models ─────────────────────────────────────────────────────────────────

enum AlertSeverity { info, warning, high, critical }
enum AlertCategory { flood, drought, irrigate, fertilise, fungal, heat, spray }

class FarmAlert {
  final AlertCategory category;
  final AlertSeverity severity;
  final String title;
  final String message;
  final String actionLabel;
  final DateTime generatedAt;

  const FarmAlert({
    required this.category,
    required this.severity,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.generatedAt,
  });

  Map<String, dynamic> toFirestoreMap(String userId, String county) => {
    'userId':     userId,
    'county':     county,
    'category':   category.name,
    'severity':   severity.name,
    'title':      title,
    'message':    message,
    'createdAt':  Timestamp.fromDate(generatedAt),
    'sent':       false,
  };
}

// ── Service ────────────────────────────────────────────────────────────────

class FarmAlertService {
  FarmAlertService._();

  /// Evaluates current IoT + satellite data and returns all active alerts.
  /// Also persists high/critical alerts to Firestore for push notification.
  static Future<List<FarmAlert>> evaluateAlerts() async {
    IotSensorReading? iot;
    SatelliteReading? sat;
    List<SatelliteReading> history = [];

    try { iot     = await IotSensorService.getReadingForFarm(); } catch (_) {}
    try { sat     = await NasaPowerService.getToday(); } catch (_) {}
    try { history = await NasaPowerService.getHistory(days: 7); } catch (_) {}

    final rain7d = SatelliteReading.totalPrecipitation(history);
    final alerts  = _compute(iot, sat, rain7d);

    // Persist high/critical to Firestore for FCM
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final location = await FarmLocationService.getLocation();
    if (uid != null) {
      await _persistAlerts(alerts, uid, location.county);
    }

    return alerts;
  }

  // ── Alert computation ──────────────────────────────────────────────────────

  static List<FarmAlert> _compute(
    IotSensorReading? iot,
    SatelliteReading? sat,
    double rain7d,
  ) {
    final now    = DateTime.now();
    final alerts = <FarmAlert>[];

    // ── 1. FLOOD RISK ────────────────────────────────────────────────────────
    final heavyRain   = (sat?.precipitation ?? 0) > 25;           // > 25mm today
    final saturated   = (sat?.rootZoneMoisture ?? 0) > 0.85;
    final veryWetSoil = (iot?.humidity ?? 0) > 85;
    if (heavyRain && (saturated || veryWetSoil)) {
      alerts.add(FarmAlert(
        category:    AlertCategory.flood,
        severity:    saturated && heavyRain ? AlertSeverity.critical : AlertSeverity.high,
        title:       'Flood risk on your farm',
        message:     'Heavy rainfall (${sat?.precipitation.toStringAsFixed(0)} mm today) '
                     'combined with ${saturated ? 'saturated root zone' : 'high soil moisture'} '
                     '(${(sat?.rootZoneMoisture ?? 0 * 100).toStringAsFixed(0)}%). '
                     'Check drainage channels and avoid applying fertiliser — nutrients will wash away.',
        actionLabel: 'Check drainage',
        generatedAt: now,
      ));
    }

    // ── 2. DROUGHT RISK ──────────────────────────────────────────────────────
    final noRain    = rain7d < 5;
    final drySoil   = (sat?.rootZoneMoisture ?? 1) < 0.20;
    final hotAir    = (sat?.airTemp ?? 0) > 30;
    final dryIot    = (iot?.humidity ?? 100) < 25;
    if (noRain && (drySoil || dryIot) && hotAir) {
      alerts.add(FarmAlert(
        category:    AlertCategory.drought,
        severity:    (drySoil && noRain && hotAir) ? AlertSeverity.critical : AlertSeverity.high,
        title:       'Drought conditions developing',
        message:     'Only ${rain7d.toStringAsFixed(1)} mm rain in the past 7 days. '
                     'Root zone moisture at ${((sat?.rootZoneMoisture ?? 0) * 100).toStringAsFixed(0)}%. '
                     'Crop stress likely. Consider emergency irrigation.',
        actionLabel: 'Plan irrigation',
        generatedAt: now,
      ));
    }

    // ── 3. IRRIGATE NOW ──────────────────────────────────────────────────────
    final lowMoisture = (sat?.rootZoneMoisture ?? 1) < 0.35;
    final notFlooding = (sat?.precipitation ?? 0) < 10;
    final warmEnough  = (sat?.airTemp ?? 0) > 20;
    if (lowMoisture && notFlooding && warmEnough && !noRain) {
      // Separate from drought — soil is just getting dry, not critically so
      alerts.add(FarmAlert(
        category:    AlertCategory.irrigate,
        severity:    AlertSeverity.warning,
        title:       'Soil moisture is low — consider irrigation',
        message:     'Root zone moisture is at ${((sat?.rootZoneMoisture ?? 0) * 100).toStringAsFixed(0)}% '
                     '(optimal: 40–70%). '
                     'Apply irrigation before the next fertiliser application for best uptake.',
        actionLabel: 'Log irrigation',
        generatedAt: now,
      ));
    }

    // ── 4. FERTILISER NEEDED ─────────────────────────────────────────────────
    if (iot != null) {
      final lowN = iot.n > 0 && iot.n < 15;
      final lowP = iot.p > 0 && iot.p < 8;
      final lowK = iot.k > 0 && iot.k < 80;
      if (lowN || lowP || lowK) {
        final deficient = [
          if (lowN) 'Nitrogen (N: ${iot.n.toStringAsFixed(0)} mg/kg, target >20)',
          if (lowP) 'Phosphorus (P: ${iot.p.toStringAsFixed(0)} mg/kg, target >10)',
          if (lowK) 'Potassium (K: ${iot.k.toStringAsFixed(0)} mg/kg, target >100)',
        ].join(', ');
        alerts.add(FarmAlert(
          category:    AlertCategory.fertilise,
          severity:    (lowN && lowP) ? AlertSeverity.high : AlertSeverity.warning,
          title:       'Soil nutrient deficiency detected',
          message:     'Sensor readings indicate low: $deficient. '
                       '${(sat?.rootZoneMoisture ?? 0) > 0.35 ? 'Soil moisture is adequate for fertiliser application.' : 'Irrigate first to improve uptake.'}',
          actionLabel: 'View fertiliser plan',
          generatedAt: now,
        ));
      }
    }

    // ── 5. FUNGAL DISEASE RISK ───────────────────────────────────────────────
    final highHumidity  = (sat?.humidity ?? 0) > 80 || (iot?.humidity ?? 0) > 80;
    final warmFungal    = (sat?.airTemp ?? 0) > 18 && (sat?.airTemp ?? 0) < 30;
    final dewNearAir    = ((sat?.airTemp ?? 99) - (sat?.dewPoint ?? 0)).abs() < 4;
    final overcast      = (sat?.cloudCover ?? 0) > 65;
    if (highHumidity && warmFungal && (dewNearAir || overcast)) {
      alerts.add(FarmAlert(
        category:    AlertCategory.fungal,
        severity:    dewNearAir ? AlertSeverity.high : AlertSeverity.warning,
        title:       'High fungal disease risk',
        message:     'Humidity ${(sat?.humidity ?? iot?.humidity ?? 0).toStringAsFixed(0)}%, '
                     'temp ${sat?.airTemp.toStringAsFixed(0)}°C, '
                     'cloud cover ${sat?.cloudCover.toStringAsFixed(0)}%. '
                     'Conditions are ideal for downy mildew, late blight, and grey mould. '
                     'Scout crops and consider preventive fungicide.',
        actionLabel: 'Log disease observation',
        generatedAt: now,
      ));
    }

    // ── 6. HEAT STRESS ───────────────────────────────────────────────────────
    final highSoilTemp = (iot?.temperature ?? 0) > 36;
    final highAirTemp  = (sat?.airTempMax ?? 0) > 38;
    if (highSoilTemp || highAirTemp) {
      alerts.add(FarmAlert(
        category:    AlertCategory.heat,
        severity:    (highSoilTemp && highAirTemp) ? AlertSeverity.high : AlertSeverity.warning,
        title:       'Heat stress conditions',
        message:     [
          if (highSoilTemp) 'Soil temperature ${iot?.temperature.toStringAsFixed(0)}°C (sensor).',
          if (highAirTemp)  'Max air temp ${sat?.airTempMax.toStringAsFixed(0)}°C today.',
          'Root activity and nutrient uptake may be impaired. Consider shade or irrigation to cool soil.',
        ].join(' '),
        actionLabel: 'View crop interventions',
        generatedAt: now,
      ));
    }

    // ── 7. SPRAY WINDOW (positive alert) ────────────────────────────────────
    final goodWind  = (sat?.windSpeed ?? 99) < 3;
    final noRainNow = (sat?.precipitation ?? 99) < 2;
    final daylight  = DateTime.now().hour >= 6 && DateTime.now().hour <= 17;
    if (goodWind && noRainNow && daylight) {
      alerts.add(FarmAlert(
        category:    AlertCategory.spray,
        severity:    AlertSeverity.info,
        title:       'Good spray window today',
        message:     'Wind speed ${sat?.windSpeed.toStringAsFixed(1)} m/s — '
                     'safe conditions for pesticide/fungicide application. '
                     'No rain forecast. Best time: early morning or late afternoon.',
        actionLabel: 'Log intervention',
        generatedAt: now,
      ));
    }

    // Sort: critical first, then high, warning, info
    alerts.sort((a, b) => b.severity.index.compareTo(a.severity.index));
    return alerts;
  }

  // ── Firestore persistence ──────────────────────────────────────────────────

  static Future<void> _persistAlerts(
    List<FarmAlert> alerts, String userId, String county,
  ) async {
    final highPriority = alerts.where(
      (a) => a.severity == AlertSeverity.high || a.severity == AlertSeverity.critical,
    ).toList();

    if (highPriority.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    final col   = FirebaseFirestore.instance
        .collection('farm_alerts')
        .doc(userId)
        .collection('alerts');

    // Delete yesterday's alerts for this county before writing new ones
    final old = await col
        .where('county', isEqualTo: county)
        .where('sent', isEqualTo: false)
        .get();
    for (final doc in old.docs) {
      batch.delete(doc.reference);
    }

    for (final alert in highPriority) {
      batch.set(col.doc(), alert.toFirestoreMap(userId, county));
    }

    await batch.commit();
  }
}