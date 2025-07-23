import 'package:flutter/material.dart';

class RecordsSection extends StatelessWidget {
  final Color darkGreen = const Color(0xFF1B5E20);

  const RecordsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: darkGreen,
        title: const Text('Records Section', style: TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            buildRecordTile(context, 'Animal Records', 'View cow health & production logs'),
            buildRecordTile(context, 'Feed Records', 'Track feed usage & costs'),
          ],
        ),
      ),
    );
  }

  Widget buildRecordTile(BuildContext context, String title, String subtitle) {
    return Card(
      elevation: 4,
      child: ListTile(
        title: Text(title, style: TextStyle(color: darkGreen, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward),
        onTap: () {
          // Dummy navigation for demo
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title tapped')));
        },
      ),
    );
  }
}