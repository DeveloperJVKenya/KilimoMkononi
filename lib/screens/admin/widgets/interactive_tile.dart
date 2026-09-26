// lib/screens/admin/widgets/interactive_tile.dart
//
// Compact, tactile cards for the Admin Dashboard.
//   hover   → lifts (scale 1.02), coloured glow, gradient shifts, chevron nudges
//   press   → sinks (scale 0.97) with ink ripple + haptic tick
//   focus   → coloured ring (keyboard / D-pad), Enter/Space activates
// Everything animates in ≤200 ms so it feels responsive, not floaty.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared hover / press / focus behaviour for the tiles below.
class _Tactile extends StatefulWidget {
  final Color accent;
  final VoidCallback? onTap;
  final String semanticsLabel;
  final BorderRadius radius;
  final Widget Function(BuildContext context, bool active) builder;

  const _Tactile({
    required this.accent,
    required this.onTap,
    required this.semanticsLabel,
    required this.builder,
    this.radius = const BorderRadius.all(Radius.circular(16)),
  });

  @override
  State<_Tactile> createState() => _TactileState();
}

class _TactileState extends State<_Tactile> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    final active = _enabled && (_hovered || _focused);
    final scale = !_enabled
        ? 1.0
        : _pressed
        ? 0.97
        : active
        ? 1.02
        : 1.0;
    final accent = widget.accent;

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticsLabel,
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: _enabled ? Colors.white : const Color(0xFFF1F3F1),
            borderRadius: widget.radius,
            border: Border.all(
              color: _focused
                  ? accent
                  : active
                  ? accent.withValues(alpha: 0.45)
                  : const Color(0xFFE3E7E2),
              width: _focused ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: active
                    ? accent.withValues(alpha: 0.28)
                    : Colors.black.withValues(alpha: 0.05),
                blurRadius: active ? 18 : 6,
                offset: Offset(0, active ? 6 : 2),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: widget.radius,
              onTap: _enabled
                  ? () {
                      HapticFeedback.selectionClick();
                      widget.onTap!();
                    }
                  : null,
              onHover: (v) => setState(() => _hovered = v),
              onHighlightChanged: (v) => setState(() => _pressed = v),
              onFocusChange: (v) => setState(() => _focused = v),
              splashColor: accent.withValues(alpha: 0.16),
              highlightColor: accent.withValues(alpha: 0.06),
              hoverColor: accent.withValues(alpha: 0.03),
              focusColor: accent.withValues(alpha: 0.06),
              child: widget.builder(context, active),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded gradient icon badge. [active] sweeps the gradient diagonal.
class GradientIconBadge extends StatelessWidget {
  final IconData icon;
  final List<Color> gradient;
  final bool active;
  final double size;

  const GradientIconBadge({
    super.key,
    required this.icon,
    required this.gradient,
    this.active = false,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: LinearGradient(
          begin: active ? Alignment.topRight : Alignment.topLeft,
          end: active ? Alignment.bottomLeft : Alignment.bottomRight,
          colors: gradient,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: active ? 0.45 : 0.25),
            blurRadius: active ? 10 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      // Subtle top highlight — a light "sheen" over the gradient.
      child: ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (rect) => LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Colors.white.withValues(alpha: 0.82)],
        ).createShader(rect),
        child: Icon(icon, color: Colors.white, size: size * 0.52),
      ),
    );
  }
}

/// Horizontal action / role tile: icon · title + subtitle · badge/chevron.
class ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Color> gradient;
  final VoidCallback? onTap;

  /// Small pill on the right (e.g. member count). Null → chevron.
  final Widget? trailing;

  const ActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.gradient,
    this.subtitle,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return _Tactile(
      accent: gradient.first,
      onTap: onTap,
      semanticsLabel: subtitle == null ? title : '$title. $subtitle',
      builder: (context, active) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            GradientIconBadge(icon: icon, gradient: gradient, active: active),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B2A1B),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                        height: 1.25,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                AnimatedSlide(
                  offset: Offset(active ? 0.25 : 0, 0),
                  duration: const Duration(milliseconds: 160),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: active ? gradient.first : Colors.black26,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// Compact statistic tile: icon + animated count + label.
class StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  /// null while loading; -1 on error.
  final int? count;
  final VoidCallback? onTap;

  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.count,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _Tactile(
      accent: color,
      onTap: onTap,
      radius: const BorderRadius.all(Radius.circular(14)),
      semanticsLabel:
          '$label: ${count == null
              ? 'loading'
              : count! < 0
              ? 'unavailable'
              : count}',
      builder: (context, active) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: active ? 0.2 : 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AnimatedCount(count: count, color: color),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedCount extends StatelessWidget {
  final int? count;
  final Color color;
  const _AnimatedCount({required this.count, required this.color});

  static String _fmt(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w800,
      height: 1.1,
    );
    if (count == null) {
      return Container(
        width: 36,
        height: 14,
        margin: const EdgeInsets.symmetric(vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }
    if (count! < 0) {
      return Text('—', style: style.copyWith(color: Colors.black38));
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: count!.toDouble()),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      // One line, shrinking to fit — big counts never wrap and push the
      // label out of the tile on narrow phones.
      builder: (_, v, _) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          _fmt(v.round()),
          maxLines: 1,
          style: style.copyWith(color: color),
        ),
      ),
    );
  }
}
