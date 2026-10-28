// lib/enterprise/features/weather/advisory_ai_comparison_screen.dart
//
// Admin-only screen: lists all published advisories that have an AI-generated
// parallel draft, lets admins compare them side-by-side, add a note, and mark
// as reviewed. Collection: advisoryAiComparisons/{advisoryId} (admin-only).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_ai_comparison.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_actions.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_widgets.dart';
import 'package:kilimomkononi/utils/friendly_error.dart';

const _kDarkGreen = Color.fromARGB(255, 3, 39, 4);
const _kPageBg = Color(0xFFF4F6F3);
const _kAi = Color(0xFF6A1B9A);
const _kAgronomist = Color(0xFF1B5E20);

class AdvisoryAiComparisonScreen extends StatelessWidget {
  const AdvisoryAiComparisonScreen({super.key});

  static Stream<List<AdvisoryAiComparison>> _stream() =>
      FirebaseFirestore.instance
          .collection('advisoryAiComparisons')
          .orderBy('generatedAt', descending: true)
          .snapshots()
          .map(
            (s) => s.docs.map(AdvisoryAiComparison.fromDoc).toList(),
          );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPageBg,
      appBar: AppBar(
        backgroundColor: _kDarkGreen,
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
      body: StreamBuilder<List<AdvisoryAiComparison>>(
        stream: _stream(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Text(
                friendlyError(snap.error, 'Could not load comparisons'),
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data!;
          if (items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.compare_arrows_rounded, size: 48, color: Colors.black26),
                  SizedBox(height: 12),
                  Text(
                    'No comparisons yet',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black54),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Comparisons are generated automatically\nwhen an agronomist publishes an advisory.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: Colors.black38),
                  ),
                ],
              ),
            );
          }

          final pending = items.where((e) => !e.adminReviewed).length;
          return Column(
            children: [
              if (pending > 0)
                Container(
                  width: double.infinity,
                  color: const Color(0xFFFFF9C4),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(children: [
                    const Icon(Icons.pending_actions_rounded, size: 16, color: Color(0xFFF57F17)),
                    const SizedBox(width: 8),
                    Text(
                      '$pending pending review${pending == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFF57F17),
                      ),
                    ),
                  ]),
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _ComparisonTile(
                    item: items[i],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _ComparisonDetailScreen(item: items[i]),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── List tile ─────────────────────────────────────────────────────────────────

class _ComparisonTile extends StatelessWidget {
  final AdvisoryAiComparison item;
  final VoidCallback onTap;
  const _ComparisonTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final reviewed = item.adminReviewed;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: reviewed
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  reviewed
                      ? Icons.check_circle_outline_rounded
                      : Icons.pending_actions_rounded,
                  color: reviewed
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFE65100),
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
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.crops.take(3).join(', ') +
                          (item.crops.length > 3
                              ? ' +${item.crops.length - 3} more'
                              : ''),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Colors.black54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(children: [
                      Text(
                        'by ${item.agronomistName}',
                        style: const TextStyle(fontSize: 11, color: Colors.black45),
                      ),
                      if (item.generatedAt != null) ...[
                        const Text(
                          ' · ',
                          style: TextStyle(fontSize: 11, color: Colors.black26),
                        ),
                        Text(
                          DateFormat('d MMM y').format(item.generatedAt!),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: reviewed
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      reviewed ? 'Reviewed' : 'Pending',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: reviewed
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFE65100),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Icon(Icons.chevron_right_rounded, color: Colors.black26),
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

class _ComparisonDetailScreen extends StatefulWidget {
  final AdvisoryAiComparison item;
  const _ComparisonDetailScreen({required this.item});

  @override
  State<_ComparisonDetailScreen> createState() =>
      _ComparisonDetailScreenState();
}

class _ComparisonDetailScreenState extends State<_ComparisonDetailScreen> {
  late TextEditingController _noteCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController(text: widget.item.adminNote);
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _markReviewed() async {
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final snap = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .get();
      final name = (snap.data()?['fullName'] as String?)?.trim() ??
          user.displayName ??
          'Admin';

      await FirebaseFirestore.instance
          .collection('advisoryAiComparisons')
          .doc(widget.item.advisoryId)
          .update({
        'adminReviewed': true,
        'adminNote': _noteCtrl.text.trim(),
        'reviewedByName': name,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e, 'Could not save review')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveNote() async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('advisoryAiComparisons')
          .doc(widget.item.advisoryId)
          .update({'adminNote': _noteCtrl.text.trim()});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note saved.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e, 'Could not save note')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Scaffold(
      backgroundColor: _kPageBg,
      appBar: AppBar(
        backgroundColor: _kDarkGreen,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Advisory Comparison',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            Text(
              '${item.conditionLabel.isEmpty ? item.condition : item.conditionLabel} · v${item.advisoryVersion}',
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
            // ── Meta ─────────────────────────────────────────────────────
            _metaCard(item),
            const SizedBox(height: 14),

            // ── Side by side header ───────────────────────────────────────
            Row(children: [
              Expanded(
                child: _header(
                  Icons.verified_rounded,
                  'Agronomist',
                  item.agronomistName,
                  _kAgronomist,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _header(
                  Icons.auto_awesome_rounded,
                  'AI Generated',
                  'Gemini · not verified',
                  _kAi,
                ),
              ),
            ]),
            const SizedBox(height: 10),

            // ── Main action ───────────────────────────────────────────────
            _sectionLabel('Main action'),
            _comparisonRow(
              item.agronomistAdvice.main,
              item.aiAdvice.main,
            ),
            const SizedBox(height: 10),

            // ── DO lists ──────────────────────────────────────────────────
            _sectionLabel('DO'),
            _listComparisonRow(item.agronomistAdvice.doList, item.aiAdvice.doList),
            const SizedBox(height: 10),

            // ── AVOID lists ───────────────────────────────────────────────
            _sectionLabel('AVOID'),
            _listComparisonRow(
                item.agronomistAdvice.avoidList, item.aiAdvice.avoidList),
            const SizedBox(height: 10),

            // ── WHY ───────────────────────────────────────────────────────
            _sectionLabel('WHY'),
            _comparisonRow(item.agronomistAdvice.why, item.aiAdvice.why),
            const SizedBox(height: 14),

            // ── Pest checks ───────────────────────────────────────────────
            if (item.agronomistActions.pests.isNotEmpty ||
                item.aiActions.pests.isNotEmpty) ...[
              _sectionLabel('Pests to check'),
              _checksComparisonRow(
                item.agronomistActions.pests,
                item.aiActions.pests,
                color: const Color(0xFFEF6C00),
              ),
              const SizedBox(height: 10),
            ],

            // ── Disease checks ────────────────────────────────────────────
            if (item.agronomistActions.diseases.isNotEmpty ||
                item.aiActions.diseases.isNotEmpty) ...[
              _sectionLabel('Diseases to check'),
              _checksComparisonRow(
                item.agronomistActions.diseases,
                item.aiActions.diseases,
                color: const Color(0xFFC62828),
              ),
              const SizedBox(height: 10),
            ],

            // ── Soil actions ──────────────────────────────────────────────
            if (item.agronomistActions.soil.isNotEmpty ||
                item.aiActions.soil.isNotEmpty) ...[
              _sectionLabel('Soil & fertiliser actions'),
              _soilComparisonRow(
                item.agronomistActions.soil,
                item.aiActions.soil,
              ),
              const SizedBox(height: 10),
            ],

            const SizedBox(height: 6),
            const Divider(),
            const SizedBox(height: 6),

            // ── Admin note ────────────────────────────────────────────────
            _adminNoteSection(item),

            if (item.adminReviewed) ...[
              const SizedBox(height: 10),
              _reviewedBadge(item),
            ],
          ],
        ),
      ),
      bottomNavigationBar: item.adminReviewed
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border:
                      Border(top: BorderSide(color: AdvisoryColors.border)),
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

  Widget _metaCard(AdvisoryAiComparison item) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AdvisoryColors.border),
    ),
    child: Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        _metaChip(Icons.spa_rounded, item.crops.take(4).join(', ')),
        _metaChip(Icons.thermostat_rounded,
            item.conditionLabel.isEmpty ? item.condition : item.conditionLabel),
        if (item.generatedAt != null)
          _metaChip(
            Icons.calendar_today_rounded,
            DateFormat('d MMM y').format(item.generatedAt!),
          ),
        _metaChip(Icons.person_outline_rounded, item.agronomistName),
      ],
    ),
  );

  Widget _metaChip(IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: Colors.black45),
      const SizedBox(width: 4),
      Text(label,
          style: const TextStyle(fontSize: 12, color: Colors.black54)),
    ],
  );

  Widget _header(
      IconData icon, String title, String subtitle, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: color)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 10.5, color: Colors.black54),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _sectionLabel(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      t,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: Colors.black54,
      ),
    ),
  );

  Widget _comparisonRow(String agronomist, String ai) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: _textBox(agronomist, _kAgronomist)),
      const SizedBox(width: 8),
      Expanded(child: _textBox(ai, _kAi)),
    ],
  );

  Widget _textBox(String text, Color color) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Text(
      text.isEmpty ? '—' : text,
      style: TextStyle(
        fontSize: 12.5,
        color: text.isEmpty ? Colors.black26 : Colors.black87,
        height: 1.4,
      ),
    ),
  );

  Widget _listComparisonRow(List<String> agronomist, List<String> ai) {
    final count = [agronomist.length, ai.length].reduce((a, b) => a > b ? a : b);
    if (count == 0) {
      return _comparisonRow('(none)', '(none)');
    }
    return Column(
      children: List.generate(count, (i) {
        final a = i < agronomist.length ? agronomist[i] : '';
        final b = i < ai.length ? ai[i] : '';
        return Padding(
          padding: EdgeInsets.only(bottom: i < count - 1 ? 6 : 0),
          child: _comparisonRow(a.isEmpty ? '—' : '• $a', b.isEmpty ? '—' : '• $b'),
        );
      }),
    );
  }

  Widget _checksComparisonRow(
      List<CropCheck> agronomist, List<CropCheck> ai,
      {required Color color}) {
    final agrTexts = agronomist
        .map((c) => '${c.name}\n  Signs: ${c.signs}\n  If found: ${c.ifFound}')
        .toList();
    final aiTexts = ai
        .map((c) => '${c.name}\n  Signs: ${c.signs}\n  If found: ${c.ifFound}')
        .toList();

    if (agrTexts.isEmpty && aiTexts.isEmpty) return const SizedBox.shrink();

    final count = [agrTexts.length, aiTexts.length]
        .reduce((a, b) => a > b ? a : b);
    return Column(
      children: List.generate(count, (i) {
        final a = i < agrTexts.length ? agrTexts[i] : '—';
        final b = i < aiTexts.length ? aiTexts[i] : '—';
        return Padding(
          padding: EdgeInsets.only(bottom: i < count - 1 ? 6 : 0),
          child: _comparisonRow(a, b),
        );
      }),
    );
  }

  Widget _soilComparisonRow(
      List<SoilAction> agronomist, List<SoilAction> ai) {
    String soilText(SoilAction s) {
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

    final agrTexts = agronomist.map(soilText).toList();
    final aiTexts = ai.map(soilText).toList();

    if (agrTexts.isEmpty && aiTexts.isEmpty) return const SizedBox.shrink();

    final count =
        [agrTexts.length, aiTexts.length].reduce((a, b) => a > b ? a : b);
    return Column(
      children: List.generate(count, (i) {
        final a = i < agrTexts.length ? agrTexts[i] : '—';
        final b = i < aiTexts.length ? aiTexts[i] : '—';
        return Padding(
          padding: EdgeInsets.only(bottom: i < count - 1 ? 6 : 0),
          child: _comparisonRow(a, b),
        );
      }),
    );
  }

  Widget _adminNoteSection(AdvisoryAiComparison item) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Admin note',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Colors.black87,
        ),
      ),
      const SizedBox(height: 4),
      const Text(
        'Note any critical information the agronomist may have missed, or confirm accuracy.',
        style: TextStyle(fontSize: 12, color: Colors.black45, height: 1.35),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _noteCtrl,
        enabled: !item.adminReviewed,
        minLines: 3,
        maxLines: 8,
        maxLength: 1000,
        decoration: InputDecoration(
          hintText: 'Add observations, corrections or confirmation…',
          isDense: true,
          filled: true,
          fillColor: const Color(0xFFFAFBFA),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    ],
  );

  Widget _reviewedBadge(AdvisoryAiComparison item) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFE8F5E9),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFA5D6A7)),
    ),
    child: Row(children: [
      const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 18),
      const SizedBox(width: 8),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Reviewed',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1B5E20))),
          if (item.reviewedByName != null)
            Text(
              'by ${item.reviewedByName}'
              '${item.reviewedAt != null ? ' · ${DateFormat('d MMM y').format(item.reviewedAt!)}' : ''}',
              style: const TextStyle(fontSize: 11.5, color: Colors.black54),
            ),
        ]),
      ),
    ]),
  );
}
