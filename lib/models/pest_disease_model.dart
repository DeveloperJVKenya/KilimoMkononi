import 'package:cloud_firestore/cloud_firestore.dart';

class PestData {
  final String name;
  final String imagePath;
  final List<String> preventionStrategies;
  final String activeAgent;
  final List<String> possibleCauses;
  final List<String> herbicides;
  final List<String> organicInterventions; 

  PestData({
    required this.name,
    required this.imagePath,
    required this.preventionStrategies,
    required this.activeAgent,
    required this.possibleCauses,
    required this.herbicides,
    required this.organicInterventions,
  });

  factory PestData.fromMap(Map<String, dynamic> data) {
    return PestData(
      name: data['name'] as String? ?? '',
      imagePath: data['imagePath'] as String? ?? '',
      preventionStrategies: List<String>.from(data['preventionStrategies'] ?? []),
      activeAgent: data['activeAgent'] as String? ?? '',
      possibleCauses: List<String>.from(data['possibleCauses'] ?? []),
      herbicides: List<String>.from(data['herbicidesPesticides'] ?? []),
      organicInterventions: List<String>.from(data['organicInterventions'] ?? []),
    );
  }

  static final Map<String, PestData> pestLibrary = {};
}

/// ─────────────────────────────────────────────────────────────────────────────
/// PestIntervention — pest management record
/// ─────────────────────────────────────────────────────────────────────────────
class PestIntervention {
  final String? id;
  final String? plotId;              // ← NEW: Links to farm plot
  final String pestName;
  final String cropType;
  final String cropStage;
  final String? cycle;               // Cycle reference (e.g., 'A', 'Season 2024')
  final String intervention;
  final double? dosage;              // Amount of intervention
  final String? unit;                // Unit (ml, L, kg, etc)
  final double? area;                // Area treated
  final String areaUnit;             // Acres, SQM, etc
  final double? cost;                // ← NEW: Cost in KES
  final Timestamp timestamp;
  final String userId;
  final bool isDeleted;
  final String? amount;              // Legacy field for backward compatibility

  PestIntervention({
    this.id,
    this.plotId,                      // ← NEW parameter
    required this.pestName,
    required this.cropType,
    required this.cropStage,
    this.cycle,
    required this.intervention,
    this.dosage,
    this.unit,
    this.area,
    required this.areaUnit,
    this.cost,                        // ← NEW parameter
    required this.timestamp,
    required this.userId,
    required this.isDeleted,
    this.amount,
  });

  Map<String, dynamic> toMap() {
    return {
      'plotId': plotId,               // ← NEW in map
      'pestName': pestName,
      'cropType': cropType,
      'cropStage': cropStage,
      'cycle': cycle,
      'intervention': intervention,
      'dosage': dosage,
      'unit': unit,
      'area': area,
      'areaUnit': areaUnit,
      'cost': cost,                   // ← NEW in map
      'timestamp': timestamp,
      'userId': userId,
      'isDeleted': isDeleted,
      'amount': amount,
    };
  }

  factory PestIntervention.fromMap(Map<String, dynamic> data, String docId) {
    return PestIntervention(
      id: docId,
      plotId: data['plotId'] as String?,           // ← NEW from map
      pestName: data['pestName'] as String? ?? 'Unknown',
      cropType: data['cropType'] as String? ?? 'Unknown',
      cropStage: data['cropStage'] as String? ?? 'Unknown',
      cycle: data['cycle'] as String?,
      intervention: data['intervention'] as String? ?? '',
      dosage: data['dosage'] as double?,
      unit: data['unit'] as String?,
      area: data['area'] as double?,
      areaUnit: data['areaUnit'] as String? ?? 'Acres',
      cost: data['cost'] as double?,               // ← NEW from map
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
      userId: data['userId'] as String? ?? 'Unknown',
      isDeleted: data['isDeleted'] as bool? ?? false,
      amount: data['amount'] as String?,
    );
  }

  factory PestIntervention.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data()!;
    return PestIntervention(
      id: snapshot.id,
      plotId: data['plotId'] as String?,           // ← NEW from firestore
      pestName: data['pestName'] as String? ?? 'Unknown',
      cropType: data['cropType'] as String? ?? 'Unknown',
      cropStage: data['cropStage'] as String? ?? 'Unknown',
      cycle: data['cycle'] as String?,
      intervention: data['intervention'] as String? ?? '',
      dosage: data['dosage'] as double?,
      unit: data['unit'] as String?,
      area: data['area'] as double?,
      areaUnit: data['areaUnit'] as String? ?? 'Acres',
      cost: data['cost'] as double?,               // ← NEW from firestore
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
      userId: data['userId'] as String? ?? 'Unknown',
      isDeleted: data['isDeleted'] as bool? ?? false,
      amount: data['amount'] as String?,
    );
  }

  PestIntervention copyWith({
    String? id,
    String? plotId,                   // ← NEW parameter
    String? pestName,
    String? cropType,
    String? cropStage,
    String? cycle,
    String? intervention,
    double? dosage,
    String? unit,
    double? area,
    String? areaUnit,
    double? cost,                     // ← NEW parameter
    Timestamp? timestamp,
    String? userId,
    bool? isDeleted,
    String? amount,
  }) {
    return PestIntervention(
      id: id ?? this.id,
      plotId: plotId ?? this.plotId,  // ← NEW in copy
      pestName: pestName ?? this.pestName,
      cropType: cropType ?? this.cropType,
      cropStage: cropStage ?? this.cropStage,
      cycle: cycle ?? this.cycle,
      intervention: intervention ?? this.intervention,
      dosage: dosage ?? this.dosage,
      unit: unit ?? this.unit,
      area: area ?? this.area,
      areaUnit: areaUnit ?? this.areaUnit,
      cost: cost ?? this.cost,        // ← NEW in copy
      timestamp: timestamp ?? this.timestamp,
      userId: userId ?? this.userId,
      isDeleted: isDeleted ?? this.isDeleted,
      amount: amount ?? this.amount,
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// DiseaseIntervention — disease management record (mirrors PestIntervention)
/// ─────────────────────────────────────────────────────────────────────────────
class DiseaseIntervention {
  final String? id;
  final String? plotId;              // ← NEW: Links to farm plot
  final String diseaseName;
  final String cropType;
  final String cropStage;
  final String? cycle;               // Cycle reference
  final String intervention;
  final double? dosage;              // Amount of intervention
  final String? unit;                // Unit (ml, L, kg, etc)
  final double? area;                // Area treated
  final String areaUnit;             // Acres, SQM, etc
  final double? cost;                // ← NEW: Cost in KES
  final Timestamp timestamp;
  final String userId;
  final bool isDeleted;

  DiseaseIntervention({
    this.id,
    this.plotId,                      // ← NEW parameter
    required this.diseaseName,
    required this.cropType,
    required this.cropStage,
    this.cycle,
    required this.intervention,
    this.dosage,
    this.unit,
    this.area,
    required this.areaUnit,
    this.cost,                        // ← NEW parameter
    required this.timestamp,
    required this.userId,
    required this.isDeleted,
  });

  Map<String, dynamic> toMap() {
    return {
      'plotId': plotId,               // ← NEW in map
      'diseaseName': diseaseName,
      'cropType': cropType,
      'cropStage': cropStage,
      'cycle': cycle,
      'intervention': intervention,
      'dosage': dosage,
      'unit': unit,
      'area': area,
      'areaUnit': areaUnit,
      'cost': cost,                   // ← NEW in map
      'timestamp': timestamp,
      'userId': userId,
      'isDeleted': isDeleted,
    };
  }

  factory DiseaseIntervention.fromMap(Map<String, dynamic> data, String docId) {
    return DiseaseIntervention(
      id: docId,
      plotId: data['plotId'] as String?,           // ← NEW from map
      diseaseName: data['diseaseName'] as String? ?? 'Unknown',
      cropType: data['cropType'] as String? ?? 'Unknown',
      cropStage: data['cropStage'] as String? ?? 'Unknown',
      cycle: data['cycle'] as String?,
      intervention: data['intervention'] as String? ?? '',
      dosage: data['dosage'] as double?,
      unit: data['unit'] as String?,
      area: data['area'] as double?,
      areaUnit: data['areaUnit'] as String? ?? 'Acres',
      cost: data['cost'] as double?,               // ← NEW from map
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
      userId: data['userId'] as String? ?? 'Unknown',
      isDeleted: data['isDeleted'] as bool? ?? false,
    );
  }

  factory DiseaseIntervention.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data()!;
    return DiseaseIntervention(
      id: snapshot.id,
      plotId: data['plotId'] as String?,           // ← NEW from firestore
      diseaseName: data['diseaseName'] as String? ?? 'Unknown',
      cropType: data['cropType'] as String? ?? 'Unknown',
      cropStage: data['cropStage'] as String? ?? 'Unknown',
      cycle: data['cycle'] as String?,
      intervention: data['intervention'] as String? ?? '',
      dosage: data['dosage'] as double?,
      unit: data['unit'] as String?,
      area: data['area'] as double?,
      areaUnit: data['areaUnit'] as String? ?? 'Acres',
      cost: data['cost'] as double?,               // ← NEW from firestore
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
      userId: data['userId'] as String? ?? 'Unknown',
      isDeleted: data['isDeleted'] as bool? ?? false,
    );
  }

  DiseaseIntervention copyWith({
    String? id,
    String? plotId,                   // ← NEW parameter
    String? diseaseName,
    String? cropType,
    String? cropStage,
    String? cycle,
    String? intervention,
    double? dosage,
    String? unit,
    double? area,
    String? areaUnit,
    double? cost,                     // ← NEW parameter
    Timestamp? timestamp,
    String? userId,
    bool? isDeleted,
  }) {
    return DiseaseIntervention(
      id: id ?? this.id,
      plotId: plotId ?? this.plotId,  // ← NEW in copy
      diseaseName: diseaseName ?? this.diseaseName,
      cropType: cropType ?? this.cropType,
      cropStage: cropStage ?? this.cropStage,
      cycle: cycle ?? this.cycle,
      intervention: intervention ?? this.intervention,
      dosage: dosage ?? this.dosage,
      unit: unit ?? this.unit,
      area: area ?? this.area,
      areaUnit: areaUnit ?? this.areaUnit,
      cost: cost ?? this.cost,        // ← NEW in copy
      timestamp: timestamp ?? this.timestamp,
      userId: userId ?? this.userId,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}