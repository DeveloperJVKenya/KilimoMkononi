// lib/settings/widgets/legal_kit.dart
//
// Layout for the legal documents (Terms, Privacy). The screens keep their
// text; this lays it out as: a coloured title header (with the document's
// reference chips), a contents card whose entries jump to their section, and
// one card per numbered section with a coloured number badge. A "back to
// top" button and a contact card finish the page. Sections are matched by
// number ("10. Privacy" ↔ "10.  Privacy").

import 'package:flutter/material.dart';
import 'package:kilimomkononi/settings/contact_us_screen.dart';
import 'package:kilimomkononi/settings/widgets/settings_kit.dart';

String? legalNumber(String text) => RegExp(r'^\s*(\d+)\.').firstMatch(text)?.group(1);

/// Colour for section [n] (cycles).
Color legalColor(String? n) {
  const palette = [
    Color(0xFF2E7D32),
    Color(0xFF1E88E5),
    Color(0xFF00897B),
    Color(0xFF8E24AA),
    Color(0xFFEF6C00),
    Color(0xFF3949AB),
    Color(0xFFD81B60),
    Color(0xFF6D4C41),
  ];
  final i = int.tryParse(n ?? '') ?? 0;
  return palette[i % palette.length];
}

class _LegalRegistry extends InheritedWidget {
  final Map<String, GlobalKey> keys;
  const _LegalRegistry({required this.keys, required super.child});

  GlobalKey keyFor(String title) => keys.putIfAbsent(legalNumber(title) ?? title, GlobalKey.new);

  void scrollTo(String tocText) {
    final ctx = keys[legalNumber(tocText) ?? tocText]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic, alignment: 0.02);
    }
  }

  static _LegalRegistry of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_LegalRegistry>()!;

  @override
  bool updateShouldNotify(_LegalRegistry old) => false;
}

class LegalScaffold extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;
  const LegalScaffold({
    super.key,
    required this.title,
    required this.children,
    this.subtitle = 'Kilimo Mkononi',
    this.icon = Icons.gavel_rounded,
  });

  @override
  State<LegalScaffold> createState() => _LegalScaffoldState();
}

class _LegalScaffoldState extends State<LegalScaffold> {
  final _keys = <String, GlobalKey>{};
  final _scroll = ScrollController();
  bool _showTop = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final show = _scroll.offset > 600;
      if (show != _showTop) setState(() => _showTop = show);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Splits the flat document into intro / contents / numbered sections.
  List<Widget> _layout() {
    String? meta;
    final intro = <Widget>[];
    final groups = <(LegalSectionTitle, List<Widget>)>[];
    for (final w in widget.children) {
      if (w is LegalHeader) continue; // shown in the header band
      if (w is LegalMeta) {
        meta = w.text;
        continue;
      }
      if (w is LegalSectionTitle) {
        groups.add((w, <Widget>[]));
      } else if (groups.isEmpty) {
        intro.add(w);
      } else {
        groups.last.$2.add(w);
      }
    }
    // Spacers between sections are replaced by the card gaps.
    List<Widget> trim(List<Widget> l) {
      final out = [...l];
      while (out.isNotEmpty && out.last is SizedBox && (out.last as SizedBox).child == null) {
        out.removeLast();
      }
      while (out.isNotEmpty && out.first is SizedBox && (out.first as SizedBox).child == null) {
        out.removeAt(0);
      }
      return out;
    }

    return [
      _Hero(title: widget.title, icon: widget.icon, meta: meta),
      if (trim(intro).isNotEmpty) ...[
        const SizedBox(height: 14),
        _Card(color: kSetGreen, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: trim(intro))),
      ],
      for (final (title, body) in groups) ...[
        const SizedBox(height: 14),
        if (legalNumber(title.title) == null)
          _Card(
            color: const Color(0xFF5E35B1),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const SettingsIcon(Icons.list_alt_rounded, color: Color(0xFF5E35B1)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kSetInk)),
                    const Text('Tap a section to jump to it', style: TextStyle(color: kSetMuted, fontSize: 12)),
                  ]),
                ),
              ]),
              const SizedBox(height: 8),
              ...trim(body),
            ]),
          )
        else
          _Card(
            color: legalColor(legalNumber(title.title)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, ...trim(body)]),
          ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kSetPage,
        appBar: AppBar(
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [kSetGreenDark, kSetGreen])),
          ),
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            Text(widget.subtitle, style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
          ]),
        ),
        floatingActionButton: AnimatedScale(
          scale: _showTop ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: FloatingActionButton.small(
            tooltip: 'Back to top',
            backgroundColor: kSetGreen,
            foregroundColor: Colors.white,
            onPressed: () => _scroll.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic),
            child: const Icon(Icons.vertical_align_top_rounded),
          ),
        ),
        body: _LegalRegistry(
          keys: _keys,
          child: Scrollbar(
            controller: _scroll,
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 780),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    ..._layout(),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(colors: [Color(0xFFFFF4E0), Color(0xFFFFE6C2)]),
                      ),
                      child: Row(children: [
                        const CircleAvatar(
                          radius: 22,
                          backgroundColor: Color(0xFFB26A00),
                          child: Icon(Icons.support_agent_rounded, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Questions about this document?',
                                style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF7A4A00))),
                            Text('${KmContact.email} · ${KmContact.phone}',
                                style: TextStyle(color: Color(0xFF7A4A00), fontSize: 12.5)),
                          ]),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB26A00)),
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ContactUsScreen(initialTopic: SupportTopic.account))),
                          child: const Text('Ask us'),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}

class _Hero extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? meta;
  const _Hero({required this.title, required this.icon, this.meta});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
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
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            ),
          ]),
          if (meta != null) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final part in meta!.split('|').map((s) => s.trim()).where((s) => s.isNotEmpty))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
                  child: Text(part, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
            ]),
          ],
        ]),
      );
}

/// A white section card with a coloured accent strip.
class _Card extends StatelessWidget {
  final Color color;
  final Widget child;
  const _Card({required this.color, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 5, color: color),
            Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: child)),
          ]),
        ),
      );
}

/// Document title (shown in the header band by [LegalScaffold]).
class LegalHeader extends StatelessWidget {
  final String title;
  const LegalHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) => Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900));
}

/// Reference line ("Last Updated | Ref | Version"), shown as header chips.
class LegalMeta extends StatelessWidget {
  final String text;
  const LegalMeta(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(color: kSetMuted, fontSize: 12));
}

class LegalSectionTitle extends StatelessWidget {
  final String title;
  const LegalSectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    final n = legalNumber(title);
    final label = n == null ? title : title.replaceFirst(RegExp(r'^\s*\d+\.\s*'), '');
    final color = legalColor(n);
    return KeyedSubtree(
      key: _LegalRegistry.of(context).keyFor(title),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          if (n != null) ...[
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(11)),
              child: Text(n, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: n == null ? kSetInk : color)),
          ),
        ]),
      ),
    );
  }
}

class LegalTocItem extends StatelessWidget {
  final String text;
  const LegalTocItem(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final n = legalNumber(text);
    final label = text.replaceFirst(RegExp(r'^\s*\d+\.\s*'), '').replaceAll(RegExp(r'\s+'), ' ');
    final color = legalColor(n);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _LegalRegistry.of(context).scrollTo(text),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
            child: Row(children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                child: Text(n ?? '•', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(n == null ? text : label,
                    style: const TextStyle(fontSize: 14, color: kSetInk, fontWeight: FontWeight.w600)),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: color),
            ]),
          ),
        ),
      ),
    );
  }
}
