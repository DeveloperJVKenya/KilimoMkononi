// lib/services/kindwise_service.dart

import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kilimomkononi/services/diagnosis_service.dart';

// API keys live server-side in the `kindwiseProxy` Cloud Function
// (Secret Manager) — they used to be embedded here and shipped in the app.

const Set<String> _kCropHealthCrops = {
  'Maize', 'Tomatoes', 'Onions', 'Irish Potatoes',
};

// ─── MODELS ───────────────────────────────────────────────────────────────────
class KindwiseSuggestion {
  final String name;
  final String? scientificName;
  final double probability;
  final String? type;
  final String? description;
  final KindwiseTreatment? treatment;
  final String? symptoms;
  final String? severity;
  final String? imageUrl;

  const KindwiseSuggestion({
    required this.name,
    this.scientificName,
    required this.probability,
    this.type,
    this.description,
    this.treatment,
    this.symptoms,
    this.severity,
    this.imageUrl,
  });

  bool get isHealthy =>
      name.toLowerCase().contains('healthy') ||
      name.toLowerCase() == 'no disease' ||
      name.toLowerCase() == 'no pest';

  String get percentLabel =>
      '${(probability * 100).toStringAsFixed(0)}%';

  factory KindwiseSuggestion.fromJson(Map<String, dynamic> json) {
    // crop.health puts treatment/description at top level in each suggestion
    // plant.id puts them inside a 'details' sub-object
    final details = json['details'] as Map<String, dynamic>? ?? {};
    final treatmentRaw = json['treatment'] ?? details['treatment'];
    final images = (json['images'] ?? details['images']) as List?;

    return KindwiseSuggestion(
      name: json['name'] as String? ?? 'Unknown',
      scientificName: json['scientific_name'] as String?,
      probability: (json['probability'] as num?)?.toDouble() ?? 0.0,
      type: (json['type'] ?? details['type']) as String?,
      description: (json['description'] ?? details['description']) as String?,
      treatment: treatmentRaw is Map<String, dynamic>
          ? KindwiseTreatment.fromJson(treatmentRaw)
          : null,
      symptoms: _extractString(json['symptoms'] ?? details['symptoms']),
      severity: (json['severity'] ?? details['severity']) as String?,
      imageUrl: images != null && images.isNotEmpty
          ? (images.first as Map)['url'] as String?
          : null,
    );
  }

  static String? _extractString(dynamic val) {
    if (val == null) return null;
    if (val is String) return val;
    if (val is Map && val['description'] is String) return val['description'] as String;
    return null;
  }
}

class KindwiseTreatment {
  final List<String> biological;
  final List<String> chemical;
  final List<String> prevention;

  const KindwiseTreatment({
    required this.biological,
    required this.chemical,
    required this.prevention,
  });

  bool get isEmpty =>
      biological.isEmpty && chemical.isEmpty && prevention.isEmpty;

  factory KindwiseTreatment.fromJson(Map<String, dynamic> json) {
    List<String> parse(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      if (raw is String) return [raw];
      if (raw is Map && raw['description'] is String) return [raw['description'] as String];
      return [];
    }
    return KindwiseTreatment(
      biological: parse(json['biological']),
      chemical: parse(json['chemical']),
      prevention: parse(json['prevention']),
    );
  }
}

class KindwiseResult {
  final String accessToken;
  final String apiUsed;
  final List<KindwiseSuggestion> suggestions;
  final bool isHealthy;
  final String? storagePath;
  final String? downloadUrl;

  const KindwiseResult({
    required this.accessToken,
    required this.apiUsed,
    required this.suggestions,
    required this.isHealthy,
    this.storagePath,
    this.downloadUrl,
  });

  KindwiseSuggestion? get top =>
      suggestions.isNotEmpty ? suggestions.first : null;
}

// ─── SERVICE ───────────────────────────────────────────────────────────────
class KindwiseService {

  static Future<KindwiseResult> identify({
    required Uint8List imageBytes,
    required String crop,
    required String fileName,
    required bool isPest,           // ← This decides which API to call
    double? latitude,
    double? longitude,
    String? datetime,
  }) async {
    final apiUsed = isPest 
        ? 'insect.id' 
        : (_kCropHealthCrops.contains(crop) ? 'crop.health' : 'plant.id');

    debugPrint('[Kindwise] Crop "$crop" → $apiUsed (isPest: $isPest)');

    final results = await Future.wait([
      isPest
          ? _callInsectId(imageBytes: imageBytes)
          : _kCropHealthCrops.contains(crop)
              ? _callCropHealth(imageBytes: imageBytes, latitude: latitude, longitude: longitude, datetime: datetime)
              : _callPlantId(imageBytes: imageBytes, latitude: latitude, longitude: longitude),
      DiagnosisService.uploadPhoto(imageBytes, fileName),
    ]);

    final apiResult = results[0] as KindwiseResult;
    final upload = results[1] as ({String storagePath, String downloadUrl});

    debugPrint('[Kindwise] ✓ Top: ${apiResult.top?.name} ${apiResult.top?.percentLabel}');

    return KindwiseResult(
      accessToken: apiResult.accessToken,
      apiUsed: apiResult.apiUsed,
      suggestions: apiResult.suggestions,
      isHealthy: apiResult.isHealthy,
      storagePath: upload.storagePath,
      downloadUrl: upload.downloadUrl,
    );
  }

  // ── INSECT.ID (for pests) ───────────────────────────────────────────────
  static Future<KindwiseResult> _callInsectId({required Uint8List imageBytes}) async {
    final base64Image = 'data:image/jpeg;base64,${base64Encode(imageBytes)}';

    final body = {
      'images': [base64Image],
      'similar_images': true,
    };

    debugPrint('[insect.id] POSTing...');
    final response = await _proxy('insect', body)
        .timeout(const Duration(seconds: 60));

    debugPrint('[insect.id] Status: ${response.statusCode}');

    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception('insect.id error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final token = data['access_token'] as String? ?? '';
    final result = data['result'] as Map<String, dynamic>? ?? {};

    final rawSugs = result['insect']?['suggestions'] as List? ?? [];

    final suggestions = rawSugs
        .map((s) => KindwiseSuggestion.fromJson(s as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.probability.compareTo(a.probability));

    return KindwiseResult(
      accessToken: token,
      apiUsed: 'insect.id',
      suggestions: suggestions,
      isHealthy: suggestions.isEmpty || suggestions.first.isHealthy,
    );
  }

  // ── CROP.HEALTH ─────────────────────────────────────────────────────────────
  // crop.health ONLY accepts similar_images=true as a modifier.
  // Do NOT send 'details' — it is not supported and causes 400.
  // The API always returns its own fixed response shape.
  static Future<KindwiseResult> _callCropHealth({
    required Uint8List imageBytes,
    double? latitude,
    double? longitude,
    String? datetime,
  }) async {
    final base64Image = 'data:image/jpeg;base64,${base64Encode(imageBytes)}';

    final body = <String, dynamic>{
      'images': [base64Image],
      'similar_images': true,   // the ONLY modifier crop.health supports
    };
    if (latitude != null)  body['latitude']  = latitude;
    if (longitude != null) body['longitude'] = longitude;
    if (datetime != null)  body['datetime']  = datetime;

    debugPrint('[crop.health] POSTing...');
    final response = await _proxy('crop', body)
        .timeout(const Duration(seconds: 60));

    debugPrint('[crop.health] Status: ${response.statusCode}');
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception('crop.health error ${response.statusCode}: ${response.body}');
    }

    final data   = jsonDecode(response.body) as Map<String, dynamic>;
    final token  = data['access_token'] as String? ?? '';
    final result = data['result'] as Map<String, dynamic>? ?? {};

    debugPrint('[crop.health] Raw result keys: ${result.keys.toList()}');

    // crop.health returns pest AND disease suggestions separately
    final diseaseSugs = result['disease']?['suggestions'] as List? ?? [];
    final pestSugs    = result['pest']?['suggestions']    as List? ?? [];
    final allSugs     = [...diseaseSugs, ...pestSugs];

    debugPrint('[crop.health] disease suggestions: ${diseaseSugs.length}, pest: ${pestSugs.length}');

    final suggestions = allSugs
        .map((s) => KindwiseSuggestion.fromJson(s as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.probability.compareTo(a.probability));

    final diseaseHealthy =
        result['disease']?['is_healthy'] == true ||
        (diseaseSugs.isNotEmpty &&
            (diseaseSugs.first['name'] as String? ?? '')
                .toLowerCase().contains('healthy'));
    final pestHealthy =
        result['pest']?['is_healthy'] == true || pestSugs.isEmpty;

    return KindwiseResult(
      accessToken: token,
      apiUsed: 'crop.health',
      suggestions: suggestions,
      isHealthy: diseaseHealthy && pestHealthy,
    );
  }

  // ── PLANT.ID HEALTH ASSESSMENT ──────────────────────────────────────────────
  // plant.id supports 'details' and 'health' modifiers — no issue here.
  static Future<KindwiseResult> _callPlantId({
    required Uint8List imageBytes,
    double? latitude,
    double? longitude,
  }) async {
    final base64Image = 'data:image/jpeg;base64,${base64Encode(imageBytes)}';

    final body = <String, dynamic>{
      'images': [base64Image],
      'similar_images': true,
      'health': 'all',
      'details': [
        'treatment', 'description', 'common_names',
        'taxonomy', 'symptoms', 'severity', 'images',
      ],
    };
    if (latitude != null)  body['latitude']  = latitude;
    if (longitude != null) body['longitude'] = longitude;

    debugPrint('[plant.id] POSTing...');
    final response = await _proxy('plant', body)
        .timeout(const Duration(seconds: 60));

    debugPrint('[plant.id] Status: ${response.statusCode}');
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception('Plant.id error ${response.statusCode}: ${response.body}');
    }

    final data   = jsonDecode(response.body) as Map<String, dynamic>;
    final token  = data['access_token'] as String? ?? '';
    final result = data['result'] as Map<String, dynamic>? ?? {};

    final rawSugs =
        result['disease']?['suggestions'] as List? ??
        result['health']?['diseases']    as List? ??
        [];

    final suggestions = rawSugs
        .map((s) => KindwiseSuggestion.fromJson(s as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.probability.compareTo(a.probability));

    final isHealthy = result['is_healthy']?['binary'] == true ||
        (suggestions.isNotEmpty && suggestions.first.isHealthy);

    return KindwiseResult(
      accessToken: token,
      apiUsed: 'plant.id',
      suggestions: suggestions,
      isHealthy: isHealthy,
    );
  }

  static Future<Map<String, dynamic>> getUsageInfo() async {
    final res = await _proxy('usage', null);
    return {
      'crop.health': res.statusCode == 200
          ? jsonDecode(res.body)
          : {'error': res.statusCode},
    };
  }

  /// Calls the `kindwiseProxy` Cloud Function, which adds the API key
  /// server-side. Returns Kindwise's own status code and JSON body so the
  /// callers' status checks and jsonDecode(response.body) are unchanged.
  static Future<http.Response> _proxy(
      String service, Map<String, dynamic>? body) async {
    final fn = FirebaseFunctions.instance.httpsCallable(
      'kindwiseProxy',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 90)),
    );
    final res = await fn.call({'service': service, 'body': body});
    final data = Map<String, dynamic>.from(res.data as Map);
    return http.Response(
      jsonEncode(data['data']),
      (data['status'] as num?)?.toInt() ?? 500,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}