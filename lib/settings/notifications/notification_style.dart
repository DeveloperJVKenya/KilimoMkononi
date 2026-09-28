// lib/settings/notifications/notification_style.dart
//
// Colours and date/time formatting shared by the Notifications screen and
// Notification Settings. Green stays the brand colour; orange, blue, purple,
// teal and red give each kind of item its own recognisable accent.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class KmColors {
  KmColors._();

  static const greenDark = Color(0xFF003900);
  static const green = Color(0xFF1B5E20);
  static const greenMid = Color(0xFF2E7D32);
  static const greenTint = Color(0xFFE8F5E9);

  static const orange = Color(0xFFEF6C00);
  static const orangeTint = Color(0xFFFFF3E0);
  static const blue = Color(0xFF1565C0);
  static const blueTint = Color(0xFFE3F2FD);
  static const purple = Color(0xFF6A1B9A);
  static const purpleTint = Color(0xFFF3E5F5);
  static const teal = Color(0xFF00796B);
  static const tealTint = Color(0xFFE0F2F1);
  static const red = Color(0xFFC62828);
  static const redTint = Color(0xFFFFEBEE);
  static const amber = Color(0xFFF9A825);
  static const amberTint = Color(0xFFFFF8E1);

  static const page = Color(0xFFF4F7F5);
  static const border = Color(0xFFE3E8E4);
  static const muted = Color(0xFF6B7280);

  /// App bar gradient: brand green with a lighter green edge.
  static const appBarGradient = LinearGradient(
    colors: [greenDark, green, greenMid],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// "Mon 28 Sep 2026 · 09:41" — the exact moment, for traceability.
String fullStamp(DateTime t) => DateFormat('EEE d MMM yyyy · HH:mm').format(t);

/// "09:41"
String clockTime(DateTime t) => DateFormat('HH:mm').format(t);

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

/// "Today" / "Yesterday" / "Tomorrow" / "Wednesday 30 Sep 2026".
String dayHeading(DateTime t, {DateTime? now}) {
  final diff = _day(t).difference(_day(now ?? DateTime.now())).inDays;
  if (diff == 0) return 'Today';
  if (diff == -1) return 'Yesterday';
  if (diff == 1) return 'Tomorrow';
  return DateFormat('EEEE d MMM yyyy').format(t);
}

/// "just now", "5 min ago", "3 h ago", "2 days ago" — or "in 20 min",
/// "in 3 h", "in 4 days" for future times.
String relativeTime(DateTime t, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final d = t.difference(n);
  final future = d.inSeconds > 30;
  final a = d.abs();
  String span;
  if (a.inMinutes < 1) return 'just now';
  if (a.inMinutes < 60) {
    span = '${a.inMinutes} min';
  } else if (a.inHours < 24) {
    span = '${a.inHours} h';
  } else {
    final days = a.inDays;
    span = days == 1 ? '1 day' : '$days days';
  }
  return future ? 'in $span' : '$span ago';
}

/// Groups [items] under day headings (in the order given).
List<(String, List<T>)> groupByDay<T>(Iterable<T> items, DateTime Function(T) timeOf, {DateTime? now}) {
  final out = <(String, List<T>)>[];
  for (final item in items) {
    final h = dayHeading(timeOf(item), now: now);
    if (out.isEmpty || out.last.$1 != h) {
      out.add((h, [item]));
    } else {
      out.last.$2.add(item);
    }
  }
  return out;
}

/// Small rounded label.
class KmTag extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool filled;
  const KmTag(this.label, this.color, {super.key, this.icon, this.filled = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: filled ? null : Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: filled ? Colors.white : color),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 10.5, fontWeight: FontWeight.w700, color: filled ? Colors.white : color)),
          ),
        ]),
      );
}

/// "🕘 Mon 28 Sep 2026 · 09:41 · 5 min ago" line under an item.
class KmTimestamp extends StatelessWidget {
  final DateTime time;
  final String? prefix; // e.g. "Due", "Received", "Set"
  final Color color;
  final IconData icon;
  const KmTimestamp(this.time,
      {super.key, this.prefix, this.color = KmColors.muted, this.icon = Icons.schedule_rounded});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text.rich(
            TextSpan(children: [
              if (prefix != null) TextSpan(text: '$prefix '),
              TextSpan(text: fullStamp(time), style: const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: '  ·  ${relativeTime(time)}'),
            ]),
            style: TextStyle(fontSize: 11.5, color: color),
            maxLines: 2,
          ),
        ),
      ]);
}

/// Consistent empty state.
class KmEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color color;
  const KmEmptyState(
      {super.key, required this.icon, required this.title, required this.message, this.color = KmColors.green});

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.10), shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: KmColors.muted, height: 1.45)),
          ]),
        ),
      );
}
