// lib/screens/weather_comparison_screen.dart
//
// Weather forecast → "Compare with weather station": Google's weather and the
// farm's weather station side by side (WeatherComparisonService), for the
// station of the farm in view:
//   • Right now — Google | Station | Difference per measure
//   • How close they were over 24 h — average difference / gap per measure
//   • Hour by hour (last 24 h) — both RECORDED values for each hour
// "Download Excel" / "Download CSV" save it straight away as
// "Google to Weather station Comparison data --YYYY-MM-DD"
// (lib/utils/weather_comparison_export.dart).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kilimomkononi/services/weather_comparison.dart';
import 'package:kilimomkononi/utils/file_saver.dart';
import 'package:kilimomkononi/utils/friendly_error.dart';
import 'package:kilimomkononi/utils/weather_comparison_export.dart';

const _kDark = Color.fromARGB(255, 3, 39, 4);
const _kGoogle = Color(0xFF1A73E8);
const _kStation = Color(0xFF2E7D32);
const _kDiff = Color(0xFFE65100);
const _kPage = Color(0xFFF4F6F3);
const _kBorder = Color(0xFFE0E4DF);

class WeatherComparisonScreen extends StatefulWidget {
  /// Compare this station (default: the one for the farm in view).
  final String? stationId;
  const WeatherComparisonScreen({super.key, this.stationId});

  @override
  State<WeatherComparisonScreen> createState() => _WeatherComparisonScreenState();
}

class _WeatherComparisonScreenState extends State<WeatherComparisonScreen> {
  WeatherComparison? _data;
  String? _error;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await WeatherComparisonService.build(stationId: widget.stationId);
      if (mounted) setState(() => _data = d);
    } on NoStationForComparison catch (e) {
      if (mounted) setState(() => _error = '$e');
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e, 'Couldn\'t load the comparison'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _download({required bool excel}) async {
    final d = _data;
    if (d == null || _saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final base = comparisonFileBaseName(DateTime.now());
      final mime = excel ? kXlsxMime : kCsvMime;
      final saved = await saveFileForUser(
        excel ? buildComparisonXlsx(d) : buildComparisonCsv(d),
        '$base.${excel ? 'xlsx' : 'csv'}',
        mimeType: mime,
      );
      messenger.showSnackBar(SnackBar(
        backgroundColor: _kStation,
        duration: const Duration(seconds: 6),
        content: Text(saved.path == null ? 'Downloaded "${saved.fileName}"' : 'Saved "${saved.fileName}"'),
        action: saved.path == null
            ? null
            : SnackBarAction(
                label: 'Share',
                textColor: Colors.white,
                onPressed: () => shareSavedFile(saved, mimeType: mime, text: base),
              ),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e, 'Couldn\'t save the file'))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      backgroundColor: _kPage,
      appBar: AppBar(
        backgroundColor: _kDark,
        foregroundColor: Colors.white,
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Google vs. weather station', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          Text('Side by side · last 24 hours', style: TextStyle(fontSize: 11.5, color: Colors.white70)),
        ]),
        actions: [
          IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded), onPressed: _loading ? null : _load),
        ],
      ),
      body: _loading && d == null
          ? const Center(child: CircularProgressIndicator(color: _kStation))
          : _error != null && d == null
          ? _Message(_error!, onRetry: _load)
          : RefreshIndicator(
              color: _kStation,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _Header(d!),
                  const SizedBox(height: 12),
                  _DownloadBar(saving: _saving, onExcel: () => _download(excel: true), onCsv: () => _download(excel: false)),
                  const SizedBox(height: 16),
                  if (d.now != null) ...[
                    _SectionTitle('Right now', 'Station reading ${DateFormat('EEE d MMM · HH:mm').format(d.now!.time)}'),
                    _NowTable(d.now!),
                    const SizedBox(height: 18),
                  ],
                  const _SectionTitle('How close they were', 'Over the last 24 hours (station − Google)'),
                  _SummaryCards(d.summaries),
                  const SizedBox(height: 18),
                  _SectionTitle('Hour by hour', '${d.hourly.length} hours · recorded values from both'),
                  _HourlyTable(d.hourly),
                  const SizedBox(height: 14),
                  const _Legend(),
                ],
              ),
            ),
    );
  }
}

// ── Pieces ───────────────────────────────────────────────────────────────────

String _fmt(double? v) => v == null ? '—' : v.toStringAsFixed(1);
String _fmtDiff(double? v) => v == null ? '—' : '${v > 0 ? '+' : ''}${v.toStringAsFixed(1)}';

class _Message extends StatelessWidget {
  final String text;
  final VoidCallback onRetry;
  const _Message(this.text, {required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.compare_arrows_rounded, size: 46, color: Colors.black38),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, height: 1.4)),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
      ]),
    ),
  );
}

class _Header extends StatelessWidget {
  final WeatherComparison d;
  const _Header(this.d);

  Widget _side(IconData icon, String title, String subtitle, Color c) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: c),
          const SizedBox(width: 6),
          Flexible(child: Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: c))),
        ]),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(fontSize: 12, height: 1.3, color: Colors.black87)),
      ]),
    ),
  );

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _side(Icons.public_rounded, 'Google Weather', 'Area model for ${d.place}', _kGoogle),
        const SizedBox(width: 10),
        _side(Icons.sensors_rounded, 'Weather station', '${d.stationName} — measured on the farm', _kStation),
      ]),
    ),
    const SizedBox(height: 8),
    Text(
      'Generated ${DateFormat('EEE d MMM yyyy · HH:mm').format(d.generatedAt)}'
      '${d.usedFarmLocation ? ' · Google data for your farm\'s location' : ''}',
      style: const TextStyle(fontSize: 11.5, color: Colors.black54),
    ),
  ]);
}

class _DownloadBar extends StatelessWidget {
  final bool saving;
  final VoidCallback onExcel;
  final VoidCallback onCsv;
  const _DownloadBar({required this.saving, required this.onExcel, required this.onCsv});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _kBorder),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Download for analysis',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: _kDark)),
      Text(
        'Saved as "${comparisonFileBaseName(DateTime.now())}"',
        style: const TextStyle(fontSize: 11.5, color: Colors.black54),
      ),
      const SizedBox(height: 10),
      Wrap(spacing: 10, runSpacing: 8, children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: _kStation),
          onPressed: saving ? null : onExcel,
          icon: saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.table_view_rounded, size: 18),
          label: const Text('Download Excel'),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: _kStation),
          onPressed: saving ? null : onCsv,
          icon: const Icon(Icons.description_outlined, size: 18),
          label: const Text('Download CSV'),
        ),
      ]),
    ]),
  );
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionTitle(this.title, this.subtitle);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kDark)),
      Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
    ]),
  );
}

Widget _headCell(String text, Color c, {TextAlign align = TextAlign.center}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
  color: c,
  child: Text(text,
      textAlign: align, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
);

Widget _cell(String text, {Color? color, bool bold = false, TextAlign align = TextAlign.center, Color? bg}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
  color: bg,
  child: Text(text,
      textAlign: align,
      style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: color ?? Colors.black87)),
);

class _NowTable extends StatelessWidget {
  final ComparisonRow now;
  const _NowTable(this.now);

  @override
  Widget build(BuildContext context) {
    final rows = ComparedMetric.values.where((m) => now[m].google != null || now[m].station != null).toList();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _kBorder), borderRadius: BorderRadius.circular(12)),
        child: Table(
          columnWidths: const {0: FlexColumnWidth(1.6), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1), 3: FlexColumnWidth(1.1)},
          border: const TableBorder(horizontalInside: BorderSide(color: _kBorder)),
          children: [
            TableRow(children: [
              _headCell('Measure', _kDark, align: TextAlign.left),
              _headCell('Google', _kGoogle),
              _headCell('Station', _kStation),
              _headCell('Difference', _kDiff),
            ]),
            for (final (i, m) in rows.indexed)
              TableRow(
                decoration: BoxDecoration(color: i.isOdd ? const Color(0xFFF7F9F7) : Colors.white),
                children: [
                  _cell(m.heading, align: TextAlign.left, bold: true),
                  _cell(_fmt(now[m].google), color: _kGoogle),
                  _cell(_fmt(now[m].station), color: _kStation),
                  _cell(_fmtDiff(now[m].difference), color: _kDiff, bold: true, bg: const Color(0xFFFFF3E0)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  final List<MetricSummary> items;
  const _SummaryCards(this.items);

  @override
  Widget build(BuildContext context) => Wrap(spacing: 10, runSpacing: 10, children: [
    for (final m in items)
      Container(
        width: 160,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(m.metric.label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            m.pairs == 0 ? '—' : '${_fmtDiff(m.meanDifference)} ${m.metric.unit}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _kDiff),
          ),
          Text(
            m.pairs == 0
                ? 'No matching hours'
                : 'avg. gap ${_fmt(m.meanAbsDifference)} · max ${_fmt(m.maxAbsDifference)}\n${m.pairs} hours compared',
            style: const TextStyle(fontSize: 11, color: Colors.black54, height: 1.3),
          ),
        ]),
      ),
  ]);
}

class _HourlyTable extends StatelessWidget {
  final List<ComparisonRow> rows;
  const _HourlyTable(this.rows);

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Text('No hourly data from one or both sources for the last 24 hours.',
          style: TextStyle(color: Colors.black54));
    }
    const metrics = WeatherComparison.hourlyMetrics;
    final hourFmt = DateFormat('EEE HH:00');
    const w = 62.0;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const FixedColumnWidth(w),
          columnWidths: const {0: FixedColumnWidth(92)},
          border: const TableBorder(
            horizontalInside: BorderSide(color: _kBorder),
            verticalInside: BorderSide(color: Color(0xFFEFF2EF)),
          ),
          children: [
            // Metric bands
            TableRow(children: [
              _headCell('Hour', _kDark, align: TextAlign.left),
              for (final m in metrics) ...[
                _headCell(m.label, _kDark),
                _headCell(m.unit, _kDark),
                _headCell('', _kDark),
              ],
            ]),
            TableRow(children: [
              _headCell('', _kDark),
              for (var k = 0; k < metrics.length; k++) ...[
                _headCell('Google', _kGoogle),
                _headCell('Station', _kStation),
                _headCell('Diff.', _kDiff),
              ],
            ]),
            for (final (i, r) in rows.indexed)
              TableRow(
                decoration: BoxDecoration(color: i.isOdd ? const Color(0xFFF7F9F7) : Colors.white),
                children: [
                  _cell(hourFmt.format(r.time), align: TextAlign.left, bold: true),
                  for (final m in metrics) ...[
                    _cell(_fmt(r[m].google), color: _kGoogle),
                    _cell(_fmt(r[m].station), color: _kStation),
                    _cell(_fmtDiff(r[m].difference), color: _kDiff, bold: true, bg: const Color(0xFFFFF7EC)),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) => const Text(
    'Difference = Station − Google (positive = the station read higher). Wind in km/h for both. '
    'Google is a model for the area; the station measures your farm — advice and alerts use the station.',
    style: TextStyle(fontSize: 11.5, color: Colors.black54, height: 1.4),
  );
}
