// lib/education/primary/primary_daily_challenge_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'primary_ai_service.dart';

/// Generates one AI challenge per classId per day, caches it in Firestore
/// so all students in the class see the same challenge.
///
/// Schema: dailyChallenge/{classId}/{date}
///   { type, topic, emoji, title, subtitle, generatedAt }
class PrimaryDailyChallengeService {
  static final _db = FirebaseFirestore.instance;
  static const _service = PrimaryAiService();

  static const _topics = [
    'Seeds & Plants', 'Farming Tools', 'Weeds & Pests',
    'Farm Animals', 'Soil & Water', 'Buying & Selling',
  ];

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Returns today's challenge for [classId], generating and caching if needed.
  static Future<Map<String, String>?> getOrGenerate({
    required String classId,
    required String grade,
  }) async {
    final dateStr = _today();
    final docRef  = _db.collection('dailyChallenge').doc(classId)
                       .collection('days').doc(dateStr);

    // Try cache first
    try {
      final snap = await docRef.get();
      if (snap.exists) {
        final data = snap.data()!;
        return {
          'type':     data['type']     as String? ?? 'quiz',
          'topic':    data['topic']    as String? ?? 'Farm Animals',
          'emoji':    data['emoji']    as String? ?? '🌱',
          'title':    data['title']    as String? ?? "Today's Quiz",
          'subtitle': data['subtitle'] as String? ?? 'Test yourself!',
        };
      }
    } catch (_) {}

    // Generate new
    final challenge = await _service.generateDailyChallenge(
      grade: grade, topics: _topics);
    if (challenge == null) return _fallback();

    // Cache
    try {
      await docRef.set({
        ...challenge,
        'generatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    return challenge;
  }

  static Map<String, String> _fallback() => {
    'type':     'quiz',
    'topic':    'Farm Animals',
    'emoji':    '🐄',
    'title':    "Today's Quiz",
    'subtitle': 'Test what you know about farm animals!',
  };
}