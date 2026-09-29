// lib/screens/farming_tips_widget.dart
//
// Farming Tips: a library of step-by-step crop guides.
//   • search across crops, varieties and every tip
//   • "Your crops" (from your field data) and "Saved" guides first
//   • crop guide: Overview (key points, season at a glance), Growth stages
//     (timeline from land preparation to storage) and Varieties (what each is
//     best for) — copy any section to share it
// Data and matching live in lib/screens/tips/farming_tips_data.dart.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kilimomkononi/screens/tips/farming_tips_data.dart';

const _kGreen = Color(0xFF2E7D32);
const _kGreenDark = Color(0xFF1B5E20);
const _kLime = Color(0xFF9E9D24);
const _kPage = Color(0xFFF4F7F2);
const _kInk = Color(0xFF1F2937);
const _kMuted = Color(0xFF6B7280);
const _kBorder = Color(0xFFE1E8DC);

enum _Shelf { all, mine, saved }

class FarmingTipsWidget extends ConsumerStatefulWidget {
  const FarmingTipsWidget({super.key});

  @override
  ConsumerState<FarmingTipsWidget> createState() => _FarmingTipsWidgetState();
}

class _FarmingTipsWidgetState extends ConsumerState<FarmingTipsWidget> {
  final _search = TextEditingController();
  _Shelf _shelf = _Shelf.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lib = ref.watch(tipsLibraryProvider);
    final mine = ref.watch(myGuideKeysProvider);
    final saved = ref.watch(savedGuidesProvider);
    final q = _search.text.trim();

    return Scaffold(
      backgroundColor: _kPage,
      appBar: AppBar(
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [_kGreenDark, _kGreen, _kLime])),
        ),
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Farming Tips', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          Text('Step-by-step guides, from planting to storage', style: TextStyle(fontSize: 11.5, color: Colors.white70)),
        ]),
      ),
      body: lib.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _kGreen)),
        error: (e, _) => _Message(icon: Icons.error_outline_rounded, title: 'Couldn\'t load the guides', text: '$e'),
        data: (guides) {
          // Your crops first, then saved, then the rest (file order).
          int rank(CropGuide g) => mine.contains(g.key) ? 0 : (saved.contains(g.key) ? 1 : 2);
          final ordered = [...guides]..sort((a, b) => rank(a).compareTo(rank(b)));
          final shown = ordered.where((g) {
            if (_shelf == _Shelf.mine && !mine.contains(g.key)) return false;
            if (_shelf == _Shelf.saved && !saved.contains(g.key)) return false;
            return g.matches(q);
          }).toList();

          return LayoutBuilder(builder: (context, c) {
            final side = c.maxWidth > 1132 ? (c.maxWidth - 1100) / 2 : 16.0;
            return CustomScrollView(slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(side, 16, side, 0),
                sliver: SliverList.list(children: [
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search crops, varieties or a problem (e.g. armyworm, spacing)',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: q.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => setState(_search.clear),
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _kBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _kBorder)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _ShelfChip('All crops', guides.length, _shelf == _Shelf.all, () => setState(() => _shelf = _Shelf.all)),
                    _ShelfChip('Your crops', mine.length, _shelf == _Shelf.mine, () => setState(() => _shelf = _Shelf.mine),
                        icon: Icons.agriculture_rounded),
                    _ShelfChip('Saved', saved.length, _shelf == _Shelf.saved, () => setState(() => _shelf = _Shelf.saved),
                        icon: Icons.bookmark_rounded),
                  ]),
                  const SizedBox(height: 14),
                ]),
              ),
              if (shown.isEmpty)
                SliverToBoxAdapter(
                  child: _Message(
                    icon: _shelf == _Shelf.saved ? Icons.bookmark_border_rounded : Icons.search_off_rounded,
                    title: switch (_shelf) {
                      _ when q.isNotEmpty => 'Nothing matches "$q"',
                      _Shelf.saved => 'No saved guides yet',
                      _Shelf.mine => 'No guides for your recorded crops yet',
                      _Shelf.all => 'No guides',
                    },
                    text: switch (_shelf) {
                      _ when q.isNotEmpty => 'Try a crop name or a simpler word.',
                      _Shelf.saved => 'Tap the bookmark on a crop to keep it here.',
                      _Shelf.mine => 'Add your crops in Field Data Input and their guides will show here.',
                      _Shelf.all => '',
                    },
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(side, 0, side, 32),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 280,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      mainAxisExtent: 214 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3),
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _CropCard(
                        guide: shown[i],
                        mine: mine.contains(shown[i].key),
                        saved: saved.contains(shown[i].key),
                        query: q,
                      ),
                      childCount: shown.length,
                    ),
                  ),
                ),
            ]);
          });
        },
      ),
    );
  }
}

class _ShelfChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  const _ShelfChip(this.label, this.count, this.selected, this.onTap, {this.icon});

  @override
  Widget build(BuildContext context) => ChoiceChip(
        avatar: icon == null ? null : Icon(icon, size: 16, color: selected ? Colors.white : _kGreen),
        label: Text('$label · $count'),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: _kGreen,
        backgroundColor: Colors.white,
        side: BorderSide(color: selected ? _kGreen : _kBorder),
        labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: selected ? Colors.white : _kInk),
      );
}

class _CropCard extends ConsumerWidget {
  final CropGuide guide;
  final bool mine;
  final bool saved;
  final String query;
  const _CropCard({required this.guide, required this.mine, required this.saved, required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = guide;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CropGuideScreen(guide: g))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              GuideImage(path: g.image, emoji: g.emoji),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x22000000), Colors.transparent, Color(0x99000000)],
                  ),
                ),
              ),
              Positioned(
                left: 10,
                top: 8,
                child: mine ? const _Pill('Your crop', Icons.agriculture_rounded) : const SizedBox.shrink(),
              ),
              Positioned(
                right: 2,
                top: 0,
                child: IconButton(
                  tooltip: saved ? 'Remove from saved' : 'Save this guide',
                  icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: Colors.white),
                  onPressed: () => ref.read(savedGuidesProvider.notifier).toggle(g.key),
                ),
              ),
              Positioned(
                left: 12,
                bottom: 8,
                right: 12,
                child: Text('${g.emoji}  ${g.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                g.general.isEmpty ? 'Growing guide' : g.general.first.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _kInk, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.timeline_rounded, size: 14, color: _kGreen),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${g.stages.length} stage${g.stages.length == 1 ? '' : 's'} · '
                    '${g.varieties.length} variet${g.varieties.length == 1 ? 'y' : 'ies'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _kMuted, fontSize: 11.5),
                  ),
                ),
                if (query.isNotEmpty && !g.name.toLowerCase().contains(query.toLowerCase()))
                  const Tooltip(
                    message: 'Your search appears in this guide',
                    child: Icon(Icons.manage_search_rounded, size: 16, color: _kLime),
                  ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final IconData icon;
  const _Pill(this.label, this.icon);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: _kGreen, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      );
}

/// Asset image with a green emoji tile when the file is missing.
class GuideImage extends StatelessWidget {
  final String? path;
  final String emoji;
  final double emojiSize;
  const GuideImage({super.key, required this.path, required this.emoji, this.emojiSize = 44});

  @override
  Widget build(BuildContext context) {
    final fallback = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFDCEDC8), Color(0xFFA5D6A7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(child: Text(emoji, style: TextStyle(fontSize: emojiSize))),
    );
    if (path == null) return fallback;
    return Image.asset(path!, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback);
  }
}

// ── Crop guide ───────────────────────────────────────────────────────────────

class CropGuideScreen extends ConsumerStatefulWidget {
  final CropGuide guide;
  final int initialTab;
  const CropGuideScreen({super.key, required this.guide, this.initialTab = 0});

  @override
  ConsumerState<CropGuideScreen> createState() => _CropGuideScreenState();
}

class _CropGuideScreenState extends ConsumerState<CropGuideScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
  int _openStage = 0;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _goToStage(int i) {
    setState(() => _openStage = i);
    _tabs.animateTo(1);
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.guide;
    final saved = ref.watch(savedGuidesProvider).contains(g.key);
    return Scaffold(
      backgroundColor: _kPage,
      appBar: AppBar(
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [_kGreenDark, _kGreen, _kLime])),
        ),
        title: Text('${g.emoji}  ${g.name}', style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: saved ? 'Remove from saved' : 'Save this guide',
            icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
            onPressed: () => ref.read(savedGuidesProvider.notifier).toggle(g.key),
          ),
          IconButton(
            tooltip: 'Copy the whole guide',
            icon: const Icon(Icons.copy_all_rounded),
            onPressed: () => _copy(context, g.asText(), 'Guide copied — paste it anywhere to share'),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800),
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.info_outline_rounded, size: 20)),
            Tab(text: 'Growth stages', icon: Icon(Icons.timeline_rounded, size: 20)),
            Tab(text: 'Varieties', icon: Icon(Icons.grass_rounded, size: 20)),
          ],
        ),
      ),
      body: TabBarView(controller: _tabs, children: [
        _Centered(child: _Overview(guide: g, onStage: _goToStage, onVarieties: () => _tabs.animateTo(2))),
        _Centered(
          child: _Stages(
            guide: g,
            open: _openStage,
            onToggle: (i) => setState(() => _openStage = _openStage == i ? -1 : i),
          ),
        ),
        _Centered(child: _Varieties(guide: g)),
      ]),
    );
  }
}

void _copy(BuildContext context, String text, String message) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), backgroundColor: _kGreen));
}

String _itemsText(String title, List<TipItem> items) {
  final b = StringBuffer('$title\n');
  for (final t in items) {
    b.writeln('• ${t.text}');
    for (final s in t.subs) {
      b.writeln('   – $s');
    }
  }
  return b.toString();
}

/// Caps the reading width at 820 px.
class _Centered extends StatelessWidget {
  final Widget child;
  const _Centered({required this.child});

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 820), child: child),
      );
}

IconData stageIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('land') || n.contains('prep')) return Icons.agriculture_rounded;
  if (n.contains('nursery') || n.contains('seed')) return Icons.spa_rounded;
  if (n.contains('plant') || n.contains('spacing') || n.contains('transplant')) return Icons.grass_rounded;
  if (n.contains('fertil') || n.contains('nutri') || n.contains('manure')) return Icons.science_rounded;
  if (n.contains('water') || n.contains('irrig')) return Icons.water_drop_rounded;
  if (n.contains('pest') || n.contains('disease')) return Icons.bug_report_rounded;
  if (n.contains('weed')) return Icons.content_cut_rounded;
  if (n.contains('harvest') || n.contains('storage')) return Icons.inventory_2_rounded;
  return Icons.eco_rounded;
}

class _Overview extends StatelessWidget {
  final CropGuide guide;
  final ValueChanged<int> onStage;
  final VoidCallback onVarieties;
  const _Overview({required this.guide, required this.onStage, required this.onVarieties});

  @override
  Widget build(BuildContext context) {
    final g = guide;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AspectRatio(aspectRatio: 16 / 7, child: GuideImage(path: g.image, emoji: g.emoji, emojiSize: 64)),
      ),
      const SizedBox(height: 14),
      _Section(
        icon: Icons.star_rounded,
        title: 'Key points',
        onCopy: () => _copy(context, _itemsText('${g.name} — key points', g.general), 'Key points copied'),
        child: _TipList(items: g.general),
      ),
      if (g.stages.isNotEmpty)
        _Section(
          icon: Icons.timeline_rounded,
          title: 'Season at a glance',
          subtitle: 'Tap a stage for its steps',
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < g.stages.length; i++)
              ActionChip(
                avatar: CircleAvatar(
                  backgroundColor: _kGreen,
                  child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                ),
                label: Text(g.stages[i].name),
                onPressed: () => onStage(i),
                backgroundColor: const Color(0xFFF1F8E9),
                side: const BorderSide(color: _kBorder),
              ),
          ]),
        ),
      if (g.varieties.isNotEmpty)
        Material(
          color: const Color(0xFFF9FBE7),
          borderRadius: BorderRadius.circular(16),
          child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            leading: const Icon(Icons.grass_rounded, color: _kLime),
            title: Text('${g.varieties.length} recommended varieties',
                style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(g.varieties.map((v) => v.name.split('(').first.trim()).take(3).join(' · '),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onVarieties,
          ),
        ),
    ]);
  }
}

class _Stages extends StatelessWidget {
  final CropGuide guide;
  final int open;
  final ValueChanged<int> onToggle;
  const _Stages({required this.guide, required this.open, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final stages = guide.stages;
    if (stages.isEmpty) {
      return const _Message(icon: Icons.timeline_rounded, title: 'No stages yet', text: '');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 32),
      itemCount: stages.length,
      itemBuilder: (context, i) {
        final s = stages[i];
        final isOpen = open == i;
        final last = i == stages.length - 1;
        return Stack(children: [
          // Timeline rail.
          if (!last)
            Positioned(
              left: 21,
              top: 34,
              bottom: 0,
              child: Container(width: 2, color: const Color(0xFFC5E1A5)),
            ),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 44,
              child: Column(children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isOpen ? _kGreen : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: _kGreen, width: 2),
                  ),
                  child: Icon(stageIcon(s.name), size: 18, color: isOpen ? Colors.white : _kGreen),
                ),
              ]),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    InkWell(
                      onTap: () => onToggle(i),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                        child: Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Step ${i + 1}', style: const TextStyle(color: _kMuted, fontSize: 11.5)),
                              Text(s.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _kInk)),
                            ]),
                          ),
                          Text('${s.tips.length} tips', style: const TextStyle(color: _kMuted, fontSize: 11.5)),
                          Icon(isOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: _kMuted),
                        ]),
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      alignment: Alignment.topCenter,
                      child: !isOpen
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                                if (s.image != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: AspectRatio(
                                      aspectRatio: 16 / 7,
                                      child: GuideImage(path: s.image, emoji: guide.emoji),
                                    ),
                                  ),
                                const SizedBox(height: 10),
                                _TipList(items: s.tips),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () => _copy(context, _itemsText('${guide.name} — ${s.name}', s.tips), 'Copied'),
                                    icon: const Icon(Icons.copy_rounded, size: 16),
                                    label: const Text('Copy'),
                                    style: TextButton.styleFrom(foregroundColor: _kGreen),
                                  ),
                                ),
                              ]),
                            ),
                    ),
                  ]),
                ),
              ),
            ),
          ]),
        ]);
      },
    );
  }
}

class _Varieties extends StatelessWidget {
  final CropGuide guide;
  const _Varieties({required this.guide});

  @override
  Widget build(BuildContext context) {
    final list = guide.varieties;
    if (list.isEmpty) {
      return const _Message(icon: Icons.grass_rounded, title: 'No varieties listed', text: '');
    }
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
      const Padding(
        padding: EdgeInsets.only(bottom: 12, left: 2),
        child: Text('Choose a variety that suits your area and market. Always buy certified seed.',
            style: TextStyle(color: _kMuted, height: 1.4)),
      ),
      for (final v in list)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: LayoutBuilder(builder: (context, c) {
              final wide = c.maxWidth >= 560;
              final image = GuideImage(path: v.image, emoji: guide.emoji, emojiSize: 36);
              final body = Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(v.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _kInk)),
                  if (v.bestFor.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: const Color(0xFFF1F8E9), borderRadius: BorderRadius.circular(10)),
                      child: Text.rich(TextSpan(children: [
                        const TextSpan(text: 'Best for: ', style: TextStyle(fontWeight: FontWeight.w800, color: _kGreenDark)),
                        TextSpan(text: v.bestFor, style: const TextStyle(color: _kGreenDark)),
                      ]), style: const TextStyle(fontSize: 12.5)),
                    ),
                  ],
                  const SizedBox(height: 10),
                  _TipList(items: v.tips),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _copy(
                          context,
                          _itemsText('${guide.name} — ${v.name}${v.bestFor.isEmpty ? '' : ' (best for: ${v.bestFor})'}', v.tips),
                          'Copied'),
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy'),
                      style: TextButton.styleFrom(foregroundColor: _kGreen),
                    ),
                  ),
                ]),
              );
              return wide
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(width: 190, height: 150, child: image),
                        ),
                      ),
                      Expanded(child: body),
                    ])
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      AspectRatio(aspectRatio: 16 / 6, child: image),
                      body,
                    ]);
            }),
          ),
        ),
    ]);
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onCopy;
  final Widget child;
  const _Section({required this.icon, required this.title, required this.child, this.subtitle, this.onCopy});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: _kGreen, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                if (subtitle != null) Text(subtitle!, style: const TextStyle(color: _kMuted, fontSize: 11.5)),
              ]),
            ),
            if (onCopy != null)
              IconButton(tooltip: 'Copy', icon: const Icon(Icons.copy_rounded, size: 18, color: _kMuted), onPressed: onCopy)
            else
              const SizedBox(height: 40),
          ]),
          const SizedBox(height: 6),
          Padding(padding: const EdgeInsets.only(right: 8), child: child),
        ]),
      );
}

class _TipList extends StatelessWidget {
  final List<TipItem> items;
  const _TipList({required this.items});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final t in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.check_circle_rounded, size: 16, color: _kGreen),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.text, style: const TextStyle(color: _kInk, height: 1.35, fontSize: 14)),
                  for (final s in t.subs)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('–  ', style: TextStyle(color: _kMuted)),
                        Expanded(child: Text(s, style: const TextStyle(color: _kMuted, height: 1.35, fontSize: 13.5))),
                      ]),
                    ),
                ]),
              ),
            ]),
          ),
      ]);
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const _Message({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: Color(0xFFE8F5E9), shape: BoxShape.circle),
            child: Icon(icon, size: 36, color: _kGreen),
          ),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: _kMuted, height: 1.4)),
          ],
        ]),
      );
}
