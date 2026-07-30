// lib/education/primary/primary_farm_animals.dart
import 'package:flutter/material.dart';
import 'package:kilimomkononi/models/education_user.dart';
// ── AI widgets ──────────────────────────────────────────────────────
import '../ai/primary_ai_tooltip.dart';
import '../ai/primary_fun_fact_box.dart';
import '../ai/primary_mini_quiz_sheet.dart';
import '../ai/primary_spot_mistake.dart';

class _Img extends StatelessWidget {
  final String url; final double h= 200.0;
  const _Img(this.url);
  @override
  Widget build(BuildContext c) => Image.asset(url, height: h, width: double.infinity, fit: BoxFit.cover,
    errorBuilder: (_, _, _) => Container(height: h, color: const Color(0xFFFFF3E0),
        child: const Center(child: Icon(Icons.pets, size: 48, color: Color(0xFFE65100)))));
}

class _Animal {
  final String emoji, name, swahili, products, food, care, funFact, imageUrl;
  final Color c, lc;
  const _Animal({required this.emoji, required this.name, required this.swahili,
      required this.products, required this.food, required this.care,
      required this.funFact, required this.imageUrl, required this.c, required this.lc});
}

const _animals = <_Animal>[
  _Animal(emoji:'🐄', name:'Dairy Cow', swahili:'Ng\'ombe wa maziwa',
    products:'Milk, meat, manure, leather',
    imageUrl:'assets/education/primary/animals/dairy_cow.jpg',
    food:'Grass, hay, maize silage, mineral supplements and plenty of clean water '
        '(a cow drinks up to 80 litres per day!).',
    care:'• Provide clean water every day\n'
        '• Deworm every 3 months\n'
        '• Vaccinate against Foot-and-Mouth Disease, East Coast Fever\n'
        '• Clean the shed daily — remove dung and wet bedding\n'
        '• Milk at the same time every day for best production',
    funFact:'A cow has 4 stomach compartments! It swallows grass, then brings it back up to chew it again (called "chewing cud").',
    c: Color(0xFF4E342E), lc: Color(0xFFEFEBE9)),
  _Animal(emoji:'🐐', name:'Goat', swahili:'Mbuzi',
    products:'Milk, meat, skin, manure',
    imageUrl:'assets/education/primary/animals/goat.jpg',
    food:'Leaves, grass, shrubs, crop residues, maize stalks and water.',
    care:'• Provide clean water and browse daily\n'
        '• Deworm every 3 months\n'
        '• Vaccinate against CCPP (goat plague)\n'
        '• Shelter at night to protect from predators and rain\n'
        '• Check hooves monthly for overgrowth or infection',
    funFact:'Goats were one of the first animals ever domesticated by humans — over 10,000 years ago!',
    c: Color(0xFF795548), lc: Color(0xFFFBE9E7)),
  _Animal(emoji:'🐔', name:'Local Chicken', swahili:'Kuku wa kienyeji',
    products:'Eggs, meat, feathers, manure',
    imageUrl:'assets/education/primary/animals/chicken.jpg',
    food:'Grains (maize, wheat), insects, worms, kitchen scraps, clean water.',
    care:'• Vaccinate against Newcastle Disease (kills entire flocks)\n'
        '• Clean the coop weekly — remove old litter\n'
        '• Provide clean water in a raised container to avoid dirt\n'
        '• Give grit (small stones) to help digestion\n'
        '• Collect eggs daily',
    funFact:'A hen turns each egg over 50 times a day to keep it at the right temperature!',
    c: Color(0xFFE65100), lc: Color(0xFFFFF3E0)),
  _Animal(emoji:'🐷', name:'Pig', swahili:'Nguruwe',
    products:'Pork, lard, manure, leather',
    imageUrl:'assets/education/primary/animals/pig.jpg',
    food:'Kitchen waste, maize, soy, commercial pig feed and water.',
    care:'• Clean the sty (pig house) daily — pigs need clean dry bedding\n'
        '• Vaccinate against African Swine Fever and Swine Erysipelas\n'
        '• Deworm every 6 months\n'
        '• Provide shade and mud for wallowing — pigs cannot sweat!\n'
        '• Separate piglets from adults',
    funFact:'Pigs are considered smarter than dogs! They can learn their name and solve puzzles.',
    c: Color(0xFFEC407A), lc: Color(0xFFFCE4EC)),
  _Animal(emoji:'🐰', name:'Rabbit', swahili:'Sungura',
    products:'Meat, fur, manure',
    imageUrl:'assets/education/primary/animals/rabbit.jpg',
    food:'Grass, vegetables, hay, maize stalks, clean water.',
    care:'• Keep in a wire-mesh hutch raised off the ground\n'
        '• Clean the hutch every 2–3 days\n'
        '• Keep separate from dogs and cats\n'
        '• Provide fresh greens daily — never wilted or wet grass\n'
        '• Vaccinate against Rabbit Haemorrhagic Disease',
    funFact:'A rabbit can rotate its ears 270 degrees to hear predators from any direction!',
    c: Color(0xFF9E9E9E), lc: Color(0xFFF5F5F5)),
  _Animal(emoji:'🐝', name:'Honey Bee', swahili:'Nyuki wa asali',
    products:'Honey, beeswax, royal jelly, propolis, pollination',
    imageUrl:'assets/education/primary/animals/honey_bee.jpg',
    food:'Flower nectar (makes honey) and pollen (their protein food).',
    care:'• Place hives 2–3 metres high, facing east (morning sun)\n'
        '• Provide a water source within 100 metres\n'
        '• Never spray pesticides near hives\n'
        '• Inspect hives monthly — wear protective gear\n'
        '• Harvest honey only when 80% of comb is capped (sealed)',
    funFact:'A bee visits 50–100 flowers on one trip. It takes visits to 5,000 flowers to make one jar of honey!',
    c: Color(0xFFF9A825), lc: Color(0xFFFFF9C4)),
];

// ── Screen ────────────────────────────────────────────────────────────────

class PrimaryFarmAnimalsScreen extends StatelessWidget {
  final EduRole role; final String schoolName; final String classId;
  const PrimaryFarmAnimalsScreen({super.key,
      required this.role, required this.schoolName, required this.classId});

  /// Derives a human-readable grade label from the classId.
  String get _grade {
    if (classId.contains('|')) {
      final parts = classId.split('|');
      const grades = ['Grade 1','Grade 2','Grade 3','Grade 4','Grade 5','Grade 6'];
      return grades.firstWhere(
        (g) => g.split(' ').last == parts[0],
        orElse: () => 'Grade 3');
    }
    final m = RegExp(r'_(\d+)$').firstMatch(classId);
    return m != null ? 'Grade ${m.group(1)}' : 'Grade 3';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFFF3E0),
    appBar: AppBar(backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white, title: const Text('Farm Animals'), elevation: 0),
    body: Column(children: [
      Container(width: double.infinity, padding: const EdgeInsets.fromLTRB(20,16,20,20),
        decoration: const BoxDecoration(color: Color(0xFFE65100),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('🐄 Farm Animals', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text('Tap each animal to learn what it gives us and how to care for it.',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
        ])),
      Expanded(child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          ..._animals.map((a) => _AnimalCard(animal: a, grade: _grade)),
          const SizedBox(height: 8),
          // ── AI Feature 3: Spot the Mistake ──────────────────────────
          PrimarySpotMistakeButton(
            topic: 'Farm Animals',
            grade: _grade,
            accentColor: const Color(0xFFE65100),
          ),
          // ── AI Feature 2: Mini Quiz ──────────────────────────────────
          _QuizButton(topic: 'Farm Animals', grade: _grade),
          const SizedBox(height: 32),
        ],
      )),
    ]),
  );
}

// ── Quiz launch button ────────────────────────────────────────────────────
class _QuizButton extends StatelessWidget {
  final String topic, grade;
  const _QuizButton({required this.topic, required this.grade});

  @override
  Widget build(BuildContext context) {
    const c = Color(0xFFE65100);
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
            builder: (_, sc) => PrimaryMiniQuizSheet(
              topic: topic, grade: grade, accentColor: c),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(12)),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.quiz_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Test Yourself! 🎯',
                style: TextStyle(color: Colors.white, fontSize: 14,
                    fontWeight: FontWeight.bold)),
          ]),
        ),
      ),
    );
  }
}

// ── Animal card ───────────────────────────────────────────────────────────
class _AnimalCard extends StatefulWidget {
  final _Animal animal;
  final String  grade;
  const _AnimalCard({required this.animal, required this.grade});
  @override State<_AnimalCard> createState() => _AnimalCardState();
}
class _AnimalCardState extends State<_AnimalCard> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    final a = widget.animal;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: a.c.withValues(alpha: 0.2)),
          boxShadow: [BoxShadow(color: a.c.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0,3))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          onTap: () => setState(() => _open = !_open),
          child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
            Container(width: 54, height: 54,
                decoration: BoxDecoration(color: a.lc, borderRadius: BorderRadius.circular(13)),
                child: Center(child: Text(a.emoji, style: const TextStyle(fontSize: 30)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: a.c)),
              Text(a.swahili, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              Text('Products: ${a.products}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ])),
            AnimatedRotation(turns: _open ? 0.5 : 0, duration: const Duration(milliseconds: 200),
                child: Icon(Icons.keyboard_arrow_down, color: a.c)),
          ])),
        ),
        if (_open) ...[
          ClipRRect(child: _Img(a.imageUrl)),
          _row(a, '🍽', 'What it eats', a.food),
          _row(a, '🏠', 'How to care for it', a.care),
          // ── AI Feature 6: Fun Fact Box (replaces static amber box) ──
          PrimaryFunFactBox(
            itemName:    a.name,
            initialFact: a.funFact,
          ),
          // ── AI Feature 1: Tap-to-Explain tooltip ────────────────────
          PrimaryAiTooltip(
            topic:       a.name,
            grade:       widget.grade,
            accentColor: a.c,
          ),
        ],
      ]),
    );
  }

  Widget _row(_Animal a, String icon, String label, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(14,12,14,0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('$icon ', style: const TextStyle(fontSize: 16)),
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: a.c)),
      ]),
      const SizedBox(height: 4),
      Text(text, style: const TextStyle(fontSize: 13.5, height: 1.5)),
    ]));
}