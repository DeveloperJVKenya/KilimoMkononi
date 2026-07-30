// lib/education/simulations/farm_planting_simulation.dart
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:kilimomkononi/education/simulations/simulation_result_screen.dart';
import 'package:kilimomkononi/education/simulations/gemini_simulation_service.dart';
import 'package:kilimomkononi/education/tutor/tutor_chat_screen.dart';

const Color _fg = Color(0xFF032704);
const Color _waterBlue = Color(0xFF29B6F6);
const Color _bugRed    = Color(0xFFE53935);

enum CellStage { bare, plowed, seeded, seedling, sapling, mature, harvest, dead }
enum ActiveTool { none, plow, seed, water, fertiliser, pesticide, harvest }

// ── PlotCellComponent ────────────────────────────────────────────────────────
class PlotCellComponent extends PositionComponent with TapCallbacks {
  final int row, col;
  final void Function(int r, int c) onTap;

  CellStage stage   = CellStage.bare;
  double water      = 40;
  double fertility  = 50;
  bool   hasPest    = false;
  double health     = 100;
  double _t         = 0;

  PlotCellComponent({
    required this.row, required this.col, required this.onTap,
    required Vector2 position, required Vector2 size,
  }) : super(position: position, size: size);

  @override
  void onTapDown(TapDownEvent event) => onTap(row, col);

  @override
  void update(double dt) { _t += dt * 2; }

  @override
  void render(Canvas canvas) {
    final r = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawRRect(
      RRect.fromRectAndRadius(r.deflate(1), const Radius.circular(6)),
      Paint()..color = _bg(),
    );
    // Furrow lines
    if (stage == CellStage.plowed) {
      final p = Paint()..color = const Color(0xFF2D1B00).withValues(alpha: 0.4)..strokeWidth = 1.5;
      for (double y = 8; y < size.y; y += 10) {
        canvas.drawLine(Offset(4, y), Offset(size.x - 4, y), p);
      }
    }
    // Water strip
    canvas.drawRect(
      Rect.fromLTWH(2, size.y - 4, (size.x - 4) * (water / 100).clamp(0, 1), 3),
      Paint()..color = _waterBlue.withValues(alpha: 0.7),
    );
    // Stage label
    _paintLabel(canvas);
    // Pest dot
    if (hasPest) {
      final blink = (sin(_t) * 0.4 + 0.6).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(size.x - 8, 8), 5,
          Paint()..color = _bugRed.withValues(alpha: blink));
    }
    // Flood tint
    if (water >= 95) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r.deflate(1), const Radius.circular(6)),
        Paint()..color = _waterBlue.withValues(alpha: 0.35),
      );
    }
    // Health bar
    canvas.drawRect(
      Rect.fromLTWH(2, 2, (size.x - 4) * (health / 100).clamp(0, 1), 3),
      Paint()..color = health > 50 ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
    );
  }

  Color _bg() {
    switch (stage) {
      case CellStage.bare:     return const Color(0xFF8B5E3C);
      case CellStage.plowed:   return const Color(0xFF4A2C0A);
      case CellStage.seeded:   return const Color(0xFF3E2000);
      case CellStage.seedling: return const Color(0xFF2E5902);
      case CellStage.sapling:  return const Color(0xFF388E3C);
      case CellStage.mature:   return const Color(0xFF1B5E20);
      case CellStage.harvest:  return const Color(0xFFF9A825);
      case CellStage.dead:     return const Color(0xFF4E342E);
    }
  }

  void _paintLabel(Canvas canvas) {
    final Map<CellStage, String> labels = {
      CellStage.plowed:   '≡',
      CellStage.seeded:   '·',
      CellStage.seedling: '↑',
      CellStage.sapling:  '♣',
      CellStage.mature:   '✿',
      CellStage.harvest:  '★',
      CellStage.dead:     '✕',
    };
    final text = labels[stage];
    if (text == null) return;
    final tp = TextPaint(style: TextStyle(
        fontSize: size.x * 0.38,
        color: stage == CellStage.harvest ? Colors.amber : Colors.white,
        fontWeight: FontWeight.bold));
    tp.render(canvas, text, Vector2(size.x / 2, size.y / 2), anchor: Anchor.center);
  }
}

// ── RainOverlayComponent ─────────────────────────────────────────────────────
class RainOverlayComponent extends PositionComponent {
  bool active = false;
  final _drops = <Offset>[];
  final _rng   = Random();

  RainOverlayComponent({required Vector2 size}) : super(size: size) {
    for (int i = 0; i < 40; i++) {
      _drops.add(Offset(_rng.nextDouble(), _rng.nextDouble()));
    }
  }

  @override
  void update(double dt) {
    if (!active) return;
    for (int i = 0; i < _drops.length; i++) {
      _drops[i] = Offset(_drops[i].dx, (_drops[i].dy + dt * 1.5) % 1.0);
    }
  }

  @override
  void render(Canvas canvas) {
    if (!active) return;
    final paint = Paint()..color = _waterBlue.withValues(alpha: 0.5)..strokeWidth = 1.5;
    for (final d in _drops) {
      canvas.drawLine(
        Offset(d.dx * size.x, d.dy * size.y),
        Offset(d.dx * size.x - 2, d.dy * size.y + 12), paint,
      );
    }
  }
}

// ── SkyComponent ─────────────────────────────────────────────────────────────
class SkyComponent extends PositionComponent {
  double sunAngle = 0;
  Color  skyColor;
  SkyComponent({required Vector2 size, required this.skyColor})
      : super(size: size);

  @override
  void update(double dt) => sunAngle += dt * 0.3;

  @override
  void render(Canvas canvas) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..shader = LinearGradient(
          colors: [skyColor, skyColor.withValues(alpha: 0.4)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, size.x, size.y)));
    // Sun
    const sx = 0.85; const sy = 0.35;
    canvas.drawCircle(Offset(size.x * sx, size.y * sy), 14,
        Paint()..color = Colors.yellow.shade600);
    final rp = Paint()..color = Colors.yellow.shade300..strokeWidth = 2;
    for (int i = 0; i < 8; i++) {
      final a = (i / 8) * 2 * pi + sunAngle;
      canvas.drawLine(
        Offset(size.x * sx + cos(a) * 18, size.y * sy + sin(a) * 18),
        Offset(size.x * sx + cos(a) * 28, size.y * sy + sin(a) * 28), rp,
      );
    }
    // Ground
    canvas.drawRect(Rect.fromLTWH(0, size.y * 0.72, size.x, size.y * 0.28),
        Paint()..color = const Color(0xFF5D3A1A));
  }
}

// ── FarmGame ─────────────────────────────────────────────────────────────────
class FarmGame extends FlameGame {
  static const int cols = 4, rows = 4;

  final void Function(int r, int c) onCellTap;
  final String cropName;

  late List<List<PlotCellComponent>> cells;
  late RainOverlayComponent rainOverlay;
  late SkyComponent sky;

  FarmGame({required this.onCellTap, required this.cropName});

  @override
  Future<void> onLoad() async {
    sky = SkyComponent(
        size: Vector2(size.x, size.y * 0.22),
        skyColor: const Color(0xFF87CEEB));
    add(sky);

    final gridTop   = size.y * 0.24;
    final cellW     = size.x / cols;
    final cellH     = (size.y - gridTop) / rows;

    cells = List.generate(rows, (r) => List.generate(cols, (c) {
      final cell = PlotCellComponent(
        row: r, col: c, onTap: onCellTap,
        position: Vector2(c * cellW, gridTop + r * cellH),
        size: Vector2(cellW - 2, cellH - 2),
      );
      add(cell);
      return cell;
    }));

    rainOverlay = RainOverlayComponent(size: size);
    add(rainOverlay);
  }

  PlotCellComponent cellAt(int r, int c) => cells[r][c];
  void setRain(bool v) => rainOverlay.active = v;
  void setSkyColor(Color c) => sky.skyColor = c;
}

// ── FarmPlantingSimulation (Flutter Widget) ───────────────────────────────────
class FarmPlantingSimulation extends StatefulWidget {
  final String cropName;
  final Map<String, dynamic> cropData;
  final VoidCallback onComplete;
  final String classId;
  final String module;
  final String studentName;

  const FarmPlantingSimulation({
    super.key,
    required this.cropName, required this.cropData,
    required this.onComplete, required this.classId,
    required this.module, required this.studentName,
  });

  @override
  State<FarmPlantingSimulation> createState() => _FarmPlantingSimulationState();
}

class _FarmPlantingSimulationState extends State<FarmPlantingSimulation> {
  late final FarmGame _game;

  ActiveTool _tool = ActiveTool.none;
  int _seeds = 12, _water = 10, _fert = 4, _spray = 3;
  int _day = 1, _harvested = 0, _chemCount = 0;
  String _msg = '', _event = '';
  Color  _eventColor = Colors.green;
  bool   _evaluating = false;
  final List<String> _log = [];
  final Random _rng = Random();
  final _svc = const GeminiSimulationService();
  late ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
    _game = FarmGame(onCellTap: _tapCell, cropName: widget.cropName);
    _msg = 'Select a tool, then tap a cell. 🌱 Start by plowing!';
  }

  @override
  void dispose() { _confetti.dispose(); super.dispose(); }

  void _tapCell(int r, int c) {
    final cell = _game.cellAt(r, c);
    setState(() {
      switch (_tool) {
        case ActiveTool.plow:
          if (cell.stage == CellStage.bare) {
            cell.stage = CellStage.plowed;
            _log.add('Day $_day: Plowed ($r,$c)');
            _msg = 'Soil plowed! Good structure for root growth. Now plant seeds.';
          } else { _msg = 'This cell is already worked.'; }
          break;
        case ActiveTool.seed:
          if (_seeds <= 0) { _msg = 'No seeds left!'; return; }
          if (cell.stage == CellStage.plowed) {
            cell.stage = CellStage.seeded; _seeds--;
            _log.add('Day $_day: Seeded ($r,$c)');
            _msg = 'Seeds planted at correct depth. Now water regularly.';
          } else { _msg = 'Plow the soil first!'; }
          break;
        case ActiveTool.water:
          if (_water <= 0) { _msg = 'No water left today!'; return; }
          if (cell.stage.index >= CellStage.seeded.index &&
              cell.stage != CellStage.harvest && cell.stage != CellStage.dead) {
            if (cell.water >= 90) {
              cell.water = (cell.water + 15).clamp(0, 100);
              if (cell.water >= 100) { cell.stage = CellStage.dead; cell.health = 0; }
              _msg = '⚠️ Overwatered! Roots are drowning. Water less frequently.';
            } else {
              cell.water = (cell.water + 25).clamp(0, 100); _water--;
              _log.add('Day $_day: Watered ($r,$c) → ${cell.water.toInt()}%');
              _msg = '💧 Good watering! ${widget.cropName} needs 60-80% moisture.';
              _grow(cell);
            }
          } else { _msg = 'Nothing to water here.'; }
          break;
        case ActiveTool.fertiliser:
          if (_fert <= 0) { _msg = 'No fertiliser left!'; return; }
          if (cell.stage.index >= CellStage.seeded.index &&
              cell.stage != CellStage.harvest && cell.stage != CellStage.dead) {
            cell.fertility = (cell.fertility + 30).clamp(0, 100); _fert--;
            _log.add('Day $_day: Fertilised ($r,$c)');
            _msg = '🌿 Nitrogen, phosphorus & potassium boosted. Growth accelerates!';
            _grow(cell);
          } else { _msg = 'Plant seeds first!'; }
          break;
        case ActiveTool.pesticide:
          if (_spray <= 0) { _msg = 'No spray left!'; return; }
          if (cell.hasPest) {
            cell.hasPest = false; cell.health = (cell.health + 10).clamp(0, 100);
            _spray--; _chemCount++;
            _log.add('Day $_day: Chemical spray ($r,$c) — uses: $_chemCount');
            _msg = '🧴 Pest eliminated — but ${_chemCount > 2 ? "DANGER: chemicals are harming beneficial insects!" : "use IPM methods when possible."}';
          } else { _msg = 'No pest here. Biocontrol (ladybirds) works without harming the ecosystem.'; }
          break;
        case ActiveTool.harvest:
          if (cell.stage == CellStage.harvest) {
            cell.stage = CellStage.plowed;
            cell.water = 40; cell.fertility = 50; cell.health = 100;
            _harvested++; _confetti.play();
            _log.add('Day $_day: Harvested ($r,$c) — total: $_harvested');
            _msg = '🌽 Excellent! $_harvested plots harvested. Replant this cell.';
          } else { _msg = 'This cell is not at harvest stage yet.'; }
          break;
        default:
          _msg = 'Select a tool above first! ☝️';
      }
    });
  }

  void _grow(PlotCellComponent cell) {
    if (cell.water >= 40 && cell.fertility >= 40 && !cell.hasPest &&
        cell.stage != CellStage.harvest && cell.stage != CellStage.dead) {
      if (_rng.nextDouble() < 0.55) {
        cell.stage = CellStage.values[
            (cell.stage.index + 1).clamp(0, CellStage.harvest.index)];
      }
    }
  }

  void _advanceDay() {
    if (_day >= 30) { _finish(); return; }
    setState(() {
      _day++; _water = 10;
      for (int r = 0; r < FarmGame.rows; r++) {
        for (int c = 0; c < FarmGame.cols; c++) {
          final cell = _game.cellAt(r, c);
          if (cell.stage == CellStage.dead) continue;
          cell.water = (cell.water - 12).clamp(0, 100);
          if (cell.water < 20 && cell.stage.index >= CellStage.seeded.index) {
            cell.health = (cell.health - 8).clamp(0, 100);
            if (cell.health <= 0) { cell.stage = CellStage.dead; }
          }
          if (!cell.hasPest && _rng.nextDouble() < 0.05 &&
              cell.stage.index >= CellStage.seedling.index) {
            cell.hasPest = true;
          }
          if (cell.hasPest) {
            cell.health = (cell.health - 15).clamp(0, 100);
            if (cell.health <= 0) cell.stage = CellStage.dead;
          }
          if (cell.water >= 30 && cell.health >= 30 && !cell.hasPest &&
              _rng.nextDouble() < 0.25) {
            cell.stage = CellStage.values[
                (cell.stage.index + 1).clamp(0, CellStage.harvest.index)];
          }
        }
      }
      if (_day % 7 == 0) _weatherEvent();
      _msg = 'Day $_day/30 — Seeds: $_seeds | Water: $_water | Harvested: $_harvested';
    });
  }

  void _weatherEvent() {
    final events = [
      ('🌧️ Heavy Rain! All cells +30 water. Beware flooding!', Colors.blue, () {
        for (int r = 0; r < FarmGame.rows; r++) {
          for (int c = 0; c < FarmGame.cols; c++) {
            final cell = _game.cellAt(r, c);
            cell.water = (cell.water + 30).clamp(0, 100);
            if (cell.water >= 100 && cell.stage.index >= CellStage.seeded.index) {
              cell.stage = CellStage.dead;
            }
          }
        }
        _game.setRain(true);
        Future.delayed(const Duration(seconds: 3), () => _game.setRain(false));
      }),
      ('☀️ Drought alert! -20 soil moisture everywhere.', Colors.deepOrange, () {
        for (int r = 0; r < FarmGame.rows; r++) {
          for (int c = 0; c < FarmGame.cols; c++) {
            _game.cellAt(r, c).water = (_game.cellAt(r, c).water - 20).clamp(0, 100);
          }
        }
        _game.setSkyColor(const Color(0xFFFFCA28));
        Future.delayed(const Duration(seconds: 3),
            () => _game.setSkyColor(const Color(0xFF87CEEB)));
      }),
      ('🐛 Pest swarm! Multiple crops attacked.', Colors.red, () {
        for (int r = 0; r < FarmGame.rows; r++) {
          for (int c = 0; c < FarmGame.cols; c++) {
            final cell = _game.cellAt(r, c);
            if (cell.stage.index >= CellStage.seedling.index && _rng.nextBool()) {
              cell.hasPest = true;
            }
          }
        }
      }),
    ];
    final e = events[_rng.nextInt(events.length)];
    _event = e.$1; _eventColor = e.$2; e.$3();
    Future.delayed(const Duration(seconds: 3),
        () { if (mounted) setState(() => _event = ''); });
  }

  Future<void> _finish() async {
    _confetti.play();
    final score = _calcScore();
    setState(() => _evaluating = true);
    final fb = await _svc.evaluateFarmPlanting(
      cropName: widget.cropName,
      completedTasks: _log.take(20).toList(),
      waterLevel: _avgWater().toInt(),
      fertilizerLevel: 4 - _fert,
      pestControlApplied: _chemCount > 0,
      daysElapsed: _day,
      rawScore: score,
    );
    if (!mounted) return;
    setState(() => _evaluating = false);
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) =>
        SimulationResultScreen(
          classId: widget.classId, module: widget.module,
          simulationTitle: '${widget.cropName} Farm — Day $_day',
          feedback: fb, fallbackScore: score, decisionLog: _log,
          summaryData: {'crop': widget.cropName, 'harvested': _harvested,
              'days': _day, 'chemSprays': _chemCount},
          onDone: widget.onComplete,
        )));
  }

  int _calcScore() {
    int s = (_harvested * 8).clamp(0, 60);
    s += (16 - _chemCount * 2).clamp(0, 16);
    s += _day < 25 ? 12 : 6;
    int dead = 0;
    for (int r = 0; r < FarmGame.rows; r++) {
      for (int c = 0; c < FarmGame.cols; c++) {
        if (_game.cellAt(r, c).stage == CellStage.dead) dead++;
      }
    }
    return (s - dead * 3).clamp(0, 100);
  }

  double _avgWater() {
    double t = 0;
    for (int r = 0; r < FarmGame.rows; r++) {
      for (int c = 0; c < FarmGame.cols; c++) { t += _game.cellAt(r, c).water; }
    }
    return t / (FarmGame.rows * FarmGame.cols);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      body: SafeArea(child: Column(children: [
        // Header
        Container(
          color: _fg,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context)),
            Expanded(child: Text('🌾 ${widget.cropName} Farm — Day $_day/30',
                style: const TextStyle(color: Colors.white,
                    fontSize: 15, fontWeight: FontWeight.bold))),
            _chip('🌽', '$_harvested'),
          ]),
        ),
        // Event banner
        if (_event.isNotEmpty)
          Container(width: double.infinity, color: _eventColor.withValues(alpha: 0.9),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(_event, style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold))),
        // Toolbar
        _toolbar(),
        // ── Flame canvas ──────────────────────────────────────────────────
        Expanded(child: GameWidget.controlled(gameFactory: () => _game)),
        // Status
        Container(color: Colors.green.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(_msg, style: TextStyle(color: _fg, fontSize: 11), maxLines: 2)),
        // Day button
        Container(
          color: _fg,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Expanded(child: ElevatedButton.icon(
              onPressed: _evaluating ? null : _advanceDay,
              icon: Icon(_day >= 30 ? Icons.flag : Icons.wb_sunny),
              label: Text(_day >= 30 ? '🏁 End Season' : '⏩ Next Day'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber, foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 12)),
            )),
            const SizedBox(width: 10),
            IconButton(icon: const Icon(Icons.help_outline, color: Colors.white),
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => TutorChatScreen(
                      topic: 'Crop Planting', grade: '', classId: widget.classId,
                      isPrimary: false,
                      contextQuestion: 'Growing ${widget.cropName}. Day $_day.',
                      contextModule: 'farming_content', wrongAnswer: false,
                    )))),
          ]),
        ),
      ])),
    );
  }

  Widget _chip(String icon, String val) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
    child: Text('$icon $val', style: const TextStyle(
        color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
  );

  Widget _toolbar() {
    final tools = [
      (ActiveTool.plow, '🔨', 'Plow'),
      (ActiveTool.seed, '🌾', 'Seeds\n$_seeds'),
      (ActiveTool.water, '💧', 'Water\n$_water'),
      (ActiveTool.fertiliser, '🌿', 'Fert\n$_fert'),
      (ActiveTool.pesticide, '🧴', 'Spray\n$_spray'),
      (ActiveTool.harvest, '🌽', 'Harvest'),
    ];
    return Container(
      height: 64,
      color: Colors.brown.shade100,
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: tools.map((t) {
          final active = _tool == t.$1;
          return GestureDetector(
            onTap: () => setState(() =>
                _tool = active ? ActiveTool.none : t.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: active ? _fg : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: active ? Border.all(color: Colors.amber, width: 2) : null,
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(t.$2, style: const TextStyle(fontSize: 18)),
                Text(t.$3, textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 8,
                        color: active ? Colors.white : Colors.brown.shade800)),
              ]),
            ),
          );
        }).toList()),
    );
  }
}

enum SimulationPhase { preparation, soilPreparation, planting, growing, harvesting, completed }