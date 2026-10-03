// lib/screens/complete_farmer_profile.dart
//
// Shown once, right after a brand-new Google sign-up on the Farmer app.
// Google gives us name + email for free — we only need to collect the
// location fields (county/constituency/ward) and phone number before we
// can create the Users/{uid} document, since the rest of the app assumes
// every farmer has real farm-location data (used for satellite/weather
// lookups etc.), not a registration-county default.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:kilimomkononi/models/user_model.dart';
import 'package:kilimomkononi/authentication/widgets/auth_kit.dart';
import 'package:kilimomkononi/services/auth_state_service.dart';
import 'package:kilimomkononi/services/google_auth_service.dart';
import 'package:kilimomkononi/utils/friendly_error.dart';

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
  bool _isLoading = false;
  bool _hasAcceptedTerms = false;
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;
  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.suggestedFullName);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneNumberController.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  void _updateConstituencies(String? county) {
    setState(() {
      _county = county;
      _constituency = null;
      _ward = null;
    });
  }

  void _updateWards(String? constituency) {
    setState(() {
      _constituency = constituency;
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
        SnackBar(content: Text(friendlyError(e, 'Could not save profile'))),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancel() async {
    // If they back out, don't leave a half-signed-in session with no
    // Firestore profile — sign out of Firebase AND the Google account.
    await GoogleAuthService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  // Enter / button: validate, focus the first problem, else save.
  void _submit() {
    if (_isLoading) return;
    setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
    if (!_formKey.currentState!.validate()) {
      if (validateName(_fullNameController.text) != null) {
        _nameFocus.requestFocus();
      } else if (validatePhone(_phoneNumberController.text) != null) {
        _phoneFocus.requestFocus();
      }
      return;
    }
    _saveProfile();
  }

  @override
  Widget build(BuildContext context) {
    final first = widget.suggestedFullName.trim().split(' ').first;
    return AuthLayout(
      title: first.isEmpty ? 'Almost there!' : 'Almost there, $first!',
      subtitle: 'Signed in as ${widget.email}. Add your phone and farm location — we use them '
          'for accurate weather, alerts and advice.',
      maxFormWidth: 580,
      topAction: (onDark) => TextButton.icon(
        onPressed: _isLoading ? null : _cancel,
        icon: const Icon(Icons.close_rounded, size: 18),
        label: const Text('Cancel'),
        style: TextButton.styleFrom(foregroundColor: onDark ? Colors.white : AuthColors.muted),
      ),
      child: EnterToSubmit(
        onSubmit: _submit,
        enabled: !_isLoading,
        child: Form(
          key: _formKey,
          autovalidateMode: _autovalidate,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const AuthSectionTitle(step: '1', title: 'About you', icon: Icons.person_outline_rounded),
            AuthRow(children: [
              AuthField(
                controller: _fullNameController,
                focusNode: _nameFocus,
                label: 'Full name',
                icon: Icons.badge_outlined,
                capitalization: TextCapitalization.words,
                validator: validateName,
                onSubmitted: (_) => _submit(),
              ),
              AuthField(
                controller: _phoneNumberController,
                focusNode: _phoneFocus,
                label: 'Phone number',
                hint: '0712 345 678',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-()]'))],
                validator: validatePhone,
                onSubmitted: (_) => _submit(),
              ),
            ]),
            const SizedBox(height: 22),
            const AuthSectionTitle(step: '2', title: 'Farm location', icon: Icons.agriculture_outlined),
            KenyaLocationFields(
              county: _county,
              constituency: _constituency,
              ward: _ward,
              onCounty: _updateConstituencies,
              onConstituency: _updateWards,
              onWard: (v) => setState(() => _ward = v),
            ),
            const SizedBox(height: 16),
            TermsField(context: context, onChanged: (v) => setState(() => _hasAcceptedTerms = v)),
            const SizedBox(height: 16),
            AuthPrimaryButton(
              label: 'Finish setup',
              busyLabel: 'Saving…',
              icon: Icons.check_rounded,
              busy: _isLoading,
              onPressed: _submit,
            ),
          ]),
        ),
      ),
    );
  }
}