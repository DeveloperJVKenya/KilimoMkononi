import 'package:flutter/material.dart';
import 'dashboard.dart';
import 'herd_management.dart';
import 'milk_collection.dart';
import 'records_section.dart';
import 'feed_management.dart';
import 'dairy_product_management.dart';
import 'customer_management.dart';
import 'officer_management.dart';
import 'advisory_section.dart';
import 'report_generation.dart';
import 'expense_monitoring.dart';
import 'farm_setup.dart';
import 'communication_hub.dart';
import 'sustainability_tracker.dart';

class AlmaDairyHome extends StatelessWidget {
  final Color darkGreen = const Color(0xFF1B5E20);

  const AlmaDairyHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: darkGreen,
        title: const Text('Alma Dairy', style: TextStyle(color: Colors.white)),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              navigateToSection(context, value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'Dashboard', child: Text('Dashboard')),
              const PopupMenuItem(value: 'Feed Management', child: Text('Feed Management')),
              const PopupMenuItem(value: 'Dairy Product Management', child: Text('Dairy Product Management')),
              const PopupMenuItem(value: 'Customer Management', child: Text('Customer Management')),
              const PopupMenuItem(value: 'Officer Management', child: Text('Officer Management')),
              const PopupMenuItem(value: 'Advisory Section', child: Text('Advisory Section')),
              const PopupMenuItem(value: 'Report Generation', child: Text('Report Generation')),
              const PopupMenuItem(value: 'Expense Monitoring', child: Text('Expense Monitoring')),
              const PopupMenuItem(value: 'Farm Setup', child: Text('Farm Setup')),
              const PopupMenuItem(value: 'Communication Hub', child: Text('Communication Hub')),
              const PopupMenuItem(value: 'Sustainability Tracker', child: Text('Sustainability Tracker')),
            ],
            icon: const Icon(Icons.menu, color: Colors.white),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Quick Access', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  buildFeatureCard(context, 'Records Section', Icons.book, RecordsSection()),
                  buildFeatureCard(context, 'Herd Management', Icons.pets, HerdManagement()),
                  buildFeatureCard(context, 'Milk Collection', Icons.local_drink, MilkCollection()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildFeatureCard(BuildContext context, String title, IconData icon, Widget destination) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => destination)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withAlpha(77), // Replaced withOpacity(0.3) with withAlpha(77) (0.3 * 255 ≈ 77)
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: darkGreen),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontSize: 16, color: darkGreen, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  void navigateToSection(BuildContext context, String section) {
    Widget destination;
    switch (section) {
      case 'Dashboard':
        destination = Dashboard();
        break;
      case 'Feed Management':
        destination = FeedManagement();
        break;
      case 'Dairy Product Management':
        destination = DairyProductManagement();
        break;
      case 'Customer Management':
        destination = CustomerManagement();
        break;
      case 'Officer Management':
        destination = OfficerManagement();
        break;
      case 'Advisory Section':
        destination = AdvisorySection();
        break;
      case 'Report Generation':
        destination = ReportGeneration();
        break;
      case 'Expense Monitoring':
        destination = ExpenseMonitoring();
        break;
      case 'Farm Setup':
        destination = FarmSetup();
        break;
      case 'Communication Hub':
        destination = CommunicationHub();
        break;
      case 'Sustainability Tracker':
        destination = SustainabilityTracker();
        break;
      default:
        return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (context) => destination));
  }
}