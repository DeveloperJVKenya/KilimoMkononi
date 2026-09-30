// lib/settings/licenses_screen.dart
//
// About → Open-source licences: the packages Kilimo Mkononi is built with
// (from Flutter's LicenseRegistry), searchable, each opening its licence
// text.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kilimomkononi/settings/widgets/settings_kit.dart';

/// Package name → its licence texts (unit-tested helper).
Map<String, List<String>> groupLicenses(Iterable<(List<String>, String)> entries) {
  final out = <String, List<String>>{};
  for (final (packages, text) in entries) {
    for (final p in packages) {
      out.putIfAbsent(p, () => []).add(text);
    }
  }
  return Map.fromEntries(out.entries.toList()..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase())));
}

Future<Map<String, List<String>>> _loadLicenses() async {
  final entries = <(List<String>, String)>[];
  await for (final l in LicenseRegistry.licenses) {
    entries.add((l.packages.toList(), l.paragraphs.map((p) => p.text).join('\n\n')));
  }
  return groupLicenses(entries);
}

class LicensesScreen extends StatefulWidget {
  const LicensesScreen({super.key});

  @override
  State<LicensesScreen> createState() => _LicensesScreenState();
}

class _LicensesScreenState extends State<LicensesScreen> {
  late final Future<Map<String, List<String>>> _future = _loadLicenses();
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static const _colors = [
    Color(0xFF2E7D32),
    Color(0xFF1E88E5),
    Color(0xFF00897B),
    Color(0xFF8E24AA),
    Color(0xFFEF6C00),
    Color(0xFF3949AB),
  ];

  @override
  Widget build(BuildContext context) => SettingsPage(
        title: 'Open-source licences',
        subtitle: 'Software that makes Kilimo Mkononi possible',
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(colors: [Color(0xFF283593), Color(0xFF3949AB), Color(0xFF00897B)]),
            ),
            child: const Row(children: [
              Icon(Icons.favorite_rounded, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Kilimo Mkononi is built with Flutter, Firebase and many open-source packages. Thank you to their authors.',
                  style: TextStyle(color: Colors.white, height: 1.4),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search packages',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 14),
          FutureBuilder<Map<String, List<String>>>(
            future: _future,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
              }
              final q = _search.text.trim().toLowerCase();
              final items = snap.data!.entries.where((e) => q.isEmpty || e.key.toLowerCase().contains(q)).toList();
              return SettingsSection(
                title: '${items.length} packages',
                color: const Color(0xFF3949AB),
                children: [
                  for (var i = 0; i < items.length; i++)
                    SettingsTile(
                      icon: Icons.inventory_2_rounded,
                      color: _colors[i % _colors.length],
                      title: items[i].key,
                      value: '${items[i].value.length} licence${items[i].value.length == 1 ? '' : 's'}',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => _LicenseText(name: items[i].key, texts: items[i].value)),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      );
}

class _LicenseText extends StatelessWidget {
  final String name;
  final List<String> texts;
  const _LicenseText({required this.name, required this.texts});

  @override
  Widget build(BuildContext context) => SettingsPage(
        title: name,
        subtitle: 'Licence',
        maxWidth: 820,
        children: [
          for (final t in texts)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 10, offset: Offset(0, 3))],
              ),
              child: SelectableText(t, style: const TextStyle(fontSize: 13, height: 1.5, color: kSetInk)),
            ),
        ],
      );
}
