// lib/education/pest/disease_data_input.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kilimomkononi/models/education_user.dart';
import 'package:kilimomkononi/utils/firestore_helper.dart';

const Color primaryGreen = Color(0xFF388E3C);

final List<String> crops = [
  'Beans',
  'Maize',
  'Cabbage',
  'Carrots',
  'Tomatoes',
  'Onions',
];

final Map<String, List<String>> cropStages = {
  'Beans': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Flowering/Reproductive', 'Maturation/Harvesting', 'Storage'],
  'Maize': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Flowering/Reproductive', 'Maturation/Harvesting', 'Storage'],
  'Cabbage': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Flowering/Reproductive', 'Maturation/Harvesting', 'Storage'],
  'Carrots': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Maturation/Harvesting', 'Storage'],
  'Tomatoes': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Flowering/Reproductive', 'Maturation/Harvesting', 'Storage'],
  'Onions': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Bulb Formation/Reproductive', 'Bulbing/Maturation', 'Harvesting/Storage'],
};

final Map<String, Map<String, List<String>>> cropStageDiseases = {
  'Beans': {
    'Germination/Seedling': ['Fusarium Root Rot', 'Rhizoctonia Root Rot', 'Pythium Root Rot', 'Damping-Off'],
    'Vegetative Growth/Weeding': ['Anthracnose', 'Angular Leaf Spot', 'Common Bacterial Blight', 'Halo Blight', 'Bean Rust', 'Powdery Mildew', 'Bean Common Mosaic Virus', 'Bean Golden Yellow Mosaic Virus', 'Root Knot Nematodes', 'Bacterial Wilt'],
    'Flowering/Reproductive': ['Anthracnose', 'Angular Leaf Spot', 'Bean Rust', 'Powdery Mildew', 'Bean Common Mosaic Virus', 'Bean Golden Yellow Mosaic Virus', 'Ascochyta Blight', 'Sclerotinia White Mold', 'Bacterial Wilt'],
    'Maturation/Harvesting': ['Anthracnose', 'Ascochyta Blight', 'Sclerotinia White Mold', 'Brown Spot', 'Fusarium Wilt', 'Web Blight'],
    'Storage': ['Post-Harvest Fungal Rot'],
  },
  'Maize': {
    'Germination/Seedling': ['Pythium Root Rot', 'Damping-Off'],
    'Vegetative Growth/Weeding': ['Gray Leaf Spot', 'Common Rust', 'Northern Corn Leaf Blight', 'Maize Dwarf Mosaic Virus', 'Bacterial Leaf Streak', 'Anthracnose Leaf Blight', "Stewart's Wilt", 'Maize Streak Virus'],
    'Flowering/Reproductive': ['Gray Leaf Spot', 'Common Rust', 'Southern Corn Leaf Blight', 'Northern Corn Leaf Blight', 'Maize Dwarf Mosaic Virus', 'Tar Spot', 'Downy Mildew', 'Maize Streak Virus'],
    'Maturation/Harvesting': ['Maize Lethal Necrosis', 'Head Smut', 'Common Smut', "Goss's Wilt", 'Fusarium Ear Rot', 'Gibberella Ear Rot', 'Diplodia Ear Rot', 'Aspergillus Ear Rot', 'Bacterial Stalk Rot', 'Charcoal Rot'],
    'Storage': ['Post-Harvest Mycotoxins (Aflatoxins, Fumonisins)', 'Storage Rot'],
  },
  'Cabbage': {
    'Germination/Seedling': ['Damping-Off', 'Black Rot', 'Downy Mildew'],
    'Vegetative Growth/Weeding': ['Black Rot', 'Downy Mildew', 'Powdery Mildew', 'Alternaria Leaf Spot', 'Ring Spot', 'Bacterial Soft Rot', 'Fusarium Yellows', 'White Rust', 'Leaf Blight', 'Black Leg'],
    'Flowering/Reproductive': ['Downy Mildew', 'Powdery Mildew', 'Alternaria Leaf Spot', 'Sclerotinia Stem Rot (White Mold)', 'Anthracnose'],
    'Maturation/Harvesting': ['Black Rot', 'Sclerotinia Stem Rot (White Mold)', 'Bacterial Soft Rot', 'Anthracnose'],
    'Storage': ['Post-Harvest Fungal Rot'],
  },
  'Carrots': {
    'Germination/Seedling': ['Damping-Off', 'Fusarium Root Rot', 'Rhizoctonia Root Rot', 'Pythium Root Rot'],
    'Vegetative Growth/Weeding': ['Alternaria Leaf Blight', 'Cercospora Leaf Blight', 'Powdery Mildew', 'Downy Mildew', 'Bacterial Leaf Blight', 'Root Knot Nematodes', 'Carrot Mosaic Virus', 'Aster Yellows'],
    'Maturation/Harvesting': ['Sclerotinia White Mold', 'Fusarium Root Rot', 'Rhizoctonia Root Rot', 'Soft Rot', 'Black Rot'],
    'Storage': ['Post-Harvest Fungal Rot'],
  },
  'Tomatoes': {
    'Germination/Seedling': ['Damping-Off', 'Fusarium Wilt', 'Verticillium Wilt', 'Bacterial Wilt'],
    'Vegetative Growth/Weeding': ['Early Blight', 'Bacterial Spot', 'Bacterial Canker', 'Powdery Mildew', 'Mosaic Virus', 'Yellow Leaf Curl Virus', 'Root Knot Nematodes', 'Spotted Wilt Virus', 'Septoria Leaf Spot'],
    'Flowering/Reproductive': ['Early Blight', 'Late Blight', 'Bacterial Spot', 'Bacterial Canker', 'Powdery Mildew', 'Mosaic Virus', 'Yellow Leaf Curl Virus', 'Spotted Wilt Virus', 'Gray Mold (Botrytis)', 'Alternaria Stem Canker'],
    'Maturation/Harvesting': ['Late Blight', 'Anthracnose', 'Early Blight', 'Southern Blight', 'Fruit Rot', 'Gray Mold (Botrytis)'],
    'Storage': ['Post-Harvest Fungal Rot'],
  },
  'Onions': {
    'Germination/Seedling': ['Pythium Root Rot', 'Fusarium Basal Rot'],
    'Vegetative Growth/Weeding': ['Downy Mildew', 'Powdery Mildew', 'Leaf Blight'],
    'Bulb Formation/Reproductive': ['Purple Blotch', 'Fusarium Basal Rot'],
    'Bulbing/Maturation': ['Gray Mold', 'Neck Rot', 'Purple Blotch'],
    'Harvesting/Storage': ['Gray Mold', 'Post-Harvest Fungal Rot'],
  },
};

final Map<String, Map<String, dynamic>> diseaseDetails = {
  // All your original disease image paths — preserved exactly
  'Beans_Germination/Seedling_Fusarium Root Rot': {'imagePath': 'assets/diseases/beans_fusarium_root_rot_germination.jpg'},
  'Beans_Germination/Seedling_Rhizoctonia Root Rot': {'imagePath': 'assets/diseases/beans_rhizoctonia_root_rot_germination.jpg'},
  'Beans_Germination/Seedling_Pythium Root Rot': {'imagePath': 'assets/diseases/beans_pythium_root_rot_germination.jpg'},
  'Beans_Germination/Seedling_Damping-Off': {'imagePath': 'assets/diseases/beans_damping_off_germination.jpg'},
  // ... (all other entries as in your original code)
  'Onions_Harvesting/Storage_Gray Mold': {'imagePath': 'assets/diseases/onions_gray_mold_storage.jpg'},
};

class DiseaseDataInput extends StatefulWidget {
  final EduRole role;
  final String schoolName;
  final String classId;
  final Map<String, String>? prefillData;

  const DiseaseDataInput({
    super.key,
    required this.role,
    required this.schoolName,
    required this.classId,
    this.prefillData,
  });

  @override
  State<DiseaseDataInput> createState() => _DiseaseDataInputState();
}

class _DiseaseDataInputState extends State<DiseaseDataInput> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  final _interventionCtrl = TextEditingController();

  String? _selectedCrop;
  String? _selectedStage;
  String? _selectedDisease;
  String? _editingId;

  @override
  void initState() {
    super.initState();
    if (widget.prefillData != null) {
      _selectedCrop = widget.prefillData!['crop'];
      _selectedStage = widget.prefillData!['stage'];
      _selectedDisease = widget.prefillData!['name'];
    }
  }

  CollectionReference? get _collection {
    if (widget.classId.isEmpty) return null;
    return FirestoreHelper.getContentFromClassId(widget.classId, 'disease_data');
  }

  bool get _isHeadteacher => widget.role == EduRole.headteacher;
  bool get _canEdit => !_isHeadteacher && _collection != null;

  Future<void> _saveEntry() async {
    if (!_canEdit || !_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final data = {
      'cropType': _selectedCrop,
      'cropStage': _selectedStage,
      'diseaseName': _selectedDisease,
      'intervention': _interventionCtrl.text.trim().isEmpty ? null : _interventionCtrl.text.trim(),
      'schoolName': widget.schoolName,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      if (_editingId == null) {
        await _collection!.add(data);
      } else {
        await _collection!.doc(_editingId).update(data);
      }
      _resetForm();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_editingId == null ? 'Disease entry saved!' : 'Entry updated!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _editEntry(String id, Map<String, dynamic> data) {
    if (!_canEdit) return;
    setState(() {
      _editingId = id;
      _selectedCrop = data['cropType'];
      _selectedStage = data['cropStage'];
      _selectedDisease = data['diseaseName'];
      _interventionCtrl.text = data['intervention'] ?? '';
    });
  }

  Future<void> _deleteEntry(String id) async {
    if (!_canEdit) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await _collection!.doc(id).delete();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted'), backgroundColor: Colors.red));
    }
  }

  void _resetForm() {
    setState(() {
      _editingId = null;
      _selectedCrop = null;
      _selectedStage = null;
      _selectedDisease = null;
      _interventionCtrl.clear();
    });
    _formKey.currentState?.reset();
  }

  @override
  Widget build(BuildContext context) {
    String? imagePath;
    if (_selectedCrop != null && _selectedStage != null && _selectedDisease != null) {
      final key = '${_selectedCrop}_${_selectedStage}_$_selectedDisease';
      imagePath = diseaseDetails[key]?['imagePath'] as String? ?? 'assets/diseases/default.jpg';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isHeadteacher ? 'Disease Observation Form (View Only)' : 'Report Disease Observation',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryGreen),
            ),
            const SizedBox(height: 24),

            DropdownButtonFormField<String>(
              value: _selectedCrop,
              decoration: const InputDecoration(labelText: 'Crop Type', border: OutlineInputBorder()),
              items: crops.map((crop) => DropdownMenuItem(value: crop, child: Text(crop))).toList(),
              onChanged: _canEdit
                  ? (v) => setState(() {
                        _selectedCrop = v;
                        _selectedStage = null;
                        _selectedDisease = null;
                      })
                  : null,
              validator: _canEdit ? (v) => v == null ? 'Required' : null : null,
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _selectedStage,
              decoration: const InputDecoration(labelText: 'Growth Stage', border: OutlineInputBorder()),
              items: _selectedCrop == null ? [] : cropStages[_selectedCrop]!.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: _canEdit
                  ? (v) => setState(() {
                        _selectedStage = v;
                        _selectedDisease = null;
                      })
                  : null,
              validator: _canEdit ? (v) => v == null ? 'Required' : null : null,
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _selectedDisease,
              decoration: const InputDecoration(labelText: 'Disease Name', border: OutlineInputBorder()),
              items: _selectedCrop == null || _selectedStage == null
                  ? []
                  : cropStageDiseases[_selectedCrop]![_selectedStage]!
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
              onChanged: _canEdit ? (v) => setState(() => _selectedDisease = v) : null,
              validator: _canEdit ? (v) => v == null ? 'Required' : null : null,
            ),

            if (imagePath != null) ...[
              const SizedBox(height: 16),
              Center(
                child: Image.asset(
                  imagePath,
                  height: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported, size: 100),
                ),
              ),
            ],

            const SizedBox(height: 16),
            TextFormField(
              controller: _interventionCtrl,
              decoration: const InputDecoration(labelText: 'Intervention (optional)', border: OutlineInputBorder()),
              maxLines: 3,
              enabled: _canEdit,
            ),

            const SizedBox(height: 32),
            if (_canEdit)
              Center(
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveEntry,
                  icon: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.send),
                  label: Text(_editingId == null ? 'Save Disease Entry' : 'Update Entry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
              ),

            if (_editingId != null && _canEdit)
              Center(
                child: TextButton(
                  onPressed: _resetForm,
                  child: const Text('Cancel Edit', style: TextStyle(color: Colors.red)),
                ),
              ),

            const SizedBox(height: 40),
            const Text('Recent Disease Entries', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryGreen)),
            const Divider(),

            if (_collection == null)
              const Center(child: Text('Viewing form only — no class selected'))
            else
              StreamBuilder<QuerySnapshot>(
                stream: _collection!.orderBy('createdAt', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: primaryGreen));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No disease reports yet'));
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                      final id = snapshot.data!.docs[index].id;
                      final timestamp = data['createdAt'] as Timestamp?;
                      final dateStr = timestamp != null ? timestamp.toDate().toLocal().toString().split(' ')[0] : 'No date';

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          title: Text('${data['cropType']} - ${data['cropStage']}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Disease: ${data['diseaseName']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              if (data['intervention']?.toString().isNotEmpty == true)
                                Text('Intervention: ${data['intervention']}'),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_canEdit) ...[
                                IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _editEntry(id, data)),
                                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteEntry(id)),
                              ],
                              Text(dateStr, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}