// lib/authentication/login.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:kilimomkononi/authentication/registration.dart';
import 'package:kilimomkononi/services/google_auth_service.dart';
import 'package:kilimomkononi/services/auth_state_service.dart';
import 'package:kilimomkononi/screens/complete_farmer_profile.dart';
import 'package:kilimomkononi/widgets/google_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureText = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid = cred.user!.uid;

      // STEP 1: Prevent Education users from logging into Farmer app
      final eduDoc = await FirebaseFirestore.instance
          .collection('EducationUsers')
          .doc(uid)
          .get();

      if (eduDoc.exists) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wrong app! Please use "Education (Schools)" mode to log in.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // STEP 2: Check if Farmer account exists
      final farmerDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(uid)
          .get();

      if (!farmerDoc.exists) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No farmer account found. Please register first.')),
        );
        return;
      }

      // STEP 3: Check if account is disabled
      final data = farmerDoc.data()!;
      if (data['isDisabled'] == true) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account disabled. Contact admin.')),
        );
        return;
      }

      // SUCCESS → Go to Farmer Home
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No account found with this email.';
          break;
        case 'wrong-password':
          message = 'Incorrect password.';
          break;
        case 'invalid-credential':
          message = 'Invalid email or password.';
          break;
        default:
          message = 'Login failed: ${e.message}';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    // Arm the skip flag BEFORE the Google credential exchange, since
    // that's what actually fires the Firebase auth-state change that
    // AuthStateService listens for. If we set this after awaiting
    // GoogleAuthService.signIn(), the auto-navigate-to-/home listener
    // can already have fired and won the race by the time we get here.
    final authService = Provider.of<AuthStateService>(context, listen: false);
    authService.setSkipNext();

    try {
      final result = await GoogleAuthService.signIn();
      final uid = result.uid;

      // STEP 1: Block Education accounts from the Farmer app
      final eduDoc = await FirebaseFirestore.instance
          .collection('EducationUsers')
          .doc(uid)
          .get();

      if (eduDoc.exists) {
        await GoogleAuthService.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wrong app! Please use "Education (Schools)" mode to log in.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // STEP 2: Existing farmer account → sign in
      final farmerDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(uid)
          .get();

      if (farmerDoc.exists) {
        final data = farmerDoc.data()!;
        if (data['isDisabled'] == true) {
          await GoogleAuthService.signOut();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account disabled. Contact admin.')),
          );
          return;
        }
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/home');
        return;
      }

      // STEP 3: Brand-new Google user → collect the location fields we
      // still need before we can create their Users document.
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CompleteFarmerProfileScreen(
            uid: uid,
            email: result.email,
            suggestedFullName: result.displayName,
          ),
        ),
      );
    } on GoogleAuthCancelledException {
      // User closed the account picker — nothing to do.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google sign-in failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Shrink spacing/image on short screens so every element —
            // including the Google button — fits without scrolling.
            // SingleChildScrollView + minHeight is still there as a
            // safety net for very small devices or when the keyboard
            // is open, but normally this fills without needing to scroll.
            final compact = constraints.maxHeight < 700;
            final imageHeight = compact ? 90.0 : 160.0;
            final gapXL = compact ? 14.0 : 24.0;
            final gapL = compact ? 10.0 : 16.0;
            final gapM = compact ? 8.0 : 12.0;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/login.png', height: imageHeight),
                      SizedBox(height: gapL),
                      Text(
                        'Farmer Login',
                        style: TextStyle(
                          fontSize: compact ? 22 : 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      SizedBox(height: gapXL),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            _buildTextField(
                              controller: _emailController,
                              label: 'Email',
                              hintText: 'Enter your email',
                              validator: (v) =>
                                  v == null || !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)
                                      ? 'Enter valid email'
                                      : null,
                            ),
                            SizedBox(height: gapL),
                            _buildTextField(
                              controller: _passwordController,
                              label: 'Password',
                              hintText: 'Enter your password',
                              obscureText: _obscureText,
                              suffixIcon: IconButton(
                                icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
                                onPressed: () => setState(() => _obscureText = !_obscureText),
                              ),
                              validator: (v) => v == null || v.isEmpty ? 'Password required' : null,
                            ),
                            SizedBox(height: gapM),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _isLoading ? null : _handleForgotPassword,
                                child: const Text('Forgot Password?', style: TextStyle(color: Colors.teal)),
                              ),
                            ),
                            SizedBox(height: gapL),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _handleEmailLogin,
                                icon: _isLoading
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : const Icon(Icons.login, color: Colors.white),
                                label: Text(
                                  _isLoading ? 'Logging in...' : 'Login',
                                  style: const TextStyle(fontSize: 20, color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: gapL),
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey[400])),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0),
                            child: Text('OR', style: TextStyle(color: Colors.grey[600])),
                          ),
                          Expanded(child: Divider(color: Colors.grey[400])),
                        ],
                      ),
                      SizedBox(height: gapL),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _handleGoogleSignIn,
                          icon: const GoogleLogo(size: 20),
                          label: const Text('Continue with Google', style: TextStyle(fontSize: 16, color: Colors.black87)),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: compact ? 10 : 14),
                            side: BorderSide(color: Colors.grey[400]!),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                        ),
                      ),
                      SizedBox(height: gapL),
                      TextButton(
                        onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const RegistrationScreen()),
                        ),
                        child: const Text('No account? Sign Up', style: TextStyle(color: Colors.teal, fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    bool obscureText = false,
    Widget? suffixIcon,
    FormFieldValidator<String>? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: label == 'Email' ? TextInputType.emailAddress : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        filled: true,
        fillColor: Colors.teal[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
        suffixIcon: suffixIcon,
      ),
      validator: validator,
    );
  }
}