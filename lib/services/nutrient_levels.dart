// lib/services/nutrient_levels.dart
//
// Crop nutrient targets (kg/ha) and the Low / Moderate / High band a soil
// test value falls in. Shared by the Field Data Input form, verified
// advisories (fertiliser actions per band) and the advisory action screen,
// so "low N" means the same everywhere.
//
// Bands are guidance, never a gate: a farmer who has not tested their soil
// simply has no band, and can still pick the action that fits.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Crops farmers record in Field Data (fielddata.crops[].type) and Field
/// Agronomists target advisories at — one list, so the names match exactly.
/// Add new crops here (with their stages below); never rename one, since
/// records and advisories store the name.
const List<String> kFieldCropTypes = [
  'Onions',
  'Cabbages',
  'Kales',
  'Black Nightshade',
  'Crotalaria',
  'Capsicum',
  'Carrots',
  'Kunde',
  'Tomatoes',
  'Cowpeas',
  'Spinach',
  'Pineapple',
  'Arrowroots',
  'Bananas',
  'Chinese Cabbage',
  'Sweet Potatoes',
  'Amaranth (Pigweed)',
  'Beans',
  'Maize',
  'Irish Potatoes',
  'Wheat',
  'Sugarcane',
  'Rice',
];

/// Older records (and advisories) used one combined name. It still has its
/// stages and targets, and matches Cabbages and Kales (see cropNameParts).
const String kLegacyCabbageKales = 'Cabbages/Kales';

const _kLeafyStages = ['Nursery / Establishment', 'Vegetative', 'Harvesting', 'Flowering / Seed'];

const Map<String, List<String>> kFieldCropStages = {
  'Beans': ['Vegetative', 'Flowering', 'Pod Development'],
  'Maize': ['Emergence to V6', 'V6 to VT', 'Reproductive'],
  'Tomatoes': ['Early Growth', 'Flowering and Fruit Set', 'Fruit Development'],
  kLegacyCabbageKales: ['Early Growth', 'Leaf Development', 'Head Formation'],
  'Cabbages': ['Early Growth', 'Leaf Development', 'Head Formation'],
  'Kales': ['Early Growth', 'Leaf Development', 'Harvesting'],
  'Chinese Cabbage': ['Early Growth', 'Leaf Development', 'Head Formation'],
  'Carrots': ['Early Growth', 'Root Expansion', 'Maturation'],
  'Irish Potatoes': ['Early Growth', 'Tuber Initiation', 'Tuber Bulking'],
  'Wheat': ['Early Growth', 'Tillering and Stem Elongation', 'Grain Filling'],
  'Sugarcane': ['Early Growth', 'Grand Growth Phase', 'Maturity'],
  'Rice': ['Early Growth', 'Tillering to Panicle Initiation', 'Grain Filling'],
  'Onions': ['Early Growth', 'Bulb Formation', 'Maturation'],
  'Black Nightshade': _kLeafyStages,
  'Crotalaria': _kLeafyStages,
  'Kunde': _kLeafyStages,
  'Spinach': _kLeafyStages,
  'Amaranth (Pigweed)': _kLeafyStages,
  'Capsicum': ['Nursery / Transplanting', 'Vegetative', 'Flowering and Fruit Set', 'Fruit Development'],
  'Cowpeas': ['Vegetative', 'Flowering', 'Pod Development'],
  'Pineapple': ['Establishment', 'Vegetative', 'Flowering (Forcing)', 'Fruit Development'],
  'Arrowroots': ['Establishment', 'Vegetative', 'Corm Bulking', 'Maturity'],
  'Bananas': ['Establishment', 'Vegetative', 'Flowering / Shooting', 'Bunch Filling'],
  'Sweet Potatoes': ['Establishment', 'Vine Development', 'Root Bulking', 'Maturity'],
};

/// Stages offered for a crop without its own list (e.g. one an agronomist
/// typed in).
const kGenericCropStages = [
  'Planting / Nursery',
  'Early Growth',
  'Vegetative',
  'Flowering',
  'Fruiting / Bulking',
  'Maturity',
];

/// Stages for [crop] (generic ones when it has no list of its own).
List<String> stagesForCrop(String crop) =>
    kFieldCropStages[crop] ?? kGenericCropStages;

/// "Cabbages/Kales" → {cabbages/kales, cabbages, kales}; "Maize" → {maize}.
/// Lower-cased, so a combined (legacy) name matches each of its parts.
Set<String> cropNameParts(String crop) {
  final whole = crop.trim().toLowerCase();
  if (whole.isEmpty) return const {};
  return {
    whole,
    for (final p in whole.split('/')) if (p.trim().isNotEmpty) p.trim(),
  };
}

/// Nutrient targets (kg/ha) for [crop] at [stage], or null when unknown.
/// Cabbages, Kales and Chinese cabbage use the brassica targets.
Map<String, double>? nutrientTargets(String crop, String stage) {
  final own = kOptimalNutrients[crop]?[stage];
  if (own != null) return own;
  if (const {'Cabbages', 'Kales', 'Chinese Cabbage'}.contains(crop)) {
    final brassica = kOptimalNutrients[kLegacyCabbageKales]!;
    return brassica[stage] ?? (stage == 'Harvesting' ? brassica['Leaf Development'] : null);
  }
  return null;
}

const Map<String, Map<String, Map<String, double>>> kOptimalNutrients = {
  'Beans': {
    'Vegetative': {
      'N': 28,
      'P': 45,
      'K': 56,
      'Zn': 2.0,
      'Fe': 10.0,
      'Mn': 5.0,
      'Cu': 1.0,
      'B': 0.5,
      'Mo': 0.1,
    },
    'Flowering': {
      'N': 28,
      'P': 0,
      'K': 56,
      'Zn': 2.0,
      'Fe': 10.0,
      'Mn': 5.0,
      'Cu': 1.0,
      'B': 0.5,
      'Mo': 0.1,
    },
    'Pod Development': {
      'N': 28,
      'P': 0,
      'K': 56,
      'Zn': 2.0,
      'Fe': 10.0,
      'Mn': 5.0,
      'Cu': 1.0,
      'B': 0.5,
      'Mo': 0.1,
    },
  },
  'Maize': {
    'Emergence to V6': {
      'N': 45,
      'P': 28,
      'K': 56,
      'Zn': 3.0,
      'Fe': 15.0,
      'Mn': 6.0,
      'Cu': 1.5,
      'B': 0.6,
      'Mo': 0.2,
    },
    'V6 to VT': {
      'N': 84,
      'P': 28,
      'K': 56,
      'Zn': 3.0,
      'Fe': 15.0,
      'Mn': 6.0,
      'Cu': 1.5,
      'B': 0.6,
      'Mo': 0.2,
    },
    'Reproductive': {
      'N': 0,
      'P': 0,
      'K': 28,
      'Zn': 3.0,
      'Fe': 15.0,
      'Mn': 6.0,
      'Cu': 1.5,
      'B': 0.6,
      'Mo': 0.2,
    },
  },
  'Tomatoes': {
    'Early Growth': {
      'N': 100,
      'P': 50,
      'K': 150,
      'Zn': 2.5,
      'Fe': 12.0,
      'Mn': 5.5,
      'Cu': 1.2,
      'B': 0.7,
      'Mo': 0.15,
    },
    'Flowering and Fruit Set': {
      'N': 80,
      'P': 60,
      'K': 150,
      'Zn': 2.5,
      'Fe': 12.0,
      'Mn': 5.5,
      'Cu': 1.2,
      'B': 0.7,
      'Mo': 0.15,
    },
    'Fruit Development': {
      'N': 60,
      'P': 60,
      'K': 200,
      'Zn': 2.5,
      'Fe': 12.0,
      'Mn': 5.5,
      'Cu': 1.2,
      'B': 0.7,
      'Mo': 0.15,
    },
  },
  'Cabbages/Kales': {
    'Early Growth': {
      'N': 120,
      'P': 60,
      'K': 100,
      'Zn': 2.0,
      'Fe': 10.0,
      'Mn': 5.0,
      'Cu': 1.0,
      'B': 0.5,
      'Mo': 0.1,
    },
    'Leaf Development': {
      'N': 100,
      'P': 60,
      'K': 100,
      'Zn': 2.0,
      'Fe': 10.0,
      'Mn': 5.0,
      'Cu': 1.0,
      'B': 0.5,
      'Mo': 0.1,
    },
    'Head Formation': {
      'N': 80,
      'P': 60,
      'K': 120,
      'Zn': 2.0,
      'Fe': 10.0,
      'Mn': 5.0,
      'Cu': 1.0,
      'B': 0.5,
      'Mo': 0.1,
    },
  },
  'Carrots': {
    'Early Growth': {
      'N': 80,
      'P': 60,
      'K': 120,
      'Zn': 2.0,
      'Fe': 10.0,
      'Mn': 5.0,
      'Cu': 1.0,
      'B': 0.5,
      'Mo': 0.1,
    },
    'Root Expansion': {
      'N': 60,
      'P': 80,
      'K': 140,
      'Zn': 2.0,
      'Fe': 10.0,
      'Mn': 5.0,
      'Cu': 1.0,
      'B': 0.5,
      'Mo': 0.1,
    },
    'Maturation': {
      'N': 40,
      'P': 60,
      'K': 140,
      'Zn': 2.0,
      'Fe': 10.0,
      'Mn': 5.0,
      'Cu': 1.0,
      'B': 0.5,
      'Mo': 0.1,
    },
  },
  'Irish Potatoes': {
    'Early Growth': {
      'N': 100,
      'P': 80,
      'K': 150,
      'Zn': 2.5,
      'Fe': 12.0,
      'Mn': 5.5,
      'Cu': 1.2,
      'B': 0.7,
      'Mo': 0.15,
    },
    'Tuber Initiation': {
      'N': 80,
      'P': 100,
      'K': 180,
      'Zn': 2.5,
      'Fe': 12.0,
      'Mn': 5.5,
      'Cu': 1.2,
      'B': 0.7,
      'Mo': 0.15,
    },
    'Tuber Bulking': {
      'N': 60,
      'P': 80,
      'K': 200,
      'Zn': 2.5,
      'Fe': 12.0,
      'Mn': 5.5,
      'Cu': 1.2,
      'B': 0.7,
      'Mo': 0.15,
    },
  },
  'Wheat': {
    'Early Growth': {
      'N': 100,
      'P': 50,
      'K': 60,
      'Zn': 3.0,
      'Fe': 15.0,
      'Mn': 6.0,
      'Cu': 1.5,
      'B': 0.6,
      'Mo': 0.2,
    },
    'Tillering and Stem Elongation': {
      'N': 120,
      'P': 50,
      'K': 60,
      'Zn': 3.0,
      'Fe': 15.0,
      'Mn': 6.0,
      'Cu': 1.5,
      'B': 0.6,
      'Mo': 0.2,
    },
    'Grain Filling': {
      'N': 80,
      'P': 40,
      'K': 50,
      'Zn': 3.0,
      'Fe': 15.0,
      'Mn': 6.0,
      'Cu': 1.5,
      'B': 0.6,
      'Mo': 0.2,
    },
  },
  'Sugarcane': {
    'Early Growth': {
      'N': 120,
      'P': 60,
      'K': 150,
      'Zn': 2.5,
      'Fe': 12.0,
      'Mn': 5.5,
      'Cu': 1.2,
      'B': 0.7,
      'Mo': 0.15,
    },
    'Grand Growth Phase': {
      'N': 150,
      'P': 60,
      'K': 180,
      'Zn': 2.5,
      'Fe': 12.0,
      'Mn': 5.5,
      'Cu': 1.2,
      'B': 0.7,
      'Mo': 0.15,
    },
    'Maturity': {
      'N': 80,
      'P': 40,
      'K': 120,
      'Zn': 2.5,
      'Fe': 12.0,
      'Mn': 5.5,
      'Cu': 1.2,
      'B': 0.7,
      'Mo': 0.15,
    },
  },
  'Rice': {
    'Early Growth': {
      'N': 100,
      'P': 40,
      'K': 80,
      'Zn': 3.0,
      'Fe': 15.0,
      'Mn': 6.0,
      'Cu': 1.5,
      'B': 0.6,
      'Mo': 0.2,
    },
    'Tillering to Panicle Initiation': {
      'N': 120,
      'P': 50,
      'K': 80,
      'Zn': 3.0,
      'Fe': 15.0,
      'Mn': 6.0,
      'Cu': 1.5,
      'B': 0.6,
      'Mo': 0.2,
    },
    'Grain Filling': {
      'N': 80,
      'P': 40,
      'K': 60,
      'Zn': 3.0,
      'Fe': 15.0,
      'Mn': 6.0,
      'Cu': 1.5,
      'B': 0.6,
      'Mo': 0.2,
    },
  },
  'Onions': {
    'Early Growth': {
      'N': 90,
      'P': 70,
      'K': 105,
      'Zn': 2.0,
      'Fe': 10.0,
      'Mn': 5.0,
      'Cu': 1.0,
      'B': 0.5,
      'Mo': 0.1,
    },
    'Bulb Formation': {
      'N': 0,
      'P': 70,
      'K': 105,
      'Zn': 2.0,
      'Fe': 10.0,
      'Mn': 5.0,
      'Cu': 1.0,
      'B': 0.5,
      'Mo': 0.1,
    },
    'Maturation': {
      'N': 0,
      'P': 0,
      'K': 60,
      'Zn': 2.0,
      'Fe': 10.0,
      'Mn': 5.0,
      'Cu': 1.0,
      'B': 0.5,
      'Mo': 0.1,
    },
  },
};

/// Soil level band for a nutrient. [moderate] = within ±10% of the target.
enum NutrientBand {
  low('Low'),
  moderate('Moderate'),
  high('High');

  final String label;
  const NutrientBand(this.label);

  static NutrientBand? fromName(String? s) =>
      NutrientBand.values.where((b) => b.name == s).firstOrNull;
}

/// Band for [value] against [optimal]; null when either is unknown.
NutrientBand? nutrientBand(double? value, double optimal) {
  if (value == null || optimal <= 0) return null;
  if (value < optimal * 0.9) return NutrientBand.low;
  if (value > optimal * 1.1) return NutrientBand.high;
  return NutrientBand.moderate;
}

/// Average N/P/K target over the crops (type + stage) in a field record.
Map<String, double> optimalFor(List<Map<String, dynamic>> crops) {
  final sum = {'N': 0.0, 'P': 0.0, 'K': 0.0};
  var n = 0;
  for (final c in crops) {
    final opt = nutrientTargets('${c['type'] ?? ''}', '${c['stage'] ?? ''}');
    if (opt == null) continue;
    sum.updateAll((k, v) => v + (opt[k] ?? 0));
    n++;
  }
  if (n > 0) sum.updateAll((_, v) => v / n);
  return sum;
}

/// The farmer's measured N/P/K bands from one fielddata record. Nutrients
/// that were not measured (or whose crop has no target) are left out.
Map<String, NutrientBand> bandsFromFieldData(Map<String, dynamic> d) {
  final crops = ((d['crops'] as List?) ?? const [])
      .whereType<Map>()
      .map((c) => Map<String, dynamic>.from(c))
      .toList();
  final opt = optimalFor(crops);
  final npk = Map<String, dynamic>.from((d['npk'] as Map?) ?? const {});
  final out = <String, NutrientBand>{};
  for (final k in const ['N', 'P', 'K']) {
    final b = nutrientBand((npk[k] as num?)?.toDouble(), opt[k] ?? 0);
    if (b != null) out[k] = b;
  }
  return out;
}

/// When the field record was taken (for "measured on …").
DateTime? fieldDataTime(Map<String, dynamic> d) =>
    d['timestamp'] is Timestamp ? (d['timestamp'] as Timestamp).toDate() : null;
