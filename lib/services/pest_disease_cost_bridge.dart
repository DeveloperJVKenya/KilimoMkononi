// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PestCostEntry
// ─────────────────────────────────────────────────────────────────────────────

class PestCostEntry {
  final String id;
  final String userId;
  final String plotId;
  final String description;
  final String category;
  final double amount;
  final DateTime date;
  final String source;
  final String? pestName;
  final String? interventionType;

  PestCostEntry({
    required this.id,
    required this.userId,
    required this.plotId,
    required this.description,
    required this.category,
    required this.amount,
    required this.date,
    this.source = 'pest_management',
    this.pestName,
    this.interventionType,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'plotId': plotId,
        'description': description,
        'category': category,
        'amount': amount,
        'date': Timestamp.fromDate(date),
        'source': source,
        'pestName': pestName,
        'interventionType': interventionType,
      };

  factory PestCostEntry.fromMap(Map<String, dynamic> m) => PestCostEntry(
        id: m['id'] as String? ?? '',
        userId: m['userId'] as String? ?? '',
        plotId: m['plotId'] as String? ?? '',
        description: m['description'] as String? ?? '',
        category: m['category'] as String? ?? 'Miscellaneous',
        amount: (m['amount'] as num?)?.toDouble() ?? 0.0,
        date: (m['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
        source: m['source'] as String? ?? 'pest_management',
        pestName: m['pestName'] as String?,
        interventionType: m['interventionType'] as String?,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// DiseaseCostEntry
// ─────────────────────────────────────────────────────────────────────────────

class DiseaseCostEntry {
  final String id;
  final String userId;
  final String plotId;
  final String description;
  final String category;
  final double amount;
  final DateTime date;
  final String source;
  final String? diseaseName;
  final String? interventionType;

  DiseaseCostEntry({
    required this.id,
    required this.userId,
    required this.plotId,
    required this.description,
    required this.category,
    required this.amount,
    required this.date,
    this.source = 'disease_management',
    this.diseaseName,
    this.interventionType,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'plotId': plotId,
        'description': description,
        'category': category,
        'amount': amount,
        'date': Timestamp.fromDate(date),
        'source': source,
        'diseaseName': diseaseName,
        'interventionType': interventionType,
      };

  factory DiseaseCostEntry.fromMap(Map<String, dynamic> m) => DiseaseCostEntry(
        id: m['id'] as String? ?? '',
        userId: m['userId'] as String? ?? '',
        plotId: m['plotId'] as String? ?? '',
        description: m['description'] as String? ?? '',
        category: m['category'] as String? ?? 'Miscellaneous',
        amount: (m['amount'] as num?)?.toDouble() ?? 0.0,
        date: (m['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
        source: m['source'] as String? ?? 'disease_management',
        diseaseName: m['diseaseName'] as String?,
        interventionType: m['interventionType'] as String?,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared robust plot loader (SharedPreferences + Firestore fallback)
// ─────────────────────────────────────────────────────────────────────────────

Future<List<Map<String, String>>> _loadFarmPlots(String userId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final key = '${userId}_v2_plots';
    final raw = prefs.getString(key);

    if (raw != null && raw.isNotEmpty) {
      final list = jsonDecode(raw) as List<dynamic>;
      final plots = _parsePlots(list);
      if (plots.isNotEmpty) {
        print('✅ Loaded ${plots.length} plots from SharedPreferences');
        return plots;
      }
    }

    // Firestore fallback
    print('⚠️ Trying Firestore fallback...');
    final seasonDoc = await FirebaseFirestore.instance
        .collection('farmer_farm_management')
        .doc(userId)
        .collection('seasons')
        .doc('Long Rains 2025')           // ← Change if your season name differs
        .get();

    if (seasonDoc.exists) {
      final data = seasonDoc.data();
      final list = data?['plots'] as List<dynamic>? ?? [];
      final plots = _parsePlots(list);
      print('✅ Loaded ${plots.length} plots from Firestore fallback');
      return plots;
    }
  } catch (e) {
    print('❌ Error loading plots: $e');
  }
  return [];
}

List<Map<String, String>> _parsePlots(List<dynamic> list) {
  return list
      .map((e) {
        final map = e as Map<String, dynamic>;
        return {
          'id': (map['id'] as String?)?.trim() ?? '',
          'name': (map['name'] as String?)?.trim() ?? '',
        };
      })
      .where((m) => m['id']!.isNotEmpty && m['name']!.isNotEmpty)
      .toList();
}

// ─────────────────────────────────────────────────────────────────────────────
// Auto-category inference (used by both Pest & Disease)
// ─────────────────────────────────────────────────────────────────────────────

String inferPestDiseaseCostCategory(String desc) {
  final d = desc.toLowerCase();
  if (d.contains('spray') || d.contains('pesticide') || d.contains('fungicide') ||
      d.contains('insecticide') || d.contains('chemical') || d.contains('ridomil') ||
      d.contains('dithane') || d.contains('mancozeb') || d.contains('karate')) {
    return 'Pesticide / Herbicide';
  }
  if (d.contains('labour') || d.contains('worker') || d.contains('hired')) {
    return 'Labour';
  }
  if (d.contains('seed') || d.contains('seedling')) {
    return 'Seeds & Planting Material';
  }
  return 'Miscellaneous';
}

// ─────────────────────────────────────────────────────────────────────────────
// PestCostService
// ─────────────────────────────────────────────────────────────────────────────

class PestCostService {
  static final _db = FirebaseFirestore.instance;
  static const _collection = 'pest_costs';

  static String get _uid => FirebaseAuth.instance.currentUser!.uid;

  static Future<void> saveFromPest(PestCostEntry entry) async {
    await _db.collection(_collection).doc(entry.id).set(entry.toMap());
  }

  static Stream<List<PestCostEntry>> streamForUser() {
    return _db
        .collection(_collection)
        .where('userId', isEqualTo: _uid)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => PestCostEntry.fromMap(d.data())).toList());
  }

  static Future<void> delete(String id) async {
    await _db.collection(_collection).doc(id).delete();
  }

  static Future<List<Map<String, String>>> loadFarmPlots(String userId) async {
    return _loadFarmPlots(userId);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DiseaseCostService
// ─────────────────────────────────────────────────────────────────────────────

class DiseaseCostService {
  static final _db = FirebaseFirestore.instance;
  static const _collection = 'disease_costs';

  static String get _uid => FirebaseAuth.instance.currentUser!.uid;

  static Future<void> saveFromDisease(DiseaseCostEntry entry) async {
    await _db.collection(_collection).doc(entry.id).set(entry.toMap());
  }

  static Stream<List<DiseaseCostEntry>> streamForUser() {
    return _db
        .collection(_collection)
        .where('userId', isEqualTo: _uid)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => DiseaseCostEntry.fromMap(d.data())).toList());
  }

  static Future<void> delete(String id) async {
    await _db.collection(_collection).doc(id).delete();
  }

  static Future<List<Map<String, String>>> loadFarmPlots(String userId) async {
    return _loadFarmPlots(userId);
  }
}