// lib/education/education_weather_forecast.dart

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:kilimomkononi/utils/firestore_helper.dart';

import '../../utils/class_id_notifier.dart';
import '../../models/education_user.dart';
import '../../config.dart';
import 'simulations/weather_prediction_simulation.dart';
import 'quiz/shared_quiz_widgets.dart';

const Color primaryGreen = Color(0xFF032704);

extension StringExt on String {
  String capitalize() =>
      isNotEmpty ? '${this[0].toUpperCase()}${substring(1)}' : this;
}

extension TextEditingControllerExt on TextEditingController {
  String get safeText => text.trim();
}

// ─── Weather data models (unchanged) ──────────────────────────────────────

class WeatherCurrent {
  final double temp;
  final String desc;
  final String icon;
  final double humidity;
  final double windSpeed;
  final int    pressure;

  WeatherCurrent.fromJson(Map<String, dynamic> json)
      : temp      = (json['main']['temp']      as num).toDouble(),
        desc      = json['weather'][0]['description']
                        .toString()
                        .capitalize(),
        icon      = json['weather'][0]['icon'] as String,
        humidity  = (json['main']['humidity']  as num).toDouble(),
        windSpeed = (json['wind']['speed']     as num).toDouble(),
        pressure  = json['main']['pressure']   as int;
}

class WeatherForecastDay {
  final String       date;
  final double       minTemp;
  final double       maxTemp;
  final List<String> descriptions;
  final List<String> icons;

  WeatherForecastDay({
    required this.date,
    required this.minTemp,
    required this.maxTemp,
    required this.descriptions,
    required this.icons,
  });
}

// ═══════════════════════════════════════════════════════════════════════════

class EducationWeatherForecast extends StatefulWidget {
  final EduRole role;
  final String  schoolName;
  final String  classId;

  const EducationWeatherForecast({
    super.key,
    required this.role,
    required this.schoolName,
    required this.classId,
  });

  @override
  State<EducationWeatherForecast> createState() =>
      _EducationWeatherForecastState();
}

class _EducationWeatherForecastState
    extends State<EducationWeatherForecast> {
  final _locCtrl = TextEditingController();

  String? _observedWeather;
  final List<Map<String, dynamic>> _weatherConditions = [
    {'label': 'Sunny',         'icon': Icons.wb_sunny,    'color': Colors.orange},
    {'label': 'Partly Sunny',  'icon': Icons.wb_cloudy,   'color': Colors.amber},
    {'label': 'Cloudy',        'icon': Icons.cloud,       'color': Colors.grey},
    {'label': 'Rainy',         'icon': Icons.grain,       'color': Colors.blue},
    {'label': 'Stormy',        'icon': Icons.flash_on,    'color': Colors.deepPurple},
    {'label': 'Windy',         'icon': Icons.air,         'color': Colors.cyan},
    {'label': 'Broken Clouds', 'icon': Icons.wb_cloudy,   'color': Colors.blueGrey},
    {'label': 'Light Showers', 'icon': Icons.ac_unit,     'color': Colors.lightBlue},
  ];

  WeatherCurrent?        _current;
  List<WeatherForecastDay>? _forecast;
  String?                _locationName;
  bool                   _loading = false;
  String                 _error   = '';

  final String _contentType = 'weather_content';

  // ── Grade helpers ────────────────────────────────────────────────

  bool get _isPrimary {
    if (widget.classId.contains('cbcPrimary')) return true;
    final match = RegExp(r'_(\d+)$').firstMatch(widget.classId);
    if (match != null) {
      return (int.tryParse(match.group(1)!) ?? 7) <= 6;
    }
    return false;
  }

  String get _gradeLabel {
    final match =
        RegExp(r'_(\d+)$').firstMatch(widget.classId);
    if (match != null) {
      final n = match.group(1)!;
      if (widget.classId.contains('eightfourfour')) {
        final num = int.tryParse(n) ?? 1;
        return num <= 8 ? 'Standard $n' : 'Form ${num - 8}';
      }
      return 'Grade $n';
    }
    return widget.classId;
  }

  /// Subject string passed to Gemini.
  String get _geminiSubject =>
      'weather patterns, climate and agriculture in Kenya';

  @override
  void initState() {
    super.initState();
    classIdNotifier.value = widget.classId;
  }

  @override
  void dispose() {
    _locCtrl.dispose();
    super.dispose();
  }

  // ── Quiz builder ─────────────────────────────────────────────────

  void _showQuizBuilder() => showDialog(
        context: context,
        builder: (_) => EduQuizBuilder(
          onSave:        (d) => _saveContent('quiz', d),
          topicLabel:    'Weather',
          geminiSubject: _geminiSubject,
          grade:         _gradeLabel,
          isPrimary:     _isPrimary,
        ),
      );

  void _showSimBuilder() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WeatherPredictionSimulation(
          classId: widget.classId,
          module: 'Weather Forecast',
          studentName: FirebaseAuth.instance.currentUser?.displayName ?? 'Student',
          onComplete: () {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Weather prediction simulation completed!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
        ),
      ),
    );
  }

  // ── Weather API ───────────────────────────────────────────────────

  void _selectObservedWeather(String condition) {
    setState(() => _observedWeather = condition);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Observed: $condition today!'),
        backgroundColor: primaryGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _fetchWeather() async {
    final loc = _locCtrl.safeText;
    if (loc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a city')),
      );
      return;
    }

    setState(() {
      _loading  = true;
      _error    = '';
      _current  = null;
      _forecast = null;
    });

    try {
      final coords = await _getCoordinates(loc);
      if (coords == null) {
        setState(() {
          _error   = 'Location not found';
          _loading = false;
        });
        return;
      }

      final current      = await _fetchCurrentWeather(coords);
      final forecastData = await _fetchForecast(coords);

      if (mounted) {
        setState(() {
          _current      = current;
          _forecast     = _groupForecastByDay(forecastData);
          _locationName = loc.capitalize();
          _loading      = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error   = 'Failed to load weather';
          _loading = false;
        });
      }
    }
  }

  Future<Map<String, double>?> _getCoordinates(
      String loc) async {
    final url =
        'https://api.openweathermap.org/geo/1.0/direct?q=$loc&limit=1&appid=${Config.weatherApiKey}';
    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200 && res.body.isNotEmpty) {
      final data = jsonDecode(res.body)[0];
      return {
        'lat': data['lat'] as double,
        'lon': data['lon'] as double
      };
    }
    return null;
  }

  Future<WeatherCurrent> _fetchCurrentWeather(
      Map<String, double> coords) async {
    final url =
        'https://api.openweathermap.org/data/2.5/weather?lat=${coords['lat']}&lon=${coords['lon']}&appid=${Config.weatherApiKey}&units=metric';
    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) {
      return WeatherCurrent.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed current weather');
  }

  Future<List<dynamic>> _fetchForecast(
      Map<String, double> coords) async {
    final url =
        'https://api.openweathermap.org/data/2.5/forecast?lat=${coords['lat']}&lon=${coords['lon']}&appid=${Config.weatherApiKey}&units=metric';
    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) {
      return jsonDecode(res.body)['list'];
    }
    throw Exception('Failed forecast');
  }

  List<WeatherForecastDay> _groupForecastByDay(
      List<dynamic> list) {
    final Map<String, List<dynamic>> grouped = {};
    for (var item in list) {
      final date =
          (item['dt_txt'] as String).split(' ')[0];
      grouped.putIfAbsent(date, () => []).add(item);
    }

    return grouped.entries.map((entry) {
      final temps = entry.value
          .map((i) =>
              (i['main']['temp'] as num).toDouble())
          .toList();
      final descs = entry.value
          .map((i) =>
              i['weather'][0]['description'] as String)
          .toSet()
          .toList();
      final icons = entry.value
          .map((i) => i['weather'][0]['icon'] as String)
          .toList();

      return WeatherForecastDay(
        date:     DateFormat('EEEE, MMM d')
            .format(DateTime.parse(entry.key)),
        minTemp:  temps.reduce((a, b) => a < b ? a : b),
        maxTemp:  temps.reduce((a, b) => a > b ? a : b),
        descriptions: descs,
        icons:    icons,
      );
    }).toList();
  }

  Widget _buildWeatherIcon(String iconCode,
      {double size = 50}) {
    return Image.network(
      'https://openweathermap.org/img/wn/$iconCode@2x.png',
      width:  size,
      height: size,
      errorBuilder: (_, _, _) =>
          Icon(Icons.cloud, size: size, color: Colors.grey),
    );
  }

  Future<void> _saveContent(
      String type, Map<String, dynamic> data) async {
    await FirestoreHelper.ensureGradeExists(widget.classId);
    if (!mounted) return;
    final collection = FirestoreHelper.getContentFromClassId(
        widget.classId, _contentType);
    if (collection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Invalid class configuration')),
      );
      return;
    }

    final String title = data['title'] as String? ??
        '${type.capitalize()} Activity';

    try {
      await collection.add({
        'type':      type,
        'title':     title,
        'data':      jsonEncode(type == 'quiz'
            ? data['questions']
            : data['steps']),
        'createdAt': FieldValue.serverTimestamp(),
        'userId':
            FirebaseAuth.instance.currentUser!.uid,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('$title saved successfully!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to save: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _launchContent(
      String type, String docId) async {
    final rawCollection = FirestoreHelper.getContentFromClassId(
        widget.classId, _contentType);
    if (rawCollection == null) return;

    try {
      final doc    = await rawCollection.doc(docId).get();
      if (!mounted) return;
      final dataMap =
          doc.data() as Map<String, dynamic>?;

      if (dataMap == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to load content')),
        );
        return;
      }

      final String title = dataMap['title'] is String &&
              (dataMap['title'] as String).trim().isNotEmpty
          ? (dataMap['title'] as String).trim()
          : '${type.capitalize()} Activity';

      final payload =
          jsonDecode(dataMap['data'] as String);

      final fullPayload = {
        'id':    doc.id,
        'title': title,
        'grade': _gradeLabel,
        'module': 'Weather Forecast',
        if (type == 'quiz')       'questions': payload,
        if (type == 'simulation') 'steps':     payload,
      };

      if (!mounted) return;

      if (type == 'quiz') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EduQuizScreen(
              payload:       fullPayload,
              classId:       widget.classId,
              isPrimary:     _isPrimary,
              geminiSubject: _geminiSubject,
            ),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WeatherPredictionSimulation(
              classId: widget.classId,
              module: 'Weather Forecast',
              studentName: FirebaseAuth.instance.currentUser?.displayName ?? 'Student',
              onComplete: () async {
                final coll =
                    FirestoreHelper.getSubmissionsFromClassId(
                        widget.classId);
                if (coll != null) {
                  await coll.add({
                    'type':         'simulation',
                    'simulationId': doc.id,
                    'title':        title,
                    'userId':
                        FirebaseAuth.instance.currentUser!.uid,
                    'createdAt':
                        FieldValue.serverTimestamp(),
                  });
                }
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Weather simulation completed! 🎉'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    final now  = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7)  return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final double width   = MediaQuery.of(context).size.width;
    final bool isMobile  = width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weather Station'),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        leading: isMobile
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // OBSERVED WEATHER
            const Text(
                'How is the weather today at school?',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _weatherConditions.map((condition) {
                final isSelected =
                    _observedWeather == condition['label'];
                return GestureDetector(
                  onTap: () => _selectObservedWeather(
                      condition['label']),
                  child: AnimatedContainer(
                    duration:
                        const Duration(milliseconds: 250),
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? primaryGreen
                          : Colors.white,
                      borderRadius:
                          BorderRadius.circular(16),
                      border: Border.all(
                          color: isSelected
                              ? primaryGreen
                              : Colors.grey.shade300,
                          width: 2),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Icon(condition['icon'],
                            size: 40,
                            color: isSelected
                                ? Colors.white
                                : condition['color']),
                        const SizedBox(height: 8),
                        Text(
                          condition['label'],
                          style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 32),

            // ACTIVITIES SECTION
            if (widget.role != EduRole.headteacher)
              Padding(
                padding:
                    const EdgeInsets.only(bottom: 24),
                child: Card(
                  color: Colors.green.shade50,
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                        color: primaryGreen, width: 2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.assignment_turned_in,
                              size: 28, color: primaryGreen),
                          const SizedBox(width: 10),
                          Text('Practice Activities',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: primaryGreen)),
                        ]),
                        const SizedBox(height: 6),
                        const Text(
                            'Test your weather knowledge!',
                            style: TextStyle(
                                fontSize: 14,
                                color: Colors.black54)),
                        const SizedBox(height: 14),
                        SizedBox(
                            width: double.infinity,
                            child: _buildQuizSection()),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(
                                  vertical: 12),
                          child: Row(children: [
                            const Expanded(
                                child:
                                    Divider(thickness: 1)),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 10),
                              child: Text('or try',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors
                                          .grey.shade500)),
                            ),
                            const Expanded(
                                child:
                                    Divider(thickness: 1)),
                          ]),
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _showSimBuilder,
                            icon: const Icon(
                                Icons.play_circle_outline,
                                size: 22),
                            label: const Text(
                                'Run Interactive Simulation',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight:
                                        FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryGreen,
                              side: const BorderSide(
                                  color: primaryGreen,
                                  width: 1.5),
                              padding:
                                  const EdgeInsets.symmetric(
                                      vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(
                                          10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // FORECAST SECTION
            const Text('5-Day Weather Forecast',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _locCtrl,
              decoration: InputDecoration(
                hintText:
                    'Enter city name (e.g. Nairobi, Mombasa, London)',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                prefixIcon:
                    const Icon(Icons.location_on),
                suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _fetchWeather),
              ),
              onSubmitted: (_) => _fetchWeather(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    _loading ? null : _fetchWeather,
                icon: const Icon(Icons.cloud_download),
                label: const Text('Load Forecast'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16)),
              ),
            ),

            if (_loading)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(
                          color: primaryGreen))),
            if (_error.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_error,
                      style: const TextStyle(
                          color: Colors.red))),

            // OBSERVATION VS FORECAST
            if (_observedWeather != null &&
                _current != null)
              Padding(
                padding: const EdgeInsets.only(
                    top: 24, bottom: 16),
                child: Card(
                  color: Colors.blue.shade50,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.compare_arrows,
                              color: primaryGreen, size: 28),
                          const SizedBox(width: 10),
                          Text(
                              'Observation vs Forecast',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: primaryGreen)),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                            child: Column(children: [
                              const Text('You observed:',
                                  style: TextStyle(
                                      fontWeight:
                                          FontWeight.bold)),
                              const SizedBox(height: 8),
                              Icon(
                                  _weatherConditions
                                      .firstWhere((c) =>
                                          c['label'] ==
                                          _observedWeather)['icon'],
                                  size: 50,
                                  color: _weatherConditions
                                      .firstWhere((c) =>
                                          c['label'] ==
                                          _observedWeather)['color']),
                              Text(_observedWeather!,
                                  style: const TextStyle(
                                      fontSize: 18)),
                            ]),
                          ),
                          const Icon(Icons.arrow_forward,
                              size: 30, color: Colors.grey),
                          Expanded(
                            child: Column(children: [
                              const Text('Forecast says:',
                                  style: TextStyle(
                                      fontWeight:
                                          FontWeight.bold)),
                              const SizedBox(height: 8),
                              _buildWeatherIcon(
                                  _current!.icon, size: 50),
                              Text(_current!.desc,
                                  style: const TextStyle(
                                      fontSize: 18)),
                            ]),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        Text(
                          _observedWeather!
                                      .toLowerCase()
                                      .contains(_current!.desc
                                          .toLowerCase()) ||
                                  _current!.desc
                                      .toLowerCase()
                                      .contains(
                                          _observedWeather!
                                              .toLowerCase())
                              ? '✅ Your observation matches the forecast!'
                              : 'ℹ️ There might be a difference today — weather can be unpredictable!',
                          style: TextStyle(
                            fontSize: 16,
                            color: _observedWeather!
                                    .toLowerCase()
                                    .contains(_current!.desc
                                        .toLowerCase())
                                ? Colors.green
                                : Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 5-DAY FORECAST
            if (_forecast != null && _forecast!.isNotEmpty)
              Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  Text(
                    'Forecast for $_locationName',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryGreen),
                  ),
                  const SizedBox(height: 16),
                  ..._forecast!.map(
                    (day) => Card(
                      margin: const EdgeInsets.only(
                          bottom: 12),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(day.date,
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight:
                                            FontWeight.bold)),
                                const SizedBox(height: 8),
                                ...day.descriptions.map(
                                    (d) => Text('• $d',
                                        style: const TextStyle(
                                            fontSize: 15))),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: day.icons
                                  .map((i) => Padding(
                                        padding:
                                            const EdgeInsets
                                                .symmetric(
                                                    vertical:
                                                        4),
                                        child:
                                            _buildWeatherIcon(
                                                i, size: 40),
                                      ))
                                  .toList(),
                            ),
                          ),
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.end,
                            children: [
                              Text(
                                  '${day.maxTemp.round()}°C',
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight:
                                          FontWeight.bold,
                                      color: Colors.red)),
                              Text(
                                  '${day.minTemp.round()}°C',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.blue)),
                            ],
                          ),
                        ]),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
      bottomNavigationBar:
          (widget.role == EduRole.headteacher ||
                  widget.role == EduRole.student)
              ? null
              : Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey[50],
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _showQuizBuilder,
                        icon: const Icon(Icons.quiz),
                        label: const Text(
                            'Create Weather Quiz'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          foregroundColor: Colors.white,
                          minimumSize:
                              const Size(double.infinity, 52),
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                TeacherEssayReviewScreen(
                              classId:    widget.classId,
                              schoolName: widget.schoolName,
                            ),
                          ),
                        ),
                        icon: const Icon(
                            Icons.rate_review_outlined),
                        label: const Text(
                            'Review essay submissions'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryGreen,
                          side: const BorderSide(
                              color: primaryGreen),
                          minimumSize:
                              const Size(double.infinity, 44),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  // ── Quiz section (same pattern as other modules) ──────────────────

  Widget _buildQuizSection() {
    final raw = FirestoreHelper.getContentFromClassId(widget.classId, _contentType);
    if (raw == null) {
      return _SplitActivityButtons(mcqCount: 0, essayCount: 0, onMcqTap: null, onEssayTap: null);
    }
    final coll = raw.withConverter<Map<String, dynamic>>(
      fromFirestore: (s, _) => s.data()!,
      toFirestore:   (d, _) => d,
    );
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: coll.where('type', isEqualTo: 'quiz').snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        int mcqDocs = 0, essayDocs = 0;
        for (final doc in docs) {
          final data = doc.data();
          List<dynamic> qs = [];
          try {
            final raw = data['data'];
            qs = raw is String ? (jsonDecode(raw) as List? ?? []) : (raw as List? ?? []);
          } catch (_) {}
          if (qs.any((q) => (q as Map<String, dynamic>?)?['type'] != 'essay')) mcqDocs++;
          if (qs.any((q) => (q as Map<String, dynamic>?)?['type'] == 'essay')) essayDocs++;
        }
        return _SplitActivityButtons(
          mcqCount:   mcqDocs,
          essayCount: essayDocs,
          onMcqTap:   mcqDocs   == 0 ? null : () => _showActivityList('quiz', essayOnly: false),
          onEssayTap: essayDocs == 0 ? null : () => _showActivityList('quiz', essayOnly: true),
        );
      },
    );
  }

  void _showActivityList(String type, {bool essayOnly = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize:     0.95,
        minChildSize:     0.6,
        expand: false,
        builder: (_, controller) =>
            _buildContentList(type, scrollController: controller, essayOnly: essayOnly),
      ),
    );
  }

  Widget _buildContentList(String type,
      {ScrollController? scrollController, bool essayOnly = false}) {
    final rawCollection = FirestoreHelper.getContentFromClassId(
        widget.classId, _contentType);
    if (rawCollection == null) {
      return const Center(
          child: Text('Invalid configuration'));
    }

    final CollectionReference<Map<String, dynamic>>
        collection = rawCollection
            .withConverter<Map<String, dynamic>>(
      fromFirestore: (s, _) => s.data()!,
      toFirestore:   (d, _) => d,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            essayOnly ? 'Essay Assignments' : 'Quizzes',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: primaryGreen),
          ),
        ),
        Expanded(
          child:
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: collection
                .where('type', isEqualTo: type)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: primaryGreen));
              }
              if (!snapshot.hasData ||
                  snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Text('No ${type}s available yet',
                      style: const TextStyle(
                          fontSize: 18,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey)),
                );
              }

              final userId =
                  FirebaseAuth.instance.currentUser!.uid;
              final submissionsColl =
                  FirestoreHelper.getSubmissionsFromClassId(
                      widget.classId);

              return FutureBuilder<Set<String>>(
                future: submissionsColl == null
                    ? Future.value(<String>{})
                    : submissionsColl
                        .where('userId', isEqualTo: userId)
                        .where('type', isEqualTo: type)
                        .get()
                        .then((s) => s.docs
                            .map((d) {
                              final data = d.data();
                              if (data
                                  is Map<String, dynamic>) {
                                return data['${type}Id']
                                    as String?;
                              }
                              return null;
                            })
                            .whereType<String>()
                            .toSet()),
                builder: (context, completedSnap) {
                  final completedIds =
                      completedSnap.data ?? <String>{};
                  final filteredByType = essayOnly
                      ? snapshot.data!.docs.where((doc) {
                          final raw = doc.data()['data'];
                          List<dynamic> qs = [];
                          try {
                            qs = raw is String
                                ? (jsonDecode(raw) as List? ?? [])
                                : (raw as List? ?? []);
                          } catch (_) {}
                          return qs.any((q) =>
                              (q as Map<String, dynamic>?)?['type'] ==
                              'essay');
                        }).toList()
                      : snapshot.data!.docs;

                  final isTeacher =
                      widget.role == EduRole.teacher;
                  final availableDocs = isTeacher
                      ? filteredByType
                      : filteredByType
                          .where((doc) => !completedIds
                              .contains(doc.id))
                          .toList();

                  if (availableDocs.isEmpty) {
                    return Center(
                      child: Text(
                        isTeacher
                            ? 'No ${type}s created yet'
                            : 'All completed! Great job! 🎉',
                        style: const TextStyle(fontSize: 18),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: availableDocs.length,
                    itemBuilder: (context, index) {
                      final doc   = availableDocs[index];
                      final data  = doc.data();
                      final title = data['title'] as String? ??
                          'Untitled ${type.capitalize()}';
                      final createdAt =
                          data['createdAt'] as Timestamp?;

                      return Card(
                        margin: const EdgeInsets.only(
                            bottom: 12),
                        elevation: 4,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: primaryGreen,
                            child: Icon(
                                type == 'quiz'
                                    ? Icons.quiz
                                    : Icons.play_circle,
                                color: Colors.white),
                          ),
                          title: Text(title,
                              style: const TextStyle(
                                  fontWeight:
                                      FontWeight.bold)),
                          subtitle: createdAt != null
                              ? Text(
                                  'Created: ${_formatDate(createdAt.toDate())}')
                              : null,
                          trailing: const Icon(
                              Icons.arrow_forward_ios),
                          onTap: () {
                            Navigator.pop(context);
                            _launchContent(type, doc.id);
                          },
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Shared split-button widget ──────────────────────────────────────────────

class _SplitActivityButtons extends StatelessWidget {
  final int mcqCount, essayCount;
  final VoidCallback? onMcqTap, onEssayTap;
  const _SplitActivityButtons({required this.mcqCount, required this.essayCount, required this.onMcqTap, required this.onEssayTap});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _btn(icon: Icons.check_circle_outline, label: 'Quizzes', count: mcqCount,
              color: Colors.blue.shade600, bgColor: Colors.blue.shade50, onTap: onMcqTap),
          const SizedBox(height: 8),
          _btn(icon: Icons.edit_note, label: 'Essay assignments', count: essayCount,
              color: Colors.purple.shade600, bgColor: Colors.purple.shade50, onTap: onEssayTap),
        ],
      );

  Widget _btn({required IconData icon, required String label, required int count,
      required Color color, required Color bgColor, required VoidCallback? onTap}) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: onTap == null ? Colors.grey.shade100 : bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: onTap == null ? Colors.grey.shade300 : color.withValues(alpha: 0.35)),
          ),
          child: Row(children: [
            Icon(icon, color: onTap == null ? Colors.grey : color, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14,
                color: onTap == null ? Colors.grey : color))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: onTap == null ? Colors.grey.shade200 : color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(count == 0 ? 'None yet' : '$count available',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: onTap == null ? Colors.grey.shade500 : color)),
            ),
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_ios, size: 13,
                color: onTap == null ? Colors.grey.shade300 : color.withValues(alpha: 0.6)),
          ]),
        ),
      );
}