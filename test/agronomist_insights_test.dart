// Agronomist panel: what farmers' records turn into (insights_engine.dart,
// farmer_findings.dart), the records models, and custom advice as the farmer
// sees it.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilimomkononi/enterprise/features/agronomist/agronomist_providers.dart';
import 'package:kilimomkononi/enterprise/features/agronomist/farmer_advice.dart';
import 'package:kilimomkononi/enterprise/features/agronomist/farmer_findings.dart';
import 'package:kilimomkononi/enterprise/features/agronomist/farmer_records.dart';
import 'package:kilimomkononi/enterprise/features/agronomist/insights_engine.dart';
import 'package:kilimomkononi/enterprise/features/agronomist/insights_tab.dart';
import 'package:kilimomkononi/services/nutrient_levels.dart';

final now = DateTime(2026, 10, 12, 12);
int daysAgo(num d) => now.subtract(Duration(hours: (d * 24).round())).millisecondsSinceEpoch;

Map<String, dynamic> issue(String name, num ago,
        {String type = 'pest', String f = 'u1', String county = 'Nakuru', String crop = 'Maize', bool unknown = false}) =>
    {
      'type': type,
      'name': name,
      'crop': crop,
      'stage': 'Vegetative',
      'at': daysAgo(ago),
      'src': 'manual',
      'unidentified': unknown,
      'f': f,
      'county': county,
    };

InsightsData sample() => InsightsData.fromMap({
      'generatedAt': now.millisecondsSinceEpoch,
      'days': 30,
      'issues': [
        // Fall armyworm: new this period, 3 farmers, 2 counties → new + spreading
        issue('Fall armyworm', 2),
        issue('Fall armyworm', 5, f: 'u2', county: 'Kisii'),
        issue('Fall armyworm', 6, f: 'u3'),
        // Aphids: 1 before → 4 now → rising; u1 twice (repeat)
        issue('Aphids', 40, crop: 'Kales'),
        issue('Aphids', 3, crop: 'Kales'),
        issue('Aphids', 4, crop: 'Kales'),
        issue('Aphids', 8, f: 'u2', crop: 'Kales', county: 'Kisii'),
        issue('Aphids', 9, f: 'u3', crop: 'Kales'),
        // Late blight, once each period → steady
        issue('Late blight', 45, type: 'disease', crop: 'Tomatoes'),
        issue('Late blight', 10, type: 'disease', crop: 'Tomatoes'),
        // Unidentified, clustering on beans in Nakuru (one farmer not sharing)
        issue('', 1, f: 'u3', crop: 'Beans', unknown: true),
        {...issue('unknown', 2, crop: 'Beans', unknown: true), 'f': null},
      ],
      'plots': [
        {'plot': 'A', 'crops': [{'type': 'Maize', 'stage': 'Vegetative'}], 'npk': {'N': 10}, 'bands': {'N': 'low', 'P': 'moderate'}, 'at': daysAgo(3), 'f': 'u1', 'county': 'Nakuru'},
        {'plot': 'B', 'crops': [{'type': 'Maize', 'stage': 'Vegetative'}], 'npk': {'N': 90}, 'bands': {'N': 'moderate'}, 'at': daysAgo(20), 'f': 'u2', 'county': 'Kisii'},
        {'plot': '', 'crops': [{'type': 'Maize', 'stage': 'Vegetative'}], 'npk': {'N': 5}, 'bands': {'N': 'low'}, 'at': daysAgo(20), 'f': null, 'county': 'Kisii'},
      ],
      'farmers': [
        {'uid': 'u1', 'name': 'Jane Wanjiku', 'county': 'Nakuru', 'ward': 'Njoro'},
        {'uid': 'u2', 'name': 'Otieno Ouma', 'county': 'Kisii'},
        {'uid': 'u3', 'name': 'Amina Hassan', 'county': 'Nakuru'},
      ],
      'totals': {'farmers': 4, 'sharing': 3, 'optedOut': 1},
    });

void main() {
  group('computeInsights', () {
    final i = computeInsights(sample(), now: now);

    test('headline counts against the period before', () {
      expect(i.pestReports.current, 9); // incl. the 2 unidentified pest problems
      expect(i.pestReports.previous, 1);
      expect(i.diseaseReports.current, 1);
      expect(i.unidentified.current, 2);
      expect(i.activeFarmers.current, 3);
      expect(i.plotsTested, 3);
      expect(i.lowNutrientPlots, 2);
    });

    test('top pests, most reported first, with farmers and counties', () {
      expect(i.pests.map((t) => t.name), ['Aphids', 'Fall armyworm']);
      final faw = i.pests.firstWhere((t) => t.name == 'Fall armyworm');
      expect(faw.farmers, 3);
      expect(faw.counties, {'Nakuru', 'Kisii'});
      expect(faw.farmerUids, {'u1', 'u2', 'u3'});
      expect(faw.buckets.reduce((a, b) => a + b), 3);
      expect(faw.buckets.length, bucketCount(30));
    });

    test('emerging: new, rising and spreading — steady problems are not', () {
      final faw = i.emerging.firstWhere((t) => t.name == 'Fall armyworm');
      expect(faw.tags, containsAll([TrendTag.newIssue, TrendTag.spreading]));
      final aphids = i.emerging.firstWhere((t) => t.name == 'Aphids');
      expect(aphids.tags, contains(TrendTag.rising));
      expect(i.emerging.any((t) => t.name == 'Late blight'), isFalse);
    });

    test('unidentified problems on one crop in one county cluster', () {
      expect(i.unknownClusters, hasLength(1));
      final c = i.unknownClusters.single;
      expect(c.crop, 'Beans');
      expect(c.county, 'Nakuru');
      expect(c.rows, hasLength(2));
      expect(c.farmerUids, {'u3'}); // the non-sharing farmer is counted, not named
    });

    test('soil: low share per crop and nutrient, only sharing farmers listed', () {
      final n = i.nutrients.firstWhere((x) => x.crop == 'Maize' && x.nutrient == 'N');
      expect([n.low, n.moderate, n.high], [2, 1, 0]);
      expect(n.lowFarmerUids, {'u1'});
    });

    test('farmers needing attention come with reasons', () {
      expect(i.attention, isNotEmpty);
      final jane = i.attention.firstWhere((a) => a.farmer.uid == 'u1');
      expect(jane.reasons, contains('Aphids ×2'));
      expect(jane.reasons.any((r) => r.startsWith('Low N')), isTrue);
    });

    test('county and crop filters', () {
      final kisii = computeInsights(sample(), county: 'Kisii', now: now);
      expect(kisii.pestReports.current, 2);
      final beans = computeInsights(sample(), crop: 'Beans', now: now);
      expect(beans.pestReports.current, 2);
      expect(beans.pests, isEmpty); // both unidentified
      expect(i.counties, ['Kisii', 'Nakuru']);
      expect(i.crops, containsAll(['Maize', 'Kales', 'Beans', 'Tomatoes']));
    });
  });

  test('farmers tab: only sharing farmers, with this period\'s counts', () {
    final list = summarizeFarmers(sample(), now: now);
    expect(list.map((s) => s.farmer.uid), ['u1', 'u2', 'u3']);
    final u1 = list.first;
    expect(u1.pests, 3); // 2 aphids + 1 fall armyworm this period
    expect(u1.lowNutrients, ['N']);
    expect(u1.crops, containsAll(['Maize', 'Kales']));
    expect(summarizeFarmers(sample(), county: 'Kisii', now: now).single.farmer.uid, 'u2');
  });

  group('records', () {
    test('plot bands fall back to the crop targets when not saved', () {
      final opt = nutrientTargets('Maize', 'V6 to VT')!;
      final p = PlotRow.fromMap({
        'plot': 'A',
        'crops': [{'type': 'Maize', 'stage': 'V6 to VT'}],
        'npk': {'N': opt['N']! * 0.5, 'K': opt['K']! * 2},
      });
      expect(p.bands['N'], NutrientBand.low);
      expect(p.bands['K'], NutrientBand.high);
      expect(p.lowNutrients, ['N']);
    });

    test('nutrientBandNames is what field records save', () {
      final opt = nutrientTargets('Maize', 'V6 to VT')!;
      expect(
        nutrientBandNames({
          'crops': [{'type': 'Maize', 'stage': 'V6 to VT'}],
          'npk': {'N': opt['N'], 'P': null},
        }),
        {'N': 'moderate'},
      );
    });

    test('farmer record: latest plot per plot id, crops, responses', () {
      final r = FarmerRecord.fromMap({
        'profile': {'uid': 'u1', 'name': 'Jane', 'county': 'Nakuru', 'ward': 'Njoro'},
        'fieldRecords': [
          {'plotId': 'A', 'crops': [{'type': 'Maize', 'stage': 'Vegetative'}], 'npk': {'N': 1}, 'nutrientBands': {'N': 'low'}, 'timestamp': daysAgo(30)},
          {'plotId': 'A', 'crops': [{'type': 'Beans', 'stage': 'Flowering'}], 'npk': {}, 'timestamp': daysAgo(2)},
          {'plotId': 'B', 'crops': [{'type': 'Kales', 'stage': ''}], 'npk': {'N': 5}, 'nutrientBands': {'N': 'low'}, 'timestamp': daysAgo(400)},
        ],
        'issues': [issue('Aphids', 3), issue('Aphids', 5), issue('Mystery', 1, unknown: true)],
        'responses': [
          {'advisoryId': 'fa1', 'items': {'pests:Aphids': 'found'}},
        ],
      });
      expect(r.latestPlots.map((p) => p.plot), ['A', 'B']);
      expect(r.latestPlots.first.cropNames, ['Beans']);
      expect(r.crops, containsAll(['Beans', 'Kales']));
      expect(r.responses['fa1'], {'pests:Aphids': 'found'});
      expect(r.place, 'Njoro, Nakuru');

      final f = farmerFindings(r, now: now);
      expect(f.any((x) => x.level == FindingLevel.high && x.text.contains('Mystery')), isTrue);
      expect(f.any((x) => x.text == 'Aphids reported 2 times'), isTrue);
      expect(f.any((x) => x.text.contains('B: N low')), isTrue);
      expect(f.any((x) => x.text.contains('A: no soil test')), isTrue);
      expect(f.any((x) => x.text.contains('over a year old')), isTrue);
      // Repeated problems aren't listed again as "nothing done".
      expect(f.where((x) => x.text.contains('Aphids')).length, 1);
    });
  });

  test('custom advice opens like verified advice, marked as for this farmer', () {
    final a = FarmerAdvice.fromMap({
      'farmerUid': 'u1',
      'title': 'Aphids on your kales',
      'main': 'Spray neem extract this evening',
      'doList': ['Check leaf undersides'],
      'crops': <String>[],
      'pestChecks': [
        {'name': 'Aphids', 'signs': 'Sticky leaves', 'ifFound': 'Spray'},
      ],
      'status': 'sent',
      'version': 2,
      'sentByName': 'Dr Otieno',
      'sentAt': daysAgo(1),
    }, 'fa1');
    final v = a.toAdvisory();
    expect(v.isDirect, isTrue);
    expect(v.id, 'fa1');
    expect(v.publishedByName, 'Dr Otieno');
    expect(v.crops, ['All crops']);
    expect(v.actions.pests.single.name, 'Aphids');
    expect(a.content.toMap()['farmerUid'], 'u1');
  });

  testWidgets('Insights fit a 360 px phone', (tester) async {
    tester.view.physicalSize = const Size(360, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final data = sample();
    await tester.pumpWidget(ProviderScope(
      overrides: [insightsDataProvider.overrideWith((ref, days) async => data)],
      child: const MaterialApp(home: Scaffold(body: InsightsTab(testMode: false))),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Emerging & unusual'), findsOneWidget);
    expect(find.text('Fall armyworm'), findsWidgets);
    expect(find.textContaining('chose not to share'), findsOneWidget);
  });
}
