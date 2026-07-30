// lib/widgets/ai_advice_card.dart
//
// Shared "AI feedback" card used after the farmer taps an "Ask AI" /
// "Get AI Advice" button — for soil nutrients (NPK), pest advice and
// disease advice.
//
// Goals:
//  • Never show raw markdown symbols to the farmer (no *, **, ***, ##, //, etc.)
//  • Always split the AI reply into: PROBLEM, MOST URGENT ACTION,
//    RECOMMENDATIONS (small cards with Why / How highlights) and WARNINGS.
//  • Keep everything short, scannable and easy to read while working in
//    the field — no big paragraphs.
//
// Usage:
//   1. Build the prompt with [buildAiAdvicePrompt].
//   2. Parse the model's raw text reply with [AiAdviceData.fromRaw].
//   3. Render with [AiAdviceCard].

import 'package:flutter/material.dart';
import 'dart:convert';

// ─────────────────────────────────────────────────────────────────────────
// Palette — matches the existing brand greens used across the app.
// ─────────────────────────────────────────────────────────────────────────
class AiCardColors {
  AiCardColors._();

  static const gradA      = Color(0xFF0D2B0E);
  static const gradB      = Color(0xFF1B5E20);
  static const brandDark  = Color(0xFF0A2E0B);
  static const brandMid   = Color(0xFF1B5E20);
  static const brandLight = Color(0xFF2E7D32);

  static const resultsBg  = Color(0xFFF4F6F3);
  static const cardBg     = Color(0xFFFFFFFF);
  static const borderDef  = Color(0xFFBBBFBA);

  static const textPrimary = Color(0xFF111A10);
  static const textSec     = Color(0xFF3D4A3C);
  static const textHint    = Color(0xFF5C6B5A);

  // Problem / status
  static const problemBg     = Color(0xFFE3F2FD);
  static const problemBorder = Color(0xFF1565C0);
  static const problemText   = Color(0xFF0D3C7A);

  // Urgent action
  static const urgentBg     = Color(0xFFFBE9E7);
  static const urgentBorder = Color(0xFFBF360C);
  static const urgentText   = Color(0xFFBF360C);

  // Warnings
  static const warnBg     = Color(0xFFFFF3E0);
  static const warnBorder = Color(0xFFE65100);
  static const warnText   = Color(0xFF7A4F00);

  // Category: chemical
  static const chemBg     = Color(0xFFF3E5F5);
  static const chemBorder = Color(0xFF6A1B9A);
  static const chemText   = Color(0xFF4A148C);

  // Category: organic
  static const orgBg     = Color(0xFFE8F5E9);
  static const orgBorder = Color(0xFF2E7D32);
  static const orgText   = Color(0xFF1B5E20);

  // Category: cultural / other
  static const cultBg     = Color(0xFFE0F2F1);
  static const cultBorder = Color(0xFF00695C);
  static const cultText   = Color(0xFF004D40);

  // Error
  static const errorBg     = Color(0xFFFFE5E5);
  static const errorBorder = Color(0xFFCC1111);
  static const errorText   = Color(0xFF7F0000);
}

// ─────────────────────────────────────────────────────────────────────────
// Text cleanup — strips markdown symbols that sometimes leak through
// (***, **, *, ##, __, //, /// , leading "- " dashes) so the farmer never
// sees raw symbols on screen.
// ─────────────────────────────────────────────────────────────────────────
String cleanAiText(String text) {
  return text
      .replaceAll(RegExp(r'\*+'), '')
      .replaceAll(RegExp(r'#+\s*'), '')
      .replaceAll(RegExp(r'_{2,}'), '')
      .replaceAll(RegExp(r'/{2,}'), '')
      .replaceAll(RegExp(r'^[-•]\s*', multiLine: true), '')
      .replaceAll(RegExp(r'\n{2,}'), '\n')
      .trim();
}

// ─────────────────────────────────────────────────────────────────────────
// Prompt builder — asks Gemini for a single, consistent JSON shape that
// works for soil nutrients, pest advice and disease advice alike.
// ─────────────────────────────────────────────────────────────────────────
String buildAiAdvicePrompt({
  required String roleContext,
  required String situation,
  String extraInstructions = '',
  int maxRecommendations = 4,
}) {
  return '''
You are $roleContext advising smallholder farmers in Kenya and East Africa.
Respond ONLY with valid JSON. No markdown, no asterisks, no headings, no
code fences, no text before or after the JSON.

$situation

$extraInstructions

Return exactly this JSON shape. Keep every text value short (under 16 words),
plain everyday language a farmer can act on immediately:
{
  "problem": "3-6 word headline naming the issue",
  "summary": "1-2 short plain sentences explaining what is happening and why",
  "urgentAction": "the single most important thing to do today, or empty string if nothing urgent",
  "recommendations": [
    {"title":"short action name","category":"chemical|organic|cultural","dosage":"amount and unit, or empty string","why":"one short reason this helps","how":"one short instruction on how/when to apply"}
  ],
  "warnings": ["short safety or timing warning", "..."]
}
List between 2 and $maxRecommendations recommendations, ordered by priority.
''';
}

// ─────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────
class AiRecommendation {
  final String title;
  final String category; // 'chemical' | 'organic' | 'cultural' | other
  final String dosage;
  final String why;
  final String how;

  /// Original raw map — useful for callers that want to "tap to fill" a
  /// form (e.g. intervention type/quantity/unit/category).
  final Map<String, dynamic> raw;

  AiRecommendation({
    required this.title,
    this.category = '',
    this.dosage = '',
    this.why = '',
    this.how = '',
    Map<String, dynamic>? raw,
  }) : raw = raw ?? const {};

  factory AiRecommendation.fromJson(Map<String, dynamic> j) {
    String pick(List<String> keys) {
      for (final k in keys) {
        final v = j[k];
        if (v != null && v.toString().trim().isNotEmpty) return v.toString();
      }
      return '';
    }

    String dosage = pick(['dosage']);
    if (dosage.isEmpty && j['quantity'] != null) {
      final q = j['quantity'];
      final unit = j['unit']?.toString() ?? '';
      final qStr = q is num ? q.toStringAsFixed(q == q.roundToDouble() ? 0 : 1) : q.toString();
      dosage = '$qStr $unit'.trim();
    }

    return AiRecommendation(
      title: cleanAiText(pick(['title', 'type', 'product', 'name'])).isEmpty
          ? 'Recommendation'
          : cleanAiText(pick(['title', 'type', 'product', 'name'])),
      category: pick(['category']).toLowerCase(),
      dosage: cleanAiText(dosage),
      why: cleanAiText(pick(['why', 'activeIngredient'])),
      how: cleanAiText(pick(['how', 'timing', 'notes', 'method'])),
      raw: j,
    );
  }
}

class AiAdviceData {
  final String problem;
  final String summary;
  final String urgentAction;
  final List<AiRecommendation> recommendations;
  final List<String> warnings;
  final String? error;

  AiAdviceData({
    this.problem = '',
    this.summary = '',
    this.urgentAction = '',
    this.recommendations = const [],
    this.warnings = const [],
    this.error,
  });

  factory AiAdviceData.error(String message) => AiAdviceData(error: message);

  bool get isEmptyResult =>
      error == null &&
      problem.isEmpty &&
      summary.isEmpty &&
      recommendations.isEmpty &&
      warnings.isEmpty;

  /// Robustly parse a raw Gemini text reply into structured advice.
  /// Falls back gracefully if the model added stray text around the JSON,
  /// or didn't return JSON at all.
  factory AiAdviceData.fromRaw(String raw) {
    if (raw.trim().isEmpty) {
      return AiAdviceData.error('No advice returned. Try again.');
    }

    final cleanedRaw = raw.replaceAll(RegExp(r'```json|```'), '').trim();

    // Try direct decode first, then fall back to extracting the first
    // {...} block (handles cases where the model adds a stray sentence).
    Map<String, dynamic>? j;
    try {
      j = jsonDecode(cleanedRaw) as Map<String, dynamic>;
    } catch (_) {
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(cleanedRaw);
      if (match != null) {
        try {
          j = jsonDecode(match.group(0)!) as Map<String, dynamic>;
        } catch (_) {}
      }
    }

    if (j == null) {
      // No usable JSON — show the cleaned text as a single summary card
      // rather than a wall of raw markdown.
      return AiAdviceData(
        problem: 'AI Advice',
        summary: cleanAiText(cleanedRaw),
      );
    }

    final recs = ((j['recommendations'] ?? j['interventions']) as List<dynamic>?)
            ?.whereType<Map>()
            .map((e) => AiRecommendation.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        const <AiRecommendation>[];

    final warnings = (j['warnings'] as List<dynamic>?)
            ?.map((w) => cleanAiText(w.toString()))
            .where((w) => w.isNotEmpty)
            .toList() ??
        const <String>[];

    return AiAdviceData(
      problem: cleanAiText((j['problem'] ?? '').toString()),
      summary: cleanAiText((j['summary'] ?? j['diagnosis'] ?? '').toString()),
      urgentAction: cleanAiText((j['urgentAction'] ?? '').toString()),
      recommendations: recs,
      warnings: warnings,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Category styling
// ─────────────────────────────────────────────────────────────────────────
class _CategoryStyle {
  final Color bg, border, text;
  final IconData icon;
  final String label;
  const _CategoryStyle(this.bg, this.border, this.text, this.icon, this.label);
}

_CategoryStyle _categoryStyle(String category) {
  switch (category.toLowerCase()) {
    case 'chemical':
    case 'pesticide':
    case 'fungicide':
      return const _CategoryStyle(AiCardColors.chemBg, AiCardColors.chemBorder,
          AiCardColors.chemText, Icons.science_outlined, 'Chemical');
    case 'organic':
    case 'biological':
      return const _CategoryStyle(AiCardColors.orgBg, AiCardColors.orgBorder,
          AiCardColors.orgText, Icons.eco_outlined, 'Organic');
    case 'cultural':
      return const _CategoryStyle(AiCardColors.cultBg, AiCardColors.cultBorder,
          AiCardColors.cultText, Icons.agriculture_outlined, 'Cultural / Field practice');
    default:
      return const _CategoryStyle(AiCardColors.cultBg, AiCardColors.cultBorder,
          AiCardColors.cultText, Icons.checklist_rounded, 'Recommended action');
  }
}

// ─────────────────────────────────────────────────────────────────────────
// The AI Advice card
// ─────────────────────────────────────────────────────────────────────────
class AiAdviceCard extends StatelessWidget {
  /// e.g. "AI Soil Advisor", "AI Pest Advisor", "AI Disease Advisor".
  final String headerTitle;

  /// e.g. "Powered by Gemini".
  final String headerSubtitle;

  final bool loading;
  final String loadingText;

  /// Parsed advice. Null = nothing fetched yet.
  final AiAdviceData? data;

  /// Shown before the farmer has tapped the button.
  final String emptyStateText;
  final String ctaLabel;

  /// Label for the headline "problem" card, e.g. "Soil status",
  /// "What's attacking your crop", "What this disease does".
  final String problemLabel;
  final IconData problemIcon;

  /// Label above the recommendation cards.
  final String recommendationsLabel;

  final VoidCallback onFetch;

  /// Optional — if provided, each recommendation gets a "Use" button
  /// that the caller can use to pre-fill an intervention form.
  final void Function(AiRecommendation rec)? onUseRecommendation;

  const AiAdviceCard({
    super.key,
    required this.headerTitle,
    this.headerSubtitle = 'Powered by Gemini',
    required this.loading,
    this.loadingText = 'Thinking...',
    required this.data,
    required this.emptyStateText,
    required this.ctaLabel,
    required this.onFetch,
    this.problemLabel = 'The problem',
    this.problemIcon = Icons.info_outline,
    this.recommendationsLabel = 'What to do',
    this.onUseRecommendation,
  });

  bool get _hasResults => data != null && !loading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header (dark green gradient) ──────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AiCardColors.gradA, AiCardColors.gradB],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(14),
              bottom: _hasResults ? Radius.zero : const Radius.circular(14),
            ),
            border: Border.all(color: AiCardColors.brandLight, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(headerTitle,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                      Text(headerSubtitle,
                          style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
              ]),
              if (loading) ...[
                const SizedBox(height: 16),
                Center(
                  child: Column(children: [
                    const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    const SizedBox(height: 10),
                    Text(loadingText, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ]),
                ),
                const SizedBox(height: 4),
              ] else if (!_hasResults) ...[
                const SizedBox(height: 12),
                Text(emptyStateText,
                    style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onFetch,
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: Text(ctaLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AiCardColors.brandDark,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── Results (light background) ─────────────────────────────────
        if (_hasResults)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AiCardColors.resultsBg,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
              border: Border.all(color: AiCardColors.brandLight, width: 1.5),
            ),
            child: _buildResults(data!),
          ),
      ],
    );
  }

  Widget _buildResults(AiAdviceData d) {
    if (d.error != null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _block(
          icon: Icons.error_outline,
          bg: AiCardColors.errorBg,
          border: AiCardColors.errorBorder,
          textColor: AiCardColors.errorText,
          title: 'Something went wrong',
          child: Text(d.error!,
              style: const TextStyle(fontSize: 13.5, height: 1.6, color: AiCardColors.errorText)),
        ),
        const SizedBox(height: 10),
        _refreshLink(),
      ]);
    }

    if (d.isEmptyResult) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('No advice returned. Please try again.',
            style: TextStyle(fontSize: 13.5, color: AiCardColors.textSec, height: 1.6)),
        const SizedBox(height: 10),
        _refreshLink(),
      ]);
    }

    final children = <Widget>[];

    // ── Problem / status card ─────────────────────────────────────────
    if (d.problem.isNotEmpty || d.summary.isNotEmpty) {
      children.add(_block(
        icon: problemIcon,
        bg: AiCardColors.problemBg,
        border: AiCardColors.problemBorder,
        textColor: AiCardColors.problemText,
        title: d.problem.isNotEmpty ? '$problemLabel: ${d.problem}' : problemLabel,
        child: d.summary.isNotEmpty
            ? Text(d.summary,
                style: const TextStyle(fontSize: 14, height: 1.6, color: AiCardColors.textPrimary))
            : const SizedBox.shrink(),
      ));
    }

    // ── Most urgent action ───────────────────────────────────────────
    if (d.urgentAction.isNotEmpty) {
      children.add(const SizedBox(height: 10));
      children.add(_block(
        icon: Icons.bolt,
        bg: AiCardColors.urgentBg,
        border: AiCardColors.urgentBorder,
        textColor: AiCardColors.urgentText,
        title: 'Do this first',
        child: Text(d.urgentAction,
            style: const TextStyle(
                fontSize: 14.5, height: 1.5, color: AiCardColors.textPrimary, fontWeight: FontWeight.w600)),
      ));
    }

    // ── Recommendations ───────────────────────────────────────────────
    if (d.recommendations.isNotEmpty) {
      children.add(const SizedBox(height: 14));
      children.add(Text(recommendationsLabel.toUpperCase(),
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: AiCardColors.textHint, letterSpacing: 0.8)));
      children.add(const SizedBox(height: 8));
      for (var i = 0; i < d.recommendations.length; i++) {
        children.add(_recommendationCard(i + 1, d.recommendations[i]));
        if (i != d.recommendations.length - 1) children.add(const SizedBox(height: 10));
      }
    }

    // ── Warnings ──────────────────────────────────────────────────────
    if (d.warnings.isNotEmpty) {
      children.add(const SizedBox(height: 14));
      children.add(_block(
        icon: Icons.warning_amber_rounded,
        bg: AiCardColors.warnBg,
        border: AiCardColors.warnBorder,
        textColor: AiCardColors.warnText,
        title: 'Important to know',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: d.warnings
              .map((w) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 5),
                        child: Icon(Icons.circle, size: 6, color: AiCardColors.warnBorder),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(w,
                            style: const TextStyle(fontSize: 13.5, height: 1.5, color: AiCardColors.warnText)),
                      ),
                    ]),
                  ))
              .toList(),
        ),
      ));
    }

    children.add(const SizedBox(height: 10));
    children.add(_refreshLink());

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Widget _recommendationCard(int index, AiRecommendation r) {
    final style = _categoryStyle(r.category);
    return Container(
      decoration: BoxDecoration(
        color: AiCardColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: style.border.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with number badge + category chip
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: style.border,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text('$index',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(r.title,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w700, color: AiCardColors.textPrimary)),
              ),
            ]),
          ),

          // Chips: category + dosage
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              _chip(icon: style.icon, label: style.label, bg: style.bg, fg: style.text),
              if (r.dosage.isNotEmpty)
                _chip(icon: Icons.straighten, label: r.dosage, bg: AiCardColors.resultsBg, fg: AiCardColors.textPrimary),
            ]),
          ),

          // Why / How highlights
          if (r.why.isNotEmpty)
            _highlightRow(icon: Icons.lightbulb_outline, label: 'Why', text: r.why),
          if (r.how.isNotEmpty)
            _highlightRow(icon: Icons.build_outlined, label: 'How', text: r.how),

          // Use button
          if (onUseRecommendation != null) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 10, 10),
                child: GestureDetector(
                  onTap: () => onUseRecommendation!(r),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: AiCardColors.brandDark,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Use this',
                        style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ),
          ] else
            const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _highlightRow({required IconData icon, required String label, required String text}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 15, color: AiCardColors.brandMid),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13.5, height: 1.5, color: AiCardColors.textPrimary),
              children: [
                TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: text),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _chip({required IconData icon, required String label, required Color bg, required Color fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: fg),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg)),
      ]),
    );
  }

  Widget _block({
    required IconData icon,
    required Color bg,
    required Color border,
    required Color textColor,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(title,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor)),
          ),
        ]),
        if (child is! SizedBox) ...[
          const SizedBox(height: 8),
          child,
        ],
      ]),
    );
  }

  Widget _refreshLink() {
    return GestureDetector(
      onTap: onFetch,
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.refresh_rounded, size: 13, color: AiCardColors.textHint),
        SizedBox(width: 4),
        Text('Refresh advice',
            style: TextStyle(
                color: AiCardColors.textHint,
                fontSize: 12,
                decoration: TextDecoration.underline,
                decorationColor: AiCardColors.borderDef)),
      ]),
    );
  }
}