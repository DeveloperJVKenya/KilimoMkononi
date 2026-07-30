// lib/education/simulations/market_trading_simulation.dart
//
// FLAME ENGINE — MarketTradingSimulation
//
// MarketGame (FlameGame)
//   ├── MarketBackgroundComponent  — animated market stall scene
//   │     draws awnings, stall tables, sky gradient, animated sun/clouds
//   ├── PriceTickerComponent       — scrolling price board at the top
//   │     moves left autonomously every frame via update(dt)
//   ├── CommodityStallComponent×6  — each stall is tappable
//   │     glows/pulses when price is rising; dims when falling
//   │     shows live sparkline drawn in render(Canvas)
//   └── CustomerComponent          — buyers walk across the market floor
//         when the student sells, a customer animates toward the stall
//
// Flutter UI below: trade panel, day controls, news banner

import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:kilimomkononi/education/simulations/simulation_result_screen.dart';
import 'package:kilimomkononi/education/simulations/gemini_simulation_service.dart';
import 'package:kilimomkononi/education/tutor/tutor_chat_screen.dart';

const Color _mktGreen = Color(0xFF003900);
const Color _mktAmber = Color(0xFFFF8F00);
const Color _mktRed   = Color(0xFFC62828);

// ── Data models ──────────────────────────────────────────────────────────────
class Commodity {
  final String name, emoji;
  double price;
  int owned;
  List<double> priceHistory;
  Commodity({required this.name, required this.emoji, required this.price, this.owned = 0})
      : priceHistory = [price];
  void recordPrice() => priceHistory.add(price);
  bool get rising => priceHistory.length > 1 && price > priceHistory[priceHistory.length - 2];
}

class NewsEvent {
  final String headline, detail, commodity, icon;
  final double effect;
  const NewsEvent({required this.headline, required this.detail,
      required this.commodity, required this.effect, required this.icon});
}

const _newsPool = [
  NewsEvent(headline: 'Drought hits Rift Valley', detail: 'Maize prices rising sharply.', commodity: 'Maize', effect: 1.35, icon: '☀️'),
  NewsEvent(headline: 'Bumper tomato harvest', detail: 'Oversupply — tomato prices fall.', commodity: 'Tomatoes', effect: 0.65, icon: '🍅'),
  NewsEvent(headline: 'School holidays boost demand', detail: 'Cabbage and potatoes high demand.', commodity: 'Cabbage', effect: 1.25, icon: '🏫'),
  NewsEvent(headline: 'Fuel cost increase', detail: 'All produce prices up slightly.', commodity: 'All', effect: 1.10, icon: '⛽'),
  NewsEvent(headline: 'Heavy rains damage potatoes', detail: 'Potato prices spike.', commodity: 'Potatoes', effect: 1.45, icon: '🌧️'),
  NewsEvent(headline: 'New market road opens', detail: 'Prices stabilize.', commodity: 'All', effect: 0.95, icon: '🛣️'),
  NewsEvent(headline: 'Maize export ban lifted', detail: 'Local prices drop.', commodity: 'Maize', effect: 0.75, icon: '📦'),
];

// ═══════════════════════════════════════════════════════════════════════════
//  MarketBackgroundComponent — animated scene behind stalls
// ═══════════════════════════════════════════════════════════════════════════
class MarketBackgroundComponent extends PositionComponent {
  double _t = 0;
  MarketBackgroundComponent({required Vector2 size}) : super(size: size);

  @override void update(double dt) => _t += dt * 0.4;

  @override
  void render(Canvas canvas) {
    // Sky
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y * 0.45),
        Paint()..shader = const LinearGradient(
            colors: [Color(0xFF87CEEB), Color(0xFFB3E5FC)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter)
            .createShader(Rect.fromLTWH(0, 0, size.x, size.y * 0.45)));

    // Sun
    canvas.drawCircle(Offset(size.x * 0.88, size.y * 0.12), 18,
        Paint()..color = Colors.yellow.shade600);

    // Ground / market floor
    canvas.drawRect(Rect.fromLTWH(0, size.y * 0.45, size.x, size.y * 0.55),
        Paint()..color = const Color(0xFFD7CCC8));

    // Market awning stripes (6 stalls)
    final stallW = size.x / 6;
    final awningColors = [Colors.red.shade600, Colors.blue.shade600,
        Colors.green.shade600, Colors.orange.shade600,
        Colors.purple.shade600, Colors.teal.shade600];
    for (int i = 0; i < 6; i++) {
      final x = i * stallW;
      final awningPaint = Paint()..color = awningColors[i % awningColors.length];
      // Awning
      canvas.drawRect(Rect.fromLTWH(x + 2, size.y * 0.40, stallW - 4, 14), awningPaint);
      // Awning stripes (white)
      for (double sx = x + 4; sx < x + stallW - 4; sx += 8) {
        canvas.drawRect(Rect.fromLTWH(sx, size.y * 0.40, 4, 14),
            Paint()..color = Colors.white.withValues(alpha: 0.4));
      }
      // Stall table
      canvas.drawRect(Rect.fromLTWH(x + 4, size.y * 0.54, stallW - 8, 10),
          Paint()..color = const Color(0xFF8D6E63));
    }

    // Animated customers walking
    for (int i = 0; i < 3; i++) {
      final cx = ((_t * 30 * (i + 1) * 0.5) % (size.x + 20)) - 10;
      final cy = size.y * 0.70 + i * 12;
      _drawCustomer(canvas, Offset(cx, cy));
    }
  }

  void _drawCustomer(Canvas canvas, Offset pos) {
    // Head
    canvas.drawCircle(pos + const Offset(0, -16), 6,
        Paint()..color = const Color(0xFFFFCC80));
    // Body
    canvas.drawRect(Rect.fromLTWH(pos.dx - 4, pos.dy - 10, 8, 12),
        Paint()..color = Colors.indigo.shade400);
    // Legs
    final lp = Paint()..color = Colors.brown.shade700..strokeWidth = 3;
    canvas.drawLine(pos + const Offset(-3, 2), pos + const Offset(-3, 12), lp);
    canvas.drawLine(pos + const Offset(3, 2), pos + const Offset(3, 12), lp);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  PriceTickerComponent — scrolling price board
// ═══════════════════════════════════════════════════════════════════════════
class PriceTickerComponent extends PositionComponent {
  List<Commodity> commodities;
  double _offset = 0;
  static const double speed = 55;

  PriceTickerComponent({required this.commodities, required Vector2 position})
      : super(position: position, size: Vector2(double.infinity, 28));

  @override
  void update(double dt) {
    _offset += speed * dt;
    final totalWidth = commodities.length * 160.0 * 3;
    if (_offset > totalWidth / 3) _offset -= totalWidth / 3;
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(Rect.fromLTWH(0, 0, 2000, 28),
        Paint()..color = Colors.black87);
    double x = -_offset;
    // Repeat 3× so it always fills
    for (int rep = 0; rep < 3; rep++) {
      for (final c in commodities) {
        final prev = c.priceHistory.length > 1
            ? c.priceHistory[c.priceHistory.length - 2] : c.price;
        final up = c.price >= prev;
        TextPaint(style: TextStyle(
          fontSize: 11, color: up ? Colors.greenAccent : Colors.redAccent,
          fontWeight: FontWeight.bold,
        )).render(canvas,
            '${c.emoji} ${c.name}: KES ${c.price.toStringAsFixed(0)} ${up ? "▲" : "▼"}  ',
            Vector2(x + 8, 6));
        x += 160;
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  CommodityStallComponent — tappable stall with live sparkline
// ═══════════════════════════════════════════════════════════════════════════
class CommodityStallComponent extends PositionComponent with TapCallbacks {
  final Commodity commodity;
  final void Function(Commodity c) onTap;
  bool selected = false;
  double _t = 0;
  final List<Color> awningColors = [
    Colors.red.shade600, Colors.blue.shade600, Colors.green.shade600,
    Colors.orange.shade600, Colors.purple.shade600, Colors.teal.shade600,
  ];
  final int index;

  CommodityStallComponent({
    required this.commodity, required this.onTap, required this.index,
    required Vector2 position, required Vector2 size,
  }) : super(position: position, size: size);

  @override
  void onTapDown(TapDownEvent event) => onTap(commodity);

  @override
  void update(double dt) => _t += dt * (commodity.rising ? 3.0 : 1.5);

  @override
  void render(Canvas canvas) {
    final isRising = commodity.rising;
    final glow = selected
        ? Colors.amber.withValues(alpha: 0.3)
        : isRising
            ? Colors.green.withValues(alpha: 0.15 + 0.08 * sin(_t))
            : Colors.transparent;

    // Background glow
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.x, size.y), const Radius.circular(10)),
      Paint()..color = glow,
    );

    // Card border
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.x, size.y), const Radius.circular(10)),
      Paint()
        ..color = selected ? Colors.amber : (isRising ? Colors.green : Colors.grey.shade300)
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 2.5 : 1.5,
    );

    // Card fill
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(1, 1, size.x - 2, size.y - 2), const Radius.circular(9)),
      Paint()..color = selected ? const Color(0xFFFFF8E1) : Colors.white,
    );

    // Emoji
    TextPaint(style: TextStyle(fontSize: size.x * 0.32))
        .render(canvas, commodity.emoji, Vector2(size.x / 2, size.y * 0.20), anchor: Anchor.center);

    // Name
    TextPaint(style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87))
        .render(canvas, commodity.name, Vector2(size.x / 2, size.y * 0.42), anchor: Anchor.center);

    // Price + arrow
    final prev = commodity.priceHistory.length > 1
        ? commodity.priceHistory[commodity.priceHistory.length - 2] : commodity.price;
    final diff = commodity.price - prev;
    final priceColor = diff >= 0 ? const Color(0xFF2E7D32) : _mktRed;
    TextPaint(style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: priceColor))
        .render(canvas,
            'KES ${commodity.price.toStringAsFixed(0)} ${diff >= 0 ? "▲" : "▼"}',
            Vector2(size.x / 2, size.y * 0.57), anchor: Anchor.center);

    // Sparkline
    _drawSparkline(canvas);

    // Owned badge
    if (commodity.owned > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(size.x - 26, 4, 22, 14), const Radius.circular(7)),
        Paint()..color = Colors.green.shade700,
      );
      TextPaint(style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold))
          .render(canvas, '×${commodity.owned}', Vector2(size.x - 15, 5));
    }
  }

  void _drawSparkline(Canvas canvas) {
    final data = commodity.priceHistory;
    if (data.length < 2) return;
    final mn = data.reduce(min) * 0.98;
    final mx = data.reduce(max) * 1.02;
    final range = mx - mn == 0 ? 1.0 : mx - mn;
    final chartY = size.y * 0.72;
    final chartH = size.y * 0.18;
    final chartW = size.x - 8;
    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = 4 + i / (data.length - 1) * chartW;
      final y = chartY + chartH - (data[i] - mn) / range * chartH;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(path,
        Paint()
          ..color = data.last >= data.first ? Colors.green.shade400 : Colors.red.shade400
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  MarketGame
// ═══════════════════════════════════════════════════════════════════════════
class MarketGame extends FlameGame {
  final List<Commodity> commodities;
  final void Function(Commodity c) onStallTap;

  late PriceTickerComponent ticker;
  late MarketBackgroundComponent bg;
  final List<CommodityStallComponent> stalls = [];

  MarketGame({required this.commodities, required this.onStallTap});

  @override
  Future<void> onLoad() async {
    bg = MarketBackgroundComponent(size: size);
    add(bg);

    ticker = PriceTickerComponent(
        commodities: commodities, position: Vector2(0, 0));
    add(ticker);

    final stallW = size.x / 3;
    final stallH = size.y * 0.42;
    for (int i = 0; i < commodities.length; i++) {
      final row = i ~/ 3, col = i % 3;
      final stall = CommodityStallComponent(
        commodity: commodities[i],
        onTap: onStallTap,
        index: i,
        position: Vector2(col * stallW + 4, 30 + row * (stallH + 8)),
        size: Vector2(stallW - 8, stallH),
      );
      stalls.add(stall);
      add(stall);
    }
  }

  void setSelected(Commodity? c) {
    for (final s in stalls) {
      s.selected = s.commodity.name == c?.name;
    }
  }

  void refreshTicker() => ticker.commodities = commodities;
}

// ═══════════════════════════════════════════════════════════════════════════
//  MarketTradingSimulation — Flutter widget
// ═══════════════════════════════════════════════════════════════════════════
class MarketTradingSimulation extends StatefulWidget {
  final String topic;
  final VoidCallback onComplete;
  final String classId, module, studentName;

  const MarketTradingSimulation({
    super.key,
    required this.topic, required this.onComplete,
    required this.classId, required this.module, required this.studentName,
  });

  @override
  State<MarketTradingSimulation> createState() => _MarketTradingSimulationState();
}

class _MarketTradingSimulationState extends State<MarketTradingSimulation> {
  late final MarketGame _game;
  late List<Commodity> _commodities;

  double _cash = 5000.0;
  int _day = 1, _qty = 1;
  final int _totalDays = 10;
  Commodity? _selected;
  final List<Map<String, dynamic>> _txLog = [];
  final List<String> _actionsLog = [];
  final List<double> _cashHistory = [5000.0];
  NewsEvent? _news;
  String _msg = '';
  bool _evaluating = false;
  final _svc = const GeminiSimulationService();
  late ConfettiController _confetti;
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    _commodities = [
      Commodity(name: 'Maize',    emoji: '🌽', price: 45.0),
      Commodity(name: 'Tomatoes', emoji: '🍅', price: 75.0),
      Commodity(name: 'Cabbage',  emoji: '🥬', price: 55.0),
      Commodity(name: 'Potatoes', emoji: '🥔', price: 40.0),
      Commodity(name: 'Beans',    emoji: '🫘', price: 90.0),
      Commodity(name: 'Onions',   emoji: '🧅', price: 65.0),
    ];
    _game = MarketGame(commodities: _commodities, onStallTap: _onStallTap);
    _msg = 'Day 1: Market is open! Tap a stall to select it. Buy low, sell high!';
  }

  @override
  void dispose() { _confetti.dispose(); super.dispose(); }

  void _onStallTap(Commodity c) {
    setState(() {
      _selected = _selected?.name == c.name ? null : c;
      _game.setSelected(_selected);
      _msg = _selected == null
          ? 'Select a stall.'
          : '${c.emoji} ${c.name}: KES ${c.price.toStringAsFixed(0)} | '
              'You own: ${c.owned} bags | ${c.rising ? "📈 Price rising!" : "📉 Price falling"}';
    });
  }

  void _trade(bool buying) {
    final c = _selected;
    if (c == null) return;
    final cost = c.price * _qty;
    setState(() {
      if (buying) {
        if (_cash < cost) { _msg = '❌ Not enough cash! You have KES ${_cash.toStringAsFixed(0)}.'; return; }
        _cash -= cost; c.owned += _qty;
        _actionsLog.add('Day $_day: BUY $_qty× ${c.name} @ KES ${c.price.toStringAsFixed(0)}');
        _txLog.add({'type': 'buy', 'crop': c.name, 'quantity': _qty, 'price': c.price, 'day': _day});
        _msg = '✅ Bought $_qty× ${c.emoji} for KES ${cost.toStringAsFixed(0)}. '
            'Total investment: KES ${(5000 - _cash).toStringAsFixed(0)}';
      } else {
        if (c.owned < _qty) { _msg = '❌ You only have ${c.owned}× ${c.name}.'; return; }
        _cash += cost; c.owned -= _qty;
        _actionsLog.add('Day $_day: SELL $_qty× ${c.name} @ KES ${c.price.toStringAsFixed(0)}');
        _txLog.add({'type': 'sell', 'crop': c.name, 'quantity': _qty, 'price': c.price, 'day': _day});
        _msg = '💰 Sold $_qty× ${c.emoji} for KES ${cost.toStringAsFixed(0)}!';
        _confetti.play();
      }
      _cashHistory.add(_cash);
    });
  }

  void _nextDay() {
    if (_day >= _totalDays) { _finish(); return; }
    setState(() {
      _day++;
      for (final c in _commodities) {
        final change = (_rng.nextDouble() - 0.48) * 0.2;
        c.price = double.parse((c.price * (1 + change)).clamp(10, 500).toStringAsFixed(2));
        c.recordPrice();
      }
      if (_day % 2 == 0 && _rng.nextDouble() < 0.7) {
        _news = _newsPool[_rng.nextInt(_newsPool.length)];
        for (final c in _commodities) {
          if (_news!.commodity == 'All' || _news!.commodity == c.name) {
            c.price = double.parse((c.price * _news!.effect).clamp(10, 500).toStringAsFixed(2));
          }
        }
      } else {
        _news = null;
      }
      _cashHistory.add(_cash);
      _game.refreshTicker();
      _msg = 'Day $_day/$_totalDays — KES ${_cash.toStringAsFixed(0)} available. '
          'Portfolio value: KES ${_portfolioValue().toStringAsFixed(0)}';
    });
  }

  double _portfolioValue() =>
      _commodities.fold(0, (a, c) => a + c.owned * c.price);

  Future<void> _finish() async {
    for (final c in _commodities) { _cash += c.owned * c.price; c.owned = 0; }
    _confetti.play();
    setState(() => _evaluating = true);
    final profit = _cash - 5000;
    final fb = await _svc.evaluateMarketTrading(
      startingCash: 5000, finalCash: _cash,
      netProfit: profit, profitPercent: profit / 50,
      totalTransactions: _txLog.length, transactionHistory: _txLog,
    );
    if (!mounted) return;
    setState(() => _evaluating = false);
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) =>
        SimulationResultScreen(
          classId: widget.classId, module: widget.module,
          simulationTitle: 'Market Trading — $_day Days',
          feedback: fb, fallbackScore: _calcScore(), decisionLog: _actionsLog,
          summaryData: {'finalCash': _cash.toStringAsFixed(0),
              'netProfit': profit.toStringAsFixed(0), 'transactions': _txLog.length},
          onDone: widget.onComplete,
        )));
  }

  int _calcScore() {
    final p = _cash - 5000;
    if (p > 3000) return 95;
    if (p > 1500) return 80;
    if (p > 0)    return 65;
    if (p > -1000)return 45;
    return 25;
  }

  @override
  Widget build(BuildContext context) {
    final profit = _cash - 5000;
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      body: SafeArea(child: Column(children: [
        // Header
        Container(color: _mktGreen,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context)),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('🏪 Kilimo Market', style: TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              Text('Day $_day/$_totalDays', style: const TextStyle(
                  color: Colors.white70, fontSize: 11)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('KES ${_cash.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.amber,
                      fontSize: 14, fontWeight: FontWeight.bold)),
              Text(profit >= 0 ? '▲ +${profit.toStringAsFixed(0)}' : '▼ ${profit.toStringAsFixed(0)}',
                  style: TextStyle(
                      color: profit >= 0 ? Colors.greenAccent : Colors.redAccent,
                      fontSize: 11)),
            ]),
          ]),
        ),
        // News banner
        if (_news != null) Container(
          color: _mktAmber,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            Text(_news!.icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_news!.headline, style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 12)),
              Text(_news!.detail, style: const TextStyle(fontSize: 10)),
            ])),
            Icon(_news!.effect > 1 ? Icons.trending_up : Icons.trending_down,
                color: _news!.effect > 1 ? Colors.green : Colors.red),
          ]),
        ),
        // ── Flame market canvas ───────────────────────────────────────────
        Expanded(child: GameWidget.controlled(gameFactory: () => _game)),
        // Trade panel
        _tradePanel(),
        // Day controls
        Container(color: _mktGreen,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Expanded(child: ElevatedButton.icon(
              onPressed: _evaluating ? null : _nextDay,
              icon: Icon(_day >= _totalDays ? Icons.flag : Icons.calendar_today),
              label: Text(_day >= _totalDays ? '🏁 Close Market' : '⏭ Next Day'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber, foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 12)),
            )),
            const SizedBox(width: 10),
            IconButton(icon: const Icon(Icons.help_outline, color: Colors.white),
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => TutorChatScreen(
                      topic: 'Market Trading', grade: '',
                      classId: widget.classId, isPrimary: false,
                      contextQuestion: 'Day $_day: Cash ${_cash.toStringAsFixed(0)} KES. $_msg',
                      contextModule: 'market_content', wrongAnswer: false,
                    )))),
          ]),
        ),
      ])),
    );
  }

  Widget _tradePanel() {
    if (_selected == null) {
      return Container(
        color: Colors.grey.shade100,
        padding: const EdgeInsets.all(12),
        child: Text(_msg, textAlign: TextAlign.center,
            style: TextStyle(color: _mktGreen, fontSize: 12)),
      );
    }
    final c = _selected!;
    return Container(
      color: Colors.amber.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_msg, style: TextStyle(color: _mktGreen, fontSize: 11), maxLines: 2),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('Qty: ', style: TextStyle(fontWeight: FontWeight.bold)),
          IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red, size: 22),
              onPressed: () => setState(() { if (_qty > 1) _qty--; })),
          Text('$_qty', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          IconButton(icon: const Icon(Icons.add_circle, color: Colors.green, size: 22),
              onPressed: () => setState(() => _qty++)),
        ]),
        Row(children: [
          Expanded(child: ElevatedButton.icon(
            onPressed: () => _trade(true),
            icon: const Icon(Icons.shopping_cart, size: 16),
            label: Text('BUY ×$_qty\nKES ${(c.price * _qty).toStringAsFixed(0)}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11)),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
          )),
          const SizedBox(width: 8),
          Expanded(child: ElevatedButton.icon(
            onPressed: c.owned >= _qty ? () => _trade(false) : null,
            icon: const Icon(Icons.sell, size: 16),
            label: Text('SELL ×$_qty\nKES ${(c.price * _qty).toStringAsFixed(0)}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11)),
            style: ElevatedButton.styleFrom(
                backgroundColor: _mktAmber, foregroundColor: Colors.black87),
          )),
        ]),
      ]),
    );
  }
}

enum PriceTrend { rising, falling, stable }