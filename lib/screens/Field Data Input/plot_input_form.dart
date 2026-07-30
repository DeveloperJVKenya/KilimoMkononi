import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:http/http.dart' as http;
import 'package:kilimomkononi/models/field_data_model.dart';
import 'package:kilimomkononi/services/field_cost_bridge.dart';
import 'package:kilimomkononi/services/iot_sensor_service.dart';
import 'package:kilimomkononi/services/nasa_power_service.dart';
import 'package:kilimomkononi/services/offline_queue_service.dart';
import 'package:kilimomkononi/services/farm_location_service.dart';
import 'package:kilimomkononi/widgets/farm_location_picker.dart';
import 'package:kilimomkononi/widgets/farm_environment_card.dart';
import 'package:latlong2/latlong.dart';
import 'package:kilimomkononi/widgets/weather_station_inline_panel.dart';
import 'package:kilimomkononi/screens/Field%20Data%20Input/weather_station_screen.dart';
import 'package:kilimomkononi/widgets/ai_advice_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public widget classes — unchanged API, drop-in replacement
// ─────────────────────────────────────────────────────────────────────────────

abstract class PlotInputForm extends StatefulWidget {
  final String userId;
  final String plotId;
  final String structureType;
  final FlutterLocalNotificationsPlugin notificationsPlugin;
  final VoidCallback onSave;

  const PlotInputForm({
    required this.userId,
    required this.plotId,
    required this.structureType,
    required this.notificationsPlugin,
    required this.onSave,
    super.key,
  });
}

class SingleCropForm extends PlotInputForm {
  const SingleCropForm({
    required super.userId, required super.plotId,
    required super.structureType, required super.notificationsPlugin,
    required super.onSave, super.key,
  });
  @override
  State<SingleCropForm> createState() => _SingleCropFormState();
}

class IntercropForm extends PlotInputForm {
  const IntercropForm({
    required super.userId, required super.plotId,
    required super.structureType, required super.notificationsPlugin,
    required super.onSave, super.key,
  });
  @override
  State<IntercropForm> createState() => _IntercropFormState();
}

class MultiplePlotForm extends PlotInputForm {
  const MultiplePlotForm({
    required super.userId, required super.plotId,
    required super.structureType, required super.notificationsPlugin,
    required super.onSave, super.key,
  });
  @override
  State<MultiplePlotForm> createState() => _MultiplePlotFormState();
}

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const _kDarkGreen   = Color.fromARGB(255, 3, 39, 4);
const _kAccentGreen = Color(0xFF2A6B2A);

// ── AI: call the existing Firebase Cloud Function (askGemini) ──────────────
// The function holds the GEMINI_KEY secret server-side — no key in the app.
// Endpoint: https://askgemini-<hash>-uc.a.run.app  OR the v2 callable URL.
// We use the Firebase Hosting rewrite /api/askGemini → the function, which
// works for both web and APK without CORS issues.
// If you deploy to a custom domain add it below; otherwise use the default URL.
// Use the same reliable Firebase Functions endpoint as Tutor/Quiz/Vision
const _kAskGeminiFunctionUrl =
    'https://us-central1-kilimomkononi-e1031.cloudfunctions.net/askGemini';

const _kNotifChannelId   = 'field_reminders_v2';
const _kNotifChannelName = 'Field Activity Reminders';

// ─────────────────────────────────────────────────────────────────────────────
// FieldTheme — outdoor-readable colour & text system
//
// Design rules:
//  • Minimum contrast ratio 4.5:1 (WCAG AA) on all text
//  • No grey-on-white — every secondary label is dark-on-light-surface
//  • Card surfaces use off-white (#F7F7F7) not pure white — reduces glare
//  • Borders are always visible: 1.5px, dark enough to see in sunlight
//  • Status communicated by ICON + COLOUR + TEXT — never colour alone
//  • Minimum body text 14sp, minimum label text 12sp
//  • Touch targets minimum 48×48dp
// ─────────────────────────────────────────────────────────────────────────────

class FT {
  FT._();

  // ── Surfaces ──────────────────────────────────────────────────────────────
  /// Main page background — warm off-white, reduces glare vs pure white
  static const pageBg        = Color(0xFFF0F2EF);
  /// Card surface — slightly warmer than white, still high contrast
  static const cardBg        = Color(0xFFF7F8F6);
  /// Elevated card (dialogs, sheets)
  static const elevatedBg    = Color(0xFFFFFFFF);
  /// Input field background — clear distinction from card surface
  static const inputBg       = Color(0xFFECEEEB);

  // ── Borders ───────────────────────────────────────────────────────────────
  /// Default card border — always visible even in direct sunlight
  static const borderDefault = Color(0xFFBBBFBA);
  /// Focused / selected border
  static const borderFocus   = Color(0xFF2A6B2A);
  /// Danger border
  static const borderDanger  = Color(0xFFB71C1C);

  // ── Text ──────────────────────────────────────────────────────────────────
  /// Primary text — near black for max contrast
  static const textPrimary   = Color(0xFF111A10);
  /// Secondary text — dark grey, still 4.5:1 on card surface
  static const textSecondary = Color(0xFF3D4A3C);
  /// Tertiary / hint text — minimum 3:1 (used only for non-critical hints)
  static const textHint      = Color(0xFF5C6B5A);
  /// White text (on dark backgrounds)
  static const textOnDark    = Color(0xFFFFFFFF);

  // ── Brand greens ──────────────────────────────────────────────────────────
  static const brandDark     = Color(0xFF0A2E0B);   // AppBar, primary buttons
  static const brandMid      = Color(0xFF1B5E20);   // Selected chips, badges
  static const brandLight    = Color(0xFF2E7D32);   // Progress bars, switches

  // ── Semantic colours ──────────────────────────────────────────────────────
  /// Low nutrient / warning — amber, dark enough to read
  static const warnBg        = Color(0xFFFFF3CD);
  static const warnBorder    = Color(0xFFE6A817);
  static const warnText      = Color(0xFF7A4F00);
  static const warnIcon      = Color(0xFFB97000);

  /// High nutrient / danger
  static const dangerBg      = Color(0xFFFFE5E5);
  static const dangerBorder  = Color(0xFFCC1111);
  static const dangerText    = Color(0xFF7F0000);

  /// Optimal / success
  static const okBg          = Color(0xFFDFF2DF);
  static const okBorder      = Color(0xFF2E7D32);
  static const okText        = Color(0xFF0A3D0A);

  /// Info / tip
  static const infoBg        = Color(0xFFDCEEFB);
  static const infoBorder    = Color(0xFF1565C0);
  static const infoText      = Color(0xFF0D3C7A);

  /// Cost section
  static const costBg        = Color(0xFFFFF3CD);
  static const costBorder    = Color(0xFFE6A817);
  static const costText      = Color(0xFF7A4F00);
  static const costIcon      = Color(0xFFB97000);

  // ── AI advisor gradient ───────────────────────────────────────────────────
  static const aiGradientA   = Color(0xFF0D2B0E);
  static const aiGradientB   = Color(0xFF1B5E20);

  // ── Typography helpers ────────────────────────────────────────────────────
  static const TextStyle heading = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary,
    letterSpacing: -0.2,
  );
  static const TextStyle subheading = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary,
  );
  static const TextStyle body = TextStyle(
    fontSize: 14, color: textPrimary, height: 1.5,
  );
  static const TextStyle bodySmall = TextStyle(
    fontSize: 13, color: textSecondary, height: 1.4,
  );
  static const TextStyle label = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w600,
    color: textSecondary, letterSpacing: 0.4,
  );
  static const TextStyle hint = TextStyle(
    fontSize: 12, color: textHint,
  );
  static const TextStyle chipSelected = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w700, color: textOnDark,
  );
  static const TextStyle chipUnselected = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w500, color: textSecondary,
  );
  static const TextStyle sectionLabel = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w700,
    color: textHint, letterSpacing: 0.8,
  );

  // ── Card decoration ───────────────────────────────────────────────────────
  static BoxDecoration card({
    Color? bg,
    Color? border,
    double radius = 12,
  }) =>
      BoxDecoration(
        color: bg ?? cardBg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border ?? borderDefault, width: 1.5),
      );

  static BoxDecoration inputField() => BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderDefault, width: 1.5),
      );

  // ── Input decoration ──────────────────────────────────────────────────────
  static InputDecoration fieldDecor(String label, {String? suffix}) =>
      InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
            fontSize: 13, color: textSecondary, fontWeight: FontWeight.w500),
        filled: true,
        fillColor: inputBg,
        suffixText: suffix,
        suffixStyle: const TextStyle(
            fontSize: 13, color: textHint, fontWeight: FontWeight.w500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderDefault, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderDefault, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderFocus, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );
}

 const List<String> _kCropTypes = [
  'Beans','Maize','Tomatoes','Cabbages/Kales','Carrots',
  'Irish Potatoes','Wheat','Sugarcane','Rice','Onions',
];

const Map<String, List<String>> _kCropStages = {
  'Beans':          ['Vegetative','Flowering','Pod Development'],
  'Maize':          ['Emergence to V6','V6 to VT','Reproductive'],
  'Tomatoes':       ['Early Growth','Flowering and Fruit Set','Fruit Development'],
  'Cabbages/Kales': ['Early Growth','Leaf Development','Head Formation'],
  'Carrots':        ['Early Growth','Root Expansion','Maturation'],
  'Irish Potatoes': ['Early Growth','Tuber Initiation','Tuber Bulking'],
  'Wheat':          ['Early Growth','Tillering and Stem Elongation','Grain Filling'],
  'Sugarcane':      ['Early Growth','Grand Growth Phase','Maturity'],
  'Rice':           ['Early Growth','Tillering to Panicle Initiation','Grain Filling'],
  'Onions':         ['Early Growth','Bulb Formation','Maturation'],
};

const Map<String, Map<String, Map<String, double>>> _kOptimalNutrients = {
  'Beans': {
    'Vegetative':      {'N':28,'P':45,'K':56,'Zn':2.0,'Fe':10.0,'Mn':5.0,'Cu':1.0,'B':0.5,'Mo':0.1},
    'Flowering':       {'N':28,'P':0, 'K':56,'Zn':2.0,'Fe':10.0,'Mn':5.0,'Cu':1.0,'B':0.5,'Mo':0.1},
    'Pod Development': {'N':28,'P':0, 'K':56,'Zn':2.0,'Fe':10.0,'Mn':5.0,'Cu':1.0,'B':0.5,'Mo':0.1},
  },
  'Maize': {
    'Emergence to V6': {'N':45,'P':28,'K':56,'Zn':3.0,'Fe':15.0,'Mn':6.0,'Cu':1.5,'B':0.6,'Mo':0.2},
    'V6 to VT':        {'N':84,'P':28,'K':56,'Zn':3.0,'Fe':15.0,'Mn':6.0,'Cu':1.5,'B':0.6,'Mo':0.2},
    'Reproductive':    {'N':0, 'P':0, 'K':28,'Zn':3.0,'Fe':15.0,'Mn':6.0,'Cu':1.5,'B':0.6,'Mo':0.2},
  },
  'Tomatoes': {
    'Early Growth':             {'N':100,'P':50,'K':150,'Zn':2.5,'Fe':12.0,'Mn':5.5,'Cu':1.2,'B':0.7,'Mo':0.15},
    'Flowering and Fruit Set':  {'N':80, 'P':60,'K':150,'Zn':2.5,'Fe':12.0,'Mn':5.5,'Cu':1.2,'B':0.7,'Mo':0.15},
    'Fruit Development':        {'N':60, 'P':60,'K':200,'Zn':2.5,'Fe':12.0,'Mn':5.5,'Cu':1.2,'B':0.7,'Mo':0.15},
  },
  'Cabbages/Kales': {
    'Early Growth':    {'N':120,'P':60,'K':100,'Zn':2.0,'Fe':10.0,'Mn':5.0,'Cu':1.0,'B':0.5,'Mo':0.1},
    'Leaf Development':{'N':100,'P':60,'K':100,'Zn':2.0,'Fe':10.0,'Mn':5.0,'Cu':1.0,'B':0.5,'Mo':0.1},
    'Head Formation':  {'N':80, 'P':60,'K':120,'Zn':2.0,'Fe':10.0,'Mn':5.0,'Cu':1.0,'B':0.5,'Mo':0.1},
  },
  'Carrots': {
    'Early Growth':    {'N':80,'P':60,'K':120,'Zn':2.0,'Fe':10.0,'Mn':5.0,'Cu':1.0,'B':0.5,'Mo':0.1},
    'Root Expansion':  {'N':60,'P':80,'K':140,'Zn':2.0,'Fe':10.0,'Mn':5.0,'Cu':1.0,'B':0.5,'Mo':0.1},
    'Maturation':      {'N':40,'P':60,'K':140,'Zn':2.0,'Fe':10.0,'Mn':5.0,'Cu':1.0,'B':0.5,'Mo':0.1},
  },
  'Irish Potatoes': {
    'Early Growth':    {'N':100,'P':80, 'K':150,'Zn':2.5,'Fe':12.0,'Mn':5.5,'Cu':1.2,'B':0.7,'Mo':0.15},
    'Tuber Initiation':{'N':80, 'P':100,'K':180,'Zn':2.5,'Fe':12.0,'Mn':5.5,'Cu':1.2,'B':0.7,'Mo':0.15},
    'Tuber Bulking':   {'N':60, 'P':80, 'K':200,'Zn':2.5,'Fe':12.0,'Mn':5.5,'Cu':1.2,'B':0.7,'Mo':0.15},
  },
  'Wheat': {
    'Early Growth':                  {'N':100,'P':50,'K':60,'Zn':3.0,'Fe':15.0,'Mn':6.0,'Cu':1.5,'B':0.6,'Mo':0.2},
    'Tillering and Stem Elongation': {'N':120,'P':50,'K':60,'Zn':3.0,'Fe':15.0,'Mn':6.0,'Cu':1.5,'B':0.6,'Mo':0.2},
    'Grain Filling':                 {'N':80, 'P':40,'K':50,'Zn':3.0,'Fe':15.0,'Mn':6.0,'Cu':1.5,'B':0.6,'Mo':0.2},
  },
  'Sugarcane': {
    'Early Growth':       {'N':120,'P':60,'K':150,'Zn':2.5,'Fe':12.0,'Mn':5.5,'Cu':1.2,'B':0.7,'Mo':0.15},
    'Grand Growth Phase': {'N':150,'P':60,'K':180,'Zn':2.5,'Fe':12.0,'Mn':5.5,'Cu':1.2,'B':0.7,'Mo':0.15},
    'Maturity':           {'N':80, 'P':40,'K':120,'Zn':2.5,'Fe':12.0,'Mn':5.5,'Cu':1.2,'B':0.7,'Mo':0.15},
  },
  'Rice': {
    'Early Growth':                    {'N':100,'P':40,'K':80,'Zn':3.0,'Fe':15.0,'Mn':6.0,'Cu':1.5,'B':0.6,'Mo':0.2},
    'Tillering to Panicle Initiation': {'N':120,'P':50,'K':80,'Zn':3.0,'Fe':15.0,'Mn':6.0,'Cu':1.5,'B':0.6,'Mo':0.2},
    'Grain Filling':                   {'N':80, 'P':40,'K':60,'Zn':3.0,'Fe':15.0,'Mn':6.0,'Cu':1.5,'B':0.6,'Mo':0.2},
  },
  'Onions': {
    'Early Growth':   {'N':90,'P':70,'K':105,'Zn':2.0,'Fe':10.0,'Mn':5.0,'Cu':1.0,'B':0.5,'Mo':0.1},
    'Bulb Formation': {'N':0, 'P':70,'K':105,'Zn':2.0,'Fe':10.0,'Mn':5.0,'Cu':1.0,'B':0.5,'Mo':0.1},
    'Maturation':     {'N':0, 'P':0, 'K':60, 'Zn':2.0,'Fe':10.0,'Mn':5.0,'Cu':1.0,'B':0.5,'Mo':0.1},
  },
};

const Map<String, Map<String, List<Map<String, dynamic>>>> _kNutrientRecs = {
  'N': {
    'Low': [
      {'type':'Chemical',   'desc':'Apply Urea (46-0-0)',                        'content':{'N':46,'P':0,'K':0}},
      {'type':'Biological', 'desc':'Add well-decomposed compost',                'content':null},
      {'type':'Biological', 'desc':'Plant nitrogen-fixing cover crops (clover, vetch)', 'content':null},
      {'type':'Biological', 'desc':'Apply manure (cow, poultry)',                'content':null},
    ],
    'High':[
      {'type':'Management', 'desc':'Reduce nitrogen inputs',                     'content':null},
      {'type':'Biological', 'desc':'Plant cover crops to absorb excess N',       'content':null},
    ],
  },
  'P': {
    'Low':[
      {'type':'Chemical',   'desc':'Apply DAP (18-46-0)',                        'content':{'N':18,'P':46,'K':0}},
      {'type':'Biological', 'desc':'Add bone meal',                              'content':null},
      {'type':'Biological', 'desc':'Apply rock phosphate',                       'content':null},
      {'type':'Biological', 'desc':'Inoculate with mycorrhizal fungi',           'content':null},
    ],
    'High':[
      {'type':'Management', 'desc':'Reduce phosphorus inputs',                   'content':null},
    ],
  },
  'K': {
    'Low':[
      {'type':'Chemical',   'desc':'Apply Muriate of Potash (0-0-60)',           'content':{'N':0,'P':0,'K':60}},
      {'type':'Biological', 'desc':'Add wood ash',                               'content':null},
      {'type':'Biological', 'desc':'Apply composted banana peels',               'content':null},
    ],
    'High':[
      {'type':'Management', 'desc':'Reduce potassium inputs',                    'content':null},
    ],
  },
};

// ─────────────────────────────────────────────────────────────────────────────
// Shared wizard state
// ─────────────────────────────────────────────────────────────────────────────

class _PlotInputFormState<T extends PlotInputForm> extends State<T> {
  // Step tracking
  int _currentStep = 0;

  // Step 1 — Crop setup
  List<Map<String, String>> _crops = [{'type': '', 'stage': ''}];
  bool _isOrganic = false;
  DateTime? _plantingDate;
  String _farmingMethod = 'Conventional';

  // Farm GPS — set via FarmLocationPicker
  LatLng? _plotLatLng;

  // Area — numeric input + unit toggle
  String _areaUnit = 'acres'; // 'acres' | 'ha' | 'sqm'
  final _areaCtrl  = TextEditingController();

  // Farm plots loaded from SharedPreferences (same source as farm management)
  List<Map<String, String>> _farmPlots = []; // [{id, name}, ...]
  bool _farmPlotsLoaded = false;

  // Step 2 — Soil & nutrients
  final _nCtrl = TextEditingController();
  final _pCtrl = TextEditingController();
  final _kCtrl = TextEditingController();
  final List<Map<String, dynamic>> _microNutrients = [];
  final List<Map<String, dynamic>> _interventions = [];
  final Map<String, String> _nutrientStatus = {'N': '', 'P': '', 'K': ''};
  Map<String, double> _optimalAvg = {'N': 0.0, 'P': 0.0, 'K': 0.0};

  // AI advice
  bool          _aiLoading = false;
  AiAdviceData? _aiAdvice;

  // Cached environmental readings — populated by FarmEnvironmentCard callback,
  // then reused to enrich the Gemini AI prompt without extra network calls.
  IotSensorReading? _latestIot;
  SatelliteReading? _latestSat;

  // Step 3 — Confirm & save
  final List<Map<String, dynamic>> _reminders = [];
  bool _scoutingReminder = true;
  bool _fertReminder = false;
  bool _isSaving = false;

  // Timezone
  bool _tzInitialised = false;

  @override
  void initState() {
    super.initState();
    if (widget.structureType == 'intercrop') {
      _crops = [{'type': '', 'stage': ''}, {'type': '', 'stage': ''}];
    }
    _nCtrl.addListener(_updateNutrientStatus);
    _pCtrl.addListener(_updateNutrientStatus);
    _kCtrl.addListener(_updateNutrientStatus);
    _initTimezone();
    _loadFarmPlots();
  }

  @override
  void dispose() {
    _nCtrl.dispose();
    _pCtrl.dispose();
    _kCtrl.dispose();
    _areaCtrl.dispose();
    super.dispose();
  }

    // ── Timezone ──────────────────────────────────────────────────────────────

    // ── Timezone ──────────────────────────────────────────────────────────────

    // ── Timezone ──────────────────────────────────────────────────────────────

  Future<void> _initTimezone() async {
    if (_tzInitialised) return;
    try {
      tz_data.initializeTimeZones();
      
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      final String timezoneName = timezoneInfo.identifier;

      tz.setLocalLocation(tz.getLocation(timezoneName));
      _tzInitialised = true;
    } catch (_) {
      // Falls back to UTC — reminder still fires, just at UTC time
    }
  }
  // ── Nutrient status ───────────────────────────────────────────────────────

  void _updateNutrientStatus() {
    if (!mounted) return;
    setState(() {
      _optimalAvg = {'N': 0.0, 'P': 0.0, 'K': 0.0};
      int count = 0;
      for (final c in _crops) {
        final type = c['type'] ?? '';
        final stage = c['stage'] ?? '';
        if (type.isNotEmpty && stage.isNotEmpty &&
            _kOptimalNutrients[type]?[stage] != null) {
          final opt = _kOptimalNutrients[type]![stage]!;
          _optimalAvg.updateAll((k, v) => v + (opt[k] ?? 0.0));
          count++;
        }
      }
      if (count > 0) _optimalAvg.updateAll((_, v) => v / count);
      _nutrientStatus['N'] = _calcStatus(_nCtrl.text, _optimalAvg['N']!);
      _nutrientStatus['P'] = _calcStatus(_pCtrl.text, _optimalAvg['P']!);
      _nutrientStatus['K'] = _calcStatus(_kCtrl.text, _optimalAvg['K']!);
      _aiAdvice = null;

    });
  }

  String _calcStatus(String text, double optimal) {
    if (text.isEmpty || double.tryParse(text) == null || optimal == 0) return '';
    final v = double.parse(text);
    if (v < optimal * 0.9) return 'Low';
    if (v > optimal * 1.1) return 'High';
    return 'Optimal';
  }

  // ── Area conversion ───────────────────────────────────────────────────────

  double get _areaInAcres {
    final raw = double.tryParse(_areaCtrl.text) ?? 0.0;
    if (raw <= 0) return 0.0;
    switch (_areaUnit) {
      case 'ha':  return raw * 2.47105;
      case 'sqm': return raw / 4046.86;
      default:    return raw; // acres
    }
  }

  /// Human-readable conversion label shown below the input
  String get _areaConversionLabel {
    final raw = double.tryParse(_areaCtrl.text) ?? 0.0;
    if (raw <= 0) return '';
    final acres = _areaInAcres;
    final ha    = acres / 2.47105;
    final sqm   = acres * 4046.86;
    switch (_areaUnit) {
      case 'acres':
        return '= ${ha.toStringAsFixed(2)} ha  ·  ${sqm.toStringAsFixed(0)} m²';
      case 'ha':
        return '= ${acres.toStringAsFixed(2)} acres  ·  ${sqm.toStringAsFixed(0)} m²';
      case 'sqm':
        return '= ${acres.toStringAsFixed(3)} acres  ·  ${ha.toStringAsFixed(3)} ha';
      default:
        return '';
    }
  }

// ── Farm plots (for cost linkage) ─────────────────────────────────────────

Future<void> _loadFarmPlots() async {
  if (_farmPlotsLoaded) return;

  try {
    final plots = await FieldCostService.loadFarmPlots(widget.userId);
    
    if (mounted) {
      setState(() {
        _farmPlots = plots;
        _farmPlotsLoaded = true;
      });

      if (plots.isEmpty) {
        debugPrint('⚠️ Zero plots loaded — verify Farm Management saved data');
      } else {
        debugPrint('🎉 ${_farmPlots.length} plots ready for dropdown');
      }
    }
  } catch (e) {
    debugPrint('❌ Failed to load farm plots: $e');
    if (mounted) setState(() => _farmPlotsLoaded = true);
  }
}
  // ── AI Advice ─────────────────────────────────────────────────────────────

  // ── AI Advice — calls existing askGemini Cloud Function ─────────────────
  //
  // functions/index.js accepts { prompt } and returns the full Gemini response:
  // { candidates: [{ content: { parts: [{ text }] } }] }
  // No API key lives in the app — the function holds GEMINI_KEY server-side.

        Future<void> _fetchAiAdvice() async {
    final cropLabel = _crops
        .where((c) => (c['type'] ?? '').isNotEmpty)
        .map((c) => '${c['type']} (${c['stage'] ?? '—'})')
        .join(', ');

    if (cropLabel.isEmpty) {
      _showSnack('Please select a crop and growth stage first.');
      return;
    }

    setState(() {
      _aiLoading = true;
      _aiAdvice = null;
    });

    final nVal = _nCtrl.text.isEmpty ? 'not measured' : '${_nCtrl.text} kg/ha';
    final pVal = _pCtrl.text.isEmpty ? 'not measured' : '${_pCtrl.text} kg/ha';
    final kVal = _kCtrl.text.isEmpty ? 'not measured' : '${_kCtrl.text} kg/ha';
    final areaLabel = _areaInAcres > 0 ? '${_areaInAcres.toStringAsFixed(2)} acres' : 'unknown area';

    // ── Environmental context (IoT + satellite) ────────────────────────────
    IotSensorReading? iot = _latestIot;
    SatelliteReading? sat = _latestSat;
    if (iot == null) {
      try { iot = await IotSensorService.getReadingForFarm(); _latestIot = iot; } catch (_) {}
    }
    if (sat == null) {
      try { sat = await NasaPowerService.getToday(); _latestSat = sat; } catch (_) {}
    }
    List<SatelliteReading> hist = [];
    try { hist = await NasaPowerService.getHistory(days: 7); } catch (_) {}
    final rain7d = SatelliteReading.totalPrecipitation(hist);

    final iotBlock = iot == null ? '' :
        'Farm sensor: temp ${iot.temperature}°C, humidity ${iot.humidity}%, pH ${iot.ph}, EC ${iot.ec} µs/cm.';
    final satBlock = sat == null ? '' :
        'Satellite: root zone moisture ${(sat.rootZoneMoisture * 100).toStringAsFixed(0)}%, '
        '7-day rain ${rain7d.toStringAsFixed(1)} mm, soil temp ${sat.soilTempLayer1}°C.';

    final prompt = buildAiAdvicePrompt(
      roleContext: 'an agronomist',
      situation: '''
Plot: $cropLabel, $areaLabel
Soil N: $nVal (target ~${_optimalAvg['N']?.toStringAsFixed(0)} kg/ha)
Soil P: $pVal (target ~${_optimalAvg['P']?.toStringAsFixed(0)} kg/ha)
Soil K: $kVal (target ~${_optimalAvg['K']?.toStringAsFixed(0)} kg/ha)
${iotBlock.isNotEmpty ? iotBlock : ''}${satBlock.isNotEmpty ? '\n$satBlock' : ''}
''',
      extraInstructions: '''
For "problem" name the most deficient nutrient or "Balanced" if all are fine.
For recommendations include chemical fertilisers (category "chemical") and
organic options (category "organic"). Add a cultural practice (category "cultural")
if soil moisture is low. For each recommendation, "dosage" is kg/acre or litres/acre.
If soil moisture < 40%, urgentAction should be irrigation before fertiliser.
''',
    );

    try {
      final resp = await http.post(
        Uri.parse(_kAskGeminiFunctionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'prompt': prompt}),
      ).timeout(const Duration(seconds: 50));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final raw = (data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?) ?? '';
        if (mounted) {
          setState(() {
            _aiAdvice = AiAdviceData.fromRaw(raw);
            _aiLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _aiAdvice = AiAdviceData.error('AI service error. Please try again.');
            _aiLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiAdvice = AiAdviceData.error('Could not reach AI. Check internet and try again.');
          _aiLoading = false;
        });
      }
    }
  }

  void _acceptAiIntervention(AiRecommendation r) async {
    final result = await _showInterventionDialog(
      preType: r.title,
      preQuantity: null,
      preUnit: r.dosage.split(RegExp(r'\s+')).skip(1).join(' '),
    );
    if (result != null && mounted) setState(() => _interventions.add(result));
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final reminders = <Map<String, dynamic>>[];

      if (_scoutingReminder) {
        final d = DateTime.now().add(const Duration(days: 7));
        reminders.add({'activity': 'Scouting', 'date': Timestamp.fromDate(d)});
        await _scheduleNotification(
          id: 'scout_${widget.plotId}_${d.millisecondsSinceEpoch}',
          title: 'Scouting reminder — ${widget.plotId}',
          body: 'Time to scout your plot for pests and diseases.',
          scheduledDate: d,
        );
      }

      if (_fertReminder && _nutrientStatus.values.contains('Low')) {
        final d = DateTime.now().add(const Duration(days: 14));
        reminders.add({
          'activity': 'Fertiliser top-dressing',
          'date': Timestamp.fromDate(d),
        });
        await _scheduleNotification(
          id: 'fert_${widget.plotId}_${d.millisecondsSinceEpoch}',
          title: 'Fertiliser reminder — ${widget.plotId}',
          body: 'Your soil nutrient level is low. Time to top-dress.',
          scheduledDate: d,
        );
      }

      for (final r in _reminders) {
        final d = (r['date'] as Timestamp).toDate();
        await _scheduleNotification(
          id: 'custom_${widget.plotId}_${d.millisecondsSinceEpoch}',
          title: '${r['activity']} — ${widget.plotId}',
          body: 'Scheduled field activity: ${r['activity']}',
          scheduledDate: d,
        );
        reminders.add(r);
      }

      final crops =
          _crops.where((c) => (c['type'] ?? '').isNotEmpty).toList();
      final fieldData = FieldData(
        userId: widget.userId,
        plotId: widget.plotId,
        crops: crops,
        area: _areaInAcres > 0 ? _areaInAcres : null,
        npk: {
          'N': _nCtrl.text.isNotEmpty ? double.tryParse(_nCtrl.text) : null,
          'P': _pCtrl.text.isNotEmpty ? double.tryParse(_pCtrl.text) : null,
          'K': _kCtrl.text.isNotEmpty ? double.tryParse(_kCtrl.text) : null,
        },
        microNutrients:
            _microNutrients.map((m) => m['name'] as String).toList(),
        interventions: _interventions,
        reminders: reminders,
        timestamp: Timestamp.now(),
        structureType: widget.structureType,
        fertilizerRecommendation: _buildFertRec(),
      );

      final docId =
          '${widget.userId}_${fieldData.timestamp.millisecondsSinceEpoch}';

      try {
        final map = fieldData.toMap();
        // Attach environmental snapshots for historical analysis
        if (_latestIot != null) map['iotSnapshot']       = _latestIot!.toMap();
        if (_latestSat != null) map['satelliteSnapshot'] = _latestSat!.toMap();
        // Attach plot GPS so satellite/weather screens use the correct farm location
        if (_plotLatLng != null) {
          map['latitude']  = _plotLatLng!.latitude;
          map['longitude'] = _plotLatLng!.longitude;
        }

        await FirebaseFirestore.instance
            .collection('fielddata')
            .doc(docId)
            .set(map);

        await _saveCosts(docId);
        widget.onSave();
        if (mounted) {
          _showSnack('${widget.plotId} saved ✓', green: true);
          _resetForm();
        }
      } catch (_) {
        // Firestore unavailable — save to offline queue
        final map = fieldData.toMap();
        if (_latestIot != null) map['iotSnapshot']       = _latestIot!.toMap();
        if (_latestSat != null) map['satelliteSnapshot'] = _latestSat!.toMap();
        if (_plotLatLng != null) {
          map['latitude']  = _plotLatLng!.latitude;
          map['longitude'] = _plotLatLng!.longitude;
        }

        await OfflineQueueService.enqueue(
          id:         'fielddata_$docId',
          collection: 'fielddata',
          docId:      docId,
          payload:    map,
        );

        // Queue costs too — they will sync alongside the parent record
        for (final i in _interventions) {
          final amount = (i['costAmount'] as num?)?.toDouble() ?? 0.0;
          if (amount <= 0) continue;
          final costId = '${docId}_${i.hashCode}';
          await OfflineQueueService.enqueue(
            id:         'fieldcost_$costId',
            collection: 'field_costs',
            docId:      costId,
            payload: {
              'userId':    widget.userId,
              'plotId':    (i['farmPlotId'] as String?) ?? widget.plotId,
              'amount':    amount,
              'category':  inferCostCategory(i['type'] as String? ?? ''),
              'source':    'field_data',
              'timestamp': Timestamp.now(),
            },
          );
        }

        widget.onSave();
        if (mounted) {
          _showSnack('Saved offline — syncs when connected', amber: true);
          _resetForm();
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveCosts(String parentDocId) async {
    for (final i in _interventions) {
      final amount = (i['costAmount'] as num?)?.toDouble() ?? 0.0;
      if (amount <= 0) continue;

      // Use enriched description (includes crop name) if available
      final desc = (i['enrichedDesc'] as String?)?.isNotEmpty == true
          ? i['enrichedDesc'] as String
          : (i['type'] as String? ?? 'Field intervention');

      // Use the farm-management plot ID the farmer selected in the dialog,
      // falling back to the field-data plotId only if nothing was chosen
      final linkedPlotId =
          (i['farmPlotId'] as String?) ?? widget.plotId;

      final entry = FieldCostEntry(
        id: '${parentDocId}_${i.hashCode}',
        userId: widget.userId,
        plotId: linkedPlotId,
        description: desc,
        category: inferCostCategory(i['type'] as String? ?? desc),
        amount: amount,
        date: (i['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
        source: 'field_data',
        interventionType: i['interventionType'] as String?,
      );
      await FieldCostService.saveFromFieldData(entry);
    }
  }

  String _buildFertRec() {
    final recs = <String>[];
    for (final key in ['N', 'P', 'K']) {
      if (_nutrientStatus[key] == 'Low' && _kNutrientRecs.containsKey(key)) {
        recs.add(_kNutrientRecs[key]!['Low']!.first['desc'] as String);
      }
    }
    if (_aiAdvice != null && _aiAdvice!.problem.isNotEmpty) {
      recs.add('AI: ${_aiAdvice!.problem} — ${_aiAdvice!.summary}'.substring(0, 120.clamp(0, ('AI: ${_aiAdvice!.problem} — ${_aiAdvice!.summary}').length)));
    }
    return recs.join('; ');
  }

  // ── Notifications ─────────────────────────────────────────────────────────

    Future<void> _scheduleNotification({
    required String id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (scheduledDate.isBefore(DateTime.now())) return;

    try {
              if (!_tzInitialised) await _initTimezone();
      
      final tzDate = tz.TZDateTime.from(
        scheduledDate,
        tz.local,                    // This is correct (Location type)
      );
      // Persist to Firestore for reboot recovery
      await FirebaseFirestore.instance
          .collection('field_reminders')
          .doc(id)
          .set({
        'userId': widget.userId,
        'plotId': widget.plotId,
        'title': title,
        'body': body,
        'scheduledDate': Timestamp.fromDate(scheduledDate),
        'notifId': id.hashCode,
      });

      await widget.notificationsPlugin.zonedSchedule(
        id: id.hashCode,                    // ← named
        title: title,                       // ← named
        body: body,                         // ← named
        scheduledDate: tzDate,              // ← named
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _kNotifChannelId,
            _kNotifChannelName,
            channelDescription: 'Reminders for field activities',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {
      // Notification persisted in Firestore — reboot receiver will re-schedule
    }
  }
  
  void _showSnack(String msg, {bool green = false, bool amber = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: green
          ? const Color(0xFF2E7D32)
          : amber
              ? const Color(0xFFF57C00)
              : null,
      behavior: SnackBarBehavior.floating,
      content: Text(msg, style: const TextStyle(color: Colors.white)),
    ));
  }

  void _resetForm() {
    setState(() {
      _currentStep = 0;
      _crops = widget.structureType == 'intercrop'
          ? [{'type': '', 'stage': ''}, {'type': '', 'stage': ''}]
          : [{'type': '', 'stage': ''}];
      _areaCtrl.clear();
      _areaUnit = 'acres';
      _plantingDate = null;
      _farmingMethod = 'Conventional';
      _isOrganic = false;
      _nCtrl.clear(); _pCtrl.clear(); _kCtrl.clear();
      _microNutrients.clear();
      _interventions.clear();
      _reminders.clear();
      _nutrientStatus.updateAll((_, _) => '');
      _optimalAvg.updateAll((_, _) => 0.0);
      _aiAdvice = null;
      _plotLatLng = null;

    });
  }

  Future<Map<String, dynamic>?> _showInterventionDialog({
    String? preType,
    double? preQuantity,
    String? preUnit,
  }) async {
    String type    = preType ?? '';
    String qtyText = preQuantity?.toStringAsFixed(1) ?? '';
    String unit    = preUnit ?? 'kg';
    DateTime date  = DateTime.now();
    double costAmount = 0;
    bool saveToCosts = true;
    String costCategory = inferCostCategory(type);

    // Farm plot linkage — default to first plot if any exist
    String? selectedFarmPlotId =
        _farmPlots.isNotEmpty ? _farmPlots.first['id'] : null;

    final typeCtrl = TextEditingController(text: type);
    final qtyCtrl  = TextEditingController(text: qtyText);
    final unitCtrl = TextEditingController(text: unit);
    final costCtrl = TextEditingController();

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: FT.elevatedBg,
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        title: Text(
          preType != null ? 'Log intervention' : 'Add intervention',
          style: FT.heading,
        ),
        content: StatefulBuilder(
          builder: (ctx, setS) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Intervention type
                _dialogField('Intervention type', typeCtrl, onChanged: (v) {
                  type = v;
                  setS(() => costCategory = inferCostCategory(v));
                }),
                const SizedBox(height: 12),

                // Quantity + unit
                Row(children: [
                  Expanded(
                    flex: 2,
                    child: _dialogField('Quantity', qtyCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (v) => qtyText = v),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _dialogField('Unit', unitCtrl,
                        onChanged: (v) => unit = v),
                  ),
                ]),
                const SizedBox(height: 12),

                // Date picker
                _dialogDatePicker(
                  date: date,
                  onPicked: (d) => setS(() => date = d),
                  ctx: ctx,
                ),
                const SizedBox(height: 16),

                // ── Cost section (with Farm Plot inside) ──────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: FT.costBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: FT.costBorder, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Farm Plot Link — inside cost card
                      Text('LINK COST TO FARM PLOT', style: FT.sectionLabel),
                      const SizedBox(height: 6),

                      if (_farmPlotsLoaded) ...[
                        if (_farmPlots.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: FT.inputBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: FT.borderDefault, width: 1.5),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedFarmPlotId,
                                isExpanded: true,
                                style: FT.body,
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('General / No Specific Plot'),
                                  ),
                                  ..._farmPlots.map((p) => DropdownMenuItem(
                                        value: p['id'],
                                        child: Text(p['name'] ?? 'Unnamed Plot'),
                                      )),
                                ],
                                onChanged: (v) => setS(() => selectedFarmPlotId = v),
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: FT.warnBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: FT.warnBorder),
                            ),
                            child: const Row(children: [
                              Icon(Icons.warning_amber, size: 18, color: FT.warnText),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'No plots found in Farm Management.\n'
                                  'Please add plots first.',
                                  style: TextStyle(fontSize: 13, color: FT.warnText),
                                ),
                              ),
                            ]),
                          ),
                      ] else ...[
                        const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ],

                      const SizedBox(height: 16),

                      // Cost Input
                      Row(children: [
                        const Icon(Icons.payments_outlined, size: 16, color: FT.costIcon),
                        const SizedBox(width: 8),
                        Text('Cost (optional)', 
                            style: FT.subheading.copyWith(color: FT.costText)),
                      ]),
                      const SizedBox(height: 10),

                      _dialogField('Amount (KES)', costCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (v) => costAmount = double.tryParse(v) ?? 0),

                      const SizedBox(height: 12),

                      // Auto-category
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: FT.okBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: FT.okBorder, width: 1.5),
                        ),
                        child: Row(children: [
                          const Icon(Icons.auto_awesome, size: 14, color: FT.brandMid),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text('Category: $costCategory',
                                style: FT.bodySmall.copyWith(color: FT.okText)),
                          ),
                        ]),
                      ),

                      const SizedBox(height: 12),

                      // Save toggle
                      Row(children: [
                        Switch(
                          value: saveToCosts,
                          onChanged: (v) => setS(() => saveToCosts = v),
                          activeThumbColor: FT.brandLight,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Save to Farm Management costs',
                            style: FT.bodySmall,
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: FT.body.copyWith(color: FT.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (type.isNotEmpty) {
                final cropLabel = _crops
                    .where((c) => (c['type'] ?? '').isNotEmpty)
                    .map((c) => c['type'])
                    .join(', ');
                final enrichedDesc = cropLabel.isNotEmpty
                    ? '$type — $cropLabel'
                    : type;

                Navigator.pop(ctx, {
                  'type': type,
                  'quantity': double.tryParse(qtyText),
                  'unit': unit,
                  'date': Timestamp.fromDate(date),
                  'costAmount': saveToCosts ? costAmount : 0.0,
                  'costCategory': costCategory,
                  'saveToCosts': saveToCosts,
                  'farmPlotId': selectedFarmPlotId,
                  'enrichedDesc': enrichedDesc,
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: FT.brandDark,
              foregroundColor: FT.textOnDark,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Log it',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  /// Small date picker used inside dialogs
  Widget _dialogDatePicker({
    required DateTime date,
    required ValueChanged<DateTime> onPicked,
    required BuildContext ctx,
  }) {
    return StatefulBuilder(
      builder: (_, setS) => InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: ctx,
            initialDate: date,
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
          );
          if (picked != null) {
            onPicked(picked);
            setS(() {});
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: FT.inputBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: FT.borderDefault, width: 1.5),
          ),
          child: Row(children: [
            const Icon(Icons.calendar_today_rounded,
                size: 18, color: FT.textSecondary),
            const SizedBox(width: 10),
            Text(date.toString().substring(0, 10),
                style: FT.body),
          ]),
        ),
      ),
    );
  }

  /// High-contrast text field for use inside dialogs
  Widget _dialogField(
    String label,
    TextEditingController ctrl, {
    TextInputType keyboardType = TextInputType.text,
    ValueChanged<String>? onChanged,
  }) =>
      TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: FT.body,
        decoration: FT.fieldDecor(label),
      );

  Future<void> _addInterventionFromRec(
      String nutrient, String status, Map<String, dynamic> rec) async {
    final area = _areaInAcres;
    double? qty;
    if (status == 'Low' && !_isOrganic) {
      final level = double.tryParse(nutrient == 'N'
              ? _nCtrl.text
              : nutrient == 'P'
                  ? _pCtrl.text
                  : _kCtrl.text) ??
          0.0;
      final opt     = _optimalAvg[nutrient] ?? 0.0;
      final deficit = opt - level;
      final content = rec['content'] as Map<String, dynamic>?;
      if (content != null && content[nutrient] != null && area > 0) {
        final pct = (content[nutrient] as num).toDouble() / 100.0;
        if (pct > 0) qty = (deficit * area) / pct;
      }
    }
    final result = await _showInterventionDialog(
      preType: rec['desc'] as String?, preQuantity: qty, preUnit: 'kg',
    );
    if (result != null && mounted) setState(() => _interventions.add(result));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildStepHeader(),
        Expanded(
          child: IndexedStack(
            index: _currentStep,
            children: [_buildStep1(), _buildStep2(), _buildStep3()],
          ),
        ),
        _buildNavBar(),
      ],
    );
  }

  Widget _buildStepHeader() {
    const steps = ['Crop setup', 'Soil & nutrients', 'Confirm & save'];
    return Container(
      color: FT.cardBg,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        children: [
          Row(
            children: List.generate(3, (i) {
              final done = i < _currentStep;
              final active = i == _currentStep;
              return Expanded(
                child: Row(children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done
                          ? FT.brandLight
                          : active ? FT.brandDark : FT.inputBg,
                      border: Border.all(
                        color: done || active
                            ? Colors.transparent
                            : FT.borderDefault,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: done
                          ? const Icon(Icons.check,
                              size: 14, color: FT.textOnDark)
                          : Text('${i + 1}',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: active
                                      ? FT.textOnDark
                                      : FT.textHint)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(steps[i],
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: active
                                ? FT.textPrimary
                                : done
                                    ? FT.brandLight
                                    : FT.textHint),
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (i < 2)
                    Container(
                        height: 2, width: 12,
                        color: done ? FT.brandLight : FT.borderDefault,
                        margin: const EdgeInsets.only(right: 6)),
                ]),
              );
            }),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: (_currentStep + 1) / 3,
            minHeight: 5,
            borderRadius: BorderRadius.circular(4),
            backgroundColor: FT.inputBg,
            valueColor:
                const AlwaysStoppedAnimation<Color>(FT.brandLight),
          ),
        ],
      ),
    );
  }

  // ── Step 1 ────────────────────────────────────────────────────────────────

  Widget _buildStep1() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ..._crops.asMap().entries.map((e) => _cropCard(e.key)),
        if (widget.structureType == 'intercrop')
          _addButton('+ Add another crop',
              () => setState(() => _crops.add({'type': '', 'stage': ''}))),
        const SizedBox(height: 16),
        _sectionLabel('Plot size'),
        _areaSelector(),
        const SizedBox(height: 16),
        _sectionLabel('Planting date'),
        _datePicker(),
        const SizedBox(height: 16),
        _sectionLabel('Farming method'),
        _chipGroup(['Conventional', 'Organic', 'Mixed'], _farmingMethod, (v) {
          setState(() { _farmingMethod = v; _isOrganic = v == 'Organic'; });
        }),
        const SizedBox(height: 16),

        // ── Farm Location ───────────────────────────────────────────────────
        // Setting GPS here means satellite data, weather, pest & disease
        // screens will all use THIS farm's exact coordinates — not your
        // registration county. Critical for farmers with farms far from home.
        _sectionLabel('Farm location (GPS)'),
        FarmLocationPreview(
          latLng:   _plotLatLng,
          plotName: widget.plotId,
          onEdit:   _openLocationPicker,
          onSkip:   () {}, // farmer can skip — location set later at farm
        ),
        const SizedBox(height: 16),
        if (_crops.isNotEmpty &&
            (_crops.first['type'] ?? '').isNotEmpty &&
            (_crops.first['stage'] ?? '').isNotEmpty)
          _tipCard(
              'Selecting the correct growth stage unlocks stage-specific '
              'nutrient targets and AI advice for ${_crops.first['type']}.'),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Farm GPS picker ───────────────────────────────────────────────────────

  Future<void> _openLocationPicker() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => FarmLocationPicker(
          initialLatLng: _plotLatLng,
          plotName: widget.plotId,
        ),
        fullscreenDialog: true,
      ),
    );
    if (result != null && mounted) {
      setState(() => _plotLatLng = result);
      // Persist to Firestore in background so satellite screen picks it up
      await FarmLocationService.savePlotGps(
          widget.userId, widget.plotId, result.latitude, result.longitude);
      // Auto-select this plot so satellite/weather screens switch to it
      await FarmLocationService.selectPlot(widget.plotId);
    }
  }

  Widget _cropCard(int idx) {
    final cropType = _crops[idx]['type'] ?? '';
    final stages = _kCropStages[cropType] ?? [];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: FT.card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(
              widget.structureType == 'intercrop'
                  ? 'CROP ${idx + 1}'
                  : 'CROP',
              style: FT.sectionLabel),
          const Spacer(),
          if (widget.structureType == 'intercrop' && idx >= 2)
            GestureDetector(
              onTap: () => setState(() => _crops.removeAt(idx)),
              child: const Icon(Icons.close, size: 20, color: FT.dangerText),
            ),
        ]),
        const SizedBox(height: 10),
        Text('Crop type', style: FT.label),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _kCropTypes.map((c) => _chip(c, cropType == c, () {
            setState(() {
              _crops[idx]['type'] = c;
              _crops[idx]['stage'] = '';
              _updateNutrientStatus();
            });
          })).toList(),
        ),
        if (cropType.isNotEmpty && stages.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Growth stage', style: FT.label),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: stages.map((s) => _chip(s, _crops[idx]['stage'] == s, () {
              setState(() {
                _crops[idx]['stage'] = s;
                _updateNutrientStatus();
              });
            })).toList(),
          ),
        ],
      ]),
    );
  }

  Widget _areaSelector() {
    // Common plot sizes for East African smallholders
    const quickTaps = ['0.25', '0.5', '0.75', '1', '1.5', '2', '3', '5'];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Unit toggle row
      Row(children: [
        Text('Unit:', style: FT.label),
        const SizedBox(width: 10),
        _unitChip('Acres', 'acres'),
        const SizedBox(width: 6),
        _unitChip('Hectares', 'ha'),
        const SizedBox(width: 6),
        _unitChip('Sq Metres', 'sqm'),
      ]),
      const SizedBox(height: 10),

      // Numeric input
      TextField(
        controller: _areaCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: FT.body.copyWith(
            fontSize: 20, fontWeight: FontWeight.w700),
        onChanged: (_) => setState(() {}),
        decoration: FT.fieldDecor(
          'Plot size',
          suffix: _areaUnit == 'acres'
              ? 'acres'
              : _areaUnit == 'ha'
                  ? 'ha'
                  : 'm²',
        ).copyWith(
          hintText: '0.0',
          hintStyle: FT.body.copyWith(
              fontSize: 20,
              color: FT.textHint,
              fontWeight: FontWeight.w400),
        ),
      ),

      // Live conversion display
      if (_areaConversionLabel.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 2),
          child: Text(_areaConversionLabel,
              style: FT.bodySmall.copyWith(color: FT.brandMid)),
        ),

      const SizedBox(height: 12),

      // Quick-tap common sizes (only show when unit is acres)
      if (_areaUnit == 'acres') ...[
        Text('COMMON SIZES', style: FT.sectionLabel),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: quickTaps.map((v) {
            final isSelected = _areaCtrl.text == v;
            return GestureDetector(
              onTap: () {
                setState(() => _areaCtrl.text = v);
                _areaCtrl.selection = TextSelection.fromPosition(
                    TextPosition(offset: _areaCtrl.text.length));
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 130),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected ? FT.brandMid : FT.cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? FT.brandMid
                        : FT.borderDefault,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  '$v ac',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? FT.textOnDark
                        : FT.textPrimary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    ]);
  }

  Widget _unitChip(String label, String value) {
    final selected = _areaUnit == value;
    return GestureDetector(
      onTap: () => setState(() {
        _areaUnit = value;
        _areaCtrl.clear();
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? FT.brandMid : FT.cardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? FT.brandMid : FT.borderDefault,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? FT.textOnDark : FT.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _datePicker() {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _plantingDate ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
                colorScheme: const ColorScheme.light(
                    primary: FT.brandDark,
                    onPrimary: FT.textOnDark,
                    surface: FT.cardBg,
                    onSurface: FT.textPrimary)),
            child: child!,
          ),
        );
        if (picked != null) setState(() => _plantingDate = picked);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: FT.inputBg,
          border: Border.all(color: FT.borderDefault, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_today_rounded,
              size: 20, color: FT.textSecondary),
          const SizedBox(width: 12),
          Text(
            _plantingDate != null
                ? _plantingDate!.toString().substring(0, 10)
                : 'Select planting date',
            style: FT.body.copyWith(
                color: _plantingDate != null
                    ? FT.textPrimary
                    : FT.textHint),
          ),
        ]),
      ),
    );
  }

  // ── Step 2 ────────────────────────────────────────────────────────────────

  Widget _buildStep2() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Farm conditions (weather + satellite) ──────────────────
        // Shows live weather station and satellite data for context.
        // NPK values below must be entered manually from a soil test.
        FarmEnvironmentCard(
          mode: FarmEnvironmentCardMode.soilSummary,
          onIotLoaded: (IotSensorReading reading) {
            // Cache for Firestore snapshot (ambient farm conditions only).
            // NPK fields are NOT auto-filled — soil test numbers must be
            // entered manually by the farmer or field officer.
            _latestIot = reading;
          },
        ),
        const SizedBox(height: 12),

        // ── Weather station inline panel ────────────────────────────
        WeatherStationInlinePanel(
          showFertiliser: true,
          showDegreeDays: false,
          cropNames: _crops
              .map((c) => (c['type'] ?? ''))
              .where((t) => t.isNotEmpty)
              .toList(),
          onOpenFullScreen: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const WeatherStationScreen()),
          ),
        ),
        const SizedBox(height: 12),

        // ── Macronutrients ─────────────────────────────────────────
        _sectionLabel('Macronutrients (kg/ha)'),
        // Guidance: values come from a soil test, not auto-filled
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: FT.infoBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: FT.infoBorder, width: 1.5),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.science_outlined, size: 16, color: FT.infoText),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Enter your soil test results below.\n'
                'Get a test from Egerton University, Crop Nutrition Lab, '
                'or use a soil test kit. Leave blank if not yet tested.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: FT.infoText,
                  height: 1.5,
                ),
              ),
            ),
          ]),
        ),
        _npkRow(),
        const SizedBox(height: 8),
        ..._buildNutrientAlerts(),

        // ── AI Advisor Section ─────────────────────────────────────────
        const SizedBox(height: 16),
        AiAdviceCard(
          headerTitle: 'Shamba AI Advisor',
          headerSubtitle: 'Powered by Gemini · Enter NPK values first',
          loading: _aiLoading,
          loadingText: 'Analysing your soil...',
          data: _aiAdvice,
          emptyStateText:
              'Enter your NPK values above, then get clear soil analysis and practical fertiliser advice.',
          ctaLabel: 'Get AI soil advice',
          onFetch: _fetchAiAdvice,
          problemLabel: 'Soil status',
          problemIcon: Icons.grass_outlined,
          recommendationsLabel: 'Fertiliser recommendations',
          onUseRecommendation: _acceptAiIntervention,
        ),

        // ── Micronutrients ─────────────────────────────────────────────
        const SizedBox(height: 16),
        _sectionLabel('Micronutrients'),
        ..._microNutrients.asMap().entries.map((e) => _microRow(e.key)),
        _addButton('+ Add micronutrient', () {
          setState(() =>
              _microNutrients.add({'name': '', 'level': '', 'status': ''}));
        }),

        // ── Interventions ──────────────────────────────────────────────
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionLabel('Interventions logged'),
            TextButton.icon(
              onPressed: _showOrganicGuide,
              icon: const Icon(Icons.info_outline, size: 14),
              label: const Text('Organic guide',
                  style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1565C0)),
            ),
          ],
        ),
        ..._interventions.asMap().entries.map((e) =>
            _interventionTile(e.key, e.value)),
        _addButton('+ Log intervention', () async {
          final r = await _showInterventionDialog();
          if (r != null && mounted) setState(() => _interventions.add(r));
        }),
      ],
    );
  }

  Widget _npkRow() {
    final labels = {
      'N': 'Nitrogen\n(N)',
      'P': 'Phosphorus\n(P)',
      'K': 'Potassium\n(K)',
    };
    final ctrls = {'N': _nCtrl, 'P': _pCtrl, 'K': _kCtrl};
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: ['N', 'P', 'K'].map((key) {
        final status  = _nutrientStatus[key] ?? '';
        final optimal = _optimalAvg[key] ?? 0.0;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: key == 'K' ? 0 : 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: status.isNotEmpty ? _statusBg(status) : FT.cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: status.isNotEmpty
                    ? _statusBorder(status)
                    : FT.borderDefault,
                width: 1.5,
              ),
            ),
            child: Column(children: [
              Text(labels[key]!,
                  textAlign: TextAlign.center,
                  style: FT.label),
              const SizedBox(height: 8),
              TextFormField(
                controller: ctrls[key],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: FT.heading.copyWith(fontSize: 22),
                decoration: const InputDecoration(
                  hintText: '—',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (optimal > 0) ...[
                const SizedBox(height: 4),
                Text('target: ${optimal.toStringAsFixed(0)}',
                    style: FT.hint),
              ],
              if (status.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusBorder(status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: _statusBorder(status), width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        status == 'Low'
                            ? Icons.arrow_downward_rounded
                            : status == 'High'
                                ? Icons.arrow_upward_rounded
                                : Icons.check_rounded,
                        size: 12,
                        color: _statusColor(status),
                      ),
                      const SizedBox(width: 3),
                      Text(status,
                          style: FT.label.copyWith(
                              color: _statusColor(status),
                              letterSpacing: 0.2)),
                    ],
                  ),
                ),
              ],
            ]),
          ),
        );
      }).toList(),
    );
  }

  List<Widget> _buildNutrientAlerts() {
    final alerts = <Widget>[];
    for (final key in ['N', 'P', 'K']) {
      final status = _nutrientStatus[key] ?? '';
      if (status != 'Low' && status != 'High') continue;
      final recs = (_kNutrientRecs[key]?[status] ?? [])
          .where((r) => !_isOrganic || r['type'] != 'Chemical')
          .toList();
      if (recs.isEmpty) continue;
      alerts.add(Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: status == 'Low'
              ? const Color(0xFFFFF8E1)
              : const Color(0xFFFCE4EC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: status == 'Low'
                  ? const Color(0xFFFFE082)
                  : const Color(0xFFF48FB1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(
                status == 'Low'
                    ? Icons.warning_amber_rounded
                    : Icons.trending_up,
                size: 15,
                color: status == 'Low'
                    ? const Color(0xFFF57C00)
                    : Colors.red,
              ),
              const SizedBox(width: 6),
              Text(
                status == 'Low'
                    ? '${_keyName(key)} low — target ${_optimalAvg[key]?.toStringAsFixed(0)} kg/ha'
                    : '${_keyName(key)} is high',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: status == 'Low'
                        ? const Color(0xFFE65100)
                        : Colors.red[700]),
              ),
            ]),
            const SizedBox(height: 8),
            ...recs.take(2).map((rec) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Expanded(
                      child: Text('${rec['type']}: ${rec['desc']}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black87)),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () =>
                          _addInterventionFromRec(key, status, rec),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1565C0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Log',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ]),
                )),
          ],
        ),
      ));
    }
    return alerts;
  }

  String _keyName(String k) =>
      k == 'N' ? 'Nitrogen' : k == 'P' ? 'Phosphorus' : 'Potassium';

  Widget _microRow(int idx) {
    const micros = ['Zn', 'Fe', 'Mn', 'Cu', 'B', 'Mo'];
    final selected = _microNutrients[idx]['name'] as String? ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Wrap(
              spacing: 5,
              children: micros.map((m) => _chipSmall(m, selected == m, () {
                setState(() => _microNutrients[idx]['name'] = m);
              })).toList(),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _microNutrients.removeAt(idx)),
            child: const Icon(Icons.close, size: 16, color: Colors.red),
          ),
        ]),
        if (selected.isNotEmpty) ...[
          const SizedBox(height: 8),
          TextFormField(
            initialValue: _microNutrients[idx]['level'] as String? ?? '',
            keyboardType: TextInputType.number,
            onChanged: (v) => setState(() => _microNutrients[idx]['level'] = v),
            decoration: InputDecoration(
              labelText: 'Level (ppm)',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
          ),
        ],
      ]),
    );
  }

  Widget _interventionTile(int idx, Map<String, dynamic> item) {
    final date   = (item['date'] as Timestamp?)?.toDate();
    final cost   = (item['costAmount'] as num?)?.toDouble() ?? 0.0;
    final toFarm = item['saveToCosts'] as bool? ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(children: [
        Container(
          width: 8, height: 8,
          decoration: const BoxDecoration(
              shape: BoxShape.circle, color: Color(0xFFF57C00)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${item['type']}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87)),
                Text(
                  [
                    if (item['quantity'] != null)
                      '${(item['quantity'] as num).toStringAsFixed(1)} ${item['unit'] ?? ''}',
                    if (date != null) date.toString().substring(0, 10),
                    if (cost > 0)
                      'KES ${cost.toStringAsFixed(0)}'
                          '${toFarm ? ' → Farm mgmt' : ''}',
                  ].join(' · '),
                  style: const TextStyle(
                      fontSize: 11, color: Colors.black45),
                ),
              ]),
        ),
        GestureDetector(
          onTap: () => setState(() => _interventions.removeAt(idx)),
          child: const Icon(Icons.close, size: 15, color: Colors.black26),
        ),
      ]),
    );
  }

  void _showOrganicGuide() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        title: const Text('Organic soil management',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600)),
        content: const SingleChildScrollView(
          child: Text(
            '• Crop rotation prevents nutrient depletion and breaks pest cycles.\n'
            '• Cover crops like clover or vetch fix atmospheric nitrogen.\n'
            '• Compost provides balanced slow-release nutrients.\n'
            '• Manure (cow, poultry) boosts soil biology and fertility.\n'
            '• Biochar improves nutrient retention and water holding.\n'
            '• Mycorrhizal fungi inoculation enhances P uptake.\n'
            '• Mulching retains moisture and adds organic matter.',
            style:
                TextStyle(fontSize: 13, height: 1.7, color: Colors.black87),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Got it',
                  style: TextStyle(color: _kDarkGreen))),
        ],
      ),
    );
  }

  // ── Step 3 ────────────────────────────────────────────────────────────────

  Widget _buildStep3() {
    final cropLabel = _crops
        .where((c) => (c['type'] ?? '').isNotEmpty)
        .map((c) => '${c['type']} · ${c['stage'] ?? '—'}')
        .join(', ');
    final hasLow = _nutrientStatus.values.contains('Low');
    final totalCost = _interventions.fold<double>(
        0, (s, i) => s + ((i['costAmount'] as num?)?.toDouble() ?? 0.0));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionLabel('Summary'),
        _summaryCard(cropLabel, totalCost),
        const SizedBox(height: 16),
        _sectionLabel('Reminders'),
        _reminderToggle(
          title: 'Scouting reminder',
          subtitle: 'In 7 days — ${_daysFromNow(7)}',
          value: _scoutingReminder,
          onChanged: (v) => setState(() => _scoutingReminder = v),
        ),
        if (hasLow)
          _reminderToggle(
            title: 'Fertiliser top-dress alert',
            subtitle: 'Based on low nutrient level — ${_daysFromNow(14)}',
            value: _fertReminder,
            onChanged: (v) => setState(() => _fertReminder = v),
          ),
        _addButton('+ Add custom reminder', _addCustomReminder),
        ..._reminders.map((r) => _reminderTile(r)),
        const SizedBox(height: 16),
        if (totalCost > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFE082)),
            ),
            child: Row(children: [
              const Icon(Icons.payments_outlined,
                  size: 16, color: Color(0xFFE65100)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'KES ${totalCost.toStringAsFixed(0)} in costs will be saved to Farm Management.',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFFE65100)),
                ),
              ),
            ]),
          ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFA5D6A7)),
          ),
          child: const Row(children: [
            Icon(Icons.check_circle_outline,
                size: 16, color: Color(0xFF2E7D32)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Ready to save. Data syncs to your history and season analysis.',
                style: TextStyle(
                    fontSize: 12, color: Color(0xFF1B5E20)),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _summaryCard(String cropLabel, double totalCost) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(children: [
        _summaryRow('Crop', cropLabel.isNotEmpty ? cropLabel : '—'),
        _summaryRow('Plot size',
            _areaCtrl.text.isNotEmpty
                ? '${_areaCtrl.text} ${_areaUnit == 'acres' ? 'acres' : _areaUnit == 'ha' ? 'ha' : 'm²'}${_areaConversionLabel.isNotEmpty ? '  ($_areaConversionLabel)' : ''}'
                : '—'),
        _summaryRow(
          'N / P / K',
          [_nCtrl.text, _pCtrl.text, _kCtrl.text].any((v) => v.isNotEmpty)
              ? '${_nCtrl.text.isNotEmpty ? "${_nCtrl.text} N" : "—"} · '
                  '${_pCtrl.text.isNotEmpty ? "${_pCtrl.text} P" : "—"} · '
                  '${_kCtrl.text.isNotEmpty ? "${_kCtrl.text} K" : "—"}'
              : '—',
        ),
        _summaryRow('Interventions',
            _interventions.isNotEmpty
                ? '${_interventions.length} logged'
                : 'None'),
        _summaryRow('Farming method', _farmingMethod),
        if (totalCost > 0)
          _summaryRow(
              'Total cost', 'KES ${totalCost.toStringAsFixed(0)}'),
      ]),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: Colors.black45))),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87)),
        ),
      ]),
    );
  }

  Widget _reminderToggle({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 11, color: Colors.black45)),
          ]),
        ),
        Switch(
          value: value, onChanged: onChanged,
          activeThumbColor: _kAccentGreen,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ]),
    );
  }

  Widget _reminderTile(Map<String, dynamic> r) {
    final date = (r['date'] as Timestamp?)?.toDate();
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(children: [
        const Icon(Icons.notifications_outlined,
            size: 15, color: Colors.black38),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${r['activity']}'
            '${date != null ? '  ·  ${date.toString().substring(0, 10)}' : ''}',
            style: const TextStyle(
                fontSize: 12, color: Colors.black87),
          ),
        ),
      ]),
    );
  }

  Future<void> _addCustomReminder() async {
    String? activity;
    DateTime date = DateTime.now().add(const Duration(days: 7));

    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        backgroundColor: Colors.white,
        title: const Text('Add reminder',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _kDarkGreen)),
        content: StatefulBuilder(
          builder: (ctx, setS) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(
                  'Activity (e.g. spray, irrigate)',
                  TextEditingController(),
                  onChanged: (v) => activity = v),
              const SizedBox(height: 10),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: date,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setS(() => date = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 15, color: Colors.black45),
                    const SizedBox(width: 8),
                    Text(date.toString().substring(0, 10),
                        style: const TextStyle(fontSize: 13)),
                  ]),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.black45))),
          ElevatedButton(
            onPressed: () {
              if ((activity ?? '').isNotEmpty) {
                setState(() => _reminders.add({
                      'activity': activity,
                      'date': Timestamp.fromDate(date),
                    }));
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kDarkGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  String _daysFromNow(int days) {
    final d = DateTime.now().add(Duration(days: days));
    return '${d.day}/${d.month}/${d.year}';
  }

  // ── Nav bar ───────────────────────────────────────────────────────────────

  Widget _buildNavBar() {
    final isLast = _currentStep == 2;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: FT.cardBg,
          border: Border(
              top: BorderSide(color: FT.borderDefault, width: 1.5)),
        ),
        child: Row(children: [
          if (_currentStep > 0) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _currentStep--),
                style: OutlinedButton.styleFrom(
                  foregroundColor: FT.brandDark,
                  side: BorderSide(color: FT.borderDefault, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Back',
                    style: FT.subheading
                        .copyWith(color: FT.brandDark)),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isSaving
                  ? null
                  : () {
                      if (isLast) {
                        _save();
                      } else {
                        setState(() => _currentStep++);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: FT.brandDark,
                foregroundColor: FT.textOnDark,
                disabledBackgroundColor: FT.borderDefault,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: FT.textOnDark))
                  : Text(
                      isLast
                          ? 'Save record'
                          : 'Next: ${_currentStep == 0 ? 'Soil & nutrients' : 'Confirm & save'}',
                      style: FT.subheading
                          .copyWith(color: FT.textOnDark)),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Shared UI helpers — outdoor-readable ─────────────────────────────────

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(label.toUpperCase(), style: FT.sectionLabel),
      );

  Widget _chip(String label, bool selected, VoidCallback onTap,
      {bool small = false}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: EdgeInsets.symmetric(
            horizontal: small ? 10 : 12,
            vertical: small ? 6 : 8),
        decoration: BoxDecoration(
          color: selected ? FT.brandMid : FT.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? FT.brandMid : FT.borderDefault,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: selected ? FT.chipSelected : FT.chipUnselected,
        ),
      ),
    );
  }

  Widget _chipSmall(String label, bool selected, VoidCallback onTap) =>
      _chip(label, selected, onTap, small: true);

  Widget _chipGroup(
      List<String> options, String selected, ValueChanged<String> onSelect) {
    return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options
            .map((o) => _chip(o, selected == o, () => onSelect(o)))
            .toList());
  }

  Widget _addButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 4, bottom: 8),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: FT.okBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: FT.okBorder, width: 1.5),
        ),
        child: Center(
          child: Text(label,
              style: FT.subheading.copyWith(color: FT.brandMid)),
        ),
      ),
    );
  }

  Widget _tipCard(String msg) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FT.infoBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FT.infoBorder, width: 1.5),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.lightbulb_outline,
            size: 18, color: FT.infoText),
        const SizedBox(width: 10),
        Expanded(
          child: Text(msg,
              style: FT.bodySmall.copyWith(color: FT.infoText)),
        ),
      ]),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'Low':     return FT.warnText;
      case 'High':    return FT.dangerText;
      case 'Optimal': return FT.okText;
      default:        return FT.textSecondary;
    }
  }

  Color _statusBg(String s) {
    switch (s) {
      case 'Low':     return FT.warnBg;
      case 'High':    return FT.dangerBg;
      case 'Optimal': return FT.okBg;
      default:        return FT.inputBg;
    }
  }

  Color _statusBorder(String s) {
    switch (s) {
      case 'Low':     return FT.warnBorder;
      case 'High':    return FT.dangerBorder;
      case 'Optimal': return FT.okBorder;
      default:        return FT.borderDefault;
    }
  }
}

// ── Subclass stubs ─────────────────────────────────────────────────────────

class _SingleCropFormState  extends _PlotInputFormState<SingleCropForm>  {}
class _MultiplePlotFormState extends _PlotInputFormState<MultiplePlotForm>{}
class _IntercropFormState    extends _PlotInputFormState<IntercropForm>   {
  @override
  void initState() {
    super.initState();
    _crops = [{'type': '', 'stage': ''}, {'type': '', 'stage': ''}];
  }
}