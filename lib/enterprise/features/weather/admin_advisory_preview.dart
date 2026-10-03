// lib/enterprise/features/weather/admin_advisory_preview.dart
//
// Admin-only section on the Weather Station screen: every TEST advisory
// (drafts and published) rendered exactly as farmers would see it, with a
// status line explaining whether — and when — a farmer would see it. Updates
// live as you publish / unpublish in the Field Agronomist panel (test mode).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_conditions.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_widgets.dart';
import 'package:kilimomkononi/enterprise/features/weather/agronomic_advisory.dart';
import 'package:kilimomkononi/services/nuasense_service.dart';
import 'package:kilimomkononi/utils/friendly_error.dart';

class AdminAdvisoryPreview extends StatelessWidget {
  /// Live reading at the viewed station (null / unprovisioned = unknown).
  final NuaSenseReading? reading;
  final List<String> farmerCrops;
  final VoidCallback? onOpenPanel;

  const AdminAdvisoryPreview({
    super.key,
    this.reading,
    this.farmerCrops = const [],
    this.onOpenPanel,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('agronomic_advisories')
          .where('testOnly', isEqualTo: true)
          .snapshots(),
      builder: (context, snap) {
        final list = (snap.data?.docs ?? const [])
            .map(AgronomicAdvisory.fromDoc)
            .where((a) => a.status != AdvisoryStatus.archived)
            .toList()
          ..sort((a, b) {
            // Published first, then most recently changed.
            final p = (b.status == AdvisoryStatus.published ? 1 : 0)
                .compareTo(a.status == AdvisoryStatus.published ? 1 : 0);
            if (p != 0) return p;
            return (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0));
          });

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF3E5F5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCE93D8)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.science_outlined, size: 18, color: Color(0xFF4A148C)),
              const SizedBox(width: 6),
              const Expanded(
                child: Text('Admin preview · your TEST advisories',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF4A148C))),
              ),
              if (onOpenPanel != null)
                TextButton(onPressed: onOpenPanel, child: const Text('Open panel')),
            ]),
            const Text(
              'Only admins see this section. Each card is exactly what a farmer '
              'sees once published — test advisories never reach farmers.',
              style: TextStyle(fontSize: 11.5, color: Colors.black54, height: 1.35),
            ),
            const SizedBox(height: 10),
            if (snap.hasError)
              Text(friendlyError(snap.error, 'Could not load test advisories'),
                  style: const TextStyle(fontSize: 12, color: AdvisoryColors.red))
            else if (!snap.hasData)
              const LinearProgressIndicator(minHeight: 2)
            else if (list.isEmpty)
              const Text(
                'No test advisories yet. Open the panel, create one and publish it '
                'to see it appear here — and receive its push on this device.',
                style: TextStyle(fontSize: 12.5),
              )
            else
              for (final a in list) ...[
                _PreviewItem(advisory: a, reading: reading, farmerCrops: farmerCrops),
                const SizedBox(height: 12),
              ],
          ]),
        );
      },
    );
  }
}

class _PreviewItem extends StatelessWidget {
  final AgronomicAdvisory advisory;
  final NuaSenseReading? reading;
  final List<String> farmerCrops;
  const _PreviewItem({required this.advisory, this.reading, this.farmerCrops = const []});

  @override
  Widget build(BuildContext context) {
    final a = advisory;
    final published = a.status == AdvisoryStatus.published;
    final r = reading;
    final known = r != null && r.isProvisioned;
    final conditionActive = known && a.appliesTo(activeConditionKeys(r), r);
    final cropOk = cropsMatch(a.crops, farmerCrops);
    final condLabel = a.conditionLabel;

    final (IconData icon, Color color, String headline, String detail) = !published
        ? (
            Icons.visibility_off_outlined,
            Colors.grey.shade700,
            'NOT PUBLISHED · draft v${a.version}',
            'Farmers would not see this. Publish it in the panel to preview it live.',
          )
        : !known
            ? (
                Icons.help_outline_rounded,
                const Color(0xFF6A1B9A),
                'PUBLISHED (test) · shown when "$condLabel"',
                'No live station reading here, so it can\'t be matched right now.',
              )
            : conditionActive && cropOk
                ? (
                    Icons.visibility_rounded,
                    AdvisoryColors.verified,
                    'PUBLISHED (test) · would show NOW',
                    '"$condLabel" is active at this station and the crops match.',
                  )
                : (
                    Icons.schedule_rounded,
                    const Color(0xFFE65100),
                    'PUBLISHED (test) · not showing right now',
                    !conditionActive
                        ? 'Shown when "$condLabel" — not the current condition here.'
                        : 'Crops don\'t match this farm\'s recorded crops.',
                  );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(headline,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
            Text(detail, style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
          ]),
        ),
      ]),
      const SizedBox(height: 6),
      // Drafts are dimmed: they're not what farmers see yet.
      Opacity(
        opacity: published ? 1 : 0.55,
        child: VerifiedAdvisoryCard(
          advice: a.advice,
          crops: a.crops,
          condition: a.condition,
          conditionLabel: a.isCustomCondition ? a.conditionLabel : null,
          verifierName: published ? a.publishedByName : null,
          verifiedAt: published ? a.publishedAt : null,
          stationScoped: a.isStationScoped,
          preview: !published,
          testOnly: true,
        ),
      ),
    ]);
  }
}
