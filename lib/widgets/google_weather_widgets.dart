// lib/widgets/google_weather_widgets.dart
//
// UI for Google Weather data (lib/services/google_weather_service.dart), shared
// by the Weather screen and the Weather Station screen, plus the source badges
// that keep the two data sources apart for farmers:
//   • WeatherSource.station — measured on the farm by its NuaSense station.
//     Verified advice and alerts come from this.
//   • WeatherSource.google  — Google's forecast for the area (model data).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kilimomkononi/services/google_weather_service.dart';

enum WeatherSource { station, google }

class _Palette {
  static const stationFg = Color(0xFF1B5E20);
  static const stationBg = Color(0xFFE8F5E9);
  static const googleFg = Color(0xFF0D47A1);
  static const googleBg = Color(0xFFE3F2FD);
  static const border = Color(0xFFE0E0E0);
  static const muted = Colors.black54;
}

/// "Weather station · measured on your farm" / "Google Weather · area forecast".
class WeatherSourceBadge extends StatelessWidget {
  final WeatherSource source;
  final bool compact;
  const WeatherSourceBadge(this.source, {super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final station = source == WeatherSource.station;
    final fg = station ? _Palette.stationFg : _Palette.googleFg;
    final text = station
        ? (compact ? 'Your station' : 'Weather station · measured on your farm')
        : (compact ? 'Google forecast' : 'Google Weather · area forecast');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: station ? _Palette.stationBg : _Palette.googleBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(station ? Icons.sensors_rounded : Icons.cloud_outlined, size: 13, color: fg),
        const SizedBox(width: 4),
        Flexible(
          child: Text(text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
        ),
      ]),
    );
  }
}

/// Google's condition icon, with a Material fallback if it can't load.
class GoogleWeatherIcon extends StatelessWidget {
  final GoogleCondition condition;
  final double size;
  const GoogleWeatherIcon(this.condition, {super.key, this.size = 36});

  static IconData fallback(String bucket) => switch (bucket) {
        'storm' => Icons.thunderstorm_rounded,
        'rain' => Icons.grain_rounded,
        'snow' => Icons.ac_unit_rounded,
        'fog' => Icons.foggy,
        'wind' => Icons.air_rounded,
        'clouds' => Icons.cloud_rounded,
        'clear' => Icons.wb_sunny_rounded,
        _ => Icons.wb_cloudy_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final icon = Icon(fallback(condition.bucket), size: size * 0.8, color: _Palette.googleFg);
    final url = condition.iconUrl();
    if (url == null) return SizedBox(width: size, height: size, child: Center(child: icon));
    return Image.network(
      url,
      width: size,
      height: size,
      errorBuilder: (_, _, _) => SizedBox(width: size, height: size, child: Center(child: icon)),
    );
  }
}

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}

Widget _metric(IconData icon, String label, String value) => SizedBox(
      width: 96,
      child: Row(children: [
        Icon(icon, size: 16, color: _Palette.googleFg),
        const SizedBox(width: 5),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            Text(label, style: const TextStyle(fontSize: 10.5, color: _Palette.muted)),
          ]),
        ),
      ]),
    );

BoxDecoration _card() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _Palette.border),
    );

/// Current conditions from Google for [place].
class GoogleCurrentCard extends StatelessWidget {
  final GoogleWeather weather;
  final String place;
  const GoogleCurrentCard({super.key, required this.weather, required this.place});

  @override
  Widget build(BuildContext context) {
    final c = weather.current;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: WeatherSourceBadge(WeatherSource.google)),
          Text(
            weather.fromCache ? 'Saved ${_ago(weather.fetchedAt)}' : 'Updated ${_ago(weather.fetchedAt)}',
            style: TextStyle(
                fontSize: 11,
                color: weather.fromCache ? const Color(0xFFE65100) : _Palette.muted),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.place_outlined, size: 16, color: _Palette.muted),
          const SizedBox(width: 4),
          Expanded(
            child: Text(place,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          GoogleWeatherIcon(c.condition, size: 56),
          const SizedBox(width: 12),
          Text('${c.temp.round()}°C',
              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, height: 1)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.condition.description.isEmpty ? '—' : c.condition.description,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              Text('Feels like ${c.feelsLike.round()}°C',
                  style: const TextStyle(fontSize: 12, color: _Palette.muted)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 10, children: [
          _metric(Icons.umbrella_rounded, 'Rain chance', '${c.rainChance}%'),
          _metric(Icons.water_drop_outlined, 'Humidity', '${c.humidity}%'),
          _metric(Icons.air_rounded, 'Wind${c.windDirection.isEmpty ? '' : ' ${c.windDirection}'}',
              '${c.windKmh.round()} km/h'),
          _metric(Icons.wb_sunny_outlined, 'UV index', '${c.uvIndex}'),
          _metric(Icons.cloud_outlined, 'Cloud cover', '${c.cloudCover}%'),
          _metric(Icons.grain_rounded, 'Rain (next hr)', '${c.rainMm.toStringAsFixed(1)} mm'),
        ]),
      ]),
    );
  }
}

/// Next 24 hours, scrolling sideways.
class GoogleHourlyStrip extends StatelessWidget {
  final List<GoogleHourlyForecast> hours;
  final int count;
  const GoogleHourlyStrip({super.key, required this.hours, this.count = 24});

  @override
  Widget build(BuildContext context) {
    final list = hours.take(count).toList();
    if (list.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 136,
      decoration: _card(),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final h = list[i];
          return SizedBox(
            width: 52,
            child: Column(children: [
              Text(i == 0 ? 'Now' : DateFormat('HH:00').format(h.time),
                  style: const TextStyle(fontSize: 11, color: _Palette.muted)),
              const SizedBox(height: 4),
              GoogleWeatherIcon(h.condition, size: 30),
              const SizedBox(height: 4),
              Text('${h.temp.round()}°', style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('${h.rainChance}%',
                  style: TextStyle(
                      fontSize: 11,
                      color: h.rainChance >= 50 ? _Palette.googleFg : _Palette.muted,
                      fontWeight: h.rainChance >= 50 ? FontWeight.w700 : FontWeight.w400)),
            ]),
          );
        },
      ),
    );
  }
}

/// Day-by-day forecast.
class GoogleDailyList extends StatelessWidget {
  final List<GoogleDailyForecast> days;
  final int count;
  const GoogleDailyList({super.key, required this.days, this.count = 7});

  @override
  Widget build(BuildContext context) {
    final list = days.take(count).toList();
    if (list.isEmpty) return const SizedBox.shrink();
    final today = DateTime.now();
    return Container(
      decoration: _card(),
      child: Column(children: [
        for (var i = 0; i < list.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              SizedBox(
                width: 64,
                child: Text(
                  list[i].date.day == today.day && list[i].date.month == today.month
                      ? 'Today'
                      : DateFormat('EEE d').format(list[i].date),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              GoogleWeatherIcon(list[i].condition, size: 30),
              const SizedBox(width: 8),
              Expanded(
                child: Text(list[i].condition.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: _Palette.muted)),
              ),
              const Icon(Icons.umbrella_rounded, size: 13, color: _Palette.googleFg),
              const SizedBox(width: 2),
              SizedBox(
                width: 36,
                child: Text('${list[i].rainChance}%',
                    style: const TextStyle(fontSize: 12, color: _Palette.googleFg)),
              ),
              SizedBox(
                width: 64,
                child: Text('${list[i].maxTemp.round()}° / ${list[i].minTemp.round()}°',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

/// Compact Google forecast for the Weather Station screen, shown alongside
/// (and clearly separate from) the station's own measurements.
class GoogleForecastCompactCard extends StatelessWidget {
  final GoogleWeather weather;
  final String? place;
  final VoidCallback? onOpenFull;
  const GoogleForecastCompactCard({super.key, required this.weather, this.place, this.onOpenFull});

  @override
  Widget build(BuildContext context) {
    final c = weather.current;
    final next = weather.hours.take(12).toList();
    final maxChance = next.isEmpty ? c.rainChance : next.map((h) => h.rainChance).reduce((a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: WeatherSourceBadge(WeatherSource.google)),
          Text(
            weather.fromCache ? 'Saved ${_ago(weather.fetchedAt)}' : 'Updated ${_ago(weather.fetchedAt)}',
            style: const TextStyle(fontSize: 11, color: _Palette.muted),
          ),
        ]),
        if (place != null) ...[
          const SizedBox(height: 6),
          Text('Forecast for $place',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: _Palette.muted)),
        ],
        const SizedBox(height: 10),
        Row(children: [
          GoogleWeatherIcon(c.condition, size: 44),
          const SizedBox(width: 10),
          Text('${c.temp.round()}°C', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${c.condition.description}\nRain in next 12 h: up to $maxChance%',
              style: const TextStyle(fontSize: 12.5, height: 1.35),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        GoogleDailyList(days: weather.days, count: 3),
        if (onOpenFull != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onOpenFull,
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Full 7-day forecast'),
            ),
          ),
        const Text(
          'Google\'s forecast for the area — useful for planning. Verified advice '
          'on this screen is based on your station\'s own measurements.',
          style: TextStyle(fontSize: 10.5, color: Colors.black45, height: 1.35),
        ),
      ]),
    );
  }
}
