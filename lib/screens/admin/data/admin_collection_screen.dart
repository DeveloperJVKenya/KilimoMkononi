// lib/screens/admin/data/admin_collection_screen.dart
//
// The admin screen behind every dashboard card (Farmers, Education users,
// Field / Market / Pest / Disease records, Advisories, logs), driven by an
// AdminCollectionSpec and Riverpod (admin_data_providers.dart):
//
//   • summary strip (total, statuses, added this week)
//   • search, filter chips built from the real data, sort
//   • cards on phones; list + detail panel side by side on wide screens,
//     with an optional table view
//   • record detail in labelled sections, farmer names instead of uids,
//     "Other data" for any extra fields, copy ID
//   • typed editing (numbers stay numbers), delete, soft-delete / restore,
//     disable / enable accounts, reset passwords, approve / deny education
//     accounts — single or in bulk — and "Copy as CSV"

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kilimomkononi/enterprise/features/weather/field_agronomist_panel_screen.dart';
import 'package:kilimomkononi/screens/admin/data/admin_collection_spec.dart';
import 'package:kilimomkononi/screens/admin/data/admin_data_providers.dart';
import 'package:kilimomkononi/settings/notifications/notification_style.dart';
import 'package:kilimomkononi/utils/friendly_error.dart';

const _kPage = Color(0xFFF4F6F3);
const _kInk = Color(0xFF1B2A1B);
const _kMuted = Color(0xFF6B7280);
const _kBorder = Color(0xFFE2E8E3);
const _kWide = 1000.0;

class AdminCollectionScreen extends ConsumerStatefulWidget {
  final String collection;

  /// Open with the filter chips highlighted (the old "Filter Users" tool).
  final bool startWithFilters;

  /// Filters applied on open, e.g. {'approvalStatus': 'pending'}.
  final Map<String, String> initialFilters;

  const AdminCollectionScreen({
    super.key,
    required this.collection,
    this.startWithFilters = false,
    this.initialFilters = const {},
  });

  @override
  ConsumerState<AdminCollectionScreen> createState() => _AdminCollectionScreenState();
}

class _AdminCollectionScreenState extends ConsumerState<AdminCollectionScreen> {
  late final AdminCollectionSpec spec = specFor(widget.collection);
  final _search = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final e in widget.initialFilters.entries) {
        _q.setFilter(e.key, e.value);
      }
      if (widget.startWithFilters) _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  AdminQueryController get _q => ref.read(adminQueryProvider(widget.collection).notifier);

  Color get _dark => Color.lerp(spec.color, Colors.black, 0.45)!;

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(adminViewProvider(widget.collection));
    final query = ref.watch(adminQueryProvider(widget.collection));
    final wide = MediaQuery.sizeOf(context).width >= _kWide;
    final v = view.value;

    return Scaffold(
      backgroundColor: _kPage,
      appBar: AppBar(
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: LinearGradient(colors: [_dark, spec.color])),
        ),
        title: Row(children: [
          Icon(spec.icon, size: 22),
          const SizedBox(width: 10),
          Flexible(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(spec.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              if (v != null)
                Text(
                  '${v.shown.length} shown · ${v.all.length}${v.mayHaveMore ? '+' : ''} loaded',
                  style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                ),
            ]),
          ),
        ]),
        actions: [
          if (wide && spec.tableColumns.isNotEmpty)
            IconButton(
              tooltip: query.tableView ? 'Card view' : 'Table view',
              icon: Icon(query.tableView ? Icons.view_agenda_rounded : Icons.table_rows_rounded),
              onPressed: _q.toggleTable,
            ),
          IconButton(
            tooltip: 'Copy shown records as CSV',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: v == null || v.shown.isEmpty ? null : () => _copyCsv(v.shown),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(adminDocsProvider(widget.collection)),
          ),
        ],
      ),
      body: view.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Message(
          icon: Icons.error_outline_rounded,
          color: Colors.red,
          title: 'Could not load ${spec.title.toLowerCase()}',
          text: friendlyError(e),
        ),
        data: (v) {
          final list = Column(children: [
            _SummaryStrip(spec: spec, view: v),
            _Toolbar(
              spec: spec,
              view: v,
              query: query,
              search: _search,
              searchFocus: _searchFocus,
              highlightFilters: widget.startWithFilters,
            ),
            Expanded(
              child: v.shown.isEmpty
                  ? _Message(
                      icon: query.hasFilters ? Icons.search_off_rounded : spec.icon,
                      color: spec.color,
                      title: query.hasFilters ? 'No matches' : 'No ${spec.title.toLowerCase()} yet',
                      text: query.hasFilters ? 'Try a different search or clear the filters.' : '',
                      action: query.hasFilters
                          ? TextButton(
                              onPressed: () {
                                _search.clear();
                                _q.clearFilters();
                              },
                              child: const Text('Clear filters'))
                          : null,
                    )
                  : (wide && query.tableView)
                      ? _RecordsTable(spec: spec, view: v, query: query)
                      : _RecordsList(spec: spec, view: v, query: query, onOpen: (d) => _open(d, wide)),
            ),
          ]);
          if (!wide) return list;
          final open = v.all.where((d) => d.id == query.openId).firstOrNull;
          return Row(children: [
            Expanded(flex: 3, child: list),
            const VerticalDivider(width: 1, color: _kBorder),
            SizedBox(
              width: 440,
              child: open == null
                  ? _Message(
                      icon: Icons.touch_app_rounded,
                      color: spec.color,
                      title: 'Select a ${spec.singular}',
                      text: 'Its details and actions appear here.',
                    )
                  : AdminRecordDetail(key: ValueKey(open.id), spec: spec, doc: open, onClose: () => _q.open(null)),
            ),
          ]);
        },
      ),
      bottomNavigationBar: query.selecting && v != null ? _BulkBar(spec: spec, view: v, query: query) : null,
    );
  }

  void _open(AdminDoc d, bool wide) {
    if (ref.read(adminQueryProvider(widget.collection)).selecting) {
      _q.toggleSelect(d.id);
      return;
    }
    _q.open(d.id);
    if (!wide) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _RecordPage(collection: widget.collection, id: d.id)),
      );
    }
  }

  Future<void> _copyCsv(List<AdminDoc> docs) async {
    await Clipboard.setData(ClipboardData(text: adminCsv(spec, docs)));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${docs.length} ${spec.singular}${docs.length == 1 ? '' : 's'} copied as CSV — paste into Excel or Sheets'),
      ));
    }
  }
}

// ── Summary ──────────────────────────────────────────────────────────────────

class _SummaryStrip extends StatelessWidget {
  final AdminCollectionSpec spec;
  final AdminView view;
  const _SummaryStrip({required this.spec, required this.view});

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      _StatPill(Icons.dataset_rounded, 'Loaded', '${view.all.length}${view.mayHaveMore ? '+' : ''}', spec.color),
      for (final e in view.statusCounts.entries)
        _StatPill(Icons.circle, e.key, '${e.value}', _statusColor(spec, e.key)),
      if (spec.timeField != null) _StatPill(Icons.fiber_new_rounded, 'This week', '${view.addedLast7Days}', const Color(0xFF1565C0)),
      if (spec.collection == 'marketdata') ..._priceStats(view),
    ];
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        itemCount: tiles.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => tiles[i],
      ),
    );
  }

  static Color _statusColor(AdminCollectionSpec spec, String label) {
    const map = {
      'Active': Color(0xFF2E7D32),
      'Approved': Color(0xFF2E7D32),
      'Published': Color(0xFF2E7D32),
      'Disabled': Color(0xFFC62828),
      'Deleted': Color(0xFFC62828),
      'Denied': Color(0xFFC62828),
      'Pending': Color(0xFFEF6C00),
      'Draft': Color(0xFFEF6C00),
    };
    return map[label] ?? const Color(0xFF607D8B);
  }

  List<Widget> _priceStats(AdminView v) {
    final prices = v.shown.map((d) => d['retailPrice']).whereType<num>().toList();
    if (prices.isEmpty) return const [];
    final avg = prices.reduce((a, b) => a + b) / prices.length;
    return [_StatPill(Icons.payments_rounded, 'Avg retail (shown)', 'KES ${avg.toStringAsFixed(0)}', const Color(0xFF6D4C41))];
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatPill(this.icon, this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Icon(icon, size: icon == Icons.circle ? 10 : 18, color: color),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: const TextStyle(fontSize: 10.5, color: _kMuted)),
          ]),
        ]),
      );
}

// ── Toolbar: search, filters, sort ───────────────────────────────────────────

class _Toolbar extends ConsumerWidget {
  final AdminCollectionSpec spec;
  final AdminView view;
  final AdminQuery query;
  final TextEditingController search;
  final FocusNode searchFocus;
  final bool highlightFilters;
  const _Toolbar({
    required this.spec,
    required this.view,
    required this.query,
    required this.search,
    required this.searchFocus,
    required this.highlightFilters,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.read(adminQueryProvider(spec.collection).notifier);
    final sort = spec.sorts.where((s) => s.key == query.sortKey).firstOrNull;
    return Container(
      color: _kPage,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: search,
              focusNode: searchFocus,
              onChanged: q.search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search ${spec.title.toLowerCase()}…',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: query.search.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          search.clear();
                          q.search('');
                        },
                      ),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: spec.color, width: 1.6)),
              ),
            ),
          ),
          if (spec.sorts.isNotEmpty) ...[
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              tooltip: 'Sort',
              onSelected: (key) => _chooseSort(context, ref, key),
              itemBuilder: (_) => [
                for (final s in spec.sorts)
                  CheckedPopupMenuItem(
                    value: s.key,
                    checked: s.key == query.sortKey,
                    child: Row(children: [
                      Expanded(child: Text(s.label)),
                      // Fields with specific values open a picker.
                      if (spec.filters.any((f) => f.key == s.key))
                        const Icon(Icons.chevron_right_rounded, size: 18, color: _kMuted),
                    ]),
                  ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kBorder),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(query.ascending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 16, color: spec.color),
                  const SizedBox(width: 4),
                  Text(
                    query.filters[query.sortKey] != null
                        ? '${sort?.label}: ${query.filters[query.sortKey]}'
                        : (sort?.label ?? 'Sort'),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ]),
              ),
            ),
          ],
        ]),
        if (spec.filters.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              if (highlightFilters && query.filters.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(right: 8, top: 9),
                  child: Text('Filter by:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kMuted)),
                ),
              for (final f in spec.filters) _FilterChip(spec: spec, filter: f, view: view, query: query),
              if (query.hasFilters)
                TextButton.icon(
                  onPressed: () {
                    search.clear();
                    q.clearFilters();
                  },
                  icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                  label: const Text('Clear'),
                ),
            ]),
          ),
        ],
      ]),
    );
  }
}

extension on _Toolbar {
  /// Sort by [key]; for fields with specific values (county, ward, crop…),
  /// ask which one — "All …" keeps every record, sorted by that field.
  Future<void> _chooseSort(BuildContext context, WidgetRef ref, String key) async {
    final q = ref.read(adminQueryProvider(spec.collection).notifier);
    final filter = spec.filters.where((f) => f.key == key).firstOrNull;
    final options = view.filterOptions[key] ?? const [];
    if (filter == null || options.isEmpty) {
      q.sortBy(key);
      return;
    }
    final pick = await pickAdminValue(context,
        spec: spec, filter: filter, options: options, selected: query.filters[key], allLabel: 'All — sort by ${filter.label.toLowerCase()}');
    if (pick == null) return; // dismissed
    if (query.sortKey != key) q.sortBy(key);
    q.setFilter(key, pick.value);
  }
}

class _FilterChip extends ConsumerWidget {
  final AdminCollectionSpec spec;
  final AdminFilter filter;
  final AdminView view;
  final AdminQuery query;
  const _FilterChip({required this.spec, required this.filter, required this.view, required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = query.filters[filter.key];
    final options = view.filterOptions[filter.key] ?? const [];
    final q = ref.read(adminQueryProvider(spec.collection).notifier);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: options.isEmpty
            ? null
            : () async {
                final pick = await pickAdminValue(context, spec: spec, filter: filter, options: options, selected: selected);
                if (pick != null) q.setFilter(filter.key, pick.value);
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected == null ? Colors.white : spec.color,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected == null ? _kBorder : spec.color),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(
              selected == null ? filter.label : '${filter.label}: $selected',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected == null ? (options.isEmpty ? Colors.black26 : _kInk) : Colors.white),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more_rounded, size: 16, color: selected == null ? _kMuted : Colors.white),
          ]),
        ),
      ),
    );
  }
}

// ── List ─────────────────────────────────────────────────────────────────────

class _RecordsList extends ConsumerWidget {
  final AdminCollectionSpec spec;
  final AdminView view;
  final AdminQuery query;
  final ValueChanged<AdminDoc> onOpen;
  const _RecordsList({required this.spec, required this.view, required this.query, required this.onOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = view.shown;
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(adminDocsProvider(spec.collection)),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        itemCount: items.length + 1,
        itemBuilder: (_, i) {
          if (i == items.length) return _LoadMore(spec: spec, view: view);
          final d = items[i];
          return _RecordCard(
            spec: spec,
            doc: d,
            selected: query.selected.contains(d.id),
            selecting: query.selecting,
            open: query.openId == d.id,
            onTap: () => onOpen(d),
            onLongPress: () => ref.read(adminQueryProvider(spec.collection).notifier).toggleSelect(d.id),
          );
        },
      ),
    );
  }
}

class _LoadMore extends ConsumerWidget {
  final AdminCollectionSpec spec;
  final AdminView view;
  const _LoadMore({required this.spec, required this.view});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: view.mayHaveMore
              ? OutlinedButton.icon(
                  onPressed: () => ref.read(adminLimitProvider(spec.collection).notifier).more(),
                  icon: const Icon(Icons.expand_more_rounded),
                  label: Text('Load more ${spec.title.toLowerCase()}'),
                )
              : Text('All ${view.all.length} loaded', style: const TextStyle(fontSize: 12, color: _kMuted)),
        ),
      );
}

class _RecordCard extends StatelessWidget {
  final AdminCollectionSpec spec;
  final AdminDoc doc;
  final bool selected;
  final bool selecting;
  final bool open;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _RecordCard({
    required this.spec,
    required this.doc,
    required this.selected,
    required this.selecting,
    required this.open,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final status = spec.statusOf(doc);
    final when = doc.time(spec.timeField);
    final chips = spec.chipsOf(doc).where((c) => c.trim().isNotEmpty).toList();
    final subtitle = spec.subtitleOf(doc);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? spec.color.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        elevation: open ? 2 : 0,
        shadowColor: Colors.black26,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: open || selected ? spec.color : _kBorder, width: open || selected ? 1.4 : 1),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (selecting)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Checkbox(value: selected, activeColor: spec.color, onChanged: (_) => onTap()),
                ),
              AdminAvatar(spec: spec, doc: doc),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text(spec.titleOf(doc),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: _kInk)),
                    ),
                    if (status != null) KmTag(status.label, status.color),
                  ]),
                  if (spec.userIdField != null && doc.str(spec.userIdField!).isNotEmpty) ...[
                    const SizedBox(height: 2),
                    PersonName(uid: doc.str(spec.userIdField!), icon: Icons.person_outline_rounded),
                  ],
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: _kMuted)),
                  ],
                  if (chips.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 4, children: [for (final c in chips.take(4)) KmTag(c, spec.color)]),
                  ],
                  if (when != null) ...[
                    const SizedBox(height: 6),
                    Text('${fullStamp(when)} · ${relativeTime(when)}', style: const TextStyle(fontSize: 11, color: _kMuted)),
                  ],
                ]),
              ),
              if (!selecting) const Icon(Icons.chevron_right_rounded, color: Colors.black26),
            ]),
          ),
        ),
      ),
    );
  }
}

class AdminAvatar extends StatelessWidget {
  final AdminCollectionSpec spec;
  final AdminDoc doc;
  final double size;
  const AdminAvatar({super.key, required this.spec, required this.doc, this.size = 42});

  @override
  Widget build(BuildContext context) {
    final img = spec.imageField == null ? null : doc[spec.imageField!];
    if (img is String && img.isNotEmpty) {
      try {
        return CircleAvatar(radius: size / 2, backgroundImage: MemoryImage(base64Decode(img)));
      } catch (_) {}
    }
    final title = spec.titleOf(doc);
    final isPerson = spec.collection == 'Users' || spec.collection == 'EducationUsers';
    final parts = title.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final initials = parts.isEmpty ? '?' : (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: spec.color.withValues(alpha: 0.12), shape: BoxShape.circle),
      child: isPerson
          ? Text(initials, style: TextStyle(color: spec.color, fontWeight: FontWeight.w800, fontSize: size * 0.36))
          : Icon(spec.icon, color: spec.color, size: size * 0.5),
    );
  }
}

/// A farmer / user name from a uid (tap to copy the uid).
class PersonName extends ConsumerWidget {
  final String uid;
  final IconData? icon;
  final TextStyle? style;
  const PersonName({super.key, required this.uid, this.icon, this.style});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(personNameProvider(uid)).value;
    final text = name ?? (uid.length > 10 ? '${uid.substring(0, 8)}…' : uid);
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: uid));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User ID copied')));
      },
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: _kMuted), const SizedBox(width: 3)],
        Flexible(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style ?? const TextStyle(fontSize: 12.5, color: _kInk, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

// ── Table (wide screens) ─────────────────────────────────────────────────────

class _RecordsTable extends ConsumerWidget {
  final AdminCollectionSpec spec;
  final AdminView view;
  final AdminQuery query;
  const _RecordsTable({required this.spec, required this.view, required this.query});

  String _label(String key) {
    for (final s in spec.sections) {
      for (final f in s.fields) {
        if (f.key == key) return f.label;
      }
    }
    return key == 'crop' ? 'Crops' : key;
  }

  AdminField? _field(String key) {
    for (final s in spec.sections) {
      for (final f in s.fields) {
        if (f.key == key) return f;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.read(adminQueryProvider(spec.collection).notifier);
    final sortable = {for (final s in spec.sorts) s.key};
    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              DataTable(
                showCheckboxColumn: true,
                headingRowColor: WidgetStatePropertyAll(spec.color.withValues(alpha: 0.08)),
                headingTextStyle: TextStyle(fontWeight: FontWeight.w800, color: Color.lerp(spec.color, Colors.black, 0.4)),
                sortColumnIndex: () {
                  final i = spec.tableColumns.indexOf(query.sortKey ?? '');
                  return i < 0 ? null : i + 1;
                }(),
                sortAscending: query.ascending,
                columns: [
                  const DataColumn(label: Text('')),
                  for (final c in spec.tableColumns)
                    DataColumn(
                      label: Text(_label(c)),
                      onSort: sortable.contains(c) ? (_, _) => q.sortBy(c) : null,
                    ),
                ],
                rows: [
                  for (final d in view.shown)
                    DataRow(
                      selected: query.selected.contains(d.id),
                      onSelectChanged: (_) => q.toggleSelect(d.id),
                      color: query.openId == d.id ? WidgetStatePropertyAll(spec.color.withValues(alpha: 0.06)) : null,
                      cells: [
                        DataCell(AdminAvatar(spec: spec, doc: d, size: 28), onTap: () => q.open(d.id)),
                        for (final c in spec.tableColumns) DataCell(_cell(d, c), onTap: () => q.open(d.id)),
                      ],
                    ),
                ],
              ),
              _LoadMore(spec: spec, view: view),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _cell(AdminDoc d, String key) {
    if (key == spec.userIdField || _field(key)?.kind == FieldKind.user) {
      return ConstrainedBox(constraints: const BoxConstraints(maxWidth: 180), child: PersonName(uid: d.str(key)));
    }
    final value = key == 'crop'
        ? (spec.filters.where((f) => f.key == 'crop').firstOrNull?.valuesOf(d).join(', ') ?? '')
        : formatAdminValue(d[key], kind: _field(key)?.kind ?? FieldKind.text, suffix: _field(key)?.suffix);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: Text(value.replaceAll('\n', ', '), maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }
}

// ── Bulk actions ─────────────────────────────────────────────────────────────

class _BulkBar extends ConsumerWidget {
  final AdminCollectionSpec spec;
  final AdminView view;
  final AdminQuery query;
  const _BulkBar({required this.spec, required this.view, required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.read(adminQueryProvider(spec.collection).notifier);
    final actions = ref.read(adminActionsProvider);
    final picked = view.all.where((d) => query.selected.contains(d.id)).toList();
    final n = picked.length;
    Future<void> run(String label, Future<void> Function() op, {bool confirm = true, bool danger = false}) async {
      if (confirm &&
          !await confirmAdmin(context, '$label $n ${spec.singular}${n == 1 ? '' : 's'}?',
              danger ? 'This can\'t be undone.' : 'This applies to all selected records.',
              action: label, danger: danger)) {
        return;
      }
      try {
        await op();
        q.clearSelection();
        if (context.mounted) showAdminSnack(context, '$label: $n ${spec.singular}${n == 1 ? '' : 's'}');
      } catch (e) {
        if (context.mounted) showAdminSnack(context, friendlyError(e), error: true);
      }
    }

    final buttons = <Widget>[
      if (spec.can(AdminAction.disable)) ...[
        _BulkButton(Icons.block_rounded, 'Disable', () => run('Disable', () => actions.setDisabled(spec, query.selected, true))),
        _BulkButton(Icons.check_circle_outline_rounded, 'Enable', () => run('Enable', () => actions.setDisabled(spec, query.selected, false))),
      ],
      if (spec.can(AdminAction.resetPassword))
        _BulkButton(Icons.lock_reset_rounded, 'Reset passwords',
            () => run('Send reset links to', () => actions.resetPasswords(picked.map((d) => d.str('email'))))),
      if (spec.can(AdminAction.softDelete)) ...[
        _BulkButton(Icons.delete_outline_rounded, 'Soft delete', () => run('Soft-delete', () => actions.setDeleted(spec, query.selected, true))),
        _BulkButton(Icons.restore_rounded, 'Restore', () => run('Restore', () => actions.setDeleted(spec, query.selected, false))),
      ],
      _BulkButton(Icons.file_download_outlined, 'Copy CSV', () async {
        await Clipboard.setData(ClipboardData(text: adminCsv(spec, picked)));
        if (context.mounted) showAdminSnack(context, '$n copied as CSV');
      }),
      if (spec.can(AdminAction.delete))
        _BulkButton(Icons.delete_forever_rounded, 'Delete', () => run('Delete', () => actions.delete(spec, query.selected), danger: true),
            danger: true),
    ];

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: _kBorder)),
          boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, -2))],
        ),
        child: Row(children: [
          IconButton(tooltip: 'Clear selection', icon: const Icon(Icons.close_rounded), onPressed: q.clearSelection),
          Text('$n selected', style: const TextStyle(fontWeight: FontWeight.w800)),
          TextButton(onPressed: () => q.selectAll(view.shown.map((d) => d.id)), child: Text('All ${view.shown.length}')),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(children: buttons),
            ),
          ),
        ]),
      ),
    );
  }
}

class _BulkButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const _BulkButton(this.icon, this.label, this.onTap, {this.danger = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 6),
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: danger ? const Color(0xFFC62828) : _kInk,
            side: BorderSide(color: danger ? const Color(0xFFC62828) : _kBorder),
          ),
        ),
      );
}

// ── Detail ───────────────────────────────────────────────────────────────────

/// Full-page detail on phones (keeps up with live changes).
class _RecordPage extends ConsumerWidget {
  final String collection;
  final String id;
  const _RecordPage({required this.collection, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spec = specFor(collection);
    final doc = ref.watch(adminDocsProvider(collection)).value?.where((d) => d.id == id).firstOrNull;
    return Scaffold(
      backgroundColor: _kPage,
      appBar: AppBar(
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Color.lerp(spec.color, Colors.black, 0.35),
        title: Text(spec.singular[0].toUpperCase() + spec.singular.substring(1),
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: doc == null
          ? _Message(icon: Icons.delete_sweep_rounded, color: spec.color, title: 'This record no longer exists', text: '')
          : AdminRecordDetail(spec: spec, doc: doc, onClose: () => Navigator.pop(context)),
    );
  }
}

class AdminRecordDetail extends ConsumerWidget {
  final AdminCollectionSpec spec;
  final AdminDoc doc;
  final VoidCallback onClose;
  const AdminRecordDetail({super.key, required this.spec, required this.doc, required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = spec.statusOf(doc);
    final actions = ref.read(adminActionsProvider);
    final other = doc.data.entries.where((e) => !spec.knownKeys.contains(e.key)).toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    Future<void> run(Future<void> Function() op, String done) async {
      try {
        await op();
        if (context.mounted) showAdminSnack(context, done);
      } catch (e) {
        if (context.mounted) showAdminSnack(context, friendlyError(e), error: true);
      }
    }

    final isDisabled = doc['isDisabled'] == true;
    final isDeleted = doc['isDeleted'] == true;
    final pending = spec.collection == 'EducationUsers' &&
        (doc.str('approvalStatus').isEmpty || doc.str('approvalStatus') == 'pending');

    final buttons = <Widget>[
      if (spec.can(AdminAction.approve) && pending)
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
          onPressed: () => run(() => actions.decideEducation(doc, approve: true), 'Approved'),
          icon: const Icon(Icons.check_rounded, size: 18),
          label: const Text('Approve'),
        ),
      if (spec.can(AdminAction.deny) && pending)
        OutlinedButton.icon(
          onPressed: () async {
            if (await confirmAdmin(context, 'Deny this account?', 'They will be told the request was not approved.',
                action: 'Deny', danger: true)) {
              await run(() => actions.decideEducation(doc, approve: false), 'Denied');
            }
          },
          icon: const Icon(Icons.close_rounded, size: 18),
          label: const Text('Deny'),
        ),
      if (spec.can(AdminAction.edit) && spec.editableFields.isNotEmpty)
        FilledButton.tonalIcon(
          onPressed: () => showAdminEditDialog(context, ref, spec, doc),
          icon: const Icon(Icons.edit_rounded, size: 18),
          label: const Text('Edit'),
        ),
      if (spec.can(AdminAction.disable))
        OutlinedButton.icon(
          onPressed: () async {
            if (await confirmAdmin(context, isDisabled ? 'Enable this account?' : 'Disable this account?',
                isDisabled ? 'They will be able to sign in again.' : 'They will be signed out and blocked from signing in.',
                action: isDisabled ? 'Enable' : 'Disable', danger: !isDisabled)) {
              await run(() => actions.setDisabled(spec, [doc.id], !isDisabled), isDisabled ? 'Account enabled' : 'Account disabled');
            }
          },
          icon: Icon(isDisabled ? Icons.check_circle_outline_rounded : Icons.block_rounded, size: 18),
          label: Text(isDisabled ? 'Enable' : 'Disable'),
        ),
      if (spec.can(AdminAction.resetPassword) && doc.str('email').isNotEmpty)
        OutlinedButton.icon(
          onPressed: () async {
            if (await confirmAdmin(context, 'Send a password reset link?', 'To ${doc.str('email')}.', action: 'Send')) {
              await run(() => actions.resetPasswords([doc.str('email')]), 'Reset link sent');
            }
          },
          icon: const Icon(Icons.lock_reset_rounded, size: 18),
          label: const Text('Reset password'),
        ),
      if (spec.can(AdminAction.softDelete))
        OutlinedButton.icon(
          onPressed: () => run(() => actions.setDeleted(spec, [doc.id], !isDeleted), isDeleted ? 'Restored' : 'Soft-deleted'),
          icon: Icon(isDeleted ? Icons.restore_rounded : Icons.delete_outline_rounded, size: 18),
          label: Text(isDeleted ? 'Restore' : 'Soft delete'),
        ),
      if (spec.can(AdminAction.openAgronomistPanel))
        FilledButton.tonalIcon(
          onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const FieldAgronomistPanelScreen(testMode: true))),
          icon: const Icon(Icons.fact_check_rounded, size: 18),
          label: const Text('Open Agronomist panel'),
        ),
      if (spec.can(AdminAction.delete))
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFC62828), side: const BorderSide(color: Color(0xFFC62828))),
          onPressed: () async {
            if (await confirmAdmin(context, 'Delete this ${spec.singular}?', 'This can\'t be undone.',
                action: 'Delete', danger: true)) {
              await run(() => actions.delete(spec, [doc.id]), 'Deleted');
              onClose();
            }
          },
          icon: const Icon(Icons.delete_forever_rounded, size: 18),
          label: const Text('Delete'),
        ),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          AdminAvatar(spec: spec, doc: doc, size: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(spec.titleOf(doc), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kInk)),
              if (spec.subtitleOf(doc).isNotEmpty)
                Text(spec.subtitleOf(doc), style: const TextStyle(fontSize: 13, color: _kMuted)),
              if (status != null) ...[const SizedBox(height: 6), KmTag(status.label, status.color, filled: true)],
            ]),
          ),
          IconButton(tooltip: 'Close', icon: const Icon(Icons.close_rounded), onPressed: onClose),
        ]),
        if (buttons.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: buttons),
        ],
        const SizedBox(height: 16),
        for (final s in spec.sections) _SectionCard(spec: spec, section: s, doc: doc),
        if (other.isNotEmpty)
          _Card(
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('Other data (${other.length})', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                leading: const Icon(Icons.data_object_rounded, size: 20),
                children: [
                  for (final e in other)
                    _FieldRow(label: e.key, value: e.key == spec.imageField ? '(image)' : formatAdminValue(e.value)),
                ],
              ),
            ),
          ),
        _Card(
          child: Row(children: [
            const Icon(Icons.key_rounded, size: 16, color: _kMuted),
            const SizedBox(width: 8),
            Expanded(child: SelectableText(doc.id, style: const TextStyle(fontSize: 12.5, fontFamily: 'monospace'))),
            IconButton(
              tooltip: 'Copy ID',
              icon: const Icon(Icons.copy_rounded, size: 18),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: doc.id));
                showAdminSnack(context, 'ID copied');
              },
            ),
          ]),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  // Material (not a coloured Container) so tiles inside show their ripple.
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: _kBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 10), child: child),
        ),
      );
}

class _SectionCard extends StatelessWidget {
  final AdminCollectionSpec spec;
  final AdminSection section;
  final AdminDoc doc;
  const _SectionCard({required this.spec, required this.section, required this.doc});

  @override
  Widget build(BuildContext context) => _Card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(section.icon, size: 18, color: spec.color),
            const SizedBox(width: 8),
            Text(section.title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: spec.color)),
          ]),
          const SizedBox(height: 6),
          for (final f in section.fields)
            f.kind == FieldKind.user
                ? _FieldRow(label: f.label, child: doc.str(f.key).isEmpty ? null : PersonName(uid: doc.str(f.key)))
                : _FieldRow(label: f.label, value: formatAdminValue(doc[f.key], kind: f.kind, suffix: f.suffix)),
        ]),
      );
}

class _FieldRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? child;
  const _FieldRow({required this.label, this.value, this.child});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 130, child: Text(label, style: const TextStyle(fontSize: 12.5, color: _kMuted))),
          Expanded(
            child: child ??
                SelectableText(value ?? '—', style: const TextStyle(fontSize: 13.5, color: _kInk, height: 1.35)),
          ),
        ]),
      );
}

// ── Edit dialog (typed) ──────────────────────────────────────────────────────

Future<void> showAdminEditDialog(BuildContext context, WidgetRef ref, AdminCollectionSpec spec, AdminDoc doc) async {
  final fields = spec.editableFields.toList();
  final ctrls = {
    for (final f in fields)
      if (f.kind != FieldKind.boolean) f.key: TextEditingController(text: doc[f.key] == null ? '' : '${doc[f.key]}'),
  };
  final bools = {for (final f in fields) if (f.kind == FieldKind.boolean) f.key: doc[f.key] == true};
  final formKey = GlobalKey<FormState>();
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Edit ${spec.singular}'),
        content: SizedBox(
          width: 460,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (final f in fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: f.kind == FieldKind.boolean
                        ? SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(f.label),
                            value: bools[f.key]!,
                            onChanged: (v) => setState(() => bools[f.key] = v),
                          )
                        : TextFormField(
                            controller: ctrls[f.key],
                            maxLines: f.kind == FieldKind.multiline ? 4 : 1,
                            keyboardType: f.kind == FieldKind.number
                                ? const TextInputType.numberWithOptions(decimal: true)
                                : TextInputType.text,
                            decoration: InputDecoration(
                              labelText: f.label,
                              suffixText: f.suffix,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (t) {
                              try {
                                parseAdminEdit(f, t ?? '', doc[f.key]);
                                return null;
                              } on FormatException catch (e) {
                                return e.message;
                              }
                            },
                          ),
                  ),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Save changes'),
          ),
        ],
      ),
    ),
  );
  if (saved == true) {
    final edited = <String, dynamic>{
      for (final f in fields)
        f.key: f.kind == FieldKind.boolean ? bools[f.key] : parseAdminEdit(f, ctrls[f.key]!.text, doc[f.key]),
    };
    final changes = adminChanges(doc.data, edited);
    try {
      await ref.read(adminActionsProvider).update(spec, doc.id, changes);
      if (context.mounted) {
        showAdminSnack(context, changes.isEmpty ? 'Nothing changed' : 'Saved ${changes.length} change${changes.length == 1 ? '' : 's'}');
      }
    } catch (e) {
      if (context.mounted) showAdminSnack(context, friendlyError(e, 'Save failed'), error: true);
    }
  }
  for (final c in ctrls.values) {
    c.dispose();
  }
}

// ── Small shared bits ────────────────────────────────────────────────────────

Future<bool> confirmAdmin(BuildContext context, String title, String message,
        {required String action, bool danger = false}) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title),
        content: message.isEmpty ? null : Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: danger ? FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828)) : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

void showAdminSnack(BuildContext context, String text, {bool error = false}) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? const Color(0xFFC62828) : const Color(0xFF1B5E20),
    ));

class _Message extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String text;
  final Widget? action;
  const _Message({required this.icon, required this.color, required this.title, required this.text, this.action});

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 36, color: color),
            ),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
            if (text.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(text, textAlign: TextAlign.center, style: const TextStyle(color: _kMuted, fontSize: 13)),
            ],
            if (action != null) ...[const SizedBox(height: 8), action!],
          ]),
        ),
      );
}

/// The value chosen in [pickAdminValue]; `value == null` means "all".
class AdminValuePick {
  final String? value;
  const AdminValuePick(this.value);
}

/// Searchable list of a field's values with record counts (e.g. every
/// county and how many farmers are in it). Returns null if dismissed.
Future<AdminValuePick?> pickAdminValue(
  BuildContext context, {
  required AdminCollectionSpec spec,
  required AdminFilter filter,
  required List<(String, int)> options,
  String? selected,
  String? allLabel,
}) {
  final wide = MediaQuery.sizeOf(context).width >= 700;
  final body = _ValuePicker(spec: spec, filter: filter, options: options, selected: selected, allLabel: allLabel);
  if (wide) {
    return showDialog<AdminValuePick>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560), child: body),
      ),
    );
  }
  return showModalBottomSheet<AdminValuePick>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SizedBox(height: MediaQuery.sizeOf(ctx).height * 0.75, child: body),
  );
}

class _ValuePicker extends StatefulWidget {
  final AdminCollectionSpec spec;
  final AdminFilter filter;
  final List<(String, int)> options;
  final String? selected;
  final String? allLabel;
  const _ValuePicker({required this.spec, required this.filter, required this.options, this.selected, this.allLabel});

  @override
  State<_ValuePicker> createState() => _ValuePickerState();
}

class _ValuePickerState extends State<_ValuePicker> {
  String _q = '';
  bool _az = false; // false = most records first

  @override
  Widget build(BuildContext context) {
    final color = widget.spec.color;
    final list = widget.options.where((o) => o.$1.toLowerCase().contains(_q.toLowerCase())).toList();
    if (_az) list.sort((a, b) => a.$1.toLowerCase().compareTo(b.$1.toLowerCase()));
    final total = widget.options.fold<int>(0, (a, o) => a + o.$2);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text('Choose ${widget.filter.label.toLowerCase()}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          TextButton.icon(
            onPressed: () => setState(() => _az = !_az),
            icon: Icon(_az ? Icons.sort_by_alpha_rounded : Icons.bar_chart_rounded, size: 18),
            label: Text(_az ? 'A–Z' : 'Most records'),
          ),
        ]),
        const SizedBox(height: 8),
        TextField(
          autofocus: MediaQuery.sizeOf(context).width >= 700,
          onChanged: (v) => setState(() => _q = v),
          decoration: InputDecoration(
            hintText: 'Search ${widget.options.length} ${widget.filter.label.toLowerCase()} values…',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(children: [
            if (_q.isEmpty)
              _PickRow(
                label: widget.allLabel ?? 'All',
                count: total,
                color: color,
                selected: widget.selected == null,
                icon: Icons.select_all_rounded,
                onTap: () => Navigator.pop(context, const AdminValuePick(null)),
              ),
            for (final (value, count) in list)
              _PickRow(
                label: value,
                count: count,
                color: color,
                selected: value == widget.selected,
                onTap: () => Navigator.pop(context, AdminValuePick(value)),
              ),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No matching values', textAlign: TextAlign.center, style: TextStyle(color: _kMuted)),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _PickRow extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final IconData? icon;
  final VoidCallback onTap;
  const _PickRow({required this.label, required this.count, required this.color, required this.selected, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) => ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        selected: selected,
        selectedTileColor: color.withValues(alpha: 0.08),
        leading: Icon(icon ?? (selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded),
            color: selected ? color : _kMuted, size: 20),
        title: Text(label, style: TextStyle(fontWeight: selected ? FontWeight.w800 : FontWeight.w500)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
          child: Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
        ),
        onTap: onTap,
      );
}
