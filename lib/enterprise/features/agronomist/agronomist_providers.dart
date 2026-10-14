// lib/enterprise/features/agronomist/agronomist_providers.dart
//
// Riverpod state for the Agronomist panel's farmer sections. Insights and
// the Farmers tab share one load per period (kept for a few minutes, like
// the server's cache).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kilimomkononi/enterprise/features/agronomist/agronomist_data_service.dart';
import 'package:kilimomkononi/enterprise/features/agronomist/farmer_records.dart';

/// Period, county and crop the Insights and Farmers tabs show.
class InsightsFilter {
  final int days;
  final String? county;
  final String? crop;
  const InsightsFilter({this.days = 30, this.county, this.crop});

  InsightsFilter copyWith({int? days, String? county, String? crop, bool clearCounty = false, bool clearCrop = false}) =>
      InsightsFilter(
        days: days ?? this.days,
        county: clearCounty ? null : (county ?? this.county),
        crop: clearCrop ? null : (crop ?? this.crop),
      );
}

class InsightsFilterNotifier extends Notifier<InsightsFilter> {
  @override
  InsightsFilter build() => const InsightsFilter();
  void set(InsightsFilter f) => state = f;
}

final insightsFilterProvider =
    NotifierProvider<InsightsFilterNotifier, InsightsFilter>(InsightsFilterNotifier.new);

/// Every farmer's records for a period (7 / 30 / 90 days).
final insightsDataProvider = FutureProvider.autoDispose.family<InsightsData, int>((ref, days) {
  final link = ref.keepAlive();
  final timer = Future.delayed(const Duration(minutes: 5), link.close);
  ref.onDispose(() => timer.ignore());
  return AgronomistDataService.insights(days);
});

/// One farmer's full record.
final farmerRecordProvider = FutureProvider.autoDispose.family<FarmerRecord, String>(
  (ref, uid) => AgronomistDataService.farmer(uid),
);
