// lib/education/education_tier_selection.dart
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────────
//  School code generator
// ─────────────────────────────────────────────────────────────────
String _generateRawCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rand = Random.secure();
  return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
}

Future<String> _generateUniqueSchoolCode(FirebaseFirestore firestore) async {
  while (true) {
    final code = 'KME-${_generateRawCode()}';
    final doc = await firestore.collection('Schools').doc(code).get();
    if (!doc.exists) return code;
  }
}

// ─────────────────────────────────────────────────────────────────
//  Tier metadata
// ─────────────────────────────────────────────────────────────────
class _TierInfo {
  final String id;
  final String label;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;
  final Color lightColor;

  const _TierInfo({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
    required this.lightColor,
  });
}

const _allTiers = [
  _TierInfo(
    id: 'primary',
    label: 'Primary School',
    subtitle: 'Grade 1 – 6  •  CBC',
    description: 'Visual, picture-based agriculture\nlearning for young learners',
    icon: Icons.child_care,
    color: Color(0xFFFF8C00),
    lightColor: Color(0xFFFFF3E0),
  ),
  _TierInfo(
    id: 'junior',
    label: 'Junior Secondary',
    subtitle: 'Grade 7 – 9  •  CBC',
    description: 'Hands-on farm activities,\nfield data and crop modules',
    icon: Icons.menu_book,
    color: Color(0xFF00897B),
    lightColor: Color(0xFFE0F2F1),
  ),
  _TierInfo(
    id: 'senior',
    label: 'Senior Secondary',
    subtitle: 'Grade 10 – 12  •  CBC',
    description: 'Advanced agri-science,\nmarket and farm management',
    icon: Icons.school,
    color: Color(0xFF1565C0),
    lightColor: Color(0xFFE3F2FD),
  ),
  _TierInfo(
    id: '844',
    label: '8-4-4 System',
    subtitle: 'Std 1–8  /  Form 1–4',
    description: 'Traditional curriculum with\nfull agri-science modules',
    icon: Icons.account_balance,
    color: Color(0xFF6A1B9A),
    lightColor: Color(0xFFF3E5F5),
  ),
];

// ─────────────────────────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────────────────────────
class EducationTierSelectionScreen extends StatefulWidget {
  const EducationTierSelectionScreen({super.key});

  @override
  State<EducationTierSelectionScreen> createState() =>
      _EducationTierSelectionScreenState();
}

class _EducationTierSelectionScreenState
    extends State<EducationTierSelectionScreen>
    with SingleTickerProviderStateMixin {

  final Set<String> _selectedTiers = {};
  bool _saving = false;
  String? _newlyGeneratedCode;
  late AnimationController _animCtrl;

  // Loaded once — shows existing code if headteacher already has one
  String? _existingSchoolCode;
  bool _loadingCode = true;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _loadExistingCode();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExistingCode() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loadingCode = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('EducationUsers')
          .doc(uid)
          .get();
      final code = doc.data()?['schoolCode'] as String?;
      if (mounted) {
        setState(() {
          _existingSchoolCode = code;
          _loadingCode = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCode = false);
    }
  }

  // ── Save ──────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_selectedTiers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one level your school offers.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final firestore = FirebaseFirestore.instance;

      final htDoc =
          await firestore.collection('EducationUsers').doc(uid).get();
      final data = htDoc.data() ?? {};

      String? schoolCode = data['schoolCode'] as String?;
      final schoolName = data['schoolName'] as String? ?? '';
      bool codeWasGenerated = false;

      // ── Backfill: generate code if headteacher doesn't have one ──
      if (schoolCode == null || schoolCode.isEmpty) {
        schoolCode = await _generateUniqueSchoolCode(firestore);
        codeWasGenerated = true;

        await firestore
            .collection('EducationUsers')
            .doc(uid)
            .update({'schoolCode': schoolCode});

        await firestore.collection('Schools').doc(schoolCode).set({
          'schoolName': schoolName,
          'schoolCode': schoolCode,
          'headteacherUID': uid,
          'educationTiers': _selectedTiers.toList(),
          'educationTier': _selectedTiers.contains('primary')
              ? 'primary'
              : _selectedTiers.first,
          'createdAt': FieldValue.serverTimestamp(),
          'backfilledAt': FieldValue.serverTimestamp(),
        });
      }

      final tiersList = _selectedTiers.toList();

      await firestore.collection('EducationUsers').doc(uid).update({
        'educationTiers': tiersList,
        'educationTier': tiersList.contains('primary')
            ? 'primary'
            : tiersList.first,
        'tierSetAt': FieldValue.serverTimestamp(),
      });

      await firestore.collection('Schools').doc(schoolCode).set({
        'educationTiers': tiersList,
        'educationTier': tiersList.contains('primary')
            ? 'primary'
            : tiersList.first,
      }, SetOptions(merge: true));

      if (!mounted) return;

      if (codeWasGenerated) {
        setState(() {
          _newlyGeneratedCode = schoolCode;
          _saving = false;
        });
      } else {
        Navigator.pushReplacementNamed(context, '/edu_home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
        setState(() => _saving = false);
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_newlyGeneratedCode != null) {
      return _buildCodeRevealScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      // KEY FIX: use resizeToAvoidBottomInset to prevent keyboard overflow
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                decoration: const BoxDecoration(
                  color: Color(0xFF003900),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(28),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.account_balance,
                              color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Kilimo Mkononi Education',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Set up your school 🏫',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tick every level your school offers.\n'
                      'A school can have more than one.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.82),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),

                    // ── Existing school code (if already has one) ──
                    if (!_loadingCode &&
                        _existingSchoolCode != null &&
                        _existingSchoolCode!.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.vpn_key,
                                color: Colors.white70, size: 17),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Your school code',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.65),
                                      fontSize: 10,
                                    ),
                                  ),
                                  Text(
                                    _existingSchoolCode!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(
                                    ClipboardData(text: _existingSchoolCode!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Code copied!')),
                                );
                              },
                              child: const Icon(Icons.copy,
                                  color: Colors.white70, size: 17),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Section label ────────────────────────────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 22, 20, 8),
                child: Text(
                  'Select all levels that apply',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF555555),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),

            // ── Tier cards ───────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final tier = _allTiers[i];
                    final isSelected = _selectedTiers.contains(tier.id);

                    return AnimatedBuilder(
                      animation: _animCtrl,
                      builder: (_, child) {
                        final delay = i * 0.12;
                        final progress =
                            ((_animCtrl.value - delay) / (1 - delay))
                                .clamp(0.0, 1.0);
                        return Opacity(
                          opacity: progress,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - progress)),
                            child: child,
                          ),
                        );
                      },
                      child: GestureDetector(
                        onTap: () => setState(() {
                          if (isSelected) {
                            _selectedTiers.remove(tier.id);
                          } else {
                            _selectedTiers.add(tier.id);
                          }
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color:
                                isSelected ? tier.lightColor : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? tier.color
                                  : Colors.grey.shade200,
                              width: isSelected ? 2 : 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isSelected
                                    ? tier.color.withOpacity(0.12)
                                    : Colors.black.withOpacity(0.03),
                                blurRadius: isSelected ? 10 : 4,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? tier.color
                                        : tier.color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    tier.icon,
                                    size: 26,
                                    color:
                                        isSelected ? Colors.white : tier.color,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tier.label,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? tier.color
                                              : const Color(0xFF1A1A1A),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: tier.color.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          tier.subtitle,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: tier.color,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        tier.description,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade500,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 160),
                                  child: isSelected
                                      ? Icon(Icons.check_box_rounded,
                                          key: const ValueKey('on'),
                                          color: tier.color,
                                          size: 28)
                                      : Icon(Icons.check_box_outline_blank,
                                          key: const ValueKey('off'),
                                          color: Colors.grey.shade300,
                                          size: 28),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: _allTiers.length,
                ),
              ),
            ),

            // ── Live selection summary ───────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _selectedTiers.isEmpty
                      ? Container(
                          key: const ValueKey('empty'),
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(children: [
                            Icon(Icons.info_outline,
                                color: Colors.grey.shade400, size: 16),
                            const SizedBox(width: 8),
                            Text('No levels selected yet',
                                style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 13)),
                          ]),
                        )
                      : Container(
                          key: const ValueKey('selected'),
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF003900).withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF003900).withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.check_circle,
                                  color: Color(0xFF003900), size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Selected: ${_selectedTiers.map((id) => _allTiers.firstWhere((t) => t.id == id).label).join(' · ')}',
                                  style: const TextStyle(
                                    color: Color(0xFF003900),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),

            // ── Note ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.amber.shade700, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You can update these levels later in Settings.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber.shade900,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Confirm button ───────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedTiers.isNotEmpty
                          ? const Color(0xFF003900)
                          : Colors.grey.shade300,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: _selectedTiers.isNotEmpty ? 4 : 0,
                    ),
                    onPressed:
                        (_saving || _selectedTiers.isEmpty) ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text(
                            'Confirm & Continue',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Code reveal screen ────────────────────────────────────────────
  Widget _buildCodeRevealScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: SingleChildScrollView(
          // KEY FIX: SingleChildScrollView prevents overflow on small screens
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            // At minimum, fill the available height
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom -
                  56,
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const Spacer(),

                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: const Color(0xFF003900).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.vpn_key_rounded,
                        size: 44, color: Color(0xFF003900)),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Your School Code',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Share this with your teachers and students\n'
                    'so new members can join your school.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF003900),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF003900).withOpacity(0.3),
                          blurRadius: 18,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          _newlyGeneratedCode!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 5,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Kilimo Mkononi Education',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: _newlyGeneratedCode!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('School code copied!')),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy Code',
                          style: TextStyle(fontSize: 15)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF003900),
                        side: const BorderSide(
                            color: Color(0xFF003900), width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            color: Colors.amber.shade700, size: 17),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This code is also saved in your school settings '
                            'and visible on your profile at any time.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber.shade900,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF003900),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 4,
                      ),
                      onPressed: () =>
                          Navigator.pushReplacementNamed(context, '/edu_home'),
                      child: const Text(
                        'Go to Dashboard',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}