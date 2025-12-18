// lib/education/utils/class_id_parser.dart
part of 'education_utils.dart';

(String shortGradeId, String contentType, String system) parseClassIdAndModule(
    String classId, String module) {
  if (classId.isEmpty) return ('', '', 'cbcJunior');

  // FULL ID: Kianda_School_junior_7
  final fullMatch = RegExp(r'_([^_]+)_(\d+)$').firstMatch(classId);
  if (fullMatch != null) {
    final systemPart = fullMatch.group(1)!;
    final grade = fullMatch.group(2)!;
    final system = switch (systemPart) {
      'primary' => 'cbcPrimary',
      'junior' => 'cbcJunior',
      'senior' => 'cbcSenior',
      'eightfourfour' => 'eightFourFour',
      _ => 'cbcJunior',
    };
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
    return (grade, contentType, system);
  }

  // SHORT ID: 7|cbcJunior
  final parts = classId.split('|');
  final shortId = parts[0];
  final system = parts.length > 1 ? parts[1] : 'cbcJunior';
  if (RegExp(r'^\d+$').hasMatch(shortId)) {
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
    return (shortId, contentType, system);
  }

  return ('', '', 'cbcJunior');
}

String buildFullGradeId(String schoolName, String shortGradeId, String system) {
  final normalizedSchool = schoolName.trim().replaceAll(' ', '_');
  final systemSuffix = switch (system) {
    'cbcPrimary' => 'primary',
    'cbcJunior' => 'junior',
    'cbcSenior' => 'senior',
    'eightFourFour' => 'eightfourfour',
    _ => 'junior',
  };
  // Full ID format: SchoolName_system_grade
  return '${normalizedSchool}_${systemSuffix}_$shortGradeId';
}

/// Extract school name from full class ID (human-readable with spaces)
String extractSchoolName(String classId) {
  // Pattern: SchoolName_system_grade
  final match = RegExp(r'^(.+)_(primary|junior|senior|eightfourfour)_\d+$').firstMatch(classId);
  if (match != null) {
    return match.group(1)!.replaceAll('_', ' ');
  }
  return '';
}

/// Extract normalized school name (with underscores) from full class ID
String extractNormalizedSchoolName(String classId) {
  final match = RegExp(r'^(.+)_(primary|junior|senior|eightfourfour)_\d+$').firstMatch(classId);
  if (match != null) {
    return match.group(1)!;
  }
  return '';
}

/// Extract system from full class ID
String extractSystem(String classId) {
  final match = RegExp(r'_(primary|junior|senior|eightfourfour)_\d+$').firstMatch(classId);
  if (match != null) {
    return match.group(1)!;
  }
  return '';
}

/// Extract grade number from full class ID
String extractGrade(String classId) {
  final match = RegExp(r'_(\d+)$').firstMatch(classId);
  if (match != null) {
    return match.group(1)!;
  }
  return '';
}

/// Build Firestore path with proper hierarchy
/// Returns: schools/{schoolName}/systems/{system}/grades/{grade}
String buildFirestorePath(String classId) {
  final match = RegExp(r'^(.+)_(primary|junior|senior|eightfourfour)_(\d+)$').firstMatch(classId);
  if (match != null) {
    final schoolName = match.group(1)!;
    final system = match.group(2)!;
    final grade = match.group(3)!;
    return 'schools/$schoolName/systems/$system/grades/$grade';
  }
  return '';
}

/// Get Firestore collection reference parts as a record
/// Returns: (schoolName, system, grade)
(String, String, String) parseClassIdForFirestore(String classId) {
  final match = RegExp(r'^(.+)_(primary|junior|senior|eightfourfour)_(\d+)$').firstMatch(classId);
  if (match != null) {
    return (match.group(1)!, match.group(2)!, match.group(3)!);
  }
  return ('', '', '');
}