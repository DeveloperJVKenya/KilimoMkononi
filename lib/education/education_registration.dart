// lib/screens/education_registration.dart
// ignore_for_file: avoid_print

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:kilimomkononi/models/education_user.dart';
import 'package:kilimomkononi/widgets/grade_selector.dart';
import 'package:kilimomkononi/services/auth_state_service.dart';

class EducationRegistrationScreen extends StatefulWidget {
  const EducationRegistrationScreen({super.key});
  @override
  State<EducationRegistrationScreen> createState() => _EducationRegistrationScreenState();
}

class _EducationRegistrationScreenState extends State<EducationRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _schoolCtrl = TextEditingController();

  EduRole _role = EduRole.teacher;
  String? _selectedClassId;
  String? _selectedSchoolFromDropdown;
  bool _loading = false;
  bool _obscure = true;
  List<String> _availableSchools = [];
  bool _loadingSchools = false;
  bool _hasAcceptedTerms = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableSchools();
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _schoolCtrl.dispose();
    super.dispose();
  }

  /// NEW VERSION: Only show schools from APPROVED headteachers
  Future<void> _loadAvailableSchools() async {
    setState(() => _loadingSchools = true);
    
    try {
      // Only show schools from APPROVED headteachers
      final snapshot = await _firestore
          .collection('EducationUsers')
          .where('role', isEqualTo: 'headteacher')           // only headteachers
          .where('approvalStatus', isEqualTo: 'approved')    // only approved ones
          .get();
      
      final schools = <String>{};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final schoolName = data['schoolName'] as String?;
        if (schoolName != null && schoolName.isNotEmpty) {
          schools.add(schoolName);
        }
      }
      
      setState(() {
        _availableSchools = schools.toList()..sort();
        _loadingSchools = false;
      });

      if (_availableSchools.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No schools available yet. Ask your school headteacher to register first.'),
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _loadingSchools = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading schools: $e')),
        );
      }
      print('School load error: $e');
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate school selection based on role
    String? finalSchoolName;
    
    if (_role == EduRole.headteacher) {
      // Headteachers can type new school names
      finalSchoolName = _schoolCtrl.text.trim();
      if (finalSchoolName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your school name')),
        );
        return;
      }
    } else {
      // Teachers and Students must select from dropdown
      if (_selectedSchoolFromDropdown == null || _selectedSchoolFromDropdown!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a school from the list')),
        );
        return;
      }
      finalSchoolName = _selectedSchoolFromDropdown;
    }

    if (_role == EduRole.student && _selectedClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Education System and Grade')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );

      // Create user with pending approval status
      await _firestore.collection('EducationUsers').doc(cred.user!.uid).set({
          'uid': cred.user!.uid,
          'fullName': _fullNameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'requestedRole': _role.name,
          'role': _role == EduRole.headteacher ? null : null, 
          'schoolName': finalSchoolName,
          'currentClassId': _role == EduRole.student ? _selectedClassId : null,
          'classIds': [],
          'phone': _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
          'approvalStatus': _role == EduRole.headteacher ? 'pending' : 'pending', 
          'isDisabled': false,
          'createdAt': FieldValue.serverTimestamp(),
          'termsAcceptedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // SKIP SPLASHSCREEN NAVIGATION
      final authService = Provider.of<AuthStateService>(context, listen: false);
      authService.setSkipNext();

      String message = _role == EduRole.headteacher
          ? 'Account created! Welcome, Headteacher.'
          : 'Account created! Awaiting approval...';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );

      // GO TO HOME
      Navigator.pushNamedAndRemoveUntil(context, '/edu_home', (route) => false);
    } on FirebaseAuthException catch (e) {
      String msg = 'Registration failed';
      if (e.code == 'email-already-in-use') msg = 'Email already registered.';
      if (e.code == 'weak-password') msg = 'Password too weak.';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Education Sign-Up')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _fullNameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => v!.contains('@') ? null : 'Invalid email',
              ),
              const SizedBox(height: 12),
              
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),

              // ROLE SELECTION - Show first so users can see what school input they need
              DropdownButtonFormField<EduRole>(
                initialValue: _role,
                items: [
                  // Only show teacher, student, and headteacher in registration
                  const DropdownMenuItem(
                    value: EduRole.headteacher,
                    child: Text('HEADTEACHER'),
                  ),
                  const DropdownMenuItem(
                    value: EduRole.teacher,
                    child: Text('TEACHER'),
                  ),
                  const DropdownMenuItem(
                    value: EduRole.student,
                    child: Text('STUDENT'),
                  ),
                ],
                onChanged: (v) {
                  setState(() {
                    _role = v!;
                    _selectedClassId = null;
                    _selectedSchoolFromDropdown = null;
                    _schoolCtrl.clear();
                  });
                },
                decoration: const InputDecoration(labelText: 'Role'),
              ),
              const SizedBox(height: 12),

              // SCHOOL INPUT - Dynamic based on role
              if (_role == EduRole.headteacher)
                // Headteacher can TYPE school name
                TextFormField(
                  controller: _schoolCtrl,
                  decoration: const InputDecoration(
                    labelText: 'School Name',
                    helperText: 'Enter the name of your school',
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                )
              else
                // Teachers and Students must SELECT from dropdown
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_loadingSchools)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_availableSchools.isEmpty)
                      Card(
                        color: Colors.orange.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.orange.shade700),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'No schools available yet. Ask your school headteacher to register first.',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue: _selectedSchoolFromDropdown,
                        decoration: const InputDecoration(
                          labelText: 'Select School',
                          helperText: 'Choose your school from the list',
                        ),
                        items: _availableSchools.map((school) {
                          return DropdownMenuItem(
                            value: school,
                            child: Text(school),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedSchoolFromDropdown = value);
                        },
                        validator: (v) => v == null || v.isEmpty ? 'Please select a school' : null,
                      ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _loadAvailableSchools,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Refresh school list'),
                    ),
                  ],
                ),
              
              const SizedBox(height: 12),

              // CLASS SELECTION for students
              if (_role == EduRole.student) ...[
                if (_selectedSchoolFromDropdown != null && _selectedSchoolFromDropdown!.isNotEmpty)
                  GradeSelector(
                    schoolName: _selectedSchoolFromDropdown!,
                    onGradeSelected: (id) => setState(() => _selectedClassId = id),
                    useWhiteText: false,
                  )
                else
                  Card(
                    color: Colors.blue.shade50,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Please select a school first to view available classes',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
              ],

              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) => v!.length >= 6 ? null : 'Min 6 chars',
              ),
              const SizedBox(height: 24),

              // INFO CARD - Show what happens after registration
              Card(
                color: Colors.teal.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.teal.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'What happens next?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _role == EduRole.headteacher
                            ? '✓ Your account will be created immediately\n✓ You can start approving teachers for your school'
                            : _role == EduRole.teacher
                                ? '⏳ Your account awaits Headteacher approval\n⏳ You can view the dashboard but features will be locked until approved'
                                : '⏳ Your account awaits Teacher approval\n⏳ You can view the dashboard but features will be locked until approved',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

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
              const SizedBox(height: 16),

              // Create Account Button – disabled until terms accepted
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hasAcceptedTerms ? Colors.teal : Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: (_loading || !_hasAcceptedTerms) ? null : _register,
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Create Account', style: TextStyle(fontSize: 18)),
                ),
              ),

              TextButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/edu_login'),
                child: const Text('Already have an account? Log in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}