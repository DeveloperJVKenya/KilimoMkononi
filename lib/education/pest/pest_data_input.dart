// lib/education/pest/pest_data_input.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kilimomkononi/models/education_user.dart';
import 'package:kilimomkononi/utils/firestore_helper.dart';

const Color primaryGreen = Color(0xFF388E3C);

final List<String> crops = ['Beans', 'Maize', 'Cabbage', 'Carrots', 'Tomatoes', 'Onions'];

final Map<String, List<String>> cropStages = {
  'Beans': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Flowering/Reproductive', 'Maturation/Harvesting', 'Storage'],
  'Maize': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Flowering/Reproductive', 'Maturation/Harvesting', 'Storage'],
  'Cabbage': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Flowering/Reproductive', 'Maturation/Harvesting', 'Storage'],
  'Carrots': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Maturation/Harvesting', 'Storage'],
  'Tomatoes': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Flowering/Reproductive', 'Maturation/Harvesting', 'Storage'],
  'Onions': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Bulb Formation/Reproductive', 'Bulbing/Maturation', 'Harvesting/Storage'],
};

final Map<String, Map<String, List<String>>> cropStagePests = {
  'Beans': {
    'Germination/Seedling': ['Bean Fly', 'Cutworms', 'Rodents', 'Termites'],
    'Vegetative Growth/Weeding': ['Aphids', 'Leafhoppers', 'Thrips', 'Whiteflies', 'Beetles', 'Rodents'],
    'Flowering/Reproductive': ['Aphids', 'Leafhoppers', 'Thrips', 'Pod Borers', 'Whiteflies'],
    'Maturation/Harvesting': ['Pod Borers', 'Beetles', 'Bean Weevil', 'Bruchid Beetles', 'Rodents'],
    'Storage': ['Bean Weevil', 'Bruchid Beetles', 'Rodents'],
  },
  'Maize': {
    'Germination/Seedling': ['Termites', 'Cutworms', 'Maize Shoot Fly', 'Rodents'],
    'Vegetative Growth/Weeding': ['Aphids', 'Stem Borers', 'Armyworms', 'Leafhoppers', 'Grasshoppers', 'Thrips', 'Rodents'],
    'Flowering/Reproductive': ['Aphids', 'Stem Borers', 'Armyworms', 'Leafhoppers', 'Grasshoppers', 'Earworms', 'Thrips', 'Birds'],
    'Maturation/Harvesting': ['Earworms', 'Weevils', 'Birds', 'Rodents'],
    'Storage': ['Larger Grain Borer', 'Angoumois Grain Moth', 'Weevils', 'Rodents'],
  },
  'Cabbage': {
    'Germination/Seedling': ['Termites', 'Cutworms', 'Root Maggots', 'Flea Beetles'],
    'Vegetative Growth/Weeding': ['Aphids', 'Whiteflies', 'Cross Stripped Cabbageworm', 'Diamondback Moth', 'Cabbage Looper', 'Cutworms', 'Flea Beetles', 'Cabbage Webworm', 'Armyworms', 'Cabbage Root Maggot', 'Rodents'],
    'Flowering/Reproductive': ['Aphids', 'Whiteflies', 'Thrip', 'Diamondback Moth', 'Cabbage Looper', 'Armyworm', 'Stink Bug'],
    'Maturation/Harvesting': ['Diamondback Moth', 'Cabbage Looper', 'Leafminers', 'Flea Beetle', 'Cabbage Webworm', 'Armyworm', 'Stink Bug', 'Rodent'],
    'Storage': ['Rodents', 'Aphids', 'Whiteflies'],
  },
  'Carrots': {
    'Germination/Seedling': ['Termites', 'Cutworms', 'Carrot Rust Fly', 'Nematodes', 'Wireworms', 'Rodents'],
    'Vegetative Growth/Weeding': ['Aphids', 'Whiteflies', 'Thrips', 'Leaf Loopers', 'Leafminers', 'Carrot Rust Fly', 'Nematodes', 'Wireworms', 'Armyworms', 'Rodents'],
    'Maturation/Harvesting': ['Aphids', 'White Flies', 'Thrips', 'Leaf Loopers', 'Leaf Miners', 'Carrot Rust Fly', 'Nematodes', 'Wireworms', 'Armyworms', 'Rodents'],
    'Storage': ['Carrot Rust Fly', 'Nematodes', 'Rodents', 'Aphids'],
  },
  'Tomatoes': {
    'Germination/Seedling': ['Cutworms', 'Termites', 'Rodents', 'Nematodes'],
    'Vegetative Growth/Weeding': ['Aphids', 'Whiteflies', 'Thrips', 'Leafminers', 'Spider Mites', 'Tomato Hornworms', 'Beet Armyworm', 'Nematodes', 'Rodents'],
    'Flowering/Reproductive': ['Aphids', 'Whiteflies', 'Thrips', 'Leafminers', 'Spider Mites', 'Tomato Hornworms', 'Stink Bugs', 'Beet Armyworm', 'Nematodes', 'Rodents', 'Fruit Borers', 'Bollworms'],
    'Maturation/Harvesting': ['Fruitflies', 'Stink Bugs', 'Rodents', 'Fruit Borers', 'Bollworms', 'Beet Armyworm', 'Leafminers', 'Aphids', 'Whiteflies', 'Thrips', 'Spider Mites', 'Nematodes', 'Tomato Hornworms'],
    'Storage': ['Fruit Flies', 'Fruit Borers', 'Stink Bugs', 'Rodents'],
  },
  'Onions': {
    'Germination/Seedling': ['Aphids', 'Thrips'],
    'Vegetative Growth/Weeding': ['Thrips', 'Aphids'],
    'Bulb Formation/Reproductive': ['Bulb Fly', 'Maggots'],
    'Bulbing/Maturation': ['Maggots', 'Thrips', 'Bulb Fly'],
    'Harvesting/Storage': ['Maggots', 'Rodents', 'Bulb Fly'],
  },
};

final Map<String, Map<String, dynamic>> pestDetails = {
  // All your original pestDetails entries with image paths
  'Beans_Germination/Seedling_Bean Fly': {'imagePath': 'assets/pests/beans_bean_fly_germination.jpg'},
  'Beans_Germination/Seedling_Cutworms': {'imagePath': 'assets/pests/beans_cutworms_germination.jpg'},
  'Beans_Germination/Seedling_Rodents': {'imagePath': 'assets/pests/beans_rodents_germination.jpg'},
  'Beans_Germination/Seedling_Termites': {'imagePath': 'assets/pests/beans_termites_germination.jpg'},
  // ... (all other entries exactly as in your original code)
  'Onions_Harvesting/Storage_Bulb Fly': {'imagePath': 'assets/pests/onions_bulb_fly_storage.jpg'},
};

class PestDataInput extends StatefulWidget {
  final EduRole role;
  final String schoolName;
  final String classId;
  final Map<String, String>? prefillData;

  const PestDataInput({
    super.key,
    required this.role,
    required this.schoolName,
    required this.classId,
    this.prefillData,
  });

  @override
  State<PestDataInput> createState() => _PestDataInputState();
}

class _PestDataInputState extends State<PestDataInput> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  final _interventionCtrl = TextEditingController();

  String? _selectedCrop;
  String? _selectedStage;
  String? _selectedPest;
  String? _editingId;

  @override
  void initState() {
    super.initState();
    if (widget.prefillData != null) {
      _selectedCrop = widget.prefillData!['crop'];
      _selectedStage = widget.prefillData!['stage'];
      _selectedPest = widget.prefillData!['name'];
    }
  }

  CollectionReference? get _collection {
    if (widget.classId.isEmpty) return null;
    return FirestoreHelper.getContentFromClassId(widget.classId, 'pest_data');
  }

  bool get _isHeadteacher => widget.role == EduRole.headteacher;
  bool get _canEdit => !_isHeadteacher && _collection != null;

  Future<void> _saveEntry() async {
    if (!_canEdit || !_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final data = {
      'cropType': _selectedCrop,
      'cropStage': _selectedStage,
      'pestName': _selectedPest,
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
        SnackBar(content: Text(_editingId == null ? 'Pest entry saved!' : 'Entry updated!'), backgroundColor: Colors.green),
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
      _selectedPest = data['pestName'];
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
      _selectedPest = null;
      _interventionCtrl.clear();
    });
    _formKey.currentState?.reset();
  }

  @override
  Widget build(BuildContext context) {
    String? imagePath;
    if (_selectedCrop != null && _selectedStage != null && _selectedPest != null) {
      final key = '${_selectedCrop}_${_selectedStage}_$_selectedPest';
      imagePath = pestDetails[key]?['imagePath'] as String? ?? 'assets/pests/default.jpg';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isHeadteacher ? 'Pest Observation Form (View Only)' : 'Report Pest Observation',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryGreen),
            ),
            const SizedBox(height: 24),

            DropdownButtonFormField<String>(
              value: _selectedCrop,
              decoration: const InputDecoration(labelText: 'Crop Affected', border: OutlineInputBorder()),
              items: crops.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: _canEdit
                  ? (v) => setState(() {
                        _selectedCrop = v;
                        _selectedStage = null;
                        _selectedPest = null;
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
                        _selectedPest = null;
                      })
                  : null,
              validator: _canEdit ? (v) => v == null ? 'Required' : null : null,
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _selectedPest,
              decoration: const InputDecoration(labelText: 'Pest Observed', border: OutlineInputBorder()),
              items: _selectedCrop == null || _selectedStage == null
                  ? []
                  : cropStagePests[_selectedCrop]![_selectedStage]!
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
              onChanged: _canEdit ? (v) => setState(() => _selectedPest = v) : null,
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
              decoration: const InputDecoration(labelText: 'Intervention Taken (optional)', border: OutlineInputBorder()),
              maxLines: 3,
              enabled: _canEdit,
            ),

            const SizedBox(height: 32),
            if (_canEdit)
              Center(
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveEntry,
                  icon: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.send),
                  label: Text(_editingId == null ? 'Submit Report' : 'Update Entry'),
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
            const Text('Recent Pest Entries', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryGreen)),
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
                    return const Center(child: Text('No pest reports yet'));
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
                              Text('Pest: ${data['pestName']}', style: const TextStyle(fontWeight: FontWeight.bold)),
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