import 'package:flutter/material.dart';

class CommunicationHub extends StatelessWidget {
  final Color darkGreen = const Color(0xFF1B5E20);

  const CommunicationHub({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: darkGreen, title: const Text('Communication Hub', style: TextStyle(color: Colors.white))),
      body: const Center(child: Text('Messages: Collection tomorrow at 8 AM')),
    );
  }
}