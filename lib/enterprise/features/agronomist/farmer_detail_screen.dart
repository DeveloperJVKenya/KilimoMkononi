// lib/enterprise/features/agronomist/farmer_detail_screen.dart
//
// One farmer, as a Field Agronomist sees them (Agronomist panel → a farmer,
// or a farmer-activity notification):
//
//   Summary          who and where, headline numbers, and what stands out
//                    (farmer_findings.dart) — each with "Advise"
//   Soil & plots     each plot's crops and latest soil test against the
//                    crop's target, earlier tests and logged actions
//   Pests & diseases every report (photo, confidence, what they did)
//   Advice           custom advice sent to them and what they did with it
//
// "Send advice" writes custom advice for this farmer (with an AI draft from
// these records). Opening this page is logged on the server.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kilimomkononi/enterprise/features/agronomist/agronomist_data_service.dart';
import 'package:kilimomkononi/enterprise/features/agronomist/agronomist_providers.dart';
import 'package:kilimomkononi/enterprise/features/agronomist/agronomist_widgets.dart';
import 'package:kilimomkononi/enterprise/features/agronomist/farmer_advice.dart';
import 'package:kilimomkononi/enterprise/features/agronomist/farmer_advice_editor_screen.dart';
import 'package:kilimomkononi/enterprise/features/agronomist/farmer_findings.dart';
import 'package:kilimomkononi/enterprise/features/agronomist/farmer_records.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_actions.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_widgets.dart';
import 'package:kilimomkononi/services/nutrient_levels.dart';
import 'package:kilimomkononi/utils/friendly_error.dart';
import 'package:url_launcher/url_launcher.dart';

class FarmerDetailScreen extends ConsumerWidget {
  final String farmerUid;
  final String? initialName;
  final bool testMode;

  const FarmerDetailScreen({super.key, required this.farmerUid, this.initialName, this.testMode = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(farmerRecordProvider(farmerUid));
    final name = async.value?.name ?? initialName ?? 'Farmer';
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AdvisoryColors.pageBg,
        appBar: AppBar(
          backgroundColor: testMode ? const Color(0xFF4A148C) : AdvisoryColors.darkGreen,
          foregroundColor: Colors.white,
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            Text(
              async.value?.place.isNotEmpty == true ? async.value!.place : 'Farm records',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ]),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => ref.invalidate(farmerRecordProvider(farmerUid)),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Summary'),
              Tab(text: 'Soil & plots'),
              Tab(text: 'Pests & diseases'),
              Tab(text: 'Advice'),
            ],
          ),
        ),
        floatingActionButton: async.hasValue
            ? FloatingActionButton.extended(
                backgroundColor: AdvisoryColors.verified,
                foregroundColor: Colors.white,
                onPressed: () => _advise(context, async.value!),
                icon: const Icon(Icons.send_rounded),
                label: const Text('Send advice'),
              )
            : null,
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AdvisoryColors.midGreen)),
          error: (e, _) => AgroError(
            friendlyError(e, 'Couldn\'t load this farmer\'s records'),
            onRetry: () => ref.invalidate(farmerRecordProvider(farmerUid)),
          ),
          data: (r) => TabBarView(children: [
            _SummaryTab(r, testMode: testMode),
            _SoilTab(r, testMode: testMode),
            _IssuesTab(r, testMode: testMode),
            _AdviceTab(r, testMode: testMode),
          ]),
        ),
      ),
    );
  }

  Future<void> _advise(BuildContext context, FarmerRecord r) => adviseFarmer(context, r, testMode: testMode);
}

/// Opens the editor for custom advice to [r], pre-filled from a finding /
/// report when given.
Future<void> adviseFarmer(
  BuildContext context,
  FarmerRecord r, {
  required bool testMode,
  AdviceBasis? basis,
  String? crop,
  String? checkName,
  String? checkType,
}) =>
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FarmerAdviceEditorScreen(
          targets: [AdviceTarget(uid: r.uid, name: r.name, crops: r.crops)],
          testMode: testMode,
          initialCrops: crop != null ? [crop] : (r.crops.length <= 4 ? r.crops : null),
          basedOn: basis,
          initialActions: checkName == null
              ? AdviceActions.empty
              : checkType == 'disease'
                  ? AdviceActions(diseases: [CropCheck(name: checkName, signs: '', ifFound: '')])
                  : AdviceActions(pests: [CropCheck(name: checkName, signs: '', ifFound: '')]),
          farmerContext: AgronomistDataService.farmerContext(r),
        ),
      ),
    );

// ── Summary ─────────────────────────────────────────────────────────────────

class _SummaryTab extends StatelessWidget {
  final FarmerRecord r;
  final bool testMode;
  const _SummaryTab(this.r, {required this.testMode});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final recent = r.issues.where((i) => now.difference(i.at).inDays <= 90).toList();
    final findings = farmerFindings(r, now: now);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        AgroCard(
          title: r.name,
          subtitle: r.place.isEmpty ? 'Location not set' : r.place,
          icon: Icons.person_rounded,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (r.phone.isNotEmpty)
              _ContactRow(Icons.phone_rounded, r.phone, onTap: () => launchUrl(Uri(scheme: 'tel', path: r.phone))),
            if (r.email.isNotEmpty)
              _ContactRow(Icons.mail_outline_rounded, r.email,
                  onTap: () => launchUrl(Uri(scheme: 'mailto', path: r.email))),
            if (r.joinedAt != null) _ContactRow(Icons.event_rounded, 'Joined ${shortDate(r.joinedAt)}'),
            _ContactRow(
              Icons.sensors_rounded,
              r.stations.isEmpty
                  ? 'No weather station connected'
                  : 'Station${r.stations.length > 1 ? 's' : ''}: ${r.stations.map((s) => s.name).join(', ')}',
            ),
            if (r.crops.isNotEmpty) ...[
              const SizedBox(height: 8),
              CropChips(r.crops),
            ],
          ]),
        ),
        StatGrid([
          StatTile(
            label: 'Plots',
            value: r.latestPlots.length,
            icon: Icons.grid_view_rounded,
            color: AdvisoryColors.midGreen,
            footnote: '${r.fieldRecords.length} field record${r.fieldRecords.length == 1 ? '' : 's'}',
          ),
          StatTile(
            label: 'Pest reports · 90 days',
            value: recent.where((i) => i.isPest).length,
            icon: Icons.bug_report_outlined,
            color: kPestColor,
          ),
          StatTile(
            label: 'Disease reports · 90 days',
            value: recent.where((i) => i.isDisease).length,
            icon: Icons.coronavirus_outlined,
            color: kDiseaseColor,
          ),
          StatTile(
            label: 'Unidentified · 90 days',
            value: recent.where((i) => i.unidentified).length,
            icon: Icons.help_outline_rounded,
            color: kUnknownColor,
          ),
          StatTile(
            label: 'Advice sent',
            value: r.advice.where((a) => a.status == FarmerAdviceStatus.sent).length,
            icon: Icons.send_rounded,
            color: AdvisoryColors.verified,
          ),
          StatTile(
            label: 'Spent on the farm (KES)',
            value: r.costTotal.round(),
            icon: Icons.payments_outlined,
            color: kSoilColor,
          ),
        ]),
        const SizedBox(height: 12),
        AgroCard(
          title: 'What stands out',
          subtitle: 'From this farmer\'s records — tap Advise to answer one',
          icon: Icons.insights_rounded,
          color: kLowColor,
          child: findings.isEmpty
              ? const AgroEmpty(Icons.check_circle_outline_rounded, 'Nothing stands out — records look healthy.')
              : Column(children: [
                  for (final f in findings)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        FlagTag(
                          switch (f.level) {
                            FindingLevel.high => 'Act',
                            FindingLevel.medium => 'Check',
                            FindingLevel.info => 'Note',
                          },
                          switch (f.level) {
                            FindingLevel.high => kLowColor,
                            FindingLevel.medium => const Color(0xFFB26A00),
                            FindingLevel.info => kAgroMuted,
                          },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(f.text,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kAgroInk)),
                            if (f.detail != null)
                              Text(f.detail!, style: const TextStyle(fontSize: 11.5, color: kAgroMuted)),
                          ]),
                        ),
                        TextButton(
                          onPressed: () => adviseFarmer(context, r,
                              testMode: testMode,
                              basis: f.basis,
                              crop: f.crop,
                              checkName: f.checkName,
                              checkType: f.checkType),
                          child: const Text('Advise'),
                        ),
                      ]),
                    ),
                ]),
        ),
        if (r.costByCategory.isNotEmpty)
          AgroCard(
            title: 'Spending by category',
            icon: Icons.payments_outlined,
            color: kSoilColor,
            child: Builder(builder: (_) {
              final list = r.costByCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
              final max = list.first.value.round();
              return Column(children: [
                for (final e in list.take(6))
                  MeterRow(label: e.key, value: e.value.round(), max: max, color: kSoilColor),
              ]);
            }),
          ),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;
  const _ContactRow(this.icon, this.text, {this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: text));
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Icon(icon, size: 16, color: kAgroMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: TextStyle(
                    fontSize: 13,
                    color: onTap != null ? AdvisoryColors.verified : kAgroInk,
                    fontWeight: onTap != null ? FontWeight.w700 : FontWeight.w500,
                  )),
            ),
          ]),
        ),
      );
}

// ── Soil & plots ────────────────────────────────────────────────────────────

class _SoilTab extends StatelessWidget {
  final FarmerRecord r;
  final bool testMode;
  const _SoilTab(this.r, {required this.testMode});

  @override
  Widget build(BuildContext context) {
    if (r.fieldRecords.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: AgroEmpty(Icons.grid_view_rounded, 'No field records yet.'),
      );
    }
    final byPlot = <String, List<Map<String, dynamic>>>{};
    for (final f in r.fieldRecords) {
      (byPlot['${f['plotId'] ?? ''}'] ??= []).add(f);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        for (final e in byPlot.entries) _PlotCard(r, e.key, e.value, testMode: testMode),
      ],
    );
  }
}

class _PlotCard extends StatelessWidget {
  final FarmerRecord r;
  final String plot;
  final List<Map<String, dynamic>> records;
  final bool testMode;
  const _PlotCard(this.r, this.plot, this.records, {required this.testMode});

  DateTime? _t(dynamic v) => v is num ? DateTime.fromMillisecondsSinceEpoch(v.toInt()) : null;

  @override
  Widget build(BuildContext context) {
    final latest = records.first;
    final row = FarmerRecord.plotRowOf(latest);
    final opt = optimalFor([
      for (final c in row.crops) {'type': c.type, 'stage': c.stage},
    ]);
    final interventions = [
      for (final rec in records)
        for (final i in (rec['interventions'] as List? ?? const []).whereType<Map>()) i,
    ];
    return AgroCard(
      title: plot.isEmpty ? 'Plot' : plot,
      subtitle: [
        if (row.crops.isNotEmpty) row.crops.map((c) => c.stage.isEmpty ? c.type : '${c.type} · ${c.stage}').join(', '),
        if (row.area != null) '${row.area!.toStringAsFixed(1)} acres',
        'updated ${shortDate(row.at)}',
      ].join(' · '),
      icon: Icons.grid_view_rounded,
      color: kSoilColor,
      trailing: TextButton(
        onPressed: () => adviseFarmer(
          context,
          r,
          testMode: testMode,
          crop: row.cropNames.isEmpty ? null : row.cropNames.first,
          basis: AdviceBasis(kind: 'soil', label: 'Your plot ${plot.isEmpty ? '' : plot}'.trim()),
        ),
        child: const Text('Advise'),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (row.npk.isEmpty)
          const AgroEmpty(Icons.science_outlined, 'No soil test on the latest record.')
        else
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final k in const ['N', 'P', 'K'])
              if (row.npk[k] != null)
                Container(
                  width: 104,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AdvisoryColors.pageBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(k, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: kAgroMuted)),
                    Text(row.npk[k]!.toStringAsFixed(0),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kAgroInk)),
                    if ((opt[k] ?? 0) > 0)
                      Text('target ${opt[k]!.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 10.5, color: kAgroMuted)),
                    if (row.bands[k] != null) ...[
                      const SizedBox(height: 3),
                      FlagTag(
                        row.bands[k]!.label,
                        switch (row.bands[k]!) {
                          NutrientBand.low => kLowColor,
                          NutrientBand.moderate => kModerateColor,
                          NutrientBand.high => kHighColor,
                        },
                      ),
                    ],
                  ]),
                ),
          ]),
        if (records.length > 1) ...[
          const SizedBox(height: 12),
          const Text('Earlier records', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kAgroMuted)),
          for (final rec in records.skip(1).take(6))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${shortDate(_t(rec['timestamp']))} · '
                '${((rec['crops'] as List?) ?? const []).whereType<Map>().map((c) => c['type']).join(', ')}'
                '${_npkText(rec['npk'])}',
                style: const TextStyle(fontSize: 12, color: kAgroInk),
              ),
            ),
        ],
        if (interventions.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Actions logged', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kAgroMuted)),
          for (final i in interventions.take(8))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                [
                  if (_t(i['date']) != null) shortDate(_t(i['date'])),
                  '${i['type'] ?? i['interventionType'] ?? 'Action'}',
                  if ('${i['product'] ?? ''}'.isNotEmpty) '${i['product']}',
                  if ('${i['quantity'] ?? i['amount'] ?? ''}'.isNotEmpty) '${i['quantity'] ?? i['amount']} ${i['unit'] ?? ''}'.trim(),
                ].join(' · '),
                style: const TextStyle(fontSize: 12, color: kAgroInk),
              ),
            ),
        ],
      ]),
    );
  }

  String _npkText(dynamic npk) {
    if (npk is! Map) return '';
    final parts = [
      for (final k in const ['N', 'P', 'K'])
        if (npk[k] is num) '$k ${(npk[k] as num).toStringAsFixed(0)}',
    ];
    return parts.isEmpty ? '' : ' · ${parts.join(', ')}';
  }
}

// ── Pests & diseases ────────────────────────────────────────────────────────

class _IssuesTab extends StatelessWidget {
  final FarmerRecord r;
  final bool testMode;
  const _IssuesTab(this.r, {required this.testMode});

  @override
  Widget build(BuildContext context) {
    if (r.issues.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: AgroEmpty(Icons.bug_report_outlined, 'No pest or disease reports.'),
      );
    }
    final counts = <String, int>{};
    for (final i in r.issues.where((i) => !i.unidentified && i.name.isNotEmpty)) {
      counts[i.name] = (counts[i.name] ?? 0) + 1;
    }
    final top = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        if (top.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (final e in top.take(8))
                Chip(
                  label: Text(e.value > 1 ? '${e.key} ×${e.value}' : e.key, style: const TextStyle(fontSize: 12)),
                  backgroundColor: e.value > 1 ? const Color(0xFFFFF1EC) : Colors.white,
                  side: const BorderSide(color: AdvisoryColors.border),
                  visualDensity: VisualDensity.compact,
                ),
            ]),
          ),
        for (final i in r.issues) _IssueTile(r, i, testMode: testMode),
      ],
    );
  }
}

class _IssueTile extends StatelessWidget {
  final FarmerRecord r;
  final IssueRow i;
  final bool testMode;
  const _IssueTile(this.r, this.i, {required this.testMode});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: i.unidentified ? kUnknownColor.withValues(alpha: 0.4) : AdvisoryColors.border),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (i.photoUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => Dialog(child: InteractiveViewer(child: Image.network(i.photoUrl!))),
                ),
                child: Image.network(
                  i.photoUrl!,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 64,
                    height: 64,
                    color: AdvisoryColors.pageBg,
                    child: const Icon(Icons.image_not_supported_outlined, color: Colors.black38),
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: issueColor(i.type).withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(issueIcon(i.type), size: 18, color: issueColor(i.type)),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(i.label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: kAgroInk)),
                FlagTag(i.isDisease ? 'Disease' : 'Pest', issueColor(i.type)),
                if (i.unidentified) const FlagTag('Unidentified', kUnknownColor, icon: Icons.help_outline_rounded),
              ]),
              const SizedBox(height: 3),
              Text(
                [
                  shortDate(i.at),
                  if (i.crop.isNotEmpty) i.crop,
                  if (i.stage.isNotEmpty) i.stage,
                  if (i.source == 'photo') 'Photo ID${i.confidence == null ? '' : ' · ${i.confidence} confidence'}',
                ].join(' · '),
                style: const TextStyle(fontSize: 11.5, color: kAgroMuted),
              ),
              if (i.description != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Seen: ${i.description}', style: const TextStyle(fontSize: 12, color: kAgroInk)),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  i.intervention == null ? 'Nothing logged as done' : 'Did: ${i.intervention}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: i.intervention == null ? kLowColor : AdvisoryColors.verified,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => adviseFarmer(
                    context,
                    r,
                    testMode: testMode,
                    crop: i.crop.isEmpty ? null : i.crop,
                    checkName: i.unidentified ? null : i.name,
                    checkType: i.type,
                    basis: AdviceBasis(
                      kind: i.type,
                      id: i.id,
                      label: '${i.label}${i.crop.isEmpty ? '' : ' on your ${i.crop}'} (${shortDate(i.at)})',
                    ),
                  ),
                  icon: const Icon(Icons.reply_rounded, size: 16),
                  label: const Text('Advise on this'),
                ),
              ),
            ]),
          ),
        ]),
      );
}

// ── Advice sent ─────────────────────────────────────────────────────────────

class _AdviceTab extends StatelessWidget {
  final FarmerRecord r;
  final bool testMode;
  const _AdviceTab(this.r, {required this.testMode});

  @override
  Widget build(BuildContext context) => StreamBuilder<List<FarmerAdvice>>(
        stream: AgronomistDataService.adviceFor(r.uid, includeTest: testMode),
        builder: (context, snap) {
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text(friendlyError(snap.error, 'Couldn\'t load the advice'),
                  style: const TextStyle(color: AdvisoryColors.red)),
            );
          }
          final list = snap.data ?? r.advice;
          if (list.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: AgroEmpty(Icons.send_outlined, 'No custom advice for this farmer yet. Tap "Send advice".'),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [for (final a in list) FarmerAdviceTile(a, responses: r.responses[a.id], testMode: testMode)],
          );
        },
      );
}

/// One custom advice: status, what it says, when, and what the farmer did.
class FarmerAdviceTile extends StatelessWidget {
  final FarmerAdvice a;
  final Map<String, String>? responses;
  final bool testMode;
  final bool showFarmer;

  const FarmerAdviceTile(this.a, {super.key, this.responses, required this.testMode, this.showFarmer = false});

  @override
  Widget build(BuildContext context) {
    final res = responses ?? const <String, String>{};
    String names(bool Function(String) test) =>
        [for (final e in res.entries) if (test(e.value)) e.key.split(':').last.split('@').first].join(', ');
    final found = names((v) => v == 'found');
    final logged = names((v) => v.startsWith('logged'));
    final notFound = names((v) => v == 'not_found');
    final color = switch (a.status) {
      FarmerAdviceStatus.sent => AdvisoryColors.verified,
      FarmerAdviceStatus.draft => const Color(0xFFB26A00),
      FarmerAdviceStatus.withdrawn => kAgroMuted,
    };
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => FarmerAdviceEditorScreen(existing: a, testMode: testMode)),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AdvisoryColors.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              FlagTag(a.status.label, color),
              if (a.testOnly) const FlagTag('TEST', Color(0xFF4A148C), icon: Icons.science_outlined),
              if (showFarmer)
                Text(a.farmerName.isEmpty ? 'Farmer' : a.farmerName,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kAgroInk)),
              if (a.batchId != null) const FlagTag('Sent to several', kAgroMuted, icon: Icons.groups_rounded),
            ]),
            const SizedBox(height: 6),
            if (a.title.isNotEmpty)
              Text(a.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kAgroMuted)),
            Text(a.advice.main,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AdvisoryColors.darkGreen)),
            const SizedBox(height: 4),
            Text(
              a.status == FarmerAdviceStatus.sent
                  ? 'Sent by ${a.sentByName ?? '—'} · ${formatAdvisoryDate(a.sentAt)}'
                  : 'v${a.version} · ${a.updatedByName} · ${formatAdvisoryDate(a.updatedAt)}',
              style: const TextStyle(fontSize: 11, color: kAgroMuted),
            ),
            if (a.status == FarmerAdviceStatus.sent && res.isEmpty && responses != null)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('No answer from the farmer yet', style: TextStyle(fontSize: 11.5, color: kAgroMuted)),
              ),
            if (found.isNotEmpty || logged.isNotEmpty || notFound.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  [
                    if (found.isNotEmpty) 'Found: $found',
                    if (logged.isNotEmpty) 'Logged: $logged',
                    if (notFound.isNotEmpty) 'Not on farm: $notFound',
                  ].join(' · '),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdvisoryColors.verified),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
