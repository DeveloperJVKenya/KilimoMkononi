import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:kilimomkononi/models/disease_model.dart';
import 'package:timezone/timezone.dart' as tz;

class ViewDiseaseInterventionsPage extends StatefulWidget {
  final DiseaseData diseaseData;
  final FlutterLocalNotificationsPlugin notificationsPlugin;

  const ViewDiseaseInterventionsPage({
    required this.diseaseData,
    required this.notificationsPlugin,
    super.key,
  });

  @override
  State<ViewDiseaseInterventionsPage> createState() => _ViewDiseaseInterventionsPageState();
}

class _ViewDiseaseInterventionsPageState extends State<ViewDiseaseInterventionsPage> {
  List<DiseaseIntervention> _interventions = [];

  @override
  void initState() {
    super.initState();
    _loadInterventions();
  }

  Future<void> _loadInterventions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('diseaseinterventiondata')
        .doc(user.uid)
        .collection('interventions')
        .where('diseaseName', isEqualTo: widget.diseaseData.name)
        .get();
    setState(() {
      _interventions = snapshot.docs.map((doc) => DiseaseIntervention.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Future<void> _editIntervention(DiseaseIntervention intervention) async {
    final controller = TextEditingController(text: intervention.intervention);
    final dosageController = TextEditingController(text: intervention.dosage.toString());
    final unitController = TextEditingController(text: intervention.unit);
    final areaController = TextEditingController(text: intervention.area.toString());
    bool useSQM = intervention.areaUnit == 'SQM';

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Intervention'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: 'Intervention Used'),
              ),
              TextField(
                controller: dosageController,
                decoration: const InputDecoration(labelText: 'Dosage Applied'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: unitController,
                decoration: const InputDecoration(labelText: 'Unit'),
              ),
              TextField(
                controller: areaController,
                decoration: const InputDecoration(labelText: 'Total Area Affected'),
                keyboardType: TextInputType.number,
              ),
              SwitchListTile(
                title: const Text('Use SQM'),
                value: useSQM,
                onChanged: (value) => setState(() => useSQM = value),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final updatedIntervention = intervention.copyWith(
        intervention: controller.text,
        dosage: dosageController.text.isNotEmpty ? double.parse(dosageController.text) : null,
        unit: unitController.text.isNotEmpty ? unitController.text : null,
        area: areaController.text.isNotEmpty ? double.parse(areaController.text) : null,
        areaUnit: useSQM ? 'SQM' : 'Acres',
      );

      final user = FirebaseAuth.instance.currentUser;
      try {
        await FirebaseFirestore.instance
            .collection('diseaseinterventiondata')
            .doc(user!.uid)
            .collection('interventions')
            .doc(intervention.id)
            .set(updatedIntervention.toMap());
        if (mounted) {
          scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Intervention updated successfully')));
          setState(() {
            _interventions[_interventions.indexWhere((i) => i.id == intervention.id)] = updatedIntervention;
          });
        }
      } catch (e) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error updating intervention: $e')));
        }
      }
    }
  }

  Future<void> _deleteIntervention(DiseaseIntervention intervention) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to delete this intervention?'),
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
      final user = FirebaseAuth.instance.currentUser;
      try {
        await FirebaseFirestore.instance
            .collection('diseaseinterventiondata')
            .doc(user!.uid)
            .collection('interventions')
            .doc(intervention.id)
            .delete();
        if (mounted) {
          scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Intervention deleted successfully')));
          setState(() {
            _interventions.removeWhere((i) => i.id == intervention.id);
          });
        }
      } catch (e) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error deleting intervention: $e')));
        }
      }
    }
  }

  Future<void> _scheduleFollowUp(DiseaseIntervention intervention) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    DateTime? date = DateTime.now().add(const Duration(days: 7));

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Follow-Up Reminder'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('Date: ${date!.toString().substring(0, 10)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date!,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => date = picked);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, {'date': date}),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      final tzDateTime = tz.TZDateTime.from(result['date'] as DateTime, tz.local);
      const androidDetails = AndroidNotificationDetails(
        'disease_followup_channel',
        'Disease Follow-Up Reminders',
        channelDescription: 'Reminders for disease intervention follow-ups',
        importance: Importance.max,
        priority: Priority.high,
      );
      const notificationDetails = NotificationDetails(android: androidDetails);

      try {
        await widget.notificationsPlugin.zonedSchedule(
          intervention.id.hashCode,
          'Follow-Up for ${widget.diseaseData.name}',
          'Evaluate effectiveness of ${intervention.intervention}',
          tzDateTime,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
        if (mounted) {
          scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Follow-up reminder scheduled')));
        }
      } catch (e) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error scheduling reminder: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Disease Interventions', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromARGB(255, 3, 39, 4),
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: Colors.grey[200],
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: _interventions.length,
          itemBuilder: (context, index) {
            final intervention = _interventions[index];
            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                title: Text(intervention.intervention.isNotEmpty ? intervention.intervention : 'No intervention specified'),
                subtitle: Text(
                  'Dosage: ${intervention.dosage} ${intervention.unit}, Area: ${intervention.area} ${intervention.areaUnit}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _editIntervention(intervention),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteIntervention(intervention),
                    ),
                    IconButton(
                      icon: const Icon(Icons.alarm, color: Colors.green),
                      onPressed: () => _scheduleFollowUp(intervention),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}