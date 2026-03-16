// lib/screens/registration.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:kilimomkononi/models/user_model.dart';
import 'package:kilimomkononi/data/kenya_locations.dart';
import 'package:kilimomkononi/services/auth_state_service.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  RegistrationScreenState createState() => RegistrationScreenState();
}

class RegistrationScreenState extends State<RegistrationScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final logger = Logger(printer: PrettyPrinter());

  String? _fullName;
  String? _email;
  String? _phoneNumber;
  String? _password;
  String? _county;
  String? _constituency;
  String? _ward;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _hasAcceptedTerms = false;

  List<String> _currentConstituencies = [];
  List<String> _currentWards = [];

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneNumberController.dispose();
    _passwordController.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/registration_background.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: 20.0),
                  const Text(
                    'Welcome!',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.teal),
                  ),
                  const SizedBox(height: 10.0),
                  Text(
                    'Create your account below.',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 30.0),

                  // Full Name
                  TextFormField(
                    controller: _fullNameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      hintText: 'Enter your full name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30.0)),
                      filled: true,
                      fillColor: Colors.grey[200],
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Please enter your full name' : null,
                    onSaved: (v) => _fullName = v,
                  ),
                  const SizedBox(height: 15.0),

                  // Email
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'Enter your email address',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30.0)),
                      filled: true,
                      fillColor: Colors.grey[200],
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty || !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                    onSaved: (v) => _email = v,
                  ),
                  const SizedBox(height: 15.0),

                  // County
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'County',
                      hintText: 'Select your county',
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
                    onSaved: (v) => _county = v,
                  ),
                  const SizedBox(height: 15.0),

                  // Constituency
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Constituency',
                      hintText: 'Select your constituency',
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
                    onSaved: (v) => _constituency = v,
                  ),
                  const SizedBox(height: 15.0),

                  // Ward
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Ward',
                      hintText: 'Select your ward',
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
                    onSaved: (v) => _ward = v,
                  ),
                  const SizedBox(height: 15.0),

                  // Phone
                  TextFormField(
                    controller: _phoneNumberController,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      hintText: 'Enter your phone number',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30.0)),
                      filled: true,
                      fillColor: Colors.grey[200],
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Please enter your phone number' : null,
                    onSaved: (v) => _phoneNumber = v,
                  ),
                  const SizedBox(height: 15.0),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter your password',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30.0)),
                      filled: true,
                      fillColor: Colors.grey[200],
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Please enter a password' : null,
                    onSaved: (v) => _password = v,
                  ),
                  const SizedBox(height: 20.0),

                  // Terms & Conditions Checkbox
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
                  const SizedBox(height: 16.0),

                  // Sign Up Button – disabled until terms accepted
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_isLoading || !_hasAcceptedTerms)
                          ? null
                          : () {
                              if (_formKey.currentState!.validate()) {
                                _formKey.currentState!.save();
                                _signUp();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _hasAcceptedTerms ? Colors.teal : Colors.grey,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
                        padding: const EdgeInsets.symmetric(vertical: 15.0),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Sign Up', style: TextStyle(fontSize: 20.0, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 10.0),

                  // Login Link
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
                      child: const Text('Already have an account? Log In', style: TextStyle(color: Colors.teal)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signUp() async {
    setState(() => _isLoading = true);

    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: _email!,
        password: _password!,
      );

      final appUser = AppUser(
        id: userCredential.user!.uid,
        fullName: _fullName!,
        email: _email!,
        county: _county!,
        constituency: _constituency!,
        ward: _ward!,
        phoneNumber: _phoneNumber!,
      );

      final userMap = appUser.toMap();
      userMap['termsAcceptedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('Users').doc(appUser.id).set(userMap);

      if (!mounted) return;

      // SKIP SPLASHSCREEN NAVIGATION
      final authService = Provider.of<AuthStateService>(context, listen: false);
      authService.setSkipNext();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign up successful. Welcome, $_fullName!')),
      );

      // GO TO HOME – NEW USER UX
      Navigator.of(context).pushReplacementNamed('/home');
    } catch (e) {
      if (!mounted) return;

      logger.e('Error during sign up: $e');
      String errorMessage = 'Failed to sign up. Please try again.';
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'email-already-in-use':
            errorMessage = 'The email address is already in use.';
            break;
          case 'invalid-email':
            errorMessage = 'The email address is invalid.';
            break;
          case 'weak-password':
            errorMessage = 'The password is too weak.';
            break;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}