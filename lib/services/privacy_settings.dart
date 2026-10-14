// lib/services/privacy_settings.dart
//
// A farmer's privacy choices — privacySettings/{uid} (owner only in the
// rules; read by the Cloud Functions):
//
//   shareWithAgronomists   Field Agronomists may see this farmer's records
//                          (plots, soil tests, pests, diseases) to advise
//                          them. Missing = on. Off: the farmer is left out
//                          of the Agronomist panel (counted anonymously in
//                          trends only), agronomists aren't notified about
//                          their entries, and no custom advice can be sent.
//
// Kept in its own document rather than on Users/{uid}: the profile is saved
// with a full .set(), which would silently reset the choice.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrivacySettings {
  PrivacySettings._();

  static DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      FirebaseFirestore.instance.collection('privacySettings').doc(uid);

  static String? get _uid {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null; // Firebase not set up (tests)
    }
  }

  /// Live value for the signed-in farmer (true until they turn it off).
  static Stream<bool> watchSharing() {
    final uid = _uid;
    if (uid == null) return Stream.value(true);
    return _doc(uid).snapshots().map((s) => s.data()?['shareWithAgronomists'] != false);
  }

  static Future<void> setSharing(bool share) async {
    final uid = _uid;
    if (uid == null) return;
    await _doc(uid).set({
      'shareWithAgronomists': share,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── One-time notice on Home ──────────────────────────────────────────────

  static String _noticeKey(String uid) => 'km_agronomist_sharing_notice_$uid';

  /// Has this farmer been told (on this device) that agronomists can see
  /// their records?
  static Future<bool> noticeSeen() async {
    final uid = _uid;
    if (uid == null) return true;
    try {
      return (await SharedPreferences.getInstance()).getBool(_noticeKey(uid)) ?? false;
    } catch (_) {
      return true;
    }
  }

  static Future<void> markNoticeSeen() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await (await SharedPreferences.getInstance()).setBool(_noticeKey(uid), true);
    } catch (_) {}
  }
}
