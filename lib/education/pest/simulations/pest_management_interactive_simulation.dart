// lib/education/pest/simulations/pest_management_interactive_simulation.dart
// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

const Color primaryGreen = Color(0xFF388E3C);

class PestManagementInteractiveSimulation extends StatefulWidget {
  final VoidCallback onComplete;

  const PestManagementInteractiveSimulation({
    super.key,
    required this.onComplete,
  });

  @override
  State<PestManagementInteractiveSimulation> createState() => _PestManagementInteractiveSimulationState();
}

class _PestManagementInteractiveSimulationState extends State<PestManagementInteractiveSimulation> 
    with TickerProviderStateMixin {
  
  int currentWeek = 1;
  final int totalWeeks = 8;
  
  // Pest management state
  String selectedCrop = 'Maize';
  int pestPopulation = 50;
  int cropHealth = 100;
  int beneficialInsects = 30;
  String currentPest = 'Aphids';
  
  // Management actions taken
  List<String> actionsLog = [];
  int chemicalSprayCount = 0;
  int organicTreatmentCount = 0;
  int biocontrolCount = 0;
  
  // Player choices
  String? selectedAction;
  bool actionApplied = false;
  String feedbackMessage = '';
  
  late ConfettiController confettiController;
  late AnimationController pulseController;
  final Random random = Random();

  final List<Map<String, dynamic>> pestTypes = [
    {
      'name': 'Aphids',
      'weakness': 'biocontrol',
      'description': 'Small sap-sucking insects',
      'icon': Icons.bug_report
    },
    {
      'name': 'Cutworms',
      'weakness': 'organic',
      'description': 'Caterpillars that cut seedlings',
      'icon': Icons.emoji_nature
    },
    {
      'name': 'Stem Borers',
      'weakness': 'chemical',
      'description': 'Larvae boring into stems',
      'icon': Icons.local_florist
    },
  ];

  final Map<String, String> managementTips = {
    'biocontrol': 'Use beneficial insects like ladybugs',
    'organic': 'Apply neem oil or botanical extracts',
    'chemical': 'Use synthetic pesticides as last resort',
    'cultural': 'Crop rotation and field sanitation',
  };

  @override
  void initState() {
    super.initState();
    confettiController = ConfettiController(duration: const Duration(seconds: 2));
    pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _updatePestType();
    _addLogEntry('Week 1: Pest management simulation started. Monitor your $selectedCrop field carefully.');
  }

  @override
  void dispose() {
    confettiController.dispose();
    pulseController.dispose();
    super.dispose();
  }

  void _updatePestType() {
    if (currentWeek % 3 == 0) {
      final newPest = pestTypes[random.nextInt(pestTypes.length)];
      setState(() {
        currentPest = newPest['name'];
        _addLogEntry('New pest detected: $currentPest - ${newPest['description']}');
      });
    }
  }

  void _addLogEntry(String entry) {
    setState(() {
      actionsLog.insert(0, 'Week $currentWeek: $entry');
      if (actionsLog.length > 6) actionsLog.removeLast();
    });
  }

  void _applyAction() {
    if (selectedAction == null) return;

    setState(() => actionApplied = true);

    final pestInfo = pestTypes.firstWhere((p) => p['name'] == currentPest);
    final isEffective = pestInfo['weakness'] == selectedAction;

    int pestReduction = 0;
    int healthChange = 0;
    int beneficialChange = 0;

    switch (selectedAction) {
      case 'biocontrol':
        biocontrolCount++;
        if (isEffective) {
          pestReduction = 30 + random.nextInt(20);
          healthChange = 10;
          beneficialChange = 15;
          feedbackMessage = '✅ Excellent! Biocontrol is very effective against $currentPest. Beneficial insects increased!';
          confettiController.play();
        } else {
          pestReduction = 10 + random.nextInt(10);
          healthChange = 5;
          beneficialChange = 10;
          feedbackMessage = '✓ Biocontrol helped, but another method would be more effective for $currentPest.';
        }
        _addLogEntry('Released beneficial insects. Pest population reduced by $pestReduction%');
        break;

      case 'organic':
        organicTreatmentCount++;
        if (isEffective) {
          pestReduction = 40 + random.nextInt(15);
          healthChange = 15;
          beneficialChange = -5;
          feedbackMessage = '✅ Great choice! Organic treatment works well for $currentPest with minimal side effects.';
          confettiController.play();
        } else {
          pestReduction = 15 + random.nextInt(10);
          healthChange = 8;
          beneficialChange = -5;
          feedbackMessage = '✓ Organic treatment applied, but a different approach would be better.';
        }
        _addLogEntry('Applied organic pesticide. Pest population reduced by $pestReduction%');
        break;

      case 'chemical':
        chemicalSprayCount++;
        if (isEffective) {
          pestReduction = 60 + random.nextInt(20);
          healthChange = 20;
          beneficialChange = -25;
          feedbackMessage = '⚠️ Chemical pesticide is effective but harmful to beneficial insects. Use sparingly!';
        } else {
          pestReduction = 25 + random.nextInt(15);
          healthChange = 10;
          beneficialChange = -20;
          feedbackMessage = '⚠️ Chemical used. Effective but reduced beneficial insects significantly.';
        }
        _addLogEntry('Sprayed chemical pesticide. WARNING: Beneficial insects affected!');
        break;

      case 'cultural':
        pestReduction = 15 + random.nextInt(10);
        healthChange = 12;
        beneficialChange = 5;
        feedbackMessage = '✓ Cultural practices improve overall field health and prevent future infestations.';
        _addLogEntry('Implemented cultural control: field sanitation and crop rotation planning.');
        break;
    }

    setState(() {
      pestPopulation = (pestPopulation - pestReduction).clamp(0, 100);
      cropHealth = (cropHealth + healthChange).clamp(0, 100);
      beneficialInsects = (beneficialInsects + beneficialChange).clamp(0, 100);
    });

    // Natural pest population increase over time
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
        
        // Natural population dynamics
        pestPopulation = (pestPopulation + 10 + random.nextInt(15)).clamp(0, 100);
        cropHealth = (cropHealth - (pestPopulation / 10).round()).clamp(0, 100);
        beneficialInsects = (beneficialInsects + 5).clamp(0, 100);
        
        _updatePestType();
        
        if (pestPopulation > 70) {
          _addLogEntry('⚠️ Alert: Pest population is HIGH! Take immediate action!');
        }
      });
    } else {
      _completeSimulation();
    }
  }

  void _completeSimulation() {
    final score = ((cropHealth * 0.5) + (beneficialInsects * 0.3) + (100 - pestPopulation) * 0.2).round();
    
    String performance;
    if (score >= 80) {
      performance = 'Excellent! You\'re a pest management expert!';
      confettiController.play();
    } else if (score >= 60) {
      performance = 'Good job! You managed the pests effectively.';
    } else {
      performance = 'Keep practicing! Consider using more integrated approaches.';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Simulation Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Performance Score: $score/100', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(performance),
            const Divider(height: 24),
            Text('Final Crop Health: $cropHealth%'),
            Text('Beneficial Insects: $beneficialInsects%'),
            Text('Pest Population: $pestPopulation%'),
            const Divider(height: 24),
            Text('Chemical Sprays: $chemicalSprayCount'),
            Text('Organic Treatments: $organicTreatmentCount'),
            Text('Biocontrol Releases: $biocontrolCount'),
          ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pest Management Simulation'),
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
                    Expanded(child: _buildStatusCard('Pest Level', pestPopulation, Colors.red)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildStatusCard('Beneficial', beneficialInsects, Colors.blue)),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Current Situation
                Card(
                  color: Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber, color: Colors.orange.shade700),
                            const SizedBox(width: 8),
                            const Text('Current Situation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('Pest: $currentPest', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        Text(pestTypes.firstWhere((p) => p['name'] == currentPest)['description']),
                        const SizedBox(height: 8),
                        if (pestPopulation > 50)
                          Text(
                            '⚠️ Population is ${pestPopulation > 70 ? "CRITICAL" : "HIGH"}!',
                            style: TextStyle(
                              color: pestPopulation > 70 ? Colors.red : Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Management Actions
                const Text('Choose Management Strategy:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                
                _buildActionOption(
                  'biocontrol',
                  'Biological Control',
                  managementTips['biocontrol']!,
                  Icons.local_florist,
                  Colors.green,
                ),
                _buildActionOption(
                  'organic',
                  'Organic Pesticide',
                  managementTips['organic']!,
                  Icons.eco,
                  Colors.lightGreen,
                ),
                _buildActionOption(
                  'chemical',
                  'Chemical Pesticide',
                  managementTips['chemical']!,
                  Icons.science,
                  Colors.orange,
                ),
                _buildActionOption(
                  'cultural',
                  'Cultural Control',
                  managementTips['cultural']!,
                  Icons.agriculture,
                  Colors.brown,
                ),

                const SizedBox(height: 20),

                if (feedbackMessage.isNotEmpty)
                  Card(
                    color: feedbackMessage.contains('✅') ? Colors.green.shade50 : Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(feedbackMessage, style: const TextStyle(fontSize: 16)),
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
                        onPressed: actionApplied ? _nextWeek : null,
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

  Widget _buildStatusCard(String label, int value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
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
                Text('$value%', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
      color: isSelected ? color.withOpacity(0.2) : null,
      elevation: isSelected ? 4 : 1,
      child: RadioListTile<String>(
        value: key,
        groupValue: selectedAction,
        onChanged: actionApplied ? null : (value) => setState(() => selectedAction = value),
        title: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        subtitle: Text(description, style: const TextStyle(fontSize: 12)),
        activeColor: color,
      ),
    );
  }
}