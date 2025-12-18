// lib/education/field/field_data_input.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kilimomkononi/models/education_user.dart';
import 'package:kilimomkononi/education/utils/class_id_notifier.dart';
import 'package:kilimomkononi/utils/firestore_helper.dart';

const Color primaryGreen = Color(0xFF032704);

final Map<String, List<String>> cropStages = {
  'Maize': ['Germination', 'Vegetative', 'Tasseling', 'Silking', 'Grain Filling', 'Maturity'],
  'Beans': ['Germination', 'Vegetative', 'Flowering', 'Pod Formation', 'Maturity'],
  'Tomatoes': ['Seedling', 'Vegetative', 'Flowering', 'Fruit Set', 'Ripening'],
  'Carrots': ['Germination', 'Vegetative', 'Root Enlargement', 'Maturity'],
  'Cabbage': ['Seedling', 'Vegetative', 'Head Formation', 'Maturity'],
  'Onions': ['Germination', 'Bulb Initiation', 'Bulb Development', 'Maturity'],
};

final List<String> cropList = cropStages.keys.toList();

final Map<String, Map<String, Map<String, double>>> _optimalNutrients = {
  'Beans': {
    'Vegetative': {'N': 28, 'P': 45, 'K': 56},
    'Flowering': {'N': 28, 'P': 0, 'K': 56},
    'Pod Formation': {'N': 28, 'P': 0, 'K': 56},
    'Maturity': {'N': 28, 'P': 0, 'K': 56},
  },
  'Maize': {
    'Germination': {'N': 45, 'P': 28, 'K': 56},
    'Vegetative': {'N': 84, 'P': 28, 'K': 56},
    'Tasseling': {'N': 84, 'P': 28, 'K': 56},
    'Silking': {'N': 0, 'P': 0, 'K': 28},
    'Grain Filling': {'N': 0, 'P': 0, 'K': 28},
    'Maturity': {'N': 0, 'P': 0, 'K': 28},
  },
  'Tomatoes': {
    'Seedling': {'N': 100, 'P': 50, 'K': 150},
    'Vegetative': {'N': 100, 'P': 50, 'K': 150},
    'Flowering': {'N': 80, 'P': 60, 'K': 150},
    'Fruit Set': {'N': 80, 'P': 60, 'K': 150},
    'Ripening': {'N': 60, 'P': 60, 'K': 200},
  },
  'Carrots': {
    'Germination': {'N': 80, 'P': 60, 'K': 120},
    'Vegetative': {'N': 80, 'P': 60, 'K': 120},
    'Root Enlargement': {'N': 60, 'P': 80, 'K': 140},
    'Maturity': {'N': 40, 'P': 60, 'K': 140},
  },
  'Cabbage': {
    'Seedling': {'N': 120, 'P': 60, 'K': 100},
    'Vegetative': {'N': 120, 'P': 60, 'K': 100},
    'Head Formation': {'N': 100, 'P': 60, 'K': 100},
    'Maturity': {'N': 80, 'P': 60, 'K': 120},
  },
  'Onions': {
    'Germination': {'N': 90, 'P': 70, 'K': 105},
    'Bulb Initiation': {'N': 90, 'P': 70, 'K': 105},
    'Bulb Development': {'N': 0, 'P': 70, 'K': 105},
    'Maturity': {'N': 0, 'P': 0, 'K': 60},
  },
};

class FieldDataInput extends StatefulWidget {
  final EduRole role;
  final String schoolName;
  final String classId;

  const FieldDataInput({
    super.key,
    required this.role,
    required this.schoolName,
    required this.classId,
  });

  @override
  State<FieldDataInput> createState() => _FieldDataInputState();
}

class _FieldDataInputState extends State<FieldDataInput> {
  final _formKey = GlobalKey<FormState>();
  final _plotAreaCtrl = TextEditingController();
  final _nCtrl = TextEditingController();
  final _pCtrl = TextEditingController();
  final _kCtrl = TextEditingController();
  final _micronutrientsCtrl = TextEditingController();
  final _interventionsCtrl = TextEditingController();

  String? _selectedCrop;
  String? _selectedStage;
  CollectionReference? _collection;
  bool _hasValidClass = false;
  late final bool _canCreate;
  late final bool _isTeacher;
  String? _editingDocId;

  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _isTeacher = widget.role == EduRole.teacher;
    _canCreate = widget.role == EduRole.teacher || widget.role == EduRole.student;

    classIdNotifier.value = widget.classId;
    _updateCollection();
    classIdNotifier.addListener(_updateCollection);
  }

  @override
  void dispose() {
    classIdNotifier.removeListener(_updateCollection);
    _plotAreaCtrl.dispose();
    _nCtrl.dispose();
    _pCtrl.dispose();
    _kCtrl.dispose();
    _micronutrientsCtrl.dispose();
    _interventionsCtrl.dispose();
    super.dispose();
  }

  void _updateCollection() {
    final classId = classIdNotifier.value ?? widget.classId;
    if (classId.isEmpty) {
      setState(() {
        _collection = null;
        _hasValidClass = false;
      });
      return;
    }

    final collection = FirestoreHelper.getContentFromClassId(classId, 'field_data');
    setState(() {
      _collection = collection;
      _hasValidClass = collection != null;
    });
  }

  void _resetForm() {
    _formKey.currentState!.reset();
    _plotAreaCtrl.clear();
    _selectedCrop = null;
    _selectedStage = null;
    _nCtrl.clear();
    _pCtrl.clear();
    _kCtrl.clear();
    _micronutrientsCtrl.clear();
    _interventionsCtrl.clear();
    _editingDocId = null;
    setState(() {});
  }

  Future<void> _saveEntry() async {
    if (!_formKey.currentState!.validate()) return;

    await FirestoreHelper.ensureGradeExists(widget.classId);
    if (_collection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid class configuration')),
      );
      return;
    }

    final data = {
      'plotArea': _plotAreaCtrl.text.trim(),
      'cropType': _selectedCrop,
      'cropStage': _selectedStage,
      'nLevel': double.tryParse(_nCtrl.text) ?? 0,
      'pLevel': double.tryParse(_pCtrl.text) ?? 0,
      'kLevel': double.tryParse(_kCtrl.text) ?? 0,
      'micronutrients': _micronutrientsCtrl.text.trim(),
      'interventions': _interventionsCtrl.text.trim(),
      'userId': _currentUserId,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      if (_editingDocId == null) {
        await _collection!.add(data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Field data saved!'), backgroundColor: Colors.green),
        );
      } else {
        await _collection!.doc(_editingDocId).update(data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry updated!'), backgroundColor: Colors.blue),
        );
      }
      _resetForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Operation failed: $e')),
      );
    }
  }

  void _loadForEdit(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    setState(() {
      _editingDocId = doc.id;
      _plotAreaCtrl.text = data['plotArea'] ?? '';
      _selectedCrop = data['cropType'];
      _selectedStage = data['cropStage'];
      _nCtrl.text = (data['nLevel'] as num?)?.toString() ?? '';
      _pCtrl.text = (data['pLevel'] as num?)?.toString() ?? '';
      _kCtrl.text = (data['kLevel'] as num?)?.toString() ?? '';
      _micronutrientsCtrl.text = data['micronutrients'] ?? '';
      _interventionsCtrl.text = data['interventions'] ?? '';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Scrollable.ensureVisible(context);
    });
  }

  Future<void> _deleteEntry(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure you want to delete this entry? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true || _collection == null) return;

    try {
      await _collection!.doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry deleted'), backgroundColor: Colors.red),
      );
      if (_editingDocId == docId) {
        _resetForm();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  Map<String, double> _getOptimal(String crop, String stage) {
    return _optimalNutrients[crop]?[stage] ?? {'N': 0, 'P': 0, 'K': 0};
  }

  Color _getNutrientColor(double? actual, double optimal) {
    if (actual == null || actual == 0) return Colors.grey.shade400;
    if (optimal == 0) return Colors.grey;
    final diff = (actual - optimal).abs();
    final tolerance = optimal * 0.1;
    if (diff <= tolerance) return Colors.green;
    return actual < optimal ? Colors.red : Colors.orange;
  }

  Widget _buildNutrientField(String label, TextEditingController controller, double optimal) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: controller,
            enabled: _canCreate,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            validator: (v) => v?.isEmpty == true ? 'Required' : null,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Optimal: ${optimal.toStringAsFixed(0)} ppm', style: const TextStyle(fontSize: 12)),
              const Spacer(),
              Container(
                width: 100,
                height: 10,
                decoration: BoxDecoration(
                  color: _getNutrientColor(double.tryParse(controller.text), optimal),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final optimal = _selectedCrop != null && _selectedStage != null
        ? _getOptimal(_selectedCrop!, _selectedStage!)
        : {'N': 0.0, 'P': 0.0, 'K': 0.0};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Record Field Observations',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // 1. Crop Type — always visible
            DropdownButtonFormField<String>(
              initialValue: _selectedCrop,
              decoration: const InputDecoration(labelText: 'Crop Type', border: OutlineInputBorder()),
              items: cropList.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: _canCreate
                  ? (v) {
                      setState(() {
                        _selectedCrop = v;
                        _selectedStage = null;
                      });
                    }
                  : null,
              validator: (v) => v == null ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // 2. Growth Stage — the ONLY hidden field
            if (_selectedCrop != null) ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedStage,
                decoration: const InputDecoration(labelText: 'Growth Stage', border: OutlineInputBorder()),
                items: cropStages[_selectedCrop]!
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: _canCreate ? (v) => setState(() => _selectedStage = v) : null,
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),
            ],

            // 3. Plot Area — always visible, placed right after Growth Stage block
            TextFormField(
              controller: _plotAreaCtrl,
              enabled: _canCreate,
              decoration: const InputDecoration(
                labelText: 'Plot Area (e.g. Section A, Bed 3)',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 24),

            // NPK Section — always visible
            const Text('Soil Nutrient Levels (ppm)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildNutrientField('Nitrogen (N)', _nCtrl, optimal['N'] ?? 0),
                const SizedBox(width: 12),
                _buildNutrientField('Phosphorus (P)', _pCtrl, optimal['P'] ?? 0),
                const SizedBox(width: 12),
                _buildNutrientField('Potassium (K)', _kCtrl, optimal['K'] ?? 0),
              ],
            ),
            const SizedBox(height: 24),

            // Micronutrients — always visible
            TextFormField(
              controller: _micronutrientsCtrl,
              enabled: _canCreate,
              decoration: const InputDecoration(
                labelText: 'Observed Micronutrients (e.g. Iron deficiency, Zinc low)',
                border: OutlineInputBorder(),
                hintText: 'Describe any micronutrient observations',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Interventions — always visible
            TextFormField(
              controller: _interventionsCtrl,
              enabled: _canCreate,
              decoration: const InputDecoration(
                labelText: 'Interventions (e.g. fertilizer applied, pest control)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 32),

            // Save / Update Button
            if (_canCreate)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveEntry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    padding: const EdgeInsets.all(16),
                  ),
                  child: Text(
                    _editingDocId == null ? 'Save Field Data' : 'Update Entry',
                    style: const TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              )
            else
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'Headteachers can only view data. Students and teachers can submit entries.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            if (_editingDocId != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: _resetForm,
                child: const Text('Cancel Editing', style: TextStyle(color: Colors.red)),
              ),
            ],

            const SizedBox(height: 40),
            const Text('Recent Entries (This Class)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Divider(),

            if (!_hasValidClass)
              const Center(child: Text('No class selected.'))
            else if (_collection == null)
              const Center(child: Text('Invalid class configuration'))
            else
              StreamBuilder<QuerySnapshot>(
                stream: _collection!.orderBy('createdAt', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: primaryGreen));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No entries yet'));
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (_, i) {
                      final doc = snapshot.data!.docs[i];
                      final data = doc.data() as Map<String, dynamic>;
                      final entryUserId = data['userId'] as String?;

                      final bool canEditThis = _isTeacher || entryUserId == _currentUserId;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: primaryGreen,
                            child: Text(
                              (data['cropType'] as String?)?.substring(0, 1).toUpperCase() ?? '?',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text('${data['cropType'] ?? 'Unknown'} - ${data['cropStage'] ?? 'Unknown'}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Plot: ${data['plotArea'] ?? 'N/A'}'),
                              if (data['interventions']?.toString().isNotEmpty == true)
                                Text('Interventions: ${data['interventions']}'),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                (data['createdAt'] as Timestamp?)?.toDate().toLocal().toString().split(' ')[0] ?? '',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              if (canEditThis) ...[
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  tooltip: 'Edit',
                                  onPressed: () => _loadForEdit(doc),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  tooltip: 'Delete',
                                  onPressed: () => _deleteEntry(doc.id),
                                ),
                              ],
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