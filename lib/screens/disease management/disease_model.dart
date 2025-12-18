import 'package:cloud_firestore/cloud_firestore.dart';

class DiseaseData {
  final String name;
  final String imagePath;
  final List<String> preventionStrategies;
  final String activeAgent;
  final List<String> possibleCauses;
  final List<String> fungicides;
  final List<String> organicInterventions; // Added field

  DiseaseData({
    required this.name,
    required this.imagePath,
    required this.preventionStrategies,
    required this.activeAgent,
    required this.possibleCauses,
    required this.fungicides,
    required this.organicInterventions,
  });

  factory DiseaseData.fromMap(Map<String, dynamic> data) {
    return DiseaseData(
      name: data['name'] as String? ?? '',
      imagePath: data['imagePath'] as String? ?? '',
      preventionStrategies: List<String>.from(data['preventionStrategies'] ?? []),
      activeAgent: data['activeAgent'] as String? ?? '',
      possibleCauses: List<String>.from(data['possibleCauses'] ?? []),
      fungicides: List<String>.from(data['fungicides'] ?? []),
      organicInterventions: List<String>.from(data['organicInterventions'] ?? []),
    );
  }
}

class DiseaseIntervention {
  final String? id;
  final String diseaseName;
  final String cropType;
  final String cropStage;
  final String intervention;
  final double? dosage;
  final String? unit;
  final double? area;
  final String areaUnit;
  final Timestamp timestamp;
  final String userId;
  final bool isDeleted;

  DiseaseIntervention({
    this.id,
    required this.diseaseName,
    required this.cropType,
    required this.cropStage,
    required this.intervention,
    this.dosage,
    this.unit,
    this.area,
    required this.areaUnit,
    required this.timestamp,
    required this.userId,
    this.isDeleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'diseaseName': diseaseName,
      'cropType': cropType,
      'cropStage': cropStage,
      'intervention': intervention,
      'dosage': dosage,
      'unit': unit,
      'area': area,
      'areaUnit': areaUnit,
      'timestamp': timestamp,
      'userId': userId,
      'isDeleted': isDeleted,
    };
  }

  factory DiseaseIntervention.fromMap(Map<String, dynamic> data, String id) {
    return DiseaseIntervention(
      id: id,
      diseaseName: data['diseaseName'] as String,
      cropType: data['cropType'] as String,
      cropStage: data['cropStage'] as String,
      intervention: data['intervention'] as String? ?? '',
      dosage: data['dosage']?.toDouble(),
      unit: data['unit'] as String?,
      area: data['area']?.toDouble(),
      areaUnit: data['areaUnit'] as String,
      timestamp: data['timestamp'] as Timestamp,
      userId: data['userId'] as String,
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
      diseaseName: data['diseaseName'] as String,
      cropType: data['cropType'] as String,
      cropStage: data['cropStage'] as String,
      intervention: data['intervention'] as String? ?? '',
      dosage: data['dosage']?.toDouble(),
      unit: data['unit'] as String?,
      area: data['area']?.toDouble(),
      areaUnit: data['areaUnit'] as String,
      timestamp: data['timestamp'] as Timestamp,
      userId: data['userId'] as String,
      isDeleted: data['isDeleted'] as bool? ?? false,
    );
  }

  DiseaseIntervention copyWith({
    String? id,
    String? diseaseName,
    String? cropType,
    String? cropStage,
    String? intervention,
    double? dosage,
    String? unit,
    double? area,
    String? areaUnit,
    Timestamp? timestamp,
    String? userId,
    bool? isDeleted,
  }) {
    return DiseaseIntervention(
      id: id ?? this.id,
      diseaseName: diseaseName ?? this.diseaseName,
      cropType: cropType ?? this.cropType,
      cropStage: cropStage ?? this.cropStage,
      intervention: intervention ?? this.intervention,
      dosage: dosage ?? this.dosage,
      unit: unit ?? this.unit,
      area: area ?? this.area,
      areaUnit: areaUnit ?? this.areaUnit,
      timestamp: timestamp ?? this.timestamp,
      userId: userId ?? this.userId,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}