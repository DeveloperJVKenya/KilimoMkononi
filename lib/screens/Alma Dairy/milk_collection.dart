import 'package:flutter/material.dart';

class MilkCollection extends StatelessWidget {
  final Color darkGreen = const Color(0xFF1B5E20);

  const MilkCollection({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: darkGreen,
        title: const Text('Milk Collection', style: TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            buildActionButton(context, 'Record Collection', Icons.add),
            const SizedBox(height: 16),
            buildListItem('Farmer A', '10L, 4% Fat, 8% SNF'),
            buildListItem('Farmer B', '8L, 3.8% Fat, 7.5% SNF'),
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