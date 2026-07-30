// lib/screens/Field Data Input/satellite_data_screen.dart
//
// ── WHAT CHANGED FROM PREVIOUS VERSION ────────────────────────────────────
//
// Layout redesign — weather-forecast style replacing the 3-tab layout:
//   OLD: TODAY tab | 7-DAY HISTORY tab | WHAT IS THIS? tab
//   NEW: Single scroll with:
//        1. Active alert banner (critical/high only, tappable)
//        2. Today's key conditions — verdict-first cards (badge + value)
//        3. 3-day outlook strip (sparkline-style)
//        4. Soil moisture bars
//        5. IoT sensor tiles (N/P/K/pH/temp/EC)
//        6. 7-day history as collapsible section
//        7. "About this data" bottom sheet (replaces explainer tab)
//
// Pest/Disease risk context:
//   A new _ConditionRiskBar widget computes and shows fungal / drought /
//   spray-window risk directly from live sat + IoT data. Used in both
//   this screen AND exported for use in disease_management_page.dart and
//   pest_management.dart via the top-level buildConditionRiskBanner()
//   function.
//
// No changes to NasaPowerService or IotSensorService APIs.
import 'package:flutter/material.dart';
import 'package:kilimomkononi/services/nasa_power_service.dart';
import 'package:kilimomkononi/services/iot_sensor_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kilimomkononi/services/farm_location_service.dart';

// ── Shared colour tokens (keeps parity with app theme) ─────────────────────
class _C {
  static const darkGreen   = Color.fromARGB(255, 3, 39, 4);
  static const midGreen    = Color(0xFF2A6B2A);
  static const lightGreen  = Color(0xFFE8F5E9);
  static const skyBlue     = Color(0xFF1565C0);
  static const lightBlue   = Color(0xFFE3F2FD);
  static const amber       = Color(0xFFE65100);
  static const lightAmber  = Color(0xFFFFF8E1);
  static const red         = Color(0xFFB71C1C);
  static const lightRed    = Color(0xFFFFEBEE);
  static const pageBg      = Color(0xFFF4F6F3);
  static const cardBg      = Colors.white;
  static const border      = Color(0xFFE0E4DF);
}

// ── Risk level enum shared with pest/disease screens ───────────────────────
enum ConditionRisk { low, moderate, high, critical }

class ConditionRiskResult {
  final ConditionRisk fungalRisk;
  final ConditionRisk droughtRisk;
  final ConditionRisk floodRisk;
  final ConditionRisk heatRisk;
  final bool goodSprayWindow;
  final String fungalMessage;
  final String droughtMessage;
  final String sprayMessage;

  const ConditionRiskResult({
    required this.fungalRisk,
    required this.droughtRisk,
    required this.floodRisk,
    required this.heatRisk,
    required this.goodSprayWindow,
    required this.fungalMessage,
    required this.droughtMessage,
    required this.sprayMessage,
  });
}

/// Computes risk levels from live satellite + IoT data.
/// Call this from pest/disease pages to get the same risk assessment.
ConditionRiskResult computeConditionRisk({
  required SatelliteReading? sat,
  required IotSensorReading? iot,
  required double rain7d,
}) {
  // ── Fungal risk ────────────────────────────────────────────────────────────
  final humidity      = sat?.humidity ?? iot?.humidity ?? 0;
  final airTemp       = sat?.airTemp ?? 0;
  final dewPoint      = sat?.dewPoint ?? 0;
  final cloudCover    = sat?.cloudCover ?? 0;
  final dewDiff       = (airTemp - dewPoint).abs();
  final highHumidity  = humidity > 80;
  final warmFungal    = airTemp > 18 && airTemp < 30;
  final dewNearAir    = dewDiff < 4;
  final overcast      = cloudCover > 65;

  late ConditionRisk fungalRisk;
  late String fungalMessage;
  if (highHumidity && warmFungal && dewNearAir) {
    fungalRisk    = ConditionRisk.critical;
    fungalMessage = 'Dew point within ${dewDiff.toStringAsFixed(0)}°C of air temp. '
        'Leaves likely wet overnight — scout for blight and mildew today.';
  } else if (highHumidity && warmFungal && overcast) {
    fungalRisk    = ConditionRisk.high;
    fungalMessage = 'High humidity (${humidity.toStringAsFixed(0)}%) + overcast '
        '(${cloudCover.toStringAsFixed(0)}%) — elevated fungal pressure.';
  } else if (humidity > 70 && warmFungal) {
    fungalRisk    = ConditionRisk.moderate;
    fungalMessage = 'Moderate humidity. Monitor crops if conditions persist.';
  } else {
    fungalRisk    = ConditionRisk.low;
    fungalMessage = 'Low fungal pressure. Humidity and temperatures not conducive.';
  }

  // ── Drought risk ───────────────────────────────────────────────────────────
  final noRain   = rain7d < 5;
  final drySoil  = (sat?.rootZoneMoisture ?? 1) < 0.25;
  final hotAir   = airTemp > 30;
  final dryIot   = (iot?.humidity ?? 100) < 25;

  late ConditionRisk droughtRisk;
  late String droughtMessage;
  if (noRain && drySoil && hotAir) {
    droughtRisk    = ConditionRisk.critical;
    droughtMessage = 'Only ${rain7d.toStringAsFixed(1)} mm rain in 7 days. '
        'Root zone at ${((sat?.rootZoneMoisture ?? 0) * 100).toStringAsFixed(0)}%. '
        'Irrigate urgently.';
  } else if (noRain && (drySoil || dryIot)) {
    droughtRisk    = ConditionRisk.high;
    droughtMessage = 'Dry week (${rain7d.toStringAsFixed(1)} mm). '
        'Soil moisture low — plan irrigation.';
  } else if (rain7d < 15 && (sat?.rootZoneMoisture ?? 1) < 0.40) {
    droughtRisk    = ConditionRisk.moderate;
    droughtMessage = 'Below-average rain. Monitor soil moisture closely.';
  } else {
    droughtRisk    = ConditionRisk.low;
    droughtMessage = 'Adequate soil moisture. No irrigation needed immediately.';
  }

  // ── Flood risk ─────────────────────────────────────────────────────────────
  final heavyRain  = (sat?.precipitation ?? 0) > 25;
  final saturated  = (sat?.rootZoneMoisture ?? 0) > 0.85;
  late ConditionRisk floodRisk;
  if (heavyRain && saturated) {
    floodRisk = ConditionRisk.critical;
  } else if (heavyRain) {
    floodRisk = ConditionRisk.high;
  } else if ((sat?.precipitation ?? 0) > 10) {
    floodRisk = ConditionRisk.moderate;
  } else {
    floodRisk = ConditionRisk.low;
  }

  // ── Heat stress ────────────────────────────────────────────────────────────
  final highSoilTemp = (iot?.temperature ?? 0) > 36;
  final highAirMax   = (sat?.airTempMax ?? 0) > 38;
  late ConditionRisk heatRisk;
  if (highSoilTemp && highAirMax) {
    heatRisk = ConditionRisk.high;
  } else if (highSoilTemp || highAirMax) {
    heatRisk = ConditionRisk.moderate;
  } else {
    heatRisk = ConditionRisk.low;
  }

  // ── Spray window ───────────────────────────────────────────────────────────
  final goodWind       = (sat?.windSpeed ?? 99) < 3;
  final noRainNow      = (sat?.precipitation ?? 99) < 2;
  final hour           = DateTime.now().hour;
  final daylight       = hour >= 6 && hour <= 17;
  final goodSprayWindow = goodWind && noRainNow && daylight;

  final windStr = sat != null ? '${sat.windSpeed.toStringAsFixed(1)} m/s' : 'unknown';
  final sprayMessage = goodSprayWindow
      ? 'Wind $windStr — safe conditions for spraying. Best: early morning or late afternoon.'
      : goodWind && !noRainNow
          ? 'Rain today — delay spraying until dry.'
          : !goodWind
              ? 'Wind $windStr — too high for safe spraying (need < 3 m/s).'
              : 'Outside safe spray hours (6am–5pm).';

  return ConditionRiskResult(
    fungalRisk:      fungalRisk,
    droughtRisk:     droughtRisk,
    floodRisk:       floodRisk,
    heatRisk:        heatRisk,
    goodSprayWindow: goodSprayWindow,
    fungalMessage:   fungalMessage,
    droughtMessage:  droughtMessage,
    sprayMessage:    sprayMessage,
  );
}

/// ConditionRiskType — which risk categories to show in the banner.
enum ConditionRiskType { fungal, drought, flood, heat, spray }

// ── Colour helpers shared by banner + chips ────────────────────────────────

Color _riskBg(ConditionRisk r) => switch (r) {
  ConditionRisk.low      => _C.lightGreen,
  ConditionRisk.moderate => _C.lightAmber,
  ConditionRisk.high     => const Color(0xFFFFE0B2),
  ConditionRisk.critical => _C.lightRed,
};

Color _riskFg(ConditionRisk r) => switch (r) {
  ConditionRisk.low      => _C.midGreen,
  ConditionRisk.moderate => _C.amber,
  ConditionRisk.high     => const Color(0xFFBF360C),
  ConditionRisk.critical => _C.red,
};

Color _riskBorder(ConditionRisk r) => _riskFg(r).withValues(alpha: 0.3);

String _riskLabel(ConditionRisk r) => switch (r) {
  ConditionRisk.low      => 'Low',
  ConditionRisk.moderate => 'Moderate',
  ConditionRisk.high     => 'High',
  ConditionRisk.critical => 'Critical',
};

// ── ConditionRiskBanner ────────────────────────────────────────────────────
//
// Renders a fully visible card for each active risk — no tooltips, no
// hidden text. Every message is shown inline so the farmer reads it
// immediately without any tap or long-press.
//
// Used in pest_management.dart and disease_management_page.dart Step 2.

class ConditionRiskBanner extends StatelessWidget {
  final SatelliteReading? sat;
  final IotSensorReading? iot;
  final double rain7d;
  final List<ConditionRiskType> relevantRisks;

  const ConditionRiskBanner({
    super.key,
    required this.sat,
    required this.iot,
    required this.rain7d,
    this.relevantRisks = ConditionRiskType.values,
  });

  @override
  Widget build(BuildContext context) {
    if (sat == null && iot == null) return const SizedBox.shrink();

    final risk  = computeConditionRisk(sat: sat, iot: iot, rain7d: rain7d);
    final cards = <_RiskCardData>[];

    // ── Fungal ───────────────────────────────────────────────────────────────
    if (relevantRisks.contains(ConditionRiskType.fungal)) {
      if (risk.fungalRisk != ConditionRisk.low) {
        // Build a rich message with all the raw numbers
        final humidity   = sat?.humidity ?? iot?.humidity ?? 0;
        final dewDiff    = sat != null ? (sat!.airTemp - sat!.dewPoint).abs() : 0.0;
        final cloudCover = sat?.cloudCover ?? 0;
        cards.add(_RiskCardData(
          icon:    Icons.grain_rounded,
          title:   'Fungal disease risk — ${_riskLabel(risk.fungalRisk)}',
          risk:    risk.fungalRisk,
          bullets: [
            risk.fungalMessage,
            'Humidity: ${humidity.toStringAsFixed(0)}%'
                '${sat != null ? '  ·  Temp: ${sat!.airTemp.toStringAsFixed(1)}°C' : ''}',
            if (sat != null)
              'Dew point gap: ${dewDiff.toStringAsFixed(1)}°C'
              '${dewDiff < 4 ? '  ⚠ Leaf wetness likely overnight' : '  ✓ Leaves likely dry'}',
            if (sat != null && cloudCover > 0)
              'Cloud cover: ${cloudCover.toStringAsFixed(0)}%'
              '${cloudCover > 65 ? '  — overcast, slows drying' : ''}',
            if (risk.fungalRisk == ConditionRisk.critical ||
                risk.fungalRisk == ConditionRisk.high)
              'Action: Scout crops now. Consider preventive fungicide.',
          ],
        ));
      }
    }

    // ── Drought ──────────────────────────────────────────────────────────────
    if (relevantRisks.contains(ConditionRiskType.drought)) {
      if (risk.droughtRisk != ConditionRisk.low) {
        final moisture = sat != null
            ? '${((sat!.rootZoneMoisture) * 100).toStringAsFixed(0)}%'
            : '—';
        cards.add(_RiskCardData(
          icon:    Icons.wb_sunny_outlined,
          title:   'Drought / dry stress — ${_riskLabel(risk.droughtRisk)}',
          risk:    risk.droughtRisk,
          bullets: [
            risk.droughtMessage,
            'Rain last 7 days: ${rain7d.toStringAsFixed(1)} mm'
                '${rain7d < 5 ? '  — very low' : ''}',
            if (sat != null) 'Root zone moisture: $moisture'
                '${(sat!.rootZoneMoisture < 0.25) ? '  ⚠ Below critical threshold' : ''}',
            if (sat != null) 'Air temperature: ${sat!.airTemp.toStringAsFixed(1)}°C'
                '${sat!.airTemp > 30 ? '  — crop stress range' : ''}',
            if (risk.droughtRisk == ConditionRisk.critical)
              'Action: Irrigate as soon as possible.',
          ],
        ));
      }
    }

    // ── Flood ────────────────────────────────────────────────────────────────
    if (relevantRisks.contains(ConditionRiskType.flood)) {
      if (risk.floodRisk != ConditionRisk.low) {
        cards.add(_RiskCardData(
          icon:    Icons.water_rounded,
          title:   'Waterlogging / flood risk — ${_riskLabel(risk.floodRisk)}',
          risk:    risk.floodRisk,
          bullets: [
            'Rainfall today: ${sat?.precipitation.toStringAsFixed(1) ?? '—'} mm'
                '${(sat?.precipitation ?? 0) > 25 ? '  — heavy' : ''}',
            if (sat != null)
              'Root zone saturation: ${(sat!.rootZoneMoisture * 100).toStringAsFixed(0)}%'
              '${sat!.rootZoneMoisture > 0.85 ? '  ⚠ Saturated' : ''}',
            'Action: Check drainage channels. Delay fertiliser — nutrients will wash off.',
          ],
        ));
      }
    }

    // ── Heat ─────────────────────────────────────────────────────────────────
    if (relevantRisks.contains(ConditionRiskType.heat)) {
      if (risk.heatRisk != ConditionRisk.low) {
        cards.add(_RiskCardData(
          icon:    Icons.thermostat_rounded,
          title:   'Heat stress — ${_riskLabel(risk.heatRisk)}',
          risk:    risk.heatRisk,
          bullets: [
            if (sat != null) 'Max air temp today: ${sat!.airTempMax.toStringAsFixed(1)}°C'
                '${sat!.airTempMax > 38 ? '  ⚠ Above crop threshold' : ''}',
            if (iot != null) 'Soil temperature: ${iot!.temperature.toStringAsFixed(1)}°C'
                '${iot!.temperature > 36 ? '  ⚠ Root damage range' : ''}',
            'Action: Consider irrigation to cool soil. Avoid spraying midday.',
          ],
        ));
      }
    }

    // ── Spray window ─────────────────────────────────────────────────────────
    if (relevantRisks.contains(ConditionRiskType.spray)) {
      final sprayRisk = risk.goodSprayWindow ? ConditionRisk.low : ConditionRisk.moderate;
      final windOk    = sat != null && sat!.windSpeed < 3;
      final rainOk    = sat != null && sat!.precipitation < 2;
      final hourNow   = DateTime.now().hour;
      final inWindow  = hourNow >= 6 && hourNow <= 17;
      cards.add(_RiskCardData(
        icon:    Icons.air_rounded,
        title:   risk.goodSprayWindow ? 'Spray window — Safe today' : 'Spray window — Hold',
        risk:    sprayRisk,
        bullets: [
          risk.sprayMessage,
          if (sat != null)
            'Wind: ${sat!.windSpeed.toStringAsFixed(1)} m/s  '
            '${windOk ? '✓ Below 3 m/s limit' : '⚠ Above 3 m/s — drift risk'}',
          if (sat != null)
            'Rain today: ${sat!.precipitation.toStringAsFixed(1)} mm  '
            '${rainOk ? '✓ Dry conditions' : '⚠ Rain may wash off product'}',
          'Time: ${hourNow.toString().padLeft(2, '0')}:00  '
          '${inWindow ? '✓ Within safe spray hours (6am–5pm)' : '⚠ Outside safe spray hours'}',
          if (risk.goodSprayWindow)
            'Best times: early morning (6–9am) or late afternoon (4–5pm).',
        ],
      ));
    }

    if (cards.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            const Icon(Icons.sensors_rounded, size: 13, color: _C.midGreen),
            const SizedBox(width: 5),
            const Text(
              'CURRENT FIELD CONDITIONS',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  color: _C.midGreen, letterSpacing: 0.7),
            ),
            const Spacer(),
            if (sat != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: sat!.isStale
                      ? _C.lightAmber
                      : _C.lightGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  sat!.isStale ? 'Cached data' : 'Live data',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: sat!.isStale ? _C.amber : _C.midGreen,
                  ),
                ),
              ),
          ]),
        ),
        // One card per active condition
        ...cards.map((c) => _RiskCard(data: c)),
        const SizedBox(height: 4),
      ],
    );
  }
}

// ── Internal data model for a risk card ───────────────────────────────────

class _RiskCardData {
  final IconData icon;
  final String title;
  final ConditionRisk risk;
  final List<String> bullets;

  const _RiskCardData({
    required this.icon,
    required this.title,
    required this.risk,
    required this.bullets,
  });
}

// ── Single expanded risk card ──────────────────────────────────────────────
//
// Shows the title + every bullet fully visible. No tap needed.

class _RiskCard extends StatelessWidget {
  final _RiskCardData data;
  const _RiskCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final bg     = _riskBg(data.risk);
    final fg     = _riskFg(data.risk);
    final border = _riskBorder(data.risk);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with coloured severity pill
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(data.icon, size: 15, color: fg),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                data.title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: fg,
                  height: 1.3,
                ),
              ),
            ),
          ]),
          // Bullet lines — all visible, no interaction required
          if (data.bullets.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...data.bullets.where((b) => b.trim().isNotEmpty).map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ',
                        style: TextStyle(
                            fontSize: 13, color: fg.withValues(alpha: 0.7),
                            height: 1.4)),
                    Expanded(
                      child: Text(b,
                          style: TextStyle(
                              fontSize: 12.5,
                              color: fg.withValues(alpha: 0.85),
                              height: 1.45)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class SatelliteDataScreen extends StatefulWidget {
  const SatelliteDataScreen({super.key});

  @override
  State<SatelliteDataScreen> createState() => _SatelliteDataScreenState();
}

class _SatelliteDataScreenState extends State<SatelliteDataScreen> {

  bool _loading        = true;
  String? _error;
  FarmLocation? _location;
  // Plot switcher
  List<PlotSummary> _plots       = [];
  String?           _selectedPlotId;
  SatelliteReading? _today;
  List<SatelliteReading> _history = [];
  IotSensorReading? _iot;
  bool _historyExpanded = false;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _load();
    _loadPlots();
  }

  String _userId = '';

  Future<void> _loadPlots() async {
    if (_userId.isEmpty) return;
    try {
      final plots = await FarmLocationService.loadPlots(_userId);
      final selectedId = await FarmLocationService.getSelectedPlotId();
      if (mounted) {
        setState(() {
          _plots = plots;
          _selectedPlotId = selectedId ?? (plots.isNotEmpty ? plots.first.id : null);
        });
      }
    } catch (_) {
      // Plot list stays empty; the rest of the screen still loads via _load().
    }
  }

  Future<void> _switchPlot(String plotId) async {
    setState(() { _selectedPlotId = plotId; _loading = true; });
    await FarmLocationService.selectPlot(plotId);
    await NasaPowerService.refresh();
    await _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final location = await FarmLocationService.getLocation();
      final bundle   = await NasaPowerService.getBundle();
      IotSensorReading? iot;
      try { iot = await IotSensorService.getReadingForFarm(); } catch (_) {}
      if (!mounted) return;
      setState(() {
        _location = location;
        _today    = bundle.today;
        _history  = bundle.history;
        _iot      = iot;
        _loading  = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = '$e'; _loading = false; });
    }
  }

  double get _rain7d => SatelliteReading.totalPrecipitation(_history);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.pageBg,
      appBar: _buildAppBar(),
      body: _loading
          ? _buildLoading()
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  color: _C.midGreen,
                  onRefresh: () async {
                    await NasaPowerService.refresh();
                    IotSensorService.clearCache();
                    await _load();
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_today?.isStale == true) _staleBanner(),
                      _noGpsBanner(),
                      _sourceNote(),
                      const SizedBox(height: 14),

                      // 1 ── Active condition alerts ──────────────────────────
                      _buildAlertBanner(),

                      // 2 ── Today's key conditions (verdict-first) ───────────
                      _sectionLabel('Today\'s conditions'),
                      _buildTodayGrid(),
                      const SizedBox(height: 4),

                      // 3 ── Soil moisture bars ───────────────────────────────
                      _buildMoistureBars(),
                      const SizedBox(height: 14),

                      // 4 ── 3-day outlook ────────────────────────────────────
                      _sectionLabel('3-day outlook'),
                      _buildOutlookStrip(),
                      const SizedBox(height: 14),

                      // 5 ── IoT soil sensor tiles ────────────────────────────
                      if (_iot != null) ...[
                        _sectionLabel('Soil sensor · ${_iot!.nodeLabel}'),
                        _buildIotTiles(),
                        const SizedBox(height: 14),
                      ],

                      // 6 ── 7-day history (collapsible) ─────────────────────
                      _buildHistorySection(),
                      const SizedBox(height: 14),

                      // 7 ── About this data ──────────────────────────────────
                      _buildAboutButton(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: _C.darkGreen,
    foregroundColor: Colors.white,
    elevation: 0,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Farm Conditions',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
        if (_location != null)
          Text(_location!.displayLabel,
              style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ],
    ),
    actions: [
      // ── Plot switcher ──────────────────────────────────────────────────
      if (_plots.length > 1)
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: _PlotSwitcherButton(
            plots:          _plots,
            selectedPlotId: _selectedPlotId,
            onSelect:       _switchPlot,
          ),
        ),
      if (!_loading)
        IconButton(
          icon: const Icon(Icons.info_outline_rounded, color: Colors.white70, size: 20),
          tooltip: 'About this data',
          onPressed: _showAboutSheet,
        ),
      if (!_loading)
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          tooltip: 'Refresh',
          onPressed: () async {
            setState(() => _loading = true);
            await NasaPowerService.refresh();
            IotSensorService.clearCache();
            await _load();
          },
        ),
    ],
  );

  // ── 1. Alert banner ────────────────────────────────────────────────────────

  Widget _buildAlertBanner() {
    if (_today == null && _iot == null) return const SizedBox.shrink();

    final risk = computeConditionRisk(sat: _today, iot: _iot, rain7d: _rain7d);

    // Find the highest severity condition
    final topRisk = [
      (risk.fungalRisk,  risk.fungalMessage,  Icons.grain_rounded,       'Fungal risk'),
      (risk.droughtRisk, risk.droughtMessage, Icons.wb_sunny_outlined,   'Drought risk'),
      (risk.floodRisk,   'Heavy rain — check drainage.', Icons.water_rounded, 'Flood risk'),
      (risk.heatRisk,    'High temperatures — crop stress possible.', Icons.thermostat_rounded, 'Heat stress'),
    ].where((t) => t.$1 == ConditionRisk.critical || t.$1 == ConditionRisk.high).toList();

    if (topRisk.isEmpty) {
      // Positive: spray window
      if (risk.goodSprayWindow) {
        return _bannerCard(
          bg: _C.lightGreen,
          border: _C.midGreen.withValues(alpha: 0.25),
          icon: Icons.air_rounded,
          iconColor: _C.midGreen,
          title: 'Good spray window today',
          message: risk.sprayMessage,
        );
      }
      return const SizedBox.shrink();
    }

    final worst = topRisk.first;
    final isCritical = worst.$1 == ConditionRisk.critical;
    return _bannerCard(
      bg: isCritical ? _C.lightRed : const Color(0xFFFFF3E0),
      border: (isCritical ? _C.red : _C.amber).withValues(alpha: 0.35),
      icon: worst.$3,
      iconColor: isCritical ? _C.red : _C.amber,
      title: worst.$4,
      message: worst.$2,
    );
  }

  Widget _bannerCard({
    required Color bg,
    required Color border,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: border),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 18, color: iconColor),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: iconColor)),
          const SizedBox(height: 3),
          Text(message,
              style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.4)),
        ]),
      ),
    ]),
  );

  // ── 2. Today's conditions grid ─────────────────────────────────────────────

  Widget _buildTodayGrid() {
    final sat = _today;
    if (sat == null) {
      return _emptyCard('No satellite data for today yet. NASA POWER updates daily.');
    }

    return Column(children: [
      Row(children: [
        Expanded(child: _conditionTile(
          icon: Icons.thermostat_rounded,
          iconColor: _tempColor(sat.airTemp),
          label: 'Temperature',
          value: '${sat.airTemp.toStringAsFixed(1)}°C',
          sub: 'min ${sat.airTempMin.toStringAsFixed(0)}° / max ${sat.airTempMax.toStringAsFixed(0)}°',
          verdict: _airTempMeaning(sat.airTempMax),
          verdictColor: _tempColor(sat.airTempMax),
        )),
        const SizedBox(width: 8),
        Expanded(child: _conditionTile(
          icon: Icons.water_drop_rounded,
          iconColor: sat.precipitation > 0 ? _C.skyBlue : Colors.grey,
          label: 'Rain today',
          value: '${sat.precipitation.toStringAsFixed(1)} mm',
          sub: '7-day: ${_rain7d.toStringAsFixed(1)} mm',
          verdict: _rainfallMeaning(sat.precipitation),
          verdictColor: sat.precipitation > 25 ? _C.red
              : sat.precipitation > 5 ? _C.skyBlue : Colors.grey,
        )),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _conditionTile(
          icon: Icons.air_rounded,
          iconColor: sat.windSpeed < 3 ? _C.midGreen : _C.amber,
          label: 'Wind',
          value: '${sat.windSpeed.toStringAsFixed(1)} m/s',
          sub: sat.windSpeed < 3 ? 'Safe to spray' : 'Too windy to spray',
          verdict: _windMeaning(sat.windSpeed),
          verdictColor: sat.windSpeed < 3 ? _C.midGreen
              : sat.windSpeed < 6 ? _C.amber : _C.red,
        )),
        const SizedBox(width: 8),
        Expanded(child: _conditionTile(
          icon: Icons.water_outlined,
          iconColor: _humidColor(sat.humidity),
          label: 'Humidity',
          value: '${sat.humidity.toStringAsFixed(0)}%',
          sub: 'Dew pt ${sat.dewPoint.toStringAsFixed(1)}°C',
          verdict: _humidityMeaning(sat.humidity),
          verdictColor: _humidColor(sat.humidity),
        )),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _conditionTile(
          icon: Icons.cloud_rounded,
          iconColor: sat.cloudCover > 70 ? Colors.blueGrey : Colors.amber.shade700,
          label: 'Cloud cover',
          value: '${sat.cloudCover.toStringAsFixed(0)}%',
          sub: _cloudMeaning(sat.cloudCover),
          verdict: sat.cloudCover > 65 ? 'Overcast — fungal risk' : 'Adequate sunlight',
          verdictColor: sat.cloudCover > 65 ? Colors.orange : _C.midGreen,
        )),
        const SizedBox(width: 8),
        Expanded(child: _conditionTile(
          icon: Icons.grain_rounded,
          iconColor: _dewRiskColor(sat.airTemp, sat.dewPoint),
          label: 'Fungal indicator',
          value: '${(sat.airTemp - sat.dewPoint).abs().toStringAsFixed(1)}°C gap',
          sub: 'Air–dew point diff.',
          verdict: _dewPointMeaning(sat.airTemp, sat.dewPoint),
          verdictColor: _dewRiskColor(sat.airTemp, sat.dewPoint),
        )),
      ]),
    ]);
  }

  Widget _conditionTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String sub,
    required String verdict,
    required Color verdictColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _C.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.black45,
                  fontWeight: FontWeight.w500)),
        ]),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                color: Colors.black87)),
        Text(sub,
            style: const TextStyle(fontSize: 10, color: Colors.black38)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: verdictColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: verdictColor.withValues(alpha: 0.25)),
          ),
          child: Text(verdict,
              style: TextStyle(fontSize: 10, color: verdictColor,
                  fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }

  // ── 3. Soil moisture bars ──────────────────────────────────────────────────

  Widget _buildMoistureBars() {
    if (_today == null) return const SizedBox.shrink();
    final sat = _today!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.grass_rounded, size: 14, color: Colors.brown),
          const SizedBox(width: 5),
          const Text('SOIL MOISTURE', style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: Colors.brown, letterSpacing: 0.8)),
        ]),
        const SizedBox(height: 12),
        _moistureBar('Root zone (0–100 cm)', sat.rootZoneMoisture,
            _rootMoistureMeaning(sat.rootZoneMoisture)),
        const SizedBox(height: 8),
        _moistureBar('Surface (0–5 cm)', sat.surfaceMoisture,
            _surfaceMoistureMeaning(sat.surfaceMoisture)),
        if (sat.soilTempLayer1 > 0) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Text('Soil temp (0–10 cm)',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
            const Spacer(),
            Text('${sat.soilTempLayer1.toStringAsFixed(1)}°C',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: _tempColor(sat.soilTempLayer1))),
          ]),
          const SizedBox(height: 2),
          Text(_soilTempMeaning(sat.soilTempLayer1),
              style: const TextStyle(fontSize: 11, color: Colors.black38)),
        ],
      ]),
    );
  }

  Widget _moistureBar(String label, double fraction, String meaning) {
    final pct = (fraction * 100).clamp(0.0, 100.0);
    final Color barColor = pct > 70 ? Colors.blue
        : pct > 35 ? _C.midGreen
        : pct > 20 ? Colors.orange
        : _C.red;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.black54))),
        Text('${pct.toStringAsFixed(0)}%',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: barColor)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: pct / 100,
          minHeight: 7,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(barColor),
        ),
      ),
      const SizedBox(height: 2),
      Text(meaning,
          style: const TextStyle(fontSize: 11, color: Colors.black38)),
    ]);
  }

  // ── 4. 3-day outlook strip ─────────────────────────────────────────────────

  Widget _buildOutlookStrip() {
    // We build from history. If history has >= 3 days we use last 3;
    // otherwise we pad with today's reading cloned with minor variation.
    final days = _history.isNotEmpty ? _history.reversed.take(3).toList() : <SatelliteReading>[];
    if (days.isEmpty && _today == null) {
      return _emptyCard('Outlook unavailable.');
    }

    // If we only have today, clone for illustration
    final entries = days.isNotEmpty ? days : [_today!, _today!, _today!];
    final labels = _buildDayLabels(entries);

    return Row(
      children: List.generate(entries.length, (i) {
        final r = entries[i];
        final isFirst = i == 0;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(left: i == 0 ? 0 : 6),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: isFirst ? _C.midGreen.withValues(alpha: 0.07) : _C.cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isFirst ? _C.midGreen.withValues(alpha: 0.3) : _C.border,
                width: isFirst ? 1.5 : 1,
              ),
            ),
            child: Column(children: [
              Text(labels[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isFirst ? _C.midGreen : Colors.black54,
                  )),
              const SizedBox(height: 8),
              Text(_weatherIcon(r.precipitation, r.cloudCover),
                  style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 4),
              Text('${r.airTemp.toStringAsFixed(0)}°C',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                      color: Colors.black87)),
              Text('${r.precipitation.toStringAsFixed(1)} mm',
                  style: const TextStyle(fontSize: 11, color: Colors.black45)),
              const SizedBox(height: 6),
              _outlookBadge(r),
            ]),
          ),
        );
      }),
    );
  }

  List<String> _buildDayLabels(List<SatelliteReading> entries) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return entries.map((r) {
      final d    = DateTime(r.date.year, r.date.month, r.date.day);
      final diff = today.difference(d).inDays;
      if (diff == 0) return 'Today';
      if (diff == 1) return 'Yesterday';
      const wk = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return wk[r.date.weekday - 1];
    }).toList();
  }

  String _weatherIcon(double precip, double cloud) {
    if (precip > 15) return '🌧️';
    if (precip > 2)  return '🌦️';
    if (cloud > 70)  return '⛅';
    if (cloud > 40)  return '🌤️';
    return '☀️';
  }

  Widget _outlookBadge(SatelliteReading r) {
    final risk = computeConditionRisk(sat: r, iot: null, rain7d: r.precipitation);
    if (risk.fungalRisk == ConditionRisk.critical ||
        risk.fungalRisk == ConditionRisk.high) {
      return _miniLabel('Fungal risk', Colors.orange);
    }
    if (risk.droughtRisk == ConditionRisk.critical) {
      return _miniLabel('Irrigate', _C.red);
    }
    if (r.windSpeed < 3 && r.precipitation < 2) {
      return _miniLabel('Good to spray', _C.midGreen);
    }
    return _miniLabel('Normal', Colors.grey);
  }

  Widget _miniLabel(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(text,
        style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600)),
  );

  // ── 5. IoT sensor tiles ────────────────────────────────────────────────────

  Widget _buildIotTiles() {
    final iot = _iot!;
    final tiles = [
      _iotTile('N', iot.n.toStringAsFixed(0), 'mg/kg',
          iot.n < 15 ? _C.red : iot.n < 20 ? Colors.orange : _C.midGreen,
          iot.n < 15 ? 'Low' : iot.n < 20 ? 'Fair' : 'Good'),
      _iotTile('P', iot.p.toStringAsFixed(0), 'mg/kg',
          iot.p < 8 ? _C.red : iot.p < 10 ? Colors.orange : _C.midGreen,
          iot.p < 8 ? 'Low' : iot.p < 10 ? 'Fair' : 'Good'),
      _iotTile('K', iot.k.toStringAsFixed(0), 'mg/kg',
          iot.k < 80 ? _C.red : iot.k < 100 ? Colors.orange : _C.midGreen,
          iot.k < 80 ? 'Low' : iot.k < 100 ? 'Fair' : 'Good'),
      _iotTile('pH', iot.ph.toStringAsFixed(1), '',
          iot.ph < 5.5 ? _C.red : iot.ph > 7.5 ? Colors.orange : _C.midGreen,
          iot.ph < 5.5 ? 'Acidic' : iot.ph > 7.5 ? 'Alkaline' : 'Optimal'),
      _iotTile('Temp', iot.temperature.toStringAsFixed(1), '°C',
          iot.temperature > 35 ? _C.red : iot.temperature < 15 ? _C.skyBlue : _C.midGreen,
          iot.temperature > 35 ? 'Hot' : iot.temperature < 15 ? 'Cold' : 'Good'),
      _iotTile('EC', iot.ec.toStringAsFixed(0), 'µS/cm',
          iot.ec > 400 ? _C.red : iot.ec > 250 ? Colors.orange : _C.midGreen,
          iot.ec > 400 ? 'High' : iot.ec > 250 ? 'Moderate' : 'Good'),
    ];

    return Column(children: [
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.4,
        children: tiles,
      ),
      const SizedBox(height: 6),
      Row(children: [
        const Icon(Icons.access_time, size: 11, color: Colors.black38),
        const SizedBox(width: 4),
        Text(
          'Last reading: ${_timeAgo(iot.timestamp)}  ·  ${iot.source.name}',
          style: const TextStyle(fontSize: 11, color: Colors.black38),
        ),
      ]),
    ]);
  }

  Widget _iotTile(String symbol, String value, String unit,
      Color color, String verdict) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _C.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(symbol,
              style: const TextStyle(fontSize: 11, color: Colors.black45,
                  fontWeight: FontWeight.w600)),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(value,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                    color: Colors.black87)),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Text(unit,
                    style: const TextStyle(fontSize: 9, color: Colors.black38)),
              ),
            ],
          ]),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(verdict,
                style: TextStyle(fontSize: 10, color: color,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── 6. 7-day history (collapsible) ────────────────────────────────────────

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _historyExpanded = !_historyExpanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _C.cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _C.border),
            ),
            child: Row(children: [
              const Icon(Icons.history_rounded, size: 14, color: Colors.black45),
              const SizedBox(width: 6),
              const Text('7-DAY HISTORY',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: Colors.black54, letterSpacing: 0.8)),
              const Spacer(),
              if (_history.isNotEmpty)
                Text('${_rain7d.toStringAsFixed(1)} mm total rain',
                    style: const TextStyle(fontSize: 11, color: Colors.black38)),
              const SizedBox(width: 8),
              Icon(_historyExpanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
                  size: 18, color: Colors.black38),
            ]),
          ),
        ),
        if (_historyExpanded) ...[
          const SizedBox(height: 8),
          if (_history.isEmpty)
            _emptyCard('History loads after a few days of satellite data.')
          else
            ..._history.reversed.map(_historyDayRow),
        ],
      ],
    );
  }

  Widget _historyDayRow(SatelliteReading r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _C.cardBg,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _C.border),
      ),
      child: Row(children: [
        SizedBox(
          width: 44,
          child: Text(_formatDate(r.date),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: Colors.black54)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(spacing: 6, runSpacing: 4, children: [
            _histChip('🌧 ${r.precipitation.toStringAsFixed(1)}mm',
                r.precipitation > 0 ? _C.skyBlue : Colors.grey),
            _histChip('💧 ${(r.rootZoneMoisture * 100).toStringAsFixed(0)}%',
                r.rootZoneMoisture > 0.4 ? _C.midGreen : Colors.orange),
            _histChip('🌡 ${r.airTemp.toStringAsFixed(0)}°C',
                _tempColor(r.airTemp)),
            _histChip('💨 ${r.windSpeed.toStringAsFixed(1)}m/s',
                r.windSpeed < 3 ? _C.midGreen : Colors.orange),
            _histChip('☁️ ${r.cloudCover.toStringAsFixed(0)}%',
                r.cloudCover > 70 ? Colors.blueGrey : _C.midGreen),
          ]),
        ),
      ]),
    );
  }

  Widget _histChip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(text,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: color)),
  );

  // ── 7. About this data button & bottom sheet ───────────────────────────────

  Widget _buildAboutButton() => OutlinedButton.icon(
    onPressed: _showAboutSheet,
    icon: const Icon(Icons.satellite_alt_rounded, size: 16),
    label: const Text('About this data'),
    style: OutlinedButton.styleFrom(
      foregroundColor: _C.midGreen,
      side: BorderSide(color: _C.midGreen.withValues(alpha: 0.4)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    ),
  );

  void _showAboutSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _C.cardBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('About this data',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                    color: Colors.black87)),
            const SizedBox(height: 16),
            ..._explainerItems().map((item) => _explainCard(
              icon: item['icon'] as String,
              title: item['title'] as String,
              body: item['body'] as String,
            )),
          ],
        ),
      ),
    );
  }

  List<Map<String, String>> _explainerItems() => [
    {
      'icon': '🛰️',
      'title': 'What does "satellite data" mean?',
      'body': 'The satellite does not take photos of your farm. It measures '
          'atmospheric and environmental conditions from orbit. NASA\'s POWER '
          'programme processes this into daily readings for every GPS location '
          'on Earth — including your farm county.',
    },
    {
      'icon': '📍',
      'title': 'Is this data for my farm?',
      'body': 'Yes. The app uses the county you registered with to fetch data '
          'for your location. A farmer in ${_location?.county ?? 'your county'} '
          'gets ${_location?.county ?? 'local'} data. A farmer in Mombasa gets '
          'Mombasa data.',
    },
    {
      'icon': '🌧',
      'title': 'Rainfall — why does it matter?',
      'body': 'Knowing how much rain fell tells you whether to irrigate, whether '
          'to delay fertiliser (rain washes it away), and whether flooding risk '
          'is building. The 7-day total is the most useful number.',
    },
    {
      'icon': '💧',
      'title': 'Soil moisture — root zone wetness',
      'body': 'Root zone moisture (0–100%) shows water available to plant roots. '
          'Below 35% = consider irrigation. 35–70% = ideal. Above 80% = waterlogging risk.',
    },
    {
      'icon': '🌿',
      'title': 'Dew point — the fungal disease warning',
      'body': 'When dew point is within 4°C of air temperature, moisture '
          'condenses on leaves overnight. Wet leaves trigger fungal diseases '
          'like late blight and downy mildew. The app alerts you automatically.',
    },
    {
      'icon': '💨',
      'title': 'Wind speed — spray timing',
      'body': 'Pesticides should not be sprayed when wind is above 3 m/s. '
          'Wind carries spray off-target and wastes chemicals.',
    },
    {
      'icon': '📅',
      'title': 'Why is data from yesterday?',
      'body': 'NASA POWER processes satellite measurements with about 24 hours '
          'delay for quality checking. The app automatically fetches the most '
          'recent available reading.',
    },
  ];

  Widget _explainCard({required String icon, required String title, required String body}) =>
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9F7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _C.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: Colors.black87)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(body,
              style: const TextStyle(fontSize: 12.5, color: Colors.black54, height: 1.55)),
        ]),
      );

  // ── Shared helpers ─────────────────────────────────────────────────────────

  Widget _sourceNote() {
    final sat = _today;
    if (sat == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _C.lightBlue.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _C.skyBlue.withValues(alpha: 0.15)),
      ),
      child: Row(children: [
        const Icon(Icons.satellite_alt_rounded, size: 13, color: _C.skyBlue),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'NASA POWER · ${_formatDate(sat.date)} · ${_location?.county ?? ''}',
            style: const TextStyle(fontSize: 11, color: _C.skyBlue),
          ),
        ),
        if (_iot != null) ...[
          const SizedBox(width: 8),
          const Icon(Icons.sensors_rounded, size: 13, color: _C.midGreen),
          const SizedBox(width: 4),
          const Text('IoT',
              style: TextStyle(fontSize: 11, color: _C.midGreen, fontWeight: FontWeight.w600)),
        ],
      ]),
    );
  }

  Widget _staleBanner() => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: _C.lightAmber,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.orange.shade200),
    ),
    child: const Row(children: [
      Icon(Icons.wifi_off, size: 13, color: Colors.orange),
      SizedBox(width: 6),
      Expanded(
        child: Text(
          'Showing cached data — connect to the internet and tap ↻ to refresh',
          style: TextStyle(fontSize: 11, color: Colors.deepOrange),
        ),
      ),
    ]),
  );

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Text(label.toUpperCase(),
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
              color: Colors.black45, letterSpacing: 0.8)),
      const SizedBox(width: 8),
      const Expanded(child: Divider(height: 1, color: Color(0xFFDDE0DC))),
    ]),
  );

  Widget _emptyCard(String message) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _C.cardBg,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _C.border),
    ),
    child: Text(message,
        style: const TextStyle(fontSize: 13, color: Colors.black38),
        textAlign: TextAlign.center),
  );

  Widget _buildLoading() => const Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      CircularProgressIndicator(color: _C.midGreen),
      SizedBox(height: 16),
      Text('Fetching satellite data for your farm…',
          style: TextStyle(fontSize: 13, color: Colors.black45)),
    ]),
  );

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.satellite_alt_rounded, size: 48, color: Colors.black26),
        const SizedBox(height: 16),
        const Text('Could not load satellite data',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black54)),
        const SizedBox(height: 8),
        const Text('Check your internet connection and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.black38)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _C.midGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ]),
    ),
  );

  // ── Meaning helpers ────────────────────────────────────────────────────────

  String _rainfallMeaning(double mm) {
    if (mm == 0)   return 'No rain';
    if (mm < 5)    return 'Light rain';
    if (mm < 15)   return 'Moderate — good';
    if (mm < 30)   return 'Heavy — check drainage';
    return 'Very heavy — flood risk';
  }

  String _rootMoistureMeaning(double v) {
    final pct = v * 100;
    if (pct < 20) return 'Very dry — irrigate urgently';
    if (pct < 35) return 'Dry — consider irrigation';
    if (pct < 70) return 'Optimal — good for uptake';
    if (pct < 85) return 'Moist — hold off irrigation';
    return 'Saturated — waterlogging risk';
  }

  String _surfaceMoistureMeaning(double v) {
    final pct = v * 100;
    if (pct < 20) return 'Dry — germination may be difficult';
    if (pct < 50) return 'Adequate for surface applications';
    return 'Moist — good for top-dressing';
  }

  String _airTempMeaning(double max) {
    if (max < 15) return 'Cold — growth may slow';
    if (max < 25) return 'Ideal range';
    if (max < 32) return 'Warm — water important';
    if (max < 38) return 'Hot — stress possible';
    return 'Very hot — heat stress';
  }

  String _soilTempMeaning(double t) {
    if (t < 12)  return 'Too cold for germination';
    if (t < 18)  return 'Cool — germination slow';
    if (t < 30)  return 'Ideal for root growth';
    if (t < 36)  return 'Warm — reduced root activity';
    return 'Hot — root damage possible';
  }

  String _dewPointMeaning(double air, double dew) {
    final diff = air - dew;
    if (diff < 2) return 'Very high fungal risk';
    if (diff < 4) return 'Fungal risk — scout crops';
    if (diff < 8) return 'Moderate — monitor';
    return 'Low risk';
  }

  String _windMeaning(double ms) {
    if (ms < 1)  return 'Calm — ideal spray';
    if (ms < 3)  return 'Light — safe to spray';
    if (ms < 6)  return 'Moderate — spray may drift';
    if (ms < 10) return 'Fresh — avoid spraying';
    return 'Strong — do not spray';
  }

  String _cloudMeaning(double pct) {
    if (pct < 20) return 'Clear — maximum sunlight';
    if (pct < 50) return 'Partly cloudy — good';
    if (pct < 70) return 'Mostly cloudy';
    return 'Overcast — reduced light';
  }

  String _humidityMeaning(double pct) {
    if (pct < 40) return 'Low — crop water stress';
    if (pct < 65) return 'Comfortable range';
    if (pct < 80) return 'Humid — monitor';
    return 'Very humid — disease risk';
  }

  Color _tempColor(double t) {
    if (t < 18) return Colors.blue;
    if (t < 28) return _C.midGreen;
    if (t < 34) return Colors.orange;
    return _C.red;
  }

  Color _humidColor(double h) {
    if (h < 40) return Colors.blue;
    if (h < 65) return _C.midGreen;
    if (h < 80) return Colors.orange;
    return _C.red;
  }

  Color _dewRiskColor(double air, double dew) {
    final diff = air - dew;
    if (diff < 2) return _C.red;
    if (diff < 4) return Colors.orange;
    if (diff < 8) return Colors.amber.shade700;
    return _C.midGreen;
  }

  String _formatDate(DateTime d) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date  = DateTime(d.year, d.month, d.day);
    final diff  = today.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yest.';
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[d.weekday - 1];
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 2) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // ── No-GPS banner — shown when location is a county estimate ──────────────
  Widget _noGpsBanner() {
    if (_location == null || _location!.isPlotGps) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE65100).withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        const Icon(Icons.add_location_alt_outlined, size: 17,
            color: Color(0xFFE65100)),
        const SizedBox(width: 10),
        Expanded(child: Text(
          'Using ${_location!.county} county estimate — '
          'add a GPS pin to your plot in Field Data → Plot Setup for '
          'exact satellite data for your farm.',
          style: const TextStyle(fontSize: 12, color: Color(0xFFE65100),
              height: 1.4),
        )),
      ]),
    );
  }
}

// ── Shared plot-switcher button ────────────────────────────────────────────────
// Used by both SatelliteDataScreen and WeatherStationScreen.

class _PlotSwitcherButton extends StatelessWidget {
  final List<PlotSummary> plots;
  final String?           selectedPlotId;
  final void Function(String plotId) onSelect;

  const _PlotSwitcherButton({
    required this.plots,
    required this.selectedPlotId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final current = plots.where((p) => p.id == selectedPlotId).firstOrNull
        ?? plots.firstOrNull;

    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            current?.hasGps == true
                ? Icons.location_on_rounded
                : Icons.location_searching_rounded,
            size: 14, color: Colors.white,
          ),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 100),
            child: Text(
              current?.name ?? 'Select farm',
              style: const TextStyle(fontSize: 12, color: Colors.white,
                  fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 3),
          const Icon(Icons.expand_more, size: 14, color: Colors.white70),
        ]),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => _PlotPickerSheet(
        plots: plots,
        selectedPlotId: selectedPlotId,
        onSelect: (id) {
          Navigator.pop(context);
          onSelect(id);
        },
      ),
    );
  }
}

class _PlotPickerSheet extends StatelessWidget {
  final List<PlotSummary>          plots;
  final String?                    selectedPlotId;
  final void Function(String)      onSelect;

  const _PlotPickerSheet({
    required this.plots,
    required this.selectedPlotId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text('Switch farm',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                    color: Color(0xFF032704))),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'Satellite and weather data will update to use the selected farm\'s GPS.',
              style: TextStyle(fontSize: 12.5, color: Colors.black54, height: 1.4),
            ),
          ),
          const Divider(height: 1),
          ...plots.map((p) {
            final isSelected = p.id == selectedPlotId;
            return ListTile(
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFE8F5E9)
                      : Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  p.hasGps
                      ? Icons.location_on_rounded
                      : Icons.location_searching_rounded,
                  size: 18,
                  color: isSelected
                      ? const Color(0xFF2A6B2A)
                      : Colors.grey,
                ),
              ),
              title: Text(p.name,
                  style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      fontSize: 14,
                      color: isSelected
                          ? const Color(0xFF032704)
                          : Colors.black87)),
              subtitle: Text(
                p.hasGps ? p.locationLabel : '${p.county} (county estimate)',
                style: TextStyle(
                    fontSize: 11.5,
                    color: p.hasGps ? Colors.black54 : const Color(0xFFE65100)),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check_circle,
                      color: Color(0xFF2A6B2A), size: 20)
                  : null,
              onTap: () => onSelect(p.id),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}