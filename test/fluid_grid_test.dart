// Fluid grids (lib/widgets/fluid_grid.dart): columns follow the screen width,
// rows follow their content — no overflow at any size or text size.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilimomkononi/widgets/fluid_grid.dart';

Widget card(String text) => Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.eco),
          Text(text),
          const Spacer(),
          FilledButton(onPressed: () {}, child: const Text('Open')),
        ]),
      ),
    );

void main() {
  test('no fixed-shape grids for content (use FluidGrid / SliverFluidGrid)', () {
    // The admin dashboard's compact tiles scale with text size and have their
    // own layout test; adminmanagementscreen.dart is unused.
    const allowed = {'admin_management_screen.dart', 'adminmanagementscreen.dart', 'fluid_grid.dart'};
    final fixed = RegExp(r'childAspectRatio|mainAxisExtent');
    final offenders = [
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.dart') &&
            !allowed.contains(f.uri.pathSegments.last) &&
            fixed.hasMatch(f.readAsStringSync()))
          f.path,
    ];
    expect(offenders, isEmpty);
  });

  test('columns follow the width', () {
    expect(fluidColumns(320, minTileWidth: 150), 2);
    expect(fluidColumns(360 - 32, minTileWidth: 150), 2);
    expect(fluidColumns(768, minTileWidth: 150), 4);
    expect(fluidColumns(1280, minTileWidth: 150), 6);
    expect(fluidColumns(1280, minTileWidth: 150, maxColumns: 4), 4);
    expect(fluidColumns(100, minTileWidth: 150), 1);
    expect(fluidColumns(double.infinity, minTileWidth: 150), 1);
  });

  for (final (width, scale) in [(320.0, 1.0), (360.0, 2.0), (412.0, 1.3), (768.0, 1.0), (1280.0, 1.5)]) {
    testWidgets('no overflow at $width px, text ×$scale', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, 900), textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: FluidGrid(
                minTileWidth: 140,
                minTileHeight: 100,
                children: [
                  card('Short'),
                  card('A much longer title that wraps over several lines on a narrow phone'),
                  card('Mid length text'),
                  card('Four'),
                  card('Five'),
                ],
              ),
            ),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
      // Tiles sharing the first row line up (320 px fits only one column).
      final cards = find.byType(Card);
      if (fluidColumns(width - 32, minTileWidth: 140) > 1) {
        expect(tester.getSize(cards.at(0)).height, tester.getSize(cards.at(1)).height);
      }
      expect(tester.getSize(cards.at(0)).height, greaterThanOrEqualTo(100));
    });
  }

  testWidgets('sliver grid builds rows lazily and fits the width', (tester) async {
    tester.view.physicalSize = const Size(1024, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var built = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CustomScrollView(slivers: [
          SliverFluidGrid(
            minTileWidth: 300,
            itemCount: 500,
            itemBuilder: (_, i) {
              built++;
              return SizedBox(height: 80, child: Text('Item $i'));
            },
          ),
        ]),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(built, lessThan(100)); // not all 500
    // 1024 px → 3 columns of ~333 px
    expect(tester.getSize(find.text('Item 0')).width, closeTo((1024 - 24) / 3, 1));
  });
}
