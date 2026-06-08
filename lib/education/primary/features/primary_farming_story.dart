// lib/education/primary/primary_farming_story.dart
// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../ai/primary_ai_service.dart';

/// A full screen for the "Farming Story" feature.
/// Shows a short AI-generated CBC farming story and a comprehension question.
///
/// Push from PrimaryHomeScreen as a bottom sheet or a route:
///
///   Navigator.push(context, MaterialPageRoute(
///     builder: (_) => PrimaryFarmingStoryScreen(
///       strand: 'Farm Animals',
///       grade: 'Grade 3',
///     ),
///   ));
class PrimaryFarmingStoryScreen extends StatefulWidget {
  final String strand;
  final String grade;

  const PrimaryFarmingStoryScreen({
    super.key,
    required this.strand,
    required this.grade,
  });

  @override
  State<PrimaryFarmingStoryScreen> createState() =>
      _PrimaryFarmingStoryScreenState();
}

class _PrimaryFarmingStoryScreenState
    extends State<PrimaryFarmingStoryScreen> {
  final _service = const PrimaryAiService();

  _StoryState  _state   = _StoryState.loading;
  FarmingStory? _story;

  // Comprehension question state
  bool   _showAnswer  = false;
  String _userAnswer  = '';
  bool?  _correct;       // null = not checked yet

  final _answerCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _answerCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _state       = _StoryState.loading;
      _showAnswer  = false;
      _correct     = null;
      _userAnswer  = '';
      _answerCtrl.clear();
    });

    final story = await _service.generateFarmingStory(
      strand: widget.strand,
      grade:  widget.grade,
    );

    if (!mounted) return;
    if (story == null) {
      setState(() => _state = _StoryState.error);
    } else {
      setState(() {
        _story = story;
        _state = _StoryState.story;
      });
    }
  }

  void _checkAnswer() {
    final answer = _answerCtrl.text.trim().toLowerCase();
    if (answer.isEmpty) return;
    final modelLower = (_story?.answer ?? '').toLowerCase();
    // Simple keyword check — does the user's answer share a meaningful word
    // with the model answer?
    final modelWords = modelLower
        .split(RegExp(r'\W+'))
        .where((w) => w.length > 3)
        .toSet();
    final userWords  = answer.split(RegExp(r'\W+')).toSet();
    final overlap    = modelWords.intersection(userWords);
    setState(() {
      _userAnswer = _answerCtrl.text.trim();
      _correct    = overlap.isNotEmpty;
      _showAnswer = true;
    });
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        title: const Text('Farming Story 📖'),
        elevation: 0,
        actions: [
          if (_state == _StoryState.story)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'New story',
              onPressed: _load,
            ),
        ],
      ),
      body: Column(children: [
        // Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
          decoration: const BoxDecoration(
              color: Color(0xFF2E7D32),
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(20))),
          child: Row(children: [
            const Text('📖', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.strand,
                  style: const TextStyle(color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.bold)),
              Text('${widget.grade} · Read then answer the question',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ])),
          ]),
        ),

        // Body
        Expanded(child: switch (_state) {
          _StoryState.loading => _buildLoading(),
          _StoryState.error   => _buildError(),
          _StoryState.story   => _buildStory(),
        }),
      ]),
    );
  }

  Widget _buildLoading() => const Center(child: Column(
    mainAxisSize: MainAxisSize.min, children: [
      CircularProgressIndicator(color: Color(0xFF2E7D32)),
      SizedBox(height: 16),
      Text('Writing your story…',
          style: TextStyle(fontSize: 13, color: Color(0xFF558B2F))),
    ]));

  Widget _buildError() => Center(child: Column(
    mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.wifi_off_rounded, size: 52, color: Colors.grey.shade300),
      const SizedBox(height: 12),
      Text('Could not generate story.\nCheck your connection.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
      const SizedBox(height: 20),
      ElevatedButton.icon(
        onPressed: _load,
        icon: const Icon(Icons.refresh, size: 16),
        label: const Text('Try again'),
        style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      ),
    ]));

  Widget _buildStory() {
    final s = _story!;
    return ListView(padding: const EdgeInsets.all(16), children: [
      // Story card
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.15)),
            boxShadow: [BoxShadow(
                color: const Color(0xFF2E7D32).withOpacity(0.07),
                blurRadius: 8, offset: const Offset(0, 3))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('🌾', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text('Read the story',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600)),
          ]),
          const SizedBox(height: 12),
          Text(s.story,
              style: const TextStyle(fontSize: 15, height: 1.75)),
        ]),
      ),
      const SizedBox(height: 16),

      // Question card
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: const Color(0xFF2E7D32).withOpacity(0.2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('❓', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            const Text('Your turn!',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                    color: Color(0xFF1B5E20))),
          ]),
          const SizedBox(height: 10),
          Text(s.question,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                  height: 1.4, color: Color(0xFF1B5E20))),
          const SizedBox(height: 12),

          // Answer input
          if (!_showAnswer) ...[
            TextField(
              controller: _answerCtrl,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _checkAnswer(),
              minLines: 2, maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Write your answer here…',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                filled: true, fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade200)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF2E7D32))),
              ),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity,
              child: ElevatedButton(
                onPressed: _checkAnswer,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: const Text('Check my answer',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ),
          ],

          // Feedback after checking
          if (_showAnswer) ...[
            // User's answer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200)),
              child: Text('Your answer: $_userAnswer',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            ),
            const SizedBox(height: 10),
            // Result
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: _correct! ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _correct! ? Colors.green.shade200 : Colors.orange.shade200)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  _correct! ? '🎉 Great answer!' : '💡 Good try! Here is the answer:',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold,
                      color: _correct! ? Colors.green.shade800 : Colors.orange.shade800),
                ),
                const SizedBox(height: 6),
                Text(s.answer,
                    style: TextStyle(fontSize: 13,
                        color: _correct! ? Colors.green.shade700 : Colors.grey.shade700,
                        height: 1.4)),
              ]),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.auto_stories, size: 16),
                label: const Text('New story'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2E7D32),
                    side: const BorderSide(color: Color(0xFF2E7D32)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Done'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
              )),
            ]),
          ],
        ]),
      ),
      const SizedBox(height: 32),
    ]);
  }
}

enum _StoryState { loading, error, story }