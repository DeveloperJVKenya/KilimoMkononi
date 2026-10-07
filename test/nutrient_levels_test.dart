// Every crop farmers can pick has N / P / K targets at every growth stage,
// so a soil test always reads as Low / Moderate / High (and advisories can
// preselect the farmer's level).

import 'package:flutter_test/flutter_test.dart';
import 'package:kilimomkononi/services/nutrient_levels.dart';

void main() {
  test('every crop and stage has nutrient targets', () {
    final missing = [
      for (final c in kFieldCropTypes)
        for (final s in stagesForCrop(c))
          if (nutrientTargets(c, s) == null) '$c · $s',
    ];
    expect(missing, isEmpty);
  });

  test('a newly added crop reads Low / Moderate / High against its stage', () {
    final record = {
      'crops': [
        {'type': 'Bananas', 'stage': 'Vegetative'},
      ],
      'npk': {'N': 120.0, 'P': 41.0, 'K': 400.0},
    };
    // Bananas · Vegetative targets: N 200, P 40, K 300 kg/ha.
    expect(bandsFromFieldData(record), {
      'N': NutrientBand.low,
      'P': NutrientBand.moderate,
      'K': NutrientBand.high,
    });
  });
}
