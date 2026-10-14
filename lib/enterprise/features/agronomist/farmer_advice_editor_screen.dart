// lib/enterprise/features/agronomist/farmer_advice_editor_screen.dart
//
// Write custom advice for one farmer — or the same advice for several (e.g.
// everyone reporting an emerging pest). Same content as a verified advisory
// (main action, DO / AVOID / WHY, soil / pest / disease actions) so the
// farmer receives and acts on it exactly the same way. "Draft with AI"
// starts from the farmer's own records; the agronomist reviews everything.
//
//   new        Save draft · Send
//   draft      Save draft · Send · Delete
//   sent       Save changes (tick "Notify the farmer again" to re-push) ·
//              Withdraw
//   withdrawn  read-only · Restore to draft
//
// Admins in test mode: everything is marked TEST — the farmer never sees it;
// the push goes to the admin.

import 'package:flutter/material.dart';
import 'package:kilimomkononi/enterprise/features/agronomist/agronomist_data_service.dart';
import 'package:kilimomkononi/enterprise/features/agronomist/farmer_advice.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_actions.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_actions_editor.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_widgets.dart';
import 'package:kilimomkononi/enterprise/features/weather/agronomic_advisory_service.dart';
import 'package:kilimomkononi/enterprise/features/weather/structured_advice.dart';
import 'package:kilimomkononi/services/nutrient_levels.dart';
import 'package:kilimomkononi/utils/friendly_error.dart';

class FarmerAdviceEditorScreen extends StatefulWidget {
  /// Who it is for (new advice). Ignored when editing [existing].
  final List<AdviceTarget> targets;
  final FarmerAdvice? existing;
  final bool testMode;
  final List<String>? initialCrops;
  final AdviceBasis? basedOn;
  final AdviceActions initialActions;
  final StructuredAdvice? initialAdvice;
  final String? initialTitle;

  /// The farmer's records, summarised for "Draft with AI".
  final String? farmerContext;

  const FarmerAdviceEditorScreen({
    super.key,
    this.targets = const [],
    this.existing,
    required this.testMode,
    this.initialCrops,
    this.basedOn,
    this.initialActions = AdviceActions.empty,
    this.initialAdvice,
    this.initialTitle,
    this.farmerContext,
  }) : assert(existing != null || targets.length > 0);

  @override
  State<FarmerAdviceEditorScreen> createState() => _FarmerAdviceEditorScreenState();
}

class _FarmerAdviceEditorScreenState extends State<FarmerAdviceEditorScreen> {
  final _title = TextEditingController();
  final _main = TextEditingController();
  final _do = TextEditingController();
  final _avoid = TextEditingController();
  final _why = TextEditingController();
  final _focus = TextEditingController();
  late List<String> _crops;
  late AdviceActions _actions;
  AdviceBasis? _basis;
  bool _notify = false;
  bool _busy = false;
  bool _ai = false;
  String? _aiError;

  FarmerAdvice? get _e => widget.existing;
  bool get _readOnly => _e?.status == FarmerAdviceStatus.withdrawn || (_e?.testOnly == true && !widget.testMode);
  bool get _isSent => _e?.status == FarmerAdviceStatus.sent;

  List<AdviceTarget> get _targets => _e == null
      ? widget.targets
      : [AdviceTarget(uid: _e!.farmerUid, name: _e!.farmerName.isEmpty ? 'Farmer' : _e!.farmerName, crops: _e!.crops)];

  @override
  void initState() {
    super.initState();
    final e = _e;
    final a = e?.advice ?? widget.initialAdvice ?? const StructuredAdvice(main: '');
    _title.text = e?.title ?? widget.initialTitle ?? '';
    _main.text = a.main;
    _do.text = a.doList.join('\n');
    _avoid.text = a.avoidList.join('\n');
    _why.text = a.why;
    _actions = e?.actions ?? widget.initialActions;
    _basis = e?.basedOn ?? widget.basedOn;
    final fromTargets = {for (final t in widget.targets) ...t.crops}.toList();
    _crops = [...(e?.crops ?? widget.initialCrops ?? (fromTargets.length <= 4 ? fromTargets : const <String>[]))];
    if (_title.text.isEmpty && _basis != null) _title.text = _basis!.label;
  }

  @override
  void dispose() {
    for (final c in [_title, _main, _do, _avoid, _why, _focus]) {
      c.dispose();
    }
    super.dispose();
  }

  static List<String> _lines(String s) =>
      s.split('\n').map((l) => l.replaceFirst(RegExp(r'^[-•*]\s*'), '').trim()).where((l) => l.isNotEmpty).toList();

  StructuredAdvice get _advice => StructuredAdvice(
        main: _main.text.trim(),
        doList: _lines(_do.text),
        avoidList: _lines(_avoid.text),
        why: _why.text.trim(),
      );

  FarmerAdviceContent _content(AdviceTarget t) => FarmerAdviceContent(
        farmerUid: t.uid,
        farmerName: t.name,
        title: _title.text.trim(),
        advice: _advice,
        crops: _crops,
        actions: _actions,
        basedOn: _basis,
        batchId: _e?.batchId,
        testOnly: widget.testMode || (_e?.testOnly ?? false),
      );

  String? _validate() {
    final a = _advice;
    if (a.main.isEmpty) return 'Write the main action — what the farmer should do.';
    if (a.main.length > 300) return 'Keep the main action under 300 characters.';
    if (_title.text.trim().length > 200) return 'Keep the title under 200 characters.';
    if (a.doList.length > 10 || a.avoidList.length > 10) return 'At most 10 lines each for DO and AVOID.';
    if ([...a.doList, ...a.avoidList].any((l) => l.length > 160)) return 'Keep each DO / AVOID line under 160 characters.';
    if (a.why.length > 600) return 'Keep WHY under 600 characters.';
    return null;
  }

  void _snack(String m, {bool ok = true}) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m), backgroundColor: ok ? AdvisoryColors.verified : AdvisoryColors.red));

  Future<void> _run(Future<void> Function() job, String done) async {
    setState(() => _busy = true);
    try {
      await job();
      if (!mounted) return;
      _snack(done);
      Navigator.pop(context, true);
    } on AdvisoryConflictException catch (e) {
      if (mounted) _snack(e.toString(), ok: false);
    } catch (e) {
      if (mounted) _snack(friendlyError(e, 'Couldn\'t save the advice'), ok: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(FarmerAdviceStatus status) async {
    final err = _validate();
    if (err != null) {
      _snack(err, ok: false);
      return;
    }
    final sending = status == FarmerAdviceStatus.sent && !_isSent;
    if (sending) {
      final n = _targets.length;
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.send_rounded, color: AdvisoryColors.verified),
          title: Text(n == 1 ? 'Send to ${_targets.first.name}?' : 'Send to $n farmers?'),
          content: Text(widget.testMode
              ? 'TEST mode — the farmer${n == 1 ? '' : 's'} won\'t see it; the notification comes to you.'
              : 'They get a notification now and can act on it from their phone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not yet')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AdvisoryColors.verified),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Send'),
            ),
          ],
        ),
      );
      if (go != true) return;
    }
    final e = _e;
    if (e != null) {
      await _run(
        () => AgronomistDataService.save(
          id: e.id,
          expectedVersion: e.version,
          content: _content(_targets.first),
          status: status,
          action: sending ? 'sent' : (_isSent ? 'updated' : 'edited'),
          notify: _notify,
        ),
        sending ? 'Sent' : 'Saved',
      );
    } else {
      await _run(
        () => AgronomistDataService.createForMany(
          content: _content(_targets.first),
          farmers: _targets,
          status: status,
        ),
        status == FarmerAdviceStatus.sent
            ? 'Sent to ${_targets.length == 1 ? _targets.first.name : '${_targets.length} farmers'}'
            : 'Draft saved',
      );
    }
  }

  Future<void> _status(FarmerAdviceStatus s, String action, String done) async {
    final e = _e!;
    if (s == FarmerAdviceStatus.withdrawn) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Withdraw this advice?'),
          content: const Text('The farmer will no longer see it. It stays in the record.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AdvisoryColors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Withdraw'),
            ),
          ],
        ),
      );
      if (go != true) return;
    }
    await _run(() => AgronomistDataService.changeStatus(e, s, action), done);
  }

  Future<void> _delete() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this draft?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AdvisoryColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (go != true) return;
    await _run(() => AgronomistDataService.deleteDraft(_e!.id), 'Draft deleted');
  }

  Future<void> _draftWithAi() async {
    setState(() {
      _ai = true;
      _aiError = null;
    });
    try {
      final ctx = widget.farmerContext ??
          [
            if (_basis != null) 'Reason for this advice: ${_basis!.label}',
            'Farmers: ${_targets.length} in the area',
            if (_crops.isNotEmpty) 'Crops: ${_crops.join(', ')}',
          ].join('\n');
      final r = await AgronomistDataService.aiDraft(
        farmerContext: ctx,
        crops: _crops,
        focus: [_focus.text.trim(), if (_basis != null) _basis!.label].where((s) => s.isNotEmpty).join('. '),
      );
      if (!mounted) return;
      setState(() {
        _main.text = r.advice.main;
        _do.text = r.advice.doList.join('\n');
        _avoid.text = r.advice.avoidList.join('\n');
        _why.text = r.advice.why;
        final a = r.advice.actions;
        _actions = AdviceActions(
          soil: [..._actions.soil, ...a.soil].take(20).toList(),
          pests: [..._actions.pests, ...a.pests.where((p) => !_actions.pests.any((x) => x.name == p.name))]
              .take(10)
              .toList(),
          diseases: [..._actions.diseases, ...a.diseases.where((p) => !_actions.diseases.any((x) => x.name == p.name))]
              .take(10)
              .toList(),
        );
      });
      _snack('AI draft added — review every line before sending.');
    } catch (e) {
      if (mounted) setState(() => _aiError = friendlyError(e, 'The AI draft didn\'t work'));
    } finally {
      if (mounted) setState(() => _ai = false);
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final e = _e;
    final who = _targets.length == 1 ? _targets.first.name : '${_targets.length} farmers';
    return Scaffold(
      backgroundColor: AdvisoryColors.pageBg,
      appBar: AppBar(
        backgroundColor: widget.testMode ? const Color(0xFF4A148C) : AdvisoryColors.darkGreen,
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(e == null ? 'Advice for $who' : 'Advice · ${e.status.label}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          Text(
            widget.testMode ? 'TEST MODE · farmers never see it' : 'Custom advice from their records',
            style: const TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ]),
        actions: [
          if (e != null && !_busy)
            PopupMenuButton<String>(
              onSelected: (v) => switch (v) {
                'withdraw' => _status(FarmerAdviceStatus.withdrawn, 'withdrawn', 'Withdrawn'),
                'restore' => _status(FarmerAdviceStatus.draft, 'restored', 'Restored to draft'),
                'delete' => _delete(),
                _ => null,
              },
              itemBuilder: (_) => [
                if (e.status == FarmerAdviceStatus.sent)
                  const PopupMenuItem(value: 'withdraw', child: Text('Withdraw from the farmer')),
                if (e.status == FarmerAdviceStatus.withdrawn)
                  const PopupMenuItem(value: 'restore', child: Text('Restore to draft')),
                if (e.status == FarmerAdviceStatus.draft && !e.wasEverSent)
                  const PopupMenuItem(value: 'delete', child: Text('Delete draft')),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          if (widget.testMode)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: TestModeStrip(text: 'Admin test mode — this advice is marked TEST and never reaches the farmer.'),
            ),
          _section('For', Icons.people_alt_outlined, _targetsBox()),
          if (!_readOnly) _section('Start with AI (optional)', Icons.auto_awesome_rounded, _aiBox()),
          _section('Advice', Icons.edit_note_rounded, _adviceFields()),
          for (final s in AdviceSection.values)
            _section(
              switch (s) {
                AdviceSection.soil => 'Soil & fertiliser actions',
                AdviceSection.pests => 'Pests to check',
                AdviceSection.diseases => 'Diseases to check',
              },
              s.icon,
              AdvisoryActionsSection(
                section: s,
                value: _actions,
                crops: _crops,
                readOnly: _readOnly,
                onChanged: (v) => setState(() => _actions = v),
              ),
            ),
          _section(
            'Preview — what the farmer sees',
            Icons.visibility_outlined,
            ListenableBuilder(
              listenable: Listenable.merge([_title, _main, _do, _avoid, _why]),
              builder: (_, _) => VerifiedAdvisoryCard(
                advice: _advice.main.isEmpty ? const StructuredAdvice(main: 'Your main action appears here') : _advice,
                crops: _crops,
                condition: 'general',
                preview: true,
                forYou: true,
                title: _title.text.trim().isEmpty ? null : _title.text.trim(),
                actions: _actions,
                testOnly: widget.testMode,
              ),
            ),
          ),
          if (e != null)
            Text(
              'v${e.version} · last change by ${e.updatedByName.isEmpty ? '—' : e.updatedByName} '
              '${formatAdvisoryDate(e.updatedAt)}'
              '${e.sentAt != null ? ' · sent by ${e.sentByName ?? '—'} ${formatAdvisoryDate(e.sentAt)}' : ''}',
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
        ],
      ),
      bottomNavigationBar: _readOnly ? null : _actionBar(),
    );
  }

  Widget _section(String title, IconData icon, Widget child) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdvisoryColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 16, color: AdvisoryColors.midGreen),
            const SizedBox(width: 6),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: 12),
          child,
        ]),
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 2),
        child: Text(t, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.black54)),
      );

  InputDecoration _deco(String hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFFAFBFA),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      );

  Widget _targetsBox() {
    final t = _targets;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final x in t.take(12))
          Chip(
            avatar: const Icon(Icons.person_outline_rounded, size: 16),
            label: Text(x.name, style: const TextStyle(fontSize: 12)),
            visualDensity: VisualDensity.compact,
          ),
        if (t.length > 12) Chip(label: Text('+${t.length - 12} more'), visualDensity: VisualDensity.compact),
      ]),
      if (t.length > 1)
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text('Each farmer gets their own copy — you can follow up or withdraw it farmer by farmer.',
              style: TextStyle(fontSize: 11, color: Colors.black54)),
        ),
      if (_basis != null) ...[
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.link_rounded, size: 16, color: Colors.black45),
          const SizedBox(width: 6),
          Expanded(
            child: Text('About: ${_basis!.label}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          if (!_readOnly)
            IconButton(
              tooltip: 'Remove',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded, size: 16),
              onPressed: () => setState(() => _basis = null),
            ),
        ]),
      ],
      const SizedBox(height: 10),
      _label('Crops'),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final c in _crops)
          InputChip(
            label: Text(c, style: const TextStyle(fontSize: 12)),
            onDeleted: _readOnly ? null : () => setState(() => _crops.remove(c)),
            visualDensity: VisualDensity.compact,
          ),
        if (!_readOnly && _crops.length < 20)
          PopupMenuButton<String>(
            tooltip: 'Add a crop',
            onSelected: (c) => setState(() => _crops.add(c)),
            itemBuilder: (_) => [
              for (final c in {...t.expand((x) => x.crops), ...kFieldCropTypes})
                if (!_crops.contains(c)) PopupMenuItem(value: c, child: Text(c)),
            ],
            child: const Chip(
              avatar: Icon(Icons.add_rounded, size: 16),
              label: Text('Add crop', style: TextStyle(fontSize: 12)),
              visualDensity: VisualDensity.compact,
            ),
          ),
      ]),
      if (_crops.isEmpty)
        const Text('No crop picked — the advice is about the whole farm.',
            style: TextStyle(fontSize: 11, color: Colors.black54)),
    ]);
  }

  Widget _aiBox() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          widget.farmerContext != null
              ? 'Drafts advice from this farmer\'s plots, soil tests and pest / disease reports. You review and edit it before sending.'
              : 'Drafts advice for the crops and problem above. You review and edit it before sending.',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _focus,
          decoration: _deco('Optional focus, e.g. "recurring aphids on kales"'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _ai ? null : _draftWithAi,
          icon: _ai
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.auto_awesome_rounded, size: 18),
          label: Text(_ai ? 'Drafting…' : 'Draft with AI'),
        ),
        if (_aiError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_aiError!, style: const TextStyle(fontSize: 12, color: AdvisoryColors.red)),
          ),
      ]);

  Widget _adviceFields() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label('Title (optional)'),
        TextField(
          controller: _title,
          enabled: !_readOnly,
          maxLength: 200,
          decoration: _deco('e.g. Aphids on your kales'),
        ),
        _label('Main action *'),
        TextField(
          controller: _main,
          enabled: !_readOnly,
          maxLength: 300,
          decoration: _deco('e.g. Spray neem extract on the kales this evening'),
        ),
        _label('DO — one action per line'),
        TextField(
          controller: _do,
          enabled: !_readOnly,
          minLines: 2,
          maxLines: 6,
          decoration: _deco('Check the underside of leaves every 3 days\nRemove badly infested leaves'),
        ),
        const SizedBox(height: 10),
        _label('AVOID — one per line'),
        TextField(
          controller: _avoid,
          enabled: !_readOnly,
          minLines: 1,
          maxLines: 4,
          decoration: _deco('Spraying in the midday heat'),
        ),
        const SizedBox(height: 10),
        _label('WHY — one short sentence'),
        TextField(
          controller: _why,
          enabled: !_readOnly,
          minLines: 1,
          maxLines: 3,
          decoration: _deco('You reported aphids three times this month — they are building up.'),
        ),
      ]);

  Widget _actionBar() {
    final e = _e;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AdvisoryColors.border)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_isSent)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _notify,
              onChanged: (v) => setState(() => _notify = v ?? false),
              title: const Text('Notify the farmer again about this change', style: TextStyle(fontSize: 12.5)),
            ),
          Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 8, children: [
            if (!_isSent)
              OutlinedButton(
                onPressed: _busy ? null : () => _save(FarmerAdviceStatus.draft),
                child: const Text('Save draft'),
              ),
            FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AdvisoryColors.verified),
                onPressed: _busy ? null : () => _save(FarmerAdviceStatus.sent),
                icon: _busy
                    ? const SizedBox(
                        width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(_isSent ? Icons.save_rounded : Icons.send_rounded, size: 18),
                label: Text(_isSent
                    ? 'Save changes'
                    : (e == null && _targets.length > 1 ? 'Send to ${_targets.length}' : 'Send')),
              ),
          ]),
        ]),
      ),
    );
  }
}
