// lib/education/primary/primary_farming_tools.dart
import 'package:flutter/material.dart';
import 'package:kilimomkononi/models/education_user.dart';
import '../ai/primary_ai_tooltip.dart';
import '../ai/primary_fun_fact_box.dart';
import '../ai/primary_mini_quiz_sheet.dart';
import '../ai/primary_spot_mistake.dart';

class _Img extends StatelessWidget {
  final String url; final double h = 200.0;
  const _Img(this.url);
  @override
  Widget build(BuildContext c) => Image.asset(url, height: h, width: double.infinity, fit: BoxFit.cover,
    errorBuilder: (_, _, _) => Container(height: h, color: const Color(0xFFFBE9E7),
        child: const Center(child: Icon(Icons.handyman, size: 48, color: Color(0xFFBF360C)))));
}

class _Tool {
  final String emoji, name, swahili, gradeLevel, use, safety, imageUrl;
  final Color c, lc;
  const _Tool({required this.emoji, required this.name, required this.swahili,
      required this.gradeLevel, required this.use, required this.safety,
      required this.imageUrl, required this.c, required this.lc});
}

const _tools = <_Tool>[
  _Tool(emoji:'⛏️', name:'Jembe (Hoe)', swahili:'Jembe', gradeLevel:'Grade 1 & 2',
    imageUrl:'assets/education/primary/tools/jembe_hoe.jpg',
    use:'The jembe is the most common farming tool in Kenya. It is used to:\n'
        '• Dig and loosen soil before planting\n'
        '• Make furrows (trenches) for seeds\n'
        '• Remove weeds between rows\n'
        '• Break up hard soil after rain\n\n'
        'The blade can be wide (for digging) or narrow (for weeding).',
    safety:'Always look behind you before swinging. Store blade-side down. '
        'Never run while carrying a jembe.',
    c: Color(0xFF5D4037), lc: Color(0xFFEFEBE9)),
  _Tool(emoji:'🪣', name:'Watering Can', swahili:'Bakuli ya kumwagilia', gradeLevel:'Grade 1–3',
    imageUrl:'assets/education/primary/tools/watering_can.jpg',
    use:'Used to water plants gently:\n'
        '• Water seedlings in a nursery\n'
        '• Water vegetables in a kitchen garden\n'
        '• Apply liquid fertiliser to roots\n\n'
        'The "rose" (sprayhead) breaks the water into tiny drops so the soil is not washed away.',
    safety:'Do not overfill — too heavy for small hands. Always water at the BASE of the plant, '
        'not on the leaves. Water early in the morning.',
    c: Color(0xFF0277BD), lc: Color(0xFFE1F5FE)),
  _Tool(emoji:'🧺', name:'Wheelbarrow', swahili:'Mkokoteni', gradeLevel:'Grade 4–6',
    imageUrl:'assets/education/primary/tools/wheelbarrow.jpg',
    use:'Moves heavy loads on the farm:\n'
        '• Carries manure and compost to the field\n'
        '• Transports harvested crops\n'
        '• Moves soil for raised beds\n'
        '• Collects weeds for the compost heap',
    safety:'Do not overload — it can tip. Keep the path clear of stones and holes. '
        'Lift using your legs, not your back. Check the tyre has air.',
    c: Color(0xFF558B2F), lc: Color(0xFFF1F8E9)),
  _Tool(emoji:'🌾', name:'Sickle', swahili:'Mundu', gradeLevel:'Grade 5 & 6',
    imageUrl:'assets/education/primary/tools/sickle.jpg',
    use:'A curved blade used to:\n'
        '• Harvest wheat, sorghum and millet\n'
        '• Cut grass for animal feed (fodder)\n'
        '• Clear light vegetation\n\n'
        'Hold the crop stems in one hand, cut with the other in a sweeping motion.',
    safety:'Always cut AWAY from your body. Keep it covered when stored. '
        'Never use near other people. Keep the blade sharp — blunt blades cause slipping.',
    c: Color(0xFFF57F17), lc: Color(0xFFFFF9C4)),
  _Tool(emoji:'🪚', name:'Hand Rake', swahili:'Reki', gradeLevel:'Grade 2–4',
    imageUrl:'assets/education/primary/tools/hand_rake.jpg',
    use:'Prepares the soil surface:\n'
        '• Loosens the top layer of soil for planting\n'
        '• Collects fallen leaves and crop debris\n'
        '• Levels the soil surface after digging\n'
        '• Breaks up soil lumps',
    safety:'Always store with teeth facing DOWN so nobody steps on them. '
        'Keep the handle dry and check for splinters.',
    c: Color(0xFF6A1B9A), lc: Color(0xFFF3E5F5)),
  _Tool(emoji:'🪝', name:'Hand Trowel', swahili:'Kijembe kidogo', gradeLevel:'Grade 1–3',
    imageUrl:'assets/education/primary/tools/hand_trowel.jpg',
    use:'A small digging tool for:\n'
        '• Transplanting seedlings from a nursery\n'
        '• Planting seeds in pots or small beds\n'
        '• Removing individual weeds\n'
        '• Making small planting holes',
    safety:'Keep the blade clean and dry to prevent rust. Wash and dry after each use. Store indoors.',
    c: Color(0xFFBF360C), lc: Color(0xFFFBE9E7)),
  _Tool(emoji:'💧', name:'Drip Irrigation Pipe', swahili:'Mabomba ya umwagiliaji', gradeLevel:'Grade 5 & 6',
    imageUrl:'assets/education/primary/soil_water/drip_irrigation.jpg',
    use:'Saves water by delivering it directly to roots:\n'
        '• Pipes with tiny holes release water drop by drop\n'
        '• Can save up to 60% water compared to watering cans\n'
        '• Works well in dry areas and for vegetables\n'
        '• Connected to a tank or water source',
    safety:'Check for leaks regularly. Do not let pipes kink. Flush the system after use to prevent blockages.',
    c: Color(0xFF00897B), lc: Color(0xFFE0F2F1)),
];

// ── Screen ────────────────────────────────────────────────────────────────
class PrimaryFarmingToolsScreen extends StatelessWidget {
  final EduRole role; final String schoolName; final String classId;
  const PrimaryFarmingToolsScreen({super.key,
      required this.role, required this.schoolName, required this.classId});

  String get _grade {
    if (classId.contains('|')) {
      final parts = classId.split('|');
      const grades = ['Grade 1','Grade 2','Grade 3','Grade 4','Grade 5','Grade 6'];
      return grades.firstWhere((g) => g.split(' ').last == parts[0], orElse: () => 'Grade 4');
    }
    final m = RegExp(r'_(\d+)$').firstMatch(classId);
    return m != null ? 'Grade ${m.group(1)}' : 'Grade 4';
  }

  @override
  Widget build(BuildContext context) {
    // On mobile the AppBar provides the back arrow + title, so no separate
    // banner title row is shown — only the subtitle description.
    return Scaffold(
      backgroundColor: const Color(0xFFFBE9E7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFBF360C),
        foregroundColor: Colors.white,
        title: const Text('Farming Tools'),
        elevation: 0,
      ),
      body: Column(children: [
        // Subtitle-only banner (no repeated title text)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: const BoxDecoration(
            color: Color(0xFFBF360C),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
          child: const Text(
            'Tap any tool to see a picture and learn how to use it safely.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
        Expanded(child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            ..._tools.map((t) => _ToolCard(tool: t, grade: _grade)),
            const SizedBox(height: 8),
            PrimarySpotMistakeButton(
              topic: 'Farming Tools',
              grade: _grade,
              accentColor: const Color(0xFFBF360C),
            ),
            _PrimaryQuizButton(
              topic: 'Farming Tools',
              grade: _grade,
              accentColor: const Color(0xFFBF360C),
            ),
            const SizedBox(height: 32),
          ],
        )),
      ]),
    );
  }
}

// ── Shared quiz launch button ─────────────────────────────────────────────
class _PrimaryQuizButton extends StatelessWidget {
  final String topic, grade;
  final Color accentColor;
  const _PrimaryQuizButton({required this.topic, required this.grade, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final c = accentColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => DraggableScrollableSheet(
            initialChildSize: 0.85, maxChildSize: 0.95, minChildSize: 0.5,
            builder: (_, sc) => PrimaryMiniQuizSheet(topic: topic, grade: grade, accentColor: c),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(12)),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.quiz_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Test Yourself! 🎯', style: TextStyle(color: Colors.white, fontSize: 14,
                fontWeight: FontWeight.bold)),
          ]),
        ),
      ),
    );
  }
}

// ── Tool card ─────────────────────────────────────────────────────────────
class _ToolCard extends StatefulWidget {
  final _Tool tool;
  final String grade;
  const _ToolCard({required this.tool, required this.grade});
  @override State<_ToolCard> createState() => _ToolCardState();
}
class _ToolCardState extends State<_ToolCard> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    final t = widget.tool;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.c.withValues(alpha: 0.18)),
          boxShadow: [BoxShadow(color: t.c.withValues(alpha: 0.07), blurRadius: 6, offset: const Offset(0,3))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          onTap: () => setState(() => _open = !_open),
          child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
            Container(width: 52, height: 52,
                decoration: BoxDecoration(color: t.lc, borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text(t.emoji, style: const TextStyle(fontSize: 28)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: t.c)),
              Text(t.swahili, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              Container(margin: const EdgeInsets.only(top: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: t.lc, borderRadius: BorderRadius.circular(6)),
                  child: Text(t.gradeLevel, style: TextStyle(fontSize: 10, color: t.c,
                      fontWeight: FontWeight.w600))),
            ])),
            AnimatedRotation(turns: _open ? 0.5 : 0, duration: const Duration(milliseconds: 200),
                child: Icon(Icons.keyboard_arrow_down, color: t.c)),
          ])),
        ),
        if (_open) ...[
          ClipRRect(child: _Img(t.imageUrl)),
          Padding(padding: const EdgeInsets.fromLTRB(14,12,14,0),
              child: Text('🔧 What it does:', style: TextStyle(fontSize: 13,
                  fontWeight: FontWeight.bold, color: t.c))),
          Padding(padding: const EdgeInsets.fromLTRB(14,6,14,12),
              child: Text(t.use, style: const TextStyle(fontSize: 13.5, height: 1.55))),
          // Safety box kept as-is (not a fun fact replacement)
          Padding(padding: const EdgeInsets.fromLTRB(14,0,14,12),
            child: Container(padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade100)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('⚠️', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(child: Text('Safety: ${t.safety}',
                    style: TextStyle(fontSize: 13, color: Colors.red.shade800, height: 1.4))),
              ]))),
          // AI: refreshable fun fact (tools have no built-in funFact field, so we use a default)
          PrimaryFunFactBox(
            itemName: t.name,
            initialFact: 'Kenyan farmers have used the ${t.name} for generations to grow food for their families!',
          ),
          // AI: ask a question
          PrimaryAiTooltip(topic: t.name, grade: widget.grade, accentColor: t.c),
        ],
      ]),
    );
  }
}