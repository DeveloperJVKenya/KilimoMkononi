// main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'package:kilimomkononi/authentication/splashscreen.dart';
import 'package:kilimomkononi/authentication/login.dart';
import 'package:kilimomkononi/authentication/registration.dart';
import 'package:kilimomkononi/home.dart';

// Education
import 'package:kilimomkononi/education/mode_selection.dart';
import 'package:kilimomkononi/education/education_login.dart';
import 'package:kilimomkononi/education/education_registration.dart';
import 'package:kilimomkononi/education/education_home.dart';

// Auth State Service
import 'package:kilimomkononi/services/auth_state_service.dart';

// Policy screens (used in registration links + settings)
import 'package:kilimomkononi/settings/terms_and_conditions_screen.dart';
import 'package:kilimomkononi/settings/privacy_policy_screen.dart';

// ADD THIS — matches the import already in edit_profile_screen.dart
import 'package:kilimomkononi/settings/providers/user_profile_provider.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthStateService()),
        ChangeNotifierProvider(create: (_) => UserProfile()), // ADD THIS
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kilimo Mkononi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register1': (_) => const RegistrationScreen(),
        '/home': (_) => const HomePage(),
        '/mode_selection': (_) => const ModeSelectionScreen(),
        '/edu_login': (_) => const EducationLoginScreen(),
        '/edu_register': (_) => const EducationRegistrationScreen(),
        '/edu_home': (_) => const EducationHomeScreen(),

        // Policy routes — linked from registration checkboxes
        '/terms': (_) => const TermsAndConditionsScreen(isEducation: false),
        '/privacy': (_) => const PrivacyPolicyScreen(isEducation: false),
      },
    );
  }
}