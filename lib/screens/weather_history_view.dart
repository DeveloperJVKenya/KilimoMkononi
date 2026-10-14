// lib/screens/weather_history_view.dart
//
// Weather comparison → "Past dates": a weather station's recorded data next
// to NASA POWER satellite data for any past dates the station has
// (WeatherHistoryService):
//   • station picker (Field Agronomists / admins: every KM station)
//   • dates: last 7 / 30 / 90 days, or custom From / To dates with a clear
//     "Compare these dates" button (limited to the days the station has
//     recorded since it went into service)
//   • live: a range ending today shows up to the latest recorded hour and
//     refreshes every 5 minutes
//   • hour by hour (up to 31 days) or day by day
//   • how close they were, the rows, and Excel / CSV downloads of exactly
//     the dates and view chosen ("Station to Satellite Comparison data
//     --<start>_to_<end>")

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kilimomkononi/services/farm_location_service.dart';
import 'package:kilimomkononi/services/nuasense_service.dart';
import 'package:kilimomkononi/services/weather_comparison.dart' show ComparedMetric;
import 'package:kilimomkononi/services/weather_history_comparison.dart';
import 'package:kilimomkononi/utils/file_saver.dart';
import 'package:kilimomkononi/utils/friendly_error.dart';
import 'package:kilimomkononi/utils/weather_comparison_export.dart' show kCsvMime, kXlsxMime;
import 'package:kilimomkononi/utils/weather_history_export.dart';

const _kDark = Color.fromARGB(255, 3, 39, 4);
const _kStation = Color(0xFF2E7D32);
const _kSatellite = Color(0xFF6A1B9A);
const _kDiff = Color(0xFFE65100);
const _kBorder = Color(0xFFE0E4DF);

/// Rows shown at a time on screen (downloads always have every row).
const _kPage = 168;

/// How often a range that ends today is refreshed.
const _kLiveEvery = Duration(minutes: 5);

enum _Preset {
  week('Last 7 days', 7),
  month('Last 30 days', 30),
  quarter('Last 90 days', 90),
  custom('Custom dates', 0);

  final String label;
  final int days;
  const _Preset(this.label, this.days);
}

class WeatherHistoryView extends StatefulWidget {
  final String? stationId;

  /// Field Agronomists / admins: any Kilimo Mkononi station.
  final bool allStations;
  const WeatherHistoryView({super.key, this.stationId, this.allStations = false});

  @override
  State<WeatherHistoryView> createState() => _WeatherHistoryViewState();
}

class _WeatherHistoryViewState extends State<WeatherHistoryView> with AutomaticKeepAliveClientMixin {
  List<NuaStation> _stations = [];
  String? _stationId;
  StationHistoryRange? _range;
  _Preset _preset = _Preset.week;
  DateTimeRange? _dates;
  HistoryResolution _resolution = HistoryResolution.hourly;
  HistoryComparison? _data;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  int _shown = _kPage;
  int _request = 0;

  // Custom dates being chosen (applied with "Compare these dates").
  DateTime? _from;
  DateTime? _to;
  Timer? _live;
  DateTime? _refreshedAt;

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  /// The range ends today → keep it current.
  bool get _isLive => _dates != null && !_dates!.end.isBefore(_today);

  void _armLive() {
    _live?.cancel();
    if (_isLive) _live = Timer.periodic(_kLiveEvery, (_) => _fetch(silent: true));
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stations = await NuaSenseService.getStations(allStations: widget.allStations);
      if (!mounted) return;
      if (stations.isEmpty) {
        setState(() {
          _loading = false;
          _error = widget.allStations
              ? 'No Kilimo Mkononi weather stations are connected yet.'
              : 'Your account isn\'t connected to a weather station yet, so there is no past data to compare.';
        });
        return;
      }
      final id = stations.any((s) => s.id == widget.stationId) ? widget.stationId! : stations.first.id;
      setState(() {
        _stations = stations;
        _stationId = id;
      });
      await _loadRange();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = friendlyError(e, 'Couldn\'t load the weather stations');
        });
      }
    }
  }

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _loadRange() async {
    final id = _stationId;
    if (id == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await WeatherHistoryService.range(id, allStations: widget.allStations);
      if (!mounted) return;
      setState(() => _range = r);
      _applyPreset(_preset == _Preset.custom ? _Preset.week : _preset);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = friendlyError(e, 'Couldn\'t check which dates this station has');
        });
      }
    }
  }

  void _applyPreset(_Preset p) {
    final r = _range;
    if (r == null) return;
    if (p == _Preset.custom) {
      // Show the From / To fields, starting from the dates in view.
      setState(() {
        _preset = _Preset.custom;
        _from = _dates?.start ?? r.first;
        _to = _dates?.end ?? r.last;
      });
      return;
    }
    final end = r.last;
    var start = end.subtract(Duration(days: p.days - 1));
    if (start.isBefore(r.first)) start = r.first;
    _setDates(DateTimeRange(start: start, end: end), p);
  }

  void _setDates(DateTimeRange d, _Preset p) {
    final days = d.end.difference(d.start).inDays + 1;
    setState(() {
      _preset = p;
      _dates = DateTimeRange(start: _dayOnly(d.start), end: _dayOnly(d.end));
      // Long ranges are read day by day; hour by hour only up to 31 days.
      if (days > kMaxHourlyDays) _resolution = HistoryResolution.daily;
      if (days <= 2) _resolution = HistoryResolution.hourly;
    });
    _armLive();
    _fetch();
  }

  Future<DateTime?> _pickDay(DateTime? initial, {required String help}) async {
    final r = _range;
    if (r == null) return null;
    var init = initial ?? r.last;
    if (init.isBefore(r.first)) init = r.first;
    if (init.isAfter(r.last)) init = r.last;
    return showDatePicker(
      context: context,
      firstDate: r.first,
      lastDate: r.last,
      initialDate: init,
      helpText: help,
    );
  }

  /// Why the custom dates can't be compared yet (null = they can).
  String? get _customProblem {
    final r = _range;
    final a = _from;
    final b = _to;
    if (r == null || a == null || b == null) return 'Pick a start and an end date.';
    if (b.isBefore(a)) return 'The end date is before the start date.';
    final days = b.difference(a).inDays + 1;
    if (days > r.maxSpanDays) return 'Pick at most ${r.maxSpanDays} days at a time.';
    return null;
  }

  void _compareCustom() {
    if (_customProblem != null) return;
    _setDates(DateTimeRange(start: _from!, end: _to!), _Preset.custom);
  }

  /// [silent]: a live refresh — keep showing the current data meanwhile.
  Future<void> _fetch({bool silent = false}) async {
    final id = _stationId;
    final d = _dates;
    if (id == null || d == null) return;
    if (silent && (_loading || _saving)) return;
    final ticket = ++_request;
    setState(() {
      _loading = true;
      if (!silent) _error = null;
    });
    try {
      double? lat;
      double? lon;
      if (!widget.allStations) {
        try {
          final farm = await FarmLocationService.getLocation();
          lat = farm.latitude;
          lon = farm.longitude;
        } catch (_) {}
      }
      final c = await WeatherHistoryService.compare(
        gatewayId: id,
        start: d.start,
        end: d.end,
        resolution: _resolution,
        allStations: widget.allStations,
        farmLat: lat,
        farmLon: lon,
      );
      if (!mounted || ticket != _request) return;
      setState(() {
        _data = c;
        _refreshedAt = DateTime.now();
        if (!silent) _shown = _kPage;
      });
    } catch (e) {
      // A failed live refresh keeps the data on screen.
      if (mounted && ticket == _request && !silent) {
        setState(() => _error = friendlyError(e, 'Couldn\'t load the comparison'));
      }
    } finally {
      if (mounted && ticket == _request) setState(() => _loading = false);
    }
  }

  void _setResolution(HistoryResolution r) {
    setState(() {
      _resolution = r;
      _data = _data?.withResolution(r);
      _shown = _kPage;
    });
  }

  Future<void> _download({required bool excel}) async {
    final c = _data;
    if (c == null || _saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final base = historyFileBaseName(c);
      final mime = excel ? kXlsxMime : kCsvMime;
      final saved = await saveFileForUser(
        excel ? buildHistoryXlsx(c) : buildHistoryCsv(c),
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

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_stations.isEmpty && _error != null) return _Message(_error!, onRetry: _start);
    if (_stations.isEmpty) return const Center(child: CircularProgressIndicator(color: _kStation));
    final c = _data;
    return RefreshIndicator(
      color: _kStation,
      onRefresh: _fetch,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _controls(),
          const SizedBox(height: 12),
          if (_loading) const LinearProgressIndicator(minHeight: 3, color: _kStation),
          if (_error != null) ...[
            const SizedBox(height: 8),
            _Message(_error!, onRetry: _range == null ? _loadRange : _fetch, compact: true),
          ],
          if (c != null) ...[
            const SizedBox(height: 12),
            _downloadBar(c),
            const SizedBox(height: 16),
            _title('How close they were',
                'Station − satellite over ${c.rows.length} ${c.resolution == HistoryResolution.daily ? 'days' : 'hours'}'),
            _Summaries(c),
            const SizedBox(height: 18),
            _title(c.resolution.label,
                '${DateFormat('d MMM').format(c.start)} – ${DateFormat('d MMM yyyy').format(c.end)} · '
                '${c.rows.length} row${c.rows.length == 1 ? '' : 's'}'),
            _RowsTable(c, shown: _shown),
            if (c.rows.length > _shown)
              Center(
                child: TextButton.icon(
                  onPressed: () => setState(() => _shown += _kPage),
                  icon: const Icon(Icons.expand_more_rounded),
                  label: Text('Show ${(c.rows.length - _shown).clamp(0, _kPage)} more '
                      '(${c.rows.length - _shown} left — the download has them all)'),
                ),
              ),
            const SizedBox(height: 12),
            _notes(c),
          ],
        ],
      ),
    );
  }

  Widget _controls() {
    final r = _range;
    final d = _dates;
    final days = d == null ? 0 : d.end.difference(d.start).inDays + 1;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.sensors_rounded, color: _kStation, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: _stations.length < 2
                ? Text(_stations.first.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5))
                : DropdownButton<String>(
                    value: _stationId,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final s in _stations)
                        DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name.isEmpty ? s.id : s.name, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (id) {
                      if (id == null || id == _stationId) return;
                      setState(() {
                        _stationId = id;
                        _data = null;
                      });
                      _loadRange();
                    },
                  ),
          ),
        ]),
        if (r != null)
          Text(
            r.inServiceFrom != null
                ? 'In service on the farm since ${DateFormat('d MMM yyyy').format(r.inServiceFrom!)} — '
                    'recorded data from then to ${DateFormat('d MMM yyyy').format(r.last)}'
                : 'Recorded data from ${DateFormat('d MMM yyyy').format(r.first)} to ${DateFormat('d MMM yyyy').format(r.last)}',
            style: const TextStyle(fontSize: 11.5, color: Colors.black54),
          ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in _Preset.values)
            ChoiceChip(
              label: Text(p.label),
              selected: _preset == p,
              onSelected: r == null ? null : (_) => _applyPreset(p),
            ),
        ]),
        if (_preset == _Preset.custom && r != null) ...[
          const SizedBox(height: 12),
          _customDates(),
        ],
        if (d != null) ...[
          const SizedBox(height: 10),
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.date_range_rounded, size: 18, color: _kDark),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Showing ${DateFormat('EEE d MMM yyyy').format(d.start)} – ${DateFormat('EEE d MMM yyyy').format(d.end)}'
                '  ·  $days day${days == 1 ? '' : 's'}',
                style: const TextStyle(fontWeight: FontWeight.w700, color: _kDark),
              ),
            ),
          ]),
          if (_isLive)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.fiber_manual_record_rounded, size: 10, color: Color(0xFFD32F2F)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    [
                      'Live',
                      if (_data?.stationLatest != null)
                        'latest station reading ${DateFormat('EEE HH:mm').format(_data!.stationLatest!)}',
                      'refreshes every 5 min',
                      if (_refreshedAt != null) 'checked ${DateFormat('HH:mm').format(_refreshedAt!)}',
                    ].join(' · '),
                    style: const TextStyle(fontSize: 11.5, color: Colors.black54, fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            ),
        ],
        const SizedBox(height: 10),
        SegmentedButton<HistoryResolution>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: HistoryResolution.hourly,
              label: const Text('Hour by hour'),
              enabled: days <= kMaxHourlyDays,
            ),
            const ButtonSegment(value: HistoryResolution.daily, label: Text('Day by day')),
          ],
          selected: {_resolution},
          onSelectionChanged: (s) => _setResolution(s.first),
        ),
        if (days > kMaxHourlyDays)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Hour by hour is available for up to 31 days.',
                style: TextStyle(fontSize: 11.5, color: Colors.black54)),
          ),
      ]),
    );
  }

  /// From / To pickers and a clear Compare button.
  Widget _customDates() {
    final fmt = DateFormat('EEE d MMM yyyy');
    final problem = _customProblem;
    Widget field(String label, DateTime? value, ValueChanged<DateTime> onPicked) => OutlinedButton.icon(
          onPressed: () async {
            final p = await _pickDay(value, help: label);
            if (p != null) onPicked(p);
          },
          icon: const Icon(Icons.calendar_month_rounded, size: 18),
          label: Text(value == null ? label : '$label: ${fmt.format(value)}'),
        );
    final changed = _from != _dates?.start || _to != _dates?.end;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8E9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFC5E1A5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          field('From', _from, (v) => setState(() => _from = v)),
          field('To', _to, (v) => setState(() => _to = v)),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: _kStation),
            onPressed: problem == null && !_loading ? _compareCustom : null,
            icon: const Icon(Icons.compare_arrows_rounded, size: 18),
            label: const Text('Compare these dates'),
          ),
          if (problem != null)
            Text(problem, style: const TextStyle(fontSize: 12, color: Color(0xFFC62828), fontWeight: FontWeight.w600))
          else if (!changed && _data != null)
            const Text('Showing these dates', style: TextStyle(fontSize: 12, color: Colors.black54)),
        ]),
      ]),
    );
  }

  Widget _downloadBar(HistoryComparison c) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Download these dates',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: _kDark)),
          Text('Saved as "${historyFileBaseName(c)}" · ${c.resolution.label.toLowerCase()}',
              style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 8, children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _kStation),
              onPressed: _saving ? null : () => _download(excel: true),
              icon: _saving
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.table_view_rounded, size: 18),
              label: const Text('Download Excel'),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: _kStation),
              onPressed: _saving ? null : () => _download(excel: false),
              icon: const Icon(Icons.description_outlined, size: 18),
              label: const Text('Download CSV'),
            ),
          ]),
        ]),
      );

  Widget _title(String t, String s) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kDark)),
          Text(s, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ]),
      );

  Widget _notes(HistoryComparison c) {
    final latest = c.satelliteLatest;
    return Text(
      [
        'Difference = Station − Satellite (positive = the station read higher). Wind in km/h for both.',
        'Satellite = NASA POWER for the station\'s area (~55 km grid) — an estimate, not a farm measurement.',
        if (c.resolution == HistoryResolution.daily)
          'Days are Kenyan days; temperature, humidity and wind are daily averages, rain the daily total.',
        if (!c.satelliteAvailable)
          'Satellite data couldn\'t be loaded for this station — showing the station only.'
        else if (latest != null)
          'Satellite data is published ~2–3 days late; the latest is ${DateFormat('EEE d MMM, HH:00').format(latest)}.',
        if (c.usedFarmLocation) 'This station reports no location, so satellite data is for your farm\'s location.',
        if (c.clippedToService && c.inServiceFrom != null)
          'The station went into service on ${DateFormat('d MMM yyyy').format(c.inServiceFrom!)}, so the dates start there — '
              'earlier readings were recorded before it was on the farm.',
        'Station values are exactly as the station recorded them; satellite values exactly as NASA published them. '
            'Empty cells = that source has no data for the hour or day.',
      ].join('\n'),
      style: const TextStyle(fontSize: 11.5, color: Colors.black54, height: 1.4),
    );
  }
}

String _fmt(double? v) => v == null ? '—' : v.toStringAsFixed(1);
String _fmtDiff(double? v) => v == null ? '—' : '${v > 0 ? '+' : ''}${v.toStringAsFixed(1)}';

class _Message extends StatelessWidget {
  final String text;
  final VoidCallback onRetry;
  final bool compact;
  const _Message(this.text, {required this.onRetry, this.compact = false});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: EdgeInsets.all(compact ? 8 : 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (!compact) const Icon(Icons.history_rounded, size: 46, color: Colors.black38),
            if (!compact) const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, height: 1.4)),
            const SizedBox(height: 10),
            OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
          ]),
        ),
      );
}

class _Summaries extends StatelessWidget {
  final HistoryComparison c;
  const _Summaries(this.c);

  @override
  Widget build(BuildContext context) => Wrap(spacing: 10, runSpacing: 10, children: [
        for (final m in c.summaries)
          Container(
            width: 168,
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
                    ? 'Nothing to pair'
                    : 'avg. gap ${_fmt(m.meanAbsDifference)} · max ${_fmt(m.maxAbsDifference)}\n'
                        'station ${_fmt(m.stationMean)} · satellite ${_fmt(m.satelliteMean)}\n'
                        '${m.pairs} ${c.resolution == HistoryResolution.daily ? 'days' : 'hours'} compared',
                style: const TextStyle(fontSize: 11, color: Colors.black54, height: 1.3),
              ),
            ]),
          ),
      ]);
}

Widget _head(String text, Color c, {TextAlign align = TextAlign.center}) => Container(
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

class _RowsTable extends StatelessWidget {
  final HistoryComparison c;
  final int shown;
  const _RowsTable(this.c, {required this.shown});

  @override
  Widget build(BuildContext context) {
    if (c.rows.isEmpty) {
      return const Text('No data from either source for these dates.', style: TextStyle(color: Colors.black54));
    }
    const metrics = HistoryComparison.metrics;
    final daily = c.resolution == HistoryResolution.daily;
    final when = DateFormat(daily ? 'EEE d MMM yy' : 'EEE d MMM HH:00');
    final rows = c.rows.take(shown).toList();
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
          defaultColumnWidth: const FixedColumnWidth(66),
          columnWidths: const {0: FixedColumnWidth(118)},
          border: const TableBorder(
            horizontalInside: BorderSide(color: _kBorder),
            verticalInside: BorderSide(color: Color(0xFFEFF2EF)),
          ),
          children: [
            TableRow(children: [
              _head(daily ? 'Day' : 'Hour', _kDark, align: TextAlign.left),
              for (final m in metrics) ...[
                _head(m == ComparedMetric.rain && daily ? 'Rain total' : m.label, _kDark),
                _head(m.unit, _kDark),
                _head('', _kDark),
              ],
              if (daily) ...[_head('Hours', _kDark), _head('', _kDark)],
            ]),
            TableRow(children: [
              _head('', _kDark),
              for (var k = 0; k < metrics.length; k++) ...[
                _head('Station', _kStation),
                _head('Satellite', _kSatellite),
                _head('Diff.', _kDiff),
              ],
              if (daily) ...[_head('Station', _kStation), _head('Satellite', _kSatellite)],
            ]),
            for (final (i, r) in rows.indexed)
              TableRow(
                decoration: BoxDecoration(color: i.isOdd ? const Color(0xFFF7F9F7) : Colors.white),
                children: [
                  _cell(when.format(r.time), align: TextAlign.left, bold: true),
                  for (final m in metrics) ...[
                    _cell(_fmt(r.station[m]), color: _kStation),
                    _cell(_fmt(r.satellite[m]), color: _kSatellite),
                    _cell(_fmtDiff(r.difference(m)), color: _kDiff, bold: true, bg: const Color(0xFFFFF7EC)),
                  ],
                  if (daily) ...[
                    _cell('${r.station.hours}', color: _kStation),
                    _cell('${r.satellite.hours}', color: _kSatellite),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}
