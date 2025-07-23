import 'package:flutter/material.dart';

class OfficerManagement extends StatelessWidget {
  final Color darkGreen = const Color(0xFF1B5E20);

  const OfficerManagement({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: darkGreen, title: const Text('Officer Management', style: TextStyle(color: Colors.white))),
      body: const Center(child: Text('Officers: Vet John - Health Check')),
    );
  }
}