// lib/settings/notifications/farm_alerts.dart
//
// "Farm Alerts" tab: live condition alerts computed from the farm's IoT soil
// sensor, satellite-derived risk and the NuaSense weather station. Each alert
// records its source and when that source's reading was taken, and the
// result records when the check ran — so every alert is traceable.
//
// An offline station (no readings in the last 2 h) reports placeholder zeros,
// so it contributes no alerts (see NuaSenseReading.hasData).

import 'package:flutter/material.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_actions.dart';
import 'package:kilimomkononi/screens/Field%20Data%20Input/satellite_data_screen.dart'
    show computeConditionRisk, ConditionRisk;
import 'package:kilimomkononi/services/iot_sensor_service.dart';
import 'package:kilimomkononi/services/nuasense_service.dart';

enum FarmAlertSource {
  weatherStation('Weather station', Icons.sensors_rounded),
  iotSensor('Soil sensor', Icons.device_hub_rounded),
  satellite('Satellite', Icons.satellite_alt_rounded);

  final String label;
  final IconData icon;
  const FarmAlertSource(this.label, this.icon);
}

class FarmAlert {
  final String title;
  final String body;
  final ConditionRisk risk;
  final IconData icon;
  final FarmAlertSource source;
  const FarmAlert({
    required this.title,
    required this.body,
    required this.risk,
    required this.icon,
    this.source = FarmAlertSource.satellite,
  });

  /// Which farm sections this alert is about (Soil / Pests / Diseases), so
  /// each section's screen shows its own alerts.
  Set<AdviceSection> get sections {
    final t = title.toLowerCase();
    final out = <AdviceSection>{};
    if (RegExp(r'aphid|whitefly|moth|pest').hasMatch(t)) out.add(AdviceSection.pests);
    if (RegExp(r'fungal|leaf wetness|disease|blight').hasMatch(t)) out.add(AdviceSection.diseases);
    if (RegExp(r'soil|ph |salinity|drought|water stress|waterlogging|flood|heat|leaching|fertiliser').hasMatch(t)) {
      out.add(AdviceSection.soil);
    }
    if (t.contains('spray window')) out.addAll({AdviceSection.pests, AdviceSection.diseases});
    return out;
  }
}

class FarmAlertsResult {
  final List<FarmAlert> alerts;

  /// When this check ran.
  final DateTime checkedAt;

  /// When each source's reading was taken (null = source not available).
  final Map<FarmAlertSource, DateTime?> readingTimes;

  const FarmAlertsResult({required this.alerts, required this.checkedAt, required this.readingTimes});

  DateTime? readingTimeFor(FarmAlertSource s) => readingTimes[s];
}

String riskLabel(ConditionRisk r) => switch (r) {
      ConditionRisk.critical => 'Critical',
      ConditionRisk.high => 'High',
      ConditionRisk.moderate => 'Moderate',
      ConditionRisk.low => 'Low',
    };

/// Fetches the sources and computes the alerts (most severe first).
/// [stationId]: the station the farmer is looking at (default: their first).
Future<FarmAlertsResult> loadFarmAlerts({String? stationId}) async {
  IotSensorReading? iot;
  NuaSenseReading? ws;
  await Future.wait([
    IotSensorService.getReadingForFarm()
        .then<IotSensorReading?>((r) => iot = r)
        .catchError((_) => null),
    NuaSenseService.getLatestReading(stationId: stationId)
        .then<NuaSenseReading?>((r) => ws = r)
        .catchError((_) => null),
  ]);
  // Offline / not installed → no station alerts from placeholder values.
  if (ws != null && (!ws!.isProvisioned || !ws!.hasData)) ws = null;
  return computeFarmAlerts(iot: iot, ws: ws, checkedAt: DateTime.now());
}

/// Pure alert rules (unit-tested).
FarmAlertsResult computeFarmAlerts({IotSensorReading? iot, NuaSenseReading? ws, required DateTime checkedAt}) {
  final risk  = computeConditionRisk(sat: null, iot: iot, rain7d: 0);
  final items = <FarmAlert>[];

  // ──────────────────────────────────────────────────────────────────
  // A) IoT-sensor alerts  (soil temperature, soil humidity)
  // ──────────────────────────────────────────────────────────────────
  if (iot != null) {
    // Soil heat stress
    if (iot.temperature > 36) {
      items.add(FarmAlert(
        title:  'Soil Heat Stress — Critical',
        body:   'Soil sensor reads ${iot.temperature.toStringAsFixed(1)}°C — '
                'above 36°C root growth halts and fine roots begin to die. '
                'Irrigate immediately and mulch to cool the soil.',
        risk:   ConditionRisk.critical,
        icon:   Icons.thermostat_outlined,
        source: FarmAlertSource.iotSensor,
      ));
    } else if (iot.temperature > 32) {
      items.add(FarmAlert(
        title:  'Soil Temperature Elevated — High',
        body:   'Soil at ${iot.temperature.toStringAsFixed(1)}°C. '
                'Water in early morning to cool the root zone before peak heat.',
        risk:   ConditionRisk.high,
        icon:   Icons.thermostat_outlined,
        source: FarmAlertSource.iotSensor,
      ));
    }

    // Soil pH extreme — if available (some IoT models include pH)
    final ph = iot.ph;
    if (ph > 0) {
      if (ph < 5.0) {
        items.add(FarmAlert(
          title:  'Soil pH Too Acidic — pH ${ph.toStringAsFixed(1)}',
          body:   'Soil pH ${ph.toStringAsFixed(1)} is below 5.0. '
                  'Most crops struggle below 5.5 — lime application is recommended. '
                  'Phosphorus and many micro-nutrients become unavailable at low pH.',
          risk:   ConditionRisk.high,
          icon:   Icons.science_outlined,
          source: FarmAlertSource.iotSensor,
        ));
      } else if (ph > 8.0) {
        items.add(FarmAlert(
          title:  'Soil pH Too Alkaline — pH ${ph.toStringAsFixed(1)}',
          body:   'Soil pH ${ph.toStringAsFixed(1)} is above 8.0. '
                  'Iron, manganese and zinc deficiencies are common at high pH. '
                  'Consider sulphur application or acidifying fertilisers.',
          risk:   ConditionRisk.moderate,
          icon:   Icons.science_outlined,
          source: FarmAlertSource.iotSensor,
        ));
      }
    }

    // EC (electrical conductivity) — salinity / over-fertilisation risk
    final ec = iot.ec;
    if (ec > 4.0) {
      items.add(FarmAlert(
        title:  'Soil Salinity High — EC ${ec.toStringAsFixed(1)} µS/cm',
        body:   'High electrical conductivity suggests salt build-up or '
                'excess fertiliser residue. Flush with clean water and reduce '
                'fertiliser until EC drops below 2.0 µS/cm.',
        risk:   ConditionRisk.high,
        icon:   Icons.water_damage_outlined,
        source: FarmAlertSource.iotSensor,
      ));
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // B) Satellite-derived / IoT-combo alerts (existing computeConditionRisk)
  // ──────────────────────────────────────────────────────────────────
  if (risk.fungalRisk != ConditionRisk.low) {
    items.add(FarmAlert(
      title:  'Fungal Disease Risk — ${riskLabel(risk.fungalRisk)}',
      body:   risk.fungalMessage,
      risk:   risk.fungalRisk,
      icon:   Icons.science_outlined,
      source: FarmAlertSource.iotSensor,
    ));
  }
  if (risk.droughtRisk != ConditionRisk.low) {
    items.add(FarmAlert(
      title:  'Drought / Dry Stress — ${riskLabel(risk.droughtRisk)}',
      body:   risk.droughtMessage,
      risk:   risk.droughtRisk,
      icon:   Icons.wb_sunny_outlined,
      source: FarmAlertSource.iotSensor,
    ));
  }
  if (risk.floodRisk != ConditionRisk.low) {
    final msg = risk.floodRisk == ConditionRisk.critical
        ? 'Severe waterlogging risk. Check drainage channels and raised beds immediately.'
        : risk.floodRisk == ConditionRisk.high
            ? 'High waterlogging likelihood. Ensure adequate field drainage.'
            : 'Moderate flood / waterlogging risk. Monitor low-lying areas.';
    items.add(FarmAlert(
      title:  'Waterlogging / Flood Risk — ${riskLabel(risk.floodRisk)}',
      body:   msg,
      risk:   risk.floodRisk,
      icon:   Icons.water_outlined,
      source: FarmAlertSource.satellite,
    ));
  }
  if (risk.heatRisk != ConditionRisk.low) {
    final msg = risk.heatRisk == ConditionRisk.high
        ? 'Soil temperature above 36 °C. High risk of root damage — irrigate and mulch.'
        : 'Elevated heat stress. Irrigate during cooler morning/evening hours.';
    items.add(FarmAlert(
      title:  'Heat Stress — ${riskLabel(risk.heatRisk)}',
      body:   msg,
      risk:   risk.heatRisk,
      icon:   Icons.thermostat_outlined,
      source: FarmAlertSource.satellite,
    ));
  }

  // ──────────────────────────────────────────────────────────────────
  // C) NuaSense weather-station alerts
  // ──────────────────────────────────────────────────────────────────
  if (ws != null) {
    // Spray window
    final goodWind = ws.goodSprayWind;
    final noRain   = !ws.rainingNow;
    final hour     = DateTime.now().hour;
    final inWindow = hour >= 6 && hour <= 17;
    final canSpray = goodWind && noRain && inWindow;
    if (!canSpray) {
      final reason = !goodWind
          ? 'Wind ${ws.windSpeed.toStringAsFixed(1)} m/s — too high (need < 3 m/s). Drift will waste product and harm bees.'
          : !noRain
              ? 'Currently raining — product washes off before it can work. Wait 2+ dry hours.'
              : 'Outside safe spray hours (6am–5pm). Spray early morning for best results.';
      items.add(FarmAlert(
        title:  'Spray Window — Do Not Spray Yet',
        body:   reason,
        risk:   ConditionRisk.moderate,
        icon:   Icons.air_outlined,
        source: FarmAlertSource.weatherStation,
      ));
    }

    // Leaf wetness — disease trigger alert
    if (ws.leafIsWet) {
      final wetReason = ws.lwdReason.isNotEmpty
          ? ws.lwdReason.replaceAll('_', ' ')
          : 'high humidity / dew';
      items.add(FarmAlert(
        title:  'Leaf Wetness Alert — Fungal Infection Risk',
        body:   'Station reports wet leaves ($wetReason). '
                'Fungal spores germinate when leaves are wet for 4+ consecutive hours. '
                'Scout for blight, mildew, rust today. '
                'Do not spray foliar products while leaves are wet.',
        risk:   ws.dewPointDepression <= 2
            ? ConditionRisk.critical
            : ConditionRisk.high,
        icon:   Icons.water_drop_rounded,
        source: FarmAlertSource.weatherStation,
      ));
    }

    // VPD / crop water stress
    if (ws.vpd > 2.5) {
      items.add(FarmAlert(
        title:  'Crop Water Stress — Severe (VPD ${ws.vpd.toStringAsFixed(1)} kPa)',
        body:   'Very high evaporation demand. Crops are losing water faster than '
                'roots can supply it — wilting, tip-burn and fruit drop likely. '
                'Irrigate immediately, preferably by drip or furrow to avoid wetting leaves.',
        risk:   ConditionRisk.critical,
        icon:   Icons.eco_outlined,
        source: FarmAlertSource.weatherStation,
      ));
    } else if (ws.vpd > 1.8) {
      items.add(FarmAlert(
        title:  'Crop Water Stress — Moderate (VPD ${ws.vpd.toStringAsFixed(1)} kPa)',
        body:   'High evaporation demand. Check soil moisture — if dry, '
                'irrigate within the next 12 hours.',
        risk:   ConditionRisk.moderate,
        icon:   Icons.eco_outlined,
        source: FarmAlertSource.weatherStation,
      ));
    }

    // High humidity + warm = disease alert
    if (ws.humidity > 85 && ws.airTemp > 18 && ws.airTemp < 30) {
      items.add(FarmAlert(
        title:  'High Fungal Disease Risk — Hot & Humid',
        body:   'Humidity ${ws.humidity.toStringAsFixed(0)}% at ${ws.airTemp.toStringAsFixed(1)}°C '
                '— ideal conditions for late blight (tomatoes, potatoes), '
                'grey leaf spot (maize) and downy mildew (beans, kales). '
                'Apply preventive fungicide at next safe spray window.',
        risk:   ConditionRisk.high,
        icon:   Icons.coronavirus_outlined,
        source: FarmAlertSource.weatherStation,
      ));
    }

    // Pest pressure from degree-days
    if (ws.ddAphidHour >= 1.2) {
      items.add(FarmAlert(
        title:  'Aphid Pressure — High',
        body:   'High temperature-based aphid development index today '
                '(base 4.3°C). Scout maize, beans, tomatoes and cabbages '
                'for colonies on growing tips and undersides of young leaves. '
                'Consider spraying if colonies found on >10% of plants.',
        risk:   ConditionRisk.high,
        icon:   Icons.bug_report_outlined,
        source: FarmAlertSource.weatherStation,
      ));
    } else if (ws.ddAphidHour >= 0.5) {
      items.add(FarmAlert(
        title:  'Aphid Pressure — Medium',
        body:   'Moderate aphid development conditions. Scout crops '
                'and note populations — intervene if numbers are rising.',
        risk:   ConditionRisk.moderate,
        icon:   Icons.bug_report_outlined,
        source: FarmAlertSource.weatherStation,
      ));
    }

    if (ws.ddWhiteflyHour >= 0.8) {
      items.add(FarmAlert(
        title:  'Whitefly Pressure — High',
        body:   'Hot conditions are accelerating whitefly development '
                '(base 10°C). Check tomatoes, beans and kales for adults '
                'on leaf undersides and sticky honeydew residue. '
                'Yellow sticky traps help monitor populations.',
        risk:   ConditionRisk.high,
        icon:   Icons.pest_control_outlined,
        source: FarmAlertSource.weatherStation,
      ));
    }

    if (ws.ddPtmHour >= 1.0) {
      items.add(FarmAlert(
        title:  'Potato Tuber Moth — High Pressure',
        body:   'Warm temperatures are accelerating potato tuber moth '
                'development. Check potato and tomato plants for larvae '
                'mining leaves and tubers. Hill up potatoes to prevent '
                'egg-laying on exposed tubers.',
        risk:   ConditionRisk.high,
        icon:   Icons.pest_control_rodent_outlined,
        source: FarmAlertSource.weatherStation,
      ));
    }

    // Heavy rain + fertiliser leaching risk
    if (ws.rainfall > 20) {
      items.add(FarmAlert(
        title:  'Heavy Rain — Fertiliser Leaching Risk',
        body:   '${ws.rainfall.toStringAsFixed(1)} mm of rain recorded. '
                'Nitrogen (especially urea) leaches quickly after heavy rain. '
                'Wait until soil drains before applying fertiliser again. '
                'Check for waterlogging in low-lying plots.',
        risk:   ConditionRisk.moderate,
        icon:   Icons.grain_rounded,
        source: FarmAlertSource.weatherStation,
      ));
    }
  }

  // No alerts from spray-window satellite path (already handled by WS above)
  // but keep for when WS is offline:
  if (ws == null && !risk.goodSprayWindow) {
    items.add(FarmAlert(
      title:  'Spray Window — Poor Conditions',
      body:   risk.sprayMessage,
      risk:   ConditionRisk.moderate,
      icon:   Icons.air_outlined,
      source: FarmAlertSource.satellite,
    ));
  }

  // Sort: critical → high → moderate; weather station alerts first within each tier
  items.sort((a, b) {
    final rc = b.risk.index.compareTo(a.risk.index);
    if (rc != 0) return rc;
    return a.source.index.compareTo(b.source.index);
  });

  return FarmAlertsResult(
    alerts: items,
    checkedAt: checkedAt,
    readingTimes: {
      FarmAlertSource.weatherStation: ws?.timestamp,
      FarmAlertSource.iotSensor: iot?.timestamp,
      FarmAlertSource.satellite: checkedAt,
    },
  );
}
