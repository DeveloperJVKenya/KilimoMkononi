import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'package:logger/logger.dart';


class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({super.key});

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  static const Color customGreen = Color(0xFF003900); 
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  final logger = Logger(printer: PrettyPrinter());

  Future<void> _sendFeedback() async {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text;
      final email = _emailController.text;
      final message = _messageController.text;
      logger.e('Feedback: Name: $name, Email: $email, Message: $message');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thank you for your feedback! We’ll get back to you soon.')),
      );
      _nameController.clear();
      _emailController.clear();
      _messageController.clear();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Contact Us',
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
                'Contact Us',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: customGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Introduction
              const Text(
                'We’re here to assist you! Whether you have questions, feedback, or need support with Kilimo Mkononi, '
                'feel free to reach out using the options below.',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 24),

              // Contact Options
              _buildSectionTitle(context, 'Get in Touch'),
              _buildContactItem(
                context,
                icon: Icons.email,
                title: 'Email',
                value: 'support@kilimomkononi.com',
                onTap: () => _launchUrl('mailto:infojvalmacis@gmail.com'),
              ),
              _buildContactItem(
                context,
                icon: Icons.phone,
                title: 'Phone',
                value: '+254712174516',
                onTap: () => _launchUrl('tel:+254712174516'),
              ),
              _buildContactItem(
                context,
                icon: Icons.web,
                title: 'Website',
                value: 'www.almagreentech.com',
                onTap: () => _launchUrl('https://almagreentech.co.ke/#'),
              ),
              const SizedBox(height: 24),

              // Feedback Form
              _buildSectionTitle(context, 'Send Us a Message'),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Your Name',
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: customGreen),
                        ),
                      ),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Please enter your name' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Your Email',
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: customGreen),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        labelText: 'Your Message',
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: customGreen),
                        ),
                      ),
                      maxLines: 4,
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Please enter your message' : null,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _sendFeedback,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: customGreen,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('Send Message'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

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

  // Helper method for contact items
  Widget _buildContactItem(BuildContext context, {required IconData icon, required String title, required String value, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: onTap,
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
                    value,
                    style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.blue, decoration: TextDecoration.underline),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to launch URLs
  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      logger.e('Could not launch $url');
    }
  }
}