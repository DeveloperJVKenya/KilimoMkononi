import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:kilimomkononi/models/disease_model.dart'; 
import 'package:kilimomkononi/screens/view_disease_interventions.dart';

class DiseaseManagementPage extends StatefulWidget {
  const DiseaseManagementPage({super.key});

  @override
  State<DiseaseManagementPage> createState() => _DiseaseManagementPageState();
}

class _DiseaseManagementPageState extends State<DiseaseManagementPage> {
  String? _selectedCrop;
  String? _selectedStage;
  String? _selectedDisease;
  DiseaseData? _diseaseData;
  bool _showDiseaseDetails = false;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  final Map<String, List<String>> _cropDiseases = {
    'Maize': [
      'Maize Lethal Necrosis', 'Gray Leaf Spot', 'Common Rust', 'Southern Corn Leaf Blight', 'Northern Corn Leaf Blight',
      'Maize Dwarf Mosaic Virus', 'Tar Spot', 'Downy Mildew', 'Head Smut', 'Common Smut', 'Goss’s Wilt', 'Fusarium Ear Rot',
      'Gibberella Ear Rot', 'Diplodia Ear Rot', 'Aspergillus Ear Rot', 'Bacterial Leaf Streak', 'Pythium Root Rot',
      'Anthracnose Leaf Blight', 'Stewart’s Wilt', 'Bacterial Stalk Rot', 'Charcoal Rot', 'Maize Streak Virus',
      'Post-Harvest Mycotoxins (Aflatoxins, Fumonisins)', 'Storage Rot'
    ],
    'Beans': [
      'Anthracnose', 'Angular Leaf Spot', 'Common Bacterial Blight', 'Halo Blight', 'Fusarium Root Rot',
      'Rhizoctonia Root Rot', 'Pythium Root Rot', 'Bean Rust', 'Powdery Mildew', 'Bean Common Mosaic Virus',
      'Bean Golden Yellow Mosaic Virus', 'Ascochyta Blight', 'Sclerotinia White Mold', 'Brown Spot',
      'Root Knot Nematodes', 'Charcoal Rot', 'Bacterial Wilt', 'Web Blight', 'Fusarium Wilt',
      'Post-Harvest Fungal Rot'
    ],
    'Tomatoes': [
      'Early Blight', 'Late Blight', 'Bacterial Wilt', 'Bacterial Spot', 'Bacterial Canker', 'Tomato Mosaic Virus',
      'Tomato Yellow Leaf Curl Virus', 'Fusarium Wilt', 'Verticillium Wilt', 'Septoria Leaf Spot', 'Powdery Mildew',
      'Gray Mold (Botrytis)', 'Southern Blight', 'Root Knot Nematodes', 'Tomato Spotted Wilt Virus',
      'Alternaria Stem Canker', 'Damping-Off', 'Anthracnose', 'Fruit Rot', 'Post-Harvest Fungal Rot'
    ],
    'Cassava': [
      'Cassava Mosaic Disease', 'Cassava Brown Streak Disease', 'Bacterial Blight', 'Cassava Anthracnose Disease',
      'Root Rot', 'White Leaf Spot', 'Cercospora Leaf Spot', 'Alternaria Leaf Spot', 'Fusarium Wilt',
      'Powdery Mildew', 'Rust', 'Damping-Off', 'Post-Harvest Rot'
    ],
    'Rice': [
      'Rice Blast', 'Bacterial Leaf Blight', 'Sheath Blight', 'Brown Spot', 'Leaf Smut', 'False Smut',
      'Tungro Disease', 'Bakanae Disease', 'Sheath Rot', 'Grain Discoloration', 'Stem Rot', 'Ufra Disease',
      'Root Knot Nematodes', 'White Tip Disease', 'Damping-Off', 'Post-Harvest Fungal Rot'
    ],
    'Potatoes': [
      'Late Blight', 'Early Blight', 'Bacterial Wilt', 'Blackleg', 'Common Scab', 'Powdery Scab',
      'Verticillium Wilt', 'Fusarium Dry Rot', 'Rhizoctonia Black Scurf', 'Silver Scurf', 'Brown Rot',
      'Potato Virus Y', 'Potato Leafroll Virus', 'Potato Mop-Top Virus', 'Ring Rot', 'Pink Rot',
      'Soft Rot', 'Damping-Off', 'Black Dot', 'Post-Harvest Fungal Rot'
    ],
    'Wheat': [
      'Stem Rust', 'Leaf Rust', 'Stripe Rust', 'Powdery Mildew', 'Septoria Leaf Blotch', 'Tan Spot',
      'Fusarium Head Blight', 'Bacterial Leaf Streak', 'Loose Smut', 'Common Bunt', 'Karnal Bunt',
      'Take-All Disease', 'Eyespot', 'Wheat Streak Mosaic Virus', 'Barley Yellow Dwarf Virus',
      'Snow Mold', 'Pythium Root Rot', 'Rhizoctonia Root Rot', 'Damping-Off', 'Post-Harvest Fungal Rot'
    ],
    'Cabbage/Kales': [
      'Black Rot', 'Downy Mildew', 'Powdery Mildew', 'Clubroot', 'Alternaria Leaf Spot', 'Ring Spot',
      'Bacterial Soft Rot', 'Fusarium Yellows', 'White Rust', 'Sclerotinia Stem Rot (White Mold)',
      'Damping-Off', 'Leaf Blight', 'Black Leg', 'Anthracnose', 'Post-Harvest Fungal Rot'
    ],
    'Sugarcane': [
      'Red Rot', 'Smut', 'Pokkah Boeng', 'Rust', 'Leaf Scald', 'Sugarcane Mosaic Virus',
      'Ratoon Stunting Disease', 'Bacterial Wilt', 'Yellow Leaf Disease', 'Wilt Disease',
      'Pineapple Disease', 'Damping-Off', 'Post-Harvest Fungal Rot'
    ],
    'Carrots': [
      'Alternaria Leaf Blight', 'Cercospora Leaf Blight', 'Powdery Mildew', 'Downy Mildew', 'Bacterial Leaf Blight',
      'Root Knot Nematodes', 'Sclerotinia White Mold', 'Black Rot', 'Soft Rot', 'Rhizoctonia Root Rot',
      'Fusarium Root Rot', 'Damping-Off', 'Carrot Mosaic Virus', 'Aster Yellows', 'Post-Harvest Fungal Rot'
    ],
  };

  final List<String> _cropStages = [
    'Emergence/Germination', 'Propagation', 'Transplanting', 'Weeding', 'Flowering',
    'Fruiting', 'Podding', 'Harvesting', 'Post-Harvest'
  ];

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _notificationsPlugin.initialize(initSettings);
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  void _updateDiseaseDetails() {
    if (_selectedDisease != null && DiseaseData.diseaseLibrary.containsKey(_selectedDisease)) {
      setState(() {
        _diseaseData = DiseaseData.diseaseLibrary[_selectedDisease!];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Disease Management', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromARGB(255, 3, 39, 4),
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: Colors.grey[200],
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDropdown('Crop Type', _cropDiseases.keys.toList(), _selectedCrop, (val) {
                setState(() {
                  _selectedCrop = val;
                  _selectedDisease = null;
                  _diseaseData = null;
                });
              }),
              const SizedBox(height: 16),
              _buildAutocompleteField('Crop Stage', _cropStages),
              const SizedBox(height: 16),
              _buildDropdown('Select Disease', _selectedCrop != null ? _cropDiseases[_selectedCrop]! : [], _selectedDisease, (val) {
                setState(() {
                  _selectedDisease = val;
                  _updateDiseaseDetails();
                });
              }),
              if (_diseaseData != null) ...[
                const SizedBox(height: 16),
                _buildImageCard(_diseaseData!.imagePath),
              ],
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  if (_diseaseData != null) {
                    setState(() => _showDiseaseDetails = !_showDiseaseDetails);
                  } else {
                    scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Please select a disease first')));
                  }
                },
                child: const Text(
                  'View Disease Management Hints',
                  style: TextStyle(
                    color: Color.fromARGB(255, 3, 39, 4),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              if (_showDiseaseDetails && _diseaseData != null) ...[
                const SizedBox(height: 8),
                _buildHintCard('Prevention Strategies', _diseaseData!.preventionStrategies.join('\n')),
                _buildHintCard('Possible Interventions', 'Chemical control with ${_diseaseData!.activeAgent}'),
                _buildHintCard('Possible Causes', _diseaseData!.possibleCauses.join('\n')),
                _buildHintCard('Fungicides/Bactericides', _diseaseData!.fungicides.join('\n')),
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DiseaseInterventionPage(
                            diseaseData: _diseaseData!,
                            cropType: _selectedCrop!,
                            cropStage: _selectedStage ?? '',
                            notificationsPlugin: _notificationsPlugin,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 3, 39, 4),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Manage Disease'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? value, ValueChanged<String?> onChanged) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: DropdownButtonFormField<String>(
          value: value,
          items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildAutocompleteField(String label, List<String> options) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) return options;
            return options.where((option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
          },
          onSelected: (String selection) => setState(() => _selectedStage = selection),
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) => TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              labelText: label,
              hintText: 'e.g., Flowering',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              filled: true,
              fillColor: Colors.white,
            ),
            onSubmitted: (value) => setState(() => _selectedStage = value),
          ),
        ),
      ),
    );
  }

  Widget _buildImageCard(String imagePath) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width - 56,
            maxHeight: MediaQuery.of(context).size.height * 0.4,
          ),
          child: FutureBuilder<Size>(
            future: _getImageSize(imagePath),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
                return const SizedBox(
                  height: 150,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final imageSize = snapshot.data!;
              return AspectRatio(
                aspectRatio: imageSize.width / imageSize.height,
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, size: 150),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<Size> _getImageSize(String imagePath) async {
    final Completer<Size> completer = Completer();
    final Image image = Image.asset(imagePath);
    image.image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener(
        (ImageInfo info, bool synchronousCall) {
          completer.complete(Size(info.image.width.toDouble(), info.image.height.toDouble()));
        },
        onError: (exception, stackTrace) {
          completer.complete(const Size(150, 150));
        },
      ),
    );
    return completer.future;
  }

  Widget _buildHintCard(String title, String content) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(content, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

// Disease Intervention Page included in the same file
class DiseaseInterventionPage extends StatefulWidget {
  final DiseaseData diseaseData;
  final String cropType;
  final String cropStage;
  final FlutterLocalNotificationsPlugin notificationsPlugin;

  const DiseaseInterventionPage({
    required this.diseaseData,
    required this.cropType,
    required this.cropStage,
    required this.notificationsPlugin,
    super.key,
  });

  @override
  State<DiseaseInterventionPage> createState() => _DiseaseInterventionPageState();
}

class _DiseaseInterventionPageState extends State<DiseaseInterventionPage> {
  final _interventionController = TextEditingController();
  final _dosageController = TextEditingController();
  final _unitController = TextEditingController();
  final _areaController = TextEditingController();
  bool _useSQM = true;
  bool _hasSaved = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _saveIntervention() async {
    final user = FirebaseAuth.instance.currentUser;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (user == null) {
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Please log in')));
      return;
    }

    if (_interventionController.text.isEmpty &&
        _dosageController.text.isEmpty &&
        _unitController.text.isEmpty &&
        _areaController.text.isEmpty) {
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Please fill at least one field')));
      return;
    }

    final intervention = DiseaseIntervention(
      diseaseName: widget.diseaseData.name,
      cropType: widget.cropType,
      cropStage: widget.cropStage,
      intervention: _interventionController.text,
      dosage: _dosageController.text.isNotEmpty ? double.parse(_dosageController.text) : null,
      unit: _unitController.text.isNotEmpty ? _unitController.text : null,
      area: _areaController.text.isNotEmpty ? double.parse(_areaController.text) : null,
      areaUnit: _useSQM ? 'SQM' : 'Acres',
      timestamp: Timestamp.now(),
      userId: user.uid,
    );

    try {
      await FirebaseFirestore.instance
          .collection('diseaseinterventiondata')
          .doc(user.uid)
          .collection('interventions')
          .add(intervention.toMap());
      setState(() {
        _hasSaved = true;
        _interventionController.clear();
        _dosageController.clear();
        _unitController.clear();
        _areaController.clear();
      });
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Intervention saved successfully')));
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error saving intervention: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Disease Intervention', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromARGB(255, 3, 39, 4),
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: Colors.grey[200],
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField('Intervention Used', _interventionController, 'e.g., Fungicide application'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField('Dosage Applied', _dosageController, 'e.g., 5', isNumber: true),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField('Unit', _unitController, 'e.g., ml'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField('Total Area Affected', _areaController, 'e.g., 100', isNumber: true),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Use Square Meters (SQM)', style: TextStyle(color: Colors.black87)),
                value: _useSQM,
                onChanged: (value) => setState(() => _useSQM = value),
                activeColor: Colors.green[300],
              ),
              const SizedBox(height: 24),
              Column(
                children: [
                  ElevatedButton(
                    onPressed: _saveIntervention,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 3, 39, 4),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save Intervention', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _hasSaved
                        ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ViewDiseaseInterventionsPage(
                                  diseaseData: widget.diseaseData,
                                  notificationsPlugin: widget.notificationsPlugin,
                                ),
                              ),
                            )
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 3, 39, 4),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('View Saved Interventions', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, String hint, {bool isNumber = false}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: TextField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ),
    );
  }
}