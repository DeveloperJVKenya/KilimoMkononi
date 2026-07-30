// lib/widgets/farm_location_picker.dart
//
// Farm GPS picker — full-screen map with floating controls.
//
// LAYOUT: Map fills the entire screen. Controls float as overlays:
//   • Top-left  → search bar (collapsed until tapped)
//   • Bottom    → method FAB strip (GPS / Search / County / Coords)
//   • Bottom    → DraggableScrollableSheet for active method panel
//   • Bottom    → confirm bar (appears after pin is set)
//
// FOUR LOCATION METHODS:
//   1. GPS       — stand at farm, one tap, most accurate
//   2. Search    — type nearby area, map flies there, then GPS
//   3. County    — dropdown, offline fallback, county centroid
//   4. Coords    — paste lat/lon from farmhand via WhatsApp
//

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

// ── Palette ───────────────────────────────────────────────────────────────────
const _kDark  = Color(0xFF032704);
const _kMid   = Color(0xFF2A6B2A);
const _kLight = Color(0xFFE8F5E9);
const _kAmber = Color(0xFFE65100);
const _kBlue  = Color(0xFF1565C0);

// Kenya centre
const _kKenya = LatLng(0.0236, 37.9062);

// ── Kenya counties ────────────────────────────────────────────────────────────
const _kCounties = <String, LatLng>{
  'Baringo':         LatLng( 0.6667,  35.9667),
  'Bomet':           LatLng(-0.7830,  35.3419),
  'Bungoma':         LatLng( 0.5635,  34.5606),
  'Busia':           LatLng( 0.4606,  34.1110),
  'Elgeyo Marakwet': LatLng( 0.7167,  35.5167),
  'Embu':            LatLng(-0.5300,  37.4500),
  'Garissa':         LatLng(-0.4532,  39.6460),
  'Homa Bay':        LatLng(-0.5273,  34.4571),
  'Isiolo':          LatLng( 0.3542,  37.5822),
  'Kajiado':         LatLng(-1.8516,  36.7820),
  'Kakamega':        LatLng( 0.2827,  34.7519),
  'Kericho':         LatLng(-0.3669,  35.2863),
  'Kiambu':          LatLng(-1.0300,  36.8300),
  'Kilifi':          LatLng(-3.6297,  39.8509),
  'Kirinyaga':       LatLng(-0.5600,  37.2700),
  'Kisii':           LatLng(-0.6817,  34.7667),
  'Kisumu':          LatLng(-0.0917,  34.7679),
  'Kitui':           LatLng(-1.3672,  38.0104),
  'Kwale':           LatLng(-4.1833,  39.4500),
  'Laikipia':        LatLng( 0.3600,  36.7800),
  'Lamu':            LatLng(-2.2694,  40.9021),
  'Machakos':        LatLng(-1.5177,  37.2634),
  'Makueni':         LatLng(-2.2559,  37.8945),
  'Mandera':         LatLng( 3.9366,  41.8670),
  'Marsabit':        LatLng( 2.3284,  37.9899),
  'Meru':            LatLng( 0.0500,  37.6500),
  'Migori':          LatLng(-1.0634,  34.4731),
  'Mombasa':         LatLng(-4.0435,  39.6682),
  "Murang'a":        LatLng(-0.7167,  37.1500),
  'Nairobi':         LatLng(-1.2921,  36.8219),
  'Nakuru':          LatLng(-0.3031,  36.0800),
  'Nandi':           LatLng( 0.1833,  35.1000),
  'Narok':           LatLng(-1.0833,  35.8700),
  'Nyamira':         LatLng(-0.5700,  34.9300),
  'Nyandarua':       LatLng(-0.4500,  36.5500),
  'Nyeri':           LatLng(-0.4167,  36.9500),
  'Samburu':         LatLng( 1.2000,  36.8000),
  'Siaya':           LatLng(-0.0625,  34.2879),
  'Taita Taveta':    LatLng(-3.4000,  38.5000),
  'Tana River':      LatLng(-1.4000,  40.0000),
  'Tharaka Nithi':   LatLng(-0.2990,  37.9256),
  'Trans Nzoia':     LatLng( 1.0564,  34.9506),
  'Turkana':         LatLng( 3.3192,  35.5657),
  'Uasin Gishu':     LatLng( 0.5143,  35.2698),
  'Vihiga':          LatLng( 0.0706,  34.7238),
  'Wajir':           LatLng( 1.7500,  40.0573),
  'West Pokot':      LatLng( 1.7400,  35.1200),
};

// ── Nominatim result ──────────────────────────────────────────────────────────
class _Place {
  final String displayName;
  final LatLng  latLng;
  const _Place({required this.displayName, required this.latLng});

  factory _Place.fromJson(Map<String, dynamic> j) => _Place(
    displayName: j['display_name'] as String,
    latLng: LatLng(
      double.parse(j['lat'] as String),
      double.parse(j['lon'] as String),
    ),
  );

  String get shortName =>
      displayName.split(',').take(3).join(',').trim();
}

// ── Active method ─────────────────────────────────────────────────────────────
enum _Method { gps, search, county, coords }

// ─────────────────────────────────────────────────────────────────────────────
// FarmLocationPicker — full-screen map, overlay controls
// ─────────────────────────────────────────────────────────────────────────────

class FarmLocationPicker extends StatefulWidget {
  final LatLng? initialLatLng;
  final String  plotName;

  const FarmLocationPicker({
    super.key,
    this.initialLatLng,
    this.plotName = 'your farm',
  });

  @override
  State<FarmLocationPicker> createState() => _FarmLocationPickerState();
}

class _FarmLocationPickerState extends State<FarmLocationPicker> {
  final _mapCtrl      = MapController();
  final _searchCtrl   = TextEditingController();
  final _latCtrl      = TextEditingController();
  final _lonCtrl      = TextEditingController();
  final _searchFocus  = FocusNode();
  final _sheetCtrl    = DraggableScrollableController();

  LatLng?  _pin;
  _Method? _activeMethod;   // null = sheet closed

  // GPS
  bool    _gettingGps = false;
  String? _gpsStatus;

  // Search
  List<_Place> _suggestions  = [];
  bool         _searching    = false;
  bool         _showResults  = false;
  Timer?       _debounce;

  // County
  String? _selectedCounty;

  // Manual coords
  String? _coordError;

  @override
  void initState() {
    super.initState();
    _pin = widget.initialLatLng;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _latCtrl.dispose();
    _lonCtrl.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    _sheetCtrl.dispose();
    super.dispose();
  }

  // ── Sheet open/close ──────────────────────────────────────────────────────

  void _openMethod(_Method m) {
    setState(() => _activeMethod = m);
  }

  void _closeSheet() {
    setState(() {
      _activeMethod = null;
      _showResults  = false;
      _searchFocus.unfocus();
    });
  }

  // ── GPS ───────────────────────────────────────────────────────────────────

  Future<void> _useDeviceGps() async {
    setState(() { _gettingGps = true; _gpsStatus = null; });
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _gettingGps = false;
            _gpsStatus  = 'GPS permission denied. Enable in Settings → Apps → Kilimo Mkononi → Permissions.';
          });
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 20));

      final ll = LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {
          _pin        = ll;
          _gettingGps = false;
          _gpsStatus  = 'Location found ✓  (±${pos.accuracy.toStringAsFixed(0)} m)';
        });
        _mapCtrl.move(ll, 16);
        _closeSheet();
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _gettingGps = false;
          _gpsStatus  = 'GPS timed out. Move to open area and retry, or use another method.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _gettingGps = false;
          _gpsStatus  = 'GPS unavailable. Use Search, County or Coords instead.';
        });
      }
    }
  }

  // ── Search ────────────────────────────────────────────────────────────────

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() { _suggestions = []; _showResults = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () => _search(q));
  }

  Future<void> _search(String q) async {
    setState(() { _searching = true; _showResults = true; });
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/search')
          .replace(queryParameters: {
        'q':               '$q, Kenya',
        'format':          'json',
        'limit':           '7',
        'countrycodes':    'ke',
        'accept-language': 'en',
      });
      final resp = await http.get(uri,
          headers: {'User-Agent': 'KilimoMkononi/1.0'})
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final places = (jsonDecode(resp.body) as List)
            .whereType<Map<String, dynamic>>()
            .map(_Place.fromJson)
            .toList();
        setState(() { _suggestions = places; _searching = false; });
      } else {
        setState(() { _suggestions = []; _searching = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _suggestions = []; _searching = false; });
    }
  }

  void _selectPlace(_Place p) {
    setState(() { _showResults = false; _searchCtrl.text = p.shortName; });
    _searchFocus.unfocus();
    _mapCtrl.move(p.latLng, 14);
    // Nudge to GPS after flying to area
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: _kDark,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      content: const Text(
        'Map moved. Tap "My GPS" to pin your exact farm location.',
        style: TextStyle(fontSize: 13),
      ),
      action: SnackBarAction(
        label: 'Use GPS',
        textColor: Colors.greenAccent,
        onPressed: () { _openMethod(_Method.gps); _useDeviceGps(); },
      ),
    ));
    _closeSheet();
  }

  // ── County ────────────────────────────────────────────────────────────────

  void _selectCounty(String county) {
    final ll = _kCounties[county]!;
    setState(() { _selectedCounty = county; _pin = ll; });
    _mapCtrl.move(ll, 10);
    _closeSheet();
  }

  // ── Manual coords ─────────────────────────────────────────────────────────

  void _applyCoords() {
    final lat = double.tryParse(_latCtrl.text.trim());
    final lon = double.tryParse(_lonCtrl.text.trim());
    if (lat == null || lon == null) {
      setState(() => _coordError =
          'Enter valid numbers. Example: Latitude 0.28270, Longitude 34.75190');
      return;
    }
    if (lat < -5 || lat > 5 || lon < 33 || lon > 42) {
      setState(() => _coordError =
          'These coordinates are outside Kenya. '
          'Latitude should be −5 to 5, longitude 33 to 42.');
      return;
    }
    final ll = LatLng(lat, lon);
    setState(() { _pin = ll; _coordError = null; });
    _mapCtrl.move(ll, 15);
    _closeSheet();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      // No AppBar — map goes edge to edge
      body: Stack(children: [

        // ── LAYER 1: Full-screen map ───────────────────────────────────────
        Positioned.fill(
          child: FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: _pin ?? _kKenya,
              initialZoom:   _pin != null ? 14.0 : 6.0,
              minZoom: 4,
              maxZoom: 18,
              onTap: (_, ll) {
                setState(() { _pin = ll; _selectedCounty = null; });
                _closeSheet();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.kilimomkononi.app',
              ),
              if (_pin != null)
                MarkerLayer(markers: [
                  Marker(
                    point:  _pin!,
                    width:  40,
                    height: 48,
                    child:  const Icon(Icons.location_pin,
                        color: _kMid, size: 48),
                  ),
                ]),
            ],
          ),
        ),

        // ── LAYER 2: Top bar (back + title + confirm) ──────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(children: [
                // Back button
                _MapFab(
                  icon: Icons.arrow_back,
                  tooltip: 'Back',
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                // Title pill
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.93),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(
                          color: Colors.black12, blurRadius: 6)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Set Farm Location',
                            style: TextStyle(fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _kDark)),
                        Text(widget.plotName,
                            style: const TextStyle(fontSize: 11,
                                color: Colors.black45)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Confirm button (only when pin set)
                if (_pin != null)
                  _MapFab(
                    icon: Icons.check,
                    tooltip: 'Confirm location',
                    color: _kMid,
                    onTap: _confirm,
                    label: 'Confirm',
                  ),
              ]),
            ),
          ),
        ),

        // ── LAYER 3: "Tap map to pin" hint ────────────────────────────────
        if (_pin == null && _activeMethod == null)
          Positioned(
            top: 0, bottom: 0, left: 0, right: 0,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.52),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Text(
                    'Choose a method below, or tap anywhere on the map to pin',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.white,
                        height: 1.4),
                  ),
                ),
              ),
            ),
          ),

        // ── LAYER 4: Confirm bar (above method strip) ──────────────────────
        if (_pin != null)
          Positioned(
            bottom: 72 + bottomPadding + (_activeMethod != null ? 0 : 0),
            left: 12, right: 12,
            child: _PinConfirmBanner(
              pin:        _pin!,
              isCounty:   _selectedCounty != null,
              county:     _selectedCounty,
              onConfirm:  _confirm,
              onRemove:   () => setState(() {
                _pin = null;
                _selectedCounty = null;
              }),
            ),
          ),

        // ── LAYER 5: Method strip (bottom) ────────────────────────────────
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: _MethodStrip(
            active:   _activeMethod,
            onSelect: (m) {
              if (_activeMethod == m) {
                _closeSheet();
              } else {
                _openMethod(m);
                // Auto-trigger GPS immediately on tap
                if (m == _Method.gps) _useDeviceGps();
              }
            },
            bottomPadding: bottomPadding,
          ),
        ),

        // ── LAYER 6: Method panel sheet ────────────────────────────────────
        if (_activeMethod != null && _activeMethod != _Method.gps)
          _MethodSheet(
            method:         _activeMethod!,
            onClose:        _closeSheet,
            bottomPadding:  bottomPadding,
            // Search props
            searchCtrl:     _searchCtrl,
            searchFocus:    _searchFocus,
            searching:      _searching,
            suggestions:    _suggestions,
            showResults:    _showResults,
            onSearchChanged: _onSearchChanged,
            onSearchClear:  () {
              _searchCtrl.clear();
              setState(() { _suggestions = []; _showResults = false; });
            },
            onPlaceSelected: _selectPlace,
            // County props
            selectedCounty: _selectedCounty,
            counties:       _kCounties.keys.toList()..sort(),
            onCountySelected: _selectCounty,
            // Coords props
            latCtrl:        _latCtrl,
            lonCtrl:        _lonCtrl,
            coordError:     _coordError,
            onApplyCoords:  _applyCoords,
          ),

        // ── LAYER 7: GPS status toast (above method strip) ─────────────────
        if (_activeMethod == _Method.gps)
          Positioned(
            bottom: 72 + bottomPadding + 60,
            left: 16, right: 16,
            child: _GpsStatusCard(
              loading: _gettingGps,
              status:  _gpsStatus,
              onRetry: _useDeviceGps,
              onClose: _closeSheet,
            ),
          ),
      ]),
    );
  }

  void _confirm() {
    if (_pin != null) Navigator.pop(context, _pin);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Method strip — row of 4 icon+label buttons along the bottom of the map
// ─────────────────────────────────────────────────────────────────────────────

class _MethodStrip extends StatelessWidget {
  final _Method?              active;
  final void Function(_Method) onSelect;
  final double                bottomPadding;

  const _MethodStrip({
    required this.active,
    required this.onSelect,
    required this.bottomPadding,
  });

  @override
  Widget build(BuildContext context) {
    const methods = [
      (_Method.gps,    Icons.my_location_rounded,   'My GPS'),
      (_Method.search, Icons.search_rounded,         'Search'),
      (_Method.county, Icons.map_outlined,           'County'),
      (_Method.coords, Icons.pin_drop_outlined,      'Coords'),
    ];

    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + bottomPadding),
      child: Row(
        children: methods.map((item) {
          final (method, icon, label) = item;
          final isActive = active == method;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(method),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isActive ? _kDark : const Color(0xFFF0F2EF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActive ? _kDark : const Color(0xFFCCCCCC),
                  ),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 20,
                      color: isActive ? Colors.white : Colors.black54),
                  const SizedBox(height: 3),
                  Text(label,
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isActive ? Colors.white : Colors.black54)),
                ]),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Method sheet — slides up from bottom when a method is selected
// ─────────────────────────────────────────────────────────────────────────────

class _MethodSheet extends StatelessWidget {
  final _Method   method;
  final VoidCallback onClose;
  final double    bottomPadding;
  // Search
  final TextEditingController searchCtrl;
  final FocusNode             searchFocus;
  final bool                  searching;
  final List<_Place>          suggestions;
  final bool                  showResults;
  final ValueChanged<String>  onSearchChanged;
  final VoidCallback          onSearchClear;
  final ValueChanged<_Place>  onPlaceSelected;
  // County
  final String?               selectedCounty;
  final List<String>          counties;
  final ValueChanged<String>  onCountySelected;
  // Coords
  final TextEditingController latCtrl;
  final TextEditingController lonCtrl;
  final String?               coordError;
  final VoidCallback          onApplyCoords;

  const _MethodSheet({
    required this.method,
    required this.onClose,
    required this.bottomPadding,
    required this.searchCtrl,
    required this.searchFocus,
    required this.searching,
    required this.suggestions,
    required this.showResults,
    required this.onSearchChanged,
    required this.onSearchClear,
    required this.onPlaceSelected,
    required this.selectedCounty,
    required this.counties,
    required this.onCountySelected,
    required this.latCtrl,
    required this.lonCtrl,
    required this.coordError,
    required this.onApplyCoords,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 64 + bottomPadding, // sits just above the method strip
      left: 0, right: 0,
      child: Material(
        elevation: 12,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Drag handle + close
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
              child: Row(children: [
                Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18,
                      color: Colors.black38),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ]),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: _buildContent(),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (method) {
      case _Method.search:
        return _SearchContent(
          ctrl:        searchCtrl,
          focus:       searchFocus,
          searching:   searching,
          suggestions: suggestions,
          showResults: showResults,
          onChanged:   onSearchChanged,
          onClear:     onSearchClear,
          onSelect:    onPlaceSelected,
        );
      case _Method.county:
        return _CountyContent(
          selected:  selectedCounty,
          counties:  counties,
          onSelect:  onCountySelected,
        );
      case _Method.coords:
        return _CoordsContent(
          latCtrl:  latCtrl,
          lonCtrl:  lonCtrl,
          error:    coordError,
          onApply:  onApplyCoords,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ── Search content ────────────────────────────────────────────────────────────

class _SearchContent extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode             focus;
  final bool                  searching;
  final List<_Place>          suggestions;
  final bool                  showResults;
  final ValueChanged<String>  onChanged;
  final VoidCallback          onClear;
  final ValueChanged<_Place>  onSelect;

  const _SearchContent({
    required this.ctrl, required this.focus,
    required this.searching, required this.suggestions,
    required this.showResults, required this.onChanged,
    required this.onClear, required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const Text(
        'Type a nearby town, ward, river or trading centre. '
        'Map will jump there — then tap GPS to pin your exact farm.',
        style: TextStyle(fontSize: 12.5, color: Colors.black54, height: 1.4),
      ),
      const SizedBox(height: 10),
      Container(
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F2EF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFBBBFBA)),
        ),
        child: Row(children: [
          const SizedBox(width: 10),
          searching
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _kMid))
              : const Icon(Icons.search_rounded, size: 18,
                  color: Colors.black38),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: ctrl,
              focusNode:  focus,
              onChanged:  onChanged,
              autofocus:  true,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                hintText:       'e.g. Shinyalu, Kakamega',
                hintStyle:      TextStyle(fontSize: 13.5, color: Colors.black38),
                border:         InputBorder.none,
                isDense:        true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (ctrl.text.isNotEmpty)
            GestureDetector(
              onTap: onClear,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.close, size: 16, color: Colors.black38),
              ),
            ),
        ]),
      ),
      if (showResults) ...[
        const SizedBox(height: 4),
        if (suggestions.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: suggestions.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, indent: 40),
              itemBuilder: (_, i) {
                final p = suggestions[i];
                return ListTile(
                  dense:   true,
                  leading: const Icon(Icons.location_on_outlined,
                      size: 18, color: _kMid),
                  title: Text(p.shortName,
                      style: const TextStyle(fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  onTap: () => onSelect(p),
                );
              },
            ),
          )
        else if (!searching)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'No results. Try a nearby town, ward or river name.',
              style: TextStyle(fontSize: 12.5, color: Colors.black38),
            ),
          ),
      ],
    ]);
  }
}

// ── County content ────────────────────────────────────────────────────────────

class _CountyContent extends StatelessWidget {
  final String?               selected;
  final List<String>          counties;
  final ValueChanged<String>  onSelect;

  const _CountyContent({
    required this.selected, required this.counties, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const Text(
        'Pick your county — works without internet or GPS. '
        'Saves county centre coordinates, good enough for satellite weather data.',
        style: TextStyle(fontSize: 12.5, color: Colors.black54, height: 1.45),
      ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F2EF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFBBBFBA)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value:      selected,
            isExpanded: true,
            hint: const Text('Select your county',
                style: TextStyle(fontSize: 13.5, color: Colors.black38)),
            style: const TextStyle(fontSize: 13.5, color: Colors.black87),
            items: counties.map((c) => DropdownMenuItem(
                value: c, child: Text(c))).toList(),
            onChanged: (v) { if (v != null) onSelect(v); },
          ),
        ),
      ),
    ]);
  }
}

// ── Coords content ────────────────────────────────────────────────────────────

class _CoordsContent extends StatelessWidget {
  final TextEditingController latCtrl;
  final TextEditingController lonCtrl;
  final String?               error;
  final VoidCallback          onApply;

  const _CoordsContent({
    required this.latCtrl, required this.lonCtrl,
    required this.error,   required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: _kBlue.withValues(alpha: 0.3)),
        ),
        child: const Text(
          'Ask your farmhand to open Google Maps → tap & hold on the farm '
          'field → copy the coordinates shown → send via WhatsApp.\n'
          'Paste them here.',
          style: TextStyle(fontSize: 12, color: Color(0xFF0D3C7A), height: 1.5),
        ),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _coordField(latCtrl, 'Latitude',  '0.28270')),
        const SizedBox(width: 10),
        Expanded(child: _coordField(lonCtrl, 'Longitude', '34.75190')),
      ]),
      if (error != null) ...[
        const SizedBox(height: 6),
        Text(error!,
            style: const TextStyle(fontSize: 12, color: _kAmber, height: 1.4)),
      ],
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onApply,
          icon: const Icon(Icons.pin_drop_outlined, size: 17),
          label: const Text('Place pin',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
        ),
      ),
    ]);
  }

  Widget _coordField(TextEditingController c, String label, String hint) =>
      TextField(
        controller:   c,
        keyboardType: const TextInputType.numberWithOptions(
            signed: true, decimal: true),
        style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
        decoration: InputDecoration(
          labelText: label,
          hintText:  hint,
          filled:    true,
          fillColor: const Color(0xFFF0F2EF),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFBBBFBA))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFBBBFBA))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kBlue, width: 2)),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 12),
        ),
      );
}

// ── GPS status card (floating, not a sheet) ───────────────────────────────────

class _GpsStatusCard extends StatelessWidget {
  final bool        loading;
  final String?     status;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  const _GpsStatusCard({
    required this.loading, required this.status,
    required this.onRetry, required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isSuccess = status?.contains('✓') == true;
    final isError   = status != null && !isSuccess && !loading;
    final color     = isSuccess ? _kMid : isError ? _kAmber : Colors.black87;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            if (loading)
              const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: _kMid))
            else
              Icon(
                isSuccess ? Icons.check_circle_outline : Icons.my_location_rounded,
                size: 18, color: color,
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                loading
                    ? 'Getting your exact location…'
                    : status ?? 'Tap to get your GPS location',
                style: TextStyle(fontSize: 13, color: color, height: 1.4),
              ),
            ),
            GestureDetector(
              onTap: onClose,
              child: const Icon(Icons.close, size: 16, color: Colors.black26),
            ),
          ]),
          if (isError) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 15, color: _kMid),
                label: const Text('Try again',
                    style: TextStyle(fontSize: 12.5, color: _kMid,
                        fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _kMid),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
          if (isSuccess) ...[
            const SizedBox(height: 8),
            const Text(
              'Pin placed on map. Tap Confirm in the top-right to save.',
              style: TextStyle(fontSize: 12, color: Colors.black45, height: 1.4),
            ),
          ],
        ]),
      ),
    );
  }
}

// ── Pin confirm banner (above method strip) ───────────────────────────────────

class _PinConfirmBanner extends StatelessWidget {
  final LatLng       pin;
  final bool         isCounty;
  final String?      county;
  final VoidCallback onConfirm;
  final VoidCallback onRemove;

  const _PinConfirmBanner({
    required this.pin, required this.isCounty,
    required this.county, required this.onConfirm,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kMid.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.location_on_rounded, size: 18, color: _kMid),
          const SizedBox(width: 8),
          Expanded(
            child: isCounty && county != null
                ? Text('$county  ·  county estimate',
                    style: const TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w600, color: Colors.black87))
                : Text(
                    '${pin.latitude.toStringAsFixed(5)}°,  '
                    '${pin.longitude.toStringAsFixed(5)}°',
                    style: const TextStyle(fontSize: 12,
                        fontFamily: 'monospace', color: Colors.black87),
                  ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRemove,
            child: const Text('Remove',
                style: TextStyle(fontSize: 12, color: Colors.red,
                    decoration: TextDecoration.underline)),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kDark,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Confirm',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}

// ── Floating action button (map overlay) ─────────────────────────────────────

class _MapFab extends StatelessWidget {
  final IconData  icon;
  final String    tooltip;
  final VoidCallback onTap;
  final Color     color;
  final String?   label;

  const _MapFab({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = _kDark,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: label != null ? 12 : 10, vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(
                color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: label != null
              ? Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Text(label!,
                      style: const TextStyle(color: Colors.white, fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ])
              : Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FarmLocationPreview — inline card in plot_input_form Step 1
// ─────────────────────────────────────────────────────────────────────────────

class FarmLocationPreview extends StatelessWidget {
  final LatLng?      latLng;
  final VoidCallback onEdit;
  final String       plotName;
  final VoidCallback? onSkip;

  const FarmLocationPreview({
    super.key,
    required this.latLng,
    required this.onEdit,
    required this.plotName,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    if (latLng == null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: onEdit,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kAmber.withValues(alpha: 0.4)),
            ),
            child: Row(children: [
              const Icon(Icons.add_location_alt_outlined, size: 18,
                  color: _kAmber),
              const SizedBox(width: 10),
              const Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Set your farm location',
                      style: TextStyle(fontSize: 13,
                          fontWeight: FontWeight.w700, color: _kAmber)),
                  SizedBox(height: 3),
                  Text(
                    'GPS (best) · Search nearby area · County picker · '
                    'Paste coordinates from farmhand',
                    style: TextStyle(fontSize: 12, color: _kAmber,
                        height: 1.4),
                  ),
                ],
              )),
              const Icon(Icons.chevron_right, color: _kAmber),
            ]),
          ),
        ),
        if (onSkip != null) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onSkip,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                "Skip for now — I'll set this when I'm at my farm",
                style: TextStyle(fontSize: 12, color: Colors.black38,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.black26),
              ),
            ),
          ),
        ],
      ]);
    }

    return GestureDetector(
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: _kLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kMid.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.location_on_rounded, size: 18, color: _kMid),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Farm location set ✓',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700,
                      color: _kMid)),
              const SizedBox(height: 2),
              Text(
                '${latLng!.latitude.toStringAsFixed(5)}°,  '
                '${latLng!.longitude.toStringAsFixed(5)}°',
                style: const TextStyle(fontSize: 11.5, color: Colors.black54,
                    fontFamily: 'monospace'),
              ),
            ],
          )),
          const Text('Edit',
              style: TextStyle(fontSize: 12, color: _kMid,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline)),
        ]),
      ),
    );
  }
}