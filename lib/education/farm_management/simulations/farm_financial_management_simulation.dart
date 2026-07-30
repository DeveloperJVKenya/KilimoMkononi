// lib/education/farm_management/simulations/farm_financial_management_simulation.dart
//
// FLAME ENGINE — FarmFinancialManagementSimulation
//
// FinanceDashboardGame (FlameGame)
//   ├── FarmSceneComponent         — animated farm scene (tractor, crops, barn)
//   │     scene changes based on cash level and farm health
//   ├── CashFlowRiverComponent     — animated river of coins/bills flowing left-right
//   │     flow rate = cash velocity; reverses direction when losing money
//   ├── SparklineComponent         — live profit/loss graph drawn on canvas
//   │     updates every time a decision is made
//   └── ResourceBarComponent×3     — Cash, Farm Health, Debt
//         animated bars that grow/shrink on each decision
//
// Flutter UI: monthly decision cards, result feedback panel.

import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:kilimomkononi/education/simulations/simulation_result_screen.dart';
import 'package:kilimomkononi/education/simulations/gemini_simulation_service.dart';
import 'package:kilimomkononi/education/tutor/tutor_chat_screen.dart';

const Color _appGreen  = Color(0xFF003900);
const Color _cashGreen = Color(0xFF1B5E20);
const Color _debtRed   = Color(0xFFC62828);

// ── Decision data ─────────────────────────────────────────────────────────────
class MonthlyDecision {
  final String month, scenario;
  final List<DecisionOption> options;
  const MonthlyDecision({required this.month, required this.scenario, required this.options});
}

class DecisionOption {
  final String label, description, consequence, icon;
  final double costKes, revenueKes, healthEffect;
  const DecisionOption({required this.label, required this.description,
      required this.costKes, this.revenueKes = 0, required this.healthEffect,
      required this.consequence, required this.icon});
}

const _decisions = [
  MonthlyDecision(month: 'January', scenario: 'Land preparation. Till your 2-acre plot.',
    options: [
      DecisionOption(label: 'Hire tractor', description: 'Deep ploughing, saves time.', costKes: 4000, healthEffect: 15, consequence: 'Soil well-prepared. Planting time cut by 3 days.', icon: '🚜'),
      DecisionOption(label: 'Manual jembe', description: 'Labour-intensive, low cost.', costKes: 1500, healthEffect: 8, consequence: 'Soil adequately prepared. Saved KES 2,500 but 2 extra weeks.', icon: '⛏️'),
      DecisionOption(label: 'Skip tilling', description: 'Direct seed into unplowed soil.', costKes: 0, healthEffect: -10, consequence: 'Poor germination. 20% of seeds fail.', icon: '❌'),
    ]),
  MonthlyDecision(month: 'March', scenario: 'Seedlings 3 weeks old. Agro-dealer offers DAP fertiliser.',
    options: [
      DecisionOption(label: 'Buy full 50kg', description: 'KES 4,500 — maximum yield potential.', costKes: 4500, healthEffect: 20, consequence: 'Excellent growth. Yield forecast +35%.', icon: '🌿'),
      DecisionOption(label: 'Buy 25kg', description: 'KES 2,250 — moderate investment.', costKes: 2250, healthEffect: 10, consequence: 'Good growth. Yield forecast +18%.', icon: '🌱'),
      DecisionOption(label: 'Skip fertiliser', description: 'Rely on existing soil.', costKes: 0, healthEffect: -5, consequence: 'Slow growth. Yield -25% vs fertilised.', icon: '💸'),
    ]),
  MonthlyDecision(month: 'May', scenario: 'Maize tasselling. Buyer offers forward contract.',
    options: [
      DecisionOption(label: 'Forward contract', description: 'KES 25/kg guaranteed now.', costKes: 0, revenueKes: 25000, healthEffect: 0, consequence: 'Secure income. Miss out if price rises above KES 25.', icon: '📝'),
      DecisionOption(label: 'Wait for harvest', description: 'Sell at market price later.', costKes: 0, healthEffect: 0, consequence: 'Risk — price may be KES 35 (profit) or KES 15 (loss).', icon: '⏳'),
      DecisionOption(label: 'Crop advance loan', description: 'Borrow against future harvest.', costKes: -15000, healthEffect: 0, consequence: 'Cash now, but 18% interest — repay KES 17,700 at harvest.', icon: '🏦'),
    ]),
  MonthlyDecision(month: 'July', scenario: 'Harvest! 2 tonnes of maize. How do you sell?',
    options: [
      DecisionOption(label: 'Sell to broker now', description: 'Quick sale at KES 14/kg.', costKes: 0, revenueKes: 28000, healthEffect: 0, consequence: 'Cash immediately. Low margin but no storage risk.', icon: '💰'),
      DecisionOption(label: 'Store 3 months', description: 'Wait for seasonal price rise.', costKes: 2000, revenueKes: 44000, healthEffect: 0, consequence: 'Storage cost KES 2,000. Price rose to KES 22/kg. Net +KES 14,000.', icon: '🏚️'),
      DecisionOption(label: 'Sell via NCPB', description: 'Government reserve at KES 18/kg.', costKes: 0, revenueKes: 36000, healthEffect: 0, consequence: 'Good price but payment delayed 45 days.', icon: '🏛️'),
    ]),
  MonthlyDecision(month: 'September', scenario: 'Second season starting. Expand or maintain?',
    options: [
      DecisionOption(label: 'Expand to 4 acres', description: 'Borrow KES 20,000 to double land.', costKes: 20000, healthEffect: 0, consequence: 'Higher potential revenue. Loan repayment pressure.', icon: '📈'),
      DecisionOption(label: 'Maintain 2 acres', description: 'Use first-season profit.', costKes: 8000, healthEffect: 5, consequence: 'Manageable risk. Steady forecast on known land.', icon: '✅'),
      DecisionOption(label: 'Diversify — add tomatoes', description: 'Mix maize with tomatoes.', costKes: 12000, healthEffect: 8, consequence: 'Higher labour but spreads risk. Revenue from two crops.', icon: '🍅'),
    ]),
];

// ═══════════════════════════════════════════════════════════════════════════
//  CashFlowRiverComponent — animated coins streaming across the dashboard
// ═══════════════════════════════════════════════════════════════════════════
class CashFlowRiverComponent extends PositionComponent {
  double cashVelocity; // positive = earning, negative = losing
  final List<_Coin> _coins = [];
  final Random _rng = Random();

  CashFlowRiverComponent({required this.cashVelocity, required Vector2 position})
      : super(position: position, size: Vector2(double.infinity, 32)) {
    for (int i = 0; i < 12; i++) {
      _coins.add(_Coin(x: _rng.nextDouble() * 400, y: 8 + _rng.nextDouble() * 16));
    }
  }

  @override
  void update(double dt) {
    final speed = (cashVelocity.abs() / 10000 * 80).clamp(20.0, 120.0);
    final dir   = cashVelocity >= 0 ? 1 : -1;
    for (final coin in _coins) {
      coin.x += dir * speed * dt;
      if (coin.x > 500) coin.x = -20;
      if (coin.x < -20) coin.x = 500;
    }
  }

  @override
  void render(Canvas canvas) {
    // River track
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, 500, 32), const Radius.circular(8)),
      Paint()..color = cashVelocity >= 0
          ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
    );
    // Coins
    final coinColor = cashVelocity >= 0 ? Colors.amber.shade600 : Colors.red.shade400;
    for (final coin in _coins) {
      canvas.drawCircle(Offset(coin.x, coin.y), 7, Paint()..color = coinColor);
      canvas.drawCircle(Offset(coin.x, coin.y), 7,
          Paint()..color = Colors.black26..style = PaintingStyle.stroke..strokeWidth = 1);
      TextPaint(style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold))
          .render(canvas, cashVelocity >= 0 ? 'K' : '↓', Vector2(coin.x - 3, coin.y - 5));
    }
    // Arrow showing direction
    TextPaint(style: TextStyle(fontSize: 11, color: cashVelocity >= 0 ? Colors.green : Colors.red))
        .render(canvas, cashVelocity >= 0 ? '→ Money flowing IN' : '← Money flowing OUT',
            Vector2(8, 9));
  }
}

class _Coin { double x, y; _Coin({required this.x, required this.y}); }

// ═══════════════════════════════════════════════════════════════════════════
//  SparklineComponent — live profit/loss graph
// ═══════════════════════════════════════════════════════════════════════════
class SparklineComponent extends PositionComponent {
  List<double> data;
  final double baseline;

  SparklineComponent({required this.data, required this.baseline,
      required Vector2 position, required Vector2 size})
      : super(position: position, size: size);

  @override
  void render(Canvas canvas) {
    // Background
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.x, size.y), const Radius.circular(8)),
      Paint()..color = Colors.white,
    );
    if (data.length < 2) return;

    final mn = data.reduce(min) * 0.9;
    final mx = data.reduce(max) * 1.1;
    final range = mx - mn == 0 ? 1.0 : mx - mn;

    // Baseline
    final baseY = size.y - (baseline - mn) / range * size.y;
    canvas.drawLine(Offset(0, baseY), Offset(size.x, baseY),
        Paint()..color = Colors.grey.shade300..strokeWidth = 1);

    // Sparkline
    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = 4 + i / (data.length - 1) * (size.x - 8);
      final y = size.y - 4 - (data[i] - mn) / range * (size.y - 8);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(path, Paint()
        ..color = data.last >= baseline ? Colors.green.shade500 : Colors.red.shade400
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke);

    // Fill under
    final fillPath = Path()..addPath(path, Offset.zero);
    fillPath.lineTo(size.x - 4, size.y - 4);
    fillPath.lineTo(4, size.y - 4);
    fillPath.close();
    canvas.drawPath(fillPath, Paint()
        ..color = (data.last >= baseline ? Colors.green : Colors.red).withValues(alpha: 0.12));

    // Label
    TextPaint(style: TextStyle(
        fontSize: 8,
        color: data.last >= baseline ? Colors.green.shade700 : Colors.red.shade700))
        .render(canvas, 'KES ${data.last.toStringAsFixed(0)}', Vector2(4, 2));
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  FarmSceneComponent — farm illustration that reacts to financial state
// ═══════════════════════════════════════════════════════════════════════════
class FarmSceneComponent extends PositionComponent {
  double farmHealth;
  double cashRatio; // 0–1
  double _t = 0;

  FarmSceneComponent({required this.farmHealth, required this.cashRatio,
      required Vector2 size}) : super(size: size);

  @override void update(double dt) => _t += dt * 0.5;

  @override
  void render(Canvas canvas) {
    // Sky
    final skyColor = cashRatio > 0.5
        ? const Color(0xFF87CEEB) : const Color(0xFF78909C);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y * 0.5),
        Paint()..color = skyColor);
    // Ground
    canvas.drawRect(Rect.fromLTWH(0, size.y * 0.5, size.x, size.y * 0.5),
        Paint()..color = const Color(0xFF5D3A1A));

    // Barn
    final barnColor = farmHealth > 50
        ? Colors.red.shade700 : Colors.brown.shade700;
    canvas.drawRect(Rect.fromLTWH(size.x * 0.6, size.y * 0.2, size.x * 0.25, size.y * 0.35), Paint()..color = barnColor);
    // Barn roof
    final roofPath = Path()
      ..moveTo(size.x * 0.55, size.y * 0.20)
      ..lineTo(size.x * 0.725, size.y * 0.06)
      ..lineTo(size.x * 0.90, size.y * 0.20)
      ..close();
    canvas.drawPath(roofPath, Paint()..color = Colors.brown.shade900);

    // Crop field (health-dependent)
    final cropColor = Color.lerp(
        const Color(0xFF4E342E), const Color(0xFF2E7D32), farmHealth / 100)!;
    for (double x = 10; x < size.x * 0.55; x += 18) {
      final h = (size.y * 0.18 * (farmHealth / 100)).clamp(8, size.y * 0.22);
      canvas.drawLine(
        Offset(x, size.y * 0.5),
        Offset(x, size.y * 0.5 - h),
        Paint()..color = cropColor..strokeWidth = 3,
      );
    }

    // Tractor (only visible when cash is healthy)
    if (cashRatio > 0.3) {
      final tx = (sin(_t) * 15 + size.x * 0.15);
      _drawTractor(canvas, Offset(tx, size.y * 0.56));
    }

    // Rain if losing money
    if (cashRatio < 0.4) {
      final rp = Paint()..color = Colors.lightBlue.shade200.withValues(alpha: 0.5)..strokeWidth = 1.5;
      final rng = Random(42);
      for (int i = 0; i < 15; i++) {
        final rx = rng.nextDouble() * size.x;
        final ry = (rng.nextDouble() + _t * 0.8) % 1.0 * size.y * 0.5;
        canvas.drawLine(Offset(rx, ry), Offset(rx - 1, ry + 10), rp);
      }
    }
  }

  void _drawTractor(Canvas canvas, Offset pos) {
    canvas.drawRect(Rect.fromLTWH(pos.dx, pos.dy, 28, 14), Paint()..color = Colors.green.shade700);
    canvas.drawRect(Rect.fromLTWH(pos.dx + 14, pos.dy - 6, 14, 10), Paint()..color = Colors.green.shade600);
    // Wheels
    canvas.drawCircle(pos + const Offset(6, 14), 5, Paint()..color = Colors.black87);
    canvas.drawCircle(pos + const Offset(22, 14), 7, Paint()..color = Colors.black87);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  FinanceDashboardGame
// ═══════════════════════════════════════════════════════════════════════════
class FinanceDashboardGame extends FlameGame {
  double cashBalance;
  double farmHealth;
  List<double> cashHistory;

  late FarmSceneComponent scene;
  late CashFlowRiverComponent river;
  late SparklineComponent sparkline;

  FinanceDashboardGame({
    required this.cashBalance,
    required this.farmHealth,
    required this.cashHistory,
  });

  @override
  Future<void> onLoad() async {
    scene = FarmSceneComponent(
      farmHealth: farmHealth,
      cashRatio: (cashBalance / 100000).clamp(0, 1),
      size: Vector2(size.x, size.y * 0.48),
    );
    add(scene);

    river = CashFlowRiverComponent(
      cashVelocity: cashBalance - 50000,
      position: Vector2(0, size.y * 0.50),
    );
    add(river);

    sparkline = SparklineComponent(
      data: List.from(cashHistory),
      baseline: 50000,
      position: Vector2(0, size.y * 0.60),
      size: Vector2(size.x, size.y * 0.38),
    );
    add(sparkline);
  }

  void updateState(double cash, double health, List<double> history) {
    cashBalance = cash;
    farmHealth  = health;
    cashHistory = history;
    scene.farmHealth  = health;
    scene.cashRatio   = (cash / 100000).clamp(0, 1);
    river.cashVelocity = cash - 50000;
    sparkline.data    = List.from(history);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  FarmFinancialManagementSimulation — Flutter widget
// ═══════════════════════════════════════════════════════════════════════════
class FarmFinancialManagementSimulation extends StatefulWidget {
  final VoidCallback onComplete;
  final String classId, module, studentName;

  const FarmFinancialManagementSimulation({
    super.key,
    required this.onComplete, required this.classId,
    required this.module, required this.studentName,
  });

  @override
  State<FarmFinancialManagementSimulation> createState() =>
      _FarmFinancialManagementSimulationState();
}

class _FarmFinancialManagementSimulationState
    extends State<FarmFinancialManagementSimulation> {
  late final FinanceDashboardGame _game;

  int _month = 0;
  double _cash = 50000, _revenue = 0, _expenses = 0, _farmHealth = 60;
  final List<double> _cashHistory = [50000];
  final List<String> _log = [];

  DecisionOption? _chosen;
  String? _result;
  bool _decided = false, _evaluating = false;

  final _svc = const GeminiSimulationService();
  late ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    _game = FinanceDashboardGame(
        cashBalance: _cash, farmHealth: _farmHealth, cashHistory: _cashHistory);
  }

  @override
  void dispose() { _confetti.dispose(); super.dispose(); }

  MonthlyDecision get _current => _decisions[_month];

  void _decide(DecisionOption opt) {
    final cost    = opt.costKes < 0 ? 0.0 : opt.costKes;
    final revenue = opt.revenueKes + (opt.costKes < 0 ? opt.costKes.abs() : 0);
    setState(() {
      _chosen   = opt;
      _decided  = true;
      _cash     = _cash - cost + revenue;
      _expenses += cost;
      _revenue  += revenue;
      _farmHealth = (_farmHealth + opt.healthEffect).clamp(0, 100);
      _cashHistory.add(_cash);
      _log.add('${_current.month}: ${opt.label} — cost: ${cost.toStringAsFixed(0)}, '
          'revenue: ${revenue.toStringAsFixed(0)}');
      _result = opt.consequence;
      _game.updateState(_cash, _farmHealth, _cashHistory);
      if (revenue > 0) _confetti.play();
    });
  }

  void _nextMonth() {
    if (!_decided) { setState(() => _result = 'Make a decision first!'); return; }
    if (_month >= _decisions.length - 1) { _finish(); return; }
    setState(() {
      _month++;
      _chosen  = null;
      _decided = false;
      _result  = null;
    });
  }

  Future<void> _finish() async {
    _confetti.play();
    setState(() => _evaluating = true);
    final fb = await _svc.evaluateFarmFinancial(
      startingBalance: 50000, finalBalance: _cash,
      totalRevenue: _revenue, totalExpenses: _expenses,
      landSize: 2.0, currentCrop: 'Maize',
      decisionsLog: _log, rawScore: _calcScore(),
    );
    if (!mounted) return;
    setState(() => _evaluating = false);
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) =>
        SimulationResultScreen(
          classId: widget.classId, module: widget.module,
          simulationTitle: 'Farm Financial Management',
          feedback: fb, fallbackScore: _calcScore(), decisionLog: _log,
          summaryData: {'finalCash': _cash.toStringAsFixed(0),
              'totalRevenue': _revenue.toStringAsFixed(0),
              'totalExpenses': _expenses.toStringAsFixed(0),
              'netProfit': (_cash - 50000).toStringAsFixed(0)},
          onDone: widget.onComplete,
        )));
  }

  int _calcScore() {
    final profit = _cash - 50000;
    int s = 50;
    if (profit > 30000) {
      s = 95;
    } else if (profit > 15000) {
      s = 80;
    } else if (profit > 0) {
      s = 65;
    } else if (profit > -10000) {
      s = 45;
    } else {
      s = 25;
    }
    return (s + (_farmHealth * 0.2)).clamp(0, 100).toInt();
  }

  @override
  Widget build(BuildContext context) {
    final profit = _cash - 50000;
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      body: SafeArea(child: Column(children: [
        // Header
        Container(color: _appGreen,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context)),
            const Expanded(child: Text('🏦 Farm Enterprise Manager',
                style: TextStyle(color: Colors.white, fontSize: 14,
                    fontWeight: FontWeight.bold))),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('KES ${_cash.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.amber,
                      fontWeight: FontWeight.bold, fontSize: 13)),
              Text(profit >= 0 ? '▲ Profit' : '▼ Loss',
                  style: TextStyle(
                      color: profit >= 0 ? Colors.greenAccent : Colors.redAccent,
                      fontSize: 11)),
            ]),
          ]),
        ),
        // Cash bar
        AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          height: 8,
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: (_cash / 100000).clamp(0.02, 1.0),
            child: Container(color: _cash > 50000 ? Colors.green : Colors.red),
          ),
        ),
        // ── Flame dashboard canvas ────────────────────────────────────────
        Expanded(flex: 5, child: GameWidget.controlled(gameFactory: () => _game)),
        // Metrics row
        _metrics(),
        // Decision card
        Expanded(flex: 6, child: SingleChildScrollView(child: Column(children: [
          _decisionCard(),
          if (_result != null) _resultCard(),
        ]))),
        // Controls
        Container(color: _appGreen,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Expanded(child: ElevatedButton.icon(
              onPressed: _evaluating ? null : _nextMonth,
              icon: Icon(_month >= _decisions.length - 1 ? Icons.flag : Icons.arrow_forward),
              label: Text(_month >= _decisions.length - 1 ? '🏁 Annual Report' : '📅 Next Month'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber, foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 12)),
            )),
            const SizedBox(width: 10),
            IconButton(icon: const Icon(Icons.help_outline, color: Colors.white),
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => TutorChatScreen(
                      topic: 'Farm Financial Management', grade: '',
                      classId: widget.classId, isPrimary: false,
                      contextQuestion: '${_current.month}: ${_current.scenario} '
                          'Cash: ${_cash.toStringAsFixed(0)} KES.',
                      contextModule: 'farm_management_content', wrongAnswer: false,
                    )))),
          ]),
        ),
      ])),
    );
  }

  Widget _metrics() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: Row(children: [
      _mCard('💰 Cash', 'KES ${_cash.toStringAsFixed(0)}',
          _cash > 50000 ? _cashGreen : _debtRed),
      _mCard('📈 Revenue', 'KES ${_revenue.toStringAsFixed(0)}', Colors.green.shade700),
      _mCard('📉 Expenses', 'KES ${_expenses.toStringAsFixed(0)}', Colors.orange.shade700),
      _mCard('❤️ Farm', '${_farmHealth.toInt()}%',
          _farmHealth > 50 ? Colors.green.shade700 : _debtRed),
    ]),
  );

  Widget _mCard(String label, String val, Color color) => Expanded(child:
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
        child: Column(children: [
          Text(label, style: const TextStyle(fontSize: 8, color: Colors.grey)),
          Text(val, style: TextStyle(fontSize: 10,
              fontWeight: FontWeight.bold, color: color)),
        ]),
      ));

  Widget _decisionCard() {
    final d = _current;
    return Container(
      margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _appGreen,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Row(children: [
            Text('📅 ${d.month}', style: const TextStyle(
                color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)),
            Text('  (Month ${_month + 1}/${_decisions.length})',
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d.scenario, style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ...d.options.map((opt) {
              final sel = _chosen?.label == opt.label;
              return GestureDetector(
                onTap: _decided ? null : () => _decide(opt),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: sel ? Colors.green.shade50 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: sel ? Colors.green : Colors.grey.shade300,
                        width: sel ? 2 : 1),
                  ),
                  child: Row(children: [
                    Text(opt.icon, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(opt.label, style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12)),
                          Text(opt.description, style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                        ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      if (opt.costKes > 0) Text('-KES ${opt.costKes.toStringAsFixed(0)}',
                          style: const TextStyle(color: Colors.red,
                              fontSize: 10, fontWeight: FontWeight.bold)),
                      if (opt.revenueKes > 0) Text('+KES ${opt.revenueKes.toStringAsFixed(0)}',
                          style: const TextStyle(color: Colors.green,
                              fontSize: 10, fontWeight: FontWeight.bold)),
                    ]),
                  ]),
                ),
              );
            }),
          ]),
        ),
      ]),
    );
  }

  Widget _resultCard() {
    final pos = _chosen != null && (_chosen!.revenueKes > 0 || _chosen!.healthEffect > 0);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: pos ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pos ? Colors.green : Colors.orange, width: 2),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(pos ? '✅ ' : '⚠️ ', style: const TextStyle(fontSize: 16)),
        Expanded(child: Text(_result!, style: const TextStyle(fontSize: 12))),
      ]),
    );
  }
}