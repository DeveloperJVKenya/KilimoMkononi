// lib/screens/pest management/admin_pest_management_page.dart
//
// Kept for existing callers — pest records are managed in the shared admin
// record screen (search, filters, restore / soft delete / delete, bulk).

import 'package:flutter/material.dart';
import 'package:kilimomkononi/screens/admin/data/admin_collection_screen.dart';

class AdminPestManagementPage extends StatelessWidget {
  const AdminPestManagementPage({super.key});

  @override
  Widget build(BuildContext context) => const AdminCollectionScreen(collection: 'pestinterventiondata');
}
