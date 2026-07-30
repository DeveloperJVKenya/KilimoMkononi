// lib/education/simulations/crop_crisis_simulation.dart
//
// FLAME ENGINE — CropCrisisSimulation (Play Screen)
//
// CrisisSceneGame (FlameGame)
//   ├── CrisisLandscapeComponent   — full-canvas scene that changes per stage
//   │     Drought:  cracked earth, scorching sun, wilting crops, heat haze shimmer
//   │     Flooding: rising water, storm clouds, lightning, submerged crop roots
//   │     Pest:     animated insect silhouettes crawling on crops, multiplying
//   │     Disease:  spreading dark patches on leaf surface, colony growth
//   │     Price:    stock-board style falling graph, market stall with empty shelves
//   │     Soil:     eroded earth, dusty particles, stunted crops
//   ├── ResourceMeterComponent×2   — Farm Health & Cash; animated bars
//   │     bars pulse red when < 30%
//   ├── StageTransitionComponent   — crossfade overlay between stages
//   │     plays a brief flash when transitioning (green=good, red=bad choice)
//   └── ParticleSystemComponent    — confetti/spark particles on correct decisions

import 'dart:convert';
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:http/http.dart' as http;
import 'package:kilimomkononi/education/tutor/tutor_chat_screen.dart';
import 'simulation_result_screen.dart';
import 'gemini_simulation_service.dart';

const Color _darkGreen = Color(0xFF032704);
const Color _crisis    = Color(0xFFB71C1C);
const String _geminiApiKey = 'AIzaSyDW-YIRD8p3cdveFgKG2o6KBEKWXP7mp7U';
const String _geminiBase   = 'https://generativelanguage.googleapis.com/v1beta/models';

// ── Data models (unchanged for compatibility) ────────────────────────────────
class CrisisScenario {
  final String title, cropName, county, challenge, background;
  final List<CrisisStage> stages;
  const CrisisScenario({required this.title, required this.cropName,
      required this.county, required this.challenge,
      required this.background, required this.stages});
  factory CrisisScenario.fromJson(Map<String, dynamic> j) => CrisisScenario(
    title: j['title'] as String? ?? 'Crop Crisis',
    cropName: j['cropName'] as String? ?? 'Maize',
    county: j['county'] as String? ?? 'Nakuru',
    challenge: j['challenge'] as String? ?? 'Drought',
    background: j['background'] as String? ?? '',
    stages: (j['stages'] as List? ?? [])
        .map((s) => CrisisStage.fromJson(s as Map<String, dynamic>)).toList(),
  );
}

class CrisisStage {
  final int stageNumber;
  final String situation, context;
  final List<CrisisOption> options;
  const CrisisStage({required this.stageNumber, required this.situation,
      required this.context, required this.options});
  factory CrisisStage.fromJson(Map<String, dynamic> j) => CrisisStage(
    stageNumber: (j['stageNumber'] as num?)?.toInt() ?? 1,
    situation: j['situation'] as String? ?? '',
    context: j['context'] as String? ?? '',
    options: (j['options'] as List? ?? [])
        .map((o) => CrisisOption.fromJson(o as Map<String, dynamic>)).toList(),
  );
}

class CrisisOption {
  final String id, label, description, impact, consequence;
  final int costKes;
  const CrisisOption({required this.id, required this.label,
      required this.description, required this.costKes,
      required this.impact, required this.consequence});
  factory CrisisOption.fromJson(Map<String, dynamic> j) => CrisisOption(
    id: j['id'] as String? ?? '',
    label: j['label'] as String? ?? '',
    description: j['description'] as String? ?? '',
    costKes: (j['costKes'] as num?)?.toInt() ?? 0,
    impact: j['impact'] as String? ?? 'neutral',
    consequence: j['consequence'] as String? ?? '',
  );
}

// ── Scenario generator ────────────────────────────────────────────────────────
Future<CrisisScenario?> generateCrisisScenario({
  required String cropName, required String county,
  required String challenge, required String grade,
}) async {
  final prompt = '''
You are a CBC Kenya Agricultural Education expert creating an interactive crop crisis simulation.
Generate a realistic 5-stage crop crisis scenario for:
- Crop: $cropName | County: $county, Kenya | Challenge type: $challenge | Grade: $grade
Rules: real Kenyan context, escalating crisis, 3 options per stage (best/acceptable/poor),
costs KES 500–15000, CBC strands, situation/context under 80 words, option description under 30 words.
Return ONLY JSON (no markdown):
{"title":"<title>","cropName":"$cropName","county":"$county","challenge":"$challenge",
"background":"<2-sentence intro>","stages":[{"stageNumber":1,"situation":"<1-2 sentences>",
"context":"<1 sentence>","options":[{"id":"A","label":"<action>","description":"<description>",
"costKes":<int>,"impact":"positive","consequence":"<result>"},
{"id":"B","label":"<action>","description":"<description>","costKes":<int>,"impact":"neutral","consequence":"<result>"},
{"id":"C","label":"<action>","description":"<description>","costKes":<int>,"impact":"negative","consequence":"<result>"}
]}]} (repeat stages 2-5)
''';
  try {
    final url = Uri.parse('$_geminiBase/gemini-2.5-flash:generateContent?key=$_geminiApiKey');
    final resp = await http.post(url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'contents': [{'parts': [{'text': prompt}]}],
            'generationConfig': {'temperature': 0.6, 'maxOutputTokens': 4096}}))
        .timeout(const Duration(seconds: 90));
    if (resp.statusCode != 200) return null;
    final body  = jsonDecode(resp.body) as Map<String, dynamic>;
    final parts = (body['candidates']?[0]?['content']?['parts'] as List?);
    if (parts == null || parts.isEmpty) return null;
    var raw = (parts[0] as Map)['text'] as String? ?? '';
    raw = raw.replaceAll(RegExp(r'```json\s*', multiLine: true), '')
             .replaceAll(RegExp(r'\s*```', multiLine: true), '').trim();
    final start = raw.indexOf('{'), end = raw.lastIndexOf('}');
    if (start == -1 || end == -1) return null;
    return CrisisScenario.fromJson(jsonDecode(raw.substring(start, end + 1)) as Map<String, dynamic>);
  } catch (e) { debugPrint('[CropCrisis] Error: $e'); return null; }
}

// ═══════════════════════════════════════════════════════════════════════════
//  CrisisLandscapeComponent — the main scene canvas
// ═══════════════════════════════════════════════════════════════════════════
class CrisisLandscapeComponent extends PositionComponent {
  String challenge;
  int    stageIdx;
  Color  skyColor;
  double farmHealth;
  double _t = 0;
  final Random _rng;

  CrisisLandscapeComponent({
    required this.challenge, required this.stageIdx,
    required this.skyColor, required this.farmHealth,
    required Vector2 size,
  }) : _rng = Random(stageIdx * 7 + challenge.length),
       super(size: size);

  @override void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    // Sky gradient
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..shader = LinearGradient(
            colors: [skyColor, skyColor.withValues(alpha: 0.5)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter)
            .createShader(Rect.fromLTWH(0, 0, size.x, size.y)));

    // Ground
    canvas.drawRect(Rect.fromLTWH(0, size.y * 0.65, size.x, size.y * 0.35),
        Paint()..color = farmHealth > 50
            ? const Color(0xFF4E342E) : const Color(0xFF3E2000));

    // Challenge-specific visuals
    switch (challenge) {
      case 'Drought':       _drawDrought(canvas); break;
      case 'Flooding':      _drawFlood(canvas);   break;
      case 'Pest Outbreak': _drawPests(canvas);   break;
      case 'Disease Epidemic': _drawDisease(canvas); break;
      case 'Price Crash':   _drawPriceCrash(canvas); break;
      default:              _drawGeneric(canvas);
    }

    // Crop row (health-scaled height, colour)
    final cropColor = Color.lerp(
        const Color(0xFF6D4C41), const Color(0xFF2E7D32), farmHealth / 100)!;
    final stemP = Paint()..color = cropColor..strokeWidth = 3;
    final leafP = Paint()..color = cropColor..strokeWidth = 2;
    for (double x = 16; x < size.x; x += 28) {
      final wilt = farmHealth < 40;
      final topY = wilt ? size.y * 0.62 : size.y * 0.32;
      canvas.drawLine(Offset(x, size.y * 0.65), Offset(x, topY), stemP);
      if (!wilt) {
        canvas.drawLine(Offset(x, size.y * 0.48), Offset(x + 14 + sin(_t + x) * 2, size.y * 0.44), leafP);
        canvas.drawLine(Offset(x, size.y * 0.48), Offset(x - 14 - sin(_t + x) * 2, size.y * 0.44), leafP);
      } else {
        canvas.drawLine(Offset(x, topY), Offset(x + 8, topY + 10), stemP..strokeWidth = 2);
      }
    }

    // Stage progress dots
    for (int i = 0; i < 5; i++) {
      canvas.drawCircle(
        Offset(size.x * 0.10 + i * size.x * 0.18, size.y * 0.08),
        6,
        Paint()..color = i < stageIdx ? Colors.greenAccent
            : i == stageIdx ? Colors.amber : Colors.white38,
      );
    }
    TextPaint(style: const TextStyle(fontSize: 9, color: Colors.white70))
        .render(canvas, 'Stage ${stageIdx + 1}/5', Vector2(size.x * 0.72, size.y * 0.04));
  }

  void _drawDrought(Canvas canvas) {
    // Scorching sun
    canvas.drawCircle(Offset(size.x * 0.85, size.y * 0.15), 22,
        Paint()..color = Colors.yellow.shade600);
    // Rays
    final rp = Paint()..color = Colors.yellow.shade300..strokeWidth = 2;
    for (int i = 0; i < 8; i++) {
      final a = (i / 8) * 2 * pi;
      canvas.drawLine(
        Offset(size.x * 0.85 + cos(a) * 26, size.y * 0.15 + sin(a) * 26),
        Offset(size.x * 0.85 + cos(a) * 38, size.y * 0.15 + sin(a) * 38), rp,
      );
    }
    // Cracked earth
    final cp = Paint()..color = const Color(0xFFBCAAA4)..strokeWidth = 1.5;
    for (int i = 0; i < 10 + stageIdx * 2; i++) {
      final x = _rng.nextDouble() * size.x;
      final y = size.y * 0.65 + _rng.nextDouble() * size.y * 0.3;
      canvas.drawLine(Offset(x, y),
          Offset(x + (_rng.nextDouble() - 0.5) * 40, y + _rng.nextDouble() * 20), cp);
    }
    // Heat shimmer
    for (double y = size.y * 0.30; y < size.y * 0.65; y += 10) {
      canvas.drawLine(Offset(0, y + sin(_t * 2 + y) * 1.5),
          Offset(size.x, y + cos(_t + y) * 1.5),
          Paint()..color = Colors.white.withValues(alpha: 0.04)..strokeWidth = 3);
    }
  }

  void _drawFlood(Canvas canvas) {
    // Water surface (rises with stage)
    final waterY = size.y * (0.62 - stageIdx * 0.04);
    canvas.drawRect(Rect.fromLTWH(0, waterY, size.x, size.y - waterY),
        Paint()..color = const Color(0xFF1565C0).withValues(alpha: 0.65));
    // Ripples
    for (double x = 0; x < size.x; x += 22) {
      canvas.drawArc(
        Rect.fromCenter(center: Offset(x + sin(_t + x) * 4, waterY + 5), width: 28, height: 8),
        0, pi, false,
        Paint()..color = Colors.lightBlue.shade200..strokeWidth = 1.5..style = PaintingStyle.stroke,
      );
    }
    // Storm clouds
    final cloudP = Paint()..color = const Color(0xFF546E7A);
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(Offset(size.x * (0.2 + i * 0.28), 25 + sin(_t + i) * 5), 22 + i * 4, cloudP);
    }
    // Lightning flash
    if (sin(_t * 3) > 0.85) {
      final lp = Paint()..color = Colors.yellow..strokeWidth = 2.5;
      canvas.drawLine(Offset(size.x * 0.5, 15), Offset(size.x * 0.46, 65), lp);
      canvas.drawLine(Offset(size.x * 0.46, 65), Offset(size.x * 0.54, 115), lp);
    }
  }

  void _drawPests(Canvas canvas) {
    final count = 8 + stageIdx * 4;
    for (int i = 0; i < count; i++) {
      final x = ((_t * 18 * (i % 3 + 1) * 0.4 + i * 40) % (size.x + 30)) - 15;
      final y = size.y * 0.3 + (i % 5) * size.y * 0.08;
      // Body
      canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 10, height: 6),
          Paint()..color = Colors.brown.shade800);
      // Antennae
      final ap = Paint()..color = Colors.brown.shade600..strokeWidth = 1;
      canvas.drawLine(Offset(x - 2, y - 3), Offset(x - 6, y - 8), ap);
      canvas.drawLine(Offset(x + 2, y - 3), Offset(x + 6, y - 8), ap);
      // Legs
      canvas.drawLine(Offset(x - 3, y), Offset(x - 7, y + 4), ap);
      canvas.drawLine(Offset(x + 3, y), Offset(x + 7, y + 4), ap);
    }
  }

  void _drawDisease(Canvas canvas) {
    final severity = (stageIdx + 1) / 5.0;
    for (int i = 0; i < (10 * severity).toInt() + 4; i++) {
      final x = _rng.nextDouble() * size.x;
      final y = size.y * 0.28 + _rng.nextDouble() * size.y * 0.42;
      final r = 6.0 + _rng.nextDouble() * 14;
      canvas.drawCircle(Offset(x, y), r,
          Paint()..color = Color.lerp(Colors.yellow.shade700,
              Colors.brown.shade900, severity)!.withValues(alpha: 0.65));
      canvas.drawCircle(Offset(x, y), r * 0.4,
          Paint()..color = Colors.brown.shade900.withValues(alpha: 0.5));
    }
  }

  void _drawPriceCrash(Canvas canvas) {
    // Descending price graph
    final gp = Paint()..color = Colors.red.shade400..strokeWidth = 2.5..style = PaintingStyle.stroke;
    final path = Path()..moveTo(8, size.y * 0.12);
    double y = size.y * 0.12;
    for (double x = 8; x < size.x - 8; x += 16) {
      y = (y + 6 + _rng.nextDouble() * 10).clamp(0, size.y * 0.62);
      path.lineTo(x, y);
    }
    canvas.drawPath(path, gp);
    // Down arrow
    final ap = Paint()..color = Colors.red..strokeWidth = 4;
    canvas.drawLine(Offset(size.x * 0.78, size.y * 0.12),
        Offset(size.x * 0.78, size.y * 0.6), ap);
    canvas.drawLine(Offset(size.x * 0.78, size.y * 0.6),
        Offset(size.x * 0.72, size.y * 0.5), ap);
    canvas.drawLine(Offset(size.x * 0.78, size.y * 0.6),
        Offset(size.x * 0.84, size.y * 0.5), ap);
    TextPaint(style: const TextStyle(fontSize: 14, color: Colors.red,
        fontWeight: FontWeight.bold))
        .render(canvas, '📉', Vector2(size.x * 0.68, size.y * 0.04));
  }

  void _drawGeneric(Canvas canvas) {
    // Warning triangle
    final path = Path()
      ..moveTo(size.x * 0.5, size.y * 0.08)
      ..lineTo(size.x * 0.35, size.y * 0.52)
      ..lineTo(size.x * 0.65, size.y * 0.52)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.orange.withValues(alpha: 0.45));
    canvas.drawPath(path, Paint()
        ..color = Colors.orange..style = PaintingStyle.stroke..strokeWidth = 2);
    TextPaint(style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
        color: Colors.orange))
        .render(canvas, '!', Vector2(size.x * 0.485, size.y * 0.26));
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  ResourceMeterComponent
// ═══════════════════════════════════════════════════════════════════════════
class ResourceMeterComponent extends PositionComponent {
  double value; // 0–1
  final String label;
  final Color color;
  double _t = 0;

  ResourceMeterComponent({required this.value, required this.label,
      required this.color, required Vector2 position, required Vector2 size})
      : super(position: position, size: size);

  @override void update(double dt) => _t += dt * 3;

  @override
  void render(Canvas canvas) {
    // Track
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 8, size.x, 10), const Radius.circular(5)),
        Paint()..color = Colors.white24);
    // Fill
    final pulseColor = value < 0.3
        ? Color.lerp(color, Colors.red, (sin(_t) * 0.5 + 0.5))! : color;
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 8, size.x * value.clamp(0, 1), 10), const Radius.circular(5)),
        Paint()..color = pulseColor);
    // Label
    TextPaint(style: const TextStyle(fontSize: 8, color: Colors.white70))
        .render(canvas, label, Vector2(0, 0));
    TextPaint(style: TextStyle(fontSize: 8, color: pulseColor, fontWeight: FontWeight.bold))
        .render(canvas, '${(value * 100).toInt()}%', Vector2(size.x - 26, 0));
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  CrisisSceneGame
// ═══════════════════════════════════════════════════════════════════════════
class CrisisSceneGame extends FlameGame {
  String challenge;
  int    stageIdx;
  double farmHealth;
  double cashKes;

  late CrisisLandscapeComponent landscape;
  late ResourceMeterComponent healthMeter;
  late ResourceMeterComponent cashMeter;

  static const _stageSkies = [
    Color(0xFF87CEEB), Color(0xFFFFB347),
    Color(0xFFFF7043), Color(0xFF546E7A), Color(0xFF37474F),
  ];

  CrisisSceneGame({required this.challenge, required this.stageIdx,
      required this.farmHealth, required this.cashKes});

  @override
  Future<void> onLoad() async {
    landscape = CrisisLandscapeComponent(
      challenge: challenge, stageIdx: stageIdx,
      skyColor: _stageSkies[stageIdx.clamp(0, 4)],
      farmHealth: farmHealth,
      size: Vector2(size.x, size.y * 0.72),
    );
    add(landscape);

    healthMeter = ResourceMeterComponent(
      value: farmHealth / 100, label: '❤️ Farm Health',
      color: Colors.greenAccent,
      position: Vector2(12, size.y * 0.74),
      size: Vector2(size.x / 2 - 18, 20),
    );
    add(healthMeter);

    cashMeter = ResourceMeterComponent(
      value: (cashKes / 30000).clamp(0, 1), label: '💰 Cash',
      color: Colors.amber,
      position: Vector2(size.x / 2 + 6, size.y * 0.74),
      size: Vector2(size.x / 2 - 18, 20),
    );
    add(cashMeter);
  }

  void updateState({
    required int stage, required double health,
    required double cash, required String challengeType,
  }) {
    stageIdx  = stage;
    farmHealth = health;
    cashKes    = cash;
    challenge  = challengeType;
    landscape.stageIdx   = stage;
    landscape.farmHealth = health;
    landscape.challenge  = challengeType;
    landscape.skyColor   = _stageSkies[stage.clamp(0, 4)];
    healthMeter.value    = (health / 100).clamp(0, 1);
    cashMeter.value      = (cash / 30000).clamp(0, 1);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  CropCrisisSetupScreen
// ═══════════════════════════════════════════════════════════════════════════
class CropCrisisSetupScreen extends StatefulWidget {
  final String classId, schoolName;
  const CropCrisisSetupScreen({super.key, required this.classId, required this.schoolName});
  @override State<CropCrisisSetupScreen> createState() => _CropCrisisSetupScreenState();
}

class _CropCrisisSetupScreenState extends State<CropCrisisSetupScreen>
    with SingleTickerProviderStateMixin {
  String _crop = 'Maize', _county = 'Nakuru', _challenge = 'Drought';
  bool _generating = false;

  static const _crops = ['Maize','Beans','Tomatoes','Potatoes','Cabbage','Tea','Coffee','Sugarcane','Wheat','Millet'];
  static const _counties = ['Nakuru','Kisumu','Meru','Machakos','Eldoret','Kakamega','Nyeri','Embu','Kitui','Bungoma'];
  static const _challenges = ['Drought','Pest Outbreak','Disease Epidemic','Price Crash','Flooding','Soil Degradation'];
  static const _challengeIcons = {
    'Drought':'☀️','Pest Outbreak':'🐛','Disease Epidemic':'🍂',
    'Price Crash':'📉','Flooding':'🌊','Soil Degradation':'🏜️'
  };

  late AnimationController _warnCtrl;

  @override
  void initState() { super.initState();
    _warnCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  }
  @override void dispose() { _warnCtrl.dispose(); super.dispose(); }

  Future<void> _generate() async {
    setState(() => _generating = true);
    final scenario = await generateCrisisScenario(
        cropName: _crop, county: _county, challenge: _challenge, grade: widget.classId);
    if (!mounted) return;
    setState(() => _generating = false);
    if (scenario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate scenario. Try again.'),
              backgroundColor: Colors.red));
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) =>
        CropCrisisPlayScreen(scenario: scenario, classId: widget.classId, schoolName: widget.schoolName)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7),
      appBar: AppBar(title: const Text('⚠️ Crop Crisis Simulation'),
          backgroundColor: _darkGreen, foregroundColor: Colors.white),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child:
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Container(padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF032704), Color(0xFFB71C1C)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('🤖 AI-Generated Crisis Story', style: TextStyle(
                  color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text('Gemini creates a unique 5-stage crisis rooted in Kenyan agriculture. '
                  'Each run is different. Your decisions change the outcome.',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5)),
            ])),
          const SizedBox(height: 20),
          _label('🌾 Crop'), _chips(_crops, _crop, Colors.green, (v) => setState(() => _crop = v)),
          const SizedBox(height: 16),
          _label('📍 County'), _chips(_counties, _county, Colors.blue, (v) => setState(() => _county = v)),
          const SizedBox(height: 16),
          _label('🚨 Crisis Type'),
          Wrap(spacing: 8, runSpacing: 8, children: _challenges.map((c) =>
            _chip('${_challengeIcons[c]} $c', _challenge == c, Colors.deepOrange,
                () => setState(() => _challenge = c), big: true)).toList()),
          const SizedBox(height: 24),
          // Preview
          Container(padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF388E3C)]),
              borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Text(_challengeIcons[_challenge] ?? '⚠️', style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$_challenge Crisis — $_county',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                Text('Crop: $_crop | 5-stage AI scenario',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ])),
            ])),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: _generating ? null : _generate,
            icon: _generating
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.auto_awesome, color: Colors.amber),
            label: Text(_generating ? 'Generating crisis story…' : '🎮 Generate & Play',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _generating ? Colors.grey : _crisis, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          )),
          const SizedBox(height: 8),
          Center(child: Text('⏱ ~15 seconds to generate',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500))),
        ]),
      ),
    );
  }

  Widget _label(String t) => Padding(padding: const EdgeInsets.only(bottom: 8),
      child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)));
  Widget _chips(List<String> items, String sel, Color color, void Function(String) onTap) =>
      Wrap(spacing: 8, runSpacing: 8,
          children: items.map((c) => _chip(c, sel == c, color, () => onTap(c))).toList());
  Widget _chip(String label, bool selected, Color color, VoidCallback onTap, {bool big = false}) =>
      GestureDetector(onTap: onTap, child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: big ? 14 : 12, vertical: big ? 10 : 7),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : color.withValues(alpha: 0.3),
              width: selected ? 2 : 1),
          boxShadow: selected ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 7)] : null),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : color,
            fontSize: big ? 13 : 12, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      ));
}

// ═══════════════════════════════════════════════════════════════════════════
//  CropCrisisPlayScreen
// ═══════════════════════════════════════════════════════════════════════════
class CropCrisisPlayScreen extends StatefulWidget {
  final CrisisScenario scenario;
  final String classId, schoolName;
  const CropCrisisPlayScreen({super.key, required this.scenario,
      required this.classId, required this.schoolName});
  @override State<CropCrisisPlayScreen> createState() => _CropCrisisPlayScreenState();
}

class _CropCrisisPlayScreenState extends State<CropCrisisPlayScreen>
    with SingleTickerProviderStateMixin {
  int     _stageIdx     = 0;
  String? _selectedId;
  bool    _revealed     = false;
  bool    _evaluating   = false;

  double _farmHealth    = 80.0;
  double _cashKes       = 30000.0;
  int    _posStreak     = 0;

  late CrisisSceneGame _game;
  late ConfettiController _confetti;
  late AnimationController _slideAnim;
  final List<Map<String, dynamic>> _decisions = [];
  final Random _rng = Random();

  CrisisStage get _stage  => widget.scenario.stages[_stageIdx];
  bool get _isLast        => _stageIdx >= widget.scenario.stages.length - 1;

  @override
  void initState() {
    super.initState();
    _confetti  = ConfettiController(duration: const Duration(seconds: 3));
    _slideAnim = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 450));
    _game = CrisisSceneGame(
      challenge: widget.scenario.challenge, stageIdx: 0,
      farmHealth: _farmHealth, cashKes: _cashKes,
    );
    _slideAnim.forward();
  }

  @override void dispose() { _confetti.dispose(); _slideAnim.dispose(); super.dispose(); }

  void _select(String id) { if (!_revealed) setState(() => _selectedId = id); }

  void _confirm() {
    if (_selectedId == null) return;
    final opt = _stage.options.firstWhere((o) => o.id == _selectedId);
    double healthDelta = 0;
    switch (opt.impact) {
      case 'positive': healthDelta = 6 + _rng.nextDouble() * 4; _posStreak++; break;
      case 'neutral':  healthDelta = 0; _posStreak = 0; break;
      case 'negative': healthDelta = -(8 + _rng.nextDouble() * 6); _posStreak = 0; break;
    }
    setState(() {
      _revealed    = true;
      _farmHealth  = (_farmHealth + healthDelta).clamp(0, 100);
      _cashKes     = (_cashKes - opt.costKes).clamp(0, 200000);
      _decisions.add({'stage': _stage.stageNumber, 'situation': _stage.situation,
          'chosenId': opt.id, 'chosenLabel': opt.label,
          'impact': opt.impact, 'costKes': opt.costKes, 'consequence': opt.consequence});
      _game.updateState(stage: _stageIdx, health: _farmHealth,
          cash: _cashKes, challengeType: widget.scenario.challenge);
    });
    if (opt.impact == 'positive' && _posStreak >= 3) _confetti.play();
  }

  Future<void> _next() async {
    if (_isLast) { await _finish(); return; }
    _slideAnim.reset();
    setState(() {
      _stageIdx++;
      _selectedId = null;
      _revealed   = false;
    });
    _game.updateState(stage: _stageIdx, health: _farmHealth,
        cash: _cashKes, challengeType: widget.scenario.challenge);
    _slideAnim.forward();
  }

  Future<void> _finish() async {
    setState(() => _evaluating = true);
    final posCount = _decisions.where((d) => d['impact'] == 'positive').length;
    final negCount = _decisions.where((d) => d['impact'] == 'negative').length;
    final totalCost = _decisions.fold<int>(0, (s, d) => s + (d['costKes'] as int));
    final rawScore  = (posCount / _decisions.length * 100).round();
    final decLog    = _decisions.map((d) =>
        'Stage ${d['stage']}: "${d['chosenLabel']}" (${d['impact']}) — ${d['consequence']}').toList();

    final feedback = await _evaluateCrisisScenario(
      scenario: widget.scenario, decisions: _decisions,
      positiveCount: posCount, negativeCount: negCount,
      totalCostKes: totalCost, rawScore: rawScore,
    );
    if (!mounted) return;
    setState(() => _evaluating = false);
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) =>
        SimulationResultScreen(
          classId: widget.classId, module: 'Crop Crisis',
          simulationTitle: widget.scenario.title,
          feedback: feedback, fallbackScore: rawScore,
          decisionLog: decLog,
          summaryData: {'crop': widget.scenario.cropName, 'county': widget.scenario.county,
              'challenge': widget.scenario.challenge, 'positiveChoices': posCount,
              'negativeChoices': negCount, 'totalCostKes': totalCost,
              'finalFarmHealth': _farmHealth.toInt(), 'finalCash': _cashKes.toInt()},
          onDone: () => Navigator.of(context).popUntil((r) => r.isFirst),
        )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBE7),
      body: Stack(children: [
        Align(alignment: Alignment.topCenter,
            child: ConfettiWidget(confettiController: _confetti,
                blastDirectionality: BlastDirectionality.explosive,
                colors: const [Colors.amber, Colors.green, Colors.white],
                numberOfParticles: 25)),
        SafeArea(child: Column(children: [
          // Header
          Container(color: _darkGreen,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context)),
              Expanded(child: Text(widget.scenario.title,
                  style: const TextStyle(color: Colors.white, fontSize: 13,
                      fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.deepOrange.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.deepOrange.shade300)),
                child: Text(widget.scenario.challenge,
                    style: const TextStyle(color: Colors.white, fontSize: 10,
                        fontWeight: FontWeight.bold))),
            ]),
          ),
          // ── Flame scene canvas ────────────────────────────────────────
          SizedBox(height: 200, child: GameWidget.controlled(gameFactory: () => _game)),
          // Stage + situation
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              // Situation card
              Card(elevation: 3, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(padding: const EdgeInsets.all(14), child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: _darkGreen, borderRadius: BorderRadius.circular(8)),
                          child: Text('Stage ${_stageIdx + 1}/${widget.scenario.stages.length}',
                              style: const TextStyle(color: Colors.white, fontSize: 11))),
                    ]),
                    const SizedBox(height: 8),
                    Text(_stage.situation, style: const TextStyle(fontSize: 14, height: 1.5)),
                    if (_stage.context.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8)),
                          child: Row(children: [
                            Icon(Icons.info_outline, size: 13, color: Colors.blue.shade700),
                            const SizedBox(width: 6),
                            Expanded(child: Text(_stage.context,
                                style: TextStyle(fontSize: 11, color: Colors.blue.shade800,
                                    fontStyle: FontStyle.italic))),
                          ])),
                    ],
                  ]))),
              const SizedBox(height: 10),
              const Align(alignment: Alignment.centerLeft,
                  child: Text('What will you do?',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
              const SizedBox(height: 8),
              // Options
              SlideTransition(
                position: Tween<Offset>(begin: const Offset(0.3, 0), end: Offset.zero)
                    .animate(CurvedAnimation(parent: _slideAnim, curve: Curves.easeOut)),
                child: Column(children: _stage.options.map((opt) {
                  final isSel = _selectedId == opt.id;
                  Color bg = Colors.white;
                  if (_revealed) {
                    bg = opt.impact == 'positive' ? Colors.green.shade50
                        : opt.impact == 'negative' ? Colors.red.shade50 : Colors.orange.shade50;
                  } else if (isSel) { bg = Colors.blue.shade50; }
                  return GestureDetector(
                    onTap: _revealed ? null : () => _select(opt.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: bg, borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _revealed
                              ? (opt.impact == 'positive' ? Colors.green.shade300
                                  : opt.impact == 'negative' ? Colors.red.shade300 : Colors.orange.shade300)
                              : isSel ? Colors.blue.shade400 : Colors.grey.shade300,
                          width: isSel || _revealed ? 2 : 1),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          CircleAvatar(radius: 12,
                              backgroundColor: _revealed
                                  ? (opt.impact == 'positive' ? Colors.green
                                      : opt.impact == 'negative' ? Colors.red : Colors.orange)
                                  : isSel ? Colors.blue : Colors.grey.shade400,
                              child: Text(opt.id, style: const TextStyle(color: Colors.white,
                                  fontSize: 11, fontWeight: FontWeight.bold))),
                          const SizedBox(width: 10),
                          Expanded(child: Text(opt.label, style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13))),
                          if (opt.costKes > 0) Text('KES ${opt.costKes}',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                          if (_revealed) ...[
                            const SizedBox(width: 6),
                            Icon(opt.impact == 'positive' ? Icons.check_circle
                                : opt.impact == 'negative' ? Icons.cancel : Icons.info,
                                size: 16,
                                color: opt.impact == 'positive' ? Colors.green
                                    : opt.impact == 'negative' ? Colors.red : Colors.orange),
                          ],
                        ]),
                        const SizedBox(height: 4),
                        Text(opt.description, style: const TextStyle(fontSize: 12, height: 1.4)),
                        if (_revealed && opt.id == _selectedId) ...[
                          const SizedBox(height: 6),
                          Container(padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: opt.impact == 'positive' ? Colors.green.shade100
                                    : opt.impact == 'negative' ? Colors.red.shade100 : Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(8)),
                              child: Text(opt.consequence, style: TextStyle(fontSize: 12, height: 1.4,
                                  color: opt.impact == 'positive' ? Colors.green.shade800
                                      : opt.impact == 'negative' ? Colors.red.shade800 : Colors.orange.shade800))),
                        ],
                      ]),
                    ),
                  );
                }).toList()),
              ),
              const SizedBox(height: 10),
              if (!_revealed)
                SizedBox(width: double.infinity, child: ElevatedButton(
                  onPressed: _selectedId != null ? _confirm : null,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _darkGreen, foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: Text(_selectedId == null ? 'Select an option above' : '✅ Confirm Decision',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ))
              else
                Column(children: [
                  SizedBox(width: double.infinity, child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => TutorChatScreen(
                          topic: 'Crop Crisis Management', grade: '',
                          classId: widget.classId, isPrimary: false,
                          contextQuestion: '${widget.scenario.title}. Stage ${_stageIdx + 1}: '
                              '${_stage.situation}. I chose "${_decisions.last['chosenLabel']}".',
                          contextModule: 'farming_content',
                          wrongAnswer: _decisions.last['impact'] == 'negative',
                        ))),
                    icon: const Icon(Icons.psychology_outlined, size: 18),
                    label: const Text('Ask Shamba AI to explain this'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: _darkGreen,
                        side: const BorderSide(color: _darkGreen),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  )),
                  const SizedBox(height: 8),
                  SizedBox(width: double.infinity, child: ElevatedButton.icon(
                    onPressed: _evaluating ? null : _next,
                    icon: Icon(_isLast ? Icons.analytics : Icons.arrow_forward),
                    label: Text(_isLast ? '📊 Get AI Feedback' : 'Next Stage →',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _isLast ? Colors.deepOrange : _darkGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  )),
                  if (_posStreak >= 3)
                    Container(margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFFF8F00), Color(0xFFFFCA28)]),
                          borderRadius: BorderRadius.circular(20)),
                        child: Text('🏆 Crisis Expert! $_posStreak correct in a row!',
                            style: const TextStyle(color: Colors.white,
                                fontWeight: FontWeight.bold))),
                ],
                ),
              const SizedBox(height: 20),
            ]),
          )),
        ])),
        if (_evaluating)
          Container(color: Colors.black54, child: Center(child:
            Column(mainAxisSize: MainAxisSize.min, children: const [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 14),
              Text('Shamba AI is analysing your decisions…',
                  style: TextStyle(color: Colors.white, fontSize: 15)),
            ]))),
      ]),
    );
  }
}

// ── Gemini evaluator ──────────────────────────────────────────────────────────
Future<SimulationFeedback?> _evaluateCrisisScenario({
  required CrisisScenario scenario, required List<Map<String, dynamic>> decisions,
  required int positiveCount, required int negativeCount,
  required int totalCostKes, required int rawScore,
}) async {
  final summary = decisions.map((d) =>
      'Stage ${d['stage']}: "${d['chosenLabel']}" (${d['impact']}) — ${d['consequence']}').join('\n');
  final prompt = '''
CBC Kenya agricultural expert evaluating crop crisis simulation.
Scenario: ${scenario.title} | ${scenario.cropName} | ${scenario.county} | ${scenario.challenge}
Decisions:\n$summary
$positiveCount positive, $negativeCount negative. Cost: KES $totalCostKes. Score: $rawScore/100
Return ONLY JSON: {"score":<0-100>,"maxScore":100,"grade":"Excellent|Good|Satisfactory|Needs Work",
"summary":"<2-3 sentences>","strengths":["<s1>","<s2>"],"improvements":["<i1>","<i2>"],
"hint":"<1 sentence max 20 words>","cbcStrand":"Crop Production"}
''';
  try {
    final url = Uri.parse('$_geminiBase/gemini-2.5-flash:generateContent?key=$_geminiApiKey');
    final resp = await http.post(url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'contents': [{'parts': [{'text': prompt}]}],
            'generationConfig': {'temperature': 0.2, 'maxOutputTokens': 1024}}))
        .timeout(const Duration(seconds: 60));
    if (resp.statusCode != 200) return null;
    final body  = jsonDecode(resp.body) as Map<String, dynamic>;
    final parts = (body['candidates']?[0]?['content']?['parts'] as List?);
    if (parts == null || parts.isEmpty) return null;
    var raw = (parts[0] as Map)['text'] as String? ?? '';
    raw = raw.replaceAll(RegExp(r'```json\s*', multiLine: true), '')
             .replaceAll(RegExp(r'\s*```', multiLine: true), '').trim();
    final start = raw.indexOf('{'), end = raw.lastIndexOf('}');
    if (start == -1 || end == -1) return null;
    return SimulationFeedback.fromJson(jsonDecode(raw.substring(start, end + 1)) as Map<String, dynamic>);
  } catch (e) { debugPrint('[CropCrisis] Eval error: $e'); return null; }
}