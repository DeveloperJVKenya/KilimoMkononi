// lib/education/pest/simulations/pest_management_interactive_simulation.dart
// ignore_for_file: unnecessary_brace_in_string_interps, curly_braces_in_flow_control_structures, non_constant_identifier_names, prefer_final_fields, avoid_renaming_method_parameters, use_build_context_synchronously, deprecated_member_use
//
// FLAME ENGINE — PestManagementInteractiveSimulation
//
// FarmFieldGame (FlameGame)
//   ├── LeafCellComponent ×25  — 5×5 leaf grid, TapCallbacks
//   │   each cell shows health gradient green→yellow→brown
//   │   infected cells have an animated BugIndicator drawn on top
//   └── BeneficialBugComponent — ladybird sprites that patrol the field
//       (spawned when biocontrol is used; each one auto-kills nearby aphids)
//
// Students identify pests by tapping leaves, then choose treatment from
// a Flutter panel below the game canvas.

import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:kilimomkononi/education/simulations/simulation_result_screen.dart';
import 'package:kilimomkononi/education/simulations/gemini_simulation_service.dart';
import 'package:kilimomkononi/education/tutor/tutor_chat_screen.dart';

const Color _appGreen = Color(0xFF032704);

// ── Pest data ────────────────────────────────────────────────────────────────
class PestInfo {
  final String name, description, bestTreatment, symbol;
  final int damagePerRound;
  const PestInfo({required this.name, required this.description,
      required this.bestTreatment, required this.symbol,
      required this.damagePerRound});
}

const _pests = [
  PestInfo(name: 'Aphid',      description: 'Tiny sap-suckers clustering on new leaves.',    bestTreatment: 'biocontrol', symbol: '●', damagePerRound: 5),
  PestInfo(name: 'Cutworm',    description: 'Cuts seedlings at base — active at night.',      bestTreatment: 'organic',    symbol: '◆', damagePerRound: 10),
  PestInfo(name: 'Stem Borer', description: 'Bores into stem; yellowing leaves = first sign.',bestTreatment: 'chemical',   symbol: '▲', damagePerRound: 12),
  PestInfo(name: 'Whitefly',   description: 'Spreads viruses; clouds up when disturbed.',     bestTreatment: 'organic',    symbol: '○', damagePerRound: 7),
  PestInfo(name: 'Thrips',     description: 'Silver scars on fruit; very small.',             bestTreatment: 'chemical',   symbol: '■', damagePerRound: 8),
];

// ── LeafCellComponent ────────────────────────────────────────────────────────
class LeafCellComponent extends PositionComponent with TapCallbacks {
  final int row, col;
  final void Function(int r, int c) onTap;

  double health   = 100;
  PestInfo? pest;
  bool selected   = false;
  double _t       = 0;

  LeafCellComponent({
    required this.row, required this.col, required this.onTap,
    required Vector2 position, required Vector2 size,
  }) : super(position: position, size: size);

  @override void onTapDown(TapDownEvent e) => onTap(row, col);

  @override void update(double dt) => _t += dt * 3;

  @override
  void render(Canvas canvas) {
    final h = health / 100;
    final leafColor = Color.lerp(const Color(0xFF6D4C41), const Color(0xFF66BB6A), h)!;

    // Leaf background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.x, size.y).deflate(1), const Radius.circular(6)),
      Paint()..color = leafColor,
    );

    // Leaf vein
    final vp = Paint()..color = Colors.green.shade900.withOpacity(0.15 * h)..strokeWidth = 1;
    canvas.drawLine(Offset(size.x / 2, 0), Offset(size.x / 2, size.y), vp);
    for (double y = 8; y < size.y; y += 10) {
      canvas.drawLine(
        Offset(size.x / 2, y),
        Offset(y < size.y / 2 ? 4 : size.x - 4, y), vp,
      );
    }

    // Health bar
    canvas.drawRect(
      Rect.fromLTWH(2, size.y - 4, (size.x - 4) * h.clamp(0, 1), 3),
      Paint()..color = h > 0.5 ? Colors.green : Colors.orange,
    );

    // Selected border
    if (selected) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, size.x, size.y).deflate(1), const Radius.circular(6)),
        Paint()..color = Colors.yellow..strokeWidth = 3..style = PaintingStyle.stroke,
      );
    }

    // Pest indicator — animated symbol
    if (pest != null) {
      final blink = (sin(_t) * 0.35 + 0.65).clamp(0.0, 1.0);
      final scale = 0.9 + sin(_t) * 0.15;
      canvas.save();
      canvas.translate(size.x / 2, size.y / 2);
      canvas.scale(scale);
      canvas.translate(-size.x / 2, -size.y / 2);
      TextPaint(style: TextStyle(
        fontSize: size.x * 0.42,
        color: Colors.red.shade700.withOpacity(blink),
        fontWeight: FontWeight.bold,
      )).render(canvas, pest!.symbol,
          Vector2(size.x / 2, size.y / 2), anchor: Anchor.center);
      canvas.restore();
    }

    // Health text
    TextPaint(style: const TextStyle(fontSize: 8, color: Colors.white70))
        .render(canvas, '${health.toInt()}%', Vector2(4, 4));
  }
}

// ── BeneficialBugComponent — Flame component that roams and eats aphids ──────
class BeneficialBugComponent extends PositionComponent {
  final FarmFieldGame game;
  double _angle  = 0;
  double _speed  = 60;
  double _timer  = 0;
  double _t      = 0;

  BeneficialBugComponent({required this.game, required Vector2 startPos})
      : super(position: startPos, size: Vector2(14, 14));

  @override
  void update(double dt) {
    _t += dt * 4;
    _timer += dt;

    // Wander
    _angle += (game.rng.nextDouble() - 0.5) * dt * 4;
    position += Vector2(cos(_angle) * _speed * dt, sin(_angle) * _speed * dt);
    position.x = position.x.clamp(0, game.size.x - 14);
    position.y = position.y.clamp(game.gridTop, game.size.y - 14);

    // Every 1.5s, try to eat an aphid nearby
    if (_timer >= 1.5) {
      _timer = 0;
      _tryEat();
    }
  }

  void _tryEat() {
    final cellW = game.size.x / FarmFieldGame.cols;
    final cellH = (game.size.y - game.gridTop) / FarmFieldGame.rows;
    final myCell_r = ((position.y - game.gridTop) / cellH).floor().clamp(0, FarmFieldGame.rows - 1);
    final myCell_c = (position.x / cellW).floor().clamp(0, FarmFieldGame.cols - 1);
    final cell = game.cellAt(myCell_r, myCell_c);
    if (cell.pest != null && cell.pest!.bestTreatment == 'biocontrol') {
      cell.pest = null;
      cell.health = (cell.health + 5).clamp(0, 100);
      game.onBiocontrolKill();
    }
  }

  @override
  void render(Canvas canvas) {
    // Ladybird body
    canvas.drawCircle(Offset(7, 7), 6, Paint()..color = Colors.red.shade600);
    // Spots
    canvas.drawCircle(Offset(5, 6), 1.5, Paint()..color = Colors.black87);
    canvas.drawCircle(Offset(9, 6), 1.5, Paint()..color = Colors.black87);
    canvas.drawCircle(Offset(7, 10), 1.5, Paint()..color = Colors.black87);
    // Head
    canvas.drawCircle(Offset(7, 2), 3, Paint()..color = Colors.black87);
    // Antennae
    final ap = Paint()..color = Colors.black..strokeWidth = 1;
    canvas.drawLine(const Offset(6, 1), Offset(3 + sin(_t) * 2, -3), ap);
    canvas.drawLine(const Offset(8, 1), Offset(11 + sin(_t + 1) * 2, -3), ap);
  }
}

// ── FarmFieldGame ─────────────────────────────────────────────────────────────
class FarmFieldGame extends FlameGame {
  static const int cols = 5, rows = 5;

  final void Function(int r, int c) onCellTap;
  final VoidCallback onBiocontrolKill;
  final Random rng = Random();

  late List<List<LeafCellComponent>> cells;
  final List<BeneficialBugComponent> bugs = [];
  double gridTop = 0;

  FarmFieldGame({required this.onCellTap, required this.onBiocontrolKill});

  @override
  Future<void> onLoad() async {
    gridTop = size.y * 0.05;
    final cellW = size.x / cols;
    final cellH = (size.y - gridTop) / rows;

    cells = List.generate(rows, (r) => List.generate(cols, (c) {
      final cell = LeafCellComponent(
        row: r, col: c, onTap: onCellTap,
        position: Vector2(c * cellW, gridTop + r * cellH),
        size: Vector2(cellW - 2, cellH - 2),
      );
      add(cell);
      return cell;
    }));

    // Spawn 3 initial pests
    for (int i = 0; i < 3; i++) {
      final r = rng.nextInt(rows), c = rng.nextInt(cols);
      cells[r][c].pest = _pests[rng.nextInt(_pests.length)];
    }
  }

  LeafCellComponent cellAt(int r, int c) => cells[r][c];

  void spawnBug() {
    final bug = BeneficialBugComponent(
      game: this,
      startPos: Vector2(rng.nextDouble() * size.x, gridTop + rng.nextDouble() * (size.y - gridTop)),
    );
    bugs.add(bug);
    add(bug);
  }

  void removeBug() {
    if (bugs.isNotEmpty) {
      final bug = bugs.removeLast();
      remove(bug);
    }
  }

  void spreadPests() {
    final newPests = <(int, int)>[];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (cells[r][c].pest != null && rng.nextDouble() < 0.3) {
          final dirs = [[-1,0],[1,0],[0,-1],[0,1]];
          final d = dirs[rng.nextInt(4)];
          final nr = r + d[0], nc = c + d[1];
          if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && cells[nr][nc].pest == null) {
            newPests.add((nr, nc));
          }
        }
      }
    }
    for (final pos in newPests) {
      cells[pos.$1][pos.$2].pest = _pests[rng.nextInt(_pests.length)];
    }
    // New spawn
    final spawnCount = 1 + rng.nextInt(2);
    for (int i = 0; i < spawnCount; i++) {
      final r = rng.nextInt(rows), c = rng.nextInt(cols);
      if (cells[r][c].pest == null) {
        cells[r][c].pest = _pests[rng.nextInt(_pests.length)];
      }
    }
  }

  int activePestCount() => cells.fold(0,
      (a, row) => a + row.where((c) => c.pest != null).length);
  int bugCount() => bugs.length;
}

// ── PestManagementInteractiveSimulation (Flutter) ────────────────────────────
class PestManagementInteractiveSimulation extends StatefulWidget {
  final VoidCallback onComplete;
  final String classId, module, studentName;

  const PestManagementInteractiveSimulation({
    super.key,
    required this.onComplete, required this.classId,
    required this.module, required this.studentName,
  });

  @override
  State<PestManagementInteractiveSimulation> createState() =>
      _PestManagementInteractiveSimulationState();
}

class _PestManagementInteractiveSimulationState
    extends State<PestManagementInteractiveSimulation> {
  late final FarmFieldGame _game;
  final _svc = const GeminiSimulationService();
  late ConfettiController _confetti;

  int _round = 1;
  final int _totalRounds = 8;
  int _bioTokens = 3, _orgTokens = 4, _chemTokens = 3, _trapTokens = 2;
  int _beneficialCount = 5, _cropHealth = 100;
  int _chemCount = 0, _orgCount = 0, _bioCount = 0;

  int? _selR, _selC;
  String _msg = '';
  bool _showTreatPanel = false;
  bool _evaluating = false;
  List<String> _log = [];

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    _game = FarmFieldGame(
      onCellTap: _onCellTap,
      onBiocontrolKill: _onBugKill,
    );
    _msg = 'Round 1: Tap any coloured symbol (●◆▲○■) to identify the pest!';
  }

  @override
  void dispose() { _confetti.dispose(); super.dispose(); }

  void _onBugKill() {
    if (mounted) setState(() {
      _beneficialCount = (_beneficialCount + 1).clamp(0, 20);
      _msg = '🐞 A ladybird naturally killed an aphid! Ecosystem doing its job.';
    });
  }

  void _onCellTap(int r, int c) {
    final cell = _game.cellAt(r, c);
    // Deselect previous
    if (_selR != null && _selC != null) {
      _game.cellAt(_selR!, _selC!).selected = false;
    }
    setState(() {
      cell.selected = true;
      _selR = r; _selC = c;
      if (cell.pest != null) {
        _showTreatPanel = true;
        _msg = '🔍 ${cell.pest!.name}: ${cell.pest!.description} '
            'Best treatment: ${cell.pest!.bestTreatment}. Choose below.';
      } else {
        _showTreatPanel = false;
        _msg = cell.health < 80
            ? '⚠️ Leaf damaged (${cell.health.toInt()}%) — pest may have moved on.'
            : '✅ Healthy leaf (${cell.health.toInt()}%). No active pest here.';
      }
    });
  }

  void _treat(String method) {
    if (_selR == null || _selC == null) return;
    final cell = _game.cellAt(_selR!, _selC!);
    setState(() {
      switch (method) {
        case 'biocontrol':
          if (_bioTokens <= 0) { _msg = 'No biocontrol tokens!'; return; }
          _bioTokens--; _bioCount++;
          if (cell.pest != null) {
            final optimal = cell.pest!.bestTreatment == 'biocontrol';
            cell.pest = null;
            cell.health = (cell.health + 5).clamp(0, 100);
            _beneficialCount = (_beneficialCount + (optimal ? 2 : 0)).clamp(0, 20);
            _game.spawnBug();
            _log.add('Round $_round: Biocontrol ${optimal ? "(optimal)" : "(suboptimal)"}');
            _msg = optimal
                ? '🐞 Excellent! Ladybirds released. Aphids gone. Beneficial insects +2!'
                : '🐞 Biocontrol applied. Less effective here but no harm to ecosystem.';
          }
          break;
        case 'organic':
          if (_orgTokens <= 0) { _msg = 'No organic spray!'; return; }
          _orgTokens--; _orgCount++;
          if (cell.pest != null) {
            final optimal = cell.pest!.bestTreatment == 'organic';
            cell.pest = null;
            cell.health = (cell.health + 3).clamp(0, 100);
            _log.add('Round $_round: Organic spray ${optimal ? "(optimal)" : "(OK)"}');
            _msg = optimal
                ? '🌿 Organic neem/pyrethrum worked perfectly! Safe for ecosystem.'
                : '🌿 Organic applied. Partially effective on this pest type.';
          }
          break;
        case 'chemical':
          if (_chemTokens <= 0) { _msg = 'No chemical spray!'; return; }
          _chemTokens--; _chemCount++;
          if (cell.pest != null) {
            cell.pest = null;
            cell.health = (cell.health + 8).clamp(0, 100);
            final killed = (_beneficialCount > 0) ? 2 : 0;
            _beneficialCount = (_beneficialCount - killed).clamp(0, 20);
            if (_game.bugCount() > 0) _game.removeBug();
            _log.add('Round $_round: Chemical spray — beneficial insects -$killed');
            _msg = '🧴 Pest killed but $killed beneficial insects harmed! '
                '${_chemCount > 2 ? "Over-reliance on chemicals reduces ecosystem health." : "Use IPM when possible."}';
          }
          break;
        case 'trap':
          if (_trapTokens <= 0) { _msg = 'No traps!'; return; }
          _trapTokens--;
          if (cell.pest != null) {
            cell.pest = null;
            _log.add('Round $_round: Pheromone trap');
            _msg = '🪤 Pheromone trap — chemical-free pest capture! Great IPM practice.';
          }
          break;
      }
      cell.selected = false; _selR = null; _selC = null; _showTreatPanel = false;
    });
  }

  void _nextRound() {
    if (_round >= _totalRounds) { _finish(); return; }
    setState(() {
      _round++;
      // Pest damage
      int pestDmg = 0;
      for (int r = 0; r < FarmFieldGame.rows; r++) {
        for (int c = 0; c < FarmFieldGame.cols; c++) {
          final cell = _game.cellAt(r, c);
          if (cell.pest != null) {
            cell.health = (cell.health - cell.pest!.damagePerRound).clamp(0, 100);
            pestDmg += cell.pest!.damagePerRound;
          }
        }
      }
      _cropHealth = (_cropHealth - pestDmg ~/ 8).clamp(0, 100);
      _game.spreadPests();
      // Refill tokens
      if (_round % 3 == 0) {
        _bioTokens = (_bioTokens + 1).clamp(0, 6);
        _orgTokens = (_orgTokens + 1).clamp(0, 6);
      }
      _msg = 'Round $_round/$_totalRounds — Pests: ${_game.activePestCount()} | '
          'Crop: $_cropHealth% | Beneficial: $_beneficialCount';
    });
  }

  Future<void> _finish() async {
    _confetti.play();
    setState(() => _evaluating = true);
    final score = _calcScore();
    final fb = await _svc.evaluatePestManagement(
      crop: 'Maize', cropHealth: _cropHealth,
      pestPopulation: _game.activePestCount(),
      beneficialInsects: _beneficialCount,
      chemicalSprayCount: _chemCount,
      organicTreatmentCount: _orgCount,
      biocontrolCount: _bioCount,
      actionsLog: _log, rawScore: score,
    );
    if (!mounted) return;
    setState(() => _evaluating = false);
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) =>
        SimulationResultScreen(
          classId: widget.classId, module: widget.module,
          simulationTitle: 'IPM Field Defender',
          feedback: fb, fallbackScore: score, decisionLog: _log,
          summaryData: {'cropHealth': _cropHealth, 'beneficialInsects': _beneficialCount,
              'chemSprays': _chemCount, 'biocontrol': _bioCount},
          onDone: widget.onComplete,
        )));
  }

  int _calcScore() {
    int s = (_cropHealth * 0.4).toInt();
    s += (_beneficialCount * 2).clamp(0, 20);
    s += (_bioCount * 4).clamp(0, 20);
    s += (_orgCount * 3).clamp(0, 15);
    s -= (_chemCount * 3).clamp(0, 25);
    return s.clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      body: SafeArea(child: Column(children: [
        // Header
        Container(color: _appGreen,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context)),
            const Expanded(child: Text('🌿 IPM Field Defender',
                style: TextStyle(color: Colors.white, fontSize: 16,
                    fontWeight: FontWeight.bold))),
            _chip('🐞', '$_beneficialCount'),
            const SizedBox(width: 6),
            _chip('💚', '$_cropHealth%'),
          ]),
        ),
        // Round bar
        Container(color: Colors.green.shade800,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(children: [
            const Text('Round ', style: TextStyle(color: Colors.white70, fontSize: 11)),
            ...List.generate(_totalRounds, (i) => Expanded(child: Container(
              height: 8, margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: i < _round ? Colors.amber : Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ))),
            Text('  Pests: ${_game.activePestCount()}',
                style: TextStyle(
                    color: _game.activePestCount() > 8 ? Colors.redAccent : Colors.greenAccent,
                    fontSize: 11, fontWeight: FontWeight.bold)),
          ]),
        ),
        // ── Flame canvas ──────────────────────────────────────────────────
        Expanded(child: GameWidget.controlled(gameFactory: () => _game)),
        // Treatment panel
        if (_showTreatPanel) _treatPanel(),
        // Status
        Container(color: Colors.green.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(_msg, style: TextStyle(color: _appGreen, fontSize: 11), maxLines: 3)),
        // Controls
        Container(color: _appGreen,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Expanded(child: ElevatedButton.icon(
              onPressed: _evaluating ? null : _nextRound,
              icon: Icon(_round >= _totalRounds ? Icons.flag : Icons.skip_next),
              label: Text(_round >= _totalRounds ? '🏁 Final Score' : '⏭ Next Round'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber, foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 12)),
            )),
            const SizedBox(width: 10),
            IconButton(icon: const Icon(Icons.help_outline, color: Colors.white),
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => TutorChatScreen(
                      topic: 'Pest Management', grade: '',
                      classId: widget.classId, isPrimary: false,
                      contextQuestion: 'Round $_round: ${_msg}',
                      contextModule: 'pest_content', wrongAnswer: false,
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

  Widget _treatPanel() => Container(
    color: Colors.green.shade900,
    padding: const EdgeInsets.all(12),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      _treatBtn('🐞 Bio\n($_bioTokens)', 'biocontrol', Colors.green.shade700, _bioTokens > 0),
      _treatBtn('🌿 Organic\n($_orgTokens)', 'organic', Colors.teal.shade700, _orgTokens > 0),
      _treatBtn('🧴 Chemical\n($_chemTokens)', 'chemical', Colors.orange.shade700, _chemTokens > 0),
      _treatBtn('🪤 Trap\n($_trapTokens)', 'trap', Colors.purple.shade700, _trapTokens > 0),
    ]),
  );

  Widget _treatBtn(String label, String method, Color color, bool enabled) =>
      GestureDetector(
        onTap: enabled ? () => _treat(method) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: enabled ? color : Colors.grey.shade700,
            borderRadius: BorderRadius.circular(10),
            boxShadow: enabled ? [BoxShadow(color: color, blurRadius: 6)] : null,
          ),
          child: Text(label, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white,
                  fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      );
}