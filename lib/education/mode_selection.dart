import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Mode selection: instead of two stacked buttons, the whole screen is
/// split into two big tappable halves that mirror Kilimo Mkononi's two
/// audiences — a farming-green top half for Enterprise (farmers) and a
/// learning-teal bottom half for Education (schools) — with a small
/// badge sitting on the seam between them.
class ModeSelectionScreen extends StatefulWidget {
  const ModeSelectionScreen({super.key});

  @override
  State<ModeSelectionScreen> createState() => _ModeSelectionScreenState();
}

class _ModeSelectionScreenState extends State<ModeSelectionScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entry;
  late final AnimationController _ambient;

  late final Animation<double> _topSlide;
  late final Animation<double> _bottomSlide;
  late final Animation<double> _headerOpacity;
  late final Animation<double> _badgeScale;

  @override
  void initState() {
    super.initState();

    _entry = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..forward();

    _ambient = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    )..repeat(reverse: true);

    _headerOpacity = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );
    _topSlide = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.0, 0.75, curve: Curves.easeOutCubic),
    );
    _bottomSlide = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.15, 0.9, curve: Curves.easeOutCubic),
    );
    _badgeScale = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.45, 1.0, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _entry.dispose();
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_entry, _ambient]),
        builder: (context, _) {
          final topOffset = (1 - _topSlide.value.clamp(0.0, 1.0));
          final bottomOffset = (1 - _bottomSlide.value.clamp(0.0, 1.0));

          return Stack(
            fit: StackFit.expand,
            children: [
              Column(
                children: [
                  Expanded(
                    child: Transform.translate(
                      offset: Offset(0, -topOffset * 120),
                      child: Opacity(
                        opacity: _topSlide.value.clamp(0.0, 1.0),
                        child: _ModePanel(
                          label: 'Enterprise',
                          subtitle: 'For Farmers',
                          description:
                              'Track weather, manage pests & disease,\nand plan every season.',
                          icon: Icons.agriculture,
                          gradient: [
                            Colors.green.shade700,
                            Colors.green.shade400,
                          ],
                          ambientIcon: Icons.eco,
                          ambientPhase: _ambient.value,
                          iconsDriftUp: true,
                          arrowAlignment: Alignment.bottomCenter,
                          onTap: () => Navigator.of(context)
                              .pushReplacementNamed('/login'),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Transform.translate(
                      offset: Offset(0, bottomOffset * 120),
                      child: Opacity(
                        opacity: _bottomSlide.value.clamp(0.0, 1.0),
                        child: _ModePanel(
                          label: 'Education',
                          subtitle: 'For Schools',
                          description:
                              'Lessons, simulations and quizzes for\nteachers, students & headteachers.',
                          icon: Icons.school,
                          gradient: [
                            Colors.teal.shade400,
                            Colors.teal.shade800,
                          ],
                          ambientIcon: Icons.menu_book_rounded,
                          ambientPhase: _ambient.value,
                          iconsDriftUp: false,
                          arrowAlignment: Alignment.topCenter,
                          onTap: () => Navigator.of(context)
                              .pushReplacementNamed('/edu_login'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Header, floating above the seam.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Opacity(
                    opacity: _headerOpacity.value.clamp(0.0, 1.0),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        children: [
                          const Text(
                            'Kilimo Mkononi',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Choose your mode',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Centre badge sitting on the seam between the two halves.
              Align(
                alignment: Alignment.center,
                child: Transform.scale(
                  scale: math.max(0.0, _badgeScale.value),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          left: 8,
                          child: Icon(Icons.eco,
                              color: Colors.green.shade600, size: 20),
                        ),
                        Positioned(
                          right: 8,
                          child: Icon(Icons.menu_book_rounded,
                              color: Colors.teal.shade700, size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ModePanel extends StatefulWidget {
  const _ModePanel({
    required this.label,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.gradient,
    required this.ambientIcon,
    required this.ambientPhase,
    required this.iconsDriftUp,
    required this.arrowAlignment,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final String description;
  final IconData icon;
  final List<Color> gradient;
  final IconData ambientIcon;
  final double ambientPhase;
  final bool iconsDriftUp;
  final Alignment arrowAlignment;
  final VoidCallback onTap;

  @override
  State<_ModePanel> createState() => _ModePanelState();
}

class _ModePanelState extends State<_ModePanel> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: widget.gradient,
            ),
          ),
          child: Stack(
            children: [
              ..._ambientIcons(),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.icon, size: 52, color: Colors.white),
                      const SizedBox(height: 12),
                      Text(
                        widget.label,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.description,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: widget.arrowAlignment,
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Icon(
                    widget.iconsDriftUp
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _ambientIcons() {
    return List.generate(3, (i) {
      final phase = (widget.ambientPhase + i * 0.3) % 1.0;
      final drift = math.sin(phase * math.pi) * 10;
      final dy = widget.iconsDriftUp ? -drift : drift;
      return Positioned(
        left: 30.0 + i * 90,
        top: widget.iconsDriftUp ? 24 + dy : null,
        bottom: widget.iconsDriftUp ? null : 24 + dy,
        child: Opacity(
          opacity: 0.25,
          child: Icon(widget.ambientIcon,
              color: Colors.white, size: 18 + i * 3.0),
        ),
      );
    });
  }
}