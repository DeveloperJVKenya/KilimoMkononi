// lib/models/farmer_issue_record.dart
//
// UNIFIED model for ALL farmer pest/disease records — whether identified
// by AI photo diagnosis or manually by eye.
//
// REPLACES the split between:
//   • pestinterventiondata       (manual pest records)
//   • diseaseinterventiondata    (manual disease records)
//   • farmer_diagnoses/.../records (AI photo diagnosis records)
//
// NEW single collection: farmer_issues/{userId}/records/{docId}
//
// MIGRATION NOTE:
//   Existing documents in the old collections are NOT deleted.
//   farmer_issue_service.dart reads from ALL three collections and
//   presents them together in the unified history. New records from
//   this point forward are written ONLY to farmer_issues/{userId}/records.
//
// CHANGELOG v2:
//   + aiAdvice  (String?) — plain-text advice shown by the AI Soil/Pest/Disease
//               Advisor at the time the record was saved. Distinct from
//               aiRecommendation (which comes from the photo diagnosis engine).

import 'package:cloud_firestore/cloud_firestore.dart';

// How the issue was identified
enum DiagnosisSource {
  aiPhoto,   // Gemini AI photo diagnosis
  manual,    // Farmer identified by eye / physical inspection
}

class FarmerIssueRecord {
  final String?  id;
  final String   userId;
  final String   cycle;             // e.g. 'A', 'Season 1', 'March 2026'
  final String   cropName;
  final String   cropStage;
  final String   issueType;         // 'pest' | 'disease'
  final String   issueName;         // e.g. 'Early Blight', 'Armyworms'
  final DiagnosisSource source;
  final String?  aiConfidence;      // 'high' | 'medium' | 'low' — null if manual
  final String?  aiDescription;     // what AI saw in the photo
  final String?  aiRecommendation;  // recommendation from photo diagnosis
  final String?  aiAdvice;          // plain-text advice from the Soil/Pest/Disease
                                    // Advisor (Gemini text call) shown at save time
  final String?  aiAnalysis;        // full JSON from Gemini full-analysis call
  final String?  photoUrl;
  final String?  interventionText;  // what the farmer actually did
  final double?  dosage;
  final String?  dosageUnit;
  final String?  amountText;        // free-text amount (pest records)
  final double?  area;
  final String   areaUnit;          // 'Acres' | 'SQM'
  final bool     isDeleted;
  final Timestamp timestamp;
  final DateTime? createdAt;

  const FarmerIssueRecord({
    this.id,
    required this.userId,
    required this.cycle,
    required this.cropName,
    required this.cropStage,
    required this.issueType,
    required this.issueName,
    required this.source,
    this.aiConfidence,
    this.aiDescription,
    this.aiRecommendation,
    this.aiAdvice,
    this.aiAnalysis,
    this.photoUrl,
    this.interventionText,
    this.dosage,
    this.dosageUnit,
    this.amountText,
    this.area,
    this.areaUnit = 'Acres',
    this.isDeleted = false,
    required this.timestamp,
    this.createdAt,
  });

  bool get isPest    => issueType == 'pest';
  bool get isDisease => issueType == 'disease';
  bool get isAI      => source == DiagnosisSource.aiPhoto;
  bool get hasIntervention =>
      interventionText != null && interventionText!.isNotEmpty;

  Map<String, dynamic> toMap() => {
    'userId':           userId,
    'cycle':            cycle,
    'cropName':         cropName,
    'cropStage':        cropStage,
    'issueType':        issueType,
    'issueName':        issueName,
    'source':           source.name,
    'aiConfidence':     aiConfidence,
    'aiDescription':    aiDescription,
    'aiRecommendation': aiRecommendation,
    'aiAdvice':         aiAdvice,
    'aiAnalysis':       aiAnalysis,
    'photoUrl':         photoUrl,
    'interventionText': interventionText,
    'dosage':           dosage,
    'dosageUnit':       dosageUnit,
    'amountText':       amountText,
    'area':             area,
    'areaUnit':         areaUnit,
    'isDeleted':        isDeleted,
    'timestamp':        timestamp,
    'createdAt':        FieldValue.serverTimestamp(),
  };

  factory FarmerIssueRecord.fromMap(Map<String, dynamic> d, String id) =>
      FarmerIssueRecord(
        id:               id,
        userId:           d['userId']           as String?    ?? '',
        cycle:            d['cycle']            as String?    ?? 'A',
        cropName:         d['cropName']         as String?    ?? '',
        cropStage:        d['cropStage']        as String?    ?? '',
        issueType:        d['issueType']        as String?    ?? 'pest',
        issueName:        d['issueName']        as String?    ?? '',
        source:           _parseSource(d['source'] as String?),
        aiConfidence:     d['aiConfidence']     as String?,
        aiDescription:    d['aiDescription']    as String?,
        aiRecommendation: d['aiRecommendation'] as String?,
        aiAdvice:         d['aiAdvice']         as String?,
        aiAnalysis:       d['aiAnalysis']       as String?,
        photoUrl:         d['photoUrl']         as String?,
        interventionText: d['interventionText'] as String?,
        dosage:           (d['dosage']  as num?)?.toDouble(),
        dosageUnit:       d['dosageUnit']       as String?,
        amountText:       d['amountText']       as String?,
        area:             (d['area'] as num?)?.toDouble(),
        areaUnit:         d['areaUnit']         as String?    ?? 'Acres',
        isDeleted:        d['isDeleted']        as bool?      ?? false,
        timestamp:        d['timestamp']        as Timestamp? ?? Timestamp.now(),
        createdAt: d['createdAt'] != null
            ? (d['createdAt'] as Timestamp).toDate()
            : null,
      );

  // ── Adapter: build from old pestinterventiondata document ─────────────────
  factory FarmerIssueRecord.fromOldPest(Map<String, dynamic> d, String id) =>
      FarmerIssueRecord(
        id:               id,
        userId:           d['userId']      as String? ?? '',
        cycle:            d['cycle']       as String? ?? 'A',
        cropName:         d['cropType']    as String? ?? '',
        cropStage:        d['cropStage']   as String? ?? '',
        issueType:        'pest',
        issueName:        d['pestName']    as String? ?? '',
        source:           DiagnosisSource.manual,
        interventionText: d['intervention'] as String?,
        amountText:       d['amount']      as String?,
        area:             (d['area'] as num?)?.toDouble(),
        areaUnit:         d['areaUnit']    as String? ?? 'Acres',
        isDeleted:        d['isDeleted']   as bool?   ?? false,
        timestamp:        d['timestamp']   as Timestamp? ?? Timestamp.now(),
      );

  // ── Adapter: build from old diseaseinterventiondata document ──────────────
  factory FarmerIssueRecord.fromOldDisease(Map<String, dynamic> d, String id) =>
      FarmerIssueRecord(
        id:               id,
        userId:           d['userId']      as String? ?? '',
        cycle:            d['cycle']       as String? ?? 'A',
        cropName:         d['cropType']    as String? ?? '',
        cropStage:        d['cropStage']   as String? ?? '',
        issueType:        'disease',
        issueName:        d['diseaseName'] as String? ?? '',
        source:           DiagnosisSource.manual,
        interventionText: d['intervention'] as String?,
        dosage:           (d['dosage'] as num?)?.toDouble(),
        dosageUnit:       d['unit']        as String?,
        area:             (d['area'] as num?)?.toDouble(),
        areaUnit:         d['areaUnit']    as String? ?? 'Acres',
        isDeleted:        d['isDeleted']   as bool?   ?? false,
        timestamp:        d['timestamp']   as Timestamp? ?? Timestamp.now(),
      );

  // ── Adapter: build from old farmer_diagnoses record ───────────────────────
  factory FarmerIssueRecord.fromOldAiRecord(
      Map<String, dynamic> d, String id) =>
      FarmerIssueRecord(
        id:               id,
        userId:           d['userId']           as String? ?? '',
        cycle:            d['cycle']            as String? ?? 'A',
        cropName:         d['cropName']         as String? ?? '',
        cropStage:        d['cropStage']        as String? ?? '',
        issueType:        d['issueType']        as String? ?? 'pest',
        issueName:        d['selectedName']     as String? ?? '',
        source:           DiagnosisSource.aiPhoto,
        aiConfidence:     null,
        interventionText: d['interventionText'] as String?,
        photoUrl:         d['photoUrl']         as String?,
        isDeleted:        false,
        timestamp:        d['createdAt'] as Timestamp? ?? Timestamp.now(),
      );

  FarmerIssueRecord copyWith({
    String? interventionText,
    double? dosage,
    String? dosageUnit,
    String? amountText,
    double? area,
    String? areaUnit,
    String? aiAdvice,
    String? aiAnalysis,
    bool?   isDeleted,
  }) =>
      FarmerIssueRecord(
        id:               id,
        userId:           userId,
        cycle:            cycle,
        cropName:         cropName,
        cropStage:        cropStage,
        issueType:        issueType,
        issueName:        issueName,
        source:           source,
        aiConfidence:     aiConfidence,
        aiDescription:    aiDescription,
        aiRecommendation: aiRecommendation,
        aiAdvice:         aiAdvice     ?? this.aiAdvice,
        aiAnalysis:       aiAnalysis   ?? this.aiAnalysis,
        photoUrl:         photoUrl,
        interventionText: interventionText ?? this.interventionText,
        dosage:           dosage       ?? this.dosage,
        dosageUnit:       dosageUnit   ?? this.dosageUnit,
        amountText:       amountText   ?? this.amountText,
        area:             area         ?? this.area,
        areaUnit:         areaUnit     ?? this.areaUnit,
        isDeleted:        isDeleted    ?? this.isDeleted,
        timestamp:        timestamp,
        createdAt:        createdAt,
      );

  static DiagnosisSource _parseSource(String? s) =>
      s == 'aiPhoto' ? DiagnosisSource.aiPhoto : DiagnosisSource.manual;
}