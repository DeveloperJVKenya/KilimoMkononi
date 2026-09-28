// lib/authentication/registration.dart
//
// Farmer sign-up. Same responsive shell as login (auth_kit.dart), with the
// form in three short sections — About you, Farm location, Security — laid
// out in columns when there's room. Enter submits from anywhere; if
// something's missing, the errors show and focus jumps to the first one.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kilimomkononi/authentication/widgets/auth_kit.dart';
import 'package:kilimomkononi/models/user_model.dart';
import 'package:kilimomkononi/screens/complete_farmer_profile.dart';
import 'package:kilimomkononi/services/auth_state_service.dart';
import 'package:kilimomkononi/services/google_auth_service.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  RegistrationScreenState createState() => RegistrationScreenState();
}

class RegistrationScreenState extends State<RegistrationScreen> {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  final _logger = Logger(printer: PrettyPrinter());

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _countyFocus = FocusNode();
  final _constituencyFocus = FocusNode();
  final _wardFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  String? _county;
  String? _constituency;
  String? _ward;
  bool _acceptedTerms = false;
  bool _obscure = true;
  bool _isLoading = false;
  String? _error;
  BannerTone _tone = BannerTone.error;
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    if (isKeyboardPlatform) WidgetsBinding.instance.addPostFrameCallback((_) => _nameFocus.requestFocus());
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _password, _confirm]) {
      c.dispose();
    }
    for (final f in [
      _nameFocus, _phoneFocus, _emailFocus, _countyFocus, _constituencyFocus, _wardFocus, _passwordFocus, _confirmFocus,
    ]) {
      f.dispose();
    }
    super.dispose();
  }

  void _show(String? message, [BannerTone tone = BannerTone.error]) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _tone = tone;
    });
  }

  String? _validatePassword(String? v) =>
      (v ?? '').length < 6 ? 'Use at least 6 characters' : null;

  String? _validateConfirm(String? v) =>
      v != _password.text ? 'Passwords don\'t match' : null;

  /// Focus of the first field that still needs attention (in form order).
  FocusNode? _firstProblem() {
    if (validateName(_name.text) != null) return _nameFocus;
    if (validatePhone(_phone.text) != null) return _phoneFocus;
    if (validateEmail(_email.text) != null) return _emailFocus;
    if (_county == null) return _countyFocus;
    if (_constituency == null) return _constituencyFocus;
    if (_ward == null) return _wardFocus;
    if (_validatePassword(_password.text) != null) return _passwordFocus;
    if (_validateConfirm(_confirm.text) != null) return _confirmFocus;
    return null;
  }

  void _submit() {
    if (_isLoading) return;
    _show(null);
    setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
    final ok = _formKey.currentState!.validate();
    if (!ok) {
      final problem = _firstProblem();
      if (problem != null) {
        problem.requestFocus();
      } else if (!_acceptedTerms) {
        _show('Please accept the Terms & Conditions and Privacy Policy to continue.', BannerTone.warning);
      }
      return;
    }
    _signUp();
  }

  Future<void> _signUp() async {
    setState(() => _isLoading = true);
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      final appUser = AppUser(
        id: cred.user!.uid,
        fullName: _name.text.trim(),
        email: _email.text.trim(),
        county: _county!,
        constituency: _constituency!,
        ward: _ward!,
        phoneNumber: _phone.text.trim(),
      );
      final userMap = appUser.toMap();
      userMap['termsAcceptedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('Users').doc(appUser.id).set(userMap);

      TextInput.finishAutofillContext();
      if (!mounted) return;
      Provider.of<AuthStateService>(context, listen: false).setSkipNext();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Welcome to Kilimo Mkononi, ${appUser.fullName.split(' ').first}!'),
        backgroundColor: AuthColors.green,
      ));
      Navigator.of(context).pushReplacementNamed('/home');
    } on FirebaseAuthException catch (e) {
      _logger.e('Sign up failed: ${e.code}');
      _show(authErrorMessage(e.code, e.message));
      if (e.code == 'email-already-in-use' || e.code == 'invalid-email') _emailFocus.requestFocus();
      if (e.code == 'weak-password') _passwordFocus.requestFocus();
    } catch (e) {
      _logger.e('Sign up failed: $e');
      _show('Could not create your account: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignUp() async {
    _show(null);
    setState(() => _isLoading = true);
    // Must be armed BEFORE the credential exchange — see login.dart.
    Provider.of<AuthStateService>(context, listen: false).setSkipNext();
    try {
      final result = await GoogleAuthService.signIn();
      final uid = result.uid;

      final eduDoc = await _firestore.collection('EducationUsers').doc(uid).get();
      if (eduDoc.exists) {
        await GoogleAuthService.signOut();
        _show('This Google account is registered with the Education app. Choose "Education (Schools)" instead.',
            BannerTone.warning);
        return;
      }
      final farmerDoc = await _firestore.collection('Users').doc(uid).get();
      if (farmerDoc.exists) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/home'); // already registered → signed in
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => CompleteFarmerProfileScreen(
          uid: uid,
          email: result.email,
          suggestedFullName: result.displayName,
        ),
      ));
    } on GoogleAuthCancelledException {
      // Picker closed.
    } catch (e) {
      _show('Google sign-up failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Create your farmer account',
      subtitle: 'It takes about a minute. Your farm location is used for accurate weather and advice.',
      maxFormWidth: 580,
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
              GoogleAuthButton(label: 'Sign up with Google', onPressed: _isLoading ? null : _handleGoogleSignUp),
              const OrDivider(),

              const AuthSectionTitle(step: '1', title: 'About you', icon: Icons.person_outline_rounded),
              AuthRow(children: [
                AuthField(
                  controller: _name,
                  focusNode: _nameFocus,
                  label: 'Full name',
                  hint: 'e.g. Jane Wanjiku',
                  icon: Icons.badge_outlined,
                  capitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  validator: validateName,
                  onSubmitted: (_) => _submit(),
                ),
                AuthField(
                  controller: _phone,
                  focusNode: _phoneFocus,
                  label: 'Phone number',
                  hint: '0712 345 678',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-()]'))],
                  validator: validatePhone,
                  onSubmitted: (_) => _submit(),
                ),
              ]),
              const SizedBox(height: 14),
              AuthField(
                controller: _email,
                focusNode: _emailFocus,
                label: 'Email address',
                hint: 'you@example.com',
                icon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                validator: validateEmail,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 22),

              const AuthSectionTitle(step: '2', title: 'Farm location', icon: Icons.agriculture_outlined),
              KenyaLocationFields(
                county: _county,
                constituency: _constituency,
                ward: _ward,
                countyFocus: _countyFocus,
                constituencyFocus: _constituencyFocus,
                wardFocus: _wardFocus,
                onCounty: (v) => setState(() {
                  _county = v;
                  _constituency = null;
                  _ward = null;
                }),
                onConstituency: (v) => setState(() {
                  _constituency = v;
                  _ward = null;
                }),
                onWard: (v) => setState(() => _ward = v),
              ),
              const SizedBox(height: 22),

              const AuthSectionTitle(step: '3', title: 'Security', icon: Icons.shield_outlined),
              AuthRow(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  AuthField(
                    controller: _password,
                    focusNode: _passwordFocus,
                    label: 'Password',
                    icon: Icons.lock_outline_rounded,
                    obscure: _obscure,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: _validatePassword,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _submit(),
                    suffix: IconButton(
                      tooltip: _obscure ? 'Show password' : 'Hide password',
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  PasswordStrengthMeter(password: _password.text),
                  CapsLockHint(focusNode: _passwordFocus),
                ]),
                AuthField(
                  controller: _confirm,
                  focusNode: _confirmFocus,
                  label: 'Confirm password',
                  icon: Icons.lock_reset_rounded,
                  obscure: _obscure,
                  textInputAction: TextInputAction.go,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: _validateConfirm,
                  onSubmitted: (_) => _submit(),
                ),
              ]),
              const SizedBox(height: 14),
              TermsField(context: context, onChanged: (v) => setState(() => _acceptedTerms = v)),
              const SizedBox(height: 16),
              AuthPrimaryButton(
                label: 'Create account',
                busyLabel: 'Creating your account…',
                icon: Icons.check_rounded,
                busy: _isLoading,
                onPressed: _submit,
              ),
              const SizedBox(height: 18),
              Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
                const Text('Already have an account?', style: TextStyle(color: AuthColors.muted)),
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pushReplacementNamed('/login'),
                  style: TextButton.styleFrom(foregroundColor: AuthColors.green),
                  child: const Text('Sign in', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
