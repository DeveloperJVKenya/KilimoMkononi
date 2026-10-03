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

/// Thrown by [AgronomicAdvisoryService.save] when someone else changed the
/// advisory after it was opened — saving would silently undo their change.
class AdvisoryConflictException implements Exception {
  const AdvisoryConflictException();
  @override
  String toString() =>
      'This advice was changed by someone else while you had it open. '
      'Close it and open it again to see the latest version.';
}

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

  /// One advisory (e.g. the one a notification points to); null if it was
  /// removed or isn't visible to this user (unpublished / test).
  static Future<AgronomicAdvisory?> byId(String id) async {
    try {
      final d = await _col.doc(id).get();
      return d.exists ? AgronomicAdvisory.fromDoc(d) : null;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return null;
      rethrow;
    }
  }

  /// The farmer's crops from their field records (fielddata.crops[].type) —
  /// those of [plotId] when it has any, else all their recorded crops. The
  /// same source the push functions use. Throws if the records can't load
  /// (callers then pass `farmerCrops: null` = 'All crops' advice only).
  static Future<List<String>> farmerCrops(String uid, {String? plotId}) async {
    final snap = await _db
        .collection('fielddata')
        .where('userId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .limit(30)
        .get();
    final forPlot = <String>{};
    final all = <String>{};
    for (final d in snap.docs) {
      final data = d.data();
      final types = ((data['crops'] as List?) ?? const [])
          .map((c) => (c is Map ? c['type'] : null)?.toString().trim() ?? '')
          .where((t) => t.isNotEmpty);
      all.addAll(types);
      if (plotId != null && data['plotId'] == plotId) forPlot.addAll(types);
    }
    return (forPlot.isNotEmpty ? forPlot : all).toList();
  }

  /// Published advisories for the conditions active right now, filtered to
  /// the farmer's crops and station. Most specific first: station-scoped
  /// before all-stations, a specific condition before 'general', then newest.
  ///
  /// [farmerCrops] null means the crops couldn't be loaded — only
  /// 'All crops' advice is returned then, rather than guessing. (An empty
  /// list means the farmer has recorded none, and matches everything.)
  ///
  /// [includeTest] (admins only — rules deny it for farmers) also returns
  /// test-mode advisories so an admin can see the farmer view end to end.
  static Future<List<AgronomicAdvisory>> publishedFor({
    required Set<String> conditions,
    required List<String>? farmerCrops,
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
        .where((a) => farmerCrops == null
            ? isForAllCrops(a.crops)
            : cropsMatch(a.crops, farmerCrops))
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

  /// [includeTest] is for admins in test mode. Field Agronomists never see
  /// admin TEST advisories — the rules wouldn't let them edit those anyway.
  static Stream<List<AgronomicAdvisory>> streamByStatus(
    AdvisoryStatus status, {
    bool includeTest = false,
  }) => _col.where('status', isEqualTo: status.name).snapshots().map((s) {
    final list = s.docs
        .map(AgronomicAdvisory.fromDoc)
        .where((a) => includeTest || !a.testOnly)
        .toList()
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
  ///
  /// [expectedVersion] is the version the editor opened; if the advisory has
  /// moved on since, [AdvisoryConflictException] is thrown instead of
  /// overwriting someone else's change.
  ///
  /// Farmers are notified when advice is first published. Changes to advice
  /// that is already published only notify them when [notifyFarmers] is set
  /// (so a typo fix doesn't re-push to everyone) — recorded as
  /// `notifyVersion`, which the Cloud Functions compare against.
  static Future<String> save({
    String? id,
    int? expectedVersion,
    required AdvisoryContent content,
    required AdvisoryStatus status,
    required String action,
    bool notifyFarmers = false,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final name = await _myName();
    final ref = id == null ? _col.doc() : _col.doc(id);

    await _db.runTransaction((tx) async {
      final current = id == null ? null : await tx.get(ref);
      if (id != null && !(current?.exists ?? false)) {
        throw StateError('This advisory no longer exists.');
      }
      final currentVersion = (current?.data()?['version'] as num?)?.toInt() ?? 0;
      if (expectedVersion != null && currentVersion != expectedVersion) {
        throw const AdvisoryConflictException();
      }
      final version = currentVersion + 1;
      final wasPublished =
          current?.data()?['status'] == AdvisoryStatus.published.name;
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
        if (!wasPublished || notifyFarmers) data['notifyVersion'] = version;
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
  /// Fails with [AdvisoryConflictException] if [a] is out of date.
  static Future<void> changeStatus(
    AgronomicAdvisory a,
    AdvisoryStatus status,
    String action,
  ) => save(
    id: a.id,
    expectedVersion: a.version,
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
      actions: a.actions,
    ),
    status: status,
    action: action,
  );

  /// Only drafts that were never published can be deleted (rules enforce
  /// this); anything farmers may have seen is archived instead. The draft's
  /// history entries go with it in the same batch, so nothing is orphaned.
  static Future<void> deleteDraft(String id) async {
    final ref = _col.doc(id);
    final history = await ref.collection('history').get();
    final batch = _db.batch();
    for (final h in history.docs) {
      batch.delete(h.reference);
    }
    batch.delete(ref);
    await batch.commit();
  }

  /// The text of a Gemini response body (`candidates[0].content.parts[0]
  /// .text`, or a plain `{text}`); '' when it has none — e.g. a blocked
  /// reply with an empty `candidates` list.
  static String aiReplyText(dynamic data) {
    dynamic first(dynamic list) =>
        list is List && list.isNotEmpty ? list.first : null;
    if (data is! Map) return '';
    final candidate = first(data['candidates']);
    final content = candidate is Map ? candidate['content'] : null;
    final part = first(content is Map ? content['parts'] : null);
    final text = (part is Map ? part['text'] : null) ?? data['text'];
    return (text ?? '').toString().trim();
  }

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
PESTS:
- <pest name> — <signs to look for> — <what to do if found>
DISEASES:
- <disease name> — <signs to look for> — <what to do if found>
SOIL:
- <N|P|K|pH|general> | Low: <action> | Moderate: <action> | High: <action>

Rules:
- Advice must be specific to the crop(s) and this weather condition.
- DO and AVOID: max 3 bullets each, short phrases starting with a verb.
- PESTS / DISEASES: at most 3 each that these crops commonly get in this
  condition; write "none" if none apply.
- SOIL: fertiliser / soil decisions this condition affects (e.g. leaching
  after heavy rain, delaying top-dressing). Farmers may not know their soil
  level, so give an action per level; write "none" if not relevant.
- No chemical brand names; name active ingredients only if essential.
- Do not invent numbers you were not given; leave rates to the agronomist.
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
    final raw = aiReplyText(jsonDecode(res.body));
    final advice = parseStructuredAdvice(raw);
    if (advice == null) throw Exception('AI returned an empty draft');
    return (advice: advice, raw: raw);
  }
}
