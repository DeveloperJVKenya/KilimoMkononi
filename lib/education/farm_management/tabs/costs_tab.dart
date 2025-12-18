// lib/education/farm_management/tabs/costs_tab.dart
import 'package:flutter/material.dart';
import 'package:kilimomkononi/education/farm_management/widgets/cost_form_card.dart';

class CostsTab extends StatelessWidget {
  final String classId;
  final String schoolName;

  const CostsTab({super.key, required this.classId, required this.schoolName});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          CostFormCard(title: 'Labour Costs', icon: Icons.people, hint: 'e.g., Planting', type: 'labour', classId: classId, schoolName: schoolName),
          CostFormCard(title: 'Equipment Costs', icon: Icons.agriculture, hint: 'e.g., Tractor', type: 'mechanical', classId: classId, schoolName: schoolName),
          CostFormCard(title: 'Input Costs', icon: Icons.local_florist, hint: 'e.g., Fertilizer', type: 'input', classId: classId, schoolName: schoolName),
          CostFormCard(title: 'Miscellaneous', icon: Icons.miscellaneous_services, hint: 'e.g., Transport', type: 'misc', classId: classId, schoolName: schoolName),
        ],
      ),
    );
  }
}