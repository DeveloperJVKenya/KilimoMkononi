// lib/enterprise/features/agronomist/agronomist_widgets.dart
//
// Building blocks of the Agronomist panel's farmer sections: cards, stat
// tiles (a number + its change against the previous period), small trend
// bars, meters and the Low / Moderate / High soil bar. One hue per chart;
// numbers and labels stay in text colours; status colours always come with
// a word.

import 'package:flutter/material.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_widgets.dart';
import 'package:kilimomkononi/settings/notifications/notification_style.dart';

const kAgroInk = Color(0xFF1F2A1F);
const kAgroMuted = Color(0xFF5F6B5F);
const kAgroSeries = AdvisoryColors.midGreen;
const kPestColor = Color(0xFFB45309);
const kDiseaseColor = Color(0xFF7B1FA2);
const kUnknownColor = Color(0xFFC62828);
const kSoilColor = Color(0xFF6D4C41);

/// Soil level colours (always shown with their label).
const kLowColor = Color(0xFFD84315);
const kModerateColor = Color(0xFF2E7D32);
const kHighColor = Color(0xFF1565C0);

IconData issueIcon(String type) => type == 'disease' ? Icons.coronavirus_outlined : Icons.bug_report_outlined;
Color issueColor(String type) => type == 'disease' ? kDiseaseColor : kPestColor;

String shortDate(DateTime? d) {
  if (d == null) return '—';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

String agoOrDate(DateTime? d) => d == null ? '—' : relativeTime(d);

class AgroCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final Color color;

  const AgroCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
    this.trailing,
    this.color = AdvisoryColors.midGreen,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        // Material (not a coloured box) so list tiles inside show their ink.
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AdvisoryColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: _content(),
          ),
        ),
      );

  Widget _content() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kAgroInk)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!, style: const TextStyle(fontSize: 11.5, color: kAgroMuted)),
                  ),
              ]),
            ),
            ?trailing,
          ]),
          const SizedBox(height: 12),
          child,
        ]);
}

/// A headline number and its change against the previous period. For
/// problems ([upIsBad]) a rise is shown with a warning arrow.
class StatTile extends StatelessWidget {
  final String label;
  final int value;
  final int? previous;
  final IconData icon;
  final Color color;
  final bool upIsBad;
  final String? footnote;
  final VoidCallback? onTap;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.previous,
    this.upIsBad = true,
    this.footnote,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final change = previous == null ? null : value - previous!;
    final bad = change != null && change != 0 && ((change > 0) == upIsBad);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AdvisoryColors.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: kAgroMuted)),
              ),
            ]),
            const SizedBox(height: 6),
            Text('$value', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: kAgroInk)),
            if (change != null)
              Row(children: [
                Icon(
                  change == 0
                      ? Icons.trending_flat_rounded
                      : change > 0
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                  size: 14,
                  color: bad ? kLowColor : kAgroMuted,
                ),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    change == 0 ? 'same as before' : '${change > 0 ? '+' : ''}$change vs before',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: bad ? kLowColor : kAgroMuted),
                  ),
                ),
              ]),
            if (footnote != null)
              Text(footnote!, style: const TextStyle(fontSize: 10.5, color: kAgroMuted)),
          ]),
        ),
      ),
    );
  }
}

/// Lays out stat tiles 2 / 3 per row by width.
class StatGrid extends StatelessWidget {
  final List<Widget> tiles;
  const StatGrid(this.tiles, {super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 720 ? 3 : 2;
        const gap = 10.0;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(spacing: gap, runSpacing: gap, children: [
          for (final t in tiles) SizedBox(width: w, child: t),
        ]);
      });
}

/// Reports per slice of the period — thin bars on a baseline, one hue.
/// Each bar has a tooltip with its count.
class TrendBars extends StatelessWidget {
  final List<int> values;
  final int days;
  final double height;
  final Color color;

  const TrendBars(this.values, {super.key, required this.days, this.height = 28, this.color = kAgroSeries});

  @override
  Widget build(BuildContext context) {
    final max = values.fold<int>(0, (m, v) => v > m ? v : m);
    final per = (days / values.length).round();
    return Semantics(
      label: 'Reports over the last $days days: ${values.join(', ')}',
      child: SizedBox(
        height: height,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Tooltip(
                message: '${values[i]} report${values[i] == 1 ? '' : 's'} · '
                    '${days - per * i} – ${days - per * (i + 1) < 0 ? 0 : days - per * (i + 1)} days ago',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1), // 2px gap between bars
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: max == 0 ? 2 : (values[i] == 0 ? 2 : 4 + (height - 4) * values[i] / max),
                      decoration: BoxDecoration(
                        color: values[i] == 0 ? AdvisoryColors.border : color,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

/// "Fall armyworm ███████ 12" — a horizontal meter scaled to [max].
class MeterRow extends StatelessWidget {
  final String label;
  final int value;
  final int max;
  final Color color;
  final Widget? trailing;
  final String? sublabel;
  final VoidCallback? onTap;

  const MeterRow({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    this.color = kAgroSeries,
    this.trailing,
    this.sublabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kAgroInk)),
              ),
              Text('$value', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kAgroInk)),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ]),
            const SizedBox(height: 4),
            LayoutBuilder(
              builder: (context, c) => Stack(children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(color: AdvisoryColors.pageBg, borderRadius: BorderRadius.circular(3)),
                ),
                Container(
                  height: 6,
                  width: max <= 0 ? 0 : (c.maxWidth * value / max).clamp(4, c.maxWidth).toDouble(),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
                ),
              ]),
            ),
            if (sublabel != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(sublabel!, style: const TextStyle(fontSize: 11, color: kAgroMuted)),
              ),
          ]),
        ),
      );
}

/// Change against the previous period, as a small word ("+5", "new").
class ChangeBadge extends StatelessWidget {
  final int current;
  final int previous;
  const ChangeBadge({super.key, required this.current, required this.previous});

  @override
  Widget build(BuildContext context) {
    final d = current - previous;
    final text = previous == 0 ? 'new' : (d == 0 ? '=' : '${d > 0 ? '+' : ''}$d');
    final up = previous == 0 || d > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: up ? const Color(0xFFFFF1EC) : AdvisoryColors.pageBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(up ? Icons.arrow_upward_rounded : (d == 0 ? Icons.remove_rounded : Icons.arrow_downward_rounded),
            size: 11, color: up ? kLowColor : kAgroMuted),
        Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: up ? kLowColor : kAgroMuted)),
      ]),
    );
  }
}

/// Low / Moderate / High shares of tested plots, labelled.
class BandBar extends StatelessWidget {
  final int low;
  final int moderate;
  final int high;
  const BandBar({super.key, required this.low, required this.moderate, required this.high});

  @override
  Widget build(BuildContext context) {
    final total = low + moderate + high;
    if (total == 0) return const SizedBox.shrink();
    Widget seg(int n, Color c, String label) => n == 0
        ? const SizedBox.shrink()
        : Expanded(
            flex: n,
            child: Tooltip(
              message: '$label: $n plot${n == 1 ? '' : 's'}',
              child: Container(
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)),
              ),
            ),
          );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [seg(low, kLowColor, 'Low'), seg(moderate, kModerateColor, 'Moderate'), seg(high, kHighColor, 'High')]),
      const SizedBox(height: 3),
      Text(
        [
          if (low > 0) '$low low',
          if (moderate > 0) '$moderate moderate',
          if (high > 0) '$high high',
        ].join(' · '),
        style: const TextStyle(fontSize: 11, color: kAgroMuted),
      ),
    ]);
  }
}

/// A small coloured tag with a word (never colour alone).
class FlagTag extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const FlagTag(this.text, this.color, {super.key, this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 11, color: color), const SizedBox(width: 3)],
          Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color)),
        ]),
      );
}

class AgroEmpty extends StatelessWidget {
  final IconData icon;
  final String text;
  const AgroEmpty(this.icon, this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Icon(icon, size: 18, color: Colors.black38),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5, color: kAgroMuted))),
        ]),
      );
}

class AgroError extends StatelessWidget {
  final String text;
  final VoidCallback onRetry;
  const AgroError(this.text, {super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded, size: 40, color: Colors.black38),
            const SizedBox(height: 10),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: kAgroMuted)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
            ),
          ]),
        ),
      );
}
