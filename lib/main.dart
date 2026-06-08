// main.dart

// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

// connectivity_plus — import here so the ConnectivityService provider
// is available to the entire widget tree (both Farmer and Education).
// You do NOT need to import it in individual screen files unless a screen
// is listening to connectivity changes directly.  Instead, screens should
// call  context.read<ConnectivityService>()  or wrap with
// Consumer<ConnectivityService>.
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:kilimomkononi/authentication/splashscreen.dart';
import 'package:kilimomkononi/authentication/login.dart';
import 'package:kilimomkononi/authentication/registration.dart';
import 'package:kilimomkononi/home.dart';

// Education
import 'package:kilimomkononi/education/mode_selection.dart';
import 'package:kilimomkononi/education/education_login.dart';
import 'package:kilimomkononi/education/education_registration.dart';
import 'package:kilimomkononi/education/education_home.dart';
import 'package:kilimomkononi/education/education_tier_selection.dart';
import 'package:kilimomkononi/education/primary/primary_home_screen.dart';

// Services / providers
import 'package:kilimomkononi/services/auth_state_service.dart';
import 'package:kilimomkononi/services/connectivity_service.dart'; // <-- create this file (see note below)

// Policy screens
import 'package:kilimomkononi/settings/terms_and_conditions_screen.dart';
import 'package:kilimomkononi/settings/privacy_policy_screen.dart';

// User profile provider
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
        ChangeNotifierProvider(create: (_) => UserProfile()),
        // ConnectivityService wraps connectivity_plus and exposes
        // isOnline / connectionType to the whole app via Provider.
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
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
        '/login':               (_) => const LoginScreen(),
        '/register1':           (_) => const RegistrationScreen(),
        '/home':                (_) => const HomePage(),
        '/mode_selection':      (_) => const ModeSelectionScreen(),
        '/edu_login':           (_) => const EducationLoginScreen(),
        '/edu_register':        (_) => const EducationRegistrationScreen(),
        '/edu_home':            (_) => const EducationHomeScreen(),
        '/edu_tier_selection':  (_) => const EducationTierSelectionScreen(),
        '/primary_home_screen': (_) => const PrimaryHomeScreen(),
        '/terms':   (_) => const TermsAndConditionsScreen(isEducation: false),
        '/privacy': (_) => const PrivacyPolicyScreen(isEducation: false),
      },
    );
  }
}