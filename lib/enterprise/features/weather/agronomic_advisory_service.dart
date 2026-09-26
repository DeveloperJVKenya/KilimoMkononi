// lib/enterprise/features/weather/agronomic_advisory_service.dart
//
// Field Agronomist role check, advisory CRUD with an enforced audit trail,
// the farmer-side "verified advice for today's conditions" query, and AI
// drafting (via the authenticated askGemini function).

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:kilimomkononi/enterprise/features/weather/advisory_conditions.dart';
import 'package:kilimomkononi/enterprise/features/weather/agronomic_advisory.dart';
import 'package:kilimomkononi/enterprise/features/weather/structured_advice.dart';
import 'package:kilimomkononi/services/function_auth.dart';
import 'package:kilimomkononi/services/nuasense_service.dart';

const _kAskGeminiUrl =
    'https://us-central1-kilimomkononi-e1031.cloudfunctions.net/askGemini';

/// How the current user may use the Field Agronomist panel.
///   agronomist — real advisories; publishing reaches farmers.
///   adminTest  — an admin testing the workflow; everything they create is
///                testOnly (hidden from farmers) and live advice is read-only.
enum AdvisoryAccess { none, agronomist, adminTest }

class AgronomicAdvisoryService {
  AgronomicAdvisoryService._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('agronomic_advisories');

  // ── Role ──────────────────────────────────────────────────────────────────

  /// Field Agronomists are granted by an admin (Agronomists/{uid}, assigned
  /// from the admin panel). Admins who aren't agronomists get test mode.
  static Future<AdvisoryAccess> access() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return AdvisoryAccess.none;
    try {
      if ((await _db.collection('Agronomists').doc(user.uid).get()).exists) {
        return AdvisoryAccess.agronomist;
      }
      if ((await _db.collection('Admins').doc(user.uid).get()).exists) {
        return AdvisoryAccess.adminTest;
      }
    } catch (_) {}
    return AdvisoryAccess.none;
  }

  static Future<bool> isFieldAgronomist() async =>
      (await access()) != AdvisoryAccess.none;

  static Future<String> _myName() async {
    final user = FirebaseAuth.instance.currentUser!;
    try {
      final doc = await _db.collection('Users').doc(user.uid).get();
      final name = doc.data()?['fullName'] as String?;
      if (name != null && name.trim().isNotEmpty) return name.trim();
    } catch (_) {}
    return user.displayName ?? user.email ?? 'Field Agronomist';
  }

  // ── Farmer view ───────────────────────────────────────────────────────────

  /// Published advisories for the conditions active right now, filtered to
  /// the farmer's crops and station. Most specific first: station-scoped
  /// before all-stations, a specific condition before 'general', then newest.
  ///
  /// [includeTest] (admins only — rules deny it for farmers) also returns
  /// test-mode advisories so an admin can see the farmer view end to end.
  static Future<List<AgronomicAdvisory>> publishedFor({
    required Set<String> conditions,
    required List<String> farmerCrops,
    String? gatewayId,
    bool includeTest = false,
  }) async {
    if (conditions.isEmpty) return const [];
    Query<Map<String, dynamic>> q = _col
        .where('status', isEqualTo: AdvisoryStatus.published.name)
        .where('condition', whereIn: conditions.take(30).toList());
    // Farmers must filter testOnly == false — the rules require it.
    if (!includeTest) q = q.where('testOnly', isEqualTo: false);
    final snap = await q.get();

    final list = snap.docs
        .map(AgronomicAdvisory.fromDoc)
        .where((a) => cropsMatch(a.crops, farmerCrops))
        .where((a) => !a.isStationScoped || a.gatewayId == gatewayId)
        .toList();

    int rank(AgronomicAdvisory a) =>
        (a.isStationScoped ? 0 : 2) + (a.condition == 'general' ? 1 : 0);
    list.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      if (r != 0) return r;
      return (b.publishedAt ?? DateTime(0)).compareTo(
        a.publishedAt ?? DateTime(0),
      );
    });
    return list;
  }

  // ── Panel ─────────────────────────────────────────────────────────────────

  static Stream<List<AgronomicAdvisory>> streamByStatus(
    AdvisoryStatus status,
  ) => _col.where('status', isEqualTo: status.name).snapshots().map((s) {
    final list = s.docs.map(AgronomicAdvisory.fromDoc).toList()
      ..sort(
        (a, b) =>
            (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)),
      );
    return list;
  });

  static Stream<List<AdvisoryHistoryEntry>> history(String advisoryId) => _col
      .doc(advisoryId)
      .collection('history')
      .orderBy('version', descending: true)
      .snapshots()
      .map((s) => s.docs.map(AdvisoryHistoryEntry.fromDoc).toList());

  /// Create or change an advisory. Always writes the advisory AND its
  /// history/v{version} entry in one transaction — the security rules reject
  /// either write without the other, so the audit trail can't be skipped.
  ///
  /// [status] is the target status; [action] names the change for the audit
  /// log (created, edited, published, republished, unpublished, archived,
  /// restored). Returns the advisory id.
  static Future<String> save({
    String? id,
    required AdvisoryContent content,
    required AdvisoryStatus status,
    required String action,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final name = await _myName();
    final ref = id == null ? _col.doc() : _col.doc(id);

    await _db.runTransaction((tx) async {
      final current = id == null ? null : await tx.get(ref);
      if (id != null && !(current?.exists ?? false)) {
        throw StateError('This advisory no longer exists.');
      }
      final version = ((current?.data()?['version'] as num?)?.toInt() ?? 0) + 1;
      final now = FieldValue.serverTimestamp();

      final data = <String, dynamic>{
        ...content.toMap(),
        'platform': 'km',
        'status': status.name,
        'version': version,
        'updatedBy': uid,
        'updatedByName': name,
        'updatedAt': now,
      };
      if (current == null) {
        data.addAll({
          'createdBy': uid,
          'createdByName': name,
          'createdAt': now,
        });
      }
      // Publishing = verifying: whoever publishes (or changes published
      // content) is recorded as the verifying agronomist.
      if (status == AdvisoryStatus.published) {
        data.addAll({
          'publishedBy': uid,
          'publishedByName': name,
          'publishedAt': now,
        });
      }

      if (current == null) {
        tx.set(ref, data);
      } else {
        tx.update(ref, data);
      }
      tx.set(ref.collection('history').doc('v$version'), {
        'version': version,
        'action': action,
        'status': status.name,
        'byUid': uid,
        'byName': name,
        'at': now,
        'snapshot': content.toMap(),
      });
    });
    return ref.id;
  }

  /// Status-only change (unpublish / archive / restore), keeping content.
  static Future<void> changeStatus(
    AgronomicAdvisory a,
    AdvisoryStatus status,
    String action,
  ) => save(
    id: a.id,
    content: AdvisoryContent(
      title: a.title,
      advice: a.advice,
      crops: a.crops,
      condition: a.condition,
      gatewayId: a.gatewayId,
      stationName: a.stationName,
      source: a.source,
      aiDraft: a.aiDraft,
      testOnly: a.testOnly,
    ),
    status: status,
    action: action,
  );

  /// Only drafts that were never published can be deleted (rules enforce
  /// this); anything farmers may have seen is archived instead.
  static Future<void> deleteDraft(String id) => _col.doc(id).delete();

  // ── AI drafting ───────────────────────────────────────────────────────────

  /// Asks Gemini for a draft the agronomist then reviews. Returns the parsed
  /// advice plus the raw text (kept on the advisory for audit).
  static Future<({StructuredAdvice advice, String raw})> generateAiDraft({
    required List<String> crops,
    required String conditionKey,
    NuaSenseReading? reading,
  }) async {
    final cond = conditionFor(conditionKey);
    final cropText = crops.contains(kAllCrops) || crops.isEmpty
        ? 'common smallholder crops (maize, beans, tomatoes, cabbages/kales, potatoes, onions)'
        : crops.join(', ');
    final live = reading == null || !reading.isProvisioned
        ? ''
        : '''
Current station reading (context only):
- Temp ${reading.airTemp.toStringAsFixed(1)}°C, humidity ${reading.humidity.toStringAsFixed(0)}%
- Wind ${reading.windSpeed.toStringAsFixed(1)} m/s, rain ${reading.rainfall.toStringAsFixed(1)} mm/h
- Leaves ${reading.leafIsWet ? 'wet' : 'dry'}, VPD ${reading.vpd.toStringAsFixed(2)} kPa
''';

    final prompt =
        '''
You are drafting agronomic advice for smallholder farmers in Kenya. A qualified Field Agronomist will review and edit your draft before farmers see it, so be accurate and conservative.

Crop(s): $cropText
Weather condition: ${cond.label} — ${cond.description}
$live
Reply in EXACTLY this format (plain text, no markdown):
MAIN: <one short action, max 12 words>
DO:
- <action>
- <action>
AVOID:
- <action>
WHY: <one short sentence>

Rules:
- Advice must be specific to the crop(s) and this weather condition.
- DO and AVOID: max 3 bullets each, short phrases starting with a verb.
- No chemical brand names; name active ingredients only if essential.
- Do not invent numbers you were not given.
''';

    final res = await http
        .post(
          Uri.parse(_kAskGeminiUrl),
          headers: await authJsonHeaders(),
          body: jsonEncode({'prompt': prompt}),
        )
        .timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) {
      throw Exception('AI draft failed (HTTP ${res.statusCode})');
    }
    final data = jsonDecode(res.body);
    final raw =
        (data['candidates']?[0]?['content']?['parts']?[0]?['text'] ??
                data['text'] ??
                '')
            .toString()
            .trim();
    final advice = parseStructuredAdvice(raw);
    if (advice == null) throw Exception('AI returned an empty draft');
    return (advice: advice, raw: raw);
  }
}
