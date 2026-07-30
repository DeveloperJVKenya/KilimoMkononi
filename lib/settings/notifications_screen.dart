// lib/settings/notifications_screen.dart
//
// Three-tab notifications inbox:
//   Tab 1 — Farm Alerts   : live satellite + IoT condition alerts
//   Tab 2 — Reminders     : user-set Firestore field_reminders
//                           (pest mgmt, disease mgmt, field data input, farm mgmt)
//   Tab 3 — Farm Tasks    : tasks from FarmManagementScreen SharedPrefs
//
// Index fix: Firestore query uses ONLY .where('userId') with NO .orderBy()
//            so no composite index is needed. Sorting is done client-side.
//
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kilimomkononi/services/iot_sensor_service.dart';
import 'package:kilimomkononi/services/nuasense_service.dart';

import 'package:kilimomkononi/screens/Field%20Data%20Input/satellite_data_screen.dart'
    show computeConditionRisk, ConditionRisk;

import 'package:kilimomkononi/settings/notifications_settings_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  static const Color _green    = Color(0xFF003900);
  static const Color _critical = Color(0xFFB71C1C);
  static const Color _high     = Color(0xFFE65100);
  static const Color _moderate = Color(0xFFF9A825);

  late final TabController _tab;

  // Tab 1
  bool _loadingAlerts = true;
  List<_AlertItem> _alertItems = [];

  // Tab 2
  int _reminderCount = 0;   // upcoming reminders — updated by stream

  // Tab 3
  bool _loadingTasks = true;
  List<_FarmTaskItem> _overdueTasks  = [];
  List<_FarmTaskItem> _upcomingTasks = [];

  // Plot id → name map (for task display)
  Map<String, String> _plotNames = {};

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _loadAlerts();
    _loadFarmTasks();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // ── Tab 1: Farm Alerts ────────────────────────────────────────────────
  // Pulls from three sources: IoT sensor → satellite → NuaSense weather station.
  // Each alert is labelled with its source so the farmer knows where it came from.

  Future<void> _loadAlerts() async {
    if (!mounted) return;
    setState(() => _loadingAlerts = true);
    try {
      // ── Fetch all three sources concurrently ───────────────────────────
      IotSensorReading?  iot;
      NuaSenseReading?   ws;

      await Future.wait([
        IotSensorService.getReadingForFarm()
            .then<IotSensorReading?>((r) => iot = r)
            .catchError((_) => null),
        NuaSenseService.getLatestReading()
            .then((r) => ws = r)
            .catchError((_) => NuaSenseReading.empty()),
      ]);

      final risk  = computeConditionRisk(sat: null, iot: iot, rain7d: 0);
      final items = <_AlertItem>[];

      // ──────────────────────────────────────────────────────────────────
      // A) IoT-sensor alerts  (soil temperature, soil humidity)
      // ──────────────────────────────────────────────────────────────────
      if (iot != null) {
        // Soil heat stress
        if (iot!.temperature > 36) {
          items.add(_AlertItem(
            title:  'Soil Heat Stress — Critical',
            body:   'Soil sensor reads ${iot!.temperature.toStringAsFixed(1)}°C — '
                    'above 36°C root growth halts and fine roots begin to die. '
                    'Irrigate immediately and mulch to cool the soil.',
            risk:   ConditionRisk.critical,
            icon:   Icons.thermostat_outlined,
            source: _AlertSource.iotSensor,
          ));
        } else if (iot!.temperature > 32) {
          items.add(_AlertItem(
            title:  'Soil Temperature Elevated — High',
            body:   'Soil at ${iot!.temperature.toStringAsFixed(1)}°C. '
                    'Water in early morning to cool the root zone before peak heat.',
            risk:   ConditionRisk.high,
            icon:   Icons.thermostat_outlined,
            source: _AlertSource.iotSensor,
          ));
        }

        // Soil pH extreme — if available (some IoT models include pH)
        final ph = iot!.ph;
        if (ph > 0) {
          if (ph < 5.0) {
            items.add(_AlertItem(
              title:  'Soil pH Too Acidic — pH ${ph.toStringAsFixed(1)}',
              body:   'Soil pH ${ph.toStringAsFixed(1)} is below 5.0. '
                      'Most crops struggle below 5.5 — lime application is recommended. '
                      'Phosphorus and many micro-nutrients become unavailable at low pH.',
              risk:   ConditionRisk.high,
              icon:   Icons.science_outlined,
              source: _AlertSource.iotSensor,
            ));
          } else if (ph > 8.0) {
            items.add(_AlertItem(
              title:  'Soil pH Too Alkaline — pH ${ph.toStringAsFixed(1)}',
              body:   'Soil pH ${ph.toStringAsFixed(1)} is above 8.0. '
                      'Iron, manganese and zinc deficiencies are common at high pH. '
                      'Consider sulphur application or acidifying fertilisers.',
              risk:   ConditionRisk.moderate,
              icon:   Icons.science_outlined,
              source: _AlertSource.iotSensor,
            ));
          }
        }

        // EC (electrical conductivity) — salinity / over-fertilisation risk
        final ec = iot!.ec;
        if (ec > 4.0) {
          items.add(_AlertItem(
            title:  'Soil Salinity High — EC ${ec.toStringAsFixed(1)} µS/cm',
            body:   'High electrical conductivity suggests salt build-up or '
                    'excess fertiliser residue. Flush with clean water and reduce '
                    'fertiliser until EC drops below 2.0 µS/cm.',
            risk:   ConditionRisk.high,
            icon:   Icons.water_damage_outlined,
            source: _AlertSource.iotSensor,
          ));
        }
      }

      // ──────────────────────────────────────────────────────────────────
      // B) Satellite-derived / IoT-combo alerts (existing computeConditionRisk)
      // ──────────────────────────────────────────────────────────────────
      if (risk.fungalRisk != ConditionRisk.low) {
        items.add(_AlertItem(
          title:  'Fungal Disease Risk — ${_riskLabel(risk.fungalRisk)}',
          body:   risk.fungalMessage,
          risk:   risk.fungalRisk,
          icon:   Icons.science_outlined,
          source: _AlertSource.iotSensor,
        ));
      }
      if (risk.droughtRisk != ConditionRisk.low) {
        items.add(_AlertItem(
          title:  'Drought / Dry Stress — ${_riskLabel(risk.droughtRisk)}',
          body:   risk.droughtMessage,
          risk:   risk.droughtRisk,
          icon:   Icons.wb_sunny_outlined,
          source: _AlertSource.iotSensor,
        ));
      }
      if (risk.floodRisk != ConditionRisk.low) {
        final msg = risk.floodRisk == ConditionRisk.critical
            ? 'Severe waterlogging risk. Check drainage channels and raised beds immediately.'
            : risk.floodRisk == ConditionRisk.high
                ? 'High waterlogging likelihood. Ensure adequate field drainage.'
                : 'Moderate flood / waterlogging risk. Monitor low-lying areas.';
        items.add(_AlertItem(
          title:  'Waterlogging / Flood Risk — ${_riskLabel(risk.floodRisk)}',
          body:   msg,
          risk:   risk.floodRisk,
          icon:   Icons.water_outlined,
          source: _AlertSource.satellite,
        ));
      }
      if (risk.heatRisk != ConditionRisk.low) {
        final msg = risk.heatRisk == ConditionRisk.high
            ? 'Soil temperature above 36 °C. High risk of root damage — irrigate and mulch.'
            : 'Elevated heat stress. Irrigate during cooler morning/evening hours.';
        items.add(_AlertItem(
          title:  'Heat Stress — ${_riskLabel(risk.heatRisk)}',
          body:   msg,
          risk:   risk.heatRisk,
          icon:   Icons.thermostat_outlined,
          source: _AlertSource.satellite,
        ));
      }

      // ──────────────────────────────────────────────────────────────────
      // C) NuaSense weather-station alerts
      // ──────────────────────────────────────────────────────────────────
      if (ws != null) {
        // Spray window
        final goodWind = ws!.goodSprayWind;
        final noRain   = !ws!.rainingNow;
        final hour     = DateTime.now().hour;
        final inWindow = hour >= 6 && hour <= 17;
        final canSpray = goodWind && noRain && inWindow;
        if (!canSpray) {
          final reason = !goodWind
              ? 'Wind ${ws!.windSpeed.toStringAsFixed(1)} m/s — too high (need < 3 m/s). Drift will waste product and harm bees.'
              : !noRain
                  ? 'Currently raining — product washes off before it can work. Wait 2+ dry hours.'
                  : 'Outside safe spray hours (6am–5pm). Spray early morning for best results.';
          items.add(_AlertItem(
            title:  'Spray Window — Do Not Spray Yet',
            body:   reason,
            risk:   ConditionRisk.moderate,
            icon:   Icons.air_outlined,
            source: _AlertSource.weatherStation,
          ));
        }

        // Leaf wetness — disease trigger alert
        if (ws!.leafIsWet) {
          final wetReason = ws!.lwdReason.isNotEmpty
              ? ws!.lwdReason.replaceAll('_', ' ')
              : 'high humidity / dew';
          items.add(_AlertItem(
            title:  'Leaf Wetness Alert — Fungal Infection Risk',
            body:   'Station reports wet leaves ($wetReason). '
                    'Fungal spores germinate when leaves are wet for 4+ consecutive hours. '
                    'Scout for blight, mildew, rust today. '
                    'Do not spray foliar products while leaves are wet.',
            risk:   ws!.dewPointDepression <= 2
                ? ConditionRisk.critical
                : ConditionRisk.high,
            icon:   Icons.water_drop_rounded,
            source: _AlertSource.weatherStation,
          ));
        }

        // VPD / crop water stress
        if (ws!.vpd > 2.5) {
          items.add(_AlertItem(
            title:  'Crop Water Stress — Severe (VPD ${ws!.vpd.toStringAsFixed(1)} kPa)',
            body:   'Very high evaporation demand. Crops are losing water faster than '
                    'roots can supply it — wilting, tip-burn and fruit drop likely. '
                    'Irrigate immediately, preferably by drip or furrow to avoid wetting leaves.',
            risk:   ConditionRisk.critical,
            icon:   Icons.eco_outlined,
            source: _AlertSource.weatherStation,
          ));
        } else if (ws!.vpd > 1.8) {
          items.add(_AlertItem(
            title:  'Crop Water Stress — Moderate (VPD ${ws!.vpd.toStringAsFixed(1)} kPa)',
            body:   'High evaporation demand. Check soil moisture — if dry, '
                    'irrigate within the next 12 hours.',
            risk:   ConditionRisk.moderate,
            icon:   Icons.eco_outlined,
            source: _AlertSource.weatherStation,
          ));
        }

        // High humidity + warm = disease alert
        if (ws!.humidity > 85 && ws!.airTemp > 18 && ws!.airTemp < 30) {
          items.add(_AlertItem(
            title:  'High Fungal Disease Risk — Hot & Humid',
            body:   'Humidity ${ws!.humidity.toStringAsFixed(0)}% at ${ws!.airTemp.toStringAsFixed(1)}°C '
                    '— ideal conditions for late blight (tomatoes, potatoes), '
                    'grey leaf spot (maize) and downy mildew (beans, kales). '
                    'Apply preventive fungicide at next safe spray window.',
            risk:   ConditionRisk.high,
            icon:   Icons.coronavirus_outlined,
            source: _AlertSource.weatherStation,
          ));
        }

        // Pest pressure from degree-days
        if (ws!.ddAphidHour >= 1.2) {
          items.add(_AlertItem(
            title:  'Aphid Pressure — High',
            body:   'High temperature-based aphid development index today '
                    '(base 4.3°C). Scout maize, beans, tomatoes and cabbages '
                    'for colonies on growing tips and undersides of young leaves. '
                    'Consider spraying if colonies found on >10% of plants.',
            risk:   ConditionRisk.high,
            icon:   Icons.bug_report_outlined,
            source: _AlertSource.weatherStation,
          ));
        } else if (ws!.ddAphidHour >= 0.5) {
          items.add(_AlertItem(
            title:  'Aphid Pressure — Medium',
            body:   'Moderate aphid development conditions. Scout crops '
                    'and note populations — intervene if numbers are rising.',
            risk:   ConditionRisk.moderate,
            icon:   Icons.bug_report_outlined,
            source: _AlertSource.weatherStation,
          ));
        }

        if (ws!.ddWhiteflyHour >= 0.8) {
          items.add(_AlertItem(
            title:  'Whitefly Pressure — High',
            body:   'Hot conditions are accelerating whitefly development '
                    '(base 10°C). Check tomatoes, beans and kales for adults '
                    'on leaf undersides and sticky honeydew residue. '
                    'Yellow sticky traps help monitor populations.',
            risk:   ConditionRisk.high,
            icon:   Icons.pest_control_outlined,
            source: _AlertSource.weatherStation,
          ));
        }

        if (ws!.ddPtmHour >= 1.0) {
          items.add(_AlertItem(
            title:  'Potato Tuber Moth — High Pressure',
            body:   'Warm temperatures are accelerating potato tuber moth '
                    'development. Check potato and tomato plants for larvae '
                    'mining leaves and tubers. Hill up potatoes to prevent '
                    'egg-laying on exposed tubers.',
            risk:   ConditionRisk.high,
            icon:   Icons.pest_control_rodent_outlined,
            source: _AlertSource.weatherStation,
          ));
        }

        // Heavy rain + fertiliser leaching risk
        if (ws!.rainfall > 20) {
          items.add(_AlertItem(
            title:  'Heavy Rain — Fertiliser Leaching Risk',
            body:   '${ws!.rainfall.toStringAsFixed(1)} mm of rain recorded. '
                    'Nitrogen (especially urea) leaches quickly after heavy rain. '
                    'Wait until soil drains before applying fertiliser again. '
                    'Check for waterlogging in low-lying plots.',
            risk:   ConditionRisk.moderate,
            icon:   Icons.grain_rounded,
            source: _AlertSource.weatherStation,
          ));
        }
      }

      // No alerts from spray-window satellite path (already handled by WS above)
      // but keep for when WS is offline:
      if (ws == null && !risk.goodSprayWindow) {
        items.add(_AlertItem(
          title:  'Spray Window — Poor Conditions',
          body:   risk.sprayMessage,
          risk:   ConditionRisk.moderate,
          icon:   Icons.air_outlined,
          source: _AlertSource.satellite,
        ));
      }

      // Sort: critical → high → moderate; weather station alerts first within each tier
      items.sort((a, b) {
        final rc = b.risk.index.compareTo(a.risk.index);
        if (rc != 0) return rc;
        return a.source.index.compareTo(b.source.index);
      });

      if (mounted) setState(() { _alertItems = items; _loadingAlerts = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingAlerts = false);
    }
  }

  // ── Tab 3: Farm Tasks from SharedPreferences ──────────────────────────

  Future<void> _loadFarmTasks() async {
    if (!mounted) return;
    setState(() => _loadingTasks = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) { if (mounted) setState(() => _loadingTasks = false); return; }

      final prefs = await SharedPreferences.getInstance();

      // Load plot names so we can show "Maize Plot A" instead of a raw id
      final plotsRaw = prefs.getString('${uid}_v2_plots');
      final plots = <String, String>{};
      if (plotsRaw != null && plotsRaw.isNotEmpty) {
        try {
          final list = jsonDecode(plotsRaw) as List<dynamic>;
          for (final p in list) {
            final m = p as Map<String, dynamic>;
            final id   = (m['id']   as String?) ?? '';
            final name = (m['name'] as String?) ?? id;
            if (id.isNotEmpty) plots[id] = name;
          }
        } catch (_) {}
      }

      // Load tasks
      final tasksRaw = prefs.getString('${uid}_v2_tasks');
      if (tasksRaw == null || tasksRaw.isEmpty) {
        if (mounted) setState(() { _plotNames = plots; _loadingTasks = false; });
        return;
      }

      final List<dynamic> rawList = jsonDecode(tasksRaw) as List<dynamic>;
      final tasks = rawList
          .map((j) {
            try {
              return _FarmTaskItem.fromJson(j as Map<String, dynamic>);
            } catch (_) {
              return null;
            }
          })
          .whereType<_FarmTaskItem>()
          .toList();

      final today    = _dateOnly(DateTime.now());
      final _ = today.add(const Duration(days: 1));

      final overdue  = tasks
          .where((t) => !t.isDone && _dateOnly(t.dueDate).isBefore(today))
          .toList()
        ..sort((a, b) => b.dueDate.compareTo(a.dueDate));   // most overdue first

      final upcoming = tasks
          .where((t) => !t.isDone && !_dateOnly(t.dueDate).isBefore(today))
          .toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));   // soonest first

      if (mounted) {
        setState(() {
          _plotNames     = plots;
          _overdueTasks  = overdue;
          _upcomingTasks = upcoming;
          _loadingTasks  = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingTasks = false);
    }
  }

  // ── Shared helpers ────────────────────────────────────────────────────

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String _riskLabel(ConditionRisk r) {
    switch (r) {
      case ConditionRisk.critical: return 'Critical';
      case ConditionRisk.high:     return 'High';
      case ConditionRisk.moderate: return 'Moderate';
      case ConditionRisk.low:      return 'Low';
    }
  }

  Color _riskColor(ConditionRisk r) {
    switch (r) {
      case ConditionRisk.critical: return _critical;
      case ConditionRisk.high:     return _high;
      case ConditionRisk.moderate: return _moderate;
      case ConditionRisk.low:      return const Color(0xFF2E7D32);
    }
  }

  Color _reminderAccent(DateTime scheduled) {
    final now = DateTime.now();
    if (scheduled.isBefore(now))                    return Colors.grey;
    if (scheduled.difference(now).inHours  < 24)   return _high;
    if (scheduled.difference(now).inDays   < 3)    return _moderate;
    return _green;
  }

  IconData _reminderIcon(String title) {
    final t = title.toLowerCase();
    if (t.contains('spray'))                            return Icons.opacity_outlined;
    if (t.contains('weed'))                             return Icons.grass_outlined;
    if (t.contains('scout'))                            return Icons.search_outlined;
    if (t.contains('follow'))                           return Icons.check_circle_outline;
    if (t.contains('disease'))                          return Icons.coronavirus_outlined;
    if (t.contains('pest') || t.contains('bug'))        return Icons.bug_report_outlined;
    if (t.contains('fertilise') || t.contains('fertilize')) return Icons.science_outlined;
    return Icons.notifications_outlined;
  }

  String _reminderSource(String title) {
    final t = title.toLowerCase();
    if (t.contains('disease'))                          return 'Disease Management';
    if (t.contains('pest') || t.contains('spray') ||
        t.contains('scout') || t.contains('weed')) {
      return 'Pest Management';
    }
    if (t.contains('field') || t.contains('fertilise') ||
        t.contains('fertilize')) {
      return 'Field Data Input';
    }
    if (t.contains('farm'))                             return 'Farm Management';
    return 'Activity Reminder';
  }

  String _formatDateTime(DateTime dt) {
    final now  = DateTime.now();
    final diff = _dateOnly(dt).difference(_dateOnly(now)).inDays;
    final hh   = dt.hour.toString().padLeft(2, '0');
    final mm   = dt.minute.toString().padLeft(2, '0');
    if (diff ==  0) return 'Today $hh:$mm';
    if (diff ==  1) return 'Tomorrow $hh:$mm';
    if (diff == -1) return 'Yesterday';
    if (diff  <  0) return '${dt.day}/${dt.month}/${dt.year}  ·  Overdue';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatDueDate(DateTime dt) {
    final now  = DateTime.now();
    final diff = _dateOnly(dt).difference(_dateOnly(now)).inDays;
    if (diff ==  0) return 'Today';
    if (diff ==  1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday  ·  Overdue';
    if (diff  <  0) return '${dt.day}/${dt.month}/${dt.year}  ·  Overdue';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Future<void> _cancelReminder(BuildContext ctx, String docId, int? notifId) async {
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Remove reminder'),
        content: const Text('This reminder will be cancelled and removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, remove',
                style: TextStyle(color: _critical)),
          ),
        ],
      ),
    );
    if (confirm != true || !ctx.mounted) return;
    if (notifId != null) {
      try { await FlutterLocalNotificationsPlugin().cancel(id: notifId); } catch (_) {}
    }
    await FirebaseFirestore.instance
        .collection('field_reminders')
        .doc(docId)
        .delete();
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Reminder removed')));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications',
            style: TextStyle(color: Colors.white)),
        backgroundColor: _green,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.white),
            tooltip: 'Notification Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const NotificationsSettingsScreen()),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(
              icon: Icon(Icons.satellite_alt_outlined),
              child: Text(
                _alertItems.isEmpty
                    ? 'Farm Alerts'
                    : 'Farm Alerts (${_alertItems.length})',
                style: const TextStyle(fontSize: 11),
              ),
            ),
            Tab(
              icon: Icon(Icons.alarm_outlined),
              child: Text(
                _reminderCount == 0
                    ? 'Reminders'
                    : 'Reminders ($_reminderCount)',
                style: const TextStyle(fontSize: 11),
              ),
            ),
            Tab(
              icon: Icon(Icons.task_alt_outlined),
              child: Text(
                (_overdueTasks.length + _upcomingTasks.length) == 0
                    ? 'Farm Tasks'
                    : _overdueTasks.isNotEmpty
                        ? 'Farm Tasks (${_overdueTasks.length} overdue)'
                        : 'Farm Tasks (${_upcomingTasks.length})',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildAlertsTab(),
          _buildRemindersTab(),
          _buildFarmTasksTab(),
        ],
      ),
    );
  }

  // ── Tab 1: Farm Alerts ────────────────────────────────────────────────

  Widget _buildAlertsTab() {
    if (_loadingAlerts) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_alertItems.isEmpty) {
      return _emptyState(
        icon: Icons.check_circle_outline,
        title: 'No active farm alerts',
        subtitle:
            'Satellite, IoT sensor and weather station data all look healthy right now.\nPull down to refresh.',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadAlerts,
      child: ListView.builder(
        padding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        itemCount: _alertItems.length,
        itemBuilder: (_, i) => _alertCard(_alertItems[i]),
      ),
    );
  }

  Widget _alertCard(_AlertItem item) {
    final color = _riskColor(item.risk);

    // Source label + icon
    final (srcIcon, srcLabel) = switch (item.source) {
      _AlertSource.weatherStation => (Icons.sensors_rounded,     'Weather Station · Live'),
      _AlertSource.iotSensor      => (Icons.device_hub_outlined, 'IoT Sensor · Live'),
      _AlertSource.satellite      => (Icons.satellite_alt_outlined, 'Satellite · Live'),
    };

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              children: [
                Icon(item.icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(item.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.body,
                    style:
                        const TextStyle(fontSize: 13, height: 1.45)),
                const SizedBox(height: 10),
                Row(children: [
                  Icon(srcIcon, size: 13, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(srcLabel,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Reminders ──────────────────────────────────────────────────
  //
  // IMPORTANT: No .orderBy() in this query — sorting is done client-side
  // so no composite index is required. A simple single-field index on
  // 'userId' is enough and Firestore creates that automatically.

  Widget _buildRemindersTab() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return _emptyState(
          icon: Icons.lock_outline,
          title: 'Not signed in',
          subtitle: 'Sign in to see your reminders.');
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('field_reminders')
          .where('userId', isEqualTo: uid)
          // ↑ NO .orderBy() here — sort client-side to avoid index errors
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _emptyState(
              icon: Icons.error_outline,
              title: 'Could not load reminders',
              subtitle: snap.error.toString());
        }

        final docs = snap.data?.docs ?? [];

        if (docs.isEmpty) {
          return _emptyState(
            icon: Icons.alarm_off_outlined,
            title: 'No reminders yet',
            subtitle:
                'Reminders you set in Pest Management, Disease Management, '
                'and Field Data Input will appear here — spray schedules, '
                'weeding reminders, scouting checks, and custom reminders.',
          );
        }

        // Client-side sort by scheduledDate ascending
        final sorted = [...docs];
        sorted.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;

          // Handle both 'scheduledDate' and legacy 'scheduleDate' field names
          DateTime? aDate = _tsField(aData, 'scheduledDate') ??
                            _tsField(aData, 'scheduleDate');
          DateTime? bDate = _tsField(bData, 'scheduledDate') ??
                            _tsField(bData, 'scheduleDate');
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return aDate.compareTo(bDate);
        });

        final now      = DateTime.now();
        final upcoming = sorted.where((d) {
          final dt = _reminderDate(d);
          return dt != null && dt.isAfter(now);
        }).toList();
        final past = sorted.where((d) {
          final dt = _reminderDate(d);
          return dt != null && !dt.isAfter(now);
        }).toList();

        // Keep tab label count in sync without calling setState inside build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _reminderCount != upcoming.length) {
            setState(() => _reminderCount = upcoming.length);
          }
        });

        return ListView(
          padding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          children: [
            if (upcoming.isNotEmpty) ...[
              _sectionHeader(
                  'Upcoming (${upcoming.length})',
                  Icons.upcoming_outlined,
                  _green),
              ...upcoming.map((d) => _reminderCard(ctx, d, false)),
              const SizedBox(height: 4),
            ],
            if (past.isNotEmpty) ...[
              _sectionHeader(
                  'Past (${past.length})',
                  Icons.history_outlined,
                  Colors.grey),
              ...past.map((d) => _reminderCard(ctx, d, true)),
            ],
          ],
        );
      },
    );
  }

  /// Reads either 'scheduledDate' or the legacy 'scheduleDate' timestamp field.
  DateTime? _tsField(Map<String, dynamic> data, String key) {
    final val = data[key];
    if (val is Timestamp) return val.toDate();
    return null;
  }

  DateTime? _reminderDate(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return _tsField(data, 'scheduledDate') ?? _tsField(data, 'scheduleDate');
  }

  Widget _reminderCard(
      BuildContext ctx, QueryDocumentSnapshot doc, bool isPast) {
    final data    = doc.data()! as Map<String, dynamic>;
    final title   = data['title']  as String? ?? 'Reminder';
    final body    = data['body']   as String? ?? '';
    final dt      = _reminderDate(doc) ?? DateTime.now();
    final notifId = data['notifId'] as int?;
    final plotId  = data['plotId'] as String?;
    final source  = _reminderSource(title);
    final accent  = isPast ? Colors.grey : _reminderAccent(dt);
    final icon    = _reminderIcon(title);

    return Card(
      elevation: isPast ? 1 : 3,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isPast
              ? Colors.grey.withValues(alpha: 0.15)
              : accent.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isPast
                    ? Colors.grey[100]
                    : accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  size: 20,
                  color: isPast ? Colors.grey[400] : accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isPast
                              ? Colors.grey[600]
                              : Colors.black87,
                          decoration: isPast
                              ? TextDecoration.lineThrough
                              : TextDecoration.none)),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(body,
                        style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: Colors.grey[700])),
                  ],
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.schedule_outlined,
                        size: 12,
                        color: isPast ? Colors.grey : accent),
                    const SizedBox(width: 3),
                    Text(_formatDateTime(dt),
                        style: TextStyle(
                            fontSize: 11,
                            color: isPast ? Colors.grey : accent,
                            fontWeight: FontWeight.w500)),
                  ]),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    children: [
                      _chip(source, _green),
                      if (plotId != null &&
                          plotId.isNotEmpty &&
                          plotId != 'general')
                        _chip(plotId, Colors.teal[700]!),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              color: Colors.grey[400],
              tooltip: 'Remove',
              onPressed: () => _cancelReminder(ctx, doc.id, notifId),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab 3: Farm Tasks ─────────────────────────────────────────────────

  Widget _buildFarmTasksTab() {
    if (_loadingTasks) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_overdueTasks.isEmpty && _upcomingTasks.isEmpty) {
      return _emptyState(
        icon: Icons.task_alt_outlined,
        title: 'No pending farm tasks',
        subtitle:
            'Tasks you add in Farm Management — planting, weeding, '
            'spraying, harvesting — will appear here when they are due or overdue.',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadFarmTasks,
      child: ListView(
        padding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        children: [
          if (_overdueTasks.isNotEmpty) ...[
            _sectionHeader(
                'Overdue (${_overdueTasks.length})',
                Icons.warning_amber_outlined,
                _critical),
            ..._overdueTasks.map(_farmTaskCard),
            const SizedBox(height: 4),
          ],
          if (_upcomingTasks.isNotEmpty) ...[
            _sectionHeader(
                'Upcoming (${_upcomingTasks.length})',
                Icons.upcoming_outlined,
                _green),
            ..._upcomingTasks.map(_farmTaskCard),
          ],
        ],
      ),
    );
  }

  Widget _farmTaskCard(_FarmTaskItem t) {
    final isOverdue = _dateOnly(t.dueDate).isBefore(_dateOnly(DateTime.now()));
    final accent    = isOverdue ? _critical : _green;
    final priorityColor = t.priority == 'high'
        ? _critical
        : t.priority == 'medium'
            ? _moderate
            : _green;

    // Resolve plot id → human-readable plot name
    final plotLabel = t.plotId.isEmpty || t.plotId == 'all'
        ? null
        : _plotNames[t.plotId] ?? t.plotId;

    return Card(
      elevation: isOverdue ? 3 : 2,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: accent.withValues(alpha: 0.35),
          width: isOverdue ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isOverdue
                    ? Icons.warning_amber_outlined
                    : Icons.check_box_outline_blank,
                size: 20,
                color: accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  if (t.description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(t.description,
                        style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: Colors.grey[700])),
                  ],
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 12, color: accent),
                    const SizedBox(width: 3),
                    Text(_formatDueDate(t.dueDate),
                        style: TextStyle(
                            fontSize: 11,
                            color: accent,
                            fontWeight: FontWeight.w500)),
                  ]),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (plotLabel != null)
                        _chip(plotLabel, _green),
                      _chip(_categoryLabel(t.category),
                          priorityColor),
                      if (t.priority == 'high')
                        _chip('High Priority', _critical),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _categoryLabel(String cat) {
    switch (cat) {
      case 'planting':    return 'Planting';
      case 'watering':    return 'Watering';
      case 'weeding':     return 'Weeding';
      case 'spraying':    return 'Spraying';
      case 'fertilising': return 'Fertilising';
      case 'harvesting':  return 'Harvesting';
      case 'scouting':    return 'Scouting';
      default:            return cat.isNotEmpty
                              ? cat[0].toUpperCase() + cat.substring(1)
                              : 'General';
    }
  }

  // ── Shared UI helpers ─────────────────────────────────────────────────

  Widget _sectionHeader(String label, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 13, color: color)),
      ]),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[500],
                    height: 1.5)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Local data models
// ─────────────────────────────────────────────────────────────────────────────

enum _AlertSource { satellite, weatherStation, iotSensor }

class _AlertItem {
  final String        title;
  final String        body;
  final ConditionRisk risk;
  final IconData      icon;
  final _AlertSource  source;
  const _AlertItem({
    required this.title,
    required this.body,
    required this.risk,
    required this.icon,
    this.source = _AlertSource.satellite,
  });
}

class _FarmTaskItem {
  final String   id;
  final String   title;
  final String   description;
  final String   plotId;
  final String   priority;
  final String   category;
  final DateTime dueDate;
  final bool     isDone;

  const _FarmTaskItem({
    required this.id,
    required this.title,
    required this.description,
    required this.plotId,
    required this.priority,
    required this.category,
    required this.dueDate,
    required this.isDone,
  });

  factory _FarmTaskItem.fromJson(Map<String, dynamic> j) {
    return _FarmTaskItem(
      id:          (j['id']          as String?) ?? '',
      title:       (j['title']       as String?) ?? 'Task',
      description: (j['description'] as String?) ?? '',
      plotId:      (j['plotId']      as String?) ?? '',
      priority:    (j['priority']    as String?) ?? 'normal',
      category:    (j['category']    as String?) ?? 'other',
      dueDate:     j['dueDate'] != null
                       ? DateTime.tryParse(j['dueDate'] as String) ??
                         DateTime.now()
                       : DateTime.now(),
      isDone:      (j['isDone'] as bool?) ?? false,
    );
  }
}