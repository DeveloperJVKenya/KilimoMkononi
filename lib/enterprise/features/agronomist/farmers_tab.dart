// lib/enterprise/features/agronomist/farmers_tab.dart
//
// Agronomist panel → Farmers: every farmer who shares their records, with
// their crops, this period's reports, low nutrients and last activity.
// Search by name / place, filter by county and crop (shared with Insights),
// sort by attention or recent activity. Tap → the farmer's page.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kilimomkononi/enterprise/features/agronomist/agronomist_providers.dart';
import 'package:kilimomkononi/enterprise/features/agronomist/agronomist_widgets.dart';
import 'package:kilimomkononi/enterprise/features/agronomist/insights_engine.dart';
import 'package:kilimomkononi/enterprise/features/agronomist/insights_tab.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_widgets.dart';
import 'package:kilimomkononi/utils/friendly_error.dart';

enum _Sort { attention, recent, name }

class FarmersTab extends ConsumerStatefulWidget {
  final bool testMode;
  const FarmersTab({super.key, required this.testMode});

  @override
  ConsumerState<FarmersTab> createState() => _FarmersTabState();
}

class _FarmersTabState extends ConsumerState<FarmersTab> {
  final _search = TextEditingController();
  _Sort _sort = _Sort.attention;
  bool _attentionOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(insightsFilterProvider);
    final async = ref.watch(insightsDataProvider(filter.days));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AdvisoryColors.midGreen)),
      error: (e, _) => AgroError(friendlyError(e, 'Couldn\'t load farmers'),
          onRetry: () => ref.invalidate(insightsDataProvider(filter.days))),
      data: (data) {
        final insights = computeInsights(data, county: filter.county, crop: filter.crop);
        final q = _search.text.trim().toLowerCase();
        var list = summarizeFarmers(data, county: filter.county, crop: filter.crop)
            .where((s) =>
                q.isEmpty ||
                s.farmer.name.toLowerCase().contains(q) ||
                s.farmer.place.toLowerCase().contains(q) ||
                s.crops.any((c) => c.toLowerCase().contains(q)))
            .where((s) => !_attentionOnly || s.attentionScore > 0)
            .toList();
        list.sort(switch (_sort) {
          _Sort.attention => (a, b) {
              final x = b.attentionScore.compareTo(a.attentionScore);
              return x != 0 ? x : (b.lastAt ?? DateTime(0)).compareTo(a.lastAt ?? DateTime(0));
            },
          _Sort.recent => (a, b) => (b.lastAt ?? DateTime(0)).compareTo(a.lastAt ?? DateTime(0)),
          _Sort.name => (a, b) => a.farmer.name.toLowerCase().compareTo(b.farmer.name.toLowerCase()),
        });
        return RefreshIndicator(
          color: AdvisoryColors.midGreen,
          onRefresh: () => ref.refresh(insightsDataProvider(filter.days).future),
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: list.length + 2,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  InsightsFilterBar(counties: insights.counties, crops: insights.crops),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search name, place or crop',
                        prefixIcon: const Icon(Icons.search_rounded),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () => setState(_search.clear),
                              ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      FilterChip(
                        label: const Text('Needs attention'),
                        selected: _attentionOnly,
                        onSelected: (v) => setState(() => _attentionOnly = v),
                      ),
                      DropdownButton<_Sort>(
                        value: _sort,
                        underline: const SizedBox.shrink(),
                        style: const TextStyle(fontSize: 13, color: kAgroInk),
                        items: const [
                          DropdownMenuItem(value: _Sort.attention, child: Text('Sort: needs attention')),
                          DropdownMenuItem(value: _Sort.recent, child: Text('Sort: latest activity')),
                          DropdownMenuItem(value: _Sort.name, child: Text('Sort: name')),
                        ],
                        onChanged: (v) => setState(() => _sort = v ?? _Sort.attention),
                      ),
                      Text('${list.length} farmer${list.length == 1 ? '' : 's'}',
                          style: const TextStyle(fontSize: 12, color: kAgroMuted)),
                    ]),
                  ),
                ]);
              }
              if (i == list.length + 1) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    list.isEmpty
                        ? 'No farmers match. Clear the search or filters.'
                        : data.optedOut > 0
                            ? '${data.optedOut} farmer${data.optedOut == 1 ? '' : 's'} chose not to share their records and aren\'t listed.'
                            : '',
                    style: const TextStyle(fontSize: 11.5, color: kAgroMuted),
                  ),
                );
              }
              return _FarmerTile(list[i - 1], days: filter.days, testMode: widget.testMode);
            },
          ),
        );
      },
    );
  }
}

class _FarmerTile extends StatelessWidget {
  final FarmerSummary s;
  final int days;
  final bool testMode;
  const _FarmerTile(this.s, {required this.days, required this.testMode});

  @override
  Widget build(BuildContext context) {
    final f = s.farmer;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => openFarmer(context, f, testMode: testMode),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AdvisoryColors.border),
            ),
            child: Row(children: [
              CircleAvatar(
                backgroundColor: s.attentionScore > 0 ? const Color(0xFFFFF1EC) : AdvisoryColors.verifiedBg,
                child: Text(f.name.isEmpty ? '?' : f.name[0].toUpperCase(),
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: s.attentionScore > 0 ? kLowColor : AdvisoryColors.verified)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(f.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kAgroInk)),
                  Text(
                    [
                      f.place.isEmpty ? 'Location not set' : f.place,
                      if (s.crops.isNotEmpty) s.crops.take(3).join(', ') + (s.crops.length > 3 ? ' +${s.crops.length - 3}' : ''),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: kAgroMuted),
                  ),
                  const SizedBox(height: 4),
                  Wrap(spacing: 5, runSpacing: 4, children: [
                    if (s.unidentified > 0)
                      FlagTag('${s.unidentified} unidentified', kUnknownColor, icon: Icons.help_outline_rounded),
                    if (s.pests > 0) FlagTag('${s.pests} pest', kPestColor, icon: Icons.bug_report_outlined),
                    if (s.diseases > 0) FlagTag('${s.diseases} disease', kDiseaseColor, icon: Icons.coronavirus_outlined),
                    if (s.lowNutrients.isNotEmpty) FlagTag('Low ${s.lowNutrients.join(', ')}', kLowColor),
                    Text('Last: ${agoOrDate(s.lastAt)}', style: const TextStyle(fontSize: 11, color: kAgroMuted)),
                  ]),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.black38),
            ]),
          ),
        ),
      ),
    );
  }
}
