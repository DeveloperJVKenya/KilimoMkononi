// lib/screens/admin/weather_stations_admin_screen.dart
//
// Admin panel → Weather stations. Everything about stations without touching
// code (WeatherStationAdminService → functions/stations.js):
//
//   Stations   every station the provider accounts report, plus registered
//              ones: give each a name (the only thing farmers ever see —
//              coordinates stay in "Technical details" for the backend),
//              connect / disconnect farmers, remove.
//   Providers  the built-in NuaSense account and any other station account
//              with the same partner API: name, base URL, API key (sent once,
//              kept server-side), how the key is sent; "Test connection".
//
// "Connect an account" works for any account — farmers, Field Agronomists and
// admins alike (they too see a station on their farm screens only once
// connected). An account can hold several stations; the farmer chooses in
// the app which farm uses which (shown here read-only). A new connection
// sends the account a notification; its data shows straight away.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kilimomkononi/services/weather_station_admin_service.dart';
import 'package:kilimomkononi/utils/friendly_error.dart';

const _kDark = Color.fromARGB(255, 3, 39, 4);
const _kGreen = Color(0xFF2A6B2A);
const _kPage = Color(0xFFF4F6F3);
const _kBorder = Color(0xFFE0E4DF);
const _kAmber = Color(0xFFE65100);
const _kRed = Color(0xFFB71C1C);

class WeatherStationsAdminScreen extends StatefulWidget {
  const WeatherStationsAdminScreen({super.key});

  @override
  State<WeatherStationsAdminScreen> createState() => _WeatherStationsAdminScreenState();
}

class _WeatherStationsAdminScreenState extends State<WeatherStationsAdminScreen> {
  StationsOverview? _data;
  String? _error;
  bool _loading = true;
  String _query = '';

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
      final d = await WeatherStationAdminService.overview();
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e, 'Couldn\'t load the weather stations'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool ok = true}) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), backgroundColor: ok ? _kGreen : _kRed));

  /// Runs an admin action with feedback, then reloads.
  Future<void> _run(Future<void> Function() action, String done, String failed) async {
    try {
      await action();
      _snack(done);
      await _load();
    } catch (e) {
      _snack(friendlyError(e, failed), ok: false);
    }
  }

  Future<bool> _confirm(String title, String body, String action, {bool danger = false}) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: danger ? _kRed : _kGreen),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  // ── Station actions ─────────────────────────────────────────────────────

  Future<void> _editStation([AdminStation? s]) async {
    final d = _data;
    if (d == null) return;
    final r = await showModalBottomSheet<_StationFormResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _StationForm(
        station: s,
        providers: d.providers.where((p) => p.active).toList(),
        unregistered: d.stations.where((x) => !x.registered && x.listedByProvider).toList(),
      ),
    );
    if (r == null) return;
    await _run(
      () => WeatherStationAdminService.saveStation(
        gatewayId: r.gatewayId,
        label: r.label,
        providerId: r.providerId,
        notes: r.notes,
      ),
      s == null ? 'Station "${r.label}" added' : 'Station renamed to "${r.label}"',
      'Couldn\'t save the station',
    );
  }

  Future<void> _connect([AdminStation? preset]) async {
    final d = _data;
    if (d == null) return;
    final r = await showModalBottomSheet<_ConnectResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ConnectFarmerSheet(stations: d.stations, preset: preset),
    );
    if (r == null) return;
    await _run(
      () => WeatherStationAdminService.assign(
        gatewayId: r.station.gatewayId,
        uid: r.farmer.uid,
        providerId: r.station.providerId,
        label: r.label,
        replaceOtherStations: r.replaceOthers,
      ),
      '${r.farmer.displayName} is now connected to ${r.label ?? r.station.displayName}',
      'Couldn\'t connect the account',
    );
  }

  Future<void> _disconnect(AdminStation s, StationFarmer f) async {
    if (!await _confirm(
      'Disconnect ${f.displayName}?',
      '${f.displayName} will stop seeing data, alerts and advice from ${s.displayName}.',
      'Disconnect',
      danger: true,
    )) {
      return;
    }
    await _run(
      () => WeatherStationAdminService.unassign(gatewayId: s.gatewayId, uid: f.uid),
      '${f.displayName} disconnected',
      'Couldn\'t disconnect the farmer',
    );
  }

  Future<void> _remove(AdminStation s) async {
    if (!await _confirm(
      'Remove ${s.displayName}?',
      'Its name is deleted and ${s.farmers.length} farmer(s) are disconnected. '
          'The physical station is not affected — you can add it again later.',
      'Remove',
      danger: true,
    )) {
      return;
    }
    await _run(() => WeatherStationAdminService.removeStation(s.gatewayId), '${s.displayName} removed',
        'Couldn\'t remove the station');
  }

  void _details(AdminStation s) => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(s.displayName),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'For identifying the station in the backend only — farmers see the name, never these.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          _kv('Gateway ID', s.gatewayId, selectable: true),
          _kv('Provider', s.providerName),
          _kv('Device name', s.deviceName ?? '—'),
          _kv('Coordinates', s.lat == null || s.lon == null ? '—' : '${s.lat!.toStringAsFixed(5)}, ${s.lon!.toStringAsFixed(5)}',
              selectable: true),
          _kv('Last seen', s.lastSeen == null ? '—' : DateFormat('EEE d MMM yyyy · HH:mm').format(s.lastSeen!.toLocal())),
          if (s.notes.isNotEmpty) _kv('Notes', s.notes),
        ],
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
    ),
  );

  // ── Provider actions ────────────────────────────────────────────────────

  Future<void> _editProvider([StationProvider? p]) async {
    final saved = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ProviderForm(provider: p),
    );
    if (saved == null) return;
    _snack(p == null ? 'Provider added — its stations now appear under Stations' : 'Provider updated');
    await _load();
  }

  Future<void> _testProvider(StationProvider p) async {
    _snack('Testing ${p.name}…');
    try {
      final r = await WeatherStationAdminService.testProvider(id: p.id);
      if (!mounted) return;
      _snack(r.ok ? '${p.name} works — ${r.count} station(s) on this account' : '${p.name}: ${r.message}', ok: r.ok);
    } catch (e) {
      _snack(friendlyError(e, 'Couldn\'t test ${p.name}'), ok: false);
    }
  }

  Future<void> _removeProvider(StationProvider p) async {
    if (!await _confirm('Remove ${p.name}?', 'Its saved API key is deleted too.', 'Remove', danger: true)) return;
    await _run(() => WeatherStationAdminService.removeProvider(p.id), '${p.name} removed', 'Couldn\'t remove ${p.name}');
  }

  // ── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _kPage,
        appBar: AppBar(
          backgroundColor: _kDark,
          foregroundColor: Colors.white,
          title: const Text('Weather stations', style: TextStyle(fontWeight: FontWeight.w800)),
          actions: [
            IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded), onPressed: _loading ? null : _load),
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Color(0xFF8BC34A),
            labelStyle: TextStyle(fontWeight: FontWeight.w800),
            tabs: [
              Tab(icon: Icon(Icons.sensors_rounded, size: 18), text: 'Stations'),
              Tab(icon: Icon(Icons.hub_rounded, size: 18), text: 'Providers'),
            ],
          ),
        ),
        body: _loading && _data == null
            ? const Center(child: CircularProgressIndicator(color: _kGreen))
            : _error != null && _data == null
            ? _message(Icons.cloud_off_rounded, _error!, retry: true)
            : TabBarView(children: [_stationsTab(), _providersTab()]),
      ),
    );
  }

  Widget _message(IconData icon, String text, {bool retry = false}) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: Colors.black38),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
          if (retry) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
          ],
        ],
      ),
    ),
  );

  Widget _stationsTab() {
    final all = _data!.stations;
    final q = _query.trim().toLowerCase();
    final list = q.isEmpty
        ? all
        : all.where((s) => [
            s.displayName,
            s.gatewayId,
            s.providerName,
            ...s.farmers.map((f) => '${f.displayName} ${f.contact}'),
          ].any((t) => t.toLowerCase().contains(q))).toList();
    final farmers = all.fold<int>(0, (n, s) => n + s.farmers.length);
    final unnamed = all.where((s) => s.needsLabel).length;
    final offline = all.where((s) => !s.online).length;
    return RefreshIndicator(
      color: _kGreen,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2, color: _kGreen),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _Stat(Icons.sensors_rounded, '${all.length} stations', _kGreen),
            _Stat(Icons.people_alt_rounded, '$farmers farmers connected', const Color(0xFF1565C0)),
            if (unnamed > 0) _Stat(Icons.label_off_rounded, '$unnamed need a name', _kAmber),
            if (offline > 0) _Stat(Icons.cloud_off_rounded, '$offline offline', Colors.black54),
          ]),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 8, children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _kGreen),
              onPressed: () => _connect(),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('Connect an account'),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: _kGreen),
              onPressed: () => _editStation(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add station'),
            ),
          ]),
          const SizedBox(height: 14),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search stations or farmers',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kBorder)),
            ),
          ),
          const SizedBox(height: 12),
          if (_data!.panelAccess.isNotEmpty) _PanelAccessCard(_data!.panelAccess),
          if (all.isEmpty)
            _message(Icons.sensors_off_rounded,
                'No stations yet. Add a provider (Providers tab) or add a station by its gateway ID.')
          else if (list.isEmpty)
            _message(Icons.search_off_rounded, 'Nothing matches "$_query".')
          else
            for (final s in list)
              _StationCard(
                station: s,
                onRename: () => _editStation(s),
                onConnect: () => _connect(s),
                onDisconnect: (f) => _disconnect(s, f),
                onDetails: () => _details(s),
                onRemove: s.registered || s.farmers.isNotEmpty ? () => _remove(s) : null,
              ),
        ],
      ),
    );
  }

  Widget _providersTab() {
    final providers = _data!.providers;
    return RefreshIndicator(
      color: _kGreen,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline_rounded, color: Color(0xFF1565C0), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'A provider is a weather-station account that uses the same partner API as NuaSense '
                  '(GET /stations, /weather, /derived). Add its base URL and API key here — no code '
                  'changes needed. Keys are sent once and kept on the server; the app never sees them.',
                  style: TextStyle(fontSize: 12.5, height: 1.4, color: Color(0xFF0D47A1)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _kGreen),
              onPressed: () => _editProvider(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add provider'),
            ),
          ),
          const SizedBox(height: 12),
          for (final p in providers)
            _ProviderCard(
              provider: p,
              stations: _data!.stations.where((s) => s.providerId == p.id).length,
              onTest: () => _testProvider(p),
              onEdit: p.builtIn ? null : () => _editProvider(p),
              onRemove: p.builtIn ? null : () => _removeProvider(p),
            ),
        ],
      ),
    );
  }
}

// ── Pieces ───────────────────────────────────────────────────────────────────

Widget _kv(String k, String v, {bool selectable = false}) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    SizedBox(width: 96, child: Text(k, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.black54))),
    Expanded(
      child: selectable
          ? SelectableText(v, style: const TextStyle(fontSize: 13))
          : Text(v, style: const TextStyle(fontSize: 13)),
    ),
  ]),
);

class _Stat extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _Stat(this.icon, this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 15, color: color),
      const SizedBox(width: 5),
      Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: color)),
    ]),
  );
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
    child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
  );
}

/// Who else can see station data, and where: admins and Field Agronomists
/// see every station in the Agronomist panel only (to write advice). Their
/// farm screens follow the connections above like everyone else's.
class _PanelAccessCard extends StatelessWidget {
  final List<StationFarmer> people;
  const _PanelAccessCard(this.people);

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFF3E5F5),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFCE93D8)),
    ),
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF6A1B9A)),
        title: Text('Agronomist panel access (${people.length})',
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF4A148C))),
        subtitle: const Text(
          'Admins and Field Agronomists see every station only in the Agronomist panel, to write advice. '
          'Like farmers, they must be connected (above) to see a station on their own farm screens.',
          style: TextStyle(fontSize: 11.5, height: 1.35),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        children: [
          for (final p in people)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                const Icon(Icons.person_rounded, size: 18, color: Color(0xFF6A1B9A)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(p.displayName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
                Text(p.roles.join(' · '), style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
              ]),
            ),
        ],
      ),
    ),
  );
}

class _StationCard extends StatelessWidget {
  final AdminStation station;
  final VoidCallback onRename;
  final VoidCallback onConnect;
  final ValueChanged<StationFarmer> onDisconnect;
  final VoidCallback onDetails;
  final VoidCallback? onRemove;

  const _StationCard({
    required this.station,
    required this.onRename,
    required this.onConnect,
    required this.onDisconnect,
    required this.onDetails,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final s = station;
    final statusColor = s.online ? _kGreen : Colors.black45;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: s.needsLabel ? _kAmber.withValues(alpha: 0.5) : _kBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(s.online ? Icons.sensors_rounded : Icons.sensors_off_rounded, size: 20, color: statusColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.displayName, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  _Tag(s.online ? 'Online' : 'Offline', statusColor),
                  _Tag(s.providerName, const Color(0xFF1565C0)),
                  if (s.needsLabel) const _Tag('Needs a name', _kAmber),
                  if (!s.registered) const _Tag('Not added yet', Colors.black54),
                ]),
              ]),
            ),
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (v) => switch (v) {
                'details' => onDetails(),
                'remove' => onRemove?.call(),
                _ => null,
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'details', child: Text('Technical details')),
                if (onRemove != null)
                  const PopupMenuItem(value: 'remove', child: Text('Remove station', style: TextStyle(color: _kRed))),
              ],
            ),
          ]),
          const SizedBox(height: 10),
          if (s.farmers.isEmpty)
            const Text('No account connected yet.', style: TextStyle(fontSize: 12.5, color: Colors.black54))
          else ...[
            Text('Connected accounts (${s.farmers.length})',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black54)),
            for (final f in s.farmers)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(children: [
                  const Icon(Icons.person_rounded, size: 18, color: _kGreen),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(f.displayName, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                      if (f.contact.isNotEmpty)
                        Text(f.contact, style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
                      Text(
                        f.farms.isEmpty
                            ? 'Farms: not chosen yet (the farmer picks in the app)'
                            : 'Farmer uses it for: ${f.farms.map(plotLabel).join(', ')}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: f.farms.isEmpty ? Colors.black45 : _kGreen,
                        ),
                      ),
                    ]),
                  ),
                  IconButton(
                    tooltip: 'Disconnect',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.link_off_rounded, size: 20, color: _kRed),
                    onPressed: () => onDisconnect(f),
                  ),
                ]),
              ),
          ],
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: [
            TextButton.icon(
              onPressed: onRename,
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: Text(s.needsLabel ? 'Give it a name' : 'Rename'),
              style: TextButton.styleFrom(foregroundColor: s.needsLabel ? _kAmber : _kGreen),
            ),
            TextButton.icon(
              onPressed: onConnect,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('Connect account'),
              style: TextButton.styleFrom(foregroundColor: _kGreen),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final StationProvider provider;
  final int stations;
  final VoidCallback onTest;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;

  const _ProviderCard({required this.provider, required this.stations, required this.onTest, this.onEdit, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final p = provider;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.hub_rounded, color: Color(0xFF1565C0)),
          const SizedBox(width: 8),
          Expanded(child: Text(p.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
          if (p.builtIn) const _Tag('Built in', Color(0xFF1565C0)),
        ]),
        const SizedBox(height: 6),
        if (p.baseUrl != null) _kv('Base URL', p.baseUrl!),
        _kv('API key', p.builtIn ? 'In Secret Manager' : (p.hasKey ? 'Saved ✓ (hidden)' : 'Missing')),
        if (!p.builtIn) _kv('Key sent as', p.authStyle.label),
        _kv('Status', p.status.isEmpty ? '—' : p.status),
        _kv('In the app', '$stations station(s)'),
        if (p.notes.isNotEmpty) _kv('Notes', p.notes),
        Wrap(spacing: 4, children: [
          TextButton.icon(
            onPressed: onTest,
            icon: const Icon(Icons.network_check_rounded, size: 18),
            label: const Text('Test connection'),
            style: TextButton.styleFrom(foregroundColor: _kGreen),
          ),
          if (onEdit != null)
            TextButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('Edit'),
              style: TextButton.styleFrom(foregroundColor: _kGreen),
            ),
          if (onRemove != null)
            TextButton.icon(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Remove'),
              style: TextButton.styleFrom(foregroundColor: _kRed),
            ),
        ]),
      ]),
    );
  }
}

InputDecoration _deco(String label, {String? hint, String? helper, Widget? suffix}) => InputDecoration(
  labelText: label,
  hintText: hint,
  helperText: helper,
  helperMaxLines: 3,
  suffixIcon: suffix,
  isDense: true,
  filled: true,
  fillColor: const Color(0xFFFAFBFA),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
);

Widget _sheet(BuildContext context, String title, List<Widget> children) => Padding(
  padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
  child: SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      const SizedBox(height: 14),
      ...children,
    ]),
  ),
);

// ── Add / rename a station ───────────────────────────────────────────────────

class _StationFormResult {
  final String gatewayId;
  final String label;
  final String providerId;
  final String notes;
  const _StationFormResult(this.gatewayId, this.label, this.providerId, this.notes);
}

class _StationForm extends StatefulWidget {
  final AdminStation? station;
  final List<StationProvider> providers;
  final List<AdminStation> unregistered;
  const _StationForm({this.station, required this.providers, required this.unregistered});

  @override
  State<_StationForm> createState() => _StationFormState();
}

class _StationFormState extends State<_StationForm> {
  late final _gateway = TextEditingController(text: widget.station?.gatewayId ?? '');
  late final _label = TextEditingController(text: widget.station?.label ?? '');
  late final _notes = TextEditingController(text: widget.station?.notes ?? '');
  late String _provider = widget.station?.providerId ??
      (widget.providers.isEmpty ? 'nuasense' : widget.providers.first.id);
  String? _error;

  bool get _editing => widget.station != null;

  @override
  void dispose() {
    for (final c in [_gateway, _label, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final g = _gateway.text.trim();
    final l = _label.text.trim();
    if (!RegExp(r'^[A-Za-z0-9:_.-]{2,64}$').hasMatch(g)) {
      setState(() => _error = 'Enter the gateway ID printed on the station (letters, numbers, : _ . -).');
      return;
    }
    if (l.length < 2 || l.length > 60) {
      setState(() => _error = 'Give the station a name of 2–60 characters, e.g. "Kamau farm – Nyeri".');
      return;
    }
    Navigator.pop(context, _StationFormResult(g, l, _provider, _notes.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final choices = widget.unregistered.where((s) => s.providerId == _provider).toList();
    return _sheet(context, _editing ? 'Rename station' : 'Add a weather station', [
      DropdownButtonFormField<String>(
        initialValue: widget.providers.any((p) => p.id == _provider) ? _provider : null,
        decoration: _deco('Provider'),
        items: [for (final p in widget.providers) DropdownMenuItem(value: p.id, child: Text(p.name))],
        onChanged: _editing ? null : (v) => setState(() => _provider = v ?? _provider),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _gateway,
        enabled: !_editing,
        decoration: _deco('Gateway ID', hint: 'e.g. 24E124126C123456',
            helper: 'The station\'s hardware ID from the provider. Used by the system only.'),
      ),
      if (!_editing && choices.isNotEmpty) ...[
        const SizedBox(height: 8),
        const Text('Or pick one this provider reports that isn\'t added yet:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final s in choices)
            ActionChip(
              avatar: Icon(s.online ? Icons.sensors_rounded : Icons.sensors_off_rounded, size: 16),
              label: Text(s.gatewayId),
              onPressed: () => setState(() => _gateway.text = s.gatewayId),
            ),
        ]),
      ],
      const SizedBox(height: 12),
      TextField(
        controller: _label,
        maxLength: 60,
        textCapitalization: TextCapitalization.words,
        decoration: _deco('Station name', hint: 'e.g. Kamau farm – Nyeri',
            helper: 'This is what farmers and agronomists see everywhere in the app.'),
      ),
      TextField(
        controller: _notes,
        maxLines: 2,
        maxLength: 500,
        decoration: _deco('Notes (admins only)', hint: 'Installed by…, access instructions…'),
      ),
      if (_error != null)
        Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: const TextStyle(color: _kRed, fontWeight: FontWeight.w700))),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kGreen),
            onPressed: _save,
            child: Text(_editing ? 'Save name' : 'Add station'),
          ),
        ),
      ]),
    ]);
  }
}

// ── Connect an account ───────────────────────────────────────────────────────

class _ConnectResult {
  final StationFarmer farmer;
  final AdminStation station;
  final String? label;
  final bool replaceOthers;
  const _ConnectResult(this.farmer, this.station, this.label, this.replaceOthers);
}

class _ConnectFarmerSheet extends StatefulWidget {
  final List<AdminStation> stations;
  final AdminStation? preset;
  const _ConnectFarmerSheet({required this.stations, this.preset});

  @override
  State<_ConnectFarmerSheet> createState() => _ConnectFarmerSheetState();
}

class _ConnectFarmerSheetState extends State<_ConnectFarmerSheet> {
  final _search = TextEditingController();
  final _label = TextEditingController();
  Timer? _debounce;
  List<StationFarmer> _results = [];
  int _total = 0;
  bool _searching = false;
  String? _searchError;
  StationFarmer? _farmer;
  late AdminStation? _station = widget.preset;
  bool _replaceOthers = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _runSearch(''); // newest list straight away
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _label.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _runSearch(q));
  }

  Future<void> _runSearch(String q) async {
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final r = await WeatherStationAdminService.searchUsers(q);
      if (!mounted) return;
      setState(() {
        _results = r.users;
        _total = r.total;
      });
    } catch (e) {
      if (mounted) setState(() => _searchError = friendlyError(e, 'Couldn\'t search accounts'));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  String _stationName(String gatewayId) =>
      widget.stations.where((s) => s.gatewayId == gatewayId).firstOrNull?.displayName ?? 'another station';

  void _done() {
    final f = _farmer;
    final s = _station;
    if (f == null || s == null) {
      setState(() => _error = 'Pick an account and a station.');
      return;
    }
    final label = _label.text.trim();
    if (s.needsLabel && (label.length < 2 || label.length > 60)) {
      setState(() => _error = 'This station has no name yet — give it one (2–60 characters).');
      return;
    }
    Navigator.pop(context, _ConnectResult(f, s, s.needsLabel ? label : null, _replaceOthers));
  }

  @override
  Widget build(BuildContext context) {
    final f = _farmer;
    final s = _station;
    return _sheet(context, 'Connect an account to a weather station', [
      const Text(
        'Any account — farmer, Field Agronomist or admin — sees a station on its farm screens only once '
        'connected. An account can have several stations; the farmer chooses in the app which farm uses which.',
        style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.35),
      ),
      const SizedBox(height: 12),
      const Text('1 · Account', style: TextStyle(fontWeight: FontWeight.w800, color: _kGreen)),
      const SizedBox(height: 8),
      if (f != null)
        _picked(Icons.person_rounded, f.displayName,
            [if (f.roles.isNotEmpty) f.roles.join(' · '), f.contact].where((x) => x.isNotEmpty).join('\n'),
            () => setState(() => _farmer = null))
      else ...[
        TextField(
          controller: _search,
          onChanged: _onSearch,
          decoration: _deco('Search by name, email, phone or county',
              suffix: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : const Icon(Icons.search_rounded)),
        ),
        if (_searchError != null)
          Padding(padding: const EdgeInsets.only(top: 6), child: Text(_searchError!, style: const TextStyle(color: _kRed))),
        const SizedBox(height: 6),
        if (_total > _results.length)
          Text('Showing ${_results.length} of $_total — type to narrow down',
              style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
        for (final u in _results)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(radius: 16, child: Icon(Icons.person_rounded, size: 18)),
            title: Text(
              u.roles.isEmpty ? u.displayName : '${u.displayName} · ${u.roles.join(' · ')}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text([
              if (u.contact.isNotEmpty) u.contact,
              if (u.stations.isNotEmpty) 'Has: ${u.stations.map(_stationName).join(', ')}',
            ].join('\n')),
            isThreeLine: u.stations.isNotEmpty && u.contact.isNotEmpty,
            onTap: () => setState(() => _farmer = u),
          ),
      ],
      const SizedBox(height: 16),
      const Text('2 · Weather station', style: TextStyle(fontWeight: FontWeight.w800, color: _kGreen)),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        initialValue: s?.gatewayId,
        isExpanded: true,
        decoration: _deco('Station'),
        items: [
          for (final x in widget.stations)
            DropdownMenuItem(
              value: x.gatewayId,
              child: Text('${x.displayName}${x.online ? '' : ' (offline)'}', overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (v) => setState(() => _station = widget.stations.firstWhere((x) => x.gatewayId == v)),
      ),
      if (s != null && s.needsLabel) ...[
        const SizedBox(height: 10),
        TextField(
          controller: _label,
          maxLength: 60,
          textCapitalization: TextCapitalization.words,
          decoration: _deco('Name this station', hint: 'e.g. ${f?.displayName ?? 'Kamau'} farm',
              helper: 'Farmers see this name instead of the station\'s ID or coordinates.'),
        ),
      ],
      if (f != null && f.stations.where((g) => g != s?.gatewayId).isNotEmpty)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _replaceOthers,
          onChanged: (v) => setState(() => _replaceOthers = v ?? false),
          title: const Text('Replace their other station(s)', style: TextStyle(fontSize: 13.5)),
          subtitle: Text(
              _replaceOthers
                  ? '${f.displayName} will be disconnected from ${f.stations.where((g) => g != s?.gatewayId).map(_stationName).join(', ')}.'
                  : '${f.displayName} keeps ${f.stations.where((g) => g != s?.gatewayId).map(_stationName).join(', ')} too.',
              style: const TextStyle(fontSize: 12)),
        ),
      if (_error != null)
        Padding(padding: const EdgeInsets.only(top: 6), child: Text(_error!, style: const TextStyle(color: _kRed, fontWeight: FontWeight.w700))),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: _kGreen),
            onPressed: _done,
            icon: const Icon(Icons.link_rounded, size: 18),
            label: const Text('Connect'),
          ),
        ),
      ]),
    ]);
  }

  Widget _picked(IconData icon, String title, String subtitle, VoidCallback onClear) => Container(
    padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
    decoration: BoxDecoration(
      color: const Color(0xFFE8F5E9),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFA5D6A7)),
    ),
    child: Row(children: [
      Icon(icon, color: _kGreen),
      const SizedBox(width: 8),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          if (subtitle.isNotEmpty) Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ]),
      ),
      IconButton(tooltip: 'Change', icon: const Icon(Icons.close_rounded), onPressed: onClear),
    ]),
  );
}

// ── Add / edit a provider ────────────────────────────────────────────────────

class _ProviderForm extends StatefulWidget {
  final StationProvider? provider;
  const _ProviderForm({this.provider});

  @override
  State<_ProviderForm> createState() => _ProviderFormState();
}

class _ProviderFormState extends State<_ProviderForm> {
  late final _name = TextEditingController(text: widget.provider?.name ?? '');
  late final _url = TextEditingController(text: widget.provider?.baseUrl ?? 'https://');
  final _key = TextEditingController();
  late final _notes = TextEditingController(text: widget.provider?.notes ?? '');
  late ProviderAuthStyle _auth = widget.provider?.authStyle ?? ProviderAuthStyle.bearer;
  bool _showKey = false;
  bool _busy = false;
  String? _error;
  String? _testResult;
  bool _testOk = false;

  bool get _editing => widget.provider != null;

  @override
  void dispose() {
    for (final c in [_name, _url, _key, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validate() {
    if (_name.text.trim().length < 2) return 'Give the provider a name.';
    if (!RegExp(r'^https://\S+\.\S+').hasMatch(_url.text.trim())) return 'The base URL must start with https://';
    if (!_editing && _key.text.trim().length < 8) return 'Enter the API key from the provider.';
    return null;
  }

  Future<void> _test() async {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _testResult = null;
    });
    try {
      final r = await WeatherStationAdminService.testProvider(
        id: widget.provider?.id,
        name: _name.text.trim(),
        baseUrl: _url.text.trim(),
        authStyle: _auth,
        apiKey: _key.text.trim(),
      );
      setState(() {
        _testOk = r.ok;
        _testResult = r.ok
            ? 'Connected — ${r.count} station(s) on this account'
                '${r.sample.isEmpty ? '' : ': ${r.sample.map((s) => s.gatewayId).join(', ')}'}'
            : 'Didn\'t work: ${r.message}';
      });
    } catch (e) {
      setState(() {
        _testOk = false;
        _testResult = friendlyError(e, 'Couldn\'t test');
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await WeatherStationAdminService.saveProvider(
        id: widget.provider?.id,
        name: _name.text.trim(),
        baseUrl: _url.text.trim(),
        authStyle: _auth,
        apiKey: _key.text.trim(),
        notes: _notes.text.trim(),
      );
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e, 'Couldn\'t save'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _sheet(context, _editing ? 'Edit provider' : 'Add a station provider', [
      TextField(controller: _name, decoration: _deco('Name', hint: 'e.g. Coast region stations')),
      const SizedBox(height: 12),
      TextField(
        controller: _url,
        keyboardType: TextInputType.url,
        decoration: _deco('Base URL', hint: 'https://api.example.com/api/partner/v1',
            helper: 'The address the station API lives at (ends before /stations).'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _key,
        obscureText: !_showKey,
        autocorrect: false,
        enableSuggestions: false,
        decoration: _deco(
          'API key',
          helper: _editing
              ? (widget.provider!.hasKey ? 'A key is saved. Leave blank to keep it, or paste a new one.' : 'No key saved yet.')
              : 'Sent once to the server and kept there — never shown again.',
          suffix: IconButton(
            tooltip: _showKey ? 'Hide' : 'Show',
            icon: Icon(_showKey ? Icons.visibility_off_rounded : Icons.visibility_rounded),
            onPressed: () => setState(() => _showKey = !_showKey),
          ),
        ),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<ProviderAuthStyle>(
        initialValue: _auth,
        decoration: _deco('How the key is sent'),
        items: [for (final a in ProviderAuthStyle.values) DropdownMenuItem(value: a, child: Text(a.label))],
        onChanged: (v) => setState(() => _auth = v ?? _auth),
      ),
      const SizedBox(height: 12),
      TextField(controller: _notes, maxLines: 2, maxLength: 500, decoration: _deco('Notes (admins only)')),
      if (_testResult != null)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (_testOk ? _kGreen : _kRed).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(_testResult!, style: TextStyle(color: _testOk ? _kGreen : _kRed, fontWeight: FontWeight.w700)),
        ),
      if (_error != null)
        Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: const TextStyle(color: _kRed, fontWeight: FontWeight.w700))),
      Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _test,
            icon: const Icon(Icons.network_check_rounded, size: 18),
            label: const Text('Test connection'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kGreen),
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(_editing ? 'Save' : 'Add provider'),
          ),
        ),
      ]),
    ]);
  }
}
