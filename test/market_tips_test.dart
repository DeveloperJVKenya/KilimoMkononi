import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kilimomkononi/screens/farming_tips_widget.dart';
import 'package:kilimomkononi/screens/market/market_prices.dart';
import 'package:kilimomkononi/screens/market_price_screen.dart';
import 'package:kilimomkononi/screens/tips/farming_tips_data.dart';

final _now = DateTime(2026, 9, 29, 12);

PriceReport _r(String id, String crop, String market, String region, double price,
        {int daysAgo = 0, String user = 'u2', String unit = 'per kg'}) =>
    PriceReport.fromMap(id, {
      'cropType': crop,
      'market': market,
      'region': region,
      'retailPrice': price,
      'unit': unit,
      'userId': user,
      'timestamp': Timestamp.fromDate(_now.subtract(Duration(days: daysAgo))),
    })!;

List<PriceReport> _reports() => [
      _r('a', 'Maize', 'Wakulima', 'Nairobi', 60, daysAgo: 1),
      _r('b', 'Maize', 'Wakulima', 'Nairobi', 70, daysAgo: 0),
      _r('c', 'maize', 'Kibuye', 'Kisumu', 40, daysAgo: 3, user: 'u1'),
      _r('d', 'Maize', 'Kibuye', 'Kisumu', 50, daysAgo: 90), // outside 30 days
      _r('e', 'Tomatoes', 'Wakulima', 'Nairobi', 120, daysAgo: 2, unit: 'per crate'),
    ];

const _tipsJson = {
  'maize': {
    'icon': '🌽',
    'general': '- Plant at onset of rains\n- Use certified seed',
    'stages': {
      'Land Preparation': {'tips': '- Plough early'},
      'Fertilizer': {'tips': '- Top-dress twice:\n  • At 4–6 weeks\n  • At knee-high'},
    },
    'varieties': {
      'H614': {'best_for': 'Highlands', 'tips': '- Long season'},
    },
  },
  'cabbage': {'icon': '🥬', 'general': '- Rotate crops', 'stages': {}, 'varieties': {}},
  'kales': {'icon': '🥬', 'general': '- Harvest outer leaves', 'stages': {}, 'varieties': {}},
  'irish_potatoes': {'icon': '🥔', 'general': '- Use clean seed', 'stages': {}, 'varieties': {}},
};

void main() {
  group('price board', () {
    test('parses reports; skips ones without a price or crop', () {
      expect(PriceReport.fromMap('x', {'cropType': 'Maize'}), isNull);
      expect(PriceReport.fromMap('x', {'retailPrice': 5}), isNull);
      expect(_r('a', 'beans', 'M', 'R', 10).crop, 'Beans');
      expect(formatKes(1234567.4), 'KES 1,234,567');
    });

    test('filters, sorts and counts', () {
      final b = computePriceBoard(_reports(), const PriceQuery(crop: 'Maize', sort: PriceSort.highest), now: _now);
      expect(b.shown.map((r) => r.id), ['b', 'a', 'd', 'c']);
      expect(b.crops, [('Maize', 4), ('Tomatoes', 1)]);
      expect(b.regions, [('Kisumu', 2), ('Nairobi', 2)]);

      final mine = computePriceBoard(_reports(), const PriceQuery(mineOnly: true), uid: 'u1', now: _now);
      expect(mine.shown.single.id, 'c');
      expect(computePriceBoard(_reports(), const PriceQuery(region: 'nairobi'), now: _now).shown.first.id, 'b');
    });

    test('summary uses the last 30 days: average, range, trend, best market', () {
      final s = computePriceBoard(_reports(), const PriceQuery(crop: 'Maize'), now: _now).summary!;
      expect(s.recentOnly, isTrue);
      expect(s.count, 3);
      expect(s.average, closeTo(56.67, 0.01));
      expect((s.min, s.max), (40.0, 70.0));
      expect(s.trend.length, 3);
      expect(s.trendChangePct, closeTo(75, 0.01)); // 40 → 70
      expect(s.best!.market, 'Wakulima');
      expect(s.lowest!.market, 'Kibuye');
      expect(s.unit, 'per kg');
    });

    test('summary falls back to all reports when none are recent', () {
      final s = summariseCrop('Maize', [_r('d', 'Maize', 'Kibuye', 'Kisumu', 50, daysAgo: 90)], now: _now)!;
      expect(s.recentOnly, isFalse);
      expect(s.best, isNull); // only one market
      expect(summariseCrop('Maize', const [], now: _now), isNull);
    });
  });

  group('tips library', () {
    test('parses bullets with sub-points', () {
      final items = parseTips('- Top-dress twice:\n  • At 4–6 weeks\n  • At knee-high\n- Scout weekly');
      expect(items.length, 2);
      expect(items.first.subs, ['At 4–6 weeks', 'At knee-high']);
      expect(items.last.text, 'Scout weekly');
    });

    test('bundled JSON parses into complete guides', () {
      final json = jsonDecode(File('assets/farming_tips/kilimo_farming_tips.json').readAsStringSync());
      final guides = parseTipsLibrary(json as Map<String, dynamic>);
      expect(guides.length, greaterThanOrEqualTo(8));
      for (final g in guides) {
        expect(g.general, isNotEmpty, reason: g.key);
        expect(g.stages, isNotEmpty, reason: g.key);
      }
      expect(guides.firstWhere((g) => g.key == 'irish_potatoes').name, 'Irish Potatoes');
    });

    test('field-data crop names map to guides', () {
      const keys = ['maize', 'beans', 'irish_potatoes', 'tomatoes', 'cabbage', 'kales', 'onions', 'carrots'];
      expect(guideKeysForCrop('Cabbages/Kales', keys), {'cabbage', 'kales'});
      expect(guideKeysForCrop('Irish Potatoes', keys), {'irish_potatoes'});
      expect(guideKeysForCrop('Tomatoes', keys), {'tomatoes'});
      expect(guideKeysForCrop('Onion', keys), {'onions'});
      expect(guideKeysForCrop('Wheat', keys), isEmpty);
    });

    test('search looks inside tips and varieties', () {
      final maize = parseTipsLibrary(_tipsJson).first;
      expect(maize.matches('knee'), isTrue);
      expect(maize.matches('highlands'), isTrue);
      expect(maize.matches('banana'), isFalse);
      expect(maize.asText(), contains('Top-dress twice'));
    });
  });

  group('screens at phone width', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> pump(WidgetTester t, Widget child, List overrides) async {
      t.view.physicalSize = const Size(360, 780);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(ProviderScope(overrides: [...overrides], child: MaterialApp(home: child)));
      await t.pumpAndSettle();
    }

    testWidgets('market board: pick a crop → summary; own report is editable', (t) async {
      await pump(t, const MarketPriceScreen(), [
        marketUidProvider.overrideWithValue('u1'),
        priceReportsProvider.overrideWith((ref) => Stream.value(_reports())),
      ]);
      expect(find.text('Choose a crop to see its price summary'), findsOneWidget);
      await t.tap(find.text('Maize  4'));
      await t.pumpAndSettle();
      expect(find.text('Average price'), findsOneWidget);
      expect(find.text('KES 57'), findsOneWidget);
      expect(find.textContaining('Best place to sell'), findsOneWidget);

      await t.tap(find.text('My reports'));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.text('1 report'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('1 report'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('market board: empty state and report form opens', (t) async {
      await pump(t, const MarketPriceScreen(), [
        marketUidProvider.overrideWithValue('u1'),
        priceReportsProvider.overrideWith((ref) => Stream.value(const <PriceReport>[])),
      ]);
      expect(find.text('No price reports here yet'), findsOneWidget);
      await t.tap(find.text('Report a price'));
      await t.pumpAndSettle();
      expect(find.text('Report a market price'), findsOneWidget);
      await t.tap(find.text('Submit price'));
      await t.pumpAndSettle();
      expect(find.text('Enter the market'), findsOneWidget);
      expect(find.text('Enter a price'), findsOneWidget);
    });

    testWidgets('tips: your crops first, save, open a guide and its stages', (t) async {
      await pump(t, const FarmingTipsWidget(), [
        tipsLibraryProvider.overrideWith((ref) async => parseTipsLibrary(_tipsJson)),
        myFieldCropsProvider.overrideWith((ref) async => ['Cabbages/Kales']),
      ]);
      expect(find.text('Your crops · 2'), findsOneWidget);
      expect(find.text('Your crop'), findsNWidgets(2));

      await t.tap(find.text('Your crops · 2'));
      await t.pumpAndSettle();
      expect(find.textContaining('Maize'), findsNothing);

      await t.tap(find.text('All crops · 4'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'knee');
      await t.pumpAndSettle();
      expect(find.text('🌽  Maize'), findsOneWidget);
      expect(find.textContaining('Kales'), findsNothing);

      await t.tap(find.byTooltip('Save this guide'));
      await t.pumpAndSettle();
      expect(find.text('Saved · 1'), findsOneWidget);

      await t.tap(find.text('🌽  Maize'));
      await t.pumpAndSettle();
      expect(find.text('Key points'), findsOneWidget);
      await t.tap(find.widgetWithText(ActionChip, 'Fertilizer'));
      await t.pumpAndSettle();
      expect(find.text('At knee-high'), findsOneWidget);
      await t.tap(find.text('Varieties'));
      await t.pumpAndSettle();
      expect(find.textContaining('Highlands', findRichText: true), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });
}
