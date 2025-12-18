// lib/education/farm_management/tabs/profit_loss_tab.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ProfitLossTab extends StatelessWidget {
  final String classId;
  const ProfitLossTab({super.key, required this.classId});

  String get schoolId => classId.split('_').first;
  String get gradeId => classId.split('_').last;

  CollectionReference get collection => FirebaseFirestore.instance
      .collection('schools')
      .doc(schoolId)
      .collection('grades')
      .doc(gradeId)
      .collection('farm_management_data');

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // ← SAFE: No orderBy at all → works 100% even with pending server timestamps
      stream: collection.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading data', style: TextStyle(fontSize: 18)));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('No financial records yet', style: TextStyle(fontSize: 20)),
          );
        }

        double totalCost = 0;
        double totalRevenue = 0;

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
          if (data['type'] == 'cost') {
            totalCost += amount;
          } else if (data['type'] == 'revenue') {
            totalRevenue += amount;
          }
        }

        final profit = totalRevenue - totalCost;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 10,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  const Text(
                    'Profit & Loss Statement',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF003900)),
                  ),
                  const SizedBox(height: 50),

                  _summaryRow('Total Revenue', totalRevenue, Colors.green.shade700),
                  _summaryRow('Total Costs', totalCost, Colors.red.shade700),
                  const Divider(thickness: 3, height: 60),
                  _summaryRow(
                    'NET PROFIT',
                    profit,
                    profit >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                    size: 32,
                    bold: true,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    profit >= 0 ? 'Congratulations! You made a profit 🎉' : 'You incurred a loss this period',
                    style: TextStyle(
                      fontSize: 18,
                      color: profit >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _summaryRow(String label, double value, Color color, {double size = 26, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: size, fontWeight: bold ? FontWeight.bold : FontWeight.w600),
          ),
          Text(
            'KES ${value.toStringAsFixed(0)}',
            style: TextStyle(fontSize: size, fontWeight: bold ? FontWeight.bold : FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}