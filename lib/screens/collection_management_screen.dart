// lib/screens/collection_management_screen.dart
//
// Kept for existing callers — the admin record screens now live in
// lib/screens/admin/data/admin_collection_screen.dart.

import 'package:flutter/material.dart';
import 'package:kilimomkononi/screens/admin/data/admin_collection_screen.dart';

class CollectionManagementScreen extends StatelessWidget {
  final String collectionName;
  const CollectionManagementScreen({required this.collectionName, super.key});

  @override
  Widget build(BuildContext context) => AdminCollectionScreen(collection: collectionName);
}
