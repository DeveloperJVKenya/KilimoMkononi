// lib/education/pest/gemini_vision_helper.dart
//
// SHARED Gemini Vision helper — used by all three AI photo diagnosis surfaces.
// Works on Flutter Web (Chrome), Android, and iOS.
//
// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;

const String kGeminiVisionUrl =
    'https://us-central1-kilimomkononi-e1031.cloudfunctions.net/askGeminiVision';

// ─── Crop knowledge base ──────────────────────────────────────────────────────
const Map<String, Map<String, List<String>>> kCropKnowledge = {
  'Beans': {
    'pests': ['Bean Fly', 'Cutworms', 'Aphids', 'Leafhoppers', 'Thrips',
              'Whiteflies', 'Beetles', 'Pod Borers', 'Bean Weevil',
              'Bruchid Beetles', 'Termites', 'Rodents'],
    'diseases': ['Fusarium Root Rot', 'Rhizoctonia Root Rot', 'Pythium Root Rot',
                 'Damping-Off', 'Anthracnose', 'Angular Leaf Spot',
                 'Common Bacterial Blight', 'Halo Blight', 'Bean Rust',
                 'Powdery Mildew', 'Bean Common Mosaic Virus',
                 'Sclerotinia White Mold', 'Bacterial Wilt'],
  },
  'Maize': {
    'pests': ['Termites', 'Cutworms', 'Maize Shoot Fly', 'Aphids', 'Stem Borers',
              'Armyworms', 'Leafhoppers', 'Grasshoppers', 'Thrips', 'Earworms',
              'Weevils', 'Larger Grain Borer', 'Angoumois Grain Moth', 'Rodents'],
    'diseases': ['Pythium Root Rot', 'Damping-Off', 'Gray Leaf Spot',
                 'Common Rust', 'Northern Corn Leaf Blight', 'Maize Streak Virus',
                 'Maize Dwarf Mosaic Virus', 'Maize Lethal Necrosis',
                 'Head Smut', 'Common Smut', 'Fusarium Ear Rot',
                 'Aspergillus Ear Rot', 'Bacterial Stalk Rot'],
  },
  'Cabbages/Kales': {
    'pests': ['Termites', 'Cutworms', 'Root Maggots', 'Flea Beetles', 'Aphids',
              'Whiteflies', 'Diamondback Moth', 'Cabbage Looper',
              'Cabbage Webworm', 'Armyworms', 'Cabbage Root Maggot',
              'Leafminers', 'Stink Bug', 'Rodents'],
    'diseases': ['Damping-Off', 'Black Rot', 'Downy Mildew', 'Powdery Mildew',
                 'Alternaria Leaf Spot', 'Ring Spot', 'Bacterial Soft Rot',
                 'Fusarium Yellows', 'White Rust', 'Black Leg',
                 'Sclerotinia Stem Rot'],
  },
  'Carrots': {
    'pests': ['Termites', 'Cutworms', 'Carrot Rust Fly', 'Nematodes',
              'Wireworms', 'Aphids', 'Whiteflies', 'Thrips', 'Leaf Loopers',
              'Leafminers', 'Armyworms', 'Rodents'],
    'diseases': ['Damping-Off', 'Fusarium Root Rot', 'Rhizoctonia Root Rot',
                 'Pythium Root Rot', 'Alternaria Leaf Blight',
                 'Cercospora Leaf Blight', 'Powdery Mildew', 'Downy Mildew',
                 'Bacterial Leaf Blight', 'Root Knot Nematodes',
                 'Carrot Mosaic Virus', 'Sclerotinia White Mold',
                 'Soft Rot', 'Black Rot'],
  },
  'Tomatoes': {
    'pests': ['Cutworms', 'Termites', 'Nematodes', 'Aphids', 'Whiteflies',
              'Thrips', 'Leafminers', 'Spider Mites', 'Tomato Hornworms',
              'Beet Armyworm', 'Stink Bugs', 'Fruit Borers', 'Bollworms',
              'Fruitflies', 'Rodents'],
    'diseases': ['Damping-Off', 'Fusarium Wilt', 'Verticillium Wilt',
                 'Bacterial Wilt', 'Early Blight', 'Late Blight',
                 'Bacterial Spot', 'Bacterial Canker', 'Powdery Mildew',
                 'Mosaic Virus', 'Yellow Leaf Curl Virus',
                 'Root Knot Nematodes', 'Spotted Wilt Virus',
                 'Septoria Leaf Spot', 'Gray Mold (Botrytis)', 'Anthracnose'],
  },
  'Onions': {
    'pests': ['Aphids', 'Thrips', 'Bulb Fly', 'Maggots', 'Rodents'],
    'diseases': ['Pythium Root Rot', 'Fusarium Basal Rot', 'Downy Mildew',
                 'Powdery Mildew', 'Leaf Blight', 'Purple Blotch',
                 'Gray Mold', 'Neck Rot'],
  },
  'Irish Potatoes': {
    'pests': ['Cutworms', 'Aphids', 'Whiteflies', 'Thrips', 'Leafminers',
              'Colorado Potato Beetle', 'Potato Tuber Moth', 'Nematodes',
              'Wireworms', 'Rodents'],
    'diseases': ['Early Blight', 'Late Blight', 'Bacterial Wilt',
                 'Blackleg', 'Common Scab', 'Fusarium Wilt',
                 'Rhizoctonia', 'Potato Virus Y', 'Potato Leaf Roll Virus',
                 'Powdery Mildew', 'Damping-Off'],
  },
};

// ─── Diagnosis result ─────────────────────────────────────────────────────────
class GeminiDiagResult {
  final String name;
  final String type;
  final String confidence;
  final String description;
  final String recommendation;
  final List<String> alternatives;
  final String imageSubject;
  final bool isRejected;
  final String rejectionReason;

  const GeminiDiagResult({
    required this.name,
    required this.type,
    required this.confidence,
    required this.description,
    required this.recommendation,
    required this.alternatives,
    this.imageSubject = '',
    this.isRejected = false,
    this.rejectionReason = '',
  });

  bool get isHealthy => name.toLowerCase().contains('healthy');

  Color get confColor {
    switch (confidence.toLowerCase()) {
      case 'high':   return Colors.green.shade700;
      case 'medium': return Colors.orange.shade700;
      default:       return Colors.red.shade600;
    }
  }

  String get confLabel {
    switch (confidence.toLowerCase()) {
      case 'high':   return 'High confidence';
      case 'medium': return 'Medium confidence — verify in field';
      default:       return 'Low confidence — best-effort result';
    }
  }
}

// ─── Image compression ────────────────────────────────────────────────────────
// flutter_image_compress works on Web, Android, and iOS.
// The image package (img.decodeImage) does NOT work on Flutter Web — removed.
Future<Uint8List> _prepareImage(Uint8List bytes) async {
  try {
    final result = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth:  800,
      minHeight: 600,
      quality:   82,
      format:    CompressFormat.jpeg,
    );
    // Only use compressed version if smaller than original
    return result.length < bytes.length ? result : bytes;
  } catch (_) {
    return bytes;
  }
}

// ─── Main entry point ─────────────────────────────────────────────────────────
Future<GeminiDiagResult> runGeminiVisionDiagnosis({
  required Uint8List imageBytes,
  required String crop,
  bool? isPest,
}) async {
  final prepared    = await _prepareImage(imageBytes);
  final base64Image = base64Encode(prepared);

  final cropData      = kCropKnowledge[crop];
  final knownPests    = cropData?['pests']    ?? [];
  final knownDiseases = cropData?['diseases'] ?? [];

  final cropContext = cropData != null
      ? '''
Known pests of $crop in Kenya: ${knownPests.join(', ')}.
Known diseases of $crop in Kenya: ${knownDiseases.join(', ')}.
Use these exact names if the visual evidence matches. Do not invent new names.'''
      : 'Crop: $crop. Use your agricultural knowledge of Kenyan crops.';

  final prompt = '''
You are an agricultural image analysis AI for Kenyan farmers and students.
Your outputs directly influence what interventions (chemicals, herbals) farmers apply.
WRONG outputs cause crop loss and financial harm. Accuracy is critical.

$cropContext

You must identify BOTH pests AND diseases with equal accuracy. Never favour one over the other.
PESTS include: insects (aphids, whiteflies, thrips, leafminers, moths, borers), worms
(armyworms, cutworms, nematodes), mites, termites, weevils — any invertebrate on the crop.
DISEASES include: fungal (blight, anthracnose, rust, mildew, rot, mold, leaf spot, scab,
damping-off), bacterial (wilt, canker, soft rot), viral (mosaic, streak, leaf curl, necrosis).
Disease evidence: spots, lesions, discolouration, yellowing, browning, wilting, rotting,
mould, powdery coating, water-soaked patches, cankers, scabs, stunted growth — on ANY crop
part: leaf, stem, root, fruit, pod, flower, bulb, tuber.

IMPORTANT — IMAGE QUALITY:
Many users have basic phones producing blurry or low-resolution photos. This is expected.
A blurry or dark photo of a crop IS NOT "unrelated". Give a best-effort diagnosis at
"low" or "medium" confidence. Only use "unrelated" if the SUBJECT is not agricultural
(e.g. a person, building, or vertebrate animal like a rabbit, bird, or cow).
Never reject an image purely because of poor photo quality.

════════════════════════════════════════════════════
INSTRUCTIONS — follow in this exact order:
════════════════════════════════════════════════════

STEP 1 — DESCRIBE LITERALLY:
Write one sentence in "image_subject" describing EXACTLY what you physically see.
Use only what is literally visible. Do not interpret or assume.
Examples:
  • "A green tomato leaf with brown circular spots and yellow halos."
  • "A small green insect with wings sitting on a bean leaf."
  • "A grey rabbit sitting next to tomato plants."
  • "A blurry photo showing green plant material with some discolouration."

STEP 2 — CATEGORISE (based only on image_subject):
  "pest_present"  → An invertebrate is visible: insect, worm, mite, caterpillar,
                    aphid, whitefly, slug, termite, weevil, etc.
  "crop_damage"   → ANY crop part (leaf, stem, root, fruit, pod, seedling, flower,
                    bulb, tuber) with ANY abnormality: spots, lesions, blight,
                    anthracnose, rot, mould, wilting, discolouration, holes, cankers,
                    scabs, powdery coating, water-soaked patches, mosaic patterns,
                    yellowing, browning, or any abnormal appearance.
                    A blurry or low-quality photo of a damaged plant = "crop_damage".
  "healthy_crop"  → A crop part with no visible abnormalities.
  "unrelated"     → A vertebrate animal (rabbit, bird, cow, cat, dog, rodent),
                    person, building, or completely non-agricultural subject.
                    LOW IMAGE QUALITY ALONE IS NEVER A REASON FOR "unrelated".

STEP 3 — DIAGNOSE (only if pest_present or crop_damage):
  • Identify the specific pest or disease from what is literally visible.
  • Use exact names from the crop knowledge list if they match visually.
  • Confidence:
      "high"   = clearly visible, in-focus, unambiguous
      "medium" = visible but ambiguous or image quality reduces certainty
      "low"    = very blurry or dark but still making best-effort identification
  • For low-quality images: still attempt diagnosis. State what you can observe.
  • description: specific visual features that led to your identification.
  • recommendation: most important immediate action for a Kenyan farmer.
  • type: "pest" for invertebrate organisms, "disease" for fungal/bacterial/viral.

════════════════════════════════════════════════════
RETURN ONLY valid JSON — no markdown, no code fences:
════════════════════════════════════════════════════
{
  "image_subject": "One literal sentence of exactly what is physically in the image.",
  "image_category": "pest_present" | "crop_damage" | "healthy_crop" | "unrelated",
  "rejection_reason": "If unrelated: what was seen and what to upload instead. Otherwise empty.",
  "name": "Exact common name of pest or disease. Empty if unrelated or healthy.",
  "type": "pest" | "disease" | "none" | "",
  "confidence": "high" | "medium" | "low" | "",
  "description": "2-3 sentences: visual evidence for identification. Must match image_subject.",
  "recommendation": "1-2 sentences: most important action for a Kenyan farmer. Empty if unrelated.",
  "alternatives": ["Second most likely diagnosis if applicable."]
}

════════════════════════════════════════════════════
HARD RULES:
════════════════════════════════════════════════════
1. Vertebrate animal in image → image_category MUST be "unrelated". No exceptions.
2. Person, building, non-agricultural subject → image_category MUST be "unrelated".
3. "description" MUST match "image_subject". Fix any contradiction before responding.
4. "high" confidence only when pest/disease is clearly visible and unambiguous.
5. Crop name "$crop" = what the user selected, NOT what is in the image.
6. Do NOT invent symptoms. Do NOT name a disease based on crop name alone.
7. Rabbits, birds, rodents, livestock → always "unrelated".
8. POOR IMAGE QUALITY IS NEVER A REASON FOR "unrelated". Blurry crop photo =
   "crop_damage" or "healthy_crop" diagnosed at "low" confidence.
9. Disease symptoms on any crop part ALWAYS = "crop_damage".
10. "type" must be "pest" for invertebrates, "disease" for fungal/bacterial/viral.
''';

  // Retry with exponential backoff: 0s → 5s → 12s
  Future<http.Response> doPost() => http.post(
    Uri.parse(kGeminiVisionUrl),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'imageBase64': base64Image, 'prompt': prompt}),
  ).timeout(const Duration(seconds: 90));

  http.Response resp = await doPost();

  if (resp.statusCode == 429 || resp.statusCode == 503) {
    await Future.delayed(const Duration(seconds: 5));
    resp = await doPost();
  }
  if (resp.statusCode == 429 || resp.statusCode == 503) {
    await Future.delayed(const Duration(seconds: 12));
    resp = await doPost();
  }

  if (resp.statusCode != 200) {
    if (resp.statusCode == 429) {
      throw Exception(
          'The AI service is busy right now.\n\n'
          'Please wait 30 seconds and try again.\n'
          'Your photo is fine — this is a temporary limit.');
    }
    if (resp.statusCode == 503) {
      throw Exception(
          'The AI service is temporarily overloaded.\n\n'
          'Please wait a minute and try again.');
    }
    if (resp.statusCode == 400) {
      throw Exception(
          'The image could not be processed (error 400).\n\n'
          'Try a different photo or check your connection.');
    }
    if (resp.statusCode >= 500) {
      throw Exception(
          'The AI service is temporarily unavailable (error ${resp.statusCode}).\n\n'
          'Please try again in a few minutes.');
    }
    throw Exception('AI service error (${resp.statusCode}). Please try again.');
  }

  return _parseResponse(resp.body);
}

// ─── Response parser ──────────────────────────────────────────────────────────
GeminiDiagResult _parseResponse(String body) {
  final data       = jsonDecode(body) as Map<String, dynamic>;
  final candidates = data['candidates'] as List<dynamic>?;

  if (candidates == null || candidates.isEmpty) {
    return GeminiDiagResult(
      name: '', type: 'unknown', confidence: 'low',
      description: '', recommendation: '', alternatives: [],
      isRejected: true,
      rejectionReason: 'The AI returned an empty response. Please try again.',
    );
  }

  final text = (candidates[0]?['content']?['parts']?[0]?['text'] ?? '')
      .toString().trim();

  Map<String, dynamic> j;
  try {
    final cleaned = text.replaceAll('```json', '').replaceAll('```', '').trim();
    j = jsonDecode(cleaned) as Map<String, dynamic>;
  } catch (_) {
    return GeminiDiagResult(
      name: '', type: 'unknown', confidence: 'low',
      description: '', recommendation: '', alternatives: [],
      isRejected: true,
      rejectionReason: 'The AI response could not be read. Please try again.',
    );
  }

  final category       = (j['image_category']  as String? ?? '').toLowerCase();
  final imageSubject   = (j['image_subject']    as String? ?? '');
  final rejReason      = (j['rejection_reason'] as String? ?? '');
  final name           = (j['name']             as String? ?? '');
  final type           = (j['type']             as String? ?? '');
  final confidence     = (j['confidence']       as String? ?? 'low');
  final description    = (j['description']      as String? ?? '');
  final recommendation = (j['recommendation']   as String? ?? '');
  final alternatives   = (j['alternatives'] as List<dynamic>?)
                             ?.map((e) => e.toString()).toList() ?? [];

  if (category == 'unrelated') {
    return GeminiDiagResult(
      name: '', type: 'none', confidence: 'low',
      description: '', recommendation: '', alternatives: [],
      imageSubject: imageSubject,
      isRejected: true,
      rejectionReason: rejReason.isNotEmpty
          ? rejReason
          : 'This image does not show a crop plant or agricultural pest. '
            'Please upload a photo of the affected crop part or the pest.',
    );
  }

  if (category == 'healthy_crop') {
    return GeminiDiagResult(
      name: 'Healthy Plant', type: 'none', confidence: 'high',
      description: 'No signs of pest or disease damage were detected.',
      recommendation: 'Continue monitoring your crop regularly.',
      alternatives: [],
    );
  }

  return GeminiDiagResult(
    name:            name.isNotEmpty ? name : 'Unknown issue',
    type:            type.isNotEmpty ? type : 'unknown',
    confidence:      confidence,
    description:     description,
    recommendation:  recommendation,
    alternatives:    alternatives,
    imageSubject:    imageSubject,
    isRejected:      false,
    rejectionReason: '',
  );
}