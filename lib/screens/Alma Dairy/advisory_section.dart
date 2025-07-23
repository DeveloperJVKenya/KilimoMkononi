import 'package:flutter/material.dart';

class AdvisorySection extends StatelessWidget {
  final Color darkGreen = const Color(0xFF1B5E20);

  const AdvisorySection({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: darkGreen, title: const Text('Advisory Section', style: TextStyle(color: Colors.white))),
      body: const Center(child: Text('Tips: Increase Milk Fat with Silage')),
    );
  }
}