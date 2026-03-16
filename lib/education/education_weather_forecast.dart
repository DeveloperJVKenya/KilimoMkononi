// education_weather_forecast.dart - FINAL VERSION WITH ROLE-BASED UX & FULL 5-DAY FORECAST
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:kilimomkononi/utils/firestore_helper.dart';

import '../../utils/class_id_notifier.dart';
import '../../models/education_user.dart';
import '../../config.dart';
import 'simulations/weather_prediction_simulation.dart';


const Color primaryGreen = Color(0xFF032704);

extension StringExt on String {
  String capitalize() => isNotEmpty ? '${this[0].toUpperCase()}${substring(1)}' : this;
}

extension TextEditingControllerExt on TextEditingController {
  String get safeText => text.trim();
}

// Weather Models
class WeatherCurrent {
  final double temp;
  final String desc;
  final String icon;
  final double humidity;
  final double windSpeed;
  final int pressure;

  WeatherCurrent.fromJson(Map<String, dynamic> json)
      : temp = (json['main']['temp'] as num).toDouble(),
        desc = json['weather'][0]['description'].toString().capitalize(),
        icon = json['weather'][0]['icon'] as String,
        humidity = (json['main']['humidity'] as num).toDouble(),
        windSpeed = (json['wind']['speed'] as num).toDouble(),
        pressure = json['main']['pressure'] as int;
}

class WeatherForecastDay {
  final String date;
  final double minTemp;
  final double maxTemp;
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

class EducationWeatherForecast extends StatefulWidget {
  final EduRole role;
  final String schoolName;
  final String classId;

  const EducationWeatherForecast({
    super.key,
    required this.role,
    required this.schoolName,
    required this.classId,
  });

  @override
  State<EducationWeatherForecast> createState() => _EducationWeatherForecastState();
}

class _EducationWeatherForecastState extends State<EducationWeatherForecast> {
  final _locCtrl = TextEditingController();

  // Observed weather
  String? _observedWeather;
  final List<Map<String, dynamic>> _weatherConditions = [
    {'label': 'Sunny', 'icon': Icons.wb_sunny, 'color': Colors.orange},
    {'label': 'Partly Sunny', 'icon': Icons.wb_cloudy, 'color': Colors.amber},
    {'label': 'Cloudy', 'icon': Icons.cloud, 'color': Colors.grey},
    {'label': 'Rainy', 'icon': Icons.grain, 'color': Colors.blue},
    {'label': 'Stormy', 'icon': Icons.flash_on, 'color': Colors.deepPurple},
    {'label': 'Windy', 'icon': Icons.air, 'color': Colors.cyan},
    {'label': 'Broken Clouds', 'icon': Icons.wb_cloudy, 'color': Colors.blueGrey},
    {'label': 'Light Showers', 'icon': Icons.ac_unit, 'color': Colors.lightBlue},
  ];

  // Forecast data
  WeatherCurrent? _current;
  List<WeatherForecastDay>? _forecast;
  String? _locationName;
  bool _loading = false;
  String _error = '';

  final String _contentType = 'weather_content';

  void _showSimBuilder() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) => WeatherPredictionSimulation(
          onComplete: () {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Weather prediction simulation completed!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
        ),
      ),
    );
  }


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
      _loading = true;
      _error = '';
      _current = null;
      _forecast = null;
    });

    try {
      final coords = await _getCoordinates(loc);
      if (coords == null) {
        setState(() => _error = 'Location not found');
        return;
      }

      final current = await _fetchCurrentWeather(coords);
      final forecastData = await _fetchForecast(coords);

      if (mounted) {
        setState(() {
          _current = current;
          _forecast = _groupForecastByDay(forecastData);
          _locationName = loc.capitalize();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load weather';
          _loading = false;
        });
      }
    }
  }

  Future<Map<String, double>?> _getCoordinates(String loc) async {
    final url = 'https://api.openweathermap.org/geo/1.0/direct?q=$loc&limit=1&appid=${Config.weatherApiKey}';
    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200 && res.body.isNotEmpty) {
      final data = jsonDecode(res.body)[0];
      return {'lat': data['lat'] as double, 'lon': data['lon'] as double};
    }
    return null;
  }

  Future<WeatherCurrent> _fetchCurrentWeather(Map<String, double> coords) async {
    final url = 'https://api.openweathermap.org/data/2.5/weather?lat=${coords['lat']}&lon=${coords['lon']}&appid=${Config.weatherApiKey}&units=metric';
    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) return WeatherCurrent.fromJson(jsonDecode(res.body));
    throw Exception('Failed current weather');
  }

  Future<List<dynamic>> _fetchForecast(Map<String, double> coords) async {
    final url = 'https://api.openweathermap.org/data/2.5/forecast?lat=${coords['lat']}&lon=${coords['lon']}&appid=${Config.weatherApiKey}&units=metric';
    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) return jsonDecode(res.body)['list'];
    throw Exception('Failed forecast');
  }

  List<WeatherForecastDay> _groupForecastByDay(List<dynamic> list) {
    final Map<String, List<dynamic>> grouped = {};
    for (var item in list) {
      final date = (item['dt_txt'] as String).split(' ')[0];
      grouped.putIfAbsent(date, () => []).add(item);
    }

    return grouped.entries.map((entry) {
      final temps = entry.value.map((i) => (i['main']['temp'] as num).toDouble()).toList();
      final descs = entry.value.map((i) => i['weather'][0]['description'] as String).toSet().toList();
      final icons = entry.value.map((i) => i['weather'][0]['icon'] as String).toList();

      return WeatherForecastDay(
        date: DateFormat('EEEE, MMM d').format(DateTime.parse(entry.key)),
        minTemp: temps.reduce((a, b) => a < b ? a : b),
        maxTemp: temps.reduce((a, b) => a > b ? a : b),
        descriptions: descs,
        icons: icons,
      );
    }).toList();
  }

  Widget _buildWeatherIcon(String iconCode, {double size = 50}) {
    return Image.network(
      'https://openweathermap.org/img/wn/$iconCode@2x.png',
      width: size,
      height: size,
      errorBuilder: (_, _, _) => Icon(Icons.cloud, size: size, color: Colors.grey),
    );
  }

  Future<void> _saveContent(String type, Map<String, dynamic> data) async {
    await FirestoreHelper.ensureGradeExists(widget.classId);
    final collection = FirestoreHelper.getContentFromClassId(widget.classId, _contentType);
    if (collection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid class configuration')),
      );
      return;
    }

    final String title = data['title'] as String? ?? '${type.capitalize()} Activity';

    try {
      await collection.add({
        'type': type,
        'title': title,
        'data': jsonEncode(type == 'quiz' ? data['questions'] : data['steps']),
        'createdAt': FieldValue.serverTimestamp(),
        'userId': FirebaseAuth.instance.currentUser!.uid,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title saved successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _launchContent(String type, String docId) async {
    final rawCollection = FirestoreHelper.getContentFromClassId(widget.classId, _contentType);
    if (rawCollection == null) return;

    try {
      final doc = await rawCollection.doc(docId).get();
      final dataMap = doc.data() as Map<String, dynamic>?;

      if (dataMap == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load content')),
        );
        return;
      }

      final String title = dataMap['title'] is String && (dataMap['title'] as String).trim().isNotEmpty
          ? (dataMap['title'] as String).trim()
          : '${type.capitalize()} Activity';

      final payload = jsonDecode(dataMap['data'] as String);

      final fullPayload = {
        'id': doc.id,
        'title': title,
        if (type == 'quiz') 'questions': payload,
        if (type == 'simulation') 'steps': payload,
      };

      if (mounted) {
        if (type == 'quiz') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WeatherQuizScreen(payload: fullPayload, classId: widget.classId),
            ),
          );
        } else {
          // Launch standalone weather prediction simulation
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WeatherPredictionSimulation(
                onComplete: () async {
                  // Record completion
                  final coll = FirestoreHelper.getSubmissionsFromClassId(widget.classId);
                  if (coll != null) {
                    await coll.add({
                      'type': 'simulation',
                      'simulationId': doc.id,
                      'title': title,
                      'userId': FirebaseAuth.instance.currentUser!.uid,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                  }
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Weather simulation completed! 🎉'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isTeacher = widget.role == EduRole.teacher;
    final double width = MediaQuery.of(context).size.width;
    final bool isMobile = width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weather Station'),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        leading: isMobile
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
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
            const Text('How is the weather today at school?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _weatherConditions.map((condition) {
                final isSelected = _observedWeather == condition['label'];
                return GestureDetector(
                  onTap: () => _selectObservedWeather(condition['label']),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: isSelected ? primaryGreen : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isSelected ? primaryGreen : Colors.grey.shade300, width: 2),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(condition['icon'], size: 40, color: isSelected ? Colors.white : condition['color']),
                        const SizedBox(height: 8),
                        Text(
                          condition['label'],
                          style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.w600, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 32),

            // ACTIVITIES SECTION — ONLY FOR STUDENTS
            if (widget.role == EduRole.student)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Card(
                  color: Colors.green.shade50,
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: primaryGreen, width: 2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.assignment_turned_in, size: 32, color: primaryGreen),
                            const SizedBox(width: 12),
                            Text(
                              'Practice Activities',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryGreen),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text('Test your weather knowledge!', style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildActivitySection('quiz', Icons.quiz)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildActivitySection('simulation', Icons.play_circle)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // FORECAST SECTION
            const Text('5-Day Weather Forecast', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _locCtrl,
              decoration: InputDecoration(
                hintText: 'Enter city name (e.g. Nairobi, Mombasa, London)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.location_on),
                suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _fetchWeather),
              ),
              onSubmitted: (_) => _fetchWeather(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _fetchWeather,
                icon: const Icon(Icons.cloud_download),
                label: const Text('Load Forecast'),
                style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, padding: const EdgeInsets.all(16)),
              ),
            ),

            if (_loading) const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: primaryGreen))),
            if (_error.isNotEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(_error, style: const TextStyle(color: Colors.red))),

            // OBSERVED VS FORECASTED COMPARISON
            if (_observedWeather != null && _current != null)
              Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 16),
                child: Card(
                  color: Colors.blue.shade50,
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.compare_arrows, color: primaryGreen, size: 28),
                            const SizedBox(width: 10),
                            Text('Observation vs Forecast', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryGreen)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  Text('You observed:', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  Icon(_weatherConditions.firstWhere((c) => c['label'] == _observedWeather)['icon'], size: 50, color: _weatherConditions.firstWhere((c) => c['label'] == _observedWeather)['color']),
                                  Text(_observedWeather!, style: const TextStyle(fontSize: 18)),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward, size: 30, color: Colors.grey),
                            Expanded(
                              child: Column(
                                children: [
                                  Text('Forecast says:', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  _buildWeatherIcon(_current!.icon, size: 50),
                                  Text(_current!.desc, style: const TextStyle(fontSize: 18)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _observedWeather!.toLowerCase().contains(_current!.desc.toLowerCase()) ||
                                  _current!.desc.toLowerCase().contains(_observedWeather!.toLowerCase())
                              ? '✅ Your observation matches the forecast!'
                              : 'ℹ️ There might be a difference today — weather can be unpredictable!',
                          style: TextStyle(
                            fontSize: 16,
                            color: _observedWeather!.toLowerCase().contains(_current!.desc.toLowerCase()) ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // FULL 5-DAY FORECAST DISPLAY
            if (_forecast != null && _forecast!.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  Text(
                    'Forecast for $_locationName',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryGreen),
                  ),
                  const SizedBox(height: 16),
                  ..._forecast!.map((day) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(day.date, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    ...day.descriptions.map((d) => Text('• $d', style: const TextStyle(fontSize: 15))),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  children: day.icons.map((i) => Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: _buildWeatherIcon(i, size: 40),
                                      )).toList(),
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('${day.maxTemp.round()}°C', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
                                  Text('${day.minTemp.round()}°C', style: const TextStyle(fontSize: 16, color: Colors.blue)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )),
                ],
              ),
          ],
        ),
      ),
      bottomNavigationBar: widget.role == EduRole.headteacher
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[50],
              child: Row(
                children: isTeacher
                    ? [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => showDialog(
                              context: context,
                              builder: (_) => WeatherQuizBuilder(onSave: (d) => _saveContent('quiz', d)),
                            ),
                            icon: const Icon(Icons.quiz),
                            label: const Text('Create Weather Quiz'),
                            style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, padding: const EdgeInsets.symmetric(vertical: 18)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _showSimBuilder,
                            icon: const Icon(Icons.play_circle),
                            label: const Text('Launch Weather Simulation'),
                            style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, padding: const EdgeInsets.symmetric(vertical: 18)),
                          ),
                        ),
                      ]
                    : [],
              ),
            ),
    );
  }

  // ==================== ACTIVITY SECTION & LIST (UNCHANGED) ====================

  Widget _buildActivitySection(String type, IconData icon) {
    final raw = FirestoreHelper.getContentFromClassId(widget.classId, _contentType);
    if (raw == null) {
      return ElevatedButton.icon(
        onPressed: null,
        icon: Icon(icon),
        label: Text(type == 'quiz' ? 'Quizzes' : 'Simulations'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
      );
    }

    final coll = raw.withConverter<Map<String, dynamic>>(
      fromFirestore: (s, _) => s.data()!,
      toFirestore: (d, _) => d,
    );

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: coll.where('type', isEqualTo: type).snapshots(),
      builder: (context, snapshot) {
        int total = snapshot.data?.docs.length ?? 0;

        return ElevatedButton.icon(
          onPressed: total == 0 ? null : () => _showActivityList(type),
          icon: Icon(icon, size: 28),
          label: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(type == 'quiz' ? 'Quizzes' : 'Simulations', style: const TextStyle(fontSize: 18)),
              if (total > 0) Text('$total available', style: const TextStyle(fontSize: 14)),
            ],
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
    );
  }

  void _showActivityList(String type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.6,
        expand: false,
        builder: (_, controller) => _buildContentList(type, scrollController: controller),
      ),
    );
  }

  Widget _buildContentList(String type, {ScrollController? scrollController}) {
    final rawCollection = FirestoreHelper.getContentFromClassId(widget.classId, _contentType);
    if (rawCollection == null) {
      return const Center(child: Text('Invalid configuration'));
    }

    final CollectionReference<Map<String, dynamic>> collection = rawCollection.withConverter<Map<String, dynamic>>(
      fromFirestore: (snapshot, _) => snapshot.data()!,
      toFirestore: (data, _) => data,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '${type.capitalize()}s Available',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryGreen),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: collection.where('type', isEqualTo: type).orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: primaryGreen));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Text(
                    'No ${type}s available yet',
                    style: const TextStyle(fontSize: 18, fontStyle: FontStyle.italic, color: Colors.grey),
                  ),
                );
              }

              final userId = FirebaseAuth.instance.currentUser!.uid;
              final submissionsColl = FirestoreHelper.getSubmissionsFromClassId(widget.classId);

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
                              if (data is Map<String, dynamic>) {
                                return data['${type}Id'] as String?;
                              }
                              return null;
                            })
                            .whereType<String>()
                            .toSet()),
                builder: (context, completedSnap) {
                  final completedIds = completedSnap.data ?? <String>{};

                  final availableDocs = snapshot.data!.docs.where((doc) => !completedIds.contains(doc.id)).toList();

                  if (availableDocs.isEmpty) {
                    return const Center(
                      child: Text('All completed! Great job! 🎉', style: TextStyle(fontSize: 18)),
                    );
                  }

                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: availableDocs.length,
                    itemBuilder: (context, index) {
                      final doc = availableDocs[index];
                      final data = doc.data();
                      final title = data['title'] as String? ?? 'Untitled ${type.capitalize()}';
                      final createdAt = data['createdAt'] as Timestamp?;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 4,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: primaryGreen,
                            child: Icon(type == 'quiz' ? Icons.quiz : Icons.play_circle, color: Colors.white),
                          ),
                          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: createdAt != null ? Text('Created: ${_formatDate(createdAt.toDate())}') : null,
                          trailing: const Icon(Icons.arrow_forward_ios),
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

// === QUIZ & SIMULATION SCREENS (with submission tracking) ===
class WeatherQuizScreen extends StatefulWidget {
  final Map<String, dynamic> payload;
  final String classId;

  const WeatherQuizScreen({super.key, required this.payload, required this.classId});

  @override
  State<WeatherQuizScreen> createState() => _WeatherQuizScreenState();
}

class _WeatherQuizScreenState extends State<WeatherQuizScreen> {
  int _idx = 0;
  int _score = 0;
  late final ConfettiController _conf = ConfettiController(duration: const Duration(seconds: 2));

  void _ans(int sel) {
    if (sel == widget.payload['questions'][_idx]['correct']) {
      _score++;
      _conf.play();
    }
    if (_idx < widget.payload['questions'].length - 1) {
      setState(() => _idx++);
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    final coll = FirestoreHelper.getSubmissionsFromClassId(widget.classId);
    if (coll != null) {
      await coll.add({
        'type': 'quiz',
        'quizId': widget.payload['id'],
        'title': widget.payload['title'],
        'score': _score,
        'total': widget.payload['questions'].length,
        'userId': FirebaseAuth.instance.currentUser!.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Quiz Complete!'),
          content: Text('Score: $_score / ${widget.payload['questions'].length}\n\nSaved!'),
          actions: [TextButton(onPressed: () => Navigator.of(context)..pop()..pop(), child: const Text('Done'))],
        ),
      );
    }
  }

  @override
  void dispose() {
    _conf.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.payload['questions'][_idx];
    return Scaffold(
      appBar: AppBar(title: Text(widget.payload['title'] ?? 'Weather Quiz'), backgroundColor: primaryGreen, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ConfettiWidget(confettiController: _conf, blastDirectionality: BlastDirectionality.explosive),
            const SizedBox(height: 30),
            Text(q['question'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 40),
            ...(q['options'] as List).asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: ElevatedButton(
                    onPressed: () => _ans(e.key),
                    style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, minimumSize: const Size(double.infinity, 56)),
                    child: Text('${String.fromCharCode(65 + e.key)}. ${e.value}', style: const TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}


// BUILDERS (your original ones – unchanged)
class WeatherQuizBuilder extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;
  const WeatherQuizBuilder({super.key, required this.onSave});

  @override
  State<WeatherQuizBuilder> createState() => _WeatherQuizBuilderState();
}

class _WeatherQuizBuilderState extends State<WeatherQuizBuilder> {
  final _titleCtrl = TextEditingController();
  final List<Map<String, dynamic>> _questions = [];

  void _addQuestion() {
    final questionCtrl = TextEditingController();
    final optionCtrls = List.generate(4, (_) => TextEditingController());
    int correctIndex = 0;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Question'),
        content: StatefulBuilder(
          builder: (context, setStateInner) => SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: questionCtrl, decoration: const InputDecoration(labelText: 'Question')),
              const SizedBox(height: 12),
              ...optionCtrls.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Radio<int>(value: e.key, groupValue: correctIndex, onChanged: (v) => setStateInner(() => correctIndex = v ?? 0)),
                      Expanded(child: TextField(controller: e.value, decoration: InputDecoration(labelText: 'Option ${e.key + 1}'))),
                    ]),
                  )),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
            onPressed: () {
              final filled = optionCtrls.where((c) => c.safeText.isNotEmpty).toList();
              if (questionCtrl.safeText.isEmpty || filled.isEmpty) return;
              setState(() {
                _questions.add({
                  'question': questionCtrl.safeText,
                  'options': filled.map((c) => c.safeText).toList(),
                  'correct': correctIndex,
                });
              });
              Navigator.pop(context);
            },
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Create Weather Quiz'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Quiz Title')),
            const SizedBox(height: 16),
            ElevatedButton.icon(onPressed: _addQuestion, icon: const Icon(Icons.add), label: const Text('Add Question')),
            const SizedBox(height: 16),
            ..._questions.asMap().entries.map((e) {
              final q = e.value;
              final correctLetter = String.fromCharCode(65 + (q['correct'] as int));
              return Card(
                child: ListTile(
                  title: Text(q['question']),
                  subtitle: Text('Correct: $correctLetter. ${(q['options'] as List)[q['correct']]}',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () => setState(() => _questions.removeAt(e.key))),
                ),
              );
            }),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
            onPressed: _questions.isEmpty ? null : () {
              widget.onSave({
                'title': _titleCtrl.safeText.isEmpty ? 'Weather Quiz' : _titleCtrl.safeText,
                'questions': _questions,
              });
              Navigator.pop(context);
            },
            child: const Text('Save Quiz', style: TextStyle(color: Colors.white)),
          ),
        ],
      );
}

class WeatherSimBuilder extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;
  const WeatherSimBuilder({super.key, required this.onSave});

  @override
  State<WeatherSimBuilder> createState() => _WeatherSimBuilderState();
}

class _WeatherSimBuilderState extends State<WeatherSimBuilder> {
  final _titleCtrl = TextEditingController();
  final List<Map<String, dynamic>> _steps = [];

  void _addStep() {
    final promptCtrl = TextEditingController();
    final optionCtrls = List.generate(4, (_) => TextEditingController());
    int correctIndex = 0;
    final explanationCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Step'),
        content: StatefulBuilder(
          builder: (context, setStateInner) => SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: promptCtrl, decoration: const InputDecoration(labelText: 'Situation / Prompt')),
              const SizedBox(height: 12),
              ...optionCtrls.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Checkbox(value: correctIndex == e.key, onChanged: (v) => setStateInner(() => correctIndex = v == true ? e.key : correctIndex)),
                      Expanded(child: TextField(controller: e.value, decoration: InputDecoration(labelText: 'Option ${e.key + 1}'))),
                    ]),
                  )),
              const SizedBox(height: 12),
              TextField(controller: explanationCtrl, decoration: const InputDecoration(labelText: 'Explanation if wrong (optional)'), maxLines: 3),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
            onPressed: () {
              final filled = optionCtrls.where((c) => c.safeText.isNotEmpty).toList();
              if (promptCtrl.safeText.isEmpty || filled.isEmpty) return;
              final options = filled.map((c) => {'text': c.safeText, 'correct': filled.indexOf(c) == correctIndex}).toList();
              setState(() => _steps.add({'prompt': promptCtrl.safeText, 'options': options, 'explanation': explanationCtrl.safeText}));
              Navigator.pop(context);
            },
            child: const Text('Add Step', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Create Weather Simulation'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Simulation Title')),
            const SizedBox(height: 16),
            ElevatedButton.icon(onPressed: _addStep, icon: const Icon(Icons.add), label: const Text('Add Step')),
            const SizedBox(height: 16),
            ..._steps.asMap().entries.map((e) {
              final s = e.value;
              final correctOpt = (s['options'] as List).firstWhere((o) => o['correct'] == true, orElse: () => {'text': 'None'});
              final letter = String.fromCharCode(65 + (s['options'] as List).indexOf(correctOpt));
              return Card(
                child: ListTile(
                  title: Text(s['prompt']),
                  subtitle: Text('Correct: $letter. ${correctOpt['text']}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () => setState(() => _steps.removeAt(e.key))),
                ),
              );
            }),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
            onPressed: _steps.isEmpty ? null : () {
              widget.onSave({
                'title': _titleCtrl.safeText.isEmpty ? 'Weather Simulation' : _titleCtrl.safeText,
                'steps': _steps,
              });
              Navigator.pop(context);
            },
            child: const Text('Save Simulation', style: TextStyle(color: Colors.white)),
          ),
        ],
      );
}