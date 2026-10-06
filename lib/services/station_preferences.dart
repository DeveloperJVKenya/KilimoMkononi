// lib/services/station_preferences.dart
//
// Which of the account's weather stations each of its farms / plots uses —
// the farmer's own choice, made on the Weather Station screen. The admin
// only connects stations to the account (Admin panel → Weather Stations);
// linking them to farms is up to the farmer, and synced across devices:
//
//   stationPreferences/{uid}  { userId, plots: { plotId: gatewayId }, updatedAt }
//
// It never grants access — stationAssignments does (server-side); a choice
// pointing at a station the account no longer has is simply ignored.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class StationPreferences {
  StationPreferences._();

  // Per account, so another account on the same phone never sees them.
  static final Map<String, Map<String, String>> _cache = {};

  static String? get _uid {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  static DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      FirebaseFirestore.instance.collection('stationPreferences').doc(uid);

  /// plotId → gatewayId chosen by the signed-in account ({} if none / offline).
  static Future<Map<String, String>> load({bool refresh = false}) async {
    final uid = _uid;
    if (uid == null) return const {};
    if (!refresh && _cache.containsKey(uid)) return _cache[uid]!;
    try {
      final d = await _doc(uid).get();
      final plots = {
        for (final e in ((d.data()?['plots'] as Map?) ?? const {}).entries)
          if (e.value is String) '${e.key}': e.value as String,
      };
      _cache[uid] = plots;
      return plots;
    } catch (e) {
      debugPrint('[StationPreferences] load: $e');
      return _cache[uid] ?? const {};
    }
  }

  /// Uses [gatewayId] for the farm / plot [plotId] (null clears the choice).
  static Future<void> setForPlot(String plotId, String? gatewayId) async {
    final uid = _uid;
    if (uid == null) return;
    final next = {...(_cache[uid] ?? await load())};
    gatewayId == null ? next.remove(plotId) : next[plotId] = gatewayId;
    _cache[uid] = next;
    await _doc(uid).set({
      'userId': uid,
      'plots': {plotId: gatewayId ?? FieldValue.delete()},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @visibleForTesting
  static void clearCache() => _cache.clear();
}
