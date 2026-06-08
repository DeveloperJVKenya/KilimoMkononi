// lib/widgets/plot_history_card.dart
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:kilimomkononi/services/plot_analysis_service.dart';

const Color _cardGreen = Color(0xFF003900);
const Color _mintBg    = Color(0xFFF0F7F0);

// ═══════════════════════════════════════════════════════════════════════════
//  PlotHistoryCard
//
//  Collapsible card shown at the TOP of each data-input screen.
//  Pass analysis: null → renders nothing (no empty state noise).
//  Pass analysis: PlotAnalysisResult → shows collapsible sections.
// ═══════════════════════════════════════════════════════════════════════════

class PlotHistoryCard extends StatefulWidget {
  final PlotAnalysisResult? analysis;
  final String seasonLabel;
  final bool isEducation;

  const PlotHistoryCard({
    super.key,
    required this.analysis,
    required this.seasonLabel,
    this.isEducation = true,
  });

  @override
  State<PlotHistoryCard> createState() => _PlotHistoryCardState();
}

class _PlotHistoryCardState extends State<PlotHistoryCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.analysis == null) return const SizedBox.shrink();
    final a = widget.analysis!;
    final audienceLabel = widget.isEducation ? 'Previous class' : 'Previous season';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _mintBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardGreen.withOpacity(0.3), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        // ── Collapsed header ──────────────────────────────────────────
        InkWell(
          onTap: _toggle,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _cardGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.history_edu, color: _cardGreen, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📋 $audienceLabel history',
                      style: const TextStyle(fontSize: 14,
                          fontWeight: FontWeight.bold, color: _cardGreen)),
                  Text(widget.seasonLabel,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              )),
              AnimatedRotation(
                turns: _expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 280),
                child: const Icon(Icons.keyboard_arrow_down, color: _cardGreen),
              ),
            ]),
          ),
        ),

        // ── Brief preview when collapsed ──────────────────────────────
        if (!_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              _truncate(a.newStudentBriefing.isNotEmpty
                  ? a.newStudentBriefing : a.soilSummary, 120),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700,
                  fontStyle: FontStyle.italic),
              maxLines: 2, overflow: TextOverflow.ellipsis,
            ),
          ),

        // ── Expanded content ──────────────────────────────────────────
        SizeTransition(
          sizeFactor: _anim,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Divider(height: 1),
              const SizedBox(height: 12),
              if (a.newStudentBriefing.isNotEmpty) ...[
                _Section(icon: Icons.waving_hand, color: Colors.teal,
                    title: widget.isEducation
                        ? 'Handover to new students' : 'Plot handover summary',
                    body: a.newStudentBriefing),
                const SizedBox(height: 10),
              ],
              if (a.soilSummary.isNotEmpty) ...[
                _Section(icon: Icons.grass, color: Colors.brown.shade600,
                    title: 'Soil & field summary', body: a.soilSummary),
                const SizedBox(height: 10),
              ],
              if (a.cropRotationAdvice.isNotEmpty) ...[
                _Section(icon: Icons.rotate_right, color: Colors.green.shade700,
                    title: 'Recommended next crop',
                    body: a.cropRotationAdvice, highlight: true),
                const SizedBox(height: 10),
              ],
              if (a.pestDiseaseSummary.isNotEmpty) ...[
                _Section(icon: Icons.bug_report, color: Colors.red.shade600,
                    title: 'Pests & diseases encountered',
                    body: a.pestDiseaseSummary),
                const SizedBox(height: 10),
              ],
              if (a.financialSummary.isNotEmpty) ...[
                _Section(icon: Icons.account_balance_wallet,
                    color: Colors.orange.shade700,
                    title: 'Financial outcome', body: a.financialSummary),
                const SizedBox(height: 10),
              ],
              if (a.keyLessons.isNotEmpty)
                _Section(icon: Icons.lightbulb_outline,
                    color: Colors.amber.shade700,
                    title: 'Key lessons', body: a.keyLessons),
              const SizedBox(height: 8),
              Text('Generated ${_formatDate(a.generatedAt)}',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic)),
            ]),
          ),
        ),
      ]),
    );
  }

  String _truncate(String t, int n) => t.length > n ? '${t.substring(0, n)}…' : t;

  String _formatDate(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inDays == 0) return 'today';
    if (d.inDays == 1) return 'yesterday';
    if (d.inDays < 30) return '${d.inDays} days ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   title;
  final String   body;
  final bool     highlight;
  const _Section({required this.icon, required this.color,
      required this.title, required this.body, this.highlight = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: highlight ? Colors.green.shade50 : Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
          color: highlight ? Colors.green.shade300 : Colors.grey.shade200),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, color: color, size: 16),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 12,
            fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(body, style: const TextStyle(fontSize: 13, height: 1.45)),
      ])),
    ]),
  );
}