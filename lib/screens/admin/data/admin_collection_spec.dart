// lib/screens/admin/data/admin_collection_spec.dart
//
// How each admin-managed Firestore collection is shown and managed: its
// title/subtitle, the fields in the detail view (and which are editable, with
// their real types — numbers stay numbers, yes/no stays a boolean), the
// filters, sort options, status badge and the actions allowed.
//
// One spec per dashboard card; AdminCollectionScreen renders any of them.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// A loaded document.
class AdminDoc {
  final String id;
  final Map<String, dynamic> data;
  const AdminDoc(this.id, this.data);

  dynamic operator [](String key) => data[key];

  String str(String key) {
    final v = data[key];
    return v == null ? '' : '$v'.trim();
  }

  DateTime? time(String? key) {
    if (key == null) return null;
    final v = data[key];
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}

enum FieldKind { text, multiline, number, boolean, choice, timestamp, list, map, user }

class AdminField {
  final String key;
  final String label;
  final FieldKind kind;
  final bool editable;
  final List<String> choices;
  final String? suffix; // e.g. "KES"

  const AdminField(this.key, this.label,
      {this.kind = FieldKind.text, this.editable = false, this.choices = const [], this.suffix});
}

class AdminSection {
  final String title;
  final IconData icon;
  final List<AdminField> fields;
  const AdminSection(this.title, this.icon, this.fields);
}

/// A filter chip. [valuesOf] extracts the value(s) a document has for it
/// (a list for multi-valued fields such as a plot's crops).
class AdminFilter {
  final String key;
  final String label;
  final Iterable<String> Function(AdminDoc d) valuesOf;
  const AdminFilter(this.key, this.label, this.valuesOf);

  static AdminFilter field(String key, String label) =>
      AdminFilter(key, label, (d) => [if (d.str(key).isNotEmpty) d.str(key)]);
}

class AdminSort {
  final String key;
  final String label;
  final Comparable Function(AdminDoc d) valueOf;
  const AdminSort(this.key, this.label, this.valueOf);
}

class AdminStatus {
  final String label;
  final Color color;
  const AdminStatus(this.label, this.color);
}

enum AdminAction {
  edit,
  delete,
  softDelete, // isDeleted: true / false (restore)
  disable, // isDisabled: true / false (enable)
  resetPassword,
  approve, // EducationUsers
  deny,
  openAgronomistPanel,
}

class AdminCollectionSpec {
  final String collection;
  final String title;
  final String singular;
  final IconData icon;
  final Color color;

  /// Field used for ordering by newest and the "added in 7 days" stat.
  final String? timeField;

  /// Order by [timeField] in Firestore. Only safe when EVERY document has the
  /// field — Firestore silently leaves out documents that lack it. Otherwise
  /// the newest-first order is applied on the device.
  final bool serverOrder;

  /// Field holding the owning farmer's uid (shown as their name).
  final String? userIdField;

  final String Function(AdminDoc d) titleOf;
  final String Function(AdminDoc d) subtitleOf;
  final List<String> Function(AdminDoc d) chipsOf;
  final AdminStatus? Function(AdminDoc d) statusOf;
  final List<String> searchKeys;
  final List<AdminFilter> filters;
  final List<AdminSort> sorts;
  final List<AdminSection> sections;
  final Set<AdminAction> actions;
  final List<String> tableColumns;

  /// An avatar image (base64) field, e.g. Users.profileImage.
  final String? imageField;

  const AdminCollectionSpec({
    required this.collection,
    required this.title,
    required this.singular,
    required this.icon,
    required this.color,
    required this.titleOf,
    required this.subtitleOf,
    required this.chipsOf,
    required this.statusOf,
    required this.searchKeys,
    required this.filters,
    required this.sorts,
    required this.sections,
    required this.actions,
    required this.tableColumns,
    this.timeField,
    this.serverOrder = true,
    this.userIdField,
    this.imageField,
  });

  bool can(AdminAction a) => actions.contains(a);

  Iterable<AdminField> get editableFields => sections.expand((s) => s.fields).where((f) => f.editable);

  /// Keys shown in the curated sections (the rest appear under "Other data").
  Set<String> get knownKeys => {for (final s in sections) ...s.fields.map((f) => f.key), ?imageField};
}

// ── Helpers ──────────────────────────────────────────────────────────────────

const _green = Color(0xFF2E7D32);
const _red = Color(0xFFC62828);
const _amber = Color(0xFFEF6C00);
const _grey = Color(0xFF607D8B);
const _blue = Color(0xFF1565C0);

AdminStatus? _activeStatus(AdminDoc d) =>
    d['isDisabled'] == true ? const AdminStatus('Disabled', _red) : const AdminStatus('Active', _green);

AdminStatus? _deletedStatus(AdminDoc d) =>
    d['isDeleted'] == true ? const AdminStatus('Deleted', _red) : const AdminStatus('Active', _green);

final _statusFilter = AdminFilter('isDisabled', 'Status', (d) => [d['isDisabled'] == true ? 'Disabled' : 'Active']);
final _deletedFilter = AdminFilter('isDeleted', 'Record', (d) => [d['isDeleted'] == true ? 'Deleted' : 'Active']);

AdminSort _byText(String key, String label) => AdminSort(key, label, (d) => d.str(key).toLowerCase());
AdminSort _byTime(String key, String label) =>
    AdminSort(key, label, (d) => d.time(key) ?? DateTime.fromMillisecondsSinceEpoch(0));
AdminSort _byNum(String key, String label) => AdminSort(key, label, (d) => (d[key] as num?) ?? -1);

String _money(dynamic v) => v is num ? 'KES ${v.toStringAsFixed(v % 1 == 0 ? 0 : 2)}' : '—';

List<String> _crops(AdminDoc d) => [
      for (final c in (d['crops'] as List?) ?? const [])
        if (c is Map && '${c['type'] ?? ''}'.trim().isNotEmpty) '${c['type']}'.trim(),
    ];

// ── Specs ────────────────────────────────────────────────────────────────────

final kAdminSpecs = <String, AdminCollectionSpec>{
  'Users': AdminCollectionSpec(
    collection: 'Users',
    title: 'Farmers',
    singular: 'farmer',
    icon: Icons.people_alt_rounded,
    color: const Color(0xFF2E7D32),
    imageField: 'profileImage',
    titleOf: (d) => d.str('fullName').isEmpty ? 'Unnamed farmer' : d.str('fullName'),
    subtitleOf: (d) => d.str('email'),
    chipsOf: (d) => [
      if (d.str('county').isNotEmpty) d.str('county'),
      if (d.str('ward').isNotEmpty) d.str('ward'),
      if (d.str('phoneNumber').isNotEmpty) d.str('phoneNumber'),
      if (d.str('signUpMethod') == 'google') 'Google sign-up',
    ],
    statusOf: _activeStatus,
    searchKeys: const ['fullName', 'email', 'phoneNumber', 'county', 'constituency', 'ward'],
    filters: [
      _statusFilter,
      AdminFilter.field('county', 'County'),
      AdminFilter.field('constituency', 'Constituency'),
      AdminFilter.field('ward', 'Ward'),
      AdminFilter('signUpMethod', 'Sign-up', (d) => [d.str('signUpMethod') == 'google' ? 'Google' : 'Email']),
    ],
    sorts: [
      _byText('fullName', 'Name'),
      _byText('county', 'County'),
      _byText('constituency', 'Constituency'),
      _byText('ward', 'Ward'),
      _byTime('termsAcceptedAt', 'Joined'),
    ],
    sections: const [
      AdminSection('Contact', Icons.contact_mail_rounded, [
        AdminField('fullName', 'Full name', editable: true),
        AdminField('email', 'Email'),
        AdminField('phoneNumber', 'Phone', editable: true),
      ]),
      AdminSection('Farm location', Icons.place_rounded, [
        AdminField('county', 'County', editable: true),
        AdminField('constituency', 'Constituency', editable: true),
        AdminField('ward', 'Ward', editable: true),
      ]),
      AdminSection('Account', Icons.verified_user_rounded, [
        AdminField('isDisabled', 'Disabled', kind: FieldKind.boolean),
        AdminField('signUpMethod', 'Sign-up method'),
        AdminField('termsAcceptedAt', 'Accepted terms', kind: FieldKind.timestamp),
        AdminField('createdAt', 'Created', kind: FieldKind.timestamp),
      ]),
    ],
    actions: const {AdminAction.edit, AdminAction.disable, AdminAction.resetPassword, AdminAction.delete},
    tableColumns: const ['fullName', 'email', 'phoneNumber', 'county', 'constituency', 'ward'],
  ),
  'EducationUsers': AdminCollectionSpec(
    collection: 'EducationUsers',
    title: 'Education users',
    singular: 'education user',
    icon: Icons.school_rounded,
    color: const Color(0xFF1565C0),
    timeField: 'createdAt',
    serverOrder: false, // older accounts may predate createdAt
    titleOf: (d) => d.str('fullName').isEmpty ? 'Unnamed user' : d.str('fullName'),
    subtitleOf: (d) => [d.str('email'), d.str('schoolName')].where((s) => s.isNotEmpty).join(' · '),
    chipsOf: (d) => [
      if (d.str('role').isNotEmpty) 'Role: ${d.str('role')}' else if (d.str('requestedRole').isNotEmpty) 'Requested: ${d.str('requestedRole')}',
      if (d.str('currentClassId').isNotEmpty) d.str('currentClassId'),
    ],
    statusOf: (d) {
      if (d['isDisabled'] == true) return const AdminStatus('Disabled', _red);
      return switch (d.str('approvalStatus')) {
        'approved' => const AdminStatus('Approved', _green),
        'denied' => const AdminStatus('Denied', _red),
        _ => const AdminStatus('Pending', _amber),
      };
    },
    searchKeys: const ['fullName', 'email', 'schoolName', 'schoolCode', 'phone'],
    filters: [
      AdminFilter('approvalStatus', 'Approval', (d) => [d.str('approvalStatus').isEmpty ? 'pending' : d.str('approvalStatus')]),
      AdminFilter.field('role', 'Role'),
      AdminFilter.field('requestedRole', 'Requested role'),
      AdminFilter.field('schoolName', 'School'),
      _statusFilter,
    ],
    sorts: [
      _byTime('createdAt', 'Newest'),
      _byText('fullName', 'Name'),
      _byText('schoolName', 'School'),
      _byText('approvalStatus', 'Approval'),
    ],
    sections: const [
      AdminSection('Contact', Icons.contact_mail_rounded, [
        AdminField('fullName', 'Full name', editable: true),
        AdminField('email', 'Email'),
        AdminField('phone', 'Phone', editable: true),
      ]),
      AdminSection('School', Icons.account_balance_rounded, [
        AdminField('schoolName', 'School'),
        AdminField('schoolCode', 'School code'),
        AdminField('currentClassId', 'Current class'),
        AdminField('classIds', 'Classes', kind: FieldKind.list),
        AdminField('educationTiers', 'Tiers', kind: FieldKind.list),
      ]),
      AdminSection('Approval', Icons.how_to_reg_rounded, [
        AdminField('approvalStatus', 'Status'),
        AdminField('requestedRole', 'Requested role'),
        AdminField('role', 'Role'),
        AdminField('approvedBy', 'Decided by', kind: FieldKind.user),
        AdminField('approvedAt', 'Decided at', kind: FieldKind.timestamp),
        AdminField('isDisabled', 'Disabled', kind: FieldKind.boolean),
        AdminField('createdAt', 'Registered', kind: FieldKind.timestamp),
      ]),
    ],
    actions: const {
      AdminAction.approve, AdminAction.deny, AdminAction.edit, AdminAction.disable,
      AdminAction.resetPassword, AdminAction.delete,
    },
    tableColumns: const ['fullName', 'email', 'schoolName', 'requestedRole', 'role', 'approvalStatus'],
  ),
  'fielddata': AdminCollectionSpec(
    collection: 'fielddata',
    title: 'Field records',
    singular: 'field record',
    icon: Icons.grass_rounded,
    color: const Color(0xFF558B2F),
    timeField: 'timestamp',
    userIdField: 'userId',
    titleOf: (d) => _crops(d).isEmpty ? 'Plot ${d.str('plotId')}' : _crops(d).join(', '),
    subtitleOf: (d) => 'Plot ${d.str('plotId').isEmpty ? '—' : d.str('plotId')}',
    chipsOf: (d) => [
      if (d['area'] is num) '${d['area']} acres',
      if (d.str('structureType').isNotEmpty) d.str('structureType'),
      if (d['npk'] is Map) 'NPK ${(d['npk'] as Map)['N'] ?? '-'}/${(d['npk'] as Map)['P'] ?? '-'}/${(d['npk'] as Map)['K'] ?? '-'}',
    ],
    statusOf: (_) => null,
    searchKeys: const ['plotId', 'structureType', 'fertilizerRecommendation', 'userId'],
    filters: [
      AdminFilter('crop', 'Crop', _crops),
      AdminFilter.field('structureType', 'Structure'),
      AdminFilter.field('plotId', 'Plot'),
    ],
    sorts: [_byTime('timestamp', 'Newest'), _byNum('area', 'Area'), _byText('plotId', 'Plot')],
    sections: const [
      AdminSection('Plot', Icons.crop_square_rounded, [
        AdminField('userId', 'Farmer', kind: FieldKind.user),
        AdminField('plotId', 'Plot'),
        AdminField('crops', 'Crops', kind: FieldKind.list),
        AdminField('area', 'Area', kind: FieldKind.number, editable: true, suffix: 'acres'),
        AdminField('structureType', 'Structure', editable: true),
        AdminField('timestamp', 'Recorded', kind: FieldKind.timestamp),
      ]),
      AdminSection('Soil & nutrients', Icons.science_rounded, [
        AdminField('npk', 'N / P / K', kind: FieldKind.map),
        AdminField('microNutrients', 'Micronutrients', kind: FieldKind.list),
        AdminField('fertilizerRecommendation', 'Fertiliser recommendation', kind: FieldKind.multiline, editable: true),
      ]),
      AdminSection('Activity', Icons.event_note_rounded, [
        AdminField('interventions', 'Interventions', kind: FieldKind.list),
        AdminField('reminders', 'Reminders', kind: FieldKind.list),
      ]),
    ],
    actions: const {AdminAction.edit, AdminAction.delete},
    tableColumns: const ['userId', 'plotId', 'crop', 'area', 'structureType', 'timestamp'],
  ),
  'marketdata': AdminCollectionSpec(
    collection: 'marketdata',
    title: 'Market prices',
    singular: 'price record',
    icon: Icons.storefront_rounded,
    color: const Color(0xFFEF6C00),
    timeField: 'timestamp',
    userIdField: 'userId',
    titleOf: (d) => '${d.str('cropType').isEmpty ? 'Crop' : d.str('cropType')} · ${d.str('market').isEmpty ? 'Market' : d.str('market')}',
    subtitleOf: (d) => d.str('region'),
    chipsOf: (d) => [
      'Retail ${_money(d['retailPrice'])}',
      if (d['predictedPrice'] is num) 'Predicted ${_money(d['predictedPrice'])}',
    ],
    statusOf: (_) => null,
    searchKeys: const ['cropType', 'market', 'region'],
    filters: [
      AdminFilter.field('cropType', 'Crop'),
      AdminFilter.field('market', 'Market'),
      AdminFilter.field('region', 'Region'),
    ],
    sorts: [
      _byTime('timestamp', 'Newest'),
      _byNum('retailPrice', 'Retail price'),
      _byNum('predictedPrice', 'Predicted price'),
      _byText('cropType', 'Crop'),
    ],
    sections: const [
      AdminSection('Price', Icons.payments_rounded, [
        AdminField('cropType', 'Crop', editable: true),
        AdminField('retailPrice', 'Retail price', kind: FieldKind.number, editable: true, suffix: 'KES'),
        AdminField('predictedPrice', 'Predicted price', kind: FieldKind.number, editable: true, suffix: 'KES'),
      ]),
      AdminSection('Where & when', Icons.place_rounded, [
        AdminField('market', 'Market', editable: true),
        AdminField('region', 'Region', editable: true),
        AdminField('timestamp', 'Recorded', kind: FieldKind.timestamp),
        AdminField('userId', 'Submitted by', kind: FieldKind.user),
      ]),
    ],
    actions: const {AdminAction.edit, AdminAction.delete},
    tableColumns: const ['cropType', 'market', 'region', 'retailPrice', 'predictedPrice', 'timestamp'],
  ),
  'pestinterventiondata': AdminCollectionSpec(
    collection: 'pestinterventiondata',
    title: 'Pest records',
    singular: 'pest record',
    icon: Icons.bug_report_rounded,
    color: const Color(0xFFC62828),
    timeField: 'timestamp',
    userIdField: 'userId',
    titleOf: (d) => '${d.str('pestName').isEmpty ? 'Pest' : d.str('pestName')} on ${d.str('cropType').isEmpty ? 'crop' : d.str('cropType')}',
    subtitleOf: (d) => d.str('intervention').isEmpty ? 'No intervention recorded' : d.str('intervention'),
    chipsOf: (d) => [
      if (d.str('cropStage').isNotEmpty) d.str('cropStage'),
      if (d.str('amount').isNotEmpty) 'Amount ${d.str('amount')}',
      if (d['area'] != null) 'Area ${d['area']} ${d.str('areaUnit')}',
    ],
    statusOf: _deletedStatus,
    searchKeys: const ['pestName', 'cropType', 'intervention', 'cropStage'],
    filters: [
      _deletedFilter,
      AdminFilter.field('pestName', 'Pest'),
      AdminFilter.field('cropType', 'Crop'),
      AdminFilter.field('cropStage', 'Stage'),
    ],
    sorts: [_byTime('timestamp', 'Newest'), _byText('pestName', 'Pest'), _byText('cropType', 'Crop')],
    sections: const [
      AdminSection('Pest', Icons.bug_report_rounded, [
        AdminField('pestName', 'Pest'),
        AdminField('cropType', 'Crop'),
        AdminField('cropStage', 'Crop stage', editable: true),
        AdminField('userId', 'Farmer', kind: FieldKind.user),
        AdminField('timestamp', 'Recorded', kind: FieldKind.timestamp),
      ]),
      AdminSection('Intervention', Icons.healing_rounded, [
        AdminField('intervention', 'Intervention', kind: FieldKind.multiline, editable: true),
        AdminField('amount', 'Amount', editable: true),
        AdminField('area', 'Area', kind: FieldKind.number, editable: true),
        AdminField('areaUnit', 'Area unit', editable: true),
        AdminField('isDeleted', 'Deleted by farmer', kind: FieldKind.boolean),
      ]),
    ],
    actions: const {AdminAction.edit, AdminAction.softDelete, AdminAction.delete},
    tableColumns: const ['userId', 'pestName', 'cropType', 'cropStage', 'intervention', 'timestamp'],
  ),
  'diseaseinterventiondata': AdminCollectionSpec(
    collection: 'diseaseinterventiondata',
    title: 'Disease records',
    singular: 'disease record',
    icon: Icons.coronavirus_rounded,
    color: const Color(0xFF6A1B9A),
    timeField: 'timestamp',
    userIdField: 'userId',
    titleOf: (d) =>
        '${d.str('diseaseName').isEmpty ? 'Disease' : d.str('diseaseName')} on ${d.str('cropType').isEmpty ? 'crop' : d.str('cropType')}',
    subtitleOf: (d) => d.str('intervention').isEmpty ? 'No intervention recorded' : d.str('intervention'),
    chipsOf: (d) => [
      if (d.str('cropStage').isNotEmpty) d.str('cropStage'),
      if (d['dosage'] != null) 'Dosage ${d['dosage']} ${d.str('unit')}',
      if (d.str('cycle').isNotEmpty) 'Cycle ${d.str('cycle')}',
    ],
    statusOf: _deletedStatus,
    searchKeys: const ['diseaseName', 'cropType', 'intervention', 'cropStage', 'cycle'],
    filters: [
      _deletedFilter,
      AdminFilter.field('diseaseName', 'Disease'),
      AdminFilter.field('cropType', 'Crop'),
      AdminFilter.field('cropStage', 'Stage'),
    ],
    sorts: [_byTime('timestamp', 'Newest'), _byText('diseaseName', 'Disease'), _byText('cropType', 'Crop')],
    sections: const [
      AdminSection('Disease', Icons.coronavirus_rounded, [
        AdminField('diseaseName', 'Disease'),
        AdminField('cropType', 'Crop'),
        AdminField('cropStage', 'Crop stage', editable: true),
        AdminField('cycle', 'Cycle', editable: true),
        AdminField('userId', 'Farmer', kind: FieldKind.user),
        AdminField('timestamp', 'Recorded', kind: FieldKind.timestamp),
      ]),
      AdminSection('Treatment', Icons.healing_rounded, [
        AdminField('intervention', 'Intervention', kind: FieldKind.multiline, editable: true),
        AdminField('dosage', 'Dosage', kind: FieldKind.number, editable: true),
        AdminField('unit', 'Unit', editable: true),
        AdminField('area', 'Area', kind: FieldKind.number, editable: true),
        AdminField('areaUnit', 'Area unit', editable: true),
        AdminField('isDeleted', 'Deleted by farmer', kind: FieldKind.boolean),
      ]),
    ],
    actions: const {AdminAction.edit, AdminAction.softDelete, AdminAction.delete},
    tableColumns: const ['userId', 'diseaseName', 'cropType', 'cropStage', 'dosage', 'timestamp'],
  ),
  'agronomic_advisories': AdminCollectionSpec(
    collection: 'agronomic_advisories',
    title: 'Advisories',
    singular: 'advisory',
    icon: Icons.verified_rounded,
    color: const Color(0xFF00695C),
    timeField: 'updatedAt',
    titleOf: (d) => d.str('title').isEmpty ? d.str('main') : d.str('title'),
    subtitleOf: (d) => d.str('main'),
    chipsOf: (d) => [
      if (d.str('condition').isNotEmpty) d.str('condition'),
      if (d['crops'] is List) (d['crops'] as List).join(', '),
      if (d['testOnly'] == true) 'TEST',
      if (d.str('stationName').isNotEmpty) d.str('stationName'),
    ],
    statusOf: (d) => switch (d.str('status')) {
      'published' => const AdminStatus('Published', _green),
      'archived' => const AdminStatus('Archived', _grey),
      _ => const AdminStatus('Draft', _amber),
    },
    searchKeys: const ['title', 'main', 'why', 'condition', 'publishedByName', 'createdByName'],
    filters: [
      AdminFilter.field('status', 'Status'),
      AdminFilter.field('condition', 'Condition'),
      AdminFilter('crops', 'Crop', (d) => [for (final c in (d['crops'] as List?) ?? const []) '$c']),
      AdminFilter('testOnly', 'Type', (d) => [d['testOnly'] == true ? 'Test' : 'Live']),
    ],
    sorts: [_byTime('updatedAt', 'Last updated'), _byTime('publishedAt', 'Published'), _byText('status', 'Status')],
    sections: const [
      AdminSection('Advice', Icons.lightbulb_rounded, [
        AdminField('title', 'Title'),
        AdminField('main', 'Main action', kind: FieldKind.multiline),
        AdminField('doList', 'Do', kind: FieldKind.list),
        AdminField('avoidList', 'Avoid', kind: FieldKind.list),
        AdminField('why', 'Why', kind: FieldKind.multiline),
      ]),
      AdminSection('Targeting', Icons.track_changes_rounded, [
        AdminField('crops', 'Crops', kind: FieldKind.list),
        AdminField('condition', 'Condition'),
        AdminField('stationName', 'Station'),
        AdminField('testOnly', 'Test only', kind: FieldKind.boolean),
      ]),
      AdminSection('Audit', Icons.history_rounded, [
        AdminField('status', 'Status'),
        AdminField('version', 'Version', kind: FieldKind.number),
        AdminField('createdByName', 'Created by'),
        AdminField('createdAt', 'Created', kind: FieldKind.timestamp),
        AdminField('publishedByName', 'Verified by'),
        AdminField('publishedAt', 'Published', kind: FieldKind.timestamp),
        AdminField('updatedAt', 'Last updated', kind: FieldKind.timestamp),
      ]),
    ],
    // Advisories change only through the Agronomist panel (keeps the audit trail).
    actions: const {AdminAction.openAgronomistPanel},
    tableColumns: const ['title', 'status', 'condition', 'crops', 'publishedByName', 'updatedAt'],
  ),
  'admin_logs': AdminCollectionSpec(
    collection: 'admin_logs',
    title: 'Admin logs',
    singular: 'log entry',
    icon: Icons.receipt_long_rounded,
    color: const Color(0xFF455A64),
    timeField: 'timestamp',
    userIdField: 'adminUid',
    titleOf: (d) => d.str('action').isEmpty ? 'Admin action' : d.str('action'),
    subtitleOf: (_) => '',
    chipsOf: (_) => const [],
    statusOf: (_) => null,
    searchKeys: const ['action', 'adminUid'],
    filters: const [],
    sorts: [_byTime('timestamp', 'Newest'), _byText('action', 'Action')],
    sections: const [
      AdminSection('Entry', Icons.receipt_long_rounded, [
        AdminField('action', 'Action', kind: FieldKind.multiline),
        AdminField('adminUid', 'Admin', kind: FieldKind.user),
        AdminField('timestamp', 'When', kind: FieldKind.timestamp),
      ]),
    ],
    actions: const {AdminAction.delete},
    tableColumns: const ['action', 'adminUid', 'timestamp'],
  ),
  'User_logs': AdminCollectionSpec(
    collection: 'User_logs',
    title: 'User logs',
    singular: 'log entry',
    icon: Icons.history_rounded,
    color: const Color(0xFF546E7A),
    timeField: 'timestamp',
    userIdField: 'userId',
    titleOf: (d) => [d.str('action'), d.str('collection')].where((s) => s.isNotEmpty).join(' · '),
    subtitleOf: (d) => d.str('details'),
    chipsOf: (d) => [if (d.str('documentId').isNotEmpty) 'Doc ${d.str('documentId')}'],
    statusOf: (_) => null,
    searchKeys: const ['action', 'collection', 'details', 'documentId'],
    filters: [AdminFilter.field('action', 'Action'), AdminFilter.field('collection', 'Collection')],
    sorts: [_byTime('timestamp', 'Newest'), _byText('action', 'Action')],
    sections: const [
      AdminSection('Entry', Icons.history_rounded, [
        AdminField('action', 'Action'),
        AdminField('collection', 'Collection'),
        AdminField('documentId', 'Document'),
        AdminField('details', 'Details', kind: FieldKind.multiline),
        AdminField('userId', 'By', kind: FieldKind.user),
        AdminField('timestamp', 'When', kind: FieldKind.timestamp),
      ]),
    ],
    actions: const {AdminAction.delete},
    tableColumns: const ['action', 'collection', 'details', 'userId', 'timestamp'],
  ),
};

/// Spec for any collection; unknown ones get a generic view.
AdminCollectionSpec specFor(String collection) =>
    kAdminSpecs[collection] ??
    AdminCollectionSpec(
      collection: collection,
      title: collection,
      singular: 'record',
      icon: Icons.table_rows_rounded,
      color: _blue,
      titleOf: (d) => d.id,
      subtitleOf: (d) => d.data.keys.take(4).join(', '),
      chipsOf: (_) => const [],
      statusOf: (_) => null,
      searchKeys: const [],
      filters: const [],
      sorts: const [],
      sections: const [],
      actions: const {AdminAction.delete},
      tableColumns: const [],
    );
