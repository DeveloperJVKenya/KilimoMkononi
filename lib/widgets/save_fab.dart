// lib/widgets/save_fab.dart
//
// The floating Save button every data-entry form uses, so saving is always
// one tap away — never at the bottom of a long scroll:
//
//   Scaffold(
//     floatingActionButton: SaveFab(onPressed: _save, busy: _saving),
//     body: ListView(padding: const EdgeInsets.only(bottom: kSaveFabSpace), …),
//   )
//
// • sized to its label (extended FAB), rides above the keyboard
// • busy → spinner + "Saving…" and no double taps
// • visible: false hides it until saving makes sense (e.g. after a
//   diagnosis); onPressed: null shows it greyed out
// • forms inside a tab (no Scaffold of their own) use FloatingSaveArea
//
// Give the scrolling form kSaveFabSpace of bottom padding so its last field
// can scroll clear of the button.

import 'package:flutter/material.dart';

/// Bottom padding a form needs so nothing stays hidden under the button.
const kSaveFabSpace = 96.0;

class SaveFab extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool busy;
  final bool visible;
  final String label;
  final String busyLabel;
  final IconData icon;
  final Color? color;
  final Object? heroTag;

  const SaveFab({
    super.key,
    required this.onPressed,
    this.busy = false,
    this.visible = true,
    this.label = 'Save',
    this.busyLabel = 'Saving…',
    this.icon = Icons.save_rounded,
    this.color,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onPressed != null && !busy;
    final bg = enabled ? (color ?? const Color(0xFF1B5E20)) : cs.onSurface.withValues(alpha: 0.12);
    final fg = enabled ? Colors.white : cs.onSurface.withValues(alpha: 0.38);
    return AnimatedScale(
      scale: visible ? 1 : 0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: IgnorePointer(
        ignoring: !visible,
        child: FloatingActionButton.extended(
          heroTag: heroTag ?? 'km_save_$label',
          onPressed: enabled ? onPressed : null,
          backgroundColor: bg,
          foregroundColor: fg,
          disabledElevation: 0,
          elevation: 3,
          highlightElevation: 5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          extendedPadding: const EdgeInsets.symmetric(horizontal: 20),
          tooltip: label,
          icon: busy
              ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
              : Icon(icon, size: 20),
          label: Text(
            busy ? busyLabel : label,
            style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.1),
          ),
        ),
      ),
    );
  }
}

/// A form without a Scaffold of its own (e.g. inside a tab) with a floating
/// Save button over its bottom-right corner.
class FloatingSaveArea extends StatelessWidget {
  final Widget child;
  final SaveFab fab;
  const FloatingSaveArea({super.key, required this.child, required this.fab});

  @override
  Widget build(BuildContext context) => Stack(children: [
        Positioned.fill(child: child),
        // The screen around it already shrinks for the keyboard, so this
        // stays above it.
        Positioned(
          right: 16,
          bottom: 16,
          child: SafeArea(top: false, left: false, child: fab),
        ),
      ]);
}
