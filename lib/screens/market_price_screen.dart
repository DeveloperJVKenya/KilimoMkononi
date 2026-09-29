// lib/screens/market_price_screen.dart
//
// Market Prices: a price board built from reports farmers submit, plus the
// official KAMIS site.
//   • pick a crop → average price, range, 30-day trend and the best market
//     to sell at (lib/screens/market/market_prices.dart does the maths)
//   • filter by county and market, sort by newest / highest / lowest
//   • "Report a price" (crop, market, county, price, unit); edit or delete
//     your own reports; "My reports" view
//   • responsive: summary beside the list on wide screens

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kilimomkononi/authentication/widgets/auth_kit.dart' show EnterToSubmit;
import 'package:kilimomkononi/data/kenya_locations.dart';
import 'package:kilimomkononi/screens/market/market_prices.dart';
import 'package:kilimomkononi/settings/notifications/notification_style.dart' show fullStamp, relativeTime, KmTag;
import 'package:url_launcher/url_launcher.dart';

const _kOrange = Color(0xFFEF6C00);
const _kOrangeDark = Color(0xFFBF360C);
const _kGreen = Color(0xFF2E7D32);
const _kRed = Color(0xFFC62828);
const _kPage = Color(0xFFF7F5F2);
const _kInk = Color(0xFF1F2937);
const _kMuted = Color(0xFF6B7280);
const _kBorder = Color(0xFFE7E1DA);

class MarketPriceScreen extends ConsumerWidget {
  const MarketPriceScreen({super.key});

  static const kamisUrl = 'https://kamis.kilimo.go.ke/site/market';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(priceBoardProvider);
    final q = ref.watch(priceQueryProvider);
    return Scaffold(
      backgroundColor: _kPage,
      appBar: AppBar(
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [_kOrangeDark, _kOrange])),
        ),
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Market Prices', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          Text('Know the price before you sell', style: TextStyle(fontSize: 11.5, color: Colors.white70)),
        ]),
        actions: [
          IconButton(
            tooltip: 'Official KAMIS prices',
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: () => openKamis(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _kOrange,
        foregroundColor: Colors.white,
        onPressed: () => showPriceForm(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Report a price'),
      ),
      body: board.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _kOrange)),
        error: (e, _) => _Empty(
          icon: Icons.cloud_off_rounded,
          title: 'Couldn\'t load prices',
          text: 'Check your connection. You can still open the official KAMIS prices.',
          action: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: _kOrange),
            onPressed: () => openKamis(context),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Open KAMIS'),
          ),
        ),
        data: (b) => LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 980;
          final side = c.maxWidth > 1132 ? (c.maxWidth - 1100) / 2 : 12.0;
          final filters = _Filters(board: b, query: q);
          final summary = q.crop == null
              ? _PickCropHint(board: b)
              : (b.summary == null ? const SizedBox.shrink() : _SummaryCard(summary: b.summary!, region: q.region));
          final list = _ReportList(board: b, query: q);
          if (wide) {
            return Padding(
              padding: EdgeInsets.fromLTRB(side, 12, side, 0),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: 400,
                  child: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
                    const _KamisCard(),
                    const SizedBox(height: 12),
                    summary,
                  ]),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(children: [
                    filters,
                    Expanded(child: list),
                  ]),
                ),
              ]),
            );
          }
          return CustomScrollView(slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(side, 12, side, 0),
              sliver: SliverList.list(children: [
                const _KamisCard(),
                const SizedBox(height: 12),
                filters,
                summary,
                const SizedBox(height: 8),
              ]),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(side, 0, side, 96),
              sliver: _ReportSliver(board: b, query: q),
            ),
          ]);
        }),
      ),
    );
  }
}

Future<void> openKamis(BuildContext context) async {
  try {
    final ok = await launchUrl(Uri.parse(MarketPriceScreen.kamisUrl),
        mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Couldn\'t open the browser')));
    }
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Couldn\'t open KAMIS: $e')));
  }
}

// ── KAMIS card ───────────────────────────────────────────────────────────────

class _KamisCard extends StatelessWidget {
  const _KamisCard();

  @override
  Widget build(BuildContext context) => Material(
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openKamis(context),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF0B3D1E), Color(0xFF1B5E20), Color(0xFF00695C)]),
            ),
            child: const Row(children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white24,
                child: Icon(Icons.account_balance_rounded, color: Colors.white),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Official daily prices — KAMIS',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                  SizedBox(height: 2),
                  Text('Kenya Agricultural Market Information System (Ministry of Agriculture)',
                      style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                ]),
              ),
              Icon(Icons.open_in_new_rounded, color: Colors.white, size: 20),
            ]),
          ),
        ),
      );
}

// ── Filters ──────────────────────────────────────────────────────────────────

class _Filters extends ConsumerWidget {
  final PriceBoard board;
  final PriceQuery query;
  const _Filters({required this.board, required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(priceQueryProvider.notifier);
    void set(PriceQuery q) => n.set(q);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SegmentedButton<bool>(
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: _kOrange,
          selectedForegroundColor: Colors.white,
          backgroundColor: Colors.white,
        ),
        segments: const [
          ButtonSegment(value: false, label: Text('All prices'), icon: Icon(Icons.public_rounded, size: 18)),
          ButtonSegment(value: true, label: Text('My reports'), icon: Icon(Icons.person_rounded, size: 18)),
        ],
        selected: {query.mineOnly},
        onSelectionChanged: (s) => set(query.copyWith(mineOnly: s.first)),
      ),
      const SizedBox(height: 10),
      SizedBox(
        height: 38,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          _Chip(label: 'All crops', selected: query.crop == null, onTap: () => set(query.copyWith(crop: () => null))),
          for (final (crop, count) in board.crops)
            _Chip(
              label: '$crop  $count',
              selected: query.crop != null && query.crop!.toLowerCase() == crop.toLowerCase(),
              onTap: () => set(query.copyWith(crop: () => crop, market: () => null)),
            ),
        ]),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _PickerButton(
          icon: Icons.map_outlined,
          label: query.region ?? 'All counties',
          active: query.region != null,
          onTap: () async {
            final v = await _pickValue(context, 'County', board.regions, query.region);
            if (v != null) set(query.copyWith(region: () => v.isEmpty ? null : v));
          },
        ),
        _PickerButton(
          icon: Icons.storefront_rounded,
          label: query.market ?? 'All markets',
          active: query.market != null,
          onTap: () async {
            final v = await _pickValue(context, 'Market', board.markets, query.market);
            if (v != null) set(query.copyWith(market: () => v.isEmpty ? null : v));
          },
        ),
        PopupMenuButton<PriceSort>(
          tooltip: 'Sort',
          onSelected: (s) => set(query.copyWith(sort: s)),
          itemBuilder: (_) => [
            for (final s in PriceSort.values)
              CheckedPopupMenuItem(value: s, checked: s == query.sort, child: Text(_sortLabel(s))),
          ],
          child: _PickerButton(icon: Icons.sort_rounded, label: _sortLabel(query.sort), active: false),
        ),
        if (query.region != null || query.market != null || query.crop != null)
          TextButton.icon(
            onPressed: () => set(PriceQuery(mineOnly: query.mineOnly, sort: query.sort)),
            icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
            label: const Text('Clear'),
            style: TextButton.styleFrom(foregroundColor: _kOrangeDark),
          ),
      ]),
      const SizedBox(height: 12),
    ]);
  }

  static String _sortLabel(PriceSort s) => switch (s) {
        PriceSort.newest => 'Newest first',
        PriceSort.highest => 'Highest price',
        PriceSort.lowest => 'Lowest price',
      };
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          showCheckmark: false,
          selectedColor: _kOrange,
          backgroundColor: Colors.white,
          side: BorderSide(color: selected ? _kOrange : _kBorder),
          labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: selected ? Colors.white : _kInk),
        ),
      );
}

class _PickerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;
  const _PickerButton({required this.icon, required this.label, required this.active, this.onTap});

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFFFF3E0) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? _kOrange : _kBorder),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: active ? _kOrangeDark : _kMuted),
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 170),
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: active ? _kOrangeDark : _kInk)),
        ),
        const Icon(Icons.expand_more_rounded, size: 16, color: _kMuted),
      ]),
    );
    return onTap == null ? body : InkWell(borderRadius: BorderRadius.circular(20), onTap: onTap, child: body);
  }
}

/// Searchable list with counts; returns '' for "All", null when dismissed.
Future<String?> _pickValue(BuildContext context, String label, List<(String, int)> options, String? selected) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      var q = '';
      return StatefulBuilder(
        builder: (ctx, setState) {
          final list = options.where((o) => o.$1.toLowerCase().contains(q.toLowerCase())).toList();
          return SizedBox(
            height: MediaQuery.sizeOf(ctx).height * 0.7,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Choose ${label.toLowerCase()}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (v) => setState(() => q = v),
                  decoration: InputDecoration(
                    hintText: 'Search ${label.toLowerCase()}s…',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(children: [
                    if (q.isEmpty)
                      ListTile(
                        leading: Icon(selected == null ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: selected == null ? _kOrange : _kMuted),
                        title: Text('All ${label.toLowerCase()}s'),
                        onTap: () => Navigator.pop(ctx, ''),
                      ),
                    for (final (v, count) in list)
                      ListTile(
                        leading: Icon(v == selected ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: v == selected ? _kOrange : _kMuted),
                        title: Text(v),
                        trailing: Text('$count report${count == 1 ? '' : 's'}',
                            style: const TextStyle(color: _kMuted, fontSize: 12)),
                        onTap: () => Navigator.pop(ctx, v),
                      ),
                    if (list.isEmpty && options.isNotEmpty)
                      const Padding(padding: EdgeInsets.all(20), child: Text('No matches', textAlign: TextAlign.center)),
                    if (options.isEmpty)
                      const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('No reports yet for this selection', textAlign: TextAlign.center)),
                  ]),
                ),
              ]),
            ),
          );
        },
      );
    },
  );
}

// ── Summary ──────────────────────────────────────────────────────────────────

class _PickCropHint extends ConsumerWidget {
  final PriceBoard board;
  const _PickCropHint({required this.board});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = board.crops.take(6).toList();
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.insights_rounded, color: _kOrange),
          SizedBox(width: 8),
          Expanded(
            child: Text('Choose a crop to see its price summary',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
          ),
        ]),
        const SizedBox(height: 6),
        const Text('Average price, lowest and highest, the 30-day trend and the best market to sell at.',
            style: TextStyle(color: _kMuted, fontSize: 12.5, height: 1.4)),
        if (top.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (crop, _) in top)
              ActionChip(
                label: Text(crop),
                avatar: const Icon(Icons.eco_rounded, size: 16, color: _kGreen),
                onPressed: () {
                  final n = ref.read(priceQueryProvider.notifier);
                  n.set(ref.read(priceQueryProvider).copyWith(crop: () => crop));
                },
              ),
          ]),
        ],
      ]),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final CropSummary summary;
  final String? region;
  const _SummaryCard({required this.summary, this.region});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final unit = s.unit.isEmpty ? '' : ' ${s.unit}';
    final change = s.trendChangePct;
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.eco_rounded, color: _kGreen),
          const SizedBox(width: 8),
          Expanded(
            child: Text('${s.crop}${region == null ? '' : ' · $region'}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          KmTag(s.recentOnly ? 'Last 30 days' : 'All time', _kOrangeDark),
        ]),
        const SizedBox(height: 12),
        Text('Average price', style: const TextStyle(color: _kMuted, fontSize: 12)),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.bottomLeft,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(formatKes(s.average),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _kInk)),
                Padding(
                  padding: const EdgeInsets.only(bottom: 5, left: 4),
                  child: Text(unit, style: const TextStyle(color: _kMuted, fontSize: 13)),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          if (change != null)
            Row(children: [
              Icon(change >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  color: change >= 0 ? _kGreen : _kRed),
              const SizedBox(width: 3),
              Text('${change >= 0 ? '+' : ''}${change.toStringAsFixed(0)}%',
                  style: TextStyle(fontWeight: FontWeight.w800, color: change >= 0 ? _kGreen : _kRed)),
            ]),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _MiniStat('Lowest', formatKes(s.min), _kRed)),
          Expanded(child: _MiniStat('Highest', formatKes(s.max), _kGreen)),
          Expanded(child: _MiniStat('Reports', '${s.count}', _kOrangeDark)),
        ]),
        if (s.trend.length >= 2) ...[
          const SizedBox(height: 14),
          const Text('Price trend', style: TextStyle(color: _kMuted, fontSize: 12)),
          const SizedBox(height: 6),
          SizedBox(height: 70, child: CustomPaint(painter: _TrendPainter(s.trend), size: Size.infinite)),
        ],
        if (s.best != null) ...[
          const Divider(height: 24),
          _MarketLine(icon: Icons.emoji_events_rounded, color: _kGreen, label: 'Best place to sell', stat: s.best!),
          const SizedBox(height: 6),
          _MarketLine(icon: Icons.south_rounded, color: _kRed, label: 'Lowest prices', stat: s.lowest!),
        ],
        const SizedBox(height: 10),
        Text('Latest report ${relativeTime(s.latest)} · reported by farmers — compare with KAMIS before selling.',
            style: const TextStyle(color: _kMuted, fontSize: 11.5, height: 1.4)),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: _kMuted, fontSize: 11.5)),
        Text(value, style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 14)),
      ]);
}

class _MarketLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final MarketStat stat;
  const _MarketLine({required this.icon, required this.color, required this.label, required this.stat});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(TextSpan(children: [
            TextSpan(text: '$label: ', style: const TextStyle(color: _kMuted)),
            TextSpan(text: stat.market, style: const TextStyle(fontWeight: FontWeight.w800, color: _kInk)),
          ])),
        ),
        Text(formatKes(stat.average), style: TextStyle(fontWeight: FontWeight.w800, color: color)),
      ]);
}

class _TrendPainter extends CustomPainter {
  final List<(DateTime, double)> points;
  _TrendPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final minV = points.map((p) => p.$2).reduce(math.min);
    final maxV = points.map((p) => p.$2).reduce(math.max);
    final t0 = points.first.$1.millisecondsSinceEpoch.toDouble();
    final t1 = points.last.$1.millisecondsSinceEpoch.toDouble();
    Offset at((DateTime, double) p) {
      final x = t1 == t0 ? 0.0 : (p.$1.millisecondsSinceEpoch - t0) / (t1 - t0) * size.width;
      final y = maxV == minV ? size.height / 2 : size.height - (p.$2 - minV) / (maxV - minV) * (size.height - 8) - 4;
      return Offset(x, y);
    }

    final path = Path()..moveTo(at(points.first).dx, at(points.first).dy);
    for (final p in points.skip(1)) {
      path.lineTo(at(p).dx, at(p).dy);
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
        fill,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x55EF6C00), Color(0x00EF6C00)],
          ).createShader(Offset.zero & size));
    canvas.drawPath(
        path,
        Paint()
          ..color = _kOrange
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);
    canvas.drawCircle(at(points.last), 4, Paint()..color = _kOrangeDark);
  }

  @override
  bool shouldRepaint(_TrendPainter old) => old.points != points;
}

// ── Reports ──────────────────────────────────────────────────────────────────

class _ReportList extends StatelessWidget {
  final PriceBoard board;
  final PriceQuery query;
  const _ReportList({required this.board, required this.query});

  @override
  Widget build(BuildContext context) => CustomScrollView(slivers: [
        SliverPadding(padding: const EdgeInsets.only(bottom: 96), sliver: _ReportSliver(board: board, query: query)),
      ]);
}

class _ReportSliver extends ConsumerWidget {
  final PriceBoard board;
  final PriceQuery query;
  const _ReportSliver({required this.board, required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(marketUidProvider);
    final items = board.shown;
    if (items.isEmpty) {
      return SliverToBoxAdapter(
        child: _Empty(
          icon: query.mineOnly ? Icons.edit_note_rounded : Icons.storefront_rounded,
          title: query.mineOnly ? 'You haven\'t reported any prices yet' : 'No price reports here yet',
          text: 'Seen a price at the market? Tap "Report a price" to help other farmers.',
        ),
      );
    }
    return SliverList.builder(
      itemCount: items.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 2),
            child: Text('${items.length} report${items.length == 1 ? '' : 's'}',
                style: const TextStyle(color: _kMuted, fontSize: 12, fontWeight: FontWeight.w700)),
          );
        }
        return _ReportCard(report: items[i - 1], mine: items[i - 1].isMine(uid));
      },
    );
  }
}

class _ReportCard extends ConsumerWidget {
  final PriceReport report;
  final bool mine;
  const _ReportCard({required this.report, required this.mine});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = report;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: mine ? () => showPriceForm(context, ref, existing: r) : null,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: mine ? _kOrange.withValues(alpha: 0.5) : _kBorder),
            ),
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(12)),
                child: Text(r.crop.isEmpty ? '?' : r.crop[0],
                    style: const TextStyle(color: _kOrangeDark, fontWeight: FontWeight.w900, fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(
                      child: Text(r.crop,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: _kInk)),
                    ),
                    if (mine) ...[const SizedBox(width: 6), const KmTag('You', _kOrange)],
                  ]),
                  const SizedBox(height: 2),
                  Text([r.market, r.region].where((s) => s.isNotEmpty).join(' · '),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _kMuted, fontSize: 12.5)),
                  const SizedBox(height: 2),
                  Tooltip(
                    message: fullStamp(r.at),
                    child: Text(relativeTime(r.at), style: const TextStyle(color: _kMuted, fontSize: 11.5)),
                  ),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(formatKes(r.price), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _kInk)),
                if (r.unit.isNotEmpty) Text(r.unit, style: const TextStyle(color: _kMuted, fontSize: 11.5)),
                if (mine) const Icon(Icons.edit_rounded, size: 14, color: _kOrange),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Report form ──────────────────────────────────────────────────────────────

Future<void> showPriceForm(BuildContext context, WidgetRef ref, {PriceReport? existing}) async {
  final markets = ref.read(priceBoardProvider).value?.markets.map((m) => m.$1).toList() ?? const <String>[];
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: _PriceForm(existing: existing, knownMarkets: markets),
    ),
  );
}

class _PriceForm extends StatefulWidget {
  final PriceReport? existing;
  final List<String> knownMarkets;
  const _PriceForm({this.existing, required this.knownMarkets});

  @override
  State<_PriceForm> createState() => _PriceFormState();
}

class _PriceFormState extends State<_PriceForm> {
  final _key = GlobalKey<FormState>();
  late String _crop = _initialCrop();
  final _otherCrop = TextEditingController();
  late final _market = TextEditingController(text: widget.existing?.market ?? '');
  late final _price = TextEditingController(
      text: widget.existing == null ? '' : widget.existing!.price.toStringAsFixed(widget.existing!.price % 1 == 0 ? 0 : 2));
  late String? _county = _initialCounty();
  late String _unit =
      widget.existing?.unit.isNotEmpty == true && kPriceUnits.contains(widget.existing!.unit) ? widget.existing!.unit : 'per kg';
  TextEditingController? _marketField; // Autocomplete's own controller
  bool _saving = false;
  String? _error;

  String _initialCrop() {
    final c = widget.existing?.crop;
    if (c == null) return kMarketCrops.first;
    final match = kMarketCrops.where((k) => k.toLowerCase() == c.toLowerCase()).firstOrNull;
    if (match != null) return match;
    _otherCrop.text = c;
    return 'Other';
  }

  String? _initialCounty() {
    final r = widget.existing?.region;
    if (r == null || r.isEmpty) return null;
    return kenyaLocations.keys.where((k) => k.toLowerCase() == r.toLowerCase()).firstOrNull;
  }

  @override
  void dispose() {
    _otherCrop.dispose();
    _market.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_key.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await PriceReportsRepository.save(
        id: widget.existing?.id,
        crop: _crop == 'Other' ? _otherCrop.text : _crop,
        market: _market.text,
        region: _county ?? '',
        price: double.parse(_price.text.replaceAll(',', '').trim()),
        unit: _unit,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.existing == null ? 'Thanks! Your price report helps other farmers.' : 'Report updated'),
        backgroundColor: _kGreen,
      ));
    } catch (e) {
      setState(() => _error = 'Couldn\'t save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this report?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _kRed),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await PriceReportsRepository.delete(widget.existing!.id);
    if (mounted) Navigator.pop(context);
  }

  InputDecoration _dec(String label, IconData icon, {String? hint, String? prefix}) => InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefix,
        prefixIcon: Icon(icon, size: 20),
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  @override
  Widget build(BuildContext context) {
    final counties = kenyaLocations.keys.toList()..sort();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: EnterToSubmit(
          onSubmit: _save,
          enabled: !_saving,
          child: Form(
            key: _key,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(widget.existing == null ? 'Report a market price' : 'Edit your report',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('What did you see buyers paying today?', style: TextStyle(color: _kMuted)),
              const SizedBox(height: 16),
              if (_error != null)
                Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!, style: const TextStyle(color: _kRed))),
              DropdownButtonFormField<String>(
                initialValue: _crop,
                isExpanded: true,
                decoration: _dec('Crop', Icons.eco_rounded),
                items: [for (final c in [...kMarketCrops, 'Other']) DropdownMenuItem(value: c, child: Text(c))],
                onChanged: (v) => setState(() => _crop = v ?? _crop),
              ),
              if (_crop == 'Other') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _otherCrop,
                  textCapitalization: TextCapitalization.words,
                  decoration: _dec('Crop name', Icons.edit_rounded),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Enter the crop name' : null,
                ),
              ],
              const SizedBox(height: 12),
              Autocomplete<String>(
                initialValue: TextEditingValue(text: _market.text),
                optionsBuilder: (v) => v.text.isEmpty
                    ? const Iterable<String>.empty()
                    : widget.knownMarkets.where((m) => m.toLowerCase().contains(v.text.toLowerCase())),
                onSelected: (m) => _market.text = m,
                fieldViewBuilder: (context, ctrl, focus, onSubmit) {
                  if (!identical(ctrl, _marketField)) {
                    _marketField = ctrl..addListener(() => _market.text = ctrl.text);
                  }
                  return TextFormField(
                    controller: ctrl,
                    focusNode: focus,
                    textCapitalization: TextCapitalization.words,
                    decoration: _dec('Market', Icons.storefront_rounded, hint: 'e.g. Wakulima Market, Nairobi'),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Enter the market' : null,
                  );
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _county,
                isExpanded: true,
                menuMaxHeight: 360,
                decoration: _dec('County', Icons.map_outlined),
                items: [for (final c in counties) DropdownMenuItem(value: c, child: Text(c))],
                onChanged: (v) => setState(() => _county = v),
                validator: (v) => v == null ? 'Choose the county' : null,
              ),
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    decoration: _dec('Price', Icons.payments_rounded, prefix: 'KES '),
                    validator: (v) {
                      final p = double.tryParse((v ?? '').replaceAll(',', '').trim());
                      if (p == null || p <= 0) return 'Enter a price';
                      if (p >= 10000000) return 'That price is too high';
                      return null;
                    },
                    onFieldSubmitted: (_) => _save(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _unit,
                    isExpanded: true,
                    decoration: _dec('Unit', Icons.scale_rounded),
                    items: [for (final u in kPriceUnits) DropdownMenuItem(value: u, child: Text(u))],
                    onChanged: (v) => setState(() => _unit = v ?? _unit),
                  ),
                ),
              ]),
              const SizedBox(height: 18),
              Row(children: [
                if (widget.existing != null)
                  TextButton.icon(
                    onPressed: _saving ? null : _delete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete'),
                    style: TextButton.styleFrom(foregroundColor: _kRed),
                  ),
                const Spacer(),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _kOrange, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_rounded),
                  label: Text(widget.existing == null ? 'Submit price' : 'Save changes'),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Shared bits ──────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
        ),
        child: child,
      );
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final Widget? action;
  const _Empty({required this.icon, required this.title, required this.text, this.action});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: Color(0xFFFFF3E0), shape: BoxShape.circle),
            child: Icon(icon, size: 36, color: _kOrange),
          ),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: _kMuted, height: 1.4)),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ]),
      );
}
