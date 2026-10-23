import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

// 10 distinct section colours (index 0-9).
const kSectionColors = <Color>[
  Color(0xFF2E7D32), Color(0xFF1565C0), Color(0xFFE65100), Color(0xFF6A1B9A),
  Color(0xFF00838F), Color(0xFFC62828), Color(0xFF558B2F), Color(0xFF0277BD),
  Color(0xFF4E342E), Color(0xFF37474F),
];

// ── Section / division within a farm ─────────────────────────────────────────

class FarmSection {
  final String sectionId;
  final String sectionName;
  final String? cropType;
  final String? notes;
  final List<LatLng> coordinates;
  final double areaHectares;
  final int colorIndex;

  FarmSection({
    String? sectionId,
    required this.sectionName,
    this.cropType,
    this.notes,
    required this.coordinates,
    required this.areaHectares,
    this.colorIndex = 0,
  }) : sectionId = sectionId ?? _uuid.v4();

  factory FarmSection.fromMap(Map<String, dynamic> m) => FarmSection(
        sectionId: m['sectionId'] as String? ?? _uuid.v4(),
        sectionName: m['sectionName'] as String? ?? 'Section',
        cropType: m['cropType'] as String?,
        notes: m['notes'] as String?,
        coordinates: ((m['coordinates'] as List?) ?? []).map((c) {
          final p = c as Map<String, dynamic>;
          return LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble());
        }).toList(),
        areaHectares: (m['areaHectares'] as num? ?? 0).toDouble(),
        colorIndex: (m['colorIndex'] as num? ?? 0).toInt(),
      );

  Map<String, dynamic> toMap() => {
        'sectionId': sectionId,
        'sectionName': sectionName,
        if (cropType != null && cropType!.isNotEmpty) 'cropType': cropType,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        'coordinates':
            coordinates.map((c) => {'lat': c.latitude, 'lng': c.longitude}).toList(),
        'areaHectares': areaHectares,
        'colorIndex': colorIndex,
      };

  FarmSection copyWith({
    String? sectionName,
    String? cropType,
    String? notes,
    List<LatLng>? coordinates,
    double? areaHectares,
    int? colorIndex,
  }) =>
      FarmSection(
        sectionId: sectionId,
        sectionName: sectionName ?? this.sectionName,
        cropType: cropType ?? this.cropType,
        notes: notes ?? this.notes,
        coordinates: coordinates ?? this.coordinates,
        areaHectares: areaHectares ?? this.areaHectares,
        colorIndex: colorIndex ?? this.colorIndex,
      );

  Color get color => kSectionColors[colorIndex.clamp(0, kSectionColors.length - 1)];

  String get areaLabel {
    if (areaHectares >= 1.0) return '${areaHectares.toStringAsFixed(2)} ha';
    if (areaHectares > 0) return '${(areaHectares * 10000).toStringAsFixed(0)} m²';
    return '—';
  }
}

// ── Main farm polygon record ──────────────────────────────────────────────────

class FarmPlot {
  final String? farmId;
  final String userId;
  final String farmName;
  final String? description;
  final List<LatLng> coordinates;
  /// Altitude in metres above sea level for each boundary point.
  /// Parallel to [coordinates]; empty or all-zero means no topo data.
  final List<double> altitudes;
  final double areaHectares;
  final double perimeterMeters;
  final List<FarmSection> sections;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FarmPlot({
    this.farmId,
    required this.userId,
    required this.farmName,
    this.description,
    required this.coordinates,
    this.altitudes = const [],
    required this.areaHectares,
    required this.perimeterMeters,
    this.sections = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// True when at least one boundary point has a non-zero altitude reading.
  bool get hasTopoData =>
      altitudes.isNotEmpty && altitudes.any((a) => a != 0.0);

  factory FarmPlot.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    final rawCoords = (d['coordinates'] as List?) ?? [];
    return FarmPlot(
      farmId: doc.id,
      userId: d['userId'] as String? ?? '',
      farmName: d['farmName'] as String? ?? 'Unnamed Farm',
      description: d['description'] as String?,
      coordinates: rawCoords.map((c) {
        final m = c as Map<String, dynamic>;
        return LatLng((m['lat'] as num).toDouble(), (m['lng'] as num).toDouble());
      }).toList(),
      altitudes: rawCoords.map((c) {
        final m = c as Map<String, dynamic>;
        return (m['alt'] as num?)?.toDouble() ?? 0.0;
      }).toList(),
      areaHectares: (d['areaHectares'] as num? ?? 0).toDouble(),
      perimeterMeters: (d['perimeterMeters'] as num? ?? 0).toDouble(),
      sections: ((d['sections'] as List?) ?? [])
          .map((s) => FarmSection.fromMap(s as Map<String, dynamic>))
          .toList(),
      createdAt:
          d['createdAt'] != null ? (d['createdAt'] as Timestamp).toDate() : DateTime.now(),
      updatedAt:
          d['updatedAt'] != null ? (d['updatedAt'] as Timestamp).toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'farmName': farmName,
        if (description != null && description!.isNotEmpty) 'description': description,
        'coordinates': List.generate(coordinates.length, (i) {
          final alt = i < altitudes.length ? altitudes[i] : 0.0;
          return {
            'lat': coordinates[i].latitude,
            'lng': coordinates[i].longitude,
            if (alt != 0.0) 'alt': alt,
          };
        }),
        'areaHectares': areaHectares,
        'perimeterMeters': perimeterMeters,
        'sections': sections.map((s) => s.toMap()).toList(),
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  FarmPlot copyWith({
    String? farmName,
    String? description,
    List<LatLng>? coordinates,
    List<double>? altitudes,
    double? areaHectares,
    double? perimeterMeters,
    List<FarmSection>? sections,
    DateTime? updatedAt,
  }) =>
      FarmPlot(
        farmId: farmId,
        userId: userId,
        farmName: farmName ?? this.farmName,
        description: description ?? this.description,
        coordinates: coordinates ?? this.coordinates,
        altitudes: altitudes ?? this.altitudes,
        areaHectares: areaHectares ?? this.areaHectares,
        perimeterMeters: perimeterMeters ?? this.perimeterMeters,
        sections: sections ?? this.sections,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  LatLng get center {
    if (coordinates.isEmpty) return const LatLng(-1.2921, 36.8219);
    final lat =
        coordinates.map((c) => c.latitude).reduce((a, b) => a + b) / coordinates.length;
    final lng =
        coordinates.map((c) => c.longitude).reduce((a, b) => a + b) / coordinates.length;
    return LatLng(lat, lng);
  }

  String get areaLabel {
    if (areaHectares >= 1.0) return '${areaHectares.toStringAsFixed(2)} ha';
    if (areaHectares > 0) return '${(areaHectares * 10000).toStringAsFixed(0)} m²';
    return '—';
  }

  String get perimeterLabel {
    if (perimeterMeters >= 1000) return '${(perimeterMeters / 1000).toStringAsFixed(2)} km';
    if (perimeterMeters > 0) return '${perimeterMeters.toStringAsFixed(0)} m';
    return '—';
  }
}
