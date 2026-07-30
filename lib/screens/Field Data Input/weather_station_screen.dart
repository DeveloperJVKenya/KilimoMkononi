// lib/screens/Field Data Input/weather_station_screen.dart
//
// Displays live data from the NuaSense weather station.
// Mirrors the layout/style of satellite_data_screen.dart.
//
// Sections:
//   1. Status bar (live / stale / offline)
//   2. Current conditions grid (temp, humidity, wind, rainfall, pressure, sunlight)
//   3. Agronomic advice cards (leaf wetness, spray window, VPD, ET₀, pest pressure)
//      — spray window now uses NuaSense's own spray_quality_index/_label
//      when available (wind + delta-T + inversion risk combined).
//   4. 24-hour sparkline strip (temp + humidity)
//   5. Upcoming spray windows (48h outlook from GET /derived/forecast)
//   6. Degree-day pest pressure section — now includes the crop-specific
//      pests added in the July 2026 API update (fall armyworm, diamondback
//      moth, Tuta absoluta, thrips, armyworm, coffee berry borer)
//   7. Station switcher (for accounts with more than one NuaSense station)
//   8. About this data bottom sheet
//
// Navigation: Field Data Input Home → Quick access → "Weather station"
//

import 'package:flutter/material.dart';
import 'package:kilimomkononi/services/nuasense_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kilimomkononi/services/farm_location_service.dart';

// ── Colour tokens (mirrors satellite_data_screen) ─────────────────────────
class _C {
  static const darkGreen  = Color.fromARGB(255, 3, 39, 4);
  static const midGreen   = Color(0xFF2A6B2A);
  static const lightGreen = Color(0xFFE8F5E9);
  static const skyBlue    = Color(0xFF1565C0);
  static const amber      = Color(0xFFE65100);
  static const lightAmber = Color(0xFFFFF8E1);
  static const red        = Color(0xFFB71C1C);
  static const pageBg     = Color(0xFFF4F6F3);
  static const border     = Color(0xFFE0E4DF);
}

// ─────────────────────────────────────────────────────────────────────────────

class WeatherStationScreen extends StatefulWidget {
  const WeatherStationScreen({super.key});

  @override
  State<WeatherStationScreen> createState() => _WeatherStationScreenState();
}

class _WeatherStationScreenState extends State<WeatherStationScreen> {
  bool _loading = true;
  String? _error;
  NuaSenseReading? _reading;
  List<NuaSenseHourPoint> _history = [];
  List<NuaSenseForecastPoint> _forecast = [];
  String _county = '';
  // Plot switcher
  String _userId = '';
  List<PlotSummary> _plots       = [];
  String?           _selectedPlotId;
  bool              _isPlotGps   = false;
  // Station switcher (multi-station accounts, added July 2026)
  List<NuaStation> _stations     = [];
  String?          _selectedStationId;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _load();
    _loadPlots();
    _loadStations();
  }

  Future<void> _loadStations() async {
    try {
      final stations = await NuaSenseService.getStations();
      if (!mounted) return;
      setState(() { _stations = stations; });
    } catch (_) {
      // Single-station accounts (or older Cloud Function) will just get an
      // empty list here — the switcher stays hidden, nothing else changes.
    }
  }

  Future<void> _switchStation(String? stationId) async {
    setState(() { _selectedStationId = stationId; _loading = true; });
    await _load();
  }

  Future<void> _loadPlots() async {
    if (_userId.isEmpty) return;
    try {
      final plots     = await FarmLocationService.loadPlots(_userId);
      final selectedId = await FarmLocationService.getSelectedPlotId();
      if (mounted) {
        setState(() {
        _plots = plots;
        _selectedPlotId = selectedId ?? (plots.isNotEmpty ? plots.first.id : null);
      });
      }
    } catch (_) {}
  }

  Future<void> _switchPlot(String plotId) async {
    setState(() { _selectedPlotId = plotId; _loading = true; });
    await FarmLocationService.selectPlot(plotId);
    await _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final loc = await FarmLocationService.getLocation();
      final reading = await NuaSenseService.getLatestReading(
          stationId: _selectedStationId);
      final history = await NuaSenseService.get24hHistory(
          stationId: _selectedStationId);
      if (!mounted) return;
      setState(() {
        _county     = loc.county;
        _isPlotGps  = loc.isPlotGps;
        _reading = reading;
        _history = history;
        _loading = false;
      });
      // Forecast is a separate, non-blocking call — the screen is already
      // useful without it, so failures here shouldn't show an error state.
      _loadForecast();
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = '$e'; _loading = false; });
    }
  }

  Future<void> _loadForecast() async {
    try {
      final forecast = await NuaSenseService.getSprayForecast(
          stationId: _selectedStationId, hours: 48);
      if (!mounted) return;
      setState(() { _forecast = forecast; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _forecast = []; });
    }
  }

  Future<void> _refresh() async {
    NuaSenseService.clearCache(stationId: _selectedStationId);
    await _load();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.pageBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Weather Station',
                style: TextStyle(color: Colors.white, fontSize: 17,
                    fontWeight: FontWeight.w600)),
            if (_county.isNotEmpty)
              Text(
                _isPlotGps ? '$_county · GPS' : '$_county (county estimate)',
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
          ],
        ),
        backgroundColor: _C.darkGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // ── Station switcher (premium multi-station accounts) ──────────
          if (_stations.length > 1)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _StationSwitcherButton(
                stations:          _stations,
                selectedStationId: _selectedStationId,
                onSelect:          _switchStation,
              ),
            ),
          // ── Plot switcher ───────────────────────────────────────────────
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
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              onPressed: _refresh,
            ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'About this data',
            onPressed: _showAbout,
          ),
        ],
      ),
      body: _loading
          ? _buildLoading()
          : _error != null
              ? _buildError()
              : (_reading != null && !_reading!.isProvisioned)
                  ? _buildNotProvisioned()
                  : RefreshIndicator(
                  color: _C.midGreen,
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _noGpsBanner(),
                      _buildStatusBar(),
                      const SizedBox(height: 12),
                      _sectionLabel('Current conditions'),
                      _buildConditionsGrid(),
                      const SizedBox(height: 16),
                      _sectionLabel('Agronomic advice'),
                      _buildAdviceCards(),
                      const SizedBox(height: 16),
                      _sectionLabel('Last 24 hours'),
                      _buildHistoryStrip(),
                      const SizedBox(height: 16),
                      _sectionLabel('Upcoming spray windows'),
                      _buildForecastStrip(),
                      const SizedBox(height: 16),
                      _sectionLabel('Pest degree-day pressure'),
                      _buildDegreeDaySection(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  // ── Loading / Error ───────────────────────────────────────────────────────

  Widget _buildLoading() => const Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      CircularProgressIndicator(color: _C.midGreen),
      SizedBox(height: 16),
      Text('Loading weather station data…',
          style: TextStyle(color: Colors.black45, fontSize: 13)),
    ]),
  );

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey),
        const SizedBox(height: 16),
        const Text('Could not reach weather station',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        Text(_error ?? '', textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.black45)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(backgroundColor: _C.midGreen,
              foregroundColor: Colors.white),
        ),
      ]),
    ),
  );

  // Distinct from _buildError() on purpose: this isn't a fetch failure,
  // it's an expected state for any farmer who hasn't had a station
  // installed yet. Calm, informational tone — not "something's broken."
  Widget _buildNotProvisioned() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.sensors_off_rounded, size: 48, color: _C.midGreen),
        const SizedBox(height: 16),
        const Text('No weather station installed yet',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15,
                color: Color(0xFF032704))),
        const SizedBox(height: 8),
        const Text(
          'Once a NuaSense weather station is installed on your farm, '
          'live conditions, spray windows, and pest pressure will appear '
          'here automatically.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: Colors.black54, height: 1.4),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Check again'),
          style: OutlinedButton.styleFrom(foregroundColor: _C.midGreen,
              side: const BorderSide(color: _C.midGreen)),
        ),
      ]),
    ),
  );

  // ── Status bar ────────────────────────────────────────────────────────────

  Widget _buildStatusBar() {
    final r = _reading!;
    final timeAgo = _timeAgo(r.timestamp);
    final stale   = r.isStale;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: stale ? _C.lightAmber : _C.lightGreen,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: stale
            ? _C.amber.withValues(alpha: 0.3)
            : _C.midGreen.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(stale ? Icons.access_time_rounded : Icons.sensors_rounded,
            size: 14, color: stale ? _C.amber : _C.midGreen),
        const SizedBox(width: 6),
        Expanded(child: Text(
          stale
              ? 'Cached data · Last updated $timeAgo'
              : 'Live · Updated $timeAgo',
          style: TextStyle(fontSize: 12,
              color: stale ? _C.amber : _C.midGreen,
              fontWeight: FontWeight.w500),
        )),
        const Icon(Icons.location_on_outlined, size: 12, color: Colors.black38),
        const SizedBox(width: 3),
        Text(_county, style: const TextStyle(fontSize: 11, color: Colors.black45)),
      ]),
    );
  }

  // ── Conditions grid ───────────────────────────────────────────────────────

  Widget _buildConditionsGrid() {
    final r = _reading!;
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.05,
      children: [
        _condCard(
          icon: Icons.thermostat_rounded,
          label: 'Air Temp',
          value: '${r.airTemp.toStringAsFixed(1)}°C',
          sub:   r.airTemp > 35 ? '⚠ High heat' : r.airTemp < 15 ? 'Cool' : 'Good',
          color: r.airTemp > 35 ? _C.red : r.airTemp < 15 ? _C.skyBlue : _C.midGreen,
        ),
        _condCard(
          icon: Icons.water_drop_outlined,
          label: 'Humidity',
          value: '${r.humidity.toStringAsFixed(0)}%',
          sub:   r.humidity > 80 ? '⚠ Fungal risk'
              : r.humidity < 40 ? 'Dry'
              : 'Good',
          color: r.humidity > 80 ? _C.red
              : r.humidity > 65 ? _C.amber
              : _C.midGreen,
        ),
        _condCard(
          icon: Icons.air_rounded,
          label: 'Wind',
          value: '${r.windSpeed.toStringAsFixed(1)} m/s',
          sub:   '${r.windDirLabel}  ·  gusts ${r.windGusts.toStringAsFixed(1)}',
          color: r.windSpeed > 6 ? _C.red
              : r.windSpeed > 3 ? _C.amber
              : _C.midGreen,
        ),
        _condCard(
          icon: Icons.grain_rounded,
          label: 'Rainfall',
          value: '${r.rainfall.toStringAsFixed(1)} mm',
          sub:   r.rainfall > 25 ? '⚠ Heavy rain'
              : r.rainfall > 5 ? 'Moderate'
              : r.rainfall > 0 ? 'Light rain'
              : 'Dry',
          color: r.rainfall > 25 ? _C.skyBlue
              : r.rainfall > 0 ? const Color(0xFF0288D1)
              : Colors.grey,
        ),
        _condCard(
          icon: Icons.compress_rounded,
          label: 'Pressure',
          value: '${r.airPressure.toStringAsFixed(0)} hPa',
          sub:   r.pressureTrend6h > 1.5 ? '↑ Rising'
              : r.pressureTrend6h < -1.5 ? '↓ Falling'
              : '→ Steady',
          color: r.pressureTrend6h < -1.5 ? _C.amber : _C.midGreen,
        ),
        _condCard(
          icon: Icons.wb_sunny_outlined,
          label: 'Sunlight',
          value: '${(r.sunlight / 1000).toStringAsFixed(1)} klx',
          sub:   r.sunlight > 50000 ? 'Bright sun'
              : r.sunlight > 10000 ? 'Moderate'
              : 'Low / cloudy',
          color: r.sunlight > 10000 ? Colors.orange.shade700 : Colors.grey,
        ),
      ],
    );
  }

  Widget _condCard({
    required IconData icon,
    required String label,
    required String value,
    required String sub,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 10,
                color: Colors.black45, fontWeight: FontWeight.w600)),
          ]),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 16,
              fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(fontSize: 9.5,
              color: Colors.black45), maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  // ── Agronomic advice cards ────────────────────────────────────────────────

  Widget _buildAdviceCards() {
    final r = _reading!;
    final cards = <_AdviceCard>[];

    // Leaf wetness
    cards.add(_AdviceCard(
      icon:    r.leafIsWet ? Icons.water_drop_rounded : Icons.check_circle_outline_rounded,
      title:   r.leafIsWet ? 'Leaf Wetness — Wet' : 'Leaf Wetness — Dry',
      color:   r.leafIsWet ? _C.amber : _C.midGreen,
      bullets: [
        r.leafIsWet
            ? 'Leaves are wet (${r.lwdReason.isNotEmpty ? r.lwdReason.replaceAll('_', ' ') : 'conditions indicate wetness'}). '
              'Fungal spores germinate more readily — scout for disease.'
            : 'Leaf surfaces are dry. Reduced fungal infection risk.',
        if (r.leafIsWet && r.lwdConsecutiveHours > 0)
          'Wet for ${r.lwdConsecutiveHours} consecutive hour'
              '${r.lwdConsecutiveHours == 1 ? '' : 's'}'
              '${r.lwdConsecutiveHours >= 6 ? ' — long unbroken wetness drives most infections.' : '.'}',
        'Dew point: ${r.dewPoint.toStringAsFixed(1)}°C  ·  '
            'Dew gap: ${r.dewPointDepression.toStringAsFixed(1)}°C'
            '${r.dewPointDepression <= 2 ? '  ⚠ Near-condensation' : ''}',
      ],
    ));

    // Spray window — prefer NuaSense's own combined score when present.
    if (r.sprayQualityLabel.isNotEmpty) {
      final good     = r.sprayQualityGood;
      final marginal = r.sprayQualityMarginal;
      final color = good ? _C.midGreen : marginal ? _C.amber : _C.red;
      final factorLabel = switch (r.sprayLimitingFactor) {
        'wind'      => 'wind speed',
        'delta_t'   => 'delta-T (droplets drying before landing)',
        'inversion' => 'a temperature inversion (drift hangs near the ground)',
        'rain'      => 'rain',
        _           => r.sprayLimitingFactor,
      };
      cards.add(_AdviceCard(
        icon:  good ? Icons.opacity_outlined
             : marginal ? Icons.warning_amber_rounded
             : Icons.not_interested_rounded,
        title: 'Spray Window — ${r.sprayQualityLabel} (${r.sprayQualityIndex.toStringAsFixed(0)}/100)',
        color: color,
        bullets: [
          'Wind: ${r.windSpeed.toStringAsFixed(1)} m/s  ·  '
              'Delta-T: ${r.deltaT.toStringAsFixed(1)}°C'
              '${r.inversionRisk.isNotEmpty ? '  ·  Inversion risk: ${r.inversionRisk}' : ''}',
          if (!good && r.sprayLimitingFactor.isNotEmpty)
            'Main limiting factor: $factorLabel.',
          if (good)
            'Good conditions now. Best held in early morning (6–9am) or late afternoon (4–5pm).'
          else if (marginal)
            'Usable but not ideal — expect some drift or faster evaporation.'
          else
            'Hold off. See "Upcoming spray windows" below for the next good stretch.',
        ],
      ));
    } else {
      final goodWind = r.goodSprayWind;
      final noRain   = !r.rainingNow;
      final hour     = DateTime.now().hour;
      final inWindow = hour >= 6 && hour <= 17;
      final goodSpray = goodWind && noRain && inWindow;
      cards.add(_AdviceCard(
        icon:  goodSpray ? Icons.opacity_outlined : Icons.not_interested_rounded,
        title: goodSpray ? 'Spray Window — Safe Now' : 'Spray Window — Hold',
        color: goodSpray ? _C.midGreen : _C.amber,
        bullets: [
          'Wind: ${r.windSpeed.toStringAsFixed(1)} m/s  ${goodWind ? "✓ Below 3 m/s" : "⚠ Too high — drift risk"}',
          'Rain: ${r.rainingNow ? "⚠ Currently raining — product washes off" : "✓ Dry conditions"}',
          if (!inWindow) '⚠ Outside safe spray hours (6am–5pm)',
          if (goodSpray) 'Best spray time: early morning (6–9am) or late afternoon (4–5pm).',
          if (!goodSpray && !goodWind)
            'Wait for wind to drop below 3 m/s before applying pesticide or fertiliser.',
        ],
      ));
    }

    // VPD — crop water stress
    final vpdLevel = r.vpd > 2.5 ? 'High stress'
        : r.vpd > 1.5 ? 'Moderate'
        : r.vpd > 0.5 ? 'Optimal'
        : 'Low (risk of fungal)';
    final vpdColor = r.vpd > 2.5 ? _C.red
        : r.vpd > 1.5 ? _C.amber
        : r.vpd < 0.5 ? _C.skyBlue
        : _C.midGreen;
    cards.add(_AdviceCard(
      icon:  Icons.eco_outlined,
      title: 'Crop Water Stress (VPD) — $vpdLevel',
      color: vpdColor,
      bullets: [
        'Vapour Pressure Deficit: ${r.vpd.toStringAsFixed(2)} kPa',
        r.vpd > 2.5
            ? 'Very high evaporation demand. Irrigate crops to prevent wilting.'
            : r.vpd > 1.5
                ? 'Moderate water demand. Consider irrigation if soil is dry.'
                : r.vpd < 0.5
                    ? 'Very low VPD — air is nearly saturated. Fungal risk elevated.'
                    : 'Optimal transpiration conditions for crop growth.',
        'ET₀ this hour: ${r.et0Hour.toStringAsFixed(2)} mm/h '
            '(water evaporating from reference surface)',
      ],
    ));

    // Fertiliser timing
    final okToFertilise = !r.rainingNow && r.windSpeed < 5 &&
        r.humidity < 85;
    cards.add(_AdviceCard(
      icon:  Icons.science_outlined,
      title: okToFertilise
          ? 'Fertiliser Application — Conditions OK'
          : 'Fertiliser Application — Wait',
      color: okToFertilise ? _C.midGreen : _C.amber,
      bullets: [
        if (r.rainingNow)
          '⚠ Currently raining — nutrients will leach before uptake. Wait for dry conditions.',
        if (r.windSpeed >= 5)
          '⚠ Wind ${r.windSpeed.toStringAsFixed(1)} m/s — granules/foliar spray will drift. '
          'Apply when wind drops below 5 m/s.',
        if (r.humidity >= 85 && !r.rainingNow)
          '⚠ Very high humidity — foliar uptake poor. Best to wait.',
        if (okToFertilise) ...[
          '✓ No rain, manageable wind, and good humidity for fertiliser application.',
          'Best time: early morning when wind is lowest and humidity is moderate.',
          'ET₀: ${r.et0Hour.toStringAsFixed(2)} mm/h — '
              '${r.et0Hour > 0.15 ? 'active crop uptake' : 'low evaporation demand'}.',
        ],
      ],
    ));

    return Column(children: cards.map(_buildAdviceCard).toList());
  }

  Widget _buildAdviceCard(_AdviceCard card) {
    final bg     = card.color.withValues(alpha: 0.07);
    final border = card.color.withValues(alpha: 0.25);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(card.icon, size: 15, color: card.color),
            const SizedBox(width: 7),
            Expanded(child: Text(card.title,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: card.color))),
          ]),
          if (card.bullets.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...card.bullets.where((b) => b.trim().isNotEmpty).map((b) =>
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(fontSize: 13,
                        color: card.color.withValues(alpha: 0.7), height: 1.4)),
                    Expanded(child: Text(b,
                        style: TextStyle(fontSize: 12.5, height: 1.45,
                            color: card.color.withValues(alpha: 0.85)))),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── 24-hour history strip ─────────────────────────────────────────────────

  Widget _buildHistoryStrip() {
    if (_history.isEmpty) {
      return Container(
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _C.border),
        ),
        child: const Text('No history data available',
            style: TextStyle(color: Colors.black38, fontSize: 12)),
      );
    }

    // Show last 24 points (hourly)
    final pts = _history.length > 24 ? _history.sublist(_history.length - 24) : _history;
    final maxTemp = pts.map((p) => p.airTemp).reduce((a, b) => a > b ? a : b);
    final minTemp = pts.map((p) => p.airTemp).reduce((a, b) => a < b ? a : b);
    final range   = (maxTemp - minTemp).clamp(1.0, double.infinity);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.thermostat_rounded, size: 12, color: _C.midGreen),
            const SizedBox(width: 4),
            Text('Temperature  ${minTemp.toStringAsFixed(1)}°–${maxTemp.toStringAsFixed(1)}°C',
                style: const TextStyle(fontSize: 11, color: Colors.black45)),
            const Spacer(),
            const Icon(Icons.water_drop_outlined, size: 12, color: _C.skyBlue),
            const SizedBox(width: 3),
            const Text('Humidity', style: TextStyle(fontSize: 11, color: Colors.black45)),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            height: 60,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: pts.map((p) {
                final heightFrac = ((p.airTemp - minTemp) / range).clamp(0.1, 1.0);
                final isWet      = p.lwdHour == 1;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isWet)
                          const Icon(Icons.water_drop_rounded,
                              size: 6, color: _C.skyBlue),
                        Expanded(
                          flex: (heightFrac * 10).round(),
                          child: Container(
                            decoration: BoxDecoration(
                              color: p.airTemp > 35 ? _C.red.withValues(alpha: 0.7)
                                  : _C.midGreen.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),
          // Time labels: first, 6h, 12h, 18h, now
          Row(children: [
            Text(_hourLabel(pts.first.time),
                style: const TextStyle(fontSize: 9, color: Colors.black38)),
            const Spacer(),
            Text(_hourLabel(pts[pts.length ~/ 4].time),
                style: const TextStyle(fontSize: 9, color: Colors.black38)),
            const Spacer(),
            Text(_hourLabel(pts[pts.length ~/ 2].time),
                style: const TextStyle(fontSize: 9, color: Colors.black38)),
            const Spacer(),
            Text(_hourLabel(pts[pts.length * 3 ~/ 4].time),
                style: const TextStyle(fontSize: 9, color: Colors.black38)),
            const Spacer(),
            const Text('Now', style: TextStyle(fontSize: 9, color: Colors.black38)),
          ]),
          const SizedBox(height: 4),
          // Rain row
          if (pts.any((p) => p.rainfall > 0.1))
            Row(children: [
              const Icon(Icons.grain_rounded, size: 10, color: _C.skyBlue),
              const SizedBox(width: 4),
              Text(
                '24h rainfall: ${pts.map((p) => p.rainfall).fold(0.0, (a, b) => a + b).toStringAsFixed(1)} mm  ·  '
                'Leaf wet for ${pts.where((p) => p.lwdHour == 1).length}h',
                style: const TextStyle(fontSize: 10, color: Colors.black45),
              ),
            ]),
        ],
      ),
    );
  }

  // ── Upcoming spray windows (48h forecast) ───────────────────────────────
  // Uses GET /derived/forecast — turns "what just happened" into "when to
  // act". Non-critical: if it fails to load, this section just shows a
  // quiet empty state instead of an error.

  Widget _buildForecastStrip() {
    if (_forecast.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.border),
        ),
        child: const Text('Forecast unavailable right now.',
            style: TextStyle(fontSize: 12, color: Colors.black38)),
      );
    }

    final nextWindow = NuaSenseService.nextGoodSprayWindow(_forecast);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (nextWindow != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: _C.lightGreen,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(Icons.event_available_rounded, size: 15, color: _C.midGreen),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'Next good window: ${_hourLabel(nextWindow.start)}–'
                '${_hourLabel(nextWindow.end)}'
                '${nextWindow.start.day != DateTime.now().day ? ' (${nextWindow.start.day}/${nextWindow.start.month})' : ''}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: _C.midGreen),
              )),
            ]),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('No clearly good spray window in the next '
                '${_forecast.length}h — conditions stay marginal or poor.',
                style: const TextStyle(fontSize: 12, color: Colors.black45)),
          ),
        // Simple hour-by-hour quality bar strip
        SizedBox(
          height: 46,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: _forecast.take(24).map((p) {
              final frac = (p.sprayQualityIndex / 100).clamp(0.05, 1.0);
              final color = p.sprayQualityIndex >= 70 ? _C.midGreen
                  : p.sprayQualityIndex >= 40 ? _C.amber
                  : _C.red;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        flex: (frac * 10).round(),
                        child: Container(
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 4),
        Text('Next ${_forecast.take(24).length}h  ·  green = good, amber = marginal, red = poor',
            style: const TextStyle(fontSize: 9.5, color: Colors.black38)),
      ]),
    );
  }

  // ── Degree-day pest pressure ──────────────────────────────────────────────

  Widget _buildDegreeDaySection() {
    final r = _reading!;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pest pressure is estimated from temperature-based degree-day '
            'accumulation. Higher values = faster pest development.',
            style: TextStyle(fontSize: 11, color: Colors.black45, height: 1.4),
          ),
          const SizedBox(height: 4),
          const Text('Crop-specific',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700,
                  color: Colors.black38, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          _ddTile('Fall armyworm pressure',
              r.ddFawHour, 0.4, 1.0,
              'Maize, sorghum, sugarcane — scout whorls for frass',
              Icons.bug_report_outlined),
          _ddTile('Diamondback moth pressure',
              r.ddDbmHour, 0.3, 0.8,
              'Cabbage, kale, brassicas — check leaf undersides',
              Icons.pest_control_outlined),
          _ddTile('Tuta absoluta pressure',
              r.ddTutaHour, 0.4, 1.0,
              'Tomatoes — leaf-mining tunnels, collapsing fruit',
              Icons.pest_control_rodent_outlined),
          _ddTile('Thrips pressure',
              r.ddThripsHour, 0.3, 0.7,
              'Onions, beans, flowers — silvery streaks on leaves',
              Icons.pest_control_outlined),
          _ddTile('African armyworm pressure',
              r.ddArmywormHour, 0.4, 1.0,
              'Pasture, cereals — moves in bands, strips leaves fast',
              Icons.pest_control_rodent_outlined),
          _ddTile('Coffee berry borer pressure',
              r.ddCbbHour, 0.2, 0.5,
              'Coffee only — small holes bored into ripening berries',
              Icons.bug_report_outlined),
          const SizedBox(height: 8),
          const Text('General',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700,
                  color: Colors.black38, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          _ddTile('Aphid pressure',
              r.ddAphidHour, 0.5, 1.2,
              'Base 4.3°C — aphids develop faster in warm humid conditions',
              Icons.bug_report_outlined),
          _ddTile('Whitefly pressure',
              r.ddWhiteflyHour, 0.3, 0.8,
              'Base 10°C — thrives in hot dry weather above 25°C',
              Icons.pest_control_outlined),
          _ddTile('Potato tuber moth pressure',
              r.ddPtmHour, 0.4, 1.0,
              'Base 10.5°C — risk increases above 25°C night temperatures',
              Icons.pest_control_rodent_outlined),
        ],
      ),
    );
  }

  Widget _ddTile(String label, double val, double medThresh, double highThresh,
      String description, IconData icon) {
    final color = val >= highThresh ? _C.red
        : val >= medThresh ? _C.amber
        : _C.midGreen;
    final level = val >= highThresh ? 'High'
        : val >= medThresh ? 'Medium'
        : 'Low';
    final barFrac = (val / highThresh).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(level,
                style: TextStyle(fontSize: 10, color: color,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: barFrac,
            minHeight: 6,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 3),
        Text('${val.toStringAsFixed(3)} °C·d this hour  ·  $description',
            style: const TextStyle(fontSize: 10, color: Colors.black38)),
      ]),
    );
  }

  // ── About bottom sheet ────────────────────────────────────────────────────

  void _showAbout() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 16),
            const Text('About Weather Station Data',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _aboutRow(Icons.sensors_rounded, 'Data source',
                'NuaSense Partner API — physical weather station installed at a '
                'partner farm in your region.'),
            _aboutRow(Icons.refresh_rounded, 'Update frequency',
                'Station records every ~10 minutes. This app fetches fresh data '
                'every 10 minutes and caches between calls.'),
            _aboutRow(Icons.speed_rounded, 'Spray quality score',
                'A single 0–100 score combining wind speed, delta-T '
                '(droplet drying risk) and temperature-inversion risk, '
                'provided directly by the station. Replaces the old '
                'wind-only check.'),
            _aboutRow(Icons.eco_outlined, 'VPD (vapour pressure deficit)',
                'Measures the drying power of the air. High VPD (>2 kPa) means '
                'the crop is stressed. Low VPD (<0.5 kPa) favours fungal disease.'),
            _aboutRow(Icons.water_drop_outlined, 'Leaf wetness (LWD)',
                'Computed hourly. A leaf-wet hour occurs when humidity is high, '
                'dew-point depression is ≤2°C, or rainfall is recorded. '
                'Consecutive wet hours drive most fungal infections.'),
            _aboutRow(Icons.event_available_rounded, 'Forecast',
                'Projects the signals above up to 7 days ahead (GET '
                '/derived/forecast), so you can plan spraying rather than '
                'only reacting to current conditions.'),
            _aboutRow(Icons.bug_report_outlined, 'Degree-days',
                'Temperature above a pest\'s threshold, accumulated per hour. '
                'Aphids (base 4.3°C), whitefly (base 10°C), potato tuber '
                'moth (base 10.5°C), plus crop-specific pests added in '
                'July 2026: fall armyworm, diamondback moth, Tuta absoluta, '
                'thrips, African armyworm and coffee berry borer.'),
          ]),
        ),
      ),
    );
  }

  Widget _aboutRow(IconData icon, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: _C.midGreen),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600,
              fontSize: 13)),
          const SizedBox(height: 3),
          Text(body, style: const TextStyle(fontSize: 12, color: Colors.black54,
              height: 1.45)),
        ])),
      ]),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(label.toUpperCase(),
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            color: _C.midGreen, letterSpacing: 0.8)),
  );

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  String _hourLabel(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:00';

  // ── No-GPS banner ─────────────────────────────────────────────────────────
  Widget _noGpsBanner() {
    if (_isPlotGps || _plots.isEmpty) return const SizedBox.shrink();
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
          'Using $_county county — add a GPS pin to your plot '
          'in Field Data → Plot Setup to match this station to your exact farm.',
          style: const TextStyle(fontSize: 12, color: Color(0xFFE65100),
              height: 1.4),
        )),
      ]),
    );
  }
}

// ── Internal model ────────────────────────────────────────────────────────────

class _AdviceCard {
  final IconData icon;
  final String title;
  final Color color;
  final List<String> bullets;
  const _AdviceCard({required this.icon, required this.title,
      required this.color, required this.bullets});
}

// ── Shared plot-switcher button (same as satellite_data_screen) ───────────────
// Defined here so WeatherStationScreen can use it without a circular import.
// satellite_data_screen.dart has its own identical copy — keep them in sync,
// or extract to lib/widgets/plot_switcher_button.dart if they diverge.

// ── Station-switcher button (multi-station accounts, July 2026) ──────────────
// Same interaction pattern as the plot switcher below — a compact pill in
// the AppBar that opens a bottom sheet listing every station the account
// owns (from GET /stations), with online/offline status.

class _StationSwitcherButton extends StatelessWidget {
  final List<NuaStation> stations;
  final String?          selectedStationId;
  final void Function(String? stationId) onSelect;

  const _StationSwitcherButton({
    required this.stations,
    required this.selectedStationId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final current = stations.where((s) => s.id == selectedStationId).firstOrNull
        ?? stations.firstOrNull;

    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.sensors_rounded, size: 14,
              color: current?.online == true ? Colors.white : Colors.white54),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 90),
            child: Text(
              current?.name ?? 'Station',
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
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Text('Switch weather station',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                      color: Color(0xFF032704))),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Choose which of your NuaSense stations to read from.',
                style: TextStyle(fontSize: 12.5, color: Colors.black54,
                    height: 1.4),
              ),
            ),
            const Divider(height: 1),
            ...stations.map((s) {
              final isSelected = s.id == selectedStationId ||
                  (selectedStationId == null && s == stations.first);
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
                    Icons.sensors_rounded,
                    size: 18,
                    color: !s.online
                        ? Colors.grey
                        : isSelected
                            ? const Color(0xFF2A6B2A)
                            : Colors.black54,
                  ),
                ),
                title: Text(s.name,
                    style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: 14,
                        color: isSelected
                            ? const Color(0xFF032704)
                            : Colors.black87)),
                subtitle: Text(
                  s.online ? 'Online' : 'Offline',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: s.online
                          ? Colors.black54
                          : const Color(0xFFB71C1C)),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle,
                        color: Color(0xFF2A6B2A), size: 20)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  onSelect(s.id);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

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
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Text('Switch farm',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                      color: Color(0xFF032704))),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Weather data will update to use the selected farm\'s GPS.',
                style: TextStyle(fontSize: 12.5, color: Colors.black54,
                    height: 1.4),
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
                  p.hasGps
                      ? p.locationLabel
                      : '${p.county} (county estimate)',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: p.hasGps
                          ? Colors.black54
                          : const Color(0xFFE65100)),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle,
                        color: Color(0xFF2A6B2A), size: 20)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  onSelect(p.id);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}