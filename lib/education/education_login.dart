// lib/education/education_login.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import 'package:kilimomkononi/education/education_tier_selection.dart';
import 'package:kilimomkononi/education/primary/primary_home_screen.dart';

class EducationLoginScreen extends StatefulWidget {
  const EducationLoginScreen({super.key});

  @override
  State<EducationLoginScreen> createState() => _EducationLoginScreenState();
}

class _EducationLoginScreenState extends State<EducationLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );

      final uid = cred.user!.uid;

      // Block Farmers app users from logging in here
      final farmerDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(uid)
          .get();

      if (farmerDoc.exists) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Wrong app! Please use "Enterprise (Farmers)" mode.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final eduDoc = await FirebaseFirestore.instance
          .collection('EducationUsers')
          .doc(uid)
          .get();

      if (!eduDoc.exists) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No school account found.')),
        );
        return;
      }

      final data = eduDoc.data()!;

      // Account disabled check
      if (data['isDisabled'] == true) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Account disabled. Contact your admin.')),
        );
        return;
      }

      // Still pending approval
      if (data['approvalStatus'] != 'approved') {
        if (!mounted) return;
        _showPendingDialog(data['approvalStatus'] as String? ?? 'pending');
        await FirebaseAuth.instance.signOut();
        return;
      }

      // ── Routing logic ──────────────────────────────────────────
      final role = data['role'] as String?;
      final tier = data['educationTier'] as String?;

      // Headteacher with no tier set → tier selection screen (one-time)
      if (role == 'headteacher' && (tier == null || tier.isEmpty)) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => const EducationTierSelectionScreen()),
        );
        return;
      }

      // ── Silent backfill for teachers & students ────────────────
      // Existing users registered before the school code system have
      // no schoolCode on their record. Look it up from their school
      // and save it silently.
      final existingCode = data['schoolCode'] as String?;
      if (existingCode == null || existingCode.isEmpty) {
        final schoolName = data['schoolName'] as String?;
        if (schoolName != null && schoolName.isNotEmpty) {
          try {
            final schoolSnap = await FirebaseFirestore.instance
                .collection('Schools')
                .where('schoolName', isEqualTo: schoolName)
                .limit(1)
                .get();
            if (schoolSnap.docs.isNotEmpty) {
              final code =
                  schoolSnap.docs.first.data()['schoolCode'] as String?;
              if (code != null && code.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('EducationUsers')
                    .doc(uid)
                    .update({'schoolCode': code});
              }
            }
          } catch (_) {
            // Non-critical — user can still log in fine
          }
        }
      }
      // ──────────────────────────────────────────────────────────

      // ── Primary routing ────────────────────────────────────────
      // Route based on the USER's own class, NOT the school's tier list.
      // A school may offer all 4 systems — we only check THIS user's class.
      final currentClassId = data['currentClassId'] as String?;

      // A user is "primary" only if their OWN class is a primary class.
      // Primary classIds contain 'primary' in the legacy format OR
      // 'cbcPrimary' in the pipe format.
      bool isPrimary = false;
      if (currentClassId != null && currentClassId.isNotEmpty) {
        isPrimary = currentClassId.toLowerCase().contains('_primary_') ||
            currentClassId.contains('cbcPrimary') ||
            currentClassId.contains('|cbcPrimary');
      }

      // For teachers: check if ALL their classes are primary
      // If mixed (primary + junior), send to main home where they can switch
      if (role == 'teacher') {
        final classIds = List<String>.from(data['classIds'] ?? []);
        if (classIds.isNotEmpty) {
          final allPrimary = classIds.every((id) =>
              id.toLowerCase().contains('_primary_') ||
              id.contains('cbcPrimary'));
          isPrimary = allPrimary;
        }
      }

      if (!mounted) return;

      if (isPrimary && (role == 'student' || role == 'teacher')) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PrimaryHomeScreen()),
        );
      } else {
        Navigator.pushReplacementNamed(context, '/edu_home');
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Invalid email or password';
      if (e.code != 'user-not-found' &&
          e.code != 'wrong-password' &&
          e.code != 'invalid-credential') {
        msg = e.message ?? 'Login failed';
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showPendingDialog(String status) {
    final isDenied = status == 'denied';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isDenied ? Icons.cancel : Icons.hourglass_top,
              color: isDenied ? Colors.red : Colors.orange,
            ),
            const SizedBox(width: 10),
            Text(isDenied ? 'Access Denied' : 'Pending Approval'),
          ],
        ),
        content: Text(
          isDenied
              ? 'Your account has been denied. Please contact your school admin.'
              : 'Your account is still awaiting approval.\n\n'
                  '• Headteachers are approved by Kilimo admin\n'
                  '• Teachers are approved by the headteacher\n'
                  '• Students are approved by their teacher',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Colors.teal)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // Fixed Animation at Top
            Container(
              height: 180,
              width: double.infinity,
              alignment: Alignment.center,
              child: Lottie.asset(
                'assets/lottie/school.json',
                height: 160,
                fit: BoxFit.contain,
                repeat: true,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.school, size: 90, color: Colors.teal),
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    const Text(
                      'Welcome Back!',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Education Portal',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.teal.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon:
                                  const Icon(Icons.email_outlined),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                    color: Colors.teal, width: 2),
                              ),
                            ),
                            validator: (v) => v != null && v.contains('@')
                                ? null
                                : 'Enter valid email',
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _passCtrl,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) =>
                                _loading ? null : _login(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon:
                                  const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                                onPressed: () => setState(
                                    () => _obscure = !_obscure),
                              ),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                    color: Colors.teal, width: 2),
                              ),
                            ),
                            validator: (v) =>
                                v != null && v.length >= 6
                                    ? null
                                    : 'Password required',
                          ),
                          const SizedBox(height: 40),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(16)),
                                elevation: 5,
                              ),
                              onPressed: _loading ? null : _login,
                              child: _loading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white)
                                  : const Text(
                                      'Log In',
                                      style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextButton(
                            onPressed: () => Navigator.pushReplacementNamed(
                                context, '/edu_register'),
                            child: const Text(
                              'No account? Register here',
                              style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.teal,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}