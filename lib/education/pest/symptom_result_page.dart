// lib/education/pest/symptom_result_page.dart
import 'package:flutter/material.dart';
import 'package:kilimomkononi/models/symptom_model.dart';
import 'package:kilimomkononi/models/education_user.dart';

class SymptomResultPage extends StatelessWidget {
  final List<Symptom> symptoms;
  final EduRole role;
  final String schoolName;
  final String classId;
  final bool isEmbedded;
  final Function(Map<String, String>)? onGoToManagement;
  final VoidCallback? onBack;

  const SymptomResultPage({
    super.key,
    required this.symptoms,
    required this.role,
    required this.schoolName,
    required this.classId,
    this.isEmbedded = false,
    this.onGoToManagement,
    this.onBack,
  });

  Map<String, String> _getDiagnosisData() {
    final identities = symptoms.map((s) => s.identity).toSet().toList();
    final type = symptoms.first.likelyType;
    final crop = symptoms.first.crop;
    final stage = symptoms.first.stage;
    final name = identities.length == 1 ? identities.first : identities.join(', ');

    return {
      'crop': crop,
      'stage': stage,
      'name': name,
      'type': type,
    };
  }

  @override
  Widget build(BuildContext context) {
    final types = symptoms.map((s) => s.likelyType).toSet();
    final identities = symptoms.map((s) => s.identity).toSet().toList();
    final diagnosisData = _getDiagnosisData();

    final content = Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Selected Symptoms", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Divider(),
                    ...symptoms.map((s) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text("• ${s.label} (${s.plantPart})"),
                        )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              color: types.contains('Pest') ? Colors.green[50] : Colors.red[50],
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(identities.length == 1 ? "Diagnosis" : "Possible Causes",
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    if (identities.length == 1)
                      Text(identities.first,
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green))
                    else
                      Wrap(
                        spacing: 12,
                        children: identities
                            .map((id) => Chip(
                                  backgroundColor: Colors.green[100],
                                  label: Text(id, style: const TextStyle(fontWeight: FontWeight.bold)),
                                ))
                            .toList(),
                      ),
                    const SizedBox(height: 30),
                    if (types.contains('Pest'))
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.bug_report),
                          label: const Text("Go to Pest Management", style: TextStyle(fontSize: 18)),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green[900], padding: const EdgeInsets.all(16)),
                          onPressed: () => onGoToManagement?.call(diagnosisData),
                        ),
                      ),
                    if (types.contains('Disease')) const SizedBox(height: 12),
                    if (types.contains('Disease'))
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.local_hospital),
                          label: const Text("Go to Disease Management", style: TextStyle(fontSize: 18)),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], padding: const EdgeInsets.all(16)),
                          onPressed: () => onGoToManagement?.call(diagnosisData),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!isEmbedded) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Diagnosis Result"),
          backgroundColor: const Color(0xFF032704),
          foregroundColor: Colors.white,
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        ),
        body: content,
      );
    }

    return Stack(
      children: [
        content,
        Positioned(
          top: 16,
          left: 16,
          child: FloatingActionButton.small(
            backgroundColor: Colors.white,
            onPressed: onBack,
            child: const Icon(Icons.arrow_back, color: Color(0xFF032704)),
          ),
        ),
      ],
    );
  }
}