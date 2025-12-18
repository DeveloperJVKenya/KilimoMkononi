import 'package:cloud_firestore/cloud_firestore.dart';

class FieldData {
  final String userId;
  final String plotId;
  final List<Map<String, String>> crops;
  final double? area;
  final Map<String, double?> npk;
  final List<String> microNutrients;
  final List<Map<String, dynamic>> interventions;
  final List<Map<String, dynamic>> reminders;
  final Timestamp timestamp;
  final String structureType;
  final String? fertilizerRecommendation;

  FieldData({
    required this.userId,
    required this.plotId,
    required this.crops,
    this.area,
    required this.npk,
    required this.microNutrients,
    required this.interventions,
    required this.reminders,
    required this.timestamp,
    required this.structureType,
    this.fertilizerRecommendation,
  });

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'plotId': plotId,
        'crops': crops,
        'area': area,
        'npk': npk,
        'microNutrients': microNutrients,
        'interventions': interventions,
        'reminders': reminders,
        'timestamp': timestamp,
        'structureType': structureType,
        'fertilizerRecommendation': fertilizerRecommendation,
      };

  factory FieldData.fromMap(Map<String, dynamic> map) {
    // Helper function to convert int or double to double?
    double? toDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      throw Exception('Invalid type for double?: $value (${value.runtimeType})');
    }

    // Convert npk map values
    final npkMap = Map<String, dynamic>.from(map['npk'] ?? {'N': null, 'P': null, 'K': null});
    final npkConverted = <String, double?>{};
    for (var key in ['N', 'P', 'K']) {
      npkConverted[key] = toDouble(npkMap[key]);
    }

    return FieldData(
      userId: map['userId'] as String? ?? '',
      plotId: map['plotId'] as String? ?? '',
      crops: (map['crops'] as List<dynamic>? ?? [])
          .map((item) => Map<String, String>.from(item as Map))
          .toList(),
      area: toDouble(map['area']),
      npk: npkConverted,
      microNutrients: List<String>.from(map['microNutrients'] as List? ?? []),
      interventions: List<Map<String, dynamic>>.from(map['interventions'] as List? ?? []),
      reminders: List<Map<String, dynamic>>.from(map['reminders'] as List? ?? []),
      timestamp: map['timestamp'] as Timestamp? ?? Timestamp.now(),
      structureType: map['structureType'] as String? ?? '',
      fertilizerRecommendation: map['fertilizerRecommendation'] as String?,
    );
  }
}