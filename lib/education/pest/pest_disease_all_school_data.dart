// lib/education/pest/pest_disease_all_school_data.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kilimomkononi/utils/firestore_helper.dart';

const Color primaryGreen = Color(0xFF032704);

class PestDiseaseAllSchoolData extends StatefulWidget {
  final String schoolName;
  final String contentType; // 'pest_data' or 'disease_data'

  const PestDiseaseAllSchoolData({
    super.key,
    required this.schoolName,
    required this.contentType,
  });

  @override
  State<PestDiseaseAllSchoolData> createState() => _PestDiseaseAllSchoolDataState();
}

class _PestDiseaseAllSchoolDataState extends State<PestDiseaseAllSchoolData> {
  String _normalizedSchoolName = '';
  List<String> _availableClasses = [];
  String? _selectedClassId;

  @override
  void initState() {
    super.initState();
    _normalizedSchoolName = widget.schoolName.trim().replaceAll(' ', '_');
    _loadAvailableClasses();
  }

  Future<void> _loadAvailableClasses() async {
    final systemsColl = FirestoreHelper.getSystemsCollection(_normalizedSchoolName);
    final systemsSnap = await systemsColl.get();

    List<String> classes = [];

    for (var systemDoc in systemsSnap.docs) {
      final system = systemDoc.id;
      final gradesColl = FirestoreHelper.getGradesCollection(_normalizedSchoolName, system);
      final gradesSnap = await gradesColl.get();

      for (var gradeDoc in gradesSnap.docs) {
        final grade = gradeDoc.id;
        final fullClassId = '${_normalizedSchoolName}_${system}_$grade';
        classes.add(fullClassId);
      }
    }

    setState(() {
      _availableClasses = classes;
      if (classes.isNotEmpty && _selectedClassId == null) {
        _selectedClassId = classes.first;
      }
    });
  }

  CollectionReference? get _selectedCollection {
    if (_selectedClassId == null) return null;
    return FirestoreHelper.getContentFromClassId(_selectedClassId!, widget.contentType);
  }

  String get _title => widget.contentType == 'pest_data' ? 'Pest' : 'Disease';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: primaryGreen.withValues(alpha: 0.1),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: primaryGreen, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Select a class to view all $_title entries from that class.',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryGreen),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          if (_availableClasses.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedClassId,
                decoration: const InputDecoration(
                  labelText: 'Select Class',
                  border: OutlineInputBorder(),
                ),
                items: _availableClasses.map((id) {
                  return DropdownMenuItem(value: id, child: Text(id.replaceAll('_', ' ')));
                }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedClassId = value);
                },
              ),
            ),

          Text('$_title Entries', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryGreen)),
          const Divider(height: 32),

          Expanded(
            child: _selectedCollection == null
                ? const Center(child: Text('No class selected', style: TextStyle(fontSize: 16, color: Colors.grey)))
                : StreamBuilder<QuerySnapshot>(
                    stream: _selectedCollection!.orderBy('createdAt', descending: true).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: primaryGreen));
                      }
                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return Center(child: Text('No $_title entries yet for this class.', style: TextStyle(fontSize: 16, color: Colors.grey)));
                      }

                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          final timestamp = data['createdAt'] as Timestamp?;
                          final dateStr = timestamp != null ? timestamp.toDate().toLocal().toString().split(' ')[0] : 'No date';

                          final itemName = data[widget.contentType == 'pest_data' ? 'pestName' : 'diseaseName'] ?? 'Unknown';

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            elevation: 3,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: primaryGreen,
                                child: Icon(widget.contentType == 'pest_data' ? Icons.bug_report : Icons.local_hospital, color: Colors.white),
                              ),
                              title: Text('${data['cropType'] ?? 'Unknown'} - ${data['cropStage'] ?? 'Unknown'}'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('$_title: $itemName', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  if (data['intervention']?.isNotEmpty == true)
                                    Text('Intervention: ${data['intervention']}'),
                                ],
                              ),
                              trailing: Text(dateStr, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}