// lib/settings/appearance/button_styles.dart
//
// One modern button style for the whole app (farmer and education modes),
// applied in appearanceTheme():
//   • sized to the label — 44 px tall, never stretched to fill the width
//   • 12 px rounded corners, flat (no drop shadows), semi-bold label
//   • the user's chosen font and text size (Settings → Appearance)
//
// Screens set only colours (backgroundColor / foregroundColor / side) in
// their own styleFrom(); size, padding, shape and elevation come from here.
// Don't wrap buttons in SizedBox(width: double.infinity) or give them
// minimumSize: Size.fromHeight(…) — pairs of actions use Expanded in a Row.

import 'package:flutter/material.dart';

const kButtonRadius = 12.0;
const kButtonHeight = 44.0;

ThemeData withModernButtons(ThemeData t) {
  final cs = t.colorScheme;
  final label = (t.textTheme.labelLarge ?? const TextStyle()).copyWith(
    fontSize: 14.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );
  final shape = WidgetStatePropertyAll<OutlinedBorder>(
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(kButtonRadius)),
  );
  const padding = WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20, vertical: 10));
  const minSize = WidgetStatePropertyAll(Size(64, kButtonHeight));
  final text = WidgetStatePropertyAll(label);
  const flat = WidgetStatePropertyAll(0.0);

  ButtonStyle base() => ButtonStyle(
        shape: shape,
        padding: padding,
        minimumSize: minSize,
        textStyle: text,
        elevation: flat,
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        iconSize: const WidgetStatePropertyAll(18),
      );

  return t.copyWith(
    // Solid primary actions (most screens set their own colour).
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: base().copyWith(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? cs.onSurface.withValues(alpha: 0.12) : cs.primary,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? cs.onSurface.withValues(alpha: 0.38) : cs.onPrimary,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(style: base()),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: base().copyWith(
        side: WidgetStateProperty.resolveWith(
          (s) => BorderSide(
            color: s.contains(WidgetState.disabled) ? cs.onSurface.withValues(alpha: 0.12) : cs.outline,
            width: 1.2,
          ),
        ),
      ),
    ),
    // Text buttons are lighter: less padding, a little shorter.
    textButtonTheme: TextButtonThemeData(
      style: base().copyWith(
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
        minimumSize: const WidgetStatePropertyAll(Size(48, 40)),
      ),
    ),
  );
}
