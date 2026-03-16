// lib/education/data/soil_optimal_ranges.dart
// Optimal soil nutrient ranges per crop and stage

/// Soil optimal ranges database
/// Maps 'Crop_Stage' to nutrient ranges
final Map<String, Map<String, Map<String, dynamic>>> soilOptimalRanges = {
  
  // ═══════════════════════════════════════════════════════════════
  // TOMATOES - ALL STAGES
  // ═══════════════════════════════════════════════════════════════
  
  'Tomatoes_Germination/Seedling': {
    'nitrogen': {'min': 15.0, 'max': 30.0, 'unit': 'ppm', 'optimal': 20.0},
    'phosphorus': {'min': 20.0, 'max': 40.0, 'unit': 'ppm', 'optimal': 30.0},
    'potassium': {'min': 120.0, 'max': 200.0, 'unit': 'ppm', 'optimal': 150.0},
    'calcium': {'min': 150.0, 'max': 300.0, 'unit': 'ppm', 'optimal': 200.0},
    'magnesium': {'min': 40.0, 'max': 80.0, 'unit': 'ppm', 'optimal': 60.0},
    'sulfur': {'min': 10.0, 'max': 20.0, 'unit': 'ppm', 'optimal': 15.0},
    'iron': {'min': 4.0, 'max': 10.0, 'unit': 'ppm', 'optimal': 6.0},
    'zinc': {'min': 1.0, 'max': 5.0, 'unit': 'ppm', 'optimal': 2.0},
    'boron': {'min': 0.3, 'max': 1.0, 'unit': 'ppm', 'optimal': 0.5},
    'manganese': {'min': 2.0, 'max': 10.0, 'unit': 'ppm', 'optimal': 5.0},
    'pH': {'min': 6.0, 'max': 7.0, 'optimal': 6.5},
    'organicMatter': {'min': 3.0, 'max': 5.0, 'unit': '%', 'optimal': 4.0},
  },
  
  'Tomatoes_Vegetative Growth/Weeding': {
    'nitrogen': {'min': 20.0, 'max': 40.0, 'unit': 'ppm', 'optimal': 30.0},
    'phosphorus': {'min': 15.0, 'max': 30.0, 'unit': 'ppm', 'optimal': 20.0},
    'potassium': {'min': 150.0, 'max': 250.0, 'unit': 'ppm', 'optimal': 200.0},
    'calcium': {'min': 150.0, 'max': 300.0, 'unit': 'ppm', 'optimal': 200.0},
    'magnesium': {'min': 40.0, 'max': 80.0, 'unit': 'ppm', 'optimal': 60.0},
    'sulfur': {'min': 10.0, 'max': 20.0, 'unit': 'ppm', 'optimal': 15.0},
    'iron': {'min': 4.0, 'max': 10.0, 'unit': 'ppm', 'optimal': 6.0},
    'zinc': {'min': 1.0, 'max': 5.0, 'unit': 'ppm', 'optimal': 2.0},
    'boron': {'min': 0.3, 'max': 1.0, 'unit': 'ppm', 'optimal': 0.5},
    'manganese': {'min': 2.0, 'max': 10.0, 'unit': 'ppm', 'optimal': 5.0},
    'pH': {'min': 6.0, 'max': 7.0, 'optimal': 6.5},
    'organicMatter': {'min': 3.0, 'max': 5.0, 'unit': '%', 'optimal': 4.0},
  },
  
  'Tomatoes_Flowering/Reproductive': {
    'nitrogen': {'min': 15.0, 'max': 30.0, 'unit': 'ppm', 'optimal': 20.0},
    'phosphorus': {'min': 20.0, 'max': 40.0, 'unit': 'ppm', 'optimal': 30.0},
    'potassium': {'min': 180.0, 'max': 300.0, 'unit': 'ppm', 'optimal': 240.0},
    'calcium': {'min': 200.0, 'max': 350.0, 'unit': 'ppm', 'optimal': 250.0},
    'magnesium': {'min': 50.0, 'max': 90.0, 'unit': 'ppm', 'optimal': 70.0},
    'sulfur': {'min': 10.0, 'max': 20.0, 'unit': 'ppm', 'optimal': 15.0},
    'iron': {'min': 4.0, 'max': 10.0, 'unit': 'ppm', 'optimal': 6.0},
    'zinc': {'min': 1.0, 'max': 5.0, 'unit': 'ppm', 'optimal': 2.0},
    'boron': {'min': 0.5, 'max': 1.5, 'unit': 'ppm', 'optimal': 1.0},
    'manganese': {'min': 2.0, 'max': 10.0, 'unit': 'ppm', 'optimal': 5.0},
    'pH': {'min': 6.0, 'max': 7.0, 'optimal': 6.5},
    'organicMatter': {'min': 3.0, 'max': 5.0, 'unit': '%', 'optimal': 4.0},
  },
  
  // ═══════════════════════════════════════════════════════════════
  // BEANS - ALL STAGES
  // ═══════════════════════════════════════════════════════════════
  
  'Beans_Germination/Seedling': {
    'nitrogen': {'min': 10.0, 'max': 25.0, 'unit': 'ppm', 'optimal': 15.0},
    'phosphorus': {'min': 15.0, 'max': 35.0, 'unit': 'ppm', 'optimal': 25.0},
    'potassium': {'min': 100.0, 'max': 180.0, 'unit': 'ppm', 'optimal': 140.0},
    'calcium': {'min': 120.0, 'max': 250.0, 'unit': 'ppm', 'optimal': 180.0},
    'magnesium': {'min': 35.0, 'max': 70.0, 'unit': 'ppm', 'optimal': 50.0},
    'sulfur': {'min': 8.0, 'max': 18.0, 'unit': 'ppm', 'optimal': 12.0},
    'iron': {'min': 3.0, 'max': 8.0, 'unit': 'ppm', 'optimal': 5.0},
    'zinc': {'min': 0.8, 'max': 4.0, 'unit': 'ppm', 'optimal': 1.5},
    'boron': {'min': 0.2, 'max': 0.8, 'unit': 'ppm', 'optimal': 0.4},
    'manganese': {'min': 1.5, 'max': 8.0, 'unit': 'ppm', 'optimal': 4.0},
    'pH': {'min': 6.0, 'max': 7.5, 'optimal': 6.5},
    'organicMatter': {'min': 2.5, 'max': 4.5, 'unit': '%', 'optimal': 3.5},
  },
  
  'Beans_Vegetative Growth/Weeding': {
    'nitrogen': {'min': 12.0, 'max': 30.0, 'unit': 'ppm', 'optimal': 20.0},
    'phosphorus': {'min': 15.0, 'max': 35.0, 'unit': 'ppm', 'optimal': 25.0},
    'potassium': {'min': 120.0, 'max': 200.0, 'unit': 'ppm', 'optimal': 160.0},
    'calcium': {'min': 120.0, 'max': 250.0, 'unit': 'ppm', 'optimal': 180.0},
    'magnesium': {'min': 35.0, 'max': 70.0, 'unit': 'ppm', 'optimal': 50.0},
    'sulfur': {'min': 8.0, 'max': 18.0, 'unit': 'ppm', 'optimal': 12.0},
    'iron': {'min': 3.0, 'max': 8.0, 'unit': 'ppm', 'optimal': 5.0},
    'zinc': {'min': 0.8, 'max': 4.0, 'unit': 'ppm', 'optimal': 1.5},
    'boron': {'min': 0.2, 'max': 0.8, 'unit': 'ppm', 'optimal': 0.4},
    'manganese': {'min': 1.5, 'max': 8.0, 'unit': 'ppm', 'optimal': 4.0},
    'pH': {'min': 6.0, 'max': 7.5, 'optimal': 6.5},
    'organicMatter': {'min': 2.5, 'max': 4.5, 'unit': '%', 'optimal': 3.5},
  },
  
  // ═══════════════════════════════════════════════════════════════
  // MAIZE - ALL STAGES
  // ═══════════════════════════════════════════════════════════════
  
  'Maize_Germination/Seedling': {
    'nitrogen': {'min': 18.0, 'max': 35.0, 'unit': 'ppm', 'optimal': 25.0},
    'phosphorus': {'min': 12.0, 'max': 28.0, 'unit': 'ppm', 'optimal': 18.0},
    'potassium': {'min': 130.0, 'max': 220.0, 'unit': 'ppm', 'optimal': 170.0},
    'calcium': {'min': 140.0, 'max': 280.0, 'unit': 'ppm', 'optimal': 200.0},
    'magnesium': {'min': 38.0, 'max': 75.0, 'unit': 'ppm', 'optimal': 55.0},
    'sulfur': {'min': 9.0, 'max': 19.0, 'unit': 'ppm', 'optimal': 14.0},
    'iron': {'min': 3.5, 'max': 9.0, 'unit': 'ppm', 'optimal': 5.5},
    'zinc': {'min': 0.9, 'max': 4.5, 'unit': 'ppm', 'optimal': 1.8},
    'boron': {'min': 0.25, 'max': 0.9, 'unit': 'ppm', 'optimal': 0.45},
    'manganese': {'min': 1.8, 'max': 9.0, 'unit': 'ppm', 'optimal': 4.5},
    'pH': {'min': 5.8, 'max': 7.0, 'optimal': 6.0},
    'organicMatter': {'min': 2.8, 'max': 4.8, 'unit': '%', 'optimal': 3.8},
  },
  
  'Maize_Vegetative Growth/Weeding': {
    'nitrogen': {'min': 25.0, 'max': 50.0, 'unit': 'ppm', 'optimal': 35.0},
    'phosphorus': {'min': 12.0, 'max': 28.0, 'unit': 'ppm', 'optimal': 18.0},
    'potassium': {'min': 150.0, 'max': 250.0, 'unit': 'ppm', 'optimal': 200.0},
    'calcium': {'min': 140.0, 'max': 280.0, 'unit': 'ppm', 'optimal': 200.0},
    'magnesium': {'min': 38.0, 'max': 75.0, 'unit': 'ppm', 'optimal': 55.0},
    'sulfur': {'min': 9.0, 'max': 19.0, 'unit': 'ppm', 'optimal': 14.0},
    'iron': {'min': 3.5, 'max': 9.0, 'unit': 'ppm', 'optimal': 5.5},
    'zinc': {'min': 0.9, 'max': 4.5, 'unit': 'ppm', 'optimal': 1.8},
    'boron': {'min': 0.25, 'max': 0.9, 'unit': 'ppm', 'optimal': 0.45},
    'manganese': {'min': 1.8, 'max': 9.0, 'unit': 'ppm', 'optimal': 4.5},
    'pH': {'min': 5.8, 'max': 7.0, 'optimal': 6.0},
    'organicMatter': {'min': 2.8, 'max': 4.8, 'unit': '%', 'optimal': 3.8},
  },
  
  // ═══════════════════════════════════════════════════════════════
  // DEFAULT RANGES (for crops without specific data)
  // ═══════════════════════════════════════════════════════════════
  
  'DEFAULT': {
    'nitrogen': {'min': 15.0, 'max': 35.0, 'unit': 'ppm', 'optimal': 25.0},
    'phosphorus': {'min': 12.0, 'max': 30.0, 'unit': 'ppm', 'optimal': 20.0},
    'potassium': {'min': 120.0, 'max': 220.0, 'unit': 'ppm', 'optimal': 170.0},
    'calcium': {'min': 140.0, 'max': 280.0, 'unit': 'ppm', 'optimal': 200.0},
    'magnesium': {'min': 35.0, 'max': 75.0, 'unit': 'ppm', 'optimal': 55.0},
    'sulfur': {'min': 8.0, 'max': 18.0, 'unit': 'ppm', 'optimal': 13.0},
    'iron': {'min': 3.0, 'max': 9.0, 'unit': 'ppm', 'optimal': 5.0},
    'zinc': {'min': 0.8, 'max': 4.0, 'unit': 'ppm', 'optimal': 1.5},
    'boron': {'min': 0.2, 'max': 0.9, 'unit': 'ppm', 'optimal': 0.4},
    'manganese': {'min': 1.5, 'max': 9.0, 'unit': 'ppm', 'optimal': 4.0},
    'pH': {'min': 6.0, 'max': 7.0, 'optimal': 6.5},
    'organicMatter': {'min': 2.5, 'max': 5.0, 'unit': '%', 'optimal': 3.5},
  },
};

/// Helper function to get optimal ranges for a crop and stage
Map<String, Map<String, dynamic>>? getOptimalRanges(String crop, String stage) {
  final key = '${crop}_$stage';
  return soilOptimalRanges[key] ?? soilOptimalRanges['DEFAULT'];
}

/// Analyze nutrient status compared to optimal range
String analyzeNutrientStatus(double value, String nutrient, String crop, String stage) {
  final ranges = getOptimalRanges(crop, stage);
  if (ranges == null || !ranges.containsKey(nutrient)) return 'unknown';
  
  final min = ranges[nutrient]!['min'] as double;
  final max = ranges[nutrient]!['max'] as double;
  final _ = ranges[nutrient]!['optimal'] as double;
  
  // Deficient: < 70% of minimum
  if (value < min * 0.7) return 'deficient';
  
  // Low: between 70% of min and min
  if (value < min) return 'low';
  
  // Optimal: between min and max
  if (value >= min && value <= max) return 'optimal';
  
  // High: between max and 130% of max
  if (value <= max * 1.3) return 'high';
  
  // Excess: > 130% of max
  return 'excess';
}