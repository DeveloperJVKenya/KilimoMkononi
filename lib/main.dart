import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:kilimomkononi/authentication/splashscreen.dart';
import 'package:kilimomkononi/authentication/login.dart';
import 'package:kilimomkononi/authentication/registration.dart';
import 'package:kilimomkononi/home.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KilimoApp',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegistrationScreen(),
        '/home': (context) => const HomePage(),
      },
    );
  }
}
