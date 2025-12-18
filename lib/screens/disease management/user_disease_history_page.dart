import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kilimomkononi/screens/disease%20management/disease_model.dart';
import 'package:logger/logger.dart';

class UserDiseaseHistoryPage extends StatefulWidget {
  const UserDiseaseHistoryPage({super.key});

  @override
  State<UserDiseaseHistoryPage> createState() => _UserDiseaseHistoryPageState();
}

class _UserDiseaseHistoryPageState extends State<UserDiseaseHistoryPage> {
  final _logger = Logger();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Disease Management History', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: const Color.fromARGB(255, 3, 39, 4),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Please log in to view history.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Disease Management History', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromARGB(255, 3, 39, 4),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('diseaseinterventiondata')
            .where('userId', isEqualTo: user.uid)
            .where('isDeleted', isEqualTo: false)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            _logger.e('Error fetching history: ${snapshot.error}');
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No disease management history available.'));
          }

          final interventions = snapshot.data!.docs.map((doc) {
            try {
              return DiseaseIntervention.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>, null);
            } catch (e) {
              _logger.e('Error parsing intervention ${doc.id}: $e');
              return null;
            }
          }).where((item) => item != null).cast<DiseaseIntervention>().toList();

          return Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.all(16.0),
            child: ListView.builder(
              itemCount: interventions.length,
              itemBuilder: (context, index) {
                final intervention = interventions[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Disease: ${intervention.diseaseName}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text('Crop: ${intervention.cropType}'),
                        Text('Stage: ${intervention.cropStage}'),
                        Text('Intervention: ${intervention.intervention}'),
                        if (intervention.dosage != null) Text('Dosage: ${intervention.dosage} ${intervention.unit ?? ''}'),
                        if (intervention.area != null) Text('Area: ${intervention.area} ${intervention.areaUnit}'),
                        Text('Date: ${intervention.timestamp.toDate().toString().split(' ')[0]}'),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editIntervention(intervention),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteIntervention(intervention),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _editIntervention(DiseaseIntervention intervention) async {
    final controller = TextEditingController(text: intervention.intervention);
    final dosageController = TextEditingController(text: intervention.dosage?.toString() ?? '');
    final unitController = TextEditingController(text: intervention.unit ?? '');
    final areaController = TextEditingController(text: intervention.area?.toString() ?? '');
    bool useSQM = intervention.areaUnit == 'SQM';

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Intervention'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: controller,
                decoration: const InputDecoration(labelText: 'Intervention Details'),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter intervention details';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: dosageController,
                decoration: const InputDecoration(labelText: 'Dosage (Optional)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: unitController,
                decoration: const InputDecoration(labelText: 'Unit (Optional)'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: areaController,
                decoration: const InputDecoration(labelText: 'Area (Optional)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Area Unit:'),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('SQM'),
                    selected: useSQM,
                    onSelected: (selected) {
                      if (selected) useSQM = true;
                      (dialogContext as StatefulElement).markNeedsBuild();
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Acres'),
                    selected: !useSQM,
                    onSelected: (selected) {
                      if (selected) useSQM = false;
                      (dialogContext as StatefulElement).markNeedsBuild();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      try {
        await FirebaseFirestore.instance.collection('diseaseinterventiondata').doc(intervention.id).update({
          'intervention': controller.text,
          'dosage': dosageController.text.isNotEmpty ? double.tryParse(dosageController.text) : null,
          'unit': unitController.text.isNotEmpty ? unitController.text : null,
          'area': areaController.text.isNotEmpty ? double.tryParse(areaController.text) : null,
          'areaUnit': useSQM ? 'SQM' : 'Acres',
        });

        await FirebaseFirestore.instance.collection('User_logs').add({
          'userId': intervention.userId,
          'action': 'edit',
          'collection': 'diseaseinterventiondata',
          'documentId': intervention.id,
          'timestamp': Timestamp.now(),
          'details': 'Updated intervention for ${intervention.diseaseName}',
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Intervention updated successfully')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating intervention: $e')));
        }
      }
    }
  }

  Future<void> _deleteIntervention(DiseaseIntervention intervention) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to delete this intervention? It can be restored by an admin.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await FirebaseFirestore.instance.collection('diseaseinterventiondata').doc(intervention.id).update({
          'isDeleted': true,
        });

        await FirebaseFirestore.instance.collection('User_logs').add({
          'userId': intervention.userId,
          'action': 'delete',
          'collection': 'diseaseinterventiondata',
          'documentId': intervention.id,
          'timestamp': Timestamp.now(),
          'details': 'Soft-deleted intervention for ${intervention.diseaseName}',
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Intervention deleted successfully')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting intervention: $e')));
        }
      }
    }
  }
}