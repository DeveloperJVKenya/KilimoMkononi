// lib/utils/firestore_helper.dart
//
// Handles ALL classId formats used in the app:
//
//   Format A — underscore (canonical Firestore format):
//     schoolName_system_grade
//     e.g.  "greenwood_junior_7"
//           "st_marys_senior_10"   ← schoolName itself may contain underscores
//           "greenwood_eightfourfour_3"
//           "greenwood_primary_2"
//
//   Format B — pipe (display / selection format):
//     gradeNumber|systemKey
//     e.g.  "7|cbcJunior"   "10|cbcSenior"   "3|eightFourFour"   "2|cbcPrimary"
//
//   In Format A the schoolName segment is separated from the system segment by
//   a known system keyword. The system keywords are:
//     junior, senior, primary, eightfourfour
//
//   parseClassIdForFirestore() resolves BOTH formats and always returns
//   (normalizedSchoolName, firestoreSystem, grade).
//
//   For Format B the schoolName is NOT embedded in the classId — the caller
//   must supply it via the schoolName parameter of the path-aware helpers.

import 'package:cloud_firestore/cloud_firestore.dart';

// ── Known system keywords (lower-case) used in Format A classIds ──────────
const _kSystems = ['junior', 'senior', 'primary', 'eightfourfour'];

// ── Map from pipe-format system keys → Firestore system segment ──────────
const _kPipeToFirestore = {
  'cbcjunior':     'junior',
  'cbcsenior':     'senior',
  'cbcprimary':    'primary',
  'eightfourfour': 'eightfourfour',
};

// ─────────────────────────────────────────────────────────────────────────────
//  parseClassIdForFirestore
//
//  Returns (school, system, grade) suitable for building Firestore paths.
//  Returns ('', '', '') if the classId cannot be parsed.
//
//  • Format A:  "greenwood_junior_7"   → ('greenwood', 'junior', '7')
//               "st_marys_senior_10"  → ('st_marys', 'senior', '10')
//  • Format B:  "7|cbcJunior"         → needs schoolName supplied separately;
//               when called from getContentFromClassId() the schoolName is
//               extracted from the caller context.  This function returns
//               ('', system, grade) for pipe format — callers that need the
//               school name must use the schoolName-aware variants below.
// ─────────────────────────────────────────────────────────────────────────────
(String school, String system, String grade) parseClassIdForFirestore(String classId) {
  if (classId.isEmpty) return ('', '', '');

  // ── Format B: pipe ────────────────────────────────────────────────────────
  if (classId.contains('|')) {
    final parts = classId.split('|');
    if (parts.length < 2) return ('', '', '');
    final grade  = parts[0].trim();
    final sysKey = parts[1].trim().toLowerCase();
    final system = _kPipeToFirestore[sysKey] ?? sysKey;
    // School cannot be derived from pipe format alone.
    return ('', system, grade);
  }

  // ── Format A: underscore ──────────────────────────────────────────────────
  final parts = classId.split('_');
  if (parts.length < 3) return ('', '', '');

  // Find the LAST occurrence of a known system keyword.
  // This correctly handles school names that contain underscores,
  // e.g. "st_marys_junior_7" → school='st_marys', system='junior', grade='7'
  int systemIndex = -1;
  for (int i = parts.length - 2; i >= 1; i--) {
    if (_kSystems.contains(parts[i].toLowerCase())) {
      systemIndex = i;
      break;
    }
  }
  if (systemIndex == -1) return ('', '', '');

  final school = parts.sublist(0, systemIndex).join('_');
  final system = parts[systemIndex].toLowerCase();
  final grade  = parts.sublist(systemIndex + 1).join('_');

  if (school.isEmpty || grade.isEmpty) return ('', '', '');
  return (school, system, grade);
}

// ─────────────────────────────────────────────────────────────────────────────
//  parseClassIdWithSchool
//
//  Like parseClassIdForFirestore but accepts an explicit schoolName fallback.
//  Used when the classId may be in pipe format and the schoolName is known
//  from the EducationUser document.
// ─────────────────────────────────────────────────────────────────────────────
(String school, String system, String grade) parseClassIdWithSchool(
    String classId, String schoolName) {
  final (s, sys, grade) = parseClassIdForFirestore(classId);
  if (s.isNotEmpty) return (s, sys, grade); // Format A — school embedded
  if (sys.isEmpty || grade.isEmpty) return ('', '', '');
  // Format B — use provided schoolName, normalized
  final normalizedSchool = schoolName.trim().replaceAll(' ', '_');
  return (normalizedSchool, sys, grade);
}

// ─────────────────────────────────────────────────────────────────────────────
//  extractSchoolName  (human-readable label from a Format-A classId)
// ─────────────────────────────────────────────────────────────────────────────
String extractSchoolName(String classId) {
  final (school, _, _) = parseClassIdForFirestore(classId);
  return school.replaceAll('_', ' ');
}

// =============================================================================
//  FirestoreHelper
// =============================================================================
class FirestoreHelper {
  static final _db = FirebaseFirestore.instance;

  // ── Raw path builders (accept pre-parsed segments) ───────────────────────

  static CollectionReference getSchoolsCollection() =>
      _db.collection('schools');

  static DocumentReference getSchoolDoc(String normalizedSchoolName) =>
      _db.collection('schools').doc(normalizedSchoolName);

  static CollectionReference getSystemsCollection(String normalizedSchoolName) =>
      _db.collection('schools').doc(normalizedSchoolName).collection('systems');

  static CollectionReference getGradesCollection(
          String normalizedSchoolName, String system) =>
      _db
          .collection('schools')
          .doc(normalizedSchoolName)
          .collection('systems')
          .doc(system)
          .collection('grades');

  static DocumentReference getGradeDoc(
          String normalizedSchoolName, String system, String grade) =>
      _db
          .collection('schools')
          .doc(normalizedSchoolName)
          .collection('systems')
          .doc(system)
          .collection('grades')
          .doc(grade);

  static CollectionReference getContentCollection(
          String normalizedSchoolName, String system, String grade,
          String contentType) =>
      _db
          .collection('schools')
          .doc(normalizedSchoolName)
          .collection('systems')
          .doc(system)
          .collection('grades')
          .doc(grade)
          .collection(contentType);

  // ── classId-aware helpers (Format A only) ────────────────────────────────

  /// Returns the grade DocumentReference from a Format-A classId.
  /// Returns null if classId is invalid or pipe-format (no school embedded).
  static DocumentReference? getGradeFromClassId(String classId) {
    final (school, system, grade) = parseClassIdForFirestore(classId);
    if (school.isEmpty || system.isEmpty || grade.isEmpty) return null;
    return getGradeDoc(school, system, grade);
  }

  /// Returns the content CollectionReference from a Format-A classId.
  /// Returns null for pipe-format classIds — use getContentFromClassIdAndSchool.
  static CollectionReference? getContentFromClassId(
      String classId, String contentType) {
    final (school, system, grade) = parseClassIdForFirestore(classId);
    if (school.isEmpty || system.isEmpty || grade.isEmpty) return null;
    return getContentCollection(school, system, grade, contentType);
  }

  /// Returns the content CollectionReference, accepting EITHER classId format.
  /// schoolName is used only when classId is pipe-format (school not embedded).
  static CollectionReference? getContentFromClassIdAndSchool(
      String classId, String contentType, String schoolName) {
    final (school, system, grade) =
        parseClassIdWithSchool(classId, schoolName);
    if (school.isEmpty || system.isEmpty || grade.isEmpty) return null;
    return getContentCollection(school, system, grade, contentType);
  }

  /// Returns the submissions CollectionReference from a Format-A classId.
  static CollectionReference? getSubmissionsFromClassId(String classId) =>
      getContentFromClassId(classId, 'submissions');

  /// Returns the submissions CollectionReference, accepting EITHER classId format.
  static CollectionReference? getSubmissionsFromClassIdAndSchool(
      String classId, String schoolName) =>
      getContentFromClassIdAndSchool(classId, 'submissions', schoolName);

  // ── Firestore structure initialisation ───────────────────────────────────

  /// Ensures the school → system → grade document chain exists.
  /// Accepts either classId format when schoolName is also provided.
  static Future<void> ensureGradeExists(String classId,
      {String schoolName = ''}) async {
    final (school, system, grade) = schoolName.isNotEmpty
        ? parseClassIdWithSchool(classId, schoolName)
        : parseClassIdForFirestore(classId);

    if (school.isEmpty || system.isEmpty || grade.isEmpty) {
      throw Exception(
          'FirestoreHelper.ensureGradeExists: cannot parse classId "$classId"');
    }

    final schoolDoc = getSchoolDoc(school);
    if (!(await schoolDoc.get()).exists) {
      await schoolDoc.set({
        'name':           school.replaceAll('_', ' '),
        'normalizedName': school,
        'createdAt':      FieldValue.serverTimestamp(),
      });
    }

    final systemDoc = schoolDoc.collection('systems').doc(system);
    if (!(await systemDoc.get()).exists) {
      await systemDoc.set({
        'system':    system,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    final gradeDoc = systemDoc.collection('grades').doc(grade);
    if (!(await gradeDoc.get()).exists) {
      await gradeDoc.set({
        'grade':     grade,
        'classId':   classId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ── Streaming helpers ─────────────────────────────────────────────────────

  static Stream<QuerySnapshot> streamClassContent(
      String classId, String contentType) {
    final col = getContentFromClassId(classId, contentType);
    if (col == null) throw Exception('Invalid classId: $classId');
    return col.snapshots();
  }

  static Stream<QuerySnapshot> streamClassContentWithSchool(
      String classId, String contentType, String schoolName) {
    final col =
        getContentFromClassIdAndSchool(classId, contentType, schoolName);
    if (col == null) {
      throw Exception('Invalid classId: $classId (school: $schoolName)');
    }
    return col.snapshots();
  }

  // ── Write helpers ─────────────────────────────────────────────────────────

  static Future<DocumentReference> addContentToClass(
      String classId, String contentType, Map<String, dynamic> data,
      {String schoolName = ''}) async {
    await ensureGradeExists(classId, schoolName: schoolName);
    final col = schoolName.isNotEmpty
        ? getContentFromClassIdAndSchool(classId, contentType, schoolName)
        : getContentFromClassId(classId, contentType);
    if (col == null) throw Exception('Invalid classId: $classId');
    return col.add({...data, 'createdAt': FieldValue.serverTimestamp()});
  }

  // ── Analysis path helpers ─────────────────────────────────────────────────

  /// Path: schools/{school}/systems/{sys}/grades/{grade}/plot_analyses/{year}
  static DocumentReference? getPlotAnalysisDoc(
      String classId, String year, {String schoolName = ''}) {
    final (school, system, grade) = schoolName.isNotEmpty
        ? parseClassIdWithSchool(classId, schoolName)
        : parseClassIdForFirestore(classId);
    if (school.isEmpty || system.isEmpty || grade.isEmpty) return null;
    return getContentCollection(school, system, grade, 'plot_analyses').doc(year);
  }

  // ── Farmer (enterprise) path helpers ─────────────────────────────────────

  /// Path: farmer_plot_analyses/{uid}/seasons/{docKey}
  static DocumentReference farmerPlotAnalysisDoc(String uid, String docKey) =>
      _db
          .collection('farmer_plot_analyses')
          .doc(uid)
          .collection('seasons')
          .doc(docKey);

  /// Path: farmer_diagnoses/{uid}/records/{recordId}
  static CollectionReference farmerDiagnosisRecords(String uid) =>
      _db.collection('farmer_diagnoses').doc(uid).collection('records');

  /// Path: fielddata/{docId}  (root-level, farmer platform)
  static CollectionReference farmerFieldData() =>
      _db.collection('fielddata');

  /// Path: pestinterventiondata/{docId}
  static CollectionReference farmerPestData() =>
      _db.collection('pestinterventiondata');

  /// Path: diseaseinterventiondata/{docId}
  static CollectionReference farmerDiseaseData() =>
      _db.collection('diseaseinterventiondata');
}