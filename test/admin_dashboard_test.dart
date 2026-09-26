// Admin Dashboard renders from Riverpod providers — here overridden with fake
// data, so no Firebase is needed. Checks layout at phone and desktop widths
// (any overflow fails the test) and the role sheet flow.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kilimomkononi/screens/admin/admin_management_screen.dart';
import 'package:kilimomkononi/screens/admin/admin_providers.dart';

const _counts = {
  'Users': 1234,
  'Admins': 2,
  'Agronomists': 3,
  'PriceAnalysts': 0,
};

final _members = {
  'Admins': const [
    AdminUserSummary(uid: 'me', name: 'Jane Admin', email: 'jane@example.com'),
    AdminUserSummary(uid: 'u2', name: 'Otieno Admin', email: 'otieno@example.com'),
  ],
};

Widget _app() => ProviderScope(
      overrides: [
        collectionCountProvider.overrideWith((ref, col) async => _counts[col] ?? 7),
        roleMembersProvider.overrideWith((ref, col) async => _members[col] ?? const []),
        userSearchProvider.overrideWith((ref, q) async => const [
              AdminUserSummary(uid: 'u9', name: 'Wanjiru Farmer', email: 'w@example.com'),
            ]),
        currentUidProvider.overrideWithValue('me'),
      ],
      child: const MaterialApp(home: AdminManagementScreen()),
    );

Future<void> _size(WidgetTester tester, double w, double h) async {
  tester.view.physicalSize = Size(w * 2, h * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

void main() {
  for (final (name, w, h) in [('phone', 360.0, 800.0), ('desktop', 1280.0, 900.0)]) {
    testWidgets('dashboard lays out on $name', (tester) async {
      await _size(tester, w, h);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('1,234'), findsOneWidget); // animated count settles
      expect(find.text('Field Agronomists'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Manage Pests'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Manage Pests'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('tiles are compact (not the old oversized cards)', (tester) async {
    await _size(tester, 360, 800);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    final roleTile = tester.getSize(find.ancestor(
        of: find.text('Field Agronomists'), matching: find.byType(InkWell)).first);
    expect(roleTile.height, lessThanOrEqualTo(80));
  });

  testWidgets('role sheet: members, self-protection, search and assign button', (tester) async {
    await _size(tester, 360, 800);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Admins'));
    await tester.pumpAndSettle();

    expect(find.text('Jane Admin (you)'), findsOneWidget);
    expect(find.text('Otieno Admin'), findsOneWidget);
    // You can remove Otieno, but not yourself.
    expect(find.byTooltip('Remove role'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Wan');
    await tester.pump(const Duration(milliseconds: 400)); // debounce
    await tester.pumpAndSettle();
    expect(find.text('Wanjiru Farmer'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Assign'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
