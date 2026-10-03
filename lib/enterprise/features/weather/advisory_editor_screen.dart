// lib/enterprise/features/weather/advisory_editor_screen.dart
//
// Create / edit / verify a weather advisory. Sections:
//   1. Target — crops, weather condition, station scope
//   2. AI assist — optional Gemini draft (kept for audit), always reviewed
//   3. Advice — MAIN / DO / AVOID / WHY
//   4. Soil & fertiliser actions — per nutrient, by Low / Moderate / High
//   5. Pests to check  6. Diseases to check — signs, what to do if found
//   7. Farmer preview — exactly what farmers will see
//   Verification + actions (save draft, publish/update, unpublish,
//   archive, restore, delete draft), audit history

import 'package:flutter/material.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_actions.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_actions_editor.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_conditions.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_widgets.dart';
import 'package:kilimomkononi/enterprise/features/weather/agronomic_advisory.dart';
import 'package:kilimomkononi/enterprise/features/weather/agronomic_advisory_service.dart';
import 'package:kilimomkononi/enterprise/features/weather/structured_advice.dart';
import 'package:kilimomkononi/services/nuasense_service.dart';

class AdvisoryEditorScreen extends StatefulWidget {
  final AgronomicAdvisory? existing;
  final String? presetCondition;
  final String? presetGatewayId;
  final String? presetStationName;
  final NuaSenseReading? reading;

  /// Admin test mode: new advisories are testOnly (never shown to farmers)
  /// and live advisories written by agronomists are read-only.
  final bool testMode;

  const AdvisoryEditorScreen({
    super.key,
    this.existing,
    this.presetCondition,
    this.presetGatewayId,
    this.presetStationName,
    this.reading,
    this.testMode = false,
  });

  @override
  State<AdvisoryEditorScreen> createState() => _AdvisoryEditorScreenState();
}

class _AdvisoryEditorScreenState extends State<AdvisoryEditorScreen> {
  final _mainCtrl = TextEditingController();
  final _doCtrl = TextEditingController();
  final _avoidCtrl = TextEditingController();
  final _whyCtrl = TextEditingController();

  late Set<String> _crops;
  late String _condition;
  String? _gatewayId;
  String? _stationName;
  String _source = 'manual';
  String? _aiDraft;
  AdviceActions _actions = AdviceActions.empty;

  bool _verified = false;
  // Editing already-published advice: re-notify farmers only if asked.
  bool _notifyFarmers = false;
  bool _aiBusy = false;
  bool _saving = false;
  bool _dirty = false;
  String _lastText = '';

  AgronomicAdvisory? get _existing => widget.existing;
  bool get _isPublished => _existing?.status == AdvisoryStatus.published;
  bool get _isArchived => _existing?.status == AdvisoryStatus.archived;
  bool get _testOnly => _existing?.testOnly ?? widget.testMode;
  // Test mode never touches live (agronomist-verified) advice.
  bool get _isLiveInTestMode =>
      widget.testMode && _existing != null && !_existing!.testOnly;
  bool get _readOnly => _isArchived || _isLiveInTestMode;

  @override
  void initState() {
    super.initState();
    final e = _existing;
    if (e != null) {
      _crops = e.crops.toSet();
      _condition = e.condition;
      _gatewayId = e.gatewayId;
      _stationName = e.stationName;
      _source = e.source;
      _aiDraft = e.aiDraft;
      _actions = e.actions;
      _fill(e.advice);
    } else {
      _crops = {kAllCrops};
      _condition = widget.presetCondition ?? 'general';
      _gatewayId = null; // default: all stations; agronomist can narrow it
      _stationName = null;
    }
    _lastText = _textSnapshot;
    for (final c in [_mainCtrl, _doCtrl, _avoidCtrl, _whyCtrl]) {
      c.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    for (final c in [_mainCtrl, _doCtrl, _avoidCtrl, _whyCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _textSnapshot => [
    _mainCtrl.text,
    _doCtrl.text,
    _avoidCtrl.text,
    _whyCtrl.text,
  ].join('\n---\n');

  // Controllers also notify on cursor moves — only react to real text edits.
  void _onTextChanged() {
    final now = _textSnapshot;
    if (now == _lastText) return;
    _lastText = now;
    _touched();
  }

  /// Any change to content or targeting invalidates a previous verification.
  void _touched() => setState(() {
    _dirty = true;
    _verified = false;
  });

  /// Close the editor. PopScope blocks pops while [_dirty], so clear it and
  /// pop after the rebuild.
  void _close([bool? result]) {
    setState(() => _dirty = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, result);
    });
  }

  void _fill(StructuredAdvice a) {
    _mainCtrl.text = a.main;
    _doCtrl.text = a.doList.join('\n');
    _avoidCtrl.text = a.avoidList.join('\n');
    _whyCtrl.text = a.why;
  }

  List<String> _lines(String s) => s
      .split('\n')
      .map((l) => l.trim().replaceFirst(RegExp(r'^[-•*]\s*'), ''))
      .where((l) => l.isNotEmpty)
      .toList();

  StructuredAdvice get _advice => StructuredAdvice(
    main: _mainCtrl.text.trim(),
    doList: _lines(_doCtrl.text),
    avoidList: _lines(_avoidCtrl.text),
    why: _whyCtrl.text.trim(),
  );

  List<String> get _cropList => _crops.contains(kAllCrops)
      ? [kAllCrops]
      : (kAdvisoryCrops.where(_crops.contains).toList());

  String get _autoTitle {
    final crops = _cropList.join(', ');
    return '${conditionFor(_condition).label} — $crops';
  }

  AdvisoryContent get _content => AdvisoryContent(
    title: _autoTitle,
    advice: _advice,
    crops: _cropList,
    condition: _condition,
    gatewayId: _gatewayId,
    stationName: _stationName,
    source: _source,
    aiDraft: _aiDraft,
    testOnly: _testOnly,
    actions: _actions,
  );

  String? _validate({required bool forPublish}) {
    if (_cropList.isEmpty) return 'Pick at least one crop.';
    if (_advice.main.isEmpty) return 'Write the main action.';
    if (_advice.main.length > 200) {
      return 'Keep the main action under 200 characters.';
    }
    if (_advice.doList.length > 10 || _advice.avoidList.length > 10) {
      return 'Keep DO and AVOID to 10 lines each.';
    }
    if ([..._advice.doList, ..._advice.avoidList].any((l) => l.length > 160)) {
      return 'Keep each DO / AVOID line under 160 characters.';
    }
    if (_advice.why.length > 600) {
      return 'Keep the WHY under 600 characters.';
    }
    if (forPublish &&
        _advice.doList.isEmpty &&
        _advice.avoidList.isEmpty &&
        _actions.isEmpty) {
      return 'Add at least one DO or AVOID line, or a soil / pest / disease '
          'action, before publishing.';
    }
    if (forPublish && !_verified) {
      return 'Tick the verification box to confirm you have reviewed this advice.';
    }
    return null;
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _generateAi() async {
    if (_advice.main.isNotEmpty || _advice.doList.isNotEmpty) {
      final ok = await _confirm(
        'Replace current text?',
        'The AI draft will replace what you have written so far.',
      );
      if (ok != true) return;
    }
    setState(() => _aiBusy = true);
    try {
      final r = await AgronomicAdvisoryService.generateAiDraft(
        crops: _cropList,
        conditionKey: _condition,
        reading: widget.reading,
      );
      if (!mounted) return;
      _fill(r.advice);
      setState(() {
        _source = 'ai_assisted';
        _aiDraft = r.raw;
        _actions = r.advice.actions;
      });
      _touched();
      _snack('AI draft added — review and edit every line before publishing.');
    } catch (e) {
      _snack('Could not generate a draft: $e', error: true);
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  Future<void> _save(
    AdvisoryStatus status,
    String action, {
    bool publish = false,
  }) async {
    final err = _validate(forPublish: publish);
    if (err != null) {
      _snack(err, error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await AgronomicAdvisoryService.save(
        id: _existing?.id,
        expectedVersion: _existing?.version,
        content: _content,
        status: status,
        action: action,
        notifyFarmers: _notifyFarmers,
      );
      if (!mounted) return;
      _snack(switch (action) {
        'published' when _testOnly => 'Published in TEST mode — admins only.',
        'republished' when _testOnly => 'Test advisory updated.',
        'published' => 'Verified and published to farmers.',
        'republished' when _notifyFarmers =>
          'Published advice updated — farmers will be notified.',
        'republished' => 'Published advice updated (no new notification).',
        _ => 'Draft saved.',
      });
      _close(true);
    } on AdvisoryConflictException catch (e) {
      _snack('$e', error: true);
    } catch (e) {
      _snack('Save failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _statusChange(
    AdvisoryStatus to,
    String action,
    String confirmText,
  ) async {
    final e = _existing;
    if (e == null) return;
    final ok = await _confirm('Are you sure?', confirmText);
    if (ok != true) return;
    setState(() => _saving = true);
    try {
      await AgronomicAdvisoryService.changeStatus(e, to, action);
      if (!mounted) return;
      _close(true);
    } catch (err) {
      _snack('Failed: $err', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteDraft() async {
    final e = _existing;
    if (e == null) return;
    final ok = await _confirm(
      'Delete draft?',
      'This draft was never published and will be permanently deleted.',
    );
    if (ok != true) return;
    try {
      await AgronomicAdvisoryService.deleteDraft(e.id);
      if (mounted) _close(true);
    } catch (err) {
      _snack('Delete failed: $err', error: true);
    }
  }

  Future<bool?> _confirm(String title, String body) => showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Continue'),
        ),
      ],
    ),
  );

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    // Replace any visible message so validation feedback is immediate.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: error ? AdvisoryColors.red : AdvisoryColors.midGreen,
        ),
      );
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final e = _existing;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirm(
          'Discard changes?',
          'Your unsaved edits will be lost.',
        );
        if (leave == true && mounted) _close();
      },
      child: Scaffold(
        backgroundColor: AdvisoryColors.pageBg,
        appBar: AppBar(
          backgroundColor: AdvisoryColors.darkGreen,
          foregroundColor: Colors.white,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e == null ? 'New advisory' : 'Edit advisory',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                e == null
                    ? 'Draft, verify, publish'
                    : 'Version ${e.version} · ${e.status.name}',
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
            ],
          ),
          actions: [if (e != null && !_isLiveInTestMode) _overflowMenu(e)],
        ),
        body: AbsorbPointer(
          absorbing: _saving,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            children: [
              if (_testOnly)
                _banner(
                  Icons.science_outlined,
                  'TEST MODE — this advisory is visible to admins only and never '
                  'reaches farmers.',
                  const Color(0xFFF3E5F5),
                ),
              if (_isLiveInTestMode)
                _banner(
                  Icons.lock_outline_rounded,
                  'Live advisory verified by a Field Agronomist — read-only in test mode.',
                  Colors.grey.shade200,
                ),
              if (_isArchived) _archivedBanner(),
              _section(
                '1 · Who and when',
                Icons.track_changes_rounded,
                _targetSection(),
              ),
              _section(
                '2 · AI assist (optional)',
                Icons.auto_awesome_rounded,
                _aiSection(),
              ),
              _section('3 · Advice', Icons.edit_note_rounded, _adviceSection()),
              for (final (i, s) in AdviceSection.values.indexed)
                _section(
                  '${4 + i} · ${switch (s) {
                    AdviceSection.soil => 'Soil & fertiliser actions',
                    AdviceSection.pests => 'Pests to check',
                    AdviceSection.diseases => 'Diseases to check',
                  }}',
                  s.icon,
                  AdvisoryActionsSection(
                    section: s,
                    value: _actions,
                    crops: _cropList,
                    readOnly: _readOnly,
                    onChanged: (v) {
                      setState(() => _actions = v);
                      _touched();
                    },
                  ),
                ),
              _section(
                '7 · What farmers will see',
                Icons.visibility_outlined,
                VerifiedAdvisoryCard(
                  advice: _advice,
                  crops: _cropList,
                  condition: _condition,
                  stationScoped: _gatewayId != null,
                  preview: true,
                  testOnly: _testOnly,
                  actions: _actions,
                ),
              ),
              if (!_readOnly) _verificationBox(),
              if (!_readOnly && _isPublished) _notifyBox(),
              if (e != null)
                _section(
                  'Audit history',
                  Icons.history_rounded,
                  _AuditHistory(advisoryId: e.id),
                ),
            ],
          ),
        ),
        bottomNavigationBar: _readOnly ? null : _actionBar(),
      ),
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
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AdvisoryColors.midGreen),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6, top: 2),
    child: Text(
      t,
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: Colors.black54,
      ),
    ),
  );

  Widget _targetSection() {
    final stationChoiceName = widget.presetStationName ?? _stationName;
    final stationChoiceId = widget.presetGatewayId ?? _gatewayId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Crops'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [_cropChip(kAllCrops), ...kAdvisoryCrops.map(_cropChip)],
        ),
        const SizedBox(height: 14),
        _label('Show when the station reads'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: kAdvisoryConditions.map((c) {
            final sel = _condition == c.key;
            return ChoiceChip(
              avatar: Icon(
                c.icon,
                size: 16,
                color: sel ? Colors.white : AdvisoryColors.midGreen,
              ),
              label: Text(c.label),
              selected: sel,
              showCheckmark: false,
              selectedColor: AdvisoryColors.midGreen,
              labelStyle: TextStyle(
                fontSize: 12,
                color: sel ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              tooltip: c.description,
              onSelected: (_) {
                setState(() => _condition = c.key);
                _touched();
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 4),
        Text(
          conditionFor(_condition).description,
          style: const TextStyle(fontSize: 11, color: Colors.black45),
        ),
        const SizedBox(height: 14),
        _label('Stations'),
        SegmentedButton<bool>(
          segments: [
            const ButtonSegment(
              value: false,
              icon: Icon(Icons.public_rounded, size: 16),
              label: Text('All stations'),
            ),
            ButtonSegment(
              value: true,
              enabled: stationChoiceId != null,
              icon: const Icon(Icons.sensors_rounded, size: 16),
              label: Text(
                stationChoiceName ??
                    stationChoiceId ??
                    'Pick a station in the panel',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          selected: {_gatewayId != null},
          onSelectionChanged: (s) {
            final scoped = s.first;
            setState(() {
              _gatewayId = scoped ? stationChoiceId : null;
              _stationName = scoped ? stationChoiceName : null;
            });
            _touched();
          },
        ),
      ],
    );
  }

  Widget _cropChip(String crop) {
    final sel = _crops.contains(crop);
    return FilterChip(
      label: Text(crop),
      selected: sel,
      selectedColor: AdvisoryColors.verifiedBg,
      checkmarkColor: AdvisoryColors.verified,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
        color: sel ? AdvisoryColors.verified : Colors.black87,
      ),
      onSelected: (on) {
        setState(() {
          if (crop == kAllCrops) {
            _crops = on ? {kAllCrops} : {};
          } else {
            _crops.remove(kAllCrops);
            on ? _crops.add(crop) : _crops.remove(crop);
          }
        });
        _touched();
      },
    );
  }

  Widget _aiSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Let AI draft advice for the crops and condition above, then check and '
        'correct every line. Farmers never see AI drafts until you publish.',
        style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
      ),
      const SizedBox(height: 10),
      // Wrap, not Row: button + badge don't fit side by side on small phones.
      Wrap(
        spacing: 10,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: _aiBusy || _readOnly ? null : _generateAi,
            icon: _aiBusy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_rounded, size: 16),
            label: Text(_aiBusy ? 'Drafting…' : 'Generate AI draft'),
          ),
          if (_source == 'ai_assisted')
            const Pill(
              'AI-assisted',
              icon: Icons.auto_awesome_rounded,
              fg: AdvisoryColors.amber,
              bg: AdvisoryColors.lightAmber,
            ),
        ],
      ),
      if (widget.reading != null && widget.reading!.isProvisioned) ...[
        const SizedBox(height: 6),
        const Text(
          'Uses the live reading from the station selected in the panel.',
          style: TextStyle(fontSize: 11, color: Colors.black45),
        ),
      ],
    ],
  );

  Widget _adviceSection() {
    InputDecoration deco(String hint) => InputDecoration(
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFFAFBFA),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Main action *'),
        TextField(
          controller: _mainCtrl,
          enabled: !_readOnly,
          maxLength: 200,
          decoration: deco('e.g. Hold fungicide spraying until leaves dry'),
        ),
        _label('DO — one action per line'),
        TextField(
          controller: _doCtrl,
          enabled: !_readOnly,
          minLines: 2,
          maxLines: 5,
          decoration: deco(
            'Scout lower leaves for blight\nOpen furrows to drain water',
          ),
        ),
        const SizedBox(height: 10),
        _label('AVOID — one per line'),
        TextField(
          controller: _avoidCtrl,
          enabled: !_readOnly,
          minLines: 1,
          maxLines: 4,
          decoration: deco('Top-dressing with urea before rain'),
        ),
        const SizedBox(height: 10),
        _label('WHY — one short sentence'),
        TextField(
          controller: _whyCtrl,
          enabled: !_readOnly,
          minLines: 1,
          maxLines: 3,
          decoration: deco('Wet leaves spread fungal spores quickly.'),
        ),
      ],
    );
  }

  Widget _banner(IconData icon, String text, Color bg) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(icon, color: Colors.black54),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5))),
      ],
    ),
  );

  // Material (not a coloured Container) so the tile's ink ripple is visible.
  Widget _verificationBox() => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Material(
      color: _verified ? AdvisoryColors.verifiedBg : AdvisoryColors.lightAmber,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _verified
              ? AdvisoryColors.verifiedBorder
              : const Color(0xFFFFCC80),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: CheckboxListTile(
        value: _verified,
        activeColor: AdvisoryColors.verified,
        controlAffinity: ListTileControlAffinity.leading,
        onChanged: (v) => setState(() => _verified = v ?? false),
        title: const Text(
          'I have reviewed and verified this advice',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        subtitle: const Text(
          'It is agronomically sound for the selected crops and weather condition. '
          'Your name will be shown to farmers as the verifying agronomist.',
          style: TextStyle(fontSize: 11.5, height: 1.35),
        ),
      ),
    ),
  );

  Widget _notifyBox() => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AdvisoryColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: CheckboxListTile(
        value: _notifyFarmers,
        activeColor: AdvisoryColors.verified,
        controlAffinity: ListTileControlAffinity.leading,
        onChanged: (v) => setState(() => _notifyFarmers = v ?? false),
        title: const Text(
          'Notify farmers about this change',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        subtitle: const Text(
          'Leave off for small corrections. When on, farmers get the updated '
          'advice again — straight away for "Any conditions", otherwise the '
          'next time the condition occurs at their station.',
          style: TextStyle(fontSize: 11.5, height: 1.35),
        ),
      ),
    ),
  );

  Widget _archivedBanner() => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.grey.shade200,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Row(
      children: [
        Icon(Icons.inventory_2_outlined, color: Colors.black54),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Archived — read only. Restore it to draft (menu ⋮) to edit.',
            style: TextStyle(fontSize: 12.5),
          ),
        ),
      ],
    ),
  );

  Widget _actionBar() {
    final publishLabel = _isPublished ? 'Update published' : 'Verify & publish';
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AdvisoryColors.border)),
        ),
        child: Row(
          children: [
            if (!_isPublished)
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () => _save(
                          AdvisoryStatus.draft,
                          _existing == null ? 'created' : 'edited',
                        ),
                  child: const Text('Save draft'),
                ),
              ),
            if (!_isPublished) const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AdvisoryColors.verified,
                ),
                onPressed: _saving
                    ? null
                    : () => _save(
                        AdvisoryStatus.published,
                        _isPublished ? 'republished' : 'published',
                        publish: true,
                      ),
                icon: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.verified_rounded, size: 18),
                label: Text(publishLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _overflowMenu(AgronomicAdvisory e) => PopupMenuButton<String>(
    onSelected: (v) {
      switch (v) {
        case 'unpublish':
          _statusChange(
            AdvisoryStatus.draft,
            'unpublished',
            'Farmers will stop seeing this advice. It moves back to drafts.',
          );
        case 'archive':
          _statusChange(
            AdvisoryStatus.archived,
            'archived',
            'Archived advice is hidden from farmers and kept for the record.',
          );
        case 'restore':
          _statusChange(
            AdvisoryStatus.draft,
            'restored',
            'This advice moves back to drafts so it can be edited and re-published.',
          );
        case 'delete':
          _deleteDraft();
      }
    },
    itemBuilder: (_) => [
      if (e.status == AdvisoryStatus.published)
        const PopupMenuItem(value: 'unpublish', child: Text('Unpublish')),
      if (e.status != AdvisoryStatus.archived)
        const PopupMenuItem(value: 'archive', child: Text('Archive')),
      if (e.status == AdvisoryStatus.archived)
        const PopupMenuItem(value: 'restore', child: Text('Restore to draft')),
      if (e.status == AdvisoryStatus.draft && !e.wasEverPublished)
        const PopupMenuItem(
          value: 'delete',
          child: Text(
            'Delete draft',
            style: TextStyle(color: AdvisoryColors.red),
          ),
        ),
    ],
  );
}

// ── Audit trail ──────────────────────────────────────────────────────────────

class _AuditHistory extends StatelessWidget {
  final String advisoryId;
  const _AuditHistory({required this.advisoryId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdvisoryHistoryEntry>>(
      stream: AgronomicAdvisoryService.history(advisoryId),
      builder: (context, snap) {
        if (snap.hasError) {
          return Text(
            'Could not load history: ${snap.error}',
            style: const TextStyle(fontSize: 12, color: AdvisoryColors.red),
          );
        }
        if (!snap.hasData) {
          return const LinearProgressIndicator(minHeight: 2);
        }
        final entries = snap.data!;
        if (entries.isEmpty) {
          return const Text('No history yet.', style: TextStyle(fontSize: 12));
        }
        return Column(
          children: entries
              .map(
                (h) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: AdvisoryColors.verifiedBg,
                    child: Text(
                      'v${h.version}',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: AdvisoryColors.verified,
                      ),
                    ),
                  ),
                  title: Text(
                    h.actionLabel,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    '${h.byName} · ${formatAdvisoryDate(h.at)}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                  onTap: () => _showSnapshot(context, h),
                ),
              )
              .toList(),
        );
      },
    );
  }

  void _showSnapshot(BuildContext context, AdvisoryHistoryEntry h) {
    final s = h.snapshot;
    List<String> list(dynamic v) =>
        (v as List?)?.map((e) => '$e').toList() ?? const [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'v${h.version} · ${h.actionLabel}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            Text(
              '${h.byName} · ${formatAdvisoryDate(h.at)} · status: ${h.status}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            VerifiedAdvisoryCard(
              advice: StructuredAdvice(
                main: '${s['main'] ?? ''}',
                doList: list(s['doList']),
                avoidList: list(s['avoidList']),
                why: '${s['why'] ?? ''}',
              ),
              crops: list(s['crops']),
              condition: '${s['condition'] ?? 'general'}',
              stationScoped: s['gatewayId'] != null,
              actions: AdviceActions.fromDoc(Map<String, dynamic>.from(s)),
              verifierName: h.byName,
              verifiedAt: h.at,
            ),
            if ((s['aiDraft'] as String?)?.isNotEmpty ?? false) ...[
              const SizedBox(height: 14),
              const Text(
                'Original AI draft',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AdvisoryColors.lightAmber,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${s['aiDraft']}',
                  style: const TextStyle(fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
