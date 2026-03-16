// lib/authentication/splashscreen.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // Rotating gradient animation
    _controller = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);

    // Check auth state and navigate
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
      Navigator.of(context).pushReplacementNamed('/mode_selection');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _animation,
            builder: (context, _) {
              return Transform.rotate(
                angle: vector.radians(_animation.value * 360),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.lerp(Colors.green.shade400, Colors.teal.shade400, _animation.value)!,
                        Color.lerp(Colors.teal.shade400, Colors.green.shade400, _animation.value)!,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Kilimo Mkononi',
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Smart Farming & Education Platform',
                    style: TextStyle(fontSize: 18, color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 60),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: const [
                      _FeatureIcon(icon: Icons.wb_sunny, label: 'Weather'),
                      _FeatureIcon(icon: Icons.bug_report, label: 'Pests'),
                      _FeatureIcon(icon: Icons.analytics, label: 'Insights'),
                      _FeatureIcon(icon: Icons.school, label: 'Learn'),
                    ],
                  ),
                  const SizedBox(height: 100),
                  const SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 4),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Loading your experience...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
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
        Icon(icon, size: 48, color: Colors.white),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
      ],
    );
  }
}