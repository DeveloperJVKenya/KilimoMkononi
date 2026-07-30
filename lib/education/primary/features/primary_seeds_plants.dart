// lib/education/primary/primary_seeds_plants.dart
import 'package:flutter/material.dart';
import 'package:kilimomkononi/models/education_user.dart';
import '../ai/primary_ai_tooltip.dart';
import '../ai/primary_fun_fact_box.dart';
import '../ai/primary_mini_quiz_sheet.dart';
import '../ai/primary_spot_mistake.dart';

class _Img extends StatelessWidget {
  final String url; final double h;
  const _Img(this.url, {this.h = 170});
  @override
  Widget build(BuildContext ctx) => Image.asset(url,
    height: h, width: double.infinity, fit: BoxFit.cover,
    errorBuilder: (_, _, _) => Container(height: h, color: const Color(0xFFF1F8E9),
      child: const Center(child: Icon(Icons.eco, size: 48, color: Color(0xFF2E7D32)))));
}

class _Stage { final String label, desc, url;
  const _Stage(this.label, this.desc, this.url); }

class _Crop {
  final String emoji, name, swahili, sci, about, funFact, mainUrl;
  final Color c, lc;
  final List<_Stage> stages;
  const _Crop({required this.emoji, required this.name, required this.swahili,
    required this.sci, required this.about, required this.funFact,
    required this.mainUrl, required this.c, required this.lc, required this.stages});
}

const _crops = <_Crop>[
  _Crop(emoji:'🌽', name:'Maize', swahili:'Mahindi', sci:'Zea mays',
    about:'Maize is Kenya\'s most important staple crop eaten by millions daily.\n\n'
        '• Seeds are yellow or white, planted 5 cm deep in rows 75 cm apart\n'
        '• Needs 400–800 mm of rainfall and good drainage\n'
        '• Two varieties: short-season (90 days) and long-season (120 days)\n'
        '• The whole plant is useful: cobs for food, stalks for animal feed, cobs for fuel',
    funFact:'One maize plant produces 2–3 cobs. Each cob has up to 800 seeds!',
    mainUrl:'assets/education/primary/crops/maize_main.jpg',
    c: Color(0xFFF9A825), lc: Color(0xFFFFF9C4),
    stages:[
      _Stage('1 · Seed','A dry maize grain is planted 5 cm deep in moist soil.',
        'assets/education/primary/crops/maize_seed.jpg'),
      _Stage('2 · Germination','In 5–10 days the seed sprouts and a shoot pushes through the soil.',
        'assets/education/primary/crops/maize_germination.jpg'),
      _Stage('3 · Seedling','At 3 weeks, 3–4 leaves appear. Weed the field now.',
        'assets/education/primary/crops/maize_seedling.jpg'),
      _Stage('4 · Tasselling','At 8–10 weeks the male flower (tassel) appears at the top.',
        'assets/education/primary/crops/maize_tassel.jpg'),
      _Stage('5 · Silking','Silk threads appear on the cob. Pollination happens here.',
        'assets/education/primary/crops/maize_silk.jpg'),
      _Stage('6 · Harvest','At 3–6 months the cob is dry and ready to pick.',
        'assets/education/primary/crops/maize_harvest.jpg'),
    ]),
  _Crop(emoji:'🫘', name:'Beans', swahili:'Maharagwe', sci:'Phaseolus vulgaris',
    about:'Beans are a vital protein food for Kenyan families.\n\n'
        '• Seeds can be red, white, black or spotted\n'
        '• Bush beans take less space; climbing beans need sticks\n'
        '• Ready to harvest in 60–90 days\n'
        '• Beans fix nitrogen in the soil — great for crop rotation\n'
        '• Rich in protein, iron and fibre',
    funFact:'Beans put nitrogen back into the soil, naturally fertilising it for the next crop!',
    mainUrl:'assets/education/primary/crops/beans_main.jpg',
    c: Color(0xFF8D4E85), lc: Color(0xFFF3E5F5),
    stages:[
      _Stage('1 · Seed','Bean seeds soaked briefly in water then planted 3 cm deep.',
        'assets/education/primary/crops/beans_seed.jpg'),
      _Stage('2 · Sprout','Sprouts appear in 5–8 days with two round seed leaves.',
        'assets/education/primary/crops/beans_sprout.jpg'),
      _Stage('3 · Flower','White or purple flowers appear at 6–8 weeks.',
        'assets/education/primary/crops/beans_flower.jpg'),
      _Stage('4 · Pod','Pods swell with seeds. Harvest green or let dry on the plant.',
        'assets/education/primary/crops/beans_pod.jpg'),
    ]),
  _Crop(emoji:'🥬', name:'Kale (Sukuma Wiki)', swahili:'Sukuma Wiki', sci:'Brassica oleracea',
    about:'Sukuma wiki is the most widely eaten vegetable in Kenya.\n\n'
        '• Tiny round seeds are planted in a nursery first\n'
        '• Transplanted when seedlings are 4–5 weeks old\n'
        '• A single plant is harvested many times — outer leaves cut while centre grows\n'
        '• Ready to harvest from 6 weeks onwards\n'
        '• Rich in iron, calcium and vitamins A and C',
    funFact:'"Sukuma wiki" means "push the week" in Swahili — it helps families eat all week long!',
    mainUrl:'assets/education/primary/crops/kale_main.jpg',
    c: Color(0xFF2E7D32), lc: Color(0xFFE8F5E9),
    stages:[
      _Stage('1 · Nursery','Tiny seeds sown in a nursery bed, watered twice daily.',
        'assets/education/primary/crops/kale_nursery.jpg'),
      _Stage('2 · Transplant','At 4–5 weeks, seedlings moved to the main garden.',
        'assets/education/primary/crops/kale_transplant.jpg'),
      _Stage('3 · Harvest','Outer leaves cut as needed. The plant keeps growing!',
        'assets/education/primary/crops/kale_harvest.jpg'),
    ]),
  _Crop(emoji:'🥕', name:'Carrot', swahili:'Karoti', sci:'Daucus carota',
    about:'Carrots grow the orange root underground where you cannot see it.\n\n'
        '• Seeds are very small — mix with sand for even planting\n'
        '• Need loose, deep soil so the root can grow straight\n'
        '• Ready in 70–80 days from sowing\n'
        '• Water regularly — irregular watering causes the root to crack\n'
        '• Rich in Vitamin A which protects your eyesight',
    funFact:'Carrots were originally PURPLE, not orange! Dutch farmers bred orange ones in the 1600s.',
    mainUrl:'assets/education/primary/crops/carrot_main.jpg',
    c: Color(0xFFE65100), lc: Color(0xFFFFF3E0),
    stages:[
      _Stage('1 · Seed','Very tiny seeds mixed with sand, sown in rows, covered lightly.',
        'assets/education/primary/crops/carrot_seed.jpg'),
      _Stage('2 · Sprout','Thin seedlings appear. Thin them out so roots have space.',
        'assets/education/primary/crops/carrot_sprout.jpg'),
      _Stage('3 · Root growth','The orange root swells underground over 10–12 weeks.',
        'assets/education/primary/crops/carrot_growth.jpg'),
      _Stage('4 · Harvest','Pull out when shoulders are visible at soil surface.',
        'assets/education/primary/crops/carrot_harvest.jpg'),
    ]),
  _Crop(emoji:'🍅', name:'Tomato', swahili:'Nyanya', sci:'Solanum lycopersicum',
    about:'Tomatoes are one of the most valuable vegetable crops in Kenya.\n\n'
        '• Started in a nursery, transplanted at 4–6 weeks old\n'
        '• Need stakes or strings as they grow tall\n'
        '• Require careful pest and disease management — blight is a big risk\n'
        '• Ready in 70–90 days after transplanting\n'
        '• Rich in Vitamin C and lycopene',
    funFact:'A tomato is scientifically a FRUIT — it contains seeds and develops from a flower!',
    mainUrl:'assets/education/primary/crops/tomato_main.jpg',
    c: Color(0xFFC62828), lc: Color(0xFFFFEBEE),
    stages:[
      _Stage('1 · Seed','Flat, fuzzy seeds planted in nursery trays, germinate in 5–7 days.',
        'assets/education/primary/crops/tomato_seed.jpg'),
      _Stage('2 · Seedling','At 4–6 weeks, transplant to field. Stake the plant.',
        'assets/education/primary/crops/tomato_seedling.jpg'),
      _Stage('3 · Flower','Yellow flowers appear — each one can become a tomato.',
        'assets/education/primary/crops/tomato_flower.jpg'),
      _Stage('4 · Harvest','Red ripe fruits picked 70–90 days after transplanting.',
        'assets/education/primary/crops/tomato_harvest.jpg'),
    ]),
  _Crop(emoji:'🥜', name:'Groundnuts', swahili:'Karanga', sci:'Arachis hypogaea',
    about:'Groundnuts (peanuts) are special — their pods develop underground!\n\n'
        '• Seeds planted 5 cm deep in well-drained sandy loam soil\n'
        '• After flowering, a "peg" grows down into the soil where the pod forms\n'
        '• Ready in 90–120 days\n'
        '• Rich in protein, healthy oils and energy\n'
        '• Used to make peanut butter, cooking oil and animal feed',
    funFact:'Groundnuts are not really nuts — they are legumes, related to beans and peas!',
    mainUrl:'assets/education/primary/crops/groundnuts_main.jpg',
    c: Color(0xFF795548), lc: Color(0xFFEFEBE9),
    stages:[
      _Stage('1 · Seed','Seeds planted 5 cm deep, 15 cm apart in well-drained soil.',
        'assets/education/primary/crops/groundnuts_seed.jpg'),
      _Stage('2 · Flower','Yellow flowers appear at 4–6 weeks.',
        'assets/education/primary/crops/groundnuts_flower.jpg'),
      _Stage('3 · Pegging','After flowering a "peg" bends down and enters the soil where the pod forms.',
        'assets/education/primary/crops/groundnuts_peg.jpg'),
      _Stage('4 · Harvest','Pull up the whole plant. Pods found attached to the roots.',
        'assets/education/primary/crops/groundnuts_harvest.jpg'),
    ]),
];

// ── Screen ─────────────────────────────────────────────────────────
class PrimarySeedsPlantsScreen extends StatelessWidget {
  final EduRole role; final String schoolName; final String classId;
  const PrimarySeedsPlantsScreen({super.key,
      required this.role, required this.schoolName, required this.classId});

  String get _grade {
    if (classId.contains('|')) {
      final parts = classId.split('|');
      const grades = ['Grade 1','Grade 2','Grade 3','Grade 4','Grade 5','Grade 6'];
      return grades.firstWhere((g) => g.split(' ').last == parts[0], orElse: () => 'Grade 3');
    }
    final m = RegExp(r'_(\d+)$').firstMatch(classId);
    return m != null ? 'Grade ${m.group(1)}' : 'Grade 3';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF1F8E9),
    appBar: AppBar(
      backgroundColor: const Color(0xFF2E7D32),
      foregroundColor: Colors.white,
      title: const Text('Seeds & Plants'),
      elevation: 0,
    ),
    body: Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: const BoxDecoration(
          color: Color(0xFF2E7D32),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        child: const Text(
          'Tap any crop to see how it grows — with pictures!',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ),
      Expanded(child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          ..._crops.map((crop) => _CropCard(crop: crop, grade: _grade)),
          const SizedBox(height: 8),
          PrimarySpotMistakeButton(topic: 'Seeds & Plants', grade: _grade,
              accentColor: const Color(0xFF2E7D32)),
          _PrimaryQuizButton(topic: 'Seeds & Plants', grade: _grade,
              accentColor: const Color(0xFF2E7D32)),
          const SizedBox(height: 32),
        ],
      )),
    ]),
  );
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

class _CropCard extends StatefulWidget {
  final _Crop crop; final String grade;
  const _CropCard({required this.crop, required this.grade});
  @override State<_CropCard> createState() => _CropCardState();
}
class _CropCardState extends State<_CropCard> {
  bool _open = false; int _si = 0;
  @override
  Widget build(BuildContext context) {
    final it = widget.crop;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: it.c.withValues(alpha: 0.2)),
          boxShadow: [BoxShadow(color: it.c.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0,3))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          onTap: () => setState(() => _open = !_open),
          child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
            Container(width: 54, height: 54,
                decoration: BoxDecoration(color: it.lc, borderRadius: BorderRadius.circular(13)),
                child: Center(child: Text(it.emoji, style: const TextStyle(fontSize: 30)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(it.name, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: it.c)),
              Text(it.swahili, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              Text(it.sci, style: TextStyle(fontSize: 11, color: Colors.grey.shade400,
                  fontStyle: FontStyle.italic)),
            ])),
            AnimatedRotation(turns: _open ? 0.5 : 0, duration: const Duration(milliseconds: 200),
                child: Icon(Icons.keyboard_arrow_down, color: it.c)),
          ])),
        ),
        if (_open) ...[
          ClipRRect(child: _Img(it.mainUrl, h: 155)),
          Padding(padding: const EdgeInsets.fromLTRB(14,12,14,0),
              child: Text(it.about, style: const TextStyle(fontSize: 13.5, height: 1.55))),
          Padding(padding: const EdgeInsets.fromLTRB(14,14,14,6),
              child: Text('🌱 Growth Stages — tap a stage to see',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: it.c))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SingleChildScrollView(scrollDirection: Axis.horizontal,
              child: Row(children: it.stages.asMap().entries.map((e) {
                final sel = e.key == _si;
                return GestureDetector(
                  onTap: () => setState(() => _si = e.key),
                  child: Container(margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? it.c : it.lc, borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: it.c.withValues(alpha: 0.35))),
                    child: Text(e.value.label, style: TextStyle(fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: sel ? Colors.white : it.c))),
                );
              }).toList()),
            ),
          ),
          const SizedBox(height: 10),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 14),
              child: ClipRRect(borderRadius: BorderRadius.circular(12),
                  child: _Img(it.stages[_si].url, h: 150))),
          Padding(padding: const EdgeInsets.fromLTRB(14,8,14,0),
              child: Text(it.stages[_si].desc,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4))),
          // AI Fun Fact + Ask AI
          PrimaryFunFactBox(itemName: it.name, initialFact: it.funFact),
          PrimaryAiTooltip(topic: it.name, grade: widget.grade, accentColor: it.c),
        ],
      ]),
    );
  }
}