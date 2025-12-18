class Symptom {
  final String crop;
  final String stage;
  final String plantPart;
  final String label;
  final String likelyType;
  final String shortCode;
  final String identity;

  Symptom({
    required this.crop,
    required this.stage,
    required this.plantPart,
    required this.label,
    required this.likelyType,
    required this.shortCode,
    required this.identity,
  });

  factory Symptom.fromJson(Map<String, dynamic> json) {
    return Symptom(
      crop: json['crop'] ?? '',
      stage: json['stage'] ?? '',
      plantPart: json['plant_part'] ?? 'General',   // ✅ fallback if missing
      label: json['symptom_label'] ?? json['visible_symptoms'] ?? '', // ✅ support both
      likelyType: json['likely_type'] ?? '',
      shortCode: json['short_code'] ?? '',
      identity: json['identity'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'crop': crop,
      'stage': stage,
      'plant_part': plantPart,
      'symptom_label': label,
      'likely_type': likelyType,
      'short_code': shortCode,
      'identity': identity,
    };
  }
}
