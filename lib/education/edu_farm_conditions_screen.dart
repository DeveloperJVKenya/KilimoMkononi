// lib/education/edu_farm_conditions_screen.dart
//
// Classroom farm conditions screen — education-only.
// Completely separate from the enterprise SatelliteDataScreen.
//
// ── WHY THIS EXISTS ────────────────────────────────────────────────────────
// The enterprise SatelliteDataScreen is designed for farmers:
//   • Shows flood/drought/spray ALERTS → action buttons
//   • "Your farm" language throughout
//   • Refresh tied to farmer's county in SharedPreferences
//   • No teaching tools
//
// This screen is designed for classrooms:
//   • "Today's lesson data" framing
//   • Shows which KICD/CBC curriculum strand the data maps to
//   • Teacher: collapsible full panel + AI guided question generator
//   • Student: read-only data display + teacher's question prominently shown
//   • 7-day history as a readable table (discuss trends in class)
//   • No farm alert banners, no "irrigate now" buttons
//   • School name in header, not a county farm label
//
// ── NAVIGATION ─────────────────────────────────────────────────────────────
// Reachable from field_home.dart, pest_home.dart, disease_home.dart
// via the "Farm Data" bottom nav tab.
//
// ── IMPORT IN HOME FILES ───────────────────────────────────────────────────
// import 'package:kilimomkononi/education/edu_farm_conditions_screen.dart';
//
// ── DATA SOURCE ────────────────────────────────────────────────────────────
// EduSchoolConditionsService — education-only, no shared state with
// enterprise NasaPowerService or IotSensorService.


import 'package:flutter/material.dart';
import 'package:kilimomkononi/models/education_user.dart';
import 'package:kilimomkononi/education/services/edu_school_conditions_service.dart';
import 'package:kilimomkononi/education/widgets/school_conditions_widget.dart';

// ── Colour tokens ──────────────────────────────────────────────────────────
const _kDark   = Color(0xFF032704);
const _kGreen  = Color(0xFF1B5E20);
const _kMid    = Color(0xFF2A6B2A);
const _kLight  = Color(0xFFE8F5E9);
const _kBlue   = Color(0xFF0D47A1);
const _kBorder = Color(0xFFDDE5DD);
const _kPageBg = Color(0xFFF4F6F3);

// ── KICD/CBC topic mapping ─────────────────────────────────────────────────
// Maps a contentType to the curriculum strand it supports.

const Map<String, _KicdTopic> _kicdTopics = {
  'field_submissions': _KicdTopic(
    strand: 'Agriculture · Crop Production',
    grade: 'Grade 7–9',
    competency: 'Observe, record, and interpret field data from the immediate environment.',
    icon: Icons.grass_rounded,
  ),
  'disease_data': _KicdTopic(
    strand: 'Agriculture · Pest & Disease Management',
    grade: 'Grade 7–9',
    competency: 'Identify disease conditions and apply knowledge of environmental factors to management decisions.',
    icon: Icons.local_hospital_outlined,
  ),
  'pest_data': _KicdTopic(
    strand: 'Agriculture · Pest & Disease Management',
    grade: 'Grade 7–9',
    competency: 'Identify pest conditions and relate weather and soil data to integrated pest management.',
    icon: Icons.bug_report_outlined,
  ),
};

class _KicdTopic {
  final String strand;
  final String grade;
  final String competency;
  final IconData icon;
  const _KicdTopic({
    required this.strand,
    required this.grade,
    required this.competency,
    required this.icon,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class EduFarmConditionsScreen extends StatefulWidget {
  final EduRole role;
  final String schoolName;
  final String classId;

  /// Which curriculum module opened this screen.
  /// Controls which KICD topic is shown and which questions are generated.
  /// One of: 'field_submissions', 'disease_data', 'pest_data'
  final String contentType;

  /// Optional context passed from the data form — e.g. the crop/stage the
  /// teacher has currently selected. Used to make AI questions more relevant.
  final String? selectedCrop;
  final String? selectedStage;
  final String? selectedTopic;

  const EduFarmConditionsScreen({
    super.key,
    required this.role,
    required this.schoolName,
    required this.classId,
    this.contentType = 'field_submissions',
    this.selectedCrop,
    this.selectedStage,
    this.selectedTopic,
  });

  @override
  State<EduFarmConditionsScreen> createState() =>
      _EduFarmConditionsScreenState();
}

class _EduFarmConditionsScreenState
    extends State<EduFarmConditionsScreen> {
  EduConditionsBundle? _bundle;
  bool _loading = true;
  bool _historyExpanded = false;

  bool get _isTeacher =>
      widget.role == EduRole.teacher ||
      widget.role == EduRole.headteacher;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final b = await EduSchoolConditionsService.getBundle(widget.schoolName);
      if (mounted) setState(() { _bundle = b; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final topic = _kicdTopics[widget.contentType] ?? _kicdTopics['field_submissions']!;

    return Scaffold(
      backgroundColor: _kPageBg,
      appBar: _buildAppBar(topic),
      body: _loading
          ? _buildLoading()
          : _bundle == null || !_bundle!.hasData
              ? _buildEmpty()
              : RefreshIndicator(
                  color: _kMid,
                  onRefresh: () async {
                    await EduSchoolConditionsService.refresh(widget.schoolName);
                    await _load();
                  },
                  child: _buildBody(topic),
                ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(_KicdTopic topic) => AppBar(
    backgroundColor: _kDark,
    foregroundColor: Colors.white,
    elevation: 0,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.schoolName.replaceAll('_', ' '),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
              color: Colors.white),
        ),
        Text(
          '${topic.strand} · Today\'s Data',
          style: const TextStyle(fontSize: 10, color: Colors.white60),
        ),
      ],
    ),
    actions: [
      if (!_loading)
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          tooltip: 'Refresh data',
          onPressed: () async {
            await EduSchoolConditionsService.refresh(widget.schoolName);
            await _load();
          },
        ),
    ],
  );

  // ── Main body ─────────────────────────────────────────────────────────────

  Widget _buildBody(_KicdTopic topic) {
    final b = _bundle!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [

        // ── 1. KICD curriculum banner ──────────────────────────────────────
        _buildKicdBanner(topic),

        // ── 2. Stale data notice ───────────────────────────────────────────
        if (b.sat?.isStale == true)
          _staleBanner(),

        // ── 3. SchoolConditionsWidget ─────────────────────────────────────
        // This is the full conditions panel (teacher: collapsible with AI;
        // student: read-only with teacher question). We embed it directly
        // so it stays in sync with the data forms.
        SchoolConditionsWidget(
          role:          widget.role,
          schoolName:    widget.schoolName,
          classId:       widget.classId,
          selectedCrop:  widget.selectedCrop,
          selectedStage: widget.selectedStage,
          selectedTopic: widget.selectedTopic,
          contentType:   widget.contentType,
        ),

        // ── 4. 7-day history table ─────────────────────────────────────────
        _buildHistorySection(),

        // ── 5. How to read this data (student-facing explainer) ────────────
        if (!_isTeacher) ...[
          const SizedBox(height: 14),
          _buildStudentExplainer(topic),
        ],

        // ── 6. Teacher: classroom activity ideas ───────────────────────────
        if (_isTeacher) ...[
          const SizedBox(height: 14),
          _buildTeacherActivityPanel(topic),
        ],

        const SizedBox(height: 24),
      ],
    );
  }

  // ── 1. KICD banner ────────────────────────────────────────────────────────

  Widget _buildKicdBanner(_KicdTopic topic) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(topic.icon, size: 18, color: _kMid),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(topic.strand,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: _kGreen)),
            Text(topic.grade,
                style: const TextStyle(fontSize: 11, color: _kMid)),
            const SizedBox(height: 4),
            Text('CBC competency: ${topic.competency}',
                style: const TextStyle(fontSize: 11, color: Colors.black54,
                    height: 1.45)),
          ],
        )),
      ]),
    );
  }

  // ── 2. Stale banner ───────────────────────────────────────────────────────

  Widget _staleBanner() => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF8E1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.orange.shade200),
    ),
    child: const Row(children: [
      Icon(Icons.wifi_off_rounded, size: 13, color: Colors.orange),
      SizedBox(width: 6),
      Expanded(
        child: Text(
          'Showing cached data — connect to the internet and tap ↻ to refresh.',
          style: TextStyle(fontSize: 11, color: Colors.deepOrange),
        ),
      ),
    ]),
  );

  // ── 4. 7-day history table ────────────────────────────────────────────────

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Collapsible header
        GestureDetector(
          onTap: () =>
              setState(() => _historyExpanded = !_historyExpanded),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kBorder),
            ),
            child: Row(children: [
              const Icon(Icons.table_chart_outlined,
                  size: 14, color: Colors.black45),
              const SizedBox(width: 7),
              const Text('7-DAY HISTORY TABLE',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: Colors.black54, letterSpacing: 0.7)),
              const Spacer(),
              const Text('For class discussion',
                  style: TextStyle(fontSize: 10, color: Colors.black38)),
              const SizedBox(width: 6),
              Icon(
                _historyExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 18, color: Colors.black38,
              ),
            ]),
          ),
        ),

        if (_historyExpanded) ...[
          const SizedBox(height: 8),
          _buildHistoryTable(),
          if (!_isTeacher) ...[
            const SizedBox(height: 8),
            _infoBox(
              '📊 Use this table to identify trends. '
              'Which day had the most rain? '
              'Which day had the highest temperature? '
              'How might this affect the crops in the school farm?',
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildHistoryTable() {
    // We use EduSchoolConditionsService cached bundle —
    // history isn't stored separately on EduConditionsBundle yet,
    // so we show a "pull from service" note, or reuse the last
    // 7-day precipitation from rain7d.
    //
    // For Phase 1 we show a loading-aware placeholder that gracefully
    // degrades. In Phase 2, extend EduConditionsBundle with List<EduSatelliteReading> history.
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Column(children: [
        // Table header
        _tableHeader(),
        // Show rain7d summary if full history not available
        if (_bundle?.rain7d != null)
          _tableNote(
            '7-day total rainfall: '
            '${_bundle!.rain7d.toStringAsFixed(1)} mm  ·  '
            'Full day-by-day history loads in Phase 2 when the school '
            'sensor is active.',
          ),
      ]),
    );
  }

  Widget _tableHeader() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: const BoxDecoration(
      color: Color(0xFFF0F4EF),
      borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
    ),
    child: const Row(children: [
      Expanded(flex: 2, child: Text('Day', style: TextStyle(fontSize: 11,
          fontWeight: FontWeight.w600, color: Colors.black54))),
      Expanded(child: Text('Rain\n(mm)', style: TextStyle(fontSize: 10,
          fontWeight: FontWeight.w600, color: Colors.black54),
          textAlign: TextAlign.center)),
      Expanded(child: Text('Temp\n(°C)', style: TextStyle(fontSize: 10,
          fontWeight: FontWeight.w600, color: Colors.black54),
          textAlign: TextAlign.center)),
      Expanded(child: Text('Hum.\n(%)', style: TextStyle(fontSize: 10,
          fontWeight: FontWeight.w600, color: Colors.black54),
          textAlign: TextAlign.center)),
      Expanded(child: Text('Wind\nm/s', style: TextStyle(fontSize: 10,
          fontWeight: FontWeight.w600, color: Colors.black54),
          textAlign: TextAlign.center)),
    ]),
  );

  Widget _tableNote(String text) => Padding(
    padding: const EdgeInsets.all(12),
    child: Text(text,
        style: const TextStyle(fontSize: 11, color: Colors.black45,
            height: 1.5)),
  );

  // ── 5. Student explainer ──────────────────────────────────────────────────

  Widget _buildStudentExplainer(_KicdTopic topic) {
    final items = _explainerItems(topic.strand);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('HOW TO READ THIS DATA',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  color: Colors.black45, letterSpacing: 0.7)),
        ),
        ...items.map((item) => _explainerCard(
            icon: item['icon'] as String,
            title: item['title'] as String,
            body: item['body'] as String)),
      ],
    );
  }

  List<Map<String, String>> _explainerItems(String strand) {
    final base = [
      {
        'icon': '🛰️',
        'title': 'Where does this data come from?',
        'body': 'NASA satellites measure atmospheric and soil conditions '
            'from space every day. The data shown here is for your '
            'school\'s location, fetched automatically.',
      },
      {
        'icon': '🌧️',
        'title': 'What does rainfall tell us?',
        'body': 'Rainfall determines if crops need irrigation, whether '
            'fertiliser will be washed away, and whether waterlogging '
            'is a risk. Track the 7-day total to understand trends.',
      },
      {
        'icon': '💧',
        'title': 'What is root zone moisture?',
        'body': 'This is the percentage of water in the soil where roots '
            'grow (0–100 cm deep). Below 35% means crops may need '
            'water. Above 80% means the soil may be waterlogged.',
      },
      {
        'icon': '🌡️',
        'title': 'Why does temperature matter?',
        'body': 'Most crops grow best between 18°C and 30°C. Too hot '
            'or too cold slows growth, affects germination, and can '
            'damage roots. Extreme heat above 35°C causes stress.',
      },
    ];

    if (strand.contains('Disease') || strand.contains('Pest')) {
      base.add({
        'icon': '🍄',
        'title': 'Dew point gap — what is it?',
        'body': 'When air temperature and dew point are close (less '
            'than 4°C apart), moisture forms on leaves at night. '
            'Wet leaves allow fungal spores to germinate. This is '
            'why we check the dew point gap for disease risk.',
      });
      base.add({
        'icon': '💨',
        'title': 'Wind and pesticide spraying',
        'body': 'Pesticides must not be sprayed when wind is above '
            '3 m/s. Wind carries chemicals off target, wasting '
            'inputs and potentially harming people and animals nearby.',
      });
    }

    return base;
  }

  Widget _explainerCard({
    required String icon,
    required String title,
    required String body,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(child: Text(title,
                style: const TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w600, color: Colors.black87))),
          ]),
          const SizedBox(height: 7),
          Text(body,
              style: const TextStyle(fontSize: 12.5,
                  color: Colors.black54, height: 1.55)),
        ]),
      );

  // ── 6. Teacher activity panel ─────────────────────────────────────────────

  Widget _buildTeacherActivityPanel(_KicdTopic topic) {
    final activities = _teacherActivities(topic.strand);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('CLASSROOM ACTIVITY IDEAS',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  color: Colors.black45, letterSpacing: 0.7)),
        ),
        ...activities.map((a) => _activityCard(
            emoji: a['emoji'] as String,
            title: a['title'] as String,
            instruction: a['instruction'] as String,
            duration: a['duration'] as String)),
      ],
    );
  }

  List<Map<String, String>> _teacherActivities(String strand) {
    final base = [
      {
        'emoji':       '📊',
        'title':       'Interpret today\'s data',
        'instruction': 'Show students the soil moisture and temperature '
            'readings. Ask: "Is this good or bad for our school crop right '
            'now? What would you tell a farmer to do?" Let 3–4 students '
            'respond and justify their answers.',
        'duration':    '10 min',
      },
      {
        'emoji':       '📅',
        'title':       'Rainfall trend analysis',
        'instruction': 'Open the 7-day history table. Ask students to '
            'identify the wettest day and driest day. Ask: "If you were '
            'planting next week, would you irrigate? Why or why not?"',
        'duration':    '15 min',
      },
      {
        'emoji':       '✏️',
        'title':       'Data recording exercise',
        'instruction': 'Ask each student to record today\'s N, P, K, pH '
            'values from the soil sensor in their exercise book. Then look '
            'up the optimal range for the school\'s main crop. Is the '
            'school farm soil in the right range? What fertiliser is needed?',
        'duration':    '20 min',
      },
    ];

    if (strand.contains('Disease') || strand.contains('Pest')) {
      base.add({
        'emoji':       '🍄',
        'title':       'Disease risk prediction',
        'instruction': 'Show students today\'s humidity and dew point gap. '
            'Ask them to predict which diseases are most likely to appear '
            'in the school farm this week, using their knowledge from the '
            'disease management section. Have them write a one-sentence '
            'recommendation for the school farm.',
        'duration':    '15 min',
      });
    }

    return base;
  }

  Widget _activityCard({
    required String emoji,
    required String title,
    required String instruction,
    required String duration,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(child: Text(title,
                style: const TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w600, color: Colors.black87))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: _kLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(duration,
                  style: const TextStyle(fontSize: 10, color: _kMid,
                      fontWeight: FontWeight.w500)),
            ),
          ]),
          const SizedBox(height: 7),
          Text(instruction,
              style: const TextStyle(fontSize: 12.5,
                  color: Colors.black54, height: 1.55)),
        ]),
      );

  // ── Info box ──────────────────────────────────────────────────────────────

  Widget _infoBox(String text) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F7FF),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _kBlue.withValues(alpha: 0.2)),
    ),
    child: Text(text,
        style: const TextStyle(fontSize: 12, color: Colors.black54,
            height: 1.5)),
  );

  // ── Loading / empty ───────────────────────────────────────────────────────

  Widget _buildLoading() => const Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      CircularProgressIndicator(color: _kMid),
      SizedBox(height: 16),
      Text('Fetching conditions for your school…',
          style: TextStyle(fontSize: 13, color: Colors.black45)),
    ]),
  );

  Widget _buildEmpty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.satellite_alt_rounded,
            size: 48, color: Colors.black26),
        const SizedBox(height: 16),
        const Text('Could not load conditions',
            style: TextStyle(fontSize: 15,
                fontWeight: FontWeight.w600, color: Colors.black54)),
        const SizedBox(height: 8),
        const Text(
          'Check your internet connection and try again.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.black38),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kMid,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ]),
    ),
  );
}