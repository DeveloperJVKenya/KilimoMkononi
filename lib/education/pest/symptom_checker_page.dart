// lib/education/pest/symptom_checker_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:kilimomkononi/models/symptom_model.dart';
import 'package:kilimomkononi/models/education_user.dart';
import 'symptom_result_page.dart';

class SymptomCheckerPage extends StatefulWidget {
  final EduRole role;
  final String schoolName;
  final String classId;
  final bool isEmbedded;
  final Function(Map<String, String>)? onGoToManagement;

  const SymptomCheckerPage({
    super.key,
    required this.role,
    required this.schoolName,
    required this.classId,
    this.isEmbedded = false,
    this.onGoToManagement,
  });

  @override
  State<SymptomCheckerPage> createState() => _SymptomCheckerPageState();
}

class _SymptomCheckerPageState extends State<SymptomCheckerPage> {
  List<Symptom> symptoms = [];
  String? selectedCrop;
  String? selectedStage;
  String? selectedType;
  final Set<Symptom> selectedSymptoms = {};
  bool _showResults = false;
  List<Symptom> _selectedSymptomsList = [];

  final Map<String, int> stageOrder = {
    "Germination/Seedling": 0,
    "Early Growth": 0,
    "Vegetative Growth/Weeding": 1,
    "Flowering/Reproductive": 2,
    "Podding": 3,
    "Fruiting": 3,
    "Tuber Formation": 3,
    "Tuber Initiation": 3,
    "Tuber Bulking": 3,
    "Bulb Formation/Reproductive": 4,
    "Maturation/Harvesting": 4,
    "Bulbing/Maturation": 5,
    "Maturation": 5,
    "Harvesting/Storage": 6,
    "Storage": 7,
  };

  @override
  void initState() {
    super.initState();
    _loadSymptoms();
  }

  Future<void> _loadSymptoms() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/data/master.json');
      final List data = jsonDecode(jsonString);
      setState(() {
        symptoms = data.map((e) => Symptom.fromJson(e as Map<String, dynamic>)).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading symptoms: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (symptoms.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_showResults) {
      return SymptomResultPage(
        symptoms: _selectedSymptomsList,
        role: widget.role,
        schoolName: widget.schoolName,
        classId: widget.classId,
        isEmbedded: widget.isEmbedded,
        onGoToManagement: widget.onGoToManagement,
        onBack: () => setState(() => _showResults = false),
      );
    }

    final crops = symptoms.map((s) => s.crop).toSet().toList()..sort();

    List<String> stages = [];
    if (selectedCrop != null) {
      stages = symptoms.where((s) => s.crop == selectedCrop).map((s) => s.stage).toSet().toList();
      stages.sort((a, b) => (stageOrder[a] ?? 999).compareTo(stageOrder[b] ?? 999));
    }

    List<String> types = [];
    if (selectedCrop != null && selectedStage != null) {
      types = symptoms
          .where((s) => s.crop == selectedCrop && s.stage == selectedStage)
          .map((s) => s.likelyType)
          .toSet()
          .toList()..sort();
    }

    List<Symptom> filtered = [];
    if (selectedCrop != null && selectedStage != null) {
      filtered = symptoms.where((s) =>
          s.crop == selectedCrop &&
          s.stage == selectedStage &&
          (selectedType == null || s.likelyType == selectedType)).toList();
    }

    final groupedByPart = <String, List<Symptom>>{};
    for (final s in filtered) {
      groupedByPart.putIfAbsent(s.plantPart, () => []).add(s);
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDropdown("Select Crop", crops, selectedCrop, (v) {
              setState(() {
                selectedCrop = v;
                selectedStage = null;
                selectedType = null;
                selectedSymptoms.clear();
              });
            }),

            if (selectedCrop != null) ...[
              const SizedBox(height: 16),
              _buildDropdown("Select Growth Stage", stages, selectedStage, (v) {
                setState(() {
                  selectedStage = v;
                  selectedType = null;
                  selectedSymptoms.clear();
                });
              }),
            ],

            if (selectedStage != null) ...[
              const SizedBox(height: 16),
              _buildDropdown("Filter by Type (Optional)", types, selectedType, (v) => setState(() => selectedType = v)),

              const SizedBox(height: 24),
              ...groupedByPart.entries.map((e) => Card(
                    child: ExpansionTile(
                      title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                      initiallyExpanded: true,
                      children: e.value.map((s) => CheckboxListTile(
                        title: Text(s.label),
                        subtitle: Text("Likely: ${s.likelyType} → ${s.identity}"),
                        value: selectedSymptoms.contains(s),
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              selectedSymptoms.add(s);
                            } else {
                              selectedSymptoms.remove(s);
                            }
                          });
                        },
                      )).toList(),
                    ),
                  )),

              const SizedBox(height: 30),
              if (selectedSymptoms.isNotEmpty)
                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.search),
                    label: const Text("Identify Problem", style: TextStyle(fontSize: 18)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF032704),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedSymptomsList = selectedSymptoms.toList();
                        _showResults = true;
                      });
                    },
                  ),
                ),
            ],
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? value, ValueChanged<String?> onChanged) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            border: InputBorder.none,
          ),
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}