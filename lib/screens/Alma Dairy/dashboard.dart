import 'package:flutter/material.dart';

class Dashboard extends StatelessWidget {
  final Color darkGreen = const Color(0xFF1B5E20);

  const Dashboard({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: darkGreen, title: const Text('Dashboard', style: TextStyle(color: Colors.white))),
      body: const Center(child: Text('Daily Overview: Milk - 50L, Feed - 200kg')),
    );
  }
}