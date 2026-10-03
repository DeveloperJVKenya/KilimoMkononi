import 'package:flutter_test/flutter_test.dart';

import 'package:kilimomkononi/enterprise/features/weather/advisory_conditions.dart';
import 'package:kilimomkononi/enterprise/features/weather/agronomic_advisory_service.dart';
import 'package:kilimomkononi/enterprise/features/weather/structured_advice.dart';
import 'package:kilimomkononi/services/nuasense_service.dart';

NuaSenseReading reading({
  double airTemp = 22,
  double humidity = 60,
  double rainfall = 0,
  double windSpeed = 1.5,
  double vpd = 1.0,
  int lwdHour = 0,
  int lwdConsecutiveHours = 0,
  double sprayQualityIndex = 0,
  String sprayQualityLabel = '',
  bool hasData = true,
}) =>
    NuaSenseReading(
      airTemp: airTemp, humidity: humidity, rainfall: rainfall,
      windSpeed: windSpeed, windGusts: 0, windDirection: 0,
      sunlight: 0, airPressure: 0, dewPoint: 0, dewPointDepression: 5,
      vpd: vpd, et0Hour: 0.1,
      lwdHour: lwdHour, lwdReason: '', lwdConsecutiveHours: lwdConsecutiveHours,
      pressureTrend6h: 0,
      sprayQualityIndex: sprayQualityIndex, sprayQualityLabel: sprayQualityLabel,
      sprayLimitingFactor: '', deltaT: 0, inversionRisk: '',
      ddAphidHour: 0, ddWhiteflyHour: 0, ddPtmHour: 0, ddFawHour: 0,
      ddDbmHour: 0, ddTutaHour: 0, ddThripsHour: 0, ddArmywormHour: 0,
      ddCbbHour: 0,
      timestamp: DateTime(2026, 9, 24),
      hasData: hasData,
    );

void main() {
  group('activeConditionKeys', () {
    test('calm, dry, mild day → general + good spray window', () {
      expect(activeConditionKeys(reading()), {'general', 'good_spray'});
    });

    test('rain suppresses the spray window', () {
      final keys = activeConditionKeys(reading(rainfall: 3));
      expect(keys, contains('raining'));
      expect(keys, isNot(contains('good_spray')));
    });

    test('wet leaves, humidity, wind, heat', () {
      final keys = activeConditionKeys(
          reading(lwdHour: 1, humidity: 85, windSpeed: 6, airTemp: 34));
      expect(keys, containsAll(['wet_leaves', 'high_humidity', 'high_wind', 'heat']));
      expect(keys, isNot(contains('good_spray'))); // windy
    });

    test('long leaf wetness counts even if the sensor just dried', () {
      expect(activeConditionKeys(reading(lwdConsecutiveHours: 7)), contains('wet_leaves'));
    });

    test('cool and dry-air stress', () {
      expect(activeConditionKeys(reading(airTemp: 12)), contains('cool'));
      expect(activeConditionKeys(reading(vpd: 2.8)), contains('dry_stress'));
      expect(activeConditionKeys(reading(humidity: 35)), contains('dry_stress'));
    });

    test('frost at 4°C or below (also counts as cool)', () {
      expect(activeConditionKeys(reading(airTemp: 3)), containsAll(['frost', 'cool']));
      expect(activeConditionKeys(reading(airTemp: 6)), isNot(contains('frost')));
    });

    test('offline station: placeholder zeros light up nothing but general', () {
      // What an offline station looks like: every value 0, no points.
      final offline = reading(airTemp: 0, humidity: 0, windSpeed: 0, vpd: 0, hasData: false);
      expect(activeConditionKeys(offline), {'general'});
      expect(activeConditionKeys(NuaSenseReading.empty()), {'general'});
    });

    test('station spray score takes precedence over the wind heuristic', () {
      final poor = reading(sprayQualityIndex: 30, sprayQualityLabel: 'Poor');
      expect(activeConditionKeys(poor), isNot(contains('good_spray')));
      final good = reading(windSpeed: 3.5, sprayQualityIndex: 80, sprayQualityLabel: 'Good');
      expect(activeConditionKeys(good), contains('good_spray'));
    });

    test('every key is a known condition (rules validate the same list)', () {
      final known = kAdvisoryConditions.map((c) => c.key).toSet();
      expect(known, containsAll(activeConditionKeys(
          reading(rainfall: 2, lwdHour: 1, humidity: 90, windSpeed: 7, airTemp: 35, vpd: 3))));
    });
  });

  group('cropsMatch', () {
    test('"All crops" matches anyone', () {
      expect(cropsMatch([kAllCrops], ['Maize']), isTrue);
    });
    test('farmer with no recorded crops sees everything', () {
      expect(cropsMatch(['Tomatoes'], []), isTrue);
    });
    test("isForAllCrops (used when the farmer's crops could not be loaded)", () {
      expect(isForAllCrops([kAllCrops]), isTrue);
      expect(isForAllCrops(['all crops ']), isTrue);
      expect(isForAllCrops(['Maize']), isFalse);
    });
    test('matches case-insensitively on the farmer form names', () {
      expect(cropsMatch(['Irish Potatoes', 'Maize'], ['maize']), isTrue);
      expect(cropsMatch(['Tomatoes'], ['Maize', 'Beans']), isFalse);
    });
  });

  group('parseStructuredAdvice', () {
    test('parses MAIN / DO / AVOID / WHY', () {
      final a = parseStructuredAdvice('''
MAIN: Hold spraying until leaves dry
DO:
- Scout lower leaves
- Open drainage furrows
AVOID:
- Top-dressing now
WHY: Wet leaves spread blight.
''')!;
      expect(a.main, 'Hold spraying until leaves dry');
      expect(a.doList, ['Scout lower leaves', 'Open drainage furrows']);
      expect(a.avoidList, ['Top-dressing now']);
      expect(a.why, 'Wet leaves spread blight.');
    });

    test('falls back to the first sentence when MAIN is missing', () {
      expect(parseStructuredAdvice('Check drainage today. Then scout.')!.main,
          'Check drainage today');
    });

    test('empty input → null', () {
      expect(parseStructuredAdvice('   '), isNull);
    });
  });

  group('aiReplyText', () {
    test('reads candidates[0].content.parts[0].text', () {
      expect(
        AgronomicAdvisoryService.aiReplyText({
          'candidates': [
            {'content': {'parts': [{'text': ' MAIN: Scout '}]}},
          ],
        }),
        'MAIN: Scout',
      );
    });
    test('falls back to {text}', () {
      expect(AgronomicAdvisoryService.aiReplyText({'text': 'hi'}), 'hi');
    });
    test('empty / blocked replies give "" instead of throwing', () {
      expect(AgronomicAdvisoryService.aiReplyText({'candidates': []}), '');
      expect(AgronomicAdvisoryService.aiReplyText({'candidates': [{}]}), '');
      expect(AgronomicAdvisoryService.aiReplyText(null), '');
      expect(AgronomicAdvisoryService.aiReplyText([1, 2]), '');
    });
  });
}
