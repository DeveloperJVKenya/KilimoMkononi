// lib/education/primary/primary_mini_quiz_sheet.dart
import 'package:flutter/material.dart';
import 'primary_ai_service.dart';
import 'primary_language_toggle.dart';
import 'primary_progress_service.dart';

class PrimaryMiniQuizSheet extends StatefulWidget {
  final String topic, grade;
  final Color  accentColor;
  final int    questionCount;
  final PrimaryLanguage language;

  const PrimaryMiniQuizSheet({
    super.key,
    required this.topic,
    required this.grade,
    required this.accentColor,
    this.questionCount = 3,
    this.language = PrimaryLanguage.english,
  });

  @override
  State<PrimaryMiniQuizSheet> createState() => _PrimaryMiniQuizSheetState();
}

class _PrimaryMiniQuizSheetState extends State<PrimaryMiniQuizSheet> {
  final _service = const PrimaryAiService();

  _QuizState _state = _QuizState.loading;
  List<PrimaryQuestion> _questions = [];
  String? _errorMsg;
  PrimaryLanguage _language = PrimaryLanguage.english;

  int  _currentIndex  = 0;
  int? _selectedOption;
  bool _answered      = false;
  int  _score         = 0;

  @override
  void initState() {
    super.initState();
    _language = widget.language;
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() { _state = _QuizState.loading; _errorMsg = null; });
    final questions = await _service.generateMiniQuiz(
        topic: widget.topic, grade: widget.grade,
        count: widget.questionCount, language: _language);
    if (!mounted) return;
    if (questions.isEmpty) {
      setState(() { _state = _QuizState.error;
        _errorMsg = 'Could not load questions. Check your connection.'; });
    } else {
      setState(() { _questions = questions; _currentIndex = 0;
        _selectedOption = null; _answered = false; _score = 0;
        _state = _QuizState.question; });
    }
  }

  void _onOptionTap(int index) {
    if (_answered) return;
    setState(() {
      _selectedOption = index; _answered = true;
      if (index == _questions[_currentIndex].correctIndex) _score++;
    });
  }

  void _onNext() {
    if (_currentIndex + 1 >= _questions.length) {
      // Save progress
      PrimaryProgressService.recordQuizScore(
          topic: widget.topic, score: _score, total: _questions.length);
      setState(() => _state = _QuizState.results);
    } else {
      setState(() { _currentIndex++; _selectedOption = null; _answered = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.accentColor;
    return Container(
      decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)))),
        Padding(padding: const EdgeInsets.fromLTRB(20, 8, 16, 0),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: c.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.quiz_rounded, color: c, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Test Yourself! 🎯', style: TextStyle(fontSize: 16,
                  fontWeight: FontWeight.bold, color: c)),
              Text(widget.topic, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ])),
            PrimaryLanguageToggle(value: _language,
                onChanged: (lang) { setState(() => _language = lang); _loadQuestions(); }),
            IconButton(icon: const Icon(Icons.close, size: 20),
                color: Colors.grey.shade400, onPressed: () => Navigator.pop(context)),
          ])),
        const Divider(height: 20, indent: 20, endIndent: 20),
        Flexible(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: switch (_state) {
            _QuizState.loading  => _buildLoading(c),
            _QuizState.error    => _buildError(c),
            _QuizState.question => _buildQuestion(c),
            _QuizState.results  => _buildResults(c),
          },
        )),
      ]),
    );
  }

  Widget _buildLoading(Color c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(children: [
      SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 3, color: c)),
      const SizedBox(height: 16),
      Text('Preparing your quiz about ${widget.topic}…',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600), textAlign: TextAlign.center),
    ]));

  Widget _buildError(Color c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Column(children: [
      Icon(Icons.wifi_off_rounded, size: 44, color: Colors.grey.shade300),
      const SizedBox(height: 12),
      Text(_errorMsg ?? 'Something went wrong.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600), textAlign: TextAlign.center),
      const SizedBox(height: 20),
      ElevatedButton.icon(onPressed: _loadQuestions,
        icon: const Icon(Icons.refresh, size: 16), label: const Text('Try again'),
        style: ElevatedButton.styleFrom(backgroundColor: c, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
    ]));

  Widget _buildQuestion(Color c) {
    final q        = _questions[_currentIndex];
    final progress = (_currentIndex + 1) / _questions.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Question ${_currentIndex + 1} of ${_questions.length}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        const Spacer(),
        Text('Score: $_score', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(value: progress,
            backgroundColor: Colors.grey.shade100,
            valueColor: AlwaysStoppedAnimation(c), minHeight: 6)),
      const SizedBox(height: 16),
      Container(width: double.infinity, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.withValues(alpha: 0.15))),
        child: Text(q.question,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.4))),
      const SizedBox(height: 14),
      ...q.options.asMap().entries.map((entry) => _OptionTile(
        text: entry.value, index: entry.key,
        selected: _selectedOption == entry.key, answered: _answered,
        isCorrect: entry.key == q.correctIndex, accentColor: c,
        onTap: () => _onOptionTap(entry.key),
      )),
      if (_answered) ...[
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade200)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('💡', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Expanded(child: Text(q.funExplanation,
                style: TextStyle(fontSize: 13, color: Colors.amber.shade900, height: 1.4))),
          ])),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity,
          child: ElevatedButton(onPressed: _onNext,
            style: ElevatedButton.styleFrom(backgroundColor: c, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(_currentIndex + 1 >= _questions.length
                ? 'See my results 🎉' : 'Next question →',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)))),
      ],
    ]);
  }

  Widget _buildResults(Color c) {
    final total = _questions.length;
    final pct   = (_score / total * 100).round();
    final emoji = pct >= 80 ? '🏆' : pct >= 50 ? '👍' : '📚';
    final msg   = pct >= 80
        ? 'Excellent! You really know your ${widget.topic}!'
        : pct >= 50 ? 'Good effort! Keep studying ${widget.topic}.'
            : "Keep practising — you'll get better at ${widget.topic}!";
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 52)),
        const SizedBox(height: 12),
        Text('$_score / $total correct',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: c)),
        const SizedBox(height: 6),
        Text(msg, style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            textAlign: TextAlign.center),
        const SizedBox(height: 28),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: _loadQuestions,
            icon: const Icon(Icons.refresh, size: 16), label: const Text('Try again'),
            style: OutlinedButton.styleFrom(foregroundColor: c, side: BorderSide(color: c),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.check, size: 16), label: const Text('Done'),
            style: ElevatedButton.styleFrom(backgroundColor: c, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
        ]),
      ]));
  }
}

class _OptionTile extends StatelessWidget {
  final String text; final int index; final bool selected, answered, isCorrect;
  final Color accentColor; final VoidCallback onTap;
  const _OptionTile({required this.text, required this.index, required this.selected,
      required this.answered, required this.isCorrect, required this.accentColor,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    Color bg, border, textColor; IconData? icon;
    if (!answered) { bg = Colors.grey.shade50; border = Colors.grey.shade200; textColor = Colors.black87; icon = null; }
    else if (isCorrect) { bg = Colors.green.shade50; border = Colors.green.shade300; textColor = Colors.green.shade800; icon = Icons.check_circle; }
    else if (selected) { bg = Colors.red.shade50; border = Colors.red.shade200; textColor = Colors.red.shade800; icon = Icons.cancel; }
    else { bg = Colors.grey.shade50; border = Colors.grey.shade200; textColor = Colors.grey.shade400; icon = null; }
    final labels = ['A', 'B', 'C', 'D'];
    return GestureDetector(
      onTap: answered ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: selected || (answered && isCorrect) ? 1.5 : 1)),
        child: Row(children: [
          Container(width: 26, height: 26,
            decoration: BoxDecoration(
              color: answered ? (isCorrect ? Colors.green.shade100 : selected ? Colors.red.shade100 : Colors.grey.shade100)
                  : accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6)),
            child: Center(child: Text(labels[index], style: TextStyle(fontSize: 12,
                fontWeight: FontWeight.bold,
                color: answered ? (isCorrect ? Colors.green.shade700 : selected ? Colors.red.shade700 : Colors.grey.shade400)
                    : accentColor)))),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(fontSize: 14, color: textColor, height: 1.3))),
          if (icon != null) ...[
            const SizedBox(width: 8),
            Icon(icon, size: 18, color: isCorrect ? Colors.green.shade600 : Colors.red.shade400),
          ],
        ]),
      ),
    );
  }
}

enum _QuizState { loading, error, question, results }