// lib/enterprise/features/weather/field_agronomist_panel_screen.dart
//
// Field Agronomist panel (opened from the Weather Station screen).
//   • Live conditions for any Kilimo Mkononi station, with the advisory
//     conditions active right now and which of them still lack published
//     advice.
//   • Drafts / Published / Archived advisories — tap to edit, verify,
//     publish, update, unpublish, archive.

import 'package:flutter/material.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_conditions.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_editor_screen.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_widgets.dart';
import 'package:kilimomkononi/enterprise/features/weather/agronomic_advisory.dart';
import 'package:kilimomkononi/enterprise/features/weather/agronomic_advisory_service.dart';
import 'package:kilimomkononi/services/nuasense_service.dart';

class FieldAgronomistPanelScreen extends StatefulWidget {
  final String? initialStationId;

  /// Admin test mode — see AdvisoryAccess.adminTest.
  final bool testMode;

  const FieldAgronomistPanelScreen({
    super.key,
    this.initialStationId,
    this.testMode = false,
  });

  @override
  State<FieldAgronomistPanelScreen> createState() =>
      _FieldAgronomistPanelScreenState();
}

class _FieldAgronomistPanelScreenState
    extends State<FieldAgronomistPanelScreen> {
  List<NuaStation> _stations = [];
  String? _stationId;
  NuaSenseReading? _reading;
  bool _readingLoading = true;
  String? _readingError;

  @override
  void initState() {
    super.initState();
    _stationId = widget.initialStationId;
    _loadStations();
    _loadReading();
  }

  Future<void> _loadStations() async {
    try {
      final s = await NuaSenseService.getStations();
      if (!mounted) return;
      setState(() {
        _stations = s;
        _stationId ??= s.isNotEmpty ? s.first.id : null;
      });
    } catch (_) {}
  }

  Future<void> _loadReading() async {
    setState(() {
      _readingLoading = true;
      _readingError = null;
    });
    try {
      final r = await NuaSenseService.getLatestReading(stationId: _stationId);
      if (!mounted) return;
      setState(() {
        _reading = r;
        _readingLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _readingError = '$e';
        _readingLoading = false;
      });
    }
  }

  String? get _stationName {
    for (final s in _stations) {
      if (s.id == _stationId) return s.name.isNotEmpty ? s.name : s.id;
    }
    return _stationId;
  }

  Future<void> _openEditor({
    AgronomicAdvisory? existing,
    String? condition,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdvisoryEditorScreen(
          existing: existing,
          presetCondition: condition,
          presetGatewayId: _stationId,
          presetStationName: _stationName,
          reading: _reading,
          testMode: widget.testMode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AdvisoryColors.pageBg,
        appBar: AppBar(
          backgroundColor: widget.testMode
              ? const Color(0xFF4A148C)
              : AdvisoryColors.darkGreen,
          foregroundColor: Colors.white,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Field Agronomist Panel',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              Text(
                widget.testMode
                    ? 'TEST MODE · nothing reaches farmers'
                    : 'Verify & publish weather advice for farmers',
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Refresh conditions',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadReading,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AdvisoryColors.verified,
          foregroundColor: Colors.white,
          onPressed: () => _openEditor(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('New advisory'),
        ),
        body: NestedScrollView(
          headerSliverBuilder: (_, _) => [
            if (widget.testMode)
              const SliverToBoxAdapter(
                child: TestModeStrip(
                  text: 'Admin test mode — advisories you create or publish are '
                      'marked TEST and are never shown to farmers. Live '
                      'advisories are read-only.',
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _LiveConditionsCard(
                  stations: _stations,
                  stationId: _stationId,
                  reading: _reading,
                  loading: _readingLoading,
                  error: _readingError,
                  onStation: (id) {
                    setState(() => _stationId = id);
                    _loadReading();
                  },
                  onDraft: (condition) => _openEditor(condition: condition),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: TabBar(
                labelColor: AdvisoryColors.darkGreen,
                indicatorColor: AdvisoryColors.verified,
                unselectedLabelColor: Colors.black54,
                tabs: [
                  Tab(text: 'Drafts'),
                  Tab(text: 'Published'),
                  Tab(text: 'Archived'),
                ],
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _AdvisoryList(
                status: AdvisoryStatus.draft,
                onOpen: (a) => _openEditor(existing: a),
              ),
              _AdvisoryList(
                status: AdvisoryStatus.published,
                onOpen: (a) => _openEditor(existing: a),
              ),
              _AdvisoryList(
                status: AdvisoryStatus.archived,
                onOpen: (a) => _openEditor(existing: a),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Live conditions ──────────────────────────────────────────────────────────

class _LiveConditionsCard extends StatelessWidget {
  final List<NuaStation> stations;
  final String? stationId;
  final NuaSenseReading? reading;
  final bool loading;
  final String? error;
  final ValueChanged<String?> onStation;
  final ValueChanged<String> onDraft;

  const _LiveConditionsCard({
    required this.stations,
    required this.stationId,
    required this.reading,
    required this.loading,
    required this.error,
    required this.onStation,
    required this.onDraft,
  });

  @override
  Widget build(BuildContext context) {
    final r = reading;
    final active = (r != null && r.isProvisioned)
        ? activeConditionKeys(r)
        : <String>{};
    final specific = kAdvisoryConditions.where(
      (c) => active.contains(c.key) && c.key != 'general',
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdvisoryColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.sensors_rounded,
                size: 18,
                color: AdvisoryColors.midGreen,
              ),
              const SizedBox(width: 6),
              const Text(
                'Live conditions',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              if (stations.isNotEmpty)
                DropdownButton<String>(
                  value: stations.any((s) => s.id == stationId)
                      ? stationId
                      : null,
                  hint: const Text('Station', style: TextStyle(fontSize: 12)),
                  underline: const SizedBox.shrink(),
                  isDense: true,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                  items: stations
                      .map(
                        (s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(
                            s.name.isNotEmpty ? s.name : s.id,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: onStation,
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (loading)
            const LinearProgressIndicator(minHeight: 2)
          else if (error != null)
            Text(
              'Could not load station data: $error',
              style: const TextStyle(fontSize: 12, color: AdvisoryColors.red),
            )
          else if (r == null || !r.isProvisioned)
            const Text(
              'No station data available. You can still write advisories for any '
              'condition — they will show whenever a farmer\'s station matches.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
                height: 1.4,
              ),
            )
          else ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _metric(
                  Icons.thermostat_rounded,
                  '${r.airTemp.toStringAsFixed(1)}°C',
                ),
                _metric(
                  Icons.water_drop_outlined,
                  '${r.humidity.toStringAsFixed(0)}% RH',
                ),
                _metric(
                  Icons.air_rounded,
                  '${r.windSpeed.toStringAsFixed(1)} m/s',
                ),
                _metric(
                  Icons.grain_rounded,
                  '${r.rainfall.toStringAsFixed(1)} mm/h',
                ),
                _metric(
                  Icons.eco_outlined,
                  r.leafIsWet ? 'Leaves wet' : 'Leaves dry',
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Farmers at this station now match:',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 6),
            if (specific.isEmpty)
              const Text(
                'Only "Any conditions" advice — nothing unusual right now.',
                style: TextStyle(fontSize: 12),
              )
            else
              _CoverageChips(conditions: specific.toList(), onDraft: onDraft),
          ],
        ],
      ),
    );
  }

  Widget _metric(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AdvisoryColors.pageBg,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AdvisoryColors.midGreen),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

/// Active conditions, flagged when no published advisory covers them yet.
class _CoverageChips extends StatelessWidget {
  final List<AdvisoryCondition> conditions;
  final ValueChanged<String> onDraft;
  const _CoverageChips({required this.conditions, required this.onDraft});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AgronomicAdvisory>>(
      stream: AgronomicAdvisoryService.streamByStatus(AdvisoryStatus.published),
      builder: (context, snap) {
        final covered = (snap.data ?? const <AgronomicAdvisory>[])
            .map((a) => a.condition)
            .toSet();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: conditions.map((c) {
                final has = covered.contains(c.key);
                return ActionChip(
                  avatar: Icon(
                    has ? Icons.verified_rounded : Icons.warning_amber_rounded,
                    size: 16,
                    color: has ? AdvisoryColors.verified : AdvisoryColors.amber,
                  ),
                  label: Text(has ? c.label : '${c.label} · needs advice'),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: has ? AdvisoryColors.verified : AdvisoryColors.amber,
                  ),
                  backgroundColor: has
                      ? AdvisoryColors.verifiedBg
                      : AdvisoryColors.lightAmber,
                  side: BorderSide.none,
                  tooltip: 'Draft advice for "${c.label}"',
                  onPressed: () => onDraft(c.key),
                );
              }).toList(),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap a condition to draft advice for it.',
              style: TextStyle(fontSize: 11, color: Colors.black45),
            ),
          ],
        );
      },
    );
  }
}

// ── Advisory lists ───────────────────────────────────────────────────────────

class _AdvisoryList extends StatelessWidget {
  final AdvisoryStatus status;
  final ValueChanged<AgronomicAdvisory> onOpen;
  const _AdvisoryList({required this.status, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AgronomicAdvisory>>(
      stream: AgronomicAdvisoryService.streamByStatus(status),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load advisories.\n${snap.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AdvisoryColors.red),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data!;
        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                switch (status) {
                  AdvisoryStatus.draft =>
                    'No drafts. Tap "New advisory" or a live condition above.',
                  AdvisoryStatus.published =>
                    'Nothing published yet — farmers only see the AI advisor.',
                  AdvisoryStatus.archived => 'No archived advisories.',
                },
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, color: Colors.black54),
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) =>
              _AdvisoryTile(list[i], onTap: () => onOpen(list[i])),
        );
      },
    );
  }
}

class _AdvisoryTile extends StatelessWidget {
  final AgronomicAdvisory a;
  final VoidCallback onTap;
  const _AdvisoryTile(this.a, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    final who = a.status == AdvisoryStatus.published
        ? 'Verified by ${a.publishedByName ?? '—'} · ${formatAdvisoryDate(a.publishedAt)}'
        : 'v${a.version} · ${a.updatedByName} · ${formatAdvisoryDate(a.updatedAt)}';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AdvisoryColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatusPill(a.status),
                  const SizedBox(width: 6),
                  ConditionPill(a.condition),
                  if (a.testOnly) ...[
                    const SizedBox(width: 6),
                    const Pill(
                      'TEST',
                      icon: Icons.science_outlined,
                      fg: Colors.white,
                      bg: Color(0xFF4A148C),
                    ),
                  ],
                  const Spacer(),
                  if (a.source == 'ai_assisted')
                    const Tooltip(
                      message: 'Started from an AI draft',
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        size: 14,
                        color: AdvisoryColors.amber,
                      ),
                    ),
                  const SizedBox(width: 6),
                  Icon(
                    a.isStationScoped
                        ? Icons.sensors_rounded
                        : Icons.public_rounded,
                    size: 14,
                    color: Colors.black38,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                a.advice.main,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AdvisoryColors.darkGreen,
                ),
              ),
              const SizedBox(height: 6),
              CropChips(a.crops),
              const SizedBox(height: 8),
              Text(
                who,
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
