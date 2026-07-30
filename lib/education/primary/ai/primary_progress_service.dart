// lib/education/primary/primary_progress_service.dart
// Handles reading and writing student activity progress to Firestore.
// Schema: primaryProgress/{uid}/sessions/{dateStr}
//   { quizScores: {topic: [scores]}, completions: {topic: count},
//     spotMistakes: {topic: correct}, fillBlanks: {topic: correct},
//     whatAmI: {topic: stars}, updatedAt: Timestamp }
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PrimaryProgressService {
  static final _db = FirebaseFirestore.instance;

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ── Record a quiz result ───────────────────────────────────────────────
  static Future<void> recordQuizScore({
    required String topic,
    required int score,
    required int total,
  }) async {
    final uid = _uid; if (uid == null) return;
    final pct = (score / total * 100).round();
    try {
      await _db.collection('primaryProgress').doc(uid)
          .collection('sessions').doc(_today())
          .set({
            'quizScores.$topic': FieldValue.arrayUnion([pct]),
            'completions.$topic': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) { /* silent fail — never block the UI */ }
  }

  // ── Record spot-mistake result ─────────────────────────────────────────
  static Future<void> recordSpotMistake({required String topic, required bool correct}) async {
    final uid = _uid; if (uid == null) return;
    try {
      await _db.collection('primaryProgress').doc(uid)
          .collection('sessions').doc(_today())
          .set({
            'spotMistakes.$topic': FieldValue.increment(correct ? 1 : 0),
            'completions.$topic': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (_) {}
  }

  // ── Record fill-blank result ───────────────────────────────────────────
  static Future<void> recordFillBlank({required String topic, required bool correct}) async {
    final uid = _uid; if (uid == null) return;
    try {
      await _db.collection('primaryProgress').doc(uid)
          .collection('sessions').doc(_today())
          .set({
            'fillBlanks.$topic': FieldValue.increment(correct ? 1 : 0),
            'completions.$topic': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (_) {}
  }

  // ── Record "What am I?" stars ──────────────────────────────────────────
  static Future<void> recordWhatAmI({required String topic, required int stars}) async {
    final uid = _uid; if (uid == null) return;
    try {
      await _db.collection('primaryProgress').doc(uid)
          .collection('sessions').doc(_today())
          .set({
            'whatAmI.$topic': FieldValue.increment(stars),
            'completions.$topic': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (_) {}
  }

  // ── Read today's totals for home screen banner ─────────────────────────
  static Future<Map<String, dynamic>> getTodaySummary() async {
    final uid = _uid; if (uid == null) return {};
    try {
      final snap = await _db.collection('primaryProgress').doc(uid)
          .collection('sessions').doc(_today()).get();
      return snap.data() ?? {};
    } catch (_) { return {}; }
  }

  // ── Read last 7 days of scores by topic (for teacher summary) ─────────
  static Future<Map<String, Map<String, dynamic>>> getWeeklySummaryForClass({
    required String classId,
    required String schoolName,
  }) async {
    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day - 6);
    final Map<String, List<int>>   scoresByTopic = {};
    final Map<String, int>         completionsByTopic = {};

    try {
      // Get all students in this class
      final students = await _db.collection('EducationUsers')
          .where('currentClassId', isEqualTo: classId)
          .where('schoolName', isEqualTo: schoolName)
          .where('role', isEqualTo: 'student')
          .limit(60)
          .get();

      for (final student in students.docs) {
        final sessions = await _db.collection('primaryProgress').doc(student.id)
            .collection('sessions')
            .where(FieldPath.documentId, isGreaterThanOrEqualTo:
                '${cutoff.year}-${cutoff.month.toString().padLeft(2, '0')}-${cutoff.day.toString().padLeft(2, '0')}')
            .get();

        for (final session in sessions.docs) {
          final data = session.data();
          final quizScores = data['quizScores'] as Map<String, dynamic>? ?? {};
          final completions = data['completions'] as Map<String, dynamic>? ?? {};

          quizScores.forEach((topic, scores) {
            scoresByTopic.putIfAbsent(topic, () => []);
            if (scores is List) scoresByTopic[topic]!.addAll(scores.cast<int>());
          });
          completions.forEach((topic, value) {
            completionsByTopic[topic] = (completionsByTopic[topic] ?? 0) + (value as int);
          });
        }
      }
    } catch (_) {}

    final result = <String, Map<String, dynamic>>{};
    final allTopics = {...scoresByTopic.keys, ...completionsByTopic.keys};
    for (final topic in allTopics) {
      final scores = scoresByTopic[topic] ?? [];
      final avg = scores.isEmpty ? 0 : (scores.reduce((a, b) => a + b) / scores.length).round();
      result[topic] = {
        'quizAvg':     avg,
        'completions': completionsByTopic[topic] ?? 0,
      };
    }
    return result;
  }

  // ── Read per-student scores for teacher hint ───────────────────────────
  static Future<Map<String, int>> getStudentWeeklyScores(String studentUid) async {
    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day - 6);
    final Map<String, List<int>> raw = {};
    try {
      final sessions = await _db.collection('primaryProgress').doc(studentUid)
          .collection('sessions')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo:
              '${cutoff.year}-${cutoff.month.toString().padLeft(2, '0')}-${cutoff.day.toString().padLeft(2, '0')}')
          .get();
      for (final s in sessions.docs) {
        final quizScores = s.data()['quizScores'] as Map<String, dynamic>? ?? {};
        quizScores.forEach((topic, scores) {
          raw.putIfAbsent(topic, () => []);
          if (scores is List) raw[topic]!.addAll(scores.cast<int>());
        });
      }
    } catch (_) {}
    return raw.map((t, scores) =>
        MapEntry(t, scores.isEmpty ? 0 : (scores.reduce((a, b) => a + b) / scores.length).round()));
  }
}