import 'package:flutter/material.dart';

class CustomerManagement extends StatelessWidget {
  final Color darkGreen = const Color(0xFF1B5E20);

  const CustomerManagement({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: darkGreen, title: const Text('Customer Management', style: TextStyle(color: Colors.white))),
      body: const Center(child: Text('Customers: Retailer A - 10L/week')),
    );
  }
}