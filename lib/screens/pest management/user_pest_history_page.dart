// lib/screens/pest management/user_pest_history_page.dart
//
// Kept for backward navigation compatibility.
// Immediately delegates to UnifiedIssueHistoryPage filtered to 'pest'.
// All display, edit, and delete logic now lives in UnifiedIssueHistoryPage.

import 'package:flutter/material.dart';
import 'package:kilimomkononi/screens/pest%20management/unified_issue_history_page.dart';

class UserPestHistoryPage extends StatelessWidget {
  const UserPestHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const UnifiedIssueHistoryPage(issueType: 'pest');
  }
}