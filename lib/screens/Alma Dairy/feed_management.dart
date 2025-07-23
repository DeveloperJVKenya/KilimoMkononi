import 'package:flutter/material.dart';

class FeedManagement extends StatelessWidget {
  final Color darkGreen = const Color(0xFF1B5E20);

  const FeedManagement({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: darkGreen, title: const Text('Feed Management', style: TextStyle(color: Colors.white))),
      body: const Center(child: Text('Feed Stock: Hay - 100kg, Silage - 50kg')),
    );
  }
}