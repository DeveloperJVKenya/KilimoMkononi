// ignore_for_file: library_private_types_in_public_api

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/symptom_model.dart';
import 'symptom_result_page.dart';

class SymptomCheckerPage extends StatefulWidget {
  const SymptomCheckerPage({super.key});

  @override
  _SymptomCheckerPageState createState() => _SymptomCheckerPageState();
}

class _SymptomCheckerPageState extends State<SymptomCheckerPage> {
  List<Symptom> symptoms = [];

  String? selectedCrop;
  String? selectedStage;
  String? selectedType;
  Set<Symptom> selectedSymptoms = {};

  // Custom stage order for logical sorting
  final Map<String, int> stageOrder = {
    "Germination/Seedling": 0,
    "Vegetative Growth/Weeding": 1,
    "Flowering/Reproductive": 2,
    "Podding": 3,
    "Fruiting": 3,
    "Tuber Formation": 3,
    "Maturation/Harvesting": 4,
    "Bulb Formation/Reproductive": 4,
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
    final String response =
        await rootBundle.loadString('assets/data/master.json');
    final List<dynamic> data = jsonDecode(response);
    setState(() {
      symptoms = data.map((e) => Symptom.fromJson(e)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (symptoms.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Symptom Checker",
              style: TextStyle(color: Colors.white)),
          backgroundColor: const Color.fromARGB(255, 3, 39, 4),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final crops = symptoms.map((s) => s.crop).toSet().toList();
    crops.sort();

    // For stages
    List<String> stages;
    if (selectedCrop == null) {
      stages = <String>[];
    } else {
      stages = symptoms
          .where((s) => s.crop == selectedCrop)
          .map((s) => s.stage)
          .toSet()
          .toList();
      stages.sort((a, b) {
        final orderA = stageOrder[a] ?? 999;
        final orderB = stageOrder[b] ?? 999;
        return orderA.compareTo(orderB);
      });
    }

    // For types
    List<String> types;
    if (selectedCrop != null && selectedStage != null) {
      types = symptoms
          .where((s) => s.crop == selectedCrop && s.stage == selectedStage)
          .map((s) => s.likelyType)
          .toSet()
          .toList();
      types.sort();
    } else {
      types = <String>[];
    }

    // Filtered symptoms
    final filteredSymptoms = (selectedCrop != null && selectedStage != null)
        ? symptoms.where((s) {
            final matchesCrop = s.crop == selectedCrop;
            final matchesStage = s.stage == selectedStage;
            final matchesType =
                selectedType == null || s.likelyType == selectedType;
            return matchesCrop && matchesStage && matchesType;
          }).toList()
        : [];

    // Group symptoms by plant part
    final grouped = <String, List<Symptom>>{};
    for (var s in filteredSymptoms) {
      grouped.putIfAbsent(s.plantPart, () => []).add(s);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Symptom Checker",
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromARGB(255, 3, 39, 4),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Crop dropdown
              _buildDropdown('Select Crop', crops, selectedCrop, (val) {
                setState(() {
                  selectedCrop = val;
                  selectedStage = null;
                  selectedType = null;
                  selectedSymptoms.clear();
                });
              }),
              const SizedBox(height: 16),

              // Stage dropdown
              if (selectedCrop != null) ...[
                _buildDropdown('Select Growth Stage', stages, selectedStage, (val) {
                  setState(() {
                    selectedStage = val;
                    selectedType = null;
                    selectedSymptoms.clear();
                  });
                }),
                const SizedBox(height: 16),
              ],

              // Type dropdown
              if (selectedStage != null) ...[
                _buildDropdown('Filter by Symptom Type (optional)', types, selectedType, (val) {
                  setState(() {
                    selectedType = val;
                    selectedSymptoms.clear();
                  });
                }),
                const SizedBox(height: 16),
              ],

              // Plant parts with underlined title in ExpansionTile
              if (grouped.isNotEmpty)
                ...grouped.entries.map((entry) {
                  final part = entry.key;
                  final partSymptoms = entry.value;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: ExpansionTile(
                        title: Text(
                          part,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        initiallyExpanded: true,
                        children: partSymptoms.map((s) {
                          final isSelected = selectedSymptoms.contains(s);
                          return CheckboxListTile(
                            title: Text(s.label),
                            subtitle: Text("Type: ${s.likelyType}"),
                            value: isSelected,
                            onChanged: (bool? checked) {
                              setState(() {
                                if (checked == true) {
                                  selectedSymptoms.add(s);
                                } else {
                                  selectedSymptoms.remove(s);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 20),

              // Identify button
              if (selectedSymptoms.isNotEmpty)
                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.search),
                    label: const Text("Identify"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 3, 39, 4),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SymptomResultPage(
                              symptoms: selectedSymptoms.toList()),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Reusable dropdown widget
  Widget _buildDropdown(String label, List<String> items, String? value,
      ValueChanged<String?> onChanged) {
    final uniqueItems = items.toSet().toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: uniqueItems.contains(value) ? value : null,
              items: uniqueItems
                  .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                  .toList(),
              onChanged: onChanged,
              decoration: InputDecoration(
                labelText: label,
                labelStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                border: InputBorder.none,
              ),
            ),
            if (value != null) ...[
              const SizedBox(height: 4),
              Container(
                height: 1,
                color: Colors.black,
              ),
            ],
          ],
        ),
      ),
    );
  }
}