// lib/widgets/weather_station_inline_panel.dart
//
// A compact, self-loading panel that shows NuaSense weather-station data
// inline inside any Step 2 screen (Field Data Input, Pest Management,
// Disease Management) — no navigation needed.
//
// It sits right below the FarmEnvironmentCard / satellite panel and shows:
//   • Status bar (live / stale)
//   • 3-metric mini-grid (air temp, humidity, wind)
//   • Spray window status (most critical action card) — now driven by
//     NuaSense's own spray_quality_index/_label/_limiting_factor when
//     available, with the old wind/rain heuristic as a fallback.
//   • Leaf wetness + VPD cards (relevant to pest/disease and fertiliser).
//     Leaf wetness now also shows lwd_consecutive_hours.
//   • Pest degree-day pressure strip (relevant for pest/disease step 2) —
//     now selects crop-specific pests (fall armyworm, diamondback moth,
//     Tuta absoluta, thrips, coffee berry borer) based on [cropNames],
//     alongside the original aphid/whitefly/PTM tiles.
//   • Rainfall last hour + 24h total
//   • "Full station data →" link to WeatherStationScreen
//
// Parameters:
//   [showDegreeDays]   – true for pest/disease Step 2, false for field Step 2
//   [showFertiliser]   – true for field Step 2 (fertiliser timing advice)
//   [cropNames]        – e.g. ['Maize', 'Tomatoes'] — used for crop-specific
//                        spray window advice copy AND to pick which
//                        crop-specific pest degree-day tiles to show
//
// Usage:
//   WeatherStationInlinePanel(
//     showDegreeDays: true,
//     showFertiliser: false,
//     cropNames: ['Tomatoes'],
//     onOpenFullScreen: () => Navigator.push(context, ...WeatherStationScreen),
//   )
//


import 'package:flutter/material.dart';
import 'package:kilimomkononi/services/nuasense_service.dart';

// ── Palette (mirrors weather_station_screen.dart) ──────────────────────────
class _C {
  static const midGreen   = Color(0xFF2A6B2A);
  static const lightGreen = Color(0xFFE8F5E9);
  static const skyBlue    = Color(0xFF1565C0);
  static const amber      = Color(0xFFE65100);
  static const lightAmber = Color(0xFFFFF8E1);
  static const red        = Color(0xFFB71C1C);
  static const border     = Color(0xFFDDE4DC);
}

// ─────────────────────────────────────────────────────────────────────────────

class WeatherStationInlinePanel extends StatefulWidget {
  final bool showDegreeDays;
  final bool showFertiliser;
  final List<String> cropNames;
  final VoidCallback? onOpenFullScreen;

  const WeatherStationInlinePanel({
    super.key,
    this.showDegreeDays   = false,
    this.showFertiliser   = false,
    this.cropNames        = const [],
    this.onOpenFullScreen,
  });

  @override
  State<WeatherStationInlinePanel> createState() =>
      _WeatherStationInlinePanelState();
}

class _WeatherStationInlinePanelState
    extends State<WeatherStationInlinePanel> {
  bool _loading = true;
  String? _error;
  NuaSenseReading? _r;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final r = await NuaSenseService.getLatestReading();
      if (!mounted) return;
      setState(() { _r = r; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = '$e'; _loading = false; });
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Header row ───────────────────────────────────────────────────────
      Row(children: [
        const Icon(Icons.sensors_rounded, size: 14, color: _C.midGreen),
        const SizedBox(width: 6),
        const Text('WEATHER STATION',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: _C.midGreen, letterSpacing: 0.8)),
        const Spacer(),
        if (!_loading && _error == null)
          GestureDetector(
            onTap: () {
              NuaSenseService.clearCache();
              _load();
            },
            child: const Icon(Icons.refresh_rounded, size: 15, color: _C.midGreen),
          ),
        if (widget.onOpenFullScreen != null) ...[
          const SizedBox(width: 10),
          GestureDetector(
            onTap: widget.onOpenFullScreen,
            child: const Text('Full data →',
                style: TextStyle(fontSize: 11, color: _C.skyBlue,
                    decoration: TextDecoration.underline,
                    decorationColor: _C.skyBlue)),
          ),
        ],
      ]),
      const SizedBox(height: 8),

      // ── States ───────────────────────────────────────────────────────────
      if (_loading)
        _loadingCard()
      else if (_error != null)
        _errorCard()
      else if (!_r!.isProvisioned)
        _notProvisionedCard()
      else
        _buildContent(_r!),
    ]);
  }

  Widget _loadingCard() => Container(
    height: 56,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _C.border),
    ),
    child: const Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: 16, height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: _C.midGreen)),
      SizedBox(width: 10),
      Text('Loading weather station…',
          style: TextStyle(fontSize: 12, color: Colors.black45)),
    ]),
  );

  Widget _errorCard() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: _C.lightAmber,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _C.amber.withValues(alpha: 0.3)),
    ),
    child: Row(children: [
      const Icon(Icons.wifi_off_rounded, size: 15, color: _C.amber),
      const SizedBox(width: 8),
      const Expanded(child: Text('Weather station offline. Using satellite data only.',
          style: TextStyle(fontSize: 12, color: _C.amber))),
      GestureDetector(
        onTap: _load,
        child: const Text('Retry', style: TextStyle(fontSize: 12,
            color: _C.skyBlue, fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline)),
      ),
    ]),
  );

  // Distinct from _errorCard() on purpose: this isn't a fetch failure, it's
  // the expected state for any farmer who hasn't had a station installed
  // yet — calm and informational rather than "something's wrong."
  Widget _notProvisionedCard() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: _C.lightGreen,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _C.midGreen.withValues(alpha: 0.25)),
    ),
    child: const Row(children: [
      Icon(Icons.sensors_off_rounded, size: 15, color: _C.midGreen),
      SizedBox(width: 8),
      Expanded(child: Text(
        'No weather station installed on this farm yet — using satellite '
        'data only for now.',
        style: TextStyle(fontSize: 12, color: _C.midGreen),
      )),
    ]),
  );

  Widget _buildContent(NuaSenseReading r) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ── Status + timestamp bar ──────────────────────────────────────────
      _statusBar(r),
      const SizedBox(height: 8),

      // ── 3-up conditions mini-grid ───────────────────────────────────────
      Row(children: [
        Expanded(child: _miniCard(
          icon: Icons.thermostat_rounded,
          label: 'Air Temp',
          value: '${r.airTemp.toStringAsFixed(1)}°C',
          color: r.airTemp > 35 ? _C.red : r.airTemp < 15 ? _C.skyBlue : _C.midGreen,
          alert: r.airTemp > 35 ? '⚠ High heat' : r.airTemp < 12 ? '⚠ Frost risk' : null,
        )),
        const SizedBox(width: 8),
        Expanded(child: _miniCard(
          icon: Icons.water_drop_outlined,
          label: 'Humidity',
          value: '${r.humidity.toStringAsFixed(0)}%',
          color: r.humidity > 80 ? _C.red : r.humidity > 65 ? _C.amber : _C.midGreen,
          alert: r.humidity > 80 ? '⚠ Fungal risk' : null,
        )),
        const SizedBox(width: 8),
        Expanded(child: _miniCard(
          icon: Icons.grain_rounded,
          label: 'Rain / 1h',
          value: '${r.rainfall.toStringAsFixed(1)} mm',
          color: r.rainfall > 5 ? _C.skyBlue : Colors.grey,
          alert: r.rainfall > 15 ? '⚠ Heavy rain' : null,
        )),
      ]),
      const SizedBox(height: 8),

      // ── Spray window alert ──────────────────────────────────────────────
      // This is the single most actionable card for pest & disease Step 2.
      _sprayWindowCard(r),
      const SizedBox(height: 8),

      // ── Leaf wetness card ──────────────────────────────────────────────
      _leafWetnessCard(r),

      // ── VPD / crop water stress (always show) ───────────────────────────
      const SizedBox(height: 8),
      _vpdCard(r),

      // ── Fertiliser timing (field Step 2 only) ──────────────────────────
      if (widget.showFertiliser) ...[
        const SizedBox(height: 8),
        _fertiliserCard(r),
      ],

      // ── Pest degree-day strip (pest/disease Step 2 only) ───────────────
      if (widget.showDegreeDays) ...[
        const SizedBox(height: 8),
        _degreeDayStrip(r),
      ],

      // ── Wind detail row ─────────────────────────────────────────────────
      const SizedBox(height: 6),
      _windRow(r),
    ]);
  }

  // ── Status bar ────────────────────────────────────────────────────────────

  Widget _statusBar(NuaSenseReading r) {
    final stale   = r.isStale;
    final timeAgo = _timeAgo(r.timestamp);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: stale ? _C.lightAmber : _C.lightGreen,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: (stale ? _C.amber : _C.midGreen).withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Icon(stale ? Icons.access_time_rounded : Icons.sensors_rounded,
            size: 12, color: stale ? _C.amber : _C.midGreen),
        const SizedBox(width: 5),
        Text(
          stale ? 'Cached · Updated $timeAgo' : 'Live · $timeAgo',
          style: TextStyle(fontSize: 11,
              color: stale ? _C.amber : _C.midGreen,
              fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Text('NuaSense station',
            style: const TextStyle(fontSize: 10, color: Colors.black38)),
      ]),
    );
  }

  // ── Mini metric card ──────────────────────────────────────────────────────

  Widget _miniCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    String? alert,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: alert != null
            ? color.withValues(alpha: 0.4)
            : _C.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.black45,
              fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 5),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
            color: color)),
        if (alert != null) ...[
          const SizedBox(height: 2),
          Text(alert, style: TextStyle(fontSize: 9.5, color: color),
              overflow: TextOverflow.ellipsis),
        ],
      ]),
    );
  }

  // ── Spray window card ─────────────────────────────────────────────────────
  // This is the key actionable card — shown prominently.

  Widget _sprayWindowCard(NuaSenseReading r) {
    // Prefer NuaSense's own combined spray-quality score (wind + delta-T +
    // inversion risk) when the Cloud Function is returning it. Fall back to
    // the old wind/rain-only heuristic if the field is missing (e.g. before
    // the proxy has been redeployed with the new field list).
    final hasQualityBlock = r.sprayQualityLabel.isNotEmpty;

    final cropStr = widget.cropNames.isEmpty ? 'your crops'
        : widget.cropNames.take(2).join(' and ');

    if (hasQualityBlock) {
      final good     = r.sprayQualityGood;
      final marginal = r.sprayQualityMarginal;
      final color = good ? _C.midGreen : marginal ? _C.amber : _C.red;

      final bullets = <String>[
        'Spray quality: ${r.sprayQualityIndex.toStringAsFixed(0)}/100 — ${r.sprayQualityLabel}',
      ];
      if (!good && r.sprayLimitingFactor.isNotEmpty) {
        final factorLabel = switch (r.sprayLimitingFactor) {
          'wind'      => 'wind speed',
          'delta_t'   => 'delta-T (evaporation risk — droplets drying before they land)',
          'inversion' => 'a temperature inversion (drift can hang near the ground)',
          'rain'      => 'rain',
          _           => r.sprayLimitingFactor,
        };
        bullets.add('Main limiting factor right now: $factorLabel.');
      }
      bullets.add('Wind ${r.windSpeed.toStringAsFixed(1)} m/s  ·  '
          'Delta-T ${r.deltaT.toStringAsFixed(1)}°C'
          '${r.inversionRisk.isNotEmpty ? '  ·  Inversion risk: ${r.inversionRisk}' : ''}');
      if (good) {
        bullets.add('Good window for $cropStr right now. Still best in early '
            'morning or late afternoon when it stays this way for longer.');
      } else if (marginal) {
        bullets.add('Usable but not ideal — expect some drift or faster '
            'evaporation. Consider waiting if the job isn\'t urgent.');
      } else {
        bullets.add('Hold off on $cropStr. Check back later or use the '
            'forecast to find the next good window.');
      }
      if (r.humidity > 85 && good) {
        bullets.add('Humidity ${r.humidity.toStringAsFixed(0)}% — very high. '
            'Fungal spores spread easily. Consider a preventive fungicide with your next spray.');
      }

      return _adviceCard(
        icon:  good ? Icons.opacity_outlined
             : marginal ? Icons.warning_amber_rounded
             : Icons.not_interested_rounded,
        title: good ? 'Spray Window — ${r.sprayQualityLabel}'
             : marginal ? 'Spray Window — ${r.sprayQualityLabel}'
             : 'Spray Window — ${r.sprayQualityLabel}',
        color: color,
        bullets: bullets,
      );
    }

    // ── Fallback: old wind/rain/daylight heuristic ─────────────────────────
    final goodWind  = r.goodSprayWind;          // < 3 m/s
    final noRain    = !r.rainingNow;
    final hour      = DateTime.now().hour;
    final inWindow  = hour >= 6 && hour <= 17;
    final canSpray  = goodWind && noRain && inWindow;

    final bullets = <String>[];
    if (canSpray) {
      bullets.add('Wind ${r.windSpeed.toStringAsFixed(1)} m/s ✓  ·  No rain ✓  ·  Daylight ✓');
      bullets.add('Best time to spray $cropStr: early morning 6–9am or late afternoon 4–5pm.');
      bullets.add('Always spray when air is still and not too hot (avoid 11am–2pm).');
    } else {
      if (!goodWind) {
        bullets.add('Wind ${r.windSpeed.toStringAsFixed(1)} m/s — too high. '
          'Wait for it to drop below 3 m/s. Drift will waste product and harm bees.');
      }
      if (!noRain) {
        bullets.add('Currently raining — product will wash off leaves '
          'before it can work. Wait for at least 2 dry hours after rain stops.');
      }
      if (!inWindow) {
        bullets.add('Outside safe spray hours (6am–5pm). Spray early morning '
          'when wind is lowest and product sticks better.');
      }
    }
    if (r.humidity > 85 && canSpray) {
      bullets.add('Humidity ${r.humidity.toStringAsFixed(0)}% — very high. '
          'Fungal spores spread easily. Consider a preventive fungicide with your next spray.');
    }

    return _adviceCard(
      icon:   canSpray ? Icons.opacity_outlined : Icons.not_interested_rounded,
      title:  canSpray ? 'Spray Window — Safe to Spray Now' : 'Spray Window — Do Not Spray Yet',
      color:  canSpray ? _C.midGreen : _C.amber,
      bullets: bullets,
    );
  }

  // ── Leaf wetness card ─────────────────────────────────────────────────────

  Widget _leafWetnessCard(NuaSenseReading r) {
    final wet     = r.leafIsWet;
    final reason  = r.lwdReason.isNotEmpty
        ? r.lwdReason.replaceAll('_', ' ')
        : 'conditions indicate wetness';
    final bullets = <String>[];

    if (wet) {
      bullets.add('Cause: $reason. Leaves wet = fungal spores can germinate and infect.');
      if (r.lwdConsecutiveHours > 0) {
        final long = r.lwdConsecutiveHours >= 6;
        bullets.add('Wet for ${r.lwdConsecutiveHours} hour'
            '${r.lwdConsecutiveHours == 1 ? '' : 's'} in a row'
            '${long ? ' — long unbroken wetness is when most fungal infection actually takes hold.' : '.'}');
      }
      bullets.add('Scout your crop today — look for early signs of blight, '
          'mildew, grey leaf spot on lower leaves first.');
      bullets.add('Do NOT spray foliar fertiliser or systemic pesticide while leaves '
          'are wet — product will run off and not absorb properly.');
      bullets.add('Dew gap: ${r.dewPointDepression.toStringAsFixed(1)}°C  '
          '(≤2°C means near-condensation — very high disease risk).');
    } else {
      bullets.add('Dew gap: ${r.dewPointDepression.toStringAsFixed(1)}°C  '
          '·  Dew point: ${r.dewPoint.toStringAsFixed(1)}°C.');
      bullets.add('Good conditions for foliar applications — leaves dry, '
          'product will be absorbed and not washed off.');
    }

    return _adviceCard(
      icon:    wet ? Icons.water_drop_rounded : Icons.check_circle_outline_rounded,
      title:   wet ? 'Leaves Are Wet — Disease Risk Elevated' : 'Leaves Are Dry — Good Conditions',
      color:   wet ? _C.red : _C.midGreen,
      bullets: bullets,
    );
  }

  // ── VPD / crop water stress card ──────────────────────────────────────────

  Widget _vpdCard(NuaSenseReading r) {
    final vpd   = r.vpd;
    final level = vpd > 2.5 ? 'Severe stress'
        : vpd > 1.5 ? 'Moderate stress'
        : vpd < 0.5 ? 'Very low — fungal risk'
        : 'Optimal';
    final color = vpd > 2.5 ? _C.red
        : vpd > 1.5 ? _C.amber
        : vpd < 0.5 ? _C.skyBlue
        : _C.midGreen;

    final bullets = <String>[];
    bullets.add('VPD: ${vpd.toStringAsFixed(2)} kPa  ·  ET₀: ${r.et0Hour.toStringAsFixed(2)} mm/h');

    if (vpd > 2.5) {
      bullets.add('Very high evaporation demand — crops losing water fast. '
          'Irrigate in the next few hours to prevent wilting and tip-burn.');
      bullets.add('Any fertiliser applied now will not be taken up well. '
          'Irrigate first, then fertilise when VPD drops below 2 kPa.');
    } else if (vpd > 1.5) {
      bullets.add('Moderate water demand. Check soil moisture — if dry, plan '
          'irrigation within 24 hours.');
    } else if (vpd < 0.5) {
      bullets.add('Air is nearly saturated. Fungal spores thrive. Scout for '
          'early blight, mildew and rust symptoms. Keep good air circulation '
          'between plants (weed, prune lower leaves).');
    } else {
      bullets.add('Good transpiration conditions — crop growing efficiently. '
          'Continue normal scouting and watering schedule.');
    }

    return _adviceCard(
      icon:    Icons.eco_outlined,
      title:   'Crop Water Stress (VPD) — $level',
      color:   color,
      bullets: bullets,
    );
  }

  // ── Fertiliser timing card (field Step 2 only) ────────────────────────────

  Widget _fertiliserCard(NuaSenseReading r) {
    final ok = !r.rainingNow && r.windSpeed < 5 && r.humidity < 85;
    final bullets = <String>[];

    if (r.rainingNow) {
      bullets.add('Currently raining — granular fertiliser will dissolve too '
          'fast and leach below the root zone before roots can absorb it. Wait for dry.');
      bullets.add('Foliar fertiliser will run off immediately. Do not apply now.');
    }
    if (r.windSpeed >= 5) {
      bullets.add('Wind ${r.windSpeed.toStringAsFixed(1)} m/s — granules and '
          'foliar spray will drift away from the target crop. Wait for calm < 5 m/s.');
    }
    if (r.humidity >= 85 && !r.rainingNow) {
      bullets.add('Humidity ${r.humidity.toStringAsFixed(0)}% — very high. '
          'Foliar uptake is slow. Granular fertiliser is fine in these conditions '
          'if the soil surface is moist but not waterlogged.');
    }
    if (ok) {
      bullets.add('Conditions look good for applying fertiliser. '
          'Best time: early morning when wind is lowest.');
      bullets.add('ET₀ ${r.et0Hour.toStringAsFixed(2)} mm/h — '
          '${r.et0Hour > 0.15 ? 'active crop uptake, fertiliser will be absorbed well' : 'low evaporation, ideal for slow-release products'}.');
    }

    return _adviceCard(
      icon:   ok ? Icons.science_outlined : Icons.warning_amber_rounded,
      title:  ok ? 'Fertiliser Application — Conditions OK' : 'Fertiliser Application — Wait',
      color:  ok ? _C.midGreen : _C.amber,
      bullets: bullets,
    );
  }

  // ── Degree-day pest pressure strip (pest/disease Step 2 only) ─────────────
  //
  // Tailored to crops common in Kenya — aphids, whitefly, PTM for potato,
  // plus a generalist cutworm/caterpillar degree-day approximation.

  // Maps the crops passed into this panel to the crop-specific pest
  // degree-day tiles worth showing. Falls back to the three most broadly
  // useful pests if no crop match is found (or no crops were passed in).
  List<_DdSpec> _relevantCropPests(NuaSenseReading r) {
    final crops = widget.cropNames.map((c) => c.toLowerCase()).toList();
    bool has(List<String> keywords) =>
        crops.any((c) => keywords.any((k) => c.contains(k)));

    final specs = <_DdSpec>[];
    if (has(['maize', 'sorghum', 'sugarcane', 'corn'])) {
      specs.add(_DdSpec('Fall armyworm', Icons.bug_report_outlined,
          r.ddFawHour, 0.4, 1.0,
          'Maize, sorghum, sugarcane · scout whorls for frass and windowpaning'));
    }
    if (has(['cabbage', 'kale', 'sukuma', 'broccoli', 'brassica', 'collard'])) {
      specs.add(_DdSpec('Diamondback moth', Icons.pest_control_outlined,
          r.ddDbmHour, 0.3, 0.8,
          'Cabbage, kale, other brassicas · check undersides of leaves'));
    }
    if (has(['tomato'])) {
      specs.add(_DdSpec('Tuta absoluta', Icons.pest_control_rodent_outlined,
          r.ddTutaHour, 0.4, 1.0,
          'Tomatoes · leaf-mining tunnels, collapsing fruit'));
    }
    if (has(['onion', 'bean', 'flower', 'legume'])) {
      specs.add(_DdSpec('Thrips', Icons.pest_control_outlined,
          r.ddThripsHour, 0.3, 0.7,
          'Onions, beans, flowers · silvery streaks on leaves/petals'));
    }
    if (has(['coffee'])) {
      specs.add(_DdSpec('Coffee berry borer', Icons.bug_report_outlined,
          r.ddCbbHour, 0.2, 0.5,
          'Coffee only · small holes bored into ripening berries'));
    }
    if (has(['pasture', 'napier', 'cereal', 'wheat', 'barley'])) {
      specs.add(_DdSpec('African armyworm', Icons.pest_control_rodent_outlined,
          r.ddArmywormHour, 0.4, 1.0,
          'Pasture, cereals · large larvae strip leaves fast, moves in bands'));
    }

    if (specs.isEmpty) {
      // No crop match — show the three broadest-relevance pests so the
      // strip is still useful.
      specs.addAll([
        _DdSpec('Fall armyworm', Icons.bug_report_outlined,
            r.ddFawHour, 0.4, 1.0, 'Maize, sorghum, sugarcane'),
        _DdSpec('Diamondback moth', Icons.pest_control_outlined,
            r.ddDbmHour, 0.3, 0.8, 'Cabbage, kale, brassicas'),
        _DdSpec('Tuta absoluta', Icons.pest_control_rodent_outlined,
            r.ddTutaHour, 0.4, 1.0, 'Tomatoes'),
      ]);
    }
    return specs;
  }

  Widget _degreeDayStrip(NuaSenseReading r) {
    final cropPests = _relevantCropPests(r);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _C.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.pest_control_outlined, size: 13, color: _C.midGreen),
          const SizedBox(width: 6),
          const Text('PEST PRESSURE (this hour)',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: _C.midGreen, letterSpacing: 0.5)),
        ]),
        const SizedBox(height: 4),
        const Text(
          'Temperature-based. Higher values = pests developing faster. '
          'Scout immediately at medium or high pressure.',
          style: TextStyle(fontSize: 10.5, color: Colors.black45, height: 1.4),
        ),
        const SizedBox(height: 10),
        // Crop-specific tiles first — most relevant to what's actually planted.
        for (final s in cropPests)
          _ddBar(s.label, s.icon, s.value, s.medThresh, s.highThresh, s.sub),
        // Legacy general-purpose tiles, always shown for continuity.
        _ddBar('Aphid', Icons.bug_report_outlined,
            r.ddAphidHour, 0.5, 1.2,
            'Base 4.3°C · warm + humid · maize, beans, tomatoes, cabbage'),
        _ddBar('Whitefly', Icons.pest_control_outlined,
            r.ddWhiteflyHour, 0.3, 0.8,
            'Base 10°C · hot + dry · tomatoes, beans, kales'),
        _ddBar('Potato tuber moth', Icons.pest_control_rodent_outlined,
            r.ddPtmHour, 0.4, 1.0,
            'Base 10.5°C · warm nights · Irish potatoes, tomatoes'),
      ]),
    );
  }

  Widget _ddBar(String label, IconData icon, double val,
      double medThresh, double highThresh, String crops) {
    final color = val >= highThresh ? _C.red
        : val >= medThresh ? _C.amber
        : _C.midGreen;
    final level = val >= highThresh ? 'High'
        : val >= medThresh ? 'Medium'
        : 'Low';
    final barFrac = (val / highThresh).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
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
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: barFrac, minHeight: 5,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 2),
        Text(crops, style: const TextStyle(fontSize: 9.5, color: Colors.black38)),
        if (val >= medThresh) ...[
          const SizedBox(height: 2),
          Text(
            val >= highThresh
                ? '⚠ Scout immediately. Consider applying pesticide if damage found.'
                : '⚠ Scout this crop today — check for eggs, nymphs and damage on leaves.',
            style: TextStyle(fontSize: 10, color: color, height: 1.3),
          ),
        ],
      ]),
    );
  }

  // ── Wind detail row ───────────────────────────────────────────────────────

  Widget _windRow(NuaSenseReading r) {
    final color = r.windSpeed > 6 ? _C.red
        : r.windSpeed > 3 ? _C.amber
        : Colors.black45;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _C.border),
      ),
      child: Row(children: [
        const Icon(Icons.air_rounded, size: 12, color: Colors.black38),
        const SizedBox(width: 5),
        Text('Wind: ${r.windSpeed.toStringAsFixed(1)} m/s  ${r.windDirLabel}  '
            '(gusts ${r.windGusts.toStringAsFixed(1)} m/s)',
            style: TextStyle(fontSize: 11, color: color)),
        const Spacer(),
        Text(r.windSpeed < 3 ? '✓ Safe' : r.windSpeed < 6 ? '⚠ Caution' : '✗ Too high',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }

  // ── Shared advice card builder ─────────────────────────────────────────────

  Widget _adviceCard({
    required IconData icon,
    required String title,
    required Color color,
    required List<String> bullets,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 7),
          Expanded(child: Text(title,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color))),
        ]),
        if (bullets.isNotEmpty) ...[
          const SizedBox(height: 7),
          ...bullets.map((b) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('• ', style: TextStyle(fontSize: 13, color: color.withValues(alpha: 0.6),
                  height: 1.4)),
              Expanded(child: Text(b,
                  style: TextStyle(fontSize: 12, height: 1.45,
                      color: color.withValues(alpha: 0.85)))),
            ]),
          )),
        ],
      ]),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

// ── Internal spec for a crop-specific degree-day tile ───────────────────────
class _DdSpec {
  final String label;
  final IconData icon;
  final double value;
  final double medThresh;
  final double highThresh;
  final String sub;
  const _DdSpec(this.label, this.icon, this.value, this.medThresh,
      this.highThresh, this.sub);
}