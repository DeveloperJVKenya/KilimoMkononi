import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kilimomkononi/models/field_data_model.dart';

class PlotSummaryTab extends StatefulWidget {
  final String userId;

  const PlotSummaryTab({required this.userId, super.key});

  @override
  State<PlotSummaryTab> createState() => _PlotSummaryTabState();
}

class _PlotSummaryTabState extends State<PlotSummaryTab> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 3, 39, 4),
        title: const Text(
          'Plot Summary',
          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('fielddata')
            .where('userId', isEqualTo: widget.userId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error state
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Unable to load saved data. Please try again later.',
                style: TextStyle(fontSize: 16, color: Colors.red),
                textAlign: TextAlign.center,
              ),
            );
          }

          // No data state
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No saved data available. Please save data to view your history.',
                style: TextStyle(fontSize: 16, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            );
          }

          // Data available state
          final entries = snapshot.data!.docs
              .map((doc) => FieldData.fromMap(doc.data() as Map<String, dynamic>))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _buildPlotCard(entry, snapshot.data!.docs[index].id);
            },
          );
        },
      ),
    );
  }

  Widget _buildPlotCard(FieldData entry, String docId) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ExpansionTile(
        title: Text(
          '${entry.plotId} - ${entry.timestamp.toDate().toString().substring(0, 16)}',
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(255, 3, 39, 4)),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _editPlot(context, entry, docId),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deletePlot(context, docId),
                    ),
                  ],
                ),
                _buildFieldRow('Structure Type', entry.structureType),
                _buildFieldRow(
                    'Crops',
                    entry.crops.isNotEmpty
                        ? entry.crops.map((c) => '${c['type']} (${c['stage']})').join(', ')
                        : 'None'),
                _buildFieldRow('Area', entry.area != null ? '${entry.area} Acres' : 'None'),
                _buildFieldRow('Nitrogen (N)', entry.npk['N'] != null ? '${entry.npk['N']}' : 'None'),
                _buildFieldRow('Phosphorus (P)', entry.npk['P'] != null ? '${entry.npk['P']}' : 'None'),
                _buildFieldRow('Potassium (K)', entry.npk['K'] != null ? '${entry.npk['K']}' : 'None'),
                _buildFieldRow('Micro-Nutrients',
                    entry.microNutrients.isNotEmpty ? entry.microNutrients.join(', ') : 'None'),
                _buildFieldRow(
                    'Interventions',
                    entry.interventions.isNotEmpty
                        ? entry.interventions
                            .map((i) => '${i['type']} (${i['quantity']} ${i['unit']})')
                            .join(', ')
                        : 'None'),
                _buildFieldRow(
                    'Reminders',
                    entry.reminders.isNotEmpty
                        ? entry.reminders
                            .map((r) =>
                                '${r['activity']} (${r['date'].toDate().toString().substring(0, 10)})')
                            .join(', ')
                        : 'None'),
                _buildFieldRow('Fertilizer Recommendation',
                    entry.fertilizerRecommendation ?? 'None'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontSize: 16, color: Colors.black))),
        ],
      ),
    );
  }

  Future<void> _editPlot(BuildContext context, FieldData plot, String docId) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final List<TextEditingController> cropControllers =
        plot.crops.map((c) => TextEditingController(text: c['type'])).toList();
    final List<TextEditingController> stageControllers =
        plot.crops.map((c) => TextEditingController(text: c['stage'])).toList();
    final TextEditingController areaController =
        TextEditingController(text: plot.area?.toString());
    final TextEditingController nitrogenController =
        TextEditingController(text: plot.npk['N']?.toString());
    final TextEditingController phosphorusController =
        TextEditingController(text: plot.npk['P']?.toString());
    final TextEditingController potassiumController =
        TextEditingController(text: plot.npk['K']?.toString());
    final List<TextEditingController> microNutrientControllers = plot.microNutrients
        .map((m) => TextEditingController(text: m))
        .toList()
      ..add(TextEditingController());

    List<Map<String, String>> editedCrops = List.from(plot.crops);
    List<String> editedMicroNutrients = List.from(plot.microNutrients);
    List<Map<String, dynamic>> editedInterventions = List.from(plot.interventions);
    List<Map<String, dynamic>> editedReminders = List.from(plot.reminders);

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Edit ${plot.plotId} Entry'),
        content: StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...cropControllers.asMap().entries.map((entry) {
                  int idx = entry.key;
                  return Column(
                    children: [
                      TextField(
                        controller: cropControllers[idx],
                        decoration: const InputDecoration(labelText: 'Crop Type'),
                      ),
                      TextField(
                        controller: stageControllers[idx],
                        decoration: const InputDecoration(labelText: 'Crop Stage'),
                      ),
                      const SizedBox(height: 8),
                    ],
                  );
                }),
                if (plot.structureType == 'intercrop')
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        cropControllers.add(TextEditingController());
                        stageControllers.add(TextEditingController());
                        editedCrops.add({'type': '', 'stage': ''});
                      });
                    },
                    child: const Text('+ Additional Crop'),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: areaController,
                  decoration: const InputDecoration(labelText: 'Area (Acres)'),
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nitrogenController,
                  decoration: const InputDecoration(labelText: 'Nitrogen (N)'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: phosphorusController,
                  decoration: const InputDecoration(labelText: 'Phosphorus (P)'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: potassiumController,
                  decoration: const InputDecoration(labelText: 'Potassium (K)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                Column(
                  children: microNutrientControllers.map((controller) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: TextField(
                      controller: controller,
                      decoration: const InputDecoration(labelText: 'Micro-Nutrient'),
                      onSubmitted: (value) {
                        if (value.isNotEmpty && !editedMicroNutrients.contains(value)) {
                          setState(() => editedMicroNutrients.add(value));
                        }
                      },
                    ),
                  )).toList(),
                ),
                ElevatedButton(
                  onPressed: () =>
                      setState(() => microNutrientControllers.add(TextEditingController())),
                  child: const Text('Add Another Micro-Nutrient'),
                ),
                Wrap(
                  spacing: 8,
                  children: editedMicroNutrients
                      .map((m) => Chip(
                            label: Text(m),
                            onDeleted: () =>
                                setState(() => editedMicroNutrients.remove(m)),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              editedMicroNutrients = microNutrientControllers
                  .map((c) => c.text.trim())
                  .where((t) => t.isNotEmpty)
                  .toList();
              editedCrops = cropControllers.asMap().entries.map((entry) {
                int idx = entry.key;
                return {
                  'type': cropControllers[idx].text,
                  'stage': stageControllers[idx].text,
                };
              }).where((c) => c['type']!.isNotEmpty).toList();
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final updatedFieldData = FieldData(
        userId: widget.userId,
        plotId: plot.plotId,
        crops: editedCrops,
        area: areaController.text.isNotEmpty ? double.parse(areaController.text) : null,
        npk: {
          'N': nitrogenController.text.isNotEmpty
              ? double.parse(nitrogenController.text)
              : null,
          'P': phosphorusController.text.isNotEmpty
              ? double.parse(phosphorusController.text)
              : null,
          'K': potassiumController.text.isNotEmpty
              ? double.parse(potassiumController.text)
              : null,
        },
        microNutrients: editedMicroNutrients,
        interventions: editedInterventions,
        reminders: editedReminders,
        timestamp: Timestamp.now(),
        structureType: plot.structureType,
        fertilizerRecommendation: plot.fertilizerRecommendation,
      );

      try {
        await FirebaseFirestore.instance
            .collection('fielddata')
            .doc(docId)
            .set(updatedFieldData.toMap());
        if (mounted) {
          scaffoldMessenger
              .showSnackBar(const SnackBar(content: Text('Entry updated successfully')));
        }
      } catch (e) {
        if (mounted) {
          scaffoldMessenger
              .showSnackBar(SnackBar(content: Text('Error updating entry: $e')));
        }
      }
    }
  }

  Future<void> _deletePlot(BuildContext context, String docId) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to delete this entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await FirebaseFirestore.instance.collection('fielddata').doc(docId).delete();
        if (mounted) {
          messenger
              .showSnackBar(const SnackBar(content: Text('Entry deleted successfully')));
        }
      } catch (e) {
        if (mounted) {
          messenger
              .showSnackBar(SnackBar(content: Text('Error deleting entry: $e')));
        }
      }
    }
  }
}