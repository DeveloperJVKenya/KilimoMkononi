// lib/screens/admin/widgets/role_sheet.dart
//
// Bottom sheet for one role: current members (remove) + search (assign).
// Replaces "type a UID into a dialog".

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kilimomkononi/screens/admin/admin_providers.dart';
import 'package:kilimomkononi/screens/admin/widgets/interactive_tile.dart';
import 'package:kilimomkononi/utils/friendly_error.dart';

Future<void> showRoleSheet(BuildContext context, AdminRole role) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: const Color(0xFFF7F9F6),
    constraints: const BoxConstraints(maxWidth: 640),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) =>
          _RoleSheet(role: role, scrollController: controller),
    ),
  );
}

class _RoleSheet extends ConsumerStatefulWidget {
  final AdminRole role;
  final ScrollController scrollController;
  const _RoleSheet({required this.role, required this.scrollController});

  @override
  ConsumerState<_RoleSheet> createState() => _RoleSheetState();
}

class _RoleSheetState extends ConsumerState<_RoleSheet> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _query = '';
  String? _busyUid;

  AdminRole get role => widget.role;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    // Wait for a typing pause — one query per pause, not per keystroke.
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = v.trim());
    });
  }

  Future<void> _assign(AdminUserSummary u) async {
    setState(() => _busyUid = u.uid);
    final ok = await ref.read(roleControllerProvider.notifier).assign(role, u);
    if (!mounted) return;
    setState(() => _busyUid = null);
    _toast(ok ? '${u.name} is now in ${role.label}' : _errorText(), ok);
  }

  Future<void> _revoke(AdminUserSummary u) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove from ${role.label}?'),
        content: Text('${u.name} will lose this role immediately.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _busyUid = u.uid);
    final ok = await ref.read(roleControllerProvider.notifier).revoke(role, u);
    if (!mounted) return;
    setState(() => _busyUid = null);
    _toast(ok ? '${u.name} removed from ${role.label}' : _errorText(), ok);
  }

  String _errorText() {
    final err = ref.read(roleControllerProvider).error;
    return err is StateError ? err.message : friendlyError(err);
  }

  void _toast(String msg, bool ok) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          backgroundColor: ok ? role.gradient.first : const Color(0xFFC62828),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(roleMembersProvider(role.collection));
    final memberIds =
        members.value?.map((m) => m.uid).toSet() ?? const <String>{};
    final me = ref.watch(currentUidProvider);

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Row(
          children: [
            GradientIconBadge(
              icon: role.icon,
              gradient: role.gradient,
              size: 48,
              active: true,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role.label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    role.description,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Colors.black54,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // ── Assign ─────────────────────────────────────────────────────────
        TextField(
          controller: _searchCtrl,
          onChanged: _onSearchChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search farmers by name, email or UID',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchCtrl.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    },
                  ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: role.gradient.first, width: 1.6),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (_query.length >= 2)
          _SearchResults(
            query: _query,
            memberIds: memberIds,
            busyUid: _busyUid,
            accent: role.gradient.first,
            onAssign: _assign,
          )
        else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Type at least 2 letters. Names match from the start.',
              style: TextStyle(fontSize: 11.5, color: Colors.black45),
            ),
          ),
        const SizedBox(height: 18),

        // ── Members ────────────────────────────────────────────────────────
        Row(
          children: [
            Text(
              'CURRENT MEMBERS',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w800,
                color: role.gradient.first,
              ),
            ),
            const SizedBox(width: 6),
            if (members.hasValue)
              _CountPill(members.value!.length, role.gradient.first),
          ],
        ),
        const SizedBox(height: 8),
        members.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text(
            friendlyError(e, 'Could not load members'),
            style: const TextStyle(color: Color(0xFFC62828), fontSize: 12),
          ),
          data: (list) => list.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No one has this role yet — search above to add someone.',
                    style: TextStyle(fontSize: 12.5, color: Colors.black54),
                  ),
                )
              : Column(
                  children: [
                    for (final m in list)
                      _PersonRow(
                        user: m,
                        accent: role.gradient.first,
                        busy: _busyUid == m.uid,
                        isYou: m.uid == me,
                        action: (role.collection == 'Admins' && m.uid == me)
                            ? null // can't lock yourself out
                            : _RowAction.remove,
                        onAction: () => _revoke(m),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _SearchResults extends ConsumerWidget {
  final String query;
  final Set<String> memberIds;
  final String? busyUid;
  final Color accent;
  final ValueChanged<AdminUserSummary> onAssign;

  const _SearchResults({
    required this.query,
    required this.memberIds,
    required this.busyUid,
    required this.accent,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(userSearchProvider(query));
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: results.when(
        loading: () => const LinearProgressIndicator(minHeight: 2),
        error: (e, _) => Text(
          friendlyError(e, 'Search failed'),
          style: const TextStyle(color: Color(0xFFC62828), fontSize: 12),
        ),
        data: (list) => list.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No farmers found.',
                  style: TextStyle(fontSize: 12.5),
                ),
              )
            : Column(
                children: [
                  for (final u in list)
                    _PersonRow(
                      user: u,
                      accent: accent,
                      busy: busyUid == u.uid,
                      action: memberIds.contains(u.uid)
                          ? _RowAction.done
                          : _RowAction.add,
                      onAction: () => onAssign(u),
                    ),
                ],
              ),
      ),
    );
  }
}

enum _RowAction { add, remove, done }

class _PersonRow extends StatelessWidget {
  final AdminUserSummary user;
  final Color accent;
  final bool busy;
  final bool isYou;
  final _RowAction? action;
  final VoidCallback onAction;

  const _PersonRow({
    required this.user,
    required this.accent,
    required this.busy,
    required this.action,
    required this.onAction,
    this.isYou = false,
  });

  @override
  Widget build(BuildContext context) {
    final Widget trailing = busy
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : switch (action) {
            _RowAction.add => FilledButton.tonalIcon(
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Assign'),
              style: FilledButton.styleFrom(
                foregroundColor: accent,
                backgroundColor: accent.withValues(alpha: 0.12),
                visualDensity: VisualDensity.compact,
              ),
            ),
            _RowAction.remove => IconButton(
              tooltip: 'Remove role',
              onPressed: onAction,
              icon: const Icon(
                Icons.person_remove_alt_1_rounded,
                color: Color(0xFFC62828),
              ),
            ),
            _RowAction.done => Icon(Icons.check_circle_rounded, color: accent),
            null => const SizedBox.shrink(),
          };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3E7E2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: accent.withValues(alpha: 0.14),
            child: Text(
              user.initials,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isYou ? '${user.name} (you)' : user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  user.email.isNotEmpty ? user.email : user.uid,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  final int n;
  final Color color;
  const _CountPill(this.n, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      '$n',
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
    ),
  );
}
