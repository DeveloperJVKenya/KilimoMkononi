import 'package:flutter/material.dart';
import 'package:kilimomkononi/screens/Field%20Data%20Input/field_data_input_page.dart';
import 'package:kilimomkononi/screens/Field%20Data%20Input/plot_summary_tab.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FieldDataInputHomePage extends StatelessWidget {
  const FieldDataInputHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 3, 39, 4),
        title: const Text(
          'Field Data Input',
          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Select a Farming Structure',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _buildCard(
              context,
              title: 'Single Crop',
              description: 'Manage data for a single crop plot.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FieldDataInputPage(structureType: 'single'),
                ),
              ),
            ),
            _buildCard(
              context,
              title: 'Intercrop',
              description: 'Manage data for intercropping plots.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FieldDataInputPage(structureType: 'intercrop'),
                ),
              ),
            ),
            _buildCard(
              context,
              title: 'Multiple Plots',
              description: 'Manage data for multiple distinct plots.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FieldDataInputPage(structureType: 'multiple'),
                ),
              ),
            ),
            _buildCard(
              context,
              title: 'Retrieve History',
              description: 'View and manage your saved field data.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PlotSummaryTab(userId: userId),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context,
      {required String title, required String description, required VoidCallback onTap}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 3, 39, 4),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}