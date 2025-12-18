import 'package:flutter/material.dart';

class ModeSelectionScreen extends StatelessWidget {
  const ModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choose your mode',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              _modeButton(
                context,
                label: 'Enterprise (Farmers)',
                icon: Icons.agriculture,
                color: Colors.green,
                route: '/login',
              ),
              const SizedBox(height: 20),
              _modeButton(
                context,
                label: 'Education (Schools)',
                icon: Icons.school,
                color: Colors.teal,
                route: '/edu_login',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeButton(BuildContext ctx,
      {required String label,
      required IconData icon,
      required Color color,
      required String route}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: Icon(icon, size: 32),
        label: Text(label, style: const TextStyle(fontSize: 20)),
        onPressed: () => Navigator.of(ctx).pushReplacementNamed(route),
      ),
    );
  }
}