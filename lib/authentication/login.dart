// lib/authentication/login.dart
//
// Farmer sign-in. Responsive (lib/authentication/widgets/auth_kit.dart):
// brand panel + fixed-width form on wide screens, card on tablets, compact
// header on phones. Enter submits from anywhere in the form; errors show
// inline and focus moves to the field that needs attention.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kilimomkononi/authentication/registration.dart';
import 'package:kilimomkononi/authentication/widgets/auth_kit.dart';
import 'package:kilimomkononi/screens/complete_farmer_profile.dart';
import 'package:kilimomkononi/services/auth_state_service.dart';
import 'package:kilimomkononi/services/google_auth_service.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _isLoading = false;
  bool _obscure = true;
  String? _error;
  BannerTone _tone = BannerTone.error;
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    // Keyboard users can type straight away.
    if (isKeyboardPlatform) WidgetsBinding.instance.addPostFrameCallback((_) => _emailFocus.requestFocus());
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _show(String? message, [BannerTone tone = BannerTone.error]) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _tone = tone;
    });
  }

  /// Enter / the button: validate, jump to the first problem, else sign in.
  void _submit() {
    if (_isLoading) return;
    _show(null);
    setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
    if (!_formKey.currentState!.validate()) {
      (validateEmail(_emailController.text) != null ? _emailFocus : _passwordFocus).requestFocus();
      return;
    }
    _handleEmailLogin();
  }

  Future<void> _handleEmailLogin() async {
    setState(() => _isLoading = true);
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        // Not trimmed: spaces can be part of a password (sign-up keeps them).
        password: _passwordController.text,
      );
      final uid = cred.user!.uid;

      // Education accounts belong in Education mode.
      final eduDoc = await FirebaseFirestore.instance.collection('EducationUsers').doc(uid).get();
      if (eduDoc.exists) {
        await FirebaseAuth.instance.signOut();
        _show('This is a school (Education) account. Go back and choose "Education (Schools)" to sign in.',
            BannerTone.warning);
        return;
      }

      final farmerDoc = await FirebaseFirestore.instance.collection('Users').doc(uid).get();
      if (!farmerDoc.exists) {
        await FirebaseAuth.instance.signOut();
        _show('No farmer account found for this email. Create an account first.');
        return;
      }
      if (farmerDoc.data()!['isDisabled'] == true) {
        await FirebaseAuth.instance.signOut();
        _show('This account has been disabled. Contact the administrator.');
        return;
      }

      TextInput.finishAutofillContext(); // let the browser / password manager save it
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } on FirebaseAuthException catch (e) {
      _show(authErrorMessage(e.code, e.message));
      _passwordFocus.requestFocus();
    } catch (e) {
      _show('Could not sign in: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    _show(null);
    setState(() => _isLoading = true);

    // Arm the skip flag BEFORE the Google credential exchange: that's what
    // fires the auth-state change AuthStateService listens for, and its
    // auto-navigate to /home would otherwise win the race.
    Provider.of<AuthStateService>(context, listen: false).setSkipNext();

    try {
      final result = await GoogleAuthService.signIn();
      final uid = result.uid;

      final eduDoc = await FirebaseFirestore.instance.collection('EducationUsers').doc(uid).get();
      if (eduDoc.exists) {
        await GoogleAuthService.signOut();
        _show('This Google account is a school (Education) account. Choose "Education (Schools)" to sign in.',
            BannerTone.warning);
        return;
      }

      final farmerDoc = await FirebaseFirestore.instance.collection('Users').doc(uid).get();
      if (farmerDoc.exists) {
        if (farmerDoc.data()!['isDisabled'] == true) {
          await GoogleAuthService.signOut();
          _show('This account has been disabled. Contact the administrator.');
          return;
        }
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/home');
        return;
      }

      // New Google user → collect the farm location we still need.
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => CompleteFarmerProfileScreen(
          uid: uid,
          email: result.email,
          suggestedFullName: result.displayName,
        ),
      ));
    } on GoogleAuthCancelledException {
      // Picker closed — nothing to do.
    } on GoogleAuthException catch (e) {
      _show(e.message);
    } catch (e) {
      _show('Google sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final sent = await showDialog<String>(
      context: context,
      builder: (_) => _ResetPasswordDialog(initialEmail: _emailController.text.trim()),
    );
    if (sent != null) {
      _show('Password reset link sent to $sent. Check your inbox (and spam folder).', BannerTone.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Welcome back',
      subtitle: 'Sign in to your farmer account to see your farm, alerts and advice.',
      topAction: (onDark) => TextButton.icon(
        onPressed: () => Navigator.of(context).pushReplacementNamed('/mode_selection'),
        icon: const Icon(Icons.swap_horiz_rounded, size: 18),
        label: const Text('Switch mode'),
        style: TextButton.styleFrom(foregroundColor: onDark ? Colors.white : AuthColors.teal),
      ),
      child: EnterToSubmit(
        onSubmit: _submit,
        enabled: !_isLoading,
        child: AutofillGroup(
          child: Form(
            key: _formKey,
            autovalidateMode: _autovalidate,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              AuthErrorBanner(message: _error, tone: _tone),
              AuthField(
                controller: _emailController,
                focusNode: _emailFocus,
                label: 'Email address',
                hint: 'you@example.com',
                icon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email, AutofillHints.username],
                validator: validateEmail,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 14),
              AuthField(
                controller: _passwordController,
                focusNode: _passwordFocus,
                label: 'Password',
                icon: Icons.lock_outline_rounded,
                obscure: _obscure,
                textInputAction: TextInputAction.go,
                autofillHints: const [AutofillHints.password],
                validator: (v) => v == null || v.isEmpty ? 'Enter your password' : null,
                onSubmitted: (_) => _submit(),
                suffix: IconButton(
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              CapsLockHint(focusNode: _passwordFocus),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading ? null : _forgotPassword,
                  style: TextButton.styleFrom(foregroundColor: AuthColors.teal),
                  child: const Text('Forgot password?', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 6),
              AuthPrimaryButton(
                label: 'Sign in',
                busyLabel: 'Signing in…',
                icon: Icons.arrow_forward_rounded,
                busy: _isLoading,
                onPressed: _submit,
              ),
              const OrDivider(),
              GoogleAuthButton(label: 'Continue with Google', onPressed: _isLoading ? null : _handleGoogleSignIn),
              const SizedBox(height: 22),
              Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
                const Text('New to Kilimo Mkononi?', style: TextStyle(color: AuthColors.muted)),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.pushReplacement(
                          context, MaterialPageRoute(builder: (_) => const RegistrationScreen())),
                  style: TextButton.styleFrom(foregroundColor: AuthColors.green),
                  child: const Text('Create an account', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Asks for the email and sends Firebase's reset link. Pops the email on
/// success. Enter submits here too.
class _ResetPasswordDialog extends StatefulWidget {
  final String initialEmail;
  const _ResetPasswordDialog({required this.initialEmail});

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  late final _email = TextEditingController(text: widget.initialEmail);
  final _key = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy || !_key.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _email.text.trim());
      if (mounted) Navigator.pop(context, _email.text.trim());
    } on FirebaseAuthException catch (e) {
      setState(() => _error = authErrorMessage(e.code, e.message));
    } catch (e) {
      setState(() => _error = 'Could not send the link: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.lock_reset_rounded, color: AuthColors.green, size: 32),
        title: const Text('Reset your password'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: EnterToSubmit(
            onSubmit: _send,
            enabled: !_busy,
            child: Form(
              key: _key,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('We\'ll email you a link to choose a new password.',
                    style: TextStyle(color: AuthColors.muted, fontSize: 13.5)),
                const SizedBox(height: 16),
                AuthErrorBanner(message: _error),
                AuthField(
                  controller: _email,
                  label: 'Email address',
                  icon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.send,
                  validator: validateEmail,
                  onSubmitted: (_) => _send(),
                ),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AuthColors.green),
            onPressed: _busy ? null : _send,
            child: _busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Send link'),
          ),
        ],
      );
}
