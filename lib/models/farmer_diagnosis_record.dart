// lib/models/farmer_diagnosis_record.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class FarmerDiagnosisRecord {
  final String? id;
  final String userId;
  final String cycle;
  final String cropName;
  final String cropStage;
  final String issueType;
  final String selectedName;
  final String? kindwiseTopName;
  final String? kindwiseScientific;
  final double? kindwiseProbability;
  final String? kindwiseProduct;
  final List<KindwiseSuggestionRecord> kindwiseSuggestions;
  final String? interventionText;
  final String? storagePath;
  final String? photoUrl;
  final DateTime? createdAt;
  final String? notes;

  const FarmerDiagnosisRecord({
    this.id,
    required this.userId,
    required this.cycle,
    required this.cropName,
    required this.cropStage,
    required this.issueType,
    required this.selectedName,
    this.kindwiseTopName,
    this.kindwiseScientific,
    this.kindwiseProbability,
    this.kindwiseProduct,
    this.kindwiseSuggestions = const [],
    this.interventionText,
    this.storagePath,
    this.photoUrl,
    this.createdAt,
    this.notes,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'cycle': cycle,
      'cropName': cropName,
      'cropStage': cropStage,
      'issueType': issueType,
      'selectedName': selectedName,
      'kindwiseTopName': kindwiseTopName,
      'kindwiseScientific': kindwiseScientific,
      'kindwiseProbability': kindwiseProbability,
      'kindwiseProduct': kindwiseProduct,
      'kindwiseSuggestions':
          kindwiseSuggestions.map((s) => s.toMap()).toList(),
      'interventionText': interventionText,
      'storagePath': storagePath,
      'photoUrl': photoUrl,
      // FIX #1: Store as ISO string so fromFirestore can always parse it.
      // DiagnosisService adds 'createdAt' as FieldValue.serverTimestamp()
      // separately, so this field in toFirestore() is only used for
      // manual/test writes. Real records get a Firestore Timestamp from
      // the server — handled in fromFirestore below.
      'createdAt': createdAt?.toIso8601String(),
      'notes': notes,
    };
  }

  factory FarmerDiagnosisRecord.fromFirestore(
      Map<String, dynamic> data, String docId) {
    return FarmerDiagnosisRecord(
      id: docId,
      userId: data['userId'] as String? ?? '',
      cycle: data['cycle'] as String? ?? '',
      cropName: data['cropName'] as String? ?? '',
      cropStage: data['cropStage'] as String? ?? '',
      issueType: data['issueType'] as String? ?? 'pest',
      selectedName: data['selectedName'] as String? ?? '',
      kindwiseTopName: data['kindwiseTopName'] as String?,
      kindwiseScientific: data['kindwiseScientific'] as String?,
      kindwiseProbability:
          (data['kindwiseProbability'] as num?)?.toDouble(),
      kindwiseProduct: data['kindwiseProduct'] as String?,
      kindwiseSuggestions: (data['kindwiseSuggestions'] as List? ?? [])
          .map((s) => KindwiseSuggestionRecord.fromMap(
              s as Map<String, dynamic>))
          .toList(),
      interventionText: data['interventionText'] as String?,
      storagePath: data['storagePath'] as String?,
      photoUrl: data['photoUrl'] as String?,
      // FIX #1 — Timestamp crash: Firestore serverTimestamp() returns a
      // Timestamp object, NOT a String. Handle both types gracefully.
      createdAt: _parseDate(data['createdAt']),
      notes: data['notes'] as String?,
    );
  }

  /// Safely parses createdAt regardless of whether Firestore stored it as:
  ///   - a Timestamp  (from FieldValue.serverTimestamp())
  ///   - a String     (from toIso8601String() in older records)
  ///   - null
  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  FarmerDiagnosisRecord copyWith({
    String? interventionText,
    String? photoUrl,
    String? storagePath,
    String? notes,
    String? cycle,
  }) {
    return FarmerDiagnosisRecord(
      id: id,
      userId: userId,
      cycle: cycle ?? this.cycle,
      cropName: cropName,
      cropStage: cropStage,
      issueType: issueType,
      selectedName: selectedName,
      kindwiseTopName: kindwiseTopName,
      kindwiseScientific: kindwiseScientific,
      kindwiseProbability: kindwiseProbability,
      kindwiseProduct: kindwiseProduct,
      kindwiseSuggestions: kindwiseSuggestions,
      interventionText: interventionText ?? this.interventionText,
      storagePath: storagePath ?? this.storagePath,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt,
      notes: notes ?? this.notes,
    );
  }
}

class KindwiseSuggestionRecord {
  final String name;
  final String? scientific;
  final double probability;

  const KindwiseSuggestionRecord({
    required this.name,
    this.scientific,
    required this.probability,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'scientific': scientific,
        'probability': probability,
      };

  factory KindwiseSuggestionRecord.fromMap(Map<String, dynamic> m) =>
      KindwiseSuggestionRecord(
        name: m['name'] as String? ?? '',
        scientific: m['scientific'] as String?,
        probability: (m['probability'] as num?)?.toDouble() ?? 0.0,
      );
}