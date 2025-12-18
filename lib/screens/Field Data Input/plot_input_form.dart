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
  bool _isOrganic = false;
  List<Map<String, String>> _crops = [{'type': '', 'stage': ''}];
  List<TextEditingController> _cropControllers = [TextEditingController()];
  List<TextEditingController> _stageControllers = [TextEditingController()];
  final _areaController = TextEditingController();
  final _nitrogenController = TextEditingController();
  final _phosphorusController = TextEditingController();
  final _potassiumController = TextEditingController();
  List<Map<String, dynamic>> _microNutrients = [{'name': '', 'level': 0.0, 'status': '', 'optimal': 0.0}];
  List<TextEditingController> _microNameControllers = [TextEditingController()];
  List<TextEditingController> _microLevelControllers = [TextEditingController()];
  final List<Map<String, dynamic>> _interventions = [];
  final List<Map<String, dynamic>> _reminders = [];
  final Map<String, String> _nutrientStatus = {'N': '', 'P': '', 'K': ''};
  Map<String, double> _optimalAverages = {'N': 0.0, 'P': 0.0, 'K': 0.0};
  String _fertilizerRecommendation = '';

  static const List<String> _acreFractions = [
    '1/10 Acre', '1/9 Acre', '1/8 Acre', '1/7 Acre', '1/6 Acre', '1/5 Acre', '1/4 Acre',
    '1/3 Acre', '1/2 Acre', '3/4 Acre', '1 Acre', '1 1/4 Acres', '1 1/2 Acres', '1 3/4 Acres',
    '2 Acres', '2 1/4 Acres', '2 1/2 Acres', '2 3/4 Acres', '3 Acres', '3 1/4 Acres',
    '3 1/2 Acres', '3 3/4 Acres', '4 Acres', '4 1/4 Acres', '4 1/2 Acres', '4 3/4 Acres',
    '5 Acres', '5 1/4 Acres', '5 1/2 Acres', '5 3/4 Acres', '6 Acres', '6 1/4 Acres',
    '6 1/2 Acres', '6 3/4 Acres', '7 Acres', '7 1/4 Acres', '7 1/2 Acres', '7 3/4 Acres',
    '8 Acres', '8 1/4 Acres', '8 1/2 Acres', '8 3/4 Acres', '9 Acres', '9 1/4 Acres',
    '9 1/2 Acres', '9 3/4 Acres', '10 Acres', '10 1/4 Acres', '10 1/2 Acres', '10 3/4 Acres',
    '10 9/10 Acres'
  ];

  static const List<String> _cropTypes = [
    'Beans', 'Maize', 'Tomatoes', 'Cabbages/Kales', 'Carrots',
    'Irish Potatoes', 'Wheat', 'Sugarcane', 'Rice', 'Onions'
  ];

  static const Map<String, List<String>> _cropStages = {
    'Beans': ['Vegetative', 'Flowering', 'Pod Development'],
    'Maize': ['Emergence to V6', 'V6 to VT', 'Reproductive'],
    'Tomatoes': ['Early Growth', 'Flowering and Fruit Set', 'Fruit Development'],
    'Cabbages/Kales': ['Early Growth', 'Leaf Development', 'Head Formation'],
    'Carrots': ['Early Growth', 'Root Expansion', 'Maturation'],
    'Irish Potatoes': ['Early Growth', 'Tuber Initiation', 'Tuber Bulking'],
    'Wheat': ['Early Growth', 'Tillering and Stem Elongation', 'Grain Filling'],
    'Sugarcane': ['Early Growth', 'Grand Growth Phase', 'Maturity'],
    'Rice': ['Early Growth', 'Tillering to Panicle Initiation', 'Grain Filling'],
    'Onions': ['Early Growth', 'Bulb Formation', 'Maturation'],
  };

  static const Map<String, Map<String, Map<String, double>>> _optimalNutrients = {
    'Beans': {
      'Vegetative': {'N': 28, 'P': 45, 'K': 56, 'Zn': 2.0, 'Fe': 10.0, 'Mn': 5.0, 'Cu': 1.0, 'B': 0.5, 'Mo': 0.1},
      'Flowering': {'N': 28, 'P': 0, 'K': 56, 'Zn': 2.0, 'Fe': 10.0, 'Mn': 5.0, 'Cu': 1.0, 'B': 0.5, 'Mo': 0.1},
      'Pod Development': {'N': 28, 'P': 0, 'K': 56, 'Zn': 2.0, 'Fe': 10.0, 'Mn': 5.0, 'Cu': 1.0, 'B': 0.5, 'Mo': 0.1},
    },
    'Maize': {
      'Emergence to V6': {'N': 45, 'P': 28, 'K': 56, 'Zn': 3.0, 'Fe': 15.0, 'Mn': 6.0, 'Cu': 1.5, 'B': 0.6, 'Mo': 0.2},
      'V6 to VT': {'N': 84, 'P': 28, 'K': 56, 'Zn': 3.0, 'Fe': 15.0, 'Mn': 6.0, 'Cu': 1.5, 'B': 0.6, 'Mo': 0.2},
      'Reproductive': {'N': 0, 'P': 0, 'K': 28, 'Zn': 3.0, 'Fe': 15.0, 'Mn': 6.0, 'Cu': 1.5, 'B': 0.6, 'Mo': 0.2},
    },
    'Tomatoes': {
      'Early Growth': {'N': 100, 'P': 50, 'K': 150, 'Zn': 2.5, 'Fe': 12.0, 'Mn': 5.5, 'Cu': 1.2, 'B': 0.7, 'Mo': 0.15},
      'Flowering and Fruit Set': {'N': 80, 'P': 60, 'K': 150, 'Zn': 2.5, 'Fe': 12.0, 'Mn': 5.5, 'Cu': 1.2, 'B': 0.7, 'Mo': 0.15},
      'Fruit Development': {'N': 60, 'P': 60, 'K': 200, 'Zn': 2.5, 'Fe': 12.0, 'Mn': 5.5, 'Cu': 1.2, 'B': 0.7, 'Mo': 0.15},
    },
    'Cabbages/Kales': {
      'Early Growth': {'N': 120, 'P': 60, 'K': 100, 'Zn': 2.0, 'Fe': 10.0, 'Mn': 5.0, 'Cu': 1.0, 'B': 0.5, 'Mo': 0.1},
      'Leaf Development': {'N': 100, 'P': 60, 'K': 100, 'Zn': 2.0, 'Fe': 10.0, 'Mn': 5.0, 'Cu': 1.0, 'B': 0.5, 'Mo': 0.1},
      'Head Formation': {'N': 80, 'P': 60, 'K': 120, 'Zn': 2.0, 'Fe': 10.0, 'Mn': 5.0, 'Cu': 1.0, 'B': 0.5, 'Mo': 0.1},
    },
    'Carrots': {
      'Early Growth': {'N': 80, 'P': 60, 'K': 120, 'Zn': 2.0, 'Fe': 10.0, 'Mn': 5.0, 'Cu': 1.0, 'B': 0.5, 'Mo': 0.1},
      'Root Expansion': {'N': 60, 'P': 80, 'K': 140, 'Zn': 2.0, 'Fe': 10.0, 'Mn': 5.0, 'Cu': 1.0, 'B': 0.5, 'Mo': 0.1},
      'Maturation': {'N': 40, 'P': 60, 'K': 140, 'Zn': 2.0, 'Fe': 10.0, 'Mn': 5.0, 'Cu': 1.0, 'B': 0.5, 'Mo': 0.1},
    },
    'Irish Potatoes': {
      'Early Growth': {'N': 100, 'P': 80, 'K': 150, 'Zn': 2.5, 'Fe': 12.0, 'Mn': 5.5, 'Cu': 1.2, 'B': 0.7, 'Mo': 0.15},
      'Tuber Initiation': {'N': 80, 'P': 100, 'K': 180, 'Zn': 2.5, 'Fe': 12.0, 'Mn': 5.5, 'Cu': 1.2, 'B': 0.7, 'Mo': 0.15},
      'Tuber Bulking': {'N': 60, 'P': 80, 'K': 200, 'Zn': 2.5, 'Fe': 12.0, 'Mn': 5.5, 'Cu': 1.2, 'B': 0.7, 'Mo': 0.15},
    },
    'Wheat': {
      'Early Growth': {'N': 100, 'P': 50, 'K': 60, 'Zn': 3.0, 'Fe': 15.0, 'Mn': 6.0, 'Cu': 1.5, 'B': 0.6, 'Mo': 0.2},
      'Tillering and Stem Elongation': {'N': 120, 'P': 50, 'K': 60, 'Zn': 3.0, 'Fe': 15.0, 'Mn': 6.0, 'Cu': 1.5, 'B': 0.6, 'Mo': 0.2},
      'Grain Filling': {'N': 80, 'P': 40, 'K': 50, 'Zn': 3.0, 'Fe': 15.0, 'Mn': 6.0, 'Cu': 1.5, 'B': 0.6, 'Mo': 0.2},
    },
    'Sugarcane': {
      'Early Growth': {'N': 120, 'P': 60, 'K': 150, 'Zn': 2.5, 'Fe': 12.0, 'Mn': 5.5, 'Cu': 1.2, 'B': 0.7, 'Mo': 0.15},
      'Grand Growth Phase': {'N': 150, 'P': 60, 'K': 180, 'Zn': 2.5, 'Fe': 12.0, 'Mn': 5.5, 'Cu': 1.2, 'B': 0.7, 'Mo': 0.15},
      'Maturity': {'N': 80, 'P': 40, 'K': 120, 'Zn': 2.5, 'Fe': 12.0, 'Mn': 5.5, 'Cu': 1.2, 'B': 0.7, 'Mo': 0.15},
    },
    'Rice': {
      'Early Growth': {'N': 100, 'P': 40, 'K': 80, 'Zn': 3.0, 'Fe': 15.0, 'Mn': 6.0, 'Cu': 1.5, 'B': 0.6, 'Mo': 0.2},
      'Tillering to Panicle Initiation': {'N': 120, 'P': 50, 'K': 80, 'Zn': 3.0, 'Fe': 15.0, 'Mn': 6.0, 'Cu': 1.5, 'B': 0.6, 'Mo': 0.2},
      'Grain Filling': {'N': 80, 'P': 40, 'K': 60, 'Zn': 3.0, 'Fe': 15.0, 'Mn': 6.0, 'Cu': 1.5, 'B': 0.6, 'Mo': 0.2},
    },
    'Onions': {
      'Early Growth': {'N': 90, 'P': 70, 'K': 105, 'Zn': 2.0, 'Fe': 10.0, 'Mn': 5.0, 'Cu': 1.0, 'B': 0.5, 'Mo': 0.1},
      'Bulb Formation': {'N': 0, 'P': 70, 'K': 105, 'Zn': 2.0, 'Fe': 10.0, 'Mn': 5.0, 'Cu': 1.0, 'B': 0.5, 'Mo': 0.1},
      'Maturation': {'N': 0, 'P': 0, 'K': 60, 'Zn': 2.0, 'Fe': 10.0, 'Mn': 5.0, 'Cu': 1.0, 'B': 0.5, 'Mo': 0.1},
    },
  };

  static const Map<String, Map<String, List<Map<String, dynamic>>>> _nutrientRecs = {
    'N': {
      'Low': [
        {'type': 'Chemical', 'desc': 'Apply Urea (46-0-0)', 'content': {'N': 46, 'P': 0, 'K': 0}},
        {'type': 'Biological', 'desc': 'Add well-decomposed compost', 'content': null},
        {'type': 'Biological', 'desc': 'Plant nitrogen-fixing cover crops (e.g., clover, vetch)', 'content': null},
        {'type': 'Biological', 'desc': 'Apply manure (cow, poultry)', 'content': null},
        {'type': 'Biological', 'desc': 'Inoculate with rhizobia for legumes', 'content': null},
        {'type': 'Mechanical', 'desc': 'Improve soil aeration through tillage', 'content': null},
      ],
      'High': [
        {'type': 'Management', 'desc': 'Reduce nitrogen inputs', 'content': null},
        {'type': 'Biological', 'desc': 'Plant cover crops to absorb excess N (e.g., grasses)', 'content': null},
        {'type': 'Biological', 'desc': 'Use crop rotation to balance nutrients', 'content': null},
        {'type': 'Mechanical', 'desc': 'Increase irrigation to leach excess nitrogen', 'content': null},
      ],
    },
    'P': {
      'Low': [
        {'type': 'Chemical', 'desc': 'Apply DAP (18-46-0)', 'content': {'N': 18, 'P': 46, 'K': 0}},
        {'type': 'Biological', 'desc': 'Add bone meal', 'content': null},
        {'type': 'Biological', 'desc': 'Apply rock phosphate', 'content': null},
        {'type': 'Biological', 'desc': 'Use compost rich in phosphorus', 'content': null},
        {'type': 'Biological', 'desc': 'Inoculate with mycorrhizal fungi', 'content': null},
        {'type': 'Mechanical', 'desc': 'Incorporate organic matter into soil', 'content': null},
      ],
      'High': [
        {'type': 'Management', 'desc': 'Reduce phosphorus inputs', 'content': null},
        {'type': 'Biological', 'desc': 'Use crop rotation with P-efficient crops', 'content': null},
        {'type': 'Biological', 'desc': 'Plant cover crops to stabilize P', 'content': null},
      ],
    },
    'K': {
      'Low': [
        {'type': 'Chemical', 'desc': 'Apply Muriate of Potash (0-0-60)', 'content': {'N': 0, 'P': 0, 'K': 60}},
        {'type': 'Biological', 'desc': 'Add wood ash', 'content': null},
        {'type': 'Biological', 'desc': 'Apply composted banana peels', 'content': null},
        {'type': 'Biological', 'desc': 'Use green manure (e.g., comfrey)', 'content': null},
        {'type': 'Mechanical', 'desc': 'Deep tillage to access subsoil K', 'content': null},
      ],
      'High': [
        {'type': 'Management', 'desc': 'Reduce potassium inputs', 'content': null},
        {'type': 'Biological', 'desc': 'Plant K-efficient cover crops', 'content': null},
        {'type': 'Mechanical', 'desc': 'Leach with heavy irrigation', 'content': null},
      ],
    },
    'Zn': {
      'Low': [
        {'type': 'Chemical', 'desc': 'Apply Zinc Sulfate (21% Zn)', 'content': {'Zn': 21}},
        {'type': 'Biological', 'desc': 'Add compost rich in zinc', 'content': null},
        {'type': 'Biological', 'desc': 'Use biochar to enhance Zn availability', 'content': null},
        {'type': 'Biological', 'desc': 'Inoculate with Zn-solubilizing microbes', 'content': null},
      ],
      'High': [
        {'type': 'Management', 'desc': 'Reduce Zn application', 'content': null},
        {'type': 'Biological', 'desc': 'Use crop rotation to balance Zn', 'content': null},
      ],
    },
    'Fe': {
      'Low': [
        {'type': 'Chemical', 'desc': 'Apply Ferrous Sulfate (20% Fe)', 'content': {'Fe': 20}},
        {'type': 'Biological', 'desc': 'Use compost rich in iron', 'content': null},
        {'type': 'Biological', 'desc': 'Apply biochar to improve Fe availability', 'content': null},
        {'type': 'Biological', 'desc': 'Inoculate with Fe-solubilizing microbes', 'content': null},
      ],
      'High': [
        {'type': 'Management', 'desc': 'Reduce Fe application', 'content': null},
        {'type': 'Biological', 'desc': 'Use crop rotation to balance Fe', 'content': null},
      ],
    },
    'Mn': {
      'Low': [
        {'type': 'Chemical', 'desc': 'Apply Manganese Sulfate (28% Mn)', 'content': {'Mn': 28}},
        {'type': 'Biological', 'desc': 'Add compost rich in manganese', 'content': null},
        {'type': 'Biological', 'desc': 'Use green manure to enhance Mn', 'content': null},
      ],
      'High': [
        {'type': 'Management', 'desc': 'Reduce Mn application', 'content': null},
        {'type': 'Biological', 'desc': 'Use crop rotation to balance Mn', 'content': null},
      ],
    },
    'Cu': {
      'Low': [
        {'type': 'Chemical', 'desc': 'Apply Copper Sulfate (25% Cu)', 'content': {'Cu': 25}},
        {'type': 'Biological', 'desc': 'Add compost rich in copper', 'content': null},
        {'type': 'Biological', 'desc': 'Use biochar to improve Cu availability', 'content': null},
      ],
      'High': [
        {'type': 'Management', 'desc': 'Reduce Cu application', 'content': null},
        {'type': 'Biological', 'desc': 'Use crop rotation to balance Cu', 'content': null},
      ],
    },
    'B': {
      'Low': [
        {'type': 'Chemical', 'desc': 'Apply Borax (11% B)', 'content': {'B': 11}},
        {'type': 'Biological', 'desc': 'Add compost rich in boron', 'content': null},
        {'type': 'Biological', 'desc': 'Use green manure (e.g., buckwheat)', 'content': null},
      ],
      'High': [
        {'type': 'Management', 'desc': 'Reduce B application', 'content': null},
        {'type': 'Biological', 'desc': 'Use crop rotation to balance B', 'content': null},
      ],
    },
    'Mo': {
      'Low': [
        {'type': 'Chemical', 'desc': 'Apply Sodium Molybdate (39% Mo)', 'content': {'Mo': 39}},
        {'type': 'Biological', 'desc': 'Add compost rich in molybdenum', 'content': null},
        {'type': 'Biological', 'desc': 'Inoculate with Mo-enhancing microbes', 'content': null},
      ],
      'High': [
        {'type': 'Management', 'desc': 'Reduce Mo application', 'content': null},
        {'type': 'Biological', 'desc': 'Use crop rotation to balance Mo', 'content': null},
      ],
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
    _updateNutrientStatus();
  }

  Future<void> _saveForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      for (int i = 0; i < _microNutrients.length; i++) {
        _microNutrients[i]['name'] = _microNameControllers[i].text.trim();
        _microNutrients[i]['level'] = double.tryParse(_microLevelControllers[i].text) ?? 0.0;
      }
      _microNutrients = _microNutrients.where((m) => m['name']?.isNotEmpty ?? false).toList();

      for (int i = 0; i < _crops.length; i++) {
        _crops[i]['type'] = _cropControllers[i].text;
        _crops[i]['stage'] = _stageControllers[i].text;
      }
      _crops = _crops.where((crop) => crop['type']?.isNotEmpty ?? false).toList();

      double? areaInAcres = _getAreaInAcres();

      final fieldData = FieldData(
        userId: widget.userId,
        plotId: widget.plotId,
        crops: _crops,
        area: areaInAcres,
        npk: {
          'N': _nitrogenController.text.isNotEmpty
              ? double.tryParse(_nitrogenController.text)
              : null,
          'P': _phosphorusController.text.isNotEmpty
              ? double.tryParse(_phosphorusController.text)
              : null,
          'K': _potassiumController.text.isNotEmpty
              ? double.tryParse(_potassiumController.text)
              : null,
        },
        microNutrients: _microNutrients.map((m) => m['name'] as String).toList(),
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
      _microNutrients = [{'name': '', 'level': 0.0, 'status': '', 'optimal': 0.0}];
      _microNameControllers = [TextEditingController()];
      _microLevelControllers = [TextEditingController()];
      _interventions.clear();
      _reminders.clear();
      _nutrientStatus.clear();
      _nutrientStatus.addAll({'N': '', 'P': '', 'K': ''});
      _optimalAverages.clear();
      _optimalAverages.addAll({'N': 0.0, 'P': 0.0, 'K': 0.0});
      _fertilizerRecommendation = '';
      _isOrganic = false;
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
    _updateNutrientStatus();
  }

  double _convertFractionToAcres(String fraction) {
    if (fraction.contains('Acre')) {
      final parts = fraction.split(' ');
      if (parts.length == 1) return 1.0;
      if (parts[0].contains('/')) {
        final frac = parts[0].split('/');
        return double.parse(frac[0]) / double.parse(frac[1]);
      } else if (parts.length == 2 && parts[1] == 'Acre') {
        return double.parse(parts[0]);
      } else if (parts.length == 3) {
        final whole = double.parse(parts[0]);
        final fracParts = parts[1].split('/');
        final frac = double.parse(fracParts[0]) / double.parse(fracParts[1]);
        return whole + frac;
      }
      return double.parse(parts[0]);
    }
    if (fraction.contains('/')) {
      final frac = fraction.split('/');
      return double.parse(frac[0]) / double.parse(frac[1]);
    }
    return double.parse(fraction);
  }

  double _getAreaInAcres() {
    final text = _areaController.text;
    if (text.isEmpty) return 0.0;
    if (_useAcres) {
      if (_acreFractions.contains(text)) {
        return _convertFractionToAcres(text);
      } else {
        return double.tryParse(text) ?? 0.0;
      }
    } else {
      return (double.tryParse(text) ?? 0.0) / 4046.86;
    }
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
      );
      await widget.notificationsPlugin.zonedSchedule(
        ('${widget.userId}${widget.plotId}${date}dayBefore').hashCode,
        'Upcoming Reminder for ${widget.plotId}',
        'Reminder: $activity is due tomorrow!',
        tzDayBefore,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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

  void _updateNutrientStatus() {
    setState(() {
      // Reset nutrient status
      _nutrientStatus.clear();
      _nutrientStatus.addAll({'N': '', 'P': '', 'K': ''});

      // Calculate optimal averages for selected crops and stages
      _optimalAverages = {'N': 0.0, 'P': 0.0, 'K': 0.0};
      int count = 0;
      for (var crop in _crops) {
        final cropType = crop['type'] ?? '';
        final cropStage = crop['stage'] ?? '';
        if (cropType.isNotEmpty &&
            cropStage.isNotEmpty &&
            _optimalNutrients.containsKey(cropType) &&
            _optimalNutrients[cropType]!.containsKey(cropStage)) {
          final opt = _optimalNutrients[cropType]![cropStage]!;
          _optimalAverages['N'] = _optimalAverages['N']! + (opt['N'] ?? 0.0);
          _optimalAverages['P'] = _optimalAverages['P']! + (opt['P'] ?? 0.0);
          _optimalAverages['K'] = _optimalAverages['K']! + (opt['K'] ?? 0.0);
          count++;
        }
      }
      if (count > 0) {
        _optimalAverages.updateAll((key, value) => value / count);
      }

      // Update status only if nutrient level is provided
      if (_nitrogenController.text.isNotEmpty &&
          double.tryParse(_nitrogenController.text) != null) {
        final n = double.tryParse(_nitrogenController.text) ?? 0.0;
        final optN = _optimalAverages['N'] ?? 0.0;
        _nutrientStatus['N'] = optN > 0
            ? (n < optN * 0.9
                ? 'Low'
                : n > optN * 1.1
                    ? 'High'
                    : 'Optimal')
            : '';
      }
      if (_phosphorusController.text.isNotEmpty &&
          double.tryParse(_phosphorusController.text) != null) {
        final p = double.tryParse(_phosphorusController.text) ?? 0.0;
        final optP = _optimalAverages['P'] ?? 0.0;
        _nutrientStatus['P'] = optP > 0
            ? (p < optP * 0.9
                ? 'Low'
                : p > optP * 1.1
                    ? 'High'
                    : 'Optimal')
            : '';
      }
      if (_potassiumController.text.isNotEmpty &&
          double.tryParse(_potassiumController.text) != null) {
        final k = double.tryParse(_potassiumController.text) ?? 0.0;
        final optK = _optimalAverages['K'] ?? 0.0;
        _nutrientStatus['K'] = optK > 0
            ? (k < optK * 0.9
                ? 'Low'
                : k > optK * 1.1
                    ? 'High'
                    : 'Optimal')
            : '';
      }
    });
    _updateMicroStatuses();
  }

  void _updateMicroStatuses() {
    setState(() {
      for (int i = 0; i < _microNutrients.length; i++) {
        final name = _microNameControllers[i].text.trim();
        final levelText = _microLevelControllers[i].text;
        double level = double.tryParse(levelText) ?? 0.0;
        double opt = 0.0;
        int count = 0;
        for (var crop in _crops) {
          final cropType = crop['type'] ?? '';
          final cropStage = crop['stage'] ?? '';
          if (cropType.isNotEmpty &&
              cropStage.isNotEmpty &&
              _optimalNutrients.containsKey(cropType) &&
              _optimalNutrients[cropType]!.containsKey(cropStage) &&
              _optimalNutrients[cropType]![cropStage]!.containsKey(name)) {
            opt += _optimalNutrients[cropType]![cropStage]![name] ?? 0.0;
            count++;
          }
        }
        final averageOpt = count > 0 ? opt / count : 0.0;
        final status = name.isNotEmpty &&
                levelText.isNotEmpty &&
                double.tryParse(levelText) != null &&
                averageOpt > 0
            ? (level < averageOpt * 0.9
                ? 'Low'
                : level > averageOpt * 1.1
                    ? 'High'
                    : 'Optimal')
            : '';
        _microNutrients[i] = {
          'name': name,
          'level': level,
          'status': status,
          'optimal': averageOpt,
        };
      }
      _microNutrients = _microNutrients.where((m) => m['name']?.isNotEmpty ?? false).toList();
      while (_microNameControllers.length > _microNutrients.length) {
        _microNameControllers.removeLast();
        _microLevelControllers.removeLast();
      }
      while (_microNameControllers.length < _microNutrients.length) {
        _microNameControllers.add(TextEditingController(text: _microNutrients[_microNameControllers.length]['name']));
        _microLevelControllers.add(TextEditingController(text: _microNutrients[_microLevelControllers.length]['level'].toString()));
      }
    });
  }

  Future<void> _addInterventionFromRec(String nutrient, double level, double opt, String status, Map<String, dynamic> rec) async {
    final area = _getAreaInAcres();
    if (area <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid plot area first')));
      }
      return;
    }
    double? quantity;
    if (status == 'Low' && !_isOrganic) {
      final deficit = opt - level;
      final content = rec['content'] as Map<String, dynamic>?;
      if (content != null && content[nutrient] != null) {
        final percent = (content[nutrient] ?? 0.0) / 100.0;
        if (percent > 0) {
          quantity = (deficit * area) / percent;
        }
      }
    }
    final intervention = await _showInterventionDialog(
      preType: rec['desc'],
      preQuantity: quantity,
      preUnit: 'kg',
    );
    if (intervention != null) {
      setState(() {
        _interventions.add(intervention);
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Low':
        return Colors.red;
      case 'High':
        return Colors.orange;
      case 'Optimal':
        return Colors.green;
      default:
        return Colors.black54;
    }
  }

  void _showOrganicFarmingGuide() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Organic Soil Management Guide'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Organic farmers can improve soil health using biological methods. Here are some tips:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Crop Rotation: Rotate crops to prevent nutrient depletion and improve soil structure.'),
              Text('• Cover Crops: Plant nitrogen-fixing crops like clover or vetch to enrich soil nitrogen.'),
              Text('• Companion Planting: Use plants like marigolds to deter pests and enhance soil health.'),
              Text('• Compost: Add well-decomposed compost to provide balanced nutrients.'),
              Text('• Manure: Use cow or poultry manure to boost soil fertility.'),
              Text('• Biochar: Incorporate biochar to improve nutrient retention and soil structure.'),
              Text('• Microbial Inoculants: Use mycorrhizal fungi or rhizobia to enhance nutrient uptake.'),
              Text('• Mulching: Apply organic mulch to retain moisture and add organic matter.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
                            _updateNutrientStatus();
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
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                      return _acreFractions.where((option) =>
                          option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                    },
                    onSelected: (String selection) => _areaController.text = selection,
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
              activeThumbColor: Colors.green[300],
            ),
            SwitchListTile(
              title: const Text('Organic Farming'),
              subtitle: const Text('Enable to prioritize biological interventions'),
              value: _isOrganic,
              onChanged: (value) => setState(() => _isOrganic = value),
              activeThumbColor: Colors.green[300],
            ),
            const SizedBox(height: 16),

            const Text('Soil Nutrient Levels',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: _buildNutrientFields(),
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text('Micro-Nutrients',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ..._buildMicroNutrientFields(),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _microNutrients.add({'name': '', 'level': 0.0, 'status': '', 'optimal': 0.0});
                          _microNameControllers.add(TextEditingController());
                          _microLevelControllers.add(TextEditingController());
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Add Micro-Nutrient'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Interventions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.info_outline, color: Colors.blue),
                  onPressed: _showOrganicFarmingGuide,
                  tooltip: 'Organic Soil Management Tips',
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                final intervention = await _showInterventionDialog();
                if (intervention != null) {
                  setState(() => _interventions.add(intervention));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Add Intervention'),
            ),
            ..._interventions.map((i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text('${i['type']} - ${i['quantity'] ?? 'N/A'} ${i['unit'] ?? ''}'),
                    subtitle: Text((i['date'] as Timestamp).toDate().toString().substring(0, 10)),
                  ),
                )),
            const SizedBox(height: 16),

            const Text('Reminders',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                final reminder = await _showReminderDialog();
                if (reminder != null && reminder['activity'] != null && (reminder['activity'] as String).isNotEmpty) {
                  setState(() => _reminders.add(reminder));
                  await _scheduleReminder(reminder['date'].toDate(), reminder['activity']);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Add Reminder'),
            ),
            ..._reminders.map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text(r['activity'] ?? 'No activity'),
                    subtitle: Text(r['date']?.toDate().toString().substring(0, 10) ?? 'No date'),
                  ),
                )),
            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _saveForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
      initialValue: _cropControllers[index].text.isEmpty
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
        });
        _updateNutrientStatus();
      },
      isExpanded: true,
      validator: (value) => widget.structureType == 'intercrop' && index < 2 && (value == null || value.isEmpty)
          ? 'Required for Intercrop'
          : null,
    );
  }

  Widget _buildCropStageField(int index) {
    final crop = _crops[index]['type'] ?? '';
    final stages = _cropStages[crop] ?? ['Custom'];

    return DropdownButtonFormField<String>(
      initialValue: _stageControllers[index].text.isEmpty
          ? null
          : _stageControllers[index].text,
      decoration: _inputDecoration('Crop Stage'),
      items: stages.map((stage) => DropdownMenuItem(value: stage, child: Text(stage))).toList(),
      onChanged: (value) {
        setState(() {
          _stageControllers[index].text = value ?? '';
          _crops[index]['stage'] = value ?? '';
        });
        _updateNutrientStatus();
      },
      isExpanded: true,
    );
  }

  List<Widget> _buildNutrientFields() {
    return [
      _buildMacroNutrientField('N', _nitrogenController, _optimalAverages['N'] ?? 0.0, _nutrientStatus['N'] ?? ''),
      const SizedBox(height: 16),
      _buildMacroNutrientField('P', _phosphorusController, _optimalAverages['P'] ?? 0.0, _nutrientStatus['P'] ?? ''),
      const SizedBox(height: 16),
      _buildMacroNutrientField('K', _potassiumController, _optimalAverages['K'] ?? 0.0, _nutrientStatus['K'] ?? ''),
    ];
  }

  Widget _buildMacroNutrientField(String nutrient, TextEditingController controller, double optimal, String status) {
    final hasLevel = controller.text.isNotEmpty && double.tryParse(controller.text) != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: controller,
                  decoration: _inputDecoration(
                    nutrient == 'N' ? 'Nitrogen (N)' : nutrient == 'P' ? 'Phosphorus (P)' : 'Potassium (K)',
                  ).copyWith(
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.info_outline, color: Colors.blue),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('${nutrient == 'N' ? 'Nitrogen' : nutrient == 'P' ? 'Phosphorus' : 'Potassium'} Info'),
                            content: Text('Enter the soil $nutrient level in ppm. Optimal value is approximately ${optimal.toStringAsFixed(1)} ppm.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) => v != null && v.isNotEmpty && double.tryParse(v) == null
                      ? 'Enter a valid number'
                      : null,
                  onChanged: (_) => _updateNutrientStatus(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Text(
                  'Optimal: ${optimal.toStringAsFixed(1)} ppm',
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ),
            ],
          ),
          if (hasLevel && status.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Text(
                    'Status: $status',
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      value: status == 'Optimal' ? 1.0 : status == 'Low' ? 0.3 : 0.7,
                      strokeWidth: 3,
                      color: _getStatusColor(status),
                      backgroundColor: Colors.grey[200],
                    ),
                  ),
                ],
              ),
            ),
          if (hasLevel && status.isNotEmpty && status != 'Optimal' && _nutrientRecs.containsKey(nutrient))
            Column(
              children: _nutrientRecs[nutrient]![status]!
                  .where((rec) => !_isOrganic || rec['type'] != 'Chemical')
                  .map((rec) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Tooltip(
                          message: rec['type'] == 'Chemical'
                              ? 'Apply this fertilizer to correct the deficiency.'
                              : rec['type'] == 'Biological'
                                  ? 'Use organic methods to improve soil health.'
                                  : rec['type'] == 'Mechanical'
                                      ? 'Physical soil management practices.'
                                      : 'Other management strategies.',
                          child: Text(
                            '${rec['type']}: ${rec['desc']}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _addInterventionFromRec(
                          nutrient,
                          double.tryParse(controller.text) ?? 0.0,
                          optimal,
                          status,
                          rec,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: const Text('Use as Intervention', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildMicroNutrientFields() {
    return _microNutrients.asMap().entries.map((entry) {
      final idx = entry.key;
      final micro = entry.value;
      final name = micro['name'] as String? ?? '';
      final status = micro['status'] as String? ?? '';
      final optimal = (micro['optimal'] as double?) ?? 0.0;
      final hasLevel = _microLevelControllers[idx].text.isNotEmpty &&
          double.tryParse(_microLevelControllers[idx].text) != null;

      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _microNameControllers[idx],
                    decoration: _inputDecoration('Micro-Nutrient Name (e.g., Zn)').copyWith(
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.info_outline, color: Colors.blue),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Micro-Nutrient Info'),
                              content: const Text('Enter the micro-nutrient name (e.g., Zn, Fe) and its level in ppm.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    onChanged: (v) => _updateMicroStatuses(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _microLevelControllers[idx],
                    decoration: _inputDecoration('Level (ppm)'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _updateMicroStatuses(),
                    validator: (v) => v != null && v.isNotEmpty && double.tryParse(v) == null
                        ? 'Enter a valid number'
                        : null,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _microNutrients.removeAt(idx);
                      _microNameControllers.removeAt(idx);
                      _microLevelControllers.removeAt(idx);
                    });
                    _updateMicroStatuses();
                  },
                ),
              ],
            ),
            if (hasLevel && name.isNotEmpty && optimal > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Text(
                      'Status: $status',
                      style: TextStyle(
                        color: _getStatusColor(status),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        value: status == 'Optimal' ? 1.0 : status == 'Low' ? 0.3 : 0.7,
                        strokeWidth: 3,
                        color: _getStatusColor(status),
                        backgroundColor: Colors.grey[200],
                      ),
                    ),
                  ],
                ),
              ),
            if (hasLevel && status.isNotEmpty && status != 'Optimal' && name.isNotEmpty && _nutrientRecs.containsKey(name))
              Column(
                children: _nutrientRecs[name]![status]!
                    .where((rec) => !_isOrganic || rec['type'] != 'Chemical')
                    .map((rec) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Tooltip(
                            message: rec['type'] == 'Chemical'
                                ? 'Apply this fertilizer to correct the deficiency.'
                                : rec['type'] == 'Biological'
                                    ? 'Use organic methods to improve soil health.'
                                    : rec['type'] == 'Mechanical'
                                        ? 'Physical soil management practices.'
                                        : 'Other management strategies.',
                            child: Text(
                              '${rec['type']}: ${rec['desc']}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => _addInterventionFromRec(
                            name,
                            micro['level'] as double? ?? 0.0,
                            optimal,
                            status,
                            rec,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          child: const Text('Use as Intervention', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      );
    }).toList();
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.green[700]!, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red[700]!),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red[700]!, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      );

  Future<Map<String, dynamic>?> _showInterventionDialog({
    String? preType,
    double? preQuantity,
    String? preUnit,
    DateTime? preDate,
  }) async {
    String? type = preType ?? '';
    String? quantityText = preQuantity?.toStringAsFixed(2) ?? '';
    String? unit = preUnit ?? '';
    DateTime? date = preDate ?? DateTime.now();
    final quantityController = TextEditingController(text: quantityText);
    final unitController = TextEditingController(text: unit);
    final typeController = TextEditingController(text: type);

    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Add Intervention'),
        content: StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: typeController,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            onPressed: () {
              if (activity != null && activity!.isNotEmpty) {
                Navigator.pop(context, {
                  'date': Timestamp.fromDate(date!),
                  'activity': activity,
                });
              }
            },
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
    _updateNutrientStatus();
  }
}
