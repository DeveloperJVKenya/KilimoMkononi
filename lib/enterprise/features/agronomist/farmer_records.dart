// lib/enterprise/features/agronomist/farmer_records.dart
//
// What the `agronomistData` Cloud Function (functions/agronomist.js) returns
// to the Agronomist panel:
//
//   InsightsData   action "insights": every farmer's pest / disease reports
//                  for this period and the one before (IssueRow), the latest
//                  soil test of each plot (PlotRow) and the farmers who share
//                  their records (FarmerRow). Rows of farmers who don't share
//                  have no farmer id (f == null) — counted, never named.
//   FarmerRecord   action "farmer": one farmer's full record.
//
// Times arrive as milliseconds since the epoch.

import 'package:kilimomkononi/enterprise/features/agronomist/farmer_advice.dart';
import 'package:kilimomkononi/services/nutrient_levels.dart';

DateTime? _ms(dynamic v) =>
    v is num && v > 0 ? DateTime.fromMillisecondsSinceEpoch(v.toInt()) : null;

String _s(dynamic v) => v == null ? '' : '$v'.trim();

Map<String, dynamic> _map(dynamic v) =>
    v is Map ? v.map((k, x) => MapEntry('$k', x)) : <String, dynamic>{};

List<Map<String, dynamic>> _maps(dynamic v) =>
    v is List ? v.whereType<Map>().map(_map).toList() : const [];

/// One pest or disease report.
class IssueRow {
  /// 'pest' | 'disease'
  final String type;
  final String name;
  final String crop;
  final String stage;
  final DateTime at;

  /// 'manual' | 'photo'
  final String source;

  /// 'high' | 'medium' | 'low' | null (photo ID only)
  final String? confidence;
  final bool unidentified;
  final bool hasPhoto;
  final String? intervention;

  /// Farmer uid — null when the farmer doesn't share their records.
  final String? farmerUid;
  final String county;
  final String ward;

  // Farmer record only.
  final String? id;
  final String? photoUrl;
  final String? description;
  final String? recommendation;
  final String? plot;

  const IssueRow({
    required this.type,
    required this.name,
    required this.crop,
    required this.stage,
    required this.at,
    this.source = 'manual',
    this.confidence,
    this.unidentified = false,
    this.hasPhoto = false,
    this.intervention,
    this.farmerUid,
    this.county = '',
    this.ward = '',
    this.id,
    this.photoUrl,
    this.description,
    this.recommendation,
    this.plot,
  });

  bool get isPest => type == 'pest';
  bool get isDisease => type == 'disease';

  /// What to call it in lists.
  String get label => unidentified
      ? (name.isEmpty ? 'Unidentified ${isDisease ? 'disease' : 'pest'}' : '$name (unconfirmed)')
      : name;

  factory IssueRow.fromMap(Map<String, dynamic> m) => IssueRow(
        type: _s(m['type']) == 'disease' ? 'disease' : 'pest',
        name: _s(m['name']),
        crop: _s(m['crop']),
        stage: _s(m['stage']),
        at: _ms(m['at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        source: _s(m['src']) == 'photo' ? 'photo' : 'manual',
        confidence: m['conf'] is String ? m['conf'] as String : null,
        unidentified: m['unidentified'] == true,
        hasPhoto: m['photo'] == true || _s(m['photoUrl']).isNotEmpty,
        intervention: _s(m['intervention']).isEmpty ? null : _s(m['intervention']),
        farmerUid: m['f'] is String ? m['f'] as String : null,
        county: _s(m['county']),
        ward: _s(m['ward']),
        id: m['id'] as String?,
        photoUrl: _s(m['photoUrl']).isEmpty ? null : _s(m['photoUrl']),
        description: _s(m['description']).isEmpty ? null : _s(m['description']),
        recommendation: _s(m['recommendation']).isEmpty ? null : _s(m['recommendation']),
        plot: _s(m['plot']).isEmpty ? null : _s(m['plot']),
      );
}

/// A plot's latest field record: crops, soil test and its bands.
class PlotRow {
  final String plot;
  final List<({String type, String stage})> crops;
  final Map<String, double> npk;
  final DateTime? at;
  final double? area;
  final String? farmerUid;
  final String county;
  final String ward;

  /// Bands saved with the record (newer records), else worked out here with
  /// the same targets the Field Data form uses.
  final Map<String, NutrientBand> bands;

  const PlotRow({
    required this.plot,
    required this.crops,
    required this.npk,
    required this.bands,
    this.at,
    this.area,
    this.farmerUid,
    this.county = '',
    this.ward = '',
  });

  List<String> get cropNames => crops.map((c) => c.type).toList();

  List<String> get lowNutrients =>
      [for (final e in bands.entries) if (e.value == NutrientBand.low) e.key];

  factory PlotRow.fromMap(Map<String, dynamic> m) {
    final crops = [
      for (final c in _maps(m['crops']))
        if (_s(c['type']).isNotEmpty) (type: _s(c['type']), stage: _s(c['stage'])),
    ];
    final npk = <String, double>{
      for (final e in _map(m['npk']).entries)
        if (e.value is num) e.key: (e.value as num).toDouble(),
    };
    final saved = <String, NutrientBand>{
      for (final e in _map(m['bands']).entries)
        if (NutrientBand.fromName('${e.value}') != null) e.key: NutrientBand.fromName('${e.value}')!,
    };
    final bands = saved.isNotEmpty
        ? saved
        : bandsFromFieldData({
            'crops': [for (final c in crops) {'type': c.type, 'stage': c.stage}],
            'npk': npk,
          });
    return PlotRow(
      plot: _s(m['plot']),
      crops: crops,
      npk: npk,
      bands: bands,
      at: _ms(m['at']),
      area: (m['area'] as num?)?.toDouble(),
      farmerUid: m['f'] is String ? m['f'] as String : null,
      county: _s(m['county']),
      ward: _s(m['ward']),
    );
  }
}

/// A farmer who shares their records.
class FarmerRow {
  final String uid;
  final String name;
  final String county;
  final String ward;
  final String constituency;

  const FarmerRow({
    required this.uid,
    required this.name,
    this.county = '',
    this.ward = '',
    this.constituency = '',
  });

  String get place => [ward, county].where((p) => p.isNotEmpty).join(', ');

  factory FarmerRow.fromMap(Map<String, dynamic> m) => FarmerRow(
        uid: _s(m['uid']),
        name: _s(m['name']).isEmpty ? 'Farmer' : _s(m['name']),
        county: _s(m['county']),
        ward: _s(m['ward']),
        constituency: _s(m['constituency']),
      );
}

class InsightsData {
  final DateTime generatedAt;
  final int days;
  final List<IssueRow> issues;
  final List<PlotRow> plots;
  final List<FarmerRow> farmers;
  final int totalFarmers;
  final int optedOut;

  /// The server hit its row limit — older rows of the period are missing.
  final bool truncated;

  const InsightsData({
    required this.generatedAt,
    required this.days,
    required this.issues,
    required this.plots,
    required this.farmers,
    this.totalFarmers = 0,
    this.optedOut = 0,
    this.truncated = false,
  });

  factory InsightsData.fromMap(Map<String, dynamic> m) {
    final totals = _map(m['totals']);
    return InsightsData(
      generatedAt: _ms(m['generatedAt']) ?? DateTime.now(),
      days: (m['days'] as num?)?.toInt() ?? 30,
      issues: _maps(m['issues']).map(IssueRow.fromMap).toList(),
      plots: _maps(m['plots']).map(PlotRow.fromMap).toList(),
      farmers: _maps(m['farmers']).map(FarmerRow.fromMap).toList(),
      totalFarmers: (totals['farmers'] as num?)?.toInt() ?? 0,
      optedOut: (totals['optedOut'] as num?)?.toInt() ?? 0,
      truncated: m['truncated'] == true,
    );
  }
}

/// One farmer's full record (Agronomist panel → a farmer).
class FarmerRecord {
  final String uid;
  final String name;
  final String county;
  final String constituency;
  final String ward;
  final String phone;
  final String email;
  final DateTime? joinedAt;

  /// fielddata records, newest first (timestamps in ms).
  final List<Map<String, dynamic>> fieldRecords;
  final List<IssueRow> issues;
  final List<FarmerAdvice> advice;

  /// advisoryId → item key → answer ('found', 'not_found', 'logged…').
  final Map<String, Map<String, String>> responses;
  final List<({String id, String name})> stations;
  final double costTotal;
  final Map<String, double> costByCategory;

  const FarmerRecord({
    required this.uid,
    required this.name,
    this.county = '',
    this.constituency = '',
    this.ward = '',
    this.phone = '',
    this.email = '',
    this.joinedAt,
    this.fieldRecords = const [],
    this.issues = const [],
    this.advice = const [],
    this.responses = const {},
    this.stations = const [],
    this.costTotal = 0,
    this.costByCategory = const {},
  });

  String get place => [ward, constituency, county].where((p) => p.isNotEmpty).join(', ');

  /// The crops on the farmer's latest records (each plot's newest record).
  List<String> get crops {
    final out = <String>{};
    for (final p in latestPlots) {
      out.addAll(p.cropNames);
    }
    return out.toList();
  }

  /// Latest record per plot, as plot rows.
  List<PlotRow> get latestPlots {
    final seen = <String>{};
    final out = <PlotRow>[];
    for (final r in fieldRecords) {
      final plot = _s(r['plotId']);
      if (!seen.add(plot)) continue;
      out.add(plotRowOf(r));
    }
    return out;
  }

  static PlotRow plotRowOf(Map<String, dynamic> r) => PlotRow.fromMap({
        'plot': r['plotId'],
        'crops': r['crops'],
        'npk': r['npk'],
        'bands': r['nutrientBands'],
        'area': r['area'],
        'at': r['timestamp'],
      });

  factory FarmerRecord.fromMap(Map<String, dynamic> m) {
    final p = _map(m['profile']);
    final responses = <String, Map<String, String>>{};
    for (final r in _maps(m['responses'])) {
      final id = _s(r['advisoryId']);
      if (id.isEmpty) continue;
      responses[id] = {for (final e in _map(r['items']).entries) e.key: '${e.value}'};
    }
    final costs = _map(m['costs']);
    return FarmerRecord(
      uid: _s(p['uid']),
      name: _s(p['name']).isEmpty ? 'Farmer' : _s(p['name']),
      county: _s(p['county']),
      constituency: _s(p['constituency']),
      ward: _s(p['ward']),
      phone: _s(p['phone']),
      email: _s(p['email']),
      joinedAt: _ms(p['joinedAt']),
      fieldRecords: _maps(m['fieldRecords'])
        ..sort((a, b) => ((b['timestamp'] as num?) ?? 0).compareTo((a['timestamp'] as num?) ?? 0)),
      issues: _maps(m['issues']).map(IssueRow.fromMap).toList()..sort((a, b) => b.at.compareTo(a.at)),
      advice: _maps(m['advice']).map(FarmerAdvice.fromMap).toList()
        ..sort((a, b) => (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0))),
      responses: responses,
      stations: [
        for (final s in _maps(m['stations'])) (id: _s(s['id']), name: _s(s['name'])),
      ],
      costTotal: (costs['total'] as num?)?.toDouble() ?? 0,
      costByCategory: {
        for (final e in _map(costs['byCategory']).entries)
          if (e.value is num) e.key: (e.value as num).toDouble(),
      },
    );
  }
}
