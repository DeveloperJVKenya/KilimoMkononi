import 'package:flutter/material.dart';

class ExpenseMonitoring extends StatelessWidget {
  final Color darkGreen = const Color(0xFF1B5E20);

  const ExpenseMonitoring({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: darkGreen, title: const Text('Expense Monitoring', style: TextStyle(color: Colors.white))),
      body: const Center(child: Text('Expenses: Feed - \$100, Vet - \$50')),
    );
  }
}