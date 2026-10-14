// lib/enterprise/features/agronomist/activity_tab.dart
//
// Agronomist panel → Activity: farmers' entries as they come in (pest and
// disease reports, photo IDs, field records and soil tests, actions taken
// on advice). Written by the Cloud Functions (farmerActivity) — only for
// farmers who share their records. "Notable only" = pests, diseases,
// unidentified problems, low nutrients, problems found from advice.

import 'package:flutter/material.dart';
import 'package:kilimomkononi/enterprise/features/agronomist/agronomist_data_service.dart';
import 'package:kilimomkononi/enterprise/features/agronomist/agronomist_widgets.dart';
import 'package:kilimomkononi/enterprise/features/agronomist/farmer_detail_screen.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_widgets.dart';
import 'package:kilimomkononi/settings/notifications/notification_style.dart';
import 'package:kilimomkononi/utils/friendly_error.dart';

class ActivityTab extends StatefulWidget {
  final bool testMode;
  const ActivityTab({super.key, required this.testMode});

  @override
  State<ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<ActivityTab> {
  bool _notableOnly = false;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(children: [
          const Expanded(
            child: Text('Live as farmers save their records',
                style: TextStyle(fontSize: 12, color: kAgroMuted)),
          ),
          FilterChip(
            label: const Text('Notable only'),
            selected: _notableOnly,
            onSelected: (v) => setState(() => _notableOnly = v),
          ),
        ]),
      ),
      Expanded(
        child: StreamBuilder<List<FarmerActivity>>(
          stream: AgronomistDataService.activity(notableOnly: _notableOnly),
          builder: (context, snap) {
            if (snap.hasError) {
              return AgroError(friendlyError(snap.error, 'Couldn\'t load farmer activity'),
                  onRetry: () => setState(() {}));
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator(color: AdvisoryColors.midGreen));
            }
            final list = snap.data!;
            if (list.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: AgroEmpty(Icons.inbox_outlined,
                    'Nothing yet. Farmers\' new pest, disease and soil records appear here as they save them.'),
              );
            }
            String? lastDay;
            final children = <Widget>[];
            for (final a in list) {
              final day = a.at == null ? 'Earlier' : dayHeading(a.at!);
              if (day != lastDay) {
                lastDay = day;
                children.add(Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                  child: Text(day, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kAgroMuted)),
                ));
              }
              children.add(_ActivityTile(a, testMode: widget.testMode));
            }
            return ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 96), children: children);
          },
        ),
      ),
    ]);
  }
}

class _ActivityTile extends StatelessWidget {
  final FarmerActivity a;
  final bool testMode;
  const _ActivityTile(this.a, {required this.testMode});

  (IconData, Color) get _look => switch (a.kind) {
        'pest' => (Icons.bug_report_outlined, kPestColor),
        'disease' => (Icons.coronavirus_outlined, kDiseaseColor),
        'field_record' => (Icons.grid_view_rounded, kSoilColor),
        'soil_action' => (Icons.science_outlined, kSoilColor),
        'advice_response' => (Icons.playlist_add_check_rounded, AdvisoryColors.verified),
        _ => (Icons.notes_rounded, kAgroMuted),
      };

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _look;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FarmerDetailScreen(farmerUid: a.farmerUid, initialName: a.farmerName, testMode: testMode),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: a.notable ? color.withValues(alpha: 0.4) : AdvisoryColors.border),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: a.farmerName, style: const TextStyle(fontWeight: FontWeight.w800)),
                      TextSpan(text: ' ${a.title}'),
                    ]),
                    style: const TextStyle(fontSize: 13, color: kAgroInk),
                  ),
                  const SizedBox(height: 3),
                  Wrap(spacing: 5, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    if (a.unidentified) const FlagTag('Unidentified', kUnknownColor, icon: Icons.help_outline_rounded),
                    for (final n in a.lowNutrients) FlagTag('Low $n', kLowColor),
                    if (a.flags.contains('found')) const FlagTag('Found', kLowColor),
                    Text(
                      [if (a.place.isNotEmpty) a.place, if (a.at != null) clockTime(a.at!)].join(' · '),
                      style: const TextStyle(fontSize: 11, color: kAgroMuted),
                    ),
                  ]),
                  if (a.detail.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(a.detail,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, color: kAgroMuted)),
                    ),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.black38),
            ]),
          ),
        ),
      ),
    );
  }
}
