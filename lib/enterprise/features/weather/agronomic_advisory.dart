// lib/enterprise/features/weather/agronomic_advisory.dart
//
// A weather-and-crop advisory written or verified by a Field Agronomist.
//
// Firestore: agronomic_advisories/{id}
//   title, main, doList, avoidList, why      — the advice (StructuredAdvice)
//   crops: [..] ('All crops' allowed)        — who it's for
//   condition: key from kAdvisoryConditions  — when it's shown
//   customCondition: {label, ranges}         — when condition == 'custom'
//                                              (advisory_conditions.dart)
//   gatewayId / stationName                  — null = all stations
//   platform: 'km'
//   status: draft | published | archived     — farmers only ever see published
//   source: manual | ai_assisted, aiDraft    — original AI text kept for audit
//   version, created*/updated*/published*    — who did what, when
//   testOnly                                 — created by an admin in test
//                                              mode; never shown to farmers
//   soilActions / pestChecks / diseaseChecks — what farmers act on, filed
//                                              under Soil / Pests / Diseases
//                                              (advisory_actions.dart)
//
// agronomic_advisories/{id}/history/v{version} — immutable audit trail; one
// entry per version, enforced by firestore.rules.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_actions.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_conditions.dart';
import 'package:kilimomkononi/enterprise/features/weather/structured_advice.dart';
import 'package:kilimomkononi/services/nuasense_service.dart';

enum AdvisoryStatus { draft, published, archived }

AdvisoryStatus _statusFrom(String? s) => AdvisoryStatus.values.firstWhere(
  (v) => v.name == s,
  orElse: () => AdvisoryStatus.draft,
);

DateTime? _date(dynamic v) => v is Timestamp ? v.toDate() : null;

List<String> _strings(dynamic v) =>
    (v as List?)?.map((e) => e.toString()).toList() ?? const [];

class AgronomicAdvisory {
  final String id;
  final String title;
  final StructuredAdvice advice;
  final List<String> crops;
  final String condition;

  /// The agronomist's own condition, when [condition] is 'custom'.
  final CustomCondition? customCondition;
  final String? gatewayId;
  final String? stationName;
  final AdvisoryStatus status;
  final String source;
  final String? aiDraft;
  final int version;
  final String createdByName;
  final DateTime? createdAt;
  final String updatedByName;
  final DateTime? updatedAt;
  final String? publishedByName;
  final DateTime? publishedAt;
  final bool testOnly;
  final AdviceActions actions;

  /// Built from the AI advisor (not verified, never stored as an advisory).
  final bool isAi;

  const AgronomicAdvisory({
    required this.id,
    required this.title,
    required this.advice,
    required this.crops,
    required this.condition,
    this.customCondition,
    this.gatewayId,
    this.stationName,
    required this.status,
    this.source = 'manual',
    this.aiDraft,
    required this.version,
    this.createdByName = '',
    this.createdAt,
    this.updatedByName = '',
    this.updatedAt,
    this.publishedByName,
    this.publishedAt,
    this.testOnly = false,
    this.actions = AdviceActions.empty,
    this.isAi = false,
  });

  Set<AdviceSection> get sections => actions.sections;

  bool get isStationScoped => gatewayId != null && gatewayId!.isNotEmpty;

  bool get isCustomCondition => condition == kCustomCondition;

  /// What farmers see as the condition ("Very humid", or the typed name).
  String get conditionLabel => isCustomCondition
      ? (customCondition?.label ?? 'Custom condition')
      : conditionFor(condition).label;

  /// Does this advice's condition hold for [reading] (given the reading's
  /// [activeKeys])? Typed conditions check their own ranges.
  bool appliesTo(Set<String> activeKeys, NuaSenseReading? reading) =>
      isCustomCondition
          ? (customCondition ?? const CustomCondition(label: '')).appliesTo(reading)
          : activeKeys.contains(condition);
  bool get wasEverPublished => publishedAt != null;

  factory AgronomicAdvisory.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return AgronomicAdvisory(
      id: doc.id,
      title: (d['title'] as String?) ?? '',
      advice: StructuredAdvice(
        main: (d['main'] as String?) ?? '',
        doList: _strings(d['doList']),
        avoidList: _strings(d['avoidList']),
        why: (d['why'] as String?) ?? '',
      ),
      crops: _strings(d['crops']),
      condition: (d['condition'] as String?) ?? 'general',
      customCondition: CustomCondition.fromMap(d['customCondition']),
      gatewayId: d['gatewayId'] as String?,
      stationName: d['stationName'] as String?,
      status: _statusFrom(d['status'] as String?),
      source: (d['source'] as String?) ?? 'manual',
      aiDraft: d['aiDraft'] as String?,
      version: (d['version'] as num?)?.toInt() ?? 1,
      createdByName: (d['createdByName'] as String?) ?? '',
      createdAt: _date(d['createdAt']),
      updatedByName: (d['updatedByName'] as String?) ?? '',
      updatedAt: _date(d['updatedAt']),
      publishedByName: d['publishedByName'] as String?,
      publishedAt: _date(d['publishedAt']),
      testOnly: d['testOnly'] == true,
      actions: AdviceActions.fromDoc(d),
    );
  }

  /// Today's AI advice as an advisory-shaped object, so the action screen
  /// treats it like verified advice (clearly labelled as AI).
  factory AgronomicAdvisory.fromAi({
    required String id,
    required StructuredAdvice advice,
    required List<String> crops,
    required String condition,
    String? gatewayId,
  }) => AgronomicAdvisory(
    id: id,
    title: 'AI advice',
    advice: advice,
    crops: crops.isEmpty ? const ['All crops'] : crops,
    condition: condition,
    gatewayId: gatewayId,
    status: AdvisoryStatus.published,
    source: 'ai',
    version: 1,
    publishedAt: DateTime.now(),
    actions: advice.actions,
    isAi: true,
  );
}

/// What an agronomist edits — the content part of an advisory.
class AdvisoryContent {
  final String title;
  final StructuredAdvice advice;
  final List<String> crops;
  final String condition;
  final CustomCondition? customCondition;
  final String? gatewayId;
  final String? stationName;
  final String source;
  final String? aiDraft;
  final bool testOnly;
  final AdviceActions actions;

  const AdvisoryContent({
    required this.title,
    required this.advice,
    required this.crops,
    required this.condition,
    this.customCondition,
    this.gatewayId,
    this.stationName,
    this.source = 'manual',
    this.aiDraft,
    this.testOnly = false,
    this.actions = AdviceActions.empty,
  });

  Map<String, dynamic> toMap() => {
    'title': title.trim(),
    'main': advice.main.trim(),
    'doList': advice.doList,
    'avoidList': advice.avoidList,
    'why': advice.why.trim(),
    'crops': crops,
    'condition': condition,
    'customCondition':
        condition == kCustomCondition ? customCondition?.toMap() : null,
    'gatewayId': (gatewayId == null || gatewayId!.isEmpty) ? null : gatewayId,
    'stationName': stationName,
    'source': source,
    'aiDraft': aiDraft,
    'testOnly': testOnly,
    ...actions.toMap(),
  };
}

/// One immutable audit entry (history/v{version}).
class AdvisoryHistoryEntry {
  final int version;
  final String action;
  final String byName;
  final DateTime? at;
  final String status;
  final Map<String, dynamic> snapshot;

  const AdvisoryHistoryEntry({
    required this.version,
    required this.action,
    required this.byName,
    this.at,
    required this.status,
    this.snapshot = const {},
  });

  factory AdvisoryHistoryEntry.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return AdvisoryHistoryEntry(
      version: (d['version'] as num?)?.toInt() ?? 0,
      action: (d['action'] as String?) ?? '',
      byName: (d['byName'] as String?) ?? '',
      at: _date(d['at']),
      status: (d['status'] as String?) ?? '',
      snapshot: Map<String, dynamic>.from((d['snapshot'] as Map?) ?? const {}),
    );
  }

  String get actionLabel => switch (action) {
    'created' => 'Created draft',
    'edited' => 'Edited draft',
    'published' => 'Verified & published',
    'republished' => 'Updated published advice',
    'unpublished' => 'Unpublished',
    'archived' => 'Archived',
    'restored' => 'Restored to draft',
    _ => action,
  };
}
