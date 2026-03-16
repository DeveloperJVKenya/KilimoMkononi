// lib/education/data/fertilizer_recommendations.dart
// Fertilizer recommendations for nutrient deficiencies

/// Fertilizer recommendations database
final Map<String, Map<String, dynamic>> fertilizerRecommendations = {
  
  // ═══════════════════════════════════════════════════════════════
  // NITROGEN
  // ═══════════════════════════════════════════════════════════════
  
  'nitrogen_deficient': {
    'symptoms': [
      'Yellowing of older leaves (chlorosis)',
      'Stunted growth and reduced plant size',
      'Pale green color overall',
      'Thin, spindly stems',
      'Reduced tillering in cereals',
    ],
    'chemical': [
      {
        'name': 'Urea (46-0-0)',
        'rate': '25-50 kg/acre',
        'timing': 'Split application - half at planting, half at 4 weeks',
        'notes': 'Most concentrated nitrogen source',
      },
      {
        'name': 'CAN (Calcium Ammonium Nitrate) (26-0-0)',
        'rate': '50-75 kg/acre',
        'timing': 'Apply in splits every 3-4 weeks',
        'notes': 'Quick release, good for immediate needs',
      },
      {
        'name': 'Ammonium Sulfate (21-0-0)',
        'rate': '60-100 kg/acre',
        'timing': 'Apply before planting or as top dressing',
        'notes': 'Also provides sulfur, good for alkaline soils',
      },
    ],
    'organic': [
      {
        'name': 'Well-rotted Manure',
        'rate': '3-5 tons/acre',
        'timing': 'Apply 2-3 weeks before planting',
        'notes': 'Improves soil structure and adds other nutrients',
      },
      {
        'name': 'Compost',
        'rate': '5-10 tons/acre',
        'timing': 'Incorporate into soil before planting',
        'notes': 'Slow release, improves soil health',
      },
      {
        'name': 'Blood Meal',
        'rate': '100-200 kg/acre',
        'timing': 'Apply and incorporate before planting',
        'notes': 'Quick-release organic nitrogen (12-0-0)',
      },
    ],
  },
  
  'nitrogen_low': {
    'symptoms': [
      'Slightly pale green leaves',
      'Slower than normal growth',
    ],
    'chemical': [
      {
        'name': 'Urea (46-0-0)',
        'rate': '15-30 kg/acre',
        'timing': 'Single application or light top dressing',
        'notes': 'Half the deficient rate',
      },
    ],
    'organic': [
      {
        'name': 'Compost',
        'rate': '2-4 tons/acre',
        'timing': 'Top dress around plants',
        'notes': 'Maintains levels',
      },
    ],
  },
  
  // ═══════════════════════════════════════════════════════════════
  // PHOSPHORUS
  // ═══════════════════════════════════════════════════════════════
  
  'phosphorus_deficient': {
    'symptoms': [
      'Purple or dark green leaves',
      'Poor root development',
      'Stunted growth',
      'Delayed maturity',
      'Reduced flowering and fruiting',
    ],
    'chemical': [
      {
        'name': 'DAP (Di-Ammonium Phosphate) (18-46-0)',
        'rate': '40-60 kg/acre',
        'timing': 'Band placement at planting, 5cm from seed',
        'notes': 'Also provides nitrogen, best for planting',
      },
      {
        'name': 'TSP (Triple Super Phosphate) (0-46-0)',
        'rate': '30-50 kg/acre',
        'timing': 'Broadcast and incorporate before planting',
        'notes': 'Pure phosphorus source',
      },
      {
        'name': 'SSP (Single Super Phosphate) (0-20-0)',
        'rate': '60-100 kg/acre',
        'timing': 'Apply before planting, mix into soil',
        'notes': 'Also provides calcium and sulfur',
      },
    ],
    'organic': [
      {
        'name': 'Bone Meal',
        'rate': '2-3 tons/acre',
        'timing': 'Apply 2-3 weeks before planting',
        'notes': 'Slow release (3-15-0), also adds calcium',
      },
      {
        'name': 'Rock Phosphate',
        'rate': '1-2 tons/acre',
        'timing': 'Apply several months before planting',
        'notes': 'Very slow release, long-term source',
      },
    ],
  },
  
  'phosphorus_low': {
    'symptoms': [
      'Slightly darker leaves',
      'Slow root establishment',
    ],
    'chemical': [
      {
        'name': 'DAP (18-46-0)',
        'rate': '20-35 kg/acre',
        'timing': 'Band at planting',
        'notes': 'Half the deficient rate',
      },
    ],
    'organic': [
      {
        'name': 'Bone Meal',
        'rate': '1-1.5 tons/acre',
        'timing': 'Mix into soil',
        'notes': 'Maintain levels',
      },
    ],
  },
  
  // ═══════════════════════════════════════════════════════════════
  // POTASSIUM
  // ═══════════════════════════════════════════════════════════════
  
  'potassium_deficient': {
    'symptoms': [
      'Yellowing and browning of leaf edges (marginal burn)',
      'Weak stems, plants lodge easily',
      'Poor fruit quality',
      'Reduced disease resistance',
      'Slow growth',
    ],
    'chemical': [
      {
        'name': 'Muriate of Potash (MOP/KCl) (0-0-60)',
        'rate': '30-50 kg/acre',
        'timing': 'Broadcast before planting or side dress',
        'notes': 'Most common and economical K source',
      },
      {
        'name': 'Sulfate of Potash (SOP/K2SO4) (0-0-50)',
        'rate': '35-60 kg/acre',
        'timing': 'Apply before planting or at fruit set',
        'notes': 'Chloride-free, better for sensitive crops',
      },
    ],
    'organic': [
      {
        'name': 'Wood Ash',
        'rate': '1-2 tons/acre',
        'timing': 'Broadcast and incorporate',
        'notes': 'Contains 3-7% K, also raises pH',
      },
      {
        'name': 'Kelp Meal/Seaweed',
        'rate': '200-400 kg/acre',
        'timing': 'Mix into soil or side dress',
        'notes': 'Contains K plus trace minerals',
      },
      {
        'name': 'Compost (high quality)',
        'rate': '5-10 tons/acre',
        'timing': 'Incorporate before planting',
        'notes': 'Gradual K release',
      },
    ],
  },
  
  'potassium_low': {
    'symptoms': [
      'Slight yellowing of leaf tips',
      'Reduced vigor',
    ],
    'chemical': [
      {
        'name': 'Muriate of Potash (0-0-60)',
        'rate': '15-25 kg/acre',
        'timing': 'Side dress',
        'notes': 'Light application',
      },
    ],
    'organic': [
      {
        'name': 'Wood Ash',
        'rate': '500-1000 kg/acre',
        'timing': 'Broadcast lightly',
        'notes': 'Monitor pH',
      },
    ],
  },
  
  // ═══════════════════════════════════════════════════════════════
  // pH CORRECTION
  // ═══════════════════════════════════════════════════════════════
  
  'pH_low': {
    'symptoms': [
      'Acidic soil (pH < 6.0)',
      'Reduced nutrient availability',
      'Aluminum/manganese toxicity possible',
    ],
    'chemical': [
      {
        'name': 'Agricultural Lime (CaCO3)',
        'rate': '1-3 tons/acre (depends on pH)',
        'timing': 'Apply 2-3 months before planting',
        'notes': 'Raises pH slowly, adds calcium',
      },
      {
        'name': 'Dolomitic Lime (CaMg(CO3)2)',
        'rate': '1-3 tons/acre',
        'timing': 'Apply 2-3 months before planting',
        'notes': 'Raises pH, adds calcium and magnesium',
      },
    ],
    'organic': [
      {
        'name': 'Wood Ash',
        'rate': '500-2000 kg/acre',
        'timing': 'Apply and incorporate',
        'notes': 'Raises pH quickly but temporarily',
      },
    ],
  },
  
  'pH_high': {
    'symptoms': [
      'Alkaline soil (pH > 7.5)',
      'Iron, zinc, manganese deficiencies common',
      'Phosphorus less available',
    ],
    'chemical': [
      {
        'name': 'Elemental Sulfur',
        'rate': '200-500 kg/acre',
        'timing': 'Apply 2-3 months before planting',
        'notes': 'Lowers pH slowly and safely',
      },
      {
        'name': 'Ammonium Sulfate',
        'rate': '300-600 kg/acre',
        'timing': 'Apply and incorporate',
        'notes': 'Lowers pH, adds nitrogen and sulfur',
      },
    ],
    'organic': [
      {
        'name': 'Sulfur (elemental)',
        'rate': '200-400 kg/acre',
        'timing': 'Apply several months early',
        'notes': 'Slow acting, safe',
      },
      {
        'name': 'Compost (acidic)',
        'rate': '5-10 tons/acre',
        'timing': 'Incorporate regularly',
        'notes': 'Gradual pH adjustment',
      },
    ],
  },
  
  // ═══════════════════════════════════════════════════════════════
  // ORGANIC MATTER
  // ═══════════════════════════════════════════════════════════════
  
  'organicMatter_low': {
    'symptoms': [
      'Poor soil structure',
      'Low water holding capacity',
      'Poor nutrient retention',
      'Rapid nutrient leaching',
    ],
    'chemical': [],  // No chemical solution for organic matter
    'organic': [
      {
        'name': 'Compost',
        'rate': '10-20 tons/acre',
        'timing': 'Apply annually and incorporate',
        'notes': 'Best long-term solution',
      },
      {
        'name': 'Well-rotted Manure',
        'rate': '5-10 tons/acre',
        'timing': 'Apply before planting',
        'notes': 'Adds organic matter and nutrients',
      },
      {
        'name': 'Cover Crops (Green Manure)',
        'rate': 'Full cover',
        'timing': 'Grow in off-season, incorporate before flowering',
        'notes': 'Adds organic matter, improves structure',
      },
      {
        'name': 'Mulch',
        'rate': '5-10 cm layer',
        'timing': 'Apply on surface around plants',
        'notes': 'Decomposes gradually, adds organic matter',
      },
    ],
  },
};

/// Get recommendations for a nutrient status
Map<String, dynamic>? getRecommendation(String nutrient, String status) {
  final key = '${nutrient}_$status';
  return fertilizerRecommendations[key];
}