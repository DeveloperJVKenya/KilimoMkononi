// lib/screens/weather_screen.dart
//
// Weather (farmer mode): Google Weather forecast — current conditions, next
// 24 hours and 7 days — for
//   • Weather station — the position of the account's connected station
//                       (the farm in view's station; pick another if the
//                       account has several). The default when there is one,
//                       with a live "Google vs. station" panel → the full
//                       comparison and its Excel / CSV downloads.
//   • My location     — the device's GPS (browser location on web),
//   • a place the farmer types (e.g. "Nakuru") — how to see any other area,
//                       including the account's registered county.
//
// The station's own measurements are shown alongside, clearly labelled as a
// separate source. Advice and alerts come from the station, never from this
// forecast.

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:kilimomkononi/services/device_location_service.dart';
import 'package:kilimomkononi/screens/Field%20Data%20Input/weather_station_screen.dart';
import 'package:kilimomkononi/services/farm_location_service.dart';
import 'package:kilimomkononi/screens/weather_comparison_screen.dart';
import 'package:kilimomkononi/services/google_weather_service.dart';
import 'package:kilimomkononi/services/nuasense_service.dart';
import 'package:kilimomkononi/services/weather_comparison.dart';
import 'package:kilimomkononi/widgets/google_weather_widgets.dart';

enum _Where { station, device, search }

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  WeatherScreenState createState() => WeatherScreenState();
}

class WeatherScreenState extends State<WeatherScreen> {
  static const _green = Color(0xFF032704);

  final _searchCtrl = TextEditingController();
  _Where _where = _Where.station;
  bool _loading = false;
  String? _error;
  String? _notice; // e.g. "Location is off — showing your farm"
  // What the spinner says ("Finding your location…", "Loading weather…").
  String _stage = 'Loading weather…';
  // Showing a saved device position while a fresh fix is found.
  bool _updatingLocation = false;
  String _place = '';
  GoogleWeather? _weather;
  // Bumped per request so a slow older answer can't replace a newer one.
  int _request = 0;

  NuaSenseReading? _station;
  bool _stationLoading = true;

  /// The account's connected stations, and the one shown.
  List<NuaStation> _stations = [];
  String? _stationId;

  NuaStation? get _selectedStation =>
      _stations.where((s) => s.id == _stationId).firstOrNull ?? _stations.firstOrNull;

  @override
  void initState() {
    super.initState();
    _start(_Where.station); // spinner while we find out if there's a station
    _init();
  }

  /// Opens on the station's location when the account has a station (the
  /// one for the farm in view), else on the device's location.
  Future<void> _init() async {
    try {
      final stations = await NuaSenseService.getStations();
      final id = await NuaSenseService.stationIdForPlot(await FarmLocationService.getSelectedPlotId());
      if (!mounted) return;
      setState(() {
        _stations = stations;
        _stationId = id ?? stations.firstOrNull?.id;
      });
    } catch (_) {}
    if (!mounted) return;
    if (_stations.isNotEmpty) {
      await _useStation();
    } else {
      setState(() => _stationLoading = false);
      await _useDeviceLocation();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Sources ────────────────────────────────────────────────────────────────

  /// "My location": shows the forecast for the last saved device position
  /// straight away (if there is one), while a fresh low-accuracy fix is
  /// found in the background (DeviceLocationService, capped at 10 s). The
  /// forecast reloads only if the device has moved more than ~1.5 km.
  Future<void> _useDeviceLocation() async {
    final req = _start(_Where.device);
    final sw = Stopwatch()..start();
    final saved = await DeviceLocationService.lastSaved();
    final showSaved = saved != null && saved.age < const Duration(hours: 12);

    if (showSaved) {
      setState(() {
        _stage = 'Loading weather…';
        _updatingLocation = true;
      });
      unawaited(_loadForFix(req, saved, sw, fromSaved: true));
    } else {
      setState(() => _stage = 'Finding your location…');
    }

    try {
      final fix = await DeviceLocationService.current();
      if (req != _request || !mounted) return;
      final moved = !showSaved || fix.distanceTo(saved) > 1500;
      if (moved) {
        setState(() => _stage = 'Loading weather…');
        await _loadForFix(req, fix, sw, fromSaved: false);
      } else {
        // Same area — keep what's shown, remember the fresh fix.
        await DeviceLocationService.save(fix.withLabel(saved.label));
        debugPrint('[Weather] fresh fix within 1.5 km of saved one — no reload (${sw.elapsedMilliseconds} ms)');
      }
      if (mounted && req == _request) setState(() => _updatingLocation = false);
    } on LocationUnavailable catch (e) {
      if (req != _request || !mounted) return;
      if (showSaved) {
        setState(() {
          _updatingLocation = false;
          _notice = '${e.message}. Showing your last known location '
              '(${relativeTimeShort(saved.at)}).';
        });
      } else if (_stations.isNotEmpty) {
        _notice = '${e.message} — showing your weather station\'s area instead.';
        await _useStation(keepNotice: true);
      } else {
        setState(() {
          _loading = false;
          _error = '${e.message}. Search a town or place above to see its forecast.';
        });
      }
    }
  }

  /// Weather + place name for a device fix.
  Future<void> _loadForFix(int req, DeviceFix fix, Stopwatch sw, {required bool fromSaved}) async {
    try {
      final results = await Future.wait([
        GoogleWeatherService.forLocation(fix.latitude, fix.longitude),
        fix.label != null
            ? Future<String?>.value(fix.label)
            : GoogleWeatherService.placeName(fix.latitude, fix.longitude),
      ]);
      final label = (results[1] as String?) ?? 'Your location';
      debugPrint('[Weather] ${fromSaved ? 'saved' : 'fresh'} location weather ready in ${sw.elapsedMilliseconds} ms');
      if (!fromSaved) await DeviceLocationService.save(fix.withLabel(label));
      _finish(req, results[0] as GoogleWeather, label);
    } catch (e) {
      // A saved-position failure is replaced by the fresh fix; only report
      // errors for the fresh one.
      if (!fromSaved) _fail(req, e);
    }
  }

  /// "Weather station": Google's forecast at the connected station's own
  /// position, next to that station's readings.
  Future<void> _useStation({String? stationId, bool keepNotice = false}) async {
    final notice = keepNotice ? _notice : null;
    if (stationId != null) _stationId = stationId;
    final req = _start(_Where.station);
    _notice = notice;
    final st = _selectedStation;
    if (st == null) {
      _fail(req, StateError('No weather station is connected to your account.'));
      return;
    }
    unawaited(_loadStation(st.id));
    if (st.lat == null || st.lon == null) {
      if (!mounted || req != _request) return;
      setState(() {
        _loading = false;
        _weather = null;
        _error = '${st.name} doesn\'t report its position, so Google\'s forecast for it '
            'can\'t be shown. Use "My location" or search the area\'s name.';
      });
      return;
    }
    try {
      final w = await GoogleWeatherService.forLocation(st.lat!, st.lon!);
      _finish(req, w, '${st.name} (station area)');
    } catch (e) {
      _fail(req, e);
    }
  }

  void _pickStation() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text('Show the forecast for…', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ),
        for (final s in _stations)
          ListTile(
            leading: Icon(Icons.sensors_rounded, color: s.online ? const Color(0xFF2E7D32) : Colors.grey),
            title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(s.online ? 'Online' : 'Offline'),
            trailing: s.id == _stationId ? const Icon(Icons.check_circle, color: Color(0xFF2E7D32)) : null,
            onTap: () {
              Navigator.pop(ctx);
              _useStation(stationId: s.id);
            },
          ),
        const SizedBox(height: 8),
      ]),
    ),
  );

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Type a town or place, e.g. Nakuru')));
      return;
    }
    FocusScope.of(context).unfocus();
    final req = _start(_Where.search);
    try {
      final place = await GoogleWeatherService.search(q);
      if (req != _request) return;
      if (place == null) {
        setState(() {
          _loading = false;
          _error = 'Couldn\'t find "$q". Try a nearby town or county name.';
        });
        return;
      }
      final w = await GoogleWeatherService.forLocation(place.lat, place.lon);
      _finish(req, w, place.label);
    } catch (e) {
      _fail(req, e);
    }
  }

  int _start(_Where where) {
    setState(() {
      _where = where;
      _loading = true;
      _error = null;
      _notice = null;
      _stage = 'Loading weather…';
      _updatingLocation = false;
    });
    return ++_request;
  }

  void _finish(int req, GoogleWeather w, String place) {
    if (!mounted || req != _request) return;
    setState(() {
      _weather = w;
      _place = place;
      _loading = false;
    });
  }

  void _fail(int req, Object e) {
    if (!mounted || req != _request) return;
    setState(() {
      _loading = false;
      _error = GoogleWeatherService.friendlyError(e);
    });
  }

  Future<void> _refresh() => switch (_where) {
        _Where.station => _useStation(),
        _Where.device => _useDeviceLocation(),
        _Where.search => _search(),
      };

  /// Readings of the station shown (the same one as the forecast area).
  Future<void> _loadStation(String stationId) async {
    setState(() => _stationLoading = true);
    try {
      final r = await NuaSenseService.getLatestReading(stationId: stationId);
      if (mounted && stationId == _stationId) setState(() => _station = r);
    } catch (_) {
      // No station / offline — the pairing card explains.
    } finally {
      if (mounted) setState(() => _stationLoading = false);
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F4),
      appBar: AppBar(
        title: const Text('Weather', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _green,
        foregroundColor: Colors.white,
        actions: [
          if (_station?.isProvisioned ?? false)
            IconButton(
              icon: const Icon(Icons.compare_arrows_rounded),
              tooltip: 'Compare Google with your weather station',
              onPressed: _openComparison,
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _searchBar(),
            const SizedBox(height: 10),
            _sourceChips(),
            const SizedBox(height: 12),
            if (_notice != null) _banner(Icons.info_outline_rounded, _notice!),
            if (_updatingLocation && _weather != null)
              _banner(Icons.my_location_rounded, 'Updating your location…'),
            if (_loading && _weather == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const CircularProgressIndicator(color: _green),
                    const SizedBox(height: 14),
                    Text(_stage, style: const TextStyle(color: Colors.black54)),
                  ]),
                ),
              )
            else if (_error != null && _weather == null)
              _errorCard()
            else if (_weather != null) ...[
              if (_loading) const LinearProgressIndicator(minHeight: 2, color: _green),
              if (_error != null) _banner(Icons.warning_amber_rounded, _error!),
              GoogleCurrentCard(weather: _weather!, place: _place),
              const SizedBox(height: 16),
              if (_where == _Where.station && _station != null && _station!.isProvisioned) ...[
                _comparePanel(),
                const SizedBox(height: 16),
              ],
              _label('Next 24 hours'),
              GoogleHourlyStrip(hours: _weather!.hours),
              const SizedBox(height: 16),
              _label('7-day forecast'),
              GoogleDailyList(days: _weather!.days),
            ],
            const SizedBox(height: 20),
            _label(_selectedStation == null ? 'Your weather station' : 'Weather station · ${_selectedStation!.name}'),
            _stationCard(),
            const SizedBox(height: 12),
            const Text(
              'Forecast data: Google Weather for the selected area. Station data: '
              'measured on your farm. Verified advice and weather alerts are based '
              'on your station\'s measurements.',
              style: TextStyle(fontSize: 11, color: Colors.black45, height: 1.4),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _searchBar() => TextField(
        controller: _searchCtrl,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _search(),
        decoration: InputDecoration(
          hintText: 'Search a town or place, e.g. Nakuru',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: IconButton(
            icon: const Icon(Icons.arrow_forward_rounded),
            tooltip: 'Get forecast',
            onPressed: _loading ? null : _search,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

  Widget _sourceChips() => Wrap(spacing: 8, runSpacing: 6, children: [
        ChoiceChip(
          avatar: const Icon(Icons.my_location_rounded, size: 16),
          label: const Text('My location'),
          selected: _where == _Where.device,
          onSelected: _loading ? null : (_) => _useDeviceLocation(),
        ),
        if (_stations.isNotEmpty)
          ChoiceChip(
            avatar: const Icon(Icons.sensors_rounded, size: 16),
            label: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 190),
              child: Text(
                _stations.length > 1 && _selectedStation != null ? 'Station: ${_selectedStation!.name}' : 'Weather station',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            selected: _where == _Where.station,
            onSelected: _loading ? null : (_) => _useStation(),
          ),
        if (_stations.length > 1)
          ActionChip(
            avatar: const Icon(Icons.swap_horiz_rounded, size: 16),
            label: const Text('Other station'),
            onPressed: _loading ? null : _pickStation,
          ),
        if (_where == _Where.search)
          const Chip(
            avatar: Icon(Icons.place_rounded, size: 16),
            label: Text('Searched place'),
          ),
      ]);

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black87)),
      );

  Widget _banner(IconData icon, String text) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: const Color(0xFFE65100)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5))),
        ]),
      );

  Widget _errorCard() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(children: [
          const Icon(Icons.cloud_off_rounded, size: 40, color: Colors.grey),
          const SizedBox(height: 10),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: _green),
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ]),
      );

  /// The station half of the pair: live measurements + a way into the full
  /// Weather Station screen (conditions, 24 h history).
  void _openComparison() => Navigator.push(
      context, MaterialPageRoute(builder: (_) => WeatherComparisonScreen(stationId: _stationId)));

  /// Google's current conditions next to the station's latest reading, with
  /// the way into the full 24-hour comparison and its downloads.
  Widget _comparePanel() {
    final row = pairNow(_weather!.current, _station);
    const metrics = [ComparedMetric.temp, ComparedMetric.humidity, ComparedMetric.wind, ComparedMetric.rain];
    String f(double? v) => v == null ? '—' : v.toStringAsFixed(1);
    String d(double? v) => v == null ? '—' : '${v > 0 ? '+' : ''}${v.toStringAsFixed(1)}';
    Widget head(String t, Color c) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(t, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c)),
        );
    Widget cell(String t, {Color? c, bool bold = false, TextAlign a = TextAlign.center}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(t, textAlign: a, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: c)),
        );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCFE3D0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.compare_arrows_rounded, color: Color(0xFF2E7D32)),
          SizedBox(width: 8),
          Expanded(
            child: Text('Google vs. weather station — right now',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 8),
        if (!row.hasStation)
          const Text('The station hasn\'t sent readings in the last 2 hours, so there\'s nothing to compare right now.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFFE65100)))
        else
          Table(
            columnWidths: const {0: FlexColumnWidth(1.6)},
            border: const TableBorder(horizontalInside: BorderSide(color: Color(0xFFEDF1ED))),
            children: [
              TableRow(children: [
                head('', Colors.black54),
                head('Google', const Color(0xFF1A73E8)),
                head('Station', const Color(0xFF2E7D32)),
                head('Difference', const Color(0xFFE65100)),
              ]),
              for (final m in metrics)
                TableRow(children: [
                  cell(m.heading, a: TextAlign.left, bold: true),
                  cell(f(row[m].google), c: const Color(0xFF1A73E8)),
                  cell(f(row[m].station), c: const Color(0xFF2E7D32)),
                  cell(d(row[m].difference), c: const Color(0xFFE65100), bold: true),
                ]),
            ],
          ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
            onPressed: _openComparison,
            icon: const Icon(Icons.table_view_rounded, size: 18),
            label: const Text('24-hour comparison · download Excel / CSV'),
          ),
        ),
      ]),
    );
  }

  Widget _stationCard() {
    final r = _station;
    Widget body;
    if (_stationLoading) {
      body = const LinearProgressIndicator(minHeight: 2);
    } else if (r == null || !r.isProvisioned) {
      body = const Text(
        'No weather station is linked to your account yet. Once one is '
        'installed you\'ll see live readings from your farm here, and verified '
        'advice from Field Agronomists.',
        style: TextStyle(fontSize: 12.5, height: 1.4),
      );
    } else if (!r.hasData) {
      body = const Text(
        'Your station hasn\'t sent readings in the last 2 hours — it may be offline.',
        style: TextStyle(fontSize: 12.5, color: Color(0xFFE65100), height: 1.4),
      );
    } else {
      body = Wrap(spacing: 14, runSpacing: 8, children: [
        _stationMetric(Icons.thermostat_rounded, '${r.airTemp.toStringAsFixed(1)}°C'),
        _stationMetric(Icons.water_drop_outlined, '${r.humidity.toStringAsFixed(0)}% RH'),
        _stationMetric(Icons.air_rounded, '${r.windSpeed.toStringAsFixed(1)} m/s'),
        _stationMetric(Icons.grain_rounded, '${r.rainfall.toStringAsFixed(1)} mm/h'),
        _stationMetric(Icons.eco_outlined, r.leafIsWet ? 'Leaves wet' : 'Leaves dry'),
      ]);
    }
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => WeatherStationScreen(initialStationId: _stationId))),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Expanded(child: WeatherSourceBadge(WeatherSource.station)),
              Icon(Icons.chevron_right_rounded, color: Colors.black38),
            ]),
            const SizedBox(height: 10),
            body,
            const SizedBox(height: 8),
            const Text('Open for live conditions and the last 24 hours',
                style: TextStyle(fontSize: 11, color: Colors.black54)),
            if (r != null && r.isProvisioned) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2E7D32),
                    side: const BorderSide(color: Color(0xFF2E7D32)),
                  ),
                  onPressed: _openComparison,
                  icon: const Icon(Icons.compare_arrows_rounded, size: 18),
                  label: const Text('Compare with Google · side by side · download'),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _stationMetric(IconData icon, String value) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: const Color(0xFF1B5E20)),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      ]);
}

/// "5 min ago" / "3 h ago" / "2 days ago".
String relativeTimeShort(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return '${d.inDays} days ago';
}
