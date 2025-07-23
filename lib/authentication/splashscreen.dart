import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kilimomkononi/authentication/registration.dart';
import 'package:kilimomkononi/home.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);

    // Check authentication state and navigate after the splash duration
    SchedulerBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          _navigateBasedOnAuthState();
        }
      });
    });
  }

  Future<void> _navigateBasedOnAuthState() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // User is logged in, go to HomePage
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } else {
      // User is not logged in, go to LoginScreen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const RegistrationScreen()),
      );
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
        children: [
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Transform.rotate(
                angle: vector.radians(_animation.value * 360),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.lerp(Colors.green.shade300, Colors.blue.shade300, _animation.value)!,
                        Color.lerp(Colors.blue.shade300, Colors.green.shade300, _animation.value)!,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Welcome to KilimoMkononi',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildIconWithTooltip(Icons.cloud, 'Weather Forecast'),
                    _buildIconWithTooltip(Icons.bug_report, 'Pest Management'),
                    _buildIconWithTooltip(Icons.landscape, 'Soil Testing'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconWithTooltip(IconData icon, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: Icon(icon, size: 40, color: Colors.white),
    );
  }
}