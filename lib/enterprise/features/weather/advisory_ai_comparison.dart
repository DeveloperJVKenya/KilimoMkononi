// lib/enterprise/features/weather/advisory_ai_comparison.dart
//
// Model for the side-by-side AI vs. agronomist advisory comparison stored in
// advisoryAiComparisons/{advisoryId} — admin-only, never readable by farmers
// or agronomists (covered by the admin catch-all in firestore.rules).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_actions.dart';
import 'package:kilimomkononi/enterprise/features/weather/structured_advice.dart';

DateTime? _date(dynamic v) => v is Timestamp ? v.toDate() : null;
List<String> _strs(dynamic v) =>
    (v as List?)?.map((e) => e.toString()).toList() ?? const [];

class AdvisoryAiComparison {
  final String advisoryId;
  final int advisoryVersion;
  final List<String> crops;
  final String condition;
  final String conditionLabel;
  final DateTime? generatedAt;
  final String aiRaw;
  final StructuredAdvice aiAdvice;
  final AdviceActions aiActions;
  final StructuredAdvice agronomistAdvice;
  final AdviceActions agronomistActions;
  final String agronomistName;
  final bool adminReviewed;
  final String adminNote;
  final String? reviewedByName;
  final DateTime? reviewedAt;

  const AdvisoryAiComparison({
    required this.advisoryId,
    required this.advisoryVersion,
    required this.crops,
    required this.condition,
    required this.conditionLabel,
    this.generatedAt,
    required this.aiRaw,
    required this.aiAdvice,
    required this.aiActions,
    required this.agronomistAdvice,
    required this.agronomistActions,
    required this.agronomistName,
    this.adminReviewed = false,
    this.adminNote = '',
    this.reviewedByName,
    this.reviewedAt,
  });

  factory AdvisoryAiComparison.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};

    StructuredAdvice parseAdvice(dynamic raw) {
      final m = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      return StructuredAdvice(
        main: (m['main'] as String?) ?? '',
        doList: _strs(m['doList']),
        avoidList: _strs(m['avoidList']),
        why: (m['why'] as String?) ?? '',
      );
    }

    return AdvisoryAiComparison(
      advisoryId: doc.id,
      advisoryVersion: (d['advisoryVersion'] as num?)?.toInt() ?? 1,
      crops: _strs(d['crops']),
      condition: (d['condition'] as String?) ?? 'general',
      conditionLabel: (d['conditionLabel'] as String?) ?? '',
      generatedAt: _date(d['generatedAt']),
      aiRaw: (d['aiRaw'] as String?) ?? '',
      aiAdvice: parseAdvice(d['aiAdvice']),
      aiActions: AdviceActions.fromDoc(
        d['aiActions'] is Map ? Map<String, dynamic>.from(d['aiActions'] as Map) : {},
      ),
      agronomistAdvice: parseAdvice(d['agronomistAdvice']),
      agronomistActions: AdviceActions.fromDoc(
        d['agronomistActions'] is Map
            ? Map<String, dynamic>.from(d['agronomistActions'] as Map)
            : {},
      ),
      agronomistName: (d['agronomistName'] as String?) ?? '',
      adminReviewed: d['adminReviewed'] == true,
      adminNote: (d['adminNote'] as String?) ?? '',
      reviewedByName: d['reviewedByName'] as String?,
      reviewedAt: _date(d['reviewedAt']),
    );
  }
}
