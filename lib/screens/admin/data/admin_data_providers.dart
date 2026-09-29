// lib/screens/admin/data/admin_data_providers.dart
//
// Riverpod state for the admin record screens (AdminCollectionScreen):
//
//   adminDocsProvider(col)     live documents, newest first, paged ("load
//                              more" raises adminLimitProvider(col))
//   adminQueryProvider(col)    search, filters, sort, selection, open record
//   adminViewProvider(col)     the filtered + sorted list, summary stats and
//                              filter options (computeAdminView — pure)
//   personNameProvider(uid)    "who is this uid" (Users / EducationUsers),
//                              cached
//   adminActionsProvider       edit (typed), delete, soft-delete/restore,
//                              disable/enable, reset password, approve/deny —
//                              each logged to admin_logs
//
// Plus value formatting and CSV export shared by the screen.

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kilimomkononi/screens/admin/admin_providers.dart' show collectionCountProvider;
import 'package:kilimomkononi/screens/admin/data/admin_collection_spec.dart';
import 'package:kilimomkononi/settings/notifications/notification_style.dart' show fullStamp;

const kAdminPageSize = 300;

// ═════════════════════════════════════════════════════════════════════════════
//  Loading
// ═════════════════════════════════════════════════════════════════════════════

class AdminLimit extends Notifier<int> {
  AdminLimit(this.collection);
  final String collection;
  @override
  int build() => kAdminPageSize;
  void more() => state += kAdminPageSize;
}

final adminLimitProvider = NotifierProvider.autoDispose.family<AdminLimit, int, String>(AdminLimit.new);

final adminDocsProvider = StreamProvider.autoDispose.family<List<AdminDoc>, String>((ref, collection) {
  final spec = specFor(collection);
  final limit = ref.watch(adminLimitProvider(collection));
  Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection(collection);
  // Order server-side only by a field every document has; otherwise Firestore
  // silently drops documents missing it (the old Users table did).
  if (spec.timeField != null && spec.serverOrder) q = q.orderBy(spec.timeField!, descending: true);
  return q.limit(limit).snapshots().map((s) => s.docs.map((d) => AdminDoc(d.id, d.data())).toList());
});

// ═════════════════════════════════════════════════════════════════════════════
//  Query state
// ═════════════════════════════════════════════════════════════════════════════

@immutable
class AdminQuery {
  final String search;
  final Map<String, String> filters; // filter key → selected value
  final String? sortKey;
  final bool ascending;
  final Set<String> selected;
  final String? openId;
  final bool tableView;

  const AdminQuery({
    this.search = '',
    this.filters = const {},
    this.sortKey,
    this.ascending = false,
    this.selected = const {},
    this.openId,
    this.tableView = false,
  });

  AdminQuery copyWith({
    String? search,
    Map<String, String>? filters,
    String? sortKey,
    bool? ascending,
    Set<String>? selected,
    String? Function()? openId,
    bool? tableView,
  }) =>
      AdminQuery(
        search: search ?? this.search,
        filters: filters ?? this.filters,
        sortKey: sortKey ?? this.sortKey,
        ascending: ascending ?? this.ascending,
        selected: selected ?? this.selected,
        openId: openId != null ? openId() : this.openId,
        tableView: tableView ?? this.tableView,
      );

  bool get selecting => selected.isNotEmpty;
  bool get hasFilters => search.isNotEmpty || filters.isNotEmpty;
}

class AdminQueryController extends Notifier<AdminQuery> {
  AdminQueryController(this.collection);
  final String collection;

  @override
  AdminQuery build() {
    final sorts = specFor(collection).sorts;
    return AdminQuery(
      sortKey: sorts.isEmpty ? null : sorts.first.key,
      // Newest-first for date sorts, A→Z / low→high otherwise.
      ascending: sorts.isNotEmpty && !_isDateSort(sorts.first),
    );
  }

  void search(String s) => state = state.copyWith(search: s);

  void setFilter(String key, String? value) {
    final f = Map<String, String>.from(state.filters);
    value == null ? f.remove(key) : f[key] = value;
    state = state.copyWith(filters: f);
  }

  void clearFilters() => state = state.copyWith(search: '', filters: const {});

  void sortBy(String key) {
    if (state.sortKey == key) {
      state = state.copyWith(ascending: !state.ascending);
    } else {
      final sort = specFor(collection).sorts.firstWhere((s) => s.key == key);
      state = state.copyWith(sortKey: key, ascending: !_isDateSort(sort));
    }
  }

  void toggleSelect(String id) {
    final s = Set<String>.from(state.selected);
    s.contains(id) ? s.remove(id) : s.add(id);
    state = state.copyWith(selected: s);
  }

  void selectAll(Iterable<String> ids) => state = state.copyWith(selected: {...ids});
  void clearSelection() => state = state.copyWith(selected: const {});
  void open(String? id) => state = state.copyWith(openId: () => id);
  void toggleTable() => state = state.copyWith(tableView: !state.tableView);
}

bool _isDateSort(AdminSort s) => s.valueOf(const AdminDoc('', {})) is DateTime;

final adminQueryProvider =
    NotifierProvider.autoDispose.family<AdminQueryController, AdminQuery, String>(AdminQueryController.new);

// ═════════════════════════════════════════════════════════════════════════════
//  View (pure)
// ═════════════════════════════════════════════════════════════════════════════

class AdminView {
  final List<AdminDoc> all;
  final List<AdminDoc> shown;
  final Map<String, List<(String, int)>> filterOptions; // key → (value, count)
  final Map<String, int> statusCounts; // status label → count (all loaded)
  final int addedLast7Days;
  final bool mayHaveMore;

  const AdminView({
    required this.all,
    required this.shown,
    required this.filterOptions,
    required this.statusCounts,
    required this.addedLast7Days,
    required this.mayHaveMore,
  });
}

bool _matchesSearch(AdminCollectionSpec spec, AdminDoc d, String q) {
  if (q.isEmpty) return true;
  final needle = q.toLowerCase();
  if (d.id.toLowerCase().contains(needle)) return true;
  if (spec.titleOf(d).toLowerCase().contains(needle)) return true;
  if (spec.subtitleOf(d).toLowerCase().contains(needle)) return true;
  for (final k in spec.searchKeys) {
    if (d.str(k).toLowerCase().contains(needle)) return true;
  }
  return false;
}

/// Filters, sorts and summarises [docs] for [query] (unit-tested).
AdminView computeAdminView(AdminCollectionSpec spec, List<AdminDoc> docs, AdminQuery query,
    {int limit = kAdminPageSize, DateTime? now}) {
  final n = now ?? DateTime.now();
  final filtered = docs.where((d) {
    if (!_matchesSearch(spec, d, query.search.trim())) return false;
    for (final e in query.filters.entries) {
      final f = spec.filters.where((x) => x.key == e.key).firstOrNull;
      if (f != null && !f.valuesOf(d).contains(e.value)) return false;
    }
    return true;
  }).toList();

  final sort = spec.sorts.where((s) => s.key == query.sortKey).firstOrNull;
  if (sort != null) {
    filtered.sort((a, b) {
      final c = sort.valueOf(a).compareTo(sort.valueOf(b));
      if (c != 0) return query.ascending ? c : -c;
      // Same value (e.g. everyone in the chosen county) → by name A→Z.
      return spec.titleOf(a).toLowerCase().compareTo(spec.titleOf(b).toLowerCase());
    });
  }

  // Options come from all loaded docs, counted within the other filters.
  final options = <String, List<(String, int)>>{};
  for (final f in spec.filters) {
    final counts = <String, int>{};
    for (final d in docs) {
      for (final v in f.valuesOf(d)) {
        counts[v] = (counts[v] ?? 0) + 1;
      }
    }
    final list = counts.entries.map((e) => (e.key, e.value)).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2) != 0 ? b.$2.compareTo(a.$2) : a.$1.compareTo(b.$1));
    options[f.key] = list.take(60).toList();
  }

  final statusCounts = <String, int>{};
  for (final d in docs) {
    final s = spec.statusOf(d);
    if (s != null) statusCounts[s.label] = (statusCounts[s.label] ?? 0) + 1;
  }
  final weekAgo = n.subtract(const Duration(days: 7));
  final recent = spec.timeField == null
      ? 0
      : docs.where((d) => d.time(spec.timeField)?.isAfter(weekAgo) ?? false).length;

  return AdminView(
    all: docs,
    shown: filtered,
    filterOptions: options,
    statusCounts: statusCounts,
    addedLast7Days: recent,
    mayHaveMore: docs.length >= limit,
  );
}

final adminViewProvider = Provider.autoDispose.family<AsyncValue<AdminView>, String>((ref, collection) {
  final spec = specFor(collection);
  final query = ref.watch(adminQueryProvider(collection));
  final limit = ref.watch(adminLimitProvider(collection));
  return ref.watch(adminDocsProvider(collection)).whenData((docs) => computeAdminView(spec, docs, query, limit: limit));
});

// ═════════════════════════════════════════════════════════════════════════════
//  People (uid → name)
// ═════════════════════════════════════════════════════════════════════════════

/// Name (and email) of a Users / EducationUsers account, cached per uid.
final personNameProvider = FutureProvider.family<String?, String>((ref, uid) async {
  if (uid.isEmpty) return null;
  final db = FirebaseFirestore.instance;
  for (final col in ['Users', 'EducationUsers']) {
    try {
      final d = await db.collection(col).doc(uid).get();
      final name = (d.data()?['fullName'] as String?)?.trim();
      if (d.exists && name != null && name.isNotEmpty) return name;
    } catch (_) {}
  }
  return null;
});

// ═════════════════════════════════════════════════════════════════════════════
//  Actions
// ═════════════════════════════════════════════════════════════════════════════

class AdminActions {
  AdminActions(this.ref);
  final Ref ref;

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  String? get _me => FirebaseAuth.instance.currentUser?.uid;

  Future<void> _log(String action) async {
    try {
      await _db.collection('admin_logs').add({'action': action, 'timestamp': Timestamp.now(), 'adminUid': _me});
      ref.invalidate(collectionCountProvider('admin_logs'));
    } catch (e) {
      debugPrint('[AdminActions] log failed: $e');
    }
  }

  Future<void> _batch(String collection, Iterable<String> ids, void Function(WriteBatch b, DocumentReference r) op) async {
    final list = ids.toList();
    for (var i = 0; i < list.length; i += 400) {
      final b = _db.batch();
      for (final id in list.skip(i).take(400)) {
        op(b, _db.collection(collection).doc(id));
      }
      await b.commit();
    }
  }

  /// Writes only the changed fields, keeping their types.
  Future<void> update(AdminCollectionSpec spec, String id, Map<String, dynamic> changes) async {
    if (changes.isEmpty) return;
    await _db.collection(spec.collection).doc(id).update(changes);
    await _log('Edited ${spec.singular} $id (${changes.keys.join(', ')})');
  }

  Future<void> delete(AdminCollectionSpec spec, Iterable<String> ids) async {
    await _batch(spec.collection, ids, (b, r) => b.delete(r));
    ref.invalidate(collectionCountProvider(spec.collection));
    await _log('Deleted ${ids.length} ${spec.singular}${ids.length == 1 ? '' : 's'} from ${spec.collection}: ${ids.take(5).join(', ')}');
  }

  Future<void> setDeleted(AdminCollectionSpec spec, Iterable<String> ids, bool deleted) async {
    await _batch(spec.collection, ids, (b, r) => b.update(r, {'isDeleted': deleted}));
    await _log('${deleted ? 'Soft-deleted' : 'Restored'} ${ids.length} ${spec.singular}(s) in ${spec.collection}');
  }

  Future<void> setDisabled(AdminCollectionSpec spec, Iterable<String> ids, bool disabled) async {
    await _batch(spec.collection, ids, (b, r) => b.update(r, {'isDisabled': disabled}));
    await _log('${disabled ? 'Disabled' : 'Enabled'} ${ids.length} account(s) in ${spec.collection}');
  }

  /// Sends reset links; returns how many were sent.
  Future<int> resetPasswords(Iterable<String> emails) async {
    var sent = 0;
    for (final e in emails.where((e) => e.trim().isNotEmpty)) {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: e.trim());
      sent++;
    }
    await _log('Sent $sent password reset link(s)');
    return sent;
  }

  /// Same write as the education approval chain (ApprovalManagementScreen).
  Future<void> decideEducation(AdminDoc d, {required bool approve}) async {
    final requested = d.str('requestedRole');
    if (approve && !const {'teacher', 'headteacher', 'student'}.contains(requested)) {
      throw StateError('This account has no valid requested role ($requested).');
    }
    await _db.collection('EducationUsers').doc(d.id).update({
      'approvalStatus': approve ? 'approved' : 'denied',
      if (approve) 'role': requested,
      'approvedBy': _me,
      'approvedAt': FieldValue.serverTimestamp(),
    });
    await _log('${approve ? 'Approved' : 'Denied'} education user ${d.id}');
  }
}

final adminActionsProvider = Provider<AdminActions>(AdminActions.new);

// ═════════════════════════════════════════════════════════════════════════════
//  Formatting & export
// ═════════════════════════════════════════════════════════════════════════════

/// Human-readable value for the detail view.
String formatAdminValue(dynamic v, {FieldKind kind = FieldKind.text, String? suffix}) {
  if (v == null || (v is String && v.trim().isEmpty)) return '—';
  if (v is Timestamp) return fullStamp(v.toDate());
  if (v is DateTime) return fullStamp(v);
  if (v is bool) return v ? 'Yes' : 'No';
  if (v is num) {
    final s = v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);
    return suffix == null ? s : (suffix == 'KES' ? 'KES $s' : '$s $suffix');
  }
  if (v is GeoPoint) return '${v.latitude.toStringAsFixed(5)}, ${v.longitude.toStringAsFixed(5)}';
  if (v is List) {
    if (v.isEmpty) return '—';
    return v.map((e) => e is Map ? _mapText(e) : formatAdminValue(e)).join('\n');
  }
  if (v is Map) return v.isEmpty ? '—' : _mapText(v);
  return '$v';
}

String _mapText(Map m) => m.entries.map((e) => '${e.key}: ${formatAdminValue(e.value)}').join(' · ');

/// Plain value for CSV cells.
String _csvValue(dynamic v) {
  if (v == null) return '';
  if (v is Timestamp) return v.toDate().toIso8601String();
  if (v is List || v is Map) {
    try {
      return jsonEncode(v, toEncodable: (o) => o is Timestamp ? o.toDate().toIso8601String() : '$o');
    } catch (_) {
      return '$v';
    }
  }
  return '$v';
}

String _csvCell(String s) =>
    s.contains(RegExp(r'[",\n\r]')) ? '"${s.replaceAll('"', '""')}"' : s;

/// CSV of [docs]: id + every field present (curated fields first).
String adminCsv(AdminCollectionSpec spec, List<AdminDoc> docs) {
  final keys = <String>[];
  for (final s in spec.sections) {
    for (final f in s.fields) {
      if (!keys.contains(f.key)) keys.add(f.key);
    }
  }
  for (final d in docs) {
    for (final k in d.data.keys) {
      if (!keys.contains(k) && k != spec.imageField) keys.add(k);
    }
  }
  final out = StringBuffer()..writeln(['id', ...keys].map(_csvCell).join(','));
  for (final d in docs) {
    out.writeln([d.id, ...keys.map((k) => _csvValue(d.data[k]))].map(_csvCell).join(','));
  }
  return out.toString();
}

/// Parses an edited text back to the field's type. Throws FormatException.
dynamic parseAdminEdit(AdminField f, String text, dynamic original) {
  switch (f.kind) {
    case FieldKind.number:
      final t = text.trim();
      if (t.isEmpty) return null;
      final n = num.tryParse(t);
      if (n == null) throw FormatException('${f.label} must be a number');
      // Keep ints as ints where the original was one.
      return (original is int && n % 1 == 0) ? n.toInt() : n;
    default:
      return text.trim();
  }
}

/// Only the fields whose value changed.
Map<String, dynamic> adminChanges(Map<String, dynamic> original, Map<String, dynamic> edited) => {
      for (final e in edited.entries)
        if (original[e.key] != e.value && !(original[e.key] == null && e.value == '')) e.key: e.value,
    };
