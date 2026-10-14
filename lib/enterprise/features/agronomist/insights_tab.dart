// lib/enterprise/features/agronomist/insights_tab.dart
//
// Agronomist panel → Insights: what every farmer's records say for a
// period (7 / 30 / 90 days), county and crop — headline counts against the
// period before, emerging and unidentified problems, top pests / diseases
// with their trend, where reports come from, soil nutrient status by crop,
// and the farmers who most need attention. Everything opens the farmers
// behind it; "Advise them" writes custom advice to all of them at once.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kilimomkononi/enterprise/features/agronomist/agronomist_data_service.dart';
import 'package:kilimomkononi/enterprise/features/agronomist/agronomist_providers.dart';
import 'package:kilimomkononi/enterprise/features/agronomist/agronomist_widgets.dart';
import 'package:kilimomkononi/enterprise/features/agronomist/farmer_advice.dart';
import 'package:kilimomkononi/enterprise/features/agronomist/farmer_advice_editor_screen.dart';
import 'package:kilimomkononi/enterprise/features/agronomist/farmer_detail_screen.dart';
import 'package:kilimomkononi/enterprise/features/agronomist/farmer_records.dart';
import 'package:kilimomkononi/enterprise/features/agronomist/insights_engine.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_actions.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_widgets.dart';
import 'package:kilimomkononi/enterprise/features/weather/structured_advice.dart';
import 'package:kilimomkononi/utils/friendly_error.dart';

class InsightsTab extends ConsumerWidget {
  final bool testMode;
  const InsightsTab({super.key, required this.testMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(insightsFilterProvider);
    final async = ref.watch(insightsDataProvider(filter.days));
    return RefreshIndicator(
      color: AdvisoryColors.midGreen,
      onRefresh: () => ref.refresh(insightsDataProvider(filter.days).future),
      child: async.when(
        loading: () => ListView(children: const [
          InsightsFilterBar(),
          SizedBox(height: 80),
          Center(child: CircularProgressIndicator(color: AdvisoryColors.midGreen)),
          SizedBox(height: 12),
          Center(child: Text('Reading farmers\' records…', style: TextStyle(color: kAgroMuted))),
        ]),
        error: (e, _) => ListView(children: [
          const InsightsFilterBar(),
          AgroError(friendlyError(e, 'Couldn\'t load farmers\' records'),
              onRetry: () => ref.invalidate(insightsDataProvider(filter.days))),
        ]),
        data: (data) => _InsightsBody(
          data: data,
          insights: computeInsights(data, county: filter.county, crop: filter.crop),
          testMode: testMode,
        ),
      ),
    );
  }
}

/// Period + county + crop, shared by Insights and Farmers.
class InsightsFilterBar extends ConsumerWidget {
  final List<String> counties;
  final List<String> crops;
  final bool showPeriod;
  const InsightsFilterBar({super.key, this.counties = const [], this.crops = const [], this.showPeriod = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(insightsFilterProvider);
    final set = ref.read(insightsFilterProvider.notifier).set;
    Widget pick(String label, String? value, List<String> options, ValueChanged<String?> onChanged) =>
        PopupMenuButton<String>(
          tooltip: label,
          onSelected: (v) => onChanged(v == '\u0000' ? null : v),
          itemBuilder: (_) => [
            PopupMenuItem(value: '\u0000', child: Text('All ${label.toLowerCase()}s')),
            for (final o in options) PopupMenuItem(value: o, child: Text(o)),
          ],
          child: Chip(
            avatar: Icon(label == 'County' ? Icons.place_outlined : Icons.grass_rounded, size: 16),
            label: Text(value ?? 'All ${label.toLowerCase()}s', style: const TextStyle(fontSize: 12.5)),
            backgroundColor: value == null ? Colors.white : AdvisoryColors.verifiedBg,
            side: const BorderSide(color: AdvisoryColors.border),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        if (showPeriod)
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 7, label: Text('7 days')),
              ButtonSegment(value: 30, label: Text('30 days')),
              ButtonSegment(value: 90, label: Text('90 days')),
            ],
            selected: {f.days},
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            onSelectionChanged: (s) => set(f.copyWith(days: s.first)),
          ),
        if (counties.isNotEmpty || f.county != null)
          pick('County', f.county, counties,
              (v) => set(v == null ? f.copyWith(clearCounty: true) : f.copyWith(county: v))),
        if (crops.isNotEmpty || f.crop != null)
          pick('Crop', f.crop, crops, (v) => set(v == null ? f.copyWith(clearCrop: true) : f.copyWith(crop: v))),
      ]),
    );
  }
}

class _InsightsBody extends StatelessWidget {
  final InsightsData data;
  final Insights insights;
  final bool testMode;
  const _InsightsBody({required this.data, required this.insights, required this.testMode});

  String get _period => 'last ${insights.days} days';

  @override
  Widget build(BuildContext context) {
    final i = insights;
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        InsightsFilterBar(counties: i.counties, crops: i.crops),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            StatGrid([
              StatTile(
                label: 'Farmers active',
                value: i.activeFarmers.current,
                previous: i.activeFarmers.previous,
                upIsBad: false,
                icon: Icons.groups_rounded,
                color: AdvisoryColors.midGreen,
                footnote: '${data.farmers.length} sharing their records',
              ),
              StatTile(
                label: 'Pest reports',
                value: i.pestReports.current,
                previous: i.pestReports.previous,
                icon: Icons.bug_report_outlined,
                color: kPestColor,
              ),
              StatTile(
                label: 'Disease reports',
                value: i.diseaseReports.current,
                previous: i.diseaseReports.previous,
                icon: Icons.coronavirus_outlined,
                color: kDiseaseColor,
              ),
              StatTile(
                label: 'Unidentified problems',
                value: i.unidentified.current,
                previous: i.unidentified.previous,
                icon: Icons.help_outline_rounded,
                color: kUnknownColor,
              ),
              StatTile(
                label: 'Plots low in a nutrient',
                value: i.lowNutrientPlots,
                icon: Icons.science_outlined,
                color: kSoilColor,
                footnote: 'of ${i.plotsTested} with a soil test',
              ),
              StatTile(
                label: 'Emerging problems',
                value: i.emerging.length + i.unknownClusters.length,
                icon: Icons.trending_up_rounded,
                color: kLowColor,
                footnote: 'new, rising or spreading',
              ),
            ]),
            const SizedBox(height: 12),
            if (i.isEmpty)
              const AgroCard(
                title: 'No records yet',
                icon: Icons.inbox_outlined,
                child: Text(
                  'No pest, disease or soil records match this period and filter. Try a longer period or clear the filters.',
                  style: TextStyle(fontSize: 12.5, color: kAgroMuted),
                ),
              ),
            _EmergingCard(i, data, testMode: testMode, period: _period),
            _TopCard(
              title: 'Pests',
              icon: Icons.bug_report_outlined,
              color: kPestColor,
              trends: i.pests,
              data: data,
              testMode: testMode,
              days: i.days,
            ),
            _TopCard(
              title: 'Diseases',
              icon: Icons.coronavirus_outlined,
              color: kDiseaseColor,
              trends: i.diseases,
              data: data,
              testMode: testMode,
              days: i.days,
            ),
            _UnidentifiedCard(i, data, testMode: testMode),
            _CountyCard(i),
            _SoilCard(i, data, testMode: testMode),
            _AttentionCard(i, testMode: testMode),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Text(
                [
                  'Updated ${agoOrDate(data.generatedAt)}.',
                  if (data.optedOut > 0)
                    '${data.optedOut} farmer${data.optedOut == 1 ? '' : 's'} chose not to share — their reports are counted here without names.',
                  if (data.truncated) 'Very many records — the oldest of this period may be missing.',
                ].join(' '),
                style: const TextStyle(fontSize: 11, color: kAgroMuted),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

// ── Helpers shared by the cards ─────────────────────────────────────────────

List<FarmerRow> _farmersOf(InsightsData data, Iterable<String> uids) {
  final set = uids.toSet();
  return data.farmers.where((f) => set.contains(f.uid)).toList()..sort((a, b) => a.name.compareTo(b.name));
}

List<String> _cropsOf(InsightsData data, String uid) => {
      for (final p in data.plots)
        if (p.farmerUid == uid) ...p.cropNames,
    }.toList();

void openFarmer(BuildContext context, FarmerRow f, {required bool testMode}) => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FarmerDetailScreen(farmerUid: f.uid, initialName: f.name, testMode: testMode)),
    );

Future<void> _adviseFarmers(
  BuildContext context, {
  required InsightsData data,
  required List<FarmerRow> farmers,
  required bool testMode,
  String? crop,
  AdviceBasis? basis,
  String? checkName,
  String? checkType,
}) async {
  if (farmers.isEmpty) return;
  final checks = checkName == null || checkName.isEmpty
      ? AdviceActions.empty
      : checkType == 'disease'
          ? AdviceActions(diseases: [CropCheck(name: checkName, signs: '', ifFound: '')])
          : AdviceActions(pests: [CropCheck(name: checkName, signs: '', ifFound: '')]);
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => FarmerAdviceEditorScreen(
        targets: [for (final f in farmers) AdviceTarget(uid: f.uid, name: f.name, crops: _cropsOf(data, f.uid))],
        testMode: testMode,
        initialCrops: crop == null || crop.isEmpty ? null : [crop],
        basedOn: basis,
        initialActions: checks,
        initialAdvice: const StructuredAdvice(main: ''),
      ),
    ),
  );
}

/// Bottom sheet listing farmers, with "Advise them all".
void _showFarmers(
  BuildContext context, {
  required String title,
  required InsightsData data,
  required List<FarmerRow> farmers,
  required bool testMode,
  int anonymous = 0,
  String? crop,
  AdviceBasis? basis,
  String? checkName,
  String? checkType,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            '${farmers.length} farmer${farmers.length == 1 ? '' : 's'}'
            '${anonymous > 0 ? ' · $anonymous more who don\'t share their records' : ''}',
            style: const TextStyle(fontSize: 12, color: kAgroMuted),
          ),
          const SizedBox(height: 10),
          if (farmers.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AdvisoryColors.verified),
                onPressed: () {
                  Navigator.pop(ctx);
                  _adviseFarmers(context,
                      data: data,
                      farmers: farmers,
                      testMode: testMode,
                      crop: crop,
                      basis: basis,
                      checkName: checkName,
                      checkType: checkType);
                },
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(farmers.length == 1 ? 'Advise this farmer' : 'Advise all ${farmers.length}'),
              ),
            ),
          const SizedBox(height: 6),
          for (final f in farmers)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: AdvisoryColors.verifiedBg,
                child: Text(f.name.isEmpty ? '?' : f.name[0].toUpperCase(),
                    style: const TextStyle(color: AdvisoryColors.verified, fontWeight: FontWeight.w800)),
              ),
              title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(f.place.isEmpty ? 'Location not set' : f.place),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(ctx);
                openFarmer(context, f, testMode: testMode);
              },
            ),
        ],
      ),
    ),
  );
}

// ── Emerging ────────────────────────────────────────────────────────────────

class _EmergingCard extends StatelessWidget {
  final Insights i;
  final InsightsData data;
  final bool testMode;
  final String period;
  const _EmergingCard(this.i, this.data, {required this.testMode, required this.period});

  @override
  Widget build(BuildContext context) {
    return AgroCard(
      title: 'Emerging & unusual',
      subtitle: 'New, rising or spreading problems, and unidentified problems clustering on one crop in one county',
      icon: Icons.radar_rounded,
      color: kLowColor,
      child: i.emerging.isEmpty && i.unknownClusters.isEmpty
          ? const AgroEmpty(Icons.check_circle_outline_rounded,
              'Nothing unusual — no problem is new, rising or spreading compared with the period before.')
          : Column(children: [
              for (final c in i.unknownClusters.take(5))
                _EmergingTile(
                  icon: Icons.help_outline_rounded,
                  color: kUnknownColor,
                  title: 'Unidentified ${c.type} problem${c.crop.isEmpty ? '' : ' on ${c.crop}'}',
                  tags: const [FlagTag('Unknown', kUnknownColor, icon: Icons.help_outline_rounded)],
                  detail: '${c.rows.length} reports from ${c.farmers} farmer${c.farmers == 1 ? '' : 's'}'
                      '${c.county.isEmpty ? '' : ' in ${c.county}'} · $period',
                  onTap: () => _showFarmers(
                    context,
                    title: 'Unidentified ${c.type} problem${c.crop.isEmpty ? '' : ' on ${c.crop}'}',
                    data: data,
                    farmers: _farmersOf(data, c.farmerUids),
                    anonymous: c.rows.where((r) => r.farmerUid == null).length,
                    testMode: testMode,
                    crop: c.crop,
                    basis: AdviceBasis(
                        kind: c.type,
                        label: 'Unidentified ${c.type} problem on ${c.crop.isEmpty ? 'crops' : c.crop}'
                            '${c.county.isEmpty ? '' : ' in ${c.county}'}'),
                  ),
                ),
              for (final t in i.emerging.take(8))
                _EmergingTile(
                  icon: issueIcon(t.type),
                  color: issueColor(t.type),
                  title: t.name,
                  tags: [
                    for (final tag in t.tags)
                      FlagTag(tag.label, kLowColor,
                          icon: switch (tag) {
                            TrendTag.newIssue => Icons.fiber_new_rounded,
                            TrendTag.rising => Icons.trending_up_rounded,
                            TrendTag.spreading => Icons.share_location_rounded,
                          }),
                  ],
                  detail: '${t.current} report${t.current == 1 ? '' : 's'} (${t.previous} before) · '
                      '${t.farmers} farmer${t.farmers == 1 ? '' : 's'}'
                      '${t.counties.isEmpty ? '' : ' · ${t.counties.take(3).join(', ')}${t.counties.length > 3 ? ' +${t.counties.length - 3}' : ''}'}'
                      '${t.topCrops.isEmpty ? '' : ' · on ${t.topCrops.take(2).join(', ')}'}',
                  bars: t.buckets,
                  days: i.days,
                  onTap: () => _showFarmers(
                    context,
                    title: t.name,
                    data: data,
                    farmers: _farmersOf(data, t.farmerUids),
                    testMode: testMode,
                    crop: t.topCrops.isEmpty ? null : t.topCrops.first,
                    checkName: t.name,
                    checkType: t.type,
                    basis: AdviceBasis(kind: t.type, label: '${t.name} — ${t.tags.map((x) => x.label.toLowerCase()).join(', ')} in the area'),
                  ),
                ),
            ]),
    );
  }
}

class _EmergingTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final List<Widget> tags;
  final String detail;
  final List<int>? bars;
  final int days;
  final VoidCallback onTap;

  const _EmergingTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.tags,
    required this.detail,
    required this.onTap,
    this.bars,
    this.days = 30,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: kAgroInk)),
                  ...tags,
                ]),
                const SizedBox(height: 3),
                Text(detail, style: const TextStyle(fontSize: 11.5, color: kAgroMuted)),
              ]),
            ),
            if (bars != null) ...[
              const SizedBox(width: 10),
              SizedBox(width: 72, child: TrendBars(bars!, days: days, height: 26)),
            ],
            const Icon(Icons.chevron_right_rounded, color: Colors.black38),
          ]),
        ),
      );
}

// ── Top pests / diseases ────────────────────────────────────────────────────

class _TopCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<IssueTrend> trends;
  final InsightsData data;
  final bool testMode;
  final int days;

  const _TopCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.trends,
    required this.data,
    required this.testMode,
    required this.days,
  });

  @override
  State<_TopCard> createState() => _TopCardState();
}

class _TopCardState extends State<_TopCard> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.trends;
    final shown = _all ? t : t.take(6).toList();
    final max = t.isEmpty ? 0 : t.first.current;
    return AgroCard(
      title: widget.title,
      subtitle: 'Reports in the period · change against the period before',
      icon: widget.icon,
      color: widget.color,
      child: t.isEmpty
          ? AgroEmpty(widget.icon, 'No ${widget.title.toLowerCase()} reported in this period.')
          : Column(children: [
              for (final x in shown)
                MeterRow(
                  label: x.name,
                  value: x.current,
                  max: max,
                  color: widget.color,
                  trailing: ChangeBadge(current: x.current, previous: x.previous),
                  sublabel: '${x.farmers} farmer${x.farmers == 1 ? '' : 's'}'
                      '${x.topCrops.isEmpty ? '' : ' · ${x.topCrops.take(3).join(', ')}'}'
                      '${x.counties.isEmpty ? '' : ' · ${x.counties.take(2).join(', ')}${x.counties.length > 2 ? ' +${x.counties.length - 2}' : ''}'}',
                  onTap: () => _showFarmers(
                    context,
                    title: x.name,
                    data: widget.data,
                    farmers: _farmersOf(widget.data, x.farmerUids),
                    testMode: widget.testMode,
                    crop: x.topCrops.isEmpty ? null : x.topCrops.first,
                    checkName: x.name,
                    checkType: x.type,
                    basis: AdviceBasis(kind: x.type, label: '${x.name} reported on your farm'),
                  ),
                ),
              if (t.length > 6)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() => _all = !_all),
                    child: Text(_all ? 'Show fewer' : 'Show all ${t.length}'),
                  ),
                ),
            ]),
    );
  }
}

// ── Unidentified ────────────────────────────────────────────────────────────

class _UnidentifiedCard extends StatelessWidget {
  final Insights i;
  final InsightsData data;
  final bool testMode;
  const _UnidentifiedCard(this.i, this.data, {required this.testMode});

  @override
  Widget build(BuildContext context) {
    final rows = i.unidentifiedRows;
    final byUid = {for (final f in data.farmers) f.uid: f};
    return AgroCard(
      title: 'Unidentified problems',
      subtitle: 'Farmers couldn\'t name it, or the photo ID had low confidence — check these first',
      icon: Icons.help_outline_rounded,
      color: kUnknownColor,
      child: rows.isEmpty
          ? const AgroEmpty(Icons.check_circle_outline_rounded, 'None in this period.')
          : Column(children: [
              for (final r in rows.take(10))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(issueIcon(r.type), color: issueColor(r.type)),
                  title: Text(
                    '${r.label}${r.crop.isEmpty ? '' : ' · ${r.crop}'}${r.stage.isEmpty ? '' : ' (${r.stage})'}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  subtitle: Text(
                    [
                      r.farmerUid == null ? 'Farmer not sharing' : (byUid[r.farmerUid]?.name ?? 'Farmer'),
                      if (r.county.isNotEmpty) r.county,
                      shortDate(r.at),
                      if (r.source == 'photo') 'photo ID${r.confidence == null ? '' : ' · ${r.confidence}'}',
                    ].join(' · '),
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  trailing: r.farmerUid == null || byUid[r.farmerUid] == null
                      ? null
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: r.farmerUid == null || byUid[r.farmerUid] == null
                      ? null
                      : () => openFarmer(context, byUid[r.farmerUid]!, testMode: testMode),
                ),
              if (rows.length > 10)
                Text('+${rows.length - 10} more', style: const TextStyle(fontSize: 12, color: kAgroMuted)),
            ]),
    );
  }
}

// ── Where ───────────────────────────────────────────────────────────────────

class _CountyCard extends StatelessWidget {
  final Insights i;
  const _CountyCard(this.i);

  @override
  Widget build(BuildContext context) {
    final list = i.byCounty.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final max = list.isEmpty ? 0 : list.first.value;
    return AgroCard(
      title: 'Where reports come from',
      subtitle: 'Pest and disease reports by county — tap a county to filter',
      icon: Icons.map_outlined,
      child: list.isEmpty
          ? const AgroEmpty(Icons.map_outlined, 'No reports in this period.')
          : Consumer(
              builder: (context, ref, _) => Column(children: [
                for (final e in list.take(8))
                  MeterRow(
                    label: e.key,
                    value: e.value,
                    max: max,
                    onTap: e.key == 'Not set'
                        ? null
                        : () {
                            final f = ref.read(insightsFilterProvider);
                            ref.read(insightsFilterProvider.notifier).set(f.copyWith(county: e.key));
                          },
                  ),
              ]),
            ),
    );
  }
}

// ── Soil ────────────────────────────────────────────────────────────────────

class _SoilCard extends StatelessWidget {
  final Insights i;
  final InsightsData data;
  final bool testMode;
  const _SoilCard(this.i, this.data, {required this.testMode});

  @override
  Widget build(BuildContext context) {
    final rows = i.nutrients.where((n) => n.total > 0).take(12).toList();
    return AgroCard(
      title: 'Soil nutrients',
      subtitle: 'Each plot\'s latest soil test against its crop\'s target · Low < 90% · High > 110%',
      icon: Icons.science_outlined,
      color: kSoilColor,
      child: rows.isEmpty
          ? const AgroEmpty(Icons.science_outlined, 'No soil tests recorded for these plots.')
          : Column(children: [
              for (final n in rows)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: n.lowFarmerUids.isEmpty
                      ? null
                      : () => _showFarmers(
                            context,
                            title: '${n.crop} — low ${n.nutrient}',
                            data: data,
                            farmers: _farmersOf(data, n.lowFarmerUids),
                            testMode: testMode,
                            crop: n.crop,
                            basis: AdviceBasis(kind: 'soil', label: 'Soil test: ${n.nutrient} low for ${n.crop}'),
                          ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      SizedBox(
                        width: 120,
                        child: Text('${n.crop} · ${n.nutrient}',
                            maxLines: 2,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: kAgroInk)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: BandBar(low: n.low, moderate: n.moderate, high: n.high)),
                      if (n.lowFarmerUids.isNotEmpty) const Icon(Icons.chevron_right_rounded, color: Colors.black38),
                    ]),
                  ),
                ),
            ]),
    );
  }
}

// ── Attention ───────────────────────────────────────────────────────────────

class _AttentionCard extends StatelessWidget {
  final Insights i;
  final bool testMode;
  const _AttentionCard(this.i, {required this.testMode});

  @override
  Widget build(BuildContext context) => AgroCard(
        title: 'Farmers needing attention',
        subtitle: 'Unidentified and repeated problems, diseases, pests and low nutrients',
        icon: Icons.priority_high_rounded,
        color: kLowColor,
        child: i.attention.isEmpty
            ? const AgroEmpty(Icons.check_circle_outline_rounded, 'No farmer stands out in this period.')
            : Column(children: [
                for (final a in i.attention.take(10))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFFFF1EC),
                      child: Text(a.farmer.name.isEmpty ? '?' : a.farmer.name[0].toUpperCase(),
                          style: const TextStyle(color: kLowColor, fontWeight: FontWeight.w800)),
                    ),
                    title: Text(a.farmer.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      [a.farmer.place, ...a.reasons].where((s) => s.isNotEmpty).join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => openFarmer(context, a.farmer, testMode: testMode),
                  ),
              ]),
      );
}
