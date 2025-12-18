// lib/education/utils/education_utils.dart
String _normalizeSchool(String s) => s.trim().replaceAll(' ', '_');

/// Returns (gradeId, contentType) — school handled separately
(String gradeId, String contentType) parseClassIdAndModule(String classId, String module) {
  if (classId.isEmpty) return ('', '');

  // If short numeric ID (e.g., '7')
  if (RegExp(r'^\d+$').hasMatch(classId)) {
    final contentMap = {
      'farming': 'farming_content',
      'market': 'market_content',
      'weather': 'weather_content',
      'field': 'field_content',
      'pest': 'pest_content',
      'disease': 'disease_content',
      'farm_management': 'farm_management_content',
      'manuals': 'manuals_content',
    };
    final contentType = contentMap[module] ?? '${module}_content';
    return (classId, contentType);  // gradeId = '7'
  }

  // Full ID fallback (not used anymore)
  return ('', '');
}