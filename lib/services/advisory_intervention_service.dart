// lib/services/advisory_intervention_service.dart
//
// Turns a farmer's "yes, do this" on an advisory (verified or AI) into a
// real intervention record in the right section — the SAME records the
// Field Data, Pest and Disease screens write, so it shows up there, in Plot
// history and in Season analysis without the farmer re-entering anything:
//
//   Soil     → appended to the plot's latest fielddata/{id}.interventions
//   Pest     → pestinterventiondata (as Pest Management's save)
//   Disease  → farmer_issues/{uid}/records + diseaseinterventiondata (as
//              Disease Management's save)
//
// Offline, each write falls back to OfflineQueueService like the screens do.
// What the farmer answered per item (found / not found / logged) is kept in
// advisoryResponses/{uid}_{advisoryId} so every device shows it.
//
// A farmer with no field record yet has nothing to attach an intervention
// to — [FarmContext.isEmpty]; the UI asks them to set up their farm first.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_actions.dart';
import 'package:kilimomkononi/enterprise/features/weather/agronomic_advisory.dart';
import 'package:kilimomkononi/models/farmer_issue_record.dart';
import 'package:kilimomkononi/models/pest_disease_model.dart';
import 'package:kilimomkononi/services/farmer_issue_service.dart';
import 'package:kilimomkononi/services/nutrient_levels.dart';
import 'package:kilimomkononi/services/offline_queue_service.dart';

/// One crop on one plot, from the plot's latest field record.
class FarmCrop {
  final String plotId;
  final String docId;
  final String crop;
  final String stage;

  /// The whole field record (used to write it back offline).
  final Map<String, dynamic> record;

  /// Measured N/P/K bands on this plot (only what was tested).
  final Map<String, NutrientBand> bands;
  final DateTime? measuredAt;

  const FarmCrop({
    required this.plotId,
    required this.docId,
    required this.crop,
    required this.stage,
    required this.record,
    required this.bands,
    this.measuredAt,
  });

  String get label => plotId == 'SingleCrop' || plotId == 'Intercrop'
      ? '$crop${stage.isEmpty ? '' : ' · $stage'}'
      : '$crop · $plotId${stage.isEmpty ? '' : ' · $stage'}';
}

/// The farmer's plots and crops, latest record per plot.
class FarmContext {
  final List<FarmCrop> crops;
  const FarmContext(this.crops);

  bool get isEmpty => crops.isEmpty;

  /// Crops an advisory for [advisoryCrops] applies to ('All crops' = all).
  List<FarmCrop> matching(List<String> advisoryCrops) {
    final all = advisoryCrops.isEmpty ||
        advisoryCrops.any((c) => c.trim().toLowerCase() == 'all crops');
    if (all) return crops;
    final want = advisoryCrops.map((c) => c.trim().toLowerCase()).toSet();
    final hit = crops.where((c) => want.contains(c.crop.toLowerCase())).toList();
    return hit;
  }

  /// One entry per plot (for soil actions, which are per plot).
  List<FarmCrop> get plots {
    final seen = <String>{};
    return crops.where((c) => seen.add(c.plotId)).toList();
  }
}

class AdvisoryInterventionService {
  AdvisoryInterventionService._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ── Farm context ──────────────────────────────────────────────────────────

  static Future<FarmContext> loadFarm() async {
    final uid = _uid;
    if (uid == null) return const FarmContext([]);
    final snap = await _db
        .collection('fielddata')
        .where('userId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .limit(30)
        .get();
    final latestPerPlot = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final d in snap.docs) {
      latestPerPlot.putIfAbsent('${d.data()['plotId'] ?? ''}', () => d);
    }
    final out = <FarmCrop>[];
    for (final d in latestPerPlot.values) {
      final data = d.data();
      final bands = bandsFromFieldData(data);
      for (final c in (data['crops'] as List?) ?? const []) {
        if (c is! Map) continue;
        final type = '${c['type'] ?? ''}'.trim();
        if (type.isEmpty) continue;
        out.add(FarmCrop(
          plotId: '${data['plotId'] ?? ''}',
          docId: d.id,
          crop: type,
          stage: '${c['stage'] ?? ''}'.trim(),
          record: data,
          bands: bands,
          measuredAt: fieldDataTime(data),
        ));
      }
    }
    return FarmContext(out);
  }

  // ── Responses (found / not found / logged) ────────────────────────────────

  static String responseKey(AdviceSection s, String name) => '${s.name}:$name';

  static DocumentReference<Map<String, dynamic>>? _responseRef(String advisoryId) {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('advisoryResponses').doc('${uid}_$advisoryId');
  }

  /// Item key → answer ('found', 'not_found', 'logged', 'logged:low' …).
  static Stream<Map<String, String>> responses(String advisoryId) {
    final ref = _responseRef(advisoryId);
    if (ref == null) return Stream.value(const {});
    return ref.snapshots().map((s) => {
          for (final e in ((s.data()?['items'] as Map?) ?? const {}).entries)
            '${e.key}': '${e.value}',
        });
  }

  static Future<void> setResponse(
    String advisoryId,
    String key,
    String value,
  ) async {
    final ref = _responseRef(advisoryId);
    if (ref == null) return;
    // Not awaited: Firestore keeps it offline and syncs it later.
    ref.set({
      'userId': _uid,
      'advisoryId': advisoryId,
      'items': {key: value},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).ignore();
  }

  // ── Logging ───────────────────────────────────────────────────────────────

  /// "50 kg/acre" → (50, 'kg/acre'); no number → (null, rate).
  static (double?, String) splitRate(String rate) {
    final m = RegExp(r'^\s*(\d+(?:\.\d+)?)\s*(.*)$').firstMatch(rate);
    if (m == null) return (null, rate.trim());
    return (double.tryParse(m.group(1)!), m.group(2)!.trim());
  }

  static String _sourceLabel(AgronomicAdvisory a) =>
      a.isAi ? 'AI advice' : 'Verified advice';

  /// Appends a soil / fertiliser intervention to [plot]'s field record.
  /// Returns true when saved online, false when queued offline.
  static Future<bool> logSoil({
    required AgronomicAdvisory advisory,
    required FarmCrop plot,
    required SoilAction action,
    required NutrientBand? band,
  }) async {
    final uid = _uid!;
    final chosen = action.forBand(band).isEmpty ? action.general : action.forBand(band);
    final (qty, unit) = splitRate(chosen.rate);
    final what = chosen.action.isNotEmpty
        ? chosen.action
        : (chosen.product.isNotEmpty ? 'Apply ${chosen.product}' : action.label);
    final entry = <String, dynamic>{
      'type': '${action.label}${band == null ? '' : ' (${band.label})'}: $what',
      'quantity': qty,
      'unit': unit,
      'date': Timestamp.now(),
      'costAmount': 0.0,
      'costCategory': 'Fertilizer',
      'saveToCosts': false,
      'farmPlotId': null,
      'enrichedDesc': [what, chosen.product, chosen.rate, chosen.method]
          .where((s) => s.isNotEmpty)
          .join(' · '),
      'source': 'advisory',
      'sourceLabel': _sourceLabel(advisory),
      'advisoryId': advisory.id,
      'nutrient': action.nutrient,
      'band': band?.name,
      'product': chosen.product,
      'rate': chosen.rate,
      'method': chosen.method,
      'loggedBy': uid,
    };
    var online = true;
    try {
      await _db.collection('fielddata').doc(plot.docId).update({
        'interventions': FieldValue.arrayUnion([entry]),
      });
    } catch (_) {
      online = false;
      // Offline: write the record back whole with the new entry (the queue
      // only does set()), same doc id so nothing is duplicated.
      final full = Map<String, dynamic>.from(plot.record);
      full['interventions'] = [
        ...((full['interventions'] as List?) ?? const []),
        entry,
      ];
      await OfflineQueueService.enqueue(
        id: 'fielddata_adv_${plot.docId}_${DateTime.now().millisecondsSinceEpoch}',
        collection: 'fielddata',
        docId: plot.docId,
        payload: full,
      );
    }
    setResponse(
      advisory.id,
      responseKey(AdviceSection.soil, '${action.nutrient}@${plot.plotId}'),
      'logged${band == null ? '' : ':${band.name}'}',
    );
    return online;
  }

  /// Logs a pest found on [crop] and the advised action.
  static Future<bool> logPest({
    required AgronomicAdvisory advisory,
    required FarmCrop crop,
    required CropCheck check,
  }) async {
    final uid = _uid!;
    final now = Timestamp.now();
    final (dose, unit) = splitRate(check.rate);
    final map = PestIntervention(
      plotId: crop.plotId,
      pestName: check.name,
      cropType: crop.crop,
      cropStage: crop.stage,
      cycle: 'A',
      intervention: check.interventionText,
      dosage: dose,
      unit: unit.isEmpty ? null : unit,
      areaUnit: 'Acres',
      timestamp: now,
      userId: uid,
      isDeleted: false,
    ).toMap()
      ..addAll({
        'source': 'advisory',
        'sourceLabel': _sourceLabel(advisory),
        'advisoryId': advisory.id,
      });
    var online = true;
    try {
      await _db.collection('pestinterventiondata').add(map);
    } catch (_) {
      online = false;
      await OfflineQueueService.enqueue(
        id: 'pest_adv_${uid}_${now.millisecondsSinceEpoch}',
        collection: 'pestinterventiondata',
        payload: map,
      );
    }
    setResponse(advisory.id, responseKey(AdviceSection.pests, check.name), 'logged');
    return online;
  }

  /// Logs a disease found on [crop] and the advised action.
  static Future<bool> logDisease({
    required AgronomicAdvisory advisory,
    required FarmCrop crop,
    required CropCheck check,
  }) async {
    final uid = _uid!;
    final now = Timestamp.now();
    final (dose, unit) = splitRate(check.rate);
    final record = FarmerIssueRecord(
      userId: uid,
      cycle: 'A',
      cropName: crop.crop,
      cropStage: crop.stage,
      issueType: 'disease',
      issueName: check.name,
      source: DiagnosisSource.manual,
      interventionText: check.interventionText,
      dosage: dose,
      dosageUnit: unit.isEmpty ? null : unit,
      aiRecommendation: advisory.isAi ? check.ifFound : null,
      timestamp: now,
    );
    final legacy = {
      'diseaseName': check.name,
      'cropType': crop.crop,
      'cropStage': crop.stage,
      'cycle': 'A',
      'intervention': check.interventionText,
      'dosage': dose,
      'unit': unit.isEmpty ? null : unit,
      'area': null,
      'areaUnit': 'Acres',
      'timestamp': now,
      'userId': uid,
      'isDeleted': false,
      'plotId': crop.plotId,
      'source': 'advisory',
      'sourceLabel': _sourceLabel(advisory),
      'advisoryId': advisory.id,
    };
    var online = true;
    try {
      await FarmerIssueService.saveRecord(record);
      await _db.collection('diseaseinterventiondata').add(legacy);
    } catch (_) {
      online = false;
      await OfflineQueueService.enqueue(
        id: 'disease_adv_${uid}_${now.millisecondsSinceEpoch}',
        collection: 'farmer_issues/$uid/records',
        payload: record.toMap(),
      );
      await OfflineQueueService.enqueue(
        id: 'disease_adv_legacy_${uid}_${now.millisecondsSinceEpoch}',
        collection: 'diseaseinterventiondata',
        payload: legacy,
      );
    }
    setResponse(advisory.id, responseKey(AdviceSection.diseases, check.name), 'logged');
    return online;
  }
}
