// The app-wide button style (lib/settings/appearance/button_styles.dart):
// compact, flat, rounded, sized to the label — and screens don't bring back
// the old full-width / oversized buttons.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilimomkononi/settings/appearance/appearance.dart';
import 'package:kilimomkononi/settings/appearance/button_styles.dart';
import 'package:kilimomkononi/widgets/save_fab.dart';

void main() {
  final theme = appearanceTheme(
    ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.green), useMaterial3: true),
    const AppearanceSettings(),
  );

  test('every button type is flat, rounded and 44 px tall', () {
    for (final style in [
      theme.elevatedButtonTheme.style!,
      theme.filledButtonTheme.style!,
      theme.outlinedButtonTheme.style!,
    ]) {
      expect(style.minimumSize!.resolve({}), const Size(64, kButtonHeight));
      expect(style.elevation!.resolve({}), 0);
      final shape = style.shape!.resolve({}) as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(kButtonRadius));
    }
  });

  testWidgets('a button in a wide column is sized to its label', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Column(children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {},
            child: const Text('Save'),
          ),
        ]),
      ),
    ));
    final size = tester.getSize(find.byType(ElevatedButton));
    expect(size.width, lessThan(200));
    expect(size.height, lessThanOrEqualTo(48));
  });

  test('screens leave sizing to the theme (no full-width or oversized buttons)', () {
    final offenders = <String>[];
    final fullWidth = RegExp(
        r'SizedBox\(\s*width:\s*double\.infinity,(?:\s*height:\s*[\d.]+,)?\s*child:\s*(ElevatedButton|FilledButton|OutlinedButton|TextButton)');
    final tall = RegExp(r'minimumSize:\s*(const\s*)?Size(\.fromHeight|\(double\.infinity)');
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final s = f.readAsStringSync();
      if (fullWidth.hasMatch(s) || tall.hasMatch(s)) offenders.add(f.path);
    }
    expect(offenders.where((p) => !p.endsWith('button_styles.dart')), isEmpty);
  });

  testWidgets('floating Save: sized to its label, busy and hidden states', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var taps = 0;
    Future<void> pump({bool busy = false, bool visible = true, bool enabled = true}) => tester.pumpWidget(MaterialApp(
          theme: theme,
          home: Scaffold(
            floatingActionButton: SaveFab(onPressed: enabled ? () => taps++ : null, busy: busy, visible: visible, label: 'Save intervention'),
            body: ListView(padding: const EdgeInsets.only(bottom: kSaveFabSpace), children: const [SizedBox(height: 2000)]),
          ),
        ));

    await pump();
    expect(find.text('Save intervention'), findsOneWidget);
    // Sized to the label, not stretched across the 360 px screen.
    expect(tester.getSize(find.byType(FloatingActionButton)).width, lessThan(360 - 32));
    await tester.tap(find.byType(FloatingActionButton));
    expect(taps, 1);

    await pump(busy: true);
    expect(find.text('Saving…'), findsOneWidget);
    await tester.tap(find.byType(FloatingActionButton));
    expect(taps, 1); // no double save while busy

    await pump(enabled: false);
    await tester.tap(find.byType(FloatingActionButton));
    expect(taps, 1);

    await pump(visible: false);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton), warnIfMissed: false);
    expect(taps, 1);
  });
}
