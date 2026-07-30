// lib/education/pest/pest_disease_home.dart
import 'package:flutter/material.dart';
import 'package:kilimomkononi/models/education_user.dart';
import 'pest_home.dart';
import 'disease_home.dart';
import 'symptom_checker_page.dart';
import 'package:kilimomkononi/education/pest/edu_photo_diagnosis_page.dart';

const Color _kDark = Color(0xFF032704);

class PestDiseaseHome extends StatefulWidget {
  final EduRole role;
  final String schoolName;
  final String classId;

  const PestDiseaseHome({
    super.key,
    required this.role,
    required this.schoolName,
    required this.classId,
  });

  @override
  State<PestDiseaseHome> createState() => _PestDiseaseHomeState();
}

class _PestDiseaseHomeState extends State<PestDiseaseHome>
    with SingleTickerProviderStateMixin {
  // 0 = hub, 1-4 = sections
  int _selected = 0;
  Map<String, String>? _prefillData;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  bool get _isHeadteacher => widget.role == EduRole.headteacher;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _navigate(int idx) {
    _animCtrl.reverse().then((_) {
      setState(() => _selected = idx);
      _animCtrl.forward();
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // HUB — redesigned
  // ──────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_selected != 0) return _buildSelectedContent();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      body: CustomScrollView(
        slivers: [
          // ── Hero app bar ──
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: _kDark,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Pest & Disease',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  letterSpacing: 0.3,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Subtle leaf-pattern overlay via a gradient
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF064E09),
                          _kDark,
                          const Color(0xFF0A3E0D),
                        ],
                      ),
                    ),
                  ),
                  // Decorative circles
                  Positioned(
                    right: -30, top: -30,
                    child: Container(
                      width: 160, height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -20, bottom: -20,
                    child: Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                    ),
                  ),
                  // Icon watermark
                  Positioned(
                    right: 24, top: 32,
                    child: Opacity(
                      opacity: 0.12,
                      child: const Icon(Icons.eco, size: 80, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Subtitle ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Text(
                'Select a module to get started',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),

          // ── Core modules (pest + disease) — always visible ──
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.05,
              ),
              delegate: SliverChildListDelegate([
                _ModuleCard(
                  title: 'Pest\nManagement',
                  subtitle: 'Identify & control pests',
                  icon: Icons.pest_control,
                  gradient: [const Color(0xFF2E7D32), const Color(0xFF388E3C)],
                  onTap: () => _navigate(1),
                ),
                _ModuleCard(
                  title: 'Disease\nManagement',
                  subtitle: 'Diagnose & treat diseases',
                  icon: Icons.coronavirus_outlined,
                  gradient: [const Color(0xFF00695C), const Color(0xFF00897B)],
                  onTap: () => _navigate(2),
                ),
              ]),
            ),
          ),

          // ── Tools section (students / teachers only, not headteacher) ──
          if (!_isHeadteacher) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                child: Row(children: [
                  Container(
                    width: 3, height: 18,
                    decoration: BoxDecoration(
                      color: _kDark,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Diagnostic Tools',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _ToolRow(
                    title: 'Symptom Checker',
                    subtitle: 'Step-by-step diagnosis from observable symptoms',
                    icon: Icons.search,
                    iconBg: const Color(0xFF1565C0),
                    onTap: () => _navigate(3),
                  ),
                  const SizedBox(height: 12),
                  _ToolRow(
                    title: 'AI Photo Diagnosis',
                    subtitle: 'Take or upload a photo — AI identifies the issue',
                    icon: Icons.photo_camera,
                    iconBg: const Color(0xFF6A1B9A),
                    onTap: () => _navigate(4),
                    badge: 'AI',
                  ),
                  const SizedBox(height: 24),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // SELECTED CONTENT
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildSelectedContent() {
    late Widget content;

    if (_selected == 1) {
      content = PestHome(
        role: widget.role,
        schoolName: widget.schoolName,
        classId: widget.classId,
        prefillData: _prefillData,
      );
    } else if (_selected == 2) {
      content = DiseaseHome(
        role: widget.role,
        schoolName: widget.schoolName,
        classId: widget.classId,
        prefillData: _prefillData,
      );
    } else if (_selected == 3) {
      content = SymptomCheckerPage(
        role: widget.role,
        schoolName: widget.schoolName,
        classId: widget.classId,
        isEmbedded: true,
        onGoToManagement: (data) {
          setState(() {
            _prefillData = data;
            _selected = data['type'] == 'Pest' ? 1 : 2;
          });
        },
      );
    } else {
      content = EduPhotoDiagnosisPage(
        role: widget.role,
        schoolName: widget.schoolName,
        classId: widget.classId,
      );
    }

    return FadeTransition(
      opacity: _fadeAnim,
      child: Stack(
        children: [
          content,
          // Back button
          Positioned(
            top: 12,
            left: 12,
            child: SafeArea(
              child: Material(
                color: Colors.white,
                elevation: 4,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(30),
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: () {
                    setState(() {
                      _selected = 0;
                      _prefillData = null;
                    });
                    _animCtrl.forward(from: 0);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.arrow_back_ios_new, size: 14, color: _kDark),
                      const SizedBox(width: 4),
                      Text('Back',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kDark)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable module card (2-column grid)
// ─────────────────────────────────────────────────────────────────────────────
class _ModuleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: gradient.last.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 26),
                ),
                const Spacer(),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable tool row (full-width list item)
// ─────────────────────────────────────────────────────────────────────────────
class _ToolRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconBg;
  final VoidCallback onTap;
  final String? badge;

  const _ToolRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconBg,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6A1B9A),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}