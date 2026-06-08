// lib/services/farmer_issue_service.dart
//
// UNIFIED service for all farmer pest/disease records.
//
// NEW collection:  farmer_issues/{userId}/records/{docId}
// OLD collections: pestinterventiondata, diseaseinterventiondata,
//                  farmer_diagnoses/{userId}/records
//
// This service:
//   • Writes ALL new records to farmer_issues/{userId}/records
//   • Reads from ALL four sources and merges for display
//   • Never deletes old records — they remain in old collections
//     and are shown in unified history via the adapter factories

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kilimomkononi/models/farmer_issue_record.dart';

class FarmerIssueService {
  static FirebaseFirestore get _db  => FirebaseFirestore.instance;
  static String?           get _uid => FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>>? get _newCol {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('farmer_issues').doc(uid).collection('records');
  }

  // ── SAVE (always to new unified collection) ───────────────────────────────
  static Future<String?> saveRecord(FarmerIssueRecord record) async {
    final col = _newCol;
    if (col == null) return null;
    final doc = await col.add(record.toMap());
    return doc.id;
  }

  // ── UPDATE intervention text on a record ──────────────────────────────────
  static Future<void> updateIntervention(String docId, String text) async {
    await _newCol?.doc(docId).update({'interventionText': text});
  }

  // ── SOFT DELETE ───────────────────────────────────────────────────────────
  static Future<void> softDelete(String docId) async {
    await _newCol?.doc(docId).update({'isDeleted': true});
  }

  // ── STREAM — unified live history for this user ───────────────────────────
  // Combines new unified collection + old collections for display.
  // Use this for the unified history page StreamBuilder.
  static Stream<List<FarmerIssueRecord>> streamAll({
    String? cropName,
    String? cycle,
    String? issueType,
  }) {
    final uid = _uid;
    if (uid == null) return Stream.value([]);

    // Stream from new unified collection only — old data loaded separately
    Query<Map<String, dynamic>> q = _db
        .collection('farmer_issues')
        .doc(uid)
        .collection('records')
        .where('isDeleted', isEqualTo: false);

    if (cropName  != null) q = q.where('cropName',  isEqualTo: cropName);
    if (cycle     != null) q = q.where('cycle',     isEqualTo: cycle);
    if (issueType != null) q = q.where('issueType', isEqualTo: issueType);

    return q
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => FarmerIssueRecord.fromMap(d.data(), d.id))
            .toList());
  }

  // ── FETCH ALL — merges new + old collections ──────────────────────────────
  // Called once on history page load to populate a combined list
  // including legacy records from the old separate collections.
  static Future<List<FarmerIssueRecord>> fetchAll({
    String? cropName,
    String? cycle,
  }) async {
    final uid = _uid;
    if (uid == null) return [];

    final results = <String, FarmerIssueRecord>{};

    // 1. New unified collection
    try {
      Query<Map<String, dynamic>> q = _db
          .collection('farmer_issues')
          .doc(uid)
          .collection('records')
          .where('isDeleted', isEqualTo: false);
      if (cropName != null) q = q.where('cropName', isEqualTo: cropName);
      if (cycle    != null) q = q.where('cycle',    isEqualTo: cycle);
      final snap = await q.orderBy('timestamp', descending: true).get();
      for (final d in snap.docs) {
        results['new_${d.id}'] = FarmerIssueRecord.fromMap(d.data(), d.id);
      }
    } catch (_) {}

    // 2. Old pestinterventiondata
    try {
      Query<Map<String, dynamic>> q = _db
          .collection('pestinterventiondata')
          .where('userId',    isEqualTo: uid)
          .where('isDeleted', isEqualTo: false);
      if (cropName != null) q = q.where('cropType', isEqualTo: cropName);
      if (cycle    != null) q = q.where('cycle',    isEqualTo: cycle);
      final snap = await q.orderBy('timestamp', descending: true).get();
      for (final d in snap.docs) {
        results['pest_${d.id}'] =
            FarmerIssueRecord.fromOldPest(d.data(), d.id);
      }
    } catch (_) {}

    // 3. Old diseaseinterventiondata
    try {
      Query<Map<String, dynamic>> q = _db
          .collection('diseaseinterventiondata')
          .where('userId',    isEqualTo: uid)
          .where('isDeleted', isEqualTo: false);
      if (cropName != null) q = q.where('cropType', isEqualTo: cropName);
      if (cycle    != null) q = q.where('cycle',    isEqualTo: cycle);
      final snap = await q.orderBy('timestamp', descending: true).get();
      for (final d in snap.docs) {
        results['disease_${d.id}'] =
            FarmerIssueRecord.fromOldDisease(d.data(), d.id);
      }
    } catch (_) {}

    // 4. Old farmer_diagnoses AI records
    try {
      final snap = await _db
          .collection('farmer_diagnoses')
          .doc(uid)
          .collection('records')
          .orderBy('createdAt', descending: true)
          .get();
      for (final d in snap.docs) {
        results['ai_${d.id}'] =
            FarmerIssueRecord.fromOldAiRecord(d.data(), d.id);
      }
    } catch (_) {}

    // Sort all by timestamp descending
    final list = results.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  // ── SIMILAR CASES — for past-cases reference panel ────────────────────────
  static Future<List<FarmerIssueRecord>> getSimilarCases({
    required String cropName,
    required String issueName,
    String? excludeDocId,
  }) async {
    final uid = _uid;
    if (uid == null) return [];

    final results = <String, FarmerIssueRecord>{};

    // New collection
    try {
      final snap = await _db
          .collection('farmer_issues')
          .doc(uid)
          .collection('records')
          .where('cropName',  isEqualTo: cropName)
          .where('issueName', isEqualTo: issueName)
          .where('isDeleted', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();
      for (final d in snap.docs) {
        if (d.id != excludeDocId) {
          results['new_${d.id}'] = FarmerIssueRecord.fromMap(d.data(), d.id);
        }
      }
    } catch (_) {}

    // Old pest collection
    try {
      final snap = await _db
          .collection('pestinterventiondata')
          .where('userId',    isEqualTo: uid)
          .where('cropType',  isEqualTo: cropName)
          .where('pestName',  isEqualTo: issueName)
          .where('isDeleted', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();
      for (final d in snap.docs) {
        results['pest_${d.id}'] =
            FarmerIssueRecord.fromOldPest(d.data(), d.id);
      }
    } catch (_) {}

    // Old disease collection
    try {
      final snap = await _db
          .collection('diseaseinterventiondata')
          .where('userId',      isEqualTo: uid)
          .where('cropType',    isEqualTo: cropName)
          .where('diseaseName', isEqualTo: issueName)
          .where('isDeleted',   isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();
      for (final d in snap.docs) {
        results['disease_${d.id}'] =
            FarmerIssueRecord.fromOldDisease(d.data(), d.id);
      }
    } catch (_) {}

    final list = results.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }
}