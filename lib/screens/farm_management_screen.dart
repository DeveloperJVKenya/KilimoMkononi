// ignore_for_file: unused_import, unused_field, prefer_conditional_assignment, curly_braces_in_flow_control_structures, prefer_contains, unused_element, unnecessary_non_null_assertion, library_private_types_in_public_api, deprecated_member_use, invalid_use_of_protected_member

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kilimomkononi/home.dart';
import 'package:kilimomkononi/services/field_cost_bridge.dart';
import 'package:kilimomkononi/services/pest_disease_cost_bridge.dart';

// ---------------------------------------------------------------------------
// MODELS  (unchanged)
// ---------------------------------------------------------------------------

class FarmPlot {
  final String id;
  String name, cropName, cropVariety, growthStage;
  double acreage;
  DateTime plantingDate;
  int growthDaysTotal, growthDaysElapsed;

  FarmPlot({
    required this.id, required this.name, required this.cropName,
    required this.cropVariety, required this.acreage,
    required this.plantingDate, required this.growthDaysTotal,
    required this.growthStage, required this.growthDaysElapsed,
  });

  double get growthPercent =>
      (growthDaysElapsed / growthDaysTotal).clamp(0.0, 1.0);

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'cropName': cropName,
        'cropVariety': cropVariety, 'acreage': acreage,
        'plantingDate': plantingDate.toIso8601String(),
        'growthDaysTotal': growthDaysTotal, 'growthStage': growthStage,
        'growthDaysElapsed': growthDaysElapsed,
      };

  factory FarmPlot.fromJson(Map<String, dynamic> j) => FarmPlot(
        id: j['id'], name: j['name'], cropName: j['cropName'],
        cropVariety: j['cropVariety'],
        acreage: (j['acreage'] as num).toDouble(),
        plantingDate: DateTime.parse(j['plantingDate']),
        growthDaysTotal: j['growthDaysTotal'], growthStage: j['growthStage'],
        growthDaysElapsed: j['growthDaysElapsed'],
      );
}

class FarmTask {
  final String id;
  String title, description, plotId, priority, category;
  DateTime dueDate;
  bool isDone;

  FarmTask({
    required this.id, required this.title, required this.description,
    required this.plotId, required this.dueDate, this.isDone = false,
    this.priority = 'normal', this.category = 'other',
  });

  Map<String, dynamic> toJson() => {
        'id': id, 'title': title, 'description': description,
        'plotId': plotId, 'dueDate': dueDate.toIso8601String(),
        'isDone': isDone, 'priority': priority, 'category': category,
      };

  factory FarmTask.fromJson(Map<String, dynamic> j) => FarmTask(
        id: j['id'], title: j['title'], description: j['description'],
        plotId: j['plotId'], dueDate: DateTime.parse(j['dueDate']),
        isDone: j['isDone'] ?? false, priority: j['priority'] ?? 'normal',
        category: j['category'] ?? 'other',
      );
}

class FarmExpense {
  final String id;
  String category, description, plotId;
  double amount;
  DateTime date;

  FarmExpense({
    required this.id, required this.category, required this.description,
    required this.amount, required this.date, this.plotId = 'all',
  });

  Map<String, dynamic> toJson() => {
        'id': id, 'category': category, 'description': description,
        'amount': amount, 'date': date.toIso8601String(), 'plotId': plotId,
      };

  factory FarmExpense.fromJson(Map<String, dynamic> j) => FarmExpense(
        id: j['id'], category: j['category'], description: j['description'],
        amount: (j['amount'] as num).toDouble(),
        date: DateTime.parse(j['date']), plotId: j['plotId'] ?? 'all',
      );
}

class HarvestRecord {
  final String id;
  String plotId, cropName, buyerName;
  double quantityKg, pricePerKg;
  DateTime date;
  bool isSold;

  HarvestRecord({
    required this.id, required this.plotId, required this.cropName,
    required this.quantityKg, required this.pricePerKg,
    required this.buyerName, required this.date, this.isSold = false,
  });

  double get totalValue => quantityKg * pricePerKg;

  Map<String, dynamic> toJson() => {
        'id': id, 'plotId': plotId, 'cropName': cropName,
        'quantityKg': quantityKg, 'pricePerKg': pricePerKg,
        'buyerName': buyerName, 'date': date.toIso8601String(),
        'isSold': isSold,
      };

  factory HarvestRecord.fromJson(Map<String, dynamic> j) => HarvestRecord(
        id: j['id'], plotId: j['plotId'], cropName: j['cropName'],
        quantityKg: (j['quantityKg'] as num).toDouble(),
        pricePerKg: (j['pricePerKg'] as num).toDouble(),
        buyerName: j['buyerName'], date: DateTime.parse(j['date']),
        isSold: j['isSold'] ?? false,
      );
}

class LoanRecord {
  final String id;
  String lenderName;
  double principal, interestRate, amountRepaid;
  DateTime takenDate, dueDate;

  LoanRecord({
    required this.id, required this.lenderName, required this.principal,
    required this.interestRate, required this.takenDate,
    required this.dueDate, this.amountRepaid = 0,
  });

  double get totalDue => principal + (principal * interestRate / 100);
  double get balance  => (totalDue - amountRepaid).clamp(0, double.infinity);

  Map<String, dynamic> toJson() => {
        'id': id, 'lenderName': lenderName, 'principal': principal,
        'interestRate': interestRate,
        'takenDate': takenDate.toIso8601String(),
        'dueDate': dueDate.toIso8601String(), 'amountRepaid': amountRepaid,
      };

  factory LoanRecord.fromJson(Map<String, dynamic> j) => LoanRecord(
        id: j['id'], lenderName: j['lenderName'],
        principal: (j['principal'] as num).toDouble(),
        interestRate: (j['interestRate'] as num).toDouble(),
        takenDate: DateTime.parse(j['takenDate']),
        dueDate: DateTime.parse(j['dueDate']),
        amountRepaid: (j['amountRepaid'] as num).toDouble(),
      );
}

// ---------------------------------------------------------------------------
// CONSTANTS
// ---------------------------------------------------------------------------

const Color _kGreen        = Color(0xFF1B5E20);
const Color _kGreenLight   = Color(0xFF2E7D32);
const Color _kGreenSurface = Color(0xFFE8F5E9);
const Color _kAmber        = Color(0xFFE65100);
const Color _kAmberSurface = Color(0xFFFFF8E1);
const Color _kRed          = Color(0xFFC62828);
const Color _kRedSurface   = Color(0xFFFCE4EC);
const Color _kBlue         = Color(0xFF1565C0);
const Color _kBlueSurface  = Color(0xFFE3F2FD);

const List<String> _kCropCategories = [
  'Maize','Beans','Tomatoes','Potatoes','Kale (Sukuma Wiki)','Cabbage',
  'Wheat','Sorghum','Cassava','Sweet Potato','Onions','Carrots','Peas',
  'Sunflower','Coffee','Tea','Avocado','Banana','Other',
];

const List<String> _kExpenseCategories = [
  'Labour','Seeds & Planting Material','Fertilizer',
  'Pesticide / Herbicide','Equipment Hire','Irrigation',
  'Transport','Miscellaneous',
];

const List<String> _kTaskCategories = [
  'Spray','Irrigate','Fertilise','Weed','Harvest','Labour',
  'Soil Prep','Planting','Other',
];

const List<String> _kGrowthStages = [
  'Germination','Seedling','Vegetative','Flowering',
  'Pod / Grain Fill','Ripening','Ready to Harvest',
];

const List<String> _kSeasonNames = [
  'Long Rains (Mar–Jun)','Short Rains (Oct–Dec)',
  'Dry Season (Jul–Sep)','Irrigation Season','Custom',
];

// ---------------------------------------------------------------------------
// MAIN WIDGET
// ---------------------------------------------------------------------------

class FarmManagementScreen extends StatefulWidget {
  const FarmManagementScreen({super.key});

  @override
  State<FarmManagementScreen> createState() => _FarmManagementScreenState();
}

class _FarmManagementScreenState extends State<FarmManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  late SharedPreferences _prefs;
  bool _loading = true;

  String _resolvedUid = '';
  String _key(String k) => '${_resolvedUid}_$k';

  CollectionReference<Map<String, dynamic>> get _backupCollection =>
      FirebaseFirestore.instance
          .collection('farmer_farm_management')
          .doc(_resolvedUid)
          .collection('seasons');

  String _seasonName  = 'Long Rains 2025';
  List<String> _pastSeasons = [];

  List<FarmPlot>      _plots    = [];
  List<FarmTask>      _tasks    = [];
  List<FarmExpense>   _expenses = [];
  List<HarvestRecord> _harvests = [];
  List<LoanRecord>    _loans    = [];

  // ── Field costs streamed from field_costs (source: 'field_data' only) ───────
  List<FieldCostEntry>   _fieldCosts   = [];
  // ── Pest costs streamed from pest_costs (PestCostService) ────────────────────
  List<PestCostEntry>    _pestCosts    = [];
  // ── Disease costs streamed from disease_costs (DiseaseCostService) ───────────
  List<DiseaseCostEntry> _diseaseCosts = [];
  bool _disclaimerShown = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
    _init();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      user = await FirebaseAuth.instance
          .authStateChanges()
          .firstWhere((u) => u != null)
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
    }
    if (!mounted) return;
    _resolvedUid =
        user?.uid ?? 'anonymous_${DateTime.now().millisecondsSinceEpoch}';
    await _loadAll();
    _loadFieldCosts();
    _checkDisclaimer();
  }

  // ── Load costs from three independent collections ────────────────────────
  // field_costs  → FieldCostService   (source: 'field_data')
  // pest_costs   → PestCostService    (source: 'pest_management')
  // disease_costs→ DiseaseCostService (source: 'disease_management')

  void _loadFieldCosts() {
    if (_resolvedUid.startsWith('anonymous')) return;

    // Field data costs (field_costs collection, field_data source only)
    FieldCostService.streamForUser().listen((entries) {
      if (mounted) {
        setState(() {
          _fieldCosts = entries.where((e) => e.source == 'field_data').toList();
        });
      }
    });

    // Pest management costs (pest_costs collection)
    PestCostService.streamForUser().listen((entries) {
      if (mounted) setState(() => _pestCosts = entries);
    });

    // Disease management costs (disease_costs collection)
    DiseaseCostService.streamForUser().listen((entries) {
      if (mounted) setState(() => _diseaseCosts = entries);
    });
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  Future<void> _loadAll() async {
    _prefs = await SharedPreferences.getInstance();
    final localSeason = _prefs.getString(_key('v2_seasonName'));

    if (localSeason != null) {
      setState(() {
        _seasonName  = localSeason;
        _pastSeasons = _prefs.getStringList(_key('v2_pastSeasons')) ?? [];
        _plots    = _decode<FarmPlot>(_key('v2_plots'),    FarmPlot.fromJson);
        _tasks    = _decode<FarmTask>(_key('v2_tasks'),    FarmTask.fromJson);
        _expenses = _decode<FarmExpense>(_key('v2_expenses'), FarmExpense.fromJson);
        _harvests = _decode<HarvestRecord>(_key('v2_harvests'), HarvestRecord.fromJson);
        _loans    = _decode<LoanRecord>(_key('v2_loans'),    LoanRecord.fromJson);
        _loading  = false;
      });
    } else {
      setState(() => _loading = true);
      try {
        final doc = await _backupCollection
            .doc(_seasonName)
            .get()
            .timeout(const Duration(seconds: 8));
        if (doc.exists) {
          final d = doc.data()!;
          setState(() {
            _seasonName  = d['seasonName'] ?? 'Long Rains 2025';
            _pastSeasons = List<String>.from(d['pastSeasons'] ?? []);
            _plots    = _decodeList<FarmPlot>(d['plots'],    FarmPlot.fromJson);
            _tasks    = _decodeList<FarmTask>(d['tasks'],    FarmTask.fromJson);
            _expenses = _decodeList<FarmExpense>(d['expenses'], FarmExpense.fromJson);
            _harvests = _decodeList<HarvestRecord>(d['harvests'], HarvestRecord.fromJson);
            _loans    = _decodeList<LoanRecord>(d['loans'],    LoanRecord.fromJson);
          });
          await _writeLocalPrefs();
        }
      } catch (_) {}
      finally { if (mounted) setState(() => _loading = false); }
    }
  }

  List<T> _decode<T>(String key, T Function(Map<String, dynamic>) fn) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    try { return (jsonDecode(raw) as List).map((e) => fn(e)).toList(); }
    catch (_) { return []; }
  }

  List<T> _decodeList<T>(dynamic raw, T Function(Map<String, dynamic>) fn) {
    if (raw == null) return [];
    try { return (raw as List).map((e) => fn(e)).toList(); }
    catch (_) { return []; }
  }

  Future<void> _writeLocalPrefs() async {
    await _prefs.setString(_key('v2_seasonName'), _seasonName);
    await _prefs.setStringList(_key('v2_pastSeasons'), _pastSeasons);
    await _prefs.setString(_key('v2_plots'),    jsonEncode(_plots.map((e) => e.toJson()).toList()));
    await _prefs.setString(_key('v2_tasks'),    jsonEncode(_tasks.map((e) => e.toJson()).toList()));
    await _prefs.setString(_key('v2_expenses'), jsonEncode(_expenses.map((e) => e.toJson()).toList()));
    await _prefs.setString(_key('v2_harvests'), jsonEncode(_harvests.map((e) => e.toJson()).toList()));
    await _prefs.setString(_key('v2_loans'),    jsonEncode(_loans.map((e) => e.toJson()).toList()));
  }

  Future<void> _writeFirestoreBackup() async {
    if (_resolvedUid.startsWith('anonymous')) return;
    try {
      await _backupCollection.doc(_seasonName).set({
        'seasonName': _seasonName, 'pastSeasons': _pastSeasons,
        'plots':    _plots.map((e) => e.toJson()).toList(),
        'tasks':    _tasks.map((e) => e.toJson()).toList(),
        'expenses': _expenses.map((e) => e.toJson()).toList(),
        'harvests': _harvests.map((e) => e.toJson()).toList(),
        'loans':    _loans.map((e) => e.toJson()).toList(),
        'lastSaved': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _saveAll() async {
    await _writeLocalPrefs();
    _writeFirestoreBackup();
  }

  // ── Disclaimer ────────────────────────────────────────────────────────────

  void _checkDisclaimer() async {
    final shown = _prefs.getBool(_key('v2_disclaimerShown')) ?? false;
    if (!shown && mounted) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) _showDisclaimer();
    }
  }

  void _showDisclaimer() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: const [
          Text('🌾', style: TextStyle(fontSize: 24)),
          SizedBox(width: 10),
          Text('Your Farm Data',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _disclaimerCard(_kGreenSurface, _kGreenLight,
                '✅  Your plots, tasks, costs and harvests are saved securely '
                'on this device AND backed up to your account.'),
            const SizedBox(height: 10),
            _disclaimerCard(_kAmberSurface, _kAmber,
                '⚠️  If you uninstall the app, your records will be restored '
                'from your account the next time you log in.'),
            const SizedBox(height: 10),
            _disclaimerCard(_kBlueSurface, _kBlue,
                '🔗  Costs added in Field Data Input, Pest Management, and Disease Management automatically appear here under Costs — tagged by source so you always know where they came from.'),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _kGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () {
                _prefs.setBool(_key('v2_disclaimerShown'), true);
                setState(() => _disclaimerShown = true);
                Navigator.pop(context);
              },
              child: const Text('Got it, start farming!',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _disclaimerCard(Color bg, Color border, String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border.withOpacity(0.3)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 13, height: 1.5)),
    );
  }

  // ── Computed values ───────────────────────────────────────────────────────

  double get _totalManualExpenses =>
      _expenses.fold(0, (s, e) => s + e.amount);

  double get _totalFieldCosts =>
      _fieldCosts.fold(0, (s, e) => s + e.amount);

  double get _totalPestCosts =>
      _pestCosts.fold(0, (s, e) => s + e.amount);

  double get _totalDiseaseCosts =>
      _diseaseCosts.fold(0, (s, e) => s + e.amount);

  double get _totalExpenses =>
      _totalManualExpenses + _totalFieldCosts + _totalPestCosts + _totalDiseaseCosts;

  double get _totalRevenue =>
      _harvests.where((h) => h.isSold).fold(0, (s, h) => s + h.totalValue);

  double get _expectedRevenue =>
      _harvests.fold(0, (s, h) => s + h.totalValue);

  double get _profitLoss => _totalRevenue - _totalExpenses;

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  List<FarmTask> get _overdueTasks {
    final today = _dateOnly(DateTime.now());
    return _tasks
        .where((t) => !t.isDone && _dateOnly(t.dueDate).isBefore(today))
        .toList()
      ..sort((a, b) => b.dueDate.compareTo(a.dueDate));
  }

  List<FarmTask> get _todayTasks {
    final n = DateTime.now();
    return _tasks
        .where((t) =>
            !t.isDone &&
            t.dueDate.year == n.year &&
            t.dueDate.month == n.month &&
            t.dueDate.day == n.day)
        .toList();
  }

  List<FarmTask> get _upcomingTasks {
    final tomorrow =
        _dateOnly(DateTime.now()).add(const Duration(days: 1));
    return _tasks
        .where((t) =>
            !t.isDone && !_dateOnly(t.dueDate).isBefore(tomorrow))
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  List<FarmTask> get _doneTasks =>
      _tasks.where((t) => t.isDone).toList()
        ..sort((a, b) => b.dueDate.compareTo(a.dueDate));

  double get _totalLoanBalance =>
      _loans.fold(0, (s, l) => s + l.balance);

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmtKSH(double v) =>
      'KSH ${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}';

  String _fmtDate(DateTime d) =>
      '${d.day} ${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][d.month - 1]}';

  IconData _taskIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'spray':    return Icons.science_outlined;
      case 'irrigate': return Icons.water_drop_outlined;
      case 'fertilise':return Icons.grass;
      case 'weed':     return Icons.content_cut;
      case 'harvest':  return Icons.agriculture;
      case 'labour':   return Icons.people_outline;
      case 'soil prep':return Icons.terrain;
      case 'planting': return Icons.eco_outlined;
      default:         return Icons.task_alt;
    }
  }

  Color _taskColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'spray':    return _kRed;
      case 'irrigate': return _kBlue;
      case 'fertilise':return _kGreenLight;
      case 'weed':     return _kAmber;
      case 'harvest':  return _kGreen;
      case 'labour':   return const Color(0xFF6A1B9A);
      default:         return Colors.grey.shade600;
    }
  }

  Color _taskSurface(String cat) {
    switch (cat.toLowerCase()) {
      case 'spray':    return _kRedSurface;
      case 'irrigate': return _kBlueSurface;
      case 'fertilise':return _kGreenSurface;
      case 'weed':     return _kAmberSurface;
      case 'harvest':  return _kGreenSurface;
      case 'labour':   return const Color(0xFFF3E5F5);
      default:         return Colors.grey.shade100;
    }
  }

  Color _priorityColor(String p) {
    switch (p) {
      case 'urgent': return _kRed;
      case 'normal': return _kAmber;
      default:       return Colors.grey.shade500;
    }
  }

  String _expenseIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'labour':                    return '👷';
      case 'seeds & planting material': return '🌱';
      case 'fertilizer':                return '🧪';
      case 'pesticide / herbicide':     return '💊';
      case 'equipment hire':            return '🚜';
      case 'irrigation':                return '💧';
      case 'transport':                 return '🚛';
      default:                          return '📦';
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: _kGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Farm Management',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        titleSpacing: 0,
        actions: [
          // Reminder manager shortcut
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            tooltip: 'Field reminders',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      ReminderManagerPage(userId: _resolvedUid)),
            ),
          ),
          TextButton.icon(
            onPressed: _showSeasonPicker,
            icon: const Icon(Icons.swap_horiz, color: Colors.white70, size: 16),
            label: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 110),
              child: Text(_seasonName,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                  overflow: TextOverflow.ellipsis, maxLines: 1),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          _StatStrip(
            plots: _plots.length,
            fmtCosts: _fmtKSH(_totalExpenses),
            fmtIncome: _fmtKSH(_expectedRevenue),
            fmtProfitLoss: _fmtKSH(_profitLoss.abs()),
            isProfit: _profitLoss >= 0,
            fieldCostCount: _fieldCosts.length,
            pestCostCount: _pestCosts.length,
            diseaseCostCount: _diseaseCosts.length,
          ),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _OverviewTab(parent: this),
                _PlotsTab(parent: this),
                _TasksTab(parent: this),
                _CostsTab(parent: this),
                _HarvestTab(parent: this),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tab,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: _kGreen,
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: _kGreen,
        labelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        tabs: [
          const Tab(text: 'Overview'),
          const Tab(text: 'My Plots'),
          const Tab(text: 'Tasks'),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Costs'),
                if (_fieldCosts.isNotEmpty || _pestCosts.isNotEmpty || _diseaseCosts.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: _kAmber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '+${_fieldCosts.length + _pestCosts.length + _diseaseCosts.length}',
                      style: const TextStyle(fontSize: 10, color: _kAmber),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Tab(text: 'Harvest & Sales'),
        ],
      ),
    );
  }

  // ── Season picker ─────────────────────────────────────────────────────────

  void _showSeasonPicker() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: false,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SeasonPickerSheet(
        current: _seasonName,
        past: _pastSeasons,
        onSelect: (s) {
          setState(() => _seasonName = s);
          _saveAll();
        },
        onNew: _showNewSeasonDialog,
      ),
    );
  }

  void _showNewSeasonDialog() async {
    String? selected;
    int? year;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New Season'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Season'),
              items: _kSeasonNames
                  .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                  .toList(),
              onChanged: (v) => selected = v,
            ),
            const SizedBox(height: 8),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Year'),
              keyboardType: TextInputType.number,
              onChanged: (v) => year = int.tryParse(v),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kGreen),
            onPressed: () {
              if (selected != null && year != null) {
                final newName = '$selected $year';
                setState(() {
                  if (!_pastSeasons.contains(_seasonName))
                    _pastSeasons.insert(0, _seasonName);
                  _seasonName = newName;
                  _plots.clear(); _tasks.clear();
                  _expenses.clear(); _harvests.clear(); _loans.clear();
                });
                _saveAll();
                Navigator.pop(context);
              }
            },
            child: const Text('Start', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// STAT STRIP
// ---------------------------------------------------------------------------

class _StatStrip extends StatelessWidget {
  final int plots, fieldCostCount, pestCostCount, diseaseCostCount;
  final String fmtCosts, fmtIncome, fmtProfitLoss;
  final bool isProfit;

  const _StatStrip({
    required this.plots, required this.fmtCosts, required this.fmtIncome,
    required this.fmtProfitLoss, required this.isProfit,
    this.fieldCostCount = 0, this.pestCostCount = 0, this.diseaseCostCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _kGreen,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Wrap(
        spacing: 8, runSpacing: 6,
        children: [
          _pill('$plots plot${plots == 1 ? '' : 's'}',
              Icons.map_outlined, Colors.white70),
          _pill('Costs: $fmtCosts', Icons.payments_outlined, Colors.white),
          if (fieldCostCount > 0)
            _pill('$fieldCostCount from field',
                Icons.agriculture_outlined, const Color(0xFF69F0AE)),
          if (pestCostCount > 0)
            _pill('$pestCostCount pest',
                Icons.bug_report_outlined, const Color(0xFFFFD54F)),
          if (diseaseCostCount > 0)
            _pill('$diseaseCostCount disease',
                Icons.local_hospital_outlined, const Color(0xFFEF9A9A)),
          _pill('Income: $fmtIncome', Icons.trending_up, Colors.white),
          _pill(
            isProfit ? '▲ Profit $fmtProfitLoss' : '▼ Loss $fmtProfitLoss',
            isProfit ? Icons.thumb_up_alt_outlined : Icons.thumb_down_alt_outlined,
            isProfit ? const Color(0xFF69F0AE) : const Color(0xFFFF8A80),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, IconData icon, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}

// ---------------------------------------------------------------------------
// SEASON PICKER SHEET
// ---------------------------------------------------------------------------

class _SeasonPickerSheet extends StatelessWidget {
  final String current;
  final List<String> past;
  final ValueChanged<String> onSelect;
  final VoidCallback onNew;

  const _SeasonPickerSheet(
      {required this.current, required this.past,
       required this.onSelect, required this.onNew});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Switch Season',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.circle, color: _kGreen, size: 12),
            title: Text(current,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Current season'),
            tileColor: _kGreenSurface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          if (past.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Past Seasons',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            ...past.take(5).map((s) => ListTile(
                  title: Text(s),
                  onTap: () {
                    Navigator.pop(context);
                    onSelect(s);
                  },
                )),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _kGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              icon: const Icon(Icons.add),
              label: const Text('Start New Season'),
              onPressed: () {
                Navigator.pop(context);
                onNew();
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// TAB 1: OVERVIEW
// ===========================================================================

class _OverviewTab extends StatelessWidget {
  final _FarmManagementScreenState parent;
  const _OverviewTab({required this.parent});

  @override
  Widget build(BuildContext context) {
    final overdue  = parent._overdueTasks;
    final today    = parent._todayTasks;
    final upcoming = parent._upcomingTasks.take(3).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _WeatherTipCard(),
        const SizedBox(height: 16),
        const Text('Quick Actions',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _QuickActionsGrid(parent: parent),
        const SizedBox(height: 20),

        if (overdue.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('⚠️  Overdue',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _kRed)),
              Text('${overdue.length} task${overdue.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: _kRed, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          ...overdue.take(3).map((t) => _TaskCard(task: t, parent: parent)),
          const SizedBox(height: 20),
        ],

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Today's Tasks",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            if (today.isNotEmpty)
              Text('${today.length} due',
                  style: const TextStyle(color: _kAmber, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 8),
        if (today.isEmpty)
          _EmptyState(icon: Icons.check_circle_outline,
              message: 'No tasks due today.', color: _kGreen)
        else
          ...today.map((t) => _TaskCard(task: t, parent: parent)),

        if (upcoming.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Upcoming',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...upcoming.map((t) => _TaskCard(task: t, parent: parent)),
        ],

        if (parent._plots.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Plot Snapshots',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...parent._plots.map((p) => _PlotSnapshotCard(plot: p)),
        ],
      ],
    );
  }
}

class _WeatherTipCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kBlueSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBlue.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Text('⛅', style: TextStyle(fontSize: 30)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Partly Cloudy · 24°C',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _kBlue, fontSize: 14)),
                    const Spacer(),
                    Text('Today',
                        style: TextStyle(
                            fontSize: 12, color: _kBlue.withOpacity(0.7))),
                  ],
                ),
                const SizedBox(height: 3),
                Text('Good day for spraying. Rain expected Thursday.',
                    style: TextStyle(fontSize: 12, color: _kBlue)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  final _FarmManagementScreenState parent;
  const _QuickActionsGrid({required this.parent});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QA('Log Activity', Icons.edit_note, _kGreen,
          () => parent._tab.animateTo(2)),
      _QA('Add Cost', Icons.payments_outlined, _kAmber,
          () => parent._tab.animateTo(3)),
      _QA('Record Harvest', Icons.agriculture, _kGreenLight,
          () => parent._tab.animateTo(4)),
      _QA('New Plot', Icons.add_location_alt_outlined, _kBlue,
          () => parent._showAddPlotSheet()),
    ];
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: actions.map((a) => _QAButton(action: a)).toList(),
    );
  }
}

class _QA {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  _QA(this.label, this.icon, this.color, this.onTap);
}

class _QAButton extends StatelessWidget {
  final _QA action;
  const _QAButton({required this.action});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: action.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: action.color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: action.color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(action.icon, color: action.color, size: 24),
            const SizedBox(height: 4),
            Text(action.label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: action.color)),
          ],
        ),
      ),
    );
  }
}

class _PlotSnapshotCard extends StatelessWidget {
  final FarmPlot plot;
  const _PlotSnapshotCard({required this.plot});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
                color: _kGreenSurface,
                borderRadius: BorderRadius.circular(10)),
            child: const Center(child: Text('🌱', style: TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plot.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                Text('${plot.cropName} · ${plot.acreage} acres',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: plot.growthPercent,
                  backgroundColor: Colors.grey.shade200,
                  color: _kGreenLight,
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 3),
                Text(
                    '${plot.growthStage} · ${(plot.growthPercent * 100).toInt()}%',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// TAB 2: MY PLOTS  (unchanged structure)
// ===========================================================================

class _PlotsTab extends StatelessWidget {
  final _FarmManagementScreenState parent;
  const _PlotsTab({required this.parent});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...parent._plots
            .map((p) => _PlotDetailCard(plot: p, parent: parent)),
        _AddButton(
            label: '+ Add New Plot',
            onTap: () => parent._showAddPlotSheet()),
      ],
    );
  }
}

class _PlotDetailCard extends StatelessWidget {
  final FarmPlot plot;
  final _FarmManagementScreenState parent;
  const _PlotDetailCard({required this.plot, required this.parent});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: _kGreenSurface,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(plot.name,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('${plot.cropName} – ${plot.cropVariety}',
                          style: const TextStyle(
                              color: _kGreen, fontSize: 13)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${plot.acreage} acres',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('Planted ${parent._fmtDate(plot.plantingDate)}',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(plot.growthStage,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${(plot.growthPercent * 100).toInt()}% of season',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: plot.growthPercent,
                  backgroundColor: Colors.grey.shade200,
                  color: _kGreenLight,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(6),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _plotStat('Days planted', '${plot.growthDaysElapsed}d'),
                    _plotStat('Days left',
                        '${(plot.growthDaysTotal - plot.growthDaysElapsed).clamp(0, 999)}d'),
                    _plotStat('Stage',
                        _kGrowthStages.indexOf(plot.growthStage) >= 0
                            ? '${_kGrowthStages.indexOf(plot.growthStage) + 1}/${_kGrowthStages.length}'
                            : '-'),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const Text('Inputs Used',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                // Manual expenses
                ...parent._expenses
                    .where((e) =>
                        e.plotId == plot.id || e.plotId == 'all')
                    .take(3)
                    .map((e) => _expenseRow(
                        parent._expenseIcon(e.category),
                        e.description,
                        parent._fmtKSH(e.amount))),
                // Field costs for this plot
                ...parent._fieldCosts
                    .where((e) => e.plotId == plot.id)
                    .take(2)
                    .map((e) => _expenseRow(
                        parent._expenseIcon(e.category),
                        '${e.description} 🌱',
                        parent._fmtKSH(e.amount))),
                if (parent._expenses.isEmpty && parent._fieldCosts.isEmpty)
                  Text('No inputs recorded yet',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                _SmallButton(
                    label: 'Edit Plot',
                    icon: Icons.edit_outlined,
                    onTap: () => parent._showEditPlotSheet(plot)),
                const SizedBox(width: 8),
                _SmallButton(
                    label: 'Add Task',
                    icon: Icons.add_task,
                    onTap: () =>
                        parent._showAddTaskSheet(preselectedPlotId: plot.id)),
                const SizedBox(width: 8),
                _SmallButton(
                    label: 'Delete',
                    icon: Icons.delete_outline,
                    color: _kRed,
                    onTap: () => parent._confirmDeletePlot(plot)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _expenseRow(String icon, String desc, String amt) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(desc, style: const TextStyle(fontSize: 12))),
          Text(amt,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _plotStat(String label, String value) => Expanded(
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 10)),
          ],
        ),
      );
}

// ===========================================================================
// TAB 3: TASKS  (unchanged)
// ===========================================================================

class _TasksTab extends StatefulWidget {
  final _FarmManagementScreenState parent;
  const _TasksTab({required this.parent});

  @override
  State<_TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<_TasksTab> {
  bool _showDone = false;

  @override
  Widget build(BuildContext context) {
    final overdue  = widget.parent._overdueTasks;
    final today    = widget.parent._todayTasks;
    final upcoming = widget.parent._upcomingTasks;
    final done     = widget.parent._doneTasks;
    final hasActive =
        overdue.isNotEmpty || today.isNotEmpty || upcoming.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (overdue.isNotEmpty) ...[
          _sectionHeader('⚠️  Overdue (${overdue.length})', color: _kRed),
          ...overdue.map((t) => _TaskCard(
              task: t,
              parent: widget.parent,
              onToggle: () => setState(() {}))),
          const SizedBox(height: 12),
        ],
        if (today.isNotEmpty) ...[
          _sectionHeader('Today (${today.length})'),
          ...today.map((t) => _TaskCard(
              task: t,
              parent: widget.parent,
              onToggle: () => setState(() {}))),
          const SizedBox(height: 12),
        ],
        if (upcoming.isNotEmpty) ...[
          _sectionHeader('Upcoming (${upcoming.length})'),
          ...upcoming.map((t) => _TaskCard(
              task: t,
              parent: widget.parent,
              onToggle: () => setState(() {}))),
          const SizedBox(height: 12),
        ],
        if (!hasActive)
          _EmptyState(
              icon: Icons.task_alt,
              message:
                  'No active tasks.\nAdd tasks below — log past, today or future dates.',
              color: _kGreen),
        _AddButton(
            label: '+ Add Task',
            onTap: () => widget.parent._showAddTaskSheet()),
        if (done.isNotEmpty) ...[
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => setState(() => _showDone = !_showDone),
            child: Row(children: [
              Text(
                  '${_showDone ? 'Hide' : 'Show'} completed (${done.length})',
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 13)),
              Icon(_showDone ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey.shade600),
            ]),
          ),
          if (_showDone)
            ...done.map((t) => _TaskCard(
                task: t,
                parent: widget.parent,
                onToggle: () => setState(() {}))),
        ],
      ],
    );
  }

  Widget _sectionHeader(String text, {Color? color}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color ?? Colors.black87)),
      );
}

class _TaskCard extends StatelessWidget {
  final FarmTask task;
  final _FarmManagementScreenState parent;
  final VoidCallback? onToggle;
  const _TaskCard(
      {required this.task, required this.parent, this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: task.isDone ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: task.isDone
                ? Colors.grey.shade200
                : parent
                    ._priorityColor(task.priority)
                    .withOpacity(0.25)),
      ),
      child: ListTile(
        leading: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: task.isDone
                ? Colors.grey.shade100
                : parent._taskSurface(task.category),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
              parent._taskIcon(task.category),
              color: task.isDone
                  ? Colors.grey
                  : parent._taskColor(task.category),
              size: 20),
        ),
        title: Text(task.title,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                decoration:
                    task.isDone ? TextDecoration.lineThrough : null,
                color: task.isDone ? Colors.grey : null)),
        subtitle: Text(
            task.description.isEmpty
                ? parent._fmtDate(task.dueDate)
                : '${task.description} · ${parent._fmtDate(task.dueDate)}',
            style: const TextStyle(fontSize: 11)),
        trailing: Checkbox(
          value: task.isDone,
          activeColor: _kGreen,
          onChanged: (_) {
            task.isDone = !task.isDone;
            parent._saveAll();
            onToggle?.call();
          },
        ),
        onLongPress: () => parent._confirmDeleteTask(task),
      ),
    );
  }
}

// ===========================================================================
// TAB 4: COSTS  — now includes field_costs section
// ===========================================================================

class _CostsTab extends StatefulWidget {
  final _FarmManagementScreenState parent;
  const _CostsTab({required this.parent});

  @override
  State<_CostsTab> createState() => _CostsTabState();
}

class _CostsTabState extends State<_CostsTab> {
  bool _showFieldCosts = true;
  bool _showPestCosts = true;
  bool _showDiseaseCosts = true;

  @override
  Widget build(BuildContext context) {
    final p = widget.parent;

    final Map<String, double> byCategory = {};
    for (final e in p._expenses) {
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    }
    for (final e in p._fieldCosts) {
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    }
    for (final e in p._pestCosts) {
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    }
    for (final e in p._diseaseCosts) {
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SummaryBand(
          leftLabel: 'Total Spent',
          leftValue: p._fmtKSH(p._totalExpenses),
          rightLabel: 'Total Earned',
          rightValue: p._fmtKSH(p._totalRevenue),
          bottomLabel: p._profitLoss >= 0 ? 'Profit' : 'Loss',
          bottomValue: p._fmtKSH(p._profitLoss.abs()),
          isPositive: p._profitLoss >= 0,
        ),
        const SizedBox(height: 16),

        // ── Category breakdown ────────────────────────────────────────
        const Text('Costs by Category',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ...byCategory.entries.map((e) => _CostCategoryRow(
              icon: p._expenseIcon(e.key),
              category: e.key,
              amount: e.value,
              total: p._totalExpenses,
            )),
        if (byCategory.isEmpty)
          _EmptyState(
              icon: Icons.payments_outlined,
              message: 'No expenses recorded yet.',
              color: _kAmber),

        const SizedBox(height: 12),
        _AddButton(
            label: '+ Add Expense',
            onTap: () => p._showAddExpenseSheet()),

        // ── From Field section ────────────────────────────────────────
        if (p._fieldCosts.isNotEmpty) ...[
          const SizedBox(height: 20),
          _ExternalCostSection(
            badge: '🌱 From Field',
            badgeColor: const Color(0xFF1B5E20),
            badgeBg: const Color(0xFFE8F5E9),
            badgeBorder: const Color(0xFFA5D6A7),
            icon: Icons.agriculture_outlined,
            entryCount: p._fieldCosts.length,
            totalFormatted: p._fmtKSH(p._totalFieldCosts),
            infoNote: '🌱 These costs were added while logging interventions in Field Data Input. Edit or delete them from plot history in Field Data.',
            entries: p._fieldCosts.map(_CostEntryView.fromField).toList(),
            parent: p,
            isExpanded: _showFieldCosts,
            onToggle: () => setState(() => _showFieldCosts = !_showFieldCosts),
          ),
        ],

        // ── From Pest Management ──────────────────────────────────────
        if (p._pestCosts.isNotEmpty) ...[
          const SizedBox(height: 20),
          _ExternalCostSection(
            badge: '🪲 From Pest',
            badgeColor: const Color(0xFF7A4F00),
            badgeBg: const Color(0xFFFFF3CD),
            badgeBorder: const Color(0xFFE6A817),
            icon: Icons.bug_report_outlined,
            entryCount: p._pestCosts.length,
            totalFormatted: p._fmtKSH(p._totalPestCosts),
            infoNote: '🪲 These costs were added while recording pest interventions. Edit or delete them from Pest Management › History.',
            entries: p._pestCosts.map(_CostEntryView.fromPest).toList(),
            parent: p,
            isExpanded: _showPestCosts,
            onToggle: () => setState(() => _showPestCosts = !_showPestCosts),
          ),
        ],

        // ── From Disease Management ───────────────────────────────────
        if (p._diseaseCosts.isNotEmpty) ...[
          const SizedBox(height: 20),
          _ExternalCostSection(
            badge: '🦠 From Disease',
            badgeColor: const Color(0xFF8B0000),
            badgeBg: const Color(0xFFFCE4EC),
            badgeBorder: const Color(0xFFEF9A9A),
            icon: Icons.local_hospital_outlined,
            entryCount: p._diseaseCosts.length,
            totalFormatted: p._fmtKSH(p._totalDiseaseCosts),
            infoNote: '🦠 These costs were added while recording disease interventions. Edit or delete them from Disease Management › History.',
            entries: p._diseaseCosts.map(_CostEntryView.fromDisease).toList(),
            parent: p,
            isExpanded: _showDiseaseCosts,
            onToggle: () => setState(() => _showDiseaseCosts = !_showDiseaseCosts),
          ),
        ],

        // ── Manual entries ────────────────────────────────────────────
        if (p._expenses.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('All Manual Expenses',
              style:
                  TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...p._expenses.reversed
              .take(20)
              .map((e) => _ExpenseListTile(expense: e, parent: p)),
        ],

        // ── Loan tracker ──────────────────────────────────────────────
        const SizedBox(height: 20),
        const Text('Loan Tracker',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...p._loans.map((l) => _LoanCard(loan: l, parent: p)),
        if (p._loans.isEmpty)
          _EmptyState(
              icon: Icons.account_balance_outlined,
              message: 'No loans recorded.',
              color: _kBlue),
        const SizedBox(height: 8),
        _AddButton(
            label: '+ Add Loan',
            onTap: () => p._showAddLoanSheet()),
      ],
    );
  }
}

class _FieldCostTile extends StatelessWidget {
  final FieldCostEntry entry;
  final _FarmManagementScreenState parent;
  const _FieldCostTile({required this.entry, required this.parent});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFA5D6A7)),
      ),
      child: Row(
        children: [
          Text(parent._expenseIcon(entry.category),
              style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.description,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                Row(children: [
                  Text(
                      '${entry.category} · ${entry.date.toString().substring(0, 10)}',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('🌱 Field',
                        style: TextStyle(
                            fontSize: 9, color: Color(0xFF1B5E20))),
                  ),
                ]),
              ],
            ),
          ),
          Text(parent._fmtKSH(entry.amount),
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}

// ── Generic reusable external cost section (Field / Pest / Disease) ──────────

// ── Normalised view model used by _ExternalCostSection ───────────────────────
// Converts FieldCostEntry / PestCostEntry / DiseaseCostEntry to a common shape.
class _CostEntryView {
  final String plotId, description, category;
  final double amount;
  final DateTime date;

  const _CostEntryView({
    required this.plotId,
    required this.description,
    required this.category,
    required this.amount,
    required this.date,
  });

  static _CostEntryView fromField(FieldCostEntry e) => _CostEntryView(
      plotId: e.plotId, description: e.description,
      category: e.category, amount: e.amount, date: e.date);

  static _CostEntryView fromPest(PestCostEntry e) => _CostEntryView(
      plotId: e.plotId, description: e.description,
      category: e.category, amount: e.amount, date: e.date);

  static _CostEntryView fromDisease(DiseaseCostEntry e) => _CostEntryView(
      plotId: e.plotId, description: e.description,
      category: e.category, amount: e.amount, date: e.date);
}

class _ExternalCostSection extends StatelessWidget {
  final String badge, infoNote;
  final Color badgeColor, badgeBg, badgeBorder;
  final IconData icon;
  final int entryCount;
  final String totalFormatted;
  final List<_CostEntryView> entries;
  final _FarmManagementScreenState parent;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _ExternalCostSection({
    required this.badge,
    required this.badgeColor,
    required this.badgeBg,
    required this.badgeBorder,
    required this.icon,
    required this.entryCount,
    required this.totalFormatted,
    required this.infoNote,
    required this.entries,
    required this.parent,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onToggle,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 12, color: badgeColor),
                    const SizedBox(width: 4),
                    Text(badge,
                        style: TextStyle(
                            fontSize: 11,
                            color: badgeColor,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    '$entryCount entr${entryCount == 1 ? 'y' : 'ies'} · $totalFormatted',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold)),
              ),
              Icon(isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey.shade600),
            ],
          ),
        ),
        if (isExpanded) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: badgeBorder),
            ),
            child: Text(infoNote,
                style: TextStyle(fontSize: 11, color: badgeColor)),
          ),
          const SizedBox(height: 8),
          ...entries.map((e) => _ExternalCostTile(
              entry: e, parent: parent,
              tileBorder: badgeBorder, sourceLabel: badge)),
        ],
      ],
    );
  }
}

class _ExternalCostTile extends StatelessWidget {
  final _CostEntryView entry;
  final _FarmManagementScreenState parent;
  final Color tileBorder;
  final String sourceLabel;
  const _ExternalCostTile({
    required this.entry,
    required this.parent,
    required this.tileBorder,
    required this.sourceLabel,
  });

  @override
  Widget build(BuildContext context) {
    final plotName = parent._plots
        .where((p) => p.id == entry.plotId)
        .map((p) => p.name)
        .firstOrNull;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tileBorder),
      ),
      child: Row(
        children: [
          Text(parent._expenseIcon(entry.category),
              style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.description,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                Wrap(spacing: 4, children: [
                  Text(
                      '${entry.category} · ${entry.date.toString().substring(0, 10)}',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500)),
                  if (plotName != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('📍 $plotName',
                          style: const TextStyle(
                              fontSize: 9, color: Color(0xFF1B5E20))),
                    ),
                ]),
              ],
            ),
          ),
          Text(parent._fmtKSH(entry.amount),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}

class _SummaryBand extends StatelessWidget {
  final String leftLabel, leftValue, rightLabel, rightValue;
  final String bottomLabel, bottomValue;
  final bool isPositive;
  const _SummaryBand({
    required this.leftLabel, required this.leftValue,
    required this.rightLabel, required this.rightValue,
    required this.bottomLabel, required this.bottomValue,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isPositive ? _kGreenSurface : _kRedSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isPositive
                ? _kGreenLight.withOpacity(0.3)
                : _kRed.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _statItem(leftLabel, leftValue)),
              Container(width: 1, height: 40, color: Colors.grey.withOpacity(0.3)),
              Expanded(child: _statItem(rightLabel, rightValue)),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: (isPositive ? _kGreenLight : _kRed).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                    isPositive ? Icons.trending_up : Icons.trending_down,
                    color: isPositive ? _kGreenLight : _kRed,
                    size: 18),
                const SizedBox(width: 6),
                Text('$bottomLabel: $bottomValue',
                    style: TextStyle(
                        color: isPositive ? _kGreen : _kRed,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) => Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: Colors.grey.shade600)),
        ],
      );
}

class _CostCategoryRow extends StatelessWidget {
  final String icon, category;
  final double amount, total;
  const _CostCategoryRow(
      {required this.icon, required this.category,
       required this.amount, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? amount / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(category,
                      style: const TextStyle(fontSize: 13))),
              Text('KSH ${amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              Text('${(pct * 100).toInt()}%',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.grey.shade200,
            color: _kAmber,
            minHeight: 4,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }
}

class _ExpenseListTile extends StatelessWidget {
  final FarmExpense expense;
  final _FarmManagementScreenState parent;
  const _ExpenseListTile({required this.expense, required this.parent});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Text(parent._expenseIcon(expense.category),
              style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(expense.description,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                Text(
                    '${expense.category} · ${parent._fmtDate(expense.date)}',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
          Text(parent._fmtKSH(expense.amount),
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14)),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: Colors.grey),
            onPressed: () => parent._confirmDeleteExpense(expense),
          ),
        ],
      ),
    );
  }
}

class _LoanCard extends StatelessWidget {
  final LoanRecord loan;
  final _FarmManagementScreenState parent;
  const _LoanCard({required this.loan, required this.parent});

  @override
  Widget build(BuildContext context) {
    final progress = (loan.amountRepaid / loan.totalDue).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance, color: _kBlue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(loan.lenderName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14))),
              Text('Due ${parent._fmtDate(loan.dueDate)}',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade500)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _loanFig('Borrowed', parent._fmtKSH(loan.principal)),
              _loanFig('Total Due', parent._fmtKSH(loan.totalDue)),
              _loanFig('Balance', parent._fmtKSH(loan.balance),
                  color: loan.balance > 0 ? _kRed : _kGreen),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade200,
            color: _kBlue,
            minHeight: 6,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 4),
          Text('${(progress * 100).toInt()}% repaid',
              style:
                  TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          const SizedBox(height: 8),
          _SmallButton(
              label: 'Record Payment',
              icon: Icons.payment,
              onTap: () => parent._showRepaymentSheet(loan)),
        ],
      ),
    );
  }

  Widget _loanFig(String label, String value, {Color? color}) => Expanded(
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: color ?? Colors.black87)),
            Text(label,
                style: TextStyle(
                    fontSize: 10, color: Colors.grey.shade500)),
          ],
        ),
      );
}

// ===========================================================================
// TAB 5: HARVEST & SALES  (unchanged)
// ===========================================================================

class _HarvestTab extends StatelessWidget {
  final _FarmManagementScreenState parent;
  const _HarvestTab({required this.parent});

  @override
  Widget build(BuildContext context) {
    final unsold = parent._harvests.where((h) => !h.isSold).toList();
    final sold   = parent._harvests.where((h) => h.isSold).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _kGreenSurface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(child: _harvFig('Total Earned', parent._fmtKSH(parent._totalRevenue))),
              Container(width: 1, height: 40, color: Colors.grey.withOpacity(0.3)),
              Expanded(child: _harvFig('Expected', parent._fmtKSH(parent._expectedRevenue))),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _kAmberSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kAmber.withOpacity(0.2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.trending_up, color: _kAmber),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Check live market prices before selling to get the best rate.',
                  style: TextStyle(fontSize: 13, color: _kAmber),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (unsold.isNotEmpty) ...[
          const Text('Ready / Expected to Sell',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...unsold.map((h) => _HarvestCard(harvest: h, parent: parent)),
        ],
        if (sold.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Sold',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...sold.map((h) => _HarvestCard(harvest: h, parent: parent)),
        ],
        if (parent._harvests.isEmpty)
          _EmptyState(
              icon: Icons.agriculture,
              message: 'No harvest records yet.',
              color: _kGreenLight),
        const SizedBox(height: 12),
        _AddButton(
            label: '+ Record Harvest',
            onTap: () => parent._showAddHarvestSheet()),
      ],
    );
  }

  Widget _harvFig(String label, String value) => Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: _kGreen)),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: Colors.grey.shade600)),
        ],
      );
}

class _HarvestCard extends StatelessWidget {
  final HarvestRecord harvest;
  final _FarmManagementScreenState parent;
  const _HarvestCard({required this.harvest, required this.parent});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: harvest.isSold
                ? _kGreenLight.withOpacity(0.3)
                : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('🌾 ${harvest.cropName}',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: harvest.isSold ? _kGreenSurface : _kAmberSurface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  harvest.isSold ? 'Sold' : 'Available',
                  style: TextStyle(
                      fontSize: 11,
                      color: harvest.isSold ? _kGreen : _kAmber,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _hFig('Quantity', '${harvest.quantityKg.toStringAsFixed(1)} kg'),
              _hFig('Price/kg', 'KSH ${harvest.pricePerKg.toStringAsFixed(0)}'),
              _hFig('Total', parent._fmtKSH(harvest.totalValue), highlight: true),
            ],
          ),
          if (harvest.buyerName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.handshake_outlined,
                  size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(harvest.buyerName,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600)),
            ]),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              if (!harvest.isSold) ...[
                _SmallButton(
                  label: 'Mark as Sold',
                  icon: Icons.check,
                  color: _kGreenLight,
                  onTap: () {
                    parent.setState(() => harvest.isSold = true);
                    parent._saveAll();
                  },
                ),
                const SizedBox(width: 8),
              ],
              _SmallButton(
                label: 'Delete',
                icon: Icons.delete_outline,
                color: _kRed,
                onTap: () => parent._confirmDeleteHarvest(harvest),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hFig(String label, String value, {bool highlight = false}) =>
      Expanded(
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: highlight ? 15 : 13,
                    color:
                        highlight ? _kGreenLight : Colors.black87)),
            Text(label,
                style: TextStyle(
                    fontSize: 10, color: Colors.grey.shade500)),
          ],
        ),
      );
}

// ===========================================================================
// REMINDER MANAGER PAGE
// ===========================================================================

class ReminderManagerPage extends StatelessWidget {
  final String userId;
  const ReminderManagerPage({required this.userId, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F3),
      appBar: AppBar(
        backgroundColor: _kGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Field Reminders',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('field_reminders')
            .where('userId', isEqualTo: userId)
            .orderBy('scheduledDate', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_none_rounded,
                        size: 52, color: Colors.grey[300]),
                    const SizedBox(height: 14),
                    const Text('No active reminders',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black54)),
                    const SizedBox(height: 8),
                    const Text(
                      'Add scouting or fertiliser reminders when you record field data.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13, color: Colors.black38),
                    ),
                  ],
                ),
              ),
            );
          }

          final now  = DateTime.now();
          final docs = snapshot.data!.docs;

          final upcoming = docs
              .where((d) =>
                  (d['scheduledDate'] as Timestamp)
                      .toDate()
                      .isAfter(now))
              .toList();
          final past = docs
              .where((d) =>
                  !(d['scheduledDate'] as Timestamp)
                      .toDate()
                      .isAfter(now))
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (upcoming.isNotEmpty) ...[
                _sectionLabel('Upcoming'),
                ...upcoming.map((d) => _reminderCard(context, d, false)),
              ],
              if (past.isNotEmpty) ...[
                const SizedBox(height: 16),
                _sectionLabel('Past / completed'),
                ...past.map((d) => _reminderCard(context, d, true)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(label.toUpperCase(),
            style: const TextStyle(
                fontSize: 10,
                color: Colors.black45,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5)),
      );

  Widget _reminderCard(
      BuildContext context, QueryDocumentSnapshot doc, bool isPast) {
    final data = doc.data() as Map<String, dynamic>;
    final date = (data['scheduledDate'] as Timestamp).toDate();
    final title = data['title'] as String? ?? 'Reminder';
    final body  = data['body']  as String? ?? '';
    final plot  = data['plotId'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isPast ? Colors.grey[50] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isPast ? Colors.grey[200]! : const Color(0xFFA5D6A7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: isPast
                  ? Colors.grey[100]
                  : const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isPast
                  ? Icons.notifications_none_rounded
                  : Icons.notifications_active_rounded,
              size: 18,
              color: isPast ? Colors.grey : _kGreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isPast
                            ? Colors.black45
                            : Colors.black87,
                        decoration: isPast
                            ? TextDecoration.lineThrough
                            : null)),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(body,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.black45)),
                ],
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.access_time_rounded,
                      size: 11, color: Colors.black38),
                  const SizedBox(width: 3),
                  Text(
                    '${date.day}/${date.month}/${date.year}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.black38),
                  ),
                  if (plot.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text('· $plot',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black38)),
                  ],
                ]),
              ],
            ),
          ),
          // Cancel / delete button
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: Colors.black26),
            onPressed: () => _cancelReminder(context, doc.id, data['notifId'] as int?),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelReminder(
      BuildContext context, String docId, int? notifId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Cancel reminder',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        content: const Text(
            'This reminder will be cancelled and removed.',
            style: TextStyle(fontSize: 13, color: Colors.black54)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep it')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: _kRed,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            child: const Text('Cancel reminder'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      // Cancel the OS notification
      if (notifId != null) {
        final plugin = FlutterLocalNotificationsPlugin();
        await plugin.cancel(id: notifId);
      }
      // Delete from Firestore
      await FirebaseFirestore.instance
          .collection('field_reminders')
          .doc(docId)
          .delete();
    }
  }
}

// ===========================================================================
// SHARED WIDGETS
// ===========================================================================

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;
  const _EmptyState(
      {required this.icon, required this.message, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(icon, color: color.withOpacity(0.4), size: 40),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.grey.shade500, fontSize: 13)),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _AddButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _kGreenSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kGreenLight.withOpacity(0.4)),
        ),
        child: Center(
          child: Text(label,
              style: const TextStyle(
                  color: _kGreen,
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
        ),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;
  const _SmallButton(
      {required this.label, required this.icon,
       required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? _kGreen;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: c.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: c, size: 14),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: c, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// BOTTOM SHEETS
// ===========================================================================

extension FarmManagementSheets on _FarmManagementScreenState {

  void _showAddPlotSheet({FarmPlot? editing}) {
    final isEdit = editing != null;
    String name = editing?.name ?? '';
    String crop = editing?.cropName ?? _kCropCategories.first;
    String variety = editing?.cropVariety ?? '';
    double acreage = editing?.acreage ?? 0.5;
    DateTime plantDate = editing?.plantingDate ?? DateTime.now();
    int daysTotal = editing?.growthDaysTotal ?? 90;
    String stage = editing?.growthStage ?? _kGrowthStages.first;
    int daysElapsed = editing?.growthDaysElapsed ??
        DateTime.now().difference(plantDate).inDays.clamp(0, daysTotal);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: false,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isEdit ? 'Edit Plot' : 'Add New Plot',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _field(label: 'Plot Name', initial: name, onChanged: (v) => name = v),
                const SizedBox(height: 10),
                _dropdown(label: 'Crop', value: crop, items: _kCropCategories,
                    onChanged: (v) => setS(() => crop = v!)),
                const SizedBox(height: 10),
                _field(label: 'Variety', initial: variety, onChanged: (v) => variety = v),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _field(
                      label: 'Acreage', initial: acreage.toString(),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => acreage = double.tryParse(v) ?? acreage)),
                  const SizedBox(width: 10),
                  Expanded(child: _field(
                      label: 'Days to maturity', initial: daysTotal.toString(),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => daysTotal = int.tryParse(v) ?? daysTotal)),
                ]),
                const SizedBox(height: 10),
                _dateField(label: 'Planting Date', value: plantDate,
                    onPicked: (d) => setS(() {
                      plantDate = d;
                      daysElapsed = DateTime.now()
                          .difference(d).inDays.clamp(0, daysTotal);
                    })),
                const SizedBox(height: 10),
                _dropdown(label: 'Current Growth Stage', value: stage,
                    items: _kGrowthStages,
                    onChanged: (v) => setS(() => stage = v!)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _kGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: () {
                      if (name.isEmpty) return;
                      setState(() {
                        if (isEdit) {
                          editing!
                            ..name = name
                            ..cropName = crop
                            ..cropVariety = variety
                            ..acreage = acreage
                            ..plantingDate = plantDate
                            ..growthDaysTotal = daysTotal
                            ..growthStage = stage
                            ..growthDaysElapsed = daysElapsed;
                        } else {
                          _plots.add(FarmPlot(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            name: name, cropName: crop, cropVariety: variety,
                            acreage: acreage, plantingDate: plantDate,
                            growthDaysTotal: daysTotal, growthStage: stage,
                            growthDaysElapsed: daysElapsed,
                          ));
                        }
                      });
                      _saveAll();
                      Navigator.pop(ctx);
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

  void _showEditPlotSheet(FarmPlot plot) => _showAddPlotSheet(editing: plot);

  void _confirmDeletePlot(FarmPlot plot) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Plot?'),
        content: Text('Remove ${plot.name}? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              setState(() => _plots.removeWhere((p) => p.id == plot.id));
              _saveAll();
              Navigator.pop(context);
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddTaskSheet({String? preselectedPlotId}) {
    String title = '', desc = '';
    String plotId = preselectedPlotId ?? 'all';
    DateTime due = DateTime.now();
    String priority = 'normal';
    String category = _kTaskCategories.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: false,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add Task',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _field(label: 'Task title', onChanged: (v) => title = v),
                const SizedBox(height: 10),
                _field(label: 'Details (optional)', onChanged: (v) => desc = v),
                const SizedBox(height: 10),
                _dropdown(label: 'Category', value: category,
                    items: _kTaskCategories,
                    onChanged: (v) => setS(() => category = v!)),
                const SizedBox(height: 10),
                _dropdown(
                    label: 'Plot', value: plotId,
                    items: ['all', ..._plots.map((p) => p.id)],
                    displayItems: ['All Plots', ..._plots.map((p) => p.name)],
                    onChanged: (v) => setS(() => plotId = v!)),
                const SizedBox(height: 10),
                _dropdown(label: 'Priority', value: priority,
                    items: ['urgent', 'normal', 'low'],
                    displayItems: ['Urgent', 'Normal', 'Low'],
                    onChanged: (v) => setS(() => priority = v!)),
                const SizedBox(height: 10),
                _dateField(label: 'Due Date', value: due,
                    onPicked: (d) => setS(() => due = d)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _kGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: () {
                      if (title.trim().isEmpty) return;
                      setState(() {
                        _tasks.add(FarmTask(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          title: title.trim(), description: desc.trim(),
                          plotId: plotId, dueDate: due,
                          priority: priority, category: category,
                        ));
                      });
                      _saveAll();
                      Navigator.pop(ctx);
                    },
                    child: const Text('Add Task'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteTask(FarmTask task) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Task?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              setState(() => _tasks.removeWhere((t) => t.id == task.id));
              _saveAll();
              Navigator.pop(context);
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddExpenseSheet() {
    String category = _kExpenseCategories.first;
    String desc = '';
    double amount = 0;
    DateTime date = DateTime.now();
    String plotId = 'all';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: false,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Record Expense',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _dropdown(label: 'Category', value: category,
                    items: _kExpenseCategories,
                    onChanged: (v) => setS(() => category = v!)),
                const SizedBox(height: 10),
                _field(label: 'Description (e.g. 50kg CAN fertilizer)',
                    onChanged: (v) => desc = v),
                const SizedBox(height: 10),
                _field(label: 'Amount (KSH)',
                    keyboardType: TextInputType.number,
                    onChanged: (v) => amount = double.tryParse(v) ?? 0),
                const SizedBox(height: 10),
                _dropdown(label: 'Plot', value: plotId,
                    items: ['all', ..._plots.map((p) => p.id)],
                    displayItems: ['All Plots', ..._plots.map((p) => p.name)],
                    onChanged: (v) => setS(() => plotId = v!)),
                const SizedBox(height: 10),
                _dateField(label: 'Date', value: date,
                    onPicked: (d) => setS(() => date = d)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _kGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: () {
                      if (desc.isEmpty || amount <= 0) return;
                      setState(() {
                        _expenses.add(FarmExpense(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          category: category, description: desc,
                          amount: amount, date: date, plotId: plotId,
                        ));
                      });
                      _saveAll();
                      Navigator.pop(ctx);
                    },
                    child: const Text('Add Expense'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteExpense(FarmExpense e) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Expense?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              setState(() => _expenses.removeWhere((x) => x.id == e.id));
              _saveAll();
              Navigator.pop(context);
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddHarvestSheet() {
    String plotId = _plots.isNotEmpty ? _plots.first.id : 'all';
    String cropName = '';
    double qty = 0, price = 0;
    String buyer = '';
    DateTime date = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: false,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Record Harvest',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                if (_plots.isNotEmpty)
                  _dropdown(
                      label: 'Plot', value: plotId,
                      items: _plots.map((p) => p.id).toList(),
                      displayItems: _plots.map((p) => p.name).toList(),
                      onChanged: (v) => setS(() {
                            plotId = v!;
                            cropName = _plots
                                .firstWhere((p) => p.id == v)
                                .cropName;
                          })),
                const SizedBox(height: 10),
                _field(label: 'Crop name', initial: cropName,
                    onChanged: (v) => cropName = v),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _field(
                      label: 'Quantity (kg)',
                      keyboardType: TextInputType.number,
                      onChanged: (v) => qty = double.tryParse(v) ?? 0)),
                  const SizedBox(width: 10),
                  Expanded(child: _field(
                      label: 'Price per kg (KSH)',
                      keyboardType: TextInputType.number,
                      onChanged: (v) => price = double.tryParse(v) ?? 0)),
                ]),
                const SizedBox(height: 10),
                _field(label: 'Buyer / Market (optional)',
                    onChanged: (v) => buyer = v),
                const SizedBox(height: 10),
                _dateField(label: 'Date', value: date,
                    onPicked: (d) => setS(() => date = d)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _kGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: () {
                      if (cropName.isEmpty || qty <= 0) return;
                      setState(() {
                        _harvests.add(HarvestRecord(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          plotId: plotId, cropName: cropName,
                          quantityKg: qty, pricePerKg: price,
                          buyerName: buyer, date: date,
                        ));
                      });
                      _saveAll();
                      Navigator.pop(ctx);
                    },
                    child: const Text('Save Harvest'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteHarvest(HarvestRecord h) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Harvest Record?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              setState(() => _harvests.removeWhere((x) => x.id == h.id));
              _saveAll();
              Navigator.pop(context);
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddLoanSheet() {
    String lender = '';
    double principal = 0, rate = 0;
    DateTime taken = DateTime.now();
    DateTime due = DateTime.now().add(const Duration(days: 180));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: false,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Record Loan',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _field(label: 'Lender (e.g. Equity Bank, SACCO)',
                    onChanged: (v) => lender = v),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _field(
                      label: 'Loan Amount (KSH)',
                      keyboardType: TextInputType.number,
                      onChanged: (v) => principal = double.tryParse(v) ?? 0)),
                  const SizedBox(width: 10),
                  Expanded(child: _field(
                      label: 'Interest Rate (%)',
                      keyboardType: TextInputType.number,
                      onChanged: (v) => rate = double.tryParse(v) ?? 0)),
                ]),
                const SizedBox(height: 10),
                _dateField(label: 'Date Taken', value: taken,
                    onPicked: (d) => setS(() => taken = d)),
                const SizedBox(height: 10),
                _dateField(label: 'Repayment Due Date', value: due,
                    onPicked: (d) => setS(() => due = d)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _kGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: () {
                      if (lender.isEmpty || principal <= 0) return;
                      setState(() {
                        _loans.add(LoanRecord(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          lenderName: lender, principal: principal,
                          interestRate: rate, takenDate: taken, dueDate: due,
                        ));
                      });
                      _saveAll();
                      Navigator.pop(ctx);
                    },
                    child: const Text('Add Loan'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRepaymentSheet(LoanRecord loan) {
    double payment = 0;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: false,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Repayment – ${loan.lenderName}',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Balance: ${_fmtKSH(loan.balance)}',
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            _field(
                label: 'Payment Amount (KSH)',
                keyboardType: TextInputType.number,
                onChanged: (v) => payment = double.tryParse(v) ?? 0),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _kGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: () {
                  if (payment <= 0 || payment > loan.balance) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Invalid payment amount')));
                    return;
                  }
                  setState(() => loan.amountRepaid += payment);
                  _saveAll();
                  Navigator.pop(context);
                },
                child: const Text('Record Payment'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Form helpers ──────────────────────────────────────────────────────────

  Widget _field({
    required String label,
    String? initial,
    TextInputType keyboardType = TextInputType.text,
    required ValueChanged<String> onChanged,
  }) =>
      TextFormField(
        initialValue: initial,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        onChanged: onChanged,
      );

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    List<String>? displayItems,
    required ValueChanged<String?> onChanged,
  }) =>
      DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        items: List.generate(
          items.length,
          (i) => DropdownMenuItem(
              value: items[i],
              child: Text(
                  displayItems != null ? displayItems[i] : items[i])),
        ),
        onChanged: onChanged,
      );

  Widget _dateField({
    required String label,
    required DateTime value,
    required ValueChanged<DateTime> onPicked,
  }) =>
      GestureDetector(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: value,
            firstDate: DateTime(2020),
            lastDate: DateTime(2035),
          );
          if (picked != null) onPicked(picked);
        },
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 18, color: Colors.grey),
              const SizedBox(width: 10),
              Text(label,
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 13)),
              const Spacer(),
              Text(
                '${value.day} ${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][value.month - 1]} ${value.year}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
}