// lib/enterprise/features/weather/advisory_ai_comparison_screen.dart
//
// Admin-only screen: lists all published advisories that have an AI-generated
// parallel draft, lets admins compare them side-by-side, add a note, and mark
// as reviewed.  Collection: advisoryAiComparisons/{advisoryId} (admin-only).
//
// All stream subscriptions go through Riverpod providers so they are properly
// cancelled on unmount (autoDispose) and the detail screen receives live
// Firestore updates when another admin acts on the same document.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_actions.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_ai_comparison.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_ai_comparison_providers.dart';
import 'package:kilimomkononi/enterprise/features/weather/agronomic_advisory_service.dart';
import 'package:kilimomkononi/utils/friendly_error.dart';

// ── Brand / accent constants ──────────────────────────────────────────────────
// These are product-specific accents (not in the M3 seed palette), so they
// stay as constants.  All surface / text colors come from the theme instead.
const _kAppBar = Color.fromARGB(255, 3, 39, 4);
const _kAi = Color(0xFF6A1B9A);
const _kAgronomist = Color(0xFF1B5E20);
const _kPendingBg = Color(0xFFFFF9C4);
const _kPendingFg = Color(0xFFF57F17);

// ── List screen ───────────────────────────────────────────────────────────────

class AdvisoryAiComparisonScreen extends ConsumerWidget {
  const AdvisoryAiComparisonScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final stream = ref.watch(comparisonsProvider);

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: _kAppBar,
        foregroundColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Advisory AI Review',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            Text(
              'Agronomist vs. AI — spot missed critical info',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: stream.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              friendlyError(e, 'Could not load comparisons'),
              style: TextStyle(color: cs.error),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (items) {
          if (items.isEmpty) return _EmptyState(cs: cs);
          final pending = items.where((e) => !e.adminReviewed).length;
          return Column(
            children: [
              if (pending > 0) _PendingBanner(count: pending),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final item = items[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ComparisonTile(
                        item: item,
                        cs: cs,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _ComparisonDetailScreen(
                              advisoryId: item.advisoryId,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final ColorScheme cs;
  const _EmptyState({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.compare_arrows_rounded, size: 52, color: cs.outlineVariant),
          const SizedBox(height: 14),
          Text(
            'No comparisons yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Generated automatically when an agronomist\npublishes an advisory.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: cs.outlineVariant),
          ),
        ],
      ),
    );
  }
}

// ── Pending banner ────────────────────────────────────────────────────────────

class _PendingBanner extends StatelessWidget {
  final int count;
  const _PendingBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _kPendingBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(children: [
        const Icon(Icons.pending_actions_rounded, size: 16, color: _kPendingFg),
        const SizedBox(width: 8),
        Text(
          '$count pending review${count == 1 ? '' : 's'}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _kPendingFg,
          ),
        ),
      ]),
    );
  }
}

// ── List tile ─────────────────────────────────────────────────────────────────

class _ComparisonTile extends StatelessWidget {
  final AdvisoryAiComparison item;
  final ColorScheme cs;
  final VoidCallback onTap;
  const _ComparisonTile(
      {required this.item, required this.cs, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final reviewed = item.adminReviewed;
    final iconBg =
        reviewed ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0);
    final iconFg =
        reviewed ? const Color(0xFF2E7D32) : const Color(0xFFE65100);
    final badgeFg = iconFg;
    final badgeBg = iconBg;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  reviewed
                      ? Icons.check_circle_outline_rounded
                      : Icons.pending_actions_rounded,
                  color: iconFg,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.conditionLabel.isEmpty
                          ? item.condition
                          : item.conditionLabel,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.crops.take(3).join(', ') +
                          (item.crops.length > 3
                              ? ' +${item.crops.length - 3} more'
                              : ''),
                      style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        'by ${item.agronomistName}',
                        if (item.generatedAt != null)
                          DateFormat('d MMM y').format(item.generatedAt!),
                      ].join(' · '),
                      style: TextStyle(fontSize: 11, color: cs.outline),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      reviewed ? 'Reviewed' : 'Pending',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: badgeFg,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(Icons.chevron_right_rounded, color: cs.outlineVariant),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Detail / comparison screen ────────────────────────────────────────────────

/// Receives only the [advisoryId] so it can subscribe to the live Firestore
/// document.  When another admin marks the comparison as reviewed, this screen
/// reflects that immediately without requiring a manual refresh.
class _ComparisonDetailScreen extends ConsumerStatefulWidget {
  final String advisoryId;
  const _ComparisonDetailScreen({required this.advisoryId});

  @override
  ConsumerState<_ComparisonDetailScreen> createState() =>
      _ComparisonDetailScreenState();
}

class _ComparisonDetailScreenState
    extends ConsumerState<_ComparisonDetailScreen> {
  final TextEditingController _noteCtrl = TextEditingController();
  bool _saving = false;

  // Track the last-loaded note so we only override the text field on the
  // first load (not on every live update that would interrupt typing).
  bool _noteInitialized = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _markReviewed() async {
    setState(() => _saving = true);
    try {
      await AgronomicAdvisoryService.markComparisonReviewed(
        widget.advisoryId,
        _noteCtrl.text,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _snackError(friendlyError(e, 'Could not save review'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveNote() async {
    setState(() => _saving = true);
    try {
      await AgronomicAdvisoryService.saveComparisonNote(
        widget.advisoryId,
        _noteCtrl.text,
      );
      if (mounted) _snack('Note saved.');
    } catch (e) {
      if (mounted) _snackError(friendlyError(e, 'Could not save note'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  void _snackError(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Theme.of(context).colorScheme.error),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final docAsync = ref.watch(comparisonDocProvider(widget.advisoryId));

    return docAsync.when(
      loading: () => Scaffold(
        backgroundColor: cs.surfaceContainerLowest,
        appBar: AppBar(
          backgroundColor: _kAppBar,
          foregroundColor: Colors.white,
          title: const Text('Advisory Comparison'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: cs.surfaceContainerLowest,
        appBar: AppBar(
          backgroundColor: _kAppBar,
          foregroundColor: Colors.white,
          title: const Text('Advisory Comparison'),
        ),
        body: Center(
          child: Text(
            friendlyError(e, 'Could not load comparison'),
            style: TextStyle(color: cs.error),
          ),
        ),
      ),
      data: (item) {
        if (item == null) {
          return Scaffold(
            backgroundColor: cs.surfaceContainerLowest,
            appBar: AppBar(
              backgroundColor: _kAppBar,
              foregroundColor: Colors.white,
              title: const Text('Advisory Comparison'),
            ),
            body: Center(
              child: Text(
                'Comparison not found — it may have been deleted.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
          );
        }

        // Initialise text field once from Firestore (don't overwrite typing).
        if (!_noteInitialized) {
          _noteCtrl.text = item.adminNote;
          _noteInitialized = true;
        }

        return _buildDetail(context, cs, item);
      },
    );
  }

  Widget _buildDetail(
      BuildContext context, ColorScheme cs, AdvisoryAiComparison item) {
    final title =
        item.conditionLabel.isEmpty ? item.condition : item.conditionLabel;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: _kAppBar,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Advisory Comparison',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            Text(
              '$title · v${item.advisoryVersion}',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            _MetaCard(item: item, cs: cs),
            const SizedBox(height: 14),
            _ColumnHeaders(item: item),
            const SizedBox(height: 10),
            _SectionLabel('Main action', cs),
            _ComparisonRow(item.agronomistAdvice.main, item.aiAdvice.main, cs),
            const SizedBox(height: 10),
            _SectionLabel('DO', cs),
            _ListRow(item.agronomistAdvice.doList, item.aiAdvice.doList, cs),
            const SizedBox(height: 10),
            _SectionLabel('AVOID', cs),
            _ListRow(item.agronomistAdvice.avoidList, item.aiAdvice.avoidList, cs),
            const SizedBox(height: 10),
            _SectionLabel('WHY', cs),
            _ComparisonRow(item.agronomistAdvice.why, item.aiAdvice.why, cs),
            if (item.agronomistActions.pests.isNotEmpty ||
                item.aiActions.pests.isNotEmpty) ...[
              const SizedBox(height: 10),
              _SectionLabel('Pests to check', cs),
              _CropChecksRow(
                item.agronomistActions.pests,
                item.aiActions.pests,
                cs,
              ),
            ],
            if (item.agronomistActions.diseases.isNotEmpty ||
                item.aiActions.diseases.isNotEmpty) ...[
              const SizedBox(height: 10),
              _SectionLabel('Diseases to check', cs),
              _CropChecksRow(
                item.agronomistActions.diseases,
                item.aiActions.diseases,
                cs,
              ),
            ],
            if (item.agronomistActions.soil.isNotEmpty ||
                item.aiActions.soil.isNotEmpty) ...[
              const SizedBox(height: 10),
              _SectionLabel('Soil & fertiliser actions', cs),
              _SoilRow(item.agronomistActions.soil, item.aiActions.soil, cs),
            ],
            const SizedBox(height: 14),
            Divider(color: cs.outlineVariant),
            const SizedBox(height: 10),
            _AdminNoteField(
              controller: _noteCtrl,
              readOnly: item.adminReviewed,
              cs: cs,
            ),
            if (item.adminReviewed) ...[
              const SizedBox(height: 10),
              _ReviewedBadge(item: item, cs: cs),
            ],
          ],
        ),
      ),
      bottomNavigationBar: item.adminReviewed
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: BoxDecoration(
                  color: cs.surface,
                  border: Border(
                    top: BorderSide(color: cs.outlineVariant, width: 0.8),
                  ),
                ),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: _saving ? null : _saveNote,
                      child: const Text('Save note'),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _kAgronomist,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _saving ? null : _markReviewed,
                      icon: _saving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline_rounded,
                              size: 18),
                      label: const Text('Mark as reviewed'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// ── Shared comparison widgets ─────────────────────────────────────────────────

class _MetaCard extends StatelessWidget {
  final AdvisoryAiComparison item;
  final ColorScheme cs;
  const _MetaCard({required this.item, required this.cs});

  @override
  Widget build(BuildContext context) {
    final label =
        item.conditionLabel.isEmpty ? item.condition : item.conditionLabel;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant, width: 0.8),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        children: [
          if (item.crops.isNotEmpty)
            _Chip(Icons.spa_rounded, item.crops.take(4).join(', '), cs),
          _Chip(Icons.thermostat_rounded, label, cs),
          if (item.generatedAt != null)
            _Chip(Icons.calendar_today_rounded,
                DateFormat('d MMM y').format(item.generatedAt!), cs),
          _Chip(Icons.person_outline_rounded, item.agronomistName, cs),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme cs;
  const _Chip(this.icon, this.label, this.cs);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: cs.outline),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
    ],
  );
}

class _ColumnHeaders extends StatelessWidget {
  final AdvisoryAiComparison item;
  const _ColumnHeaders({required this.item});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 400;
      if (narrow) {
        // On very narrow screens stack — the comparison rows also stack.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeaderChip(Icons.verified_rounded, 'Agronomist',
                item.agronomistName, _kAgronomist),
            const SizedBox(height: 6),
            _HeaderChip(Icons.auto_awesome_rounded, 'AI Generated',
                'Gemini · not verified', _kAi),
          ],
        );
      }
      return Row(children: [
        Expanded(
          child: _HeaderChip(Icons.verified_rounded, 'Agronomist',
              item.agronomistName, _kAgronomist),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _HeaderChip(Icons.auto_awesome_rounded, 'AI Generated',
              'Gemini · not verified', _kAi),
        ),
      ]);
    });
  }
}

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  const _HeaderChip(this.icon, this.title, this.subtitle, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Row(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 6),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w800, color: color)),
          Text(subtitle,
              style: const TextStyle(fontSize: 10.5, color: Colors.black54),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
      ),
    ]),
  );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final ColorScheme cs;
  const _SectionLabel(this.text, this.cs);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: cs.onSurfaceVariant,
        letterSpacing: 0.4,
      ),
    ),
  );
}

// ── Comparison cells ──────────────────────────────────────────────────────────

/// Side-by-side on wide screens, stacked with colour labels on narrow ones.
class _ComparisonRow extends StatelessWidget {
  final String agr;
  final String ai;
  final ColorScheme cs;
  const _ComparisonRow(this.agr, this.ai, this.cs);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => c.maxWidth >= 400
        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _TextBox(agr, _kAgronomist, cs)),
            const SizedBox(width: 8),
            Expanded(child: _TextBox(ai, _kAi, cs)),
          ])
        : Column(children: [
            _TextBox(agr, _kAgronomist, cs, label: 'Agronomist'),
            const SizedBox(height: 6),
            _TextBox(ai, _kAi, cs, label: 'AI'),
          ]),
  );
}

class _TextBox extends StatelessWidget {
  final String text;
  final Color color;
  final ColorScheme cs;
  final String? label;
  const _TextBox(this.text, this.color, this.cs, {this.label});

  @override
  Widget build(BuildContext context) {
    final isEmpty = text.isEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Text(label!,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: 0.5,
                )),
            const SizedBox(height: 4),
          ],
          Text(
            isEmpty ? '—' : text,
            style: TextStyle(
              fontSize: 12.5,
              color: isEmpty ? cs.outlineVariant : cs.onSurface,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  final List<String> agr;
  final List<String> ai;
  final ColorScheme cs;
  const _ListRow(this.agr, this.ai, this.cs);

  @override
  Widget build(BuildContext context) {
    if (agr.isEmpty && ai.isEmpty) {
      return _ComparisonRow('(none)', '(none)', cs);
    }
    final count = agr.length > ai.length ? agr.length : ai.length;
    return Column(
      children: List.generate(count, (i) {
        final a = i < agr.length ? '• ${agr[i]}' : '—';
        final b = i < ai.length ? '• ${ai[i]}' : '—';
        return Padding(
          padding: EdgeInsets.only(bottom: i < count - 1 ? 6 : 0),
          child: _ComparisonRow(a, b, cs),
        );
      }),
    );
  }
}

class _CropChecksRow extends StatelessWidget {
  final List<CropCheck> agr;
  final List<CropCheck> ai;
  final ColorScheme cs;
  const _CropChecksRow(this.agr, this.ai, this.cs);

  static String _fmt(CropCheck c) =>
      '${c.name}'
      '${c.signs.isNotEmpty ? '\n  Signs: ${c.signs}' : ''}'
      '${c.ifFound.isNotEmpty ? '\n  If found: ${c.ifFound}' : ''}';

  @override
  Widget build(BuildContext context) {
    final agrT = agr.map(_fmt).toList();
    final aiT = ai.map(_fmt).toList();
    if (agrT.isEmpty && aiT.isEmpty) return const SizedBox.shrink();
    final count = agrT.length > aiT.length ? agrT.length : aiT.length;
    return Column(
      children: List.generate(count, (i) {
        final a = i < agrT.length ? agrT[i] : '—';
        final b = i < aiT.length ? aiT[i] : '—';
        return Padding(
          padding: EdgeInsets.only(bottom: i < count - 1 ? 6 : 0),
          child: _ComparisonRow(a, b, cs),
        );
      }),
    );
  }
}

class _SoilRow extends StatelessWidget {
  final List<SoilAction> agr;
  final List<SoilAction> ai;
  final ColorScheme cs;
  const _SoilRow(this.agr, this.ai, this.cs);

  static String _fmt(SoilAction s) {
    final buf = StringBuffer(s.nutrient);
    if (s.stages.isNotEmpty) buf.write(' · ${s.stages.join(', ')}');
    if (!s.general.isEmpty) buf.write('\n  General: ${s.general.action}');
    if (s.low.action.isNotEmpty) buf.write('\n  Low: ${s.low.action}');
    if (s.moderate.action.isNotEmpty) {
      buf.write('\n  Moderate: ${s.moderate.action}');
    }
    if (s.high.action.isNotEmpty) buf.write('\n  High: ${s.high.action}');
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final agrT = agr.map(_fmt).toList();
    final aiT = ai.map(_fmt).toList();
    if (agrT.isEmpty && aiT.isEmpty) return const SizedBox.shrink();
    final count = agrT.length > aiT.length ? agrT.length : aiT.length;
    return Column(
      children: List.generate(count, (i) {
        final a = i < agrT.length ? agrT[i] : '—';
        final b = i < aiT.length ? aiT[i] : '—';
        return Padding(
          padding: EdgeInsets.only(bottom: i < count - 1 ? 6 : 0),
          child: _ComparisonRow(a, b, cs),
        );
      }),
    );
  }
}

// ── Admin note & reviewed badge ───────────────────────────────────────────────

class _AdminNoteField extends StatelessWidget {
  final TextEditingController controller;
  final bool readOnly;
  final ColorScheme cs;
  const _AdminNoteField(
      {required this.controller,
      required this.readOnly,
      required this.cs});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Admin note',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: cs.onSurface,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'Note any critical information the agronomist may have missed, '
        'or confirm accuracy.',
        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, height: 1.35),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: controller,
        enabled: !readOnly,
        minLines: 3,
        maxLines: 8,
        maxLength: 1000,
        decoration: InputDecoration(
          hintText: 'Add observations, corrections or confirmation…',
          isDense: true,
          filled: true,
          fillColor: cs.surfaceContainerLow,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: cs.outlineVariant),
          ),
        ),
      ),
    ],
  );
}

class _ReviewedBadge extends StatelessWidget {
  final AdvisoryAiComparison item;
  final ColorScheme cs;
  const _ReviewedBadge({required this.item, required this.cs});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFE8F5E9),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFA5D6A7)),
    ),
    child: Row(children: [
      const Icon(Icons.check_circle_rounded,
          color: Color(0xFF2E7D32), size: 18),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reviewed',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1B5E20),
              ),
            ),
            if (item.reviewedByName != null)
              Text(
                'by ${item.reviewedByName}'
                '${item.reviewedAt != null ? ' · ${DateFormat('d MMM y').format(item.reviewedAt!)}' : ''}',
                style: TextStyle(
                    fontSize: 11.5, color: cs.onSurfaceVariant),
              ),
          ],
        ),
      ),
    ]),
  );
}
