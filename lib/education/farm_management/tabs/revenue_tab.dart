// lib/education/farm_management/tabs/revenue_tab.dart
import 'package:flutter/material.dart';
import 'package:kilimomkononi/education/farm_management/services/farm_management_service.dart';
import 'package:kilimomkononi/education/farm_management/widgets/revenue_form_card.dart';

class RevenueTab extends StatelessWidget {
  final String classId;
  final String schoolName;

  const RevenueTab({
    super.key,
    required this.classId,
    required this.schoolName,
  });

  @override
  Widget build(BuildContext context) {
    final service = FarmManagementService();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          RevenueFormCard(
            classId: classId,
            schoolName: schoolName,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _RevenueList(
              service: service,
              classId: classId,
              schoolName: schoolName,
            ),
          ),
        ],
      ),
    );
  }
}

class _RevenueList extends StatelessWidget {
  final FarmManagementService service;
  final String classId;
  final String schoolName;

  const _RevenueList({
    required this.service,
    required this.classId,
    required this.schoolName,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: service.getContent(
        classId: classId,
        schoolName: schoolName,
        type: 'revenue',
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final revenues = (snapshot.data ?? []);

        if (revenues.isEmpty) {
          return const Center(child: Text('No revenue recorded.'));
        }

        return ListView.builder(
          itemCount: revenues.length,
          itemBuilder: (context, index) {
            final rev = revenues[index];
            final data = rev['data'] as Map<String, dynamic>;
            return Card(
              child: ListTile(
                title: Text(data['source'] ?? 'Revenue ${index + 1}'),
                subtitle: Text(
                  'Amount: KES ${data['amount']}\n'
                  'Date: ${data['date']}',
                ),
                trailing: const Icon(Icons.monetization_on),
              ),
            );
          },
        );
      },
    );
  }
}