// lib/settings/appearance/appearance.dart
//
// App-wide display preferences (Settings → Appearance), saved on this device:
// text size, font, bold text, reduced motion and compact layout. MyApp reads
// [appearanceProvider] and applies them through [appearanceTheme] and
// [AppearanceScope], so every screen follows them.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fonts offered in Settings. `system` keeps the platform default.
enum AppFont {
  system('Default', 'The standard app font'),
  atkinson('Atkinson Hyperlegible', 'Designed for low vision — very clear'),
  nunito('Nunito', 'Rounded and friendly'),
  openSans('Open Sans', 'Neutral and easy to read'),
  lato('Lato', 'Clean and compact'),
  sourceSans('Source Sans 3', 'Crisp on small screens'),
  poppins('Poppins', 'Bold and modern'),
  montserrat('Montserrat', 'Wide, confident headings'),
  ubuntu('Ubuntu', 'Warm and distinctive'),
  robotoSlab('Roboto Slab', 'Sturdy, newspaper style'),
  merriweather('Merriweather', 'Comfortable for long reading'),
  notoSerif('Noto Serif', 'Classic, like a book');

  final String label;
  final String description;
  const AppFont(this.label, this.description);
}

@immutable
class AppearanceSettings {
  /// Multiplies the phone's own text size (1.0 = unchanged).
  final double textScale;
  final AppFont font;
  final bool boldText;
  final bool reduceMotion;
  final bool compact;

  const AppearanceSettings({
    this.textScale = 1.0,
    this.font = AppFont.system,
    this.boldText = false,
    this.reduceMotion = false,
    this.compact = false,
  });

  static const minScale = 0.85;
  static const maxScale = 1.5;

  bool get isDefault => this == const AppearanceSettings();

  /// "Default", "Large" … for the Settings list.
  String get textSizeLabel {
    if (textScale < 0.95) return 'Small';
    if (textScale < 1.08) return 'Default';
    if (textScale < 1.22) return 'Large';
    if (textScale < 1.38) return 'Larger';
    return 'Largest';
  }

  AppearanceSettings copyWith({double? textScale, AppFont? font, bool? boldText, bool? reduceMotion, bool? compact}) =>
      AppearanceSettings(
        textScale: (textScale ?? this.textScale).clamp(minScale, maxScale).toDouble(),
        font: font ?? this.font,
        boldText: boldText ?? this.boldText,
        reduceMotion: reduceMotion ?? this.reduceMotion,
        compact: compact ?? this.compact,
      );

  Map<String, Object> toJson() => {
        'textScale': textScale,
        'font': font.name,
        'boldText': boldText,
        'reduceMotion': reduceMotion,
        'compact': compact,
      };

  factory AppearanceSettings.fromPrefs(SharedPreferences p) => AppearanceSettings(
        textScale: (p.getDouble('${_k}textScale') ?? 1.0).clamp(minScale, maxScale).toDouble(),
        font: AppFont.values.asNameMap()[p.getString('${_k}font')] ?? AppFont.system,
        boldText: p.getBool('${_k}boldText') ?? false,
        reduceMotion: p.getBool('${_k}reduceMotion') ?? false,
        compact: p.getBool('${_k}compact') ?? false,
      );

  Future<void> save(SharedPreferences p) async {
    await p.setDouble('${_k}textScale', textScale);
    await p.setString('${_k}font', font.name);
    await p.setBool('${_k}boldText', boldText);
    await p.setBool('${_k}reduceMotion', reduceMotion);
    await p.setBool('${_k}compact', compact);
  }

  static const _k = 'appearance_';

  @override
  bool operator ==(Object other) =>
      other is AppearanceSettings &&
      other.textScale == textScale &&
      other.font == font &&
      other.boldText == boldText &&
      other.reduceMotion == reduceMotion &&
      other.compact == compact;

  @override
  int get hashCode => Object.hash(textScale, font, boldText, reduceMotion, compact);
}

class AppearanceNotifier extends Notifier<AppearanceSettings> {
  @override
  AppearanceSettings build() {
    _load();
    return const AppearanceSettings();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      state = AppearanceSettings.fromPrefs(p);
    } catch (_) {}
  }

  Future<void> update(AppearanceSettings Function(AppearanceSettings) change) async {
    state = change(state);
    try {
      await state.save(await SharedPreferences.getInstance());
    } catch (_) {}
  }

  Future<void> reset() => update((_) => const AppearanceSettings());
}

final appearanceProvider = NotifierProvider<AppearanceNotifier, AppearanceSettings>(AppearanceNotifier.new);

/// Text theme for [font]; the default font keeps [base] unchanged.
TextTheme fontTextTheme(AppFont font, TextTheme base) => switch (font) {
      AppFont.system => base,
      AppFont.atkinson => GoogleFonts.atkinsonHyperlegibleTextTheme(base),
      AppFont.nunito => GoogleFonts.nunitoTextTheme(base),
      AppFont.openSans => GoogleFonts.openSansTextTheme(base),
      AppFont.lato => GoogleFonts.latoTextTheme(base),
      AppFont.sourceSans => GoogleFonts.sourceSans3TextTheme(base),
      AppFont.poppins => GoogleFonts.poppinsTextTheme(base),
      AppFont.montserrat => GoogleFonts.montserratTextTheme(base),
      AppFont.ubuntu => GoogleFonts.ubuntuTextTheme(base),
      AppFont.robotoSlab => GoogleFonts.robotoSlabTextTheme(base),
      AppFont.merriweather => GoogleFonts.merriweatherTextTheme(base),
      AppFont.notoSerif => GoogleFonts.notoSerifTextTheme(base),
    };

/// Font family name for widgets that set their own TextStyle.
String? fontFamilyFor(AppFont font) => switch (font) {
      AppFont.system => null,
      AppFont.atkinson => GoogleFonts.atkinsonHyperlegible().fontFamily,
      AppFont.nunito => GoogleFonts.nunito().fontFamily,
      AppFont.openSans => GoogleFonts.openSans().fontFamily,
      AppFont.lato => GoogleFonts.lato().fontFamily,
      AppFont.sourceSans => GoogleFonts.sourceSans3().fontFamily,
      AppFont.poppins => GoogleFonts.poppins().fontFamily,
      AppFont.montserrat => GoogleFonts.montserrat().fontFamily,
      AppFont.ubuntu => GoogleFonts.ubuntu().fontFamily,
      AppFont.robotoSlab => GoogleFonts.robotoSlab().fontFamily,
      AppFont.merriweather => GoogleFonts.merriweather().fontFamily,
      AppFont.notoSerif => GoogleFonts.notoSerif().fontFamily,
    };

/// The app theme with the chosen font and density applied.
ThemeData appearanceTheme(ThemeData base, AppearanceSettings s) {
  final family = fontFamilyFor(s.font);
  final themed = family == null ? base : base.copyWith(textTheme: fontTextTheme(s.font, base.textTheme));
  return themed.copyWith(visualDensity: s.compact ? VisualDensity.compact : VisualDensity.standard);
}

/// Applies text size, bold text and reduced motion below it (wrap the app's
/// navigator with it in MaterialApp.builder).
class AppearanceScope extends StatelessWidget {
  final AppearanceSettings settings;
  final Widget child;
  const AppearanceScope({super.key, required this.settings, required this.child});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final phone = mq.textScaler.scale(1);
    // Respect the phone's own setting, times ours, within readable bounds.
    final scale = (phone * settings.textScale).clamp(0.8, 2.0).toDouble();
    final family = fontFamilyFor(settings.font);
    Widget body = MediaQuery(
      data: mq.copyWith(
        textScaler: TextScaler.linear(scale),
        boldText: mq.boldText || settings.boldText,
        disableAnimations: mq.disableAnimations || settings.reduceMotion,
      ),
      child: child,
    );
    // Screens that set their own TextStyle (without a family) inherit the
    // chosen font from here.
    if (family != null) {
      body = DefaultTextStyle.merge(style: TextStyle(fontFamily: family), child: body);
    }
    return body;
  }
}
