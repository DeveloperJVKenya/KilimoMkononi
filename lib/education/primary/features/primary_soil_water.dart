// lib/education/primary/primary_soil_water.dart
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
    errorBuilder: (_, _, _) => Container(height: h, color: const Color(0xFFE1F5FE),
        child: const Center(child: Icon(Icons.water_drop, size: 48, color: Color(0xFF0277BD)))));
}

class _InfoItem {
  final String emoji, title, highlight, body, funFact, imageUrl;
  const _InfoItem({required this.emoji, required this.title, required this.highlight,
      required this.body, required this.funFact, required this.imageUrl});
}

const _soils = <_InfoItem>[
  _InfoItem(emoji:'🟤', title:'Clay Soil', highlight:'Holds nutrients very well',
    imageUrl:'assets/education/primary/soil_water/clay_soil.jpg',
    body:'Clay soil is made of very fine particles packed tightly together.\n\n'
        '• Holds water well — good in dry seasons\n'
        '• Rich in plant nutrients\n'
        '• Sticky and heavy when wet, hard when dry\n'
        '• Can waterlog in heavy rain — roots may rot\n'
        '• Good for: rice, sugar cane, cotton\n'
        '• TIP: Add compost or sand to improve drainage',
    funFact:'Clay soil is used to make traditional pots, bricks and building blocks!'),
  _InfoItem(emoji:'🟡', title:'Sandy Soil', highlight:'Drains quickly, warms up fast',
    imageUrl:'assets/education/primary/soil_water/sandy_soil.jpg',
    body:'Sandy soil has large, coarse particles with big spaces between them.\n\n'
        '• Drains very fast — water flows through quickly\n'
        '• Easy to dig even when dry\n'
        '• Warms up quickly in the sun\n'
        '• Does NOT hold water or nutrients well\n'
        '• Good for: cassava, sweet potatoes, carrots, pineapple\n'
        '• TIP: Add plenty of organic matter (manure, compost)',
    funFact:'Sandy soil warms up so fast it can be used to start germination earlier than other soils!'),
  _InfoItem(emoji:'🟠', title:'Loam Soil', highlight:'The BEST soil for most crops',
    imageUrl:'assets/education/primary/soil_water/loam_soil.jpg',
    body:'Loam is a perfect mix of clay, sand and silt particles.\n\n'
        '• Holds water AND drains excess water well\n'
        '• Rich in nutrients\n'
        '• Easy to work with in both wet and dry conditions\n'
        '• Good for: almost all crops — maize, beans, kale, tomatoes\n'
        '• Most fertile farmland in Kenya has loam soil\n'
        '• TIP: Maintain with regular compost to keep it fertile',
    funFact:'Most of Kenya\'s best farming regions — Kiambu, Meru, Trans Nzoia — have loam soil!'),
  _InfoItem(emoji:'⚫', title:'Black Cotton Soil', highlight:'Expands when wet, cracks when dry',
    imageUrl:'assets/education/primary/soil_water/black_cotton_soil.jpg',
    body:'Black cotton soil is found in the drier parts of Kenya.\n\n'
        '• Swells and becomes very sticky when wet\n'
        '• Shrinks and cracks into large blocks when dry\n'
        '• Very fertile — rich in minerals\n'
        '• Difficult to farm — tractors get stuck when wet\n'
        '• Good for: cotton, sorghum, sunflower\n'
        '• TIP: Build raised beds to improve drainage',
    funFact:'Black cotton soil can swallow a tractor wheel in the rainy season — it is that sticky!'),
];

const _water = <_InfoItem>[
  _InfoItem(emoji:'🚿', title:'Furrow (Surface) Irrigation', highlight:'Good for flat land',
    imageUrl:'assets/education/primary/soil_water/furrow_irrigation.jpg',
    body:'Water is guided along channels (furrows) between crop rows.\n\n'
        '• The oldest and most common irrigation method\n'
        '• Simple and cheap to set up — no equipment needed\n'
        '• Works best on gently sloping or flat land\n'
        '• Uses a lot of water — not ideal in dry areas\n'
        '• Risk of waterlogging if too much water is applied',
    funFact:'Furrow irrigation has been used by farmers in Egypt and Iraq for over 6,000 years!'),
  _InfoItem(emoji:'💧', title:'Drip Irrigation', highlight:'Saves up to 60% water',
    imageUrl:'assets/education/primary/soil_water/drip_irrigation.jpg',
    body:'Pipes with tiny holes deliver water drop-by-drop directly to roots.\n\n'
        '• Very efficient — water goes exactly where it\'s needed\n'
        '• Saves 40–60% water compared to surface methods\n'
        '• Reduces disease — leaves stay dry\n'
        '• Can also deliver fertiliser through the pipes\n'
        '• Used in: greenhouses, tomatoes, onions, strawberries',
    funFact:'Drip irrigation was invented in Israel in the 1960s to farm the desert — it transformed farming!'),
  _InfoItem(emoji:'🪣', title:'Watering Can / Bucket', highlight:'Perfect for small gardens',
    imageUrl:'assets/education/primary/tools/watering_can.jpg',
    body:'Simple containers used to carry and pour water by hand.\n\n'
        '• Best for small vegetable gardens and nurseries\n'
        '• The "rose" sprayhead protects seedlings from heavy drops\n'
        '• Water at the BASE of the plant — not on the leaves\n'
        '• Water early in the morning — reduces evaporation\n'
        '• Cheap, easy to use and maintain',
    funFact:'A watering can with a rose delivers water at over 1,000 tiny drops per second!'),
  _InfoItem(emoji:'🌧️', title:'Rainwater Harvesting', highlight:'Free, natural and eco-friendly',
    imageUrl:'assets/education/primary/soil_water/rainwater_tank.jpg',
    body:'Collecting rainwater from rooftops or land for later use.\n\n'
        '• Rooftop harvesting: gutters collect rain into tanks\n'
        '• Zai pits: small holes in soil capture rain directly\n'
        '• Kenya\'s long rains: March–May | Short rains: October–December\n'
        '• Water stored in tanks can last through the dry season\n'
        '• Cheap way to have water even when rivers are dry',
    funFact:'A 10m² roof in Nairobi can collect over 1,000 litres of water from a single heavy rainstorm!'),
];

// ── Screen ────────────────────────────────────────────────────────────────
class PrimarySoilWaterScreen extends StatelessWidget {
  final EduRole role; final String schoolName; final String classId;
  const PrimarySoilWaterScreen({super.key,
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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFE1F5FE),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0277BD),
      foregroundColor: Colors.white,
      title: const Text('Soil & Water'),
      elevation: 0,
    ),
    body: Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: const BoxDecoration(
          color: Color(0xFF0277BD),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        child: const Text(
          'Learn about different soils and how to water your crops wisely.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ),
      Expanded(child: ListView(padding: const EdgeInsets.all(14), children: [
        _sec('🪨 Types of Soil', const Color(0xFF0277BD)),
        ..._soils.map((s) => _Card(item: s, color: const Color(0xFF0277BD), grade: _grade)),
        const SizedBox(height: 8),
        _sec('💧 Watering & Irrigation', const Color(0xFF01579B)),
        ..._water.map((w) => _Card(item: w, color: const Color(0xFF01579B), grade: _grade)),
        const SizedBox(height: 8),
        PrimarySpotMistakeButton(topic: 'Soil & Water', grade: _grade, accentColor: const Color(0xFF0277BD)),
        _PrimaryQuizButton(topic: 'Soil & Water', grade: _grade, accentColor: const Color(0xFF0277BD)),
        const SizedBox(height: 32),
      ])),
    ]),
  );

  static Widget _sec(String t, Color c) => Padding(
    padding: const EdgeInsets.fromLTRB(0,8,0,10),
    child: Text(t, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: c)));
}

class _PrimaryQuizButton extends StatelessWidget {
  final String topic, grade; final Color accentColor;
  const _PrimaryQuizButton({required this.topic, required this.grade, required this.accentColor});
  @override
  Widget build(BuildContext context) {
    final c = accentColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showModalBottomSheet(
          context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
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

class _Card extends StatefulWidget {
  final _InfoItem item; final Color color; final String grade;
  const _Card({required this.item, required this.color, required this.grade});
  @override State<_Card> createState() => _CardState();
}
class _CardState extends State<_Card> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    final it = widget.item; final c = widget.color;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.withOpacity(0.18)),
          boxShadow: [BoxShadow(color: c.withOpacity(0.06), blurRadius: 6, offset: const Offset(0,3))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          onTap: () => setState(() => _open = !_open),
          child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
            Text(it.emoji, style: const TextStyle(fontSize: 30)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(it.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c)),
              Text(it.highlight, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ])),
            AnimatedRotation(turns: _open ? 0.5 : 0, duration: const Duration(milliseconds: 200),
                child: Icon(Icons.keyboard_arrow_down, color: c)),
          ])),
        ),
        if (_open) ...[
          ClipRRect(child: _Img(it.imageUrl)),
          Padding(padding: const EdgeInsets.fromLTRB(14,12,14,12),
              child: Text(it.body, style: const TextStyle(fontSize: 13.5, height: 1.55))),
          PrimaryFunFactBox(itemName: it.title, initialFact: it.funFact),
          PrimaryAiTooltip(topic: it.title, grade: widget.grade, accentColor: c),
        ],
      ]),
    );
  }
}