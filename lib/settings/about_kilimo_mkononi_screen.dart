import 'package:flutter/material.dart';

class AboutKilimoMkononiScreen extends StatelessWidget {
  const AboutKilimoMkononiScreen({super.key});

  static const Color customGreen = Color(0xFF003900); // Consistent with your app’s theme

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'About Kilimo Mkononi',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: customGreen,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'About Kilimo Mkononi',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: customGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Introduction
              const Text(
                'Kilimo Mkononi ("Farming in Your Hands") is a mobile application designed to empower farmers '
                'across the region with essential tools and real-time information to boost agricultural '
                'productivity and sustainability. Our goal is to bridge the gap between traditional farming '
                'practices and modern technology, ensuring farmers thrive in an ever-changing environment.',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 24),

              // Mission Section
              _buildSectionTitle(context, 'Our Mission'),
              const Text(
                'To provide farmers with accessible, reliable, and actionable resources to enhance crop yields, '
                'connect to markets, and adapt to climate challenges—all from the convenience of their mobile devices.',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 24),

              // Vision Section
              _buildSectionTitle(context, 'Our Vision'),
              const Text(
                'A future where every farmer has the knowledge and tools to make informed decisions, leading to '
                'food security, economic growth, and sustainable farming practices for generations to come.',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 24),

              // Features Section
              _buildSectionTitle(context, 'Key Features'),
               _buildFeatureItem(
                context,
                icon: Icons.book,
                title: 'Farming Tips & Manuals',
                description: 'Learn best practices from agricultural experts.',
              ),
              _buildFeatureItem(
                context,
                icon: Icons.store,
                title: 'Market Connections',
                description: 'Access market prices and connect with buyers directly.',
              ),
              _buildFeatureItem(
                context,
                icon: Icons.cloud,
                title: 'Weather Updates',
                description: 'Get real-time weather forecasts to plan your farming activities effectively.',
              ),
              _buildFeatureItem(
                context,
                icon: Icons.spa,
                title: 'Field Data Management',
                description: 'Track crop progress, soil nutrients, and interventions with ease.',
              ),
              _buildFeatureItem(
                context,
                icon: Icons.pest_control,
                title: 'Pest and Disease Management',
                description: 'Track crop progress, pests and diseases, and interventions with ease.',
              ),
              _buildFeatureItem(
                context,
                icon: Icons.account_balance_wallet,
                title: 'Farm Management',
                description: 'Track activities cost, total cost of production, revenue and profit or loss and your loan with ease.',
              ),
              const SizedBox(height: 24),

              // Contact Section
              _buildSectionTitle(context, 'Get in Touch'),
              const Text(
                'Have questions or feedback? Reach out to us!\n'
                'Email: infojvalmacis@gmail.com\n'
                'Phone: +254712174516\n'
                'Website: https://almagreentech.co.ke/#',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 16),

              // Footer
              Center(
                child: Text(
                  '© 2025 Kilimo Mkononi. All rights reserved.',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method for section titles
  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        color: customGreen,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  // Helper method for feature items
  Widget _buildFeatureItem(BuildContext context, {required IconData icon, required String title, required String description}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: customGreen, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: customGreen),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}