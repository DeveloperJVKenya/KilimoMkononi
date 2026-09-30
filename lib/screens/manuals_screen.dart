// lib/screens/manuals_screen.dart
//
// Farming manuals (PDFs in Firebase Storage `manuals/`):
//   • every manual listed at once, with search, crop filters (with counts)
//     and sort
//   • Read (in-app viewer on phones, new tab on web), Download (kept on the
//     phone for offline reading — no storage permission needed), copy link
//   • admins: upload (title + crop, progress shown) and delete

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

const _kGreen = Color(0xFF1B5E20);
const _kGreenDark = Color(0xFF0B3D1E);
const _kPage = Color(0xFFF4F6F3);
const _kInk = Color(0xFF1F2937);
const _kMuted = Color(0xFF6B7280);
const _kBorder = Color(0xFFE3E8E1);
const _kRed = Color(0xFFB3261E);

/// Crop key → (label, emoji). 'general' = not crop-specific.
const kManualCrops = <String, (String, String)>{
  'maize': ('Maize', '🌽'),
  'beans': ('Beans', '🌱'),
  'tomatoes': ('Tomatoes', '🍅'),
  'irish potatoes': ('Irish potatoes', '🥔'),
  'cabbage': ('Cabbage & kales', '🥬'),
  'carrots': ('Carrots', '🥕'),
  'onions': ('Onions', '🧅'),
  'general': ('General', '📘'),
};

String detectManualCrop(String name) {
  final n = name.toLowerCase();
  if (n.contains('bean')) return 'beans';
  if (n.contains('tomato')) return 'tomatoes';
  if (n.contains('carrot')) return 'carrots';
  if (n.contains('cabbage') || n.contains('kale') || n.contains('sukuma')) return 'cabbage';
  if (n.contains('onion')) return 'onions';
  if (n.contains('potato')) return 'irish potatoes';
  if (n.contains('maize') || n.contains('corn')) return 'maize';
  return 'general';
}

String manualTitleFromFile(String fileName) => fileName
    .replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '')
    .replaceAll(RegExp(r'[_-]+'), ' ')
    .split(' ')
    .where((w) => w.isNotEmpty)
    .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
    .join(' ');

String formatBytes(int? b) {
  if (b == null || b <= 0) return '';
  if (b < 1024 * 1024) return '${(b / 1024).round()} KB';
  return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
}

@immutable
class Manual {
  final String title;
  final String fileName; // without the upload timestamp prefix
  final String fullPath;
  final String url;
  final DateTime? uploadedAt;
  final String crop;
  final int? sizeBytes;
  final String uploadedBy;
  const Manual({
    required this.title,
    required this.fileName,
    required this.fullPath,
    required this.url,
    required this.crop,
    this.uploadedAt,
    this.sizeBytes,
    this.uploadedBy = 'Kilimo Mkononi',
  });
}

enum ManualSort { newest, title }

/// Filter + sort (unit-tested).
List<Manual> filterManuals(List<Manual> all, {String? crop, String query = '', ManualSort sort = ManualSort.newest}) {
  final q = query.trim().toLowerCase();
  final out = all
      .where(
        (m) =>
            (crop == null || m.crop == crop) &&
            (q.isEmpty || m.title.toLowerCase().contains(q) || m.fileName.toLowerCase().contains(q)),
      )
      .toList();
  out.sort(
    (a, b) => switch (sort) {
      ManualSort.newest => (b.uploadedAt ?? DateTime(1970)).compareTo(a.uploadedAt ?? DateTime(1970)),
      ManualSort.title => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    },
  );
  return out;
}

// ── Providers ────────────────────────────────────────────────────────────────

final manualsProvider = FutureProvider<List<Manual>>((ref) async {
  final result = await FirebaseStorage.instance.ref('manuals').listAll();
  final items = await Future.wait(
    result.items.map((item) async {
      try {
        final (url, meta) = await (item.getDownloadURL(), item.getMetadata()).wait;
        final clean = item.name.contains('_') && RegExp(r'^\d+_').hasMatch(item.name)
            ? item.name.substring(item.name.indexOf('_') + 1)
            : item.name;
        final custom = meta.customMetadata ?? const {};
        final crop = custom['category'];
        return Manual(
          title: (custom['title'] ?? '').trim().isNotEmpty ? custom['title']!.trim() : manualTitleFromFile(clean),
          fileName: clean,
          fullPath: item.fullPath,
          url: url,
          uploadedAt: meta.timeCreated,
          crop: kManualCrops.containsKey(crop) ? crop! : detectManualCrop(clean),
          sizeBytes: meta.size,
          uploadedBy: custom['uploadedBy'] ?? 'Kilimo Mkononi',
        );
      } catch (_) {
        return null;
      }
    }),
  );
  return items.whereType<Manual>().toList();
});

final manualAdminProvider = FutureProvider.autoDispose<bool>((ref) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return false;
  try {
    return (await FirebaseFirestore.instance.collection('Admins').doc(uid).get()).exists;
  } catch (_) {
    return false;
  }
});

bool get _canSaveOffline => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

Future<String> _offlinePath(String fileName) async {
  final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/manuals');
  if (!await dir.exists()) await dir.create(recursive: true);
  return '${dir.path}/$fileName';
}

/// File names of manuals saved on this phone.
final savedManualsProvider = FutureProvider.autoDispose<Set<String>>((ref) async {
  if (!_canSaveOffline) return const {};
  final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/manuals');
  if (!await dir.exists()) return const {};
  return dir.listSync().whereType<File>().map((f) => f.uri.pathSegments.last).toSet();
});

// ── Screen ───────────────────────────────────────────────────────────────────

class ManualsScreen extends ConsumerStatefulWidget {
  /// True when shown as a Home tab (under the Home app bar).
  final bool embedded;
  const ManualsScreen({super.key, this.embedded = false});

  @override
  ConsumerState<ManualsScreen> createState() => _ManualsScreenState();
}

class _ManualsScreenState extends ConsumerState<ManualsScreen> {
  final _search = TextEditingController();
  String? _crop;
  ManualSort _sort = ManualSort.newest;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _read(Manual m) async {
    if (!_canSaveOffline) {
      await launchUrl(Uri.parse(m.url), mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
      return;
    }
    final path = await _offlinePath(m.fileName);
    if (!await File(path).exists()) {
      final ok = await _downloadWithProgress(m, path, reason: 'Opening');
      if (!ok) return;
    }
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PDFViewerScreen(filePath: path, fileName: m.title),
      ),
    );
  }

  Future<void> _download(Manual m) async {
    if (!_canSaveOffline) {
      await launchUrl(Uri.parse(m.url), mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
      return;
    }
    final path = await _offlinePath(m.fileName);
    if (await File(path).exists()) {
      await OpenFile.open(path);
      return;
    }
    if (await _downloadWithProgress(m, path, reason: 'Downloading') && mounted) {
      _snack('Saved — "${m.title}" is now available offline');
    }
  }

  Future<void> _removeOffline(Manual m) async {
    final f = File(await _offlinePath(m.fileName));
    if (await f.exists()) await f.delete();
    ref.invalidate(savedManualsProvider);
    if (mounted) _snack('Removed from this phone');
  }

  Future<bool> _downloadWithProgress(Manual m, String path, {required String reason}) async {
    final progress = ValueNotifier<double?>(null);
    final cancel = CancelToken();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('$reason manual'),
        content: ValueListenableBuilder<double?>(
          valueListenable: progress,
          builder: (_, p, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(m.title, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 14),
              LinearProgressIndicator(value: p, color: _kGreen, minHeight: 6, borderRadius: BorderRadius.circular(3)),
              const SizedBox(height: 8),
              Text(
                p == null ? 'Starting…' : '${(p * 100).round()}% of ${formatBytes(m.sizeBytes)}',
                style: const TextStyle(color: _kMuted),
              ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => cancel.cancel(), child: const Text('Cancel'))],
      ),
    );
    try {
      await Dio().download(
        m.url,
        path,
        cancelToken: cancel,
        onReceiveProgress: (r, t) {
          if (t > 0) progress.value = r / t;
        },
      );
      ref.invalidate(savedManualsProvider);
      return true;
    } catch (e) {
      final f = File(path);
      if (await f.exists()) await f.delete();
      if (mounted && !(e is DioException && CancelToken.isCancel(e))) {
        _snack('Couldn\'t download — check your connection');
      }
      return false;
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      progress.dispose();
    }
  }

  Future<void> _delete(Manual m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this manual?'),
        content: Text('"${m.title}" will be removed for everyone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kRed),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await FirebaseStorage.instance.ref(m.fullPath).delete();
      ref.invalidate(manualsProvider);
      if (mounted) _snack('Manual deleted');
    } catch (e) {
      if (mounted) _snack('Couldn\'t delete: $e');
    }
  }

  void _actions(Manual m, {required bool saved, required bool admin}) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chrome_reader_mode_rounded, color: _kGreen),
              title: const Text('Read'),
              onTap: () {
                Navigator.pop(ctx);
                _read(m);
              },
            ),
            ListTile(
              leading: Icon(saved ? Icons.folder_open_rounded : Icons.download_rounded, color: _kGreen),
              title: Text(saved ? 'Open saved copy' : (_canSaveOffline ? 'Save for offline reading' : 'Download PDF')),
              onTap: () {
                Navigator.pop(ctx);
                _download(m);
              },
            ),
            if (saved)
              ListTile(
                leading: const Icon(Icons.delete_sweep_rounded),
                title: const Text('Remove from this phone'),
                onTap: () {
                  Navigator.pop(ctx);
                  _removeOffline(m);
                },
              ),
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: const Text('Copy link to share'),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: m.url));
                _snack('Link copied');
              },
            ),
            if (admin)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: _kRed),
                title: const Text('Delete manual', style: TextStyle(color: _kRed)),
                onTap: () {
                  Navigator.pop(ctx);
                  _delete(m);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(manualsProvider);
    final admin = ref.watch(manualAdminProvider).value ?? false;
    final saved = ref.watch(savedManualsProvider).value ?? const <String>{};

    return Scaffold(
      backgroundColor: _kPage,
      appBar: widget.embedded
          ? null
          : AppBar(
              foregroundColor: Colors.white,
              iconTheme: const IconThemeData(color: Colors.white),
              flexibleSpace: Container(
                decoration: const BoxDecoration(gradient: LinearGradient(colors: [_kGreenDark, _kGreen])),
              ),
              title: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Farming manuals', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                  Text(
                    'Guides from research institutes and experts',
                    style: TextStyle(fontSize: 11.5, color: Colors.white70),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () => ref.invalidate(manualsProvider),
                ),
              ],
            ),
      floatingActionButton: admin
          ? FloatingActionButton.extended(
              backgroundColor: _kGreen,
              foregroundColor: Colors.white,
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => const _UploadSheet(),
              ),
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Upload manual'),
            )
          : null,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _kGreen)),
        error: (e, _) => _Message(
          icon: Icons.cloud_off_rounded,
          title: 'Couldn\'t load the manuals',
          text: 'Check your internet connection and try again.',
          action: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: _kGreen),
            onPressed: () => ref.invalidate(manualsProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ),
        data: (all) {
          final counts = <String, int>{};
          for (final m in all) {
            counts[m.crop] = (counts[m.crop] ?? 0) + 1;
          }
          final shown = filterManuals(all, crop: _crop, query: _search.text, sort: _sort);
          return RefreshIndicator(
            color: _kGreen,
            onRefresh: () => ref.refresh(manualsProvider.future),
            child: LayoutBuilder(
              builder: (context, c) {
                final side = c.maxWidth > 1132 ? (c.maxWidth - 1100) / 2 : 16.0;
                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(side, 16, side, 0),
                      sliver: SliverList.list(
                        children: [
                          TextField(
                            controller: _search,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: 'Search manuals',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _search.text.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Clear',
                                      icon: const Icon(Icons.close_rounded),
                                      onPressed: () => setState(_search.clear),
                                    ),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: _kBorder),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: _kBorder),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 40,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                _CropChip(
                                  label: 'All · ${all.length}',
                                  selected: _crop == null,
                                  onTap: () => setState(() => _crop = null),
                                ),
                                for (final e in kManualCrops.entries)
                                  if ((counts[e.key] ?? 0) > 0)
                                    _CropChip(
                                      label: '${e.value.$2} ${e.value.$1} · ${counts[e.key]}',
                                      selected: _crop == e.key,
                                      onTap: () => setState(() => _crop = _crop == e.key ? null : e.key),
                                    ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${shown.length} manual${shown.length == 1 ? '' : 's'}'
                                  '${saved.isEmpty ? '' : ' · ${saved.length} saved offline'}',
                                  style: const TextStyle(color: _kMuted, fontWeight: FontWeight.w700, fontSize: 12.5),
                                ),
                              ),
                              PopupMenuButton<ManualSort>(
                                tooltip: 'Sort',
                                onSelected: (s) => setState(() => _sort = s),
                                itemBuilder: (_) => [
                                  CheckedPopupMenuItem(
                                    value: ManualSort.newest,
                                    checked: _sort == ManualSort.newest,
                                    child: const Text('Newest first'),
                                  ),
                                  CheckedPopupMenuItem(
                                    value: ManualSort.title,
                                    checked: _sort == ManualSort.title,
                                    child: const Text('Title A–Z'),
                                  ),
                                ],
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.sort_rounded, size: 18, color: _kMuted),
                                      const SizedBox(width: 4),
                                      Text(
                                        _sort == ManualSort.newest ? 'Newest' : 'A–Z',
                                        style: const TextStyle(
                                          color: _kInk,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    if (shown.isEmpty)
                      SliverToBoxAdapter(
                        child: _Message(
                          icon: all.isEmpty ? Icons.menu_book_rounded : Icons.search_off_rounded,
                          title: all.isEmpty ? 'No manuals yet' : 'No manuals match',
                          text: all.isEmpty
                              ? (admin
                                    ? 'Tap "Upload manual" to add the first one.'
                                    : 'New guides will appear here soon.')
                              : 'Try another crop or search word.',
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(side, 0, side, admin ? 96 : 32),
                        sliver: SliverGrid(
                          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 540,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            mainAxisExtent: 166 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.35),
                          ),
                          delegate: SliverChildBuilderDelegate((_, i) {
                            final m = shown[i];
                            final isSaved = saved.contains(m.fileName);
                            return _ManualCard(
                              manual: m,
                              saved: isSaved,
                              onRead: () => _read(m),
                              onDownload: () => _download(m),
                              onMore: () => _actions(m, saved: isSaved, admin: admin),
                            );
                          }, childCount: shown.length),
                        ),
                      ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _CropChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CropChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: _kGreen,
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? _kGreen : _kBorder),
      labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: selected ? Colors.white : _kInk),
    ),
  );
}

class _ManualCard extends StatelessWidget {
  final Manual manual;
  final bool saved;
  final VoidCallback onRead;
  final VoidCallback onDownload;
  final VoidCallback onMore;
  const _ManualCard({
    required this.manual,
    required this.saved,
    required this.onRead,
    required this.onDownload,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final m = manual;
    final (cropLabel, emoji) = kManualCrops[m.crop] ?? ('General', '📘');
    final meta = [
      if (m.uploadedAt != null) DateFormat('d MMM yyyy').format(m.uploadedAt!),
      if (formatBytes(m.sizeBytes).isNotEmpty) formatBytes(m.sizeBytes),
    ].join(' · ');
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onRead,
        onLongPress: onMore,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 6, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _kBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 50,
                      height: 62,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDECEA),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFF5C6C2)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 20)),
                          const Text(
                            'PDF',
                            style: TextStyle(color: _kRed, fontSize: 10.5, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                              color: _kInk,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _kMuted, fontSize: 12),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _Tag(cropLabel, _kGreen),
                              if (saved)
                                const _Tag('Saved offline', Color(0xFF1565C0), icon: Icons.offline_pin_rounded),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'More options',
                      icon: const Icon(Icons.more_vert_rounded, color: _kMuted),
                      onPressed: onMore,
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFDDEFDF),
                        foregroundColor: _kGreen,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: onRead,
                      icon: const Icon(Icons.chrome_reader_mode_rounded, size: 18),
                      label: const Text('Read'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: _kGreen, visualDensity: VisualDensity.compact),
                      onPressed: onDownload,
                      icon: Icon(saved ? Icons.folder_open_rounded : Icons.download_rounded, size: 18),
                      label: Text(saved ? 'Open file' : 'Download'),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const _Tag(this.label, this.color, {this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 3)],
        Text(
          label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final Widget? action;
  const _Message({required this.icon, required this.title, required this.text, this.action});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(color: Color(0xFFE8F5E9), shape: BoxShape.circle),
          child: Icon(icon, size: 36, color: _kGreen),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _kMuted, height: 1.4),
        ),
        if (action != null) ...[const SizedBox(height: 14), action!],
      ],
    ),
  );
}

// ── Admin upload ─────────────────────────────────────────────────────────────

class _UploadSheet extends ConsumerStatefulWidget {
  const _UploadSheet();

  @override
  ConsumerState<_UploadSheet> createState() => _UploadSheetState();
}

class _UploadSheetState extends ConsumerState<_UploadSheet> {
  final _title = TextEditingController();
  String _crop = 'general';
  PlatformFile? _file;
  int _fileSize = 0;
  double? _progress;
  bool _uploading = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    // file_picker 13: static pickFile(); bytes/size are read on demand.
    final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['pdf']);
    if (f == null) return;
    final size = await f.length() ?? 0;
    setState(() {
      _file = f;
      _fileSize = size;
      _error = null;
      if (_title.text.trim().isEmpty) _title.text = manualTitleFromFile(f.name);
      if (_crop == 'general') _crop = detectManualCrop(f.name);
    });
  }

  Future<void> _upload() async {
    final f = _file;
    if (f == null || _uploading) return;
    if (_fileSize > 50 * 1024 * 1024) {
      setState(() => _error = 'The file must be smaller than 50 MB');
      return;
    }
    setState(() {
      _uploading = true;
      _progress = 0;
      _error = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final storageRef = FirebaseStorage.instance.ref('manuals/${DateTime.now().millisecondsSinceEpoch}_${f.name}');
      final meta = SettableMetadata(
        contentType: 'application/pdf',
        customMetadata: {
          'title': _title.text.trim().isEmpty ? manualTitleFromFile(f.name) : _title.text.trim(),
          'category': _crop,
          'uploadedBy': user.displayName?.isNotEmpty == true ? user.displayName! : 'Kilimo Mkononi',
        },
      );
      final task = kIsWeb || f.path == null
          ? storageRef.putData(await f.readAsBytes(), meta)
          : storageRef.putFile(File(f.path!), meta);
      task.snapshotEvents.listen((s) {
        if (s.totalBytes > 0 && mounted) setState(() => _progress = s.bytesTransferred / s.totalBytes);
      }, onError: (_) {});
      await task;
      ref.invalidate(manualsProvider);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Manual uploaded'), backgroundColor: _kGreen));
    } catch (e) {
      setState(() => _error = 'Upload failed: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Upload a manual', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('PDF, up to 50 MB. Farmers see it straight away.', style: TextStyle(color: _kMuted)),
              const SizedBox(height: 16),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!, style: const TextStyle(color: _kRed)),
                ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  foregroundColor: _kGreen,
                ),
                onPressed: _uploading ? null : _pick,
                icon: Icon(_file == null ? Icons.attach_file_rounded : Icons.picture_as_pdf_rounded),
                label: Text(
                  _file == null ? 'Choose PDF file' : '${_file!.name} · ${formatBytes(_fileSize)}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Title farmers will see',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _crop,
                decoration: InputDecoration(
                  labelText: 'Crop',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                items: [
                  for (final e in kManualCrops.entries)
                    DropdownMenuItem(value: e.key, child: Text('${e.value.$2}  ${e.value.$1}')),
                ],
                onChanged: _uploading ? null : (v) => setState(() => _crop = v ?? _crop),
              ),
              if (_uploading) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: _progress,
                  color: _kGreen,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(height: 6),
                Text('${((_progress ?? 0) * 100).round()}% uploaded', style: const TextStyle(color: _kMuted)),
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _kGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _file == null || _uploading ? null : _upload,
                icon: const Icon(Icons.cloud_upload_rounded),
                label: Text(_uploading ? 'Uploading…' : 'Upload'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ── PDF viewer (phones) ──────────────────────────────────────────────────────

class PDFViewerScreen extends StatefulWidget {
  final String filePath;
  final String fileName;
  const PDFViewerScreen({super.key, required this.filePath, required this.fileName});

  @override
  State<PDFViewerScreen> createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends State<PDFViewerScreen> {
  int _page = 0;
  int _pages = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
      backgroundColor: _kGreen,
      title: Text(widget.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [
        IconButton(
          tooltip: 'Open in another app',
          icon: const Icon(Icons.open_in_new_rounded),
          onPressed: () => OpenFile.open(widget.filePath),
        ),
      ],
    ),
    body: SafeArea(
      child: Stack(
        children: [
          PDFView(
            filePath: widget.filePath,
            onRender: (n) => setState(() => _pages = n ?? 0),
            onPageChanged: (p, n) => setState(() {
              _page = p ?? 0;
              _pages = n ?? _pages;
            }),
          ),
          if (_pages > 0)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    'Page ${_page + 1} of $_pages',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
