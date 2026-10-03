// lib/screens/Field Data Input/weather_station_screen.dart
//
// The farm's weather station — its data only:
//   status → conditions (always open, with every sensor value) → last 24 h.
// Advice built on these readings (today's plan, farm alerts, verified and AI
// advice) lives on Home and in Notifications (lib/widgets/farm_advice_panel.dart);
// the area forecast is on the Weather forecast screen. A link card points
// there. Field Agronomists also get an entry into their panel from here.
//
// [embedded]: shown as a tab of the Field Data Input hub — no app bar; the
// station / plot switchers and refresh sit in a slim toolbar instead.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kilimomkononi/services/nuasense_service.dart';
import 'package:kilimomkononi/services/farm_location_service.dart';
import 'package:kilimomkononi/services/weather_day_plan.dart';
import 'package:kilimomkononi/enterprise/features/weather/admin_advisory_preview.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_widgets.dart';
import 'package:kilimomkononi/enterprise/features/weather/agronomic_advisory_service.dart';
import 'package:kilimomkononi/enterprise/features/weather/field_agronomist_panel_screen.dart';
import 'package:kilimomkononi/settings/notifications_screen.dart';
import 'package:kilimomkononi/widgets/google_weather_widgets.dart';
import 'package:kilimomkononi/utils/friendly_error.dart';

class _C {
  static const darkGreen = Color.fromARGB(255, 3, 39, 4);
  static const midGreen = Color(0xFF2A6B2A);
  static const lightGreen = Color(0xFFE8F5E9);
  static const skyBlue = Color(0xFF1565C0);
  static const amber = Color(0xFFE65100);
  static const lightAmber = Color(0xFFFFF8E1);
  static const red = Color(0xFFB71C1C);
  static const pageBg = Color(0xFFF4F6F3);
  static const border = Color(0xFFE0E4DF);
}

/// Default weight for this screen's text (medium, not regular).
const _kBodyWeight = TextStyle(fontWeight: FontWeight.w500);

// ── Outdoor condition chip styling ───────────────────────────────────────────

class _LabelStyle {
  final Color color;
  final IconData icon;
  const _LabelStyle(this.color, this.icon);
}

_LabelStyle _styleForLabel(String label) {
  final warn =
      label.contains('Hot') ||
      label.contains('Windy') ||
      label.contains('very humid') ||
      label.contains('Raining now');
  final caution =
      label.contains('Cool') ||
      label.contains('Breezy') ||
      label.contains('Recent rain') ||
      label.contains('wet');
  final color = warn
      ? _C.red
      : caution
      ? _C.amber
      : _C.midGreen;

  final IconData icon;
  if (label.contains('Temp') ||
      label.contains('Hot') ||
      label.contains('Cool')) {
    icon = Icons.thermostat_rounded;
  } else if (label.contains('Air')) {
    icon = Icons.water_drop_outlined;
  } else if (label.contains('ind') || label.contains('Breezy')) {
    icon = Icons.air_rounded;
  } else if (label.contains('ain')) {
    icon = Icons.grain_rounded;
  } else {
    icon = Icons.eco_outlined;
  }
  return _LabelStyle(color, icon);
}

// ── Screen ───────────────────────────────────────────────────────────────────

class WeatherStationScreen extends StatefulWidget {
  /// Opens on this station (e.g. from a push about it) instead of the
  /// farmer's first one. Ignored if it isn't one of their stations.
  final String? initialStationId;

  /// Inside the Field Data Input hub (no app bar of its own).
  final bool embedded;

  const WeatherStationScreen({
    super.key,
    this.initialStationId,
    this.embedded = false,
  });

  @override
  State<WeatherStationScreen> createState() => _WeatherStationScreenState();
}

class _WeatherStationScreenState extends State<WeatherStationScreen> {
  bool _loading = true;
  String? _error;
  NuaSenseReading? _reading;
  List<NuaSenseHourPoint> _history = [];
  String _county = '';
  String _userId = '';
  List<PlotSummary> _plots = [];
  String? _selectedPlotId;
  bool _isPlotGps = false;
  List<NuaStation> _stations = [];
  String? _selectedStationId;

  // Crops (for the conditions summary and the admin preview).
  List<String> _farmerCrops = [];
  AdvisoryAccess _advisoryAccess = AdvisoryAccess.none;
  bool get _isFieldAgronomist => _advisoryAccess != AdvisoryAccess.none;
  bool get _adminTestMode => _advisoryAccess == AdvisoryAccess.adminTest;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _init();
    _loadPlots();
    _checkRole();
  }

  /// Stations first, so the reading and the station-scoped advice both use
  /// the same explicit station (the server's default and the list order can
  /// differ for farmers with several stations).
  Future<void> _init() async {
    await _loadStations();
    await _load();
  }

  Future<void> _checkRole() async {
    final access = await AgronomicAdvisoryService.access();
    if (!mounted || access == AdvisoryAccess.none) return;
    setState(() => _advisoryAccess = access);
    // Admins also see their TEST advisories in the farmer view.
    if (access == AdvisoryAccess.adminTest) _loadFarmerCrops();
  }

  /// The farmer's crops for the selected plot, from their field records
  /// (fielddata.crops[].type). Falls back to all their recorded crops.
  /// On failure the last known crops are kept; if none were ever loaded,
  Future<void> _loadFarmerCrops() async {
    if (_userId.isEmpty) return;
    try {
      final crops = await AgronomicAdvisoryService.farmerCrops(
        _userId,
        plotId: _selectedPlotId,
      );
      if (!mounted) return;
      setState(() {
        _farmerCrops = crops;
      });
    } catch (e) {
      debugPrint('[WeatherStationScreen] loading crops failed: $e');
    }
  }

  /// Station the reading came from. [_loadStations] makes the pick explicit
  /// before the first reading, so this is only null when the station list
  /// couldn't load (the server's default is used; only all-station advice
  /// applies then).
  String? get _effectiveStationId => _selectedStationId;

  Future<void> _openAgronomistPanel() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FieldAgronomistPanelScreen(
          initialStationId: _effectiveStationId,
          testMode: _adminTestMode,
        ),
      ),
    );
  }

  Future<void> _loadStations() async {
    try {
      final stations = await NuaSenseService.getStations();
      if (!mounted) return;
      setState(() {
        _stations = stations;
        final wanted = widget.initialStationId;
        if (_selectedStationId == null && stations.isNotEmpty) {
          _selectedStationId = stations.any((s) => s.id == wanted)
              ? wanted
              : stations.first.id;
        }
      });
    } catch (e) {
      debugPrint('[WeatherStationScreen] loading stations failed: $e');
    }
  }

  String get _stationLabel {
    final id = _selectedStationId;
    if (id == null) return 'Your station';
    for (final s in _stations) {
      if (s.id == id) return s.name.isNotEmpty ? s.name : id;
    }
    return id;
  }

  Future<void> _switchStation(String? stationId) async {
    setState(() {
      _selectedStationId = stationId;
      _loading = true;
    });
    await _load();
  }

  Future<void> _loadPlots() async {
    if (_userId.isEmpty) return;
    try {
      final plots = await FarmLocationService.loadPlots(_userId);
      final selectedId = await FarmLocationService.getSelectedPlotId();
      if (!mounted) return;
      setState(() {
        _plots = plots;
        _selectedPlotId =
            selectedId ?? (plots.isNotEmpty ? plots.first.id : null);
      });
    } catch (_) {}
  }

  Future<void> _switchPlot(String plotId) async {
    setState(() {
      _selectedPlotId = plotId;
      _loading = true;
    });
    await FarmLocationService.selectPlot(plotId);
    await _load(); // reloads crops + verified advice for the new plot
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final loc = await FarmLocationService.getLocation();
      final reading = await NuaSenseService.getLatestReading(
        stationId: _selectedStationId,
      );
      final history = await NuaSenseService.get24hHistory(
        stationId: _selectedStationId,
      );
      if (!mounted) return;
      setState(() {
        _county = loc.county;
        _isPlotGps = loc.isPlotGps;
        _reading = reading;
        _history = history;
        _loading = false;
      });
      debugPrint('Using station: $_selectedStationId');
      _loadFarmerCrops(); // crop-aware condition labels
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    NuaSenseService.clearCache(stationId: _selectedStationId);
    await _load();
  }

  List<String> get _cropNames => _farmerCrops;

  List<Widget> get _actions => [
    if (_isFieldAgronomist)
      IconButton(
        icon: const Icon(Icons.fact_check_rounded),
        tooltip: 'Field Agronomist panel',
        onPressed: _openAgronomistPanel,
      ),
    if (_stations.length > 1)
      Padding(
        padding: const EdgeInsets.only(right: 4),
        child: _StationSwitcherButton(
          stations: _stations,
          selectedStationId: _selectedStationId,
          onSelect: _switchStation,
        ),
      ),
    if (_plots.length > 1)
      Padding(
        padding: const EdgeInsets.only(right: 4),
        child: _PlotSwitcherButton(
          plots: _plots,
          selectedPlotId: _selectedPlotId,
          onSelect: _switchPlot,
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
  ];

  /// Embedded in the hub: station name + the app-bar actions in one row.
  Widget _embeddedToolbar() => Material(
    color: _C.darkGreen,
    child: IconTheme(
      data: const IconThemeData(color: Colors.white),
      child: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Row(
          children: [
            const Icon(Icons.sensors_rounded, size: 16, color: Colors.white70),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _stationLabel,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ..._actions,
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final plan = _reading != null && _reading!.isProvisioned
        ? buildKmDayPlan(_reading!, cropNames: _cropNames)
        : null;

    final body = _loading
        ? _buildLoading()
        : _error != null
        ? _buildError()
        : (_reading != null && !_reading!.isProvisioned)
        ? (_adminTestMode
              ? _buildNotProvisionedWithPreview()
              : _buildNotProvisioned())
        : RefreshIndicator(
            color: _C.midGreen,
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_isFieldAgronomist) _buildAgronomistEntry(),
                _noGpsBanner(),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: WeatherSourceBadge(WeatherSource.station),
                ),
                const SizedBox(height: 8),
                _buildStatusBar(),
                const SizedBox(height: 14),
                if (_reading!.hasData)
                  _buildConditionsSummary(plan!)
                else
                  _buildOfflineCard(),
                const SizedBox(height: 14),
                _buildAdviceLink(),
                if (_adminTestMode) ...[
                  const SizedBox(height: 16),
                  _buildAdminPreview(),
                ],
                const SizedBox(height: 20),
                _sectionLabel('Last 24 hours'),
                _buildHistoryStrip(),
                const SizedBox(height: 24),
              ],
            ),
          );

    // Heavier body text for readability outdoors / on low-end screens; text
    // that sets its own weight keeps it.
    return DefaultTextStyle.merge(
      style: _kBodyWeight,
      child: widget.embedded
          ? ColoredBox(
              color: _C.pageBg,
              child: Column(
                children: [
                  _embeddedToolbar(),
                  Expanded(child: body),
                ],
              ),
            )
          : Scaffold(
              backgroundColor: _C.pageBg,
              appBar: AppBar(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Weather Station',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _stationLabel,
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
                backgroundColor: _C.darkGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                actions: _actions,
              ),
              body: body,
            ),
    );
  }

  /// Advice built on these readings lives in Notifications (and Home).
  Widget _buildAdviceLink() => Material(
    color: AdvisoryColors.verifiedBg,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const NotificationsScreen(initialTab: NotificationsTab.advice),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdvisoryColors.verifiedBorder),
        ),
        child: const Row(
          children: [
            Icon(Icons.tips_and_updates_rounded, color: AdvisoryColors.verified),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Advice for these conditions',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AdvisoryColors.verified,
                    ),
                  ),
                  Text(
                    'Farm alerts, verified and AI advice — with soil, pest and '
                    'disease checks you can log',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AdvisoryColors.verified),
          ],
        ),
      ),
    ),
  );

  Widget _buildLoading() => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(color: _C.midGreen),
        SizedBox(height: 16),
        Text(
          'Loading weather station data…',
          style: TextStyle(color: Colors.black54, fontSize: 13),
        ),
      ],
    ),
  );

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Could not reach weather station',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.midGreen,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    ),
  );

  // ── Admin test-mode preview ─────────────────────────────────────────────

  Widget _buildAdminPreview() => AdminAdvisoryPreview(
    reading: _reading,
    farmerCrops: _farmerCrops,
    onOpenPanel: _openAgronomistPanel,
  );

  /// Admins usually have no station of their own — still show the preview.
  Widget _buildNotProvisionedWithPreview() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _buildAgronomistEntry(),
      _buildNotProvisioned(),
      const SizedBox(height: 8),
      _buildAdminPreview(),
    ],
  );

  Widget _buildNotProvisioned() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sensors_off_rounded, size: 48, color: _C.midGreen),
          const SizedBox(height: 16),
          const Text(
            'No weather station installed yet',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF032704),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Once a NuaSense weather station is installed on your farm, '
            'live conditions and advice will appear here automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.black54,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Check again'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _C.midGreen,
              side: const BorderSide(color: _C.midGreen),
            ),
          ),
        ],
      ),
    ),
  );

  /// Shown instead of the day plan when the station sent nothing in the
  /// last 2 hours: its values are placeholders, not real weather.
  Widget _buildOfflineCard() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _C.lightAmber,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _C.amber.withValues(alpha: 0.3)),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.sensors_off_rounded, color: _C.amber),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Your weather station has not sent any readings in the last '
            '2 hours, so there are no live conditions to show. Check that '
            'the station has power and signal, then pull down to refresh.',
            style: TextStyle(fontSize: 12.5, height: 1.4),
          ),
        ),
      ],
    ),
  );

  Widget _buildStatusBar() {
    final r = _reading!;
    final timeAgo = _timeAgo(r.timestamp);
    final stale = r.isStale || !r.hasData;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: stale ? _C.lightAmber : _C.lightGreen,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: stale
              ? _C.amber.withValues(alpha: 0.3)
              : _C.midGreen.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            stale ? Icons.access_time_rounded : Icons.sensors_rounded,
            size: 14,
            color: stale ? _C.amber : _C.midGreen,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              !r.hasData
                  ? 'No readings in the last 2 hours · station may be offline'
                  : stale
                  ? 'Cached data · Last updated $timeAgo'
                  : 'Live · Updated $timeAgo',
              style: TextStyle(
                fontSize: 12,
                color: stale ? _C.amber : _C.midGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Icon(
            Icons.location_on_outlined,
            size: 12,
            color: Colors.black54,
          ),
          const SizedBox(width: 3),
          Text(
            _county,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  /// Always open: the condition chips and every sensor value.
  Widget _buildConditionsSummary(WeatherDayPlan plan) {
    final r = _reading!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Conditions',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: plan.conditionLabels.map((label) {
              final s = _styleForLabel(label);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: s.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: s.color.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(s.icon, size: 12, color: s.color),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: s.color,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const Divider(height: 22, color: _C.border),
          const Text(
            'SENSOR DETAILS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.black54,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          _sensorRow('Air temperature', '${r.airTemp.toStringAsFixed(1)}°C'),
          _sensorRow('Humidity', '${r.humidity.toStringAsFixed(0)}%'),
          _sensorRow('Wind', '${r.windSpeed.toStringAsFixed(1)} m/s'),
          _sensorRow('Rainfall', '${r.rainfall.toStringAsFixed(1)} mm'),
          _sensorRow('VPD', '${r.vpd.toStringAsFixed(2)} kPa'),
          _sensorRow('Leaves', r.leafIsWet ? 'Wet' : 'Dry'),
        ],
      ),
    );
  }

  Widget _sensorRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgronomistEntry() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: AdvisoryColors.verifiedBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _openAgronomistPanel,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AdvisoryColors.verifiedBorder),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.fact_check_rounded,
                color: AdvisoryColors.verified,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _adminTestMode
                          ? 'Field Agronomist panel · admin test mode'
                          : 'Field Agronomist panel',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AdvisoryColors.verified,
                      ),
                    ),
                    const Text(
                      'Draft, verify and publish advice for these conditions',
                      style: TextStyle(fontSize: 11.5, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AdvisoryColors.verified,
              ),
            ],
          ),
        ),
      ),
    ),
  );

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
        child: const Text(
          'No history data available',
          style: TextStyle(color: Colors.black54, fontSize: 12),
        ),
      );
    }

    final pts = _history.length > 24
        ? _history.sublist(_history.length - 24)
        : _history;
    final maxTemp = pts.map((p) => p.airTemp).reduce((a, b) => a > b ? a : b);
    final minTemp = pts.map((p) => p.airTemp).reduce((a, b) => a < b ? a : b);
    final range = (maxTemp - minTemp).clamp(1.0, double.infinity);

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
          Row(
            children: [
              const Icon(
                Icons.thermostat_rounded,
                size: 12,
                color: _C.midGreen,
              ),
              const SizedBox(width: 4),
              Text(
                'Temperature  ${minTemp.toStringAsFixed(1)}°–${maxTemp.toStringAsFixed(1)}°C',
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
              const Spacer(),
              const Icon(
                Icons.water_drop_outlined,
                size: 12,
                color: _C.skyBlue,
              ),
              const SizedBox(width: 3),
              const Text(
                'Humidity',
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 60,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: pts.map((p) {
                final heightFrac = ((p.airTemp - minTemp) / range).clamp(
                  0.1,
                  1.0,
                );
                final isWet = p.lwdHour == 1;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isWet)
                          const Icon(
                            Icons.water_drop_rounded,
                            size: 6,
                            color: _C.skyBlue,
                          ),
                        Expanded(
                          flex: (heightFrac * 10).round(),
                          child: Container(
                            decoration: BoxDecoration(
                              color: p.airTemp > 35
                                  ? _C.red.withValues(alpha: 0.7)
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
          Row(
            children: [
              Text(
                _hourLabel(pts.first.time),
                style: const TextStyle(fontSize: 9, color: Colors.black54),
              ),
              const Spacer(),
              Text(
                _hourLabel(pts[pts.length ~/ 4].time),
                style: const TextStyle(fontSize: 9, color: Colors.black54),
              ),
              const Spacer(),
              Text(
                _hourLabel(pts[pts.length ~/ 2].time),
                style: const TextStyle(fontSize: 9, color: Colors.black54),
              ),
              const Spacer(),
              Text(
                _hourLabel(pts[pts.length * 3 ~/ 4].time),
                style: const TextStyle(fontSize: 9, color: Colors.black54),
              ),
              const Spacer(),
              const Text(
                'Now',
                style: TextStyle(fontSize: 9, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAbout() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        builder: (_, ctrl) => DefaultTextStyle.merge(
          style: _kBodyWeight,
          child: SingleChildScrollView(
            controller: ctrl,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'About Weather Station Data',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _aboutRow(
                  Icons.checklist_rounded,
                  "Today's plan",
                  'Computed on this device from live readings — leads with what to do, not raw numbers.',
                ),
                _aboutRow(
                  Icons.sensors_rounded,
                  'Data source',
                  'NuaSense Partner API — physical weather station.',
                ),
                _aboutRow(
                  Icons.verified_rounded,
                  'Verified advice',
                  'Written or checked by a Field Agronomist for your crop and today\'s weather.',
                ),
                _aboutRow(
                  Icons.auto_awesome_rounded,
                  'AI Farm Advisor',
                  'Generated automatically from live station data — not reviewed by a person.',
                ),
                _aboutRow(
                  Icons.water_drop_outlined,
                  'Leaf wetness',
                  'Wet hours from humidity, dew-point, or rainfall — drives fungal risk advice.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _aboutRow(IconData icon, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _C.midGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: _C.midGreen,
        letterSpacing: 0.8,
      ),
    ),
  );

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  String _hourLabel(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:00';

  Widget _noGpsBanner() {
    if (_isPlotGps || _plots.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFE65100).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.add_location_alt_outlined,
            size: 17,
            color: Color(0xFFE65100),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Using $_county county — add a GPS pin to your plot '
              'in Field Data → Plot Setup to match this station to your exact farm.',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFE65100),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StationSwitcherButton extends StatelessWidget {
  final List<NuaStation> stations;
  final String? selectedStationId;
  final void Function(String? stationId) onSelect;

  const _StationSwitcherButton({
    required this.stations,
    required this.selectedStationId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final current =
        stations.where((s) => s.id == selectedStationId).firstOrNull ??
        stations.firstOrNull;
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sensors_rounded,
              size: 14,
              color: current?.online == true ? Colors.white : Colors.white54,
            ),
            const SizedBox(width: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 90),
              child: Text(
                current?.name ?? 'Station',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.expand_more, size: 14, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => Material(
        color: Colors.white,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 4),
                child: Text(
                  'Switch weather station',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF032704),
                  ),
                ),
              ),
              const Divider(height: 1),
              ...stations.map((s) {
                final isSelected =
                    s.id == selectedStationId ||
                    (selectedStationId == null && s == stations.first);
                return ListTile(
                  leading: Icon(
                    Icons.sensors_rounded,
                    color: s.online
                        ? (isSelected
                              ? const Color(0xFF2A6B2A)
                              : Colors.black54)
                        : Colors.grey,
                  ),
                  title: Text(
                    s.name,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(s.online ? 'Online' : 'Offline'),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Color(0xFF2A6B2A))
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
      ),
    );
  }
}

class _PlotSwitcherButton extends StatelessWidget {
  final List<PlotSummary> plots;
  final String? selectedPlotId;
  final void Function(String plotId) onSelect;

  const _PlotSwitcherButton({
    required this.plots,
    required this.selectedPlotId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final current =
        plots.where((p) => p.id == selectedPlotId).firstOrNull ??
        plots.firstOrNull;
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              current?.hasGps == true
                  ? Icons.location_on_rounded
                  : Icons.location_searching_rounded,
              size: 14,
              color: Colors.white,
            ),
            const SizedBox(width: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 100),
              child: Text(
                current?.name ?? 'Select farm',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.expand_more, size: 14, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => Material(
        color: Colors.white,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 4),
                child: Text(
                  'Switch farm',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF032704),
                  ),
                ),
              ),
              const Divider(height: 1),
              ...plots.map((p) {
                final isSelected = p.id == selectedPlotId;
                return ListTile(
                  leading: Icon(
                    p.hasGps
                        ? Icons.location_on_rounded
                        : Icons.location_searching_rounded,
                    color: isSelected ? const Color(0xFF2A6B2A) : Colors.grey,
                  ),
                  title: Text(
                    p.name,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    p.hasGps
                        ? p.locationLabel
                        : '${p.county} (county estimate)',
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Color(0xFF2A6B2A))
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
      ),
    );
  }
}
