// lib/settings/appearance/appearance_screen.dart
//
// Settings → Appearance: live preview, text size slider, font choice, bold
// text, reduced motion, compact layout and reset. Everything applies
// instantly app-wide (see appearance.dart).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kilimomkononi/settings/appearance/appearance.dart';
import 'package:kilimomkononi/settings/widgets/settings_kit.dart';

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appearanceProvider);
    final n = ref.read(appearanceProvider.notifier);
    return SettingsPage(
      title: 'Appearance',
      subtitle: 'Make the app comfortable to read',
      actions: [
        if (!s.isDefault)
          TextButton(
            onPressed: n.reset,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Reset'),
          ),
      ],
      children: [
        const _Preview(),
        const SizedBox(height: 18),
        SettingsSection(
          title: 'Text size',
          footer: 'Works together with your phone\'s own text size setting.',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  const Text('A', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kSetMuted)),
                  Expanded(
                    child: Slider(
                      value: s.textScale,
                      min: AppearanceSettings.minScale,
                      max: AppearanceSettings.maxScale,
                      divisions: 13,
                      activeColor: kSetGreen,
                      label: '${(s.textScale * 100).round()}%',
                      semanticFormatterCallback: (v) => 'Text size ${(v * 100).round()} percent',
                      onChanged: (v) => n.update((x) => x.copyWith(textScale: v)),
                    ),
                  ),
                  const Text('A', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: kSetMuted)),
                ]),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (label, v) in const [('Small', 0.9), ('Default', 1.0), ('Large', 1.15), ('Larger', 1.3), ('Largest', 1.45)])
                      ChoiceChip(
                        label: Text(label),
                        selected: s.textSizeLabel == label,
                        showCheckmark: false,
                        selectedColor: const Color(0xFFD8EFD9),
                        onSelected: (_) => n.update((x) => x.copyWith(textScale: v)),
                      ),
                  ],
                ),
              ]),
            ),
          ],
        ),
        SettingsSection(title: 'Font', children: [
          for (final f in AppFont.values)
            _FontTile(font: f, selected: s.font == f, onTap: () => n.update((x) => x.copyWith(font: f))),
        ]),
        SettingsSection(title: 'Reading & motion', children: [
          SettingsSwitchTile(
            icon: Icons.format_bold_rounded,
            color: const Color(0xFF00695C),
            title: 'Bold text',
            subtitle: 'Heavier letters — easier outdoors',
            value: s.boldText,
            onChanged: (v) => n.update((x) => x.copyWith(boldText: v)),
          ),
          SettingsSwitchTile(
            icon: Icons.animation_rounded,
            color: const Color(0xFF00695C),
            title: 'Reduce motion',
            subtitle: 'Turn off slide and fade animations',
            value: s.reduceMotion,
            onChanged: (v) => n.update((x) => x.copyWith(reduceMotion: v)),
          ),
          SettingsSwitchTile(
            icon: Icons.density_medium_rounded,
            color: const Color(0xFF00695C),
            title: 'Compact layout',
            subtitle: 'Fit more on the screen',
            value: s.compact,
            onChanged: (v) => n.update((x) => x.copyWith(compact: v)),
          ),
        ]),
      ],
    );
  }
}

class _FontTile extends StatelessWidget {
  final AppFont font;
  final bool selected;
  final VoidCallback onTap;
  const _FontTile({required this.font, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final family = fontFamilyFor(font);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? kSetGreen : const Color(0xFFEFF3EE),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text('Aa',
                style: TextStyle(
                    fontFamily: family,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : kSetInk,
                    fontSize: 15)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(font.label,
                  style: TextStyle(fontFamily: family, fontWeight: FontWeight.w700, fontSize: 15, color: kSetInk)),
              Text(font.description, style: const TextStyle(color: kSetMuted, fontSize: 12.5)),
            ]),
          ),
          Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: selected ? kSetGreen : kSetMuted),
        ]),
      ),
    );
  }
}

/// A mini farm card that shows the current settings.
class _Preview extends StatelessWidget {
  const _Preview();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kSetBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.visibility_rounded, size: 16, color: kSetMuted),
            SizedBox(width: 6),
            Text('PREVIEW', style: TextStyle(color: kSetMuted, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.water_drop_rounded, color: kSetGreen),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Good time to plant beans',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kSetInk)),
                SizedBox(height: 2),
                Text('Soil moisture is 32% and rain is expected on Thursday.',
                    style: TextStyle(fontSize: 13.5, color: kSetMuted, height: 1.35)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kSetGreen),
              onPressed: () {},
              child: const Text('View advice'),
            ),
          ),
        ]),
      );
}
