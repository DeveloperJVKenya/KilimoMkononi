// lib/screens/pest_management/pest_management.dart
//
// Architecture mirrors disease_management_page.dart + intervention_page.dart exactly...

// ignore_for_file: library_prefixes, unused_import, unused_field, invalid_return_type_for_catch_error, unnecessary_underscores, curly_braces_in_flow_control_structures, deprecated_member_use

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:timezone/data/latest.dart' as tzData;
import 'package:timezone/timezone.dart' as tz;
import 'dart:developer'; // for debugPrint

import 'package:kilimomkononi/models/pest_disease_model.dart';
import 'package:kilimomkononi/services/pest_disease_cost_bridge.dart';
import 'package:kilimomkononi/screens/pest%20management/user_pest_history_page.dart';
import 'package:kilimomkononi/screens/pest%20management/photo_diagnosis_page.dart';
import 'package:kilimomkononi/services/nasa_power_service.dart';
import 'package:kilimomkononi/services/iot_sensor_service.dart';
import 'package:kilimomkononi/screens/Field Data Input/satellite_data_screen.dart';
import 'package:kilimomkononi/services/offline_queue_service.dart';

// ── Auto-category inference (used by PestInterventionPage) ─────────────────
String inferCostCategory(String desc) {
  final d = desc.toLowerCase();
  if (d.contains('spray') || d.contains('pesticide') || d.contains('fungicide') ||
      d.contains('insecticide') || d.contains('chemical') || d.contains('ridomil') ||
      d.contains('dithane') || d.contains('mancozeb') || d.contains('karate') ||
      d.contains('spinosad') || d.contains('neem') || d.contains('bt') || d.contains('bacillus')) {
    return 'Pesticide / Herbicide';
  }
  if (d.contains('labour') || d.contains('worker') || d.contains('hired')) {
    return 'Labour';
  }
  if (d.contains('seed') || d.contains('seedling') || d.contains('planting')) {
    return 'Seeds & Planting Material';
  }
  return 'Miscellaneous';
}

// ── Shared theme (identical to intervention_page.dart _T) ────────────────────
class _T {
  static const pageBg      = Color(0xFFF0F2EF);
  static const cardBg      = Color(0xFFF7F8F6);
  static const inputBg     = Color(0xFFECEEEB);
  static const borderDef   = Color(0xFFBBBFBA);
  static const brandDark   = Color.fromARGB(255, 3, 39, 4);
  static const brandMid    = Color(0xFF1B5E20);
  static const brandLight  = Color(0xFF2E7D32);
  static const lightGreen  = Color(0xFFE8F5E9);
  static const textPrimary = Color(0xFF111A10);
  static const textSec     = Color(0xFF3D4A3C);
  static const textHint    = Color(0xFF5C6B5A);
  static const okBg        = Color(0xFFDFF2DF);
  static const okBorder    = Color(0xFF2E7D32);
  static const costBg      = Color(0xFFFFF3CD);
  static const costBorder  = Color(0xFFE6A817);
  static const costIcon    = Color(0xFFB97000);
  static const costText    = Color(0xFF7A4F00);
  static const aiGradA     = Color(0xFF0D2B0E);
  static const aiGradB     = Color(0xFF1B5E20);
  static const infoBg      = Color(0xFFDCEEFB);
  static const infoBorder  = Color(0xFF1565C0);
  static const infoText    = Color(0xFF0D3C7A);
  static const warnBg      = Color(0xFFFFF8E1);
  static const warnBorder  = Color(0xFFFFCC02);
  static const warnText    = Color(0xFF7A4F00);

  static BoxDecoration card({Color? border}) => BoxDecoration(
        color: cardBg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border ?? borderDef, width: 1.5));

  static InputDecoration field(String label, {String? hint}) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: textSec, fontWeight: FontWeight.w500),
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: textHint),
        filled: true, fillColor: inputBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: borderDef, width: 1.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: borderDef, width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: brandLight, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14));
}

const _kAskGeminiUrl = 'https://us-central1-kilimomkononi-e1031.cloudfunctions.net/askGeminiVision';
const _kNotifChannel  = 'pest_reminders_v2';
const _kNotifChanName = 'Pest Activity Reminders';

// ── Shared step-progress AppBar ──────────────────────────────────────────────
PreferredSizeWidget _stepHeader(String title, int current, int total) {
  return PreferredSize(
    preferredSize: const Size.fromHeight(kToolbarHeight + 52),
    child: AppBar(
      backgroundColor: _T.brandDark,
      foregroundColor: Colors.white,
      elevation: 0,
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: Container(
          color: _T.brandDark,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Step $current of $total', style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Row(
              children: List.generate(total, (i) => Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < total - 1 ? 4 : 0),
                  height: 4,
                  decoration: BoxDecoration(
                    color: i < current ? Colors.white : Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              )),
            ),
          ]),
        ),
      ),
    ),
  );
}

// ── AI response renderer — parses Gemini markdown into clean cards ────────────
// No raw *** or ** ever shown to the user.
List<Map<String, dynamic>> _parseAiSections(String raw) {
  final cleaned = raw
      .replaceAll(RegExp(r'\*{3,}'), '')
      .replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'\1')
      .replaceAll(RegExp(r'\*(.+?)\*'), r'\1')
      .trim();

  final sections = <Map<String, dynamic>>[];
  final lines = cleaned
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  String curTitle = '';
  final curItems  = <String>[];

  void flush() {
    if (curTitle.isNotEmpty || curItems.isNotEmpty) {
      sections.add({'title': curTitle, 'items': List<String>.from(curItems)});
      curTitle = '';
      curItems.clear();
    }
  }

  for (final line in lines) {
    final heading = RegExp(r'^(\d+)\.\s+(.+)$').firstMatch(line);
    if (heading != null) {
      flush();
      curTitle = heading.group(2)!;
      continue;
    }
    final bullet = RegExp(r'^[-•*]\s+(.+)$').firstMatch(line);
    curItems.add(bullet != null ? bullet.group(1)! : line);
  }
  flush();

  if (sections.isEmpty) sections.add({'title': '', 'items': [cleaned]});
  return sections;
}

Widget _buildAiSections(String raw) {
  const icons = [
    Icons.info_outline, Icons.science_outlined,
    Icons.eco_outlined, Icons.warning_amber_rounded, Icons.bolt,
  ];
  return Column(crossAxisAlignment: CrossAxisAlignment.start,
    children: _parseAiSections(raw).asMap().entries.map((e) {
      final title = e.value['title'] as String;
      final items = e.value['items'] as List<String>;
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (title.isNotEmpty) ...[
            Row(children: [
              Icon(icons[e.key % icons.length], color: Colors.white70, size: 15),
              const SizedBox(width: 6),
              Expanded(child: Text(title,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))),
            ]),
            if (items.isNotEmpty) const SizedBox(height: 8),
          ],
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('• ', style: TextStyle(color: Colors.white70, fontSize: 13)),
              Expanded(child: Text(item,
                  style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.55))),
            ]),
          )),
        ]),
      );
    }).toList(),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// PAGE 0 — Home / Entry point  (matches disease_management_page.dart structure)
// ═══════════════════════════════════════════════════════════════════════════════

class PestManagementPage extends StatefulWidget {
  final List<dynamic>? selectedSymptoms;
  const PestManagementPage({super.key, this.selectedSymptoms});

  @override
  State<PestManagementPage> createState() => _PestManagementPageState();
}

class _PestManagementPageState extends State<PestManagementPage> {
  // Selection state — shared across subpages via Navigator arguments
  String? _selectedCrop;
  String? _selectedStage;
  String? _selectedPest;
  PestData? _pestData;
  bool _isOrganic = false;
  Key _imageKey = UniqueKey();
  final FlutterLocalNotificationsPlugin _notifPlugin = FlutterLocalNotificationsPlugin();

  final List<String> _crops = [
    'Beans','Maize','Cabbages/Kales','Carrots','Tomatoes','Onions','Irish Potatoes'
  ];

  final Map<String, List<String>> _cropStages = {
    'Beans':          ['Germination/Seedling','Vegetative Growth/Weeding','Flowering/Reproductive','Maturation/Harvesting','Storage'],
    'Maize':          ['Germination/Seedling','Vegetative Growth/Weeding','Flowering/Reproductive','Maturation/Harvesting','Storage'],
    'Cabbages/Kales': ['Germination/Seedling','Vegetative Growth/Weeding','Flowering/Reproductive','Maturation/Harvesting','Storage'],
    'Carrots':        ['Germination/Seedling','Vegetative Growth/Weeding','Maturation/Harvesting','Storage'],
    'Tomatoes':       ['Germination/Seedling','Vegetative Growth/Weeding','Flowering/Reproductive','Maturation/Harvesting','Storage'],
    'Onions':         ['Germination/Seedling','Vegetative Growth/Weeding','Bulb Formation/Reproductive','Bulbing/Maturation','Harvesting/Storage'],
    'Irish Potatoes': ['Early Growth','Tuber Initiation','Tuber Bulking','Maturation/Harvesting'],
  };

  final Map<String, Map<String, List<String>>> _cropStagePests = {
    'Beans': {
      'Germination/Seedling':      ['Bean Fly','Cutworms','Rodents','Termites'],
      'Vegetative Growth/Weeding': ['Aphids','Leafhoppers','Thrips','Whiteflies','Beetles','Rodents'],
      'Flowering/Reproductive':    ['Aphids','Leafhoppers','Thrips','Pod Borers','Whiteflies'],
      'Maturation/Harvesting':     ['Pod Borers','Beetles','Bean Weevil','Bruchid Beetles','Rodents'],
      'Storage':                   ['Bean Weevil','Bruchid Beetles','Rodents'],
    },
    'Maize': {
      'Germination/Seedling':      ['Termites','Cutworms','Maize Shoot Fly','Rodents'],
      'Vegetative Growth/Weeding': ['Aphids','Stem Borers','Armyworms','Leafhoppers','Grasshoppers','Thrips','Rodents'],
      'Flowering/Reproductive':    ['Aphids','Stem Borers','Armyworms','Leafhoppers','Grasshoppers','Earworms','Thrips','Birds'],
      'Maturation/Harvesting':     ['Earworms','Weevils','Birds','Rodents'],
      'Storage':                   ['Larger Grain Borer','Angoumois Grain Moth','Weevils','Rodents'],
    },
    'Cabbages/Kales': {
      'Germination/Seedling':      ['Termites','Cutworms','Root Maggots','Flea Beetles'],
      'Vegetative Growth/Weeding': ['Aphids','Whiteflies','Diamondback Moth','Cabbage Looper','Cutworms','Flea Beetles','Armyworms','Rodents'],
      'Flowering/Reproductive':    ['Aphids','Whiteflies','Thrips','Diamondback Moth','Stink Bug'],
      'Maturation/Harvesting':     ['Diamondback Moth','Cabbage Looper','Leafminers','Stink Bug','Rodents'],
      'Storage':                   ['Rodents','Aphids'],
    },
    'Carrots': {
      'Germination/Seedling':      ['Termites','Cutworms','Nematodes','Wireworms','Rodents'],
      'Vegetative Growth/Weeding': ['Aphids','Whiteflies','Thrips','Leafminers','Carrot Rust Fly','Nematodes','Armyworms','Rodents'],
      'Maturation/Harvesting':     ['Aphids','Thrips','Carrot Rust Fly','Nematodes','Wireworms','Rodents'],
      'Storage':                   ['Carrot Rust Fly','Nematodes','Rodents'],
    },
    'Tomatoes': {
      'Germination/Seedling':      ['Cutworms','Termites','Rodents','Nematodes'],
      'Vegetative Growth/Weeding': ['Aphids','Whiteflies','Thrips','Leafminers','Spider Mites','Nematodes','Rodents'],
      'Flowering/Reproductive':    ['Aphids','Whiteflies','Thrips','Spider Mites','Stink Bugs','Fruit Borers','Bollworms','Nematodes','Rodents'],
      'Maturation/Harvesting':     ['Fruitflies','Stink Bugs','Rodents','Fruit Borers','Bollworms','Leafminers','Spider Mites','Nematodes'],
      'Storage':                   ['Fruit Flies','Stink Bugs','Rodents'],
    },
    'Onions': {
      'Germination/Seedling':      ['Aphids','Thrips'],
      'Vegetative Growth/Weeding': ['Thrips','Aphids'],
      'Bulb Formation/Reproductive':['Bulb Fly','Maggots'],
      'Bulbing/Maturation':        ['Maggots','Thrips','Bulb Fly'],
      'Harvesting/Storage':        ['Maggots','Rodents','Bulb Fly'],
    },
    'Irish Potatoes': {
      'Early Growth':           ['Wireworms','Cutworms'],
      'Tuber Initiation':       ['Colorado Potato Beetle','Aphids','Spider Mites'],
      'Tuber Bulking':          ['Aphids','Leaf Hoppers','Flea Beetles','Spider Mites'],
      'Maturation/Harvesting':  ['Colorado Potato Beetle','Aphids','Wireworms','Cutworms','Spider Mites'],
    },
  };

  @override
  void initState() {
    super.initState();
    _initNotif();
    if (widget.selectedSymptoms != null && widget.selectedSymptoms!.isNotEmpty) {
      final f = widget.selectedSymptoms!.first as dynamic;
      _selectedCrop  = f.crop  as String?;
      _selectedStage = f.stage as String?;
      _selectedPest  = f.identity as String?;
      WidgetsBinding.instance.addPostFrameCallback((_) => _updatePestDetails());
    }
  }

     Future<void> _initNotif() async {
    try {
      // Initialize timezone data
      tzData.initializeTimeZones();

      // FIXED: flutter_timezone may return a TimezoneInfo object or a String.
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      String tzName;
      try {
        // Try common property that newer versions may expose
        tzName = (timezoneInfo as dynamic).name as String;
      } catch (_) {
        // Fallback to string representation
        tzName = timezoneInfo.toString();
      }
      tz.setLocalLocation(tz.getLocation(tzName));

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings = InitializationSettings(
        android: android,
        iOS: darwin,
        macOS: darwin,
      );

      await _notifPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (details) {},
      );

      // Request permission (Android 13+)
      await _notifPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('Notification init error: $e');
    }
  }

  Future<void> _updatePestDetails() async {
    if (_selectedCrop == null || _selectedStage == null || _selectedPest == null) {
      setState(() { _pestData = null; _imageKey = UniqueKey(); });
      return;
    }
    final key = '${_selectedCrop}_${_selectedStage}_$_selectedPest';
    final det = _kPestDetails[key];
    setState(() {
      _pestData = det != null ? PestData(
        name: _selectedPest!,
        imagePath: det['imagePath'] ?? 'assets/pests/default.jpg',
        preventionStrategies: List<String>.from(det['preventionStrategies'] ?? []),
        activeAgent: det['activeAgent'] ?? '',
        possibleCauses: List<String>.from(det['possibleCauses'] ?? []),
        herbicides: List<String>.from(det['herbicidesPesticides'] ?? det['pesticides'] ?? []),
        organicInterventions: List<String>.from(det['organicInterventions'] ?? []),
      ) : null;
      _imageKey = UniqueKey();
    });
  }

  String _progressText() {
    if (_selectedPest == null) return 'Step 1 of 3 — Select crop and pest';
    return 'Step 2 of 3 — ${_selectedPest!}';
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.pageBg,
      appBar: AppBar(
        title: const Text('Pest Management', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: _T.brandDark,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Container(
            color: _T.brandDark,
            padding: const EdgeInsets.only(left: 16, bottom: 10),
            alignment: Alignment.centerLeft,
            child: Text(_progressText(), style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.history_rounded), tooltip: 'History',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserPestHistoryPage()))),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // AI Photo Diagnosis entry card (same as disease section)
          Card(
            color: _T.lightGreen,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PhotoDiagnosisPage(issueType: 'pest'))),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: _T.brandDark, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('AI Photo Diagnosis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _T.brandDark)),
                    SizedBox(height: 2),
                    Text('Take a photo — AI identifies pest instantly', style: TextStyle(fontSize: 12, color: Colors.black54)),
                  ])),
                  const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.black38),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Step tiles (navigate to subpages)
          _stepTile(
            step: 0,
            title: 'Select Crop, Stage & Pest',
            badge: _selectedPest != null ? '${_selectedCrop ?? ''} · ${_selectedStage ?? ''} · $_selectedPest' : null,
            isComplete: _selectedPest != null,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => _PestStep0Page(
                crops: _crops,
                cropStages: _cropStages,
                cropStagePests: _cropStagePests,
                selectedCrop: _selectedCrop,
                selectedStage: _selectedStage,
                selectedPest: _selectedPest,
                isOrganic: _isOrganic,
                onSaved: (crop, stage, pest, organic) {
                  setState(() {
                    _selectedCrop  = crop;
                    _selectedStage = stage;
                    _selectedPest  = pest;
                    _isOrganic     = organic;
                  });
                  _updatePestDetails();
                },
              )),
            ),
          ),

          _stepTile(
            step: 1,
            title: 'Pest Information & Hints',
            badge: _pestData != null ? 'Reviewed' : null,
            isComplete: _pestData != null,
            onTap: _selectedPest != null ? () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => _PestStep1Page(
                pestData: _pestData,
                selectedPest: _selectedPest,
                selectedCrop: _selectedCrop,
                selectedStage: _selectedStage,
                isOrganic: _isOrganic,
                imageKey: _imageKey,
              )),
            ) : null,
          ),

          _stepTile(
            step: 2,
            title: 'Log Intervention & Save',
            badge: null,
            isComplete: false,
            onTap: (_selectedPest != null && _pestData != null) ? () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PestInterventionPage(
                pestData: _pestData!,
                cropType: _selectedCrop!,
                cropStage: _selectedStage!,
                notificationsPlugin: _notifPlugin,
              )),
            ) : null,
          ),

          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserPestHistoryPage())),
            icon: const Icon(Icons.history_rounded, size: 16),
            label: const Text('View All Pest Interventions'),
            style: TextButton.styleFrom(foregroundColor: _T.brandMid),
          ),
        ],
      ),
    );
  }

  Widget _stepTile({required int step, required String title, String? badge, required bool isComplete, VoidCallback? onTap}) {
    final enabled = onTap != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _T.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isComplete ? _T.okBorder : _T.borderDef, width: isComplete ? 2 : 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: isComplete ? _T.brandMid : (enabled ? _T.brandDark : Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(child: isComplete
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : Text('${step + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: enabled ? _T.textPrimary : Colors.grey.shade400)),
              if (badge != null && badge.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(badge.length > 36 ? '${badge.substring(0, 36)}…' : badge,
                    style: const TextStyle(fontSize: 11, color: _T.brandMid)),
              ],
            ])),
            Icon(Icons.chevron_right, color: enabled ? _T.textHint : Colors.grey.shade300, size: 20),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PAGE 1 — Select Crop, Stage & Pest  (subpage)
// ═══════════════════════════════════════════════════════════════════════════════

class _PestStep0Page extends StatefulWidget {
  final List<String> crops;
  final Map<String, List<String>> cropStages;
  final Map<String, Map<String, List<String>>> cropStagePests;
  final String? selectedCrop;
  final String? selectedStage;
  final String? selectedPest;
  final bool isOrganic;
  final void Function(String? crop, String? stage, String? pest, bool organic) onSaved;

  const _PestStep0Page({
    required this.crops, required this.cropStages, required this.cropStagePests,
    this.selectedCrop, this.selectedStage, this.selectedPest, required this.isOrganic,
    required this.onSaved,
  });

  @override
  State<_PestStep0Page> createState() => _PestStep0PageState();
}

class _PestStep0PageState extends State<_PestStep0Page> {
  late String? _crop;
  late String? _stage;
  late String? _pest;
  late bool    _organic;

  @override
  void initState() {
    super.initState();
    _crop    = widget.selectedCrop;
    _stage   = widget.selectedStage;
    _pest    = widget.selectedPest;
    _organic = widget.isOrganic;
  }

  @override
  Widget build(BuildContext context) {
    final pests = widget.cropStagePests[_crop]?[_stage] ?? [];

    return Scaffold(
      backgroundColor: _T.pageBg,
      appBar: _stepHeader('Select Crop, Stage & Pest', 1, 3),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Crop
          _lbl('SELECT CROP'),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8,
            children: widget.crops.map((c) => _chip(c, c == _crop, () {
              setState(() { _crop = _crop == c ? null : c; _stage = null; _pest = null; });
            })).toList(),
          ),

          // Stage
          if (_crop != null) ...[
            const SizedBox(height: 18),
            _lbl('SELECT GROWTH STAGE'),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8,
              children: (widget.cropStages[_crop] ?? []).map((s) => _chip(s, s == _stage, () {
                setState(() { _stage = _stage == s ? null : s; _pest = null; });
              })).toList(),
            ),
          ],

          // Pest
          if (_crop != null && _stage != null) ...[
            const SizedBox(height: 18),
            _lbl('SELECT PEST'),
            const SizedBox(height: 10),
            pests.isEmpty
                ? Text('No pests recorded for this crop & stage', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))
                : Wrap(spacing: 8, runSpacing: 8,
                    children: pests.map((p) => _chip(p, p == _pest, () {
                      setState(() => _pest = _pest == p ? null : p);
                    })).toList(),
                  ),
          ],

          // Organic toggle
          const SizedBox(height: 18),
          Row(children: [
            Switch(value: _organic, onChanged: (v) => setState(() => _organic = v),
                activeColor: _T.brandLight, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
            const SizedBox(width: 8),
            const Expanded(child: Text('Show organic interventions only', style: TextStyle(fontSize: 13, color: _T.textPrimary))),
          ]),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_crop != null && _stage != null && _pest != null) ? () {
                widget.onSaved(_crop, _stage, _pest, _organic);
                Navigator.pop(context);
              } : null,
              style: ElevatedButton.styleFrom(
                  backgroundColor: _T.brandDark, foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Next: View Pest Info', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool sel, VoidCallback onTap) => FilterChip(
    label: Text(label), selected: sel, onSelected: (_) => onTap(),
    backgroundColor: Colors.white, selectedColor: _T.lightGreen,
    labelStyle: TextStyle(color: sel ? _T.brandLight : Colors.black54, fontWeight: sel ? FontWeight.w600 : FontWeight.normal),
    side: BorderSide(color: sel ? _T.brandLight : Colors.grey.shade300),
  );

  Widget _lbl(String t) => Text(t, style: const TextStyle(fontSize: 10, color: _T.textHint, fontWeight: FontWeight.w700, letterSpacing: 0.8));
}

// ═══════════════════════════════════════════════════════════════════════════════
// PAGE 2 — Pest Information, Manual Hints + AI Advisor + AI Photo  (subpage)
// ═══════════════════════════════════════════════════════════════════════════════

class _PestStep1Page extends StatefulWidget {
  final PestData? pestData;
  final String? selectedPest;
  final String? selectedCrop;
  final String? selectedStage;
  final bool isOrganic;
  final Key imageKey;

  const _PestStep1Page({
    required this.pestData,
    this.selectedPest,
    this.selectedCrop,
    this.selectedStage,
    required this.isOrganic,
    required this.imageKey,
  });

  @override
  State<_PestStep1Page> createState() => _PestStep1PageState();
}

class _PestStep1PageState extends State<_PestStep1Page> {
  // ── Live condition data ────────────────────────────────────────────────────
  SatelliteReading? _sat;
  IotSensorReading? _iot;
  double _rain7d = 0;
  bool _condLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConditions();
  }

  Future<void> _loadConditions() async {
    try {
      final results = await Future.wait([
        NasaPowerService.getToday(),
        NasaPowerService.getHistory(days: 7),
        IotSensorService.getReadingForFarm().catchError((_) => null),
      ]);
      if (!mounted) return;
      final sat     = results[0] as SatelliteReading?;
      final history = results[1] as List<SatelliteReading>;
      final iot     = results[2] as IotSensorReading?;
      setState(() {
        _sat         = sat;
        _iot         = iot;
        _rain7d      = SatelliteReading.totalPrecipitation(history);
        _condLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _condLoading = false);
    }
  }

  /// Maps the pest/disease name to the subset of risks that are relevant.
  List<ConditionRiskType> _relevantRisks(String? name) {
    if (name == null) return [ConditionRiskType.spray];
    final n = name.toLowerCase();

    final isDryWeather = _anyOf(n, [
      'spider mite', 'aphid', 'thrip', 'whitefly', 'flea beetle',
      'cutworm', 'leafhopper', 'leaf hopper', 'wireworm', 'armyworm',
    ]);
    final isWetWeather = _anyOf(n, [
      'pythium', 'damping', 'fusarium', 'rhizoctonia', 'root rot',
      'soft rot', 'bacterial', 'blight', 'mold', 'mould', 'downy',
      'rust', 'botrytis', 'sclerotinia', 'web blight', 'anthracnose',
    ]);
    final isFungal = _anyOf(n, [
      'pythium', 'fusarium', 'rhizoctonia', 'damping', 'rust', 'blight',
      'mold', 'mould', 'mildew', 'anthracnose', 'botrytis', 'sclerotinia',
      'alternaria', 'cercospora', 'gray leaf', 'grey mold',
    ]);

    final risks = <ConditionRiskType>[ConditionRiskType.spray];
    if (isFungal || isWetWeather) risks.add(ConditionRiskType.fungal);
    if (isDryWeather)              risks.add(ConditionRiskType.drought);
    if (isWetWeather)              risks.add(ConditionRiskType.flood);
    return risks;
  }

  bool _anyOf(String haystack, List<String> needles) =>
      needles.any((n) => haystack.contains(n));

  @override
  Widget build(BuildContext context) {
    final d    = widget.pestData;
    final name = widget.selectedPest;

    return Scaffold(
      backgroundColor: _T.pageBg,
      appBar: _stepHeader('Pest Information & Hints', 2, 3),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── Live conditions banner ─────────────────────────────────────────
          if (!_condLoading && (_sat != null || _iot != null))
            ConditionRiskBanner(
              sat:            _sat,
              iot:            _iot,
              rain7d:         _rain7d,
              relevantRisks:  _relevantRisks(name ?? d?.name),
            ),

          // ── Pest image ─────────────────────────────────────────────────────
          if (d != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                d.imagePath,
                key: widget.imageKey,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: _T.lightGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(Icons.bug_report_outlined, size: 52, color: _T.brandMid),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(d.name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                    color: _T.brandMid)),
            const SizedBox(height: 4),
            Text('${widget.selectedCrop} · ${widget.selectedStage}',
                style: const TextStyle(fontSize: 13, color: _T.textSec)),
            const SizedBox(height: 14),

            // ── Contextual condition note (inline, under title) ───────────
            if (!_condLoading && _sat != null)
              _buildContextNote(name ?? d.name),

            if (d.possibleCauses.isNotEmpty)
              _hintCard('Possible Causes', d.possibleCauses.join('\n')),
            if (d.preventionStrategies.isNotEmpty) ...[
              const SizedBox(height: 10),
              _hintCard('Prevention Strategies', d.preventionStrategies.join('\n')),
            ],
            if (!widget.isOrganic && d.herbicides.isNotEmpty) ...[
              const SizedBox(height: 10),
              _hintCard('Pesticides / Herbicides', d.herbicides.join('\n')),
            ],
            if (d.organicInterventions.isNotEmpty) ...[
              const SizedBox(height: 10),
              _hintCard('Organic Interventions', d.organicInterventions.join('\n')),
            ],
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _T.card(),
              child: Text(
                '${name ?? "This pest"} was not found in the library. '
                'Continue to Step 3 to get AI-powered advice.',
                style: const TextStyle(fontSize: 13, color: _T.textSec, height: 1.5),
              ),
            ),
          ],
          const SizedBox(height: 16),

          // ── AI teaser banner ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [_T.aiGradA, _T.aiGradB],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _T.brandLight, width: 1.5),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('AI Advice in Next Step',
                      style: TextStyle(color: Colors.white, fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  SizedBox(height: 3),
                  Text(
                    'Step 3 has the AI Pest Advisor — get product names, dosages '
                    'and tap to fill the form automatically.',
                    style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
                ]),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
            ]),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _T.brandDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Back to Pest Selection',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Contextual one-liner note under pest title ────────────────────────────
  //
  // Shows one relevant sentence about today's conditions as it relates to
  // this specific pest. This is intentionally brief — the full detail is
  // in the ConditionRiskBanner chips above.

  // ── Rich contextual condition card under pest name ─────────────────────────
  //
  // Shows a full breakdown of live satellite + IoT data as it relates to THIS
  // specific pest. All data visible inline — no tap or tooltip needed.

  Widget _buildContextNote(String pestName) {
    if (_sat == null && _iot == null) return const SizedBox.shrink();

    final risk = computeConditionRisk(sat: _sat, iot: _iot, rain7d: _rain7d);
    final n    = pestName.toLowerCase();

    final isDryPest = _anyOf(n, ['spider mite', 'aphid', 'thrip', 'whitefly',
        'flea beetle', 'leafhopper', 'leaf hopper', 'mite', 'wireworm']);
    final isFungalPest = _anyOf(n, ['blight', 'mildew', 'mold', 'mould', 'rust',
        'pythium', 'fusarium', 'anthracnose', 'botrytis', 'damping', 'rot']);
    final isWetPest = _anyOf(n, ['slug', 'root fly', 'root maggot',
        'fungus gnat', 'cutworm', 'armyworm']);

    String title;
    Color  cardColor;
    IconData cardIcon;
    List<String> bullets;

    if (isDryPest) {
      final airTempMax = _sat?.airTempMax ?? 0;
      final humidity   = _sat?.humidity ?? _iot?.humidity ?? 0;

      if (risk.droughtRisk == ConditionRisk.critical || risk.droughtRisk == ConditionRisk.high) {
        title     = '⚠ Hot, dry conditions are actively favouring $pestName';
        cardColor = const Color(0xFFBF360C);
        cardIcon  = Icons.wb_sunny_outlined;
      } else if (airTempMax > 28) {
        title     = 'Warm conditions — monitor for $pestName';
        cardColor = const Color(0xFFE65100);
        cardIcon  = Icons.wb_sunny_outlined;
      } else {
        title     = 'Conditions not strongly favouring $pestName today';
        cardColor = _T.brandMid;
        cardIcon  = Icons.check_circle_outline_rounded;
      }

      bullets = [
        'Max air temperature: ${airTempMax.toStringAsFixed(1)}°C'
            '${airTempMax > 32 ? '  ⚠ High heat — pest populations build quickly' : airTempMax > 28 ? '  — warm, monitor closely' : '  ✓ Acceptable'}',
        'Humidity: ${humidity.toStringAsFixed(0)}%'
            '${humidity < 35 ? '  ⚠ Very dry — ${isDryPest ? 'ideal for mites and aphids' : 'stress conditions'}' : humidity < 50 ? '  — dry, favours dry-weather pests' : '  ✓ Not particularly dry'}',
        'Rain last 7 days: ${_rain7d.toStringAsFixed(1)} mm'
            '${_rain7d < 5 ? '  — very dry week, pest pressure likely elevated' : ''}',
        if (_sat != null)
          'Root zone moisture: ${(_sat!.rootZoneMoisture * 100).toStringAsFixed(0)}%'
          '${_sat!.rootZoneMoisture < 0.25 ? '  ⚠ Drought stress — weakens plant defences' : ''}',
        if (risk.droughtRisk == ConditionRisk.high || risk.droughtRisk == ConditionRisk.critical)
          'Recommended action: Increase scouting frequency. Check undersides of leaves.',
        if (risk.droughtRisk == ConditionRisk.low && airTempMax <= 28)
          'Current conditions do not strongly favour this pest.',
      ];

    } else if (isFungalPest) {
      final humidity   = _sat?.humidity ?? _iot?.humidity ?? 0;
      final dewDiff    = _sat != null ? (_sat!.airTemp - _sat!.dewPoint).abs() : 99.0;
      final cloudCover = _sat?.cloudCover ?? 0;
      final airTemp    = _sat?.airTemp ?? 0;

      if (risk.fungalRisk == ConditionRisk.critical) {
        title     = '⚠ Conditions are ideal for $pestName today';
        cardColor = const Color(0xFFB71C1C);
        cardIcon  = Icons.grain_rounded;
      } else if (risk.fungalRisk == ConditionRisk.high) {
        title     = 'High risk conditions for $pestName';
        cardColor = const Color(0xFFBF360C);
        cardIcon  = Icons.grain_rounded;
      } else if (risk.fungalRisk == ConditionRisk.moderate) {
        title     = 'Moderate conditions — monitor for $pestName';
        cardColor = const Color(0xFFE65100);
        cardIcon  = Icons.grain_rounded;
      } else {
        title     = 'Low fungal pressure today';
        cardColor = _T.brandMid;
        cardIcon  = Icons.check_circle_outline_rounded;
      }

      bullets = [
        'Humidity: ${humidity.toStringAsFixed(0)}%'
            '${humidity > 80 ? '  ⚠ Above 80% — disease-conducive' : humidity > 70 ? '  — elevated' : '  ✓ Acceptable'}',
        if (_sat != null)
          'Temperature: ${airTemp.toStringAsFixed(1)}°C'
          '${(airTemp > 18 && airTemp < 30) ? '  ⚠ In fungal growth range (18–30°C)' : '  ✓ Outside main fungal range'}',
        if (_sat != null)
          'Dew point gap: ${dewDiff.toStringAsFixed(1)}°C'
          '${dewDiff < 4 ? '  ⚠ Leaves likely wet overnight — spores germinate easily' : dewDiff < 8 ? '  — some leaf wetness risk' : '  ✓ Leaves likely dry at night'}',
        if (_sat != null && cloudCover > 0)
          'Cloud cover: ${cloudCover.toStringAsFixed(0)}%'
          '${cloudCover > 65 ? '  — overcast, slows leaf drying' : '  ✓ Adequate sun'}',
        if (risk.fungalRisk == ConditionRisk.critical || risk.fungalRisk == ConditionRisk.high)
          'Recommended action: Scout crops now. Consider preventive fungicide before next rain.',
      ];

    } else if (isWetPest) {
      final soilMoisture  = _sat?.rootZoneMoisture ?? 0;
      final precipitation = _sat?.precipitation ?? 0;

      if (risk.floodRisk == ConditionRisk.high || risk.floodRisk == ConditionRisk.critical) {
        title     = '⚠ Wet soil conditions favour $pestName activity';
        cardColor = const Color(0xFF0D47A1);
        cardIcon  = Icons.water_rounded;
      } else {
        title     = 'Soil moisture within normal range';
        cardColor = _T.brandMid;
        cardIcon  = Icons.water_drop_outlined;
      }

      bullets = [
        if (_sat != null)
          'Root zone moisture: ${(soilMoisture * 100).toStringAsFixed(0)}%'
          '${soilMoisture > 0.75 ? '  ⚠ Wet — favours soil pest activity' : '  ✓ Acceptable'}',
        if (_sat != null)
          'Rain today: ${precipitation.toStringAsFixed(1)} mm'
          '${precipitation > 15 ? '  — significant rain, check for pest movement' : ''}',
        'Rain last 7 days: ${_rain7d.toStringAsFixed(1)} mm',
      ];

    } else {
      // No specific match — show spray window summary only
      return const SizedBox.shrink();
    }

    final bgColor     = cardColor.withOpacity(0.07);
    final borderColor = cardColor.withOpacity(0.22);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(cardIcon, size: 14, color: cardColor),
            const SizedBox(width: 7),
            Expanded(
              child: Text(title,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: cardColor, height: 1.3)),
            ),
          ]),
          const SizedBox(height: 8),
          ...bullets.where((b) => b.trim().isNotEmpty).map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('• ',
                    style: TextStyle(fontSize: 12.5,
                        color: cardColor.withOpacity(0.6), height: 1.45)),
                Expanded(
                  child: Text(b,
                      style: TextStyle(fontSize: 12.5,
                          color: cardColor.withOpacity(0.85), height: 1.45)),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hintCard(String title, String content) => Card(
    color: _T.cardBg,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                color: _T.textPrimary)),
        const SizedBox(height: 8),
        Text(content,
            style: const TextStyle(fontSize: 13, color: _T.textSec, height: 1.5)),
      ]),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// PAGE 3 — Pest Intervention + Plot + Cost + Reminders  (full subpage)
// Mirrors disease InterventionPage exactly — same _T theme, same layout
// ═══════════════════════════════════════════════════════════════════════════════

class PestInterventionPage extends StatefulWidget {
  final PestData pestData;
  final String cropType;
  final String cropStage;
  final FlutterLocalNotificationsPlugin notificationsPlugin;

  const PestInterventionPage({
    required this.pestData,
    required this.cropType,
    required this.cropStage,
    required this.notificationsPlugin,
    super.key,
  });

  @override
  State<PestInterventionPage> createState() => _PestInterventionPageState();
}

class _PestInterventionPageState extends State<PestInterventionPage> {
  final _interventionCtrl = TextEditingController();
  final _dosageCtrl       = TextEditingController();
  final _unitCtrl         = TextEditingController();
  final _areaCtrl         = TextEditingController();
  final _costCtrl         = TextEditingController();
  final _customReminderCtrl = TextEditingController();
  String _areaUnit        = 'Acres';
  bool   _saveToCosts     = true;
  String _costCategory    = 'Pesticide / Herbicide';

  // Plot — default null so user must explicitly choose their plot
  List<Map<String, String>> _farmPlots    = [];
  String?                   _selectedPlotId; // null = "General / no specific plot"
  bool                      _plotsLoading = false;

  // AI Advisor (same as disease InterventionPage)
  bool   _aiLoading  = false;
  String? _aiAdvice;
  List<Map<String, dynamic>> _aiSuggestions = [];

  // Reminders — system-suggested + custom
  bool     _followUp            = true;
  DateTime _reminderDate        = DateTime.now().add(const Duration(days: 7));
  bool     _addSprayReminder    = false;
  bool     _addWeedReminder     = false;
  bool     _addScoutReminder    = true;
  bool     _addCustomReminder   = false;
  DateTime _sprayDate   = DateTime.now().add(const Duration(days: 14));
  DateTime _weedDate    = DateTime.now().add(const Duration(days: 7));
  DateTime _scoutDate   = DateTime.now().add(const Duration(days: 7));
  DateTime _customDate  = DateTime.now().add(const Duration(days: 3));
  bool _tzReady = false;
  bool _saving  = false;

  @override
  void initState() {
    super.initState();
    _initTz();
    _loadPlots();
    _interventionCtrl.addListener(() => setState(() => _costCategory = inferCostCategory(_interventionCtrl.text)));
  }

  @override
  void dispose() {
    for (final c in [_interventionCtrl, _dosageCtrl, _unitCtrl, _areaCtrl, _costCtrl, _customReminderCtrl]) c.dispose();
    super.dispose();
  }

  Future<void> _initTz() async {
    if (_tzReady) return;
    try {
      tzData.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation((await FlutterTimezone.getLocalTimezone()) as String));
      _tzReady = true;
    } catch (_) {}
  }

  Future<void> _loadPlots() async {
    setState(() => _plotsLoading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final plots = await PestCostService.loadFarmPlots(uid);
        if (mounted) setState(() {
          _farmPlots = plots;
          _selectedPlotId = null; // ← FIX: default null, user must choose
        });
      }
    } finally {
      if (mounted) setState(() => _plotsLoading = false);
    }
  }

  // AI advisor — same as disease InterventionPage
  Future<void> _fetchAiAdvice() async {
    setState(() { _aiLoading = true; _aiAdvice = null; _aiSuggestions = []; });

    final prompt = '''
You are an agronomist advising smallholder farmers in Kenya and East Africa.

Pest: ${widget.pestData.name}
Crop: ${widget.cropType}  |  Stage: ${widget.cropStage}
Known pesticides: ${widget.pestData.herbicides.join(', ')}
Known organic options: ${widget.pestData.organicInterventions.join(', ')}

Provide:
1. Brief description of how this pest damages the crop at this stage (2 sentences).
2. Up to 3 specific pesticide interventions sold in Kenya — product name, active ingredient, dosage per litre/per acre, timing and method.
3. One organic alternative per chemical.
4. Critical warnings (pre-harvest intervals, resistance rotation, no spray in rain).
5. Single most urgent action today.

Plain English, under 220 words, numbered lists only.

Then on a new line:
INTERVENTIONS_JSON:
[{"type":"Spray Karate 2.5 EC","quantity":2.0,"unit":"ml/L","category":"Pesticide / Herbicide"}]
If none: INTERVENTIONS_JSON: []
''';

    try {
      final resp = await http.post(Uri.parse(_kAskGeminiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'prompt': prompt}),
      ).timeout(const Duration(seconds: 35));

      if (resp.statusCode == 200) {
        final raw = (jsonDecode(resp.body)['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?) ?? '';
        final idx = raw.indexOf('INTERVENTIONS_JSON:');
        final advice = idx >= 0 ? raw.substring(0, idx).trim() : raw.trim();
        List<Map<String, dynamic>> parsed = [];
        if (idx >= 0) {
          try { parsed = (jsonDecode(raw.substring(idx + 18).trim()) as List).map((e) => Map<String, dynamic>.from(e)).toList(); } catch (_) {}
        }
        if (mounted) setState(() { _aiAdvice = advice.isNotEmpty ? advice : 'No advice returned. Try again.'; _aiSuggestions = parsed; _aiLoading = false; });
      } else {
        if (mounted) setState(() { _aiAdvice = 'AI error (${resp.statusCode}). Try again.'; _aiLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _aiAdvice = e.toString().contains('Timeout') ? 'Request timed out. Check connection.' : 'AI unavailable offline.'; _aiLoading = false; });
    }
  }

  void _acceptSuggestion(Map<String, dynamic> s) {
    setState(() {
      _interventionCtrl.text = s['type'] as String? ?? '';
      if (s['quantity'] != null) { _dosageCtrl.text = (s['quantity'] as num).toStringAsFixed(1); _unitCtrl.text = s['unit'] as String? ?? ''; }
      _costCategory = s['category'] as String? ?? 'Pesticide / Herbicide';
    });
  }

  // Save
  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    final msg  = ScaffoldMessenger.of(context);
    if (user == null) { msg.showSnackBar(const SnackBar(content: Text('Please log in'))); return; }
    if (_interventionCtrl.text.isEmpty && _dosageCtrl.text.isEmpty && _unitCtrl.text.isEmpty && _areaCtrl.text.isEmpty) {
      msg.showSnackBar(const SnackBar(content: Text('Please fill at least one field'))); return;
    }

    setState(() => _saving = true);
    final now    = Timestamp.now();
    final dosage = _dosageCtrl.text.isNotEmpty ? double.tryParse(_dosageCtrl.text) : null;

    try {
      // 1. Pest intervention record
      final record = PestIntervention(
        pestName: widget.pestData.name,
        cropType: widget.cropType,
        cropStage: widget.cropStage,
        plotId: _selectedPlotId,
        intervention: _interventionCtrl.text,
        dosage: dosage,
        unit: _unitCtrl.text.isNotEmpty ? _unitCtrl.text : null,
        area: _areaCtrl.text.isNotEmpty ? double.tryParse(_areaCtrl.text) : null,
        areaUnit: _areaUnit,
        cost: double.tryParse(_costCtrl.text),
        timestamp: now,
        userId: user.uid,
        isDeleted: false,
      );

      bool savedOnline = false;
      try {
        await FirebaseFirestore.instance.collection('pestinterventiondata').add(record.toMap());
        savedOnline = true;
      } catch (_) {
        // Offline — queue the record
        final queueId = 'pest_${user.uid}_${now.millisecondsSinceEpoch}';
        await OfflineQueueService.enqueue(
          id:         queueId,
          collection: 'pestinterventiondata',
          payload:    record.toMap(),
        );
      }

      // 2. Cost → pest_costs
      final cost = double.tryParse(_costCtrl.text) ?? 0.0;
      if (cost > 0 && _saveToCosts) {
        final plotName = _selectedPlotId != null
            ? (_farmPlots.where((p) => p['id'] == _selectedPlotId).firstOrNull?['name'] ?? _selectedPlotId!)
            : 'General';
        final costEntry = PestCostEntry(
          id: '${user.uid}_pest_${now.millisecondsSinceEpoch}',
          userId: user.uid,
          plotId: _selectedPlotId ?? 'general',
          description: '${_interventionCtrl.text} — ${widget.pestData.name} (${widget.cropType}) · $plotName',
          category: _costCategory,
          amount: cost,
          date: now.toDate(),
          source: 'pest_management',
          pestName: widget.pestData.name,
          interventionType: 'pest',
        );
        try {
          await PestCostService.saveFromPest(costEntry);
        } catch (_) {
          await OfflineQueueService.enqueue(
            id:         'pestcost_${user.uid}_${now.millisecondsSinceEpoch}',
            collection: 'pest_costs',
            payload:    costEntry.toMap(),
          );
        }
      }

      // 3. Reminders — schedule locally regardless of connectivity
      if (_followUp)           await _scheduleReminder('followup_${now.millisecondsSinceEpoch}', 'Follow-up: ${widget.pestData.name}', 'Evaluate treatment on ${widget.cropType}.', _reminderDate, user.uid);
      if (_addSprayReminder)   await _scheduleReminder('spray_${now.millisecondsSinceEpoch}', 'Re-spray — ${widget.cropType}', 'Time to re-apply ${_interventionCtrl.text} for ${widget.pestData.name}.', _sprayDate, user.uid);
      if (_addWeedReminder)    await _scheduleReminder('weed_${now.millisecondsSinceEpoch}', 'Weeding — ${widget.cropType}', 'Weeds harbour pests — time to weed your plot.', _weedDate, user.uid);
      if (_addScoutReminder)   await _scheduleReminder('scout_${now.millisecondsSinceEpoch}', 'Scouting — ${widget.cropType}', 'Check for ${widget.pestData.name} re-infestation. Early detection saves crops.', _scoutDate, user.uid);
      if (_addCustomReminder && _customReminderCtrl.text.isNotEmpty)
        await _scheduleReminder('custom_${now.millisecondsSinceEpoch}', 'Custom reminder — ${widget.cropType}', _customReminderCtrl.text, _customDate, user.uid);

      if (mounted) {
        _reset();
        msg.showSnackBar(SnackBar(
          backgroundColor: _T.brandLight, behavior: SnackBarBehavior.floating,
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 16), const SizedBox(width: 8),
            Text(savedOnline
                ? (cost > 0 && _saveToCosts
                    ? 'Saved ✓  KES ${cost.toStringAsFixed(0)} linked to farm costs'
                    : 'Intervention saved ✓')
                : 'Saved offline — syncs when connected',
                style: const TextStyle(color: Colors.white)),
          ]),
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) msg.showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _scheduleReminder(String id, String title, String body, DateTime date, String userId) async {
    if (date.isBefore(DateTime.now())) return;
    try {
      if (!_tzReady) await _initTz();
      await FirebaseFirestore.instance.collection('field_reminders').doc(id).set({
        'userId': userId, 'title': title, 'body': body,
        'scheduledDate': Timestamp.fromDate(date), 'notifId': id.hashCode,
      });
            await widget.notificationsPlugin.zonedSchedule(
        id: id.hashCode,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(date, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _kNotifChannel,
            _kNotifChanName,
            channelDescription: 'Pest activity reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {}
  }

  void _reset() {
    for (final c in [_interventionCtrl, _dosageCtrl, _unitCtrl, _areaCtrl, _costCtrl, _customReminderCtrl]) c.clear();
    setState(() {
      _areaUnit = 'Acres'; _saveToCosts = true; _costCategory = 'Pesticide / Herbicide';
      _followUp = true; _reminderDate = DateTime.now().add(const Duration(days: 7));
      _aiAdvice = null; _aiSuggestions = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.pageBg,
      appBar: _stepHeader('Intervention, Cost & Reminders', 3, 3),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Context card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: _T.card(border: _T.okBorder),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.bug_report_outlined, size: 16, color: _T.brandMid),
                const SizedBox(width: 6),
                Expanded(child: Text(widget.pestData.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _T.textPrimary))),
              ]),
              const SizedBox(height: 4),
              Text('${widget.cropType}  ·  ${widget.cropStage}', style: const TextStyle(fontSize: 13, color: _T.textSec)),
            ]),
          ),
          const SizedBox(height: 16),

          // AI Advisor (identical to disease InterventionPage)
          _aiAdvisorCard(),
          const SizedBox(height: 20),

          // Form fields (NO cycle field — removed per issue #6)
          _lbl('INTERVENTION USED'),
          const SizedBox(height: 6),
          TextField(controller: _interventionCtrl, style: const TextStyle(fontSize: 14, color: _T.textPrimary),
              decoration: _T.field('Intervention used', hint: 'e.g., Spray Karate 2.5 EC')),
          const SizedBox(height: 14),

          _lbl('DOSAGE'),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(flex: 2, child: TextField(controller: _dosageCtrl, keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 14, color: _T.textPrimary), decoration: _T.field('Dosage'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _unitCtrl, style: const TextStyle(fontSize: 14, color: _T.textPrimary),
                decoration: _T.field('Unit', hint: 'ml/L'))),
          ]),
          const SizedBox(height: 14),

          _lbl('AREA AFFECTED'),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: TextField(controller: _areaCtrl, keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 14, color: _T.textPrimary), decoration: _T.field('Area'))),
            const SizedBox(width: 10),
            _unitBtn('Acres'), const SizedBox(width: 6), _unitBtn('SQM'),
          ]),
          const SizedBox(height: 20),

          // Cost + Plot card
          _costCard(),
          const SizedBox(height: 20),

          // Reminders
          _remindersCard(),
          const SizedBox(height: 24),

          // Save button
          ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
                backgroundColor: _T.brandDark, foregroundColor: Colors.white,
                elevation: 0, padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('Save Intervention', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _aiAdvisorCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_T.aiGradA, _T.aiGradB], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14), border: Border.all(color: _T.brandLight, width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 18)),
          const SizedBox(width: 10),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('AI Pest Advisor', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
            Text('Powered by Gemini · No setup required', style: TextStyle(color: Colors.white70, fontSize: 11)),
          ]),
        ]),
        const SizedBox(height: 12),
        if (_aiLoading)
          const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)))
        else if (_aiAdvice != null) ...[
          _buildAiSections(_aiAdvice!),
          if (_aiSuggestions.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('SUGGESTED INTERVENTIONS', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            const SizedBox(height: 6),
            ..._aiSuggestions.map((s) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.10), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white.withOpacity(0.2))),
              child: Row(children: [
                Expanded(child: Text('${s['type']}${s['quantity'] != null ? '  ·  ${(s['quantity'] as num).toStringAsFixed(1)} ${s['unit']}' : ''}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500))),
                GestureDetector(onTap: () => _acceptSuggestion(s),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                    child: const Text('Use', style: TextStyle(fontSize: 12, color: _T.brandDark, fontWeight: FontWeight.w700)))),
              ]),
            )),
          ],
          const SizedBox(height: 8),
          GestureDetector(onTap: _fetchAiAdvice,
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.refresh_rounded, size: 13, color: Colors.white60), SizedBox(width: 4),
              Text('Refresh advice', style: TextStyle(color: Colors.white60, fontSize: 12, decoration: TextDecoration.underline, decorationColor: Colors.white38)),
            ])),
        ] else ...[
          const Text('Get pesticide names, dosages and timing for this exact pest, crop and stage.', style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _fetchAiAdvice,
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('Get AI pest advice', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: _T.brandDark, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            )),
        ],
      ]),
    );
  }

  Widget _costCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _T.costBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _T.costBorder, width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.payments_outlined, size: 16, color: _T.costIcon), SizedBox(width: 8),
          Text('Cost (optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _T.costText)),
        ]),
        const SizedBox(height: 10),
        TextField(controller: _costCtrl, keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 14, color: _T.textPrimary),
            decoration: _T.field('Amount (KES)')),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: _T.okBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: _T.okBorder, width: 1.5)),
          child: Row(children: [
            const Icon(Icons.auto_awesome, size: 13, color: _T.brandMid), const SizedBox(width: 6),
            Text('Category: $_costCategory', style: const TextStyle(fontSize: 12, color: _T.brandMid)),
          ]),
        ),
        const SizedBox(height: 10),
        _lbl('LINK TO FARM PLOT'),
        const SizedBox(height: 6),
        if (_plotsLoading)
          const Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)))
        else if (_farmPlots.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(color: _T.inputBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _T.borderDef, width: 1.5)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedPlotId, isExpanded: true,
                style: const TextStyle(fontSize: 13, color: _T.textPrimary),
                items: [
                  const DropdownMenuItem(value: null, child: Text('General / no specific plot')),
                  ..._farmPlots.map((p) => DropdownMenuItem(value: p['id'], child: Text(p['name'] ?? p['id']!))),
                ],
                onChanged: (v) => setState(() => _selectedPlotId = v),
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _T.infoBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: _T.infoBorder, width: 1.5)),
            child: const Row(children: [
              Icon(Icons.info_outline, size: 14, color: _T.infoText), SizedBox(width: 8),
              Expanded(child: Text('Add plots in Farm Management to link costs to a specific plot.', style: TextStyle(fontSize: 11, color: _T.infoText))),
            ]),
          ),
        const SizedBox(height: 4),
        // Confirmation of where cost is saved — visible plot name
        if (_selectedPlotId != null)
          Container(
            margin: const EdgeInsets.only(top: 2, bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: _T.okBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _T.okBorder, width: 1.5),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle_outline, size: 14, color: _T.brandMid),
              const SizedBox(width: 6),
              Expanded(child: Text(
                'Cost will be saved to: ${_farmPlots.where((p) => p['id'] == _selectedPlotId).firstOrNull?['name'] ?? _selectedPlotId!}',
                style: const TextStyle(fontSize: 12, color: _T.brandMid, fontWeight: FontWeight.w600),
              )),
            ]),
          )
        else
          const Padding(
            padding: EdgeInsets.only(top: 2, bottom: 4),
            child: Text('No plot selected — cost will not be linked to a specific plot.',
                style: TextStyle(fontSize: 11, color: _T.textHint)),
          ),
        const SizedBox(height: 10),
        Row(children: [
          Switch(value: _saveToCosts, onChanged: (v) => setState(() => _saveToCosts = v), activeColor: _T.brandLight, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
          const SizedBox(width: 8),
          const Expanded(child: Text('Save to Farm Management costs', style: TextStyle(fontSize: 13, color: _T.textPrimary))),
        ]),
      ]),
    );
  }

  Widget _remindersCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _T.card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Reminders', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _T.textPrimary)),
        const SizedBox(height: 4),
        const Text('System-suggested and custom reminders for follow-up activities.', style: TextStyle(fontSize: 11, color: _T.textHint, height: 1.4)),
        const SizedBox(height: 14),

        // Follow-up (identical to disease InterventionPage)
        _remRow('Follow-up check', '${_reminderDate.day}/${_reminderDate.month}/${_reminderDate.year}',
            _followUp, (v) => setState(() => _followUp = v),
            () => _pickDate(_reminderDate, (d) => setState(() => _reminderDate = d))),
        const Divider(height: 18),

        // System suggestions based on pest type
        const Text('SUGGESTED BASED ON THIS PEST', style: TextStyle(fontSize: 10, color: _T.textHint, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
        const SizedBox(height: 10),
        _remRow('Re-spray in 2 weeks', '${_sprayDate.day}/${_sprayDate.month}/${_sprayDate.year}  ·  Most pesticides require repeat application',
            _addSprayReminder, (v) => setState(() => _addSprayReminder = v),
            () => _pickDate(_sprayDate, (d) => setState(() => _sprayDate = d))),
        const SizedBox(height: 8),
        _remRow('Weed your plot', '${_weedDate.day}/${_weedDate.month}/${_weedDate.year}  ·  Weeds harbour pests and reduce yields',
            _addWeedReminder, (v) => setState(() => _addWeedReminder = v),
            () => _pickDate(_weedDate, (d) => setState(() => _weedDate = d))),
        const SizedBox(height: 8),
        _remRow('Pest scouting check', '${_scoutDate.day}/${_scoutDate.month}/${_scoutDate.year}  ·  Check for re-infestation signs',
            _addScoutReminder, (v) => setState(() => _addScoutReminder = v),
            () => _pickDate(_scoutDate, (d) => setState(() => _scoutDate = d))),
        const Divider(height: 18),

        // Custom reminder
        const Text('CUSTOM REMINDER', style: TextStyle(fontSize: 10, color: _T.textHint, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
        const SizedBox(height: 8),
        Row(children: [
          Switch(value: _addCustomReminder, onChanged: (v) => setState(() => _addCustomReminder = v), activeColor: _T.brandLight, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
          const SizedBox(width: 8),
          const Expanded(child: Text('Add custom reminder', style: TextStyle(fontSize: 13, color: _T.textPrimary))),
        ]),
        if (_addCustomReminder) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _customReminderCtrl,
            style: const TextStyle(fontSize: 14, color: _T.textPrimary),
            decoration: _T.field('Reminder message', hint: 'e.g., Apply second dose of Dursban'),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _pickDate(_customDate, (d) => setState(() => _customDate = d)),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(color: _T.inputBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _T.borderDef, width: 1.5)),
              child: Row(children: [
                const Icon(Icons.calendar_today_rounded, size: 18, color: _T.textSec), const SizedBox(width: 10),
                Text('${_customDate.day}/${_customDate.month}/${_customDate.year}', style: const TextStyle(fontSize: 14, color: _T.textPrimary)),
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _remRow(String title, String sub, bool val, ValueChanged<bool> onToggle, VoidCallback onDate) {
    return Row(children: [
      Expanded(child: InkWell(
        onTap: val ? onDate : null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: val ? _T.textPrimary : Colors.grey.shade400)),
          const SizedBox(height: 2),
          Text(sub, style: TextStyle(fontSize: 11, color: val ? _T.textHint : Colors.grey.shade400)),
        ]),
      )),
      Switch(value: val, onChanged: onToggle, activeColor: _T.brandLight, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
    ]);
  }

  Future<void> _pickDate(DateTime initial, ValueChanged<DateTime> onPicked) async {
    final p = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime.now(), lastDate: DateTime(2030));
    if (p != null) onPicked(p);
  }

  Widget _lbl(String t) => Text(t, style: const TextStyle(fontSize: 10, color: _T.textHint, fontWeight: FontWeight.w700, letterSpacing: 0.8));

  Widget _unitBtn(String val) {
    final sel = _areaUnit == val;
    return GestureDetector(
      onTap: () => setState(() => _areaUnit = val),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? _T.brandMid : _T.cardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: sel ? _T.brandMid : _T.borderDef, width: 1.5)),
        child: Text(val, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sel ? Colors.white : _T.textSec)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PEST DETAILS LIBRARY  (key = "${crop}_${stage}_${pest}")
// ─────────────────────────────────────────────────────────────────────────────

const Map<String, Map<String, dynamic>> _kPestDetails = {
    // ===== BEANS PESTS =====
    // Beans - Germination/Seedling
    'Beans_Germination/Seedling_Bean Fly': {
      'imagePath': 'assets/pests/beans_bean_fly_germination.jpg',
      'possibleStrategies': [
        'Use crop rotation',
        'Use row covers',
        'Monitor seedlings for early damage',
        'Plant trap crops like cowpeas',
        'Apply organic soil treatments',
      ],
      'intervention': 'Apply neem oil to soil',
      'possibleCauses': [
        'Warm, moist soil conditions',
        'Infested soil from previous crops',
        'Proximity to host plants',
        'Lack of natural predators',
      ],
      'herbicidesPesticides': [
        'Imidacloprid',
        'Thiamethoxam',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Diatomaceous earth (organic)',
      ],
      'organicInterventions': [
        'Apply neem oil to soil around seedlings',
        'Use lightweight row covers during egg-laying',
        'Introduce beneficial nematodes to soil',
        'Plant trap crops like cowpeas',
        'Apply diatomaceous earth around plant base',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_germination.jpg',
    },
    'Beans_Germination/Seedling_Cutworms': {
      'imagePath': 'assets/pests/beans_cutworms_germination.jpg',
      'possibleStrategies': [
        'Remove crop debris',
        'Use row covers',
        'Apply organic mulch',
        'Hand-pick pests at night',
        'Introduce beneficial insects',
      ],
      'intervention': 'Apply Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Moist, undisturbed soil',
        'Presence of crop residue',
        'Weedy fields',
        'Lack of natural predators',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Permethrin',
        'Bacillus thuringiensis (Bt) (organic)',
        'Spinosad (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to soil',
        'Use row covers at planting',
        'Hand-pick cutworms at night',
        'Apply diatomaceous earth around seedlings',
        'Introduce predatory insects like ground beetles',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_germination.jpg',
    },
    'Beans_Germination/Seedling_Rodents': {
      'imagePath': 'assets/pests/beans_rodents_germination.jpg',
      'possibleStrategies': [
        'Set mechanical traps',
        'Clear vegetation around fields',
        'Use natural repellents',
        'Introduce predators like cats',
        'Use fencing',
      ],
      'intervention': 'Set mechanical traps',
      'possibleCauses': [
        'Availability of food sources',
        'Nearby nesting sites',
        'Unprotected fields',
        'Lack of predators',
      ],
      'herbicidesPesticides': [
        'Bromadiolone',
        'Zinc phosphide',
        'Garlic extract (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Use garlic extract as a repellent',
        'Set mechanical traps around fields',
        'Plant repellent crops like mint',
        'Clear debris to reduce nesting sites',
        'Introduce natural predators like cats',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_germination.jpg',
    },
    'Beans_Germination/Seedling_Termites': {
      'imagePath': 'assets/pests/beans_termites_germination.jpg',
      'possibleStrategies': [
        'Treat soil with organic amendments',
        'Remove wood debris',
        'Use treated seeds',
        'Apply organic mulch',
        'Introduce beneficial nematodes',
      ],
      'intervention': 'Apply neem oil to soil',
      'possibleCauses': [
        'Presence of dry wood or debris',
        'Warm, dry soil conditions',
        'Lack of soil treatment',
        'Previous termite infestations',
      ],
      'herbicidesPesticides': [
        'Fipronil',
        'Imidacloprid',
        'Neem oil (organic)',
        'Diatomaceous earth (organic)',
        'Beneficial nematodes (organic)',
      ],
      'organicInterventions': [
        'Apply neem oil to soil around seedlings',
        'Introduce beneficial nematodes to soil',
        'Use diatomaceous earth as a soil barrier',
        'Plant repellent crops like marigolds',
        'Maintain moist soil to deter termites',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_germination.jpg',
    },

    // Beans - Vegetative Growth/Weeding
    'Beans_Vegetative Growth/Weeding_Aphids': {
      'imagePath': 'assets/pests/beans_aphids_vegetative_growth.jpg',
      'possibleStrategies': [
        'Introduce beneficial insects',
        'Use neem oil sprays',
        'Plant companion crops like marigolds',
        'Use reflective mulches',
        'Monitor plant health',
      ],
      'intervention': 'Spray neem oil on foliage',
      'possibleCauses': [
        'Warm weather',
        'Overcrowded plants',
        'Lack of natural predators',
        'Excess nitrogen in soil',
      ],
      'herbicidesPesticides': [
        'Malathion',
        'Imidacloprid',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Garlic extract (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected leaves',
        'Introduce ladybugs to control aphid population',
        'Use garlic extract spray',
        'Plant marigolds as companion crops',
        'Apply diatomaceous earth to leaves',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_vegetative_growth.jpg',
    },
    'Beans_Vegetative Growth/Weeding_Leafhoppers': {
      'imagePath': 'assets/pests/beans_leaf_hoppers_vegetative_growth.jpg',
      'possibleStrategies': [
        'Use row covers',
        'Introduce beneficial insects',
        'Plant trap crops',
        'Apply organic sprays',
        'Monitor plant damage',
      ],
      'intervention': 'Spray pyrethrin on foliage',
      'possibleCauses': [
        'Warm, dry conditions',
        'Nearby weed hosts',
        'Lack of predators',
        'Crop monoculture',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Imidacloprid',
        'Pyrethrin (organic)',
        'Neem oil (organic)',
        'Spinosad (organic)',
      ],
      'organicInterventions': [
        'Spray pyrethrin on affected leaves',
        'Introduce predatory wasps',
        'Plant trap crops like alfalfa',
        'Use neem oil sprays',
        'Apply row covers during peak activity',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_vegetative.jpg',
    },
    'Beans_Vegetative Growth/Weeding_Thrips': {
      'imagePath': 'assets/pests/beans_thrips_vegetative_growth.jpg',
      'possibleStrategies': [
        'Use reflective mulches',
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Maintain plant health',
        'Use crop rotation',
      ],
      'intervention': 'Apply spinosad to foliage',
      'possibleCauses': [
        'Hot, dry conditions',
        'Weedy fields',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Imidacloprid',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Apply spinosad to affected leaves',
        'Introduce predatory mites',
        'Use neem oil sprays',
        'Plant companion crops like marigolds',
        'Use reflective mulches to deter thrips',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_vegetative.jpg',
    },
    'Beans_Vegetative Growth/Weeding_Whiteflies': {
      'imagePath': 'assets/pests/beans_whiteflies_vegetative_growth.jpg',
      'possibleStrategies': [
        'Use yellow sticky traps',
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Plant companion crops',
        'Use reflective mulches',
      ],
      'intervention': 'Apply neem oil to foliage',
      'possibleCauses': [
        'Warm, humid conditions',
        'Overcrowded plants',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Imidacloprid',
        'Pyriproxyfen',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Spinosad (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected leaves',
        'Introduce parasitic wasps',
        'Use yellow sticky traps',
        'Plant marigolds as companion crops',
        'Apply garlic extract spray',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_vegetative.jpg',
    },
    'Beans_Vegetative Growth/Weeding_Beetles': {
      'imagePath': 'assets/pests/beans_beetles_vegetative_growth.jpg',
      'possibleStrategies': [
        'Hand-pick beetles',
        'Use row covers',
        'Apply organic sprays',
        'Plant trap crops',
        'Introduce beneficial insects',
      ],
      'intervention': 'Apply spinosad to foliage',
      'possibleCauses': [
        'Warm weather',
        'Crop residue',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Permethrin',
        'Spinosad (organic)',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Apply spinosad to affected leaves',
        'Hand-pick beetles and larvae',
        'Use neem oil sprays',
        'Plant trap crops like mustard',
        'Introduce predatory beetles',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_vegetative.jpg',
    },
    'Beans_Vegetative Growth/Weeding_Rodents': {
      'imagePath': 'assets/pests/beans_rodents_vegetative_growth.jpg',
      'possibleStrategies': [
        'Set mechanical traps',
        'Clear vegetation around fields',
        'Use natural repellents',
        'Introduce predators',
        'Use fencing',
      ],
      'intervention': 'Set mechanical traps',
      'possibleCauses': [
        'Food availability',
        'Nearby nesting sites',
        'Unprotected fields',
        'Lack of predators',
      ],
      'herbicidesPesticides': [
        'Bromadiolone',
        'Zinc phosphide',
        'Garlic extract (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Use garlic extract as a repellent',
        'Set mechanical traps around fields',
        'Plant repellent crops like mint',
        'Clear debris to reduce nesting sites',
        'Introduce natural predators like cats',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_vegetative.jpg',
    },

    // Beans - Flowering/Reproductive
    'Beans_Flowering/Reproductive_Aphids': {
      'imagePath': 'assets/pests/beans_aphids_flowering.jpg',
      'possibleStrategies': [
        'Introduce beneficial insects',
        'Use neem oil sprays',
        'Plant companion crops',
        'Use reflective mulches',
        'Monitor flower buds',
      ],
      'intervention': 'Spray neem oil on flowers',
      'possibleCauses': [
        'Warm weather',
        'Overcrowded plants',
        'Lack of predators',
        'Excess nitrogen in soil',
      ],
      'herbicidesPesticides': [
        'Malathion',
        'Imidacloprid',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Garlic extract (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected flowers',
        'Introduce ladybugs to control aphids',
        'Use garlic extract spray',
        'Plant marigolds as companion crops',
        'Apply diatomaceous earth to flowers',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_flowering.jpg',
    },
    'Beans_Flowering/Reproductive_Leafhoppers': {
      'imagePath': 'assets/pests/beans_leaf_hoppers_flowering.jpg',
      'possibleStrategies': [
        'Use row covers',
        'Introduce beneficial insects',
        'Plant trap crops',
        'Apply organic sprays',
        'Monitor flower damage',
      ],
      'intervention': 'Spray pyrethrin on flowers',
      'possibleCauses': [
        'Warm, dry conditions',
        'Nearby weed hosts',
        'Lack of predators',
        'Crop monoculture',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Imidacloprid',
        'Pyrethrin (organic)',
        'Neem oil (organic)',
        'Spinosad (organic)',
      ],
      'organicInterventions': [
        'Spray pyrethrin on affected flowers',
        'Introduce predatory wasps',
        'Plant trap crops like alfalfa',
        'Use neem oil sprays',
        'Apply row covers during flowering',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_flowering.jpg',
    },
    'Beans_Flowering/Reproductive_Thrips': {
      'imagePath': 'assets/pests/beans_thrips_flowering.jpg',
      'possibleStrategies': [
        'Use reflective mulches',
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Maintain plant health',
        'Use crop rotation',
      ],
      'intervention': 'Apply spinosad to flowers',
      'possibleCauses': [
        'Hot, dry conditions',
        'Weedy fields',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Imidacloprid',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Apply spinosad to affected flowers',
        'Introduce predatory mites',
        'Use neem oil sprays',
        'Plant companion crops like marigolds',
        'Use reflective mulches to deter thrips',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_flowering.jpg',
    },
    'Beans_Flowering/Reproductive_Pod Borers': {
      'imagePath': 'assets/pests/beans_pod_borer_flowering.jpg',
      'possibleStrategies': [
        'Use trap crops',
        'Apply organic sprays',
        'Monitor pods for entry holes',
        'Introduce beneficial insects',
        'Use row covers',
      ],
      'intervention': 'Apply Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm weather',
        'Nearby host plants',
        'Crop residue',
        'Lack of predators',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Spinosad (organic)',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to flowers',
        'Use neem oil sprays',
        'Plant trap crops like cowpeas',
        'Hand-pick larvae from pods',
        'Use row covers during flowering',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_flowering.jpg',
    },
    'Beans_Flowering/Reproductive_Whiteflies': {
      'imagePath': 'assets/pests/beans_whiteflies_flowering.jpg',
      'possibleStrategies': [
        'Use yellow sticky traps',
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Plant companion crops',
        'Use reflective mulches',
      ],
      'intervention': 'Apply neem oil to flowers',
      'possibleCauses': [
        'Warm, humid conditions',
        'Overcrowded plants',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Imidacloprid',
        'Pyriproxyfen',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Spinosad (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected flowers',
        'Introduce parasitic wasps',
        'Use yellow sticky traps',
        'Plant marigolds as companion crops',
        'Apply garlic extract spray',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_flowering.jpg',
    },

    // Beans - Maturation/Harvesting
    'Beans_Maturation/Harvesting_Pod Borers': {
      'imagePath': 'assets/pests/beans_pod_borers_harvesting.jpg',
      'possibleStrategies': [
        'Use trap crops',
        'Apply organic sprays',
        'Monitor pods for damage',
        'Hand-pick larvae',
        'Introduce beneficial insects',
      ],
      'intervention': 'Apply Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm weather',
        'Crop residue',
        'Nearby host plants',
        'Lack of predators',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Spinosad (organic)',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to pods',
        'Use neem oil sprays',
        'Plant trap crops like cowpeas',
        'Hand-pick larvae from pods',
        'Remove infested pods',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_maturation.jpg',
    },
    'Beans_Maturation/Harvesting_Beetles': {
      'imagePath': 'assets/pests/beans_beetles_harvesting.jpg',
      'possibleStrategies': [
        'Hand-pick beetles',
        'Use row covers',
        'Apply organic sprays',
        'Plant trap crops',
        'Introduce beneficial insects',
      ],
      'intervention': 'Apply spinosad to pods',
      'possibleCauses': [
        'Warm weather',
        'Crop residue',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Permethrin',
        'Spinosad (organic)',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Apply spinosad to affected pods',
        'Hand-pick beetles and larvae',
        'Use neem oil sprays',
        'Plant trap crops like mustard',
        'Introduce predatory beetles',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_maturation.jpg',
    },
    'Beans_Maturation/Harvesting_Bean Weevil': {
      'imagePath': 'assets/pests/beans_bean_weevil_harvesting.jpg',
      'possibleStrategies': [
        'Harvest beans early',
        'Apply organic sprays',
        'Monitor pods for damage',
        'Use trap crops',
        'Introduce beneficial insects',
      ],
      'intervention': 'Apply spinosad to pods',
      'possibleCauses': [
        'Warm, dry conditions',
        'Infested seeds',
        'Lack of predators',
        'Delayed harvesting',
      ],
      'herbicidesPesticides': [
        'Malathion',
        'Spinosad (organic)',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Apply spinosad to affected pods',
        'Harvest beans early to avoid infestation',
        'Use neem oil sprays',
        'Plant trap crops like cowpeas',
        'Introduce parasitic wasps',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_maturation.jpg',
    },
    'Beans_Maturation/Harvesting_Bruchid Beetles': {
      'imagePath': 'assets/pests/beans_bruchid_beetle_harvesting.jpg',
      'possibleStrategies': [
        'Harvest beans early',
        'Apply organic sprays',
        'Monitor pods for damage',
        'Use trap crops',
        'Introduce beneficial insects',
      ],
      'intervention': 'Apply spinosad to pods',
      'possibleCauses': [
        'Warm, dry conditions',
        'Infested seeds',
        'Lack of predators',
        'Delayed harvesting',
      ],
      'herbicidesPesticides': [
        'Malathion',
        'Spinosad (organic)',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Apply spinosad to affected pods',
        'Harvest beans early to avoid infestation',
        'Use neem oil sprays',
        'Plant trap crops like cowpeas',
        'Introduce parasitic wasps',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_maturation.jpg',
    },
    'Beans_Maturation/Harvesting_Rodents': {
      'imagePath': 'assets/pests/beans_rodents_harvesting.jpg',
      'possibleStrategies': [
        'Set mechanical traps',
        'Clear vegetation around fields',
        'Use natural repellents',
        'Introduce predators',
        'Use fencing',
      ],
      'intervention': 'Set mechanical traps',
      'possibleCauses': [
        'Ripe beans as food source',
        'Nearby nesting sites',
        'Unprotected fields',
        'Lack of predators',
      ],
      'herbicidesPesticides': [
        'Bromadiolone',
        'Zinc phosphide',
        'Garlic extract (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Use garlic extract as a repellent',
        'Set mechanical traps around fields',
        'Plant repellent crops like mint',
        'Clear debris to reduce nesting sites',
        'Introduce natural predators like cats',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_maturation.jpg',
    },

    // Beans - Storage
    'Beans_Storage_Bean Weevil': {
      'imagePath': 'assets/pests/beans_bean_weevil_storage.jpg',
      'possibleStrategies': [
        'Store in airtight containers',
        'Use diatomaceous earth',
        'Apply organic treatments',
        'Ensure proper drying before storage',
        'Monitor stored beans',
      ],
      'intervention': 'Apply diatomaceous earth',
      'possibleCauses': [
        'Infested seeds',
        'High humidity in storage',
        'Poor storage conditions',
        'Lack of inspection',
      ],
      'herbicidesPesticides': [
        'Malathion',
        'Diatomaceous earth (organic)',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Apply diatomaceous earth to stored beans',
        'Use neem oil-treated containers',
        'Store in airtight containers with desiccants',
        'Freeze beans to kill larvae',
        'Regularly inspect stored beans',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_storage.jpg',
    },
    'Beans_Storage_Bruchid Beetles': {
      'imagePath': 'assets/pests/beans_bruchid_beetle_storage.jpg',
      'possibleStrategies': [
        'Store in airtight containers',
        'Use diatomaceous earth',
        'Apply organic treatments',
        'Ensure proper drying before storage',
        'Monitor stored beans',
      ],
      'intervention': 'Apply diatomaceous earth',
      'possibleCauses': [
        'Infested seeds',
        'High humidity in storage',
        'Poor storage conditions',
        'Lack of inspection',
      ],
      'herbicidesPesticides': [
        'Malathion',
        'Diatomaceous earth (organic)',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Apply diatomaceous earth to stored beans',
        'Use neem oil-treated containers',
        'Store in airtight containers with desiccants',
        'Freeze beans to kill larvae',
        'Regularly inspect stored beans',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_storage.jpg',
    },
    'Beans_Storage_Rodents': {
      'imagePath': 'assets/pests/beans_rodents_storage.jpg',
      'possibleStrategies': [
        'Store in rodent-proof containers',
        'Set mechanical traps',
        'Use natural repellents',
        'Ensure proper storage conditions',
        'Introduce predators',
      ],
      'intervention': 'Use rodent-proof containers',
      'possibleCauses': [
        'Food availability',
        'Poor storage facilities',
        'Nearby nesting sites',
        'Lack of predators',
      ],
      'herbicidesPesticides': [
        'Bromadiolone',
        'Zinc phosphide',
        'Garlic extract (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Use garlic extract as a repellent',
        'Store in metal or rodent-proof containers',
        'Set mechanical traps in storage areas',
        'Clear debris around storage',
        'Introduce natural predators like cats',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_storage.jpg',
    },

    // ===== MAIZE PESTS =====
    // Maize - Germination/Seedling
    'Maize_Germination/Seedling_Termites': {
      'imagePath': 'assets/pests/maize_termites_germination.jpg',
      'possibleStrategies': [
        'Treat soil with organic amendments',
        'Remove wood debris',
        'Use treated seeds',
        'Apply organic mulch',
        'Introduce beneficial nematodes',
      ],
      'intervention': 'Apply neem oil to soil',
      'possibleCauses': [
        'Presence of dry wood or debris',
        'Warm, dry soil conditions',
        'Lack of soil treatment',
        'Previous termite infestations',
      ],
      'herbicidesPesticides': [
        'Fipronil',
        'Imidacloprid',
        'Neem oil (organic)',
        'Diatomaceous earth (organic)',
        'Beneficial nematodes (organic)',
      ],
      'organicInterventions': [
        'Apply neem oil to soil around seedlings',
        'Introduce beneficial nematodes to soil',
        'Use diatomaceous earth as a soil barrier',
        'Plant repellent crops like marigolds',
        'Maintain moist soil to deter termites',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_germination.jpg',
    },
    'Maize_Germination/Seedling_Cutworms': {
      'imagePath': 'assets/pests/maize_cutworm_germination.jpg',
      'possibleStrategies': [
        'Remove crop debris',
        'Use row covers',
        'Apply organic mulch',
        'Hand-pick pests at night',
        'Introduce beneficial insects',
      ],
      'intervention': 'Apply Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Moist, undisturbed soil',
        'Presence of crop residue',
        'Weedy fields',
        'Lack of natural predators',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Permethrin',
        'Bacillus thuringiensis (Bt) (organic)',
        'Spinosad (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to soil',
        'Use row covers at planting',
        'Hand-pick cutworms at night',
        'Apply diatomaceous earth around seedlings',
        'Introduce predatory insects like ground beetles',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_germination.jpg',
    },
    'Maize_Germination/Seedling_Maize Shoot Fly': {
      'imagePath': 'assets/pests/maize_shoot_fly_germination.jpg',
      'possibleStrategies': [
        'Use treated seeds',
        'Apply organic soil treatments',
        'Use row covers',
        'Plant early to avoid peak fly activity',
        'Monitor seedlings',
      ],
      'intervention': 'Apply neem oil to soil',
      'possibleCauses': [
        'Warm, moist soil',
        'Crop residue',
        'Lack of predators',
        'Delayed planting',
      ],
      'herbicidesPesticides': [
        'Imidacloprid',
        'Thiamethoxam',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Diatomaceous earth (organic)',
      ],
      'organicInterventions': [
        'Apply neem oil to soil around seedlings',
        'Use lightweight row covers',
        'Plant early to avoid peak fly activity',
        'Introduce beneficial nematodes',
        'Apply diatomaceous earth around plant base',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_germination.jpg',
    },
    'Maize_Germination/Seedling_Rodents': {
      'imagePath': 'assets/pests/maize_rodents_germination.jpg',
      'possibleStrategies': [
        'Set mechanical traps',
        'Clear vegetation around fields',
        'Use natural repellents',
        'Introduce predators',
        'Use fencing',
      ],
      'intervention': 'Set mechanical traps',
      'possibleCauses': [
        'Food availability',
        'Nearby nesting sites',
        'Unprotected fields',
        'Lack of predators',
      ],
      'herbicidesPesticides': [
        'Bromadiolone',
        'Zinc phosphide',
        'Garlic extract (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Use garlic extract as a repellent',
        'Set mechanical traps around fields',
        'Plant repellent crops like mint',
        'Clear debris to reduce nesting sites',
        'Introduce natural predators like cats',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_germination.jpg',
    },

    // Maize - Vegetative Growth/Weeding
    'Maize_Vegetative Growth/Weeding_Aphids': {
      'imagePath': 'assets/pests/maize_leaf_aphids_vegetative_growth.jpg',
      'possibleStrategies': [
        'Introduce beneficial insects',
        'Use neem oil sprays',
        'Plant companion crops',
        'Use reflective mulches',
        'Monitor plant health',
      ],
      'intervention': 'Spray neem oil on foliage',
      'possibleCauses': [
        'Warm weather',
        'Overcrowded plants',
        'Lack of natural predators',
        'Excess nitrogen in soil',
      ],
      'herbicidesPesticides': [
        'Malathion',
        'Imidacloprid',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Garlic extract (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected leaves',
        'Introduce ladybugs to control aphid population',
        'Use garlic extract spray',
        'Plant marigolds as companion crops',
        'Apply diatomaceous earth to leaves',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_vegetative.jpg',
    },
    'Maize_Vegetative Growth/Weeding_Stem Borers': {
      'imagePath': 'assets/pests/maize_stem_borer_vegetative_growth.jpg',
      'possibleStrategies': [
        'Use trap crops',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Destroy crop residue',
        'Monitor stems for entry holes',
      ],
      'intervention': 'Apply Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm weather',
        'Crop residue',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Lambda-cyhalothrin',
        'Bacillus thuringiensis (Bt) (organic)',
        'Spinosad (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to stems',
        'Use neem oil sprays',
        'Plant trap crops like napier grass',
        'Introduce parasitic wasps',
        'Destroy infested crop residue',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_vegetative.jpg',
    },
    'Maize_Vegetative Growth/Weeding_Armyworms': {
      'imagePath': 'assets/pests/maize_armyworm_vegetative_growth.jpg',
      'possibleStrategies': [
        'Hand-pick larvae',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Use trap crops',
        'Monitor plant damage',
      ],
      'intervention': 'Apply Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm, humid conditions',
        'Weedy fields',
        'Lack of predators',
        'Crop residue',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Carbaryl',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to foliage',
        'Hand-pick larvae at night',
        'Use neem oil sprays',
        'Plant trap crops like sorghum',
        'Introduce predatory birds',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_vegetative.jpg',
    },
    'Maize_Vegetative Growth/Weeding_Leafhoppers': {
      'imagePath': 'assets/pests/maize_leaf_hoppers_vegetative_growth.jpg',
      'possibleStrategies': [
        'Use row covers',
        'Introduce beneficial insects',
        'Plant trap crops',
        'Apply organic sprays',
        'Monitor plant damage',
      ],
      'intervention': 'Spray pyrethrin on foliage',
      'possibleCauses': [
        'Warm, dry conditions',
        'Nearby weed hosts',
        'Lack of predators',
        'Crop monoculture',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Imidacloprid',
        'Pyrethrin (organic)',
        'Neem oil (organic)',
        'Spinosad (organic)',
      ],
      'organicInterventions': [
        'Spray pyrethrin on affected leaves',
        'Introduce predatory wasps',
        'Plant trap crops like alfalfa',
        'Use neem oil sprays',
        'Apply row covers during peak activity',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_vegetative.jpg',
    },
    'Maize_Vegetative Growth/Weeding_Grasshoppers': {
      'imagePath': 'assets/pests/maize_grass_hoppers_vegetative_growth.jpg',
      'possibleStrategies': [
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Use trap crops',
        'Maintain weed-free fields',
        'Use row covers',
      ],
      'intervention': 'Apply neem oil to foliage',
      'possibleCauses': [
        'Dry, warm conditions',
        'Weedy fields',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Malathion',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Spinosad (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected leaves',
        'Introduce predatory birds',
        'Plant trap crops like millet',
        'Use row covers during peak activity',
        'Apply garlic extract spray',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_vegetative.jpg',
    },
    'Maize_Vegetative Growth/Weeding_Thrips': {
      'imagePath': 'assets/pests/maize_thrips_vegetative_growth.jpg',
      'possibleStrategies': [
        'Use reflective mulches',
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Maintain plant health',
        'Use crop rotation',
      ],
      'intervention': 'Apply spinosad to foliage',
      'possibleCauses': [
        'Hot, dry conditions',
        'Weedy fields',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Imidacloprid',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Apply spinosad to affected leaves',
        'Introduce predatory mites',
        'Use neem oil sprays',
        'Plant companion crops like marigolds',
        'Use reflective mulches to deter thrips',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_vegetative.jpg',
    },
    'Maize_Vegetative Growth/Weeding_Rodents': {
      'imagePath': 'assets/pests/maize_rodents_vegetative_growth.jpg',
      'possibleStrategies': [
        'Set mechanical traps',
        'Clear vegetation around fields',
        'Use natural repellents',
        'Introduce predators',
        'Use fencing',
      ],
      'intervention': 'Set mechanical traps',
      'possibleCauses': [
        'Food availability',
        'Nearby nesting sites',
        'Unprotected fields',
        'Lack of predators',
      ],
      'herbicidesPesticides': [
        'Bromadiolone',
        'Zinc phosphide',
        'Garlic extract (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Use garlic extract as a repellent',
        'Set mechanical traps around fields',
        'Plant repellent crops like mint',
        'Clear debris to reduce nesting sites',
        'Introduce natural predators like cats',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_vegetative.jpg',
    },

    // Maize - Flowering/Reproductive
    'Maize_Flowering/Reproductive_Aphids': {
      'imagePath': 'assets/pests/maize_aphids_flowering.jpg',
      'possibleStrategies': [
        'Introduce beneficial insects',
        'Use neem oil sprays',
        'Plant companion crops',
        'Use reflective mulches',
        'Monitor tassels and silks',
      ],
      'intervention': 'Spray neem oil on tassels',
      'possibleCauses': [
        'Warm weather',
        'Overcrowded plants',
        'Lack of natural predators',
        'Excess nitrogen in soil',
      ],
      'herbicidesPesticides': [
        'Malathion',
        'Imidacloprid',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Garlic extract (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected tassels',
        'Introduce ladybugs to control aphids',
        'Use garlic extract spray',
        'Plant marigolds as companion crops',
        'Apply diatomaceous earth to tassels',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_flowering.jpg',
    },
    'Maize_Flowering/Reproductive_Stem Borers': {
      'imagePath': 'assets/pests/maize_stem_borer_flowering.jpg',
      'possibleStrategies': [
        'Use trap crops',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Destroy crop residue',
        'Monitor stems for entry holes',
      ],
      'intervention': 'Apply Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm weather',
        'Crop residue',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Lambda-cyhalothrin',
        'Bacillus thuringiensis (Bt) (organic)',
        'Spinosad (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to stems',
        'Use neem oil sprays',
        'Plant trap crops like napier grass',
        'Introduce parasitic wasps',
        'Destroy infested crop residue',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_flowering.jpg',
    },
    'Maize_Flowering/Reproductive_Armyworms': {
      'imagePath': 'assets/pests/maize_armyworm_flowering.jpg',
      'possibleStrategies': [
        'Hand-pick larvae',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Use trap crops',
        'Monitor tassels for damage',
      ],
      'intervention': 'Apply Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm, humid conditions',
        'Weedy fields',
        'Lack of predators',
        'Crop residue',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Carbaryl',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to tassels',
        'Hand-pick larvae at night',
        'Use neem oil sprays',
        'Plant trap crops like sorghum',
        'Introduce predatory birds',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_flowering.jpg',
    },
    'Maize_Flowering/Reproductive_Leafhoppers': {
      'imagePath': 'assets/pests/maize_leaf_hoppers_flowering.jpg',
      'possibleStrategies': [
        'Use row covers',
        'Introduce beneficial insects',
        'Plant trap crops',
        'Apply organic sprays',
        'Monitor tassels for damage',
      ],
      'intervention': 'Spray pyrethrin on tassels',
      'possibleCauses': [
        'Warm, dry conditions',
        'Nearby weed hosts',
        'Lack of predators',
        'Crop monoculture',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Imidacloprid',
        'Pyrethrin (organic)',
        'Neem oil (organic)',
        'Spinosad (organic)',
      ],
      'organicInterventions': [
        'Spray pyrethrin on affected tassels',
        'Introduce predatory wasps',
        'Plant trap crops like alfalfa',
        'Use neem oil sprays',
        'Apply row covers during flowering',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_flowering.jpg',
    },
    'Maize_Flowering/Reproductive_Grasshoppers': {
      'imagePath': 'assets/pests/maize_grass_hoppers_flowering.jpg',
      'possibleStrategies': [
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Use trap crops',
        'Maintain weed-free fields',
        'Use row covers',
      ],
      'intervention': 'Apply neem oil to tassels',
      'possibleCauses': [
        'Dry, warm conditions',
        'Weedy fields',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Malathion',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Spinosad (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected tassels',
        'Introduce predatory birds',
        'Plant trap crops like millet',
        'Use row covers during flowering',
        'Apply garlic extract spray',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_flowering.jpg',
    },
    'Maize_Flowering/Reproductive_Earworms': {
      'imagePath': 'assets/pests/maize_earworm_flowering.jpg',
      'possibleStrategies': [
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Use trap crops',
        'Monitor ears for damage',
        'Hand-pick larvae',
      ],
      'intervention': 'Apply Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm weather',
        'Crop residue',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Spinosad (organic)',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to silks',
        'Use neem oil sprays on ears',
        'Plant trap crops like sorghum',
        'Hand-pick larvae from ears',
        'Introduce parasitic wasps',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_flowering.jpg',
    },
    'Maize_Flowering/Reproductive_Thrips': {
      'imagePath': 'assets/pests/maize_thrips_flowering.jpg',
      'possibleStrategies': [
        'Use reflective mulches',
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Maintain plant health',
        'Use crop rotation',
      ],
      'intervention': 'Apply spinosad to tassels',
      'possibleCauses': [
        'Hot, dry conditions',
        'Weedy fields',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Imidacloprid',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Apply spinosad to affected tassels',
        'Introduce predatory mites',
        'Use neem oil sprays',
        'Plant companion crops like marigolds',
        'Use reflective mulches to deter thrips',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_flowering.jpg',
    },
    'Maize_Flowering/Reproductive_Birds': {
      'imagePath': 'assets/pests/maize_birds_flowering.jpg',
      'possibleStrategies': [
        'Use bird netting',
        'Install scare devices',
        'Plant decoy crops',
        'Harvest early',
        'Introduce predators',
      ],
      'intervention': 'Install bird netting',
      'possibleCauses': [
        'Ripe kernels',
        'Lack of deterrents',
        'Nearby nesting sites',
        'Food scarcity',
      ],
      'herbicidesPesticides': [],
      'organicInterventions': [
        'Install bird netting over plants',
        'Use reflective tape or scarecrows',
        'Plant decoy crops like sunflowers',
        'Introduce predatory birds',
        'Harvest ears early',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_flowering.jpg',
    },

    // Maize - Maturation/Harvesting
    'Maize_Maturation/Harvesting_Earworms': {
      'imagePath': 'assets/pests/maize_earworm_harvesting.jpg',
      'possibleStrategies': [
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Use trap crops',
        'Monitor ears for damage',
        'Hand-pick larvae',
      ],
      'intervention': 'Apply Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm weather',
        'Crop residue',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Spinosad (organic)',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to ears',
        'Use neem oil sprays on ears',
        'Plant trap crops like sorghum',
        'Hand-pick larvae from ears',
        'Introduce parasitic wasps',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_maturation.jpg',
    },
    'Maize_Maturation/Harvesting_Weevils': {
      'imagePath': 'assets/pests/maize_weevil_harvesting.jpg',
      'possibleStrategies': [
        'Harvest ears early',
        'Apply organic sprays',
        'Monitor ears for damage',
        'Use trap crops',
        'Introduce beneficial insects',
      ],
      'intervention': 'Apply spinosad to ears',
      'possibleCauses': [
        'Warm, dry conditions',
        'Infested seeds',
        'Lack of predators',
        'Delayed harvesting',
      ],
      'herbicidesPesticides': [
        'Malathion',
        'Spinosad (organic)',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Apply spinosad to affected ears',
        'Harvest maize early to avoid infestation',
        'Use neem oil sprays',
        'Plant trap crops like sorghum',
        'Introduce parasitic wasps',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_maturation.jpg',
    },
    'Maize_Maturation/Harvesting_Birds': {
      'imagePath': 'assets/pests/maize_birds_harvesting.jpg',
      'possibleStrategies': [
        'Use bird netting',
        'Install scare devices',
        'Plant decoy crops',
        'Harvest early',
        'Introduce predators',
      ],
      'intervention': 'Install bird netting',
      'possibleCauses': [
        'Ripe kernels',
        'Lack of deterrents',
        'Nearby nesting sites',
        'Food scarcity',
      ],
      'herbicidesPesticides': [],
      'organicInterventions': [
        'Install bird netting over plants',
        'Use reflective tape or scarecrows',
        'Plant decoy crops like sunflowers',
        'Introduce predatory birds',
        'Harvest ears early',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_maturation.jpg',
    },
    'Maize_Maturation/Harvesting_Rodents': {
      'imagePath': 'assets/pests/maize_rodents_harvesting.jpg',
      'possibleStrategies': [
        'Set mechanical traps',
        'Clear vegetation around fields',
        'Use natural repellents',
        'Introduce predators',
        'Use fencing',
      ],
      'intervention': 'Set mechanical traps',
      'possibleCauses': [
        'Ripe kernels as food source',
        'Nearby nesting sites',
        'Unprotected fields',
        'Lack of predators',
      ],
      'herbicidesPesticides': [
        'Bromadiolone',
        'Zinc phosphide',
        'Garlic extract (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Use garlic extract as a repellent',
        'Set mechanical traps around fields',
        'Plant repellent crops like mint',
        'Clear debris to reduce nesting sites',
        'Introduce natural predators like cats',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_maturation.jpg',
    },

    // Maize - Storage
    'Maize_Storage_Larger Grain Borer': {
      'imagePath': 'assets/pests/maize_larger_grain_borer_storage.jpg',
      'possibleStrategies': [
        'Store in airtight containers',
        'Use diatomaceous earth',
        'Apply organic treatments',
        'Ensure proper drying before storage',
        'Monitor stored maize',
      ],
      'intervention': 'Apply diatomaceous earth',
      'possibleCauses': [
        'Infested kernels',
        'High humidity in storage',
        'Poor storage conditions',
        'Lack of inspection',
      ],
      'herbicidesPesticides': [
        'Malathion',
        'Diatomaceous earth (organic)',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Apply diatomaceous earth to stored maize',
        'Use neem oil-treated containers',
        'Store in airtight containers with desiccants',
        'Freeze maize to kill larvae',
        'Regularly inspect stored maize',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_storage.jpg',
    },
    'Maize_Storage_Angoumois Grain Moth': {
      'imagePath': 'assets/pests/maize_angoumois_grain_moth_storage.jpg',
      'possibleStrategies': [
        'Store in airtight containers',
        'Use diatomaceous earth',
        'Apply organic treatments',
        'Ensure proper drying before storage',
        'Monitor stored maize',
      ],
      'intervention': 'Apply diatomaceous earth',
      'possibleCauses': [
        'Infested kernels',
        'High humidity in storage',
        'Poor storage conditions',
        'Lack of inspection',
      ],
      'herbicidesPesticides': [
        'Malathion',
        'Diatomaceous earth (organic)',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Apply diatomaceous earth to stored maize',
        'Use neem oil-treated containers',
        'Store in airtight containers with desiccants',
        'Freeze maize to kill larvae',
        'Regularly inspect stored maize',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_storage.jpg',
    },
    'Maize_Storage_Weevils': {
      'imagePath': 'assets/pests/maize_weevil_storage.jpg',
      'possibleStrategies': [
        'Store in airtight containers',
        'Use diatomaceous earth',
        'Apply organic treatments',
        'Ensure proper drying before storage',
        'Monitor stored maize',
      ],
      'intervention': 'Apply diatomaceous earth',
      'possibleCauses': [
        'Infested kernels',
        'High humidity in storage',
        'Poor storage conditions',
        'Lack of inspection',
      ],
      'herbicidesPesticides': [
        'Malathion',
        'Diatomaceous earth (organic)',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Apply diatomaceous earth to stored maize',
        'Use neem oil-treated containers',
        'Store in airtight containers with desiccants',
        'Freeze maize to kill larvae',
        'Regularly inspect stored maize',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_storage.jpg',
    },
    'Maize_Storage_Rodents': {
      'imagePath': 'assets/pests/maize_rodents_storage.jpg',
      'possibleStrategies': [
        'Store in rodent-proof containers',
        'Set mechanical traps',
        'Use natural repellents',
        'Ensure proper storage conditions',
        'Introduce predators',
      ],
      'intervention': 'Use rodent-proof containers',
      'possibleCauses': [
        'Food availability',
        'Poor storage facilities',
        'Nearby nesting sites',
        'Lack of predators',
      ],
      'herbicidesPesticides': [
        'Bromadiolone',
        'Zinc phosphide',
        'Garlic extract (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Use garlic extract as a repellent',
        'Store in metal or rodent-proof containers',
        'Set mechanical traps in storage areas',
        'Clear debris around storage',
        'Introduce natural predators like cats',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_storage.jpg',
    },
  
   // ===== CABBAGES/KALES PESTS =====
    // Cabbages/Kales - Germination/Seedling
    'Cabbages/Kales_Germination/Seedling_Cutworms': {
      'imagePath': 'assets/pests/cabbage_kale_cutworms_germination.jpg',
      'possibleStrategies': [
        'Remove crop debris',
        'Use row covers',
        'Apply organic mulch',
        'Hand-pick pests at night',
        'Introduce beneficial insects',
      ],
      'intervention': 'Apply Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Moist, undisturbed soil',
        'Presence of crop residue',
        'Weedy fields',
        'Lack of natural predators',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Permethrin',
        'Bacillus thuringiensis (Bt) (organic)',
        'Spinosad (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to soil',
        'Use row covers at planting',
        'Hand-pick cutworms at night',
        'Apply diatomaceous earth around seedlings',
        'Introduce predatory insects like ground beetles',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_germination.jpg',
    },
    'Cabbages/Kales_Germination/Seedling_Flea Beetles': {
      'imagePath': 'assets/pests/cabbage_kale_flea_beetle_germination.jpg',
      'possibleStrategies': [
        'Use row covers',
        'Plant trap crops',
        'Apply organic mulch',
        'Introduce beneficial insects',
        'Monitor seedling damage',
      ],
      'intervention': 'Apply neem oil to seedlings',
      'possibleCauses': [
        'Warm, dry conditions',
        'Weedy fields',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Imidacloprid',
        'Spinosad (organic)',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Apply neem oil to affected seedlings',
        'Use row covers during early growth',
        'Plant trap crops like radish',
        'Introduce predatory beetles',
        'Apply diatomaceous earth around seedlings',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_germination.jpg',
    },
    'Cabbages/Kales_Germination/Seedling_Root Maggots': {
      'imagePath': 'assets/pests/cabbage_kale_root_maggots_germination.jpg',
      'possibleStrategies': [
        'Use row covers',
        'Apply organic mulch',
        'Introduce beneficial nematodes',
        'Rotate crops',
        'Remove crop debris',
      ],
      'intervention': 'Apply beneficial nematodes to soil',
      'possibleCauses': [
        'Cool, wet soil',
        'Presence of crop residue',
        'Weedy fields',
        'Lack of natural predators',
      ],
      'herbicidesPesticides': [
        'Imidacloprid',
        'Spinosad (organic)',
        'Neem oil (organic)',
        'Beneficial nematodes (organic)',
      ],
      'organicInterventions': [
        'Apply beneficial nematodes to soil around seedlings',
        'Use row covers at planting',
        'Remove crop debris after harvest',
        'Rotate crops to non-host plants',
        'Maintain well-drained soil conditions',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_germination.jpg',
    },
    'Cabbages/Kales_Germination/Seedling_Termites': {
      'imagePath': 'assets/pests/cabbage_kale_termites_germination.jpg',
      'possibleStrategies': [
        'Remove crop debris',
        'Use organic mulch',
        'Apply natural repellents',
        'Introduce beneficial insects',
        'Maintain dry soil conditions',
      ],
      'intervention': 'Apply orange oil or neem oil to soil',
      'possibleCauses': [
        'Moist, warm soil',
        'Presence of wood or plant debris',
        'Weedy fields',
        'Lack of natural predators',
      ],
      'herbicidesPesticides': [
        'Bifenthrin',
        'Imidacloprid',
        'Neem oil (organic)',
        'Orange oil (organic)',
      ],
      'organicInterventions': [
        'Apply orange oil or neem oil to soil around seedlings',
        'Remove wood and plant debris from field',
        'Use organic mulch sparingly to avoid moisture retention',
        'Introduce predatory insects like ants',
        'Maintain well-drained soil conditions',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_germination.jpg',
    },

    // Cabbages/Kales - Vegetative Growth/Weeding
    'Cabbages/Kales_Vegetative Growth/Weeding_Aphids': {
      'imagePath': 'assets/pests/cabbage_kale_aphids_vegetative_growth.jpg',
      'possibleStrategies': [
        'Introduce beneficial insects',
        'Use neem oil sprays',
        'Plant companion crops like marigolds',
        'Use reflective mulches',
        'Monitor plant health',
      ],
      'intervention': 'Spray neem oil on foliage',
      'possibleCauses': [
        'Warm weather',
        'Overcrowded plants',
        'Lack of natural predators',
        'Excess nitrogen in soil',
      ],
      'herbicidesPesticides': [
        'Malathion',
        'Imidacloprid',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Garlic extract (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected leaves',
        'Introduce ladybugs to control aphid population',
        'Use garlic extract spray',
        'Plant marigolds as companion crops',
        'Apply diatomaceous earth to leaves',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_vegetative.jpg',
    },
      'Cabbages/Kales_Vegetative Growth/Weeding_Diamondback Moth': {
      'imagePath': 'assets/pests/cabbage_kale_diamondback_moth_vegetative_growth.jpg',
      'possibleStrategies': [
        'Use trap crops',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Monitor leaves for larvae',
        'Use row covers',
      ],
      'intervention': 'Apply Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm, humid conditions',
        'Crop residue',
        'Lack of predators',
        'Nearby crucifer crops',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Lambda-cyhalothrin',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to foliage',
        'Use neem oil sprays',
        'Plant trap crops like mustard',
        'Introduce parasitic wasps',
        'Use row covers during egg-laying',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_vegetative.jpg',
    },
    'Cabbages/Kales_Vegetative Growth/Weeding_Whiteflies': {
      'imagePath': 'assets/pests/cabbage_kale_whiteflies_vegetative_growth.jpg',
      'possibleStrategies': [
        'Use yellow sticky traps',
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Plant companion crops',
        'Use reflective mulches',
      ],
      'intervention': 'Apply neem oil to foliage',
      'possibleCauses': [
        'Warm, humid conditions',
        'Overcrowded plants',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Imidacloprid',
        'Pyriproxyfen',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Spinosad (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected leaves',
        'Introduce parasitic wasps',
        'Use yellow sticky traps',
        'Plant marigolds as companion crops',
        'Apply garlic extract spray',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_vegetative.jpg',
    },
    'Cabbages/Kales_Vegetative Growth/Weeding_Flea Beetles': {
      'imagePath': 'assets/pests/cabbage_kale_flea_beetle_vegetative_growth.jpg',
      'possibleStrategies': [
        'Use row covers',
        'Plant trap crops',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Monitor leaf damage',
      ],
      'intervention': 'Apply neem oil to foliage',
      'possibleCauses': [
        'Warm, dry conditions',
        'Weedy fields',
        'Lack of predators',
        'Nearby crucifer crops',
      ],
      'herbicidesPesticides': [
        'Imidacloprid',
        'Spinosad (organic)',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected leaves',
        'Use row covers during vegetative growth',
        'Plant trap crops like radish',
        'Introduce predatory beetles',
        'Apply diatomaceous earth to leaves',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_vegetative.jpg',
    },
    'Cabbages/Kales_Vegetative Growth/Weeding_Rodents': {
      'imagePath': 'assets/pests/cabbage_kale_rodents_vegetative_growth.jpg',
      'possibleStrategies': [
        'Set mechanical traps',
        'Clear vegetation around fields',
        'Use natural repellents',
        'Introduce predators',
        'Use fencing',
      ],
      'intervention': 'Set mechanical traps',
      'possibleCauses': [
        'Food availability',
        'Nearby nesting sites',
        'Unprotected fields',
        'Lack of predators',
      ],
      'herbicidesPesticides': [
        'Bromadiolone',
        'Zinc phosphide',
        'Garlic extract (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Use garlic extract as a repellent',
        'Set mechanical traps around fields',
        'Plant repellent crops like mint',
        'Clear debris to reduce nesting sites',
        'Introduce natural predators like cats',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_vegetative.jpg',
    },
    'Cabbages/Kales_Vegetative Growth/Weeding_Armyworms': {
      'imagePath': 'assets/pests/cabbage_kale_armyworm_vegetative_growth.jpg',
      'possibleStrategies': [
        'Hand-pick larvae',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Use trap crops',
        'Monitor leaves for damage',
      ],
      'intervention': 'Apply Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm, humid conditions',
        'Weedy fields',
        'Lack of predators',
        'Crop residue',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Carbaryl',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to foliage',
        'Hand-pick larvae at night',
        'Use neem oil sprays',
        'Plant trap crops like millet',
        'Introduce predatory birds',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_vegetative.jpg',
    },
    'Cabbages/Kales_Vegetative Growth/Weeding_Cross Stripped Cabbageworm': {
      'imagePath': 'assets/pests/cabbage_kale_cross_stripped_cabbageworm_vegetative_growth.jpg',
      'possibleStrategies': [
        'Hand-pick larvae',
        'Use row covers',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Plant trap crops',
      ],
      'intervention': 'Apply Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm weather',
        'Nearby host plants',
        'Lack of predators',
        'Crop residue',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Spinosad (organic)',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to foliage',
        'Hand-pick larvae from leaves',
        'Use neem oil sprays',
        'Use row covers during vegetative growth',
        'Introduce parasitic wasps',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_vegetative.jpg',
    },
    'Cabbages/Kales_Vegetative Growth/Weeding_Cabbage Webworm': {
      'imagePath': 'assets/pests/cabbage_kale_cabbage_webworm_vegetative_growth.jpg',
      'possibleStrategies': [
        'Hand-pick larvae',
        'Use row covers',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Plant trap crops',
      ],
      'intervention': 'Apply Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm weather',
        'Nearby host plants',
        'Lack of predators',
        'Crop residue',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Spinosad (organic)',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to foliage',
        'Hand-pick larvae from leaves',
        'Use neem oil sprays',
        'Use row covers during vegetative growth',
        'Introduce parasitic wasps',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_vegetative.jpg',
    },
    'Cabbages/Kales_Vegetative Growth/Weeding_Cutworms': {
      'imagePath': 'assets/pests/cabbage_kale_cutworms_vegetative_growth.jpg',
      'possibleStrategies': [
        'Remove crop debris',
        'Use row covers',
        'Apply organic mulch',
        'Hand-pick pests at night',
        'Introduce beneficial insects',
      ],
      'intervention': 'Apply Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Moist, undisturbed soil',
        'Presence of crop residue',
        'Weedy fields',
        'Lack of natural predators',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Permethrin',
        'Bacillus thuringiensis (Bt) (organic)',
        'Spinosad (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to soil',
        'Use row covers at planting',
        'Hand-pick cutworms at night',
        'Apply diatomaceous earth around plants',
        'Introduce predatory insects like ground beetles',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_vegetative.jpg',
    },
    'Cabbages/Kales_Vegetative Growth/Weeding_Cabbage Looper': {
      'imagePath': 'assets/pests/cabbage_kale_cabbage_looper_vegetative_growth.jpg',
      'possibleStrategies': [
        'Hand-pick larvae',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Use trap crops',
        'Monitor leaves for damage',
      ],
      'intervention': 'Apply Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm, humid conditions',
        'Weedy fields',
        'Lack of predators',
        'Crop residue',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Carbaryl',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to foliage',
        'Hand-pick larvae at night',
        'Use neem oil sprays',
        'Plant trap crops like millet',
        'Introduce predatory birds',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_vegetative.jpg',
    },
    'Cabbages/Kales_Vegetative Growth/Weeding_Cabbage Root Maggot': {
      'imagePath': 'assets/pests/cabbage_kale_cabbage_root_maggots_vegetative_growth.jpg',
      'possibleStrategies': [
        'Use row covers',
        'Apply organic mulch',
        'Introduce beneficial nematodes',
        'Rotate crops',
        'Remove crop debris',
      ],
      'intervention': 'Apply beneficial nematodes to soil',
      'possibleCauses': [
        'Cool, wet soil',
        'Presence of crop residue',
        'Weedy fields',
        'Lack of natural predators',
      ],
      'herbicidesPesticides': [
        'Imidacloprid',
        'Spinosad (organic)',
        'Neem oil (organic)',
        'Beneficial nematodes (organic)',
      ],
      'organicInterventions': [
        'Apply beneficial nematodes to soil around plants',
        'Use row covers at planting',
        'Remove crop debris after harvest',
        'Rotate crops to non-host plants',
        'Maintain well-drained soil conditions',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_vegetative.jpg',
    },

    // Cabbages/Kales - Flowering/Reproductive
    'Cabbages/Kales_Flowering/Reproductive_Diamondback Moth': {
      'imagePath': 'assets/pests/cabbage_kale_diamondback_moth_flowering.jpg',
      'possibleStrategies': [
        'Use trap crops',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Monitor flowers for larvae',
        'Use row covers',
      ],
      'intervention': 'Apply Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm, humid conditions',
        'Crop residue',
        'Lack of predators',
        'Nearby crucifer crops',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Lambda-cyhalothrin',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to flowers',
        'Use neem oil sprays',
        'Plant trap crops like mustard',
        'Introduce parasitic wasps',
        'Use row covers during flowering',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_flowering.jpg',
    },
    'Cabbages/Kales_Flowering/Reproductive_Whiteflies': {
      'imagePath': 'assets/pests/cabbage_kale_whiteflies_flowering.jpg',
      'possibleStrategies': [
        'Use yellow sticky traps',
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Plant companion crops',
        'Use reflective mulches',
      ],
      'intervention': 'Apply neem oil to flowers',
      'possibleCauses': [
        'Warm, humid conditions',
        'Overcrowded plants',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Imidacloprid',
        'Pyriproxyfen',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Spinosad (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected flowers',
        'Introduce parasitic wasps',
        'Use yellow sticky traps',
        'Plant marigolds as companion crops',
        'Apply garlic extract spray',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_flowering.jpg',
    },
    'Cabbages/Kales_Flowering/Reproductive_Thrip': {
      'imagePath': 'assets/pests/cabbage_kale_thrips_flowering.jpg',
      'possibleStrategies': [
        'Use reflective mulches',
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Plant companion crops',
        'Monitor flowers for damage',
      ],
      'intervention': 'Apply neem oil to flowers',
      'possibleCauses': [
        'Warm, dry conditions',
        'Overcrowded plants',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Imidacloprid',
        'Spinosad (organic)',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected flowers',
        'Introduce predatory mites',
        'Use reflective mulches around plants',
        'Plant companion crops like marigolds',
        'Apply garlic extract spray',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_flowering.jpg',
    },
      'Cabbages/Kales_Flowering/Reproductive_Cabbage Looper': {
      'imagePath': 'assets/pests/cabbage_kale_cabbage_looper_flowering.jpg',
      'possibleStrategies': [
        'Hand-pick larvae',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Use trap crops',
        'Monitor flowers for damage',
      ],
      'intervention': 'Apply Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm, humid conditions',
        'Weedy fields',
        'Lack of predators',
        'Crop residue',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Carbaryl',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to flowers',
        'Hand-pick larvae at night',
        'Use neem oil sprays',
        'Plant trap crops like millet',
        'Introduce predatory birds',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_flowering.jpg',
    },
    'Cabbages/Kales_Flowering/Reproductive_Armyworm': {
      'imagePath': 'assets/pests/cabbage_kale_armyworm_flowering.jpg',
      'possibleStrategies': [
        'Hand-pick larvae',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Use trap crops',
        'Monitor flowers for damage',
      ],
      'intervention': 'Apply Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm, humid conditions',
        'Weedy fields',
        'Lack of predators',
        'Crop residue',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Carbaryl',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to flowers',
        'Hand-pick larvae at night',
        'Use neem oil sprays',
        'Plant trap crops like millet',
        'Introduce predatory birds',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_flowering.jpg',
    },
    'Cabbages/Kales_Flowering/Reproductive_Aphids': {
      'imagePath': 'assets/pests/cabbage_kale_aphids_flowering.jpg',
      'possibleStrategies': [
        'Introduce beneficial insects',
        'Use neem oil sprays',
        'Plant companion crops like marigolds',
        'Use reflective mulches',
        'Monitor plant health',
      ],
      'intervention': 'Spray neem oil on flowers',
      'possibleCauses': [
        'Warm weather',
        'Overcrowded plants',
        'Lack of natural predators',
        'Excess nitrogen in soil',
      ],
      'herbicidesPesticides': [
        'Malathion',
        'Imidacloprid',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Garlic extract (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected flowers',
        'Introduce ladybugs to control aphid population',
        'Use garlic extract spray',
        'Plant marigolds as companion crops',
        'Apply diatomaceous earth to flowers',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_flowering.jpg',
    },
    'Cabbages/Kales_Flowering/Reproductive_Stink Bug': {
      'imagePath': 'assets/pests/cabbage_kale_stink_bug_flowering.jpg',
      'possibleStrategies': [
        'Hand-pick bugs',
        'Use row covers',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Monitor flowers for damage',
      ],
      'intervention': 'Apply neem oil to flowers',
      'possibleCauses': [
        'Warm weather',
        'Nearby host plants',
        'Lack of predators',
        'Weedy fields',
      ],
      'herbicidesPesticides': [
        'Imidacloprid',
        'Bifenthrin',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected flowers',
        'Hand-pick stink bugs from plants',
        'Use row covers during flowering',
        'Introduce predatory insects like parasitic wasps',
        'Plant trap crops to divert stink bugs',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_flowering.jpg',
    },

    // Cabbages/Kales - Maturation/Harvesting
    'Cabbages/Kales_Maturation/Harvesting_Cabbage Webworm': {
      'imagePath': 'assets/pests/cabbage_kale_cabbage_webworm_harvesting.jpg',
      'possibleStrategies': [
        'Hand-pick larvae',
        'Use row covers',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Plant trap crops',
      ],
      'intervention': 'Apply Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm weather',
        'Nearby host plants',
        'Lack of predators',
        'Crop residue',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Spinosad (organic)',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to heads',
        'Hand-pick larvae from heads',
        'Use neem oil sprays',
        'Use row covers during maturation',
        'Introduce parasitic wasps',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_maturation.jpg',
    },
    'Cabbages/Kales_Maturation/Harvesting_Diamondback Moth': {
      'imagePath': 'assets/pests/cabbage_kale_diamondback_moth_harvesting.jpg',
      'possibleStrategies': [
        'Use trap crops',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Monitor heads for larvae',
        'Use row covers',
      ],
      'intervention': 'Apply Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm, humid conditions',
        'Crop residue',
        'Lack of predators',
        'Nearby crucifer crops',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Lambda-cyhalothrin',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to heads',
        'Use neem oil sprays',
        'Plant trap crops like mustard',
        'Introduce parasitic wasps',
        'Use row covers during maturation',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_maturation.jpg',
    },
    'Cabbages/Kales_Maturation/Harvesting_Rodent': {
      'imagePath': 'assets/pests/cabbage_kale_rodents_harvesting.jpg',
      'possibleStrategies': [
        'Set mechanical traps',
        'Clear vegetation around fields',
        'Use natural repellents',
        'Introduce predators',
        'Use fencing',
      ],
      'intervention': 'Set mechanical traps',
      'possibleCauses': [
        'Mature heads as food source',
        'Nearby nesting sites',
        'Unprotected fields',
        'Lack of predators',
      ],
      'herbicidesPesticides': [
        'Bromadiolone',
        'Zinc phosphide',
        'Garlic extract (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Use garlic extract as a repellent',
        'Set mechanical traps around fields',
        'Plant repellent crops like mint',
        'Clear debris to reduce nesting sites',
        'Introduce natural predators like cats',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_maturation.jpg',
    },

    'Cabbages/Kales_Maturation/Harvesting_Flea Beetle': {
      'imagePath': 'assets/pests/cabbage_kale_flea_beetle_harvesting.jpg',
      'possibleStrategies': [
        'Use row covers',
        'Plant trap crops',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Monitor head damage',
      ],
      'intervention': 'Apply neem oil to heads',
      'possibleCauses': [
        'Warm, dry conditions',
        'Weedy fields',
        'Lack of predators',
        'Nearby crucifer crops',
      ],
      'herbicidesPesticides': [
        'Imidacloprid',
        'Spinosad (organic)',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected heads',
        'Use row covers during maturation',
        'Plant trap crops like radish',
        'Introduce predatory beetles',
        'Apply diatomaceous earth to heads',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_maturation.jpg',
    },
    'Cabbages/Kales_Maturation/Harvesting_Leafminers': {
      'imagePath': 'assets/pests/cabbage_kale_leafminers_harvesting.jpg',
      'possibleStrategies': [
        'Remove affected leaves',
        'Introduce beneficial insects',
        'Use row covers',
        'Apply organic sprays',
        'Monitor heads for damage',
      ],
      'intervention': 'Apply neem oil to heads',
      'possibleCauses': [
        'Warm weather',
        'Presence of crop residue',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Imidacloprid',
        'Spinosad (organic)',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected heads',
        'Introduce parasitic wasps',
        'Use row covers during maturation',
        'Remove and destroy affected leaves',
        'Apply garlic extract spray',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_maturation.jpg',
    },
    'Cabbages/Kales_Maturation/Harvesting_Cabbage Looper': {
      'imagePath': 'assets/pests/cabbage_kale_cabbage_looper_harvesting.jpg',
      'possibleStrategies': [
        'Hand-pick larvae',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Use trap crops',
        'Monitor heads for damage',
      ],
      'intervention': 'Apply Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm, humid conditions',
        'Weedy fields',
        'Lack of predators',
        'Crop residue',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Carbaryl',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to heads',
        'Hand-pick larvae at night',
        'Use neem oil sprays',
        'Plant trap crops like millet',
        'Introduce predatory birds',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_maturation.jpg',
    },
    'Cabbages/Kales_Maturation/Harvesting_Armyworm': {
      'imagePath': 'assets/pests/cabbage_kale_armyworm_harvesting.jpg',
      'possibleStrategies': [
        'Hand-pick larvae',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Use trap crops',
        'Monitor heads for damage',
      ],
      'intervention': 'Apply Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm, humid conditions',
        'Weedy fields',
        'Lack of predators',
        'Crop residue',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Carbaryl',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to heads',
        'Hand-pick larvae at night',
        'Use neem oil sprays',
        'Plant trap crops like millet',
        'Introduce predatory birds',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_maturation.jpg',
    },
    'Cabbages/Kales_Maturation/Harvesting_Stink Bug': {
      'imagePath': 'assets/pests/cabbage_kale_stink_bug_harvesting.jpg',
      'possibleStrategies': [
        'Hand-pick bugs',
        'Use row covers',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Monitor heads for damage',
      ],
      'intervention': 'Apply neem oil to heads',
      'possibleCauses': [
        'Warm weather',
        'Nearby host plants',
        'Lack of predators',
        'Weedy fields',
      ],
      'herbicidesPesticides': [
        'Imidacloprid',
        'Bifenthrin',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected heads',
        'Hand-pick stink bugs from plants',
        'Use row covers during maturation',
        'Introduce predatory insects like parasitic wasps',
        'Plant trap crops to divert stink bugs',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_maturation.jpg',
    },
    // Cabbages/Kales - Storage
    'Cabbages/Kales_Storage_Rodents': {
      'imagePath': 'assets/pests/cabbage_kale_rodents_storage.jpg',
      'possibleStrategies': [
        'Store in rodent-proof containers',
        'Set mechanical traps',
        'Use natural repellents',
        'Ensure proper storage conditions',
        'Introduce predators',
      ],
      'intervention': 'Use rodent-proof containers',
      'possibleCauses': [
        'Food availability',
        'Poor storage facilities',
        'Nearby nesting sites',
        'Lack of predators',
      ],
      'herbicidesPesticides': [
        'Bromadiolone',
        'Zinc phosphide',
        'Garlic extract (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Use garlic extract as a repellent',
        'Store in metal or rodent-proof containers',
        'Set mechanical traps in storage areas',
        'Clear debris around storage',
        'Introduce natural predators like cats',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_storage.jpg',
    },
    'Cabbages/Kales_Storage_Whiteflies': {
      'imagePath': 'assets/pests/cabbage_kale_whiteflies_storage.jpg',
      'possibleStrategies': [
        'Use yellow sticky traps',
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Ensure proper ventilation',
        'Monitor stored produce',
      ],
      'intervention': 'Use yellow sticky traps in storage',
      'possibleCauses': [
        'Warm, humid conditions',
        'Poor ventilation',
        'Nearby host plants',
        'Lack of predators',
      ],
      'herbicidesPesticides': [
        'Imidacloprid',
        'Pyriproxyfen',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Spinosad (organic)',
      ],
      'organicInterventions': [
        'Use yellow sticky traps in storage areas',
        'Introduce parasitic wasps if feasible',
        'Ensure good ventilation to reduce humidity',
        'Regularly inspect stored produce for damage',
        'Apply garlic extract spray if needed',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_storage.jpg',
    },
    'Cabbages/Kales_Storage_Aphids': {
      'imagePath': 'assets/pests/cabbage_kale_aphids_storage.jpg',
      'possibleStrategies': [
        'Introduce beneficial insects',
        'Use neem oil sprays',
        'Ensure proper storage conditions',
        'Monitor stored produce',
        'Maintain cleanliness',
      ],
      'intervention': 'Spray neem oil on stored produce',
      'possibleCauses': [
        'Warm conditions',
        'Poor storage hygiene',
        'Nearby host plants',
        'Lack of predators',
      ],
      'herbicidesPesticides': [
        'Malathion',
        'Imidacloprid',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Garlic extract (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected stored produce',
        'Introduce ladybugs if feasible',
        'Maintain cleanliness in storage areas',
        'Ensure good ventilation to reduce humidity',
        'Apply garlic extract spray if needed',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_storage.jpg',
    },

    // ===== TOMATOES PESTS =====
    // Tomatoes - Germination/Seedling
    'Tomatoes_Germination/Seedling_Cutworms': {
      'imagePath': 'assets/pests/tomatoes_cutworm_germination.jpg',
      'possibleStrategies': [
        'Remove crop debris',
        'Use row covers',
        'Apply organic mulch',
        'Hand-pick pests at night',
        'Introduce beneficial insects',
      ],
      'intervention': 'Apply Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Moist, undisturbed soil',
        'Presence of crop residue',
        'Weedy fields',
        'Lack of natural predators',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Permethrin',
        'Bacillus thuringiensis (Bt) (organic)',
        'Spinosad (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to soil',
        'Use row covers at planting',
        'Hand-pick cutworms at night',
        'Apply diatomaceous earth around seedlings',
        'Introduce predatory insects like ground beetles',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_germination.jpg',
    },
    'Tomatoes_Germination/Seedling_Rodents': {
      'imagePath': 'assets/pests/tomatoes_rodents_germination.jpg',
      'possibleStrategies': [
        'Set mechanical traps',
        'Clear vegetation around fields',
        'Use natural repellents',
        'Introduce predators like cats',
        'Use fencing',
      ],
      'intervention': 'Set mechanical traps',
      'possibleCauses': [
        'Availability of food sources',
        'Nearby nesting sites',
        'Unprotected fields',
        'Lack of predators',
      ],
      'herbicidesPesticides': [
        'Bromadiolone',
        'Zinc phosphide',
        'Garlic extract (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Use garlic extract as a repellent',
        'Set mechanical traps around fields',
        'Plant repellent crops like mint',
        'Clear debris to reduce nesting sites',
        'Introduce natural predators like cats',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_germination.jpg',
    },
    'Tomatoes_Germination/Seedling_Nematodes': {
      'imagePath': 'assets/pests/tomatoes_nematodes_germination.jpg',
      'possibleStrategies': [
        'Use nematode-resistant varieties',
        'Apply beneficial nematodes',
        'Rotate crops',
        'Solarize soil',
        'Maintain healthy soil',
      ],
      'intervention': 'Apply beneficial nematodes to soil',
      'possibleCauses': [
        'Infested soil',
        'Warm soil temperatures',
        'Poor crop rotation',
        'Susceptible plant varieties',
      ],
      'herbicidesPesticides': [
        'Fumigants like 1,3-Dichloropropene',
        'Beneficial nematodes (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply beneficial nematodes to soil around seedlings',
        'Use solarization to reduce nematode populations',
        'Rotate crops to non-host plants',
        'Maintain healthy soil with organic matter',
        'Plant nematode-resistant tomato varieties',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_germination.jpg',
    },
    'Tomatoes_Germination/Seedling_Termites': {
      'imagePath': 'assets/pests/tomatoes_termites_germination.jpg',
      'possibleStrategies': [
        'Remove wood debris',
        'Use bait stations',
        'Apply natural repellents',
        'Maintain dry soil conditions',
        'Introduce predators',
      ],
      'intervention': 'Use termite bait stations',
      'possibleCauses': [
        'Presence of wood debris',
        'Moist soil conditions',
        'Nearby termite colonies',
        'Lack of natural predators',
      ],
      'herbicidesPesticides': [
        'Termiticides like Fipronil',
        'Bait stations (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Set up termite bait stations around fields',
        'Remove wood debris from planting areas',
        'Maintain dry soil conditions to deter termites',
        'Introduce natural predators like ants',
        'Use neem oil as a repellent if needed',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_germination.jpg',
    },

    // Tomatoes - Vegetative Growth/Weeding
    'Tomatoes_Vegetative Growth/Weeding_Aphids': {
      'imagePath': 'assets/pests/tomatoes_aphids_vegetative_growth.jpg',
      'possibleStrategies': [
        'Introduce beneficial insects',
        'Use neem oil sprays',
        'Plant companion crops like marigolds',
        'Use reflective mulches',
        'Monitor plant health',
      ],
      'intervention': 'Spray neem oil on foliage',
      'possibleCauses': [
        'Warm weather',
        'Overcrowded plants',
        'Lack of natural predators',
        'Excess nitrogen in soil',
      ],
      'herbicidesPesticides': [
        'Malathion',
        'Imidacloprid',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Garlic extract (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected leaves',
        'Introduce ladybugs to control aphid population',
        'Use garlic extract spray',
        'Plant marigolds as companion crops',
        'Apply diatomaceous earth to leaves',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_vegetative.jpg',
    },
    'Tomatoes_Vegetative Growth/Weeding_Whiteflies': {
      'imagePath': 'assets/pests/tomatoes_whiteflies_vegetative_growth.jpg',
      'possibleStrategies': [
        'Use yellow sticky traps',
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Plant companion crops',
        'Use reflective mulches',
      ],
      'intervention': 'Apply neem oil to foliage',
      'possibleCauses': [
        'Warm, humid conditions',
        'Overcrowded plants',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Imidacloprid',
        'Pyriproxyfen',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Spinosad (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected leaves',
        'Introduce parasitic wasps',
        'Use yellow sticky traps',
        'Plant marigolds as companion crops',
        'Apply garlic extract spray',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_vegetative.jpg',
    },
    'Tomatoes_Vegetative Growth/Weeding_Tomato Hornworms': {
      'imagePath': 'assets/pests/tomatoes_hornworm_vegetative_growth.jpg',
      'possibleStrategies': [
        'Hand-pick larvae',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Use row covers',
        'Plant trap crops',
      ],
      'intervention': 'Apply Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm weather',
        'Nearby host plants',
        'Lack of predators',
        'Crop residue',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Spinosad (organic)',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to foliage',
        'Hand-pick hornworms from leaves',
        'Use neem oil sprays',
        'Introduce parasitic wasps',
        'Plant trap crops like dill',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_vegetative.jpg',
    },
    'Tomatoes_Vegetative Growth/Weeding_Spider Mites': {
      'imagePath': 'assets/pests/tomatoes_spider_mites_vegetative_growth.jpg',
      'possibleStrategies': [
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Maintain adequate irrigation',
        'Use reflective mulches',
        'Monitor leaves for webbing',
      ],
      'intervention': 'Apply neem oil to foliage',
      'possibleCauses': [
        'Hot, dry conditions',
        'Dust on leaves',
        'Lack of predators',
        'Overcrowded plants',
      ],
      'herbicidesPesticides': [
        'Abamectin',
        'Spinosad (organic)',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected leaves',
        'Introduce predatory mites',
        'Use garlic extract spray',
        'Maintain high humidity around plants',
        'Apply diatomaceous earth to leaves',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_vegetative.jpg',
    },
    'Tomatoes_Vegetative Growth/Weeding_Leafminers': {
      'imagePath': 'assets/pests/tomatoes_leafminers_vegetative_growth.jpg',
      'possibleStrategies': [
        'Use yellow sticky traps',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Remove affected leaves',
        'Plant trap crops',
      ],
      'intervention': 'Apply spinosad to foliage',
      'possibleCauses': [
        'Warm weather',
        'Nearby host plants',
        'Lack of predators',
        'Crop residue',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Abamectin',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Apply spinosad to affected leaves',
        'Introduce parasitic wasps',
        'Use yellow sticky traps',
        'Remove and destroy affected leaves',
        'Plant trap crops like marigolds',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_vegetative.jpg',
    },
    'Tomatoes_Vegetative Growth/Weeding_Rodents': {
      'imagePath': 'assets/pests/tomatoes_rodents_vegetative_growth.jpg',
      'possibleStrategies': [
        'Set mechanical traps',
        'Clear vegetation around fields',
        'Use natural repellents',
        'Introduce predators',
        'Use fencing',
      ],
      'intervention': 'Set mechanical traps',
      'possibleCauses': [
        'Food availability',
        'Nearby nesting sites',
        'Unprotected fields',
        'Lack of predators',
      ],
      'herbicidesPesticides': [
        'Bromadiolone',
        'Zinc phosphide',
        'Garlic extract (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Use garlic extract as a repellent',
        'Set mechanical traps around fields',
        'Plant repellent crops like mint',
        'Clear debris to reduce nesting sites',
        'Introduce natural predators like cats',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_vegetative.jpg',
    },
    'Tomatoes_Vegetative Growth/Weeding_Thrips': {
      'imagePath': 'assets/pests/tomatoes_thrips_vegetative_growth.jpg',
      'possibleStrategies': [
        'Use reflective mulches',
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Maintain plant health',
        'Use crop rotation',
      ],
      'intervention': 'Apply spinosad to foliage',
      'possibleCauses': [
        'Hot, dry conditions',
        'Weedy fields',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Imidacloprid',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Apply spinosad to affected leaves',
        'Introduce predatory insects like minute pirate bugs',
        'Use reflective mulches around plants',
        'Maintain plant health with proper fertilization',
        'Rotate crops to disrupt thrip life cycle',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_vegetative.jpg',
    },
    'Tomatoes_Vegetative Growth/Weeding_Spidermites': {
      'imagePath': 'assets/pests/tomatoes_spider_mites_vegetative_growth.jpg',
      'possibleStrategies': [
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Maintain adequate irrigation',
        'Use reflective mulches',
        'Monitor leaves for webbing',
      ],
      'intervention': 'Apply neem oil to foliage',
      'possibleCauses': [
        'Hot, dry conditions',
        'Dust on leaves',
        'Lack of predators',
        'Overcrowded plants',
      ],
      'herbicidesPesticides': [
        'Abamectin',
        'Spinosad (organic)',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected leaves',
        'Introduce predatory mites',
        'Use garlic extract spray',
        'Maintain high humidity around plants',
        'Apply diatomaceous earth to leaves',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_vegetative.jpg',
    },
    'Tomatoes_Vegetative Growth/Weeding_Beet Armyworm': {
      'imagePath': 'assets/pests/tomatoes_beet_armyworm_vegetative_growth.jpg',
      'possibleStrategies': [
        'Hand-pick larvae',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Use trap crops',
        'Monitor plants for damage',
      ],
      'intervention': 'Apply Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm, humid conditions',
        'Weedy fields',
        'Lack of predators',
        'Crop residue',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Carbaryl',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to foliage',
        'Hand-pick larvae at night',
        'Use neem oil sprays',
        'Plant trap crops like millet',
        'Introduce predatory birds',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_vegetative.jpg',
    },
    'Tomatoes_Vegetative Growth/Weeding_Nematodes': {
      'imagePath': 'assets/pests/tomatoes_nematodes_vegetative_growth.jpg',
      'possibleStrategies': [
        'Use nematode-resistant varieties',
        'Apply beneficial nematodes',
        'Rotate crops',
        'Solarize soil',
        'Maintain healthy soil',
      ],
      'intervention': 'Apply beneficial nematodes to soil',
      'possibleCauses': [
        'Infested soil',
        'Warm soil temperatures',
        'Poor crop rotation',
        'Susceptible plant varieties',
      ],
      'herbicidesPesticides': [
        'Fumigants like 1,3-Dichloropropene',
        'Beneficial nematodes (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply beneficial nematodes to soil around plants',
        'Use solarization to reduce nematode populations',
        'Rotate crops to non-host plants',
        'Maintain healthy soil with organic matter',
        'Plant nematode-resistant tomato varieties',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_vegetative.jpg',
    },

    // Tomatoes - Flowering/Reproductive
    'Tomatoes_Flowering/Reproductive_Aphids': {
      'imagePath': 'assets/pests/tomatoes_aphids_flowering.jpg',
      'possibleStrategies': [
        'Introduce beneficial insects',
        'Use neem oil sprays',
        'Plant companion crops',
        'Use reflective mulches',
        'Monitor flower buds',
      ],
      'intervention': 'Spray neem oil on flowers',
      'possibleCauses': [
        'Warm weather',
        'Overcrowded plants',
        'Lack of natural predators',
        'Excess nitrogen in soil',
      ],
      'herbicidesPesticides': [
        'Malathion',
        'Imidacloprid',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Garlic extract (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected flowers',
        'Introduce ladybugs to control aphids',
        'Use garlic extract spray',
        'Plant marigolds as companion crops',
        'Apply diatomaceous earth to flowers',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_flowering.jpg',
    },
    'Tomatoes_Flowering/Reproductive_Whiteflies': {
      'imagePath': 'assets/pests/tomatoes_whiteflies_flowering.jpg',
      'possibleStrategies': [
        'Use yellow sticky traps',
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Plant companion crops',
        'Use reflective mulches',
      ],
      'intervention': 'Apply neem oil to flowers',
      'possibleCauses': [
        'Warm, humid conditions',
        'Overcrowded plants',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Imidacloprid',
        'Pyriproxyfen',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Spinosad (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected flowers',
        'Introduce parasitic wasps',
        'Use yellow sticky traps',
        'Plant marigolds as companion crops',
        'Apply garlic extract spray',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_flowering.jpg',
    },
    'Tomatoes_Flowering/Reproductive_Tomato Hornworms': {
      'imagePath': 'assets/pests/tomatoes_hornworm_flowering.jpg',
      'possibleStrategies': [
        'Hand-pick larvae',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Use row covers',
        'Plant trap crops',
      ],
      'intervention': 'Apply Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm weather',
        'Nearby host plants',
        'Lack of predators',
        'Crop residue',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Spinosad (organic)',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to flowers',
        'Hand-pick hornworms from flowers',
        'Use neem oil sprays',
        'Introduce parasitic wasps',
        'Plant trap crops like dill',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_flowering.jpg',
    },
    'Tomatoes_Flowering/Reproductive_Spider Mites': {
      'imagePath': 'assets/pests/tomatoes_spider_mites_flowering.jpg',
      'possibleStrategies': [
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Maintain adequate irrigation',
        'Use reflective mulches',
        'Monitor flowers for webbing',
      ],
      'intervention': 'Apply neem oil to flowers',
      'possibleCauses': [
        'Hot, dry conditions',
        'Dust on leaves',
        'Lack of predators',
        'Overcrowded plants',
      ],
      'herbicidesPesticides': [
        'Abamectin',
        'Spinosad (organic)',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected flowers',
        'Introduce predatory mites',
        'Use garlic extract spray',
        'Maintain high humidity around plants',
        'Apply diatomaceous earth to flowers',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_flowering.jpg',
    },
    'Tomatoes_Flowering/Reproductive_Thrips': {
      'imagePath': 'assets/pests/tomatoes_thrips_flowering.jpg',
      'possibleStrategies': [
        'Use reflective mulches',
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Maintain plant health',
        'Use crop rotation',
      ],
      'intervention': 'Apply spinosad to flowers',
      'possibleCauses': [
        'Hot, dry conditions',
        'Weedy fields',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Imidacloprid',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Apply spinosad to affected flowers',
        'Introduce predatory mites',
        'Use neem oil sprays',
        'Plant companion crops like marigolds',
        'Use reflective mulches to deter thrips',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_flowering.jpg',
    },
    'Tomatoes_Flowering/Reproductive_Leafminers': {
      'imagePath': 'assets/pests/tomatoes_leafminers_flowering.jpg',
      'possibleStrategies': [
        'Use yellow sticky traps',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Remove affected leaves',
        'Plant trap crops',
      ],
      'intervention': 'Apply spinosad to foliage',
      'possibleCauses': [
        'Warm weather',
        'Nearby host plants',
        'Lack of predators',
        'Crop residue',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Abamectin',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Apply spinosad to affected leaves',
        'Introduce parasitic wasps',
        'Use yellow sticky traps',
        'Remove and destroy affected leaves',
        'Plant trap crops like marigolds',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_flowering.jpg',
    },
    'Tomatoes_Flowering/Reproductive_Beet Armyworm': {
      'imagePath': 'assets/pests/tomatoes_beet_armyworm_flowering.jpg',
      'possibleStrategies': [
        'Hand-pick larvae',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Use trap crops',
        'Monitor plants for damage',
      ],
      'intervention': 'Apply Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm, humid conditions',
        'Weedy fields',
        'Lack of predators',
        'Crop residue',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Carbaryl',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to foliage',
        'Hand-pick larvae at night',
        'Use neem oil sprays',
        'Plant trap crops like millet',
        'Introduce predatory birds',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_flowering.jpg',
    },
    'Tomatoes_Flowering/Reproductive_Rodents': {
      'imagePath': 'assets/pests/tomatoes_rodents_flowering.jpg',
      'possibleStrategies': [
        'Set mechanical traps',
        'Clear vegetation around fields',
        'Use natural repellents',
        'Introduce predators',
        'Use fencing',
      ],
      'intervention': 'Set mechanical traps',
      'possibleCauses': [
        'Food availability',
        'Nearby nesting sites',
        'Unprotected fields',
        'Lack of predators',
      ],
      'herbicidesPesticides': [
        'Bromadiolone',
        'Zinc phosphide',
        'Garlic extract (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Use garlic extract as a repellent',
        'Set mechanical traps around fields',
        'Plant repellent crops like mint',
        'Clear debris to reduce nesting sites',
        'Introduce natural predators like cats',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_flowering.jpg',
    },
    'Tomatoes_Flowering/Reproductive_Nematodes': {
      'imagePath': 'assets/pests/tomatoes_nematodes_flowering.jpg',
      'possibleStrategies': [
        'Use nematode-resistant varieties',
        'Apply beneficial nematodes',
        'Rotate crops',
        'Solarize soil',
        'Maintain healthy soil',
      ],
      'intervention': 'Apply beneficial nematodes to soil',
      'possibleCauses': [
        'Infested soil',
        'Warm soil temperatures',
        'Poor crop rotation',
        'Susceptible plant varieties',
      ],
      'herbicidesPesticides': [
        'Fumigants like 1,3-Dichloropropene',
        'Beneficial nematodes (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply beneficial nematodes to soil around plants',
        'Use solarization to reduce nematode populations',
        'Rotate crops to non-host plants',
        'Maintain healthy soil with organic matter',
        'Plant nematode-resistant tomato varieties',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_flowering.jpg',
    },
    'Tomatoes_Flowering/Reproductive_Stink Bugs': {
      'imagePath': 'assets/pests/tomatoes_stink_bugs_flowering.jpg',
      'possibleStrategies': [
        'Hand-pick bugs',
        'Use row covers',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Plant trap crops',
      ],
      'intervention': 'Spray neem oil on flowers',
      'possibleCauses': [
        'Warm weather',
        'Nearby host plants',
        'Lack of predators',
        'Weedy fields',
      ],
      'herbicidesPesticides': [
        'Malathion',
        'Imidacloprid',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Carbaryl',
      ],
      'organicInterventions': [
        'Spray neem oil on affected flowers',
        'Hand-pick stink bugs from plants',
        'Use row covers during flowering',
        'Introduce predatory insects like parasitic wasps',
        'Plant trap crops to divert stink bugs',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_flowering.jpg',
    },
    'Tomatoes_Flowering/Reproductive_Fruit Borers': {
      'imagePath': 'assets/pests/tomatoes_fruit_borers_flowering.jpg',
      'possibleStrategies': [
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Use trap crops',
        'Monitor flowers for damage',
        'Hand-pick larvae',
      ],
      'intervention': 'Apply Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm weather',
        'Crop residue',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Spinosad (organic)',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to flowers',
        'Use neem oil sprays on flowers',
        'Plant trap crops like corn',
        'Hand-pick larvae from flowers',
        'Introduce parasitic wasps',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_flowering.jpg',
    },
    'Tomatoes_Flowering/Reproductive_Bollworms': {
      'imagePath': 'assets/pests/tomatoes_bollworm_flowering.jpg',
      'possibleStrategies': [
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Use trap crops',
        'Monitor flowers for damage',
        'Hand-pick larvae',
      ],
      'intervention': 'Apply Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm weather',
        'Crop residue',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Spinosad (organic)',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to flowers',
        'Use neem oil sprays on flowers',
        'Plant trap crops like corn',
        'Hand-pick larvae from flowers',
        'Introduce parasitic wasps',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_flowering.jpg',
    },

    // Tomatoes - Maturation/Harvesting
    'Tomatoes_Maturation/Harvesting_Aphids': {
      'imagePath': 'assets/pests/tomatoes_aphids_harvesting.jpg',
      'possibleStrategies': [
        'Introduce beneficial insects',
        'Use neem oil sprays',
        'Plant companion crops',
        'Use reflective mulches',
        'Monitor fruits for aphids',
      ],
      'intervention': 'Spray neem oil on fruits',
      'possibleCauses': [
        'Warm weather',
        'Overcrowded plants',
        'Lack of natural predators',
        'Excess nitrogen in soil',
      ],
      'herbicidesPesticides': [
        'Malathion',
        'Imidacloprid',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Garlic extract (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected fruits',
        'Introduce ladybugs to control aphids',
        'Use garlic extract spray',
        'Plant marigolds as companion crops',
        'Apply diatomaceous earth to fruits',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_maturation.jpg',
    },
    'Tomatoes_Maturation/Harvesting_Whiteflies': {
      'imagePath': 'assets/pests/tomatoes_whiteflies_harvesting.jpg',
      'possibleStrategies': [
        'Use yellow sticky traps',
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Plant companion crops',
        'Use reflective mulches',
      ],
      'intervention': 'Apply neem oil to fruits',
      'possibleCauses': [
        'Warm, humid conditions',
        'Overcrowded plants',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Imidacloprid',
        'Pyriproxyfen',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Spinosad (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected fruits',
        'Introduce parasitic wasps',
        'Use yellow sticky traps',
        'Plant marigolds as companion crops',
        'Apply garlic extract spray',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_maturation.jpg',
    },
    'Tomatoes_Maturation/Harvesting_Spider Mites': {
      'imagePath': 'assets/pests/tomatoes_spider_mites_harvesting.jpg',
      'possibleStrategies': [
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Maintain adequate irrigation',
        'Use reflective mulches',
        'Monitor fruits for webbing',
      ],
      'intervention': 'Apply neem oil to fruits',
      'possibleCauses': [
        'Hot, dry conditions',
        'Dust on leaves',
        'Lack of predators',
        'Overcrowded plants',
      ],
      'herbicidesPesticides': [
        'Abamectin',
        'Spinosad (organic)',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected fruits',
        'Introduce predatory mites',
        'Use garlic extract spray',
        'Maintain high humidity around plants',
        'Apply diatomaceous earth to fruits',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_maturation.jpg',
    },
    'Tomatoes_Maturation/Harvesting_Rodents': {
      'imagePath': 'assets/pests/tomatoes_rodents_harvesting.jpg',
      'possibleStrategies': [
        'Set mechanical traps',
        'Clear vegetation around fields',
        'Use natural repellents',
        'Introduce predators',
        'Use fencing',
      ],
      'intervention': 'Set mechanical traps',
      'possibleCauses': [
        'Ripe fruits as food source',
        'Nearby nesting sites',
        'Unprotected fields',
        'Lack of predators',
      ],
      'herbicidesPesticides': [
        'Bromadiolone',
        'Zinc phosphide',
        'Garlic extract (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Use garlic extract as a repellent',
        'Set mechanical traps around fields',
        'Plant repellent crops like mint',
        'Clear debris to reduce nesting sites',
        'Introduce natural predators like cats',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_maturation.jpg',
    },
    'Tomatoes_Maturation/Harvesting_Thrips': {
      'imagePath': 'assets/pests/tomatoes_thrips_harvesting.jpg',
      'possibleStrategies': [
        'Use reflective mulches',
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Maintain plant health',
        'Use crop rotation',
      ],
      'intervention': 'Apply spinosad to fruits',
      'possibleCauses': [
        'Hot, dry conditions',
        'Weedy fields',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Imidacloprid',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Apply spinosad to affected fruits',
        'Introduce predatory mites',
        'Use neem oil sprays',
        'Plant companion crops like marigolds',
        'Use reflective mulches to deter thrips',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_maturation.jpg',
    },
    'Tomatoes_Maturation/Harvesting_Leafminers': {
      'imagePath': 'assets/pests/tomatoes_leafminers_harvesting.jpg',
      'possibleStrategies': [
        'Use yellow sticky traps',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Remove affected leaves',
        'Plant trap crops',
      ],
      'intervention': 'Apply spinosad to foliage',
      'possibleCauses': [
        'Warm weather',
        'Nearby host plants',
        'Lack of predators',
        'Crop residue',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Abamectin',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Apply spinosad to affected leaves',
        'Introduce parasitic wasps',
        'Use yellow sticky traps',
        'Remove and destroy affected leaves',
        'Plant trap crops like marigolds',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_maturation.jpg',
    },
    'Tomatoes_Maturation/Harvesting_Beet Armyworm': {
      'imagePath': 'assets/pests/tomatoes_beet_armyworm_harvesting.jpg',
      'possibleStrategies': [
        'Hand-pick larvae',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Use trap crops',
        'Monitor plants for damage',
      ],
      'intervention': 'Apply Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm, humid conditions',
        'Weedy fields',
        'Lack of predators',
        'Crop residue',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Carbaryl',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to foliage',
        'Hand-pick larvae at night',
        'Use neem oil sprays',
        'Plant trap crops like millet',
        'Introduce predatory birds',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_maturation.jpg',
    },
    'Tomatoes_Maturation/Harvesting_Nematodes': {
      'imagePath': 'assets/pests/tomatoes_nematodes_harvesting.jpg',
      'possibleStrategies': [
        'Use nematode-resistant varieties',
        'Apply beneficial nematodes',
        'Rotate crops',
        'Solarize soil',
        'Maintain healthy soil',
      ],
      'intervention': 'Apply beneficial nematodes to soil',
      'possibleCauses': [
        'Infested soil',
        'Warm soil temperatures',
        'Poor crop rotation',
        'Susceptible plant varieties',
      ],
      'herbicidesPesticides': [
        'Fumigants like 1,3-Dichloropropene',
        'Beneficial nematodes (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply beneficial nematodes to soil around plants',
        'Use solarization to reduce nematode populations',
        'Rotate crops to non-host plants',
        'Maintain healthy soil with organic matter',
        'Plant nematode-resistant tomato varieties',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_maturation.jpg',
    },
    'Tomatoes_Maturation/Harvesting_Stink Bugs': {
      'imagePath': 'assets/pests/tomatoes_stink_bugs_harvesting.jpg',
      'possibleStrategies': [
        'Hand-pick bugs',
        'Use row covers',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Plant trap crops',
      ],
      'intervention': 'Spray neem oil on fruits',
      'possibleCauses': [
        'Warm weather',
        'Nearby host plants',
        'Lack of predators',
        'Weedy fields',
      ],
      'herbicidesPesticides': [
        'Malathion',
        'Imidacloprid',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Carbaryl',
      ],
      'organicInterventions': [
        'Spray neem oil on affected fruits',
        'Hand-pick stink bugs from plants',
        'Use row covers during flowering',
        'Introduce predatory insects like parasitic wasps',
        'Plant trap crops to divert stink bugs',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_maturation.jpg',
    },
    'Tomatoes_Maturation/Harvesting_Fruit Borers': {
      'imagePath': 'assets/pests/tomatoes_fruit_borers_harvesting.jpg',
      'possibleStrategies': [
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Use trap crops',
        'Monitor fruits for damage',
        'Hand-pick larvae',
      ],
      'intervention': 'Apply Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm weather',
        'Crop residue',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Spinosad (organic)',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to fruits',
        'Use neem oil sprays on fruits',
        'Plant trap crops like corn',
        'Hand-pick larvae from fruits',
        'Introduce parasitic wasps',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_maturation.jpg',
    },
    'Tomatoes_Maturation/Harvesting_Bollworms': {
      'imagePath': 'assets/pests/tomatoes_bollworm_harvesting.jpg',
      'possibleStrategies': [
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Use trap crops',
        'Monitor fruits for damage',
        'Hand-pick larvae',
      ],
      'intervention': 'Apply Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm weather',
        'Crop residue',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Spinosad (organic)',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to fruits',
        'Use neem oil sprays on fruits',
        'Plant trap crops like corn',
        'Hand-pick larvae from fruits',
        'Introduce parasitic wasps',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_maturation.jpg',
    },
    'Tomatoes_Maturation/Harvesting_Fruitflies': {
      'imagePath': 'assets/pests/tomatoes_fruitflies_harvesting.jpg',
      'possibleStrategies': [
        'Use baited traps',
        'Remove fallen fruits',
        'Introduce beneficial insects',
        'Use row covers',
        'Monitor fruits for damage',
      ],
      'intervention': 'Set baited traps around plants',
      'possibleCauses': [
        'Warm weather',
        'Ripe fruits',
        'Nearby host plants',
        'Lack of predators',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Malathion',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Set baited traps with spinosad',
        'Remove and destroy fallen fruits promptly',
        'Introduce parasitic wasps',
        'Use row covers to protect fruits',
        'Apply neem oil sprays on fruits',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_maturation.jpg',
    },
    'Tomatoes_Maturation/Harvesting_Tomato Hornworms': {
      'imagePath': 'assets/pests/tomatoes_hornworm_harvesting.jpg',
      'possibleStrategies': [
        'Hand-pick larvae',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Use row covers',
        'Plant trap crops',
      ],
      'intervention': 'Apply Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm weather',
        'Nearby host plants',
        'Lack of predators',
        'Crop residue',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Spinosad (organic)',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to fruits',
        'Hand-pick hornworms from fruits',
        'Use neem oil sprays',
        'Introduce parasitic wasps',
        'Plant trap crops like dill',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_maturation.jpg',
    },

    // Tomatoes - Storage
    'Tomatoes_Storage_Rodents': {
      'imagePath': 'assets/pests/tomatoes_rodents_storage.jpg',
      'possibleStrategies': [
        'Store in rodent-proof containers',
        'Set mechanical traps',
        'Use natural repellents',
        'Ensure proper storage conditions',
        'Introduce predators',
      ],
      'intervention': 'Use rodent-proof containers',
      'possibleCauses': [
        'Food availability',
        'Poor storage facilities',
        'Nearby nesting sites',
        'Lack of predators',
      ],
      'herbicidesPesticides': [
        'Bromadiolone',
        'Zinc phosphide',
        'Garlic extract (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Use garlic extract as a repellent',
        'Store in metal or rodent-proof containers',
        'Set mechanical traps in storage areas',
        'Clear debris around storage',
        'Introduce natural predators like cats',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_storage.jpg',
    },
    'Tomatoes_Storage_Fruit Flies': {
      'imagePath': 'assets/pests/tomatoes_fruitflies_storage.jpg',
      'possibleStrategies': [
        'Use baited traps',
        'Maintain proper hygiene',
        'Store in sealed containers',
        'Monitor storage areas',
        'Introduce beneficial insects',
      ],
      'intervention': 'Set baited traps in storage area',
      'possibleCauses': [
        'Ripe or overripe fruits',
        'Poor sanitation',
        'Warm storage conditions',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Malathion',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Set baited traps with spinosad in storage areas',
        'Maintain cleanliness and remove spoiled fruits',
        'Store tomatoes in sealed containers',
        'Introduce parasitic wasps if feasible',
        'Apply neem oil sprays around storage area',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_storage.jpg',
    },
    'Tomatoes_Storage_Fruit Borers': {
      'imagePath': 'assets/pests/tomatoes_fruit_borers_storage.jpg',
      'possibleStrategies': [
        'Inspect fruits before storage',
        'Use sealed containers',
        'Maintain proper hygiene',
        'Monitor storage areas',
        'Apply organic treatments if needed',
      ],
      'intervention': 'Inspect and remove infested fruits',
      'possibleCauses': [
        'Infested fruits',
        'Poor storage conditions',
        'Warm, humid environment',
        'Lack of monitoring',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Spinosad (organic)',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Inspect and remove any infested fruits before storage',
        'Store tomatoes in sealed containers',
        'Maintain cleanliness in storage areas',
        'Apply neem oil sprays around storage area if needed',
        'Monitor regularly for signs of infestation',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_storage.jpg',
    },
    'Tomatoes_Storage_Stink Bugs': {
      'imagePath': 'assets/pests/tomatoes_stink_bugs_storage.jpg',
      'possibleStrategies': [
        'Store in sealed containers',
        'Set mechanical traps',
        'Maintain proper hygiene',
        'Use natural repellents',
        'Monitor storage areas',
      ],
      'intervention': 'Store in sealed containers',
      'possibleCauses': [
        'Infested fruits',
        'Poor storage conditions',
        'Warm, humid environment',
        'Lack of monitoring',
      ],
      'herbicidesPesticides': [
        'Malathion',
        'Imidacloprid',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Carbaryl',
      ],
      'organicInterventions': [
        'Store tomatoes in sealed containers to prevent stink bug access',
        'Set mechanical traps around storage areas',
        'Maintain cleanliness and remove any infested fruits',
        'Use garlic extract as a repellent around storage area',
        'Monitor regularly for signs of stink bugs',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_storage.jpg',
    },

    // ===== CARROTS PESTS =====
     // Carrots - Germination/Seedling
  'Carrots_Germination/Seedling_Termites': {
    'imagePath': 'assets/pests/carrots_termites_germination.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Soil treatment', 'Use treated seeds', 'Remove debris'],
    'activeAgent': 'Insecticide (Fipronil)',
    'possibleCauses': ['Dry soil', 'Organic matter'],
    'pesticides': ['Termidor (Fipronil)', 'Premise (Imidacloprid)'],
    'organicInterventions': [
      'Apply neem oil to soil around seedlings',
      'Introduce beneficial nematodes to soil',
      'Use diatomaceous earth as a soil barrier',
      'Plant repellent crops like marigolds',
      'Maintain moist soil to deter termites'
    ],
  },
  'Carrots_Germination/Seedling_Cutworms': {
    'imagePath': 'assets/pests/carrots_cutworm_germination.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Plow fields', 'Use collars', 'Remove weeds'],
    'activeAgent': 'Insecticide (Lambda-cyhalothrin)',
    'possibleCauses': ['Moist soil', 'Weedy fields'],
    'pesticides': ['Karate (Lambda-cyhalothrin)', 'Sevin (Carbaryl)'],
    'organicInterventions': [
      'Place cardboard collars around seedling stems',
      'Apply diatomaceous earth around plant base',
      'Introduce beneficial nematodes to soil',
      'Spray Bacillus thuringiensis (Bt) on affected areas',
      'Use insecticidal soap sprays'
    ],
  },
  'Carrots_Germination/Seedling_Carrot Rust Fly': {
    'imagePath': 'assets/pests/carrots_carrot_rust_fly_germination.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Crop rotation', 'Use row covers', 'Monitor seedlings'],
    'activeAgent': 'Insecticide (Spinosad)',
    'possibleCauses': ['Cool, moist conditions', 'Carrot fields'],
    'pesticides': ['Entrust (Spinosad)', 'Success (Spinosad)'],
    'organicInterventions': [
      'Apply beneficial nematodes to soil',
      'Use lightweight row covers during egg-laying',
      'Apply neem oil to soil around seedlings',
      'Plant trap crops like radishes',
      'Use diatomaceous earth around plant base'
    ],
  },
  'Carrots_Germination/Seedling_Nematodes': {
    'imagePath': 'assets/pests/carrots_nematodes_germination.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Crop rotation', 'Soil solarization', 'Use resistant varieties'],
    'activeAgent': 'Nematicide (Oxamyl)',
    'possibleCauses': ['Infested soil', 'Continuous cropping'],
    'pesticides': ['Vydate (Oxamyl)', 'Nemacur (Fenamiphos)'],
    'organicInterventions': [
      'Apply beneficial nematodes to soil',
      'Use soil solarization before planting',
      'Plant resistant carrot varieties',
      'Incorporate marigold cover crops',
      'Apply composted manure to improve soil health'
    ],
  },
  'Carrots_Germination/Seedling_Wireworms': {
    'imagePath': 'assets/pests/carrots_wireworm_germination.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Crop rotation', 'Avoid grassy fields', 'Deep tillage'],
    'activeAgent': 'Insecticide (Imidacloprid)',
    'possibleCauses': ['Cool, moist soil', 'Previous grass crops'],
    'pesticides': ['Gaucho (Imidacloprid)', 'Admire (Imidacloprid)'],
    'organicInterventions': [
      'Apply beneficial nematodes to soil',
      'Use trap crops like wheat or barley',
      'Apply diatomaceous earth around seedlings',
      'Perform deep tillage to expose wireworms',
      'Introduce predatory ground beetles'
    ],
  },
  'Carrots_Germination/Seedling_Rodents': {
    'imagePath': 'assets/pests/carrots_rodent_germination.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Use traps', 'Protect seedlings', 'Clear debris'],
    'activeAgent': 'Rodenticide (Bromadiolone)',
    'possibleCauses': ['Seed availability', 'Unprotected fields'],
    'pesticides': ['Ratoxin (Bromadiolone)', 'Tomcat (Bromadiolone)'],
    'organicInterventions': [
      'Set mechanical snap traps with organic bait',
      'Use peppermint oil as a repellent around fields',
      'Install owl nesting boxes to encourage predation',
      'Use metal mesh barriers around seedling beds'
    ],
  },
  // Carrots - Vegetative Growth/Weeding
  'Carrots_Vegetative Growth/Weeding_Aphids': {
    'imagePath': 'assets/pests/carrots_aphids_vegetative_growth.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Introduce ladybugs', 'Use reflective mulches', 'Monitor leaves'],
    'activeAgent': 'Insecticide (Neem Oil)',
    'possibleCauses': ['Warm weather', 'Over-fertilization'],
    'pesticides': ['Azadirachtin (Neem Oil)', 'Admire (Imidacloprid)'],
    'organicInterventions': [
      'Release ladybugs or lacewings as predators',
      'Apply neem oil sprays every 5-7 days',
      'Use insecticidal soap on affected leaves',
      'Plant companion plants like garlic',
      'Spray water to dislodge aphids'
    ],
  },
  'Carrots_Vegetative Growth/Weeding_Whiteflies': {
    'imagePath': 'assets/pests/carrots_whiteflies_vegetative_growth.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Use yellow traps', 'Introduce Encarsia', 'Control humidity'],
    'activeAgent': 'Insecticide (Imidacloprid)',
    'possibleCauses': ['Warm, humid weather', 'Dense foliage'],
    'pesticides': ['Admire (Imidacloprid)', 'Confidor (Imidacloprid)'],
    'organicInterventions': [
      'Release Encarsia formosa parasitic wasps',
      'Apply insecticidal soap to undersides of leaves',
      'Use neem oil sprays every 5-7 days',
      'Place yellow sticky traps near plants',
      'Plant repellent herbs like basil'
    ],
  },
  'Carrots_Vegetative Growth/Weeding_Thrips': {
    'imagePath': 'assets/pests/carrots_thrips_vegetative_growth.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Use blue sticky traps', 'Maintain plant health', 'Avoid dense planting'],
    'activeAgent': 'Insecticide (Spinosad)',
    'possibleCauses': ['Dry conditions', 'Young leaves'],
    'pesticides': ['Entrust (Spinosad)', 'Radiant (Spinosad)'],
    'organicInterventions': [
      'Spray spinosad on affected leaves',
      'Use blue sticky traps to capture thrips',
      'Apply neem oil sprays every 7 days',
      'Introduce predatory mites or lacewings',
      'Maintain irrigation to reduce plant stress'
    ],
  },
  'Carrots_Vegetative Growth/Weeding_Carrot Rust Fly': {
    'imagePath': 'assets/pests/carrots_carrot_rust_fly_vegetative_growth.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Crop rotation', 'Use row covers', 'Monitor plants'],
    'activeAgent': 'Insecticide (Spinosad)',
    'possibleCauses': ['Cool, moist conditions', 'Carrot fields'],
    'pesticides': ['Entrust (Spinosad)', 'Success (Spinosad)'],
    'organicInterventions': [
      'Apply spinosad to soil around plants',
      'Use lightweight row covers during egg-laying',
      'Apply beneficial nematodes to soil',
      'Plant trap crops like radishes',
      'Use neem oil sprays to deter adults'
    ],
  },
  'Carrots_Vegetative Growth/Weeding_Leaf Loopers': {
    'imagePath': 'assets/pests/carrots_leaf_loopers_vegetative_growth.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Use reflective mulches', 'Control weeds', 'Monitor populations'],
    'activeAgent': 'Insecticide (Imidacloprid)',
    'possibleCauses': ['Warm weather', 'Nearby host plants'],
    'pesticides': ['Confidor (Imidacloprid)', 'Gaucho (Imidacloprid)'],
    'organicInterventions': [
      'Apply neem oil sprays weekly',
      'Use insecticidal soap on affected plants',
      'Place yellow sticky traps around plants',
      'Introduce predatory bugs like minute pirate bugs',
      'Plant trap crops like alfalfa'
    ],
  },
  'Carrots_Vegetative Growth/Weeding_Nematodes': {
    'imagePath': 'assets/pests/carrots_nematodes_vegetative_growth.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Crop rotation', 'Soil solarization', 'Use resistant varieties'],
    'activeAgent': 'Nematicide (Oxamyl)',
    'possibleCauses': ['Infested soil', 'Continuous cropping'],
    'pesticides': ['Vydate (Oxamyl)', 'Nemacur (Fenamiphos)'],
    'organicInterventions': [
      'Apply beneficial nematodes to soil',
      'Use soil solarization during fallow periods',
      'Plant resistant carrot varieties',
      'Incorporate marigold cover crops',
      'Apply composted manure to improve soil health'
    ],
  },
  'Carrots_Vegetative Growth/Weeding_Wireworms': {
    'imagePath': 'assets/pests/carrots_wireworm_vegetative_growth.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Crop rotation', 'Avoid grassy fields', 'Deep tillage'],
    'activeAgent': 'Insecticide (Imidacloprid)',
    'possibleCauses': ['Cool, moist soil', 'Previous grass crops'],
    'pesticides': ['Gaucho (Imidacloprid)', 'Admire (Imidacloprid)'],
    'organicInterventions': [
      'Apply beneficial nematodes to soil',
      'Use trap crops like wheat or barley',
      'Apply diatomaceous earth around plants',
      'Perform deep tillage to expose wireworms',
      'Introduce predatory ground beetles'
    ],
  },
  'Carrots_Vegetative Growth/Weeding_Rodents': {
    'imagePath': 'assets/pests/carrots_rodent_vegetative_growth.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Use traps', 'Remove weeds', 'Secure field edges'],
    'activeAgent': 'Rodenticide (Bromadiolone)',
    'possibleCauses': ['Dense vegetation', 'Food sources'],
    'pesticides': ['Ratoxin (Bromadiolone)', 'Tomcat (Bromadiolone)'],
    'organicInterventions': [
      'Set mechanical snap traps with organic bait',
      'Apply peppermint oil around field edges',
      'Encourage natural predators like owls',
      'Use metal mesh barriers around fields'
    ],
  },
'Carrots_Vegetative Growth/Weeding_Leafminers': {
    'imagePath': 'assets/pests/carrots_leafminers_vegetative_growth.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Use yellow sticky traps', 'Remove affected leaves', 'Introduce beneficial insects'],
    'activeAgent': 'Insecticide (Spinosad)',
    'possibleCauses': ['Warm weather', 'Nearby host plants'],
    'pesticides': ['Entrust (Spinosad)', 'Success (Spinosad)'],
    'organicInterventions': [
      'Apply spinosad to affected leaves',
      'Introduce parasitic wasps like Diglyphus isaea',
      'Use yellow sticky traps to monitor populations',
      'Remove and destroy infested leaves',
      'Plant trap crops like marigolds'
    ],
  },
  'Carrots_Vegetative Growth/Weeding_Armyworms': {
    'imagePath': 'assets/pests/carrots_armyworm_vegetative_growth.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Hand-pick larvae', 'Use trap crops', 'Introduce beneficial insects'],
    'activeAgent': 'Insecticide (Bacillus thuringiensis)',
    'possibleCauses': ['Warm, humid conditions', 'Weedy fields'],
    'pesticides': ['Dipel (Bacillus thuringiensis)', 'XenTari (Bacillus thuringiensis)'],
    'organicInterventions': [
      'Apply Bacillus thuringiensis (Bt) to foliage',
      'Hand-pick larvae during early morning or evening',
      'Use neem oil sprays on affected areas',
      'Plant trap crops like millet or sorghum',
      'Introduce predatory birds or insects'
    ],
  },

  // Carrots - Maturation/Harvesting
  'Carrots_Maturation/Harvesting_Carrot Rust Fly': {
    'imagePath': 'assets/pests/carrots_carrot_rust_fly_harvesting.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Harvest early', 'Use row covers', 'Monitor roots'],
    'activeAgent': 'Insecticide (Spinosad)',
    'possibleCauses': ['Cool, moist conditions', 'Mature roots'],
    'pesticides': ['Entrust (Spinosad)', 'Success (Spinosad)'],
    'organicInterventions': [
      'Apply spinosad to soil around mature plants',
      'Use lightweight row covers during egg-laying',
      'Apply beneficial nematodes to soil',
      'Plant trap crops like radishes',
      'Harvest carrots promptly to reduce exposure'
    ],
  },
  'Carrots_Maturation/Harvesting_Nematodes': {
    'imagePath': 'assets/pests/carrots_nematodes_harvesting.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Harvest early', 'Crop rotation', 'Soil testing'],
    'activeAgent': 'Nematicide (Oxamyl)',
    'possibleCauses': ['Infested soil', 'Mature roots'],
    'pesticides': ['Vydate (Oxamyl)', 'Nemacur (Fenamiphos)'],
    'organicInterventions': [
      'Apply beneficial nematodes to soil',
      'Use soil solarization before planting next crop',
      'Plant resistant carrot varieties',
      'Incorporate marigold cover crops',
      'Harvest promptly to minimize damage'
    ],
  },
  'Carrots_Maturation/Harvesting_Wireworms': {
    'imagePath': 'assets/pests/carrots_wireworm_harvesting.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Harvest early', 'Crop rotation', 'Deep tillage'],
    'activeAgent': 'Insecticide (Imidacloprid)',
    'possibleCauses': ['Cool, moist soil', 'Mature roots'],
    'pesticides': ['Gaucho (Imidacloprid)', 'Admire (Imidacloprid)'],
    'organicInterventions': [
      'Apply beneficial nematodes to soil',
      'Use trap crops like wheat or barley',
      'Apply diatomaceous earth around plants',
      'Perform deep tillage to expose wireworms',
      'Harvest carrots promptly to reduce damage'
    ],
  },
  'Carrots_Maturation/Harvesting_Aphids': {
    'imagePath': 'assets/pests/carrots_aphids_harvesting.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Harvest early', 'Introduce ladybugs', 'Monitor leaves'],
    'activeAgent': 'Insecticide (Neem Oil)',
    'possibleCauses': ['Warm weather', 'Mature plants'],
    'pesticides': ['Azadirachtin (Neem Oil)', 'Admire (Imidacloprid)'],
    'organicInterventions': [
      'Release ladybugs or lacewings on mature plants',
      'Apply neem oil sprays every 5-7 days',
      'Use insecticidal soap on affected leaves',
      'Plant companion plants like garlic',
      'Harvest promptly to reduce exposure'
    ],
  },
  'Carrots_Maturation/Harvesting_Rodents': {
    'imagePath': 'assets/pests/carrots_rodent_harvesting.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Harvest promptly', 'Use traps', 'Secure fields'],
    'activeAgent': 'Rodenticide (Bromadiolone)',
    'possibleCauses': ['Mature roots', 'Unprotected fields'],
    'pesticides': ['Ratoxin (Bromadiolone)', 'Tomcat (Bromadiolone)'],
    'organicInterventions': [
      'Set mechanical snap traps with organic bait',
      'Apply peppermint oil around field edges',
      'Encourage natural predators like owls',
      'Use metal mesh barriers around harvested carrots'
    ],
  },
  'Carrots_Maturation/Harvesting_Armyworms': {
    'imagePath': 'assets/pests/carrots_armyworm_harvesting.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Harvest early', 'Hand-pick larvae', 'Use trap crops'],
    'activeAgent': 'Insecticide (Bacillus thuringiensis)',
    'possibleCauses': ['Warm, humid conditions', 'Mature plants'],
    'pesticides': ['Dipel (Bacillus thuringiensis)', 'XenTari (Bacillus thuringiensis)'],
    'organicInterventions': [
      'Apply Bacillus thuringiensis (Bt) to foliage',
      'Hand-pick larvae during early morning or evening',
      'Use neem oil sprays on affected areas',
      'Plant trap crops like millet or sorghum',
      'Introduce predatory birds or insects'
    ],
  },
'Carrots_Maturation/Harvesting_Thrips': {
    'imagePath': 'assets/pests/carrots_thrips_harvesting.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Harvest early', 'Use blue sticky traps', 'Monitor flowers'],
    'activeAgent': 'Insecticide (Spinosad)',
    'possibleCauses': ['Dry conditions', 'Mature plants'],
    'pesticides': ['Entrust (Spinosad)', 'Radiant (Spinosad)'],
    'organicInterventions': [
      'Spray spinosad on flowers and leaves',
      'Use blue sticky traps to capture thrips',
      'Apply neem oil sprays every 7 days',
      'Introduce predatory mites or lacewings',
      'Ensure adequate irrigation to reduce stress'
    ],
  },
  'Carrots_Maturation/Harvesting_Leaf Loopers': {
    'imagePath': 'assets/pests/carrots_leaf_looper_harvesting.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Harvest early', 'Use reflective mulches', 'Monitor plants'],
    'activeAgent': 'Insecticide (Imidacloprid)',
    'possibleCauses': ['Warm weather', 'Mature plants'],
    'pesticides': ['Confidor (Imidacloprid)', 'Gaucho (Imidacloprid)'],
    'organicInterventions': [
      'Apply neem oil sprays weekly',
      'Use insecticidal soap on affected plants',
      'Place yellow sticky traps around flowers',
      'Introduce predatory bugs like minute pirate bugs',
      'Plant trap crops like alfalfa'
    ],
  },
  'Carrots_Maturation/Harvesting_White Flies': {
    'imagePath': 'assets/pests/carrots_whiteflies_harvesting.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Harvest early', 'Use yellow traps', 'Introduce Encarsia'],
    'activeAgent': 'Insecticide (Imidacloprid)',
    'possibleCauses': ['Warm, humid weather', 'Mature plants'],
    'pesticides': ['Admire (Imidacloprid)', 'Confidor (Imidacloprid)'],
    'organicInterventions': [
      'Release Encarsia formosa parasitic wasps',
      'Apply insecticidal soap to undersides of leaves',
      'Use neem oil sprays every 5-7 days',
      'Place yellow sticky traps near flowers',
      'Plant repellent herbs like mint'
    ],
  },
  'Carrots_Maturation/Harvesting_Leaf Miners': {
    'imagePath': 'assets/pests/carrots_leafminers_harvesting.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Harvest early', 'Use yellow sticky traps', 'Remove affected leaves'],
    'activeAgent': 'Insecticide (Spinosad)',
    'possibleCauses': ['Warm weather', 'Mature plants'],
    'pesticides': ['Entrust (Spinosad)', 'Success (Spinosad)'],
    'organicInterventions': [
      'Apply spinosad to affected leaves',
      'Introduce parasitic wasps like Diglyphus isaea',
      'Use yellow sticky traps to monitor populations',
      'Remove and destroy infested leaves',
      'Plant trap crops like marigolds'
    ],
  },

  // Carrots - Storage
  'Carrots_Storage_Rodents': {
    'imagePath': 'assets/pests/carrots_rodent_storage.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Use rodent-proof containers', 'Set traps', 'Clean storage'],
    'activeAgent': 'Rodenticide (Bromadiolone)',
    'possibleCauses': ['Unprotected storage', 'Food availability'],
    'pesticides': ['Ratoxin (Bromadiolone)', 'Tomcat (Bromadiolone)'],
    'organicInterventions': [
      'Use rodent-proof metal containers',
      'Set mechanical snap traps with organic bait',
      'Apply peppermint oil around storage areas',
      'Encourage natural predators like barn owls',
      'Regularly clean storage to remove food debris'
    ],
  },
  'Carrots_Storage_Aphids': {
    'imagePath': 'assets/pests/carrots_aphids_storage.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Inspect stored produce', 'Use cold storage', 'Sanitize storage'],
    'activeAgent': 'Insecticide (Neem Oil)',
    'possibleCauses': ['Warm storage', 'Infested produce'],
    'pesticides': ['Azadirachtin (Neem Oil)', 'Admire (Imidacloprid)'],
    'organicInterventions': [
      'Apply neem oil to carrots before storage',
      'Maintain cold storage at 32-40°F',
      'Inspect and remove infested carrots',
      'Use insecticidal soap on affected areas',
      'Sanitize storage with organic disinfectants'
    ],
  },
  'Carrots_Storage_Nematodes': {
    'imagePath': 'assets/pests/carrots_nematodes_storage.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Inspect produce', 'Use cold storage', 'Sanitize storage'],
    'activeAgent': 'Nematicide (Oxamyl)',
    'possibleCauses': ['Infested produce', 'Warm storage'],
    'pesticides': ['Vydate (Oxamyl)', 'Nemacur (Fenamiphos)'],
    'organicInterventions': [
      'Inspect and remove infested carrots before storage',
      'Maintain cold storage at 32-40°F',
      'Use soil solarization before next planting',
      'Plant resistant carrot varieties',
      'Sanitize storage with organic disinfectants'
    ],
  },
  'Carrots_Storage_Carrot Rust Fly': {
    'imagePath': 'assets/pests/carrots_carrot_rust_fly_storage.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Inspect produce', 'Use cold storage', 'Sanitize storage'],
    'activeAgent': 'Insecticide (Spinosad)',
    'possibleCauses': ['Infested produce', 'Warm storage'],
    'pesticides': ['Entrust (Spinosad)', 'Success (Spinosad)'],
    'organicInterventions': [
      'Inspect and remove infested carrots before storage',
      'Maintain cold storage at 32-40°F',
      'Apply spinosad to carrots before storage',
      'Use beneficial nematodes in soil before next planting',
      'Sanitize storage with organic disinfectants'
    ],
  },

  // Onions - Germination/Seedling
  'Onions_Germination/Seedling_Thrips': {
    'imagePath': 'assets/pests/onions_thrips_germination.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Use resistant varieties', 'Introduce natural predators', 'Maintain proper field hygiene'],
    'activeAgent': 'Neem oil or spinosad sprays',
    'possibleCauses': ['High humidity', 'Overcrowding', 'Late planting'],
    'pesticides': ['Neem-based sprays', 'Spinosad', 'Insecticidal soaps'],
    'organicInterventions': [
      'Apply neem oil sprays every 7 days',
      'Use blue sticky traps to capture thrips',
      'Introduce predatory mites or lacewings',
      'Maintain irrigation to reduce plant stress',
      'Plant resistant onion varieties'
    ],
  },
  'Onions_Germination/Seedling_Aphids': {
    'imagePath': 'assets/pests/onions_aphids_germination.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Use reflective mulches', 'Encourage natural predators', 'Proper spacing'],
    'activeAgent': 'Insecticidal soap or neem oil',
    'possibleCauses': ['High nitrogen levels', 'Weak plants'],
    'pesticides': ['Insecticidal soaps', 'Neem oil', 'Pyrethroids'],
    'organicInterventions': [
      'Release ladybugs or lacewings as predators',
      'Apply neem oil sprays every 5-7 days',
      'Use insecticidal soap on affected leaves',
      'Plant companion plants like garlic or chives',
      'Spray water to dislodge aphids'
    ],
  },
   
  // Onions - Vegetative Growth/Weeding
  'Onions_Vegetative Growth/Weeding_Thrips': {
    'imagePath': 'assets/pests/onions_thrips_vegetative_growth.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Use resistant varieties', 'Introduce natural predators', 'Maintain proper field hygiene'],
    'activeAgent': 'Neem oil or spinosad sprays',
    'possibleCauses': ['High humidity', 'Overcrowding', 'Late planting'],
    'pesticides': ['Neem-based sprays', 'Spinosad', 'Insecticidal soaps'],
    'organicInterventions': [
      'Apply neem oil sprays every 7 days',
      'Use blue sticky traps to capture thrips',
      'Introduce predatory mites or lacewings',
      'Maintain irrigation to reduce plant stress',
      'Plant resistant onion varieties'
    ],
  },
  'Onions_Vegetative Growth/Weeding_Aphids': {
    'imagePath': 'assets/pests/onions_aphids_vegetative_growth.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Use reflective mulches', 'Encourage natural predators', 'Proper spacing'],
    'activeAgent': 'Insecticidal soap or neem oil',
    'possibleCauses': ['High nitrogen levels', 'Weak plants'],
    'pesticides': ['Insecticidal soaps', 'Neem oil', 'Pyrethroids'],
    'organicInterventions': [
      'Release ladybugs or lacewings as predators',
      'Apply neem oil sprays every 5-7 days',
      'Use insecticidal soap on affected leaves',
      'Plant companion plants like garlic or chives',
      'Spray water to dislodge aphids'
    ],
  },
 
 
  // Onions - Bulb Formation/Reproductive
  'Onions_Bulb Formation/Reproductive_Maggots': {
    'imagePath': 'assets/pests/onions_maggots_bulb_formation.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Crop rotation', 'Good field sanitation', 'Use of resistant varieties'],
    'activeAgent': 'Dip bulbs in neem extract, apply insecticidal soil drenches',
    'possibleCauses': ['Exposed bulbs', 'Planting in infested soils'],
    'pesticides': ['Phorate (Thimet)', 'Chlorpyrifos'],
    'organicInterventions': [
      'Apply beneficial nematodes to soil',
      'Dip bulbs in neem extract before planting',
      'Use lightweight row covers during egg-laying',
      'Plant trap crops like radishes',
      'Apply diatomaceous earth around bulb base'
    ],
  },
  'Onions_Bulb Formation/Reproductive_Bulb Fly': {
    'imagePath': 'assets/pests/onions_bulbfly_bulb_formation.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Crop rotation', 'Use of sticky traps', 'Plant resistant varieties'],
    'activeAgent': 'Apply soil drenches with insecticides like diazinon',
    'possibleCauses': ['Infested soil', 'Overgrown young plants'],
    'pesticides': ['Diazinon', 'Chlorpyrifos'],
    'organicInterventions': [
      'Apply beneficial nematodes to soil',
      'Use yellow sticky traps to capture adults',
      'Apply neem oil to soil around bulbs',
      'Plant trap crops like radishes',
      'Use lightweight row covers during egg-laying'
    ],
  },
  
  // Onions - Bulbing/Maturation
  'Onions_Bulbing/Maturation_Maggots': {
    'imagePath': 'assets/pests/onions_maggots_bulbing.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Crop rotation', 'Good field sanitation', 'Use of resistant varieties'],
    'activeAgent': 'Dip bulbs in neem extract, apply insecticidal soil drenches',
    'possibleCauses': ['Exposed bulbs', 'Planting in infested soils'],
    'pesticides': ['Phorate (Thimet)', 'Chlorpyrifos'],
    'organicInterventions': [
      'Apply beneficial nematodes to soil',
      'Dip bulbs in neem extract before planting',
      'Use lightweight row covers during egg-laying',
      'Plant trap crops like radishes',
      'Harvest promptly to reduce exposure'
    ],
  },
  'Onions_Bulbing/Maturation_Bulb Fly': {
    'imagePath': 'assets/pests/onions_bulbfly_bulbing.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Crop rotation', 'Use of sticky traps', 'Plant resistant varieties'],
    'activeAgent': 'Apply soil drenches with insecticides like diazinon',
    'possibleCauses': ['Infested soil', 'Overgrown young plants'],
    'pesticides': ['Diazinon', 'Chlorpyrifos'],
    'organicInterventions': [
      'Apply beneficial nematodes to soil',
      'Use yellow sticky traps to capture adults',
      'Apply neem oil to soil around bulbs',
      'Plant trap crops like radishes',
      'Harvest promptly to reduce exposure'
    ],
  },
  'Onions_Bulbing/Maturation_Thrips': {
    'imagePath': 'assets/pests/onions_thrips_bulbing.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Use resistant varieties', 'Introduce natural predators', 'Maintain proper field hygiene'],
    'activeAgent': 'Neem oil or spinosad sprays',
    'possibleCauses': ['High humidity', 'Overcrowding', 'Late planting'],
    'pesticides': ['Neem-based sprays', 'Spinosad', 'Insecticidal soaps'],
    'organicInterventions': [
      'Apply neem oil sprays every 7 days',
      'Use blue sticky traps to capture thrips',
      'Introduce predatory mites or lacewings',
      'Maintain irrigation to reduce plant stress',
      'Harvest promptly to reduce exposure'
    ],
  },
  
  // Onions - Harvesting/Storage
  'Onions_Harvesting/Storage_Maggots': {
    'imagePath': 'assets/pests/onions_maggots_harvesting.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Harvest promptly', 'Use row covers', 'Monitor mature onions'],
    'activeAgent': 'Insecticide (Spinosad)',
    'possibleCauses': ['Cool, moist conditions', 'Mature onions'],
    'pesticides': ['Entrust (Spinosad)', 'Success (Spinosad)'],
    'organicInterventions': [
      'Apply beneficial nematodes to soil before harvest',
      'Use lightweight row covers during egg-laying',
      'Apply neem oil to soil around mature plants',
      'Harvest onions promptly to reduce exposure',
      'Inspect and remove infested onions'
    ],
  },
  'Onions_Harvesting/Storage_Bulb Fly': {
    'imagePath': 'assets/pests/onions_bulbfly_harvesting.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Harvest promptly', 'Use row covers', 'Monitor mature onions'],
    'activeAgent': 'Insecticide (Diazinon)',
    'possibleCauses': ['Cool, moist conditions', 'Mature onions'],
    'pesticides': ['Diazinon', 'Chlorpyrifos'],
    'organicInterventions': [
      'Apply beneficial nematodes to soil before harvest',
      'Use yellow sticky traps to capture adults',
      'Apply neem oil to soil around mature plants',
      'Harvest onions promptly to reduce exposure',
      'Inspect and remove infested onions'
    ],
  },
  'Onions_Harvesting/Storage_Rodents': {
    'imagePath': 'assets/pests/onions_rodents_harvesting.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Use rodent-proof containers', 'Set traps', 'Clean storage'],
    'activeAgent': 'Rodenticide (Bromadiolone)',
    'possibleCauses': ['Unprotected storage', 'Food availability'],
    'pesticides': ['Ratoxin (Bromadiolone)', 'Tomcat (Bromadiolone)'],
    'organicInterventions': [
      'Use rodent-proof metal containers',
      'Set mechanical snap traps with organic bait',
      'Apply peppermint oil around storage areas',
      'Encourage natural predators like barn owls',
      'Regularly clean storage to remove food debris'
    ],
  },
  
  //IRISH POTATOES PESTS
  // Irish Potatoes - Early Growth
  'Irish Potatoes_Early Growth_Wireworms': {
    'imagePath': 'assets/pests/irish_potatoes_wireworms_early_growth.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Crop rotation', 'Soil solarization', 'Use resistant varieties'],
    'activeAgent': 'Nematicide (Oxamyl)',
    'possibleCauses': ['Infested soil', 'Continuous cropping'],
    'pesticides': ['Vydate (Oxamyl)', 'Nemacur (Fenamiphos)'],
    'organicInterventions': [
      'Apply beneficial nematodes to soil',
      'Use soil solarization before planting',
      'Plant resistant potato varieties',
      'Incorporate marigold cover crops',
      'Apply composted manure to improve soil health'
    ],
  },
  'Irish Potatoes_Early Growth_Cutworms': {
    'imagePath': 'assets/pests/irish_potatoes_cutworms_early_growth.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Plow fields', 'Use collars', 'Remove weeds'],
    'activeAgent': 'Insecticide (Lambda-cyhalothrin)',
    'possibleCauses': ['Moist soil', 'Weedy fields'],
    'pesticides': ['Karate (Lambda-cyhalothrin)', 'Sevin (Carbaryl)'],
    'organicInterventions': [
      'Place cardboard collars around seedling stems',
      'Apply diatomaceous earth around plant base',
      'Introduce beneficial nematodes to soil',
      'Spray Bacillus thuringiensis (Bt) on affected areas',
      'Use insecticidal soap sprays'
    ],
  },
   
  // Irish Potatoes - Tuber Initiation
  'Irish Potatoes_Tuber Initiation_Colorado Potato Beetle': {
    'imagePath': 'assets/pests/irish_potatoes_colorado_potato_beetle_tuber_initiation.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Hand-picking', 'Use traps', 'Crop rotation'],
    'activeAgent': 'Insecticide (Spinosad)',
    'possibleCauses': ['Warm weather', 'Dense planting'],
    'pesticides': ['Entrust (Spinosad)', 'Success (Spinosad)'],
    'organicInterventions': [
      'Hand-pick beetles and larvae early in the morning',
      'Apply spinosad sprays to affected plants',
      'Use lightweight row covers to protect plants',
      'Introduce predatory bugs like ladybugs',
      'Plant trap crops like eggplant'
    ],
  },
  'Irish Potatoes_Tuber Initiation_Aphids': {
    'imagePath': 'assets/pests/irish_potatoes_aphids_tuber_initiation.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Introduce ladybugs', 'Use reflective mulches', 'Monitor leaves'],
    'activeAgent': 'Insecticide (Neem Oil)',
    'possibleCauses': ['Warm weather', 'Over-fertilization'],
    'pesticides': ['Azadirachtin (Neem Oil)', 'Admire (Imidacloprid)'],
    'organicInterventions': [
      'Release ladybugs or lacewings as predators',
      'Apply neem oil sprays every 5-7 days',
      'Use insecticidal soap on affected leaves',
      'Plant companion plants like garlic or chives',
      'Spray water to dislodge aphids'
    ],
  },
  'Irish Potatoes_Tuber Initiation_Spider Mites': {
    'imagePath': 'assets/pests/irish_potatoes_spider_mites_tuber_initiation.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Increase humidity', 'Use predatory mites', 'Monitor leaves'],
    'activeAgent': 'Miticide (Abamectin)',
    'possibleCauses': ['Dry conditions', 'Dusty fields'],
    'pesticides': ['Agri-Mek (Abamectin)', 'Avid (Abamectin)'],
    'organicInterventions': [
      'Release predatory mites like Phytoseiulus persimilis',
      'Apply neem oil sprays every 7 days',
      'Use insecticidal soap on affected leaves',
      'Increase humidity around plants',
      'Spray water to dislodge mites'
    ],
  },
   
  // Irish Potatoes - Tuber Bulking
  'Irish Potatoes_Tuber Bulking_Flea Beetles': {
    'imagePath': 'assets/pests/irish_potatoes_flea_beetles_tuber_bulking.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Use row covers', 'Crop rotation', 'Monitor plants'],
    'activeAgent': 'Insecticide (Pyrethroids)',
    'possibleCauses': ['Warm weather', 'Young plants'],
    'pesticides': ['Sevin (Carbaryl)', 'Pounce (Permethrin)'],
    'organicInterventions': [
      'Apply neem oil sprays weekly',
      'Use lightweight row covers to protect plants',
      'Place yellow sticky traps around plants',
      'Plant trap crops like mustard',
      'Apply diatomaceous earth to foliage'
    ],
  },
  'Irish Potatoes_Tuber Bulking_Leaf Hoppers': {
    'imagePath': 'assets/pests/irish_potatoes_leafhoppers_tuber_bulking.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Use reflective mulches', 'Monitor plants', 'Crop rotation'],
    'activeAgent': 'Insecticide (Imidacloprid)',
    'possibleCauses': ['Warm weather', 'Young plants'],
    'pesticides': ['Admire (Imidacloprid)', 'Assail (Acetamiprid)'],
    'organicInterventions': [
      'Apply neem oil sprays weekly',
      'Use insecticidal soap on affected plants',
      'Place yellow sticky traps around plants',
      'Introduce predatory bugs like minute pirate bugs',
      'Plant trap crops like alfalfa'
    ],
  },
  'Irish Potatoes_Tuber Bulking_Aphids': {
    'imagePath': 'assets/pests/irish_potatoes_aphids_tuber_bulking.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Introduce ladybugs', 'Use reflective mulches', 'Monitor leaves'],
    'activeAgent': 'Insecticide (Neem Oil)',
    'possibleCauses': ['Warm weather', 'Over-fertilization'],
    'pesticides': ['Azadirachtin (Neem Oil)', 'Admire (Imidacloprid)'],
    'organicInterventions': [
      'Release ladybugs or lacewings as predators',
      'Apply neem oil sprays every 5-7 days',
      'Use insecticidal soap on affected leaves',
      'Plant companion plants like garlic or chives',
      'Spray water to dislodge aphids'
    ],
  },
  'Irish Potatoes_Tuber Bulking_Spider Mites': {
    'imagePath': 'assets/pests/irish_potatoes_spider_mites_tuber_bulking.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Increase humidity', 'Use predatory mites', 'Monitor leaves'],
    'activeAgent': 'Miticide (Abamectin)',
    'possibleCauses': ['Dry conditions', 'Dusty fields'],
    'pesticides': ['Agri-Mek (Abamectin)', 'Avid (Abamectin)'],
    'organicInterventions': [
      'Release predatory mites like Phytoseiulus persimilis',
      'Apply neem oil sprays every 7 days',
      'Use insecticidal soap on affected leaves',
      'Increase humidity around plants',
      'Spray water to dislodge mites'
    ],
  },
    
  // Irish Potatoes - Maturation/Harvesting
  'Irish Potatoes_Maturation/Harvesting_Wireworms': {
    'imagePath': 'assets/pests/irish_potatoes_wireworms_maturation.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Crop rotation', 'Soil solarization', 'Use resistant varieties'],
    'activeAgent': 'Nemicide (Oxamyl)',
    'possibleCauses': ['Infested soil', 'Continuous cropping'],
    'pesticides': ['Vydate (Oxamyl)', 'Nemacur (Fenamiphos)'],
    'organicInterventions': [
      'Apply beneficial nematodes to soil',
      'Use soil solarization before planting next crop',
      'Plant resistant potato varieties',
      'Incorporate marigold cover crops',
      'Harvest promptly to minimize damage'
    ],
  },
  'Irish Potatoes_Maturation/Harvesting_Cutworms': {
    'imagePath': 'assets/pests/irish_potatoes_cutworms_maturation.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Plow fields', 'Use collars', 'Remove weeds'],
    'activeAgent': 'Insecticide (Lambda-cyhalothrin)',
    'possibleCauses': ['Moist soil', 'Weedy fields'],
    'pesticides': ['Karate (Lambda-cyhalothrin)', 'Sevin (Carbaryl)'],
    'organicInterventions': [
      'Place cardboard collars around plant stems',
      'Apply diatomaceous earth around plant base',
      'Introduce beneficial nematodes to soil',
      'Spray Bacillus thuringiensis (Bt) on affected areas',
      'Harvest promptly to reduce exposure'
    ],
  },
  'Irish Potatoes_Maturation/Harvesting_Colorado Potato Beetle': {
    'imagePath': 'assets/pests/irish_potatoes_colorado_potato_beetle_maturation.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Hand-picking', 'Use traps', 'Crop rotation'],
    'activeAgent': 'Insecticide (Spinosad)',
    'possibleCauses': ['Warm weather', 'Dense planting'],
    'pesticides': ['Entrust (Spinosad)', 'Success (Spinosad)'],
    'organicInterventions': [
      'Hand-pick beetles and larvae early in the morning',
      'Apply spinosad sprays to affected plants',
      'Use lightweight row covers to protect plants',
      'Introduce predatory bugs like ladybugs',
      'Harvest promptly to reduce exposure'
    ],
  },
  'Irish Potatoes_Maturation/Harvesting_Aphids': {
    'imagePath': 'assets/pests/irish_potatoes_aphids_maturation.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Introduce ladybugs', 'Use reflective mulches', 'Monitor leaves'],
    'activeAgent': 'Insecticide (Neem Oil)',
    'possibleCauses': ['Warm weather', 'Over-fertilization'],
    'pesticides': ['Azadirachtin (Neem Oil)', 'Admire (Imidacloprid)'],
    'organicInterventions': [
      'Release ladybugs or lacewings as predators',
      'Apply neem oil sprays every 5-7 days',
      'Use insecticidal soap on affected leaves',
      'Plant companion plants like garlic or chives',
      'Harvest promptly to reduce exposure'
    ],
  },
  'Irish Potatoes_Maturation/Harvesting_Spider Mites': {
    'imagePath': 'assets/pests/irish_potatoes_spider_mites_maturation.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Increase humidity', 'Use predatory mites', 'Monitor leaves'],
    'activeAgent': 'Miticide (Abamectin)',
    'possibleCauses': ['Dry conditions', 'Dusty fields'],
    'pesticides': ['Agri-Mek (Abamectin)', 'Avid (Abamectin)'],
    'organicInterventions': [
      'Release predatory mites like Phytoseiulus persimilis',
      'Apply neem oil sprays every 7 days',
      'Use insecticidal soap on affected leaves',
      'Increase humidity around plants',
      'Harvest promptly to reduce exposure'
    ],
  },
 };