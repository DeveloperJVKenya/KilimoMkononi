// lib/screens/admin/admin_providers.dart
//
// Riverpod state for the Admin Dashboard.
//
//   collectionCountProvider(col)  — Firestore count() aggregation: ONE small
//                                   read per statistic, instead of streaming
//                                   every document (the old cards downloaded
//                                   whole collections, incl. profile photos).
//   roleMembersProvider(role)     — who holds a role, with names.
//   userSearchProvider(query)     — find a user by name prefix, email or UID.
//   roleControllerProvider        — grant / revoke with loading + error state;
//                                   refreshes counts and member lists after.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Definitions ──────────────────────────────────────────────────────────────

/// A role granted by the existence of `{collection}/{uid}`.
class AdminRole {
  final String collection;
  final String label;
  final String description;
  final IconData icon;
  final List<Color> gradient;

  const AdminRole({
    required this.collection,
    required this.label,
    required this.description,
    required this.icon,
    required this.gradient,
  });
}

const kAdminRoles = <AdminRole>[
  AdminRole(
    collection: 'Admins',
    label: 'Admins',
    description: 'Full access to the admin dashboard and all data.',
    icon: Icons.admin_panel_settings_rounded,
    gradient: [Color(0xFF1B5E20), Color(0xFF43A047)],
  ),
  AdminRole(
    collection: 'Agronomists',
    label: 'Field Agronomists',
    description: 'Draft, verify and publish weather advice to farmers.',
    icon: Icons.fact_check_rounded,
    gradient: [Color(0xFF00695C), Color(0xFF26A69A)],
  ),
  AdminRole(
    collection: 'PriceAnalysts',
    label: 'Price Analysts',
    description: 'Reserved role — grants no app permissions yet.',
    icon: Icons.monetization_on_rounded,
    gradient: [Color(0xFFE65100), Color(0xFFFFA726)],
  ),
];

/// A statistic card: a Firestore collection with a friendly label.
class AdminStat {
  final String collection;
  final String label;
  final IconData icon;
  final Color color;
  const AdminStat(this.collection, this.label, this.icon, this.color);
}

const kAdminStats = <AdminStat>[
  AdminStat('Users', 'Farmers', Icons.people_alt_rounded, Color(0xFF2E7D32)),
  AdminStat(
    'EducationUsers',
    'Education users',
    Icons.school_rounded,
    Color(0xFF1565C0),
  ),
  AdminStat(
    'fielddata',
    'Field records',
    Icons.grass_rounded,
    Color(0xFF558B2F),
  ),
  AdminStat(
    'marketdata',
    'Market prices',
    Icons.storefront_rounded,
    Color(0xFFEF6C00),
  ),
  AdminStat(
    'pestinterventiondata',
    'Pest records',
    Icons.bug_report_rounded,
    Color(0xFFC62828),
  ),
  AdminStat(
    'diseaseinterventiondata',
    'Disease records',
    Icons.coronavirus_rounded,
    Color(0xFF6A1B9A),
  ),
  AdminStat(
    'agronomic_advisories',
    'Advisories',
    Icons.verified_rounded,
    Color(0xFF00695C),
  ),
  AdminStat(
    'supportMessages',
    'Support messages',
    Icons.support_agent_rounded,
    Color(0xFFB26A00),
  ),
  AdminStat(
    'admin_logs',
    'Admin logs',
    Icons.receipt_long_rounded,
    Color(0xFF455A64),
  ),
  AdminStat('User_logs', 'User logs', Icons.history_rounded, Color(0xFF546E7A)),
];

class AdminUserSummary {
  final String uid;
  final String name;
  final String email;
  const AdminUserSummary({
    required this.uid,
    required this.name,
    required this.email,
  });

  factory AdminUserSummary.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data() ?? const {};
    return AdminUserSummary(
      uid: d.id,
      name: (data['fullName'] as String?)?.trim().isNotEmpty == true
          ? (data['fullName'] as String).trim()
          : (data['name'] as String?) ?? 'Unnamed user',
      email: (data['email'] as String?) ?? '',
    );
  }

  String get initials {
    final parts = name
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : ''))
        .toUpperCase();
  }
}

// ── Providers ────────────────────────────────────────────────────────────────

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

/// Signed-in user's uid (overridable in tests).
final currentUidProvider = Provider<String?>(
  (ref) => FirebaseAuth.instance.currentUser?.uid,
);

/// Document count via aggregation (cheap). Refresh with ref.invalidate.
final collectionCountProvider = FutureProvider.autoDispose.family<int, String>((
  ref,
  collection,
) async {
  final snap = await ref
      .watch(firestoreProvider)
      .collection(collection)
      .count()
      .get();
  return snap.count ?? 0;
});

/// Members of a role, with names from the role doc or their Users profile.
final roleMembersProvider = FutureProvider.autoDispose
    .family<List<AdminUserSummary>, String>((ref, collection) async {
      final db = ref.watch(firestoreProvider);
      final roleDocs = (await db.collection(collection).get()).docs;
      final byUid = <String, AdminUserSummary>{};
      final missing = <String>[];
      for (final d in roleDocs) {
        final data = d.data();
        final name = data['name'] as String?;
        if (name != null && name.isNotEmpty) {
          byUid[d.id] = AdminUserSummary(
            uid: d.id,
            name: name,
            email: (data['email'] as String?) ?? '',
          );
        } else {
          missing.add(d.id);
        }
      }
      // Older role docs only have {added: true}: look names up, 30 at a time.
      for (var i = 0; i < missing.length; i += 30) {
        final part = missing.sublist(i, (i + 30).clamp(0, missing.length));
        final users = await db
            .collection('Users')
            .where(FieldPath.documentId, whereIn: part)
            .get();
        for (final u in users.docs) {
          byUid[u.id] = AdminUserSummary.fromDoc(u);
        }
        for (final uid in part) {
          byUid.putIfAbsent(
            uid,
            () => AdminUserSummary(uid: uid, name: 'Unknown user', email: ''),
          );
        }
      }
      return byUid.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    });

/// Find farmers by name prefix, exact email, or exact UID (max 20).
/// Firestore has no substring search, so names match from the start.
final userSearchProvider = FutureProvider.autoDispose
    .family<List<AdminUserSummary>, String>((ref, raw) async {
      final q = raw.trim();
      if (q.length < 2) return const [];
      final db = ref.watch(firestoreProvider);
      final users = db.collection('Users');
      final results = <String, AdminUserSummary>{};

      void addAll(QuerySnapshot<Map<String, dynamic>> s) {
        for (final d in s.docs) {
          results[d.id] = AdminUserSummary.fromDoc(d);
        }
      }

      if (q.contains('@')) {
        addAll(
          await users.where('email', isEqualTo: q.toLowerCase()).limit(5).get(),
        );
        if (q.toLowerCase() != q) {
          addAll(await users.where('email', isEqualTo: q).limit(5).get());
        }
      } else if (!q.contains(' ') && q.length >= 20) {
        final byId = await users.doc(q).get();
        if (byId.exists) results[byId.id] = AdminUserSummary.fromDoc(byId);
      }
      // Name prefix — try as typed and Capitalised (names are usually stored so).
      final variants = {q, q[0].toUpperCase() + q.substring(1)};
      for (final v in variants) {
        addAll(
          await users
              .orderBy('fullName')
              .startAt([v])
              .endAt(['$v'])
              .limit(20)
              .get(),
        );
      }
      return results.values.take(20).toList();
    });

/// Grants / revokes roles. `state` drives loading and error UI.
final roleControllerProvider = AsyncNotifierProvider<RoleController, void>(
  RoleController.new,
);

class RoleController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  FirebaseFirestore get _db => ref.read(firestoreProvider);

  Future<bool> assign(AdminRole role, AdminUserSummary user) => _run(() async {
    await _db.collection(role.collection).doc(user.uid).set({
      'added': true,
      'name': user.name,
      'email': user.email,
      'grantedBy': ref.read(currentUidProvider),
      'grantedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _log('Assigned ${role.label} role to ${user.name} (${user.uid})');
  }, role);

  Future<bool> revoke(AdminRole role, AdminUserSummary user) => _run(() async {
    if (role.collection == 'Admins' &&
        user.uid == ref.read(currentUidProvider)) {
      throw StateError("You can't remove your own admin access.");
    }
    await _db.collection(role.collection).doc(user.uid).delete();
    await _log('Removed ${role.label} role from ${user.name} (${user.uid})');
  }, role);

  Future<bool> _run(Future<void> Function() action, AdminRole role) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(action);
    // Counts and member lists are stale now either way.
    ref.invalidate(collectionCountProvider(role.collection));
    ref.invalidate(roleMembersProvider(role.collection));
    ref.invalidate(collectionCountProvider('admin_logs'));
    return !state.hasError;
  }

  Future<void> _log(String action) async {
    try {
      await _db.collection('admin_logs').add({
        'action': action,
        'timestamp': Timestamp.now(),
        'adminUid': ref.read(currentUidProvider),
      });
    } catch (_) {}
  }
}
