// lib/education/simulations/weather_prediction_simulation.dart
// ignore_for_file: prefer_final_fields, annotate_overrides, use_build_context_synchronously, deprecated_member_use
//
// FLAME ENGINE — WeatherPredictionSimulation
//
// WeatherGame (FlameGame)
//   ├── SkyBackgroundComponent     — animated gradient sky
//   ├── SunComponent               — rotating sun with rays
//   ├── CloudComponent ×N          — clouds drifting across sky
//   ├── RainComponent              — animated rain drops
//   ├── LightningComponent         — storm flash
//   ├── FogComponent               — fog bands for foggy weather
//   └── CropRowComponent           — foreground crop silhouettes
//
// Flutter panel below shows instrument gauges + prediction buttons.
// Students observe sky clues and predict tomorrow's weather.

import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:kilimomkononi/education/simulations/simulation_result_screen.dart';
import 'package:kilimomkononi/education/simulations/gemini_simulation_service.dart';
import 'package:kilimomkononi/education/tutor/tutor_chat_screen.dart';

const Color _appGreen = Color(0xFF032704);

enum WxCondition { sunny, partlyCloudy, overcast, rainy, stormy, foggy }

extension WxX on WxCondition {
  String get label => const {
    WxCondition.sunny: 'Sunny', WxCondition.partlyCloudy: 'Partly Cloudy',
    WxCondition.overcast: 'Overcast', WxCondition.rainy: 'Rainy',
    WxCondition.stormy: 'Stormy', WxCondition.foggy: 'Foggy',
  }[this]!;
  String get emoji => const {
    WxCondition.sunny: '☀️', WxCondition.partlyCloudy: '⛅',
    WxCondition.overcast: '☁️', WxCondition.rainy: '🌧️',
    WxCondition.stormy: '⛈️', WxCondition.foggy: '🌫️',
  }[this]!;
  String get advice => const {
    WxCondition.sunny: 'Irrigate in the morning. Good day to spray pesticides.',
    WxCondition.partlyCloudy: 'Good farming day. Check soil moisture.',
    WxCondition.overcast: 'Avoid fungicide spray — humidity encourages disease.',
    WxCondition.rainy: 'Skip irrigation. Check drainage. Delay spraying.',
    WxCondition.stormy: 'Secure young seedlings. Stay indoors. Check crops after storm.',
    WxCondition.foggy: 'High disease risk — watch for early blight and mildew.',
  }[this]!;
  Color get skyColor => const {
    WxCondition.sunny: Color(0xFF64B5F6),
    WxCondition.partlyCloudy: Color(0xFF90CAF9),
    WxCondition.overcast: Color(0xFF90A4AE),
    WxCondition.rainy: Color(0xFF78909C),
    WxCondition.stormy: Color(0xFF455A64),
    WxCondition.foggy: Color(0xFFB0BEC5),
  }[this]!;
}

class DayWx {
  final int dayNum;
  final WxCondition condition;
  final double tempC;
  final int humidity, cloudCover, barometer;
  final double windKph;
  final String observation;
  DayWx({required this.dayNum, required this.condition, required this.tempC,
      required this.humidity, required this.cloudCover, required this.barometer,
      required this.windKph, required this.observation});
}

// ── Flame sky components ─────────────────────────────────────────────────────

class SkyBgComponent extends PositionComponent {
  WxCondition condition;
  SkyBgComponent({required Vector2 size, required this.condition}) : super(size: size);
  @override
  void render(Canvas canvas) {
    final c = condition.skyColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..shader = LinearGradient(
            colors: [c, c.withOpacity(0.5)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter)
            .createShader(Rect.fromLTWH(0, 0, size.x, size.y)));
    // Ground strip
    canvas.drawRect(Rect.fromLTWH(0, size.y * 0.75, size.x, size.y * 0.25),
        Paint()..color = const Color(0xFF5D3A1A));
    // Simple crop silhouettes
    final cp = Paint()..color = const Color(0xFF2E7D32);
    for (double x = 15; x < size.x; x += 25) {
      canvas.drawLine(Offset(x, size.y * 0.75), Offset(x, size.y * 0.5),
          cp..strokeWidth = 3);
      // Leaf
      canvas.drawLine(Offset(x, size.y * 0.62), Offset(x + 12, size.y * 0.57),
          cp..strokeWidth = 2);
    }
  }
}

class SunComponent extends PositionComponent {
  double angle = 0;
  SunComponent() : super(position: Vector2(0, 0), size: Vector2(60, 60));
  @override
  void update(double dt) => angle += dt * 0.4;
  @override
  void render(Canvas canvas) {
    canvas.drawCircle(const Offset(30, 30), 18, Paint()..color = Colors.yellow.shade600);
    final rp = Paint()..color = Colors.yellow.shade300..strokeWidth = 2.5;
    for (int i = 0; i < 8; i++) {
      final a = (i / 8) * 2 * pi + angle;
      canvas.drawLine(
        Offset(30 + cos(a) * 22, 30 + sin(a) * 22),
        Offset(30 + cos(a) * 33, 30 + sin(a) * 33), rp,
      );
    }
  }
}

class CloudComponent extends PositionComponent {
  final double speed;
  CloudComponent({required Vector2 position, required Vector2 size, required this.speed})
      : super(position: position, size: size);
  @override
  void update(double dt) {
    position.x += speed * dt;
    if (position.x > 500) position.x = -size.x;
  }
  @override
  void render(Canvas canvas) {
    final p = Paint()..color = Colors.white.withOpacity(0.85);
    canvas.drawCircle(Offset(size.x * 0.4, size.y * 0.5), size.x * 0.28, p);
    canvas.drawCircle(Offset(size.x * 0.6, size.y * 0.4), size.x * 0.32, p);
    canvas.drawCircle(Offset(size.x * 0.75, size.y * 0.55), size.x * 0.24, p);
    canvas.drawCircle(Offset(size.x * 0.25, size.y * 0.55), size.x * 0.22, p);
  }
}

class RainComponent extends PositionComponent {
  bool active = false;
  final List<Offset> _drops = [];
  final Random _rng = Random();
  RainComponent({required Vector2 size}) : super(size: size) {
    for (int i = 0; i < 50; i++) {
      _drops.add(Offset(_rng.nextDouble(), _rng.nextDouble()));
    }
  }
  @override
  void update(double dt) {
    if (!active) return;
    for (int i = 0; i < _drops.length; i++) {
      _drops[i] = Offset(_drops[i].dx, (_drops[i].dy + dt * 1.8) % 1.0);
    }
  }
  @override
  void render(Canvas canvas) {
    if (!active) return;
    final p = Paint()..color = Colors.lightBlue.shade200.withOpacity(0.6)..strokeWidth = 1.5;
    for (final d in _drops) {
      canvas.drawLine(Offset(d.dx * size.x, d.dy * size.y),
          Offset(d.dx * size.x - 2, d.dy * size.y + 12), p);
    }
  }
}

class FogComponent extends PositionComponent {
  double _t = 0;
  bool active = false;
  FogComponent({required Vector2 size}) : super(size: size);
  @override void update(double dt) => _t += dt * 0.3;
  @override
  void render(Canvas canvas) {
    if (!active) return;
    for (double y = 0; y < size.y * 0.75; y += 20) {
      canvas.drawLine(Offset(0, y + sin(_t) * 5), Offset(size.x, y + 8 + cos(_t) * 5),
          Paint()..color = Colors.white.withOpacity(0.4)..strokeWidth = 14);
    }
  }
}

// ── WeatherGame ───────────────────────────────────────────────────────────────
class WeatherGame extends FlameGame {
  WxCondition _condition;
  late SkyBgComponent sky;
  late SunComponent sun;
  late RainComponent rain;
  late FogComponent fog;
  final List<CloudComponent> clouds = [];
  final Random rng = Random();

  WeatherGame({required WxCondition initial}) : _condition = initial;

  @override
  Future<void> onLoad() async {
    sky = SkyBgComponent(size: size, condition: _condition);
    add(sky);

    sun = SunComponent()..position = Vector2(size.x * 0.82, size.y * 0.1);
    add(sun);

    // Clouds
    for (int i = 0; i < 5; i++) {
      final cloud = CloudComponent(
        position: Vector2(rng.nextDouble() * size.x, rng.nextDouble() * size.y * 0.35),
        size: Vector2(70 + rng.nextDouble() * 50, 40),
        speed: 12 + rng.nextDouble() * 18,
      );
      clouds.add(cloud);
      add(cloud);
    }

    rain = RainComponent(size: size);
    add(rain);
    fog = FogComponent(size: size);
    add(fog);

    _applyCondition(_condition);
  }

  void setCondition(WxCondition c) {
    _condition = c;
    sky.condition = c;
    _applyCondition(c);
  }

  void _applyCondition(WxCondition c) {
    rain.active = c == WxCondition.rainy || c == WxCondition.stormy;
    fog.active  = c == WxCondition.foggy;

    final cloudCount = c == WxCondition.sunny ? 1
        : c == WxCondition.partlyCloudy ? 3
        : 5;

    for (int i = 0; i < clouds.length; i++) {
      clouds[i].position.y = i < cloudCount ? rng.nextDouble() * size.y * 0.35 : -200;
    }

    // Dark clouds for stormy/overcast
    if (c == WxCondition.stormy || c == WxCondition.overcast) {
      for (final cloud in clouds) {
        cloud.position.y = cloud.position.y.clamp(0, size.y * 0.3);
      }
    }
  }
}

// ── WeatherPredictionSimulation (Flutter) ────────────────────────────────────
class WeatherPredictionSimulation extends StatefulWidget {
  final VoidCallback onComplete;
  final String classId, module, studentName;

  const WeatherPredictionSimulation({
    super.key, required this.onComplete, required this.classId,
    required this.module, required this.studentName,
  });

  @override
  State<WeatherPredictionSimulation> createState() =>
      _WeatherPredictionSimulationState();
}

class _WeatherPredictionSimulationState
    extends State<WeatherPredictionSimulation> {
  late final WeatherGame _game;
  late List<DayWx> _seq;
  final _svc = const GeminiSimulationService();
  late ConfettiController _confetti;
  final Random _rng = Random();

  int _day = 1;
  final int _totalDays = 7;
  WxCondition? _prediction;
  bool _locked = false, _showResult = false, _isCorrect = false, _evaluating = false;
  int _correct = 0;
  List<Map<String, dynamic>> _history = [];
  List<String> _log = [];

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    _seq = _generateSeq();
    _game = WeatherGame(initial: _seq[0].condition);
  }

  @override
  void dispose() { _confetti.dispose(); super.dispose(); }

  DayWx get today => _seq[_day - 1];

  List<DayWx> _generateSeq() {
    final r = _rng;
    final pool = WxCondition.values;
    WxCondition last = pool[r.nextInt(pool.length)];
    return List.generate(7, (i) {
      final c = r.nextDouble() < 0.5 ? last : pool[r.nextInt(pool.length)];
      last = c;
      final (temp, hum, wind, cloud, baro) = _readings(c);
      return DayWx(
        dayNum: i + 1, condition: c,
        tempC: temp + (r.nextDouble() - 0.5) * 4,
        humidity: (hum + r.nextInt(10) - 5).clamp(20, 100),
        windKph: wind + (r.nextDouble() - 0.5) * 8,
        cloudCover: (cloud + r.nextInt(15) - 7).clamp(0, 100),
        barometer: (baro + r.nextInt(6) - 3).clamp(990, 1030),
        observation: _obs(c)[r.nextInt(_obs(c).length)],
      );
    });
  }

  (double, int, double, int, int) _readings(WxCondition c) => switch (c) {
    WxCondition.sunny        => (28.0, 40, 10.0, 10,  1018),
    WxCondition.partlyCloudy => (25.0, 60, 15.0, 50,  1012),
    WxCondition.overcast     => (22.0, 75, 20.0, 85,  1008),
    WxCondition.rainy        => (19.0, 90, 25.0, 95,  1002),
    WxCondition.stormy       => (17.0, 95, 45.0, 100,  995),
    WxCondition.foggy        => (16.0, 98, 5.0,  70,  1010),
  };

  List<String> _obs(WxCondition c) => switch (c) {
    WxCondition.sunny        => ['Clear blue sky. Mount Kenya visible. Soil drying fast.',
                                  'Strong sunshine. Insects very active.'],
    WxCondition.partlyCloudy => ['White cumulus clouds drift east. Mild breeze.',
                                  'Good visibility. Some afternoon cloud build-up.'],
    WxCondition.overcast     => ['Grey sky. Humidity feels heavy. Barometer falling.',
                                  'Leaves feel damp. No sun visible all day.'],
    WxCondition.rainy        => ['Steady rain. Streams running. Roads muddy.',
                                  'Nimbostratus clouds overhead. Drizzle all day.'],
    WxCondition.stormy       => ['Cumulonimbus towers to west! Lightning. Strong gusts.',
                                  'Sky turned dark. Temperature dropped 8°C in one hour.'],
    WxCondition.foggy        => ['Visibility under 200m at dawn. Valley filled with mist.',
                                  'Dew on every leaf. Fog burns off by 10am.'],
  };

  void _predict(WxCondition p) {
    if (_locked) return;
    setState(() {
      _prediction = p; _locked = true; _showResult = true;
      _isCorrect = p == today.condition;
      if (_isCorrect) { _correct++; _confetti.play(); }
      _log.add('Day $_day: predicted ${p.label}, actual ${today.condition.label}, '
          '${_isCorrect ? "correct" : "wrong"}');
      _history.add({'day': _day, 'predicted': p.label,
          'actual': today.condition.label, 'correct': _isCorrect});
    });
  }

  void _nextDay() {
    if (!_locked) return;
    if (_day >= _totalDays) { _finish(); return; }
    setState(() {
      _day++; _prediction = null; _locked = false; _showResult = false;
      _game.setCondition(_seq[_day - 1].condition);
    });
  }

  Future<void> _finish() async {
    _confetti.play();
    setState(() => _evaluating = true);
    final acc = _correct / _totalDays * 100;
    final fb = await _svc.evaluateWeatherPrediction(
      correctPredictions: _correct, totalPredictions: _totalDays,
      accuracy: acc, weatherHistory: _history,
    );
    if (!mounted) return;
    setState(() => _evaluating = false);
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) =>
        SimulationResultScreen(
          classId: widget.classId, module: widget.module,
          simulationTitle: '7-Day Weather Prediction',
          feedback: fb, fallbackScore: acc.toInt(), decisionLog: _log,
          summaryData: {'correct': _correct, 'total': _totalDays,
              'accuracy': '${acc.toStringAsFixed(0)}%'},
          onDone: widget.onComplete,
        )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: Column(children: [
        // Header
        Container(color: _appGreen,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context)),
            Expanded(child: Text('🌤 Kenya Weather Station — Day $_day/$_totalDays',
                style: const TextStyle(color: Colors.white, fontSize: 14,
                    fontWeight: FontWeight.bold))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.amber.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('$_correct/$_totalDays ✅',
                  style: const TextStyle(color: Colors.amber,
                      fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
        // ── Flame sky canvas ──────────────────────────────────────────────
        SizedBox(height: 180, child: GameWidget.controlled(gameFactory: () => _game)),
        // Instruments
        _instruments(),
        // Observation
        _observation(),
        // Prediction / result
        Expanded(child: SingleChildScrollView(child: Column(children: [
          if (!_locked) _predictionRow(),
          if (_showResult) _resultCard(),
        ]))),
        // Controls
        Container(color: _appGreen,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Expanded(child: ElevatedButton.icon(
              onPressed: _evaluating ? null : _nextDay,
              icon: Icon(_day >= _totalDays && _locked ? Icons.flag : Icons.arrow_forward),
              label: Text(_day >= _totalDays && _locked ? '🏁 View Results'
                  : _locked ? '⏭ Next Day' : '⬆ Make Prediction First'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber, foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 12)),
            )),
            const SizedBox(width: 10),
            IconButton(icon: const Icon(Icons.help_outline, color: Colors.white),
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => TutorChatScreen(
                      topic: 'Weather & Climate', grade: '',
                      classId: widget.classId, isPrimary: false,
                      contextQuestion: 'Day $_day: Temp=${today.tempC.toStringAsFixed(0)}°C, '
                          'Humidity=${today.humidity}%, Barometer=${today.barometer}hPa. '
                          'What does this mean for crops?',
                      contextModule: 'weather_content', wrongAnswer: false,
                    )))),
          ]),
        ),
      ])),
    );
  }

  Widget _instruments() => Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Column(children: [
      Text('Day $_day — Read the clues to predict tomorrow!',
          style: TextStyle(color: _appGreen, fontWeight: FontWeight.bold, fontSize: 12)),
      const SizedBox(height: 8),
      Row(children: [
        _gauge('🌡️', '${today.tempC.toStringAsFixed(0)}°C', today.tempC / 40, Colors.orange),
        _gauge('💧', '${today.humidity}%', today.humidity / 100, Colors.blue),
        _gauge('💨', '${today.windKph.toStringAsFixed(0)}kph', today.windKph / 80, Colors.cyan),
        _gauge('☁️', '${today.cloudCover}%', today.cloudCover / 100, Colors.grey),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        const Text('📊 Barometer: ', style: TextStyle(fontSize: 11)),
        Text('${today.barometer} hPa', style: TextStyle(
            fontWeight: FontWeight.bold,
            color: today.barometer < 1005 ? Colors.red : Colors.green,
            fontSize: 11)),
        Text(today.barometer < 1005 ? ' ↘ Falling — storm likely!' : ' Stable',
            style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic)),
      ]),
    ]),
  );

  Widget _gauge(String icon, String val, double frac, Color color) =>
      Expanded(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(children: [
          Text(icon, style: const TextStyle(fontSize: 10)),
          const SizedBox(height: 3),
          Stack(alignment: Alignment.bottomCenter, children: [
            Container(width: 22, height: 55,
                decoration: BoxDecoration(color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(11))),
            AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              width: 22, height: (55 * frac.clamp(0, 1)),
              decoration: BoxDecoration(color: color,
                  borderRadius: BorderRadius.circular(11)),
            ),
          ]),
          const SizedBox(height: 3),
          Text(val, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
        ]),
      ));

  Widget _observation() => Container(
    margin: const EdgeInsets.all(10),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade200)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('👁️ ', style: TextStyle(fontSize: 16)),
      Expanded(child: Text(today.observation,
          style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic))),
    ]),
  );

  Widget _predictionRow() => Padding(
    padding: const EdgeInsets.all(10),
    child: Column(children: [
      const Text('🔮 Predict tomorrow\'s weather:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8,
          children: WxCondition.values.map((w) => GestureDetector(
            onTap: () => _predict(w),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.white,
                  border: Border.all(color: Colors.blue.shade300),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
              child: Text('${w.emoji} ${w.label}', style: const TextStyle(fontSize: 12)),
            ),
          )).toList()),
    ]),
  );

  Widget _resultCard() {
    final actual = today.condition;
    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _isCorrect ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _isCorrect ? Colors.green : Colors.orange, width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_isCorrect ? '✅ Correct!' : '❌ Not quite.',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                color: _isCorrect ? Colors.green : Colors.orange)),
        if (!_isCorrect) Text(
          'Predicted ${_prediction?.emoji} ${_prediction?.label}, '
              'actual ${actual.emoji} ${actual.label}.',
          style: const TextStyle(fontSize: 12)),
        const Divider(),
        Text('🌾 Farmer\'s advisory:',
            style: TextStyle(fontWeight: FontWeight.bold, color: _appGreen, fontSize: 12)),
        const SizedBox(height: 4),
        Text(actual.advice, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
      ]),
    );
  }
}