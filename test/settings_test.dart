import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kilimomkononi/screens/manuals_screen.dart';
import 'package:kilimomkononi/settings/appearance/appearance.dart';
import 'package:kilimomkononi/settings/appearance/appearance_screen.dart';
import 'package:kilimomkononi/settings/faq_screen.dart';
import 'package:kilimomkononi/settings/licenses_screen.dart';
import 'package:kilimomkononi/settings/profile_edit_screen.dart';
import 'package:kilimomkononi/settings/settings_providers.dart';
import 'package:kilimomkononi/settings/widgets/legal_kit.dart';
import 'package:kilimomkononi/settings/widgets/settings_kit.dart';

void main() {
  test('app version shown in Settings matches pubspec.yaml', () {
    final line = File('pubspec.yaml').readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    expect(line.trim(), 'version: $kAppVersion+$kAppBuild');
  });

  group('appearance', () {
    test('text size is clamped and labelled', () {
      const s = AppearanceSettings();
      expect(s.isDefault, isTrue);
      expect(s.textSizeLabel, 'Default');
      expect(s.copyWith(textScale: 9).textScale, AppearanceSettings.maxScale);
      expect(s.copyWith(textScale: 0.1).textScale, AppearanceSettings.minScale);
      expect(s.copyWith(textScale: 1.15).textSizeLabel, 'Large');
      expect(s.copyWith(textScale: 1.45).textSizeLabel, 'Largest');
    });

    test('saved on the device and read back', () async {
      SharedPreferences.setMockInitialValues({});
      final p = await SharedPreferences.getInstance();
      const s = AppearanceSettings(textScale: 1.3, font: AppFont.lato, boldText: true, compact: true);
      await s.save(p);
      expect(AppearanceSettings.fromPrefs(p), s);
    });

    test('compact layout and default font in the theme', () {
      final base = ThemeData(useMaterial3: true);
      expect(appearanceTheme(base, const AppearanceSettings(compact: true)).visualDensity, VisualDensity.compact);
      expect(appearanceTheme(base, const AppearanceSettings()).textTheme, base.textTheme);
    });

    testWidgets('AppearanceScope scales text and applies bold/motion', (t) async {
      late MediaQueryData seen;
      await t.pumpWidget(MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.1)),
        child: AppearanceScope(
          settings: const AppearanceSettings(textScale: 1.2, boldText: true, reduceMotion: true),
          child: Builder(builder: (c) {
            seen = MediaQuery.of(c);
            return const SizedBox();
          }),
        ),
      ));
      expect(seen.textScaler.scale(10), closeTo(13.2, 0.001)); // phone 1.1 × ours 1.2
      expect(seen.boldText, isTrue);
      expect(seen.disableAnimations, isTrue);
    });

    testWidgets('Appearance screen: presets, switches and reset at phone width', (t) async {
      SharedPreferences.setMockInitialValues({});
      t.view.physicalSize = const Size(360, 780);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await t.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AppearanceScreen()),
      ));
      await t.pumpAndSettle();
      expect(find.text('Reset'), findsNothing);

      await t.tap(find.widgetWithText(ChoiceChip, 'Large'));
      await t.pumpAndSettle();
      expect(container.read(appearanceProvider).textScale, 1.15);
      expect(find.text('Reset'), findsOneWidget);

      await t.scrollUntilVisible(find.text('Bold text'), 300, scrollable: find.byType(Scrollable).first);
      await t.drag(find.byType(Scrollable).first, const Offset(0, -200)); // clear of the edge
      await t.pumpAndSettle();
      final boldSwitch = find.descendant(of: find.widgetWithText(SettingsSwitchTile, 'Bold text'), matching: find.byType(Switch));
      await t.tap(boldSwitch);
      await t.pumpAndSettle();
      expect(container.read(appearanceProvider).boldText, isTrue);
      expect((await SharedPreferences.getInstance()).getBool('appearance_boldText'), isTrue);

      await t.tap(find.text('Reset'));
      await t.pumpAndSettle();
      expect(find.text('Reset appearance?'), findsOneWidget); // asks first
      await t.tap(find.widgetWithText(FilledButton, 'Reset'));
      await t.pumpAndSettle();
      expect(container.read(appearanceProvider).isDefault, isTrue);
      expect(t.takeException(), isNull);
    });
  });

  group('profile & help', () {
    test('Kenyan phone numbers', () {
      expect(validateKenyanPhone('0712 345 678'), isNull);
      expect(validateKenyanPhone('+254712345678'), isNull);
      expect(validateKenyanPhone('0112345678'), isNull);
      expect(validateKenyanPhone('12345'), isNotNull);
      expect(validateKenyanPhone(''), isNotNull);
    });

    test('profile summary: initials, location, role', () {
      final p = ProfileSummary.fromMap('u1', {
        'fullName': 'Jane Wanjiku Kamau',
        'county': 'Nakuru',
        'constituency': 'Njoro',
        'ward': 'Mauche',
      });
      expect(p.initials, 'JK');
      expect(p.location, 'Mauche, Njoro, Nakuru');
      expect(p.roleLabel, 'Farmer');
      expect(p.imageBytes, isNull);
    });

    test('FAQ search looks in questions and answers', () {
      expect(kFarmerFaqs.where((f) => f.matches('offline')).length, greaterThanOrEqualTo(1));
      expect(kFarmerFaqs.where((f) => f.matches('KAMIS')).single.category, 'Market prices');
      expect(kFarmerFaqs.every((f) => f.matches('')), isTrue);
    });

    test('licences are grouped by package, A–Z', () {
      final g = groupLicenses([
        (['zeta', 'alpha'], 'MIT'),
        (['alpha'], 'BSD'),
      ]);
      expect(g.keys, ['alpha', 'zeta']);
      expect(g['alpha'], ['MIT', 'BSD']);
    });

    test('legal contents link to sections by number', () {
      expect(legalNumber('10. Privacy'), '10');
      expect(legalNumber('10.  Privacy'), '10');
      expect(legalNumber('Contents'), isNull);
    });
  });

  group('manuals', () {
    Manual m(String title, String crop, int day) => Manual(
          title: title,
          fileName: '$title.pdf',
          fullPath: 'manuals/$title.pdf',
          url: 'https://x/$title',
          crop: crop,
          uploadedAt: DateTime(2026, 9, day),
        );

    test('crop detection and titles from file names', () {
      expect(detectManualCrop('KALRO_Tomato_Production.pdf'), 'tomatoes');
      expect(detectManualCrop('sukuma-wiki guide.pdf'), 'cabbage');
      expect(detectManualCrop('Soil health handbook.pdf'), 'general'); // no longer lumped under maize
      expect(manualTitleFromFile('irish_potato-growing_GUIDE.pdf'), 'Irish Potato Growing Guide');
      expect(formatBytes(2 * 1024 * 1024 + 300000), '2.3 MB');
      expect(formatBytes(null), '');
    });

    test('filter by crop and search; sort newest or A–Z', () {
      final all = [m('Maize basics', 'maize', 3), m('Bean pests', 'beans', 9), m('Maize storage', 'maize', 20)];
      expect(filterManuals(all).map((x) => x.title), ['Maize storage', 'Bean pests', 'Maize basics']);
      expect(filterManuals(all, crop: 'maize', sort: ManualSort.title).map((x) => x.title), ['Maize basics', 'Maize storage']);
      expect(filterManuals(all, query: 'pest').single.title, 'Bean pests');
    });
  });

  testWidgets('settings rows and logout confirmation', (t) async {
    t.view.physicalSize = const Size(360, 780);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    bool? answer;
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => SettingsPage(title: 'Settings', children: [
          SettingsSection(title: 'Account', children: [
            const SettingsTile(icon: Icons.person, title: 'Edit profile', subtitle: 'Name, photo, phone and location'),
            SettingsSwitchTile(icon: Icons.format_bold, title: 'Bold text', value: false, onChanged: (_) {}),
          ]),
          FilledButton(onPressed: () async => answer = await confirmLogout(context), child: const Text('Log out')),
        ]),
      ),
    ));
    expect(find.text('ACCOUNT'), findsOneWidget);
    await t.tap(find.text('Log out'));
    await t.pumpAndSettle();
    expect(find.text('Log out of Kilimo Mkononi?'), findsOneWidget);
    await t.tap(find.text('Stay signed in'));
    await t.pumpAndSettle();
    expect(answer, isFalse);
    expect(t.takeException(), isNull);
  });
}
