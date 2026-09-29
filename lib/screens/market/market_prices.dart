// lib/screens/market/market_prices.dart
//
// Market price board: price reports farmers submit (Firestore `marketdata`,
// readable by every signed-in farmer — see firestore.rules) plus the pure
// maths behind the screen: filtering, per-crop summary (average, range,
// 30-day trend, best market to sell at).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const kPriceUnits = <String>[
  'per kg',
  'per 90 kg bag',
  'per 50 kg bag',
  'per crate',
  'per bunch',
  'per piece',
  'per tonne',
  'per litre',
];

const kMarketCrops = <String>[
  'Maize', 'Beans', 'Irish Potatoes', 'Tomatoes', 'Cabbages', 'Kales', 'Onions', 'Carrots',
  'Wheat', 'Rice', 'Sorghum', 'Green grams', 'Bananas', 'Avocados', 'Mangoes', 'Milk',
];

@immutable
class PriceReport {
  final String id;
  final String crop;
  final String market;
  final String region;
  final double price;
  final String unit; // '' for older reports
  final double? predicted;
  final String userId;
  final DateTime at;

  const PriceReport({
    required this.id,
    required this.crop,
    required this.market,
    required this.region,
    required this.price,
    required this.unit,
    required this.userId,
    required this.at,
    this.predicted,
  });

  static PriceReport? fromMap(String id, Map<String, dynamic> d) {
    final price = (d['retailPrice'] as num?)?.toDouble();
    final crop = '${d['cropType'] ?? ''}'.trim();
    if (price == null || price <= 0 || crop.isEmpty) return null;
    final ts = d['timestamp'];
    return PriceReport(
      id: id,
      crop: _title(crop),
      market: '${d['market'] ?? ''}'.trim(),
      region: '${d['region'] ?? ''}'.trim(),
      price: price,
      unit: '${d['unit'] ?? ''}'.trim(),
      predicted: (d['predictedPrice'] as num?)?.toDouble(),
      userId: '${d['userId'] ?? ''}',
      at: ts is Timestamp ? ts.toDate() : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  bool isMine(String? uid) => uid != null && uid == userId;
}

String _title(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String formatKes(num v) {
  final whole = v.round();
  final s = whole.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return 'KES ${whole < 0 ? '-' : ''}$b';
}

// ── Query & board ────────────────────────────────────────────────────────────

enum PriceSort { newest, highest, lowest }

@immutable
class PriceQuery {
  final String? crop;
  final String? region;
  final String? market;
  final PriceSort sort;
  final bool mineOnly;
  const PriceQuery({this.crop, this.region, this.market, this.sort = PriceSort.newest, this.mineOnly = false});

  PriceQuery copyWith({
    String? Function()? crop,
    String? Function()? region,
    String? Function()? market,
    PriceSort? sort,
    bool? mineOnly,
  }) =>
      PriceQuery(
        crop: crop != null ? crop() : this.crop,
        region: region != null ? region() : this.region,
        market: market != null ? market() : this.market,
        sort: sort ?? this.sort,
        mineOnly: mineOnly ?? this.mineOnly,
      );
}

class MarketStat {
  final String market;
  final double average;
  final int count;
  const MarketStat(this.market, this.average, this.count);
}

class CropSummary {
  final String crop;
  final int count;
  final double average;
  final double min;
  final double max;
  final DateTime latest;
  final String unit; // most common unit ('' if none)
  final List<(DateTime, double)> trend; // daily averages, oldest first
  final MarketStat? best; // highest average
  final MarketStat? lowest;
  final bool recentOnly; // computed from the last 30 days

  const CropSummary({
    required this.crop,
    required this.count,
    required this.average,
    required this.min,
    required this.max,
    required this.latest,
    required this.unit,
    required this.trend,
    required this.best,
    required this.lowest,
    required this.recentOnly,
  });

  /// Change from the first to the last day of the trend, in percent.
  double? get trendChangePct {
    if (trend.length < 2 || trend.first.$2 == 0) return null;
    return (trend.last.$2 - trend.first.$2) / trend.first.$2 * 100;
  }
}

class PriceBoard {
  final List<PriceReport> shown;
  final List<(String, int)> crops; // crop → reports (all)
  final List<(String, int)> regions;
  final List<(String, int)> markets;
  final CropSummary? summary; // when a crop is selected
  const PriceBoard({required this.shown, required this.crops, required this.regions, required this.markets, this.summary});
}

List<(String, int)> _counts(Iterable<String> values) {
  final m = <String, int>{};
  for (final v in values) {
    if (v.isEmpty) continue;
    m[v] = (m[v] ?? 0) + 1;
  }
  return m.entries.map((e) => (e.key, e.value)).toList()
    ..sort((a, b) => b.$2 != a.$2 ? b.$2.compareTo(a.$2) : a.$1.compareTo(b.$1));
}

bool _same(String a, String b) => a.toLowerCase() == b.toLowerCase();

/// Filters, sorts and summarises [reports] (unit-tested).
PriceBoard computePriceBoard(List<PriceReport> reports, PriceQuery q, {String? uid, DateTime? now}) {
  final n = now ?? DateTime.now();
  final shown = reports.where((r) {
    if (q.mineOnly && !r.isMine(uid)) return false;
    if (q.crop != null && !_same(r.crop, q.crop!)) return false;
    if (q.region != null && !_same(r.region, q.region!)) return false;
    if (q.market != null && !_same(r.market, q.market!)) return false;
    return true;
  }).toList()
    ..sort((a, b) => switch (q.sort) {
          PriceSort.newest => b.at.compareTo(a.at),
          PriceSort.highest => b.price.compareTo(a.price),
          PriceSort.lowest => a.price.compareTo(b.price),
        });

  CropSummary? summary;
  if (q.crop != null) {
    final forCrop = reports.where((r) =>
        _same(r.crop, q.crop!) && (q.region == null || _same(r.region, q.region!)));
    summary = summariseCrop(q.crop!, forCrop.toList(), now: n);
  }

  final scope = q.crop == null ? reports : reports.where((r) => _same(r.crop, q.crop!));
  return PriceBoard(
    shown: shown,
    crops: _counts(reports.map((r) => r.crop)),
    regions: _counts(scope.map((r) => r.region)),
    markets: _counts(scope.map((r) => r.market)),
    summary: summary,
  );
}

/// Average, range, trend and best market for one crop's reports.
CropSummary? summariseCrop(String crop, List<PriceReport> reports, {DateTime? now}) {
  if (reports.isEmpty) return null;
  final n = now ?? DateTime.now();
  final cutoff = n.subtract(const Duration(days: 30));
  final recent = reports.where((r) => r.at.isAfter(cutoff)).toList();
  final use = recent.isNotEmpty ? recent : reports;
  final prices = use.map((r) => r.price).toList();
  final avg = prices.reduce((a, b) => a + b) / prices.length;

  final unitCounts = _counts(use.map((r) => r.unit));
  final byDay = <DateTime, List<double>>{};
  for (final r in use) {
    final d = DateTime(r.at.year, r.at.month, r.at.day);
    byDay.putIfAbsent(d, () => []).add(r.price);
  }
  final trend = byDay.entries.map((e) => (e.key, e.value.reduce((a, b) => a + b) / e.value.length)).toList()
    ..sort((a, b) => a.$1.compareTo(b.$1));

  final byMarket = <String, List<double>>{};
  for (final r in use) {
    if (r.market.isEmpty) continue;
    byMarket.putIfAbsent(r.market, () => []).add(r.price);
  }
  final markets = byMarket.entries
      .map((e) => MarketStat(e.key, e.value.reduce((a, b) => a + b) / e.value.length, e.value.length))
      .toList()
    ..sort((a, b) => b.average.compareTo(a.average));

  return CropSummary(
    crop: crop,
    count: use.length,
    average: avg,
    min: prices.reduce((a, b) => a < b ? a : b),
    max: prices.reduce((a, b) => a > b ? a : b),
    latest: use.map((r) => r.at).reduce((a, b) => a.isAfter(b) ? a : b),
    unit: unitCounts.isEmpty ? '' : unitCounts.first.$1,
    trend: trend,
    best: markets.length > 1 ? markets.first : null,
    lowest: markets.length > 1 ? markets.last : null,
    recentOnly: recent.isNotEmpty,
  );
}

// ── Riverpod ────────────────────────────────────────────────────────────────

final marketUidProvider = Provider<String?>((ref) => FirebaseAuth.instance.currentUser?.uid);

final priceReportsProvider = StreamProvider.autoDispose<List<PriceReport>>((ref) => FirebaseFirestore.instance
    .collection('marketdata')
    .orderBy('timestamp', descending: true)
    .limit(600)
    .snapshots()
    .map((s) => s.docs.map((d) => PriceReport.fromMap(d.id, d.data())).whereType<PriceReport>().toList()));

class PriceQueryNotifier extends Notifier<PriceQuery> {
  @override
  PriceQuery build() => const PriceQuery();
  void set(PriceQuery q) => state = q;
}

final priceQueryProvider = NotifierProvider.autoDispose<PriceQueryNotifier, PriceQuery>(PriceQueryNotifier.new);

final priceBoardProvider = Provider.autoDispose<AsyncValue<PriceBoard>>((ref) {
  final q = ref.watch(priceQueryProvider);
  final uid = ref.watch(marketUidProvider);
  return ref.watch(priceReportsProvider).whenData((r) => computePriceBoard(r, q, uid: uid));
});

class PriceReportsRepository {
  static CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('marketdata');

  static Future<void> save({
    String? id,
    required String crop,
    required String market,
    required String region,
    required double price,
    required String unit,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final data = {
      'userId': uid,
      'cropType': crop.trim(),
      'market': market.trim(),
      'region': region.trim(),
      'retailPrice': price,
      'unit': unit,
      'timestamp': FieldValue.serverTimestamp(),
    };
    if (id == null) {
      await _col.add(data);
    } else {
      await _col.doc(id).update(data);
    }
  }

  static Future<void> delete(String id) => _col.doc(id).delete();
}
