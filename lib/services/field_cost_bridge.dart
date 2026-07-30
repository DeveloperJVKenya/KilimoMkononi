import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/foundation.dart';
// ─────────────────────────────────────────────────────────────────────────────
// FieldCostEntry — written by field data input, displayed in farm management
// ─────────────────────────────────────────────────────────────────────────────

class FieldCostEntry {
  final String id;
  final String userId;
  final String plotId;       // matches fielddata plotId
  final String description;  // e.g. "Applied CAN fertiliser"
  final String category;     // maps to FarmManagement _kExpenseCategories
  final double amount;       // KES
  final DateTime date;
  final String source;       // always 'field_data'
  final String? interventionType; // e.g. "Chemical", "Labour"

  FieldCostEntry({
    required this.id,
    required this.userId,
    required this.plotId,
    required this.description,
    required this.category,
    required this.amount,
    required this.date,
    this.source = 'field_data',
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
        'interventionType': interventionType,
      };

  factory FieldCostEntry.fromMap(Map<String, dynamic> m) => FieldCostEntry(
        id: m['id'] as String? ?? '',
        userId: m['userId'] as String? ?? '',
        plotId: m['plotId'] as String? ?? '',
        description: m['description'] as String? ?? '',
        category: m['category'] as String? ?? 'Miscellaneous',
        amount: (m['amount'] as num?)?.toDouble() ?? 0.0,
        date: (m['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
        source: m['source'] as String? ?? 'field_data',
        interventionType: m['interventionType'] as String?,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Auto-category inference from intervention description
// ─────────────────────────────────────────────────────────────────────────────

String inferCostCategory(String interventionDesc) {
  final d = interventionDesc.toLowerCase();
  if (_matches(d, ['fertiliser', 'fertilizer', 'npk', 'dap', 'can', 'urea',
      'mavuno', 'top dress', 'topdress', 'basal'])) {
    return 'Fertilizer';
  }
  if (_matches(d, ['spray', 'pesticide', 'herbicide', 'fungicide', 'insecticide',
      'chemical', 'roundup', 'dithane', 'ridomil', 'karate'])) {
    return 'Pesticide / Herbicide';
  }
  if (_matches(d, ['labour', 'labor', 'worker', 'hired', 'weeding', 'casual'])) {
    return 'Labour';
  }
  if (_matches(d, ['seed', 'seedling', 'cutting', 'transplant'])) {
    return 'Seeds & Planting Material';
  }
  if (_matches(d, ['irrigation', 'water', 'drip', 'furrow'])) {
    return 'Irrigation';
  }
  if (_matches(d, ['transport', 'delivery', 'truck', 'lorry', 'tractor'])) {
    return 'Transport';
  }
  if (_matches(d, ['equipment', 'hire', 'plough', 'tractor hire', 'machine'])) {
    return 'Equipment Hire';
  }
  return 'Miscellaneous';
}

bool _matches(String text, List<String> keywords) =>
    keywords.any((k) => text.contains(k));

// ─────────────────────────────────────────────────────────────────────────────
// FieldCostService — thin Firestore wrapper used by both screens
// ─────────────────────────────────────────────────────────────────────────────

class FieldCostService {
  static final _db = FirebaseFirestore.instance;
  static const _collection = 'field_costs';

  static String get _uid => FirebaseAuth.instance.currentUser!.uid;

  /// Save a cost entry created from field data input.
  static Future<void> saveFromFieldData(FieldCostEntry entry) async {
    await _db.collection(_collection).doc(entry.id).set(entry.toMap());
  }

  /// Stream all cost entries for this user (used by farm management).
  static Stream<List<FieldCostEntry>> streamForUser() {
    return _db
        .collection(_collection)
        .where('userId', isEqualTo: _uid)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => FieldCostEntry.fromMap(d.data())).toList());
  }

  /// Delete a cost entry (farm management delete or field data edit).
  static Future<void> delete(String id) async {
    await _db.collection(_collection).doc(id).delete();
  }

  /// Fetch once — used by farm management to merge into expense list on load.
  static Future<List<FieldCostEntry>> fetchForUser() async {
    final snap = await _db
        .collection(_collection)
        .where('userId', isEqualTo: _uid)
        .orderBy('date', descending: true)
        .get();
    return snap.docs.map((d) => FieldCostEntry.fromMap(d.data())).toList();
  }

      /// Load farm management plots — tries SharedPreferences first, then Firestore fallback
  static Future<List<Map<String, String>>> loadFarmPlots(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${userId}_v2_plots';
      final raw = prefs.getString(key);

      debugPrint('🔍 Trying SharedPreferences key: $key');

      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        final plots = _parsePlots(list);
        if (plots.isNotEmpty) {
          debugPrint('✅ Loaded ${plots.length} plots from SharedPreferences');
          return plots;
        }
      }

      // Fallback: Load from Firestore season document
      debugPrint('⚠️ No plots in SharedPreferences → Trying Firestore fallback');
      
      final seasonDoc = await FirebaseFirestore.instance
          .collection('farmer_farm_management')
          .doc(userId)
          .collection('seasons')
          .doc('Long Rains 2025')           // Change if you use different season names
          .get();

      if (seasonDoc.exists) {
        final data = seasonDoc.data();
        final list = data?['plots'] as List<dynamic>? ?? [];
        final plots = _parsePlots(list);
        
        debugPrint('✅ Loaded ${plots.length} plots from Firestore fallback');
        return plots;
      }

      debugPrint('⚠️ No plots found in Firestore either');
      return [];
    } catch (e) {
      debugPrint('❌ Error loading farm plots: $e');
      return [];
    }
  }

  // Helper to parse both sources
  static List<Map<String, String>> _parsePlots(List<dynamic> list) {
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
  }}