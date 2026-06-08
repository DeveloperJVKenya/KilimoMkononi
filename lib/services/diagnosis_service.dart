// lib/services/diagnosis_service.dart
//
// Handles:
//  1. Saving a diagnosis record to Firestore
//  2. Uploading a photo to Firebase Storage
//  3. Querying past records for the "similar cases" reference feature
//
// Firestore path: farmer_diagnoses/{userId}/records/{docId}

import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:kilimomkononi/models/farmer_diagnosis_record.dart';

class DiagnosisService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static FirebaseStorage get _storage => FirebaseStorage.instance;

  // ── CURRENT USER ──────────────────────────────────────────────────────────
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>>? get _collection {
    final uid = _uid;
    if (uid == null) return null;
    return _db
        .collection('farmer_diagnoses')
        .doc(uid)
        .collection('records');
  }

  // ── SAVE A NEW RECORD ─────────────────────────────────────────────────────
  static Future<String?> saveRecord(FarmerDiagnosisRecord record) async {
    final col = _collection;
    if (col == null) return null;

    final doc = await col.add({
      ...record.toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  // ── UPDATE INTERVENTION ON EXISTING RECORD ────────────────────────────────
  static Future<void> updateIntervention(
      String docId, String interventionText) async {
    await _collection?.doc(docId).update({
      'interventionText': interventionText,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── UPLOAD PHOTO TO FIREBASE STORAGE ─────────────────────────────────────
  // Returns {storagePath, downloadUrl}
  // Works on both mobile and web (bytes passed in).
  static Future<({String storagePath, String downloadUrl})>
      uploadPhoto(Uint8List bytes, String fileName) async {
    final uid = _uid ?? 'anonymous';
    final path =
        'ai_diagnoses/$uid/${DateTime.now().millisecondsSinceEpoch}_$fileName';

    final ref = _storage.ref(path);
    final metadata = SettableMetadata(contentType: 'image/jpeg');
    await ref.putData(bytes, metadata);
    final url = await ref.getDownloadURL();
    return (storagePath: path, downloadUrl: url);
  }

  // ── GET ALL PAST RECORDS FOR THIS FARMER ──────────────────────────────────
  static Future<List<FarmerDiagnosisRecord>> getAllRecords() async {
    final col = _collection;
    if (col == null) return [];

    final snap = await col
        .orderBy('createdAt', descending: true)
        .limit(200)
        .get();

    return snap.docs
        .map((d) => FarmerDiagnosisRecord.fromFirestore(d.data(), d.id))
        .toList();
  }

  // ── GET SIMILAR PAST CASES ────────────────────────────────────────────────
  // Called when farmer is on a new cycle with same crop + issue.
  // Matches by:
  //   - same cropName (required)
  //   - same selectedName OR same kindwiseTopName (option C from chatbot)
  static Future<List<FarmerDiagnosisRecord>> getSimilarCases({
    required String cropName,
    required String issueName,  // your internal label
    String? kindwiseName,       // API result name (may differ)
    String? excludeCycle,       // don't show current cycle's own record
  }) async {
    final col = _collection;
    if (col == null) return [];

    // Query 1: match by internal app label
    final q1 = await col
        .where('cropName', isEqualTo: cropName)
        .where('selectedName', isEqualTo: issueName)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();

    final results = <String, FarmerDiagnosisRecord>{};
    for (final d in q1.docs) {
      final rec = FarmerDiagnosisRecord.fromFirestore(d.data(), d.id);
      if (rec.cycle != excludeCycle) results[d.id] = rec;
    }

    // Query 2: match by kindwise name (if provided and different)
    if (kindwiseName != null && kindwiseName != issueName) {
      try {
        final q2 = await col
            .where('cropName', isEqualTo: cropName)
            .where('kindwiseTopName', isEqualTo: kindwiseName)
            .orderBy('createdAt', descending: true)
            .limit(10)
            .get();

        for (final d in q2.docs) {
          if (!results.containsKey(d.id)) {
            final rec = FarmerDiagnosisRecord.fromFirestore(d.data(), d.id);
            if (rec.cycle != excludeCycle) results[d.id] = rec;
          }
        }
      } catch (_) {
        // Index may not exist yet for kindwiseTopName — graceful fallback
      }
    }

    final list = results.values.toList()
      ..sort((a, b) =>
          (b.createdAt ?? DateTime(2000))
              .compareTo(a.createdAt ?? DateTime(2000)));
    return list;
  }

  // ── DELETE A RECORD ───────────────────────────────────────────────────────
  static Future<void> deleteRecord(String docId) async {
    await _collection?.doc(docId).delete();
  }
}