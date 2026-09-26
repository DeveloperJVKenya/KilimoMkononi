import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kilimomkononi/screens/admin/admin_providers.dart';
import 'package:kilimomkononi/screens/admin/filter_users_screen.dart';
import 'package:kilimomkononi/screens/admin/widgets/interactive_tile.dart';
import 'package:kilimomkononi/screens/admin/widgets/role_sheet.dart';
import 'package:logger/logger.dart';
import 'package:kilimomkononi/screens/collection_management_screen.dart';
import 'package:kilimomkononi/screens/pest%20management/admin_pest_management_page.dart';
import 'package:kilimomkononi/enterprise/features/weather/field_agronomist_panel_screen.dart';

const _kDarkGreen = Color.fromARGB(255, 3, 39, 4);
const _kPageBg = Color(0xFFF4F6F3);

/// Admin Dashboard: live overview (count() aggregations), roles (tap to
/// add/remove people), and tools. State lives in admin_providers.dart.
class AdminManagementScreen extends ConsumerStatefulWidget {
  const AdminManagementScreen({super.key});

  @override
  ConsumerState<AdminManagementScreen> createState() =>
      _AdminManagementScreenState();
}

class _AdminManagementScreenState extends ConsumerState<AdminManagementScreen> {
  final logger = Logger(printer: PrettyPrinter());

  Future<void> _deleteUser(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('Users').doc(uid).delete();
      _logActivity('Deleted user $uid');
      ref.invalidate(collectionCountProvider('Users'));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User deleted from Firestore!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting user: $e')));
      }
    }
  }

  Future<void> _resetPassword(String email) async {
    try {
      if (email.isEmpty) throw 'Email is required';
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _logActivity('Sent password reset for $email');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending password reset: $e')),
        );
      }
    }
  }

  Future<void> _logActivity(String action) async {
    try {
      await FirebaseFirestore.instance.collection('admin_logs').add({
        'action': action,
        'timestamp': Timestamp.now(),
        'adminUid': FirebaseAuth.instance.currentUser?.uid,
      });
    } catch (e) {
      logger.e('Error logging activity: $e');
    }
  }

  /// Pull-to-refresh: re-run every count() aggregation.
  Future<void> _refresh() async {
    for (final s in kAdminStats) {
      ref.invalidate(collectionCountProvider(s.collection));
    }
    for (final r in kAdminRoles) {
      ref.invalidate(collectionCountProvider(r.collection));
    }
    await ref
        .read(collectionCountProvider(kAdminStats.first.collection).future)
        .catchError((_) => 0);
  }

  void _open(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPageBg,
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _kDarkGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: _kDarkGreen,
        onRefresh: _refresh,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Content stays readable on tablets/desktop: max ~1100px wide.
            final side = math.max(16.0, (constraints.maxWidth - 1100) / 2);
            final wide = constraints.maxWidth >= 700;
            // Tiles grow with the phone's text-size setting (accessibility),
            // so large text never clips inside a fixed-height tile.
            final ts = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(side, 16, side, 0),
                  sliver: const SliverToBoxAdapter(
                    child: _SectionHeader(
                      title: 'Overview',
                      hint: 'Live counts · tap a card to open the data',
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(side, 10, side, 0),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: wide ? 220 : 190,
                      mainAxisExtent: 62 * ts,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) =>
                          _Entrance(index: i, child: _statTile(kAdminStats[i])),
                      childCount: kAdminStats.length,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(side, 24, side, 0),
                  sliver: const SliverToBoxAdapter(
                    child: _SectionHeader(
                      title: 'Roles',
                      hint: 'Tap a role to add or remove people',
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(side, 10, side, 0),
                  sliver: SliverGrid(
                    gridDelegate:
                        SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 380,
                          mainAxisExtent: 76 * ts,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                        ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _Entrance(
                        index: i + 3,
                        child: _roleTile(kAdminRoles[i]),
                      ),
                      childCount: kAdminRoles.length,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(side, 24, side, 0),
                  sliver: const SliverToBoxAdapter(
                    child: _SectionHeader(
                      title: 'Tools',
                      hint: 'Manage data and test features',
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(side, 10, side, 32),
                  sliver: SliverGrid(
                    gridDelegate:
                        SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 380,
                          mainAxisExtent: 72 * ts,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                        ),
                    delegate: SliverChildListDelegate([
                      for (final (i, t) in _tools().indexed)
                        _Entrance(index: i + 6, child: t),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _statTile(AdminStat s) => Consumer(
    builder: (context, ref, _) {
      final count = ref.watch(collectionCountProvider(s.collection));
      return StatTile(
        icon: s.icon,
        label: s.label,
        color: s.color,
        // Keep showing the previous number while a refresh runs.
        count: count.hasError && !count.hasValue ? -1 : count.value,
        onTap: () =>
            _open(CollectionManagementScreen(collectionName: s.collection)),
      );
    },
  );

  Widget _roleTile(AdminRole r) => Consumer(
    builder: (context, ref, _) {
      final count = ref.watch(collectionCountProvider(r.collection)).value;
      return ActionTile(
        icon: r.icon,
        title: r.label,
        subtitle: r.description,
        gradient: r.gradient,
        onTap: () => showRoleSheet(context, r),
        trailing: _MemberBadge(count: count, color: r.gradient.first),
      );
    },
  );

  List<Widget> _tools() => [
    ActionTile(
      icon: Icons.science_rounded,
      title: 'Agronomist Panel (Test)',
      subtitle: 'Try the advisory workflow — never reaches farmers',
      gradient: const [Color(0xFF4A148C), Color(0xFF8E24AA)],
      onTap: () => _open(const FieldAgronomistPanelScreen(testMode: true)),
    ),
    ActionTile(
      icon: Icons.manage_accounts_rounded,
      title: 'Manage Users',
      subtitle: 'Delete, reset passwords, copy UIDs',
      gradient: const [Color(0xFF0D47A1), Color(0xFF42A5F5)],
      onTap: _showManageUsersScreen,
    ),
    ActionTile(
      icon: Icons.filter_alt_rounded,
      title: 'Filter Users',
      subtitle: 'Find farmers by location and status',
      gradient: const [Color(0xFF00695C), Color(0xFF4DB6AC)],
      onTap: () => _open(const FilterUsersScreen()),
    ),
    ActionTile(
      icon: Icons.bug_report_rounded,
      title: 'Manage Pests',
      subtitle: 'Review and restore pest records',
      gradient: const [Color(0xFFB71C1C), Color(0xFFEF5350)],
      onTap: () => _open(const AdminPestManagementPage()),
    ),
  ];

  void _showManageUsersScreen() {
    String? bulkAction;
    List<String> selectedUids = [];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => Scaffold(
            appBar: AppBar(
              title: const Text(
                'Manage Users',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: const Color.fromARGB(255, 3, 39, 4),
              foregroundColor: Colors.white,
              actions: [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.menu),
                  onSelected: (value) {
                    setState(() {
                      bulkAction = value;
                      selectedUids.clear();
                    });
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'Bulk Delete',
                      child: Text('Bulk Delete'),
                    ),
                    const PopupMenuItem(
                      value: 'Bulk Reset Password',
                      child: Text('Bulk Reset Password'),
                    ),
                  ],
                ),
              ],
            ),
            body: Column(
              children: [
                // count() aggregation — was a second full stream of every user.
                Consumer(
                  builder: (context, ref, _) {
                    final total = ref
                        .watch(collectionCountProvider('Users'))
                        .value;
                    if (total == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Total Users: $total',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('Users')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('No users found.'));
                      }

                      final users = snapshot.data!.docs;
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: DataTable(
                            columns: const [
                              DataColumn(
                                label: Text(
                                  'Profile',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Full Name',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Email',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'County',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Constituency',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Ward',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Phone Number',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Status',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Actions',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                            rows: users.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final uid = doc.id;
                              return DataRow(
                                cells: [
                                  DataCell(
                                    data['profileImage'] != null
                                        ? Image.memory(
                                            base64Decode(data['profileImage']),
                                            width: 28,
                                            height: 28,
                                            fit: BoxFit.cover,
                                          )
                                        : const Icon(Icons.person, size: 28),
                                  ),
                                  DataCell(Text(data['fullName'] ?? 'N/A')),
                                  DataCell(Text(data['email'] ?? 'N/A')),
                                  DataCell(Text(data['county'] ?? 'N/A')),
                                  DataCell(Text(data['constituency'] ?? 'N/A')),
                                  DataCell(Text(data['ward'] ?? 'N/A')),
                                  DataCell(Text(data['phoneNumber'] ?? 'N/A')),
                                  DataCell(
                                    Text(
                                      data['isDisabled'] == true
                                          ? 'Disabled'
                                          : 'Active',
                                    ),
                                  ),
                                  DataCell(
                                    PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'Delete') {
                                          _confirmDeleteUser(uid);
                                        }
                                        if (value == 'Reset Password') {
                                          _resetPassword(data['email'] ?? '');
                                        }
                                        if (value == 'Copy UID') {
                                          Clipboard.setData(
                                            ClipboardData(text: uid),
                                          );
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'UID copied to clipboard!',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'Delete',
                                          child: Text('Delete User'),
                                        ),
                                        const PopupMenuItem(
                                          value: 'Reset Password',
                                          child: Text('Reset Password'),
                                        ),
                                        const PopupMenuItem(
                                          value: 'Copy UID',
                                          child: Text('Copy UID'),
                                        ),
                                      ],
                                      icon: const Icon(Icons.more_vert),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (bulkAction != null && selectedUids.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: () async {
                        if (bulkAction == 'Bulk Delete') {
                          for (var uid in selectedUids) {
                            _confirmDeleteUser(uid);
                          }
                        } else if (bulkAction == 'Bulk Reset Password') {
                          for (var uid in selectedUids) {
                            final doc = await FirebaseFirestore.instance
                                .collection('Users')
                                .doc(uid)
                                .get();
                            await _resetPassword(
                              doc.data()?['email'] as String? ?? '',
                            );
                          }
                        }
                        setState(() {
                          bulkAction = null;
                          selectedUids.clear();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 3, 39, 4),
                        foregroundColor: Colors.white,
                      ),
                      child: Text('Execute $bulkAction'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteUser(String uid) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Confirm Deletion',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to delete this user? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _deleteUser(uid);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ── Small building blocks ────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String hint;
  const _SectionHeader({required this.title, required this.hint});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: Color(0xFF1B2A1B),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          hint,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11.5, color: Colors.black45),
        ),
      ),
    ],
  );
}

class _MemberBadge extends StatelessWidget {
  final int? count;
  final Color color;
  const _MemberBadge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 200),
    child: Container(
      key: ValueKey(count),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_rounded, size: 13, color: color),
          const SizedBox(width: 3),
          Text(
            count == null ? '…' : '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Staggered fade + rise when the dashboard first appears.
class _Entrance extends StatefulWidget {
  final int index;
  final Widget child;
  const _Entrance({required this.index, required this.child});

  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance> {
  bool _shown = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Cancellable (unlike Future.delayed) so nothing fires after dispose.
    _timer = Timer(Duration(milliseconds: 30 * widget.index.clamp(0, 12)), () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: _shown ? 1 : 0,
    duration: const Duration(milliseconds: 260),
    curve: Curves.easeOut,
    child: AnimatedSlide(
      offset: _shown ? Offset.zero : const Offset(0, 0.12),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: widget.child,
    ),
  );
}
