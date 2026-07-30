// lib/education/widgets/edu_ai_advice_card.dart
//
// Education-specific AI advice card.
//
// PURPOSE
//  • Replaces the three duplicated _AiMarkdownCard classes + _showAiResultDialog
//    pattern that exists identically in disease_data_input.dart, pest_data_input.dart
//    and field_data_input.dart.
//  • Completely independent of the enterprise widget at
//    lib/widgets/ai_advice_card.dart — same philosophy, different brand (teal
//    for education vs green for enterprise) and education-specific features
//    (teacher vs student mode, Socratic prompt display, grading context).
//
// PUBLIC API
//  • [showEduAiResultDialog]  — call this wherever _showAiResultDialog was called.
//  • [EduAiResultCard]        — inline card variant (e.g. inside EduAiPhotoTab).
//  • [EduAiMarkdownContent]   — the raw markdown renderer, usable standalone.
//
// HOW TO USE (dialog)
//   await showEduAiResultDialog(
//     context: context,
//     title: '🤖 AI Disease Analysis: Gray Leaf Spot',
//     markdownResult: result,    // raw Gemini text reply
//     mode: EduAiMode.teacher,   // or .student
//   );
//
// HOW TO USE (inline photo result card — replaces _buildResultSection)
//   EduAiResultCard(
//     result: geminiDiagResult,
//     isPest: widget.isPest,
//     onUseResult: (prefill) { ... },
//   )
//

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Palette — teal for education, distinct from enterprise green
// ─────────────────────────────────────────────────────────────────────────────
class _EduColors {
  _EduColors._();

  static const brand     = Color(0xFF00695C);  // teal 800
  static const brandLight= Color(0xFF80CBC4);  // teal 200
  static const gradA     = Color(0xFF004D40);  // teal 900
  static const gradB     = Color(0xFF00796B);  // teal 700

  static const pageBg    = Color(0xFFF4F9F8);

  // Section colours — cycle through these for numbered sections
  static const List<Color> sectionBg = [
    Color(0xFFE0F2F1), // teal 50
    Color(0xFFE3F2FD), // blue 50
    Color(0xFFFFF8E1), // amber 50
    Color(0xFFFCE4EC), // pink 50
    Color(0xFFEDE7F6), // deep purple 50
    Color(0xFFE8F5E9), // green 50
  ];
  static const List<Color> sectionBorder = [
    Color(0xFF00897B),
    Color(0xFF1565C0),
    Color(0xFFF9A825),
    Color(0xFFC62828),
    Color(0xFF6A1B9A),
    Color(0xFF2E7D32),
  ];
  static const List<Color> sectionTitle = [
    Color(0xFF004D40),
    Color(0xFF0D47A1),
    Color(0xFFE65100),
    Color(0xFFB71C1C),
    Color(0xFF4A148C),
    Color(0xFF1B5E20),
  ];

  static const healthyBg   = Color(0xFFE8F5E9);
}

// ─────────────────────────────────────────────────────────────────────────────
// Mode enum — controls header badge and some copy
// ─────────────────────────────────────────────────────────────────────────────
enum EduAiMode { teacher, student }

// ─────────────────────────────────────────────────────────────────────────────
// Text cleanup — strips raw markdown symbols before display
// ─────────────────────────────────────────────────────────────────────────────
String _cleanEduText(String text) => text
    .replaceAll(RegExp(r'\*{3,}'), '')
    .replaceAll(RegExp(r'#+\s*'), '')
    .replaceAll(RegExp(r'_{2,}'), '')
    .replaceAll(RegExp(r'/{2,}'), '')
    .trim();

// ─────────────────────────────────────────────────────────────────────────────
// showEduAiResultDialog — drop-in replacement for _showAiResultDialog
// ─────────────────────────────────────────────────────────────────────────────
Future<void> showEduAiResultDialog({
  required BuildContext context,
  required String title,
  required String markdownResult,
  EduAiMode mode = EduAiMode.teacher,
}) {
  // Strip the emoji prefix the caller sometimes adds — we show it with our own icon
  final cleanTitle = title.replaceFirst(RegExp(r'^[🤖\s]+'), '').trim();

  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_EduColors.gradA, _EduColors.gradB],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.psychology_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(cleanTitle,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          mode == EduAiMode.teacher ? 'Teacher view' : 'Student feedback',
                          style: const TextStyle(color: Colors.white70, fontSize: 10,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text('Powered by Gemini',
                          style: TextStyle(color: Colors.white54, fontSize: 10)),
                    ]),
                  ]),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white70, size: 18),
                  ),
                ),
              ]),
            ),

            // ── Body ────────────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: EduAiMarkdownContent(
                  content: markdownResult,
                  mode: mode,
                ),
              ),
            ),

            // ── Footer ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              color: _EduColors.pageBg,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Got it!',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _EduColors.brand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// EduAiMarkdownContent — replaces _AiMarkdownCard in all three edu data inputs
//
// Parses Gemini's markdown into coloured, icon-labelled section cards.
// Supports: ## headings, numbered lists, bullet lists, **bold**, plain text.
// Never shows raw *, **, ##, //, /// to the student or teacher.
// ─────────────────────────────────────────────────────────────────────────────
class EduAiMarkdownContent extends StatelessWidget {
  final String content;
  final EduAiMode mode;

  const EduAiMarkdownContent({
    super.key,
    required this.content,
    this.mode = EduAiMode.teacher,
  });

  @override
  Widget build(BuildContext context) {
    final sections = _parseSections(content);
    if (sections.isEmpty) {
      return _plainText(_cleanEduText(content));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections.asMap().entries.map((entry) {
        final idx = entry.key;
        final s   = entry.value;

        // Intro block (text before first heading)
        if (s['type'] == 'intro') {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: _EduColors.pageBg,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: _EduColors.brandLight, width: 1.5),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline, color: _EduColors.brand, size: 17),
                const SizedBox(width: 9),
                Expanded(child: _renderBody(s['body'] ?? '')),
              ]),
            ),
          );
        }

        // Numbered section
        final ci = idx % _EduColors.sectionBg.length;
        final icon = _sectionIcon(s['title'] ?? '');
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            decoration: BoxDecoration(
              color: _EduColors.sectionBg[ci],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _EduColors.sectionBorder[ci].withValues(alpha: 0.45),
                  width: 1.5),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Section title bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                decoration: BoxDecoration(
                  color: _EduColors.sectionBorder[ci].withValues(alpha: 0.10),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                ),
                child: Row(children: [
                  Icon(icon, color: _EduColors.sectionTitle[ci], size: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _cleanTitle(s['title'] ?? ''),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _EduColors.sectionTitle[ci]),
                    ),
                  ),
                ]),
              ),
              // Section body
              Padding(
                padding: const EdgeInsets.fromLTRB(13, 10, 13, 13),
                child: _renderBody(s['body'] ?? ''),
              ),
            ]),
          ),
        );
      }).toList(),
    );
  }

  // ── Section parser ────────────────────────────────────────────────────────
  List<Map<String, String>> _parseSections(String raw) {
    final lines    = raw.split('\n');
    final sections = <Map<String, String>>[];
    String? currentTitle;
    final bodyBuf = StringBuffer();

    void flush() {
      final body = bodyBuf.toString().trim();
      if (body.isEmpty && currentTitle == null) return;
      sections.add({
        'type':  currentTitle == null ? 'intro' : 'section',
        'title': currentTitle ?? '',
        'body':  body,
      });
      bodyBuf.clear();
      currentTitle = null;
    }

    for (final line in lines) {
      if (RegExp(r'^#{1,3}\s').hasMatch(line)) {
        flush();
        currentTitle = line.replaceFirst(RegExp(r'^#+\s*'), '');
      } else {
        bodyBuf.writeln(line);
      }
    }
    flush();
    return sections;
  }

  // ── Body renderer ─────────────────────────────────────────────────────────
  Widget _renderBody(String text) {
    final lines   = text.split('\n');
    final widgets = <Widget>[];

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) { widgets.add(const SizedBox(height: 4)); continue; }

      // Numbered item
      final numMatch = RegExp(r'^(\d+)\.\s+(.+)').firstMatch(line);
      if (numMatch != null) {
        widgets.add(_bulletRow(
          '${numMatch.group(1)}.',
          numMatch.group(2)!,
          numbered: true,
        ));
        continue;
      }

      // Bullet item
      if (line.startsWith('- ') || line.startsWith('* ') || line.startsWith('• ')) {
        widgets.add(_bulletRow(
          '•',
          line.replaceFirst(RegExp(r'^[-*•]\s+'), ''),
          numbered: false,
        ));
        continue;
      }

      // Standalone **bold line**
      if (line.startsWith('**') && line.endsWith('**') && line.length > 4) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            line.substring(2, line.length - 2),
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1A2E2C)),
          ),
        ));
        continue;
      }

      // Plain text with possible inline bold
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: _inlineBold(line),
      ));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  Widget _bulletRow(String marker, String text, {required bool numbered}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: numbered ? 24 : 16,
            child: Text(
              marker,
              style: TextStyle(
                fontSize: 13,
                fontWeight: numbered ? FontWeight.w700 : FontWeight.normal,
                color: numbered ? _EduColors.brand : Colors.black54,
              ),
            ),
          ),
          Expanded(child: _inlineBold(text)),
        ]),
      );

  Widget _inlineBold(String text) {
    final spans = <TextSpan>[];
    final re    = RegExp(r'\*\*(.+?)\*\*');
    int last    = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      spans.add(TextSpan(
        text: m.group(1),
        style: const TextStyle(
            fontWeight: FontWeight.w700, color: Color(0xFF1A2E2C)),
      ));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return RichText(
      text: TextSpan(
        style: const TextStyle(
            fontSize: 13.5, color: Color(0xFF263238), height: 1.5),
        children: spans,
      ),
    );
  }

  Widget _plainText(String t) => Text(
    t,
    style: const TextStyle(fontSize: 13.5, color: Color(0xFF263238), height: 1.5),
  );

  String _cleanTitle(String t) =>
      t.replaceAll(RegExp(r'^[#*0-9.]+\s*'), '').trim();

  // Maps section title keywords → icons for quick visual scanning
  IconData _sectionIcon(String title) {
    final t = title.toLowerCase();
    if (t.contains('chemical') || t.contains('fungicid') || t.contains('pesticide')) {
      return Icons.science_outlined;
    }
    if (t.contains('organic') || t.contains('bio') || t.contains('natural')) {
      return Icons.eco_outlined;
    }
    if (t.contains('cultural') || t.contains('prevent') || t.contains('practice')) {
      return Icons.agriculture_outlined;
    }
    if (t.contains('diagnos') || t.contains('symptom') || t.contains('sign')) {
      return Icons.search;
    }
    if (t.contains('soil') || t.contains('nutrient') || t.contains('fertil')) {
      return Icons.grass_outlined;
    }
    if (t.contains('safety') || t.contains('warning') || t.contains('caution')) {
      return Icons.warning_amber_outlined;
    }
    if (t.contains('recommend') || t.contains('action') || t.contains('control')) {
      return Icons.recommend_outlined;
    }
    if (t.contains('question') || t.contains('reflect') || t.contains('socratic')) {
      return Icons.psychology_outlined;
    }
    if (t.contains('assessment') || t.contains('evaluat') || t.contains('feedback')) {
      return Icons.grading_outlined;
    }
    if (t.contains('urgent') || t.contains('immediate') || t.contains('do now')) {
      return Icons.bolt;
    }
    if (t.contains('rotation') || t.contains('next crop')) {
      return Icons.loop;
    }
    if (t.contains('biology') || t.contains('life cycle') || t.contains('pathogen')) {
      return Icons.biotech_outlined;
    }
    if (t.contains('economic') || t.contains('threshold')) {
      return Icons.trending_up;
    }
    if (t.contains('identification') || t.contains('identify')) {
      return Icons.center_focus_strong_outlined;
    }
    return Icons.info_outline;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EduAiResultCard — inline result card for EduAiPhotoTab
//
// Replaces _buildResultSection in edu_ai_photo_tab.dart.
// Takes a GeminiDiagResult-like plain map so this widget has no dependency
// on gemini_vision_helper.dart (keeps the widget self-contained).
// ─────────────────────────────────────────────────────────────────────────────

/// Lightweight result model — populated from GeminiDiagResult in the caller.
class EduDiagResult {
  final String name;
  final String type;       // 'pest' | 'disease'
  final String confidence; // 'high' | 'medium' | 'low'
  final String description;
  final String recommendation;
  final List<String> alternatives;
  final bool isHealthy;
  final bool isRejected;
  final String rejectionReason;
  final String imageSubject;

  const EduDiagResult({
    required this.name,
    required this.type,
    this.confidence    = 'high',
    this.description   = '',
    this.recommendation= '',
    this.alternatives  = const [],
    this.isHealthy     = false,
    this.isRejected    = false,
    this.rejectionReason = '',
    this.imageSubject    = '',
  });

  Color get confColor {
    switch (confidence.toLowerCase()) {
      case 'high':   return const Color(0xFF2E7D32);
      case 'medium': return const Color(0xFFE65100);
      default:       return const Color(0xFFC62828);
    }
  }
  String get confLabel => confidence.isEmpty ? '' : confidence[0].toUpperCase() + confidence.substring(1);
}

class EduAiResultCard extends StatelessWidget {
  final EduDiagResult result;
  final bool isPest;

  /// Callback when teacher/student taps "Use Result" — receives prefill map.
  final void Function(Map<String, String> prefill)? onUseResult;

  /// Crop that was selected in the photo tab — included in prefill.
  final String? selectedCrop;

  const EduAiResultCard({
    super.key,
    required this.result,
    required this.isPest,
    this.onUseResult,
    this.selectedCrop,
  });

  @override
  Widget build(BuildContext context) {
    final r = result;

    if (r.isHealthy) {
      return _healthyCard();
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Medium confidence notice
      if (r.confidence.toLowerCase() == 'medium')
        _noticeBox(
          icon: Icons.info_outline,
          color: const Color(0xFFE65100),
          bg: const Color(0xFFFFF3E0),
          borderColor: const Color(0xFFFFCC80),
          text: 'Medium confidence — verify with a local agronomist before applying any treatment.',
        ),

      // AI disclaimer
      _noticeBox(
        icon: Icons.auto_awesome,
        color: _EduColors.brand,
        bg: _EduColors.pageBg,
        borderColor: _EduColors.brandLight,
        text: 'AI result — a guide, not a guarantee. Always verify with field observation.',
      ),
      const SizedBox(height: 12),

      // ── Main result card ──────────────────────────────────────────────────
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _EduColors.brandLight, width: 2),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Title bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_EduColors.gradA, _EduColors.gradB],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(children: [
              Icon(r.type == 'pest' ? Icons.pest_control_outlined : Icons.biotech_outlined,
                  color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(r.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                      color: Colors.white))),
              // Confidence chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                ),
                child: Text(r.confLabel,
                    style: const TextStyle(fontSize: 11, color: Colors.white,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── What AI sees ──────────────────────────────────────────
              if (r.description.isNotEmpty) ...[
                _sectionHeader(Icons.search, 'What the AI sees'),
                const SizedBox(height: 6),
                Text(r.description,
                    style: const TextStyle(fontSize: 13.5, height: 1.55,
                        color: Color(0xFF263238))),
              ],

              // ── Recommendation highlight card ─────────────────────────
              if (r.recommendation.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFCC80)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.lightbulb_outline, size: 17,
                        color: Color(0xFFE65100)),
                    const SizedBox(width: 9),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Recommended action',
                              style: TextStyle(fontSize: 12,
                                  fontWeight: FontWeight.w700, color: Color(0xFFE65100))),
                          const SizedBox(height: 4),
                          Text(r.recommendation,
                              style: const TextStyle(fontSize: 13.5, height: 1.5,
                                  color: Color(0xFF3E2723))),
                        ])),
                  ]),
                ),
              ],

              // ── Other possibilities ───────────────────────────────────
              if (r.alternatives.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FBE7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFC5E1A5)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.compare_arrows, size: 15, color: Color(0xFF558B2F)),
                    const SizedBox(width: 7),
                    Expanded(child: Text(
                      'Other possibilities: ${r.alternatives.join(', ')}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF33691E)),
                    )),
                  ]),
                ),
              ],
            ]),
          ),
        ]),
      ),

      // ── Use result button ─────────────────────────────────────────────────
      if (onUseResult != null) ...[
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.auto_fix_high, size: 18),
            label: Text(
              'Use Result & Go to ${isPest ? "Pest Data" : "Disease Data"} Tab',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _EduColors.brand,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () => onUseResult!({
              'crop':  selectedCrop ?? '',
              'stage': '',
              'name':  r.name,
              'type':  r.type,
            }),
          ),
        ),
      ],
      const SizedBox(height: 40),
    ]);
  }

  Widget _healthyCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _EduColors.healthyBg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF81C784)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 28),
      const SizedBox(width: 12),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Plant appears healthy!',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                color: Color(0xFF1B5E20))),
        SizedBox(height: 5),
        Text('No signs of pest or disease damage were detected in this photo.',
            style: TextStyle(fontSize: 13.5, height: 1.5, color: Color(0xFF2E7D32))),
      ])),
    ]),
  );

  Widget _noticeBox({
    required IconData icon,
    required Color color,
    required Color bg,
    required Color borderColor,
    required String text,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: borderColor),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 8),
          Expanded(child: Text(text,
              style: TextStyle(fontSize: 12.5, color: color, height: 1.4))),
        ]),
      );

  Widget _sectionHeader(IconData icon, String label) =>
      Row(children: [
        Icon(icon, size: 15, color: _EduColors.brand),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                color: _EduColors.brand)),
      ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// EduAiLoadingButton — standardised "Ask AI" button with built-in loading state
//
// Usage:
//   EduAiLoadingButton(
//     loading: _aiLoading,
//     label: '🤖 AI Analysis for this Disease',
//     onPressed: () => _runAiDiseaseAnalysis(null),
//   )
// ─────────────────────────────────────────────────────────────────────────────
class EduAiLoadingButton extends StatelessWidget {
  final bool loading;
  final String label;
  final VoidCallback? onPressed;

  /// Filled style (used in photo tab). Defaults to outlined (data input forms).
  final bool filled;

  const EduAiLoadingButton({
    super.key,
    required this.loading,
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final icon = loading
        ? const SizedBox(width: 14, height: 14,
            child: CircularProgressIndicator(strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Color(0xFF00695C))))
        : const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF00695C));

    final child = Row(mainAxisSize: MainAxisSize.min, children: [
      icon,
      const SizedBox(width: 8),
      Text(loading ? 'Analysing…' : label,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600,
              color: Color(0xFF00695C))),
    ]);

    if (filled) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: _EduColors.brand,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (loading)
              const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            else
              const Icon(Icons.auto_awesome, size: 17, color: Colors.white),
            const SizedBox(width: 8),
            Text(loading ? 'Analysing…' : label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ]),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
              color: loading ? Colors.grey.shade300 : _EduColors.brand,
              width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 11),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
        child: child,
      ),
    );
  }
}