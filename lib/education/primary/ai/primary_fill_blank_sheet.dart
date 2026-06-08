// lib/education/primary/primary_fill_blank_sheet.dart
// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'primary_ai_service.dart';

/// Fill-in-the-blank activity.
/// Shows a sentence with a blank "___", three word chips to choose from.
/// Child taps a word to place it. Colour feedback + explanation after.
///
/// Usage:
///   showModalBottomSheet(
///     context: context,
///     isScrollControlled: true,
///     backgroundColor: Colors.transparent,
///     builder: (_) => DraggableScrollableSheet(
///       initialChildSize: 0.75,
///       builder: (_, sc) => PrimaryFillBlankSheet(
///         topic: 'Farming Tools', grade: 'Grade 3',
///         accentColor: Color(0xFFBF360C)),
///     ),
///   );
class PrimaryFillBlankSheet extends StatefulWidget {
  final String topic, grade;
  final Color  accentColor;
  final PrimaryLanguage language;

  const PrimaryFillBlankSheet({
    super.key,
    required this.topic,
    required this.grade,
    required this.accentColor,
    this.language = PrimaryLanguage.english,
  });

  @override
  State<PrimaryFillBlankSheet> createState() => _PrimaryFillBlankSheetState();
}

class _PrimaryFillBlankSheetState extends State<PrimaryFillBlankSheet> {
  final _service = const PrimaryAiService();

  _FBState      _state = _FBState.loading;
  FillBlankItem? _item;
  int?          _selectedIndex;
  bool          _answered = false;
  int           _streak   = 0;      // correct answers in a row this session
  int           _total    = 0;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _state = _FBState.loading; _selectedIndex = null; _answered = false; });
    final result = await _service.generateFillBlank(
      topic: widget.topic, grade: widget.grade, language: widget.language);
    if (!mounted) return;
    if (result == null) { setState(() => _state = _FBState.error); return; }
    setState(() { _item = result; _state = _FBState.question; });
  }

  void _onChoice(int idx) {
    if (_answered) return;
    final correct = idx == _item!.correctIndex;
    setState(() {
      _selectedIndex = idx;
      _answered      = true;
      _total++;
      if (correct) {
        _streak++;
      } else {
        _streak = 0;
      }
    });
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
        _handle(),
        _header(c),
        const Divider(height: 1, indent: 20, endIndent: 20),
        Flexible(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: switch (_state) {
            _FBState.loading  => _buildLoading(c),
            _FBState.error    => _buildError(c),
            _FBState.question => _buildQuestion(c),
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
        child: Icon(Icons.text_fields_rounded, color: c, size: 20)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Fill in the blank 📝', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c)),
        Text(widget.topic, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      ])),
      if (_total > 0)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.local_fire_department_rounded, color: c, size: 14),
            const SizedBox(width: 4),
            Text('$_streak streak', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c)),
          ]),
        ),
      IconButton(icon: const Icon(Icons.close, size: 20), color: Colors.grey.shade400,
          onPressed: () => Navigator.pop(context)),
    ]),
  );

  Widget _buildLoading(Color c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Column(children: [
      SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 3, color: c)),
      const SizedBox(height: 16),
      Text('Writing your sentence…', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
    ]),
  );

  Widget _buildError(Color c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(children: [
      Icon(Icons.wifi_off_rounded, size: 44, color: Colors.grey.shade300),
      const SizedBox(height: 12),
      const Text('Could not load. Check your connection.',
          style: TextStyle(fontSize: 13), textAlign: TextAlign.center),
      const SizedBox(height: 20),
      ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh, size: 16),
        label: const Text('Try again'),
        style: ElevatedButton.styleFrom(backgroundColor: c, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
    ]),
  );

  Widget _buildQuestion(Color c) {
    final item = _item!;
    // Split sentence around "___" for animated blank
    final parts = item.sentence.split('___');
    final before = parts.isNotEmpty ? parts[0] : '';
    final after  = parts.length > 1 ? parts[1] : '';

    final selectedWord = _selectedIndex != null ? item.choices[_selectedIndex!] : null;
    final isCorrect    = _answered && _selectedIndex == item.correctIndex;

    return Column(children: [
      // Sentence display
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: _answered
                ? (isCorrect ? Colors.green.shade50 : Colors.red.shade50)
                : c.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: _answered
                    ? (isCorrect ? Colors.green.shade300 : Colors.red.shade200)
                    : c.withOpacity(0.15),
                width: 1.5)),
        child: Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(before, style: const TextStyle(fontSize: 17, height: 1.5)),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _answered && selectedWord != null
                ? Container(
                    key: ValueKey(selectedWord),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                        color: isCorrect ? Colors.green.shade100 : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: isCorrect ? Colors.green.shade400 : Colors.red.shade300)),
                    child: Text(selectedWord,
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
                            color: isCorrect ? Colors.green.shade800 : Colors.red.shade800)),
                  )
                : Container(
                    key: const ValueKey('blank'),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 80, height: 28,
                    decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: c, width: 2))),
                    child: Center(child: Text('     ',
                        style: TextStyle(fontSize: 17, color: c, fontWeight: FontWeight.bold))),
                  ),
          ),
          Text(after, style: const TextStyle(fontSize: 17, height: 1.5)),
        ]),
      ),
      const SizedBox(height: 20),

      // Word choices
      Text('Tap the correct word:', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: item.choices.asMap().entries.map((e) {
        final idx  = e.key;
        final word = e.value;
        Color bg, border, textC;
        if (!_answered) {
          bg = c.withOpacity(0.08); border = c.withOpacity(0.25); textC = c;
        } else if (idx == item.correctIndex) {
          bg = Colors.green.shade50; border = Colors.green.shade400; textC = Colors.green.shade800;
        } else if (idx == _selectedIndex) {
          bg = Colors.red.shade50; border = Colors.red.shade300; textC = Colors.red.shade800;
        } else {
          bg = Colors.grey.shade50; border = Colors.grey.shade200; textC = Colors.grey.shade400;
        }
        return GestureDetector(
          onTap: _answered ? null : () => _onChoice(idx),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 5),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border, width: 1.5)),
            child: Text(word, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textC)),
          ),
        );
      }).toList()),

      // Explanation after answering
      if (_answered) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.amber.shade50, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade200)),
          child: Row(children: [
            const Text('💡', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Expanded(child: Text(item.explanation,
                style: TextStyle(fontSize: 13, color: Colors.amber.shade900, height: 1.4))),
          ]),
        ),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: const Text('Next sentence →'),
            style: ElevatedButton.styleFrom(
                backgroundColor: c, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          )),
      ],
    ]);
  }
}

enum _FBState { loading, error, question }