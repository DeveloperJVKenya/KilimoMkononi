// lib/enterprise/features/weather/advisory_widgets.dart
//
// Shared visuals for weather advice: the MAIN / DO / AVOID / WHY body used
// by the AI card, verified advisories and the editor preview, plus the
// verified-advisory card farmers see and the small chips/pills the Field
// Agronomist panel uses.

import 'package:flutter/material.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_actions.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_conditions.dart';
import 'package:kilimomkononi/enterprise/features/weather/agronomic_advisory.dart';
import 'package:kilimomkononi/enterprise/features/weather/structured_advice.dart';

class AdvisoryColors {
  AdvisoryColors._();
  static const darkGreen = Color.fromARGB(255, 3, 39, 4);
  static const midGreen = Color(0xFF2A6B2A);
  static const verified = Color(0xFF1B5E20);
  static const verifiedBg = Color(0xFFE8F5E9);
  static const verifiedBorder = Color(0xFF81C784);
  static const amber = Color(0xFFE65100);
  static const lightAmber = Color(0xFFFFF8E1);
  static const red = Color(0xFFB71C1C);
  static const border = Color(0xFFE0E4DF);
  static const pageBg = Color(0xFFF4F6F3);
}

String formatAdvisoryDate(DateTime? d) {
  if (d == null) return '—';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '$dd/$mm/${d.year}';
}

// ── MAIN / DO / AVOID / WHY ──────────────────────────────────────────────────

class AdviceBody extends StatelessWidget {
  final StructuredAdvice advice;
  const AdviceBody({super.key, required this.advice});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (advice.main.trim().isNotEmpty)
          Text(
            advice.main.toUpperCase(),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AdvisoryColors.darkGreen,
              height: 1.25,
            ),
          ),
        if (advice.doList.isNotEmpty) ...[
          const SizedBox(height: 12),
          const _ListHeading('DO NOW', AdvisoryColors.midGreen),
          ...advice.doList.map(
            (t) => _Bullet(t, Icons.check_rounded, AdvisoryColors.midGreen),
          ),
        ],
        if (advice.avoidList.isNotEmpty) ...[
          const SizedBox(height: 10),
          const _ListHeading('AVOID', AdvisoryColors.red),
          ...advice.avoidList.map(
            (t) => _Bullet(t, Icons.block_rounded, AdvisoryColors.red),
          ),
        ],
        if (advice.why.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            advice.why,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

class _ListHeading extends StatelessWidget {
  final String text;
  final Color color;
  const _ListHeading(this.text, this.color);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: 0.6,
      ),
    ),
  );
}

class _Bullet extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  const _Bullet(this.text, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              height: 1.3,
            ),
          ),
        ),
      ],
    ),
  );
}

// ── Pills & chips ────────────────────────────────────────────────────────────

class Pill extends StatelessWidget {
  final String text;
  final Color fg;
  final Color bg;
  final IconData? icon;

  /// Ellipsize instead of overflowing — only where the width is bounded
  /// (e.g. inside a Wrap), never as a plain child of a Row.
  final bool flexible;
  const Pill(
    this.text, {
    super.key,
    required this.fg,
    required this.bg,
    this.icon,
    this.flexible = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 3),
        ],
        if (flexible)
          Flexible(child: _label)
        else
          _label,
      ],
    ),
  );

  Widget get _label => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
  );
}

class ConditionPill extends StatelessWidget {
  final String conditionKey;

  /// The name to show instead of the key's own (a typed condition's name).
  final String? label;
  const ConditionPill(this.conditionKey, {super.key, this.label});

  @override
  Widget build(BuildContext context) {
    final c = conditionFor(conditionKey);
    return Pill(
      (label ?? '').trim().isNotEmpty ? label!.trim() : c.label,
      icon: c.icon,
      fg: const Color(0xFF0D47A1),
      bg: const Color(0xFFE3F2FD),
    );
  }
}

class StatusPill extends StatelessWidget {
  final AdvisoryStatus status;
  const StatusPill(this.status, {super.key});

  @override
  Widget build(BuildContext context) => switch (status) {
    AdvisoryStatus.published => const Pill(
      'PUBLISHED',
      icon: Icons.verified_rounded,
      fg: AdvisoryColors.verified,
      bg: AdvisoryColors.verifiedBg,
    ),
    AdvisoryStatus.draft => const Pill(
      'DRAFT',
      icon: Icons.edit_note_rounded,
      fg: AdvisoryColors.amber,
      bg: AdvisoryColors.lightAmber,
    ),
    AdvisoryStatus.archived => Pill(
      'ARCHIVED',
      icon: Icons.inventory_2_outlined,
      fg: Colors.grey.shade700,
      bg: Colors.grey.shade200,
    ),
  };
}

class CropChips extends StatelessWidget {
  final List<String> crops;
  const CropChips(this.crops, {super.key});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 4,
    runSpacing: 4,
    children: crops
        .map(
          (c) => Pill(
            c,
            icon: Icons.grass_rounded,
            fg: AdvisoryColors.midGreen,
            bg: Colors.white,
          ),
        )
        .toList(),
  );
}

// ── Farmer-facing verified advisory ──────────────────────────────────────────

/// A published advisory as farmers see it. [preview] renders the same card
/// inside the editor before anything is published.
class VerifiedAdvisoryCard extends StatelessWidget {
  final StructuredAdvice advice;
  final List<String> crops;
  final String condition;

  /// A typed condition's name (when [condition] is 'custom').
  final String? conditionLabel;
  final String? verifierName;
  final DateTime? verifiedAt;
  final bool stationScoped;
  final bool preview;
  final bool testOnly;

  /// Soil / pest / disease content, summarised under the advice.
  final AdviceActions actions;

  /// Opens the action screen ("Check & log"); null hides the button.
  final VoidCallback? onOpen;

  const VerifiedAdvisoryCard({
    super.key,
    required this.advice,
    required this.crops,
    required this.condition,
    this.conditionLabel,
    this.verifierName,
    this.verifiedAt,
    this.stationScoped = false,
    this.preview = false,
    this.testOnly = false,
    this.actions = AdviceActions.empty,
    this.onOpen,
  });

  factory VerifiedAdvisoryCard.fromAdvisory(
    AgronomicAdvisory a, {
    VoidCallback? onOpen,
  }) => VerifiedAdvisoryCard(
        onOpen: onOpen,
        actions: a.actions,
        advice: a.advice,
        crops: a.crops,
        condition: a.condition,
        conditionLabel: a.isCustomCondition ? a.conditionLabel : null,
        verifierName: a.publishedByName,
        verifiedAt: a.publishedAt,
        stationScoped: a.isStationScoped,
        testOnly: a.testOnly,
      );

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdvisoryColors.verifiedBorder, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Verified banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: const BoxDecoration(
              color: AdvisoryColors.verifiedBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_rounded,
                  size: 16,
                  color: AdvisoryColors.verified,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    preview
                        ? 'Preview · Verified by Field Agronomist'
                        : 'Verified by Field Agronomist',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AdvisoryColors.verified,
                    ),
                  ),
                ),
                ConditionPill(condition, label: conditionLabel),
              ],
            ),
          ),
          if (testOnly) const TestModeStrip(),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (crops.isNotEmpty) ...[
                  CropChips(crops),
                  const SizedBox(height: 10),
                ],
                AdviceBody(advice: advice),
                if (!actions.isEmpty) ...[
                  const SizedBox(height: 10),
                  AdviceActionsSummary(actions),
                ],
                const SizedBox(height: 10),
                const Divider(height: 1, color: AdvisoryColors.border),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.support_agent_rounded,
                      size: 14,
                      color: AdvisoryColors.verified,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        preview
                            ? 'Your name and the publish date appear here'
                            : '${verifierName ?? 'Field Agronomist'} · ${formatAdvisoryDate(verifiedAt)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AdvisoryColors.verified,
                        ),
                      ),
                    ),
                    Text(
                      stationScoped ? 'This station' : 'All stations',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
                if (onOpen != null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AdvisoryColors.verified,
                      ),
                      onPressed: onOpen,
                      icon: const Icon(Icons.playlist_add_check_rounded, size: 18),
                      label: Text(
                        actions.isEmpty ? 'Open advice' : 'Check my farm & log actions',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    return card;
  }
}

/// "Soil: N, P · Check for: Aphids, Late blight" — what an advice asks the
/// farmer to act on, by section.
class AdviceActionsSummary extends StatelessWidget {
  final AdviceActions actions;
  const AdviceActionsSummary(this.actions, {super.key});

  @override
  Widget build(BuildContext context) {
    Widget row(AdviceSection s, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(s.icon, size: 14, color: s.color),
          const SizedBox(width: 6),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: s == AdviceSection.soil ? 'Soil: ' : '${s.short} to check: ',
                  style: TextStyle(fontWeight: FontWeight.w800, color: s.color),
                ),
                TextSpan(text: text),
              ]),
              style: const TextStyle(fontSize: 12.5, color: Colors.black87, height: 1.3),
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (actions.soil.isNotEmpty)
          row(AdviceSection.soil, actions.soil.map((a) => a.label).join(', ')),
        if (actions.pests.isNotEmpty)
          row(AdviceSection.pests, actions.pests.map((c) => c.name).join(', ')),
        if (actions.diseases.isNotEmpty)
          row(AdviceSection.diseases, actions.diseases.map((c) => c.name).join(', ')),
      ],
    );
  }
}

/// Marks admin test-mode content — never shown to farmers.
class TestModeStrip extends StatelessWidget {
  final String text;
  const TestModeStrip({
    super.key,
    this.text = 'TEST — visible to admins only, never to farmers',
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    color: const Color(0xFF4A148C),
    child: Row(
      children: [
        const Icon(Icons.science_outlined, size: 13, color: Colors.white),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ],
    ),
  );
}
