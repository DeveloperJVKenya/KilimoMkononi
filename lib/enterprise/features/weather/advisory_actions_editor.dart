// lib/enterprise/features/weather/advisory_actions_editor.dart
//
// Editor pieces for an advisory's actionable content (advisory_actions.dart),
// used by AdvisoryEditorScreen:
//   • Soil & fertiliser — per nutrient and crop growth stage(s): a general
//     action plus optional Low / Moderate / High actions, each with product,
//     a rate (amount + unit per acre / hectare / plant, scaled to each
//     farmer's plot) and how / when. The farmer's level is never required.
//   • Pests / Diseases to check — name (from the crop catalogue, or typed),
//     signs to look for, what to do if found, product and rate.

import 'package:flutter/material.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_actions.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_conditions.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_widgets.dart';
import 'package:kilimomkononi/services/nutrient_levels.dart';
import 'package:kilimomkononi/services/pest_disease_catalog.dart';

const kMaxSoilActions = 20;
const kMaxChecks = 10;

/// The list for one [section] of [value], with add / edit / remove.
class AdvisoryActionsSection extends StatelessWidget {
  final AdviceSection section;
  final AdviceActions value;
  final List<String> crops;
  final bool readOnly;
  final ValueChanged<AdviceActions> onChanged;

  const AdvisoryActionsSection({
    super.key,
    required this.section,
    required this.value,
    required this.crops,
    required this.readOnly,
    required this.onChanged,
  });

  List<String> get _catalogCrops =>
      crops.contains(kAllCrops) ? const [] : crops;

  Future<void> _editSoil(BuildContext context, [int? index]) async {
    final current = index == null ? null : value.soil[index];
    // One action per nutrient + stage(s); the same nutrient can repeat for
    // other stages.
    final used = value.soil.map((s) => s.key).toSet()..remove(current?.key);
    final r = await showModalBottomSheet<SoilAction>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SoilActionSheet(initial: current, usedKeys: used, crops: crops),
    );
    if (r == null) return;
    final list = [...value.soil];
    index == null ? list.add(r) : list[index] = r;
    onChanged(AdviceActions(soil: list, pests: value.pests, diseases: value.diseases));
  }

  Future<void> _editCheck(BuildContext context, [int? index]) async {
    final pest = section == AdviceSection.pests;
    final list = [...(pest ? value.pests : value.diseases)];
    final r = await showModalBottomSheet<CropCheck>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CheckSheet(
        section: section,
        initial: index == null ? null : list[index],
        suggestions: pest ? pestsForCrops(_catalogCrops) : diseasesForCrops(_catalogCrops),
      ),
    );
    if (r == null) return;
    index == null ? list.add(r) : list[index] = r;
    onChanged(AdviceActions(
      soil: value.soil,
      pests: pest ? list : value.pests,
      diseases: pest ? value.diseases : list,
    ));
  }

  void _remove(int index) {
    switch (section) {
      case AdviceSection.soil:
        onChanged(AdviceActions(
          soil: [...value.soil]..removeAt(index),
          pests: value.pests,
          diseases: value.diseases,
        ));
      case AdviceSection.pests:
        onChanged(AdviceActions(
          soil: value.soil,
          pests: [...value.pests]..removeAt(index),
          diseases: value.diseases,
        ));
      case AdviceSection.diseases:
        onChanged(AdviceActions(
          soil: value.soil,
          pests: value.pests,
          diseases: [...value.diseases]..removeAt(index),
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final soil = section == AdviceSection.soil;
    final count = value.countFor(section);
    final max = soil ? kMaxSoilActions : kMaxChecks;
    final hint = switch (section) {
      AdviceSection.soil =>
        'Fertiliser / soil decisions for these conditions, by crop stage. Give '
            'the action for each soil level you can — farmers who haven\'t tested '
            'use the general action or pick their level. Rates per acre or '
            'hectare are worked out for each farmer\'s plot size.',
      AdviceSection.pests =>
        'Pests farmers should scout for in these conditions, and what to do if '
            'they find them. Farmers can confirm, identify (photo / guide) and log.',
      AdviceSection.diseases =>
        'Diseases to look for in these conditions, and what to do if found.',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(hint, style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.4)),
        const SizedBox(height: 10),
        for (var i = 0; i < count; i++)
          _ItemTile(
            color: section.color,
            icon: section.icon,
            title: soil
                ? '${value.soil[i].label} · ${value.soil[i].stageLabel}'
                : (section == AdviceSection.pests ? value.pests : value.diseases)[i].name,
            lines: soil ? _soilLines(value.soil[i]) : _checkLines((section == AdviceSection.pests ? value.pests : value.diseases)[i]),
            onEdit: readOnly ? null : () => soil ? _editSoil(context, i) : _editCheck(context, i),
            onRemove: readOnly ? null : () => _remove(i),
          ),
        if (!readOnly && count < max)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: section.color,
              side: BorderSide(color: section.color.withValues(alpha: 0.5)),
            ),
            onPressed: () => soil ? _editSoil(context) : _editCheck(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(switch (section) {
              AdviceSection.soil => 'Add soil / fertiliser action',
              AdviceSection.pests => 'Add pest to check',
              AdviceSection.diseases => 'Add disease to check',
            }),
          ),
      ],
    );
  }

  static List<String> _soilLines(SoilAction a) => [
    if (!a.general.isEmpty) 'Any level: ${a.general.summary}',
    for (final b in NutrientBand.values)
      if (!a.forBand(b).isEmpty) '${b.label}: ${a.forBand(b).summary}',
  ];

  static List<String> _checkLines(CropCheck c) => [
    if (c.signs.isNotEmpty) 'Look for: ${c.signs}',
    if (c.ifFound.isNotEmpty) 'If found: ${c.ifFound}',
    if (c.product.isNotEmpty || c.rate.isNotEmpty)
      [c.product, c.rate].where((s) => s.isNotEmpty).join(' · '),
  ];
}

class _ItemTile extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final List<String> lines;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;

  const _ItemTile({
    required this.color,
    required this.icon,
    required this.title,
    required this.lines,
    this.onEdit,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              for (final l in lines)
                Text(l, style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.35)),
            ],
          ),
        ),
        if (onEdit != null)
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_rounded, size: 18),
            onPressed: onEdit,
          ),
        if (onRemove != null)
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Remove',
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: onRemove,
          ),
      ],
    ),
  );
}

InputDecoration _deco(String label, [String? hint]) => InputDecoration(
  labelText: label,
  hintText: hint,
  isDense: true,
  filled: true,
  fillColor: const Color(0xFFFAFBFA),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
);

Widget _sheetFrame(BuildContext context, String title, List<Widget> children, VoidCallback onSave) =>
    Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            ...children,
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AdvisoryColors.verified),
                    onPressed: onSave,
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

/// Controllers for one band's action / product / rate / method.
class _BandCtrls {
  final action = TextEditingController();
  final product = TextEditingController();
  final amount = TextEditingController();
  final rate = TextEditingController();
  final method = TextEditingController();
  String unit;
  String per;

  _BandCtrls(BandAction b)
      : unit = b.hasStructuredRate && kRateUnits.contains(b.unit) ? b.unit : 'kg',
        per = b.hasStructuredRate && kRatePers.containsKey(b.per) ? b.per : 'acre' {
    action.text = b.action;
    product.text = b.product;
    if (b.hasStructuredRate) {
      final a = b.amount!;
      amount.text = a == a.roundToDouble() ? a.toStringAsFixed(0) : '$a';
    } else {
      rate.text = b.rate;
    }
    method.text = b.method;
  }

  double? get _amount => double.tryParse(amount.text.trim().replaceAll(',', '.'));

  /// Typed something in Amount that isn't a positive number.
  bool get badAmount =>
      amount.text.trim().isNotEmpty && (_amount == null || _amount! <= 0);

  BandAction get value {
    final a = _amount;
    final structured = a != null && a > 0;
    return BandAction(
      action: action.text.trim(),
      product: product.text.trim(),
      rate: structured ? '' : rate.text.trim(),
      method: method.text.trim(),
      amount: structured ? a : null,
      unit: structured ? unit : '',
      per: structured ? per : '',
    );
  }

  void dispose() {
    for (final c in [action, product, amount, rate, method]) {
      c.dispose();
    }
  }
}

class _SoilActionSheet extends StatefulWidget {
  final SoilAction? initial;
  final Set<String> usedKeys;
  final List<String> crops;
  const _SoilActionSheet({this.initial, required this.usedKeys, required this.crops});

  @override
  State<_SoilActionSheet> createState() => _SoilActionSheetState();
}

class _SoilActionSheetState extends State<_SoilActionSheet> {
  late String _nutrient = widget.initial?.nutrient ?? 'N';
  late final Set<String> _stages = {...?widget.initial?.stages};
  final _stageCtrl = TextEditingController();
  late final _general = _BandCtrls(widget.initial?.general ?? const BandAction());
  late final _bands = {
    for (final b in NutrientBand.values)
      b: _BandCtrls(widget.initial?.forBand(b) ?? const BandAction()),
  };
  String? _error;

  @override
  void dispose() {
    _stageCtrl.dispose();
    _general.dispose();
    for (final c in _bands.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Stage choices per crop of the advisory (generic stages for 'All
  /// crops' or a typed crop without its own list).
  Map<String, List<String>> get _stageGroups {
    final crops = widget.crops.where((c) => c != kAllCrops).toList();
    if (crops.isEmpty) return {'Any crop': kGenericCropStages};
    return {for (final c in crops) c: stagesForCrop(c)};
  }

  void _addTypedStage() {
    final t = _stageCtrl.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _stages.add(t);
      _stageCtrl.clear();
    });
  }

  Widget _stagePicker() {
    final known = {for (final l in _stageGroups.values) ...l};
    final typed = _stages.where((s) => !known.contains(s)).toList();
    Widget chip(String s) => FilterChip(
          label: Text(s, style: const TextStyle(fontSize: 12)),
          selected: _stages.contains(s),
          visualDensity: VisualDensity.compact,
          selectedColor: AdvisoryColors.verifiedBg,
          checkmarkColor: AdvisoryColors.verified,
          onSelected: (on) => setState(() => on ? _stages.add(s) : _stages.remove(s)),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Crop growth stage',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
      const Text(
        'Farmers see it for their crop\'s stage (picked from their field record). '
        'Leave all off for any stage.',
        style: TextStyle(fontSize: 11.5, color: Colors.black54),
      ),
      const SizedBox(height: 6),
      ChoiceChip(
        label: const Text('Any stage', style: TextStyle(fontSize: 12)),
        selected: _stages.isEmpty,
        visualDensity: VisualDensity.compact,
        onSelected: (_) => setState(_stages.clear),
      ),
      for (final g in _stageGroups.entries) ...[
        const SizedBox(height: 6),
        Text(g.key, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.black54)),
        const SizedBox(height: 4),
        Wrap(spacing: 6, runSpacing: 6, children: [for (final st in g.value) chip(st)]),
      ],
      if (typed.isNotEmpty) ...[
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [for (final st in typed) chip(st)]),
      ],
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: TextField(
            controller: _stageCtrl,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => _addTypedStage(),
            decoration: _deco('Other stage', 'Type a stage, e.g. Second top-dressing'),
          ),
        ),
        const SizedBox(width: 6),
        IconButton.filledTonal(
          tooltip: 'Add stage',
          onPressed: _addTypedStage,
          icon: const Icon(Icons.add_rounded),
        ),
      ]),
    ]);
  }

  Widget _rateRow(_BandCtrls c) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: c.amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: _deco('Amount', '50'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  initialValue: c.unit,
                  isExpanded: true,
                  decoration: _deco('Unit'),
                  items: [for (final u in kRateUnits) DropdownMenuItem(value: u, child: Text(u, overflow: TextOverflow.ellipsis))],
                  onChanged: (v) => setState(() => c.unit = v ?? c.unit),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 4,
                child: DropdownButtonFormField<String>(
                  initialValue: c.per,
                  isExpanded: true,
                  decoration: _deco('Per'),
                  items: [
                    for (final e in kRatePers.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() => c.per = v ?? c.per),
                ),
              ),
            ],
          ),
          if (c.badAmount)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Amount must be a number above 0, e.g. 50 or 2.5',
                  style: TextStyle(fontSize: 11.5, color: AdvisoryColors.red)),
            )
          else if (c.value.scalesWithArea)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'A farmer with ½ acre sees: ${c.value.amountLabelFor(0.5)}',
                style: const TextStyle(fontSize: 11.5, color: AdvisoryColors.midGreen, fontWeight: FontWeight.w600),
              ),
            ),
          if (c.amount.text.trim().isEmpty) ...[
            const SizedBox(height: 8),
            TextField(controller: c.rate, decoration: _deco('Or describe the rate', 'e.g. a handful per plant')),
          ],
        ],
      );

  Widget _band(String title, String subtitle, _BandCtrls c, Color color) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
        Text(subtitle, style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
        const SizedBox(height: 8),
        TextField(controller: c.action, maxLength: 160, decoration: _deco('Action', 'e.g. Top-dress with CAN')),
        TextField(controller: c.product, decoration: _deco('Product', 'CAN 26%')),
        const SizedBox(height: 8),
        _rateRow(c),
        const SizedBox(height: 8),
        TextField(controller: c.method, decoration: _deco('How / when', 'Band-place after rain, 5 cm from stems')),
      ],
    ),
  );

  void _save() {
    _addTypedStage();
    final all = [_general, ..._bands.values];
    if (all.any((c) => c.badAmount)) {
      setState(() => _error = 'Fix the amount — it must be a number above 0.');
      return;
    }
    final a = SoilAction(
      nutrient: _nutrient,
      stages: _stages.toList(),
      general: _general.value,
      low: _bands[NutrientBand.low]!.value,
      moderate: _bands[NutrientBand.moderate]!.value,
      high: _bands[NutrientBand.high]!.value,
    );
    if (a.isEmpty) {
      setState(() => _error = 'Fill in at least one action.');
      return;
    }
    if (widget.usedKeys.contains(a.key)) {
      setState(() => _error =
          'There is already a ${a.label} action for ${a.stageLabel.toLowerCase()}. '
          'Edit that one, or pick other stages.');
      return;
    }
    Navigator.pop(context, a);
  }

  @override
  Widget build(BuildContext context) {
    final measurable = const {'N', 'P', 'K'}.contains(_nutrient);
    return _sheetFrame(context, 'Soil / fertiliser action', [
      DropdownButtonFormField<String>(
        initialValue: _nutrient,
        decoration: _deco('Nutrient / topic'),
        items: [
          for (final e in kSoilNutrients.entries)
            DropdownMenuItem(value: e.key, child: Text(e.value)),
        ],
        onChanged: (v) => setState(() => _nutrient = v ?? _nutrient),
      ),
      const SizedBox(height: 12),
      _stagePicker(),
      const SizedBox(height: 14),
      _band('Any level / not tested', 'Shown to farmers who don\'t know their level', _general, Colors.black54),
      if (measurable) ...[
        const Text(
          'By soil test level (optional — leave a level blank if it needs no action):',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        _band('Low', 'Below the crop\'s target', _bands[NutrientBand.low]!, const Color(0xFFC62828)),
        _band('Moderate', 'Around the target (±10%)', _bands[NutrientBand.moderate]!, AdvisoryColors.midGreen),
        _band('High', 'Above the target', _bands[NutrientBand.high]!, const Color(0xFFEF6C00)),
      ],
      if (_error != null) Text(_error!, style: const TextStyle(color: AdvisoryColors.red, fontWeight: FontWeight.w700)),
    ], _save);
  }
}

class _CheckSheet extends StatefulWidget {
  final AdviceSection section;
  final CropCheck? initial;
  final List<String> suggestions;
  const _CheckSheet({required this.section, this.initial, required this.suggestions});

  @override
  State<_CheckSheet> createState() => _CheckSheetState();
}

class _CheckSheetState extends State<_CheckSheet> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _signs = TextEditingController(text: widget.initial?.signs ?? '');
  late final _ifFound = TextEditingController(text: widget.initial?.ifFound ?? '');
  late final _product = TextEditingController(text: widget.initial?.product ?? '');
  late final _rate = TextEditingController(text: widget.initial?.rate ?? '');
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _signs, _ifFound, _product, _rate]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Name the ${widget.section == AdviceSection.pests ? 'pest' : 'disease'}.');
      return;
    }
    Navigator.pop(
      context,
      CropCheck(
        name: _name.text.trim(),
        signs: _signs.text.trim(),
        ifFound: _ifFound.text.trim(),
        product: _product.text.trim(),
        rate: _rate.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pest = widget.section == AdviceSection.pests;
    return _sheetFrame(context, pest ? 'Pest to check' : 'Disease to check', [
      Autocomplete<String>(
        initialValue: TextEditingValue(text: _name.text),
        optionsBuilder: (v) {
          final q = v.text.trim().toLowerCase();
          return q.isEmpty
              ? widget.suggestions
              : widget.suggestions.where((s) => s.toLowerCase().contains(q));
        },
        onSelected: (v) => _name.text = v,
        fieldViewBuilder: (context, ctrl, focus, onSubmit) {
          return TextField(
            controller: ctrl,
            focusNode: focus,
            onChanged: (t) => _name.text = t,
            decoration: _deco(
              pest ? 'Pest' : 'Disease',
              pest ? 'Pick from the list or type' : 'Pick from the list or type',
            ),
          );
        },
      ),
      if (widget.suggestions.isNotEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            'Names from the library open the matching guide for farmers.',
            style: TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ),
      const SizedBox(height: 10),
      TextField(controller: _signs, maxLines: 2, maxLength: 200, decoration: _deco('Signs to look for', 'Curled leaves, sticky honeydew under leaves')),
      TextField(controller: _ifFound, maxLines: 2, maxLength: 200, decoration: _deco('What to do if found', 'Spray neem extract on the undersides')),
      Row(
        children: [
          Expanded(child: TextField(controller: _product, decoration: _deco('Product (optional)', 'Neem oil'))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: _rate, decoration: _deco('Rate (optional)', '30 ml / 20 L'))),
        ],
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_error!, style: const TextStyle(color: AdvisoryColors.red, fontWeight: FontWeight.w700)),
        ),
    ], _save);
  }
}
