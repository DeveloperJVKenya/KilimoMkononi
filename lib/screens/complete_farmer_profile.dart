// lib/screens/complete_farmer_profile.dart
//
// Shown once, right after a brand-new Google sign-up on the Farmer app.
// Google gives us name + email for free — we only need to collect the
// location fields (county/constituency/ward) and phone number before we
// can create the Users/{uid} document, since the rest of the app assumes
// every farmer has real farm-location data (used for satellite/weather
// lookups etc.), not a registration-county default.

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:kilimomkononi/models/user_model.dart';
import 'package:kilimomkononi/data/kenya_locations.dart';
import 'package:kilimomkononi/services/auth_state_service.dart';

class CompleteFarmerProfileScreen extends StatefulWidget {
  final String uid;
  final String email;
  final String suggestedFullName;

  const CompleteFarmerProfileScreen({
    super.key,
    required this.uid,
    required this.email,
    required this.suggestedFullName,
  });

  @override
  State<CompleteFarmerProfileScreen> createState() =>
      _CompleteFarmerProfileScreenState();
}

class _CompleteFarmerProfileScreenState
    extends State<CompleteFarmerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  final _phoneNumberController = TextEditingController();

  String? _county;
  String? _constituency;
  String? _ward;
  List<String> _currentConstituencies = [];
  List<String> _currentWards = [];
  bool _isLoading = false;
  bool _hasAcceptedTerms = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.suggestedFullName);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  void _updateConstituencies(String? county) {
    setState(() {
      _county = county;
      _currentConstituencies = county != null ? kenyaLocations[county] ?? [] : [];
      _constituency = null;
      _currentWards = [];
      _ward = null;
    });
  }

  void _updateWards(String? constituency) {
    setState(() {
      _constituency = constituency;
      _currentWards = constituency != null ? constituencyWards[constituency] ?? [] : [];
      _ward = null;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_hasAcceptedTerms) return;
    setState(() => _isLoading = true);

    try {
      final appUser = AppUser(
        id: widget.uid,
        fullName: _fullNameController.text.trim(),
        email: widget.email,
        county: _county!,
        constituency: _constituency!,
        ward: _ward!,
        phoneNumber: _phoneNumberController.text.trim(),
      );

      final userMap = appUser.toMap();
      userMap['termsAcceptedAt'] = FieldValue.serverTimestamp();
      userMap['signUpMethod'] = 'google';

      await FirebaseFirestore.instance
          .collection('Users')
          .doc(widget.uid)
          .set(userMap);

      if (!mounted) return;

      final authService = Provider.of<AuthStateService>(context, listen: false);
      authService.setSkipNext();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Welcome, ${appUser.fullName}!')),
      );
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save profile: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancel() async {
    // If they back out, don't leave a half-signed-in Firebase Auth
    // session with no Firestore profile hanging around.
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finish Setting Up'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _isLoading ? null : _cancel,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Text(
                'Almost there, ${widget.suggestedFullName.split(' ').first}!',
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal),
              ),
              const SizedBox(height: 8),
              Text(
                'We use your farm location for accurate weather and satellite data — this only takes a moment.',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _fullNameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30.0)),
                  filled: true,
                  fillColor: Colors.grey[200],
                ),
                validator: (v) => v == null || v.isEmpty ? 'Please enter your full name' : null,
              ),
              const SizedBox(height: 15.0),

              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'County',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30.0)),
                  filled: true,
                  fillColor: Colors.grey[200],
                ),
                initialValue: _county,
                items: kenyaLocations.keys
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: _updateConstituencies,
                validator: (v) => v == null ? 'Please select a county' : null,
              ),
              const SizedBox(height: 15.0),

              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Constituency',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30.0)),
                  filled: true,
                  fillColor: Colors.grey[200],
                ),
                initialValue: _constituency,
                items: _currentConstituencies
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: _updateWards,
                validator: (v) => v == null ? 'Please select a constituency' : null,
              ),
              const SizedBox(height: 15.0),

              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Ward',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30.0)),
                  filled: true,
                  fillColor: Colors.grey[200],
                ),
                initialValue: _ward,
                items: _currentWards
                    .map((w) => DropdownMenuItem(value: w, child: Text(w)))
                    .toList(),
                onChanged: (v) => setState(() => _ward = v),
                validator: (v) => v == null ? 'Please select a ward' : null,
              ),
              const SizedBox(height: 15.0),

              TextFormField(
                controller: _phoneNumberController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30.0)),
                  filled: true,
                  fillColor: Colors.grey[200],
                ),
                validator: (v) => v == null || v.isEmpty ? 'Please enter your phone number' : null,
              ),
              const SizedBox(height: 20.0),

              // Terms & Conditions Checkbox — same pattern as the main
              // registration screen, since Google sign-up skips that
              // form entirely and this is the only step where a
              // brand-new farmer account actually gets created.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _hasAcceptedTerms,
                    activeColor: Colors.teal,
                    onChanged: (val) => setState(() => _hasAcceptedTerms = val ?? false),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(color: Colors.black87, fontSize: 14),
                          children: [
                            const TextSpan(text: 'I have read and agree to the '),
                            TextSpan(
                              text: 'Terms & Conditions',
                              style: const TextStyle(
                                color: Colors.teal,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => Navigator.pushNamed(context, '/terms'),
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: const TextStyle(
                                color: Colors.teal,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => Navigator.pushNamed(context, '/privacy'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10.0),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isLoading || !_hasAcceptedTerms) ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hasAcceptedTerms ? Colors.teal : Colors.grey,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
                    padding: const EdgeInsets.symmetric(vertical: 15.0),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Finish Setup',
                          style: TextStyle(fontSize: 20.0, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}