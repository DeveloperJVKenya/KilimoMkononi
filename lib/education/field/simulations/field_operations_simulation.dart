// lib/education/field/simulations/field_operations_simulation.dart
// ignore_for_file: prefer_final_fields, avoid_renaming_method_parameters, use_build_context_synchronously, deprecated_member_use
//
// FLAME ENGINE — FieldOperationsSimulation
//
// FieldLabGame (FlameGame)
//   ├── FieldBackgroundComponent    — sky + horizon + soil band
//   ├── FieldStripComponent ×3      — A, B, C strips side by side, TapCallbacks
//   │     each renders its crop growth stage with an animated plant
//   │     soil moisture shown as blue gradient at base of strip
//   │     weeds rendered as small green tufts that multiply visually
//   │     dead strip turns dark brown with wilted plant shape
//   └── WeatherIconComponent        — sun/cloud/rain icon top-right
//         changes each week based on random weather event
//
// Students tap a strip to select it, then use Flutter operation buttons.
// Weekly challenge cards appear in Flutter UI below the canvas.

import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:kilimomkononi/education/simulations/simulation_result_screen.dart';
import 'package:kilimomkononi/education/simulations/gemini_simulation_service.dart';
import 'package:kilimomkononi/education/tutor/tutor_chat_screen.dart';

const Color _appGreen  = Color(0xFF032704);
const Color _soilBrown = Color(0xFF5D3A1A);

// ── Growth stages ────────────────────────────────────────────────────────────
enum GrowthStage { bare, germination, seedling, vegetative, tasselling, silking, maturing, harvest, dead }

extension GrowthX on GrowthStage {
  String get label => switch (this) {
    GrowthStage.bare        => 'Bare',
    GrowthStage.germination => 'Germination',
    GrowthStage.seedling    => 'Seedling',
    GrowthStage.vegetative  => 'Vegetative',
    GrowthStage.tasselling  => 'Tasselling',
    GrowthStage.silking     => 'Silking',
    GrowthStage.maturing    => 'Maturing',
    GrowthStage.harvest     => 'Ready!',
    GrowthStage.dead        => 'Failed',
  };
}

// ── Strip state model ────────────────────────────────────────────────────────
class StripData {
  final String label;
  GrowthStage stage    = GrowthStage.bare;
  double soilFertility = 50;
  double soilMoisture  = 50;
  double weedLevel     = 10;
  double health        = 100;
  bool   harvested     = false;
  StripData({required this.label});
}

// ── WeeklyChallenge ──────────────────────────────────────────────────────────
class WeeklyChallenge {
  final String scenario, question;
  final List<String> options, actions;
  final String bestAction, explanation;
  const WeeklyChallenge({required this.scenario, required this.question,
      required this.options, required this.actions,
      required this.bestAction, required this.explanation});
}

const _challenges = [
  WeeklyChallenge(
    scenario: '🌧️ It rained 60mm yesterday.',
    question: 'What do you do today?',
    options: ['Irrigate anyway', 'Skip irrigation today', 'Apply fertiliser while wet', 'Nothing'],
    actions: ['irrigate', 'skip', 'fertilise', 'nothing'],
    bestAction: 'skip',
    explanation: 'After heavy rain, soil is well-watered. Over-irrigation wastes water and risks root rot.',
  ),
  WeeklyChallenge(
    scenario: '☀️ Two dry weeks, soil is cracked.',
    question: 'What do you prioritise?',
    options: ['Irrigate immediately', 'Weed first then irrigate', 'Add fertiliser', 'Wait for rain'],
    actions: ['irrigate', 'weed_irrigate', 'fertilise', 'nothing'],
    bestAction: 'irrigate',
    explanation: 'Drought stress reduces yield fast. Irrigate first — weeding can follow.',
  ),
  WeeklyChallenge(
    scenario: '🌿 Weeds are knee-high between rows.',
    question: 'Best management approach?',
    options: ['Chemical herbicide', 'Hand-weed only', 'Leave them', 'Mulch between rows'],
    actions: ['herbicide', 'weed', 'nothing', 'mulch'],
    bestAction: 'mulch',
    explanation: 'Mulching suppresses future weeds AND retains moisture — best integrated approach.',
  ),
  WeeklyChallenge(
    scenario: '🌱 Plants are at knee-high (vegetative) stage.',
    question: 'When do you apply top-dressing fertiliser?',
    options: ['Now (knee-high)', 'At planting only', 'At flowering', 'Never needed'],
    actions: ['fertilise', 'nothing', 'fertilise_late', 'nothing2'],
    bestAction: 'fertilise',
    explanation: 'Top-dressing at knee-high matches peak nutrient demand for maize.',
  ),
  WeeklyChallenge(
    scenario: '💧 Choosing irrigation method for a 1-acre plot.',
    question: 'Most efficient method for Kenya smallholder?',
    options: ['Overhead sprinklers', 'Furrow irrigation', 'Drip irrigation', 'No irrigation'],
    actions: ['overhead', 'furrow', 'drip', 'nothing'],
    bestAction: 'drip',
    explanation: 'Drip irrigation uses 30–50% less water and reduces disease risk.',
  ),
];

// ── FieldBackgroundComponent ──────────────────────────────────────────────────
class FieldBackgroundComponent extends PositionComponent {
  double _t = 0;
  String weatherIcon = '☀️';
  FieldBackgroundComponent({required Vector2 size}) : super(size: size);
  @override void update(double dt) => _t += dt * 0.3;
  @override
  void render(Canvas canvas) {
    // Sky
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y * 0.30),
        Paint()..shader = const LinearGradient(
            colors: [Color(0xFF87CEEB), Color(0xFFB3E5FC)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter)
            .createShader(Rect.fromLTWH(0, 0, size.x, size.y * 0.30)));
    // Ground
    canvas.drawRect(Rect.fromLTWH(0, size.y * 0.30, size.x, size.y * 0.70),
        Paint()..color = _soilBrown);
    // Weather icon
    TextPaint(style: const TextStyle(fontSize: 22))
        .render(canvas, weatherIcon, Vector2(size.x - 34, 6));
  }
}

// ── FieldStripComponent ───────────────────────────────────────────────────────
class FieldStripComponent extends PositionComponent with TapCallbacks {
  final StripData data;
  final void Function(StripData d) onTap;
  bool selected = false;
  double _t = 0;
  final Random _rng = Random();
  final List<Offset> _weedPos = [];

  FieldStripComponent({
    required this.data, required this.onTap,
    required Vector2 position, required Vector2 size,
  }) : super(position: position, size: size) {
    for (int i = 0; i < 8; i++) {
      _weedPos.add(Offset(_rng.nextDouble(), 0.7 + _rng.nextDouble() * 0.25));
    }
  }

  @override void onTapDown(TapDownEvent e) => onTap(data);
  @override void update(double dt) => _t += dt * 1.8;

  @override
  void render(Canvas canvas) {
    // Strip background
    final soilColor = Color.lerp(
        const Color(0xFF3E2000), const Color(0xFF6D4C41),
        data.soilMoisture / 100)!;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.x, size.y), const Radius.circular(8)),
      Paint()..color = selected ? Colors.amber.shade100 : soilColor,
    );

    // Moisture puddle at base
    if (data.soilMoisture > 60) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(2, size.y * 0.85, size.x - 4, size.y * 0.12),
            const Radius.circular(4)),
        Paint()..color = const Color(0xFF29B6F6).withOpacity((data.soilMoisture - 60) / 80),
      );
    }

    // Weeds (scaled by weed level)
    final visibleWeeds = ((data.weedLevel / 100) * _weedPos.length).round();
    final weedP = Paint()..color = Colors.green.shade700;
    for (int i = 0; i < visibleWeeds && i < _weedPos.length; i++) {
      final wx = _weedPos[i].dx * size.x;
      final wy = _weedPos[i].dy * size.y;
      canvas.drawLine(Offset(wx, wy), Offset(wx - 4, wy - 8 - sin(_t + i) * 2), weedP..strokeWidth = 1.5);
      canvas.drawLine(Offset(wx, wy), Offset(wx + 4, wy - 8 - sin(_t + i + 1) * 2), weedP..strokeWidth = 1.5);
    }

    // Crop plant
    _drawCrop(canvas);

    // Health bar
    final hFrac = data.health / 100;
    canvas.drawRect(Rect.fromLTWH(2, size.y - 6, (size.x - 4) * hFrac, 4),
        Paint()..color = hFrac > 0.5 ? Colors.green : Colors.red);

    // Selection border
    if (selected) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.x, size.y), const Radius.circular(8)),
        Paint()..color = Colors.amber..style = PaintingStyle.stroke..strokeWidth = 3,
      );
    }

    // Strip label
    TextPaint(style: const TextStyle(fontSize: 10, color: Colors.white70,
        fontWeight: FontWeight.bold))
        .render(canvas, data.label, Vector2(size.x / 2, size.y * 0.92), anchor: Anchor.center);

    // Growth stage label
    TextPaint(style: const TextStyle(fontSize: 8, color: Colors.white54))
        .render(canvas, data.stage.label, Vector2(size.x / 2, size.y * 0.04), anchor: Anchor.center);
  }

  void _drawCrop(Canvas canvas) {
    if (data.stage == GrowthStage.bare) return;
    if (data.stage == GrowthStage.dead) {
      // Wilted plant
      final p = Paint()..color = const Color(0xFF4E342E)..strokeWidth = 2;
      canvas.drawLine(Offset(size.x / 2, size.y * 0.75),
          Offset(size.x / 2, size.y * 0.55), p);
      canvas.drawLine(Offset(size.x / 2, size.y * 0.60),
          Offset(size.x / 2 - 10, size.y * 0.65), p);
      return;
    }

    final stageIdx = data.stage.index;
    final heightFrac = (stageIdx / GrowthStage.harvest.index).clamp(0.05, 0.85);
    final plantH     = size.y * heightFrac;
    final baseY      = size.y * 0.80;
    final topY       = baseY - plantH;
    final cx         = size.x / 2;

    final cropColor  = Color.lerp(
        const Color(0xFF8BC34A), const Color(0xFF1B5E20),
        (stageIdx / GrowthStage.harvest.index).clamp(0, 1))!;

    final stemP = Paint()..color = cropColor..strokeWidth = 3;
    canvas.drawLine(Offset(cx, baseY), Offset(cx, topY), stemP);

    // Leaves at each stage
    if (stageIdx >= GrowthStage.seedling.index) {
      final lp = Paint()..color = cropColor..strokeWidth = 2;
      for (int i = 1; i <= min(stageIdx, 4); i++) {
        final ly = baseY - (plantH * i / 5);
        final wave = sin(_t + i) * 2;
        canvas.drawLine(Offset(cx, ly), Offset(cx - 12 + wave, ly - 8), lp);
        canvas.drawLine(Offset(cx, ly), Offset(cx + 12 - wave, ly - 8), lp);
      }
    }

    // Harvest indicator
    if (data.stage == GrowthStage.harvest) {
      TextPaint(style: const TextStyle(fontSize: 16))
          .render(canvas, '🌽', Vector2(cx - 8, topY - 20));
    }

    // Fruit/tassel at tasselling+
    if (stageIdx >= GrowthStage.tasselling.index &&
        stageIdx < GrowthStage.harvest.index) {
      canvas.drawCircle(Offset(cx, topY - 4), 5,
          Paint()..color = Colors.yellow.shade600);
    }
  }
}

// ── FieldLabGame ───────────────────────────────────────────────────────────────
class FieldLabGame extends FlameGame {
  final List<StripData> strips;
  final void Function(StripData d) onStripTap;

  late FieldBackgroundComponent bg;
  late List<FieldStripComponent> stripComponents;

  FieldLabGame({required this.strips, required this.onStripTap});

  @override
  Future<void> onLoad() async {
    bg = FieldBackgroundComponent(size: size);
    add(bg);

    final stripW = (size.x - 16) / 3;
    final stripH = size.y * 0.88;
    stripComponents = [];
    for (int i = 0; i < strips.length; i++) {
      final comp = FieldStripComponent(
        data: strips[i], onTap: onStripTap,
        position: Vector2(4 + i * (stripW + 4), size.y * 0.06),
        size: Vector2(stripW, stripH),
      );
      stripComponents.add(comp);
      add(comp);
    }
  }

  void setSelected(StripData? d) {
    for (final c in stripComponents) {
      c.selected = c.data.label == d?.label;
    }
  }

  void setWeather(String icon) => bg.weatherIcon = icon;
}

// ═══════════════════════════════════════════════════════════════════════════
//  FieldOperationsSimulation — Flutter widget
// ═══════════════════════════════════════════════════════════════════════════
class FieldOperationsSimulation extends StatefulWidget {
  final VoidCallback onComplete;
  final String classId, module, studentName;

  const FieldOperationsSimulation({
    super.key,
    required this.onComplete, required this.classId,
    required this.module, required this.studentName,
  });

  @override
  State<FieldOperationsSimulation> createState() => _FieldOperationsSimulationState();
}

class _FieldOperationsSimulationState extends State<FieldOperationsSimulation> {
  late final FieldLabGame _game;
  late List<StripData> _strips;

  int _week = 1, _totalWeeks = 10;
  int _tilCount = 0, _fertCount = 0, _weedCount = 0, _irrigCount = 0;
  int _selIdx = 0;
  List<String> _log = [];
  String _msg = '';

  WeeklyChallenge? _challenge;
  String? _challengeResult;
  bool _waitChallenge = false, _evaluating = false;

  final _svc = const GeminiSimulationService();
  late ConfettiController _confetti;
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    _strips = [StripData(label: 'Strip A'), StripData(label: 'Strip B'), StripData(label: 'Strip C')];
    _game = FieldLabGame(strips: _strips, onStripTap: _onStripTap);
    _msg = 'Week 1: Tap a strip to select it, then use operation buttons. '
        'Answer the weekly challenge to advance!';
    _pickChallenge();
  }

  @override
  void dispose() { _confetti.dispose(); super.dispose(); }

  void _pickChallenge() {
    _challenge = _challenges[_rng.nextInt(_challenges.length)];
    _challengeResult = null;
    _waitChallenge = true;
  }

  void _onStripTap(StripData d) {
    setState(() {
      _selIdx = _strips.indexOf(d);
      _game.setSelected(d);
      _msg = '${d.label} selected — ${d.stage.label} | '
          'Moisture: ${d.soilMoisture.toInt()}% | '
          'Fertility: ${d.soilFertility.toInt()}% | '
          'Weeds: ${d.weedLevel.toInt()}%';
    });
  }

  void _applyOp(String action) {
    final strip = _strips[_selIdx];
    setState(() {
      switch (action) {
        case 'till':
          _tilCount++;
          strip.soilFertility = (strip.soilFertility + 8).clamp(0, 100);
          strip.weedLevel     = (strip.weedLevel - 15).clamp(0, 100);
          _log.add('Week $_week ${strip.label}: Tillage');
          _msg = '🔨 ${strip.label} tilled! Soil aerated and weed seeds buried.';
          break;
        case 'fertilise':
          _fertCount++;
          strip.soilFertility = (strip.soilFertility + 20).clamp(0, 100);
          _log.add('Week $_week ${strip.label}: Fertiliser');
          _msg = '🌿 ${strip.label} fertilised! Nitrogen & phosphorus boosted.';
          _tryGrow(strip);
          break;
        case 'weed':
          _weedCount++;
          strip.weedLevel = (strip.weedLevel - 30).clamp(0, 100);
          _log.add('Week $_week ${strip.label}: Weeding');
          _msg = '✂️ ${strip.label} weeded! Less competition for nutrients.';
          break;
        case 'irrigate':
          _irrigCount++;
          strip.soilMoisture = (strip.soilMoisture + 25).clamp(0, 100);
          _log.add('Week $_week ${strip.label}: Irrigation');
          _msg = '💧 ${strip.label} irrigated. Moisture restored.';
          _tryGrow(strip);
          break;
        case 'mulch':
          strip.weedLevel     = (strip.weedLevel - 20).clamp(0, 100);
          strip.soilMoisture  = (strip.soilMoisture + 10).clamp(0, 100);
          _log.add('Week $_week ${strip.label}: Mulching');
          _msg = '🍂 ${strip.label} mulched! Weeds suppressed, moisture retained.';
          break;
        case 'harvest':
          if (strip.stage == GrowthStage.harvest) {
            strip.harvested = true;
            _confetti.play();
            _log.add('Week $_week ${strip.label}: HARVESTED');
            _msg = '🌽 ${strip.label} harvested! Score: ${_calcStripScore(strip)}/100';
          } else {
            _msg = '⚠️ ${strip.label} is not ready to harvest yet.';
          }
          break;
      }
    });
  }

  void _tryGrow(StripData strip) {
    if (strip.soilMoisture >= 40 && strip.soilFertility >= 35 &&
        strip.weedLevel <= 50 && strip.health >= 40 &&
        strip.stage != GrowthStage.harvest && strip.stage != GrowthStage.dead) {
      if (_rng.nextDouble() < 0.5) {
        strip.stage = GrowthStage.values[
            (strip.stage.index + 1).clamp(0, GrowthStage.harvest.index)];
      }
    }
  }

  void _answerChallenge(int idx) {
    final ch = _challenge!;
    final correct = ch.actions[idx] == ch.bestAction;
    setState(() {
      _challengeResult = correct
          ? '✅ Correct! ${ch.explanation}'
          : '❌ Not optimal. ${ch.explanation}';
      _waitChallenge = false;
      for (final s in _strips) {
        if (correct) {
          s.soilMoisture = (s.soilMoisture + 10).clamp(0, 100);
          s.health = (s.health + 5).clamp(0, 100);
        } else {
          s.health = (s.health - 8).clamp(0, 100);
        }
      }
    });
  }

  void _nextWeek() {
    if (_waitChallenge) { setState(() => _msg = 'Answer the Weekly Challenge first!'); return; }
    if (_week >= _totalWeeks) { _finish(); return; }
    setState(() {
      _week++;
      for (final s in _strips) {
        if (s.harvested) continue;
        s.soilMoisture  = (s.soilMoisture - 10).clamp(0, 100);
        s.weedLevel     = (s.weedLevel + 5).clamp(0, 100);
        s.soilFertility = (s.soilFertility - 3).clamp(0, 100);
        if (s.soilMoisture < 20) {
          s.health = (s.health - 12).clamp(0, 100);
        }
        if (s.weedLevel > 70) s.health = (s.health - 8).clamp(0, 100);
        if (s.health <= 20) s.stage = GrowthStage.dead;
        if (s.soilMoisture >= 30 && s.health >= 30 && _rng.nextDouble() < 0.3) {
          s.stage = GrowthStage.values[
              (s.stage.index + 1).clamp(0, GrowthStage.harvest.index)];
        }
      }
      // Random weather
      final weathers = [('☀️', 'Hot and dry'), ('🌧️', 'Rainy'), ('⛅', 'Cloudy')];
      final w = weathers[_rng.nextInt(weathers.length)];
      _game.setWeather(w.$1);
      _pickChallenge();
      _msg = 'Week $_week — Strips: A:${_strips[0].stage.label} | '
          'B:${_strips[1].stage.label} | C:${_strips[2].stage.label}';
    });
  }

  int _calcStripScore(StripData s) {
    int sc = (s.health * 0.3).toInt();
    sc += (s.soilFertility * 0.2).toInt();
    sc += ((100 - s.weedLevel) * 0.15).toInt();
    sc += GrowthStage.values.indexOf(s.stage) * 5;
    return sc.clamp(0, 100);
  }

  Future<void> _finish() async {
    _confetti.play();
    final best = _strips.reduce((a, b) =>
        _calcStripScore(a) >= _calcStripScore(b) ? a : b);
    setState(() => _evaluating = true);
    final fb = await _svc.evaluateFieldOperations(
      cropType: 'Maize', cropHealth: best.health.toInt(),
      soilFertility: best.soilFertility.toInt(), weedLevel: best.weedLevel.toInt(),
      tillageCount: _tilCount, fertilizationCount: _fertCount,
      weedingCount: _weedCount, irrigationCount: _irrigCount,
      finalGrowthStage: best.stage.label, actionsLog: _log, rawScore: _calcStripScore(best),
    );
    if (!mounted) return;
    setState(() => _evaluating = false);
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) =>
        SimulationResultScreen(
          classId: widget.classId, module: widget.module,
          simulationTitle: 'Field Operations Lab',
          feedback: fb, fallbackScore: _calcStripScore(best), decisionLog: _log,
          summaryData: {'bestStrip': best.label, 'bestStage': best.stage.label,
              'tillage': _tilCount, 'fertilization': _fertCount},
          onDone: widget.onComplete,
        )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      body: SafeArea(child: Column(children: [
        // Header
        Container(color: _appGreen,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context)),
            Expanded(child: Text('🌾 Field Operations Lab — Week $_week/$_totalWeeks',
                style: const TextStyle(color: Colors.white, fontSize: 14,
                    fontWeight: FontWeight.bold))),
          ]),
        ),
        // Week progress
        Container(color: Colors.green.shade800,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(children: [
            const Text('Progress ', style: TextStyle(color: Colors.white70, fontSize: 10)),
            ...List.generate(_totalWeeks, (i) => Expanded(child: Container(
              height: 8, margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: i < _week ? Colors.amber : Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ))),
          ]),
        ),
        // ── Flame field canvas ────────────────────────────────────────────
        Expanded(flex: 5, child: GameWidget.controlled(gameFactory: () => _game)),
        // Operation buttons
        _opsBar(),
        // Challenge card
        if (_challenge != null) _challengeCard(),
        if (_challengeResult != null) _challengeResultCard(),
        // Status
        Container(color: Colors.green.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(_msg, style: TextStyle(color: _appGreen, fontSize: 11), maxLines: 2)),
        // Controls
        Container(color: _appGreen,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Expanded(child: ElevatedButton.icon(
              onPressed: _evaluating ? null : _nextWeek,
              icon: Icon(_week >= _totalWeeks ? Icons.flag : Icons.skip_next),
              label: Text(_week >= _totalWeeks ? '🏁 Harvest Report' : '⏭ Next Week'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber, foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 12)),
            )),
            const SizedBox(width: 10),
            IconButton(icon: const Icon(Icons.help_outline, color: Colors.white),
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => TutorChatScreen(
                      topic: 'Field Data & Operations', grade: '',
                      classId: widget.classId, isPrimary: false,
                      contextQuestion: 'Week $_week. Challenge: ${_challenge?.scenario}',
                      contextModule: 'field_content', wrongAnswer: false,
                    )))),
          ]),
        ),
      ])),
    );
  }

  Widget _opsBar() {
    final ops = [
      ('🔨', 'Till', 'till'), ('🌿', 'Fertilise', 'fertilise'),
      ('✂️', 'Weed', 'weed'), ('💧', 'Irrigate', 'irrigate'),
      ('🍂', 'Mulch', 'mulch'), ('🌽', 'Harvest', 'harvest'),
    ];
    return Container(
      height: 60,
      color: Colors.brown.shade50,
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: ops.map((op) => GestureDetector(
          onTap: () => _applyOp(op.$3),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(op.$1, style: const TextStyle(fontSize: 20)),
            Text(op.$2, style: const TextStyle(fontSize: 9)),
          ]),
        )).toList()),
    );
  }

  Widget _challengeCard() {
    final ch = _challenge!;
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300, width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('📋 Weekly Challenge', style: TextStyle(
            fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 4),
        Text(ch.scenario, style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
        Text(ch.question, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        const SizedBox(height: 6),
        if (_waitChallenge) ...List.generate(ch.options.length, (i) =>
            GestureDetector(
              onTap: () => _answerChallenge(i),
              child: Container(
                width: double.infinity, margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200)),
                child: Text(ch.options[i], style: const TextStyle(fontSize: 12)),
              ),
            )),
      ]),
    );
  }

  Widget _challengeResultCard() {
    final correct = _challengeResult!.startsWith('✅');
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: correct ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: correct ? Colors.green : Colors.red),
      ),
      child: Text(_challengeResult!,
          style: TextStyle(fontSize: 11,
              color: correct ? Colors.green.shade800 : Colors.red.shade700)),
    );
  }
}