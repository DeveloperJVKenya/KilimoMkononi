// lib/education/primary/primary_spot_mistake.dart
// ignore_for_file: unused_field, deprecated_member_use
import 'package:flutter/material.dart';
import 'primary_ai_service.dart';

/// A "Spot the Mistake" game card. Generates an AI sentence with one error,
/// asks True/False, then (if False) shows the wrong word highlighted.
///
/// Drop anywhere in a primary topic screen's expanded card content OR use
/// it as a standalone bottom sheet.
///
/// Example as a button that launches a bottom sheet:
///   PrimarySpotMistakeButton(
///     topic: 'Weeds & Pests',
///     grade: 'Grade 4',
///     accentColor: Color(0xFF558B2F),
///   )
class PrimarySpotMistakeButton extends StatelessWidget {
  final String topic;
  final String grade;
  final Color  accentColor;

  const PrimarySpotMistakeButton({
    super.key,
    required this.topic,
    required this.grade,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = accentColor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _SpotMistakeSheet(
            topic: topic,
            grade: grade,
            accentColor: c,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: BoxDecoration(
              color: c.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.withOpacity(0.2))),
          child: Row(children: [
            Text('🔍', style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Spot the Mistake!',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c)),
              Text('Can you find the one wrong word?',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ])),
            Icon(Icons.arrow_forward_ios, size: 14, color: c.withOpacity(0.5)),
          ]),
        ),
      ),
    );
  }
}

// ─── Bottom sheet ─────────────────────────────────────────────────────────

class _SpotMistakeSheet extends StatefulWidget {
  final String topic;
  final String grade;
  final Color  accentColor;
  const _SpotMistakeSheet({required this.topic, required this.grade, required this.accentColor});

  @override
  State<_SpotMistakeSheet> createState() => _SpotMistakeSheetState();
}

class _SpotMistakeSheetState extends State<_SpotMistakeSheet> {
  final _service = const PrimaryAiService();

  _SMState       _state = _SMState.loading;
  SpotMistakeItem? _item;
  String?        _errorMsg;

  // Phase 2: after True/False
  bool?          _answeredTrue;  // true if pupil chose TRUE, false if FALSE
  bool           _revealed      = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _state = _SMState.loading; _answeredTrue = null; _revealed = false; });
    final item = await _service.generateSpotMistake(
      topic: widget.topic,
      grade: widget.grade,
    );
    if (!mounted) return;
    if (item == null) {
      setState(() { _state = _SMState.error; });
    } else {
      setState(() { _item = item; _state = _SMState.question; });
    }
  }

  void _onAnswer(bool choseTrue) {
    // The sentence always contains a mistake → correct answer is FALSE
    setState(() { _answeredTrue = choseTrue; _revealed = true; });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.accentColor;
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Drag handle
        Center(child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)))),
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 16, 0),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.search_rounded, color: c, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Spot the Mistake! 🔍',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c)),
              Text(widget.topic,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ])),
            IconButton(icon: const Icon(Icons.close, size: 20),
                color: Colors.grey.shade400,
                onPressed: () => Navigator.pop(context)),
          ]),
        ),
        const Divider(height: 20, indent: 20, endIndent: 20),

        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: switch (_state) {
              _SMState.loading  => _buildLoading(c),
              _SMState.error    => _buildError(c),
              _SMState.question => _buildQuestion(c),
            },
          ),
        ),
      ]),
    );
  }

  Widget _buildLoading(Color c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(children: [
      SizedBox(width: 32, height: 32,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: c)),
      const SizedBox(height: 14),
      Text('Generating a tricky sentence…',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
    ]),
  );

  Widget _buildError(Color c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Column(children: [
      Icon(Icons.wifi_off_rounded, size: 44, color: Colors.grey.shade300),
      const SizedBox(height: 12),
      const Text('Could not load. Check your connection.',
          style: TextStyle(fontSize: 13), textAlign: TextAlign.center),
      const SizedBox(height: 20),
      ElevatedButton.icon(onPressed: _load,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Try again'),
          style: ElevatedButton.styleFrom(backgroundColor: c, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
    ]),
  );

  Widget _buildQuestion(Color c) {
    final item = _item!;
    // Highlight the wrong word in the sentence once revealed
    final sentenceWidget = _revealed
        ? _highlightWord(item.sentence, item.wrongWord, c)
        : Text(item.sentence,
            style: const TextStyle(fontSize: 16, height: 1.6, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center);

    final correctAnswer = false; // sentence always has a mistake
    final userWasRight  = _revealed && (_answeredTrue == correctAnswer); // user said FALSE

    return Column(children: [
      // Instruction
      Text('Is this sentence TRUE or FALSE?',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          textAlign: TextAlign.center),
      const SizedBox(height: 14),

      // Sentence box
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: _revealed
                ? (userWasRight ? Colors.green.shade50 : Colors.red.shade50)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: _revealed
                    ? (userWasRight ? Colors.green.shade300 : Colors.red.shade200)
                    : Colors.grey.shade200)),
        child: sentenceWidget,
      ),
      const SizedBox(height: 20),

      // True / False buttons (disabled after answering)
      if (!_revealed) ...[
        Row(children: [
          Expanded(child: _TFButton(
            label: 'TRUE ✅',
            color: Colors.green,
            onTap: () => _onAnswer(true),
          )),
          const SizedBox(width: 12),
          Expanded(child: _TFButton(
            label: 'FALSE ❌',
            color: Colors.red,
            onTap: () => _onAnswer(false),
          )),
        ]),
      ],

      // Result feedback
      if (_revealed) ...[
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: userWasRight ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: userWasRight ? Colors.green.shade200 : Colors.orange.shade200)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(userWasRight ? '🎉 Well done!' : '🤔 Not quite!',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold,
                      color: userWasRight ? Colors.green.shade800 : Colors.orange.shade800)),
            ]),
            const SizedBox(height: 8),
            Text.rich(TextSpan(children: [
              TextSpan(text: 'The mistake was: ',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
              TextSpan(text: '"${item.wrongWord}"',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                      color: Colors.red, decoration: TextDecoration.lineThrough)),
              TextSpan(text: '  →  ',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
              TextSpan(text: '"${item.correction}"',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                      color: Colors.green.shade700)),
            ])),
            const SizedBox(height: 8),
            Text(item.explanation,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4)),
          ]),
        ),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('New sentence'),
            style: OutlinedButton.styleFrom(
                foregroundColor: c, side: BorderSide(color: c),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          )),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Done'),
            style: ElevatedButton.styleFrom(
                backgroundColor: c, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          )),
        ]),
      ],
    ]);
  }

  /// Builds a RichText that bolds & colours the [wrongWord] within [sentence].
  Widget _highlightWord(String sentence, String wrongWord, Color c) {
    final lower = sentence.toLowerCase();
    final lowerWord = wrongWord.toLowerCase();
    final idx = lower.indexOf(lowerWord);
    if (idx == -1) {
      return Text(sentence,
          style: const TextStyle(fontSize: 16, height: 1.6, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center);
    }
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: sentence.substring(0, idx),
            style: const TextStyle(fontSize: 16, height: 1.6, fontWeight: FontWeight.w500)),
        TextSpan(text: sentence.substring(idx, idx + wrongWord.length),
            style: const TextStyle(fontSize: 16, height: 1.6, fontWeight: FontWeight.bold,
                color: Colors.red, decoration: TextDecoration.lineThrough)),
        TextSpan(text: sentence.substring(idx + wrongWord.length),
            style: const TextStyle(fontSize: 16, height: 1.6, fontWeight: FontWeight.w500)),
      ]),
      textAlign: TextAlign.center,
    );
  }
}

class _TFButton extends StatelessWidget {
  final String label;
  final MaterialColor  color;
  final VoidCallback onTap;
  const _TFButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => ElevatedButton(
    onPressed: onTap,
    style: ElevatedButton.styleFrom(
        backgroundColor: color.shade50,
        foregroundColor: color.shade800,
        elevation: 0,
        side: BorderSide(color: color.withOpacity(0.2)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
  );
}

enum _SMState { loading, error, question }