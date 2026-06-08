// lib/education/primary/primary_weeds_pests.dart
// ignore_for_file: deprecated_member_use
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
    errorBuilder: (_, _, _) => Container(height: h, color: const Color(0xFFF1F8E9),
        child: const Center(child: Icon(Icons.bug_report, size: 48, color: Color(0xFF558B2F)))));
}

class _WP {
  final String emoji, name, type, desc, control, funFact, imageUrl;
  final Color c, lc;
  const _WP({required this.emoji, required this.name, required this.type,
      required this.desc, required this.control, required this.funFact,
      required this.imageUrl, required this.c, required this.lc});
}

const _wps = <_WP>[
  _WP(type:'Weed', emoji:'🌿', name:'Black Jack (Bidens pilosa)',
    imageUrl:'assets/education/primary/weeds_pests/blackjack_weed.jpg',
    desc:'Black jack is a very common weed in Kenyan farms.\n\n'
        '• Small star-shaped flowers turn into black arrow-shaped seeds\n'
        '• The seeds stick to clothes, animal fur and tools\n'
        '• Spreads quickly and competes with crops for water and nutrients\n'
        '• Found in maize, bean and vegetable fields',
    control:'• Pull out by hand BEFORE it produces seeds\n'
        '• Mulch the soil to stop seeds germinating\n'
        '• Do not carry seeds from one field to another on your clothes',
    funFact:'Black jack seeds can spread over 1 km by sticking to animals and people!',
    c: Color(0xFF558B2F), lc: Color(0xFFF1F8E9)),
  _WP(type:'Weed', emoji:'🌱', name:'Couch Grass (Digitaria scalarum)',
    imageUrl:'assets/education/primary/weeds_pests/couch_grass.jpg',
    desc:'Couch grass is one of the hardest weeds to remove.\n\n'
        '• Spreads underground by long white roots (rhizomes)\n'
        '• Each root piece left in soil grows into a new plant\n'
        '• Found in maize and bean fields across Kenya\n'
        '• Steals water and nutrients from crops',
    control:'• Dig out ALL roots — even small pieces regrow\n'
        '• Never chop — each piece becomes a new plant\n'
        '• Sun-dry the roots for several days before composting them',
    funFact:'Couch grass roots can reach 2 metres deep underground!',
    c: Color(0xFF33691E), lc: Color(0xFFF9FBE7)),
  _WP(type:'Weed', emoji:'🌼', name:'Mexican Marigold (Tagetes minuta)',
    imageUrl:'assets/education/primary/weeds_pests/mexican_marigold.jpg',
    desc:'Mexican marigold is a tall annual weed that grows in disturbed soils.\n\n'
        '• Has a strong smell that some farmers use to repel pests\n'
        '• Produces thousands of tiny seeds that spread by wind\n'
        '• Can grow up to 2 metres tall if not controlled\n'
        '• Releases chemicals that suppress other plants',
    control:'• Remove before it flowers and sets seed\n'
        '• Till the soil after harvest to bury seeds\n'
        '• Some farmers plant it as a border to repel nematodes',
    funFact:'Some farmers plant Mexican marigold ON PURPOSE to repel soil pests!',
    c: Color(0xFFF9A825), lc: Color(0xFFFFF9C4)),
  _WP(type:'Pest', emoji:'🪲', name:'Aphids (Familia: Aphididae)',
    imageUrl:'assets/education/primary/weeds_pests/aphids.jpg',
    desc:'Aphids are tiny soft-bodied insects — green, black or brown.\n\n'
        '• Suck sap from tender shoots, leaves and stems\n'
        '• Cause leaves to curl, yellow and wilt\n'
        '• Produce sticky "honeydew" that causes black mould\n'
        '• Spread plant viruses from one plant to another\n'
        '• Attack beans, kale, tomatoes, maize',
    control:'• Spray soapy water (1 spoon soap per litre) on the leaves\n'
        '• Attract ladybirds — they eat aphids naturally\n'
        '• Plant marigolds nearby to repel them\n'
        '• Remove heavily infested leaves',
    funFact:'One aphid can produce 80 offspring in a week without mating!',
    c: Color(0xFF1B5E20), lc: Color(0xFFE8F5E9)),
  _WP(type:'Pest', emoji:'🐛', name:'Cutworm (Agrotis spp.)',
    imageUrl:'assets/education/primary/weeds_pests/cutworm.jpg',
    desc:'Cutworms are caterpillars that live in the soil.\n\n'
        '• Active at night — they chew through plant stems at ground level\n'
        '• Young seedlings fall over as if cut with scissors\n'
        '• Hide in the soil during the day — grey or brown in colour\n'
        '• Attack maize, tomatoes, cabbages and kale',
    control:'• Dig the soil before planting to expose and remove them\n'
        '• Pour wood ash or dry sand around plant bases\n'
        '• Wrap the base of transplants with foil or cardboard\n'
        '• Inspect at night with a torch',
    funFact:'Cutworms become moths when they grow up — they fly at night around lights!',
    c: Color(0xFF4E342E), lc: Color(0xFFEFEBE9)),
  _WP(type:'Pest', emoji:'🦗', name:'Maize Stalk Borer (Busseola fusca)',
    imageUrl:'assets/education/primary/weeds_pests/maize_stalk_borer.jpg',
    desc:'The stalk borer is Kenya\'s most damaging maize pest.\n\n'
        '• A caterpillar that bores tunnels inside maize stems\n'
        '• Look for "dead heart" — the central shoot wilts and dies\n'
        '• Plants affected early produce no cob\n'
        '• The larva is cream/pink with dark spots on the back',
    control:'• Plant maize at the right time (onset of rains) to avoid the pest\n'
        '• Remove and burn affected plants immediately\n'
        '• Push sand into the central whorl to kill young larvae\n'
        '• Plant Desmodium (silverleaf) between maize rows — it repels the moth',
    funFact:'The "Push-Pull" technique uses Desmodium to PUSH borers away and Napier grass to PULL them — developed right here in Kenya!',
    c: Color(0xFFF57F17), lc: Color(0xFFFFF9C4)),
  _WP(type:'Pest', emoji:'🐜', name:'Fall Army Worm (Spodoptera frugiperda)',
    imageUrl:'assets/education/primary/weeds_pests/fall_armyworm.jpg',
    desc:'The fall armyworm arrived in Africa in 2016 and spread rapidly.\n\n'
        '• Caterpillars march in large groups eating everything in their path\n'
        '• Feed on maize leaves creating ragged holes with sawdust-like frass\n'
        '• Identified by an upside-down Y mark on the head\n'
        '• One female moth lays up to 2,000 eggs in her lifetime',
    control:'• Scout fields twice a week in the morning\n'
        '• Apply ash, soil, or sand directly into the maize whorl\n'
        '• Use neem-based spray or approved pesticide at first sign\n'
        '• Report large outbreaks to the local agricultural officer',
    funFact:'Fall armyworms can fly up to 100 km in one night and crossed from Americas to Africa in just 2 years!',
    c: Color(0xFF880E4F), lc: Color(0xFFFCE4EC)),
];

// ── Screen ────────────────────────────────────────────────────────────────
class PrimaryWeedsPestsScreen extends StatelessWidget {
  final EduRole role; final String schoolName; final String classId;
  const PrimaryWeedsPestsScreen({super.key,
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
    final weeds = _wps.where((w) => w.type == 'Weed').toList();
    final pests = _wps.where((w) => w.type == 'Pest').toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF558B2F),
        foregroundColor: Colors.white,
        title: const Text('Weeds & Pests'),
        elevation: 0,
      ),
      body: Column(children: [
        // Subtitle-only banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: const BoxDecoration(
            color: Color(0xFF558B2F),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
          child: const Text(
            'Learn to identify and control what harms your crops.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
        Expanded(child: ListView(padding: const EdgeInsets.all(14), children: [
          _section('🌿 Weeds', 'Plants that steal water and nutrients', const Color(0xFF558B2F)),
          ...weeds.map((w) => _WPCard(item: w, grade: _grade)),
          const SizedBox(height: 8),
          _section('🪲 Pests', 'Insects that damage or destroy crops', const Color(0xFF1B5E20)),
          ...pests.map((w) => _WPCard(item: w, grade: _grade)),
          const SizedBox(height: 8),
          PrimarySpotMistakeButton(
            topic: 'Weeds & Pests',
            grade: _grade,
            accentColor: const Color(0xFF558B2F),
          ),
          _PrimaryQuizButton(topic: 'Weeds & Pests', grade: _grade, accentColor: const Color(0xFF558B2F)),
          const SizedBox(height: 32),
        ])),
      ]),
    );
  }

  static Widget _section(String t, String s, Color c) => Padding(
    padding: const EdgeInsets.fromLTRB(0,8,0,10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: c)),
      Text(s, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
    ]));
}

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

class _WPCard extends StatefulWidget {
  final _WP item;
  final String grade;
  const _WPCard({required this.item, required this.grade});
  @override State<_WPCard> createState() => _WPCardState();
}
class _WPCardState extends State<_WPCard> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    final w = widget.item;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: w.c.withOpacity(0.18)),
          boxShadow: [BoxShadow(color: w.c.withOpacity(0.07), blurRadius: 6, offset: const Offset(0,3))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          onTap: () => setState(() => _open = !_open),
          child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
            Container(width: 52, height: 52,
                decoration: BoxDecoration(color: w.lc, borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text(w.emoji, style: const TextStyle(fontSize: 28)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(w.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: w.c)),
              Container(margin: const EdgeInsets.only(top: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: w.type == 'Weed' ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6)),
                  child: Text(w.type, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: w.type == 'Weed' ? Colors.green.shade700 : Colors.red.shade700))),
            ])),
            AnimatedRotation(turns: _open ? 0.5 : 0, duration: const Duration(milliseconds: 200),
                child: Icon(Icons.keyboard_arrow_down, color: w.c)),
          ])),
        ),
        if (_open) ...[
          ClipRRect(child: _Img(w.imageUrl)),
          Padding(padding: const EdgeInsets.fromLTRB(14,12,14,0),
              child: Text(w.desc, style: const TextStyle(fontSize: 13.5, height: 1.55))),
          Padding(padding: const EdgeInsets.fromLTRB(14,12,14,0),
              child: Text('✅ How to control:', style: TextStyle(fontSize: 13,
                  fontWeight: FontWeight.bold, color: w.c))),
          Padding(padding: const EdgeInsets.fromLTRB(14,6,14,12),
              child: Text(w.control, style: const TextStyle(fontSize: 13.5, height: 1.55))),
          PrimaryFunFactBox(itemName: w.name, initialFact: w.funFact),
          PrimaryAiTooltip(topic: w.name, grade: widget.grade, accentColor: w.c),
        ],
      ]),
    );
  }
}