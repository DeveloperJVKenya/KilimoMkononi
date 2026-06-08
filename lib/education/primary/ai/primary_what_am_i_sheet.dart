// lib/education/primary/primary_what_am_i_sheet.dart
// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'primary_ai_service.dart';

/// "What am I?" guessing game.
/// AI picks an item from [topic] and gives 3 clues, hardest first.
/// Stars earned: guess after clue 1 = ⭐⭐⭐, clue 2 = ⭐⭐, clue 3 = ⭐
///
/// Usage:
///   showModalBottomSheet(
///     context: context,
///     isScrollControlled: true,
///     backgroundColor: Colors.transparent,
///     builder: (_) => DraggableScrollableSheet(
///       initialChildSize: 0.85,
///       builder: (_, sc) => PrimaryWhatAmISheet(
///         topic: 'Farm Animals', grade: 'Grade 3', accentColor: Color(0xFFE65100)),
///     ),
///   );
class PrimaryWhatAmISheet extends StatefulWidget {
  final String topic, grade;
  final Color  accentColor;
  final PrimaryLanguage language;

  const PrimaryWhatAmISheet({
    super.key,
    required this.topic,
    required this.grade,
    required this.accentColor,
    this.language = PrimaryLanguage.english,
  });

  @override
  State<PrimaryWhatAmISheet> createState() => _PrimaryWhatAmISheetState();
}

class _PrimaryWhatAmISheetState extends State<PrimaryWhatAmISheet> {
  final _service = const PrimaryAiService();

  _WState       _state  = _WState.loading;
  WhatAmIClues? _data;

  int  _cluesShown  = 1;  // 1, 2 or 3
  bool _guessed     = false;
  bool _correct     = false;

  final _guessCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _guessCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _state = _WState.loading; _cluesShown = 1; _guessed = false; _correct = false; _guessCtrl.clear(); });
    final result = await _service.generateWhatAmIClues(
      topic: widget.topic, grade: widget.grade, language: widget.language);
    if (!mounted) return;
    if (result == null) { setState(() => _state = _WState.error); return; }
    setState(() { _data = result; _state = _WState.playing; });
  }

  void _revealNextClue() {
    if (_cluesShown < 3) setState(() => _cluesShown++);
  }

  void _submitGuess() {
    final guess  = _guessCtrl.text.trim().toLowerCase();
    final answer = (_data?.item ?? '').toLowerCase();
    // Fuzzy match: guess contains answer word or answer contains guess word
    final gWords = guess.split(RegExp(r'\W+')).where((w) => w.length > 2).toSet();
    final aWords = answer.split(RegExp(r'\W+')).where((w) => w.length > 2).toSet();
    final hit = gWords.intersection(aWords).isNotEmpty || answer.contains(guess) || guess.contains(answer);
    setState(() { _guessed = true; _correct = hit; });
    FocusScope.of(context).unfocus();
  }

  int get _starsEarned => _correct ? (4 - _cluesShown) : 0; // 3,2,1 or 0

  @override
  Widget build(BuildContext context) {
    final c = widget.accentColor;
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _handle(),
        _header(c),
        const Divider(height: 1, indent: 20, endIndent: 20),
        Flexible(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: switch (_state) {
            _WState.loading => _buildLoading(c),
            _WState.error   => _buildError(c),
            _WState.playing => _buildGame(c),
          },
        )),
      ]),
    );
  }

  Widget _handle() => Center(child: Container(
      margin: const EdgeInsets.only(top: 12, bottom: 4), width: 36, height: 4,
      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))));

  Widget _header(Color c) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(Icons.help_outline_rounded, color: c, size: 20)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('What am I? 🤔', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c)),
        Text(widget.topic, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      ])),
      IconButton(icon: const Icon(Icons.close, size: 20), color: Colors.grey.shade400,
          onPressed: () => Navigator.pop(context)),
    ]),
  );

  Widget _buildLoading(Color c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Column(children: [
      SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 3, color: c)),
      const SizedBox(height: 16),
      Text('Getting your clues ready…', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
    ]),
  );

  Widget _buildError(Color c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(children: [
      Icon(Icons.wifi_off_rounded, size: 44, color: Colors.grey.shade300),
      const SizedBox(height: 12),
      Text('Could not load. Check your connection.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600), textAlign: TextAlign.center),
      const SizedBox(height: 20),
      ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh, size: 16),
        label: const Text('Try again'),
        style: ElevatedButton.styleFrom(backgroundColor: c, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
    ]),
  );

  Widget _buildGame(Color c) {
    final data = _data!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Instruction
      Center(child: Text('Read the clues and guess the item!',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500))),
      const SizedBox(height: 16),

      // Clue cards
      ...List.generate(_cluesShown, (i) => _ClueCard(
        number: i + 1,
        text: data.clues[i],
        color: c,
        isNew: i == _cluesShown - 1 && !_guessed,
      )),

      // "Show next clue" button (if not all shown and not guessed)
      if (!_guessed && _cluesShown < 3) ...[
        const SizedBox(height: 4),
        _HintButton(
          label: 'Show clue ${_cluesShown + 1} of 3 (costs 1 star)',
          color: c,
          onTap: _revealNextClue,
        ),
        const SizedBox(height: 12),
      ],

      // Guess input (only while playing)
      if (!_guessed) ...[
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: c.withOpacity(0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.withOpacity(0.15))),
          child: Column(children: [
            Text('I think I am…', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(
                controller: _guessCtrl,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submitGuess(),
                decoration: InputDecoration(
                  hintText: 'Type your answer…',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                  filled: true, fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 14),
              )),
              const SizedBox(width: 8),
              InkWell(
                onTap: _submitGuess,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 16)),
              ),
            ]),
          ]),
        ),
      ],

      // Result
      if (_guessed) ...[
        const SizedBox(height: 16),
        _ResultCard(
          correct: _correct,
          stars: _starsEarned,
          answer: data.item,
          accentColor: c,
        ),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('New item'),
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
}

class _ClueCard extends StatelessWidget {
  final int number;
  final String text;
  final Color color;
  final bool isNew;
  const _ClueCard({required this.number, required this.text, required this.color, required this.isNew});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: isNew ? color.withOpacity(0.08) : Colors.grey.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: isNew ? color.withOpacity(0.3) : Colors.grey.shade200,
          width: isNew ? 1.5 : 1),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
            color: isNew ? color : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8)),
        child: Center(child: Text('$number',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                color: isNew ? Colors.white : Colors.grey.shade500))),
      ),
      const SizedBox(width: 12),
      Expanded(child: Text(text,
          style: TextStyle(fontSize: 14, height: 1.45,
              color: isNew ? const Color(0xFF1A1A1A) : Colors.grey.shade600))),
    ]),
  );
}

class _HintButton extends StatelessWidget {
  final String label; final Color color; final VoidCallback onTap;
  const _HintButton({required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amber.shade200)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.lightbulb_outline, color: Colors.amber.shade700, size: 16),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.amber.shade800,
            fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

class _ResultCard extends StatelessWidget {
  final bool correct; final int stars; final String answer; final Color accentColor;
  const _ResultCard({required this.correct, required this.stars, required this.answer, required this.accentColor});
  @override
  Widget build(BuildContext context) {
    final starRow = Row(mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) => Icon(
            i < stars ? Icons.star_rounded : Icons.star_border_rounded,
            color: i < stars ? Colors.amber.shade600 : Colors.grey.shade300, size: 36)));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: correct ? Colors.green.shade50 : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: correct ? Colors.green.shade200 : Colors.orange.shade200)),
      child: Column(children: [
        starRow,
        const SizedBox(height: 10),
        Text(correct ? '🎉 Well done!' : '🤔 Not quite!',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                color: correct ? Colors.green.shade800 : Colors.orange.shade800)),
        const SizedBox(height: 6),
        Text.rich(TextSpan(children: [
          TextSpan(text: 'The answer was: ', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          TextSpan(text: answer, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
              color: accentColor)),
        ])),
      ]),
    );
  }
}

enum _WState { loading, error, playing }