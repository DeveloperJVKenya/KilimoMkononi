// farm_planting_simulation.dart - Interactive Planting Simulation
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

const Color primaryGreen = Color(0xFF032704);
const Color soilBrown = Color(0xFF8B4513);
const Color plantGreen = Color(0xFF228B22);
const Color waterBlue = Color(0xFF1E90FF);

class FarmPlantingSimulation extends StatefulWidget {
  final String cropName;
  final Map<String, dynamic> cropData;
  final VoidCallback onComplete;

  const FarmPlantingSimulation({
    super.key,
    required this.cropName,
    required this.cropData,
    required this.onComplete,
  });

  @override
  State<FarmPlantingSimulation> createState() => _FarmPlantingSimulationState();
}

class _FarmPlantingSimulationState extends State<FarmPlantingSimulation> with TickerProviderStateMixin {
  SimulationPhase currentPhase = SimulationPhase.preparation;
  int waterLevel = 0;
  int fertilizer = 0;
  double plantGrowth = 0.0;
  int daysElapsed = 0;
  bool isPestControl = false;
  List<String> completedTasks = [];
  Timer? growthTimer;
  
  late ConfettiController confettiController;
  late AnimationController growthAnimController;
  late Animation<double> growthAnimation;

  String currentTip = '';

  @override
  void initState() {
    super.initState();
    confettiController = ConfettiController(duration: const Duration(seconds: 3));
    growthAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    growthAnimation = CurvedAnimation(
      parent: growthAnimController,
      curve: Curves.easeInOut,
    );
    startSimulation();
  }

  @override
  void dispose() {
    confettiController.dispose();
    growthAnimController.dispose();
    growthTimer?.cancel();
    super.dispose();
  }

  void startSimulation() {
    setState(() {
      currentTip = 'Welcome! Let\'s learn how to grow ${widget.cropName}. First, we need to prepare the soil.';
    });
  }

  void prepareSoil() {
    setState(() {
      currentPhase = SimulationPhase.soilPreparation;
      currentTip = 'Great! Soil preparation is essential. Tap to plow the field.';
      completedTasks.add('Soil Preparation');
    });
  }

  void plantSeeds() {
    if (!completedTasks.contains('Soil Preparation')) {
      showFeedbackMessage('You need to prepare the soil first!', isError: true);
      return;
    }
    
    setState(() {
      currentPhase = SimulationPhase.planting;
      currentTip = 'Excellent! Now plant your ${widget.cropName} seeds at the right depth and spacing.';
      completedTasks.add('Planting');
      plantGrowth = 0.1;
      growthAnimController.forward();
    });
    startGrowthTimer();
  }

  void addWater() {
    if (!completedTasks.contains('Planting')) {
      showFeedbackMessage('Plant the seeds first!', isError: true);
      return;
    }

    setState(() {
      if (waterLevel < 100) {
        waterLevel += 25;
        plantGrowth = (plantGrowth + 0.15).clamp(0.0, 1.0);
        growthAnimController.forward(from: plantGrowth - 0.15);
        
        if (waterLevel >= 75) {
          currentTip = 'Perfect watering! ${widget.cropName} needs consistent moisture.';
        } else {
          currentTip = 'Good! Continue watering regularly.';
        }
      } else {
        currentTip = 'Careful! Too much water can harm the plant. Wait for the soil to dry a bit.';
        showFeedbackMessage('Overwatering detected!', isError: true);
      }
    });
  }

  void addFertilizer() {
    if (!completedTasks.contains('Planting')) {
      showFeedbackMessage('Plant the seeds first!', isError: true);
      return;
    }

    setState(() {
      if (fertilizer < 100) {
        fertilizer += 33;
        plantGrowth = (plantGrowth + 0.1).clamp(0.0, 1.0);
        growthAnimController.forward(from: plantGrowth - 0.1);
        currentTip = 'Good! Fertilizer provides essential nutrients for ${widget.cropName}.';
        
        if (!completedTasks.contains('Fertilizing')) {
          completedTasks.add('Fertilizing');
        }
      }
    });
  }

  void applyPestControl() {
    if (!completedTasks.contains('Planting')) {
      showFeedbackMessage('Plant the seeds first!', isError: true);
      return;
    }

    setState(() {
      isPestControl = true;
      completedTasks.add('Pest Control');
      currentTip = 'Smart! Protecting your crop from pests ensures a healthy harvest.';
    });
  }

  void advanceDay() {
    if (!completedTasks.contains('Planting')) {
      showFeedbackMessage('You need to plant seeds first!', isError: true);
      return;
    }

    setState(() {
      daysElapsed++;
      
      if (waterLevel > 0) {
        waterLevel = (waterLevel - 15).clamp(0, 100);
        plantGrowth = (plantGrowth + 0.05).clamp(0.0, 1.0);
        growthAnimController.forward(from: plantGrowth - 0.05);
      }
      
      currentTip = 'Day $daysElapsed: Plant is growing! Water level: $waterLevel%';
      
      if (plantGrowth >= 0.95 && completedTasks.contains('Fertilizing')) {
        currentPhase = SimulationPhase.harvesting;
        currentTip = 'Congratulations! Your ${widget.cropName} is ready to harvest!';
      }
    });
  }

  void harvest() {
    if (currentPhase != SimulationPhase.harvesting) {
      showFeedbackMessage('The crop is not ready yet. Keep caring for it!', isError: true);
      return;
    }

    setState(() {
      currentPhase = SimulationPhase.completed;
      confettiController.play();
    });

    final int score = calculateScore();
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        showCompletionDialog(score);
      }
    });
  }

  int calculateScore() {
    int score = 50;
    
    if (completedTasks.contains('Soil Preparation')) score += 10;
    if (completedTasks.contains('Fertilizing')) score += 15;
    if (completedTasks.contains('Pest Control')) score += 15;
    if (waterLevel >= 50 && waterLevel <= 75) score += 10;
    
    return score.clamp(0, 100);
  }

  void showCompletionDialog(int score) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber, size: 32),
            SizedBox(width: 8),
            Text('Harvest Complete!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You successfully grew ${widget.cropName}!', 
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('Your Score: $score/100', style: const TextStyle(fontSize: 20, color: primaryGreen)),
            const SizedBox(height: 12),
            const Text('Tasks Completed:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...completedTasks.map((task) => Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  Text(task),
                ],
              ),
            )),
            const SizedBox(height: 12),
            Text('Days to Harvest: $daysElapsed'),
            if (score >= 80)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('🌟 Excellent farming! You\'re a natural!',
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              widget.onComplete();
            },
            child: const Text('Continue Learning'),
          ),
        ],
      ),
    );
  }

  void showFeedbackMessage(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void startGrowthTimer() {
    growthTimer?.cancel();
    growthTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted || currentPhase == SimulationPhase.completed) {
        timer.cancel();
        return;
      }
      
      if (waterLevel > 20) {
        setState(() {
          plantGrowth = (plantGrowth + 0.02).clamp(0.0, 1.0);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Growing ${widget.cropName}'),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                buildTipBanner(),
                const SizedBox(height: 16),
                buildFarmVisualization(),
                const SizedBox(height: 20),
                buildProgressIndicators(),
                const SizedBox(height: 24),
                buildActionButtons(),
                const SizedBox(height: 16),
                buildCompletedTasks(),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              colors: const [Colors.green, Colors.yellow, Colors.orange, Colors.brown],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTipBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb, color: Colors.orange.shade700, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              currentTip,
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildFarmVisualization() {
    return Container(
      height: 320,
      decoration: BoxDecoration(
        color: soilBrown.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: soilBrown, width: 3),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 100,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.lightBlue.shade200, Colors.lightBlue.shade50],
                ),
              ),
            ),
          ),
          const Positioned(
            top: 20,
            right: 20,
            child: Icon(Icons.wb_sunny, color: Colors.orange, size: 48),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 220,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [soilBrown.withValues(alpha: 0.6), soilBrown],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
            ),
          ),
          if (completedTasks.contains('Planting'))
            Center(
              child: AnimatedBuilder(
                animation: growthAnimation,
                builder: (BuildContext context, Widget? child) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Transform.scale(
                        scale: plantGrowth,
                        child: Column(
                          children: [
                            if (plantGrowth > 0.5)
                              const Icon(
                                Icons.eco,
                                size: 80,
                                color: plantGreen,
                              ),
                            Container(
                              width: 8,
                              height: 100 * plantGrowth,
                              decoration: BoxDecoration(
                                color: plantGreen,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 80),
                    ],
                  );
                },
              ),
            ),
          if (waterLevel > 0)
            ...List.generate((waterLevel / 25).floor(), (index) {
              return Positioned(
                top: 120 + (index * 25.0),
                left: 40 + (index * 30.0),
                child: const Icon(
                  Icons.water_drop,
                  color: waterBlue,
                  size: 24,
                ),
              );
            }),
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: primaryGreen),
              ),
              child: Text(
                'Growth: ${(plantGrowth * 100).toInt()}%',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: primaryGreen,
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: primaryGreen),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Day $daysElapsed',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildProgressIndicators() {
    return Column(
      children: [
        buildProgressBar('Water Level', waterLevel, waterBlue),
        const SizedBox(height: 12),
        buildProgressBar('Fertilizer', fertilizer, Colors.brown),
        const SizedBox(height: 12),
        if (isPestControl)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield, color: Colors.green),
                SizedBox(width: 8),
                Text('Pest Control Active', 
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
          ),
      ],
    );
  }

  Widget buildProgressBar(String label, int value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('$value%', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: value / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 12,
          ),
        ),
      ],
    );
  }

  Widget buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: actionButton(
                'Prepare Soil',
                Icons.grass,
                currentPhase == SimulationPhase.preparation ? prepareSoil : null,
                Colors.brown,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: actionButton(
                'Plant Seeds',
                Icons.energy_savings_leaf,
                currentPhase == SimulationPhase.soilPreparation ? plantSeeds : null,
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: actionButton(
                'Water',
                Icons.water_drop,
                completedTasks.contains('Planting') ? addWater : null,
                waterBlue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: actionButton(
                'Fertilize',
                Icons.eco,
                completedTasks.contains('Planting') ? addFertilizer : null,
                Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: actionButton(
                'Pest Control',
                Icons.bug_report,
                completedTasks.contains('Planting') && !isPestControl ? applyPestControl : null,
                Colors.red,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: actionButton(
                'Next Day',
                Icons.fast_forward,
                completedTasks.contains('Planting') ? advanceDay : null,
                primaryGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: currentPhase == SimulationPhase.harvesting ? harvest : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.agriculture, size: 28),
            label: const Text('HARVEST', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget actionButton(String label, IconData icon, VoidCallback? onPressed, Color color) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: onPressed == null ? Colors.grey : color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }

  Widget buildCompletedTasks() {
    if (completedTasks.isEmpty) return const SizedBox.shrink();
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Completed Tasks',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: completedTasks.map((task) {
                return Chip(
                  avatar: const Icon(Icons.check_circle, color: Colors.white, size: 18),
                  label: Text(task),
                  backgroundColor: Colors.green,
                  labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

enum SimulationPhase {
  preparation,
  soilPreparation,
  planting,
  growing,
  harvesting,
  completed,
}