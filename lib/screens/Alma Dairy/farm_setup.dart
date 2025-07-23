import 'package:flutter/material.dart';

class FarmSetup extends StatelessWidget {
  final Color darkGreen = const Color(0xFF1B5E20);

  const FarmSetup({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: darkGreen, title: const Text('Farm Setup', style: TextStyle(color: Colors.white))),
      body: const Center(child: Text('Farm: 10 acres, 20 cows')),
    );
  }
}