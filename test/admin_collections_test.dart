import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kilimomkononi/screens/admin/data/admin_collection_screen.dart';
import 'package:kilimomkononi/screens/admin/data/admin_collection_spec.dart';
import 'package:kilimomkononi/screens/admin/data/admin_data_providers.dart';

final _now = DateTime(2026, 9, 29, 12);

List<AdminDoc> farmers() => const [
      AdminDoc('u1', {'fullName': 'Jane Wanjiku', 'email': 'jane@farm.ke', 'county': 'Nakuru', 'ward': 'Njoro', 'isDisabled': false}),
      AdminDoc('u2', {'fullName': 'Brian Otieno', 'email': 'brian@farm.ke', 'county': 'Kisumu', 'ward': 'Kondele', 'isDisabled': true,
          'legacyNote': 'Imported from the old system'}), // → "Other data" section
      AdminDoc('u3', {'fullName': 'Amina Hassan', 'email': 'amina@farm.ke', 'county': 'Nakuru', 'ward': 'Bahati'}),
    ];

List<AdminDoc> pests() => [
      AdminDoc('p1', {
        'pestName': 'Aphids', 'cropType': 'Maize', 'cropStage': 'Vegetative', 'intervention': 'Neem spray',
        'userId': 'u1', 'isDeleted': false, 'amount': '2 L', 'area': 2, 'areaUnit': 'Acres',
        'timestamp': Timestamp.fromDate(_now.subtract(const Duration(days: 1))),
      }),
      AdminDoc('p2', {
        'pestName': 'Fall armyworm', 'cropType': 'Maize', 'userId': 'u2', 'isDeleted': true,
        'timestamp': Timestamp.fromDate(_now.subtract(const Duration(days: 20))),
      }),
    ];

void main() {
  group('computeAdminView', () {
    final users = specFor('Users');

    test('search matches name, email and location; sort A→Z by name', () {
      final v = computeAdminView(users, farmers(), const AdminQuery(search: 'nakuru', sortKey: 'fullName', ascending: true),
          now: _now);
      expect(v.shown.map((d) => d.id), ['u3', 'u1']);
      expect(computeAdminView(users, farmers(), const AdminQuery(search: 'brian@'), now: _now).shown.single.id, 'u2');
    });

    test('filters, options with counts, status counts', () {
      final v = computeAdminView(users, farmers(), const AdminQuery(filters: {'isDisabled': 'Disabled'}), now: _now);
      expect(v.shown.map((d) => d.id), ['u2']);
      expect(v.filterOptions['county'], [('Nakuru', 2), ('Kisumu', 1)]);
      expect(v.statusCounts, {'Active': 2, 'Disabled': 1});
      expect(v.mayHaveMore, isFalse);
    });

    test('records: deleted filter, newest first, added this week', () {
      final spec = specFor('pestinterventiondata');
      final v = computeAdminView(spec, pests(), const AdminQuery(sortKey: 'timestamp'), now: _now);
      expect(v.shown.first.id, 'p1');
      expect(v.addedLast7Days, 1);
      expect(computeAdminView(spec, pests(), const AdminQuery(filters: {'isDeleted': 'Deleted'})).shown.single.id, 'p2');
    });

    test('multi-valued filter (a plot\'s crops)', () {
      final spec = specFor('fielddata');
      final docs = const [
        AdminDoc('f1', {'crops': [{'type': 'Maize'}, {'type': 'Beans'}], 'plotId': 'A'}),
        AdminDoc('f2', {'crops': [{'type': 'Tomatoes'}], 'plotId': 'B'}),
      ];
      final v = computeAdminView(spec, docs, const AdminQuery(filters: {'crop': 'Beans'}));
      expect(v.shown.single.id, 'f1');
      expect(spec.titleOf(docs.first), 'Maize, Beans');
    });
  });

  group('typed editing', () {
    const area = AdminField('area', 'Area', kind: FieldKind.number, editable: true);
    test('numbers stay numbers; ints stay ints; bad input is rejected', () {
      expect(parseAdminEdit(area, '3', 2), 3);
      expect(parseAdminEdit(area, '3', 2), isA<int>());
      expect(parseAdminEdit(area, '2.5', 2), 2.5);
      expect(parseAdminEdit(area, '', 2), isNull);
      expect(() => parseAdminEdit(area, 'two', 2), throwsFormatException);
      expect(parseAdminEdit(const AdminField('ward', 'Ward'), '  Njoro ', 'x'), 'Njoro');
    });
    test('only changed fields are written', () {
      expect(adminChanges({'a': 1, 'b': 'x', 'c': null}, {'a': 1, 'b': 'y', 'c': ''}), {'b': 'y'});
    });
  });

  group('formatting & CSV', () {
    test('values', () {
      expect(formatAdminValue(null), '—');
      expect(formatAdminValue(true), 'Yes');
      expect(formatAdminValue(1500, suffix: 'KES'), 'KES 1500');
      expect(formatAdminValue(2.5, suffix: 'acres'), '2.50 acres');
      expect(formatAdminValue([{'type': 'Maize', 'stage': 'Vegetative'}]), 'type: Maize · stage: Vegetative');
      expect(formatAdminValue(Timestamp.fromDate(DateTime(2026, 9, 28, 9, 41))), 'Mon 28 Sep 2026 · 09:41');
    });
    test('CSV escapes commas, quotes and new lines; keeps every field', () {
      final csv = adminCsv(specFor('Users'), const [
        AdminDoc('u1', {'fullName': 'Doe, "JJ"', 'email': 'a@b.c', 'extra': 'x\ny', 'profileImage': 'BASE64'}),
      ]);
      final lines = csv.trim().split('\n');
      expect(lines.first.startsWith('id,fullName,email'), isTrue);
      expect(csv, contains('"Doe, ""JJ"""'));
      expect(csv, contains('"x\ny"'));
      expect(csv, isNot(contains('BASE64'))); // images left out
    });
  });

  test('every spec is consistent', () {
    for (final spec in kAdminSpecs.values) {
      final keys = spec.sections.expand((s) => s.fields).map((f) => f.key).toSet();
      for (final c in spec.tableColumns) {
        expect(keys.contains(c) || spec.filters.any((f) => f.key == c), isTrue, reason: '${spec.collection}.$c');
      }
      expect(spec.filters.map((f) => f.key).toSet().length, spec.filters.length, reason: spec.collection);
      for (final f in spec.editableFields) {
        expect(const {FieldKind.text, FieldKind.multiline, FieldKind.number, FieldKind.boolean, FieldKind.choice}
            .contains(f.kind), isTrue, reason: '${spec.collection}.${f.key} can\'t be edited as ${f.kind}');
      }
    }
    // Advisories only change through the Agronomist panel (audit trail).
    expect(specFor('agronomic_advisories').can(AdminAction.delete), isFalse);
    expect(specFor('agronomic_advisories').can(AdminAction.edit), isFalse);
  });

  group('screen', () {
    Future<void> sized(WidgetTester t, double w, double h) async {
      t.view.physicalSize = Size(w, h);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
    }

    Widget app(String collection, List<AdminDoc> docs) => ProviderScope(
          overrides: [
            adminDocsProvider.overrideWith((ref, col) => Stream.value(docs)),
            personNameProvider.overrideWith((ref, uid) async => uid == 'u1' ? 'Jane Wanjiku' : 'Brian Otieno'),
          ],
          child: MaterialApp(home: AdminCollectionScreen(collection: collection)),
        );

    testWidgets('phone: cards, search, open detail', (t) async {
      await sized(t, 390, 844);
      await t.pumpWidget(app('Users', farmers()));
      await t.pumpAndSettle();
      expect(find.text('Farmers'), findsOneWidget);
      expect(find.text('Jane Wanjiku'), findsOneWidget);
      expect(find.text('3 shown · 3 loaded'), findsOneWidget);
      expect(t.takeException(), isNull);

      await t.enterText(find.byType(TextField).first, 'kisumu');
      await t.pumpAndSettle();
      expect(find.text('1 shown · 3 loaded'), findsOneWidget);

      await t.tap(find.text('Brian Otieno'));
      await t.pumpAndSettle();
      expect(find.text('Farm location'), findsOneWidget);
      expect(find.text('Enable'), findsOneWidget); // disabled account → enable
      expect(find.text('Reset password'), findsOneWidget);
      expect(t.takeException(), isNull);
      // Extra fields appear under "Other data" (expandable, with ripple).
      await t.ensureVisible(find.text('Other data (1)'));
      await t.pumpAndSettle();
      await t.tap(find.text('Other data (1)'));
      await t.pumpAndSettle();
      expect(find.byWidgetPredicate((w) => w is SelectableText && w.data == 'Imported from the old system'),
          findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('desktop: detail panel beside the list, table view, farmer names', (t) async {
      await sized(t, 1440, 900);
      await t.pumpWidget(app('pestinterventiondata', pests()));
      await t.pumpAndSettle();
      expect(find.text('Select a pest record'), findsOneWidget);
      expect(find.text('Jane Wanjiku'), findsWidgets); // uid shown as a name
      await t.tap(find.text('Aphids on Maize'));
      await t.pumpAndSettle();
      expect(find.text('Intervention'), findsWidgets);
      expect(find.text('Soft delete'), findsOneWidget);
      await t.tap(find.byTooltip('Table view'));
      await t.pumpAndSettle();
      expect(find.byType(DataTable), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('long-press selects; bulk bar offers the collection\'s actions', (t) async {
      await sized(t, 390, 844);
      await t.pumpWidget(app('Users', farmers()));
      await t.pumpAndSettle();
      await t.longPress(find.text('Jane Wanjiku'));
      await t.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);
      await t.tap(find.text('Amina Hassan')); // taps toggle while selecting
      await t.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);
      expect(find.text('Disable'), findsOneWidget);
      expect(find.text('Copy CSV'), findsOneWidget);
    });
  });
}
