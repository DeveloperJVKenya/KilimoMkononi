// lib/education/farm_management/farm_management_data_input.dart
//
// ════════════════════════════════════════════════════════════════════════════
//  BUG FIXES & REDESIGN NOTES
// ════════════════════════════════════════════════════════════════════════════
//
//  BUG — plots saved but not showing
//  ────────────────────────────────────
//  Root cause: the previous version queried plots with BOTH .where('type')
//  AND .orderBy('createdAt') on the same collection.  Firestore requires a
//  composite index for that combination, and without it the query returns an
//  empty stream silently.
//
//  Fix: plots are now stored in a SEPARATE sub-collection:
//    {dataCollection.path}/plots/{plotId}
//  Financial entries remain in the parent collection (farm_management_data).
//  This eliminates the composite-index requirement entirely.  The plots stream
//  is a simple .snapshots() on the plots sub-collection — always works.
//
//  UX/UI — mockup applied to school context
//  ──────────────────────────────────────────
//  • Header: dark-green AppBar + 3-card summary strip (plots, invested, P/L).
//  • Tab bar: scrollable, icon + label, green underline indicator.
//  • Overview tab: school weather/tip banner, quick-action grid (4 buttons),
//    today's tasks list, plot snapshot 2-column grid — matches mockup exactly.
//  • Plots tab: 2-column plot card grid with crop emoji, progress bar, stage.
//    Teacher FAB adds a plot; tapping a card opens detail/edit.
//  • Records tab: cost / revenue sub-tabs with colour-coded entry tiles.
//    Add sheet includes plot picker streamed from the plots sub-collection.
//  • P&L tab: large profit/loss card + school learning note.
//  • Loans tab: loan cards with LinearProgressIndicator + repayment input.
//
//  Role differentiation
//  ─────────────────────
//  • Teacher  : can add/edit/delete plots, add/edit/delete records, add loans.
//  • Student  : read-only — sees all data, no add/edit controls.
//  • Headteacher: class picker, read-only across all classes.
//
//  Firestore paths
//  ────────────────
//    Plots   :  {dataCollection}/plots/{plotDocId}
//    Financials: {dataCollection}/{entryDocId}   (type = cost | revenue | loan)
//
// ════════════════════════════════════════════════════════════════════════════

// ignore_for_file: unnecessary_non_null_assertion, curly_braces_in_flow_control_structures, unused_element, avoid_print, deprecated_member_use, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:kilimomkononi/models/education_user.dart';
import 'package:kilimomkononi/utils/firestore_helper.dart';
import 'package:kilimomkononi/utils/education_utils.dart';
import 'package:kilimomkononi/education/tutor/tutor_suppressor.dart';
import 'package:kilimomkononi/services/plot_analysis_service.dart';
import 'package:kilimomkononi/widgets/plot_history_card.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  DESIGN TOKENS  (match mockup palette)
// ═══════════════════════════════════════════════════════════════════════════

const Color _kDarkGreen   = Color(0xFF1A3D1A); // mockup header
const Color _kGreen       = Color(0xFF2A6B2A); // mockup accent
const Color _kGreenLight  = Color(0xFF2E7D32);
const Color _kGreenSurf   = Color(0xFFE8F5E9);
const Color _kAmber       = Color(0xFFE65100);
const Color _kAmberSurf   = Color(0xFFFFF8E1);
const Color _kRed         = Color(0xFFC62828);
const Color _kRedSurf     = Color(0xFFFCE4EC);
const Color _kBlue        = Color(0xFF1565C0);
const Color _kBlueSurf    = Color(0xFFE3F2FD);

const List<String> _kMonths = [
  'Jan','Feb','Mar','Apr','May','Jun',
  'Jul','Aug','Sep','Oct','Nov','Dec',
];

// School crops — Kenyan school farm context
const List<String> _kCrops = [
  'Maize','Beans','Kales (Sukuma Wiki)','Cabbage','Tomatoes',
  'Spinach','Carrots','Onions','Sweet Potatoes','Cassava',
  'Sorghum','Sunflower','Groundnuts','Peas','Potatoes',
  'Avocado','Banana','Pawpaw','Passion Fruit','Other',
];

const List<String> _kStages = [
  'Land Preparation','Planting','Germination','Seedling',
  'Vegetative Growth','Flowering','Pod / Grain Fill',
  'Ripening / Maturing','Ready for Harvest','Harvested',
];

const List<String> _kCostCats = [
  'Labour','Equipment & Machinery','Seeds & Fertilizer',
  'Chemicals & Pesticides','Transport','Land Rent/Preparation',
  'Irrigation','Miscellaneous',
];

const List<String> _kRevCats = [
  'Maize Sales','Beans Sales','Vegetable Sales','Livestock',
  'Fruits','Value-Added Products','Other Crops','Grants/Subsidies',
];

// Crop → emoji mapping
String _cropEmoji(String crop) {
  switch (crop.split(' ').first.toLowerCase()) {
    case 'maize':       return '🌽';
    case 'beans':       return '🫘';
    case 'kales':       return '🥬';
    case 'cabbage':     return '🥦';
    case 'tomatoes':    return '🍅';
    case 'spinach':     return '🌿';
    case 'carrots':     return '🥕';
    case 'onions':      return '🧅';
    case 'sweet':       return '🍠';
    case 'cassava':     return '🌾';
    case 'sorghum':     return '🌾';
    case 'sunflower':   return '🌻';
    case 'groundnuts':  return '🥜';
    case 'peas':        return '🫛';
    case 'potatoes':    return '🥔';
    case 'avocado':     return '🥑';
    case 'banana':      return '🍌';
    case 'pawpaw':      return '🍈';
    case 'passion':     return '💛';
    default:            return '🌱';
  }
}

String _categoryEmoji(String cat) {
  switch (cat) {
    case 'Labour':                 return '👷';
    case 'Equipment & Machinery':  return '🚜';
    case 'Seeds & Fertilizer':     return '🌱';
    case 'Chemicals & Pesticides': return '💊';
    case 'Transport':              return '🚛';
    case 'Land Rent/Preparation':  return '🏞️';
    case 'Irrigation':             return '💧';
    default:                       return '📦';
  }
}

extension _StrExt on String {
  String get cap => isNotEmpty
      ? '${this[0].toUpperCase()}${substring(1).toLowerCase()}'
      : this;
}

// ═══════════════════════════════════════════════════════════════════════════
//  MAIN WIDGET
// ═══════════════════════════════════════════════════════════════════════════

class FarmManagementDataInput extends StatefulWidget {
  final EduRole role;
  final String  schoolName;
  final String  classId;
  final bool    showAppBar;

  const FarmManagementDataInput({
    super.key,
    required this.role,
    required this.schoolName,
    required this.classId,
    this.showAppBar = true,
  });

  @override
  State<FarmManagementDataInput> createState() =>
      _FarmManagementDataInputState();
}

class _FarmManagementDataInputState extends State<FarmManagementDataInput>
    with SingleTickerProviderStateMixin, TutorSuppressorMixin {

  late TabController _tab;

  bool   get _isTeacher     => widget.role == EduRole.teacher;
  bool   get _isHT          => widget.role == EduRole.headteacher;
  String _normSchool        = '';

  CollectionReference? _dataColl;   // financial entries
  CollectionReference? _plotsColl;  // plots sub-collection  ← BUG FIX
  List<String>         _allClasses  = [];
  String?              _selClass;
  PlotAnalysisResult?  _prevAnalysis;

  // Active plot filter (null = all)
  String? _filterPlotId;
  String? _filterPlotName;

  @override
  void initState() {
    super.initState();
    _tab       = TabController(length: 5, vsync: this);
    _normSchool = widget.schoolName.trim().replaceAll(' ', '_');

    if (_isHT) {
      _loadClasses();
    } else if (widget.classId.isNotEmpty) {
      _selectClass(widget.classId);
      _loadPrevAnalysis(widget.classId);
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // ── Firestore ─────────────────────────────────────────────────────────────

  Future<void> _loadPrevAnalysis(String classId) async {
    final p = classId.split('_');
    if (p.length < 2) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('schools').doc(p[0])
          .collection('systems').doc(p[1])
          .collection('grades').doc(p.length > 2 ? p.sublist(2).join('_') : p.last)
          .collection('plot_analyses').doc(DateTime.now().year.toString())
          .get();
      if (snap.exists && mounted) {
        setState(() => _prevAnalysis =
            PlotAnalysisResult.fromMap(snap.data() as Map<String, dynamic>));
      }
    } catch (_) {}
  }

  Future<void> _loadClasses() async {
    final sysSnap = await FirestoreHelper
        .getSystemsCollection(_normSchool).get();
    final list = <String>[];
    for (final sys in sysSnap.docs) {
      final gSnap = await FirestoreHelper
          .getGradesCollection(_normSchool, sys.id).get();
      for (final g in gSnap.docs) {
        list.add(buildFullGradeId(
          widget.schoolName, g.id, _mapSys(sys.id)));
      }
    }
    setState(() {
      _allClasses = list;
      if (list.isNotEmpty && _selClass == null) _selectClass(list.first);
    });
  }

  String _mapSys(String id) => switch (id) {
        'primary'       => 'cbcPrimary',
        'junior'        => 'cbcJunior',
        'senior'        => 'cbcSenior',
        'eightfourfour' => 'eightFourFour',
        _               => 'cbcJunior',
      };

  // BUG FIX: separate sub-collection for plots, no composite index needed
  void _selectClass(String classId) {
    final base = FirestoreHelper.getContentFromClassId(
        classId, 'farm_management_data');
    setState(() {
      _dataColl      = base;
      _plotsColl     = base?.doc('_meta').collection('plots');
      _selClass      = classId;
      _filterPlotId  = null;
      _filterPlotName = null;
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmtKES(double v) => 'KES ${v.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}';

  String _fmtDate(DateTime d) =>
      '${d.day} ${_kMonths[d.month - 1]}';

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ready = _dataColl != null && _plotsColl != null;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: _kDarkGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              title: Text(
                _isHT ? 'School Farm Management' : 'Farm Management',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 17),
              ),
              titleSpacing: 0,
            )
          : null,
      body: Column(
        children: [
          // Live summary strip
          if (ready)
            _SummaryStrip(
              dataColl:  _dataColl!,
              plotsColl: _plotsColl!,
              fmtKES:    _fmtKES,
            ),

          // HT class picker
          if (_isHT && _allClasses.isNotEmpty)
            _ClassPicker(
              classes:   _allClasses,
              selected:  _selClass,
              onChanged: _selectClass,
            ),

          // Tab bar
          Material(
            color: Colors.white,
            elevation: 1,
            child: TabBar(
              controller: _tab,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: _kGreen,
              unselectedLabelColor: Colors.grey.shade500,
              indicatorColor: _kGreen,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(icon: Icon(Icons.dashboard_outlined, size: 16),
                    text: 'Overview'),
                Tab(icon: Icon(Icons.grass, size: 16),
                    text: 'Plots'),
                Tab(icon: Icon(Icons.receipt_long_outlined, size: 16),
                    text: 'Records'),
                Tab(icon: Icon(Icons.bar_chart_outlined, size: 16),
                    text: 'P & L'),
                Tab(icon: Icon(Icons.account_balance_outlined, size: 16),
                    text: 'Loans'),
              ],
            ),
          ),

          // Plot filter ribbon (shown when a plot is selected)
          if (ready && _filterPlotId != null)
            _FilterRibbon(
              plotName:  _filterPlotName ?? 'Plot',
              onClear:   () => setState(() {
                _filterPlotId   = null;
                _filterPlotName = null;
              }),
            ),

          Expanded(
            child: ready
                ? TabBarView(
                    controller: _tab,
                    children: [
                      _OverviewTab(
                        dataColl:   _dataColl!,
                        plotsColl:  _plotsColl!,
                        isTeacher:  _isTeacher,
                        isHT:       _isHT,
                        fmtKES:     _fmtKES,
                        fmtDate:    _fmtDate,
                        filterPlotId: _filterPlotId,
                        prevAnalysis: _prevAnalysis,
                        onAddPlot: () => _showAddPlotSheet(context),
                        onTabTo:   (i) => _tab.animateTo(i),
                      ),
                      _PlotsTab(
                        plotsColl:  _plotsColl!,
                        dataColl:   _dataColl!,
                        isTeacher:  _isTeacher,
                        isHT:       _isHT,
                        fmtKES:     _fmtKES,
                        fmtDate:    _fmtDate,
                        selectedId: _filterPlotId,
                        onSelect: (id, name) => setState(() {
                          _filterPlotId   = id;
                          _filterPlotName = name;
                        }),
                        onAdd: () => _showAddPlotSheet(context),
                      ),
                      _RecordsTab(
                        dataColl:   _dataColl!,
                        plotsColl:  _plotsColl!,
                        isTeacher:  _isTeacher,
                        isHT:       _isHT,
                        normSchool: _normSchool,
                        fmtKES:     _fmtKES,
                        filterPlotId: _filterPlotId,
                      ),
                      _PnLTab(
                        dataColl:     _dataColl!,
                        fmtKES:       _fmtKES,
                        filterPlotId: _filterPlotId,
                      ),
                      _LoansTab(
                        dataColl:  _dataColl!,
                        isTeacher: _isTeacher,
                        isHT:      _isHT,
                        normSchool: _normSchool,
                        fmtKES:    _fmtKES,
                      ),
                    ],
                  )
                : Center(
                    child: _isHT
                        ? const _Empty(
                            icon: Icons.class_outlined,
                            msg: 'Select a class to view farm data.',
                            color: _kGreen)
                        : const _Empty(
                            icon: Icons.agriculture_outlined,
                            msg: 'No farm data yet.',
                            color: _kGreen),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Add plot sheet ────────────────────────────────────────────────────────

  void _showAddPlotSheet(BuildContext context, {DocumentSnapshot? editing}) {
    final isEdit    = editing != null;
    final ed        = isEdit ? editing!.data() as Map<String, dynamic> : {};
    String name     = ed['plotName']     ?? '';
    String crop     = ed['cropName']     ?? _kCrops.first;
    String variety  = ed['cropVariety']  ?? '';
    double areaSqM  = (ed['areaSqM'] as num?)?.toDouble() ?? 100.0;
    String stage    = ed['growthStage']  ?? _kStages.first;
    int daysTotal   = (ed['growthDaysTotal'] as num?)?.toInt() ?? 90;
    int elapsed     = (ed['growthDaysElapsed'] as num?)?.toInt() ?? 0;
    DateTime planted = ed['plantingDate'] != null
        ? (ed['plantingDate'] as Timestamp).toDate()
        : DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, ss) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  const Text('🌱', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Text(isEdit ? 'Edit Plot' : 'Add New Plot',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 18),

                _field('Plot Name',
                    hint: 'e.g. Maize Plot 1, Beans Section A',
                    init: name, on: (v) => name = v),
                const SizedBox(height: 12),

                _dropdown('Crop', crop, _kCrops,
                    on: (v) => ss(() => crop = v!)),
                const SizedBox(height: 12),

                _field('Variety / Cultivar',
                    hint: 'e.g. H614D, Rose Coco (optional)',
                    init: variety, on: (v) => variety = v),
                const SizedBox(height: 12),

                Row(children: [
                  Expanded(
                    child: _field('Plot Area (m²)',
                        init: areaSqM.toStringAsFixed(0),
                        kb: TextInputType.number,
                        on: (v) => areaSqM = double.tryParse(v) ?? areaSqM),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field('Days to Maturity',
                        init: daysTotal.toString(),
                        kb: TextInputType.number,
                        on: (v) => daysTotal = int.tryParse(v) ?? daysTotal),
                  ),
                ]),
                const SizedBox(height: 12),

                _datePicker('Planting Date', planted, ctx, on: (d) => ss(() {
                  planted = d;
                  elapsed = DateTime.now()
                      .difference(d).inDays.clamp(0, daysTotal);
                })),
                const SizedBox(height: 12),

                _dropdown('Current Growth Stage', stage, _kStages,
                    on: (v) => ss(() => stage = v!)),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _kDarkGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    onPressed: () {
                      if (name.trim().isEmpty) return;
                      final payload = {
                        'plotName':          name.trim(),
                        'cropName':          crop,
                        'cropVariety':       variety.trim(),
                        'areaSqM':           areaSqM,
                        'plantingDate':      Timestamp.fromDate(planted),
                        'growthDaysTotal':   daysTotal,
                        'growthDaysElapsed': elapsed,
                        'growthStage':       stage,
                        'schoolName':        _normSchool,
                        'updatedAt':         FieldValue.serverTimestamp(),
                      };
                      if (isEdit) {
                        editing!.reference.update(payload);
                      } else {
                        payload['createdAt'] = FieldValue.serverTimestamp();
                        _plotsColl!.add(payload);
                      }
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          backgroundColor: _kGreenLight,
                          content: Text(isEdit
                              ? '${name.trim()} updated!'
                              : '${name.trim()} added!')));
                    },
                    child: Text(isEdit ? 'Save Changes' : 'Add Plot'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SUMMARY STRIP  — three cards matching mockup header
// ═══════════════════════════════════════════════════════════════════════════

class _SummaryStrip extends StatelessWidget {
  final CollectionReference     dataColl;
  final CollectionReference     plotsColl;
  final String Function(double) fmtKES;
  const _SummaryStrip({
    required this.dataColl,
    required this.plotsColl,
    required this.fmtKES,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: dataColl.snapshots(),
      builder: (_, snap) {
        double rev = 0, cost = 0;
        if (snap.hasData) {
          for (final d in snap.data!.docs) {
            final m   = d.data() as Map<String, dynamic>;
            final amt = (m['amount'] as num?)?.toDouble() ?? 0;
            if (m['type'] == 'revenue') rev  += amt;
            if (m['type'] == 'cost')    cost += amt;
          }
        }
        final profit   = rev - cost;
        final isProfit = profit >= 0;

        return StreamBuilder<QuerySnapshot>(
          stream: plotsColl.snapshots(),
          builder: (_, pSnap) {
            final plots = pSnap.data?.docs.length ?? 0;
            return Container(
              color: _kDarkGreen,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(children: [
                _card('$plots Plot${plots == 1 ? '' : 's'}', 'Active'),
                const SizedBox(width: 8),
                _card(fmtKES(cost), 'Invested'),
                const SizedBox(width: 8),
                _card(
                  '${isProfit ? '+' : '-'}${fmtKES(profit.abs())}',
                  isProfit ? 'Est. Profit' : 'Est. Loss',
                  valColor: isProfit
                      ? const Color(0xFF7FFF7F)
                      : const Color(0xFFFFAAAA),
                ),
              ]),
            );
          },
        );
      },
    );
  }

  Widget _card(String val, String lbl, {Color valColor = Colors.white}) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(children: [
            Text(val,
                style: TextStyle(
                    color: valColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(lbl,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.65), fontSize: 10)),
          ]),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
//  CLASS PICKER  (headteacher)
// ═══════════════════════════════════════════════════════════════════════════

class _ClassPicker extends StatelessWidget {
  final List<String>        classes;
  final String?             selected;
  final ValueChanged<String> onChanged;
  const _ClassPicker({
    required this.classes,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
    child: DropdownButtonFormField<String>(
      value: selected,
      decoration: InputDecoration(
        labelText: 'Select Class / Grade',
        prefixIcon: const Icon(Icons.class_, color: _kDarkGreen),
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      items: classes
          .map((id) => DropdownMenuItem(
              value: id, child: Text(id.replaceAll('_', ' '))))
          .toList(),
      onChanged: (v) { if (v != null) onChanged(v); },
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
//  FILTER RIBBON
// ═══════════════════════════════════════════════════════════════════════════

class _FilterRibbon extends StatelessWidget {
  final String      plotName;
  final VoidCallback onClear;
  const _FilterRibbon({required this.plotName, required this.onClear});

  @override
  Widget build(BuildContext context) => Container(
    color: _kGreenSurf,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    child: Row(children: [
      const Icon(Icons.filter_alt_outlined, size: 14, color: _kGreen),
      const SizedBox(width: 6),
      Expanded(
        child: Text('Showing: $plotName',
            style: const TextStyle(
                fontSize: 12, color: _kGreen, fontWeight: FontWeight.w600)),
      ),
      GestureDetector(
        onTap: onClear,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
              color: _kGreen,
              borderRadius: BorderRadius.circular(12)),
          child: const Text('Clear',
              style: TextStyle(color: Colors.white, fontSize: 11)),
        ),
      ),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
//  TAB 0 — OVERVIEW   (mockup style)
// ═══════════════════════════════════════════════════════════════════════════

class _OverviewTab extends StatelessWidget {
  final CollectionReference     dataColl;
  final CollectionReference     plotsColl;
  final bool                    isTeacher;
  final bool                    isHT;
  final String Function(double) fmtKES;
  final String Function(DateTime) fmtDate;
  final String?                 filterPlotId;
  final PlotAnalysisResult?     prevAnalysis;
  final VoidCallback            onAddPlot;
  final ValueChanged<int>       onTabTo;

  const _OverviewTab({
    required this.dataColl,   required this.plotsColl,
    required this.isTeacher,  required this.isHT,
    required this.fmtKES,     required this.fmtDate,
    required this.onAddPlot,  required this.onTabTo,
    this.filterPlotId, this.prevAnalysis,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Previous season card
        PlotHistoryCard(
          analysis:    prevAnalysis,
          seasonLabel: '${DateTime.now().year - 1} Season',
          isEducation: true,
        ),
        const SizedBox(height: 12),

        // Quick actions (match mockup 4-button grid)
        const _SectionTitle('Quick Actions'),
        const SizedBox(height: 8),
        _QuickActionGrid(
          isTeacher: isTeacher,
          isHT:      isHT,
          onTabTo:   onTabTo,
          onAddPlot: onAddPlot,
        ),
        const SizedBox(height: 16),

        // Today's records summary
        _SectionTitle('This Season at a Glance'),
        const SizedBox(height: 8),
        _SeasonGlance(dataColl: dataColl, fmtKES: fmtKES,
            filterPlotId: filterPlotId),
        const SizedBox(height: 16),

        // Plot snapshots grid
        StreamBuilder<QuerySnapshot>(
          stream: plotsColl.snapshots(),
          builder: (_, snap) {
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle('Plot Snapshots'),
                const SizedBox(height: 8),
                // 2-column grid exactly like mockup
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.3,
                  ),
                  itemBuilder: (_, i) {
                    final d = docs[i].data() as Map<String, dynamic>;
                    return _PlotMiniCard(data: d);
                  },
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _QuickActionGrid extends StatelessWidget {
  final bool            isTeacher;
  final bool            isHT;
  final ValueChanged<int> onTabTo;
  final VoidCallback    onAddPlot;
  const _QuickActionGrid({
    required this.isTeacher, required this.isHT,
    required this.onTabTo,   required this.onAddPlot,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      if (isTeacher && !isHT)
        _QA('Add Cost',    '💰', () => onTabTo(2)),
      if (isTeacher && !isHT)
        _QA('Add Revenue', '🌾', () => onTabTo(2)),
      _QA('View P & L',  '📊', () => onTabTo(3)),
      _QA('View Plots',  '🗺️', () => onTabTo(1)),
      if (isTeacher && !isHT)
        _QA('New Plot',    '🌱', onAddPlot),
      if (!isTeacher && !isHT)
        _QA('View Records','📋', () => onTabTo(2)),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: actions.map((a) => _QAButton(a)).toList(),
    );
  }
}

class _QA {
  final String label, emoji;
  final VoidCallback onTap;
  const _QA(this.label, this.emoji, this.onTap);
}

class _QAButton extends StatelessWidget {
  final _QA a;
  const _QAButton(this.a);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: a.onTap,
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(a.emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(a.label,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 9,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

class _SeasonGlance extends StatelessWidget {
  final CollectionReference     dataColl;
  final String Function(double) fmtKES;
  final String?                 filterPlotId;
  const _SeasonGlance({
    required this.dataColl, required this.fmtKES, this.filterPlotId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: dataColl.snapshots(),
      builder: (_, snap) {
        double rev = 0, cost = 0;
        int    entries = 0;
        if (snap.hasData) {
          for (final doc in snap.data!.docs) {
            final d = doc.data() as Map<String, dynamic>;
            if (filterPlotId != null &&
                d['plotId'] != filterPlotId &&
                d['plotId'] != 'all') continue;
            final amt = (d['amount'] as num?)?.toDouble() ?? 0;
            if (d['type'] == 'revenue') { rev  += amt; entries++; }
            if (d['type'] == 'cost')    { cost += amt; entries++; }
          }
        }
        final profit   = rev - cost;
        final isProfit = profit >= 0;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(children: [
            Row(children: [
              _glanceFig('$entries', 'Entries',    Colors.grey.shade700),
              _div,
              _glanceFig(fmtKES(cost),  'Costs',   _kRed),
              _div,
              _glanceFig(fmtKES(rev),   'Revenue', _kGreenLight),
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: (isProfit ? _kGreenLight : _kRed).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                Icon(
                    isProfit
                        ? Icons.trending_up
                        : Icons.trending_down,
                    color: isProfit ? _kGreenLight : _kRed,
                    size: 16),
                const SizedBox(width: 6),
                Text(
                  '${isProfit ? 'Profit' : 'Loss'}: ${fmtKES(profit.abs())}',
                  style: TextStyle(
                      color: isProfit ? _kGreenLight : _kRed,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ]),
            ),
          ]),
        );
      },
    );
  }

  Widget get _div => Container(
      width: 1, height: 36, color: Colors.grey.withOpacity(0.25));

  Widget _glanceFig(String val, String lbl, Color color) => Expanded(
    child: Column(children: [
      Text(val,
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 13, color: color),
          overflow: TextOverflow.ellipsis),
      Text(lbl,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
    ]),
  );
}

// Mini plot card for overview 2-column grid
class _PlotMiniCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PlotMiniCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final name     = (data['plotName']   as String?) ?? 'Plot';
    final crop     = (data['cropName']   as String?) ?? '—';
    final variety  = (data['cropVariety'] as String?) ?? '';
    final daysT    = (data['growthDaysTotal']   as num?)?.toInt() ?? 1;
    final elapsed  = (data['growthDaysElapsed'] as num?)?.toInt() ?? 0;
    final stage    = (data['growthStage'] as String?) ?? '—';
    final pct      = (elapsed / daysT).clamp(0.0, 1.0);
    final planted  = data['plantingDate'] != null
        ? (data['plantingDate'] as Timestamp).toDate()
        : null;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('${_cropEmoji(crop)} $crop'
              '${variety.isNotEmpty ? ' – $variety' : ''}',
              style: TextStyle(fontSize: 10, color: _kGreen),
              overflow: TextOverflow.ellipsis),
          if (planted != null)
            Text(
                '${(data['areaSqM'] as num?)?.toInt() ?? 0} m² · '
                'Planted ${planted.day}/${planted.month}',
                style: TextStyle(
                    fontSize: 9, color: Colors.grey.shade500)),
          const Spacer(),
          LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.grey.shade200,
            color: _kGreen,
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),
          const SizedBox(height: 3),
          Text('$stage (${(pct * 100).toInt()}%)',
              style: TextStyle(
                  fontSize: 9, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TAB 1 — PLOTS
//  BUG FIX: streams from plotsColl (sub-collection) — no composite index
// ═══════════════════════════════════════════════════════════════════════════

class _PlotsTab extends StatelessWidget {
  final CollectionReference       plotsColl;
  final CollectionReference       dataColl;
  final bool                      isTeacher;
  final bool                      isHT;
  final String Function(double)   fmtKES;
  final String Function(DateTime) fmtDate;
  final String?                   selectedId;
  final void Function(String, String) onSelect;
  final VoidCallback              onAdd;

  const _PlotsTab({
    required this.plotsColl, required this.dataColl,
    required this.isTeacher, required this.isHT,
    required this.fmtKES,    required this.fmtDate,
    required this.onSelect,  required this.onAdd,
    this.selectedId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      floatingActionButton: isTeacher && !isHT
          ? FloatingActionButton.extended(
              backgroundColor: _kDarkGreen,
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('New Plot'),
            )
          : null,
      body: StreamBuilder<QuerySnapshot>(
        // BUG FIX: simple .snapshots() — no where+orderBy = no composite index needed
        stream: plotsColl.snapshots(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _kGreen));
          }

          if (snap.hasError) {
            return Center(
              child: _Empty(
                icon: Icons.error_outline,
                msg: 'Could not load plots.\n${snap.error}',
                color: _kRed,
              ),
            );
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: _Empty(
                icon: Icons.grass,
                msg: isTeacher && !isHT
                    ? 'No plots yet.\nTap + below to add your first plot.'
                    : 'No plots set up yet.\nAsk your teacher to add the school plots.',
                color: _kGreen,
              ),
            );
          }

          // Sort client-side to avoid needing a Firestore index
          final sorted = [...docs]..sort((a, b) {
              final ta = (a.data() as Map)['createdAt'];
              final tb = (b.data() as Map)['createdAt'];
              if (ta == null || tb == null) return 0;
              return (ta as Timestamp).compareTo(tb as Timestamp);
            });

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            itemCount: sorted.length,
            itemBuilder: (_, i) => _PlotDetailCard(
              doc:        sorted[i],
              dataColl:   dataColl,
              isTeacher:  isTeacher && !isHT,
              isSelected: selectedId == sorted[i].id,
              fmtKES:     fmtKES,
              fmtDate:    fmtDate,
              onTap: () => onSelect(sorted[i].id,
                  (sorted[i].data() as Map)['plotName'] ?? 'Plot'),
              onEdit: () => _editPlot(context, sorted[i]),
              onDelete: () => _deletePlot(context, sorted[i]),
            ),
          );
        },
      ),
    );
  }

  void _editPlot(BuildContext context, DocumentSnapshot doc) {
    // Rebuild add-plot sheet pre-filled
    final d = doc.data() as Map<String, dynamic>;
    String name     = d['plotName']     ?? '';
    String crop     = d['cropName']     ?? _kCrops.first;
    String variety  = d['cropVariety']  ?? '';
    double areaSqM  = (d['areaSqM'] as num?)?.toDouble() ?? 100.0;
    String stage    = d['growthStage']  ?? _kStages.first;
    int daysTotal   = (d['growthDaysTotal'] as num?)?.toInt() ?? 90;
    int elapsed     = (d['growthDaysElapsed'] as num?)?.toInt() ?? 0;
    DateTime planted = d['plantingDate'] != null
        ? (d['plantingDate'] as Timestamp).toDate()
        : DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, ss) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Row(children: [
                  const Text('✏️', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  const Text('Edit Plot',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 18),
                _field('Plot Name', init: name, on: (v) => name = v),
                const SizedBox(height: 12),
                _dropdown('Crop', crop, _kCrops,
                    on: (v) => ss(() => crop = v!)),
                const SizedBox(height: 12),
                _field('Variety', init: variety, on: (v) => variety = v),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _field('Area (m²)',
                      init: areaSqM.toStringAsFixed(0),
                      kb: TextInputType.number,
                      on: (v) => areaSqM = double.tryParse(v) ?? areaSqM)),
                  const SizedBox(width: 12),
                  Expanded(child: _field('Days to Maturity',
                      init: daysTotal.toString(),
                      kb: TextInputType.number,
                      on: (v) => daysTotal = int.tryParse(v) ?? daysTotal)),
                ]),
                const SizedBox(height: 12),
                _datePicker('Planting Date', planted, ctx, on: (d2) => ss(() {
                  planted = d2;
                  elapsed = DateTime.now().difference(d2).inDays.clamp(0, daysTotal);
                })),
                const SizedBox(height: 12),
                _dropdown('Growth Stage', stage, _kStages,
                    on: (v) => ss(() => stage = v!)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _kDarkGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    onPressed: () {
                      if (name.trim().isEmpty) return;
                      doc.reference.update({
                        'plotName':          name.trim(),
                        'cropName':          crop,
                        'cropVariety':       variety.trim(),
                        'areaSqM':           areaSqM,
                        'plantingDate':      Timestamp.fromDate(planted),
                        'growthDaysTotal':   daysTotal,
                        'growthDaysElapsed': elapsed,
                        'growthStage':       stage,
                        'updatedAt':         FieldValue.serverTimestamp(),
                      });
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          backgroundColor: _kGreenLight,
                          content: Text('${name.trim()} updated!')));
                    },
                    child: const Text('Save Changes'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deletePlot(
      BuildContext context, DocumentSnapshot doc) async {
    final d  = doc.data() as Map<String, dynamic>;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Plot?'),
        content: Text(
            'Remove "${d['plotName']}"?\n'
            'Financial records linked to this plot will not be deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await doc.reference.delete();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Plot deleted.')));
    }
  }
}

// ── Full plot detail card ─────────────────────────────────────────────────

class _PlotDetailCard extends StatelessWidget {
  final DocumentSnapshot          doc;
  final CollectionReference       dataColl;
  final bool                      isTeacher;
  final bool                      isSelected;
  final String Function(double)   fmtKES;
  final String Function(DateTime) fmtDate;
  final VoidCallback              onTap;
  final VoidCallback              onEdit;
  final VoidCallback              onDelete;

  const _PlotDetailCard({
    required this.doc,       required this.dataColl,
    required this.isTeacher, required this.isSelected,
    required this.fmtKES,    required this.fmtDate,
    required this.onTap,     required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final d       = doc.data() as Map<String, dynamic>;
    final name    = (d['plotName']  as String?) ?? 'Unnamed Plot';
    final crop    = (d['cropName']  as String?) ?? '—';
    final variety = (d['cropVariety'] as String?) ?? '';
    final areaSqM = (d['areaSqM']   as num?)?.toDouble() ?? 0;
    final stage   = (d['growthStage'] as String?) ?? '—';
    final daysT   = (d['growthDaysTotal']   as num?)?.toInt() ?? 1;
    final elapsed = (d['growthDaysElapsed'] as num?)?.toInt() ?? 0;
    final pct     = (elapsed / daysT).clamp(0.0, 1.0);
    final planted = d['plantingDate'] != null
        ? (d['plantingDate'] as Timestamp).toDate()
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _kGreen : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected ? _kGreenSurf : Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(13)),
            ),
            child: Row(children: [
              Text(_cropEmoji(crop),
                  style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: _kDarkGreen)),
                  Text(variety.isNotEmpty ? '$crop — $variety' : crop,
                      style: TextStyle(
                          fontSize: 12,
                          color: _kGreen.withOpacity(0.8))),
                ],
              )),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${areaSqM.toStringAsFixed(0)} m²',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                if (planted != null)
                  Text('Planted ${fmtDate(planted)}',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500)),
              ]),
            ]),
          ),

          // Progress section
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(stage,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('${(pct * 100).toInt()}% of season',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500)),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: pct,
                  backgroundColor: Colors.grey.shade200,
                  color: _kGreen,
                  minHeight: 7,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Day $elapsed of $daysT',
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade500)),
                    Text(
                      '${(daysT - elapsed).clamp(0, 999)} days to harvest',
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Cost summary for this plot
          StreamBuilder<QuerySnapshot>(
            stream: dataColl
                .where('plotId', isEqualTo: doc.id)
                .snapshots(),
            builder: (_, snap) {
              double cost = 0, rev = 0;
              if (snap.hasData) {
                for (final entry in snap.data!.docs) {
                  final m   = entry.data() as Map<String, dynamic>;
                  final amt = (m['amount'] as num?)?.toDouble() ?? 0;
                  if (m['type'] == 'cost')    cost += amt;
                  if (m['type'] == 'revenue') rev  += amt;
                }
              }
              if (cost == 0 && rev == 0) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(children: [
                  _fi('Cost', fmtKES(cost), _kRed),
                  Container(width: 1, height: 28,
                      color: Colors.grey.withOpacity(0.3)),
                  _fi('Revenue', fmtKES(rev), _kGreenLight),
                  Container(width: 1, height: 28,
                      color: Colors.grey.withOpacity(0.3)),
                  _fi(rev >= cost ? 'Profit' : 'Loss',
                      fmtKES((rev - cost).abs()),
                      rev >= cost ? _kGreenLight : _kRed),
                ]),
              );
            },
          ),

          // Teacher actions
          if (isTeacher)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Row(children: [
                _smBtn('Edit Plot', Icons.edit_outlined, onEdit),
                const SizedBox(width: 8),
                _smBtn('Delete', Icons.delete_outline, onDelete,
                    color: _kRed),
              ]),
            )
          else
            const SizedBox(height: 14),
        ]),
      ),
    );
  }

  Widget _fi(String lbl, String val, Color color) => Expanded(
    child: Column(children: [
      Text(val, style: TextStyle(
          fontWeight: FontWeight.bold, fontSize: 12, color: color)),
      Text(lbl, style: TextStyle(
          fontSize: 9, color: Colors.grey.shade500)),
    ]),
  );

  Widget _smBtn(String label, IconData icon, VoidCallback onTap,
      {Color? color}) {
    final c = color ?? _kDarkGreen;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: c.withOpacity(0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.withOpacity(0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: c, size: 14),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: c, fontSize: 12)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TAB 2 — RECORDS
// ═══════════════════════════════════════════════════════════════════════════

class _RecordsTab extends StatelessWidget {
  final CollectionReference     dataColl;
  final CollectionReference     plotsColl;
  final bool                    isTeacher;
  final bool                    isHT;
  final String                  normSchool;
  final String Function(double) fmtKES;
  final String?                 filterPlotId;

  const _RecordsTab({
    required this.dataColl,   required this.plotsColl,
    required this.isTeacher,  required this.isHT,
    required this.normSchool, required this.fmtKES,
    this.filterPlotId,
  });

  static const Map<String, List<String>> _costSubs = {
    'Labour':               ['Manual Workers','Skilled Labour','Supervisor','Casual Workers','Family Labour'],
    'Equipment & Machinery':['Tractor Hire','Ploughing','Harvester','Tools Purchase','Repairs'],
    'Seeds & Fertilizer':   ['Maize Seeds','Bean Seeds','Fertilizer (DAP/CAN)','Manure','Lime'],
    'Chemicals & Pesticides':['Herbicides','Insecticides','Fungicides','Rodenticides'],
    'Transport':            ['Produce to Market','Input Delivery','Worker Transport'],
    'Land Rent/Preparation':['Land Rent','Land Clearing','Ploughing Service'],
    'Irrigation':           ['Fuel for Pump','Pipe Repairs','Water Fees'],
    'Miscellaneous':        ['Packaging','Storage','Insurance','Other'],
  };

  static const Map<String, List<String>> _revSubs = {
    'Maize Sales':         ['Fresh Maize','Dry Maize','Maize Flour Sales'],
    'Beans Sales':         ['Dry Beans','Fresh Beans','Bean Leaves'],
    'Vegetable Sales':     ['Tomatoes','Cabbage','Onions','Kales/Sukuma'],
    'Livestock':           ['Milk Sales','Eggs','Chicken','Goats'],
    'Fruits':              ['Mangoes','Avocado','Bananas','Oranges'],
    'Value-Added Products':['Maize Flour','Bean Flour','Dried Vegetables'],
    'Other Crops':         ['Sunflower','Groundnuts','Sorghum'],
    'Grants/Subsidies':    ['Government Support','NGO Aid','School Funding'],
  };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: dataColl.snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _kGreen));
        }

        final all = snap.data?.docs ?? [];

        bool matchPlot(QueryDocumentSnapshot d) {
          if (filterPlotId == null) return true;
          final m = d.data() as Map<String, dynamic>;
          return m['plotId'] == filterPlotId || m['plotId'] == 'all';
        }

        final costs = all.where((d) =>
            (d.data() as Map)['type'] == 'cost' && matchPlot(d)).toList();
        final revs  = all.where((d) =>
            (d.data() as Map)['type'] == 'revenue' && matchPlot(d)).toList();

        return DefaultTabController(
          length: 2,
          child: Column(children: [
            Container(
              color: Colors.white,
              child: TabBar(
                tabs: [
                  Tab(text: 'Costs (${costs.length})'),
                  Tab(text: 'Revenue (${revs.length})'),
                ],
                labelColor: _kGreen,
                indicatorColor: _kGreen,
                unselectedLabelColor: Colors.grey,
              ),
            ),
            Expanded(
              child: TabBarView(children: [
                _entryList(context, costs,  'cost'),
                _entryList(context, revs,   'revenue'),
              ]),
            ),
            if (isTeacher && !isHT)
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.white,
                child: Row(children: [
                  Expanded(child: _addBtn(context, 'Add Cost', _kRed,
                      Icons.remove_circle_outline, 'cost')),
                  const SizedBox(width: 12),
                  Expanded(child: _addBtn(context, 'Add Revenue',
                      _kGreenLight, Icons.add_circle_outline, 'revenue')),
                ]),
              ),
          ]),
        );
      },
    );
  }

  Widget _addBtn(BuildContext ctx, String label, Color color,
      IconData icon, String type) =>
      ElevatedButton.icon(
        onPressed: () => _showAddSheet(ctx, type),
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );

  Widget _entryList(BuildContext context,
      List<QueryDocumentSnapshot> entries, String type) {
    if (entries.isEmpty) {
      return Center(
        child: _Empty(
          icon:  type == 'cost'
              ? Icons.payments_outlined
              : Icons.point_of_sale_outlined,
          msg:   'No ${type == 'cost' ? 'cost' : 'revenue'} records yet.',
          color: type == 'cost' ? _kRed : _kGreenLight,
        ),
      );
    }

    // Sort descending by createdAt client-side
    final sorted = [...entries]..sort((a, b) {
        final ta = (a.data() as Map)['createdAt'];
        final tb = (b.data() as Map)['createdAt'];
        if (ta == null || tb == null) return 0;
        return (tb as Timestamp).compareTo(ta as Timestamp);
      });

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: sorted.length,
      itemBuilder: (_, i) => _EntryTile(
        doc:       sorted[i],
        type:      type,
        isTeacher: isTeacher && !isHT,
        fmtKES:    fmtKES,
        onEdit:    () => _showEditSheet(context, sorted[i]),
        onDelete:  () => _deleteEntry(context, sorted[i]),
      ),
    );
  }

  void _showAddSheet(BuildContext context, String type) {
    String? cat, sub, plotId = 'all';
    String  desc   = '';
    double  amount = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, ss) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: StreamBuilder<QuerySnapshot>(
              stream: plotsColl.snapshots(),
              builder: (_, pSnap) {
                final pDocs   = pSnap.data?.docs ?? [];
                final pIds    = ['all', ...pDocs.map((d) => d.id)];
                final pLabels = <String>[
                  'Whole Farm',
                  ...pDocs.map((d) =>
                      ((d.data() as Map<String,dynamic>)['plotName'] as String?)
                          ?? d.id),
                ];

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 16),
                    Row(children: [
                      Text(type == 'cost' ? '💰' : '🌾',
                          style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Text('Add ${type.cap} Entry',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 18),

                    _dropdown('Plot', plotId, pIds,
                        disp: pLabels,
                        on: (v) => ss(() => plotId = v!)),
                    const SizedBox(height: 12),

                    _dropdown('Category', cat,
                        type == 'cost' ? _kCostCats : _kRevCats,
                        on: (v) => ss(() { cat = v; sub = null; })),
                    const SizedBox(height: 12),

                    if (cat != null) ...[
                      _dropdown('Specific Activity', sub,
                          type == 'cost'
                              ? (_costSubs[cat] ?? [])
                              : (_revSubs[cat] ?? []),
                          on: (v) => ss(() => sub = v)),
                      const SizedBox(height: 12),
                    ],

                    _field('Description (optional)',
                        hint: type == 'cost'
                            ? 'e.g. Hired 5 workers for weeding'
                            : 'e.g. Sold 20 bags of maize',
                        on: (v) => desc = v,
                        maxLines: 2),
                    const SizedBox(height: 12),

                    _field('Amount (KES)',
                        kb: TextInputType.number,
                        on: (v) => amount = double.tryParse(v) ?? 0),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: _kDarkGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        onPressed: () {
                          if (amount <= 0 || cat == null) return;
                          dataColl.add({
                            'type':        type,
                            'plotId':      plotId,
                            'category':    cat,
                            'subCategory': sub ?? '',
                            'description': desc.trim(),
                            'amount':      amount,
                            'schoolName':  normSchool,
                            'createdAt':   FieldValue.serverTimestamp(),
                          });
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              backgroundColor: _kGreenLight,
                              content: Text('${type.cap} entry saved!')));
                        },
                        child: const Text('Save Entry'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showEditSheet(BuildContext context, QueryDocumentSnapshot doc) {
    final d    = doc.data() as Map<String, dynamic>;
    String cat = d['category']    ?? '';
    String sub = d['subCategory'] ?? '';
    final type = d['type'] as String? ?? 'cost';
    final descCtrl = TextEditingController(text: d['description'] ?? '');
    final amtCtrl  = TextEditingController(
        text: (d['amount'] as num?)?.toString() ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, ss) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text('Edit ${type.cap} Entry',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 18),
                _dropdown('Category', cat,
                    type == 'cost' ? _kCostCats : _kRevCats,
                    on: (v) => ss(() { cat = v!; sub = ''; })),
                const SizedBox(height: 12),
                _dropdown('Specific Activity', sub.isEmpty ? null : sub,
                    type == 'cost'
                        ? (_costSubs[cat] ?? [])
                        : (_revSubs[cat] ?? []),
                    on: (v) => ss(() => sub = v ?? '')),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amtCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount (KES)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _kDarkGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    onPressed: () {
                      final amt = double.tryParse(amtCtrl.text) ?? 0;
                      if (amt <= 0) return;
                      doc.reference.update({
                        'category':    cat,
                        'subCategory': sub,
                        'description': descCtrl.text.trim(),
                        'amount':      amt,
                      });
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Entry updated!')));
                    },
                    child: const Text('Update'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteEntry(
      BuildContext context, QueryDocumentSnapshot doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: const Text('This record will be permanently deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) await doc.reference.delete();
  }
}

class _EntryTile extends StatelessWidget {
  final QueryDocumentSnapshot   doc;
  final String                  type;
  final bool                    isTeacher;
  final String Function(double) fmtKES;
  final VoidCallback            onEdit;
  final VoidCallback            onDelete;

  const _EntryTile({
    required this.doc,       required this.type,
    required this.isTeacher, required this.fmtKES,
    required this.onEdit,    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final d      = doc.data() as Map<String, dynamic>;
    final amount = (d['amount'] as num?)?.toDouble() ?? 0.0;
    final date   = (d['createdAt'] as Timestamp?)?.toDate();
    final color  = type == 'cost' ? _kRed : _kGreenLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(_categoryEmoji(d['category'] ?? ''),
                style: const TextStyle(fontSize: 16)),
          ),
        ),
        title: Text(
          (d['category'] as String?) ?? 'Unknown',
          style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 13),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((d['subCategory'] as String?)?.isNotEmpty == true)
              Text(d['subCategory'] as String,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w500)),
            Row(children: [
              if ((d['plotId'] as String?) != null &&
                  d['plotId'] != 'all') ...[
                const Icon(Icons.grass, size: 10, color: _kGreen),
                const SizedBox(width: 3),
                Text(d['plotId'] as String,
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey.shade500)),
                const SizedBox(width: 6),
              ],
              if (date != null)
                Text('${date.day}/${date.month}/${date.year}',
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey.shade500)),
            ]),
          ],
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(fmtKES(amount),
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color)),
          if (isTeacher) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  size: 15, color: _kBlue),
              onPressed: onEdit,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 2),
            IconButton(
              icon: Icon(Icons.delete_outline, size: 15, color: _kRed),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TAB 3 — P & L
// ═══════════════════════════════════════════════════════════════════════════

class _PnLTab extends StatelessWidget {
  final CollectionReference     dataColl;
  final String Function(double) fmtKES;
  final String?                 filterPlotId;

  const _PnLTab({
    required this.dataColl, required this.fmtKES, this.filterPlotId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: dataColl.snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _kGreen));
        }

        double rev = 0, cost = 0;
        final costByCat = <String, double>{};

        for (final doc in snap.data?.docs ?? []) {
          final d = doc.data() as Map<String, dynamic>;
          if (filterPlotId != null &&
              d['plotId'] != filterPlotId &&
              d['plotId'] != 'all') continue;
          final amt = (d['amount'] as num?)?.toDouble() ?? 0;
          if (d['type'] == 'revenue') rev  += amt;
          if (d['type'] == 'cost') {
            cost += amt;
            final c = (d['category'] as String?) ?? 'Other';
            costByCat[c] = (costByCat[c] ?? 0) + amt;
          }
        }

        if (rev == 0 && cost == 0) {
          return const Center(
            child: _Empty(
              icon: Icons.analytics_outlined,
              msg: 'No financial data yet.\nAdd records to see P&L.',
              color: _kGreen,
            ),
          );
        }

        final profit   = rev - cost;
        final isProfit = profit >= 0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            // Big P&L card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isProfit ? _kGreenSurf : _kRedSurf,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: isProfit
                        ? _kGreenLight.withOpacity(0.35)
                        : _kRed.withOpacity(0.35)),
              ),
              child: Column(children: [
                Row(children: [
                  _pnlFig('Total Revenue', rev, _kGreenLight),
                  Container(width: 1, height: 44,
                      color: Colors.grey.withOpacity(0.3)),
                  _pnlFig('Total Costs', cost, _kRed),
                ]),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: (isProfit ? _kGreenLight : _kRed).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    Icon(
                        isProfit
                            ? Icons.trending_up
                            : Icons.trending_down,
                        color: isProfit ? _kGreenLight : _kRed,
                        size: 22),
                    const SizedBox(width: 8),
                    Text(
                      '${isProfit ? 'Net Profit' : 'Net Loss'}: ${fmtKES(profit.abs())}',
                      style: TextStyle(
                          color: isProfit ? _kGreenLight : _kRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // Cost breakdown
            if (costByCat.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cost Breakdown',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 180,
                      child: PieChart(PieChartData(
                        sections: costByCat.entries.map((e) {
                          final idx = costByCat.keys.toList().indexOf(e.key);
                          return PieChartSectionData(
                            value: e.value,
                            title: e.key,
                            color: Colors.primaries[
                                idx % Colors.primaries.length],
                            radius: 60,
                            titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 9),
                          );
                        }).toList(),
                        centerSpaceRadius: 26,
                      )),
                    ),
                    const SizedBox(height: 12),
                    ...costByCat.entries.map((e) => _CatBar(
                          emoji:    _categoryEmoji(e.key),
                          category: e.key,
                          amount:   e.value,
                          total:    cost,
                          fmtKES:   fmtKES,
                        )),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // School learning note
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _kBlueSurf,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kBlue.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: const [
                    Icon(Icons.school_outlined, color: _kBlue, size: 16),
                    SizedBox(width: 8),
                    Text('Learning Note',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _kBlue,
                            fontSize: 13)),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    isProfit
                        ? 'The school farm made a profit. Revenue (${fmtKES(rev)}) '
                            'exceeded costs (${fmtKES(cost)}). '
                            'Discuss: how could this profit be reinvested into the farm?'
                        : 'The school farm recorded a loss. Costs (${fmtKES(cost)}) '
                            'exceeded revenue (${fmtKES(rev)}). '
                            'Discuss with your class: which costs could be reduced, '
                            'or which crops might sell better next season?',
                    style: const TextStyle(fontSize: 12, color: _kBlue,
                        height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ]),
        );
      },
    );
  }

  Widget _pnlFig(String label, double value, Color color) =>
      Expanded(child: Column(children: [
        Text(fmtKES(value),
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
      ]));
}

// ═══════════════════════════════════════════════════════════════════════════
//  TAB 4 — LOANS
// ═══════════════════════════════════════════════════════════════════════════

class _LoansTab extends StatelessWidget {
  final CollectionReference     dataColl;
  final bool                    isTeacher;
  final bool                    isHT;
  final String                  normSchool;
  final String Function(double) fmtKES;

  const _LoansTab({
    required this.dataColl,  required this.isTeacher,
    required this.isHT,      required this.normSchool,
    required this.fmtKES,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      floatingActionButton: isTeacher && !isHT
          ? FloatingActionButton.extended(
              backgroundColor: _kDarkGreen,
              onPressed: () => _showAddSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('New Loan'),
            )
          : null,
      body: StreamBuilder<QuerySnapshot>(
        stream: dataColl.where('type', isEqualTo: 'loan').snapshots(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _kGreen));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: _Empty(
                icon: Icons.account_balance_outlined,
                msg: isTeacher && !isHT
                    ? 'No loans yet.\nTap + to add one.'
                    : 'No loan records yet.',
                color: _kBlue,
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            itemCount: docs.length,
            itemBuilder: (_, i) => _LoanCard(
              doc:       docs[i],
              isTeacher: isTeacher && !isHT,
              fmtKES:    fmtKES,
            ),
          );
        },
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    final lenderCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final rateCtrl   = TextEditingController(text: '10');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(children: const [
              Text('🏦', style: TextStyle(fontSize: 22)),
              SizedBox(width: 10),
              Text('Add New Loan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 18),
            TextField(
              controller: lenderCtrl,
              decoration: InputDecoration(
                labelText: 'Lender (e.g. Bank, NGO, Government)',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount (KES)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: rateCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Interest (%)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _kDarkGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                onPressed: () {
                  final amt = double.tryParse(amountCtrl.text) ?? 0;
                  if (amt <= 0) return;
                  dataColl.add({
                    'type':         'loan',
                    'lender':       lenderCtrl.text.trim().isEmpty
                        ? 'Bank'
                        : lenderCtrl.text.trim(),
                    'amount':       amt,
                    'interestRate': double.tryParse(rateCtrl.text) ?? 0,
                    'remaining':    amt,
                    'repayments':   [],
                    'schoolName':   normSchool,
                    'createdAt':    FieldValue.serverTimestamp(),
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          backgroundColor: _kGreenLight,
                          content: Text('Loan added!')));
                },
                child: const Text('Save Loan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoanCard extends StatefulWidget {
  final QueryDocumentSnapshot   doc;
  final bool                    isTeacher;
  final String Function(double) fmtKES;
  const _LoanCard({
    required this.doc, required this.isTeacher, required this.fmtKES});
  @override
  State<_LoanCard> createState() => _LoanCardState();
}

class _LoanCardState extends State<_LoanCard> {
  final _ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final d         = widget.doc.data() as Map<String, dynamic>;
    final amount    = (d['amount']    as num?)?.toDouble() ?? 0.0;
    final remaining = (d['remaining'] as num?)?.toDouble() ?? 0.0;
    final rate      = (d['interestRate'] as num?)?.toDouble() ?? 0.0;
    final paid      = amount - remaining;
    final pct       = amount > 0 ? (paid / amount).clamp(0.0, 1.0) : 0.0;
    final isPaid    = remaining <= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('🏦', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(child: Text((d['lender'] as String?) ?? 'Loan',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: isPaid ? _kGreenSurf : _kRedSurf,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(isPaid ? 'Fully Paid' : 'Outstanding',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isPaid ? _kGreenLight : _kRed)),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _f('Borrowed', widget.fmtKES(amount)),
          _f('Interest', '$rate%'),
          _f('Balance',  widget.fmtKES(remaining),
              color: isPaid ? _kGreenLight : _kRed),
        ]),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: pct,
          backgroundColor: Colors.grey.shade200,
          color: _kBlue, minHeight: 7,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 4),
        Text('${(pct * 100).toInt()}% repaid · Paid: ${widget.fmtKES(paid)}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        if (widget.isTeacher && !isPaid) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Repay Amount (KES)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _kGreenLight,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () {
                final pay = double.tryParse(_ctrl.text) ?? 0;
                if (pay > 0 && pay <= remaining) {
                  widget.doc.reference.update({
                    'remaining':  remaining - pay,
                    'repayments': FieldValue.arrayUnion([{
                      'amount': pay,
                      'date':   FieldValue.serverTimestamp(),
                    }]),
                  });
                  _ctrl.clear();
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Payment recorded!')));
                }
              },
              child: const Text('Pay'),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _f(String lbl, String val, {Color? color}) =>
      Expanded(child: Column(children: [
        Text(val, style: TextStyle(
            fontWeight: FontWeight.bold, fontSize: 13,
            color: color ?? Colors.black87)),
        Text(lbl, style: TextStyle(
            fontSize: 10, color: Colors.grey.shade500)),
      ]));
}

// ═══════════════════════════════════════════════════════════════════════════
//  SHARED MICRO-WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _CatBar extends StatelessWidget {
  final String                  emoji, category;
  final double                  amount, total;
  final String Function(double) fmtKES;

  const _CatBar({
    required this.emoji,    required this.category,
    required this.amount,   required this.total,
    required this.fmtKES,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (amount / total).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Column(children: [
        Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(child: Text(category,
              style: const TextStyle(fontSize: 12))),
          Text(fmtKES(amount),
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Text('${(pct * 100).toInt()}%',
              style: TextStyle(
                  fontSize: 10, color: Colors.grey.shade500)),
        ]),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: pct,
          backgroundColor: Colors.grey.shade200,
          color: _kAmber, minHeight: 4,
          borderRadius: BorderRadius.circular(3),
        ),
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600));
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String   msg;
  final Color    color;
  const _Empty({required this.icon, required this.msg, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color.withOpacity(0.35), size: 52),
      const SizedBox(height: 12),
      Text(msg,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.grey.shade500, fontSize: 14, height: 1.5)),
    ]),
  );
}

// ── Free-function form helpers ────────────────────────────────────────────

Widget _field(String label, {
  String? init, String? hint,
  TextInputType kb = TextInputType.text,
  int maxLines = 1,
  required ValueChanged<String> on,
}) =>
    TextFormField(
      initialValue: init,
      keyboardType: kb,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      onChanged: on,
    );

Widget _dropdown(String label, String? value, List<String> items, {
  List<String>? disp,
  required ValueChanged<String?> on,
}) =>
    DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      items: List.generate(items.length, (i) => DropdownMenuItem(
          value: items[i],
          child: Text(disp != null ? disp[i] : items[i]))),
      onChanged: on,
    );

Widget _datePicker(String label, DateTime value, BuildContext ctx, {
  required ValueChanged<DateTime> on,
}) =>
    GestureDetector(
      onTap: () async {
        final p = await showDatePicker(
          context: ctx,
          initialDate: value,
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
        );
        if (p != null) on(p);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_today_outlined, size: 16,
              color: Colors.grey),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  color: Colors.grey.shade600, fontSize: 13)),
          const Spacer(),
          Text(
            '${value.day} ${_kMonths[value.month - 1]} ${value.year}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ]),
      ),
    );