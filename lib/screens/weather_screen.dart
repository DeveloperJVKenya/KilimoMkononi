// lib/screens/weather_screen.dart
//
// Weather (farmer mode): Google Weather forecast — current conditions, next
// 24 hours and 7 days — for
//   • My location  — the device's GPS (browser location on web),
//   • My farm      — the selected plot's pin / registered county,
//   • a place the farmer types (e.g. "Nakuru", "Kitale").
//
// Paired with the farm's own NuaSense station (live measurements), clearly
// labelled as a separate source. Verified advice and alerts come from the
// station — see WeatherStationScreen — never from this forecast.

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kilimomkononi/screens/Field%20Data%20Input/weather_station_screen.dart';
import 'package:kilimomkononi/services/farm_location_service.dart';
import 'package:kilimomkononi/services/google_weather_service.dart';
import 'package:kilimomkononi/services/nuasense_service.dart';
import 'package:kilimomkononi/widgets/google_weather_widgets.dart';

enum _Where { device, farm, search }

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  WeatherScreenState createState() => WeatherScreenState();
}

class WeatherScreenState extends State<WeatherScreen> {
  static const _green = Color(0xFF032704);

  final _searchCtrl = TextEditingController();
  _Where _where = _Where.device;
  bool _loading = false;
  String? _error;
  String? _notice; // e.g. "Location is off — showing your farm"
  String _place = '';
  GoogleWeather? _weather;
  // Bumped per request so a slow older answer can't replace a newer one.
  int _request = 0;

  NuaSenseReading? _station;
  bool _stationLoading = true;

  @override
  void initState() {
    super.initState();
    _useDeviceLocation();
    _loadStation();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Sources ────────────────────────────────────────────────────────────────

  Future<void> _useDeviceLocation() async {
    final req = _start(_Where.device);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      final allowed = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      if (!allowed || !await Geolocator.isLocationServiceEnabled()) {
        if (req != _request) return;
        _notice = allowed
            ? 'Location is turned off — showing your farm instead.'
            : 'Location permission not given — showing your farm instead.';
        await _useFarm(keepNotice: true);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );
      final results = await Future.wait([
        GoogleWeatherService.forLocation(pos.latitude, pos.longitude),
        GoogleWeatherService.placeName(pos.latitude, pos.longitude),
      ]);
      _finish(req, results[0] as GoogleWeather,
          (results[1] as String?) ?? 'Your location');
    } catch (e) {
      if (req != _request) return;
      _notice = 'Could not get your location — showing your farm instead.';
      await _useFarm(keepNotice: true);
    }
  }

  Future<void> _useFarm({bool keepNotice = false}) async {
    final notice = keepNotice ? _notice : null;
    final req = _start(_Where.farm);
    _notice = notice;
    try {
      final loc = await FarmLocationService.getLocation();
      final w = await GoogleWeatherService.forLocation(loc.latitude, loc.longitude);
      _finish(req, w, loc.plotName?.isNotEmpty == true
          ? '${loc.plotName} · ${loc.displayLabel}'
          : loc.displayLabel);
    } catch (e) {
      _fail(req, e);
    }
  }

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
        _Where.device => _useDeviceLocation(),
        _Where.farm => _useFarm(),
        _Where.search => _search(),
      };

  Future<void> _loadStation() async {
    try {
      final r = await NuaSenseService.getLatestReading();
      if (mounted) setState(() => _station = r);
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
            if (_loading && _weather == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator(color: _green)),
              )
            else if (_error != null && _weather == null)
              _errorCard()
            else if (_weather != null) ...[
              if (_loading) const LinearProgressIndicator(minHeight: 2, color: _green),
              if (_error != null) _banner(Icons.warning_amber_rounded, _error!),
              GoogleCurrentCard(weather: _weather!, place: _place),
              const SizedBox(height: 16),
              _label('Next 24 hours'),
              GoogleHourlyStrip(hours: _weather!.hours),
              const SizedBox(height: 16),
              _label('7-day forecast'),
              GoogleDailyList(days: _weather!.days),
            ],
            const SizedBox(height: 20),
            _label('Your farm\'s weather station'),
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
        ChoiceChip(
          avatar: const Icon(Icons.agriculture_rounded, size: 16),
          label: const Text('My farm'),
          selected: _where == _Where.farm,
          onSelected: _loading ? null : (_) => _useFarm(),
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
  /// Weather Station screen (plan, verified advice, 24 h history).
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
            context, MaterialPageRoute(builder: (_) => const WeatherStationScreen())),
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
            const Text('Open for today\'s plan, verified advice and 24-hour history',
                style: TextStyle(fontSize: 11, color: Colors.black45)),
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
