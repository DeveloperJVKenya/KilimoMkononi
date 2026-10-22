// lib/widgets/soil_sensor_card.dart
//
// The station's soil sensor on the Weather Station screen: moisture (% VWC),
// temperature (°C) and EC (µS/cm) per probe — the latest reading, the last
// 24 h range and change, and a small 24 h line. Values exactly as recorded
// (SoilSensorService); nothing is interpreted or estimated here.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kilimomkononi/services/soil_sensor_service.dart';
import 'package:kilimomkononi/widgets/fluid_grid.dart';

class _C {
  static const green = Color(0xFF2A6B2A);
  static const lightGreen = Color(0xFFE8F5E9);
  static const amber = Color(0xFFE65100);
  static const lightAmber = Color(0xFFFFF8E1);
  static const border = Color(0xFFE0E4DF);
  static const soil = Color(0xFF6D4C41);
}

Color _metricColor(SoilMetric m) => switch (m) {
      SoilMetric.moisture => const Color(0xFF1565C0),
      SoilMetric.temperature => const Color(0xFFC62828),
      SoilMetric.ec => const Color(0xFF6A1B9A),
    };

IconData _metricIcon(SoilMetric m) => switch (m) {
      SoilMetric.moisture => Icons.water_drop_rounded,
      SoilMetric.temperature => Icons.thermostat_rounded,
      SoilMetric.ec => Icons.bolt_rounded,
    };

String _ago(DateTime t, DateTime now) {
  final d = now.difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 48) return '${d.inHours} h ago';
  return '${d.inDays} days ago';
}

class SoilSensorCard extends StatelessWidget {
  final SoilSensorData data;

  /// The admin confirmed a soil sensor on this station.
  final bool confirmed;

  /// For tests; defaults to now.
  final DateTime? now;

  const SoilSensorCard({super.key, required this.data, this.confirmed = false, this.now});

  @override
  Widget build(BuildContext context) {
    final clock = now ?? DateTime.now();
    final last = data.lastReading;
    final live = data.isLive;
    final multi = data.probes.length > 1;

    final String status;
    if (data.failed) {
      status = 'Couldn\'t load the soil readings · pull down to refresh';
    } else if (last == null) {
      status = 'No soil readings yet';
    } else if (live) {
      status = 'Live · updated ${_ago(last, clock)}';
    } else {
      status = 'Not reporting · last reading ${_ago(last, clock)}';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: _C.soil.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: const Icon(Icons.grass_rounded, size: 18, color: _C.soil),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Soil sensor',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _StatusLine(text: status, ok: live && !data.failed),
          if (!data.failed && !data.hasReadings) ...[
            const SizedBox(height: 10),
            Text(
              confirmed
                  ? 'This station has a soil sensor, but it hasn\'t sent any readings yet. '
                      'Check that the probe is in the ground and connected, then pull down to refresh.'
                  : 'No soil readings from this station.',
              style: const TextStyle(fontSize: 12.5, height: 1.4),
            ),
          ],
          for (final probe in data.probes)
            if (probe.metrics.isNotEmpty) ...[
              const SizedBox(height: 12),
              if (multi)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(probe.label.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black54, letterSpacing: 0.5)),
                ),
              FluidGrid.builder(
                itemCount: probe.metrics.length,
                minTileWidth: 150,
                maxColumns: 3,
                spacing: 8,
                runSpacing: 8,
                itemBuilder: (_, i) => _MetricTile(probe: probe, metric: probe.metrics[i]),
              ),
            ],
          if (data.hasReadings) ...[
            const SizedBox(height: 10),
            Text(
              '${multi ? '${data.probes.length} probes' : 'Probe 1'} at this station · '
              'moisture = water in the soil (% of its volume, VWC) · '
              'EC = dissolved salts and nutrients · values as recorded',
              style: const TextStyle(fontSize: 11, color: Colors.black54, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  final String text;
  final bool ok;
  const _StatusLine({required this.text, required this.ok});

  @override
  Widget build(BuildContext context) {
    final color = ok ? _C.green : _C.amber;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ok ? _C.lightGreen : _C.lightAmber,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(ok ? Icons.sensors_rounded : Icons.access_time_rounded, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final SoilProbe probe;
  final SoilMetric metric;
  const _MetricTile({required this.probe, required this.metric});

  @override
  Widget build(BuildContext context) {
    final color = _metricColor(metric);
    final now = probe.current(metric);
    final range = probe.range24h(metric);
    final change = probe.change24h(metric);
    final pts = probe.history[metric] ?? const <SoilPoint>[];
    final d = metric.decimals;

    String? changeText;
    if (change != null) {
      final step = math.pow(10, -d) / 2;
      changeText = change.abs() < step
          ? 'steady over 24 h'
          : '${change > 0 ? 'up' : 'down'} ${change.abs().toStringAsFixed(d)} over 24 h';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_metricIcon(metric), size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(metric.label,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.black54)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(children: [
              TextSpan(
                text: now == null ? '—' : now.value.toStringAsFixed(d),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color),
              ),
              TextSpan(
                text: ' ${metric.unit}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54),
              ),
            ]),
          ),
          if (range != null)
            Text('24 h: ${range.min.toStringAsFixed(d)} – ${range.max.toStringAsFixed(d)}',
                style: const TextStyle(fontSize: 11, color: Colors.black54)),
          if (changeText != null)
            Text(changeText, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          if (pts.length >= 2) ...[
            const SizedBox(height: 6),
            SizedBox(
              height: 28,
              width: double.infinity,
              child: CustomPaint(painter: _Sparkline(pts.map((p) => p.value).toList(), color)),
            ),
          ],
        ],
      ),
    );
  }
}

class _Sparkline extends CustomPainter {
  final List<double> values;
  final Color color;
  _Sparkline(this.values, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final lo = values.reduce(math.min), hi = values.reduce(math.max);
    final span = hi - lo == 0 ? 1.0 : hi - lo;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - 2 - (size.height - 4) * (values[i] - lo) / span;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_Sparkline old) => old.values != values || old.color != color;
}
