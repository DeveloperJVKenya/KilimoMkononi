// lib/enterprise/features/weather/advisory_detail_screen.dart
//
// What a farmer sees when they open advice — from a push, the Notifications
// screen, Home, or a section's alert list. Verified advice and AI advice
// look alike (AI is clearly labelled). Below the advice itself:
//
//   Soil & fertiliser  per nutrient: the farmer's measured level (if any),
//                      Low / Moderate / High / "not sure" choices, the action
//                      for that level → "Log in Soil records"
//   Pests / Diseases   what to look for → "I see it" / "Not on my farm";
//                      Photo ID and the Pest / Disease guide to confirm;
//                      once found → "Log treatment"
//
// Every "log" writes the real intervention record of that section
// (AdvisoryInterventionService) — no need to open Field Data, Pest or
// Disease Management. Farmers without a field record are asked to set up
// their farm first, since interventions belong to a plot and crop.

import 'package:flutter/material.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_actions.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_widgets.dart';
import 'package:kilimomkononi/enterprise/features/weather/agronomic_advisory.dart';
import 'package:kilimomkononi/enterprise/features/weather/agronomic_advisory_service.dart';
import 'package:kilimomkononi/models/symptom_model.dart';
import 'package:kilimomkononi/screens/Field%20Data%20Input/field_data_input_home_page.dart';
import 'package:kilimomkononi/screens/disease%20management/disease_management_page.dart';
import 'package:kilimomkononi/screens/pest%20management/pest_management.dart';
import 'package:kilimomkononi/screens/pest%20management/photo_diagnosis_page.dart';
import 'package:kilimomkononi/services/advisory_intervention_service.dart';
import 'package:kilimomkononi/services/nutrient_levels.dart';
import 'package:kilimomkononi/services/pest_disease_catalog.dart';
import 'package:kilimomkononi/utils/friendly_error.dart';

class AdvisoryDetailScreen extends StatefulWidget {
  final String? advisoryId;
  final AgronomicAdvisory? advisory;

  /// The alert that led here (e.g. "Heavy rain at your farm"), if any.
  final String? alertTitle;

  /// Tests only: skip Firebase for the farm and the saved answers.
  @visibleForTesting
  final FarmContext? testFarm;
  @visibleForTesting
  final Map<String, String>? testResponses;

  const AdvisoryDetailScreen({
    super.key,
    this.advisoryId,
    this.advisory,
    this.alertTitle,
    this.testFarm,
    this.testResponses,
  }) : assert(advisoryId != null || advisory != null);

  @override
  State<AdvisoryDetailScreen> createState() => _AdvisoryDetailScreenState();
}

class _AdvisoryDetailScreenState extends State<AdvisoryDetailScreen> {
  AgronomicAdvisory? _advisory;
  bool _loading = true;
  String? _error;
  FarmContext? _farm;
  bool _farmLoading = true;

  @override
  void initState() {
    super.initState();
    _advisory = widget.advisory;
    _load();
  }

  Future<void> _load() async {
    if (_advisory == null) {
      try {
        final a = await AgronomicAdvisoryService.byId(widget.advisoryId!);
        if (!mounted) return;
        setState(() {
          _advisory = a;
          if (a == null) _error = 'This advice is no longer available — it may have been withdrawn.';
        });
      } catch (e) {
        if (!mounted) return;
        setState(() => _error = 'Could not load this advice. Check your connection and try again.');
      }
    }
    if (mounted) setState(() => _loading = false);
    await _loadFarm();
  }

  Future<void> _loadFarm() async {
    if (widget.testFarm != null) {
      setState(() {
        _farm = widget.testFarm;
        _farmLoading = false;
      });
      return;
    }
    setState(() => _farmLoading = true);
    try {
      final f = await AdvisoryInterventionService.loadFarm();
      if (mounted) setState(() => _farm = f);
    } catch (_) {
      if (mounted) setState(() => _farm = const FarmContext([]));
    } finally {
      if (mounted) setState(() => _farmLoading = false);
    }
  }

  /// Interventions belong to a plot + crop: without a field record, send
  /// the farmer to set one up, then come back here.
  Future<bool> _ensureFarm() async {
    if (_farm != null && !_farm!.isEmpty) return true;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.agriculture_rounded, color: AdvisoryColors.midGreen),
        title: const Text('Set up your farm first'),
        content: const Text(
          'Actions are saved against your plot and crop. Record your crop (and '
          'soil test, if you have one) in Field Data Input, then come back to '
          'log this advice.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AdvisoryColors.verified),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Set up farm'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return false;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const FieldDataInputHomePage()));
    await _loadFarm();
    return _farm != null && !_farm!.isEmpty;
  }

  void _snack(String msg, {bool ok = true}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: ok ? AdvisoryColors.verified : AdvisoryColors.red,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final a = _advisory;
    return Scaffold(
      backgroundColor: AdvisoryColors.pageBg,
      appBar: AppBar(
        backgroundColor: AdvisoryColors.darkGreen,
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(a?.isAi == true ? 'AI advice' : 'Verified advice',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const Text('Check your crops and log what you do',
              style: TextStyle(fontSize: 11.5, color: Colors.white70)),
        ]),
      ),
      body: DefaultTextStyle.merge(
        style: const TextStyle(fontWeight: FontWeight.w500),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AdvisoryColors.midGreen))
            : a == null
                ? _message(Icons.info_outline_rounded, _error ?? 'Advice not found.')
                : StreamBuilder<Map<String, String>>(
                    stream: widget.testResponses != null
                        ? Stream.value(widget.testResponses!)
                        : AdvisoryInterventionService.responses(a.id),
                    builder: (context, snap) => _body(a, snap.data ?? const {}),
                  ),
      ),
    );
  }

  Widget _message(IconData icon, String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 44, color: Colors.black38),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.black54)),
          ]),
        ),
      );

  Widget _body(AgronomicAdvisory a, Map<String, String> responses) {
    final farm = _farm;
    final act = a.actions;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (widget.alertTitle != null && widget.alertTitle!.isNotEmpty)
          _Banner(
            icon: Icons.warning_amber_rounded,
            color: AdvisoryColors.amber,
            text: 'Sent with the alert: ${widget.alertTitle}',
          ),
        if (a.isAi) _AiHeader(a) else VerifiedAdvisoryCard.fromAdvisory(a),
        const SizedBox(height: 14),
        if (!act.isEmpty) _SectionSummary(act),
        if (_farmLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(minHeight: 2, color: AdvisoryColors.midGreen),
          )
        else if (farm == null || farm.isEmpty)
          _Banner(
            icon: Icons.agriculture_rounded,
            color: AdvisoryColors.midGreen,
            text: 'Record your crop in Field Data Input to log these actions against your plot.',
            action: 'Set up farm',
            onAction: _ensureFarm,
          ),
        if (act.isEmpty)
          const _Banner(
            icon: Icons.checklist_rounded,
            color: AdvisoryColors.midGreen,
            text: 'This advice has no soil, pest or disease checks — follow the steps above.',
          ),
        if (act.soil.isNotEmpty) ...[
          _SectionHeader(AdviceSection.soil, act.soil.length,
              hint: 'Pick your soil level — or "Not sure" if you haven\'t tested.'),
          for (final s in act.soil)
            _SoilActionCard(
              advisory: a,
              action: s,
              farm: farm,
              responses: responses,
              ensureFarm: _ensureFarm,
              onDone: _snack,
            ),
        ],
        if (act.pests.isNotEmpty) ...[
          _SectionHeader(AdviceSection.pests, act.pests.length,
              hint: 'Walk your field and check for these.'),
          for (final c in act.pests)
            _CheckCard(
              advisory: a,
              section: AdviceSection.pests,
              check: c,
              farm: farm,
              responses: responses,
              ensureFarm: _ensureFarm,
              onDone: _snack,
            ),
        ],
        if (act.diseases.isNotEmpty) ...[
          _SectionHeader(AdviceSection.diseases, act.diseases.length,
              hint: 'Look at leaves, stems and fruit for these signs.'),
          for (final c in act.diseases)
            _CheckCard(
              advisory: a,
              section: AdviceSection.diseases,
              check: c,
              farm: farm,
              responses: responses,
              ensureFarm: _ensureFarm,
              onDone: _snack,
            ),
        ],
      ],
    );
  }
}

// ── Pieces ───────────────────────────────────────────────────────────────────

class _Banner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final String? action;
  final VoidCallback? onAction;
  const _Banner({required this.icon, required this.color, required this.text, this.action, this.onAction});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, color: color, height: 1.35, fontWeight: FontWeight.w600))),
          if (action != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: color),
              child: Text(action!, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ]),
      );
}

class _AiHeader extends StatelessWidget {
  final AgronomicAdvisory a;
  const _AiHeader(this.a);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdvisoryColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Wrap: the label drops below the title on narrow / large-text screens.
          const Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.auto_awesome_rounded, size: 16, color: AdvisoryColors.midGreen),
              SizedBox(width: 6),
              Text('AI Farm Advisor', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            ]),
            Pill('AI-generated · not verified',
                flexible: true,
                icon: Icons.info_outline_rounded, fg: AdvisoryColors.amber, bg: AdvisoryColors.lightAmber),
          ]),
          const SizedBox(height: 10),
          AdviceBody(advice: a.advice),
          const SizedBox(height: 8),
          const Text(
            'Generated from your station\'s live data and not reviewed by an agronomist. '
            'Confirm what you see on your farm before acting.',
            style: TextStyle(fontSize: 11, color: Colors.black54, height: 1.35),
          ),
        ]),
      );
}

class _SectionSummary extends StatelessWidget {
  final AdviceActions act;
  const _SectionSummary(this.act);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Wrap(spacing: 6, runSpacing: 6, children: [
          for (final s in act.sections) SectionChip(s, count: act.countFor(s)),
        ]),
      );
}

class _SectionHeader extends StatelessWidget {
  final AdviceSection section;
  final int count;
  final String hint;
  const _SectionHeader(this.section, this.count, {required this.hint});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: section.color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(section.icon, size: 16, color: section.color),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(section == AdviceSection.soil ? section.label : '${section.label} to check',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: section.color)),
            ),
            const SizedBox(width: 6),
            Text('($count)', style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
          ]),
          const SizedBox(height: 3),
          Text(hint, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ]),
      );
}

Widget _card({required Color color, required Widget child}) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.all(14),
      child: child,
    );

Widget _kv(String k, String v) => v.isEmpty
    ? const SizedBox.shrink()
    : Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 74,
            child: Text(k, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w700)),
          ),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 13, height: 1.35, color: Colors.black87))),
        ]),
      );

Future<bool> _confirmLog(BuildContext context, String title, List<String> lines) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final l in lines.where((l) => l.isNotEmpty)) Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(l, style: const TextStyle(fontSize: 13.5)),
          )],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AdvisoryColors.verified),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log it'),
          ),
        ],
      ),
    ) ??
    false;

Widget _cropPicker({
  required List<FarmCrop> options,
  required FarmCrop? value,
  required ValueChanged<FarmCrop?> onChanged,
  String label = 'Crop / plot',
}) {
  if (options.length <= 1) {
    return options.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('$label: ${options.first.label}',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.black87)),
          );
  }
  return Padding(
    padding: const EdgeInsets.only(top: 8),
    child: DropdownButtonFormField<FarmCrop>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: [for (final o in options) DropdownMenuItem(value: o, child: Text(o.label, overflow: TextOverflow.ellipsis))],
      onChanged: onChanged,
    ),
  );
}

// ── Soil & fertiliser ────────────────────────────────────────────────────────

class _SoilActionCard extends StatefulWidget {
  final AgronomicAdvisory advisory;
  final SoilAction action;
  final FarmContext? farm;
  final Map<String, String> responses;
  final Future<bool> Function() ensureFarm;
  final void Function(String, {bool ok}) onDone;

  const _SoilActionCard({
    required this.advisory,
    required this.action,
    required this.farm,
    required this.responses,
    required this.ensureFarm,
    required this.onDone,
  });

  @override
  State<_SoilActionCard> createState() => _SoilActionCardState();
}

class _SoilActionCardState extends State<_SoilActionCard> {
  FarmCrop? _plot;
  NutrientBand? _band;
  bool _bandTouched = false;
  bool _busy = false;

  List<FarmCrop> get _plots {
    final f = widget.farm;
    if (f == null) return const [];
    final m = FarmContext(f.matching(widget.advisory.crops)).plots;
    return m.isEmpty ? f.plots : m;
  }

  FarmCrop? get _currentPlot {
    final p = _plots;
    if (_plot != null && p.contains(_plot)) return _plot;
    return p.isEmpty ? null : p.first;
  }

  NutrientBand? get _measured => _currentPlot?.bands[widget.action.nutrient];

  /// The farmer's pick, else their measured level (if the advice covers it).
  NutrientBand? get _effectiveBand {
    if (_bandTouched) return _band;
    final m = _measured;
    return m != null && !widget.action.forBand(m).isEmpty ? m : null;
  }

  BandAction get _chosen {
    final b = _effectiveBand;
    final x = widget.action.forBand(b);
    return x.isEmpty ? widget.action.general : x;
  }

  String get _responseKey => AdvisoryInterventionService.responseKey(
      AdviceSection.soil, '${widget.action.nutrient}@${_currentPlot?.plotId ?? ''}');

  Future<void> _log() async {
    if (!await widget.ensureFarm()) return;
    final plot = _currentPlot;
    if (plot == null || !mounted) return;
    final c = _chosen;
    final band = _effectiveBand;
    final ok = await _confirmLog(context, 'Log in Soil records?', [
      'Plot: ${plot.label}',
      '${widget.action.label}${band == null ? '' : ' — ${band.label} level'}',
      if (c.action.isNotEmpty) 'Action: ${c.action}',
      if (c.product.isNotEmpty) 'Product: ${c.product}',
      if (c.rate.isNotEmpty) 'Rate: ${c.rate}',
      if (c.method.isNotEmpty) 'How / when: ${c.method}',
    ]);
    if (!ok) return;
    setState(() => _busy = true);
    try {
      final online = await AdvisoryInterventionService.logSoil(
        advisory: widget.advisory,
        plot: plot,
        action: widget.action,
        band: band,
      );
      widget.onDone(online
          ? 'Logged in Field Data (${plot.plotId}) — see Plot history'
          : 'Saved offline — syncs to Field Data when connected');
    } catch (e) {
      widget.onDone(friendlyError(e, 'Could not log it'), ok: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.action;
    final plot = _currentPlot;
    final measured = _measured;
    final band = _effectiveBand;
    final chosen = _chosen;
    final logged = widget.responses[_responseKey];
    const color = Color(0xFF6D4C41);
    return _card(
      color: color,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.science_outlined, size: 18, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(a.label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800))),
          if (logged != null) const Pill('Logged', icon: Icons.check_rounded, fg: AdvisoryColors.verified, bg: AdvisoryColors.verifiedBg),
        ]),
        _cropPicker(
          options: _plots,
          value: plot,
          label: 'Plot',
          onChanged: (p) => setState(() {
            _plot = p;
            _bandTouched = false;
          }),
        ),
        if (a.isMeasured) ...[
          const SizedBox(height: 8),
          Text(
            measured != null
                ? 'Your soil test: ${measured.label}${plot?.measuredAt == null ? '' : ' (recorded ${formatAdvisoryDate(plot!.measuredAt)})'}'
                : 'Not measured on this plot — choose the level you think fits, or "Not sure".',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: measured != null ? color : Colors.black54,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final b in NutrientBand.values)
            if (!a.forBand(b).isEmpty)
              ChoiceChip(
                label: Text(b == measured ? '${b.label} (your test)' : b.label),
                selected: band == b,
                showCheckmark: false,
                selectedColor: color,
                labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: band == b ? Colors.white : color),
                onSelected: (_) => setState(() {
                  _band = b;
                  _bandTouched = true;
                }),
              ),
          ChoiceChip(
            label: const Text('Not sure'),
            selected: band == null,
            showCheckmark: false,
            selectedColor: Colors.black54,
            labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: band == null ? Colors.white : Colors.black54),
            onSelected: (_) => setState(() {
              _band = null;
              _bandTouched = true;
            }),
          ),
        ]),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFF8F5F3), borderRadius: BorderRadius.circular(10)),
          child: chosen.isEmpty
              ? const Text('No general action — pick a level above.',
                  style: TextStyle(fontSize: 12.5, color: Colors.black54))
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(band == null ? 'What to do' : 'What to do at ${band.label.toLowerCase()} level',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: color)),
                  _kv('Action', chosen.action),
                  _kv('Product', chosen.product),
                  _kv('Rate', chosen.rate),
                  _kv('How/when', chosen.method),
                ]),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: color),
            onPressed: _busy || chosen.isEmpty ? null : _log,
            icon: _busy
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.playlist_add_check_rounded, size: 18),
            label: Text(logged != null ? 'Log again' : 'Apply & log in Soil records'),
          ),
        ),
      ]),
    );
  }
}

// ── Pests / diseases ─────────────────────────────────────────────────────────

class _CheckCard extends StatefulWidget {
  final AgronomicAdvisory advisory;
  final AdviceSection section;
  final CropCheck check;
  final FarmContext? farm;
  final Map<String, String> responses;
  final Future<bool> Function() ensureFarm;
  final void Function(String, {bool ok}) onDone;

  const _CheckCard({
    required this.advisory,
    required this.section,
    required this.check,
    required this.farm,
    required this.responses,
    required this.ensureFarm,
    required this.onDone,
  });

  @override
  State<_CheckCard> createState() => _CheckCardState();
}

class _CheckCardState extends State<_CheckCard> {
  FarmCrop? _crop;
  bool _busy = false;

  bool get _isPest => widget.section == AdviceSection.pests;

  String get _key => AdvisoryInterventionService.responseKey(widget.section, widget.check.name);

  List<FarmCrop> get _crops {
    final f = widget.farm;
    if (f == null) return const [];
    final m = f.matching(widget.advisory.crops);
    return m.isEmpty ? f.crops : m;
  }

  FarmCrop? get _currentCrop {
    final c = _crops;
    if (_crop != null && c.contains(_crop)) return _crop;
    return c.isEmpty ? null : c.first;
  }

  void _answer(String v) =>
      AdvisoryInterventionService.setResponse(widget.advisory.id, _key, v);

  /// Opens the Pest / Disease guide on this pest/disease for the crop.
  void _openGuide() {
    final crop = _currentCrop?.crop ?? (widget.advisory.crops.isEmpty ? '' : widget.advisory.crops.first);
    final stage = catalogStageFor(crop, widget.check.name, pest: _isPest);
    final symptoms = stage == null
        ? null
        : [
            Symptom(
              crop: crop,
              stage: stage,
              plantPart: 'General',
              label: widget.check.signs,
              likelyType: _isPest ? 'pest' : 'disease',
              shortCode: '',
              identity: widget.check.name,
            ),
          ];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _isPest
            ? PestManagementPage(selectedSymptoms: symptoms)
            : DiseaseManagementPage(selectedSymptoms: symptoms),
      ),
    );
  }

  void _openPhotoId() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PhotoDiagnosisPage(issueType: _isPest ? 'pest' : 'disease')),
      );

  Future<void> _log() async {
    if (!await widget.ensureFarm()) return;
    final crop = _currentCrop;
    if (crop == null || !mounted) return;
    final c = widget.check;
    final ok = await _confirmLog(context, 'Log in ${_isPest ? 'Pest' : 'Disease'} records?', [
      '${_isPest ? 'Pest' : 'Disease'}: ${c.name}',
      'Crop: ${crop.label}',
      'Action: ${c.interventionText}',
      if (c.rate.isNotEmpty) 'Rate: ${c.rate}',
    ]);
    if (!ok) return;
    setState(() => _busy = true);
    try {
      final online = _isPest
          ? await AdvisoryInterventionService.logPest(advisory: widget.advisory, crop: crop, check: c)
          : await AdvisoryInterventionService.logDisease(advisory: widget.advisory, crop: crop, check: c);
      widget.onDone(online
          ? 'Logged in ${_isPest ? 'Pest' : 'Disease'} Management — see its history'
          : 'Saved offline — syncs when connected');
    } catch (e) {
      widget.onDone(friendlyError(e, 'Could not log it'), ok: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.check;
    final s = widget.section;
    final answer = widget.responses[_key];
    final found = answer == 'found' || answer == 'logged';
    return _card(
      color: s.color,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(s.icon, size: 18, color: s.color),
          const SizedBox(width: 6),
          Expanded(child: Text(c.name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800))),
          if (answer == 'logged')
            const Pill('Logged', icon: Icons.check_rounded, fg: AdvisoryColors.verified, bg: AdvisoryColors.verifiedBg)
          else if (answer == 'not_found')
            Pill('Not seen', icon: Icons.remove_done_rounded, fg: Colors.grey.shade700, bg: Colors.grey.shade200)
          else if (answer == 'found')
            Pill('Found', icon: Icons.priority_high_rounded, fg: s.color, bg: s.color.withValues(alpha: 0.12)),
        ]),
        _kv('Look for', c.signs),
        _kv('If found', c.ifFound),
        _kv('Product', c.product),
        _kv('Rate', c.rate),
        const SizedBox(height: 10),
        Text('Is it on your farm?', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: s.color)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 6, children: [
          ChoiceChip(
            avatar: Icon(Icons.check_circle_rounded, size: 16, color: found ? Colors.white : s.color),
            label: const Text('Yes, I see it'),
            selected: found,
            showCheckmark: false,
            selectedColor: s.color,
            labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: found ? Colors.white : s.color),
            onSelected: (_) => _answer(answer == 'logged' ? 'logged' : 'found'),
          ),
          ChoiceChip(
            label: const Text('Not on my farm'),
            selected: answer == 'not_found',
            showCheckmark: false,
            selectedColor: Colors.black54,
            labelStyle: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: answer == 'not_found' ? Colors.white : Colors.black54),
            onSelected: (_) => _answer('not_found'),
          ),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 4, children: [
          TextButton.icon(
            onPressed: _openPhotoId,
            icon: const Icon(Icons.photo_camera_rounded, size: 16),
            label: const Text('Not sure? Photo ID'),
            style: TextButton.styleFrom(foregroundColor: s.color),
          ),
          TextButton.icon(
            onPressed: _openGuide,
            icon: const Icon(Icons.menu_book_rounded, size: 16),
            label: Text(_isPest ? 'Pest guide' : 'Disease guide'),
            style: TextButton.styleFrom(foregroundColor: s.color),
          ),
        ]),
        if (found) ...[
          const Divider(height: 18),
          _cropPicker(options: _crops, value: _currentCrop, onChanged: (v) => setState(() => _crop = v)),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: s.color),
              onPressed: _busy ? null : _log,
              icon: _busy
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.playlist_add_check_rounded, size: 18),
              label: Text(answer == 'logged' ? 'Log again' : 'Log treatment in ${_isPest ? 'Pest' : 'Disease'} records'),
            ),
          ),
        ],
      ]),
    );
  }
}

/// "Soil 2" / "Pests 1" chip in a section's colour.
class SectionChip extends StatelessWidget {
  final AdviceSection section;
  final int? count;
  final bool dense;
  const SectionChip(this.section, {super.key, this.count, this.dense = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 8, vertical: dense ? 2 : 4),
        decoration: BoxDecoration(
          color: section.color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: section.color.withValues(alpha: 0.35)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(section.icon, size: dense ? 11 : 13, color: section.color),
          const SizedBox(width: 4),
          Text(count == null ? section.short : '${section.short} $count',
              style: TextStyle(fontSize: dense ? 10 : 11.5, fontWeight: FontWeight.w800, color: section.color)),
        ]),
      );
}
