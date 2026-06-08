// lib/widgets/farm_environment_card.dart
//
// A self-contained card widget that displays IoT + satellite data
// for the farmer's registered location.
//
// ── PLACEMENT ─────────────────────────────────────────────────────────────
//
//   field_data_input_home_page.dart  → after _sectionLabel('Quick access')
//                                       shows soil health overview + alerts
//
//   plot_input_form.dart  Step 2     → above the NPK row
//                                       shows sensor tiles + auto-fills fields
//
//   pest_management.dart  Step 0     → above crop selector
//                                       shows risk panel
//
//   disease_management_page.dart Step 0 → above crop selector
//                                          shows risk panel
//
// ── HOW IT WORKS FOR THE FARMER ───────────────────────────────────────────
//
// The farmer opens any of these pages and the card is ALREADY there —
// no button to press, no section to navigate to.
// It shows a loading skeleton for ~2 seconds while data fetches,
// then displays the live data for THEIR farm county.
//
// Data is location-specific:
//   Nakuru farmer → Nakuru IoT sensor + Nakuru NASA POWER coordinates
//   Mombasa farmer → Mombasa IoT sensor + Mombasa NASA POWER coordinates
//
// ── MODE ──────────────────────────────────────────────────────────────────
//
//   FarmEnvironmentCardMode.soilSummary
//     - IoT NPK tiles (colour-coded low/good/high)
//     - pH, EC, soil temp tiles
//     - Satellite: root moisture, 7-day rain, PAR, soil temp
//     - Calls onIotLoaded so parent can auto-fill NPK controllers
//
//   FarmEnvironmentCardMode.pestRisk
//     - Collapsible risk banner (tap to expand)
//     - Risk cards for active conditions
//     - Live conditions chip row

// ignore_for_file: unused_local_variable, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:kilimomkononi/services/farm_location_service.dart';
import 'package:kilimomkononi/services/iot_sensor_service.dart';
import 'package:kilimomkononi/services/nasa_power_service.dart';
import 'package:kilimomkononi/services/farm_alert_service.dart';

enum FarmEnvironmentCardMode { soilSummary, pestRisk }

class FarmEnvironmentCard extends StatefulWidget {
  final FarmEnvironmentCardMode mode;

  /// [soilSummary] mode only — called when IoT data loads so the parent
  /// form can pre-fill NPK TextEditingControllers.
  final void Function(IotSensorReading reading)? onIotLoaded;

  const FarmEnvironmentCard({
    required this.mode,
    this.onIotLoaded,
    super.key,
  });

  @override
  State<FarmEnvironmentCard> createState() => _FarmEnvironmentCardState();
}

class _FarmEnvironmentCardState extends State<FarmEnvironmentCard> {
  static const _green      = Color(0xFF1B5E20);
  static const _accentGreen= Color(0xFF2A6B2A);
  static const _cardBg     = Color(0xFFF7F8F6);
  static const _border     = Color(0xFFBBBFBA);

  bool _loading  = true;
  String? _error;
  bool _expanded = false;

  FarmLocation?          _location;
  IotSensorReading?      _iot;
  SatelliteReading?      _sat;
  List<SatelliteReading> _history = [];
  List<FarmAlert>        _alerts  = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        FarmLocationService.getLocation(),
        IotSensorService.getReadingForFarm(),
        NasaPowerService.getToday(),
        NasaPowerService.getHistory(days: 7),
      ]);

      final location = results[0] as FarmLocation;
      final iot      = results[1] as IotSensorReading;
      final sat      = results[2] as SatelliteReading?;
      final history  = results[3] as List<SatelliteReading>;

      // Compute alerts (uses cached data — no extra network calls)
      final alerts = await FarmAlertService.evaluateAlerts();

      if (!mounted) return;
      setState(() {
        _location = location;
        _iot      = iot;
        _sat      = sat;
        _history  = history;
        _alerts   = alerts;
        _loading  = false;
      });

      if (widget.mode == FarmEnvironmentCardMode.soilSummary) {
        widget.onIotLoaded?.call(iot);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = '$e'; _loading = false; });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) return _skeleton();
    if (_error != null)  return _errorCard();
    return widget.mode == FarmEnvironmentCardMode.soilSummary
        ? _soilCard()
        : _pestRiskCard();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SOIL SUMMARY MODE
  // ══════════════════════════════════════════════════════════════════════════

  Widget _soilCard() {
    final iot = _iot!;
    final sat = _sat;
    final rain7d = SatelliteReading.totalPrecipitation(_history);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Source banner ────────────────────────────────────────────────────
        _sourceBanner(iot),
        const SizedBox(height: 8),

        // ── NPK tiles ────────────────────────────────────────────────────────
        Row(children: [
          _nutrientTile('N', iot.n, 20, 40, 'mg/kg'),
          const SizedBox(width: 8),
          _nutrientTile('P', iot.p, 10, 30, 'mg/kg'),
          const SizedBox(width: 8),
          _nutrientTile('K', iot.k, 100, 200, 'mg/kg'),
        ]),
        const SizedBox(height: 8),

        // ── Other IoT tiles ──────────────────────────────────────────────────
        Row(children: [
          _valueTile('pH',    iot.ph,          5.5, 7.5, '',       decimals: 2),
          const SizedBox(width: 8),
          _valueTile('EC',    iot.ec,          0,   999, 'µs/cm'),
          const SizedBox(width: 8),
          _valueTile('Soil °C', iot.temperature, 0, 34, '°C',     decimals: 1, invertLogic: true),
        ]),

        // ── Satellite card ───────────────────────────────────────────────────
        if (sat != null) ...[
          const SizedBox(height: 8),
          _satCard(sat, rain7d),
        ],

        // ── Alert strip ─────────────────────────────────────────────────────
        if (_alerts.isNotEmpty) ...[
          const SizedBox(height: 8),
          _alertStrip(),
        ],
      ],
    );
  }

  Widget _sourceBanner(IotSensorReading iot) {
    final isLive = iot.source == IotDataSource.firestore;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEDF7ED),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _accentGreen.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Row(children: [
        Icon(isLive ? Icons.sensors : Icons.sensors_outlined,
            size: 13, color: _accentGreen),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 11, color: Color(0xFF1B5E20)),
              children: [
                TextSpan(
                  text: isLive ? 'Live sensor · ' : 'Simulated sensor · ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: '${iot.nodeLabel} · '),
                TextSpan(
                  text: _location!.displayLabel,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
        GestureDetector(
          onTap: () { setState(() { _loading = true; _error = null; }); _load(); },
          child: const Icon(Icons.refresh, size: 13, color: Color(0xFF2A6B2A)),
        ),
      ]),
    );
  }

  Widget _satCard(SatelliteReading sat, double rain7d) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFFEDF4FB),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.2)),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.satellite_alt_rounded, size: 12, color: Color(0xFF1565C0)),
        const SizedBox(width: 5),
        const Text('Satellite data — NASA POWER',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: Color(0xFF1565C0))),
        const Spacer(),
        Text(_location!.county,
            style: const TextStyle(fontSize: 10, color: Color(0xFF1565C0))),
        if (sat.isStale)
          const Text('  (cached)', style: TextStyle(fontSize: 10, color: Colors.orange)),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        _miniStat('Root moisture',
            '${(sat.rootZoneMoisture * 100).toStringAsFixed(0)}%',
            sat.rootZoneMoisture > 0.4),
        _miniStat('7-day rain',
            '${rain7d.toStringAsFixed(1)} mm',
            rain7d > 10),
        _miniStat('PAR today',
            '${sat.par.toStringAsFixed(0)} W/m²',
            sat.par > 15),
        _miniStat('Soil temp (sat)',
            '${sat.soilTempLayer1.toStringAsFixed(0)}°C',
            sat.soilTempLayer1 < 35),
      ]),
    ]),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // PEST RISK MODE
  // ══════════════════════════════════════════════════════════════════════════

  Widget _pestRiskCard() {
    final criticalAlerts = _alerts.where(
      (a) => a.severity == AlertSeverity.high || a.severity == AlertSeverity.critical,
    ).toList();
    final hasRisk = criticalAlerts.isNotEmpty;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Banner ─────────────────────────────────────────────────────────────
      GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Container(
          decoration: BoxDecoration(
            color: hasRisk ? const Color(0xFFFFF8E1) : const Color(0xFFEDF7ED),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasRisk
                  ? const Color(0xFFE65100).withOpacity(0.3)
                  : _green.withOpacity(0.25),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Icon(
              hasRisk ? Icons.warning_amber_rounded : Icons.check_circle_outline,
              size: 18,
              color: hasRisk ? const Color(0xFFE65100) : _accentGreen,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasRisk
                    ? '${criticalAlerts.length} risk condition${criticalAlerts.length > 1 ? 's' : ''} '
                      'active on your farm · ${_location?.county}'
                    : 'No high-risk conditions on your farm today · ${_location?.county}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: hasRisk ? const Color(0xFFE65100) : _accentGreen,
                ),
              ),
            ),
            Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                size: 18, color: Colors.black45),
          ]),
        ),
      ),

      // ── Expanded detail ────────────────────────────────────────────────────
      if (_expanded) ...[
        const SizedBox(height: 8),
        ..._alerts.map((a) => _alertCard(a)),
        const SizedBox(height: 8),
        _conditionsChips(),
      ],
    ]);
  }

  Widget _alertStrip() {
    final critical = _alerts.where(
      (a) => a.severity == AlertSeverity.high || a.severity == AlertSeverity.critical,
    ).toList();
    if (critical.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE65100).withOpacity(0.3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.warning_amber_rounded, size: 13, color: Color(0xFFE65100)),
          const SizedBox(width: 5),
          Text('${critical.length} active alert${critical.length > 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: Color(0xFFE65100))),
        ]),
        const SizedBox(height: 4),
        ...critical.map((a) => Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text('• ${a.title}',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFFBF360C))),
        )),
      ]),
    );
  }

  Widget _alertCard(FarmAlert alert) {
    final Color bg, border, iconColor;
    IconData icon;
    switch (alert.severity) {
      case AlertSeverity.critical:
        bg = const Color(0xFFFFEBEE); border = const Color(0xFFB71C1C);
        iconColor = const Color(0xFFB71C1C); icon = Icons.dangerous_rounded;
      case AlertSeverity.high:
        bg = const Color(0xFFFFF3E0); border = const Color(0xFFE65100);
        iconColor = const Color(0xFFE65100); icon = Icons.warning_rounded;
      case AlertSeverity.warning:
        bg = const Color(0xFFFFF8E1); border = const Color(0xFFF57F17);
        iconColor = const Color(0xFFF57F17); icon = Icons.info_outline_rounded;
      case AlertSeverity.info:
        bg = const Color(0xFFE8F5E9); border = const Color(0xFF2E7D32);
        iconColor = _green; icon = Icons.check_circle_outline_rounded;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(alert.title,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: iconColor)),
          const SizedBox(height: 3),
          Text(alert.message,
              style: const TextStyle(fontSize: 11.5, color: Colors.black54, height: 1.4)),
        ])),
      ]),
    );
  }

  Widget _conditionsChips() => Container(
    decoration: BoxDecoration(
      color: _cardBg, borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _border),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Live conditions · ${_location?.county ?? ''}',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
              color: Colors.black54)),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: [
        if (_iot != null) ...[
          _chip('Soil ${_iot!.temperature.toStringAsFixed(0)}°C',
              _iot!.temperature > 35 ? Colors.orange : Colors.green),
          _chip('Humidity ${_iot!.humidity.toStringAsFixed(0)}%',
              _iot!.humidity > 80 ? Colors.orange : Colors.green),
          _chip('pH ${_iot!.ph.toStringAsFixed(1)}',
              (_iot!.ph >= 5.5 && _iot!.ph <= 7.5) ? Colors.green : Colors.orange),
        ],
        if (_sat != null) ...[
          _chip('Air ${_sat!.airTemp.toStringAsFixed(0)}°C',
              _sat!.airTemp > 35 ? Colors.orange : Colors.green),
          _chip('Humidity ${_sat!.humidity.toStringAsFixed(0)}%',
              _sat!.humidity > 80 ? Colors.orange : Colors.green),
          _chip('Rain 7d ${SatelliteReading.totalPrecipitation(_history).toStringAsFixed(1)} mm',
              Colors.blue.shade700),
          _chip('Wind ${_sat!.windSpeed.toStringAsFixed(1)} m/s',
              _sat!.windSpeed > 5 ? Colors.orange : Colors.green),
          _chip('Cloud ${_sat!.cloudCover.toStringAsFixed(0)}%',
              _sat!.cloudCover > 70 ? Colors.orange : Colors.green),
        ],
      ]),
    ]),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // SHARED HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _nutrientTile(String label, double value, double low, double high, String unit) {
    final bool isLow  = value > 0 && value < low;
    final bool isHigh = value > high;
    final bool isGood = value >= low && value <= high;
    final Color bg    = isGood ? const Color(0xFFE8F5E9)
        : isLow ? const Color(0xFFFFEBEE) : const Color(0xFFFFF3E0);
    final Color text  = isGood ? _green
        : isLow ? const Color(0xFFB71C1C) : const Color(0xFFE65100);
    final String status = isGood ? 'Good' : isLow ? 'Low' : value <= 0 ? '—' : 'High';

    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(8),
          border: Border.all(color: text.withOpacity(0.25)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Column(children: [
          Text('$label ($unit)',
              style: const TextStyle(fontSize: 10, color: Colors.black54),
              textAlign: TextAlign.center),
          const SizedBox(height: 3),
          Text(value > 0 ? value.toStringAsFixed(1) : '—',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: text)),
          const SizedBox(height: 2),
          Text(status, style: TextStyle(fontSize: 10, color: text)),
        ]),
      ),
    );
  }

  Widget _valueTile(String label, double value, double low, double high, String unit,
      {int decimals = 1, bool invertLogic = false}) {
    bool isGood;
    if (invertLogic) {
      isGood = value <= high;
    } else {
      isGood = value >= low && value <= high;
    }
    final Color bg   = isGood ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1);
    final Color text = isGood ? _green : const Color(0xFFF57F17);

    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(8),
          border: Border.all(color: text.withOpacity(0.25)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Column(children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.black54),
              textAlign: TextAlign.center),
          const SizedBox(height: 3),
          Text('${value.toStringAsFixed(decimals)}${unit.isNotEmpty ? ' $unit' : ''}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: text),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _miniStat(String label, String value, bool isGood) {
    final color = isGood ? _green : const Color(0xFFE65100);
    return Expanded(child: Column(children: [
      Text(value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
          textAlign: TextAlign.center),
      Text(label,
          style: const TextStyle(fontSize: 9.5, color: Colors.black54),
          textAlign: TextAlign.center),
    ]));
  }

  Widget _chip(String text, Color color) => Container(
    decoration: BoxDecoration(
      color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    child: Text(text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color)),
  );

  Widget _skeleton() => Container(
    height: 84,
    decoration: BoxDecoration(
      color: _cardBg, borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _border),
    ),
    child: const Center(
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 14, height: 14,
            child: CircularProgressIndicator(strokeWidth: 2,
                color: Color(0xFF2A6B2A))),
        SizedBox(width: 8),
        Text('Loading farm data…',
            style: TextStyle(fontSize: 12, color: Colors.black45)),
      ]),
    ),
  );

  Widget _errorCard() => Container(
    decoration: BoxDecoration(
      color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.orange.shade200),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    child: Row(children: [
      const Icon(Icons.sensors_off, size: 14, color: Colors.orange),
      const SizedBox(width: 8),
      const Expanded(
        child: Text('Farm sensor data unavailable — enter values manually',
            style: TextStyle(fontSize: 12, color: Colors.deepOrange)),
      ),
      IconButton(
        icon: const Icon(Icons.refresh, size: 16, color: Colors.orange),
        onPressed: () { setState(() { _loading = true; _error = null; }); _load(); },
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    ]),
  );
}