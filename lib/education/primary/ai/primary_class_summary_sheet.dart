// lib/education/primary/primary_class_summary_sheet.dart
import 'package:flutter/material.dart';
import 'primary_ai_service.dart';
import 'primary_progress_service.dart';

/// Teacher-only weekly class summary sheet.
/// Reads Firestore progress data for the class, sends it to Gemini,
/// displays a plain-English summary with tips.
///
/// Usage (teacher home screen card):
///   showModalBottomSheet(
///     context: context,
///     isScrollControlled: true,
///     backgroundColor: Colors.transparent,
///     builder: (_) => DraggableScrollableSheet(
///       initialChildSize: 0.85,
///       builder: (_, sc) => PrimaryClassSummarySheet(
///         classId: 'school_primary_3', grade: 'Grade 3', schoolName: 'Sunshine Academy'),
///     ),
///   );
class PrimaryClassSummarySheet extends StatefulWidget {
  final String classId, grade, schoolName;
  const PrimaryClassSummarySheet({
      super.key, required this.classId, required this.grade, required this.schoolName});

  @override
  State<PrimaryClassSummarySheet> createState() => _PrimaryClassSummarySheetState();
}

class _PrimaryClassSummarySheetState extends State<PrimaryClassSummarySheet> {
  final _aiService = const PrimaryAiService();

  _CSState      _state = _CSState.loading;
  ClassSummary? _summary;
  Map<String, Map<String, dynamic>> _rawData = {};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _state = _CSState.loading);

    // 1. Read from Firestore
    final data = await PrimaryProgressService.getWeeklySummaryForClass(
        classId: widget.classId, schoolName: widget.schoolName);

    if (!mounted) return;

    if (data.isEmpty) {
      setState(() { _state = _CSState.noData; _rawData = {}; });
      return;
    }

    _rawData = data;

    // 2. Ask AI to interpret
    final summary = await _aiService.generateClassSummary(
        grade: widget.grade, schoolName: widget.schoolName, activityData: data);

    if (!mounted) return;
    setState(() {
      _summary = summary;
      _state   = summary == null ? _CSState.error : _CSState.done;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(children: [
        Center(child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4), width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 16, 0),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFF003900).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.bar_chart_rounded, color: Color(0xFF003900), size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('This week\'s summary', style: TextStyle(fontSize: 16,
                  fontWeight: FontWeight.bold, color: Color(0xFF003900))),
              Text('${widget.grade} · ${widget.schoolName}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ])),
            if (_state == _CSState.done)
              IconButton(icon: const Icon(Icons.refresh_rounded, size: 20),
                  color: Colors.grey.shade400, onPressed: _load),
            IconButton(icon: const Icon(Icons.close, size: 20), color: Colors.grey.shade400,
                onPressed: () => Navigator.pop(context)),
          ]),
        ),
        const Divider(height: 20, indent: 20, endIndent: 20),
        Expanded(child: switch (_state) {
          _CSState.loading => _buildLoading(),
          _CSState.noData  => _buildNoData(),
          _CSState.error   => _buildError(),
          _CSState.done    => _buildSummary(),
        }),
      ]),
    );
  }

  Widget _buildLoading() => const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    CircularProgressIndicator(color: Color(0xFF003900)),
    SizedBox(height: 16),
    Text('Reading class activity…', style: TextStyle(fontSize: 13, color: Color(0xFF558B2F))),
  ]));

  Widget _buildNoData() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.hourglass_empty_rounded, size: 52, color: Colors.grey.shade300),
    const SizedBox(height: 12),
    Text('No activity recorded yet this week.',
        textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
    const SizedBox(height: 6),
    Text('Students need to complete quizzes and activities\nfor the summary to appear here.',
        textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
  ]));

  Widget _buildError() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.wifi_off_rounded, size: 52, color: Colors.grey.shade300),
    const SizedBox(height: 12),
    Text('Could not generate summary. Check your connection.',
        textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
    const SizedBox(height: 20),
    ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh, size: 16),
        label: const Text('Try again'),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF003900),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
  ]));

  Widget _buildSummary() {
    final s = _summary!;
    return ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 32), children: [
      // AI narrative
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Text('📊 ', style: TextStyle(fontSize: 16)),
            Text('Weekly overview', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                color: Color(0xFF1B5E20))),
          ]),
          const SizedBox(height: 8),
          Text(s.summary, style: const TextStyle(fontSize: 14, height: 1.6)),
        ]),
      ),
      const SizedBox(height: 14),

      // Best / weakest topic chips
      Row(children: [
        Expanded(child: _TopicChip(
          label: 'Most active', topic: s.topTopic, color: Colors.green)),
        const SizedBox(width: 10),
        Expanded(child: _TopicChip(
          label: 'Needs attention', topic: s.weakTopic, color: Colors.orange)),
      ]),
      const SizedBox(height: 14),

      // Raw data table
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Activity breakdown', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
              color: Colors.grey.shade600)),
          const SizedBox(height: 10),
          ..._rawData.entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(child: Text(e.key, style: const TextStyle(fontSize: 13))),
              Text('${e.value['completions']} activities',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              const SizedBox(width: 10),
              _ScorePill(score: e.value['quizAvg'] as int? ?? 0),
            ]),
          )),
        ]),
      ),
      const SizedBox(height: 14),

      // Teaching tips
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.amber.shade50, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade200)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Text('💡 ', style: TextStyle(fontSize: 16)),
            Text('Teaching tips', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          ...s.tips.map((tip) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('• ', style: TextStyle(color: Colors.amber.shade800, fontWeight: FontWeight.bold)),
              Expanded(child: Text(tip, style: TextStyle(fontSize: 13,
                  color: Colors.amber.shade900, height: 1.4))),
            ]),
          )),
        ]),
      ),
    ]);
  }
}

class _TopicChip extends StatelessWidget {
  final String label, topic; final MaterialColor color;
  const _TopicChip({required this.label, required this.topic, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: color.shade50, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.shade200)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 10, color: color.shade600, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text(topic, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color.shade800),
          maxLines: 2, overflow: TextOverflow.ellipsis),
    ]),
  );
}

class _ScorePill extends StatelessWidget {
  final int score;
  const _ScorePill({required this.score});
  @override
  Widget build(BuildContext context) {
    final c = score >= 70 ? Colors.green : score >= 50 ? Colors.orange : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.shade50, borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.shade200)),
      child: Text('$score%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
          color: c.shade700)),
    );
  }
}

enum _CSState { loading, noData, error, done }