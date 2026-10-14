// lib/enterprise/features/agronomist/farmer_advice.dart
//
// Custom advice a Field Agronomist writes for ONE farmer from their records
// (Agronomist panel → a farmer → "Send advice"). Same content as a verified
// advisory — main action, DO / AVOID / WHY, and soil / pest / disease
// actions — so the farmer receives and acts on it exactly the same way
// (push → AdvisoryDetailScreen → log interventions).
//
// Firestore: farmer_advice/{id}
//   farmerUid, farmerName                     — who it is for (one farmer)
//   title, main, doList, avoidList, why       — the advice
//   crops                                     — the crops it is about
//   soilActions / pestChecks / diseaseChecks  — what the farmer acts on
//   basedOn: {kind, id, label}                — the record it answers, if any
//   batchId                                   — advice sent to several farmers
//                                               at once shares one
//   status: draft | sent | withdrawn          — the farmer only sees "sent"
//   version, created*/updated*/sent*, notifyVersion, testOnly, platform
// farmer_advice/{id}/history/v{version}      — immutable audit trail
//
// Pushed to the farmer by onFarmerAdviceSent (functions/agronomist.js).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_actions.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_conditions.dart';
import 'package:kilimomkononi/enterprise/features/weather/agronomic_advisory.dart';
import 'package:kilimomkononi/enterprise/features/weather/structured_advice.dart';

enum FarmerAdviceStatus {
  draft('Draft'),
  sent('Sent'),
  withdrawn('Withdrawn');

  final String label;
  const FarmerAdviceStatus(this.label);

  static FarmerAdviceStatus from(String? s) =>
      values.firstWhere((v) => v.name == s, orElse: () => FarmerAdviceStatus.draft);
}

DateTime? _date(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is num && v > 0) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
  return null;
}

List<String> _strings(dynamic v) =>
    (v as List?)?.map((e) => e.toString()).toList() ?? const [];

/// The record a piece of advice answers (a pest report, a soil test …).
class AdviceBasis {
  /// 'pest' | 'disease' | 'soil' | 'insight'
  final String kind;
  final String? id;
  final String label;

  const AdviceBasis({required this.kind, this.id, required this.label});

  Map<String, dynamic> toMap() => {'kind': kind, 'id': id, 'label': label};

  static AdviceBasis? fromMap(dynamic m) {
    if (m is! Map) return null;
    final label = '${m['label'] ?? ''}'.trim();
    if (label.isEmpty) return null;
    return AdviceBasis(kind: '${m['kind'] ?? 'insight'}', id: m['id'] as String?, label: label);
  }
}

class FarmerAdvice {
  final String id;
  final String farmerUid;
  final String farmerName;
  final String title;
  final StructuredAdvice advice;
  final List<String> crops;
  final AdviceActions actions;
  final AdviceBasis? basedOn;
  final String? batchId;
  final FarmerAdviceStatus status;
  final int version;
  final String createdByName;
  final DateTime? createdAt;
  final String updatedByName;
  final DateTime? updatedAt;
  final String? sentBy;
  final String? sentByName;
  final DateTime? sentAt;
  final bool testOnly;

  const FarmerAdvice({
    required this.id,
    required this.farmerUid,
    this.farmerName = '',
    this.title = '',
    required this.advice,
    this.crops = const [],
    this.actions = AdviceActions.empty,
    this.basedOn,
    this.batchId,
    this.status = FarmerAdviceStatus.draft,
    this.version = 1,
    this.createdByName = '',
    this.createdAt,
    this.updatedByName = '',
    this.updatedAt,
    this.sentBy,
    this.sentByName,
    this.sentAt,
    this.testOnly = false,
  });

  bool get wasEverSent => sentAt != null;

  factory FarmerAdvice.fromMap(Map<String, dynamic> d, [String? id]) => FarmerAdvice(
        id: id ?? '${d['id'] ?? ''}',
        farmerUid: '${d['farmerUid'] ?? ''}',
        farmerName: '${d['farmerName'] ?? ''}',
        title: '${d['title'] ?? ''}',
        advice: StructuredAdvice(
          main: '${d['main'] ?? ''}',
          doList: _strings(d['doList']),
          avoidList: _strings(d['avoidList']),
          why: '${d['why'] ?? ''}',
        ),
        crops: _strings(d['crops']),
        actions: AdviceActions.fromDoc(d),
        basedOn: AdviceBasis.fromMap(d['basedOn']),
        batchId: d['batchId'] as String?,
        status: FarmerAdviceStatus.from(d['status'] as String?),
        version: (d['version'] as num?)?.toInt() ?? 1,
        createdByName: '${d['createdByName'] ?? ''}',
        createdAt: _date(d['createdAt']),
        updatedByName: '${d['updatedByName'] ?? ''}',
        updatedAt: _date(d['updatedAt']),
        sentBy: d['sentBy'] as String?,
        sentByName: d['sentByName'] as String?,
        sentAt: _date(d['sentAt']),
        testOnly: d['testOnly'] == true,
      );

  factory FarmerAdvice.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      FarmerAdvice.fromMap(doc.data() ?? const {}, doc.id);

  /// As the farmer sees it — the same model, screens and logging as verified
  /// advice, marked as written for them.
  AgronomicAdvisory toAdvisory() => AgronomicAdvisory(
        id: id,
        title: title,
        advice: advice,
        crops: crops.isEmpty ? const [kAllCrops] : crops,
        condition: 'general',
        status: AdvisoryStatus.published,
        version: version,
        createdByName: createdByName,
        createdAt: createdAt,
        updatedByName: updatedByName,
        updatedAt: updatedAt,
        publishedByName: sentByName,
        publishedAt: sentAt,
        testOnly: testOnly,
        actions: actions,
        isDirect: true,
      );

  FarmerAdviceContent get content => FarmerAdviceContent(
        farmerUid: farmerUid,
        farmerName: farmerName,
        title: title,
        advice: advice,
        crops: crops,
        actions: actions,
        basedOn: basedOn,
        batchId: batchId,
        testOnly: testOnly,
      );
}

/// What an agronomist edits.
class FarmerAdviceContent {
  final String farmerUid;
  final String farmerName;
  final String title;
  final StructuredAdvice advice;
  final List<String> crops;
  final AdviceActions actions;
  final AdviceBasis? basedOn;
  final String? batchId;
  final bool testOnly;

  const FarmerAdviceContent({
    required this.farmerUid,
    this.farmerName = '',
    this.title = '',
    required this.advice,
    this.crops = const [],
    this.actions = AdviceActions.empty,
    this.basedOn,
    this.batchId,
    this.testOnly = false,
  });

  FarmerAdviceContent forFarmer(String uid, String name) => FarmerAdviceContent(
        farmerUid: uid,
        farmerName: name,
        title: title,
        advice: advice,
        crops: crops,
        actions: actions,
        basedOn: basedOn,
        batchId: batchId,
        testOnly: testOnly,
      );

  Map<String, dynamic> toMap() => {
        'farmerUid': farmerUid,
        'farmerName': farmerName.trim(),
        'title': title.trim(),
        'main': advice.main.trim(),
        'doList': advice.doList,
        'avoidList': advice.avoidList,
        'why': advice.why.trim(),
        'crops': crops,
        'basedOn': basedOn?.toMap(),
        'batchId': batchId,
        'testOnly': testOnly,
        ...actions.toMap(),
      };
}
