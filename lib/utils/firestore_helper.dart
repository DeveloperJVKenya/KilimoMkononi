// lib/education/utils/firestore_helper.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kilimomkononi/utils/education_utils.dart';

class FirestoreHelper {
  static final _firestore = FirebaseFirestore.instance;

  /// Get school collection reference
  /// Path: /schools/{schoolName}
  static CollectionReference getSchoolsCollection() {
    return _firestore.collection('schools');
  }

  /// Get specific school document reference
  /// Path: /schools/{schoolName}
  static DocumentReference getSchoolDoc(String normalizedSchoolName) {
    return _firestore.collection('schools').doc(normalizedSchoolName);
  }

  /// Get systems collection for a school
  /// Path: /schools/{schoolName}/systems
  static CollectionReference getSystemsCollection(String normalizedSchoolName) {
    return _firestore
        .collection('schools')
        .doc(normalizedSchoolName)
        .collection('systems');
  }

  /// Get grades collection for a school system
  /// Path: /schools/{schoolName}/systems/{system}/grades
  static CollectionReference getGradesCollection(
      String normalizedSchoolName, String system) {
    return _firestore
        .collection('schools')
        .doc(normalizedSchoolName)
        .collection('systems')
        .doc(system)
        .collection('grades');
  }

  /// Get specific grade document reference
  /// Path: /schools/{schoolName}/systems/{system}/grades/{grade}
  static DocumentReference getGradeDoc(
      String normalizedSchoolName, String system, String grade) {
    return _firestore
        .collection('schools')
        .doc(normalizedSchoolName)
        .collection('systems')
        .doc(system)
        .collection('grades')
        .doc(grade);
  }

  /// Get grade reference from full classId
  /// Parses classId and returns the grade document reference
  static DocumentReference? getGradeFromClassId(String classId) {
    final (school, system, grade) = parseClassIdForFirestore(classId);
    if (school.isEmpty || system.isEmpty || grade.isEmpty) return null;
    return getGradeDoc(school, system, grade);
  }

  /// Get content collection for a grade (e.g., farming_content, pest_content)
  /// Path: /schools/{schoolName}/systems/{system}/grades/{grade}/{contentType}
  static CollectionReference getContentCollection(
      String normalizedSchoolName, String system, String grade, String contentType) {
    return _firestore
        .collection('schools')
        .doc(normalizedSchoolName)
        .collection('systems')
        .doc(system)
        .collection('grades')
        .doc(grade)
        .collection(contentType);
  }

  /// Get content collection from classId
  static CollectionReference? getContentFromClassId(
      String classId, String contentType) {
    final (school, system, grade) = parseClassIdForFirestore(classId);
    if (school.isEmpty || system.isEmpty || grade.isEmpty) return null;
    return getContentCollection(school, system, grade, contentType);
  }

  /// Get submissions collection for a grade
  /// Path: /schools/{schoolName}/systems/{system}/grades/{grade}/submissions
  static CollectionReference getSubmissionsCollection(
      String normalizedSchoolName, String system, String grade) {
    return getContentCollection(normalizedSchoolName, system, grade, 'submissions');
  }

  /// Get submissions collection from classId
  static CollectionReference? getSubmissionsFromClassId(String classId) {
    return getContentFromClassId(classId, 'submissions');
  }

  /// Create or ensure school, system, and grade documents exist
  static Future<void> ensureGradeExists(String classId) async {
    final (schoolName, system, grade) = parseClassIdForFirestore(classId);
    if (schoolName.isEmpty || system.isEmpty || grade.isEmpty) {
      throw Exception('Invalid classId format: $classId');
    }

    // Create school document if it doesn't exist
    final schoolDoc = getSchoolDoc(schoolName);
    final schoolSnapshot = await schoolDoc.get();
    if (!schoolSnapshot.exists) {
      await schoolDoc.set({
        'name': extractSchoolName(classId), // Human-readable name
        'normalizedName': schoolName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // Create system document if it doesn't exist
    final systemDoc = schoolDoc.collection('systems').doc(system);
    final systemSnapshot = await systemDoc.get();
    if (!systemSnapshot.exists) {
      await systemDoc.set({
        'system': system,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // Create grade document if it doesn't exist
    final gradeDoc = systemDoc.collection('grades').doc(grade);
    final gradeSnapshot = await gradeDoc.get();
    if (!gradeSnapshot.exists) {
      await gradeDoc.set({
        'grade': grade,
        'classId': classId, // Store full classId for reference
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Example usage: Query all content for a specific class
  static Stream<QuerySnapshot> streamClassContent(
      String classId, String contentType) {
    final collection = getContentFromClassId(classId, contentType);
    if (collection == null) {
      throw Exception('Invalid classId: $classId');
    }
    return collection.snapshots();
  }

  /// Example usage: Add content to a class
  static Future<DocumentReference> addContentToClass(
      String classId, String contentType, Map<String, dynamic> data) async {
    await ensureGradeExists(classId); // Ensure structure exists
    
    final collection = getContentFromClassId(classId, contentType);
    if (collection == null) {
      throw Exception('Invalid classId: $classId');
    }
    
    return await collection.add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}