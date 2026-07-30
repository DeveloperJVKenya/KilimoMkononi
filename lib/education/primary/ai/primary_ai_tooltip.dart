// lib/education/primary/primary_ai_tooltip.dart
import 'package:flutter/material.dart';
import 'primary_ai_service.dart';
import 'primary_language_toggle.dart';

/// "Ask Shamba AI" question-answer box dropped inside any expanded card.
/// Now supports English / Kiswahili toggle.
class PrimaryAiTooltip extends StatefulWidget {
  final String topic, grade;
  final Color  accentColor;

  const PrimaryAiTooltip({
    super.key,
    required this.topic,
    required this.grade,
    required this.accentColor,
  });

  @override
  State<PrimaryAiTooltip> createState() => _PrimaryAiTooltipState();
}

class _PrimaryAiTooltipState extends State<PrimaryAiTooltip> {
  final _service    = const PrimaryAiService();
  final _controller = TextEditingController();

  _TipState      _state    = _TipState.idle;
  String         _response = '';
  PrimaryLanguage _language = PrimaryLanguage.english;

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  Future<void> _ask() async {
    final question = _controller.text.trim();
    if (question.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() { _state = _TipState.loading; _response = ''; });

    final answer = await _service.explainForChild(
      topic: widget.topic, question: question,
      grade: widget.grade, language: _language,
    );

    if (!mounted) return;
    setState(() { _state = _TipState.answered; _response = answer; });
  }

  void _reset() {
    _controller.clear();
    setState(() { _state = _TipState.idle; _response = ''; });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.accentColor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(children: [
              const Text('🌱', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              const Text('Ask Shamba AI',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
              const Spacer(),
              PrimaryLanguageToggle(
                value: _language,
                onChanged: (lang) { setState(() { _language = lang; if (_state == _TipState.answered) _reset(); }); },
              ),
              if (_state == _TipState.answered) ...[
                const SizedBox(width: 6),
                GestureDetector(onTap: _reset,
                    child: const Icon(Icons.refresh, size: 16, color: Color(0xFF2E7D32))),
              ],
            ]),
          ),
          const SizedBox(height: 8),
          if (_state == _TipState.loading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(children: [
                SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: c)),
                const SizedBox(width: 10),
                Text('Thinking…', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ]),
            ),
          if (_state == _TipState.answered)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(_response,
                  style: const TextStyle(fontSize: 13.5, height: 1.6, color: Color(0xFF1B5E20))),
            ),
          if (_state != _TipState.loading)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
              child: Row(children: [
                Expanded(child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _ask(),
                  decoration: InputDecoration(
                    hintText: _state == _TipState.answered
                        ? (_language == PrimaryLanguage.swahili ? 'Uliza swali lingine…' : 'Ask another question…')
                        : (_language == PrimaryLanguage.swahili
                            ? 'Unataka kujua nini kuhusu ${widget.topic}?'
                            : 'What do you want to know about ${widget.topic}?'),
                    hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true, fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                )),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _ask, borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFF2E7D32),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 16)),
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}

enum _TipState { idle, loading, answered }