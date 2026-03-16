// lib/education/education_login.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';

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

      // Prevent Farmer users from logging into Education app
      final farmerDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(uid)
          .get();

      if (farmerDoc.exists) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wrong app! Please use "Enterprise (Farmers)" mode.'),
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

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/edu_home');
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Invalid email or password';
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        msg = 'Invalid email or password';
      } else {
        msg = e.message ?? 'Login failed';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
            // Fixed Animation at Top (No scrolling needed)
            Container(
              height: 180,
              width: double.infinity,
              alignment: Alignment.center,
              child: Lottie.asset(
                'assets/lottie/school.json',
                height: 160,
                fit: BoxFit.contain,
                repeat: true,
                errorBuilder: (_, _, _) => const Icon(Icons.school, size: 90, color: Colors.teal),
              ),
            ),

            // Scrollable Content Below
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
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Colors.teal, width: 2),
                            ),
                          ),
                          validator: (v) => v != null && v.contains('@') ? null : 'Enter valid email',
                        ),

                        const SizedBox(height: 20),

                        TextFormField(
                          controller: _passCtrl,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Colors.teal, width: 2),
                            ),
                          ),
                          validator: (v) => v != null && v.length >= 6 ? null : 'Password required',
                        ),

                        const SizedBox(height: 40),

                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 5,
                            ),
                            onPressed: _loading ? null : _login,
                            child: _loading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text(
                                    'Log In',
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        TextButton(
                          onPressed: () => Navigator.pushReplacementNamed(context, '/edu_register'),
                          child: const Text(
                            'No account? Register here',
                            style: TextStyle(fontSize: 16, color: Colors.teal, fontWeight: FontWeight.w600),
                          ),
                        ),

                        const SizedBox(height: 40), // Extra space for keyboard
                      ],
                    ),
                  ),
                ],
              ),
            ),
            )]
        ),
      ),
    );
  }
}