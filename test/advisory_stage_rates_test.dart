// Crop stages and per-area rates on soil / fertiliser actions, the
// "Moderate weather" and typed (custom) conditions, typed crops, and the
// crop list shared by Field Data and advisories.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_actions.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_conditions.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_detail_screen.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_editor_screen.dart';
import 'package:kilimomkononi/enterprise/features/weather/agronomic_advisory.dart';
import 'package:kilimomkononi/enterprise/features/weather/structured_advice.dart';
import 'package:kilimomkononi/services/advisory_intervention_service.dart';
import 'package:kilimomkononi/services/notification_service.dart';
import 'package:kilimomkononi/services/nuasense_service.dart';
import 'package:kilimomkononi/services/nutrient_levels.dart';
import 'package:kilimomkononi/services/pest_disease_catalog.dart';

NuaSenseReading _reading({
  double airTemp = 22,
  double humidity = 60,
  double rainfall = 0,
  double windSpeed = 2,
  bool hasData = true,
}) =>
    NuaSenseReading(
      airTemp: airTemp, humidity: humidity, rainfall: rainfall,
      windSpeed: windSpeed, windGusts: 0, windDirection: 0,
      sunlight: 0, airPressure: 0, dewPoint: 0, dewPointDepression: 5,
      vpd: 1.0, et0Hour: 0.1,
      lwdHour: 0, lwdReason: '', lwdConsecutiveHours: 0,
      pressureTrend6h: 0,
      sprayQualityIndex: 0, sprayQualityLabel: '',
      sprayLimitingFactor: '', deltaT: 0, inversionRisk: '',
      ddAphidHour: 0, ddWhiteflyHour: 0, ddPtmHour: 0, ddFawHour: 0,
      ddDbmHour: 0, ddTutaHour: 0, ddThripsHour: 0, ddArmywormHour: 0,
      ddCbbHour: 0,
      timestamp: DateTime(2026, 10, 1),
      hasData: hasData,
    );

const _byStage = AdviceActions(soil: [
  SoilAction(
    nutrient: 'N',
    stages: ['Early Growth'],
    general: BandAction(action: 'Top-dress with CAN', product: 'CAN', amount: 50, unit: 'kg', per: 'acre'),
  ),
  SoilAction(
    nutrient: 'N',
    stages: ['Fruit Development'],
    general: BandAction(action: 'Split the last dose', amount: 2, unit: 'bags (50 kg)', per: 'ha'),
  ),
  SoilAction(nutrient: 'general', general: BandAction(action: 'Mulch after rain')),
]);

AgronomicAdvisory _advisory(AdviceActions actions) => AgronomicAdvisory(
      id: 'adv1',
      title: 't',
      advice: const StructuredAdvice(main: 'Feed the crop', doList: ['Check soil moisture']),
      crops: const ['Tomatoes'],
      condition: 'moderate',
      status: AdvisoryStatus.published,
      version: 1,
      publishedByName: 'Jane',
      publishedAt: DateTime(2026, 9, 30),
      actions: actions,
    );

FarmCrop _plot({String stage = 'Early Growth', double? acres = 0.5}) {
  final record = <String, dynamic>{
    'plotId': 'SingleCrop',
    'crops': [
      {'type': 'Tomatoes', 'stage': stage},
    ],
    'area': acres,
    'timestamp': Timestamp.fromDate(DateTime(2026, 9, 1)),
  };
  return FarmCrop(
    plotId: 'SingleCrop',
    docId: 'd1',
    crop: 'Tomatoes',
    stage: stage,
    record: record,
    bands: const {},
    areaAcres: acres,
  );
}

Future<void> _scrollTo(WidgetTester tester, Finder f, {bool up = false}) =>
    tester.scrollUntilVisible(f, up ? -200 : 200, scrollable: find.byType(Scrollable).first);

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('rates per farm size', () {
    test('per acre / hectare rates scale to the plot; others do not', () {
      const perAcre = BandAction(amount: 50, unit: 'kg', per: 'acre');
      expect(perAcre.rateLabel, '50 kg per acre');
      expect(perAcre.amountFor(0.5), 25);
      expect(perAcre.amountLabelFor(0.5), '25 kg (≈ 0.5 bags of 50 kg)');
      expect(perAcre.amountLabelFor(0.25), '12.5 kg');

      const perHa = BandAction(amount: 100, unit: 'kg', per: 'ha');
      expect(perHa.amountFor(2.47105), closeTo(100, 0.001));

      const perPlant = BandAction(amount: 5, unit: 'g', per: 'plant');
      expect(perPlant.rateLabel, '5 g per plant / hole');
      expect(perPlant.scalesWithArea, isFalse);
      expect(perPlant.amountFor(1), isNull);

      expect(const BandAction(rate: 'a handful').rateLabel, 'a handful');
    });

    test('structured rates round-trip and keep a readable `rate` for older apps', () {
      const b = BandAction(action: 'Top-dress', amount: 50, unit: 'kg', per: 'acre');
      final m = b.toMap()!;
      expect(m['rate'], '50 kg per acre');
      final back = BandAction.fromMap(m);
      expect(back.amount, 50);
      expect(back.per, 'acre');
      expect(BandAction.fromMap({'rate': '50 kg/acre'}).hasStructuredRate, isFalse);
    });

    test('rates in AI / free text become structured', () {
      final b = BandAction.fromText('Apply CAN 50 kg per acre after rain');
      expect(b.amount, 50);
      expect(b.unit, 'kg');
      expect(b.per, 'acre');
      expect(BandAction.fromText('apply 2 L/ha of foliar feed').per, 'ha');
      expect(BandAction.fromText('Mulch the beds').hasStructuredRate, isFalse);
    });
  });

  group('crop stages', () {
    test('actions apply to their stages; "any stage" always', () {
      final s = _byStage.soil;
      expect(s[0].isForStage('early growth'), isTrue);
      expect(s[0].isForStage('Fruit Development'), isFalse);
      expect(s[2].isForStage('Fruit Development'), isTrue);
      expect(s[0].isForStage(null), isTrue, reason: '"All stages" shows everything');
      expect(_byStage.soilStages, ['Early Growth', 'Fruit Development']);
      expect(s[0].key, 'N#Early Growth');
      expect(s[2].key, 'general');
    });

    test('stages round-trip through Firestore', () {
      final back = AdviceActions.fromDoc(_byStage.toMap());
      expect(back.soil.first.stages, ['Early Growth']);
      expect(back.soil.last.stages, isEmpty);
    });

    test('AI soil lines carry their stage', () {
      final a = parseStructuredAdvice('''
MAIN: Feed the crop
SOIL:
- N | Stage: Vegetative | Low: top-dress CAN 50 kg per acre | High: skip
- P | Stage: any | Low: add DAP
''')!;
      expect(a.actions.soil.first.stages, ['Vegetative']);
      expect(a.actions.soil.first.low.amount, 50);
      expect(a.actions.soil.last.stages, isEmpty);
    });

    test('every crop has stages; new brassicas use the brassica targets', () {
      for (final c in kFieldCropTypes) {
        expect(stagesForCrop(c), isNotEmpty, reason: c);
      }
      expect(stagesForCrop('Passion Fruit'), kGenericCropStages);
      expect(nutrientTargets('Kales', 'Leaf Development'), isNotNull);
      expect(nutrientTargets('Kales', 'Harvesting'), isNotNull);
      expect(nutrientTargets('Cabbages', 'Head Formation')!['N'], 80);
      expect(nutrientTargets('Spinach', 'Vegetative'), isNull);
    });
  });

  group('crops', () {
    test('the requested crops are all listed, and advisories use the same list', () {
      expect(kFieldCropTypes, containsAll([
        'Onions', 'Cabbages', 'Kales', 'Black Nightshade', 'Crotalaria', 'Capsicum',
        'Carrots', 'Kunde', 'Tomatoes', 'Cowpeas', 'Spinach', 'Pineapple', 'Arrowroots',
        'Bananas', 'Chinese Cabbage', 'Sweet Potatoes', 'Amaranth (Pigweed)',
      ]));
      expect(kAdvisoryCrops, same(kFieldCropTypes));
      expect(kFieldCropTypes.toSet().length, kFieldCropTypes.length);
    });

    test('"Cabbages/Kales" (older records / advice) matches Cabbages and Kales', () {
      expect(cropsMatch(['Kales'], ['Cabbages/Kales']), isTrue);
      expect(cropsMatch(['Cabbages/Kales'], ['Cabbages']), isTrue);
      expect(cropsMatch(['Kales'], ['Cabbages']), isFalse);
      expect(cropsMatch(['Passion Fruit'], ['passion fruit']), isTrue, reason: 'typed crops match by name');
      expect(NotificationService.cropTopicsFor('Cabbages/Kales'),
          {'km_crop_cabbages_kales', 'km_crop_cabbages', 'km_crop_kales'});
      expect(NotificationService.cropTopicsFor('Amaranth (Pigweed)'), {'km_crop_amaranth_pigweed'});
      expect(catalogCropFor('Kales'), 'Cabbages/Kales');
      expect(pestsForCrops(['Kales']), isNotEmpty);
    });
  });

  group('conditions', () {
    test('Moderate weather: mild, calm and dry', () {
      expect(activeConditionKeys(_reading()), contains('moderate'));
      expect(activeConditionKeys(_reading(airTemp: 34)), isNot(contains('moderate')));
      expect(activeConditionKeys(_reading(rainfall: 2)), isNot(contains('moderate')));
      expect(activeConditionKeys(_reading(humidity: 90)), isNot(contains('moderate')));
      expect(activeConditionKeys(_reading(windSpeed: 7)), isNot(contains('moderate')));
      expect(activeConditionKeys(_reading(hasData: false)), {'general'});
    });

    test('typed condition: ranges are checked against live data', () {
      const warmHumid = CustomCondition(label: 'Warm and humid', tempMin: 20, tempMax: 30, humidityMin: 70);
      expect(warmHumid.hasRanges, isTrue);
      expect(warmHumid.appliesTo(_reading(airTemp: 25, humidity: 75)), isTrue);
      expect(warmHumid.appliesTo(_reading(airTemp: 25, humidity: 60)), isFalse);
      expect(warmHumid.appliesTo(_reading(airTemp: 25, humidity: 75, hasData: false)), isFalse);
      expect(warmHumid.appliesTo(null), isFalse);
      expect(warmHumid.description, 'temp 20–30°C · humidity 70% or more');

      const anyWeather = CustomCondition(label: 'Before planting');
      expect(anyWeather.hasRanges, isFalse);
      expect(anyWeather.appliesTo(null), isTrue);
      expect(const CustomCondition(label: 'x', tempMin: 30, tempMax: 20).invalidRange, 'temperature');
    });

    test('a typed condition is stored with its name and labels the advice', () {
      const content = AdvisoryContent(
        title: 't',
        advice: StructuredAdvice(main: 'm'),
        crops: ['Kales'],
        condition: kCustomCondition,
        customCondition: CustomCondition(label: 'After hail', rainMin: 5),
      );
      final m = content.toMap();
      expect(m['customCondition']['label'], 'After hail');
      expect(m['customCondition']['rainMin'], 5);
      expect(
        const AdvisoryContent(title: 't', advice: StructuredAdvice(main: 'm'), crops: ['Kales'],
                condition: 'raining', customCondition: CustomCondition(label: 'x'))
            .toMap()['customCondition'],
        isNull,
        reason: 'only kept for a custom condition',
      );
      final a = AgronomicAdvisory(
        id: 'a', title: 't', advice: const StructuredAdvice(main: 'm'), crops: const ['Kales'],
        condition: kCustomCondition, status: AdvisoryStatus.published, version: 1,
        customCondition: const CustomCondition(label: 'After hail', rainMin: 5),
      );
      expect(a.conditionLabel, 'After hail');
      expect(a.appliesTo({'general'}, _reading(rainfall: 8)), isTrue);
      expect(a.appliesTo({'general', 'raining'}, _reading(rainfall: 1)), isFalse);
    });
  });

  group('screens at 360px', () {
    testWidgets('farmer: stage picked from their crop, amount for their plot', (tester) async {
      await _phone(tester);
      await tester.pumpWidget(MaterialApp(
        home: AdvisoryDetailScreen(
          advisory: _advisory(_byStage),
          testFarm: FarmContext([_plot()]),
          testResponses: const {},
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Your crop stage (from your field record): Early Growth'), findsOneWidget);
      expect(find.text('Early Growth (your crop)'), findsOneWidget);
      // Early Growth N action + the any-stage one; the Fruit Development one hidden.
      await _scrollTo(tester, find.text('Top-dress with CAN'));
      expect(find.text('For your plot (0.50 acres): 25 kg (≈ 0.5 bags of 50 kg)'), findsOneWidget);
      await _scrollTo(tester, find.textContaining('1 more for other crop stages'));
      expect(find.text('Split the last dose'), findsNothing);

      await _scrollTo(tester, find.text('All stages'), up: true);
      await tester.tap(find.text('All stages'));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('Split the last dose'));
      expect(find.text('Split the last dose'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('farmer without a recorded plot size can type it', (tester) async {
      await _phone(tester);
      await tester.pumpWidget(MaterialApp(
        home: AdvisoryDetailScreen(
          advisory: _advisory(const AdviceActions(soil: [
            SoilAction(nutrient: 'N', general: BandAction(action: 'Top-dress', amount: 40, unit: 'kg', per: 'acre')),
          ])),
          testFarm: FarmContext([_plot(acres: null)]),
          testResponses: const {},
        ),
      ));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('Your plot size (acres)'));
      await tester.enterText(find.widgetWithText(TextField, 'Your plot size (acres)'), '2');
      await tester.pump();
      await _scrollTo(tester, find.text('For your plot (2 acres): 80 kg (≈ 1.6 bags of 50 kg)'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('agronomist: typed condition and typed crop', (tester) async {
      await _phone(tester);
      await tester.pumpWidget(const MaterialApp(home: AdvisoryEditorScreen()));
      await tester.pump();
      await _scrollTo(tester, find.text('Moderate weather'));
      await tester.ensureVisible(find.text('Other (type your own)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other (type your own)'));
      await tester.pump();
      await _scrollTo(tester, find.text('Condition name *'));
      await tester.enterText(find.widgetWithText(TextField, 'Condition name *'), 'Warm and humid');
      await tester.pump();

      await _scrollTo(tester, find.widgetWithText(TextField, 'Another crop'));
      await tester.enterText(find.widgetWithText(TextField, 'Another crop'), 'Passion Fruit');
      await tester.ensureVisible(find.byTooltip('Add crop'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Add crop'));
      await tester.pump();
      await _scrollTo(tester, find.widgetWithText(FilterChip, 'Passion Fruit'));
      expect(tester.takeException(), isNull);
    });
  });
}
