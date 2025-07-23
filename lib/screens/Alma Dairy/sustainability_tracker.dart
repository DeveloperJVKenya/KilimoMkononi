import 'package:flutter/material.dart';

class SustainabilityTracker extends StatelessWidget {
  final Color darkGreen = const Color(0xFF1B5E20);

  const SustainabilityTracker({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: darkGreen, title: const Text('Sustainability Tracker', style: TextStyle(color: Colors.white))),
      body: const Center(child: Text('Carbon Footprint: 50 kg CO2')),
    );
  }
}