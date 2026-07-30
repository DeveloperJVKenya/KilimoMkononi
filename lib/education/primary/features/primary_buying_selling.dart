// lib/education/primary/primary_buying_selling.dart
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
    errorBuilder: (_, _, _) => Container(height: h, color: const Color(0xFFF3E5F5),
        child: const Center(child: Icon(Icons.storefront, size: 48, color: Color(0xFF6A1B9A)))));
}

class _Item {
  final String emoji, title, subtitle, body, funFact, imageUrl;
  const _Item({required this.emoji, required this.title, required this.subtitle,
      required this.body, required this.funFact, required this.imageUrl});
}

const _markets = <_Item>[
  _Item(emoji:'🏬', title:'Local Market', subtitle:'Sell directly to buyers',
    imageUrl:'assets/education/primary/markets/local_market.jpg',
    body:'Farmers carry or transport produce to the nearest town market.\n\n'
        '• No middleman — the farmer receives the full price\n'
        '• Flexible: you can sell any quantity\n'
        '• Prices change daily depending on supply\n'
        '• Examples: Marikiti, Wakulima Market (Nairobi), Kongowea (Mombasa)\n'
        '• Best for: fresh vegetables, fruits, eggs, small quantities',
    funFact:'Wakulima Market in Nairobi handles over 1,000 tonnes of produce every day!'),
  _Item(emoji:'🚚', title:'Broker / Middleman', subtitle:'Convenient but lower price',
    imageUrl:'assets/education/primary/markets/broker_truck.jpg',
    body:'A broker buys produce from the farmer and resells it to shops or markets.\n\n'
        '• Comes to the farm — no transport needed for the farmer\n'
        '• Pays less than market price — they need to make a profit too\n'
        '• Useful when you have large quantities to sell quickly\n'
        '• Risk: some brokers pay very low prices\n'
        '• Tip: know the current market price before negotiating',
    funFact:'A clever farmer can negotiate with 2–3 brokers at once to get the best price!'),
  _Item(emoji:'🏭', title:'Factory / Processor', subtitle:'Large volumes, stable price',
    imageUrl:'assets/education/primary/markets/factory_processing.jpg',
    body:'Factories buy large quantities to process into products.\n\n'
        '• Examples: KCC (milk), Kitui Soko (tomato paste), Bidco (cooking oil)\n'
        '• Prices are fixed in advance — no market price changes\n'
        '• Requires consistent quality and large quantities\n'
        '• Payment is usually reliable and on time\n'
        '• Best for: milk, sugar cane, wheat, sunflower',
    funFact:'KCC (Kenya Co-operative Creameries) collects milk from over 100,000 farmers across Kenya every day!'),
  _Item(emoji:'📱', title:'Digital Market (App / M-Pesa)', subtitle:'Modern and growing fast',
    imageUrl:'assets/education/primary/markets/mpesa_digital.jpg',
    body:'Farmers can now sell through apps and receive payment by M-Pesa.\n\n'
        '• Examples: Twiga Foods, Mkulima Young, AgroStar, DigiFarm\n'
        '• Better prices — connects farmers directly to buyers\n'
        '• Payment arrives on your phone — no carrying cash\n'
        '• Can track orders and prices from anywhere\n'
        '• Growing fast — young farmers are using this most',
    funFact:'Twiga Foods has paid over KSh 5 billion directly to Kenyan farmers via mobile phone!'),
];

const _prices = <_Item>[
  _Item(emoji:'📈', title:'Supply and Demand', subtitle:'Why prices go up and down',
    imageUrl:'assets/education/primary/markets/market_price.jpg',
    body:'Prices are controlled by how much is available and how many people want it.\n\n'
        '• Too many farmers harvest at the same time → price FALLS\n'
        '• Drought reduces supply → price RISES\n'
        '• This is why TIMING your harvest matters greatly\n'
        '• Strategy: plant early or late to avoid the flood of supply\n'
        '• Lesson: always check market prices before planting!',
    funFact:'During the maize harvest season in Kenya, prices can drop by 50% — then rise again in the dry season!'),
  _Item(emoji:'🧮', title:'Calculating Profit', subtitle:'Know your money',
    imageUrl:'assets/education/primary/markets/mpesa_payment.jpg',
    body:'Profit = Money earned − Money spent on farming\n\n'
        'Costs include: seeds, fertiliser, water, labour, transport\n\n'
        'Example:\n'
        '• Cost to grow 1 bag of tomatoes = KSh 2,000\n'
        '• Sold for = KSh 3,500\n'
        '• Profit = KSh 1,500\n\n'
        'Always keep a simple record book. Write down every expense and every sale!',
    funFact:'Farmers who keep records earn on average 30% more than those who don\'t — knowledge is money!'),
];

const _postharvest = <_Item>[
  _Item(emoji:'🌬️', title:'Drying', subtitle:'Reduces moisture, prevents mould',
    imageUrl:'assets/education/primary/markets/maize_drying.jpg',
    body:'After harvesting, crops must be dried before storage or sale.\n\n'
        '• Spread maize, beans or sorghum on a clean tarpaulin in full sun\n'
        '• Stir every 2–3 hours for even drying\n'
        '• Maize should be below 13% moisture before bagging\n'
        '• Wet grain heats up in the bag and grows mould (aflatoxin)\n'
        '• Aflatoxin is very dangerous — it is invisible and toxic',
    funFact:'Poorly dried maize kills and hospitalises thousands of Kenyans each year due to aflatoxin poisoning!'),
  _Item(emoji:'🧺', title:'Sorting & Grading', subtitle:'Quality earns more money',
    imageUrl:'assets/education/primary/markets/tomato_sorting.jpg',
    body:'Before selling, sort your produce into quality categories.\n\n'
        '• Grade A: perfect, uniform, no blemishes — highest price\n'
        '• Grade B: slightly imperfect — sold to processors\n'
        '• Remove rotten, damaged and undersized produce\n'
        '• Buyers pay 20–40% more for well-graded produce\n'
        '• Weigh accurately — use a certified scale',
    funFact:'Well-graded tomatoes can sell for twice the price of unsorted ones in the same market!'),
  _Item(emoji:'📦', title:'Storage', subtitle:'Keep produce fresh longer',
    imageUrl:'assets/education/primary/markets/hermetic_bags.jpg',
    body:'Good storage prevents losses and lets you sell when prices are high.\n\n'
        '• Use hermetic (airtight) bags for grain — kills insects without chemicals\n'
        '• Cool, dark, dry stores prevent mould and pests\n'
        '• Never store on bare ground — use pallets to allow air flow\n'
        '• Vegetables need cool temperatures — use a simple cool store or sell quickly\n'
        '• Post-harvest losses in Kenya = 30% of all food produced!',
    funFact:'Kenya loses food worth KSh 150 billion every year due to poor storage — good storage is like growing more crops!'),
];

// ── Screen ────────────────────────────────────────────────────────────────
class PrimaryBuyingSellingScreen extends StatelessWidget {
  final EduRole role; final String schoolName; final String classId;
  const PrimaryBuyingSellingScreen({super.key,
      required this.role, required this.schoolName, required this.classId});

  String get _grade {
    if (classId.contains('|')) {
      final parts = classId.split('|');
      const grades = ['Grade 1','Grade 2','Grade 3','Grade 4','Grade 5','Grade 6'];
      return grades.firstWhere((g) => g.split(' ').last == parts[0], orElse: () => 'Grade 5');
    }
    final m = RegExp(r'_(\d+)$').firstMatch(classId);
    return m != null ? 'Grade ${m.group(1)}' : 'Grade 5';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF3E5F5),
    appBar: AppBar(
      backgroundColor: const Color(0xFF6A1B9A),
      foregroundColor: Colors.white,
      title: const Text('Buying & Selling'),
      elevation: 0,
    ),
    body: Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: const BoxDecoration(
          color: Color(0xFF6A1B9A),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        child: const Text(
          'Learn where and how farmers sell their crops and earn money.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ),
      Expanded(child: ListView(padding: const EdgeInsets.all(14), children: [
        _sec('🏪 Where to Sell', const Color(0xFF6A1B9A)),
        ..._markets.map((m) => _Card(item: m, c: const Color(0xFF6A1B9A), grade: _grade)),
        const SizedBox(height: 8),
        _sec('💰 How Prices Work', const Color(0xFF4A148C)),
        ..._prices.map((p) => _Card(item: p, c: const Color(0xFF4A148C), grade: _grade)),
        const SizedBox(height: 8),
        _sec('📦 After Harvest — Getting Ready to Sell', const Color(0xFF7B1FA2)),
        ..._postharvest.map((p) => _Card(item: p, c: const Color(0xFF7B1FA2), grade: _grade)),
        const SizedBox(height: 8),
        PrimarySpotMistakeButton(topic: 'Buying & Selling', grade: _grade,
            accentColor: const Color(0xFF6A1B9A)),
        _PrimaryQuizButton(topic: 'Buying & Selling', grade: _grade,
            accentColor: const Color(0xFF6A1B9A)),
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
  final _Item item; final Color c; final String grade;
  const _Card({required this.item, required this.c, required this.grade});
  @override State<_Card> createState() => _CardState();
}
class _CardState extends State<_Card> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    final it = widget.item; final c = widget.c;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.withValues(alpha: 0.18)),
          boxShadow: [BoxShadow(color: c.withValues(alpha: 0.07), blurRadius: 6, offset: const Offset(0,3))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          onTap: () => setState(() => _open = !_open),
          child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
            Text(it.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(it.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c)),
              Text(it.subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
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