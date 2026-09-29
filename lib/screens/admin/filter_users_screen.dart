// lib/screens/admin/filter_users_screen.dart
//
// Kept for existing callers — farmers are filtered in the shared admin record
// screen (search + County / Constituency / Ward / Status / Sign-up chips).

import 'package:flutter/material.dart';
import 'package:kilimomkononi/screens/admin/data/admin_collection_screen.dart';

class FilterUsersScreen extends StatelessWidget {
  const FilterUsersScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const AdminCollectionScreen(collection: 'Users', startWithFilters: true);
}
