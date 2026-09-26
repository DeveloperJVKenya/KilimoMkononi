// main.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
// Riverpod runs alongside `provider` during the migration. Only ProviderScope
// is imported here — both packages define a class named `Provider`.
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;

// connectivity_plus — import here so the ConnectivityService provider
// is available to the entire widget tree (both Farmer and Education).
// You do NOT need to import it in individual screen files unless a screen
// is listening to connectivity changes directly.  Instead, screens should
// call  context.read<ConnectivityService>()  or wrap with
// Consumer<ConnectivityService>.
// import 'package:connectivity_plus/connectivity_plus.dart';

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

// Notifications (local + push) — see lib/services/notification_service.dart
import 'package:kilimomkononi/services/notification_service.dart';
import 'package:kilimomkononi/screens/Field%20Data%20Input/weather_station_screen.dart';
import 'package:kilimomkononi/settings/notifications_screen.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Push while the app is closed/backgrounded, then one-time notification
  // setup (channels, timezone, FCM listeners, tap routing).
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  NotificationService.routeHandler = _openNotificationRoute;
  await NotificationService.init();

  runApp(
    // Riverpod scope (new state, e.g. the Admin Dashboard) wraps the existing
    // `provider` setup, so both work while screens migrate incrementally.
    ProviderScope(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthStateService()),
          ChangeNotifierProvider(create: (_) => UserProfile()),
          // ConnectivityService wraps connectivity_plus and exposes
          // isOnline / connectionType to the whole app via Provider.
          ChangeNotifierProvider(create: (_) => ConnectivityService()),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

/// Opens the screen a tapped notification points to (`route` in the push).
void _openNotificationRoute(String route, Map<String, String> args) {
  final nav = NotificationService.navigatorKey.currentState;
  if (nav == null) return;
  switch (route) {
    case KmRoute.weatherStation:
      nav.push(MaterialPageRoute(
          builder: (_) => WeatherStationScreen(initialStationId: args['gatewayId'])));
    case KmRoute.notifications:
      nav.push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    case KmRoute.eduHome:
      nav.pushNamed('/edu_home');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kilimo Mkononi',
      navigatorKey: NotificationService.navigatorKey,
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
        '/edu_tier_selection': (_) => const EducationTierSelectionScreen(),
        '/primary_home_screen': (_) => const PrimaryHomeScreen(),
        '/terms': (_) => const TermsAndConditionsScreen(isEducation: false),
        '/privacy': (_) => const PrivacyPolicyScreen(isEducation: false),
      },
    );
  }
}
