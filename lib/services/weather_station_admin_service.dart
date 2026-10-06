// lib/services/weather_station_admin_service.dart
//
// Admin-only: weather stations and their providers, through the
// `manageWeatherStations` Cloud Function (functions/stations.js). The app
// never sees a provider's API key — it is sent once when saving and stays
// server-side. Station coordinates come back only for "Technical details";
// everywhere else a station is shown by its admin-entered label.

import 'package:cloud_functions/cloud_functions.dart';

Map<String, dynamic> _map(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _list(Object? v) => v is List ? v.map(_map).toList() : const [];
String _s(Object? v) => v == null ? '' : '$v';

class StationFarmer {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String county;
  final DateTime? assignedAt;

  /// The farms / plots the account itself chose this station for
  /// (its own choice in the app — the admin doesn't set it).
  final List<String> farms;

  /// "Admin" / "Field Agronomist" (panel-access list only).
  final List<String> roles;

  /// Other stations this farmer is connected to (search results only).
  final List<String> stations;

  const StationFarmer({
    required this.uid,
    this.name = '',
    this.email = '',
    this.phone = '',
    this.county = '',
    this.assignedAt,
    this.farms = const [],
    this.stations = const [],
    this.roles = const [],
  });

  String get displayName => name.isNotEmpty ? name : (email.isNotEmpty ? email : uid);

  /// "email · phone · county" — whatever is known.
  String get contact => [email, phone, county].where((s) => s.isNotEmpty).join(' · ');

  factory StationFarmer.fromMap(Map<String, dynamic> m) => StationFarmer(
    uid: _s(m['uid']),
    name: _s(m['name']),
    email: _s(m['email']),
    phone: _s(m['phone']),
    county: _s(m['county']),
    assignedAt: DateTime.tryParse(_s(m['assignedAt'])),
    farms: (m['farms'] as List?)?.map((e) => '$e').toList() ?? const [],
    stations: (m['stations'] as List?)?.map((e) => '$e').toList() ?? const [],
    roles: (m['roles'] as List?)?.map((e) => '$e').toList() ?? const [],
  );
}

class AdminStation {
  final String gatewayId;

  /// Admin-entered name (null = not labelled yet).
  final String? label;

  /// What farmers see: the label, else a readable fallback (never coordinates).
  final String displayName;
  final String providerId;
  final String providerName;
  final bool registered;
  final bool listedByProvider;
  final bool online;
  final DateTime? lastSeen;
  final String notes;

  // Backend identification only.
  final String? deviceName;
  final double? lat;
  final double? lon;

  final List<StationFarmer> farmers;

  const AdminStation({
    required this.gatewayId,
    this.label,
    required this.displayName,
    required this.providerId,
    required this.providerName,
    this.registered = false,
    this.listedByProvider = false,
    this.online = false,
    this.lastSeen,
    this.notes = '',
    this.deviceName,
    this.lat,
    this.lon,
    this.farmers = const [],
  });

  bool get needsLabel => label == null || label!.trim().isEmpty;

  factory AdminStation.fromMap(Map<String, dynamic> m) => AdminStation(
    gatewayId: _s(m['gatewayId']),
    label: m['label'] == null ? null : _s(m['label']),
    displayName: _s(m['displayName']),
    providerId: _s(m['providerId']),
    providerName: _s(m['providerName']),
    registered: m['registered'] == true,
    listedByProvider: m['listedByProvider'] == true,
    online: m['online'] == true,
    lastSeen: DateTime.tryParse(_s(m['lastSeen'])),
    notes: _s(m['notes']),
    deviceName: m['deviceName'] == null ? null : _s(m['deviceName']),
    lat: (m['lat'] as num?)?.toDouble(),
    lon: (m['lon'] as num?)?.toDouble(),
    farmers: _list(m['farmers']).map(StationFarmer.fromMap).toList(),
  );
}

/// How the provider expects its API key.
enum ProviderAuthStyle {
  bearer('bearer', 'Authorization: Bearer <key>'),
  header('x-api-key', 'X-API-Key header'),
  query('query', '?api_key=<key> in the URL');

  final String value;
  final String label;
  const ProviderAuthStyle(this.value, this.label);

  static ProviderAuthStyle from(String? v) =>
      ProviderAuthStyle.values.firstWhere((s) => s.value == v, orElse: () => ProviderAuthStyle.bearer);
}

class StationProvider {
  final String id;
  final String name;
  final String? baseUrl;
  final ProviderAuthStyle authStyle;
  final bool builtIn;
  final bool hasKey;
  final bool active;
  final String notes;

  /// "3 station(s)" / "unreachable" / "not set up" — from the last overview.
  final String status;

  const StationProvider({
    required this.id,
    required this.name,
    this.baseUrl,
    this.authStyle = ProviderAuthStyle.bearer,
    this.builtIn = false,
    this.hasKey = false,
    this.active = true,
    this.notes = '',
    this.status = '',
  });

  factory StationProvider.fromMap(Map<String, dynamic> m) => StationProvider(
    id: _s(m['id']),
    name: _s(m['name']),
    baseUrl: m['baseUrl'] == null ? null : _s(m['baseUrl']),
    authStyle: ProviderAuthStyle.from(m['authStyle'] as String?),
    builtIn: m['builtIn'] == true,
    hasKey: m['hasKey'] == true,
    active: m['active'] != false,
    notes: _s(m['notes']),
    status: _s(m['status']),
  );
}

/// "SingleCrop" → "Single-crop plot"; other plot ids as they are.
String plotLabel(String? plotId) => switch (plotId) {
  null || '' => 'All farms',
  'SingleCrop' => 'Single-crop plot',
  'Intercrop' => 'Intercrop plot',
  _ => plotId,
};

class StationsOverview {
  final List<StationProvider> providers;
  final List<AdminStation> stations;

  /// Admins and Field Agronomists: they see every station, but only in the
  /// Field Agronomist panel (to write advice) — never as their farm data.
  final List<StationFarmer> panelAccess;
  const StationsOverview(this.providers, this.stations, [this.panelAccess = const []]);
}

class ProviderTestResult {
  final bool ok;
  final int count;
  final String message;
  final List<({String gatewayId, String name})> sample;
  const ProviderTestResult({required this.ok, this.count = 0, this.message = '', this.sample = const []});
}

class WeatherStationAdminService {
  WeatherStationAdminService._();

  static Future<Map<String, dynamic>> _call(String action, [Map<String, dynamic> data = const {}]) async {
    final res = await FirebaseFunctions.instance
        .httpsCallable('manageWeatherStations', options: HttpsCallableOptions(timeout: const Duration(seconds: 60)))
        .call({'action': action, ...data});
    return _map(res.data);
  }

  static Future<StationsOverview> overview() async {
    final d = await _call('overview');
    return StationsOverview(
      _list(d['providers']).map(StationProvider.fromMap).toList(),
      _list(d['stations']).map(AdminStation.fromMap).toList(),
      _list(d['panelAccess']).map(StationFarmer.fromMap).toList(),
    );
  }

  /// Registers a station or changes its label / provider / notes.
  static Future<void> saveStation({
    required String gatewayId,
    required String label,
    required String providerId,
    String notes = '',
  }) => _call('saveStation', {'gatewayId': gatewayId, 'label': label, 'providerId': providerId, 'notes': notes});

  static Future<void> removeStation(String gatewayId) => _call('removeStation', {'gatewayId': gatewayId});

  /// Connects [uid] to the station. Unless [keepOtherStations], the farmer's
  /// other stations are disconnected (a farm normally has one).
  /// Connects an account (farmer, agronomist or admin) to the station.
  /// Accounts can hold several stations; [replaceOtherStations] disconnects
  /// the others. Which farm uses which station, the account chooses itself.
  static Future<void> assign({
    required String gatewayId,
    required String uid,
    String providerId = 'nuasense',
    String? label,
    bool replaceOtherStations = false,
  }) => _call('assign', {
    'gatewayId': gatewayId,
    'uid': uid,
    'providerId': providerId,
    'label': ?label,
    'replaceOtherStations': replaceOtherStations,
  });

  static Future<void> unassign({required String gatewayId, required String uid}) =>
      _call('unassign', {'gatewayId': gatewayId, 'uid': uid});

  /// Adds (no [id]) or edits a provider. [apiKey] may be empty when editing
  /// to keep the saved key. Returns the provider id.
  static Future<String> saveProvider({
    String? id,
    required String name,
    required String baseUrl,
    required ProviderAuthStyle authStyle,
    String apiKey = '',
    String notes = '',
  }) async {
    final d = await _call('saveProvider', {
      'id': ?id,
      'name': name,
      'baseUrl': baseUrl,
      'authStyle': authStyle.value,
      'apiKey': apiKey,
      'notes': notes,
    });
    return _s(d['id']);
  }

  /// Calls the provider's GET /stations with these details (or the saved
  /// ones for [id]) to check the URL and key work.
  static Future<ProviderTestResult> testProvider({
    String? id,
    String? baseUrl,
    ProviderAuthStyle? authStyle,
    String apiKey = '',
    String name = 'test',
  }) async {
    final d = await _call('testProvider', {
      'id': ?id,
      'baseUrl': ?baseUrl,
      if (authStyle != null) 'authStyle': authStyle.value,
      if (apiKey.isNotEmpty) 'apiKey': apiKey,
      'name': name,
    });
    return ProviderTestResult(
      ok: d['ok'] == true,
      count: (d['count'] as num?)?.toInt() ?? 0,
      message: _s(d['message']),
      sample: _list(d['sample']).map((m) => (gatewayId: _s(m['gatewayId']), name: _s(m['name']))).toList(),
    );
  }

  static Future<void> removeProvider(String id) => _call('removeProvider', {'id': id});

  static Future<({List<StationFarmer> users, int total})> searchUsers(String q) async {
    final d = await _call('searchUsers', {'q': q});
    return (
      users: _list(d['users']).map(StationFarmer.fromMap).toList(),
      total: (d['total'] as num?)?.toInt() ?? 0,
    );
  }
}
