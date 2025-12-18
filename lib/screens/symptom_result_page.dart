import 'package:flutter/material.dart';
import '../models/symptom_model.dart';
import 'package:kilimomkononi/screens/pest%20management/pest_management.dart';
import 'package:kilimomkononi/screens/disease%20management/disease_management_page.dart';

class SymptomResultPage extends StatelessWidget {
  final List<Symptom> symptoms;

  const SymptomResultPage({super.key, required this.symptoms});

  Color _primaryColorForTypes(Set<String> types) {
    if (types.contains('Disease') && !types.contains('Pest')) return Colors.red[700]!;
    if (types.contains('Pest') && !types.contains('Disease')) return Colors.green[900]!;
    if (types.contains('Nematode')) return Colors.purple[700]!;
    if (types.contains('Abiotic')) return Colors.blue[800]!;
    if (types.contains('Storage')) return Colors.brown[700]!;
    return Colors.black87;
  }

  @override
  Widget build(BuildContext context) {
    final identities = symptoms.map((s) => s.identity).toSet().toList();
    final likelyTypes = symptoms.map((s) => s.likelyType).toSet();

    final primaryColor = _primaryColorForTypes(likelyTypes);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Symptom Result", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromARGB(255, 3, 39, 4),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Selected Symptoms:",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 3, 39, 4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...symptoms.map((s) => Text("- ${s.label} (${s.plantPart})")),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                "Likely Type(s): ${likelyTypes.join(', ')}",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 3, 39, 4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "🔍 Possible Identities:",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 3, 39, 4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (identities.length == 1) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.yellow[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: primaryColor, width: 1.6),
                      ),
                      child: Text(
                        identities.first,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                        textAlign: identities.first.length < 20 ? TextAlign.center : TextAlign.left,
                      ),
                    ),
                  ] else ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: identities
                          .map((id) => Chip(label: Text(id)))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const Spacer(),

          // Pass selected symptoms to PestManagementPage
          if (likelyTypes.contains('Pest'))
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[900]),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PestManagementPage(
                          selectedSymptoms: symptoms,
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    "Go to Pest Management",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),

          // Pass selected symptoms to DiseaseManagementPage
          if (likelyTypes.contains('Disease'))
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DiseaseManagementPage(
                        selectedSymptoms: symptoms,
                      ),
                    ),
                  );
                },
                child: const Text(
                  "Go to Disease Management",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}