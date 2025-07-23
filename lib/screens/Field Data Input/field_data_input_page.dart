import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:kilimomkononi/screens/Field%20Data%20Input/plot_input_form.dart';
import 'package:kilimomkononi/screens/Field%20Data%20Input/plot_summary_tab.dart';

enum PageState { dataLoaded }

class FieldDataInputPage extends StatefulWidget {
  final String structureType;

  const FieldDataInputPage({required this.structureType, super.key});

  @override
  State<FieldDataInputPage> createState() => _FieldDataInputPageState();
}

class _FieldDataInputPageState extends State<FieldDataInputPage>
    with SingleTickerProviderStateMixin {
  late String _farmingScenario;
  late List<String> _plotIds;
  late TabController _tabController;
  late FlutterLocalNotificationsPlugin _notificationsPlugin;
  final Map<String, bool> _plotHasData = {};
  bool _isLoading = true; // Track initial data loading
  String? _errorMessage; // Store error message for display

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
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);
      await _notificationsPlugin.initialize(initSettings);
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        if (granted != true && mounted) { 
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notification permissions denied. Reminders may not work.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to initialize notifications.')),
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
      for (var plotId in _plotIds) {
        final snapshot = await FirebaseFirestore.instance
            .collection('fielddata')
            .where('userId', isEqualTo: userId)
            .where('plotId', isEqualTo: plotId)
            .get();
        if (mounted) {
          setState(() {
            _plotHasData[plotId] = snapshot.docs.isNotEmpty;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load plot data. Please try again later.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showOnboardingDialog() async {
    int? plotCount;
    String? plotLabelPrefix;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Text(
          'Redefine Your Farming Structure',
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(255, 3, 39, 4)),
        ),
        content: StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_farmingScenario == 'multiple') ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Number of Plots',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => plotCount = int.tryParse(value),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Plot Label Prefix',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (value) =>
                        plotLabelPrefix = value.isNotEmpty ? value : 'Plot',
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (_farmingScenario != 'multiple' ||
                  (plotCount != null && plotCount! > 0)) {
                if (mounted) {
                  setState(() {
                    if (_farmingScenario == 'multiple') {
                      _plotIds = List.generate(
                        plotCount!,
                        (i) => '${plotLabelPrefix ?? 'Plot'} ${i + 1}',
                      );
                      _tabController.dispose();
                      _tabController = TabController(length: _plotIds.length, vsync: this);
                    }
                  });
                  Navigator.pop(dialogContext, true);
                  _checkPlotDataStatus(); // Re-check data after redefining
                }
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid number of plots')),
                );
              }
            },
            child: const Text('OK', style: TextStyle(color: Color.fromARGB(255, 3, 39, 4))),
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

  Future<void> _deletePlot(String plotId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete $plotId?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() {
        _plotIds.remove(plotId);
        _plotHasData.remove(plotId);
        _tabController.dispose();
        _tabController = TabController(length: _plotIds.length, vsync: this);
      });
    }
  }

  void _showFieldHistory() {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlotSummaryTab(userId: FirebaseAuth.instance.currentUser!.uid),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to show history. Please try again.')),
        );
      }
    }
  }

  Widget _buildPlotInputForm(String plotId) {
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
      case 'single':
        return SingleCropForm(
          userId: userId,
          plotId: plotId,
          structureType: _farmingScenario,
          notificationsPlugin: _notificationsPlugin,
          onSave: _checkPlotDataStatus,
        );
      default:
        throw Exception('Unknown farming scenario: $_farmingScenario');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _plotIds.length,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color.fromARGB(255, 3, 39, 4),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Field Data Input',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _errorMessage!,
                          style: const TextStyle(fontSize: 16, color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _checkPlotDataStatus,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      if (_plotIds.isNotEmpty)
                        Container(
                          color: const Color.fromARGB(255, 240, 244, 243),
                          child: TabBar(
                            controller: _tabController,
                            isScrollable: true,
                            labelColor: Colors.black,
                            unselectedLabelColor: Colors.black54,
                            indicatorColor: const Color.fromRGBO(67, 145, 67, 1),
                            tabs: _plotIds.map((plotId) => Tab(text: plotId)).toList(),
                          ),
                        ),
                      Expanded(
                        child: _plotIds.isEmpty
                            ? const Center(child: Text('No plots defined yet.'))
                            : TabBarView(
                                controller: _tabController,
                                children: _plotIds
                                    .map((plotId) => _buildPlotInputForm(plotId))
                                    .toList(),
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            if (_farmingScenario == 'multiple')
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: ElevatedButton(
                                    onPressed: _showOnboardingDialog,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color.fromARGB(255, 3, 39, 4),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: const Text('Redefine Structure',
                                        style: TextStyle(fontSize: 16)),
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: ElevatedButton(
                                  onPressed: _showFieldHistory,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color.fromARGB(255, 3, 39, 4),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Retrieve History',
                                      style: TextStyle(fontSize: 16)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
        floatingActionButton: _farmingScenario == 'multiple' &&
                _plotHasData.values.every((hasData) => !hasData)
            ? FloatingActionButton(
                onPressed: () => _deletePlot(_plotIds[_tabController.index]),
                backgroundColor: Colors.red,
                child: const Icon(Icons.delete),
              )
            : null,
      ),
    );
  }
}