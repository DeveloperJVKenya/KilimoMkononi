import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kilimomkononi/enterprise/features/weather/advisory_editor_screen.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_widgets.dart';
import 'package:kilimomkononi/enterprise/features/weather/agronomic_advisory.dart';
import 'package:kilimomkononi/enterprise/features/weather/structured_advice.dart';

// Layout smoke tests at a small phone width: any RenderFlex overflow fails.
void main() {
  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('verified advisory card renders farmer-facing labels', (tester) async {
    await phone(tester);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: VerifiedAdvisoryCard(
            advice: const StructuredAdvice(
              main: 'Hold fungicide spraying until the leaves have fully dried',
              doList: ['Scout lower leaves for grey leaf spot', 'Open drainage furrows'],
              avoidList: ['Top-dressing with urea before rain'],
              why: 'Wet leaves spread fungal spores quickly.',
            ),
            crops: const ['Maize', 'Beans', 'Irish Potatoes', 'Cabbages/Kales'],
            condition: 'wet_leaves',
            verifierName: 'Jane Wanjiku',
            verifiedAt: DateTime.now().subtract(const Duration(hours: 3)),
          ),
        ),
      ),
    ));
    expect(find.text('Verified by Field Agronomist'), findsOneWidget);
    expect(find.textContaining('Jane Wanjiku'), findsOneWidget);
    expect(find.text('Wet leaves'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('advisory editor lays out and requires verification to publish', (tester) async {
    await phone(tester);
    await tester.pumpWidget(const MaterialApp(
      home: AdvisoryEditorScreen(presetCondition: 'high_wind'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('New advisory'), findsOneWidget);
    expect(find.text('Verify & publish'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Publishing without text / verification is blocked with a message.
    await tester.tap(find.text('Verify & publish'));
    await tester.pump();
    expect(find.text('Write the main action.'), findsOneWidget);

    // The advice fields sit below the fold in a lazy list — scroll to them.
    await tester.scrollUntilVisible(find.text('Main action *'), 300,
        scrollable: find.byType(Scrollable).first);
    // By hint: the crop / condition fields above come first in the list.
    TextField field(String hint) => tester.widget<TextField>(
        find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == hint));
    await tester.enterText(
        find.byWidget(field('e.g. Hold fungicide spraying until leaves dry')),
        'Delay spraying until wind drops');
    await tester.enterText(
        find.byWidgetPredicate((w) => w is TextField && (w.decoration?.hintText ?? '').startsWith('Scout lower leaves')),
        'Spray early morning');
    await tester.pump();
    await tester.tap(find.text('Verify & publish'));
    // Old snackbar animates out, then the new one animates in (separate frames).
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.textContaining('Tick the verification box'), findsOneWidget);
  });

  testWidgets('admin test mode: new advisories are marked TEST', (tester) async {
    await phone(tester);
    await tester.pumpWidget(const MaterialApp(
      home: AdvisoryEditorScreen(testMode: true),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('TEST MODE'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('never to farmers'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('never to farmers'), findsOneWidget); // preview strip
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin test mode: live agronomist advice is read-only', (tester) async {
    await phone(tester);
    final live = AgronomicAdvisory(
      id: 'a1',
      title: 't',
      advice: const StructuredAdvice(main: 'Scout for blight', doList: ['Check leaves']),
      crops: const ['Maize'],
      condition: 'wet_leaves',
      status: AdvisoryStatus.published,
      version: 2,
      publishedByName: 'Jane',
      publishedAt: DateTime(2026, 9, 20),
    );
    await tester.pumpWidget(MaterialApp(
      home: AdvisoryEditorScreen(existing: live, testMode: true),
    ));
    await tester.pump();
    expect(find.textContaining('read-only in test mode'), findsOneWidget);
    expect(find.text('Update published'), findsNothing); // no action bar
    expect(find.byType(PopupMenuButton<String>), findsNothing); // no unpublish/archive
    expect(tester.takeException(), isNull);
  });

  testWidgets('read-only advice: crop / condition chips are locked; other crops kept', (tester) async {
    await phone(tester);
    final live = AgronomicAdvisory(
      id: 'a3',
      title: 't',
      advice: const StructuredAdvice(main: 'Scout for blight', doList: ['Check leaves']),
      crops: const ['Maize', 'Cassava'], // Cassava isn't a standard crop
      condition: 'wet_leaves',
      status: AdvisoryStatus.archived,
      version: 4,
    );
    await tester.pumpWidget(MaterialApp(
      home: AdvisoryEditorScreen(existing: live),
    ));
    await tester.pump();
    expect(find.widgetWithText(FilterChip, 'Cassava'), findsOneWidget);
    for (final chip in tester.widgetList<FilterChip>(find.byType(FilterChip))) {
      expect(chip.onSelected, isNull);
    }
    for (final chip in tester.widgetList<ChoiceChip>(find.byType(ChoiceChip))) {
      expect(chip.onSelected, isNull);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing published advice offers "notify farmers" (off by default)', (tester) async {
    await phone(tester);
    final published = AgronomicAdvisory(
      id: 'a2',
      title: 't',
      advice: const StructuredAdvice(main: 'Scout for blight', doList: ['Check leaves']),
      crops: const ['Maize'],
      condition: 'wet_leaves',
      status: AdvisoryStatus.published,
      version: 3,
      publishedByName: 'Jane',
      publishedAt: DateTime(2026, 9, 20),
    );
    await tester.pumpWidget(MaterialApp(
      home: AdvisoryEditorScreen(existing: published),
    ));
    await tester.pump();
    expect(find.text('Update published'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Notify farmers about this change'), 300,
        scrollable: find.byType(Scrollable).first);
    final tile = tester.widget<CheckboxListTile>(find.ancestor(
        of: find.text('Notify farmers about this change'),
        matching: find.byType(CheckboxListTile)));
    expect(tile.value, isFalse);
    // Scrolling builds the audit-history section below, which reads
    // Firestore — not initialised in widget tests. Anything else must fail.
    final e = tester.takeException();
    expect(e == null || '$e'.contains('no-app'), isTrue, reason: '$e');
  });

  testWidgets('new advice has no "notify" option (first publish always notifies)', (tester) async {
    await phone(tester);
    await tester.pumpWidget(const MaterialApp(home: AdvisoryEditorScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Notify farmers about this change', skipOffstage: false), findsNothing);
  });
}
