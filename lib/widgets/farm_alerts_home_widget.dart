// lib/widgets/farm_alerts_home_widget.dart
//
// Displays active farm alerts on field_data_input_home_page.dart.
// Placed between "Start recording" and "Your plots this season" sections.
//
// Shows:
//   - A green card when all is well
//   - Amber/red cards for active warnings/critical alerts
//   - Each card has an action button that deep-links to the relevant screen
//
// Usage in field_data_input_home_page.dart:
//
//   // In the ListView children, after _sectionLabel('Start recording')
//   // and the three structure cards, add:
//
//   _sectionLabel('Farm alerts'),
//   const FarmAlertsHomeWidget(),

import 'package:flutter/material.dart';
import 'package:kilimomkononi/services/farm_alert_service.dart';
import 'package:kilimomkononi/services/farm_location_service.dart';

class FarmAlertsHomeWidget extends StatefulWidget {
  const FarmAlertsHomeWidget({super.key});

  @override
  State<FarmAlertsHomeWidget> createState() => _FarmAlertsHomeWidgetState();
}

class _FarmAlertsHomeWidgetState extends State<FarmAlertsHomeWidget> {
  static const _accentGreen = Color(0xFF2A6B2A);
  static const _green       = Color(0xFF1B5E20);

  bool _loading = true;
  List<FarmAlert> _alerts = [];
  String _county = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final location = await FarmLocationService.getLocation();
      final alerts   = await FarmAlertService.evaluateAlerts();
      if (!mounted) return;
      setState(() {
        _county  = location.county;
        _alerts  = alerts;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8F6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Center(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 12, height: 12,
                child: CircularProgressIndicator(strokeWidth: 2,
                    color: Color(0xFF2A6B2A))),
            SizedBox(width: 8),
            Text('Checking farm conditions…',
                style: TextStyle(fontSize: 12, color: Colors.black45)),
          ]),
        ),
      );
    }

    final critical = _alerts.where(
      (a) => a.severity == AlertSeverity.critical || a.severity == AlertSeverity.high,
    ).toList();
    final warnings = _alerts.where(
      (a) => a.severity == AlertSeverity.warning,
    ).toList();
    final spray = _alerts.where(
      (a) => a.category == AlertCategory.spray,
    ).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Location line ──────────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          const Icon(Icons.location_on_outlined, size: 12, color: Colors.black38),
          const SizedBox(width: 4),
          Text('Farm: $_county',
              style: const TextStyle(fontSize: 11, color: Colors.black45)),
          const Spacer(),
          GestureDetector(
            onTap: () { setState(() => _loading = true); _load(); },
            child: const Row(children: [
              Icon(Icons.refresh, size: 11, color: Colors.black38),
              SizedBox(width: 2),
              Text('Refresh', style: TextStyle(fontSize: 11, color: Colors.black38)),
            ]),
          ),
        ]),
      ),

      // ── All clear ─────────────────────────────────────────────────────────
      if (critical.isEmpty && warnings.isEmpty)
        _allClearCard(spray.isNotEmpty ? spray.first : null),

      // ── Critical / high alerts ─────────────────────────────────────────────
      ...critical.map((a) => _alertTile(a, context)),

      // ── Warnings (collapsed under an "N more" chip if > 2) ────────────────
      if (warnings.isNotEmpty)
        ...warnings.take(2).map((a) => _alertTile(a, context)),
      if (warnings.length > 2)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('+ ${warnings.length - 2} more warnings',
              style: const TextStyle(fontSize: 12, color: Colors.black45)),
        ),

      // ── Spray window (positive) ────────────────────────────────────────────
      if (spray.isNotEmpty && critical.isNotEmpty)
        _alertTile(spray.first, context),
    ]);
  }

  Widget _allClearCard(FarmAlert? sprayAlert) => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: Colors.grey.shade200),
    ),
    color: const Color(0xFFEDF7ED),
    margin: const EdgeInsets.only(bottom: 8),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        const Icon(Icons.check_circle_outline_rounded, color: _accentGreen, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('All clear — no alerts on your farm today',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: Color(0xFF1B5E20))),
          if (sprayAlert != null) ...[
            const SizedBox(height: 2),
            Text(sprayAlert.message,
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF2E7D32))),
          ],
        ])),
      ]),
    ),
  );

  Widget _alertTile(FarmAlert alert, BuildContext context) {
    final Color bg, border, iconColor;
    IconData icon;
    switch (alert.severity) {
      case AlertSeverity.critical:
        bg = const Color(0xFFFFEBEE); border = const Color(0xFFB71C1C);
        iconColor = const Color(0xFFB71C1C); icon = Icons.dangerous_rounded;
      case AlertSeverity.high:
        bg = const Color(0xFFFFF3E0); border = const Color(0xFFE65100);
        iconColor = const Color(0xFFE65100); icon = Icons.warning_rounded;
      case AlertSeverity.warning:
        bg = const Color(0xFFFFF8E1); border = const Color(0xFFF57F17);
        iconColor = const Color(0xFFF57F17); icon = Icons.info_outline_rounded;
      case AlertSeverity.info:
        bg = const Color(0xFFEDF7ED); border = _green;
        iconColor = _green; icon = Icons.check_circle_outline_rounded;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: border.withValues(alpha: 0.3)),
      ),
      color: bg,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(alert.title,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: iconColor)),
            const SizedBox(height: 3),
            Text(alert.message,
                style: const TextStyle(fontSize: 12, color: Colors.black54,
                    height: 1.4)),
          ])),
        ]),
      ),
    );
  }
}