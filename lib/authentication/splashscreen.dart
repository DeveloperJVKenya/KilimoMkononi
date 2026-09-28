// lib/authentication/splashscreen.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Splash screen: a short choreographed entrance that tells Kilimo
/// Mkononi's story in one motion — a farming-green glow rises from below,
/// a learning-teal glow settles from above, and the two meet at the centre
/// to form the app's mark before the tagline "Grow. Learn. Thrive." reveals
/// word by word.
///
/// The entrance animation runs on its own clock; navigation is driven by
/// [_checkAuthAndNavigate]. First-time visitors continue as soon as the
/// entrance finishes (~3 s, or a tap) instead of a fixed 8 s wait; returning
/// users go straight to their home screen as before. Devices with "reduce
/// motion" turned on skip the animation.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entry;
  late final AnimationController _pulse;
  // Continuous clock for the drifting particles.
  late final AnimationController _drift;
  late final TickerFuture _entryDone;
  bool _navigated = false;
  // First-time visitor (not signed in) — may tap to continue.
  bool _canSkip = false;

  late final Animation<double> _topGlow;
  late final Animation<double> _bottomGlow;
  late final Animation<double> _dividerOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _wordGrow;
  late final Animation<double> _wordLearn;
  late final Animation<double> _wordThrive;
  late final Animation<double> _featuresOpacity;
  late final Animation<double> _loadingOpacity;

  Animation<double> _interval(
    double begin,
    double end, {
    Curve curve = Curves.easeOutCubic,
  }) {
    return CurvedAnimation(
      parent: _entry,
      curve: Interval(begin, end, curve: curve),
    );
  }

  @override
  void initState() {
    super.initState();

    _entry = AnimationController(
      duration: const Duration(milliseconds: 2600),
      vsync: this,
    );
    _entryDone = _entry.forward();

    _pulse = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);

    _drift = AnimationController(
      duration: const Duration(seconds: 9),
      vsync: this,
    )..repeat();

    _topGlow = _interval(0.0, 0.40);
    _bottomGlow = _interval(0.0, 0.40);
    _dividerOpacity = _interval(0.28, 0.45);
    _logoScale = _interval(0.22, 0.50, curve: Curves.elasticOut);
    _logoOpacity = _interval(0.22, 0.38);
    _titleOpacity = _interval(0.40, 0.55);
    _wordGrow = _interval(0.50, 0.60);
    _wordLearn = _interval(0.58, 0.68);
    _wordThrive = _interval(0.66, 0.76);
    _featuresOpacity = _interval(0.74, 0.88);
    _loadingOpacity = _interval(0.86, 1.0);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Respect the system's "reduce motion" setting.
      if (MediaQuery.of(context).disableAnimations) {
        _entry.value = 1;
        _pulse.stop();
        _drift.stop();
      }
      _checkAuthAndNavigate();
    });
  }

  void _go(String route) {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacementNamed(route);
  }

  Future<void> _checkAuthAndNavigate() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // New visitor → let the entrance finish (or tap), then mode selection.
      if (mounted) setState(() => _canSkip = true);
      try {
        await _entryDone.orCancel;
      } on TickerCanceled {
        // Jumped to the end (reduce motion) or disposed — _go() checks mounted.
      }
      await Future.delayed(const Duration(milliseconds: 650));
      _go('/mode_selection');
      return;
    }

    try {
      final uid = user.uid;

      // Check if Farmer
      final farmerSnap = await FirebaseFirestore.instance
          .collection('Users')
          .doc(uid)
          .get();

      if (farmerSnap.exists) {
        final data = farmerSnap.data()!;
        if (data['isDisabled'] == true) {
          await FirebaseAuth.instance.signOut();
          _go('/mode_selection');
          return;
        }
        // Returning farmer → short splash, then home
        await Future.delayed(const Duration(seconds: 2));
        _go('/home');
        return;
      }

      // Check if Education
      final eduSnap = await FirebaseFirestore.instance
          .collection('EducationUsers')
          .doc(uid)
          .get();

      if (eduSnap.exists) {
        final data = eduSnap.data()!;
        if (data['isDisabled'] == true) {
          // Add if field exists
          await FirebaseAuth.instance.signOut();
          _go('/mode_selection');
          return;
        }
        // Returning education user → short splash, then edu home
        await Future.delayed(const Duration(seconds: 2));
        _go('/edu_home');
        return;
      }

      // No profile → sign out and mode selection
      await FirebaseAuth.instance.signOut();
      await Future.delayed(const Duration(seconds: 2));
      _go('/mode_selection');
    } catch (e) {
      debugPrint('Auth check error: $e');
      _go('/mode_selection');
    }
  }

  @override
  void dispose() {
    _entry.dispose();
    _pulse.dispose();
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF12241A),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_canSkip) _go('/mode_selection');
        },
        child: AnimatedBuilder(
          animation: Listenable.merge([_entry, _pulse, _drift]),
          builder: (context, _) {
            return Stack(
              fit: StackFit.expand,
              children: [
                _buildTopHalf(size),
                _buildBottomHalf(size),
                IgnorePointer(
                  child: CustomPaint(
                    painter: _ParticlesPainter(
                      time: _drift.value,
                      opacity: _topGlow.value.clamp(0.0, 1.0),
                    ),
                  ),
                ),
                _buildDivider(size),
                SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 2),
                      _buildLogo(),
                      const SizedBox(height: 18),
                      _buildTitle(),
                      const SizedBox(height: 10),
                      _buildTagline(),
                      const Spacer(flex: 3),
                      _buildFeatures(),
                      const SizedBox(height: 32),
                      _buildLoading(),
                      const SizedBox(height: 36),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Top half: a farming-green panel that slides down into place, with a
  /// few leaf icons drifting gently once revealed.
  Widget _buildTopHalf(Size size) {
    final t = _topGlow.value.clamp(0.0, 1.0);
    return Positioned(
      top: -size.height * 0.5 * (1 - t),
      left: 0,
      right: 0,
      height: size.height * 0.5,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green.shade700, Colors.green.shade400],
          ),
        ),
        child: Stack(
          children: List.generate(3, (i) {
            final phase = (_pulse.value + i * 0.33) % 1.0;
            final dy = -math.sin(phase * math.pi) * 14;
            return Positioned(
              left: size.width * (0.22 + i * 0.28),
              top: size.height * 0.10 + dy,
              child: Opacity(
                opacity: t * 0.7,
                child: Icon(
                  Icons.eco,
                  color: Colors.white.withValues(alpha: 0.55),
                  size: 22 + i * 4.0,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  /// Bottom half: a learning-teal panel that slides up into place, with a
  /// few book icons drifting gently once revealed.
  Widget _buildBottomHalf(Size size) {
    final t = _bottomGlow.value.clamp(0.0, 1.0);
    return Positioned(
      bottom: -size.height * 0.5 * (1 - t),
      left: 0,
      right: 0,
      height: size.height * 0.5,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.teal.shade400, Colors.teal.shade800],
          ),
        ),
        child: Stack(
          children: List.generate(3, (i) {
            final phase = (_pulse.value + 0.5 + i * 0.31) % 1.0;
            final dy = math.sin(phase * math.pi) * 14;
            return Positioned(
              right: size.width * (0.20 + i * 0.28),
              bottom: size.height * 0.08 + dy,
              child: Opacity(
                opacity: t * 0.7,
                child: Icon(
                  Icons.menu_book_rounded,
                  color: Colors.white.withValues(alpha: 0.55),
                  size: 20 + i * 4.0,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildDivider(Size size) {
    final opacity = _dividerOpacity.value.clamp(0.0, 1.0);
    if (opacity <= 0) return const SizedBox.shrink();
    return Positioned(
      top: size.height / 2 - 1,
      left: 0,
      right: 0,
      child: Opacity(
        opacity: opacity,
        child: Container(
          height: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.0),
                Colors.white.withValues(alpha: 0.8),
                Colors.white.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The two halves meet as a single badge: a leaf for farming, a book
  /// for learning, sharing one circle.
  Widget _buildLogo() {
    final opacity = _logoOpacity.value.clamp(0.0, 1.0);
    final scale = math.max(0.0, _logoScale.value);
    if (opacity <= 0) return const SizedBox(height: 84);
    final ring = _pulse.value;
    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Soft glow ring that breathes with the pulse.
            Container(
              width: 84 + 26 * ring,
              height: 84 + 26 * ring,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35 * (1 - ring)),
                  width: 2,
                ),
              ),
            ),
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 14,
                    child: Icon(
                      Icons.eco,
                      color: Colors.green.shade600,
                      size: 30,
                    ),
                  ),
                  Positioned(
                    right: 14,
                    child: Icon(
                      Icons.menu_book_rounded,
                      color: Colors.teal.shade700,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    final opacity = _titleOpacity.value.clamp(0.0, 1.0);
    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, (1 - opacity) * 10),
        child: ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (rect) {
            final x = -1.0 + 3.0 * _drift.value; // sweeps left → right
            return LinearGradient(
              begin: Alignment(x - 0.6, 0),
              end: Alignment(x + 0.6, 0),
              colors: const [Colors.white, Color(0xFFE8F5E9), Colors.white],
              stops: const [0.35, 0.5, 0.65],
            ).createShader(rect);
          },
          child: const Text(
            'Kilimo Mkononi',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.4,
              shadows: [
                Shadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTagline() {
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        _word('Grow', _wordGrow.value, Colors.greenAccent.shade100),
        _dot(_wordLearn.value > 0 ? 1 : 0),
        _word('Learn', _wordLearn.value, Colors.white),
        _dot(_wordThrive.value > 0 ? 1 : 0),
        _word('Thrive', _wordThrive.value, Colors.tealAccent.shade100),
      ],
    );
  }

  Widget _word(String text, double opacity, Color color) {
    final clamped = opacity.clamp(0.0, 1.0);
    return Opacity(
      opacity: clamped,
      child: Transform.translate(
        offset: Offset(0, (1 - clamped) * 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _dot(double opacity) {
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6),
        child: Text('•', style: TextStyle(color: Colors.white70)),
      ),
    );
  }

  Widget _buildFeatures() {
    final opacity = _featuresOpacity.value.clamp(0.0, 1.0);
    return Opacity(
      opacity: opacity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: const [
          _FeatureIcon(icon: Icons.wb_sunny, label: 'Weather'),
          _FeatureIcon(icon: Icons.bug_report, label: 'Pests'),
          _FeatureIcon(icon: Icons.analytics, label: 'Insights'),
          _FeatureIcon(icon: Icons.school, label: 'Learn'),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    final opacity = _loadingOpacity.value.clamp(0.0, 1.0);
    return Opacity(
      opacity: opacity,
      child: Column(
        children: [
          SizedBox(
            width: 200,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                // Fills with the entrance, then keeps moving while we check
                // the account.
                value: _entry.isCompleted ? null : _entry.value,
                minHeight: 5,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                valueColor: const AlwaysStoppedAnimation(Color(0xFFFFD54F)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _canSkip && _entry.isCompleted
                ? 'Tap anywhere to continue'
                : 'Preparing your experience…',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureIcon extends StatelessWidget {
  const _FeatureIcon({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 30, color: Colors.white),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}

/// Small glowing seeds drifting upward across the whole splash.
class _ParticlesPainter extends CustomPainter {
  _ParticlesPainter({required this.time, required this.opacity});
  final double time; // 0..1, repeating
  final double opacity;

  static final _seeds = List.generate(22, (i) {
    final r = math.Random(i * 7919);
    return (
      r.nextDouble(),
      r.nextDouble(),
      1.2 + r.nextDouble() * 2.6,
      0.4 + r.nextDouble() * 0.6,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final paint = Paint();
    for (final (x, y0, radius, speed) in _seeds) {
      final y = (y0 - time * speed) % 1.0;
      final sway = math.sin((time * 2 + x) * math.pi * 2) * 10;
      final fade = math.sin(
        y * math.pi,
      ); // fade in at the bottom, out at the top
      paint.color = Colors.white.withValues(alpha: 0.28 * fade * opacity);
      canvas.drawCircle(
        Offset(x * size.width + sway, y * size.height),
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlesPainter old) =>
      old.time != time || old.opacity != opacity;
}
