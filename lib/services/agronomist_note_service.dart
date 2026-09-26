// lib/services/agronomist_note_service.dart
//
// Loads the latest published KALRO / field agronomist note for the weather
// screen. Prefers a note scoped to [gatewayId]; falls back to a global note
// for the same platform.
//
// ── Fixed ────────────────────────────────────────────────────────────────
// Previously ran two separate queries, the second using
// `.where('gatewayId', isNull: true)` to find "global" notes. Firestore's
// isNull only matches documents where the field is PRESENT and set to
// null — a document that simply omits gatewayId (e.g. typed in the console
// without that field) silently never matches, so the note would never show
// up as global even though it obviously should. Fixed by running one query
// (published + platform) and picking the right note client-side, where
// "global" means gatewayId is null OR the field was never set — both
// already collapse to `null` on the AgronomistNote model, so this is a
// single, reliable check instead of a second, fragile Firestore query.
// This also means only ONE composite index is needed now, not two.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kilimomkononi/models/agronomist_note.dart';

class AgronomistNoteService {
  AgronomistNoteService._();

  static final _col = FirebaseFirestore.instance.collection('agronomist_notes');

  /// Latest published note for Kilimo Mkononi ("km").
  /// Pass the selected NuaSense gateway id when available.
  static Future<AgronomistNote?> getLatestForStation({
    String? gatewayId,
    String platform = 'km',
  }) async {
    try {
      final snap = await _col
          .where('published', isEqualTo: true)
          .where('platform', whereIn: [platform, 'both'])
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      if (snap.docs.isEmpty) return null;

      final notes = snap.docs.map(AgronomistNote.fromDoc).toList();

      // 1) Prefer a note scoped to this exact station.
      if (gatewayId != null && gatewayId.isNotEmpty) {
        for (final n in notes) {
          if (n.gatewayId == gatewayId) return n;
        }
      }

      // 2) Otherwise the most recent global note. `gatewayId == null`
      // covers both an explicit `null` and a document that never set the
      // field at all — AgronomistNote.fromDoc already normalizes both to
      // null, so this one check is all that's needed.
      for (final n in notes) {
        if (n.gatewayId == null || n.gatewayId!.isEmpty) return n;
      }

      return null;
    } catch (e) {
      // Missing composite index or offline — fail soft. If notes aren't
      // showing up during testing and nothing else looks wrong, check the
      // debug console for this line — it usually contains a direct link to
      // create the missing index.
      assert(() {
        // ignore: avoid_print
        print('[AgronomistNoteService] $e');
        return true;
      }());
      return null;
    }
  }
}