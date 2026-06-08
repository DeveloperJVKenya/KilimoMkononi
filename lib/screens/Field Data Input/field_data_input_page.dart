import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:kilimomkononi/screens/Field%20Data%20Input/plot_input_form.dart';
import 'package:kilimomkononi/screens/Field%20Data%20Input/plot_summary_tab.dart';

class FieldDataInputPage extends StatefulWidget {
  final String structureType;
  const FieldDataInputPage({required this.structureType, super.key});

  @override
  State<FieldDataInputPage> createState() => _FieldDataInputPageState();
}

class _FieldDataInputPageState extends State<FieldDataInputPage>
    with SingleTickerProviderStateMixin {
  static const _darkGreen = Color.fromARGB(255, 3, 39, 4);

  late String _farmingScenario;
  late List<String> _plotIds;
  late TabController _tabController;
  late FlutterLocalNotificationsPlugin _notificationsPlugin;
  final Map<String, bool> _plotHasData = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();
    _initializeNotifications();
    _farmingScenario = widget.structureType;
    _plotIds = _farmingScenario == 'multiple'
        ? ['Plot 1']
        : [_farmingScenario == 'intercrop' ? 'Intercrop' : 'SingleCrop'];
    _tabController = TabController(length: _plotIds.length, vsync: this);
    _checkPlotDataStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeNotifications() async {
    try {
      _notificationsPlugin = FlutterLocalNotificationsPlugin();
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);
      await _notificationsPlugin.initialize(settings: initSettings);
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final granted =
            await androidPlugin.requestNotificationsPermission();
        if (granted != true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Notification permissions denied. Reminders may not work.')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to initialise notifications.')),
        );
      }
    }
  }

  Future<void> _checkPlotDataStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final userId = FirebaseAuth.instance.currentUser!.uid;
    try {
      for (final plotId in _plotIds) {
        final snap = await FirebaseFirestore.instance
            .collection('fielddata')
            .where('userId', isEqualTo: userId)
            .where('plotId', isEqualTo: plotId)
            .get();
        if (mounted) setState(() => _plotHasData[plotId] = snap.docs.isNotEmpty);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage =
            'Failed to load plot data. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showRedefineDialog() async {
    int? plotCount;
    String? plotLabelPrefix;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        title: const Text(
          'Redefine plots',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _darkGreen),
        ),
        content: StatefulBuilder(
          builder: (ctx, setState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(
                  label: 'Number of plots',
                  keyboardType: TextInputType.number,
                  onChanged: (v) => plotCount = int.tryParse(v),
                ),
                const SizedBox(height: 12),
                _dialogField(
                  label: 'Plot label prefix (e.g. "Field")',
                  onChanged: (v) =>
                      plotLabelPrefix = v.isNotEmpty ? v : 'Plot',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.black54)),
          ),
          TextButton(
            onPressed: () {
              if (plotCount != null && plotCount! > 0) {
                if (mounted) {
                  setState(() {
                    _plotIds = List.generate(
                        plotCount!,
                        (i) =>
                            '${plotLabelPrefix ?? 'Plot'} ${i + 1}');
                    _tabController.dispose();
                    _tabController =
                        TabController(length: _plotIds.length, vsync: this);
                  });
                  Navigator.pop(dialogContext, true);
                  _checkPlotDataStatus();
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                          Text('Please enter a valid number of plots')),
                );
              }
            },
            child: const Text('Apply',
                style: TextStyle(color: _darkGreen, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (result != true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Structure not changed')),
      );
    }
  }

  Widget _dialogField({
    required String label,
    TextInputType keyboardType = TextInputType.text,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Future<void> _deletePlot(String plotId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Remove plot'),
        content: Text('Remove "$plotId" from this session?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true && mounted) {
      setState(() {
        _plotIds.remove(plotId);
        _plotHasData.remove(plotId);
        _tabController.dispose();
        _tabController =
            TabController(length: _plotIds.length, vsync: this);
      });
    }
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PlotSummaryTab(userId: FirebaseAuth.instance.currentUser!.uid),
      ),
    );
  }

  Widget _buildPlotForm(String plotId) {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    switch (_farmingScenario) {
      case 'multiple':
        return MultiplePlotForm(
          userId: userId,
          plotId: plotId,
          structureType: _farmingScenario,
          notificationsPlugin: _notificationsPlugin,
          onSave: _checkPlotDataStatus,
        );
      case 'intercrop':
        return IntercropForm(
          userId: userId,
          plotId: plotId,
          structureType: _farmingScenario,
          notificationsPlugin: _notificationsPlugin,
          onSave: _checkPlotDataStatus,
        );
      default:
        return SingleCropForm(
          userId: userId,
          plotId: plotId,
          structureType: _farmingScenario,
          notificationsPlugin: _notificationsPlugin,
          onSave: _checkPlotDataStatus,
        );
    }
  }

  String get _pageTitle {
    switch (_farmingScenario) {
      case 'multiple':
        return 'Multiple plots';
      case 'intercrop':
        return 'Intercropping';
      default:
        return 'Single crop';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F3),
      appBar: AppBar(
        backgroundColor: _darkGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _pageTitle,
          style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.white),
            tooltip: 'View history',
            onPressed: _openHistory,
          ),
        ],
        bottom: _plotIds.length > 1
            ? PreferredSize(
                preferredSize: const Size.fromHeight(42),
                child: Container(
                  color: const Color(0xFF1A3D1A),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    indicatorColor: const Color(0xFF6AB04C),
                    indicatorWeight: 2.5,
                    labelStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                    tabs: _plotIds
                        .map((id) => Tab(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(id),
                                  if (_plotHasData[id] == true)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 4),
                                      child: Icon(Icons.check_circle,
                                          size: 12,
                                          color: Color(0xFF6AB04C)),
                                    ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_off_rounded,
                            size: 48, color: Colors.black26),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 14, color: Colors.black54),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _checkPlotDataStatus,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: _darkGreen,
                              foregroundColor: Colors.white),
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: _plotIds.isEmpty
                          ? const Center(child: Text('No plots defined.'))
                          : _plotIds.length == 1
                              ? _buildPlotForm(_plotIds.first)
                              : TabBarView(
                                  controller: _tabController,
                                  children: _plotIds
                                      .map((id) => _buildPlotForm(id))
                                      .toList(),
                                ),
                    ),
                    // Bottom action bar for multiple plots
                    if (_farmingScenario == 'multiple')
                      SafeArea(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(
                                top: BorderSide(
                                    color: Color(0xFFE0E0E0))),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _showRedefineDialog,
                                  icon: const Icon(Icons.edit_rounded, size: 16),
                                  label: const Text('Redefine'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _darkGreen,
                                    side: const BorderSide(
                                        color: Color(0xFFA5D6A7)),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 11),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _deletePlot(
                                      _plotIds[_tabController.index]),
                                  icon: const Icon(Icons.delete_outline,
                                      size: 16),
                                  label: const Text('Remove plot'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red[50],
                                    foregroundColor: Colors.red[700],
                                    elevation: 0,
                                    side: BorderSide(
                                        color: Colors.red[200]!),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 11),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}