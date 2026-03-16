// lib/education/field/simulations/field_operations_simulation.dart
// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

const Color primaryGreen = Color(0xFF032704);

class FieldOperationsSimulation extends StatefulWidget {
  final VoidCallback onComplete;

  const FieldOperationsSimulation({
    super.key,
    required this.onComplete,
  });

  @override
  State<FieldOperationsSimulation> createState() => _FieldOperationsSimulationState();
}

class _FieldOperationsSimulationState extends State<FieldOperationsSimulation> 
    with TickerProviderStateMixin {
  
  int currentWeek = 1;
  final int totalWeeks = 10;
  
  // Field state
  String cropType = 'Maize';
  String growthStage = 'Land Preparation';
  int soilMoisture = 60;
  int soilFertility = 70;
  int weedLevel = 10;
  int cropHealth = 100;
  
  // Field conditions
  String weather = 'Normal';
  bool hasIrrigation = false;
  bool hasMulch = false;
  
  // Actions log
  List<String> actionsLog = [];
  int tillageCount = 0;
  int fertilizationCount = 0;
  int weedingCount = 0;
  int irrigationCount = 0;
  
  // Player choice
  String? selectedAction;
  bool actionApplied = false;
  String feedbackMessage = '';
  
  late ConfettiController confettiController;
  final Random random = Random();

  final List<String> growthStages = [
    'Land Preparation',
    'Planting',
    'Germination',
    'Vegetative Growth',
    'Flowering',
    'Maturation',
    'Harvest Ready',
  ];

  final List<String> weatherTypes = ['Sunny', 'Normal', 'Rainy', 'Drought'];

  @override
  void initState() {
    super.initState();
    confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _addLog('Week 1: Field operations simulation started. Focus on proper land preparation.');
  }

  @override
  void dispose() {
    confettiController.dispose();
    super.dispose();
  }

  void _addLog(String entry) {
    setState(() {
      actionsLog.insert(0, 'Week $currentWeek: $entry');
      if (actionsLog.length > 8) actionsLog.removeLast();
    });
  }

  void _updateWeather() {
    setState(() {
      weather = weatherTypes[random.nextInt(weatherTypes.length)];
      
      // Weather affects soil moisture
      if (weather == 'Rainy') {
        soilMoisture = (soilMoisture + 20).clamp(0, 100);
        _addLog('Heavy rain increased soil moisture.');
      } else if (weather == 'Drought') {
        soilMoisture = (soilMoisture - 25).clamp(0, 100);
        _addLog('⚠️ Drought conditions! Soil moisture dropping rapidly.');
      }
    });
  }

  void _updateGrowthStage() {
    final currentIndex = growthStages.indexOf(growthStage);
    if (currentWeek % 2 == 0 && currentIndex < growthStages.length - 1) {
      setState(() {
        growthStage = growthStages[currentIndex + 1];
        _addLog('Crop advanced to $growthStage stage.');
      });
    }
  }

  void _applyAction() {
    if (selectedAction == null) return;

    setState(() => actionApplied = true);

    int moistureChange = 0;
    int fertilityChange = 0;
    int weedChange = 0;
    int healthChange = 0;

    switch (selectedAction) {
      case 'tillage':
        tillageCount++;
        if (growthStage == 'Land Preparation') {
          fertilityChange = 10;
          weedChange = -20;
          healthChange = 5;
          feedbackMessage = '✅ Perfect timing! Proper tillage improves soil structure and reduces weeds.';
          confettiController.play();
        } else {
          healthChange = -10;
          feedbackMessage = '⚠️ Tillage during crop growth can damage roots!';
        }
        _addLog('Performed tillage operation.');
        break;

      case 'fertilize':
        fertilizationCount++;
        if (growthStage == 'Vegetative Growth' || growthStage == 'Flowering') {
          fertilityChange = 20;
          healthChange = 15;
          feedbackMessage = '✅ Excellent! Fertilization at this stage maximizes crop growth.';
          confettiController.play();
        } else if (growthStage == 'Land Preparation') {
          fertilityChange = 15;
          healthChange = 5;
          feedbackMessage = '✓ Basal fertilizer applied. Good preparation.';
        } else {
          fertilityChange = 10;
          healthChange = 5;
          feedbackMessage = '✓ Fertilizer applied, but timing could be better.';
        }
        _addLog('Applied fertilizer to the field.');
        break;

      case 'weed':
        weedingCount++;
        if (weedLevel > 40) {
          weedChange = -50;
          healthChange = 20;
          fertilityChange = 5;
          feedbackMessage = '✅ Great! Heavy weeding restored crop health significantly.';
          confettiController.play();
        } else {
          weedChange = -30;
          healthChange = 10;
          feedbackMessage = '✓ Regular weeding maintains field cleanliness.';
        }
        _addLog('Weeded the field thoroughly.');
        break;

      case 'irrigate':
        irrigationCount++;
        if (soilMoisture < 40) {
          moistureChange = 40;
          healthChange = 15;
          hasIrrigation = true;
          feedbackMessage = '✅ Perfect! Irrigation saved the crop from drought stress.';
          confettiController.play();
        } else if (soilMoisture > 80) {
          moistureChange = 10;
          healthChange = -5;
          feedbackMessage = '⚠️ Soil already wet. Over-irrigation can cause waterlogging!';
        } else {
          moistureChange = 30;
          healthChange = 10;
          hasIrrigation = true;
          feedbackMessage = '✓ Irrigation maintained optimal soil moisture.';
        }
        _addLog('Irrigated the field.');
        break;

      case 'mulch':
        if (!hasMulch) {
          moistureChange = 10;
          weedChange = -15;
          healthChange = 10;
          hasMulch = true;
          feedbackMessage = '✅ Excellent practice! Mulching conserves moisture and suppresses weeds.';
          confettiController.play();
          _addLog('Applied mulch to conserve moisture.');
        } else {
          feedbackMessage = '⚠️ Mulch already applied.';
        }
        break;

      case 'monitor':
        healthChange = 5;
        feedbackMessage = '✓ Field monitoring completed. Early detection prevents major problems.';
        _addLog('Conducted field monitoring and observation.');
        break;
    }

    setState(() {
      soilMoisture = (soilMoisture + moistureChange).clamp(0, 100);
      soilFertility = (soilFertility + fertilityChange).clamp(0, 100);
      weedLevel = (weedLevel + weedChange).clamp(0, 100);
      cropHealth = (cropHealth + healthChange).clamp(0, 100);
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

  void _nextWeek() {
    if (currentWeek < totalWeeks) {
      setState(() {
        currentWeek++;
        
        // Natural changes
        soilMoisture = (soilMoisture - 10).clamp(0, 100);
        soilFertility = (soilFertility - 3).clamp(0, 100);
        weedLevel = (weedLevel + 15).clamp(0, 100);
        
        // Weather effects
        _updateWeather();
        _updateGrowthStage();
        
        // Health calculation
        int healthPenalty = 0;
        if (soilMoisture < 30) healthPenalty += 10;
        if (soilFertility < 40) healthPenalty += 10;
        if (weedLevel > 60) healthPenalty += 15;
        
        cropHealth = (cropHealth - healthPenalty).clamp(0, 100);
        
        if (cropHealth < 50) {
          _addLog('⚠️ Crop health critical! Immediate intervention needed!');
        }
        if (weedLevel > 70) {
          _addLog('⚠️ Severe weed infestation detected!');
        }
      });
    } else {
      _completeSimulation();
    }
  }

  void _completeSimulation() {
    final score = ((cropHealth * 0.4) + (soilFertility * 0.3) + ((100 - weedLevel) * 0.3)).round();
    
    String performance;
    String advice;
    
    if (score >= 85) {
      performance = 'Excellent! Outstanding field management!';
      advice = 'You demonstrated expert knowledge of crop and soil management.';
      confettiController.play();
    } else if (score >= 70) {
      performance = 'Good work! Effective field operations.';
      advice = 'Your field management practices were solid.';
    } else if (score >= 50) {
      performance = 'Fair performance. Room for improvement.';
      advice = 'Focus on timely interventions and preventive measures.';
    } else {
      performance = 'Keep practicing!';
      advice = 'Review proper timing for tillage, fertilization, and weed control.';
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
              _buildResultRow('Crop Health', '$cropHealth%', cropHealth >= 70),
              _buildResultRow('Soil Fertility', '$soilFertility%', soilFertility >= 60),
              _buildResultRow('Weed Control', '${100 - weedLevel}%', weedLevel <= 40),
              _buildResultRow('Soil Moisture', '$soilMoisture%', soilMoisture >= 40),
              const Divider(height: 24),
              const Text('Operations Summary:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Tillage Operations: $tillageCount'),
              Text('Fertilization: $fertilizationCount'),
              Text('Weeding: $weedingCount'),
              Text('Irrigation: $irrigationCount'),
              Text('Mulching: ${hasMulch ? "Yes" : "No"}'),
              const SizedBox(height: 12),
              if (weedingCount < 3)
                const Text(
                  '💡 Tip: Regular weeding (3-4 times) maintains field cleanliness.',
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
        title: const Text('Field Operations Simulation'),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Text(
                'Week $currentWeek/$totalWeeks',
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
                    Expanded(child: _buildStatusCard('Crop Health', cropHealth, Colors.green)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildStatusCard('Soil Moisture', soilMoisture, Colors.blue)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildStatusCard('Soil Fertility', soilFertility, Colors.brown)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildStatusCard('Weed Level', weedLevel, Colors.red)),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Field Status Card
                Card(
                  color: primaryGreen.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Growth Stage:', style: TextStyle(fontSize: 12)),
                                Text(growthStage, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Weather:', style: TextStyle(fontSize: 12)),
                                Row(
                                  children: [
                                    Icon(_getWeatherIcon(), size: 20),
                                    const SizedBox(width: 4),
                                    Text(weather, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (hasMulch) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: const [
                              Icon(Icons.grass, color: Colors.green, size: 16),
                              SizedBox(width: 4),
                              Text('Mulch Applied', style: TextStyle(fontSize: 12, color: Colors.green)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Action Options
                const Text('Field Operations:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                _buildActionOption(
                  'tillage',
                  'Tillage & Land Prep',
                  'Improves soil structure, best before planting',
                  Icons.agriculture,
                  Colors.brown,
                ),
                _buildActionOption(
                  'fertilize',
                  'Apply Fertilizer',
                  'Boosts soil fertility and crop nutrition',
                  Icons.science,
                  Colors.green,
                ),
                _buildActionOption(
                  'weed',
                  'Weed Control',
                  'Removes competition for nutrients',
                  Icons.cleaning_services,
                  Colors.orange,
                ),
                _buildActionOption(
                  'irrigate',
                  'Irrigate Field',
                  'Maintains optimal soil moisture',
                  Icons.water_drop,
                  Colors.blue,
                ),
                _buildActionOption(
                  'mulch',
                  'Apply Mulch',
                  'Conserves moisture & suppresses weeds',
                  Icons.grass,
                  Colors.lightGreen,
                ),
                _buildActionOption(
                  'monitor',
                  'Field Monitoring',
                  'Inspect crop and identify issues early',
                  Icons.remove_red_eye,
                  Colors.purple,
                ),

                const SizedBox(height: 20),

                if (feedbackMessage.isNotEmpty)
                  Card(
                    color: feedbackMessage.contains('✅')
                        ? Colors.green.shade50
                        : feedbackMessage.contains('⚠️')
                            ? Colors.orange.shade50
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
                        child: const Text('Perform Operation', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: actionApplied || selectedAction == null ? _nextWeek : null,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          currentWeek < totalWeeks ? 'Next Week →' : 'Finish',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Actions Log
                const Text('Operations Log:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
      case 'Rainy':
        return Icons.water_drop;
      case 'Drought':
        return Icons.warning_amber;
      case 'Normal':
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