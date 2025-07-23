import 'package:flutter/material.dart';

class ReportGeneration extends StatelessWidget {
  final Color darkGreen = const Color(0xFF1B5E20);

  const ReportGeneration({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: darkGreen, title: const Text('Reports', style: TextStyle(color: Colors.white))),
      body: const Center(child: Text('Report: Milk Yield - 50L/day')),
    );
  }
}