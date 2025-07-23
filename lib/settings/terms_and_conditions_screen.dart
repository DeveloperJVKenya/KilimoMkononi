import 'package:flutter/material.dart';

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  static const Color customGreen = Color(0xFF003900); // Consistent with your app’s theme

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Terms and Conditions',
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
                'Terms and Conditions',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: customGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Last Updated
              Text(
                'Last Updated: March 5, 2025',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),

              // Introduction
              _buildSectionTitle(context, '1. Acceptance of Terms'),
              const Text(
                'By downloading, installing, or using the Kilimo Mkononi application ("the App"), you agree to be '
                'bound by these Terms and Conditions ("Terms"). If you do not agree with these Terms, please do not '
                'use the App. Kilimo Mkononi reserves the right to update these Terms at any time, with changes '
                'effective upon posting within the App.',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 24),

              // Use of the App
              _buildSectionTitle(context, '2. Use of the App'),
              const Text(
                'Kilimo Mkononi is provided to assist farmers with tools for weather updates, field data management, '
                'market connections, and farming advice. You agree to use the App solely for lawful purposes related '
                'to agricultural activities. You are responsible for ensuring the accuracy of data entered into the '
                'App, such as field measurements and reminders.',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 24),

              // User Responsibilities
              _buildSectionTitle(context, '3. User Responsibilities'),
              const Text(
                'You agree to:\n'
                '- Provide accurate and up-to-date information when using the App.\n'
                '- Protect your account credentials and not share them with others.\n'
                '- Use the App in compliance with all applicable local, national, and international laws.\n'
                'Misuse of the App, including submitting false data or using it for non-agricultural purposes, may '
                'result in suspension or termination of your access.',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 24),

              // Privacy
              _buildSectionTitle(context, '4. Privacy'),
              const Text(
                'Your use of Kilimo Mkononi is also governed by our Privacy Policy. We collect and use personal data '
                '(e.g., name, location, farming data) to provide App services. By using the App, you consent to such '
                'data collection and processing as outlined in the Privacy Policy.',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 24),

              // Intellectual Property
              _buildSectionTitle(context, '5. Intellectual Property'),
              const Text(
                'All content, logos, and features within Kilimo Mkononi are the property of Kilimo Mkononi or its '
                'licensors and are protected by copyright and trademark laws. You may not reproduce, distribute, or '
                'modify any part of the App without prior written consent.',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 24),

              // Disclaimers
              _buildSectionTitle(context, '6. Disclaimers'),
              const Text(
                'The App is provided "as is" without warranties of any kind. Kilimo Mkononi does not guarantee the '
                'accuracy of weather forecasts, market prices, or farming advice provided through the App. You use '
                'this information at your own risk. We are not liable for losses or damages arising from your reliance '
                'on the App’s features.',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 24),

              // Termination
              _buildSectionTitle(context, '7. Termination'),
              const Text(
                'Kilimo Mkononi may suspend or terminate your access to the App at any time if you violate these Terms '
                'or for any other reason deemed necessary, with or without notice.',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 24),

              // Contact Information
              _buildSectionTitle(context, '8. Contact Us'),
              const Text(
                'For questions about these Terms, please contact us at:\n'
                'Email: support@kilimomkononi.com\n'
                'Phone: +254 \n'
                'Website: https://alma-greentech.co.ke/#',
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: customGreen,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}