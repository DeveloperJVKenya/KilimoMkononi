import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kilimomkononi/screens/admin/admin_providers.dart';
import 'package:kilimomkononi/screens/admin/data/admin_collection_screen.dart';
import 'package:kilimomkononi/screens/admin/widgets/interactive_tile.dart';
import 'package:kilimomkononi/screens/admin/widgets/role_sheet.dart';
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
        onTap: () => _open(AdminCollectionScreen(collection: s.collection)),
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
      subtitle: 'Edit, disable/enable, reset passwords — one or many',
      gradient: const [Color(0xFF0D47A1), Color(0xFF42A5F5)],
      onTap: () => _open(const AdminCollectionScreen(collection: 'Users')),
    ),
    ActionTile(
      icon: Icons.filter_alt_rounded,
      title: 'Filter Users',
      subtitle: 'Find farmers by county, constituency, ward or status',
      gradient: const [Color(0xFF00695C), Color(0xFF4DB6AC)],
      onTap: () => _open(const AdminCollectionScreen(collection: 'Users', startWithFilters: true)),
    ),
    ActionTile(
      icon: Icons.how_to_reg_rounded,
      title: 'Education Approvals',
      subtitle: 'Approve or deny pending school accounts',
      gradient: const [Color(0xFF283593), Color(0xFF5C6BC0)],
      onTap: () => _open(const AdminCollectionScreen(
        collection: 'EducationUsers',
        initialFilters: {'approvalStatus': 'pending'},
      )),
    ),
    ActionTile(
      icon: Icons.bug_report_rounded,
      title: 'Manage Pests',
      subtitle: 'Review, restore or remove pest records',
      gradient: const [Color(0xFFB71C1C), Color(0xFFEF5350)],
      onTap: () => _open(const AdminCollectionScreen(collection: 'pestinterventiondata')),
    ),
    ActionTile(
      icon: Icons.coronavirus_rounded,
      title: 'Manage Diseases',
      subtitle: 'Review, restore or remove disease records',
      gradient: const [Color(0xFF4A148C), Color(0xFFAB47BC)],
      onTap: () => _open(const AdminCollectionScreen(collection: 'diseaseinterventiondata')),
    ),
  ];

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
