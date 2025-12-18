// lib/education/farm_management/tabs/dashboard_tab.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class DashboardTab extends StatelessWidget {
  final String classId;
  const DashboardTab({super.key, required this.classId});

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
      // ← SAFE: Works with both Timestamp.now() and serverTimestamp (even pending ones)
      stream: collection.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 60, color: Colors.red),
                SizedBox(height: 16),
                Text('Error loading dashboard', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text('Check your connection and try again'),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No financial data yet.\nStart recording costs, revenue, or loans!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
          );
        }

        // ────── CALCULATIONS (unchanged) ──────
        double totalCost = 0;
        double totalRevenue = 0;
        double totalLoans = 0;
        double totalPaid = 0;
        double totalRemaining = 0;
        final Map<String, double> costBreakdown = {};

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;

          switch (data['type']) {
            case 'cost':
              totalCost += amount;
              final cat = data['category'] ?? 'Other';
              costBreakdown[cat] = (costBreakdown[cat] ?? 0) + amount;
              break;
            case 'revenue':
              totalRevenue += amount;
              break;
            case 'loan':
              totalLoans += amount;
              totalPaid += (data['paid'] as num?)?.toDouble() ?? 0.0;
              totalRemaining += (data['remaining'] as num?)?.toDouble() ?? 0.0;
              break;
          }
        }

        final profit = totalRevenue - totalCost;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cost Pie Chart
              if (costBreakdown.isNotEmpty)
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Text('Cost Breakdown', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF003900))),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 250,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                              sections: costBreakdown.entries.map((e) {
                                final i = costBreakdown.keys.toList().indexOf(e.key);
                                return PieChartSectionData(
                                  value: e.value,
                                  title: e.key.length > 12 ? '${e.key.substring(0, 12)}...' : e.key,
                                  color: Colors.primaries[i % Colors.primaries.length],
                                  radius: 100,
                                  titleStyle: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 32),

              // Financial Summary Cards
              _summaryCard('Total Costs', totalCost, Icons.remove_circle_outline, Colors.red.shade700),
              _summaryCard('Total Revenue', totalRevenue, Icons.add_circle_outline, Colors.green.shade700),
              _summaryCard(
                'Net Profit/Loss',
                profit,
                profit >= 0 ? Icons.trending_up : Icons.trending_down,
                profit >= 0 ? Colors.green.shade700 : Colors.red.shade700,
              ),

              const SizedBox(height: 32),
              const Divider(thickness: 2, color: Colors.grey),

              // Loan Summary
              const Text('Loan Summary', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF003900))),
              const SizedBox(height: 16),

              if (totalLoans == 0)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No loans recorded', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  ),
                )
              else ...[
                _summaryCard('Loans Taken', totalLoans, Icons.account_balance_wallet, Colors.orange.shade700),
                _summaryCard('Amount Repaid', totalPaid, Icons.payments, Colors.blue.shade700),
                _summaryCard(
                  'Outstanding Balance',
                  totalRemaining,
                  Icons.warning_amber_rounded,
                  totalRemaining > 0 ? Colors.red.shade700 : Colors.green.shade700,
                ),
              ],

              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _summaryCard(String title, double amount, IconData icon, Color color) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        leading: CircleAvatar(
          radius: 32,
          backgroundColor: color,
          child: Icon(icon, size: 36, color: Colors.white),
        ),
        title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        trailing: Text(
          'KES ${amount.toStringAsFixed(0)}',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }
}