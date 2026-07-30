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
/// The entrance animation is purely decorative and runs on its own clock.
/// Real navigation is still driven entirely by [_checkAuthAndNavigate],
/// whose logic and timing are unchanged from the previous version.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entry;
  late final AnimationController _pulse;

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

  Animation<double> _interval(double begin, double end,
      {Curve curve = Curves.easeOutCubic}) {
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
    )..forward();

    _pulse = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);

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

    // Check auth state and navigate (unchanged from previous version).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndNavigate();
    });
  }

  Future<void> _checkAuthAndNavigate() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // New user → show splash for 8 seconds, then mode selection
      await Future.delayed(const Duration(seconds: 8));
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/mode_selection');
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
          if (!mounted) return;
          Navigator.of(context).pushReplacementNamed('/mode_selection');
          return;
        }
        // Returning farmer → short splash, then home
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/home');
        return;
      }

      // Check if Education
      final eduSnap = await FirebaseFirestore.instance
          .collection('EducationUsers')
          .doc(uid)
          .get();

      if (eduSnap.exists) {
        final data = eduSnap.data()!;
        if (data['isDisabled'] == true) { // Add if field exists
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          Navigator.of(context).pushReplacementNamed('/mode_selection');
          return;
        }
        // Returning education user → short splash, then edu home
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/edu_home');
        return;
      }

      // No profile → sign out and mode selection
      await FirebaseAuth.instance.signOut();
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/mode_selection');
    } catch (e) {
      debugPrint('Auth check error: $e');
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/mode_selection');
    }
  }

  @override
  void dispose() {
    _entry.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF12241A),
      body: AnimatedBuilder(
        animation: Listenable.merge([_entry, _pulse]),
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              _buildTopHalf(size),
              _buildBottomHalf(size),
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
                child: Icon(Icons.eco,
                    color: Colors.white.withValues(alpha: 0.55),
                    size: 22 + i * 4.0),
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
                child: Icon(Icons.menu_book_rounded,
                    color: Colors.white.withValues(alpha: 0.55),
                    size: 20 + i * 4.0),
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
    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: Container(
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
                child: Icon(Icons.eco, color: Colors.green.shade600, size: 30),
              ),
              Positioned(
                right: 14,
                child: Icon(Icons.menu_book_rounded,
                    color: Colors.teal.shade700, size: 28),
              ),
            ],
          ),
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
        child: const Text(
          'Kilimo Mkononi',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.4,
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
              fontSize: 18, fontWeight: FontWeight.w600, color: color),
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
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 3),
          ),
          const SizedBox(height: 16),
          Text(
            'Preparing your experience...',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
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
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}