import 'package:flutter/material.dart';

class HerdManagement extends StatelessWidget {
  final Color darkGreen = const Color(0xFF1B5E20);

  const HerdManagement({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: darkGreen,
        title: const Text('Herd Management', style: TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            buildActionButton(context, 'Add Animal', Icons.add),
            const SizedBox(height: 16),
            buildListItem('Cow #001', 'Holstein, Milking, 5L/day'),
            buildListItem('Cow #002', 'Jersey, Dry, Due in 2 months'),
          ],
        ),
      ),
    );
  }

  Widget buildActionButton(BuildContext context, String label, IconData icon) {
    return ElevatedButton.icon(
      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label tapped'))),
      icon: Icon(icon, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(backgroundColor: darkGreen),
    );
  }

  Widget buildListItem(String title, String subtitle) {
    return Card(
      child: ListTile(
        title: Text(title, style: TextStyle(color: darkGreen)),
        subtitle: Text(subtitle),
      ),
    );
  }
}