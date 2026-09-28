// lib/authentication/widgets/auth_kit.dart
//
// Shared building blocks for the farmer sign-in / sign-up screens:
//
//   AuthLayout      responsive shell — wide screens get a brand panel beside
//                   a fixed-width form; tablets a centred card; phones a
//                   compact header. Fields never stretch to the screen edge.
//   EnterToSubmit   Enter / numpad Enter submits from anywhere in the form
//                   (a field, the terms checkbox, a closed dropdown). Space
//                   still toggles checkboxes and opens dropdowns.
//   AuthField, AuthDropdown, PasswordStrengthMeter, TermsField,
//   AuthPrimaryButton (shows "or press Enter" on keyboard devices),
//   GoogleAuthButton, OrDivider, AuthErrorBanner, KenyaLocationFields.

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kilimomkononi/data/kenya_locations.dart';
import 'package:kilimomkononi/widgets/google_logo.dart';

class AuthColors {
  AuthColors._();
  static const greenDark = Color(0xFF0B3D1E);
  static const green = Color(0xFF1B5E20);
  static const greenMid = Color(0xFF2E7D32);
  static const teal = Color(0xFF00695C);
  static const tealLight = Color(0xFF26A69A);
  static const amber = Color(0xFFFFB300);
  static const orange = Color(0xFFEF6C00);
  static const red = Color(0xFFC62828);
  static const field = Color(0xFFF5F8F6);
  static const border = Color(0xFFDDE5E0);
  static const muted = Color(0xFF64748B);
  static const ink = Color(0xFF0F172A);

  static const brandGradient = LinearGradient(
    colors: [greenDark, green, teal],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// True on web and desktop, where a physical keyboard is likely.
bool get isKeyboardPlatform =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.linux;

// ═════════════════════════════════════════════════════════════════════════════
//  Layout
// ═════════════════════════════════════════════════════════════════════════════

class AuthLayout extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final double maxFormWidth;

  /// Optional top-right action (e.g. "Switch mode"); told whether it sits
  /// on the dark brand colours or on white, so it stays readable.
  final Widget Function(bool onDark)? topAction;

  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.maxFormWidth = 440,
    this.topAction,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(builder: (context, c) {
        final form = _FormColumn(title: title, subtitle: subtitle, maxWidth: maxFormWidth, child: child);
        if (c.maxWidth >= 960) {
          // Split: brand panel | form.
          return Row(children: [
            const Expanded(flex: 5, child: _BrandPanel()),
            Expanded(
              flex: 6,
              child: SafeArea(child: Stack(children: [
                Center(child: SingleChildScrollView(padding: const EdgeInsets.all(40), child: form)),
                if (topAction != null) Positioned(top: 12, right: 16, child: topAction!(false)),
              ])),
            ),
          ]);
        }
        if (c.maxWidth >= 600) {
          // Tablet / small window: a card on the brand gradient.
          return Container(
            decoration: const BoxDecoration(gradient: AuthColors.brandGradient),
            child: SafeArea(child: Stack(children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Material(
                    color: Colors.white,
                    elevation: 12,
                    shadowColor: Colors.black38,
                    borderRadius: BorderRadius.circular(24),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(36, 32, 36, 28),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const _BrandMark(onDark: false),
                        const SizedBox(height: 20),
                        form,
                      ]),
                    ),
                  ),
                ),
              ),
              if (topAction != null) Positioned(top: 12, right: 16, child: topAction!(true)),
            ])),
          );
        }
        // Phone: compact gradient header, then the form.
        return SingleChildScrollView(
          child: Column(children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: AuthColors.brandGradient,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
                  // Brand on the left, action on the right — never overlapping.
                  child: Row(children: [
                    const Expanded(child: Align(alignment: Alignment.centerLeft, child: _BrandMark(onDark: true))),
                    if (topAction != null) topAction!(true),
                  ]),
                ),
              ),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(20, 24, 20, 32), child: form),
          ]),
        );
      }),
    );
  }
}

class _FormColumn extends StatelessWidget {
  final String title;
  final String subtitle;
  final double maxWidth;
  final Widget child;
  const _FormColumn({required this.title, required this.subtitle, required this.maxWidth, required this.child});

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(title,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AuthColors.ink, height: 1.2)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(fontSize: 14.5, color: AuthColors.muted, height: 1.4)),
          const SizedBox(height: 24),
          child,
        ]),
      );
}

/// Leaf (farming) + book (learning) badge with the app name.
class _BrandMark extends StatelessWidget {
  final bool onDark;
  const _BrandMark({required this.onDark});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        const AuthLogoBadge(size: 44),
        const SizedBox(width: 12),
        Flexible(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('Kilimo Mkononi',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: onDark ? Colors.white : AuthColors.green)),
            Text('Smart farming at your fingertips',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: onDark ? Colors.white70 : AuthColors.muted)),
          ]),
        ),
      ]);
}

class AuthLogoBadge extends StatelessWidget {
  final double size;
  const AuthLogoBadge({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Stack(alignment: Alignment.center, children: [
          Positioned(left: size * 0.14, child: Icon(Icons.eco, color: AuthColors.greenMid, size: size * 0.36)),
          Positioned(right: size * 0.14, child: Icon(Icons.menu_book_rounded, color: AuthColors.teal, size: size * 0.33)),
        ]),
      );
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        Image.asset('assets/field_data_collection.jpg', fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox()),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AuthColors.greenDark.withValues(alpha: 0.94),
                AuthColors.green.withValues(alpha: 0.86),
                AuthColors.teal.withValues(alpha: 0.82),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(48, 48, 48, 40),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _BrandMark(onDark: true),
              const Spacer(),
              const Text('Grow. Learn. Thrive.',
                  style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, color: Colors.white, height: 1.15)),
              const SizedBox(height: 14),
              Text(
                'Live readings from your farm\'s weather station, pest and disease help, '
                'and advice verified by field agronomists — all in one place.',
                style: TextStyle(fontSize: 15.5, color: Colors.white.withValues(alpha: 0.85), height: 1.5),
              ),
              const SizedBox(height: 32),
              const _Feature(Icons.sensors_rounded, 'Weather station data from your own farm', AuthColors.amber),
              const _Feature(Icons.bug_report_rounded, 'Photo diagnosis for pests and diseases', Color(0xFFFF8A65)),
              const _Feature(Icons.verified_rounded, 'Advice verified by Field Agronomists', Color(0xFF80CBC4)),
              const _Feature(Icons.notifications_active_rounded, 'Alerts and reminders when it matters', Color(0xFF90CAF9)),
              const Spacer(),
              Text('© ${DateTime.now().year} Kilimo Mkononi',
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
            ]),
          ),
        ),
      ]);
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _Feature(this.icon, this.text, this.color);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14.5))),
        ]),
      );
}

// ═════════════════════════════════════════════════════════════════════════════
//  Keyboard
// ═════════════════════════════════════════════════════════════════════════════

/// Enter / numpad Enter anywhere inside [child] calls [onSubmit] (unless
/// [enabled] is false). Repeated triggers within 400 ms are ignored, so a
/// field's own onFieldSubmitted and this shortcut can't double-submit.
class EnterToSubmit extends StatefulWidget {
  final VoidCallback onSubmit;
  final bool enabled;
  final Widget child;
  const EnterToSubmit({super.key, required this.onSubmit, required this.child, this.enabled = true});

  @override
  State<EnterToSubmit> createState() => _EnterToSubmitState();
}

class _EnterToSubmitState extends State<EnterToSubmit> {
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  void _fire() {
    if (!widget.enabled) return;
    final now = DateTime.now();
    if (now.difference(_last).inMilliseconds < 400) return;
    _last = now;
    widget.onSubmit();
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter): _fire,
          const SingleActivator(LogicalKeyboardKey.numpadEnter): _fire,
        },
        child: FocusTraversalGroup(child: widget.child),
      );
}

/// Caps Lock warning for password fields (keyboard devices only).
class CapsLockHint extends StatefulWidget {
  final FocusNode focusNode;
  const CapsLockHint({super.key, required this.focusNode});

  @override
  State<CapsLockHint> createState() => _CapsLockHintState();
}

class _CapsLockHintState extends State<CapsLockHint> {
  bool _caps = false;

  bool _check(KeyEvent _) {
    final caps = HardwareKeyboard.instance.lockModesEnabled.contains(KeyboardLockMode.capsLock);
    if (caps != _caps && mounted) setState(() => _caps = caps);
    return false;
  }

  void _onFocus() => _check(const KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.capsLock, logicalKey: LogicalKeyboardKey.capsLock, timeStamp: Duration.zero));

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_check);
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_check);
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_caps || !widget.focusNode.hasFocus) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.only(top: 6, left: 4),
      child: Row(children: [
        Icon(Icons.keyboard_capslock_rounded, size: 15, color: AuthColors.orange),
        SizedBox(width: 4),
        Text('Caps Lock is on', style: TextStyle(fontSize: 12, color: AuthColors.orange, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  Fields
// ═════════════════════════════════════════════════════════════════════════════

InputDecoration authDecoration({
  required String label,
  String? hint,
  IconData? icon,
  Widget? suffix,
  String? prefixText,
}) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefixText,
      prefixIcon: icon == null ? null : Icon(icon, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: AuthColors.field,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      floatingLabelStyle: const TextStyle(color: AuthColors.green, fontWeight: FontWeight.w600),
      prefixIconColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.focused) ? AuthColors.green : AuthColors.muted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AuthColors.border)),
      enabledBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AuthColors.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AuthColors.green, width: 1.8)),
      errorBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AuthColors.red)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AuthColors.red, width: 1.8)),
    );

class AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final FocusNode? focusNode;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  final bool obscure;
  final Widget? suffix;
  final String? prefixText;
  final TextCapitalization capitalization;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final List<TextInputFormatter>? inputFormatters;

  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.focusNode,
    this.validator,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.autofillHints,
    this.obscure = false,
    this.suffix,
    this.prefixText,
    this.capitalization = TextCapitalization.none,
    this.onChanged,
    this.enabled = true,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        obscureText: obscure,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        textCapitalization: capitalization,
        autofillHints: autofillHints,
        inputFormatters: inputFormatters,
        onFieldSubmitted: onSubmitted,
        onChanged: onChanged,
        validator: validator,
        style: const TextStyle(fontSize: 15, color: AuthColors.ink),
        decoration: authDecoration(label: label, hint: hint, icon: icon, suffix: suffix, prefixText: prefixText),
      );
}

class AuthDropdown extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final String emptyHint;
  final FocusNode? focusNode;

  const AuthDropdown({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.emptyHint,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
        // Rebuild when the options change (e.g. a new county's constituencies).
        key: ValueKey('$label-${items.length}-${items.isEmpty ? '' : items.first}'),
        focusNode: focusNode,
        initialValue: value,
        isExpanded: true,
        menuMaxHeight: 360,
        borderRadius: BorderRadius.circular(12),
        decoration: authDecoration(label: label, icon: icon, hint: items.isEmpty ? emptyHint : null),
        items: items.map((v) => DropdownMenuItem(value: v, child: Text(v, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: items.isEmpty ? null : onChanged,
        validator: (v) => v == null ? 'Select your ${label.toLowerCase()}' : null,
      );
}

/// County → constituency → ward, as linked dropdowns.
class KenyaLocationFields extends StatelessWidget {
  final String? county;
  final String? constituency;
  final String? ward;
  final ValueChanged<String?> onCounty;
  final ValueChanged<String?> onConstituency;
  final ValueChanged<String?> onWard;
  final FocusNode? countyFocus;
  final FocusNode? constituencyFocus;
  final FocusNode? wardFocus;

  const KenyaLocationFields({
    super.key,
    required this.county,
    required this.constituency,
    required this.ward,
    required this.onCounty,
    required this.onConstituency,
    required this.onWard,
    this.countyFocus,
    this.constituencyFocus,
    this.wardFocus,
  });

  @override
  Widget build(BuildContext context) {
    final counties = kenyaLocations.keys.toList()..sort();
    final constituencies = county == null ? const <String>[] : (kenyaLocations[county] ?? const <String>[]);
    final wards = constituency == null ? const <String>[] : (constituencyWards[constituency] ?? const <String>[]);
    return AuthRow(children: [
      AuthDropdown(
          label: 'County', icon: Icons.map_outlined, value: county, items: counties,
          onChanged: onCounty, emptyHint: '', focusNode: countyFocus),
      AuthDropdown(
          label: 'Constituency', icon: Icons.location_city_outlined, value: constituency, items: constituencies,
          onChanged: onConstituency, emptyHint: 'Choose a county first', focusNode: constituencyFocus),
      AuthDropdown(
          label: 'Ward', icon: Icons.place_outlined, value: ward, items: wards,
          onChanged: onWard, emptyHint: 'Choose a constituency first', focusNode: wardFocus),
    ]);
  }
}

/// Lays children out in columns when there's room (≥ 520 px for two, ≥ 760
/// for three), stacked otherwise.
class AuthRow extends StatelessWidget {
  final List<Widget> children;
  final double gap;
  const AuthRow({super.key, required this.children, this.gap = 14});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final perRow = c.maxWidth >= 760 ? 3 : (c.maxWidth >= 520 ? 2 : 1);
        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += perRow) {
          final slice = children.sublist(i, (i + perRow).clamp(0, children.length));
          if (rows.isNotEmpty) rows.add(SizedBox(height: gap));
          rows.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var j = 0; j < slice.length; j++) ...[
              if (j > 0) SizedBox(width: gap),
              Expanded(child: slice[j]),
            ],
            // Keep widths equal on a partial last row.
            for (var k = slice.length; k < perRow && children.length > perRow; k++) ...[
              SizedBox(width: gap),
              const Expanded(child: SizedBox()),
            ],
          ]));
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
      });
}

// ═════════════════════════════════════════════════════════════════════════════
//  Password strength
// ═════════════════════════════════════════════════════════════════════════════

/// 0 (empty) … 4 (strong).
int passwordStrength(String p) {
  if (p.isEmpty) return 0;
  var score = 0;
  if (p.length >= 8) score++;
  if (p.length >= 12) score++;
  if (RegExp(r'[a-z]').hasMatch(p) && RegExp(r'[A-Z]').hasMatch(p)) score++;
  if (RegExp(r'\d').hasMatch(p)) score++;
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) score++;
  return score.clamp(1, 4);
}

class PasswordStrengthMeter extends StatelessWidget {
  final String password;
  const PasswordStrengthMeter({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    final s = passwordStrength(password);
    const labels = ['', 'Weak', 'Fair', 'Good', 'Strong'];
    const colors = [AuthColors.border, AuthColors.red, AuthColors.orange, AuthColors.amber, AuthColors.greenMid];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [
        for (var i = 1; i <= 4; i++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 5,
              decoration: BoxDecoration(
                color: i <= s ? colors[s] : AuthColors.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          if (i < 4) const SizedBox(width: 5),
        ],
        const SizedBox(width: 10),
        SizedBox(
          width: 110,
          child: Text(
            s == 0 ? 'At least 6 characters' : labels[s],
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: s == 0 ? AuthColors.muted : colors[s]),
          ),
        ),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  Terms, buttons, banners
// ═════════════════════════════════════════════════════════════════════════════

/// "I agree to the Terms & Privacy Policy" as a validated form field.
class TermsField extends FormField<bool> {
  TermsField({super.key, required ValueChanged<bool> onChanged, required BuildContext context})
      : super(
          initialValue: false,
          validator: (v) => v == true ? null : 'Please accept the terms to continue',
          builder: (state) {
            final linkStyle = const TextStyle(
                color: AuthColors.green, fontWeight: FontWeight.w700, decoration: TextDecoration.underline);
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  state.didChange(!(state.value ?? false));
                  onChanged(state.value ?? false);
                },
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Checkbox(
                    value: state.value ?? false,
                    activeColor: AuthColors.green,
                    onChanged: (v) {
                      state.didChange(v ?? false);
                      onChanged(v ?? false);
                    },
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text.rich(TextSpan(
                        style: const TextStyle(color: AuthColors.ink, fontSize: 13.5, height: 1.4),
                        children: [
                          const TextSpan(text: 'I have read and agree to the '),
                          TextSpan(
                            text: 'Terms & Conditions',
                            style: linkStyle,
                            recognizer: TapGestureRecognizer()..onTap = () => Navigator.pushNamed(context, '/terms'),
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: linkStyle,
                            recognizer: TapGestureRecognizer()..onTap = () => Navigator.pushNamed(context, '/privacy'),
                          ),
                          const TextSpan(text: '.'),
                        ],
                      )),
                    ),
                  ),
                ]),
              ),
              if (state.hasError)
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 2),
                  child: Text(state.errorText!, style: const TextStyle(color: AuthColors.red, fontSize: 12)),
                ),
            ]);
          },
        );
}

class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final String busyLabel;
  final IconData icon;
  final bool busy;
  final VoidCallback? onPressed;
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.busyLabel,
    required this.icon,
    required this.busy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 52,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: onPressed == null && !busy
                  ? null
                  : const LinearGradient(colors: [AuthColors.green, AuthColors.teal]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: AuthColors.green.withValues(alpha: 0.28), blurRadius: 14, offset: const Offset(0, 6)),
              ],
            ),
            child: ElevatedButton(
              onPressed: busy ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                disabledBackgroundColor: busy ? Colors.transparent : Colors.grey.shade300,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: busy
                    ? Row(key: const ValueKey('busy'), mainAxisSize: MainAxisSize.min, children: [
                        const SizedBox(
                            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)),
                        const SizedBox(width: 12),
                        Text(busyLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ])
                    : Row(key: const ValueKey('idle'), mainAxisSize: MainAxisSize.min, children: [
                        Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 10),
                        Icon(icon, size: 20),
                      ]),
              ),
            ),
          ),
        ),
        if (isKeyboardPlatform)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('or press ', style: TextStyle(fontSize: 12, color: AuthColors.muted)),
              _KeyCap('Enter ↵'),
            ]),
          ),
      ]);
}

class _KeyCap extends StatelessWidget {
  final String text;
  const _KeyCap(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: const Color(0xFFCBD5E1)),
          boxShadow: const [BoxShadow(color: Color(0xFFCBD5E1), offset: Offset(0, 1.5))],
        ),
        child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AuthColors.ink)),
      );
}

class GoogleAuthButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const GoogleAuthButton({super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 50,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            side: const BorderSide(color: AuthColors.border, width: 1.2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const GoogleLogo(size: 20),
            const SizedBox(width: 12),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, color: AuthColors.ink, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      );
}

class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Row(children: [
          Expanded(child: Divider(color: AuthColors.border)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('or', style: TextStyle(color: AuthColors.muted, fontSize: 13)),
          ),
          Expanded(child: Divider(color: AuthColors.border)),
        ]),
      );
}

enum BannerTone { error, warning, success }

/// Inline message above the form (instead of a snackbar that vanishes).
class AuthErrorBanner extends StatelessWidget {
  final String? message;
  final BannerTone tone;
  const AuthErrorBanner({super.key, required this.message, this.tone = BannerTone.error});

  @override
  Widget build(BuildContext context) {
    final (color, bg, icon) = switch (tone) {
      BannerTone.error => (AuthColors.red, const Color(0xFFFFEBEE), Icons.error_outline_rounded),
      BannerTone.warning => (AuthColors.orange, const Color(0xFFFFF3E0), Icons.warning_amber_rounded),
      BannerTone.success => (AuthColors.greenMid, const Color(0xFFE8F5E9), Icons.check_circle_outline_rounded),
    };
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 18),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.35)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(message!, style: TextStyle(color: color, fontSize: 13.5, height: 1.35))),
              ]),
            ),
    );
  }
}

/// Section heading inside a longer form ("1 · About you").
class AuthSectionTitle extends StatelessWidget {
  final String step;
  final String title;
  final IconData icon;
  const AuthSectionTitle({super.key, required this.step, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12, top: 4),
        child: Row(children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [AuthColors.green, AuthColors.teal]), shape: BoxShape.circle),
            child: Text(step, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
          ),
          const SizedBox(width: 10),
          Icon(icon, size: 18, color: AuthColors.green),
          const SizedBox(width: 6),
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AuthColors.ink)),
        ]),
      );
}

// ═════════════════════════════════════════════════════════════════════════════
//  Validators & messages
// ═════════════════════════════════════════════════════════════════════════════

final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateEmail(String? v) =>
    v == null || !_emailRe.hasMatch(v.trim()) ? 'Enter a valid email address' : null;

/// Kenyan-friendly: 9–13 digits once spaces, dashes and "+" are removed
/// (07XX…, 01XX…, 2547XX…, 7XX…).
String? validatePhone(String? v) {
  final digits = (v ?? '').replaceAll(RegExp(r'[\s\-+()]'), '');
  if (digits.isEmpty) return 'Enter your phone number';
  if (!RegExp(r'^\d{9,13}$').hasMatch(digits)) return 'Enter a valid phone number, e.g. 0712 345 678';
  return null;
}

String? validateName(String? v) {
  final t = (v ?? '').trim();
  if (t.isEmpty) return 'Enter your full name';
  if (t.length < 3) return 'Enter your full name';
  return null;
}

/// Friendly text for Firebase Auth error codes.
String authErrorMessage(String code, [String? fallback]) => switch (code) {
      'user-not-found' => 'No account found with this email.',
      'wrong-password' || 'invalid-credential' || 'INVALID_LOGIN_CREDENTIALS' =>
        'The email or password is incorrect.',
      'invalid-email' => 'That email address is not valid.',
      'user-disabled' => 'This account has been disabled. Contact the administrator.',
      'too-many-requests' => 'Too many attempts. Please wait a few minutes and try again.',
      'network-request-failed' => 'No internet connection. Check your connection and try again.',
      'email-already-in-use' => 'An account already exists for this email. Sign in instead.',
      'weak-password' => 'That password is too weak — use at least 6 characters.',
      _ => fallback ?? 'Something went wrong. Please try again.',
    };
