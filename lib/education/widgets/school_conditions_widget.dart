// lib/education/widgets/school_conditions_widget.dart
//
// Live satellite + IoT conditions panel for all three education data-input screens.
// Education-only — zero dependency on enterprise services or satellite_data_screen.dart.
//
// ── CHANGES FROM PREVIOUS VERSION ─────────────────────────────────────────
// • Removed all enterprise imports (NasaPowerService, IotSensorService,
//   FarmLocationService, satellite_data_screen.dart)
// • Uses EduSchoolConditionsService and EduFarmLocationService exclusively
// • Fixed: CollectionReference?.add() null error — all Firestore writes
//   now use direct FirebaseFirestore paths parsed from classId, not
//   FirestoreHelper (which returns nullable CollectionReference?)
// • Risk cards are now self-contained — no ConditionRiskBanner import needed
//
// ── WHAT IT SHOWS ──────────────────────────────────────────────────────────
// TEACHER (collapsible, open by default):
//   • Weather tiles: rain, temp, humidity, wind, cloud cover, dew point
//   • Soil sensor tiles: N/P/K/pH/soil temp/EC with Good/Low/High badges
//   • Risk cards: fungal, drought, flood, heat, spray window (expanded, not chips)
//   • AI guided question generator → KICD-aligned CBC question from live data
//
// STUDENT (always visible, compact):
//   • Same weather + soil tiles
//   • Teacher's saved question highlighted above the submission form

// ignore_for_file: dead_code, unused_element, deprecated_member_use

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:kilimomkononi/models/education_user.dart';
import 'package:kilimomkononi/education/services/edu_school_conditions_service.dart';

// ── Colour tokens ──────────────────────────────────────────────────────────
const _kDarkGreen  = Color(0xFF032704);
const _kGreen      = Color(0xFF1B5E20);
const _kMidGreen   = Color(0xFF2A6B2A);
const _kLightGreen = Color(0xFFE8F5E9);
const _kAmber      = Color(0xFFE65100);
const _kLightAmber = Color(0xFFFFF8E1);
const _kBlue       = Color(0xFF0D47A1);
const _kRed        = Color(0xFFB71C1C);
const _kLightRed   = Color(0xFFFFEBEE);
const _kBorder     = Color(0xFFDDE5DD);

// ═══════════════════════════════════════════════════════════════════════════
// WIDGET
// ═══════════════════════════════════════════════════════════════════════════

class SchoolConditionsWidget extends StatefulWidget {
  final EduRole role;
  final String schoolName;
  final String classId;
  final String? selectedCrop;
  final String? selectedStage;
  final String? selectedTopic;    // issue / disease name / pest name
  final String contentType;       // 'field_submissions' | 'disease_data' | 'pest_data'

  const SchoolConditionsWidget({
    super.key,
    required this.role,
    required this.schoolName,
    required this.classId,
    this.selectedCrop,
    this.selectedStage,
    this.selectedTopic,
    this.contentType = 'field_submissions',
  });

  @override
  State<SchoolConditionsWidget> createState() => _SchoolConditionsWidgetState();
}

class _SchoolConditionsWidgetState extends State<SchoolConditionsWidget> {
  EduConditionsBundle? _bundle;
  bool _loading    = true;
  bool _expanded   = true;
  bool _aiLoading  = false;
  String? _aiQuestion;
  String? _savedQuestion;

  bool get _isTeacher =>
      widget.role == EduRole.teacher || widget.role == EduRole.headteacher;

  // ── Firestore path from classId ────────────────────────────────────────
  // Parses classId exactly like field_data_input._parseClassId().
  // Returns null when classId is empty or malformed — all writes then no-op.

  DocumentReference? _gradeDocRef() {
    if (widget.classId.isEmpty) return null;
    const systems = ['eightfourfour', 'senior', 'junior', 'primary'];
    String school = '', system = '', grade = '';
    for (final sys in systems) {
      final marker = '_${sys}_';
      final idx = widget.classId.toLowerCase().indexOf(marker);
      if (idx != -1) {
        school = widget.classId.substring(0, idx);
        system = widget.classId.substring(idx + 1, idx + marker.length - 1);
        grade  = widget.classId.substring(idx + marker.length);
        break;
      }
    }
    if (school.isEmpty) {
      final parts = widget.classId.split('_');
      school = parts.isNotEmpty ? parts[0] : widget.classId;
      system = parts.length > 1 ? parts[1] : '';
      grade  = parts.length > 2 ? parts.sublist(2).join('_') : '';
    }
    if (school.isEmpty || system.isEmpty || grade.isEmpty) return null;
    return FirebaseFirestore.instance
        .collection('schools').doc(school)
        .collection('systems').doc(system)
        .collection('grades').doc(grade);
  }

  CollectionReference? _questionsCollection() =>
      _gradeDocRef()?.collection('${widget.contentType}_questions');

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _load();
    _loadSavedQuestion();
  }

  @override
  void didUpdateWidget(SchoolConditionsWidget old) {
    super.didUpdateWidget(old);
    if (old.selectedCrop  != widget.selectedCrop  ||
        old.selectedStage != widget.selectedStage  ||
        old.selectedTopic != widget.selectedTopic) {
      _loadSavedQuestion();
    }
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final bundle = await EduSchoolConditionsService.getBundle(widget.schoolName);
      if (mounted) setState(() { _bundle = bundle; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSavedQuestion() async {
    final col = _questionsCollection();
    if (col == null) return;
    try {
      final key = _questionKey();
      final snap = await col
          .where('key', isEqualTo: key)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty && mounted) {
        setState(() =>
            _savedQuestion = snap.docs.first['question'] as String?);
      } else if (mounted) {
        setState(() => _savedQuestion = null);
      }
    } catch (_) {}
  }

  String _questionKey() =>
      '${widget.selectedCrop ?? ''}_${widget.selectedStage ?? ''}'
      '_${widget.selectedTopic ?? ''}';

  // ── AI guided question generation ─────────────────────────────────────────

  Future<void> _generateQuestion() async {
    final b = _bundle;
    if (b == null) return;
    setState(() => _aiLoading = true);

    final sat = b.sat;
    final iot = b.iot;
    final sb  = StringBuffer();

    if (sat != null) {
      sb
        ..writeln('Today\'s satellite data for ${b.location.county}:')
        ..writeln('- Rainfall: ${sat.precipitation.toStringAsFixed(1)} mm')
        ..writeln('- Air temperature: ${sat.airTemp.toStringAsFixed(1)}°C '
            '(max ${sat.airTempMax.toStringAsFixed(1)}°C)')
        ..writeln('- Humidity: ${sat.humidity.toStringAsFixed(0)}%')
        ..writeln('- Dew point: ${sat.dewPoint.toStringAsFixed(1)}°C '
            '(gap: ${(sat.airTemp - sat.dewPoint).abs().toStringAsFixed(1)}°C)')
        ..writeln('- Wind: ${sat.windSpeed.toStringAsFixed(1)} m/s')
        ..writeln('- Cloud cover: ${sat.cloudCover.toStringAsFixed(0)}%')
        ..writeln('- Root zone moisture: '
            '${(sat.rootZoneMoisture * 100).toStringAsFixed(0)}%')
        ..writeln('- 7-day total rain: ${b.rain7d.toStringAsFixed(1)} mm');
    }
    if (iot != null) {
      sb
        ..writeln('Soil sensor (${iot.isSimulated ? 'simulated' : 'live'}):')
        ..writeln('- N: ${iot.n.toStringAsFixed(0)} mg/kg, '
            'P: ${iot.p.toStringAsFixed(0)} mg/kg, '
            'K: ${iot.k.toStringAsFixed(0)} mg/kg')
        ..writeln('- pH: ${iot.ph.toStringAsFixed(1)}, '
            'Soil temp: ${iot.temperature.toStringAsFixed(1)}°C');
    }

    final cropCtx  = widget.selectedCrop  != null
        ? 'Crop: ${widget.selectedCrop}, Stage: ${widget.selectedStage ?? 'unknown'}' : '';
    final topicCtx = widget.selectedTopic != null
        ? 'Today\'s topic: ${widget.selectedTopic}' : '';

    final prompt = '''
You are a Kenyan CBC agriculture teacher preparing a class discussion question.

$sb
$cropCtx
$topicCtx

Generate ONE clear, specific guided question (2-3 sentences max) that:
1. Quotes the ACTUAL data values above.
2. Requires students to apply their knowledge of ${widget.selectedTopic ?? 'agriculture'} to explain what is happening and what a farmer should do.
3. Is appropriate for Grade 7-9 Kenyan CBC agriculture students.
4. Aligns with KICD competency: observe, record, and interpret field data.

Return only the question text — no preamble, no numbering, no markdown.
''';

    String result;
    try {
      final resp = await http.post(
        Uri.parse(
            'https://us-central1-kilimomkononi-e1031.cloudfunctions.net/askGemini'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'prompt': prompt}),
      ).timeout(const Duration(seconds: 30));
      final data = jsonDecode(resp.body);
      result = (data['text'] ??
              data['candidates']?[0]?['content']?['parts']?[0]?['text'] ??
              'Could not generate question.')
          .toString()
          .trim();
    } catch (_) {
      result = 'Could not reach AI service. Check connection.';
    }

    if (mounted) {
      setState(() { _aiQuestion = result; _aiLoading = false; });
      if (!result.contains('Could not')) {
        await _saveQuestion(result);
      }
    }
  }

  Future<void> _saveQuestion(String question) async {
    final col = _questionsCollection();
    if (col == null) return;          // ← null guard: no-op if classId invalid
    try {
      await col.add({
        'question':   question,
        'key':        _questionKey(),
        'crop':       widget.selectedCrop,
        'stage':      widget.selectedStage,
        'topic':      widget.selectedTopic,
        'schoolName': widget.schoolName,
        'createdAt':  FieldValue.serverTimestamp(),
      });
      if (mounted) setState(() => _savedQuestion = question);
    } catch (_) {}
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kLightGreen,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kBorder),
        ),
        child: Row(children: [
          const SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2,
                  color: _kMidGreen)),
          const SizedBox(width: 10),
          Text(
            'Loading conditions for '
            '${widget.schoolName.replaceAll('_', ' ')}…',
            style: const TextStyle(fontSize: 12, color: _kMidGreen),
          ),
        ]),
      );
    }

    final b = _bundle;
    if (b == null || !b.hasData) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _kLightGreen.withOpacity(0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA5C9A5)),
      ),
      child: Column(children: [
        // ── Header ──────────────────────────────────────────────────────────
        InkWell(
          onTap: _isTeacher
              ? () => setState(() => _expanded = !_expanded)
              : null,
          borderRadius: BorderRadius.vertical(
            top: const Radius.circular(12),
            bottom: _expanded
                ? Radius.zero
                : const Radius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            child: Row(children: [
              const Icon(Icons.sensors_rounded,
                  size: 16, color: _kMidGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TODAY\'S FARM CONDITIONS',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _kMidGreen,
                            letterSpacing: 0.7)),
                    Text(
                      '${b.location.county} · NASA POWER'
                      '${b.iot?.isSimulated == true ? ' · Simulated sensor' : ' · Live sensor'}',
                      style: const TextStyle(
                          fontSize: 10, color: Colors.black45),
                    ),
                  ],
                ),
              ),
              if (b.sat?.isStale == true)
                _pill('Cached', _kAmber, _kLightAmber),
              if (_isTeacher) ...[
                const SizedBox(width: 6),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: _kMidGreen,
                ),
              ],
            ]),
          ),
        ),

        // ── Expandable body ──────────────────────────────────────────────────
        if (_expanded || !_isTeacher)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 1, color: Color(0xFFBBD9BB)),
                const SizedBox(height: 10),

                // Weather tiles
                if (b.sat != null) _buildWeatherTiles(b.sat!),

                // Soil tiles
                if (b.iot != null) ...[
                  const SizedBox(height: 10),
                  _buildSoilTiles(b.iot!),
                ],

                // Risk cards
                if (b.sat != null) ...[
                  const SizedBox(height: 10),
                  _buildRiskCards(b),
                ],

                // Teacher: AI question section
                if (_isTeacher) ...[
                  const SizedBox(height: 10),
                  _buildTeacherQuestionSection(),
                ],

                // Student: saved teacher question
                if (!_isTeacher &&
                    (_savedQuestion?.isNotEmpty ?? false)) ...[
                  const SizedBox(height: 10),
                  _buildStudentQuestion(_savedQuestion!),
                ],
              ],
            ),
          ),
      ]),
    );
  }

  // ── Weather tiles ─────────────────────────────────────────────────────────

  Widget _buildWeatherTiles(EduSatelliteReading sat) {
    return Column(children: [
      Row(children: [
        Expanded(child: _weatherTile(Icons.water_drop_outlined, 'Rain today',
            '${sat.precipitation.toStringAsFixed(1)} mm',
            sat.precipitation > 25 ? _kRed
                : sat.precipitation > 5 ? _kBlue : Colors.grey,
            sat.precipitation > 25 ? 'Heavy'
                : sat.precipitation > 5 ? 'Moderate' : 'None')),
        const SizedBox(width: 6),
        Expanded(child: _weatherTile(Icons.thermostat_rounded, 'Temperature',
            '${sat.airTemp.toStringAsFixed(1)}°C',
            sat.airTemp > 34 ? _kRed : sat.airTemp > 28 ? _kAmber : _kGreen,
            sat.airTemp > 34 ? 'Heat stress' : sat.airTemp > 28 ? 'Warm' : 'Ideal')),
        const SizedBox(width: 6),
        Expanded(child: _weatherTile(Icons.water_outlined, 'Humidity',
            '${sat.humidity.toStringAsFixed(0)}%',
            sat.humidity > 80 ? _kRed : sat.humidity > 65 ? _kAmber : _kGreen,
            sat.humidity > 80 ? 'High risk' : sat.humidity > 65 ? 'Elevated' : 'Good')),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(child: _weatherTile(Icons.air_rounded, 'Wind',
            '${sat.windSpeed.toStringAsFixed(1)} m/s',
            sat.windSpeed < 3 ? _kGreen : sat.windSpeed < 6 ? _kAmber : _kRed,
            sat.windSpeed < 3 ? 'Safe to spray'
                : sat.windSpeed < 6 ? 'Moderate' : 'Strong')),
        const SizedBox(width: 6),
        Expanded(child: _weatherTile(Icons.cloud_rounded, 'Cloud cover',
            '${sat.cloudCover.toStringAsFixed(0)}%',
            sat.cloudCover > 70 ? Colors.blueGrey : _kGreen,
            sat.cloudCover > 70 ? 'Overcast'
                : sat.cloudCover > 40 ? 'Partly cloudy' : 'Clear')),
        const SizedBox(width: 6),
        Expanded(child: _weatherTile(Icons.grain_rounded, 'Dew gap',
            '${(sat.airTemp - sat.dewPoint).abs().toStringAsFixed(1)}°C',
            (sat.airTemp - sat.dewPoint).abs() < 4 ? _kRed
                : (sat.airTemp - sat.dewPoint).abs() < 8 ? _kAmber : _kGreen,
            (sat.airTemp - sat.dewPoint).abs() < 4 ? 'Leaf wet risk'
                : (sat.airTemp - sat.dewPoint).abs() < 8 ? 'Monitor' : 'Low risk')),
      ]),
    ]);
  }

  Widget _weatherTile(IconData icon, String label, String value,
      Color color, String badge) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Expanded(child: Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.black45),
              overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14,
            fontWeight: FontWeight.w700, color: Colors.black87)),
        const SizedBox(height: 4),
        _pill(badge, color, color.withOpacity(0.1)),
      ]),
    );
  }

  // ── Soil tiles ────────────────────────────────────────────────────────────

  Widget _buildSoilTiles(EduIotReading iot) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('SOIL SENSOR',
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
              color: Colors.brown, letterSpacing: 0.7)),
      const SizedBox(height: 6),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 1.5,
        children: [
          _soilTile('N',    iot.n.toStringAsFixed(0),           'mg/kg',
              iot.n < 15 ? _kRed : iot.n < 20 ? _kAmber : _kGreen,
              iot.n < 15 ? 'Low' : iot.n < 20 ? 'Fair' : 'Good'),
          _soilTile('P',    iot.p.toStringAsFixed(0),           'mg/kg',
              iot.p < 8 ? _kRed : iot.p < 10 ? _kAmber : _kGreen,
              iot.p < 8 ? 'Low' : iot.p < 10 ? 'Fair' : 'Good'),
          _soilTile('K',    iot.k.toStringAsFixed(0),           'mg/kg',
              iot.k < 80 ? _kRed : iot.k < 100 ? _kAmber : _kGreen,
              iot.k < 80 ? 'Low' : iot.k < 100 ? 'Fair' : 'Good'),
          _soilTile('pH',   iot.ph.toStringAsFixed(1),          '',
              iot.ph < 5.5 ? _kRed : iot.ph > 7.5 ? _kAmber : _kGreen,
              iot.ph < 5.5 ? 'Acidic' : iot.ph > 7.5 ? 'Alkaline' : 'Optimal'),
          _soilTile('Temp', iot.temperature.toStringAsFixed(1), '°C',
              iot.temperature > 35 ? _kRed : iot.temperature < 15 ? _kBlue : _kGreen,
              iot.temperature > 35 ? 'Hot' : iot.temperature < 15 ? 'Cold' : 'Good'),
          _soilTile('EC',   iot.ec.toStringAsFixed(0),          'µS/cm',
              iot.ec > 400 ? _kRed : iot.ec > 250 ? _kAmber : _kGreen,
              iot.ec > 400 ? 'High' : iot.ec > 250 ? 'Moderate' : 'Good'),
        ],
      ),
    ]);
  }

  Widget _soilTile(String symbol, String value, String unit,
      Color color, String verdict) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(symbol, style: const TextStyle(fontSize: 10,
              color: Colors.black45, fontWeight: FontWeight.w600)),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(value, style: const TextStyle(fontSize: 14,
                fontWeight: FontWeight.w700, color: Colors.black87)),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Text(unit,
                    style: const TextStyle(fontSize: 8, color: Colors.black38)),
              ),
            ],
          ]),
          _pill(verdict, color, color.withOpacity(0.12)),
        ],
      ),
    );
  }

  // ── Risk cards (self-contained, no enterprise import needed) ──────────────

  Widget _buildRiskCards(EduConditionsBundle b) {
    final sat = b.sat!;
    final cards = <_RiskEntry>[];

    final humidity  = sat.humidity;
    final dewDiff   = (sat.airTemp - sat.dewPoint).abs();
    final airTemp   = sat.airTemp;

    // Fungal risk
    if (humidity > 70 && airTemp > 18 && airTemp < 30) {
      final isCritical = humidity > 80 && dewDiff < 4;
      final isHigh     = humidity > 80 || dewDiff < 4;
      cards.add(_RiskEntry(
        icon:  Icons.grain_rounded,
        title: 'Fungal risk — ${isCritical ? 'Critical' : isHigh ? 'High' : 'Moderate'}',
        color: isCritical ? _kRed : isHigh ? const Color(0xFFBF360C) : _kAmber,
        bullets: [
          'Humidity: ${humidity.toStringAsFixed(0)}% '
              '${humidity > 80 ? '⚠ Above 80%' : '— elevated'}',
          'Dew point gap: ${dewDiff.toStringAsFixed(1)}°C '
              '${dewDiff < 4 ? '⚠ Leaves likely wet at night' : '— monitor'}',
          'Temperature: ${airTemp.toStringAsFixed(1)}°C '
              '— in fungal growth range (18–30°C)',
          if (isCritical || isHigh)
            'Action: Scout crops. Consider preventive fungicide.',
        ],
      ));
    }

    // Drought risk
    if (b.rain7d < 5 && (sat.rootZoneMoisture < 0.25 || airTemp > 30)) {
      cards.add(_RiskEntry(
        icon:  Icons.wb_sunny_outlined,
        title: 'Dry conditions — ${airTemp > 30 ? 'High' : 'Moderate'}',
        color: airTemp > 30 ? const Color(0xFFBF360C) : _kAmber,
        bullets: [
          'Rain last 7 days: ${b.rain7d.toStringAsFixed(1)} mm — very low',
          'Root zone moisture: '
              '${(sat.rootZoneMoisture * 100).toStringAsFixed(0)}% '
              '${sat.rootZoneMoisture < 0.25 ? '⚠ Below critical' : ''}',
          if (airTemp > 30) 'Air temperature: ${airTemp.toStringAsFixed(1)}°C '
              '— crop stress range',
          'Action: Irrigation recommended.',
        ],
      ));
    }

    // Spray window
    final windOk  = sat.windSpeed < 3;
    final rainOk  = sat.precipitation < 2;
    final hourNow = DateTime.now().hour;
    final inHours = hourNow >= 6 && hourNow <= 17;
    final canSpray = windOk && rainOk && inHours;
    cards.add(_RiskEntry(
      icon:  Icons.air_rounded,
      title: canSpray ? 'Spray window — Safe today' : 'Spray window — Hold',
      color: canSpray ? _kMidGreen : _kAmber,
      bullets: [
        'Wind: ${sat.windSpeed.toStringAsFixed(1)} m/s  '
            '${windOk ? '✓ Below 3 m/s limit' : '⚠ Above 3 m/s — drift risk'}',
        'Rain today: ${sat.precipitation.toStringAsFixed(1)} mm  '
            '${rainOk ? '✓ Dry conditions' : '⚠ Rain may wash off product'}',
        'Time: ${hourNow.toString().padLeft(2, '0')}:00  '
            '${inHours ? '✓ Within safe hours (6am–5pm)' : '⚠ Outside safe hours'}',
        if (canSpray) 'Best times: 6–9am or 4–5pm.',
      ],
    ));

    if (cards.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('CURRENT CONDITIONS',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                color: _kMidGreen, letterSpacing: 0.7)),
        const SizedBox(height: 6),
        ...cards.map((c) => _RiskCard(entry: c)),
      ],
    );
  }

  // ── Teacher: AI question section ──────────────────────────────────────────

  Widget _buildTeacherQuestionSection() {
    final hasContext =
        widget.selectedCrop != null || widget.selectedTopic != null;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Divider(height: 1, color: Color(0xFFBBD9BB)),
      const SizedBox(height: 10),
      Row(children: [
        const Icon(Icons.psychology_rounded, size: 14, color: _kMidGreen),
        const SizedBox(width: 6),
        const Text('GUIDED TEACHING QUESTION',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                color: _kMidGreen, letterSpacing: 0.6)),
        const Spacer(),
        if (!hasContext)
          const Text('Select crop & topic first',
              style: TextStyle(fontSize: 10, color: Colors.black38)),
      ]),
      const SizedBox(height: 8),

      if (_savedQuestion?.isNotEmpty ?? false) ...[
        _questionBox(_savedQuestion!, Colors.green),
        const SizedBox(height: 8),
      ],
      if (_aiQuestion?.isNotEmpty ?? false &&
          _aiQuestion != _savedQuestion) ...[
        _questionBox(_aiQuestion!, Colors.blue),
        const SizedBox(height: 8),
      ],

      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: (!hasContext || _aiLoading) ? null : _generateQuestion,
          icon: _aiLoading
              ? const SizedBox(width: 13, height: 13,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _kMidGreen))
              : const Icon(Icons.auto_awesome, size: 14, color: _kMidGreen),
          label: Text(
            _aiLoading ? 'Generating…'
                : hasContext
                    ? '✨ Generate question from today\'s data'
                    : 'Select crop/topic to generate question',
            style: const TextStyle(fontSize: 12, color: _kMidGreen),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(
                color: hasContext ? _kMidGreen : Colors.grey,
                width: 0.5),
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
      if (hasContext && _aiQuestion == null && _savedQuestion == null) ...[
        const SizedBox(height: 6),
        const Text(
          'The AI will write a question from today\'s real sensor + '
          'satellite data for your students to answer.',
          style: TextStyle(fontSize: 11, color: Colors.black45, height: 1.4),
        ),
      ],
    ]);
  }

  // ── Student: saved question box ───────────────────────────────────────────

  Widget _buildStudentQuestion(String question) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBlue.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.school_rounded, size: 14, color: _kBlue),
          const SizedBox(width: 6),
          const Text('TODAY\'S QUESTION FROM YOUR TEACHER',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  color: _kBlue, letterSpacing: 0.5)),
        ]),
        const SizedBox(height: 8),
        Text(question,
            style: const TextStyle(fontSize: 13, color: Colors.black87,
                height: 1.55, fontStyle: FontStyle.italic)),
        const SizedBox(height: 6),
        const Text('Answer this in the "Your Idea / Solution" field below.',
            style: TextStyle(fontSize: 11, color: Colors.black45)),
      ]),
    );
  }

  Widget _questionBox(String question, MaterialColor color) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color.shade50,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.shade200),
    ),
    child: Text(question,
        style: TextStyle(fontSize: 12.5, color: color.shade900, height: 1.5)),
  );

  // ── Shared helpers ────────────────────────────────────────────────────────

  Widget _pill(String text, Color fg, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(text,
        style: TextStyle(fontSize: 9, color: fg,
            fontWeight: FontWeight.w600)),
  );
}

// ── Risk card internal model ───────────────────────────────────────────────

class _RiskEntry {
  final IconData icon;
  final String title;
  final Color color;
  final List<String> bullets;
  const _RiskEntry({
    required this.icon,
    required this.title,
    required this.color,
    required this.bullets,
  });
}

class _RiskCard extends StatelessWidget {
  final _RiskEntry entry;
  const _RiskCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final bg     = entry.color.withOpacity(0.07);
    final border = entry.color.withOpacity(0.25);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(entry.icon, size: 14, color: entry.color),
          const SizedBox(width: 7),
          Expanded(child: Text(entry.title,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: entry.color, height: 1.3))),
        ]),
        const SizedBox(height: 8),
        ...entry.bullets.where((b) => b.trim().isNotEmpty).map((b) =>
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('• ', style: TextStyle(fontSize: 12.5,
                  color: entry.color.withOpacity(0.6), height: 1.45)),
              Expanded(child: Text(b, style: TextStyle(fontSize: 12.5,
                  color: entry.color.withOpacity(0.85), height: 1.45))),
            ]),
          )),
      ]),
    );
  }
}