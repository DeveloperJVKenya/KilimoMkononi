import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kilimomkononi/screens/farm_mapping/models/farm_plot_model.dart';
import 'package:logger/logger.dart';

class FarmPlotService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _log = Logger(printer: PrettyPrinter());
  static const _col = 'farmPlots';

  String? get _uid => _auth.currentUser?.uid;

  // ── READ (live stream) ────────────────────────────────────────────────────

  Stream<List<FarmPlot>> userFarmsStream() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);
    return _firestore
        .collection(_col)
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .transform(StreamTransformer.fromHandlers(
          handleData: (snap, sink) {
            sink.add(snap.docs
                .map((d) => FarmPlot.fromFirestore(
                    d as DocumentSnapshot<Map<String, dynamic>>))
                .toList());
          },
          handleError: (Object e, StackTrace st, sink) {
            _log.e('FarmPlotService.userFarmsStream: $e', stackTrace: st);
            sink.add([]);
          },
        ));
  }

  // ── CREATE ────────────────────────────────────────────────────────────────

  Future<String?> saveFarm(FarmPlot farm) async {
    if (_uid == null) return null;
    try {
      final ref = await _firestore.collection(_col).add(farm.toFirestore());
      _log.i('FarmPlotService: saved "${farm.farmName}" → ${ref.id}');
      return ref.id;
    } catch (e, st) {
      _log.e('FarmPlotService.saveFarm: $e', stackTrace: st);
      rethrow;
    }
  }

  // ── UPDATE (full replace) ─────────────────────────────────────────────────

  Future<void> updateFarm(FarmPlot farm) async {
    if (farm.farmId == null) return;
    try {
      await _firestore
          .collection(_col)
          .doc(farm.farmId)
          .update(farm.copyWith(updatedAt: DateTime.now()).toFirestore());
    } catch (e, st) {
      _log.e('FarmPlotService.updateFarm: $e', stackTrace: st);
      rethrow;
    }
  }

  // ── UPDATE (rename only) ──────────────────────────────────────────────────

  Future<void> renameFarm(String farmId, String name) async {
    try {
      await _firestore.collection(_col).doc(farmId).update({
        'farmName': name.trim(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e, st) {
      _log.e('FarmPlotService.renameFarm: $e', stackTrace: st);
      rethrow;
    }
  }

  // ── UPDATE (sections only) ────────────────────────────────────────────────

  Future<void> saveSections(String farmId, List<FarmSection> sections) async {
    try {
      await _firestore.collection(_col).doc(farmId).update({
        'sections': sections.map((s) => s.toMap()).toList(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e, st) {
      _log.e('FarmPlotService.saveSections: $e', stackTrace: st);
      rethrow;
    }
  }

  // ── DELETE ────────────────────────────────────────────────────────────────

  Future<void> deleteFarm(String farmId) async {
    try {
      await _firestore.collection(_col).doc(farmId).delete();
      _log.i('FarmPlotService: deleted farm $farmId');
    } catch (e, st) {
      _log.e('FarmPlotService.deleteFarm: $e', stackTrace: st);
      rethrow;
    }
  }
}
