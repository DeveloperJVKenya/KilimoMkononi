import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kilimomkononi/authentication/login.dart';
import 'package:kilimomkononi/authentication/registration.dart';
import 'package:kilimomkononi/authentication/widgets/auth_kit.dart';

void main() {
  group('validators', () {
    test('email', () {
      expect(validateEmail('jane@farm.co.ke'), isNull);
      expect(validateEmail(' jane@farm.co.ke '), isNull);
      expect(validateEmail('jane@farm'), isNotNull);
      expect(validateEmail(''), isNotNull);
    });
    test('Kenyan phone formats', () {
      for (final ok in ['0712345678', '0712 345 678', '+254712345678', '254-712-345678', '712345678']) {
        expect(validatePhone(ok), isNull, reason: ok);
      }
      for (final bad in ['', '12345', 'phone', '07123456789012']) {
        expect(validatePhone(bad), isNotNull, reason: bad);
      }
    });
    test('name', () {
      expect(validateName('Jane Wanjiku'), isNull);
      expect(validateName(' J '), isNotNull);
    });
    test('password strength 0–4', () {
      expect(passwordStrength(''), 0);
      expect(passwordStrength('abc'), 1);
      expect(passwordStrength('abcdefgh1'), 2);
      expect(passwordStrength('Abcdefgh1'), 3);
      expect(passwordStrength('Abcdefgh1234!'), 4);
    });
    test('friendly Firebase messages', () {
      expect(authErrorMessage('invalid-credential'), 'The email or password is incorrect.');
      expect(authErrorMessage('network-request-failed'), contains('internet'));
      // Firebase's own text for an unknown code is never shown — it's often technical.
      expect(authErrorMessage('something-new', 'Raw [INTERNAL]'), 'Something went wrong. Please try again.');
    });
  });

  Future<void> sized(WidgetTester tester, double width, double height) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Finder field(String label) => find.ancestor(of: find.text(label), matching: find.byType(TextField));

  group('login', () {
    testWidgets('desktop: brand panel, form capped at 440 px', (tester) async {
      await sized(tester, 1280, 820);
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Grow. Learn. Thrive.'), findsOneWidget);
      expect(tester.getSize(field('Email address')).width, lessThanOrEqualTo(440));
      expect(tester.takeException(), isNull);
    });

    testWidgets('phone: compact header, no overflow', (tester) async {
      await sized(tester, 360, 740);
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Grow. Learn. Thrive.'), findsNothing);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Enter submits: errors show and focus goes to the first problem', (tester) async {
      await sized(tester, 1280, 820);
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pumpAndSettle();
      await tester.tap(field('Password'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);
      final email = tester.widget<TextField>(field('Email address'));
      expect(email.focusNode?.hasFocus, isTrue);
    });
  });

  group('registration', () {
    testWidgets('desktop: sections in two columns, capped width', (tester) async {
      await sized(tester, 1400, 1000);
      await tester.pumpWidget(const MaterialApp(home: RegistrationScreen()));
      await tester.pumpAndSettle();
      final name = tester.getTopLeft(field('Full name'));
      final phone = tester.getTopLeft(field('Phone number'));
      expect(name.dy, phone.dy); // side by side
      expect(phone.dx, greaterThan(name.dx));
      expect(tester.getSize(field('Email address')).width, lessThanOrEqualTo(580));
      expect(find.text('Farm location'), findsOneWidget);
      expect(find.text('Security'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('phone: single column, no overflow', (tester) async {
      await sized(tester, 360, 1800);
      await tester.pumpWidget(const MaterialApp(home: RegistrationScreen()));
      await tester.pumpAndSettle();
      final name = tester.getTopLeft(field('Full name'));
      final phone = tester.getTopLeft(field('Phone number'));
      expect(phone.dy, greaterThan(name.dy)); // stacked
      expect(tester.takeException(), isNull);
    });

    testWidgets('Enter validates everything and focuses the first missing field', (tester) async {
      await sized(tester, 1400, 1000);
      await tester.pumpWidget(const MaterialApp(home: RegistrationScreen()));
      await tester.pumpAndSettle();
      await tester.enterText(field('Full name'), 'Jane Wanjiku');
      await tester.tap(field('Email address'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Enter your phone number'), findsOneWidget);
      expect(find.text('Please accept the terms to continue'), findsOneWidget);
      expect(tester.widget<TextField>(field('Phone number')).focusNode?.hasFocus, isTrue);
    });

    testWidgets('password strength and confirmation', (tester) async {
      await sized(tester, 1400, 1000);
      await tester.pumpWidget(const MaterialApp(home: RegistrationScreen()));
      await tester.pumpAndSettle();
      await tester.enterText(field('Password'), 'Abcdefgh1234!');
      await tester.pump();
      expect(find.text('Strong'), findsOneWidget);
      await tester.enterText(field('Confirm password'), 'different');
      await tester.tap(field('Confirm password'));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Passwords don\'t match'), findsOneWidget);
    });
  });
}
