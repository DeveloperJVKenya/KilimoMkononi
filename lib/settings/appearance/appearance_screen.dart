// lib/settings/appearance/appearance_screen.dart
//
// Settings → Appearance: live preview, text size (slider + presets), font
// (dropdown previewing each font), bold text, reduced motion, compact
// layout and reset. Everything applies instantly app-wide (appearance.dart).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kilimomkononi/settings/appearance/appearance.dart';
import 'package:kilimomkononi/settings/widgets/settings_kit.dart';

const _teal = Color(0xFF00897B);
const _indigo = Color(0xFF3949AB);
const _amber = Color(0xFFEF8F00);
const _purple = Color(0xFF8E24AA);
const _blue = Color(0xFF1E88E5);

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  static const presets = [('Small', 0.9), ('Default', 1.0), ('Large', 1.15), ('Larger', 1.3), ('Largest', 1.45)];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appearanceProvider);
    final n = ref.read(appearanceProvider.notifier);
    return SettingsPage(
      title: 'Appearance',
      subtitle: 'Make the app comfortable to read',
      actions: [
        if (!s.isDefault)
          TextButton.icon(
            onPressed: () async {
              if (await confirmAction(
                context,
                icon: Icons.restart_alt_rounded,
                title: 'Reset appearance?',
                message: 'Text size, font and reading options go back to the defaults.',
                confirmLabel: 'Reset',
              )) {
                n.reset();
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: const Text('Reset'),
          ),
      ],
      children: [
        _Preview(settings: s),
        const SizedBox(height: 20),
        SettingsSection(
          title: 'Text size',
          color: _teal,
          footer: 'Works together with your phone\'s own text size setting.',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  const SettingsIcon(Icons.format_size_rounded, color: _teal),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(s.textSizeLabel,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: kSetInk)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: _teal.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                    child: Text('${(s.textScale * 100).round()}%',
                        style: const TextStyle(color: _teal, fontWeight: FontWeight.w800)),
                  ),
                ]),
                const SizedBox(height: 6),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: _teal,
                    inactiveTrackColor: _teal.withValues(alpha: 0.18),
                    thumbColor: _teal,
                    overlayColor: _teal.withValues(alpha: 0.12),
                    trackHeight: 6,
                  ),
                  child: Row(children: [
                    const Text('A', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _teal)),
                    Expanded(
                      child: Slider(
                        value: s.textScale,
                        min: AppearanceSettings.minScale,
                        max: AppearanceSettings.maxScale,
                        divisions: 13,
                        label: '${(s.textScale * 100).round()}%',
                        semanticFormatterCallback: (v) => 'Text size ${(v * 100).round()} percent',
                        onChanged: (v) => n.update((x) => x.copyWith(textScale: v)),
                      ),
                    ),
                    const Text('A', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _teal)),
                  ]),
                ),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (label, v) in presets)
                      ChoiceChip(
                        label: Text(label),
                        selected: s.textSizeLabel == label,
                        showCheckmark: false,
                        selectedColor: _teal,
                        backgroundColor: _teal.withValues(alpha: 0.06),
                        side: BorderSide(color: _teal.withValues(alpha: 0.3)),
                        labelStyle: TextStyle(
                            color: s.textSizeLabel == label ? Colors.white : _teal, fontWeight: FontWeight.w700),
                        onSelected: (_) => n.update((x) => x.copyWith(textScale: v)),
                      ),
                  ],
                ),
              ]),
            ),
          ],
        ),
        SettingsSection(
          title: 'Font',
          color: _indigo,
          footer: 'Fonts download once the first time you choose them.',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                DropdownButtonFormField<AppFont>(
                  key: ValueKey(s.font), // follows Reset
                  initialValue: s.font,
                  isExpanded: true,
                  menuMaxHeight: 420,
                  borderRadius: BorderRadius.circular(16),
                  decoration: InputDecoration(
                    labelText: 'App font',
                    prefixIcon: const Icon(Icons.font_download_rounded, color: _indigo),
                    filled: true,
                    fillColor: _indigo.withValues(alpha: 0.06),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    enabledBorder:
                        OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                  // The closed field shows plain text; the open menu previews
                  // each font in its own style.
                  selectedItemBuilder: (_) => [
                    for (final f in AppFont.values)
                      Text(f.label, style: const TextStyle(fontWeight: FontWeight.w700, color: kSetInk)),
                  ],
                  items: [
                    for (final f in AppFont.values)
                      DropdownMenuItem(
                        value: f,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          Text(f.label,
                              style: TextStyle(fontFamily: fontFamilyFor(f), fontWeight: FontWeight.w700, fontSize: 15)),
                          Text(f.description, style: const TextStyle(fontSize: 11.5, color: kSetMuted)),
                        ]),
                      ),
                  ],
                  onChanged: (f) => n.update((x) => x.copyWith(font: f)),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [_indigo.withValues(alpha: 0.08), _teal.withValues(alpha: 0.08)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Aa Bb Cc — ${s.font.description}. 0123456789',
                    style: TextStyle(fontFamily: fontFamilyFor(s.font), fontSize: 15, color: kSetInk, height: 1.4),
                  ),
                ),
              ]),
            ),
          ],
        ),
        SettingsSection(title: 'Reading & motion', color: _purple, children: [
          SettingsSwitchTile(
            icon: Icons.format_bold_rounded,
            color: _amber,
            title: 'Bold text',
            subtitle: 'Heavier letters — easier outdoors',
            value: s.boldText,
            onChanged: (v) => n.update((x) => x.copyWith(boldText: v)),
          ),
          SettingsSwitchTile(
            icon: Icons.animation_rounded,
            color: _purple,
            title: 'Reduce motion',
            subtitle: 'Turn off slide and fade animations',
            value: s.reduceMotion,
            onChanged: (v) => n.update((x) => x.copyWith(reduceMotion: v)),
          ),
          SettingsSwitchTile(
            icon: Icons.density_medium_rounded,
            color: _blue,
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

/// A mini farm card on a colourful band, showing the current settings.
class _Preview extends StatelessWidget {
  final AppearanceSettings settings;
  const _Preview({required this.settings});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            colors: [Color(0xFF0B3D1E), Color(0xFF1B5E20), Color(0xFF00897B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.visibility_rounded, size: 16, color: Colors.white70),
            const SizedBox(width: 6),
            const Expanded(
              child: Text('LIVE PREVIEW',
                  style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
            ),
            _PreviewChip(settings.textSizeLabel),
            const SizedBox(width: 6),
            _PreviewChip(settings.font.label),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.water_drop_rounded, color: Colors.white),
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
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDDEFDF), foregroundColor: kSetGreen),
                  onPressed: () {},
                  child: const Text('View advice'),
                ),
              ),
            ]),
          ),
        ]),
      );
}

class _PreviewChip extends StatelessWidget {
  final String label;
  const _PreviewChip(this.label);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 110),
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      );
}
