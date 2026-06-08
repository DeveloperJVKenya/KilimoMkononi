// lib/education/pest/simulations/disease_management_interactive_simulation.dart
// ignore_for_file: prefer_final_fields, avoid_renaming_method_parameters, use_build_context_synchronously, deprecated_member_use
//
// FLAME ENGINE — DiseaseManagementInteractiveSimulation
//
// PlantDiseaseGame (FlameGame)
//   ├── SoilComponent              — ground + root zone at bottom
//   ├── PlantZoneComponent×5       — roots, stem, lower leaves, upper leaves, fruit
//   │     each is TapCallbacks; renders health as colour gradient
//   │     infected zones pulse red-orange via update(dt) sin wave
//   ├── SpreadParticleComponent    — particle that flies between zones when
//   │     disease spreads; shows students the spread direction visually
//   └── HumidityMeterComponent     — animated vertical bar on left side
//         fills/empties as humidity changes, turns blue when > 70%
//
// When humidity is high the infection particles spawn faster (visible).

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
const Color _healthy   = Color(0xFF43A047);
const Color _inf1      = Color(0xFFFFEE58);
const Color _inf2      = Color(0xFFFF8F00);
const Color _inf3      = Color(0xFF4E342E);

// ── Data models ──────────────────────────────────────────────────────────────
enum PlantZone { roots, stem, lowerLeaves, upperLeaves, fruit }

class PlantDisease {
  final String name, emoji, description, symptomHint, correctTreatment;
  final double humidityFavour;
  final PlantZone startsIn;
  const PlantDisease({required this.name, required this.emoji,
      required this.description, required this.symptomHint,
      required this.correctTreatment, required this.humidityFavour,
      required this.startsIn});
}

const _diseases = [
  PlantDisease(name: 'Early Blight', emoji: '🍂',
      description: 'Alternaria solani — dark spots with yellow halos on lower leaves.',
      symptomHint: 'Concentric dark rings, yellowing edges. Starts on lower/older leaves.',
      correctTreatment: 'fungicide', humidityFavour: 1.5, startsIn: PlantZone.lowerLeaves),
  PlantDisease(name: 'Fusarium Wilt', emoji: '🌿',
      description: 'Fusarium oxysporum — vascular wilting, root and stem rot.',
      symptomHint: 'Brown stem cross-section. Plant wilts in afternoon heat.',
      correctTreatment: 'resistant', humidityFavour: 1.2, startsIn: PlantZone.roots),
  PlantDisease(name: 'Powdery Mildew', emoji: '🌫️',
      description: 'Erysiphe — white powdery coating on leaf surfaces.',
      symptomHint: 'White powder on upper leaf. Prefers dry, warm conditions.',
      correctTreatment: 'cultural', humidityFavour: 0.8, startsIn: PlantZone.upperLeaves),
  PlantDisease(name: 'Grey Mould', emoji: '🩶',
      description: 'Botrytis cinerea — grey fuzzy mould on fruit and flowers.',
      symptomHint: 'Fluffy grey growth on damaged or aging fruit tissue.',
      correctTreatment: 'remove', humidityFavour: 2.0, startsIn: PlantZone.fruit),
];

class ZoneState {
  PlantZone zone;
  double infection;
  bool treated;
  ZoneState({required this.zone, this.infection = 0, this.treated = false});
}

// ── SpreadParticleComponent ───────────────────────────────────────────────────
class SpreadParticleComponent extends PositionComponent {
  final Vector2 target;
  double _life = 1.0;
  final Color color;

  SpreadParticleComponent({required Vector2 start, required this.target, required this.color})
      : super(position: start.clone(), size: Vector2(8, 8));

  @override
  void update(double dt) {
    _life -= dt * 1.2;
    final dir = (target - position).normalized();
    position += dir * 80 * dt;
    if (_life <= 0) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(const Offset(4, 4), 4 * _life.clamp(0, 1),
        Paint()..color = color.withOpacity(_life.clamp(0, 1)));
  }
}

// ── HumidityMeterComponent ────────────────────────────────────────────────────
class HumidityMeterComponent extends PositionComponent {
  double humidity;
  HumidityMeterComponent({required this.humidity, required Vector2 position})
      : super(position: position, size: Vector2(20, 120));

  @override
  void render(Canvas canvas) {
    // Meter track
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, 20, 120), const Radius.circular(10)),
        Paint()..color = Colors.grey.shade300);
    // Fill
    final fill = humidity / 100;
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 120 * (1 - fill), 20, 120 * fill), const Radius.circular(10)),
        Paint()..color = humidity > 70
            ? const Color(0xFF1565C0) : const Color(0xFF4FC3F7));
    // Label
    TextPaint(style: const TextStyle(fontSize: 8, color: Colors.black54, fontWeight: FontWeight.bold))
        .render(canvas, '💧', Vector2(4, -14));
    TextPaint(style: const TextStyle(fontSize: 8, color: Colors.black54))
        .render(canvas, '${humidity.toInt()}%', Vector2(0, 122));
    // Warning
    if (humidity > 70) {
      TextPaint(style: const TextStyle(fontSize: 8, color: Colors.red, fontWeight: FontWeight.bold))
          .render(canvas, '!', Vector2(7, 56));
    }
  }
}

// ── PlantZoneComponent ────────────────────────────────────────────────────────
class PlantZoneComponent extends PositionComponent with TapCallbacks {
  final PlantZone zone;
  final void Function(PlantZone z) onTap;
  ZoneState state;
  bool selected = false;
  double _t = 0;

  PlantZoneComponent({
    required this.zone, required this.onTap, required this.state,
    required Vector2 position, required Vector2 size,
  }) : super(position: position, size: size);

  @override void onTapDown(TapDownEvent e) => onTap(zone);
  @override void update(double dt) => _t += dt * 2.5;

  Color get _zoneColor {
    final inf = state.infection;
    if (inf == 0) return _healthy;
    if (inf < 30)  return Color.lerp(_healthy, _inf1, inf / 30)!;
    if (inf < 60)  return Color.lerp(_inf1, _inf2, (inf - 30) / 30)!;
    return Color.lerp(_inf2, _inf3, (inf - 60) / 40)!;
  }

  @override
  void render(Canvas canvas) {
    final infFrac = state.infection / 100;
    final pulse = state.infection > 20 && !state.treated
        ? (sin(_t) * 0.12 + 0.88).clamp(0.0, 1.0)
        : 1.0;

    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.scale(pulse);
    canvas.translate(-size.x / 2, -size.y / 2);

    // Zone background
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.x, size.y), const Radius.circular(10)),
      Paint()..color = _zoneColor,
    );

    // Infection fill overlay from bottom
    if (state.infection > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(0, size.y * (1 - infFrac), size.x, size.y * infFrac),
            const Radius.circular(10)),
        Paint()..color = _inf2.withOpacity(0.45),
      );
    }

    // Selection glow
    if (selected) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.x, size.y), const Radius.circular(10)),
        Paint()..color = Colors.yellow..style = PaintingStyle.stroke..strokeWidth = 3,
      );
    }

    // Treated badge
    if (state.treated) {
      TextPaint(style: const TextStyle(fontSize: 12))
          .render(canvas, '💊', Vector2(size.x - 18, 4));
    }

    // Warning indicator
    if (state.infection > 10 && !state.treated) {
      TextPaint(style: const TextStyle(fontSize: 12))
          .render(canvas, '⚠', Vector2(size.x - 18, 4));
    }

    // Infection % text
    TextPaint(style: const TextStyle(fontSize: 9, color: Colors.white70, fontWeight: FontWeight.bold))
        .render(canvas, '${state.infection.toInt()}%', Vector2(4, 4));

    // Zone name
    TextPaint(style: const TextStyle(fontSize: 10, color: Colors.white,
        fontWeight: FontWeight.bold))
        .render(canvas, _zoneLabel(zone),
            Vector2(size.x / 2, size.y / 2), anchor: Anchor.center);

    canvas.restore();
  }

  String _zoneLabel(PlantZone z) => switch (z) {
    PlantZone.roots       => 'ROOTS',
    PlantZone.stem        => 'STEM',
    PlantZone.lowerLeaves => 'LOWER\nLEAVES',
    PlantZone.upperLeaves => 'UPPER\nLEAVES',
    PlantZone.fruit       => 'FRUIT',
  };
}

// ── PlantDiseaseGame ──────────────────────────────────────────────────────────
class PlantDiseaseGame extends FlameGame {
  final Map<PlantZone, ZoneState> zoneStates;
  final void Function(PlantZone z) onZoneTap;
  final Random rng = Random();

  late HumidityMeterComponent humidityMeter;
  late Map<PlantZone, PlantZoneComponent> zoneComponents;
  double _humidity = 70;

  PlantDiseaseGame({required this.zoneStates, required this.onZoneTap});

  @override
  Future<void> onLoad() async {
    // Layout: plant drawn as anatomical diagram
    // [Fruit at top] [UpperLeaves left/right] [LowerLeaves left/right] [Stem center] [Roots bottom]
    final w = size.x, h = size.y;
    final zw = w * 0.30, zh = h * 0.18;

    final positions = {
      PlantZone.fruit:       Vector2(w * 0.35, h * 0.04),
      PlantZone.upperLeaves: Vector2(w * 0.07, h * 0.22),
      PlantZone.stem:        Vector2(w * 0.35, h * 0.38),
      PlantZone.lowerLeaves: Vector2(w * 0.07, h * 0.56),
      PlantZone.roots:       Vector2(w * 0.35, h * 0.73),
    };
    final sizes = {
      PlantZone.fruit:       Vector2(zw * 1.0, zh),
      PlantZone.upperLeaves: Vector2(zw * 0.8, zh),
      PlantZone.stem:        Vector2(zw * 0.55, zh),
      PlantZone.lowerLeaves: Vector2(zw * 0.8, zh),
      PlantZone.roots:       Vector2(zw * 1.0, zh),
    };

    zoneComponents = {};
    for (final zone in PlantZone.values) {
      final comp = PlantZoneComponent(
        zone: zone, onTap: onZoneTap,
        state: zoneStates[zone]!,
        position: positions[zone]!,
        size: sizes[zone]!,
      );
      zoneComponents[zone] = comp;
      add(comp);
    }

    humidityMeter = HumidityMeterComponent(
        humidity: _humidity, position: Vector2(w * 0.90, h * 0.12));
    add(humidityMeter);
  }

  void setHumidity(double h) {
    _humidity = h;
    humidityMeter.humidity = h;
  }

  void setSelected(PlantZone? z) {
    for (final c in zoneComponents.values) {
      c.selected = c.zone == z;
    }
  }

  void triggerSpreadParticle(PlantZone from, PlantZone to) {
    final fromComp = zoneComponents[from];
    final toComp   = zoneComponents[to];
    if (fromComp == null || toComp == null) return;
    final particle = SpreadParticleComponent(
      start: fromComp.position + fromComp.size / 2,
      target: toComp.position + toComp.size / 2,
      color: _inf2,
    );
    add(particle);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  DiseaseManagementInteractiveSimulation — Flutter widget
// ═══════════════════════════════════════════════════════════════════════════
class DiseaseManagementInteractiveSimulation extends StatefulWidget {
  final VoidCallback onComplete;
  final String classId, module, studentName;

  const DiseaseManagementInteractiveSimulation({
    super.key,
    required this.onComplete, required this.classId,
    required this.module, required this.studentName,
  });

  @override
  State<DiseaseManagementInteractiveSimulation> createState() =>
      _DiseaseManagementInteractiveSimulationState();
}

class _DiseaseManagementInteractiveSimulationState
    extends State<DiseaseManagementInteractiveSimulation> {
  late final PlantDiseaseGame _game;
  late PlantDisease _disease;
  late Map<PlantZone, ZoneState> _zones;

  final _svc = const GeminiSimulationService();
  late ConfettiController _confetti;
  final Random _rng = Random();

  int _day = 1, _totalDays = 10;
  double _humidity = 70, _temperature = 25;
  String _selectedCrop = 'Tomato';
  PlantZone? _selZone;

  int _fungCount = 0, _cultCount = 0, _resistCount = 0;
  List<String> _log = [];
  String _msg = '';
  bool _showTreat = false, _evaluating = false;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    _disease  = _diseases[_rng.nextInt(_diseases.length)];
    _zones    = {
      for (final z in PlantZone.values)
        z: ZoneState(zone: z, infection: z == _disease.startsIn ? 25.0 : 0.0)
    };
    _game = PlantDiseaseGame(zoneStates: _zones, onZoneTap: _tapZone);
    _msg  = 'Day 1: Your $_selectedCrop shows signs of ${_disease.name}! '
        'Tap infected zones (glowing red-orange) to examine them.';
  }

  @override
  void dispose() { _confetti.dispose(); super.dispose(); }

  void _tapZone(PlantZone zone) {
    final z = _zones[zone]!;
    setState(() {
      // Deselect previous
      if (_selZone != null) _game.setSelected(null);
      _selZone = zone;
      _game.setSelected(zone);
      if (z.infection > 0) {
        _showTreat = true;
        _msg = '🔍 ${_zoneName(zone)}: ${_disease.symptomHint}  '
            'Infection: ${z.infection.toInt()}%. Choose treatment below.';
      } else {
        _showTreat = false;
        _msg = '✅ ${_zoneName(zone)} looks healthy (${z.infection.toInt()}% infection).';
      }
    });
  }

  String _zoneName(PlantZone z) => switch (z) {
    PlantZone.roots       => 'Roots',
    PlantZone.stem        => 'Stem',
    PlantZone.lowerLeaves => 'Lower Leaves',
    PlantZone.upperLeaves => 'Upper Leaves',
    PlantZone.fruit       => 'Fruit',
  };

  void _treat(String method) {
    if (_selZone == null) return;
    final zone = _zones[_selZone!]!;
    final correct = method == _disease.correctTreatment;
    setState(() {
      switch (method) {
        case 'fungicide':
          _fungCount++;
          zone.infection = (zone.infection - (correct ? 40 : 15)).clamp(0, 100);
          zone.treated = true;
          _log.add('Day $_day: Fungicide on ${_zoneName(_selZone!)} ${correct ? "(correct)" : "(suboptimal)"}');
          _msg = correct
              ? '💊 Fungicide applied correctly! ${_disease.name} infection reduced significantly.'
              : '💊 Fungicide slows spread but is not the best treatment for ${_disease.name}.';
          break;
        case 'cultural':
          _cultCount++;
          zone.infection = (zone.infection - (correct ? 30 : 10)).clamp(0, 100);
          zone.treated = true;
          _log.add('Day $_day: Cultural practice — ${_zoneName(_selZone!)}');
          _msg = correct
              ? '🌿 Cultural practice (spacing/pruning/ventilation) is ideal for ${_disease.name}!'
              : '🌿 Cultural practice helps but not the primary treatment here.';
          break;
        case 'resistant':
          _resistCount++;
          zone.infection = (zone.infection - (correct ? 50 : 5)).clamp(0, 100);
          zone.treated = true;
          _log.add('Day $_day: Resistant variety strategy noted');
          _msg = correct
              ? '🧬 Resistant varieties eliminate ${_disease.name} long-term — best solution!'
              : '🧬 Resistance helps but this needs immediate treatment too.';
          break;
        case 'remove':
          zone.infection = (zone.infection - (correct ? 35 : 8)).clamp(0, 100);
          zone.treated = true;
          _log.add('Day $_day: Removed infected material — ${_zoneName(_selZone!)}');
          _msg = correct
              ? '✂️ Removing infected ${_zoneName(_selZone!)} stops ${_disease.name} from spreading!'
              : '✂️ Removal reduces spread but this disease needs other treatments too.';
          break;
      }
      _game.setSelected(null);
      _selZone = null;
      _showTreat = false;
    });
  }

  void _nextDay() {
    if (_day >= _totalDays) { _finish(); return; }
    setState(() {
      _day++;
      _humidity    = (_humidity + (_rng.nextDouble() - 0.4) * 10).clamp(30, 98);
      _temperature = (_temperature + (_rng.nextDouble() - 0.5) * 4).clamp(15, 38);
      _game.setHumidity(_humidity);

      final spreadRate = 8.0
          * (_humidity > 70 ? _disease.humidityFavour : 1.0)
          * (_temperature > 22 ? 1.2 : 0.8);

      final zones = PlantZone.values.toList();
      for (final z in zones) {
        final state = _zones[z]!;
        if (state.infection > 0 && !state.treated) {
          state.infection = (state.infection + spreadRate).clamp(0, 100);
        }
        // Spread to adjacent zones with particle effect
        if (state.infection > 40 && _rng.nextDouble() < 0.35) {
          final idx = zones.indexOf(z);
          if (idx > 0) {
            final adj = zones[idx - 1];
            final adjState = _zones[adj]!;
            if (adjState.infection < state.infection * 0.6) {
              adjState.infection = (adjState.infection + spreadRate * 0.5).clamp(0, 100);
              _game.triggerSpreadParticle(z, adj);
            }
          }
          if (idx < zones.length - 1) {
            final adj = zones[idx + 1];
            final adjState = _zones[adj]!;
            if (adjState.infection < state.infection * 0.6 && _rng.nextDouble() < 0.4) {
              adjState.infection = (adjState.infection + spreadRate * 0.4).clamp(0, 100);
              _game.triggerSpreadParticle(z, adj);
            }
          }
        }
        // Treated zones slowly recover
        if (state.treated) {
          state.infection = (state.infection - 5).clamp(0, 100);
          if (state.infection <= 0) state.treated = false;
        }
      }

      final avg = _zones.values.fold<double>(0, (a, z) => a + z.infection) / _zones.length;
      _msg = 'Day $_day/$_totalDays | Avg infection: ${avg.toInt()}% | '
          'Humidity: ${_humidity.toInt()}% | Temp: ${_temperature.toInt()}°C';
    });
  }

  double _overallHealth() {
    final avg = _zones.values.fold<double>(0, (a, z) => a + z.infection) / _zones.length;
    return (100 - avg).clamp(0, 100);
  }

  Future<void> _finish() async {
    _confetti.play();
    setState(() => _evaluating = true);
    final health = _overallHealth();
    final fb = await _svc.evaluateDiseaseManagement(
      crop: _selectedCrop, plantHealth: health.toInt(),
      soilHealth: (80 - _fungCount * 2).clamp(0, 100),
      diseaseInfection: (100 - health).toInt(),
      fungicideCount: _fungCount, culturalPracticeCount: _cultCount,
      resistantVarietyUsed: _resistCount, actionsLog: _log,
      rawScore: _calcScore(health),
    );
    if (!mounted) return;
    setState(() => _evaluating = false);
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) =>
        SimulationResultScreen(
          classId: widget.classId, module: widget.module,
          simulationTitle: '${_disease.name} on $_selectedCrop',
          feedback: fb, fallbackScore: _calcScore(health),
          decisionLog: _log,
          summaryData: {'disease': _disease.name, 'crop': _selectedCrop,
              'plantHealth': health.toInt(), 'fungicide': _fungCount},
          onDone: widget.onComplete,
        )));
  }

  int _calcScore(double health) {
    int s = (health * 0.5).toInt();
    s += (_cultCount * 5).clamp(0, 20);
    s += (_resistCount * 8).clamp(0, 20);
    s -= (_fungCount * 2).clamp(0, 15);
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
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${_disease.emoji} ${_disease.name} on $_selectedCrop',
                  style: const TextStyle(color: Colors.white, fontSize: 14,
                      fontWeight: FontWeight.bold)),
              Text('Day $_day/$_totalDays', style: const TextStyle(
                  color: Colors.white70, fontSize: 11)),
            ])),
            _chip('💚', '${_overallHealth().toInt()}%'),
            const SizedBox(width: 6),
            _chip(_humidity > 70 ? '💧⚠️' : '💧', '${_humidity.toInt()}%'),
          ]),
        ),
        // ── Flame plant diagram ───────────────────────────────────────────
        Expanded(child: GameWidget.controlled(gameFactory: () => _game)),
        // Treatment panel
        if (_showTreat) _treatPanel(),
        // Status
        Container(color: Colors.green.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(_msg, style: TextStyle(color: _appGreen, fontSize: 11),
                maxLines: 3)),
        // Controls
        Container(color: _appGreen,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Expanded(child: ElevatedButton.icon(
              onPressed: _evaluating ? null : _nextDay,
              icon: Icon(_day >= _totalDays ? Icons.flag : Icons.skip_next),
              label: Text(_day >= _totalDays ? '🏁 Final Assessment' : '⏭ Next Day'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber, foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 12)),
            )),
            const SizedBox(width: 10),
            IconButton(icon: const Icon(Icons.help_outline, color: Colors.white),
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => TutorChatScreen(
                      topic: 'Disease Management', grade: '',
                      classId: widget.classId, isPrimary: false,
                      contextQuestion: 'Managing ${_disease.name} on $_selectedCrop. '
                          'Day $_day. Humidity: ${_humidity.toInt()}%.',
                      contextModule: 'disease_content', wrongAnswer: false,
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
        color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
  );

  Widget _treatPanel() => Container(
    color: Colors.green.shade900,
    padding: const EdgeInsets.all(12),
    child: Column(children: [
      Row(children: [
        Text(_disease.emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Expanded(child: Text(_disease.name, style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: Colors.amber,
              borderRadius: BorderRadius.circular(10)),
          child: Text('Best: ${_disease.correctTreatment}',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ]),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _treatBtn('💊 Fungicide', 'fungicide', Colors.blue.shade700),
        _treatBtn('🌿 Cultural', 'cultural', Colors.green.shade700),
        _treatBtn('🧬 Resistant\nVariety', 'resistant', Colors.purple.shade700),
        _treatBtn('✂️ Remove', 'remove', Colors.red.shade700),
      ]),
    ]),
  );

  Widget _treatBtn(String label, String method, Color color) =>
      GestureDetector(
        onTap: () => _treat(method),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)],
          ),
          child: Text(label, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ),
      );
}