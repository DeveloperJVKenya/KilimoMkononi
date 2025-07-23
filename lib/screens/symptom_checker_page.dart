import 'package:flutter/material.dart';
import 'package:kilimomkononi/screens/pest%20management/pest_management.dart';
import 'package:kilimomkononi/screens/disease_management_page.dart';

class SymptomCheckerPage extends StatefulWidget {
  const SymptomCheckerPage({super.key});

  @override
  State<SymptomCheckerPage> createState() => _SymptomCheckerPageState();
}

class _SymptomCheckerPageState extends State<SymptomCheckerPage> {
  // Symptom data organized by plant section and pest/disease
  final Map<String, Map<String, List<String>>> symptoms = {
    'Roots': {
      'Pests': [
        'Holes or tunnels in roots',
        'Swollen or knotted roots',
        'Wilting despite adequate watering',
        'Roots eaten or missing',
        'Presence of larvae or grubs in the soil',
        'Root surfaces scraped or damaged',
      ],
      'Diseases': [
        'Blackened or rotten roots',
        'Soft, mushy, or decaying roots',
        'White, fuzzy fungal growth on roots',
        'Yellowing and stunted plant growth',
        'Roots with sunken, dark lesions',
        'Bad odor from decaying roots',
      ],
    },
    'Stems': {
      'Pests': [
        'Holes bored into stems',
        'Girdling or ring-like damage around stems',
        'Sawdust-like material around stem base',
        'Visible caterpillars or borers inside stems',
        'Stems chewed or snapped',
        'Galls or unusual swellings on stems',
      ],
      'Diseases': [
        'Dark, sunken lesions or cankers on stems',
        'White or gray mold on stems',
        'Stems cracking or splitting abnormally',
        'Oozing or gummy sap from the stem',
        'Black streaks or rotting at the base of stems',
        'Stems drying and becoming brittle',
      ],
    },
    'Leaves': {
      'Pests': [
        'Holes or irregular chewing marks',
        'Skeletonized leaves (only veins left)',
        'Webbing or silky threads on leaves',
        'Sticky, shiny substance (honeydew) on leaves',
        'Small insects seen crawling on or under leaves',
        'Leaves curling, crinkling, or rolling up',
      ],
      'Diseases': [
        'Yellowing or browning of leaves (not from aging)',
        'Powdery white or gray coating on leaves',
        'Black, brown, or yellow spots with halos',
        'Water-soaked lesions on leaves',
        'Leaves wilting and falling prematurely',
        'Sooty black coating on leaf surfaces',
      ],
    },
    'Fruits/Grains': {
      'Pests': [
        'Small holes or tunnels in fruits or grains',
        'Worms or larvae inside the fruit/grain',
        'Fruits with chewed or missing parts',
        'Discoloration or deformities on grains',
        'Silky webbing on stored grains',
        'Fruits dropping before ripening',
      ],
      'Diseases': [
        'Sunken, black, or brown spots on fruits',
        'Soft, mushy, or rotting fruits',
        'Fungal growth (white, gray, or black mold) on fruit surfaces',
        'Grains appearing shriveled or discolored',
        'Fruits cracking or developing lesions',
        'Bad odor or fermentation from rotting produce',
      ],
    },
  };

  // Store selected symptoms
  Map<String, List<bool>> selectedSymptoms = {
    'Roots': [],
    'Stems': [],
    'Leaves': [],
    'Fruits/Grains': [],
  };

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize selectedSymptoms with false for each symptom
    symptoms.forEach((section, categories) {
      int totalSymptoms = categories['Pests']!.length + categories['Diseases']!.length;
      selectedSymptoms[section] = List.filled(totalSymptoms, false);
    });
  }

  void _analyzeSymptoms() async {
    setState(() => _isLoading = true);

    // Simulate analysis delay
    await Future.delayed(const Duration(seconds: 2));

    int pestCount = 0;
    int diseaseCount = 0;
    int totalSelected = 0;

    symptoms.forEach((section, categories) {
      List<String> allSymptoms = [...categories['Pests']!, ...categories['Diseases']!];
      for (int i = 0; i < allSymptoms.length; i++) {
        if (selectedSymptoms[section]![i]) {
          totalSelected++;
          if (i < categories['Pests']!.length) {
            pestCount++;
          } else {
            diseaseCount++;
          }
        }
      }
    });

    String resultMessage;
    Widget navigationButton;

    if (totalSelected == 0) {
      resultMessage = 'Please select at least one symptom to analyze.';
      navigationButton = const SizedBox.shrink(); // No button
    } else {
      double pestPercentage = (pestCount / totalSelected) * 100;
      double diseasePercentage = (diseaseCount / totalSelected) * 100;

      if (pestPercentage >= 60) {
        resultMessage = 'After analysis of your selected symptoms, the chances are that your crop is Pest affected.';
        navigationButton = ElevatedButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PestManagementPage())),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 3, 39, 4),
            foregroundColor: Colors.white,
          ),
          child: const Text('Go Ahead to Manage Pest'),
        );
      } else if (diseasePercentage >= 60) {
        resultMessage = 'After analysis of your selected symptoms, the chances are that your crop is Disease affected.';
        navigationButton = ElevatedButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DiseaseManagementPage())),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 3, 39, 4),
            foregroundColor: Colors.white,
          ),
          child: const Text('Go Ahead to Manage Disease'),
        );
      } else {
        resultMessage = 'The symptoms suggest it could be either a pest or disease. Please explore both options.';
        navigationButton = Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PestManagementPage())),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 3, 39, 4),
                foregroundColor: Colors.white,
              ),
              child: const Text('Manage Pest'),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DiseaseManagementPage())),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 3, 39, 4),
                foregroundColor: Colors.white,
              ),
              child: const Text('Manage Disease'),
            ),
          ],
        );
      }
    }

    setState(() => _isLoading = false);

    // Check if the widget is still mounted before using context
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Analysis Result'),
          content: Text(resultMessage),
          actions: [
            navigationButton,
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Symptom Checker', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromARGB(255, 3, 39, 4),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection('Roots'),
                  const SizedBox(height: 16),
                  _buildSection('Stems'),
                  const SizedBox(height: 16),
                  _buildSection('Leaves'),
                  const SizedBox(height: 16),
                  _buildSection('Fruits/Grains'),
                  const SizedBox(height: 24),
                  Center(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _analyzeSymptoms,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 3, 39, 4),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Analyze Symptoms', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color.fromARGB(255, 3, 39, 4)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSection(String section) {
    final pestSymptoms = symptoms[section]!['Pests']!;
    final diseaseSymptoms = symptoms[section]!['Diseases']!;
    final allSymptoms = [...pestSymptoms, ...diseaseSymptoms];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 3, 39, 4)),
            ),
            const SizedBox(height: 8),
            ...List.generate(allSymptoms.length, (index) {
              return CheckboxListTile(
                title: Text(
                  allSymptoms[index],
                  style: const TextStyle(fontSize: 14),
                ),
                value: selectedSymptoms[section]![index],
                onChanged: (bool? value) {
                  setState(() {
                    selectedSymptoms[section]![index] = value!;
                  });
                },
                activeColor: const Color.fromARGB(255, 3, 39, 4),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              );
            }),
          ],
        ),
      ),
    );
  }
}