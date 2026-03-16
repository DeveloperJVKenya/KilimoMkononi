// lib/education/farm_management/services/farm_management_service.dart
// ignore_for_file: unused_element

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FarmManagementService {
  final FirebaseFirestore _fs = FirebaseFirestore.instance;

  /// Normalize school name (spaces → underscores)
  String _normalizeSchool(String s) => s.trim().replaceAll(' ', '_');

  /// Fetch content of a specific type (labour, revenue, loan, etc.)
  Future<List<Map<String, dynamic>>> getContent({
    required String classId,
    required String schoolName,
    required String type,
  }) async {
    // PARSE FULL ID: Kianda_Schooljunior_7
    final match = RegExp(r'^(.*)_(\d+)$').firstMatch(classId);
    if (match == null) return [];

    final schoolId = match.group(1)!;
    final gradeId = match.group(2)!;

    try {
      final snap = await _fs
          .collection('schools')
          .doc(schoolId)
          .collection('grades')
          .doc(gradeId)  // Use SHORT gradeId
          .collection('farm_management_content')
          .where('type', isEqualTo: type)
          .orderBy('createdAt', descending: true)
          .get();

      return snap.docs.map((doc) {
        final data = doc.data();
        final raw = data['data'] as String?;
        return {
          ...data,
          'id': doc.id,
          'data': raw != null ? json.decode(raw) : null,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching $type: $e');
      return [];
    }
  }

  /// Save new content (cost, revenue, loan, etc.)
  Future<void> saveContent({
    required String classId,
    required String schoolName,
    required String type,
    required dynamic data,
    String? docId,  // Optional fixed docId for loans
  }) async {
    // PARSE FULL ID: Kianda_Schooljunior_7
    final match = RegExp(r'^(.*)_(\d+)$').firstMatch(classId);
    if (match == null) throw Exception('Invalid classId');

    final schoolId = match.group(1)!;
    final gradeId = match.group(2)!;

    final ref = _fs
        .collection('schools')
        .doc(schoolId)
        .collection('grades')
        .doc(gradeId)  // Use SHORT gradeId
        .collection('farm_management_content')
        .doc(docId);  // Use fixed docId if provided

    final batch = _fs.batch();

    batch.set(ref, {
      'contentType': 'farm_management_content',
      'type': type,
      'data': json.encode(data),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Increment counter for quiz/simulation
    if (type == 'quiz' || type == 'simulation') {
      final counterField = type == 'quiz' ? 'quizCount' : 'simulationCount';
      final gradeRef = _fs
          .collection('schools')
          .doc(schoolId)
          .collection('grades')
          .doc(gradeId);

      batch.update(gradeRef, {
        counterField: FieldValue.increment(1),
        'new${type[0].toUpperCase() + type.substring(1)}': true,
      });
    }

    try {
      await batch.commit();
    } catch (e) {
      debugPrint('Error saving $type: $e');
      rethrow;
    }
  }

  /// Update remaining loan balance after payment
  Future<void> updateLoanRemaining({
    required String classId,
    required String schoolName,
    required String docId,
    required double remaining,
  }) async {
    await saveContent(
      classId: classId,
      schoolName: schoolName,
      type: 'loan',
      docId: docId,
      data: {'remaining': remaining},
    );
  }
}