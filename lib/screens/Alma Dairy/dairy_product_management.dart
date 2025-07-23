import 'package:flutter/material.dart';

class DairyProductManagement extends StatelessWidget {
  final Color darkGreen = const Color(0xFF1B5E20);

  const DairyProductManagement({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: darkGreen, title: const Text('Dairy Products', style: TextStyle(color: Colors.white))),
      body: const Center(child: Text('Products: Milk - 20L, Cheese - 5kg')),
    );
  }
}