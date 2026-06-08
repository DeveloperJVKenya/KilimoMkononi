// lib/education/education_registration.dart
// ignore_for_file: deprecated_member_use, avoid_print, use_build_context_synchronously

import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:kilimomkononi/models/education_user.dart';
import 'package:kilimomkononi/services/auth_state_service.dart';

// ─────────────────────────────────────────────────────────────────
//  School code generator
// ─────────────────────────────────────────────────────────────────
String _generateRawCode() {
  // Exclude confusing chars: 0, O, 1, I
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rand = Random.secure();
  return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
}

Future<String> _generateUniqueSchoolCode() async {
  final firestore = FirebaseFirestore.instance;
  while (true) {
    final code = 'KME-${_generateRawCode()}';
    final doc = await firestore.collection('Schools').doc(code).get();
    if (!doc.exists) return code;
  }
}

// ─────────────────────────────────────────────────────────────────
//  Role card data
// ─────────────────────────────────────────────────────────────────
class _RoleCard {
  final EduRole role;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _RoleCard({
    required this.role,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

const _roleCards = [
  _RoleCard(
    role: EduRole.headteacher,
    label: 'Headteacher',
    subtitle: 'Register your school',
    icon: Icons.account_balance,
    color: Color(0xFF003900),
  ),
  _RoleCard(
    role: EduRole.teacher,
    label: 'Teacher',
    subtitle: 'Join with school code',
    icon: Icons.person_pin,
    color: Color(0xFF00897B),
  ),
  _RoleCard(
    role: EduRole.student,
    label: 'Student',
    subtitle: 'Join with school code',
    icon: Icons.face,
    color: Color(0xFF1565C0),
  ),
];

// ─────────────────────────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────────────────────────
class EducationRegistrationScreen extends StatefulWidget {
  const EducationRegistrationScreen({super.key});

  @override
  State<EducationRegistrationScreen> createState() =>
      _EducationRegistrationScreenState();
}

class _EducationRegistrationScreenState
    extends State<EducationRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // Step 0 = pick role, Step 1 = fill form
  int _step = 0;
  EduRole? _selectedRole;

  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  // Headteacher only
  final _schoolNameCtrl = TextEditingController();

  // Teacher / Student only
  final _schoolCodeCtrl = TextEditingController();
  Map<String, dynamic>? _resolvedSchool; // fetched from Schools/{code}
  bool _resolvingCode = false;

  // Grade/system selection (shown after school code verified)
  String? _selectedSystem; // e.g. 'primary', 'junior', 'senior', '844'
  String? _selectedGrade;  // e.g. '7', '8', '9'

  bool _loading = false;
  bool _obscure = true;
  bool _hasAcceptedTerms = false;

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _schoolNameCtrl.dispose();
    _schoolCodeCtrl.dispose();
    super.dispose();
  }

  // ── School code lookup ──────────────────────────────────────────
  Future<void> _lookupSchoolCode() async {
    final code = _schoolCodeCtrl.text.trim().toUpperCase();
    if (code.length < 9) {
      // KME- + 6 chars = 10, but be lenient
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the full school code (e.g. KME-X7R4NQ)')),
      );
      return;
    }

    setState(() {
      _resolvingCode = true;
      _resolvedSchool = null;
    });

    try {
      final doc = await _firestore.collection('Schools').doc(code).get();
      if (!doc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('School code not found. Double-check with your headteacher.'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        setState(() => _resolvedSchool = doc.data());
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _resolvingCode = false);
    }
  }

  // ── Registration ────────────────────────────────────────────────
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    // Teacher/Student must have resolved a school
    if (_selectedRole != EduRole.headteacher && _resolvedSchool == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please verify your school code first.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );

      final uid = cred.user!.uid;
      final now = FieldValue.serverTimestamp();

      if (_selectedRole == EduRole.headteacher) {
        // Generate unique school code
        final schoolCode = await _generateUniqueSchoolCode();
        final schoolName = _schoolNameCtrl.text.trim();

        // Create headteacher user record
        await _firestore.collection('EducationUsers').doc(uid).set({
          'uid': uid,
          'fullName': _fullNameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim().isNotEmpty
              ? _phoneCtrl.text.trim()
              : null,
          'requestedRole': 'headteacher',
          'role': null, // set by mainadmin on approval
          'schoolName': schoolName,
          'schoolCode': schoolCode,
          'educationTier': null, // set by headteacher on first login post-approval
          'approvalStatus': 'pending',
          'isDisabled': false,
          'createdAt': now,
          'termsAcceptedAt': now,
        });

        // Create Schools document so teachers/students can look up by code
        await _firestore.collection('Schools').doc(schoolCode).set({
          'schoolName': schoolName,
          'schoolCode': schoolCode,
          'headteacherUID': uid,
          'educationTier': null,
          'createdAt': now,
        });
      } else {
        // Teacher or Student
        final code = _schoolCodeCtrl.text.trim().toUpperCase();
        final schoolName = _resolvedSchool!['schoolName'] as String;
        final tier = _resolvedSchool!['educationTier'] as String?;

        // Build classId from selected system + grade (if teacher/student selected one)
        String? initialClassId;
        if (_selectedSystem != null && _selectedGrade != null) {
          final sysKey = _selectedSystem == '844' ? 'eightfourfour' : _selectedSystem!;
          final normalized = schoolName.replaceAll(' ', '_');
          initialClassId = '${normalized}_${sysKey}_$_selectedGrade';
        }

        await _firestore.collection('EducationUsers').doc(uid).set({
          'uid': uid,
          'fullName': _fullNameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim().isNotEmpty
              ? _phoneCtrl.text.trim()
              : null,
          'requestedRole': _selectedRole!.name,
          'role': null,
          'schoolName': schoolName,
          'schoolCode': code,
          'educationTier': tier,
          'educationTiers': List<String>.from(
              _resolvedSchool!['educationTiers'] ?? [tier ?? '']),
          'currentClassId': initialClassId,
          'classIds': initialClassId != null ? [initialClassId] : [],
          'approvalStatus': 'pending',
          'isDisabled': false,
          'createdAt': now,
          'termsAcceptedAt': now,
        });
      }

      if (!mounted) return;
      final authService = Provider.of<AuthStateService>(context, listen: false);
      authService.setSkipNext();

      final message = _selectedRole == EduRole.headteacher
          ? 'School registered! Awaiting Kilimo admin approval.'
          : 'Account created! Awaiting approval from your school.';

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      Navigator.pushNamedAndRemoveUntil(context, '/edu_home', (_) => false);
    } on FirebaseAuthException catch (e) {
      String msg = 'Registration failed';
      if (e.code == 'email-already-in-use') msg = 'Email already registered.';
      if (e.code == 'weak-password') msg = 'Password must be at least 6 characters.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────
  Color get _roleColor {
    switch (_selectedRole) {
      case EduRole.headteacher:
        return const Color(0xFF003900);
      case EduRole.teacher:
        return const Color(0xFF00897B);
      case EduRole.student:
        return const Color(0xFF1565C0);
      default:
        return const Color(0xFF003900);
    }
  }

  // ── Build ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF003900),
        foregroundColor: Colors.white,
        title: Text(_step == 0 ? 'Education Sign-Up' : 'Create Account'),
        leading: _step == 1
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _step = 0;
                  _selectedRole = null;
                  _resolvedSchool = null;
                }),
              )
            : null,
        elevation: 0,
      ),
      body: _step == 0 ? _buildRoleStep() : _buildFormStep(),
    );
  }

  // ── Step 0: Pick Role ────────────────────────────────────────────
  Widget _buildRoleStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text(
            'Who are you?',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select your role to get started',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 32),
          ..._roleCards.map((card) {
            return GestureDetector(
              onTap: () => setState(() {
                _selectedRole = card.role;
                _step = 1;
              }),
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: card.color.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: card.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(card.icon, size: 30, color: card.color),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            card.label,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: card.color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            card.subtitle,
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        color: card.color.withOpacity(0.5)),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
          Center(
            child: TextButton(
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, '/edu_login'),
              child: Text(
                'Already have an account? Log in',
                style:
                    TextStyle(color: const Color(0xFF00897B), fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 1: Fill Form ────────────────────────────────────────────
  Widget _buildFormStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Role badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _roleColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_roleCards
                          .firstWhere((c) => c.role == _selectedRole)
                          .icon,
                      color: _roleColor, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _roleCards
                        .firstWhere((c) => c.role == _selectedRole)
                        .label,
                    style: TextStyle(
                        color: _roleColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Common fields ─────────────────────────────────────
            _field(
              controller: _fullNameCtrl,
              label: 'Full Name',
              icon: Icons.person_outline,
              validator: (v) =>
                  v != null && v.trim().length >= 3 ? null : 'Enter your full name',
            ),
            const SizedBox(height: 16),
            _field(
              controller: _emailCtrl,
              label: 'Email',
              icon: Icons.email_outlined,
              keyboard: TextInputType.emailAddress,
              validator: (v) =>
                  v != null && v.contains('@') ? null : 'Enter a valid email',
            ),
            const SizedBox(height: 16),
            _field(
              controller: _phoneCtrl,
              label: 'Phone (optional)',
              icon: Icons.phone_outlined,
              keyboard: TextInputType.phone,
              required: false,
            ),
            const SizedBox(height: 16),

            // ── Role-specific fields ──────────────────────────────
            if (_selectedRole == EduRole.headteacher) ...[
              _field(
                controller: _schoolNameCtrl,
                label: 'School Name',
                icon: Icons.account_balance,
                validator: (v) => v != null && v.trim().length >= 3
                    ? null
                    : 'Enter your school name',
              ),
              const SizedBox(height: 12),
              // Info card
              _infoCard(
                color: Colors.teal,
                icon: Icons.vpn_key,
                text: 'A unique school code will be generated after registration.\n'
                    'Share it with your teachers and students.',
              ),
            ] else ...[
              // School code field
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _schoolCodeCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: 'School Code',
                        hintText: 'e.g. KME-X7R4NQ',
                        prefixIcon: const Icon(Icons.vpn_key_outlined),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              BorderSide(color: _roleColor, width: 2),
                        ),
                      ),
                      validator: (v) =>
                          v != null && v.trim().length >= 6
                              ? null
                              : 'Enter the school code',
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _roleColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _resolvingCode ? null : _lookupSchoolCode,
                      child: _resolvingCode
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Verify',
                              style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Show resolved school
              if (_resolvedSchool != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _resolvedSchool!['schoolName'] ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15),
                            ),
                            if (_resolvedSchool!['educationTier'] != null)
                              Text(
                                _formatTier(
                                    _resolvedSchool!['educationTier']),
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                _infoCard(
                  color: Colors.blue,
                  icon: Icons.info_outline,
                  text: 'Ask your headteacher for the school code.\n'
                      'Tap Verify to confirm before registering.',
                ),

              // Grade/system picker — shown after school is verified
              if (_resolvedSchool != null) ...[
                const SizedBox(height: 14),
                _buildGradeSystemPicker(),
              ],
            ],

            const SizedBox(height: 16),

            // Password
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _roleColor, width: 2),
                ),
              ),
              validator: (v) =>
                  v != null && v.length >= 6 ? null : 'Min 6 characters',
            ),

            const SizedBox(height: 24),

            // What happens next card
            _infoCard(
              color: Colors.teal,
              icon: Icons.info_outline,
              text: _selectedRole == EduRole.headteacher
                  ? '✓ Your school will be registered\n'
                      '⏳ Awaiting Kilimo admin approval\n'
                      '✓ Once approved, set your school type & share the code'
                  : _selectedRole == EduRole.teacher
                      ? '⏳ Awaiting headteacher approval\n'
                          '✓ Once approved, you can manage your classes'
                      : '⏳ Awaiting teacher approval\n'
                          '✓ Once approved, you can access all learning modules',
            ),

            const SizedBox(height: 16),

            // Terms
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _hasAcceptedTerms,
                  activeColor: _roleColor,
                  onChanged: (v) =>
                      setState(() => _hasAcceptedTerms = v ?? false),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                            color: Colors.black87, fontSize: 14),
                        children: [
                          const TextSpan(
                              text: 'I have read and agree to the '),
                          TextSpan(
                            text: 'Terms & Conditions',
                            style: TextStyle(
                              color: _roleColor,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () =>
                                  Navigator.pushNamed(context, '/terms'),
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(
                              color: _roleColor,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () =>
                                  Navigator.pushNamed(context, '/privacy'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _hasAcceptedTerms ? _roleColor : Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: _hasAcceptedTerms ? 4 : 0,
                ),
                onPressed: (_loading || !_hasAcceptedTerms) ? null : _register,
                child: _loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : const Text(
                        'Create Account',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
              ),
            ),

            const SizedBox(height: 12),

            Center(
              child: TextButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/edu_login'),
                child: const Text('Already have an account? Log in',
                    style:
                        TextStyle(color: Color(0xFF00897B), fontSize: 15)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

    // ── Grade / system picker (shown after school code verified) ────────
  Widget _buildGradeSystemPicker() {
    final schoolTiers = List<String>.from(
        _resolvedSchool?['educationTiers'] ?? 
        (_resolvedSchool?['educationTier'] != null 
            ? [_resolvedSchool!['educationTier']] 
            : []));

    if (schoolTiers.isEmpty) return const SizedBox.shrink();

    // Map tier id → display info
    final tierInfo = {
      'primary': (
        label: 'Primary (Gr 1–6)',
        color: const Color(0xFFFF8C00),
        grades: ['1','2','3','4','5','6']
      ),
      'junior': (
        label: 'Junior Secondary (Gr 7–9)',
        color: const Color(0xFF00897B),
        grades: ['7','8','9']
      ),
      'senior': (
        label: 'Senior Secondary (Gr 10–12)',
        color: const Color(0xFF1565C0),
        grades: ['10','11','12']
      ),
      '844': (
        label: '8-4-4 (Std 1–8 / Form 1–4)',
        color: const Color(0xFF6A1B9A),
        grades: ['1','2','3','4','5','6','7','8','9','10','11','12']  // adjusted for 8-4-4
      ),
    };

    final availableGrades = _selectedSystem != null
        ? (tierInfo[_selectedSystem]?.grades ?? <String>[])
        : <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select your class (optional — headteacher will confirm)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),

        // System chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: schoolTiers.map((tier) {
            final info = tierInfo[tier];
            if (info == null) return const SizedBox.shrink();
            final isSelected = _selectedSystem == tier;
            return GestureDetector(
              onTap: () => setState(() {
                _selectedSystem = tier;
                _selectedGrade = null;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? info.color.withOpacity(0.12)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? info.color : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Text(
                  info.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? info.color : Colors.grey.shade700,
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        // Grade dropdown
        if (_selectedSystem != null && availableGrades.isNotEmpty) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _selectedGrade,
            decoration: InputDecoration(
              labelText: 'Select Grade',
              prefixIcon: const Icon(Icons.class_),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: tierInfo[_selectedSystem]!.color, width: 2),
              ),
            ),
            items: availableGrades.map((g) {
              final sys = _selectedSystem!;
              final label = sys == '844'
                  ? (int.parse(g) <= 8 ? 'Standard $g' : 'Form $g')
                  : 'Grade $g';

              return DropdownMenuItem<String>(
                value: g,           // ← Explicit cast
                child: Text(label),
              );
            }).toList(),
            onChanged: (v) => setState(() => _selectedGrade = v),
          ),
        ],
      ],
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────
  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
    bool required = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _roleColor, width: 2),
        ),
      ),
      validator: required ? validator : null,
    );
  }

  Widget _infoCard({
    required Color color,
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  fontSize: 13,
                  color: color.withOpacity(0.85),
                  height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTier(String? tier) {
    switch (tier) {
      case 'primary':
        return 'Primary School (Grade 1–6)';
      case 'junior':
        return 'Junior Secondary (Grade 7–9)';
      case 'senior':
        return 'Senior Secondary (Grade 10–12)';
      default:
        return tier ?? '';
    }
  }
}