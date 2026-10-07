// Advisory actions: soil / pest / disease content agronomists and the AI
// add to advice, how farmers' notifications are filed under each farm
// section, and the screen where farmers confirm and log actions.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_actions.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_detail_screen.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_widgets.dart';
import 'package:kilimomkononi/enterprise/features/weather/agronomic_advisory.dart';
import 'package:kilimomkononi/enterprise/features/weather/structured_advice.dart';
import 'package:kilimomkononi/services/advisory_intervention_service.dart';
import 'package:kilimomkononi/services/nutrient_levels.dart';
import 'package:kilimomkononi/services/pest_disease_catalog.dart';
import 'package:kilimomkononi/settings/notifications/notification_providers.dart';

const _actions = AdviceActions(
  soil: [
    SoilAction(
      nutrient: 'N',
      general: BandAction(action: 'Delay top-dressing until the rain stops'),
      low: BandAction(action: 'Top-dress after rain', product: 'CAN', rate: '50 kg/acre', method: 'Band 5 cm from stems'),
      high: BandAction(action: 'Skip nitrogen this round'),
    ),
  ],
  pests: [CropCheck(name: 'Aphids', signs: 'Curled sticky leaves', ifFound: 'Spray neem extract', rate: '30 ml/20 L')],
  diseases: [CropCheck(name: 'Late Blight', signs: 'Dark water-soaked patches', ifFound: 'Remove infected leaves')],
);

AgronomicAdvisory _advisory({AdviceActions actions = _actions, bool ai = false}) => AgronomicAdvisory(
      id: 'adv1',
      title: 'Raining now — Tomatoes',
      advice: const StructuredAdvice(main: 'Hold spraying until the rain stops', doList: ['Open drainage furrows']),
      crops: const ['Tomatoes'],
      condition: 'raining',
      status: AdvisoryStatus.published,
      version: 1,
      publishedByName: 'Jane Agronomist',
      publishedAt: DateTime(2026, 9, 30, 8),
      actions: actions,
      isAi: ai,
    );

FarmCrop _crop({Map<String, dynamic> npk = const {'N': 40.0, 'P': null, 'K': null}}) {
  final record = <String, dynamic>{
    'plotId': 'SingleCrop',
    'crops': [
      {'type': 'Tomatoes', 'stage': 'Early Growth'},
    ],
    'npk': npk,
    'timestamp': Timestamp.fromDate(DateTime(2026, 9, 1)),
  };
  return FarmCrop(
    plotId: 'SingleCrop',
    docId: 'd1',
    crop: 'Tomatoes',
    stage: 'Early Growth',
    record: record,
    bands: bandsFromFieldData(record),
    measuredAt: DateTime(2026, 9, 1),
  );
}

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('advice actions', () {
    test('round-trip through Firestore maps; empty bands are dropped', () {
      final back = AdviceActions.fromDoc(_actions.toMap());
      expect(back.soil.single.low.product, 'CAN');
      expect(back.soil.single.moderate.isEmpty, isTrue);
      expect(back.soil.single.bands, [NutrientBand.low, NutrientBand.high]);
      expect(back.pests.single.name, 'Aphids');
      expect(back.diseases.single.ifFound, 'Remove infected leaves');
      expect(back.sections, {AdviceSection.soil, AdviceSection.pests, AdviceSection.diseases});
      expect(_actions.toMap()['soilActions'][0]['moderate'], isNull);
    });

    test('a level the agronomist left blank falls back to the general action', () {
      final a = _actions.soil.single;
      expect(a.forBand(NutrientBand.low).product, 'CAN');
      expect(a.forBand(null).action, startsWith('Delay'));
      expect(a.forBand(NutrientBand.moderate).isEmpty, isTrue);
    });

    test('AI replies carry pests, diseases and soil actions', () {
      final a = parseStructuredAdvice('''
MAIN: Hold spraying
DO:
- Open drainage
AVOID:
- Top-dressing now
WHY: Rain washes fertiliser away.
PESTS:
- Aphids — curled sticky leaves — spray neem if colonies seen
DISEASES:
- Late blight — dark patches on leaves — remove infected leaves
SOIL:
- N | Low: top-dress CAN after rain | High: skip nitrogen
- general | Add mulch to stop erosion
''')!;
      expect(a.main, 'Hold spraying');
      expect(a.actions.pests.single.name, 'Aphids');
      expect(a.actions.pests.single.signs, 'curled sticky leaves');
      expect(a.actions.pests.single.ifFound, 'spray neem if colonies seen');
      expect(a.actions.diseases.single.name, 'Late blight');
      expect(a.actions.soil.first.nutrient, 'N');
      expect(a.actions.soil.first.low.action, 'top-dress CAN after rain');
      expect(a.actions.soil.first.high.action, 'skip nitrogen');
      expect(a.actions.soil[1].general.action, 'Add mulch to stop erosion');
    });

    test('"none" sections and replies without them give no actions', () {
      final a = parseStructuredAdvice('MAIN: Spray today\nPESTS: none\nDISEASES:\n- none\nSOIL: none')!;
      expect(a.actions.isEmpty, isTrue);
      expect(parseStructuredAdvice('MAIN: Water early')!.actions.isEmpty, isTrue);
    });

    test('soil test values map to Low / Moderate / High against the crop target', () {
      expect(nutrientBand(40, 100), NutrientBand.low);
      expect(nutrientBand(95, 100), NutrientBand.moderate);
      expect(nutrientBand(120, 100), NutrientBand.high);
      expect(nutrientBand(null, 100), isNull, reason: 'untested is never forced into a band');
      // Tomatoes · Early Growth targets N 100 kg/ha.
      expect(_crop().bands, {'N': NutrientBand.low});
      expect(_crop(npk: const {}).bands, isEmpty);
    });

    test('rates split into a dose and unit for the intervention record', () {
      expect(AdvisoryInterventionService.splitRate('50 kg/acre'), (50.0, 'kg/acre'));
      expect(AdvisoryInterventionService.splitRate('2.5 L'), (2.5, 'L'));
      expect(AdvisoryInterventionService.splitRate('as label'), (null, 'as label'));
    });

    test('advice for "All crops" applies to every crop; otherwise only matching ones', () {
      final farm = FarmContext([
        _crop(),
        FarmCrop(plotId: 'Plot 2', docId: 'd2', crop: 'Maize', stage: '', record: const {}, bands: const {}),
      ]);
      expect(farm.matching(['All crops']).length, 2);
      expect(farm.matching(['maize']).single.crop, 'Maize');
      expect(farm.matching(['Beans']), isEmpty);
      expect(farm.plots.length, 2);
    });

    test('pest / disease names from the catalogue open the right guide stage', () {
      expect(pestsForCrops(['Tomatoes']), contains('Whiteflies'));
      expect(diseasesForCrops(['Maize']), contains('Gray Leaf Spot'));
      expect(catalogStageFor('Beans', 'bean fly', pest: true), 'Germination/Seedling');
      expect(catalogStageFor('Beans', 'Not a pest', pest: true), isNull);
    });
  });

  group('notifications are filed by farm section', () {
    test('advice uses the sections the server attached; alerts their category', () {
      const advice = InboxItem(
        id: 'a', type: 'advisory', channel: 'km_advisories', title: 't', body: 'b',
        args: {'advisoryId': 'adv1', 'sections': 'pests,diseases', 'crops': 'Maize, Beans'},
      );
      expect(advice.sections, {AdviceSection.pests, AdviceSection.diseases});
      expect(advice.crops, ['Maize', 'Beans']);
      expect(advice.advisoryId, 'adv1');
      expect(InboxFilter.pests.matches(advice), isTrue);
      expect(InboxFilter.soil.matches(advice), isFalse);

      const rain = InboxItem(
        id: 'w', type: 'weather_alert', channel: 'km_weather_alerts', title: 'Heavy rain', body: '',
        args: {'category': 'heavy_rain'},
      );
      expect(rain.sections, {AdviceSection.soil});
      expect(rain.advisoryId, isNull);
    });
  });

  group('screens at 360px', () {
    testWidgets('verified advice card summarises what to check and opens the actions', (tester) async {
      await _phone(tester);
      var opened = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: VerifiedAdvisoryCard.fromAdvisory(_advisory(), onOpen: () => opened = true),
          ),
        ),
      ));
      expect(find.textContaining('Aphids'), findsOneWidget);
      expect(find.textContaining('Late Blight'), findsOneWidget);
      expect(find.textContaining('Nitrogen (N)'), findsOneWidget);
      await tester.tap(find.text('Check my farm & log actions'));
      expect(opened, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('action screen: soil level from the test, pest / disease checks, logged state',
        (tester) async {
      await _phone(tester);
      await tester.pumpWidget(MaterialApp(
        home: AdvisoryDetailScreen(
          advisory: _advisory(),
          alertTitle: 'Heavy rain at your farm',
          testFarm: FarmContext([_crop()]),
          testResponses: const {'pests:Aphids': 'logged'},
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Sent with the alert: Heavy rain at your farm'), findsOneWidget);
      expect(find.textContaining('Your soil test: Low'), findsOneWidget);
      expect(find.text('Low (your test)'), findsOneWidget);
      expect(find.text('Top-dress after rain'), findsOneWidget, reason: 'the low-level action is preselected');

      // Not sure → the general action.
      await tester.ensureVisible(find.text('Not sure'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not sure'));
      await tester.pumpAndSettle();
      expect(find.text('Delay top-dressing until the rain stops'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Late Blight'), 300);
      expect(find.textContaining('Logged'), findsOneWidget); // pill (icon inline) // Aphids
      expect(find.text('Disease guide'), findsOneWidget);
      expect(find.text('Not sure? Photo ID'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('no field record yet → asked to set up the farm first', (tester) async {
      await _phone(tester);
      await tester.pumpWidget(MaterialApp(
        home: AdvisoryDetailScreen(
          advisory: _advisory(ai: true),
          testFarm: const FarmContext([]),
          testResponses: const {},
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('AI-generated · not verified'), findsOneWidget);
      expect(find.text('Set up farm'), findsOneWidget);
      expect(find.textContaining('Not measured on this plot'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
