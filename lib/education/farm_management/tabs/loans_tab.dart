// lib/education/farm_management/tabs/loans_tab.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class LoansTab extends StatelessWidget {
  final String classId;
  const LoansTab({super.key, required this.classId});

  String get schoolId => classId.split('_').first;
  String get gradeId => classId.split('_').last;

  CollectionReference get loans => FirebaseFirestore.instance
      .collection('schools')
      .doc(schoolId)
      .collection('grades')
      .doc(gradeId)
      .collection('farm_management_data');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF003900),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _showAddLoanDialog(context),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: loans.where('type', isEqualTo: 'loan').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading loans', style: TextStyle(fontSize: 18)));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No loans recorded yet\nTap + to add one',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (_, i) => LoanCard(doc: docs[i]),
          );
        },
      ),
    );
  }

  void _showAddLoanDialog(BuildContext context) {
    final lenderCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final interestCtrl = TextEditingController(text: '10');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Record New Loan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: lenderCtrl, decoration: const InputDecoration(labelText: 'Lender / Bank')),
            TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Loan Amount (KES)')),
            TextField(controller: interestCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Interest Rate (%)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text) ?? 0;
              final interest = double.tryParse(interestCtrl.text) ?? 0;
              if (amount <= 0) return;

              await loans.add({
                'type': 'loan',
                'lender': lenderCtrl.text.trim(),
                'amount': amount,
                'interestRate': interest,
                'totalRepayable': amount + (amount * interest / 100),
                'paid': 0,
                'remaining': amount,
                'createdAt': Timestamp.now(), // ← FIXED: Real timestamp
              });

              if (context.mounted) Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Loan recorded!'), backgroundColor: Colors.green),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class LoanCard extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  const LoanCard({super.key, required this.doc});

  @override
  State<LoanCard> createState() => _LoanCardState();
}

class _LoanCardState extends State<LoanCard> {
  final _payCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data() as Map<String, dynamic>;
    final remaining = (data['remaining'] as num?)?.toDouble() ?? 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        leading: const CircleAvatar(backgroundColor: Color(0xFF003900), child: Icon(Icons.account_balance, color: Colors.white)),
        title: Text(data['lender'] ?? 'Loan', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Text('Remaining: KES ${remaining.toStringAsFixed(0)}',
            style: TextStyle(color: remaining > 0 ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Amount: KES ${data['amount']}'),
                Text('Interest Rate: ${data['interestRate'] ?? 0}%'),
                Text('Total Repayable: KES ${data['totalRepayable'] ?? 0}'),
                Text('Paid: KES ${data['paid'] ?? 0}'),
                const SizedBox(height: 20),
                if (remaining > 0) ...[
                  TextField(
                    controller: _payCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Payment Amount', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final pay = double.tryParse(_payCtrl.text) ?? 0;
                        if (pay <= 0 || pay > remaining) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid amount')));
                          return;
                        }
                        await widget.doc.reference.update({
                          'paid': FieldValue.increment(pay),
                          'remaining': remaining - pay,
                        });
                        _payCtrl.clear();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment recorded!'), backgroundColor: Colors.green));
                      },
                      icon: const Icon(Icons.payment),
                      label: const Text('Record Payment'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF003900)),
                    ),
                  ),
                ] else
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text('LOAN FULLY PAID ✓', style: TextStyle(color: Colors.green, fontSize: 22, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}