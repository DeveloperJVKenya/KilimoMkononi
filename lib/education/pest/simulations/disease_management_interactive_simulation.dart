// lib/education/pest/simulations/disease_management_interactive_simulation.dart
// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

const Color primaryGreen = Color(0xFF388E3C);

class DiseaseManagementInteractiveSimulation extends StatefulWidget {
  final VoidCallback onComplete;

  const DiseaseManagementInteractiveSimulation({
    super.key,
    required this.onComplete,
  });

  @override
  State<DiseaseManagementInteractiveSimulation> createState() => _DiseaseManagementInteractiveSimulationState();
}

class _DiseaseManagementInteractiveSimulationState extends State<DiseaseManagementInteractiveSimulation> 
    with TickerProviderStateMixin {
  
  int currentDay = 1;
  final int totalDays = 10;
  
  // Disease management state
  String selectedCrop = 'Tomato';
  int diseaseInfection = 30;
  int plantHealth = 100;
  int soilHealth = 80;
  String currentDisease = 'Early Blight';
  
  // Environmental factors
  String weather = 'Partly Cloudy';
  int humidity = 65;
  int temperature = 25;
  
  // Management actions taken
  List<String> actionsLog = [];
  int fungicideCount = 0;
  int culturalPracticeCount = 0;
  int resistantVarietyUsed = 0;
  
  // Player choices
  String? selectedAction;
  bool actionApplied = false;
  String feedbackMessage = '';
  
  late ConfettiController confettiController;
  late AnimationController pulseController;
  final Random random = Random();

  final List<Map<String, dynamic>> diseaseTypes = [
    {
      'name': 'Early Blight',
      'weakness': 'cultural',
      'description': 'Fungal disease causing leaf spots',
      'icon': Icons.coronavirus
    },
    {
      'name': 'Powdery Mildew',
      'weakness': 'fungicide',
      'description': 'White powdery growth on leaves',
      'icon': Icons.cloud
    },
    {
      'name': 'Bacterial Wilt',
      'weakness': 'resistant',
      'description': 'Wilting caused by bacteria',
      'icon': Icons.water_drop
    },
    {
      'name': 'Mosaic Virus',
      'weakness': 'prevention',
      'description': 'Viral disease with mottled leaves',
      'icon': Icons.broken_image
    },
  ];

  final Map<String, String> managementTips = {
    'fungicide': 'Apply approved fungicides for fungal diseases',
    'cultural': 'Remove infected plants, improve spacing',
    'resistant': 'Use disease-resistant varieties',
    'prevention': 'Sanitize tools, control vectors',
  };

  final List<String> weatherOptions = ['Sunny', 'Cloudy', 'Rainy', 'Partly Cloudy'];

  @override
  void initState() {
    super.initState();
    confettiController = ConfettiController(duration: const Duration(seconds: 2));
    pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _updateWeather();
    _addLogEntry('Day 1: Disease management simulation started. Monitor $selectedCrop for disease symptoms.');
  }

  @override
  void dispose() {
    confettiController.dispose();
    pulseController.dispose();
    super.dispose();
  }

  void _updateWeather() {
    setState(() {
      weather = weatherOptions[random.nextInt(weatherOptions.length)];
      humidity = 40 + random.nextInt(50);
      temperature = 18 + random.nextInt(15);
      
      // Weather affects disease progression
      if (weather == 'Rainy' && humidity > 80) {
        _addLogEntry('⚠️ High humidity and rain favor disease development!');
      }
    });
  }

  void _updateDiseaseType() {
    if (currentDay % 4 == 0) {
      final newDisease = diseaseTypes[random.nextInt(diseaseTypes.length)];
      setState(() {
        currentDisease = newDisease['name'];
        _addLogEntry('New symptoms detected: $currentDisease - ${newDisease['description']}');
      });
    }
  }

  void _addLogEntry(String entry) {
    setState(() {
      actionsLog.insert(0, 'Day $currentDay: $entry');
      if (actionsLog.length > 7) actionsLog.removeLast();
    });
  }

  void _applyAction() {
    if (selectedAction == null) return;

    setState(() => actionApplied = true);

    final diseaseInfo = diseaseTypes.firstWhere((d) => d['name'] == currentDisease);
    final isEffective = diseaseInfo['weakness'] == selectedAction;

    int infectionReduction = 0;
    int healthChange = 0;
    int soilChange = 0;

    switch (selectedAction) {
      case 'fungicide':
        fungicideCount++;
        if (isEffective && currentDisease.contains('Blight') || currentDisease.contains('Mildew')) {
          infectionReduction = 40 + random.nextInt(20);
          healthChange = 15;
          soilChange = -5;
          feedbackMessage = '✅ Excellent! Fungicide is highly effective against $currentDisease.';
          confettiController.play();
        } else if (currentDisease.contains('Virus') || currentDisease.contains('Bacteria')) {
          infectionReduction = 5;
          healthChange = 0;
          soilChange = -5;
          feedbackMessage = '❌ Fungicides don\'t work on viral or bacterial diseases!';
        } else {
          infectionReduction = 20 + random.nextInt(15);
          healthChange = 8;
          soilChange = -5;
          feedbackMessage = '✓ Fungicide applied, but better options exist for this disease.';
        }
        _addLogEntry('Applied fungicide. Infection reduced by $infectionReduction%');
        break;

      case 'cultural':
        culturalPracticeCount++;
        if (isEffective) {
          infectionReduction = 30 + random.nextInt(15);
          healthChange = 12;
          soilChange = 10;
          feedbackMessage = '✅ Great! Cultural practices are the best approach for $currentDisease.';
          confettiController.play();
        } else {
          infectionReduction = 15 + random.nextInt(10);
          healthChange = 8;
          soilChange = 5;
          feedbackMessage = '✓ Cultural practices help, but more direct treatment may be needed.';
        }
        _addLogEntry('Implemented cultural controls: removed infected tissue, improved air circulation.');
        break;

      case 'resistant':
        resistantVarietyUsed = 1;
        if (isEffective) {
          infectionReduction = 25 + random.nextInt(15);
          healthChange = 20;
          soilChange = 0;
          feedbackMessage = '✅ Perfect! Resistant variety provides long-term protection against $currentDisease.';
          confettiController.play();
        } else {
          infectionReduction = 10 + random.nextInt(10);
          healthChange = 10;
          soilChange = 0;
          feedbackMessage = '✓ Resistant variety helps overall, though not specifically for this disease.';
        }
        _addLogEntry('Planted disease-resistant variety for future protection.');
        break;

      case 'prevention':
        if (isEffective) {
          infectionReduction = 35 + random.nextInt(20);
          healthChange = 10;
          soilChange = 5;
          feedbackMessage = '✅ Excellent! Prevention is key for controlling $currentDisease spread.';
          confettiController.play();
        } else {
          infectionReduction = 10 + random.nextInt(10);
          healthChange = 5;
          soilChange = 3;
          feedbackMessage = '✓ Good hygiene practices help prevent spread.';
        }
        _addLogEntry('Implemented preventive measures: tool sanitation, vector control.');
        break;
    }

    setState(() {
      diseaseInfection = (diseaseInfection - infectionReduction).clamp(0, 100);
      plantHealth = (plantHealth + healthChange).clamp(0, 100);
      soilHealth = (soilHealth + soilChange).clamp(0, 100);
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          selectedAction = null;
          actionApplied = false;
          feedbackMessage = '';
        });
      }
    });
  }

  void _nextDay() {
    if (currentDay < totalDays) {
      setState(() {
        currentDay++;
        
        // Weather and disease progression
        _updateWeather();
        _updateDiseaseType();
        
        // Natural disease progression based on weather
        int diseaseIncrease = 5 + random.nextInt(10);
        if (weather == 'Rainy' && humidity > 75) {
          diseaseIncrease += 15;
        }
        
        diseaseInfection = (diseaseInfection + diseaseIncrease).clamp(0, 100);
        plantHealth = (plantHealth - (diseaseInfection / 8).round()).clamp(0, 100);
        
        if (diseaseInfection > 70) {
          _addLogEntry('⚠️ CRITICAL: Disease infection very high! Immediate action needed!');
        }
      });
    } else {
      _completeSimulation();
    }
  }

  void _completeSimulation() {
    final score = ((plantHealth * 0.4) + (soilHealth * 0.3) + (100 - diseaseInfection) * 0.3).round();
    
    String performance;
    String advice;
    
    if (score >= 85) {
      performance = 'Outstanding! You\'re a disease management expert!';
      advice = 'Your integrated approach minimized chemical use while maintaining crop health.';
      confettiController.play();
    } else if (score >= 70) {
      performance = 'Well done! Good disease management.';
      advice = 'You effectively controlled the disease spread.';
    } else if (score >= 50) {
      performance = 'Fair performance. There\'s room for improvement.';
      advice = 'Try combining cultural practices with targeted treatments.';
    } else {
      performance = 'Keep practicing!';
      advice = 'Focus on early detection and integrated pest management strategies.';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Simulation Complete!'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Performance Score: $score/100', 
                   style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryGreen)),
              const SizedBox(height: 12),
              Text(performance, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(advice),
              const Divider(height: 24),
              _buildResultRow('Final Plant Health', '$plantHealth%', plantHealth >= 70),
              _buildResultRow('Soil Health', '$soilHealth%', soilHealth >= 70),
              _buildResultRow('Disease Infection', '$diseaseInfection%', diseaseInfection <= 30),
              const Divider(height: 24),
              const Text('Management Summary:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Fungicide Applications: $fungicideCount'),
              Text('Cultural Practices: $culturalPracticeCount'),
              Text('Resistant Variety: ${resistantVarietyUsed > 0 ? "Yes" : "No"}'),
              const SizedBox(height: 12),
              if (fungicideCount > 5)
                const Text(
                  '💡 Tip: Try using more cultural practices to reduce chemical dependence.',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onComplete();
            },
            child: const Text('Finish'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value, bool isGood) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Row(
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Icon(
                isGood ? Icons.check_circle : Icons.warning,
                color: isGood ? Colors.green : Colors.orange,
                size: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Disease Management Simulation'),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Text(
                'Day $currentDay/$totalDays',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          ConfettiWidget(
            confettiController: confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Cards
                Row(
                  children: [
                    Expanded(child: _buildStatusCard('Plant Health', plantHealth, Colors.green)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildStatusCard('Infection', diseaseInfection, Colors.red)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildStatusCard('Soil Health', soilHealth, Colors.brown)),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Weather Card
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Icon(_getWeatherIcon(), size: 32, color: Colors.blue.shade700),
                            Text(weather, style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        Column(
                          children: [
                            const Icon(Icons.opacity, color: Colors.blue),
                            Text('$humidity%', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const Text('Humidity', style: TextStyle(fontSize: 10)),
                          ],
                        ),
                        Column(
                          children: [
                            const Icon(Icons.thermostat, color: Colors.orange),
                            Text('$temperature°C', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const Text('Temp', style: TextStyle(fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Current Disease
                Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.coronavirus, color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            const Text('Current Disease', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('Disease: $currentDisease', 
                             style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        Text(diseaseTypes.firstWhere((d) => d['name'] == currentDisease)['description']),
                        const SizedBox(height: 8),
                        if (diseaseInfection > 50)
                          Text(
                            '⚠️ Infection level is ${diseaseInfection > 70 ? "CRITICAL" : "HIGH"}!',
                            style: TextStyle(
                              color: diseaseInfection > 70 ? Colors.red : Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Management Actions
                const Text('Choose Management Strategy:', 
                           style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                
                _buildActionOption(
                  'fungicide',
                  'Fungicide Treatment',
                  managementTips['fungicide']!,
                  Icons.science,
                  Colors.blue,
                ),
                _buildActionOption(
                  'cultural',
                  'Cultural Practices',
                  managementTips['cultural']!,
                  Icons.agriculture,
                  Colors.green,
                ),
                _buildActionOption(
                  'resistant',
                  'Resistant Variety',
                  managementTips['resistant']!,
                  Icons.shield,
                  Colors.purple,
                ),
                _buildActionOption(
                  'prevention',
                  'Prevention & Sanitation',
                  managementTips['prevention']!,
                  Icons.cleaning_services,
                  Colors.orange,
                ),

                const SizedBox(height: 20),

                if (feedbackMessage.isNotEmpty)
                  Card(
                    color: feedbackMessage.contains('✅') 
                        ? Colors.green.shade50 
                        : feedbackMessage.contains('❌')
                            ? Colors.red.shade50
                            : Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(feedbackMessage, style: const TextStyle(fontSize: 15)),
                    ),
                  ),

                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: selectedAction != null && !actionApplied ? _applyAction : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Apply Treatment', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: actionApplied ? _nextDay : null,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          currentDay < totalDays ? 'Next Day →' : 'Finish',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Activity Log
                const Text('Activity Log:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: actionsLog.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          actionsLog[index],
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getWeatherIcon() {
    switch (weather) {
      case 'Sunny':
        return Icons.wb_sunny;
      case 'Cloudy':
        return Icons.cloud;
      case 'Rainy':
        return Icons.water_drop;
      case 'Partly Cloudy':
      default:
        return Icons.wb_cloudy;
    }
  }

  Widget _buildStatusCard(String label, int value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 11), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    value: value / 100,
                    strokeWidth: 6,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                Text('$value%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionOption(String key, String title, String description, IconData icon, Color color) {
    final isSelected = selectedAction == key;
    
    return Card(
      color: isSelected ? color.withOpacity(0.15) : null,
      elevation: isSelected ? 4 : 1,
      child: RadioListTile<String>(
        value: key,
        groupValue: selectedAction,
        onChanged: actionApplied ? null : (value) => setState(() => selectedAction = value),
        title: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
        subtitle: Text(description, style: const TextStyle(fontSize: 12)),
        activeColor: color,
      ),
    );
  }
}