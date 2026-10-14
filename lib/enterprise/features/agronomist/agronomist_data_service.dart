// lib/enterprise/features/agronomist/agronomist_data_service.dart
//
// The Agronomist panel's access to farmers:
//   • insights / farmer records — through the `agronomistData` Cloud Function
//     (functions/agronomist.js); the rules never let the app read another
//     farmer's collections directly, and every farmer view is logged.
//   • the live activity feed (farmerActivity, written by the functions).
//   • custom advice for farmers (farmer_advice) — create / send / update /
//     withdraw, each write with its history/v{version} audit entry in the
//     same transaction or batch (the rules reject one without the other).
//   • AI drafts of custom advice from a farmer's records (askGemini).

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:kilimomkononi/enterprise/features/agronomist/farmer_advice.dart';
import 'package:kilimomkononi/enterprise/features/agronomist/farmer_records.dart';
import 'package:kilimomkononi/enterprise/features/weather/agronomic_advisory_service.dart';
import 'package:kilimomkononi/enterprise/features/weather/structured_advice.dart';
import 'package:kilimomkononi/services/function_auth.dart';

const _kAskGeminiUrl = 'https://us-central1-kilimomkononi-e1031.cloudfunctions.net/askGemini';

/// One entry in the farmer activity feed (farmerActivity/{id}).
class FarmerActivity {
  final String id;
  final String farmerUid;
  final String farmerName;
  final String county;
  final String ward;

  /// pest | disease | field_record | soil_action | advice_response
  final String kind;
  final String title;
  final String detail;
  final String? crop;
  final String? issueName;
  final List<String> flags;
  final bool notable;
  final DateTime? at;

  const FarmerActivity({
    required this.id,
    required this.farmerUid,
    required this.farmerName,
    this.county = '',
    this.ward = '',
    required this.kind,
    required this.title,
    this.detail = '',
    this.crop,
    this.issueName,
    this.flags = const [],
    this.notable = false,
    this.at,
  });

  bool get unidentified => flags.contains('unidentified');
  List<String> get lowNutrients =>
      [for (final f in flags) if (f.startsWith('low_')) f.substring(4)];
  String get place => [ward, county].where((p) => p.isNotEmpty).join(', ');

  factory FarmerActivity.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return FarmerActivity(
      id: doc.id,
      farmerUid: '${d['farmerUid'] ?? ''}',
      farmerName: '${d['farmerName'] ?? 'A farmer'}',
      county: '${d['county'] ?? ''}',
      ward: '${d['ward'] ?? ''}',
      kind: '${d['kind'] ?? ''}',
      title: '${d['title'] ?? ''}',
      detail: '${d['detail'] ?? ''}',
      crop: d['crop'] as String?,
      issueName: d['issueName'] as String?,
      flags: ((d['flags'] as List?) ?? const []).map((e) => '$e').toList(),
      notable: d['notable'] == true,
      at: d['at'] is Timestamp ? (d['at'] as Timestamp).toDate() : null,
    );
  }
}

/// A farmer advice is about to be sent to — the editor's target.
class AdviceTarget {
  final String uid;
  final String name;
  final List<String> crops;
  const AdviceTarget({required this.uid, required this.name, this.crops = const []});
}

class AgronomistDataService {
  AgronomistDataService._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _advice => _db.collection('farmer_advice');

  static Future<Map<String, dynamic>> _call(Map<String, dynamic> data) async {
    final res = await FirebaseFunctions.instance
        .httpsCallable('agronomistData', options: HttpsCallableOptions(timeout: const Duration(seconds: 90)))
        .call<Object?>(data);
    final out = res.data;
    return out is Map ? out.map((k, v) => MapEntry('$k', v)) : <String, dynamic>{};
  }

  // ── Records (through the Cloud Function) ─────────────────────────────────

  /// Every farmer's recent records — [days] is 7, 30 or 90.
  static Future<InsightsData> insights(int days) async =>
      InsightsData.fromMap(await _call({'action': 'insights', 'days': days}));

  /// One farmer's full record (refused if they don't share; logged).
  static Future<FarmerRecord> farmer(String uid) async =>
      FarmerRecord.fromMap(await _call({'action': 'farmer', 'farmerUid': uid}));

  // ── Activity feed ────────────────────────────────────────────────────────

  static Stream<List<FarmerActivity>> activity({bool notableOnly = false, int limit = 150}) {
    Query<Map<String, dynamic>> q = _db.collection('farmerActivity');
    if (notableOnly) q = q.where('notable', isEqualTo: true);
    return q
        .orderBy('at', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(FarmerActivity.fromDoc).toList());
  }

  static Stream<List<FarmerActivity>> activityOf(String farmerUid, {int limit = 50}) => _db
      .collection('farmerActivity')
      .where('farmerUid', isEqualTo: farmerUid)
      .orderBy('at', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(FarmerActivity.fromDoc).toList());

  // ── Custom advice ────────────────────────────────────────────────────────

  /// All custom advice (newest change first). [includeTest]: admins in test
  /// mode also see their TEST advice; agronomists never do.
  static Stream<List<FarmerAdvice>> allAdvice({bool includeTest = false, int limit = 300}) => _advice
      .orderBy('updatedAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(FarmerAdvice.fromDoc).where((a) => includeTest || !a.testOnly).toList());

  static Stream<List<FarmerAdvice>> adviceFor(String farmerUid, {bool includeTest = false}) => _advice
      .where('farmerUid', isEqualTo: farmerUid)
      .snapshots()
      .map((s) => s.docs.map(FarmerAdvice.fromDoc).where((a) => includeTest || !a.testOnly).toList()
        ..sort((a, b) => (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0))));

  static Future<String> _myName() async {
    final user = FirebaseAuth.instance.currentUser!;
    try {
      final doc = await _db.collection('Users').doc(user.uid).get();
      final name = doc.data()?['fullName'] as String?;
      if (name != null && name.trim().isNotEmpty) return name.trim();
    } catch (_) {}
    return user.displayName ?? user.email ?? 'Field Agronomist';
  }

  static Map<String, dynamic> _write({
    required FarmerAdviceContent content,
    required FarmerAdviceStatus status,
    required int version,
    required String uid,
    required String name,
    required bool isNew,
    required bool notify,
    required bool wasSent,
  }) {
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
    if (isNew) data.addAll({'createdBy': uid, 'createdByName': name, 'createdAt': now});
    // Sending: the sender is recorded each time sent content changes.
    if (status == FarmerAdviceStatus.sent) {
      data.addAll({'sentBy': uid, 'sentByName': name, 'sentAt': now});
      if (!wasSent || notify) data['notifyVersion'] = version;
    }
    return data;
  }

  static Map<String, dynamic> _history(int version, String action, FarmerAdviceStatus status, String uid,
          String name, FarmerAdviceContent content) =>
      {
        'version': version,
        'action': action,
        'status': status.name,
        'byUid': uid,
        'byName': name,
        'at': FieldValue.serverTimestamp(),
        'snapshot': content.toMap(),
      };

  /// Creates or changes ONE farmer's advice. [expectedVersion] guards against
  /// overwriting someone else's edit (throws [AdvisoryConflictException]).
  /// Sent advice that changes only re-notifies the farmer when [notify].
  static Future<String> save({
    String? id,
    int? expectedVersion,
    required FarmerAdviceContent content,
    required FarmerAdviceStatus status,
    required String action,
    bool notify = false,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final name = await _myName();
    final ref = id == null ? _advice.doc() : _advice.doc(id);
    await _db.runTransaction((tx) async {
      final current = id == null ? null : await tx.get(ref);
      if (id != null && !(current?.exists ?? false)) {
        throw StateError('This advice no longer exists.');
      }
      final currentVersion = (current?.data()?['version'] as num?)?.toInt() ?? 0;
      if (expectedVersion != null && currentVersion != expectedVersion) {
        throw const AdvisoryConflictException();
      }
      final version = currentVersion + 1;
      final data = _write(
        content: content,
        status: status,
        version: version,
        uid: uid,
        name: name,
        isNew: current == null,
        notify: notify,
        wasSent: current?.data()?['status'] == FarmerAdviceStatus.sent.name,
      );
      current == null ? tx.set(ref, data) : tx.update(ref, data);
      tx.set(ref.collection('history').doc('v$version'), _history(version, action, status, uid, name, content));
    });
    return ref.id;
  }

  /// The same new advice for several farmers: one document each (so every
  /// farmer's copy, answers and withdrawal are their own), linked by batchId.
  static Future<List<String>> createForMany({
    required FarmerAdviceContent content,
    required List<AdviceTarget> farmers,
    required FarmerAdviceStatus status,
  }) async {
    if (farmers.length == 1) {
      final t = farmers.single;
      return [
        await save(
          content: content.forFarmer(t.uid, t.name),
          status: status,
          action: status == FarmerAdviceStatus.sent ? 'sent' : 'created',
        ),
      ];
    }
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final name = await _myName();
    final batchId = _advice.doc().id;
    final ids = <String>[];
    // Two writes per farmer (advice + its audit entry); stay under 500.
    for (var i = 0; i < farmers.length; i += 200) {
      final batch = _db.batch();
      for (final t in farmers.skip(i).take(200)) {
        final c = FarmerAdviceContent(
          farmerUid: t.uid,
          farmerName: t.name,
          title: content.title,
          advice: content.advice,
          crops: content.crops,
          actions: content.actions,
          basedOn: content.basedOn,
          batchId: batchId,
          testOnly: content.testOnly,
        );
        final ref = _advice.doc();
        ids.add(ref.id);
        batch.set(ref, _write(
          content: c, status: status, version: 1, uid: uid, name: name,
          isNew: true, notify: false, wasSent: false,
        ));
        batch.set(ref.collection('history').doc('v1'),
            _history(1, status == FarmerAdviceStatus.sent ? 'sent' : 'created', status, uid, name, c));
      }
      await batch.commit();
    }
    return ids;
  }

  static Future<void> changeStatus(FarmerAdvice a, FarmerAdviceStatus status, String action) => save(
        id: a.id,
        expectedVersion: a.version,
        content: a.content,
        status: status,
        action: action,
      );

  /// Only never-sent drafts can be deleted (with their history).
  static Future<void> deleteDraft(String id) async {
    final ref = _advice.doc(id);
    final history = await ref.collection('history').get();
    final batch = _db.batch();
    for (final h in history.docs) {
      batch.delete(h.reference);
    }
    batch.delete(ref);
    await batch.commit();
  }

  // ── AI drafting ──────────────────────────────────────────────────────────

  /// A short, factual summary of a farmer's records for the AI prompt.
  static String farmerContext(FarmerRecord r, {int maxIssues = 12}) {
    final b = StringBuffer();
    b.writeln('Location: ${r.place.isEmpty ? 'Kenya' : '${r.place}, Kenya'}');
    for (final p in r.latestPlots.take(6)) {
      final crops = p.crops.map((c) => c.stage.isEmpty ? c.type : '${c.type} (${c.stage})').join(', ');
      final soil = p.npk.entries
          .map((e) => '${e.key} ${e.value.toStringAsFixed(0)}${p.bands[e.key] != null ? ' (${p.bands[e.key]!.label})' : ''}')
          .join(', ');
      b.writeln('Plot ${p.plot}: ${crops.isEmpty ? 'no crop recorded' : crops}'
          '${p.area != null ? ', ${p.area!.toStringAsFixed(1)} acres' : ''}'
          '${soil.isEmpty ? '' : '; soil test $soil'}');
    }
    final recent = r.issues.take(maxIssues).toList();
    if (recent.isNotEmpty) {
      b.writeln('Recent pest / disease reports (newest first):');
      for (final i in recent) {
        final d = i.at;
        b.writeln('- ${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
            '${i.type}: ${i.label}${i.crop.isEmpty ? '' : ' on ${i.crop}'}'
            '${i.stage.isEmpty ? '' : ' (${i.stage})'}'
            '${i.confidence != null ? ', photo ID ${i.confidence} confidence' : ''}'
            '${i.intervention != null ? ', farmer did: ${i.intervention}' : ''}');
      }
    }
    return b.toString();
  }

  /// Asks Gemini for a draft of custom advice; the agronomist reviews it.
  static Future<({StructuredAdvice advice, String raw})> aiDraft({
    required String farmerContext,
    required List<String> crops,
    String focus = '',
  }) async {
    final prompt = '''
You are drafting farm advice for ONE smallholder farmer in Kenya, from their own farm records. A qualified Field Agronomist will review and edit your draft before the farmer sees it, so be accurate and conservative.

Farmer's records:
$farmerContext
Crop(s) to advise on: ${crops.isEmpty ? 'the crops in the records' : crops.join(', ')}
${focus.trim().isEmpty ? 'Focus: the most important problem in these records.' : 'Focus: ${focus.trim()}'}

Reply in EXACTLY this format (plain text, no markdown):
MAIN: <one short action, max 12 words>
DO:
- <action>
- <action>
AVOID:
- <action>
WHY: <one short sentence, referring to what the records show>
PESTS:
- <pest name> — <signs to look for> — <what to do if found>
DISEASES:
- <disease name> — <signs to look for> — <what to do if found>
SOIL:
- <N|P|K|pH|general> | Stage: <crop growth stage, or "any"> | Low: <action> | Moderate: <action> | High: <action>

Rules:
- Base the advice on the records above; mention repeated or unresolved problems.
- If a problem is unidentified, tell the farmer how to confirm it (what to look for, take a clear photo, isolate affected plants).
- DO and AVOID: max 3 bullets each, short phrases starting with a verb.
- PESTS / DISEASES: at most 3 each; write "none" if none apply.
- SOIL: only if the soil test or crop stage calls for it; give rates per acre; else "none".
- No chemical brand names; name active ingredients only if essential.
- Do not invent numbers you were not given.
''';
    final res = await http
        .post(Uri.parse(_kAskGeminiUrl), headers: await authJsonHeaders(), body: jsonEncode({'prompt': prompt}))
        .timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) throw Exception('AI draft failed (HTTP ${res.statusCode})');
    final raw = AgronomicAdvisoryService.aiReplyText(jsonDecode(res.body));
    final advice = parseStructuredAdvice(raw);
    if (advice == null) throw Exception('AI returned an empty draft');
    return (advice: advice, raw: raw);
  }
}
