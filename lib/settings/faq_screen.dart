import 'package:flutter/material.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  static const Color customGreen = Color(0xFF003900); // Consistent with your app’s theme

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Knowledge Base / FAQ',
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
                'Frequently Asked Questions',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: customGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Introduction
              const Text(
                'Find answers to common questions about using Kilimo Mkononi. If you don’t see your question here, '
                'feel free to contact us!',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 24),

              // FAQ List
              _buildFAQItem(
                context,
                question: 'How do I reset my password?',
                answer: 'Go to the "Settings" screen, tap "Edit Profile," and select "Change Password." Follow the '
                    'prompts to enter your old password and set a new one.',
              ),
              _buildFAQItem(
                context,
                question: 'Where can I find crop prices?',
                answer: 'Check the "Market Price Prediction" section on the Home Screen for real-time updates on '
                    'crop prices in your region.',
              ),
              _buildFAQItem(
                context,
                question: 'How do I set a reminder for my farming tasks?',
                answer: 'In the "Field Data Input" screen, select a plot, fill in your data, and tap the "Reminder Date" '
                    'tile under "Intervention Used." Set the date and activity, then save your data.',
              ),
              _buildFAQItem(
                context,
                question: 'Why aren’t my reminders showing in the Inbox?',
                answer: 'Ensure you’ve saved your data after setting a reminder. If the issue persists, check your '
                    'notification settings or contact support at support@kilimomkononi.com.',
              ),
              _buildFAQItem(
                context,
                question: 'How accurate are the weather forecasts?',
                answer: 'Weather updates are sourced from reliable providers, but accuracy depends on local conditions. '
                    'Use them as a guide and check frequently for updates.',
              ),
              _buildFAQItem(
                context,
                question: 'Can I use the app offline?',
                answer: 'Some features, like saved field data and manuals, are available offline. However, weather '
                    'updates and market prices require an internet connection.',
              ),
              _buildFAQItem(
                context,
                question: 'How do I delete my account?',
                answer: 'Contact us at support@kilimomkononi.com with your account details, and we’ll process your '
                    'deletion request within 7 business days.',
              ),
              _buildFAQItem(
                context,
                question: 'Is my data secure?',
                answer: 'Yes, we use encryption and secure storage to protect your information. See our Privacy Policy '
                    'for more details.',
              ),
              const SizedBox(height: 24),

              // Contact Prompt
              _buildSectionTitle(context, 'Still Have Questions?'),
              const Text(
                'Reach out to us at:\n'
                'Email: infojvalmacis@gmail.com\n'
                'Phone: +254712174516',
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

  // Helper method for FAQ items using ExpansionTile
  Widget _buildFAQItem(BuildContext context, {required String question, required String answer}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ExpansionTile(
        leading: const Icon(Icons.question_answer, color: customGreen),
        title: Text(
          question,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: customGreen,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              answer,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}