// Settings, help, legal and manuals screens render at phone width (360 px)
// without overflow, with Firebase-backed providers replaced by test data.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kilimomkononi/screens/manuals_screen.dart';
import 'package:kilimomkononi/settings/about_kilimo_mkononi_screen.dart';
import 'package:kilimomkononi/settings/account_settings_screen.dart';
import 'package:kilimomkononi/settings/contact_us_screen.dart';
import 'package:kilimomkononi/settings/faq_screen.dart';
import 'package:kilimomkononi/settings/profile_edit_screen.dart';
import 'package:kilimomkononi/settings/settings_providers.dart';
import 'package:kilimomkononi/settings/settings_screen.dart';
import 'package:kilimomkononi/settings/terms_and_conditions_screen.dart';

const _jane = ProfileSummary(
  uid: 'u1',
  fullName: 'Jane Wanjiku',
  email: 'jane@farm.ke',
  phone: '0712345678',
  county: 'Nakuru',
  constituency: 'Njoro',
  ward: 'Mauche',
);

final _overrides = [
  settingsAuthProvider.overrideWith((ref) => Stream.value(null)),
  settingsProfileProvider.overrideWith((ref, edu) => Stream.value(_jane)),
  mySupportMessagesProvider.overrideWith((ref) => Stream.value(const [])),
];

Future<void> _pump(WidgetTester t, Widget screen, {List extra = const []}) async {
  SharedPreferences.setMockInitialValues({});
  t.view.physicalSize = const Size(360, 780);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(overrides: [..._overrides, ...extra], child: MaterialApp(home: screen)));
  await t.pumpAndSettle();
}

/// Scrolls the main list to the end so every row is laid out once.
Future<void> _scrollThrough(WidgetTester t) async {
  final scrollable = find.byType(Scrollable).first;
  for (var i = 0; i < 12; i++) {
    await t.drag(scrollable, const Offset(0, -400));
    await t.pump();
  }
  await t.pumpAndSettle();
}

void main() {
  testWidgets('Settings: profile card, sections, appearance values, log out', (t) async {
    await _pump(t, const SettingsScreen());
    expect(find.text('Jane Wanjiku'), findsOneWidget);
    expect(find.text('ACCOUNT'), findsOneWidget);
    expect(find.text('Text size'), findsOneWidget);
    expect(find.text('Default'), findsWidgets);
    await _scrollThrough(t);
    expect(find.text('Log out'), findsOneWidget);
    expect(find.textContaining('Kilimo Mkononi v'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('Settings as a Home tab has no back button', (t) async {
    await _pump(t, const SettingsScreen(embedded: true));
    expect(find.byTooltip('Back'), findsNothing);
  });

  testWidgets('Edit profile: pre-filled, location pickers, phone validation', (t) async {
    await _pump(t, const ProfileEditScreen());
    expect(find.text('Jane Wanjiku'), findsOneWidget);
    expect(find.text('0712345678'), findsOneWidget);
    expect(find.text('Nakuru'), findsOneWidget);
    expect(find.text('Njoro'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextFormField, '0712345678'), '12345');
    final save = find.text('Save changes');
    await t.scrollUntilVisible(save, 300, scrollable: find.byType(Scrollable).first);
    await t.ensureVisible(save);
    await t.pumpAndSettle();
    await t.tap(save);
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('Use a Kenyan number, e.g. 0712 345 678'), -300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Use a Kenyan number, e.g. 0712 345 678'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('Account & security (signed out view) and delete sheet', (t) async {
    await _pump(t, const AccountSettingsScreen());
    expect(find.text('Send password reset link'), findsOneWidget);
    await _scrollThrough(t);
    await t.tap(find.text('Delete account and data'));
    await t.pumpAndSettle();
    expect(find.text('Delete your account?'), findsOneWidget);
    await t.tap(find.text('Delete forever'));
    await t.pumpAndSettle();
    expect(find.text('Type DELETE to confirm'), findsWidgets); // validation blocks it
    expect(t.takeException(), isNull);
  });

  testWidgets('Contact us: real contacts, form validation', (t) async {
    await _pump(t, const ContactUsScreen());
    expect(find.text('+254 795 802 020'), findsOneWidget);
    expect(find.text('support@jvalmacis.co.ke'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    final send = find.text('Send message');
    await t.scrollUntilVisible(send, 300, scrollable: find.byType(Scrollable).first);
    await t.ensureVisible(send);
    await t.pumpAndSettle();
    await t.tap(send);
    await t.pumpAndSettle();
    expect(find.text('Please write a little more (10+ characters)'), findsOneWidget);
    // Name and email came from the profile.
    expect(find.text('Jane Wanjiku'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('Help centre: search and expand', (t) async {
    await _pump(t, const FAQScreen());
    await t.enterText(find.byType(TextField), 'password');
    await t.pumpAndSettle();
    expect(find.text('How do I change my password or email?'), findsOneWidget);
    expect(find.text('Where do the market prices come from?'), findsNothing);
    await t.tap(find.text('I forgot my password'));
    await t.pumpAndSettle();
    expect(find.textContaining('Forgot password?'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('About and Terms (contents jump to a section)', (t) async {
    await _pump(t, const AboutKilimoMkononiScreen());
    expect(find.textContaining('Version'), findsOneWidget);
    await _scrollThrough(t);
    expect(t.takeException(), isNull);

    await _pump(t, const TermsAndConditionsScreen());
    final toc = find.text('14. Governing Law');
    expect(toc, findsOneWidget);
    await t.ensureVisible(toc);
    await t.pumpAndSettle();
    await t.tap(toc);
    await t.pumpAndSettle();
    // The section heading is now at the top of the screen.
    expect(t.getTopLeft(find.text('Governing Law')).dy, lessThan(200));
    expect(find.byTooltip('Back to top'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('Manuals: all listed, crop filter, search, empty state', (t) async {
    final manuals = [
      Manual(
          title: 'Maize production guide',
          fileName: 'maize.pdf',
          fullPath: 'manuals/1_maize.pdf',
          url: 'https://x/m',
          crop: 'maize',
          sizeBytes: 2400000,
          uploadedAt: DateTime(2026, 9, 1)),
      Manual(
          title: 'Bean pests',
          fileName: 'beans.pdf',
          fullPath: 'manuals/2_beans.pdf',
          url: 'https://x/b',
          crop: 'beans',
          uploadedAt: DateTime(2026, 9, 5)),
    ];
    await _pump(t, const ManualsScreen(), extra: [
      manualsProvider.overrideWith((ref) async => manuals),
      manualAdminProvider.overrideWith((ref) async => false),
      savedManualsProvider.overrideWith((ref) async => {'beans.pdf'}),
    ]);
    expect(find.text('2 manuals · 1 saved offline'), findsOneWidget);
    expect(find.text('Saved offline'), findsOneWidget);
    expect(find.text('Upload manual'), findsNothing);
    await t.tap(find.textContaining('Maize · 1'));
    await t.pumpAndSettle();
    expect(find.text('Bean pests'), findsNothing);
    expect(find.text('Maize production guide'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'storage');
    await t.pumpAndSettle();
    expect(find.text('No manuals match'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
