import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:kilimomkononi/screens/Field%20Data%20Input/plot_summary_tab.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:kilimomkononi/models/field_data_model.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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

class MultiplePlotForm extends PlotInputForm {
  const MultiplePlotForm({
    required super.userId,
    required super.plotId,
    required super.structureType,
    required super.notificationsPlugin,
    required super.onSave,
    super.key,
  });

  @override
  State<MultiplePlotForm> createState() => _MultiplePlotFormState();
}

class IntercropForm extends PlotInputForm {
  const IntercropForm({
    required super.userId,
    required super.plotId,
    required super.structureType,
    required super.notificationsPlugin,
    required super.onSave,
    super.key,
  });

  @override
  State<IntercropForm> createState() => _IntercropFormState();
}

class SingleCropForm extends PlotInputForm {
  const SingleCropForm({
    required super.userId,
    required super.plotId,
    required super.structureType,
    required super.notificationsPlugin,
    required super.onSave,
    super.key,
  });

  @override
  State<SingleCropForm> createState() => _SingleCropFormState();
}

class _PlotInputFormState<T extends PlotInputForm> extends State<T> {
  final _formKey = GlobalKey<FormState>();
  bool _useAcres = true;
  List<Map<String, String>> _crops = [{'type': '', 'stage': ''}];
  List<TextEditingController> _cropControllers = [TextEditingController()];
  List<TextEditingController> _stageControllers = [TextEditingController()];
  final _areaController = TextEditingController();
  final _nitrogenController = TextEditingController();
  final _phosphorusController = TextEditingController();
  final _potassiumController = TextEditingController();
  List<String> _microNutrients = [];
  List<TextEditingController> _microNutrientControllers = [TextEditingController()];
  final List<Map<String, dynamic>> _interventions = [];
  final List<Map<String, dynamic>> _reminders = [];
  final Map<String, String> _nutrientStatus = {};
  String _fertilizerRecommendation = '';

  static const List<String> _acreFractions = [
    '1/10 Acre', '1/9 Acre', '1/8 Acre', '1/7 Acre', '1/6 Acre', '1/5 Acre', '1/4 Acre', 
    '2/7 Acre', '1/3 Acre', '2/5 Acre', '3/7 Acre', '1/2 Acre', '4/7 Acre', '3/5 Acre', 
    '2/3 Acre', '5/7 Acre', '3/4 Acre', '4/5 Acre', '5/6 Acre', '6/7 Acre', '7/8 Acre', 
    '8/9 Acre', '9/10 Acre', '1 Acre', '1 1/10 Acres', '1 1/9 Acres', '1 1/8 Acres', 
    '1 1/7 Acres', '1 1/6 Acres', '1 1/5 Acres', '1 1/4 Acres', '1 2/7 Acres', '1 1/3 Acres', 
    '1 2/5 Acres', '1 3/7 Acres', '1 1/2 Acres', '1 4/7 Acres', '1 3/5 Acres', '1 2/3 Acres', 
    '1 5/7 Acres', '1 3/4 Acres', '1 4/5 Acres', '1 5/6 Acres', '1 6/7 Acres', '1 7/8 Acres', 
    '1 8/9 Acres', '1 9/10 Acres', '2 Acres', '2 1/10 Acres', '2 1/9 Acres', '2 1/8 Acres', 
    '2 1/7 Acres', '2 1/6 Acres', '2 1/5 Acres', '2 1/4 Acres', '2 2/7 Acres', '2 1/3 Acres', 
    '2 2/5 Acres', '2 3/7 Acres', '2 1/2 Acres', '2 4/7 Acres', '2 3/5 Acres', '2 2/3 Acres', 
    '2 5/7 Acres', '2 3/4 Acres', '2 4/5 Acres', '2 5/6 Acres', '2 6/7 Acres', '2 7/8 Acres', 
    '2 8/9 Acres', '2 9/10 Acres', '3 Acres', '3 1/10 Acres', '3 1/9 Acres', '3 1/8 Acres', 
    '3 1/7 Acres', '3 1/6 Acres', '3 1/5 Acres', '3 1/4 Acres', '3 2/7 Acres', '3 1/3 Acres', 
    '3 2/5 Acres', '3 3/7 Acres', '3 1/2 Acres', '3 4/7 Acres', '3 3/5 Acres', '3 2/3 Acres', 
    '3 5/7 Acres', '3 3/4 Acres', '3 4/5 Acres', '3 5/6 Acres', '3 6/7 Acres', '3 7/8 Acres', 
    '3 8/9 Acres', '3 9/10 Acres', '4 Acres', '4 1/10 Acres', '4 1/9 Acres', '4 1/8 Acres', 
    '4 1/7 Acres', '4 1/6 Acres', '4 1/5 Acres', '4 1/4 Acres', '4 2/7 Acres', '4 1/3 Acres', 
    '4 2/5 Acres', '4 3/7 Acres', '4 1/2 Acres', '4 4/7 Acres', '4 3/5 Acres', '4 2/3 Acres', 
    '4 5/7 Acres', '4 3/4 Acres', '4 4/5 Acres', '4 5/6 Acres', '4 6/7 Acres', '4 7/8 Acres', 
    '4 8/9 Acres', '4 9/10 Acres', '5 Acres', '5 1/10 Acres', '5 1/9 Acres', '5 1/8 Acres', 
    '5 1/7 Acres', '5 1/6 Acres', '5 1/5 Acres', '5 1/4 Acres', '5 2/7 Acres', '5 1/3 Acres', 
    '5 2/5 Acres', '5 3/7 Acres', '5 1/2 Acres', '5 4/7 Acres', '5 3/5 Acres', '5 2/3 Acres', 
    '5 5/7 Acres', '5 3/4 Acres', '5 4/5 Acres', '5 5/6 Acres', '5 6/7 Acres', '5 7/8 Acres', 
    '5 8/9 Acres', '5 9/10 Acres', '6 Acres', '6 1/10 Acres', '6 1/9 Acres', '6 1/8 Acres', 
    '6 1/7 Acres', '6 1/6 Acres', '6 1/5 Acres', '6 1/4 Acres', '6 2/7 Acres', '6 1/3 Acres', 
    '6 2/5 Acres', '6 3/7 Acres', '6 1/2 Acres', '6 4/7 Acres', '6 3/5 Acres', '6 2/3 Acres', 
    '6 5/7 Acres', '6 3/4 Acres', '6 4/5 Acres', '6 5/6 Acres', '6 6/7 Acres', '6 7/8 Acres', 
    '6 8/9 Acres', '6 9/10 Acres', '7 Acres', '7 1/10 Acres', '7 1/9 Acres', '7 1/8 Acres', 
    '7 1/7 Acres', '7 1/6 Acres', '7 1/5 Acres', '7 1/4 Acres', '7 2/7 Acres', '7 1/3 Acres', 
    '7 2/5 Acres', '7 3/7 Acres', '7 1/2 Acres', '7 4/7 Acres', '7 3/5 Acres', '7 2/3 Acres', 
    '7 5/7 Acres', '7 3/4 Acres', '7 4/5 Acres', '7 5/6 Acres', '7 6/7 Acres', '7 7/8 Acres', 
    '7 8/9 Acres', '7 9/10 Acres', '8 Acres', '8 1/10 Acres', '8 1/9 Acres', '8 1/8 Acres', 
    '8 1/7 Acres', '8 1/6 Acres', '8 1/5 Acres', '8 1/4 Acres', '8 2/7 Acres', '8 1/3 Acres', 
    '8 2/5 Acres', '8 3/7 Acres', '8 1/2 Acres', '8 4/7 Acres', '8 3/5 Acres', '8 2/3 Acres', 
    '8 5/7 Acres', '8 3/4 Acres', '8 4/5 Acres', '8 5/6 Acres', '8 6/7 Acres', '8 7/8 Acres', 
    '8 8/9 Acres', '8 9/10 Acres', '9 Acres', '9 1/10 Acres', '9 1/9 Acres', '9 1/8 Acres', 
    '9 1/7 Acres', '9 1/6 Acres', '9 1/5 Acres', '9 1/4 Acres', '9 2/7 Acres', '9 1/3 Acres', 
    '9 2/5 Acres', '9 3/7 Acres', '9 1/2 Acres', '9 4/7 Acres', '9 3/5 Acres', '9 2/3 Acres', 
    '9 5/7 Acres', '9 3/4 Acres', '9 4/5 Acres', '9 5/6 Acres', '9 6/7 Acres', '9 7/8 Acres', 
    '9 8/9 Acres', '9 9/10 Acres', '10 Acres', '10 1/10 Acres', '10 1/9 Acres', '10 1/8 Acres', 
    '10 1/7 Acres', '10 1/6 Acres', '10 1/5 Acres', '10 1/4 Acres', '10 2/7 Acres', '10 1/3 Acres', 
    '10 2/5 Acres', '10 3/7 Acres', '10 1/2 Acres', '10 4/7 Acres', '10 3/5 Acres', '10 2/3 Acres', 
    '10 5/7 Acres', '10 3/4 Acres', '10 4/5 Acres', '10 5/6 Acres', '10 6/7 Acres', '10 7/8 Acres', 
    '10 8/9 Acres', '10 9/10 Acres'
  ];

  static const List<String> _cropTypes = [
    'Beans', 'Maize', 'Tomatoes', 'Cabbages/Kales', 'Carrots',
    'Potatoes', 'Wheat', 'Sugarcane', 'Rice'
  ];

  static const Map<String, List<String>> _cropStages = {
    'Beans': ['Vegetative', 'Flowering', 'Pod Development'],
    'Maize': ['Emergence to V6', 'V6 to VT', 'Reproductive'],
    'Tomatoes': ['Early Growth', 'Flowering and Fruit Set', 'Fruit Development'],
    'Cabbages/Kales': ['Early Growth', 'Leaf Development', 'Head Formation'],
    'Carrots': ['Early Growth', 'Root Expansion', 'Maturation'],
    'Potatoes': ['Early Growth', 'Tuber Initiation', 'Tuber Bulking'],
    'Wheat': ['Early Growth', 'Tillering and Stem Elongation', 'Grain Filling'],
    'Sugarcane': ['Early Growth', 'Grand Growth Phase', 'Maturity'],
    'Rice': ['Early Growth', 'Tillering to Panicle Initiation', 'Grain Filling'],
  };

  static const Map<String, Map<String, Map<String, double>>> _optimalNpk = {
    'Beans': {
      'Vegetative': {'N': 28, 'P': 45, 'K': 56},
      'Flowering': {'N': 28, 'P': 0, 'K': 56},
      'Pod Development': {'N': 28, 'P': 0, 'K': 56},
    },
    'Maize': {
      'Emergence to V6': {'N': 45, 'P': 28, 'K': 56},
      'V6 to VT': {'N': 84, 'P': 28, 'K': 56},
      'Reproductive': {'N': 0, 'P': 0, 'K': 28},
    },
    'Tomatoes': {
      'Early Growth': {'N': 67, 'P': 78, 'K': 101},
      'Flowering and Fruit Set': {'N': 0, 'P': 78, 'K': 101},
      'Fruit Development': {'N': 0, 'P': 0, 'K': 56},
    },
    'Cabbages/Kales': {
      'Early Growth': {'N': 65, 'P': 70, 'K': 90},
      'Leaf Development': {'N': 0, 'P': 70, 'K': 90},
      'Head Formation': {'N': 0, 'P': 0, 'K': 50},
    },
    'Carrots': {
      'Early Growth': {'N': 50, 'P': 65, 'K': 90},
      'Root Expansion': {'N': 0, 'P': 65, 'K': 90},
      'Maturation': {'N': 0, 'P': 0, 'K': 50},
    },
    'Potatoes': {
      'Early Growth': {'N': 62, 'P': 75, 'K': 115},
      'Tuber Initiation': {'N': 0, 'P': 75, 'K': 115},
      'Tuber Bulking': {'N': 0, 'P': 0, 'K': 60},
    },
    'Wheat': {
      'Early Growth': {'N': 55, 'P': 55, 'K': 50},
      'Tillering and Stem Elongation': {'N': 0, 'P': 55, 'K': 50},
      'Grain Filling': {'N': 0, 'P': 0, 'K': 40},
    },
    'Sugarcane': {
      'Early Growth': {'N': 90, 'P': 70, 'K': 105},
      'Grand Growth Phase': {'N': 0, 'P': 70, 'K': 105},
      'Maturity': {'N': 0, 'P': 0, 'K': 60},
    },
    'Rice': {
      'Early Growth': {'N': 50, 'P': 40, 'K': 50},
      'Tillering to Panicle Initiation': {'N': 0, 'P': 40, 'K': 50},
      'Grain Filling': {'N': 0, 'P': 0, 'K': 40},
    },
  };

  static const Map<String, Map<String, String>> _fertilizerRecommendations = {
    'Beans': {
      'Vegetative': 'Triple Superphosphate (0-46-0) or DAP (18-46-0)',
      'Flowering': 'Muriate of Potash (0-0-60), Urea (46-0-0)',
      'Pod Development': 'Muriate of Potash (0-0-60), Urea (46-0-0)',
    },
    'Maize': {
      'Emergence to V6': 'Urea (46-0-0) or Ammonium Nitrate (34-0-0)',
      'V6 to VT': 'NPK 20-20-20 or 10-20-20',
      'Reproductive': 'Muriate of Potash (0-0-60)',
    },
    'Tomatoes': {
      'Early Growth': 'Urea (46-0-0) or Ammonium Sulfate (21-0-0)',
      'Flowering and Fruit Set': 'NPK 10-20-20 or 12-24-12',
      'Fruit Development': 'Muriate of Potash (0-0-60)',
    },
    'Cabbages/Kales': {
      'Early Growth': 'Urea (46-0-0) or Ammonium Sulfate (21-0-0)',
      'Leaf Development': 'NPK 10-20-20 or 14-28-14',
      'Head Formation': 'Muriate of Potash (0-0-60)',
    },
    'Carrots': {
      'Early Growth': 'Ammonium Nitrate (34-0-0) or Ammonium Sulfate (21-0-0)',
      'Root Expansion': 'NPK 10-20-20 or 14-28-14',
      'Maturation': 'Muriate of Potash (0-0-60)',
    },
    'Potatoes': {
      'Early Growth': 'Urea (46-0-0) or Ammonium Nitrate (34-0-0)',
      'Tuber Initiation': 'NPK 10-20-20 or 14-28-14',
      'Tuber Bulking': 'Muriate of Potash (0-0-60)',
    },
    'Wheat': {
      'Early Growth': 'Urea (46-0-0) or Ammonium Sulfate (21-0-0)',
      'Tillering and Stem Elongation': 'NPK 18-46-0 (DAP) or 12-24-12',
      'Grain Filling': 'Muriate of Potash (0-0-60)',
    },
    'Sugarcane': {
      'Early Growth': 'Urea (46-0-0) or Ammonium Sulfate (21-0-0)',
      'Grand Growth Phase': 'NPK 14-28-14 or 12-24-12',
      'Maturity': 'Muriate of Potash (0-0-60)',
    },
    'Rice': {
      'Early Growth': 'Urea (46-0-0) or Ammonium Sulfate (21-0-0)',
      'Tillering to Panicle Initiation': 'NPK 16-20-0 or 10-26-26',
      'Grain Filling': 'Muriate of Potash (0-0-60)',
    },
  };

  @override
  void initState() {
    super.initState();
    if (widget.structureType == 'intercrop') {
      _crops = [{'type': '', 'stage': ''}, {'type': '', 'stage': ''}];
      _cropControllers = [TextEditingController(), TextEditingController()];
      _stageControllers = [TextEditingController(), TextEditingController()];
    }
  }

  Future<void> _saveForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      _microNutrients = _microNutrientControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      for (int i = 0; i < _crops.length; i++) {
        _crops[i]['type'] = _cropControllers[i].text;
        _crops[i]['stage'] = _stageControllers[i].text;
      }
      _crops = _crops.where((crop) => crop['type']!.isNotEmpty).toList();

      double? areaInAcres;
      if (_areaController.text.isNotEmpty) {
        if (_useAcres) {
          final text = _areaController.text;
          if (_acreFractions.contains(text)) {
            areaInAcres = _convertFractionToAcres(text);
          } else {
            areaInAcres = double.tryParse(text);
          }
        } else {
          areaInAcres = double.parse(_areaController.text) / 4046.86;
        }
      }

      final fieldData = FieldData(
        userId: widget.userId,
        plotId: widget.plotId,
        crops: _crops,
        area: areaInAcres,
        npk: {
          'N': _nitrogenController.text.isNotEmpty
              ? double.parse(_nitrogenController.text)
              : null,
          'P': _phosphorusController.text.isNotEmpty
              ? double.parse(_phosphorusController.text)
              : null,
          'K': _potassiumController.text.isNotEmpty
              ? double.parse(_potassiumController.text)
              : null,
        },
        microNutrients: _microNutrients,
        interventions: _interventions,
        reminders: _reminders,
        timestamp: Timestamp.now(),
        structureType: widget.structureType,
        fertilizerRecommendation: _fertilizerRecommendation,
      );

      try {
        await FirebaseFirestore.instance
            .collection('fielddata')
            .doc('${widget.userId}_${fieldData.timestamp.millisecondsSinceEpoch}')
            .set(fieldData.toMap());
        widget.onSave();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Data saved successfully')));
          _resetForm();
        }
      } catch (e) {
        if (mounted) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
              'offline_fielddata_${widget.userId}_${fieldData.timestamp.millisecondsSinceEpoch}',
              jsonEncode(fieldData.toMap()));
          if (mounted) { 
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Saved offline, will sync when online')));
            _resetForm();
          }
        }
      }
    }
  }

  void _resetForm() {
    setState(() {
      _areaController.clear();
      _nitrogenController.clear();
      _phosphorusController.clear();
      _potassiumController.clear();
      _microNutrients.clear();
      _microNutrientControllers = [TextEditingController()];
      _interventions.clear();
      _reminders.clear();
      _nutrientStatus.clear();
      _fertilizerRecommendation = '';
      if (widget.structureType == 'intercrop') {
        _crops = [{'type': '', 'stage': ''}, {'type': '', 'stage': ''}];
        _cropControllers = [TextEditingController(), TextEditingController()];
        _stageControllers = [TextEditingController(), TextEditingController()];
      } else {
        _crops = [{'type': '', 'stage': ''}];
        _cropControllers = [TextEditingController()];
        _stageControllers = [TextEditingController()];
      }
    });
  }

  double _convertFractionToAcres(String fraction) {
    if (fraction.contains('Acre')) {
      final parts = fraction.split(' ');
      if (parts.length == 1) return 1.0;
      if (parts[0].contains('/')) {
        final frac = parts[0].split('/');
        return double.parse(frac[0]) / double.parse(frac[1]);
      }
      return double.parse(parts[0]);
    }
    return double.parse(fraction);
  }

  Future<void> _scheduleReminder(DateTime date, String activity) async {
    const androidDetails = AndroidNotificationDetails(
      'field_data_channel',
      'Field Data Reminders',
      channelDescription: 'Reminders for field activities',
      importance: Importance.max,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);
    final tzDateTime = tz.TZDateTime.from(date, tz.local);
    final tzDayBefore =
        tz.TZDateTime.from(date.subtract(const Duration(days: 1)), tz.local);

    try {
      await widget.notificationsPlugin.zonedSchedule(
        (widget.userId + widget.plotId + date.toString()).hashCode,
        'Reminder for ${widget.plotId}',
        activity,
        tzDateTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        // Removed uiLocalNotificationDateInterpretation as it is not defined
      );
      await widget.notificationsPlugin.zonedSchedule(
        ('${widget.userId}${widget.plotId}${date}dayBefore').hashCode,
        'Upcoming Reminder for ${widget.plotId}',
        'Reminder: $activity is due tomorrow!',
        tzDayBefore,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        // Removed uiLocalNotificationDateInterpretation as it is not defined
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reminders scheduled successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error scheduling reminder: $e')));
      }
    }
  }

  void _updateNutrientStatus(String crop, String stage) {
    final optimal = _optimalNpk[crop]?[stage] ?? {'N': 0.0, 'P': 0.0, 'K': 0.0};
    final fertilizer = _fertilizerRecommendations[crop]?[stage] ?? '';

    setState(() {
      _nutrientStatus.clear();
      _fertilizerRecommendation = fertilizer;
      final n = _nitrogenController.text.isNotEmpty
          ? double.parse(_nitrogenController.text)
          : 0;
      final p = _phosphorusController.text.isNotEmpty
          ? double.parse(_phosphorusController.text)
          : 0;
      final k = _potassiumController.text.isNotEmpty
          ? double.parse(_potassiumController.text)
          : 0;

      _nutrientStatus['N'] =
          n < optimal['N']! ? 'Low' : n > optimal['N']! ? 'High' : 'Optimal';
      _nutrientStatus['P'] =
          p < optimal['P']! ? 'Low' : p > optimal['P']! ? 'High' : 'Optimal';
      _nutrientStatus['K'] =
          k < optimal['K']! ? 'Low' : k > optimal['K']! ? 'High' : 'Optimal';
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Crop',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._crops.asMap().entries.map((entry) {
              final idx = entry.key;
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildCropTypeField(idx)),
                      if (widget.structureType == 'intercrop' && idx >= 2)
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _crops.removeAt(idx);
                              _cropControllers.removeAt(idx);
                              _stageControllers.removeAt(idx);
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildCropStageField(idx),
                  const SizedBox(height: 8),
                ],
              );
            }),
            if (widget.structureType == 'intercrop')
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _crops.add({'type': '', 'stage': ''});
                    _cropControllers.add(TextEditingController());
                    _stageControllers.add(TextEditingController());
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 3, 39, 4),
                  foregroundColor: Colors.white,
                ),
                child: const Text('+ Additional Crop'),
              ),
            if (widget.structureType == 'single' && _crops.length > 1)
              const Text(
                'Note: Single Crop structure allows only one crop.',
                style: TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 16),

            const Text('Plot Area',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _useAcres
                ? Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      return _acreFractions.where((option) => option
                          .toLowerCase()
                          .contains(textEditingValue.text.toLowerCase()));
                    },
                    onSelected: (String selection) =>
                        _areaController.text = selection,
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) {
                      _areaController.text = controller.text;
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: _inputDecoration('Area (Acres)'),
                        keyboardType: TextInputType.text,
                        validator: (value) =>
                            value != null && value.isNotEmpty && !_acreFractions.contains(value) && double.tryParse(value) == null
                                ? 'Enter a valid number or fraction'
                                : null,
                      );
                    },
                  )
                : TextFormField(
                    controller: _areaController,
                    decoration: _inputDecoration('Area (SQM)'),
                    keyboardType: TextInputType.number,
                    validator: (value) => value != null && value.isNotEmpty && double.tryParse(value) == null
                        ? 'Enter a valid number'
                        : null,
                  ),
            SwitchListTile(
              title: const Text('Use Acres'),
              value: _useAcres,
              onChanged: (value) => setState(() => _useAcres = value),
              activeColor: Colors.green[300],
            ),
            const SizedBox(height: 16),

            const Text('Soil Nutrient Levels',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._buildNutrientFields(),
            const SizedBox(height: 16),

            const Text('Nutrient Analysis & Recommendations',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_nutrientStatus.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('N Status: ${_nutrientStatus['N']}',
                      style: TextStyle(
                          color: _nutrientStatus['N'] == 'Low'
                              ? Colors.red
                              : _nutrientStatus['N'] == 'High'
                                  ? Colors.orange
                                  : Colors.green)),
                  Text('P Status: ${_nutrientStatus['P']}',
                      style: TextStyle(
                          color: _nutrientStatus['P'] == 'Low'
                              ? Colors.red
                              : _nutrientStatus['P'] == 'High'
                                  ? Colors.orange
                                  : Colors.green)),
                  Text('K Status: ${_nutrientStatus['K']}',
                      style: TextStyle(
                          color: _nutrientStatus['K'] == 'Low'
                              ? Colors.red
                              : _nutrientStatus['K'] == 'High'
                                  ? Colors.orange
                                  : Colors.green)),
                  if (_fertilizerRecommendation.isNotEmpty)
                    Text('Recommended Fertilizer: $_fertilizerRecommendation',
                        style: const TextStyle(color: Colors.blue)),
                ],
              ),
            const SizedBox(height: 16),

            const Text('Micro-Nutrients',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._microNutrientControllers.map((controller) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: TextFormField(
                    controller: controller,
                    decoration: _inputDecoration('Micro-Nutrient'),
                    onFieldSubmitted: (value) {
                      if (value.isNotEmpty && !_microNutrients.contains(value)) {
                        setState(() => _microNutrients.add(value));
                      }
                    },
                  ),
                )),
            ElevatedButton(
              onPressed: () =>
                  setState(() => _microNutrientControllers.add(TextEditingController())),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 3, 39, 4),
                foregroundColor: Colors.white,
              ),
              child: const Text('Add Another Micro-Nutrient'),
            ),
            Wrap(
              spacing: 8,
              children: _microNutrients
                  .map((m) => Chip(
                        label: Text(m),
                        onDeleted: () => setState(() => _microNutrients.remove(m)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),

            const Text('Interventions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                final intervention = await _showInterventionDialog();
                if (intervention != null) {
                  setState(() => _interventions.add(intervention));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 3, 39, 4),
                foregroundColor: Colors.white,
              ),
              child: const Text('Add Intervention'),
            ),
            ..._interventions.map((i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text('${i['type']} - ${i['quantity']} ${i['unit']}'),
                    subtitle:
                        Text((i['date'] as Timestamp).toDate().toString().substring(0, 10)),
                  ),
                )),
            const SizedBox(height: 16),

            const Text('Reminders',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                final reminder = await _showReminderDialog();
                if (reminder != null) {
                  setState(() => _reminders.add(reminder));
                  await _scheduleReminder(reminder['date'].toDate(), reminder['activity']);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 3, 39, 4),
                foregroundColor: Colors.white,
              ),
              child: const Text('Add Reminder'),
            ),
            ..._reminders.map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text(r['activity']),
                    subtitle: Text(r['date'].toDate().toString().substring(0, 10)),
                  ),
                )),
            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _saveForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 3, 39, 4),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Save New Entry', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          PlotSummaryTab(userId: widget.userId),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 3, 39, 4),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('View Summary'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCropTypeField(int index) {
    return DropdownButtonFormField<String>(
      value: _cropControllers[index].text.isEmpty
          ? null
          : _cropControllers[index].text,
      decoration: _inputDecoration('Crop Type'),
      items: _cropTypes.map((crop) => DropdownMenuItem(value: crop, child: Text(crop))).toList(),
      onChanged: (value) {
        setState(() {
          _cropControllers[index].text = value ?? '';
          _crops[index]['type'] = value ?? '';
          _stageControllers[index].clear();
          _crops[index]['stage'] = '';
          if (_cropTypes.contains(value) &&
              _cropStages[value]!.contains(_crops[index]['stage'])) {
            _updateNutrientStatus(value!, _crops[index]['stage']!);
          } else {
            _nutrientStatus.clear();
            _fertilizerRecommendation = '';
          }
        });
      },
      isExpanded: true,
      validator: (value) => widget.structureType == 'intercrop' && index < 2 && (value == null || value.isEmpty)
          ? 'Required for Intercrop'
          : null,
    );
  }

  Widget _buildCropStageField(int index) {
    final crop = _crops[index]['type']!;
    final stages = _cropStages[crop] ?? ['Custom'];

    return DropdownButtonFormField<String>(
      value: _stageControllers[index].text.isEmpty
          ? null
          : _stageControllers[index].text,
      decoration: _inputDecoration('Crop Stage'),
      items: stages.map((stage) => DropdownMenuItem(value: stage, child: Text(stage))).toList(),
      onChanged: (value) {
        setState(() {
          _stageControllers[index].text = value ?? '';
          _crops[index]['stage'] = value ?? '';
          if (_cropTypes.contains(crop) && stages.contains(value)) {
            _updateNutrientStatus(crop, value!);
          } else {
            _nutrientStatus.clear();
            _fertilizerRecommendation = '';
          }
        });
      },
      isExpanded: true,
    );
  }

  List<Widget> _buildNutrientFields() {
    final crop =
        _crops.isNotEmpty && _crops[0]['type']!.isNotEmpty ? _crops[0]['type'] : '';
    final stage =
        _crops.isNotEmpty && _crops[0]['stage']!.isNotEmpty ? _crops[0]['stage'] : '';
    final optimal = _optimalNpk[crop]?[stage] ?? {'N': 0.0, 'P': 0.0, 'K': 0.0};

    return [
      Row(
        children: [
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: _nitrogenController,
              decoration: _inputDecoration('Nitrogen (N)'),
              keyboardType: TextInputType.number,
              validator: (v) => v != null && v.isNotEmpty && double.tryParse(v) == null
                  ? 'Enter a valid number'
                  : null,
              onChanged: (_) => _updateNutrientStatus(crop!, stage!),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Text('Optimal: ${optimal['N']}',
                style: const TextStyle(fontSize: 14, color: Colors.black54)),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: _phosphorusController,
              decoration: _inputDecoration('Phosphorus (P)'),
              keyboardType: TextInputType.number,
              validator: (v) => v != null && v.isNotEmpty && double.tryParse(v) == null
                  ? 'Enter a valid number'
                  : null,
              onChanged: (_) => _updateNutrientStatus(crop!, stage!),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Text('Optimal: ${optimal['P']}',
                style: const TextStyle(fontSize: 14, color: Colors.black54)),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: _potassiumController,
              decoration: _inputDecoration('Potassium (K)'),
              keyboardType: TextInputType.number,
              validator: (v) => v != null && v.isNotEmpty && double.tryParse(v) == null
                  ? 'Enter a valid number'
                  : null,
              onChanged: (_) => _updateNutrientStatus(crop!, stage!),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Text('Optimal: ${optimal['K']}',
                style: const TextStyle(fontSize: 14, color: Colors.black54)),
          ),
        ],
      ),
    ];
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
        focusedBorder:
            const OutlineInputBorder(borderSide: BorderSide(color: Colors.green)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      );

  Future<Map<String, dynamic>?> _showInterventionDialog() async {
    String? type;
    String? quantityText;
    String? unit;
    DateTime? date = DateTime.now();
    final quantityController = TextEditingController();
    final unitController = TextEditingController();

    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Intervention'),
        content: StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: _inputDecoration('Intervention Type'),
                  onChanged: (value) => type = value,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: quantityController,
                  decoration: _inputDecoration('Quantity'),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => quantityText = value,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: unitController,
                  decoration: _inputDecoration('Unit'),
                  onChanged: (value) => unit = value,
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: Text('Date: ${date!.toString().substring(0, 10)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date!,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setState(() => date = picked);
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final quantity = quantityText != null && quantityText!.isNotEmpty
                  ? double.tryParse(quantityText!)
                  : null;
              if (type != null && type!.isNotEmpty) {
                Navigator.pop(context, {
                  'type': type,
                  'quantity': quantity,
                  'unit': unit,
                  'date': Timestamp.fromDate(date!),
                });
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _showReminderDialog() async {
    DateTime? date = DateTime.now().add(const Duration(days: 7));
    String? activity;
    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Reminder'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: _inputDecoration('Activity'),
                onChanged: (v) => activity = v,
              ),
              const SizedBox(height: 8),
              ListTile(
                title: Text('Date: ${date!.toString().substring(0, 10)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date!,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null && mounted) setState(() => date = picked);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, {
                  'date': Timestamp.fromDate(date!),
                  'activity': activity,
                }),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _MultiplePlotFormState extends _PlotInputFormState<MultiplePlotForm> {}

class _IntercropFormState extends _PlotInputFormState<IntercropForm> {}

class _SingleCropFormState extends _PlotInputFormState<SingleCropForm> {
  @override
  void initState() {
    super.initState();
    _crops = [{'type': '', 'stage': ''}];
    _cropControllers = [TextEditingController()];
    _stageControllers = [TextEditingController()];
  }
}