import 'package:flutter/material.dart';
import 'package:kilimomkononi/screens/pest%20management/pest_management.dart';
import 'package:kilimomkononi/screens/disease_management_page.dart';
import 'package:kilimomkononi/screens/symptom_checker_page.dart';

class PestDiseaseHomePage extends StatelessWidget {
  const PestDiseaseHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    ScaffoldMessenger.of(context); 

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pest & Disease Management',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color.fromARGB(255, 3, 39, 4),
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: Colors.grey[200],
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Choose an option to manage your farm:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            _buildOptionCard(
              context,
              'Manage Pests',
              Icons.bug_report,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PestManagementPage()),
              ),
            ),
            const SizedBox(height: 20),
            _buildOptionCard(
              context,
              'Manage Diseases',
              Icons.local_hospital,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DiseaseManagementPage()),
              ),
            ),
            const SizedBox(height: 20),
            _buildOptionCard(
              context,
              'Identify Issue by Symptoms',
              Icons.search,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SymptomCheckerPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(20),
          width: MediaQuery.of(context).size.width * 0.8,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: const Color.fromARGB(255, 3, 39, 4)),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}