// lib/settings/widgets/legal_kit.dart
//
// Layout for the legal documents (Terms, Privacy): a readable card capped at
// 760 px, a contents list whose items jump to their section, a "back to top"
// button, and a contact footer. Sections are matched by their number
// ("10. Privacy" ↔ "10.  Privacy").

import 'package:flutter/material.dart';
import 'package:kilimomkononi/settings/contact_us_screen.dart';
import 'package:kilimomkononi/settings/widgets/settings_kit.dart';

String? legalNumber(String text) => RegExp(r'^\s*(\d+)\.').firstMatch(text)?.group(1);

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
  final List<Widget> children;
  const LegalScaffold({super.key, required this.title, required this.children, this.subtitle = 'Kilimo Mkononi'});

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
            onPressed: () =>
                _scroll.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic),
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
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: kSetBorder),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: widget.children),
                    ),
                    const SizedBox(height: 16),
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18), side: const BorderSide(color: kSetBorder)),
                        leading: const SettingsIcon(Icons.support_agent_rounded, color: Color(0xFFB26A00)),
                        title: const Text('Questions about this document?', style: TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: const Text('${KmContact.email} · ${KmContact.phone}'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.push(
                            context, MaterialPageRoute(builder: (_) => const ContactUsScreen(initialTopic: SupportTopic.account))),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}

/// Document title + reference line at the top of the card.
class LegalHeader extends StatelessWidget {
  final String title;
  const LegalHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) => Row(children: [
        const SettingsIcon(Icons.gavel_rounded),
        const SizedBox(width: 12),
        Expanded(
          child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kSetInk)),
        ),
      ]);
}

class LegalMeta extends StatelessWidget {
  final String text;
  const LegalMeta(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Wrap(spacing: 6, runSpacing: 6, children: [
        for (final part in text.split('|').map((s) => s.trim()).where((s) => s.isNotEmpty))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFEFF3EE), borderRadius: BorderRadius.circular(20)),
            child: Text(part, style: const TextStyle(color: kSetMuted, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
      ]);
}

class LegalSectionTitle extends StatelessWidget {
  final String title;
  const LegalSectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    final n = legalNumber(title);
    final label = n == null ? title : title.replaceFirst(RegExp(r'^\s*\d+\.\s*'), '');
    return KeyedSubtree(
      key: _LegalRegistry.of(context).keyFor(title),
      child: Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 12),
        child: Row(children: [
          if (n != null) ...[
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: kSetGreen, shape: BoxShape.circle),
              child: Text(n, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kSetInk)),
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
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _LegalRegistry.of(context).scrollTo(text),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Row(children: [
            Expanded(
              child: Text(text.replaceAll(RegExp(r'\s+'), ' '),
                  style: const TextStyle(fontSize: 14, color: kSetGreen, fontWeight: FontWeight.w600)),
            ),
            const Icon(Icons.arrow_downward_rounded, size: 16, color: kSetMuted),
          ]),
        ),
      );
}
