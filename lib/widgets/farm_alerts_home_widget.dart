// lib/widgets/farm_alerts_home_widget.dart
//
// Farm Alerts on Home + Field Data home.
// Shows the SAME advice stack as Weather Station:
//   1) Today's plan from buildKmDayPlan (station parameters → Do/Avoid)
//   2) Verified advice — advisories a Field Agronomist published for the
//      farmer's crops and today's station conditions (same query as the
//      Weather Station's "Verified advice"). Without a station, only
//      "Any conditions" advice for their crops.
// The AI Farm Advisor stays on the Weather Station screen only.
// Does NOT use FarmAlertService pest degree-day / NuaSense catalogue alerts.
// Tap → full Weather Station screen (plan + verified + AI advice).

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_conditions.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_widgets.dart';
import 'package:kilimomkononi/enterprise/features/weather/agronomic_advisory.dart';
import 'package:kilimomkononi/enterprise/features/weather/agronomic_advisory_service.dart';
import 'package:kilimomkononi/services/farm_location_service.dart';
import 'package:kilimomkononi/services/nuasense_service.dart';
import 'package:kilimomkononi/services/weather_day_plan.dart';
import 'package:kilimomkononi/screens/Field%20Data%20Input/weather_station_screen.dart';

class FarmAlertsHomeWidget extends StatefulWidget {
  /// Opens the Weather Station. Defaults to pushing the screen; the Field
  /// Data Input hub passes a callback that switches to its Weather tab.
  final VoidCallback? onOpenWeatherStation;

  const FarmAlertsHomeWidget({super.key, this.onOpenWeatherStation});

  @override
  State<FarmAlertsHomeWidget> createState() => _FarmAlertsHomeWidgetState();
}

class _FarmAlertsHomeWidgetState extends State<FarmAlertsHomeWidget> {
  static const _accentGreen = Color(0xFF2A6B2A);
  static const _green = Color(0xFF1B5E20);
  static const _amber = Color(0xFFE65100);
  static const _red = Color(0xFFB71C1C);

  bool _loading = true;
  String _county = '';
  bool _provisioned = false;
  WeatherDayPlan? _plan;
  List<AgronomicAdvisory> _verified = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final location = await FarmLocationService.getLocation();
      // Same station the Weather Station screen opens on (its first), so the
      // reading and station-scoped advice match what the farmer sees there.
      String? stationId;
      try {
        final stations = await NuaSenseService.getStations();
        if (stations.isNotEmpty) stationId = stations.first.id;
      } catch (_) {}
      final reading = await NuaSenseService.getLatestReading(
        stationId: stationId,
      );
      final provisioned = reading.isProvisioned;

      final plan = provisioned && reading.hasData
          ? buildKmDayPlan(reading)
          : null;
      final verified = await _loadVerified(reading, stationId);

      if (!mounted) return;
      setState(() {
        _county = location.county;
        _provisioned = provisioned;
        _plan = plan;
        _verified = verified;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  /// Published advice for the farmer's crops and the station's conditions
  /// right now (only "Any conditions" advice without a station). Fails soft:
  /// the rest of the card still shows.
  Future<List<AgronomicAdvisory>> _loadVerified(
    NuaSenseReading reading,
    String? stationId,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const [];
    try {
      List<String>? crops;
      try {
        crops = await AgronomicAdvisoryService.farmerCrops(
          uid,
          plotId: await FarmLocationService.getSelectedPlotId(),
        );
      } catch (_) {
        crops = null; // unknown → 'All crops' advice only
      }
      return await AgronomicAdvisoryService.publishedFor(
        conditions: reading.isProvisioned
            ? activeConditionKeys(reading)
            : {'general'},
        farmerCrops: crops,
        gatewayId: reading.isProvisioned ? stationId : null,
      );
    } catch (e) {
      debugPrint('[FarmAlertsHomeWidget] verified advice failed: $e');
      return const [];
    }
  }

  void _openWeatherStation() {
    if (widget.onOpenWeatherStation != null) {
      widget.onOpenWeatherStation!();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WeatherStationScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8F6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF2A6B2A),
                ),
              ),
              SizedBox(width: 8),
              Text(
                'Loading farm advice…',
                style: TextStyle(fontSize: 12, color: Colors.black45),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 12,
                color: Colors.black38,
              ),
              const SizedBox(width: 4),
              Text(
                _county.isEmpty ? 'Your farm' : 'Farm: $_county',
                style: const TextStyle(fontSize: 11, color: Colors.black45),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _load,
                child: const Row(
                  children: [
                    Icon(Icons.refresh, size: 11, color: Colors.black38),
                    SizedBox(width: 2),
                    Text(
                      'Refresh',
                      style: TextStyle(fontSize: 11, color: Colors.black38),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_error != null) _errorCard(),
        if (_error == null && !_provisioned) _noStationCard(),
        if (_error == null && _provisioned && _plan != null) ...[
          _planCard(_plan!),
          if (_plan!.doToday.isNotEmpty || _plan!.avoidToday.isNotEmpty)
            _doAvoidCard(_plan!),
        ],
        if (_error == null)
          for (final a in _verified.take(2)) _verifiedCard(a),
        if (_error == null && _verified.length > 2)
          _moreVerifiedLink(_verified.length - 2),
        if (_error == null && _provisioned && _verified.isEmpty)
          _noVerifiedHint(),
      ],
    );
  }

  Widget _errorCard() {
    return _baseCard(
      bg: const Color(0xFFFFEBEE),
      border: _red.withValues(alpha: 0.3),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: _red, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Could not load advice. Pull to refresh or open Weather Station.',
              style: TextStyle(
                fontSize: 12.5,
                color: _red.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _noStationCard() {
    return InkWell(
      onTap: _openWeatherStation,
      borderRadius: BorderRadius.circular(12),
      child: _baseCard(
        bg: const Color(0xFFF7F8F6),
        border: Colors.grey.shade300,
        child: const Row(
          children: [
            Icon(Icons.sensors_off_rounded, color: Colors.black45, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'No weather station data yet. Open Weather Station when a station is assigned.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.black54,
                  height: 1.35,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.black26, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _planCard(WeatherDayPlan plan) {
    final Color bg;
    final Color border;
    final Color iconColor;
    final IconData icon;
    switch (plan.mood) {
      case DayMood.good:
        bg = const Color(0xFFEDF7ED);
        border = _green.withValues(alpha: 0.35);
        iconColor = _accentGreen;
        icon = Icons.check_circle_outline_rounded;
        break;
      case DayMood.caution:
        bg = const Color(0xFFFFF8E1);
        border = _amber.withValues(alpha: 0.35);
        iconColor = _amber;
        icon = Icons.warning_amber_rounded;
        break;
      case DayMood.hold:
        bg = const Color(0xFFFFEBEE);
        border = _red.withValues(alpha: 0.3);
        iconColor = _red;
        icon = Icons.pause_circle_outline_rounded;
        break;
    }

    return InkWell(
      onTap: _openWeatherStation,
      borderRadius: BorderRadius.circular(12),
      child: _baseCard(
        bg: bg,
        border: border,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "TODAY'S ADVICE",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    plan.mainAdvice,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Open Weather Station for AI & full plan',
                    style: TextStyle(fontSize: 11, color: iconColor),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: iconColor.withValues(alpha: 0.5),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _doAvoidCard(WeatherDayPlan plan) {
    return _baseCard(
      bg: Colors.white,
      border: Colors.grey.shade200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (plan.doToday.isNotEmpty) ...[
            const Text(
              'DO TODAY',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _accentGreen,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            ...plan.doToday
                .take(3)
                .map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '• ',
                          style: TextStyle(color: _accentGreen, fontSize: 12),
                        ),
                        Expanded(
                          child: Text(
                            t,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Colors.black87,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
          if (plan.avoidToday.isNotEmpty) ...[
            if (plan.doToday.isNotEmpty) const SizedBox(height: 8),
            const Text(
              'AVOID',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _red,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            ...plan.avoidToday
                .take(3)
                .map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '• ',
                          style: TextStyle(color: _red, fontSize: 12),
                        ),
                        Expanded(
                          child: Text(
                            t,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Colors.black87,
                              height: 1.3,
                            ),
                          ),
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

  /// Verified advice, tappable → the Weather Station (full advice + AI).
  Widget _verifiedCard(AgronomicAdvisory a) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: GestureDetector(
      onTap: _openWeatherStation,
      child: VerifiedAdvisoryCard.fromAdvisory(a),
    ),
  );

  Widget _moreVerifiedLink(int more) => Align(
    alignment: Alignment.centerRight,
    child: TextButton.icon(
      onPressed: _openWeatherStation,
      icon: const Icon(Icons.verified_rounded, size: 16),
      label: Text('$more more verified advice on Weather Station'),
      style: TextButton.styleFrom(
        foregroundColor: AdvisoryColors.verified,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    ),
  );

  Widget _noVerifiedHint() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 2),
      child: Text(
        "No verified advice for your crops and today's weather yet. "
        'AI advice is on Weather Station.',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          color: Colors.grey.shade700,
          height: 1.3,
        ),
      ),
    );
  }

  Widget _baseCard({
    required Color bg,
    required Color border,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: child,
      ),
    );
  }
}
