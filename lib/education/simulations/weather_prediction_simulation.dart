// weather_prediction_simulation.dart - Interactive Weather Prediction Simulation
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

const Color primaryGreen = Color(0xFF032704);

class WeatherPredictionSimulation extends StatefulWidget {
  final VoidCallback onComplete;

  const WeatherPredictionSimulation({
    super.key,
    required this.onComplete,
  });

  @override
  State<WeatherPredictionSimulation> createState() => _WeatherPredictionSimulationState();
}

class _WeatherPredictionSimulationState extends State<WeatherPredictionSimulation> with TickerProviderStateMixin {
  int currentDay = 1;
  final int totalDays = 7;
  
  WeatherCondition currentWeather = WeatherCondition.partlyCloudy;
  double temperature = 25.0;
  double humidity = 60.0;
  double windSpeed = 10.0;
  int cloudCover = 50;
  
  final List<Map<String, dynamic>> weatherHistory = [];
  
  WeatherCondition? playerPrediction;
  int correctPredictions = 0;
  int totalPredictions = 0;
  
  String currentTip = '';
  List<String> observations = [];
  
  late ConfettiController confettiController;
  late AnimationController cloudAnimController;
  final Random random = Random();
  
  bool predictionMade = false;
  bool showingResult = false;

  @override
  void initState() {
    super.initState();
    confettiController = ConfettiController(duration: const Duration(seconds: 2));
    cloudAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    
    initializeWeather();
    startSimulation();
  }

  @override
  void dispose() {
    confettiController.dispose();
    cloudAnimController.dispose();
    super.dispose();
  }

  void initializeWeather() {
    currentWeather = WeatherCondition.values[random.nextInt(WeatherCondition.values.length)];
    temperature = 20.0 + random.nextDouble() * 15;
    humidity = 40.0 + random.nextDouble() * 50;
    windSpeed = 5.0 + random.nextDouble() * 20;
    cloudCover = random.nextInt(100);
    
    recordWeatherData();
  }

  void startSimulation() {
    setState(() {
      currentTip = 'Welcome, Young Meteorologist! Study the weather patterns and predict tomorrow\'s conditions.';
      addObservation('Simulation started. Day 1 weather recorded.');
    });
  }

  void recordWeatherData() {
    weatherHistory.add({
      'day': currentDay,
      'weather': currentWeather,
      'temp': temperature,
      'humidity': humidity,
      'wind': windSpeed,
      'cloudCover': cloudCover,
    });
  }

  void addObservation(String observation) {
    setState(() {
      observations.insert(0, 'Day $currentDay: $observation');
      if (observations.length > 5) observations.removeLast();
    });
  }

  void makePrediction(WeatherCondition prediction) {
    if (predictionMade) return;
    
    setState(() {
      playerPrediction = prediction;
      predictionMade = true;
      currentTip = 'Prediction recorded: ${getWeatherName(prediction)}. Let\'s see what tomorrow brings...';
    });
  }

  void advanceDay() {
    if (!predictionMade && currentDay > 1) {
      showMessage('Make a prediction first!', isError: true);
      return;
    }
    
    if (currentDay >= totalDays) {
      endSimulation();
      return;
    }
    
    final nextWeather = generateNextWeather();
    
    setState(() {
      currentDay++;
      showingResult = true;
    });
    
    if (predictionMade && playerPrediction != null) {
      final isCorrect = playerPrediction == nextWeather;
      totalPredictions++;
      
      if (isCorrect) {
        correctPredictions++;
        confettiController.play();
        addObservation('✓ Correct prediction! Well done!');
        currentTip = 'Excellent! Your prediction was accurate. You\'re learning weather patterns!';
      } else {
        addObservation('✗ Prediction was ${getWeatherName(playerPrediction!)} but got ${getWeatherName(nextWeather)}');
        currentTip = 'Not quite right. Study the patterns more closely. Notice humidity and cloud cover changes.';
      }
    }
    
    currentWeather = nextWeather;
    recordWeatherData();
    
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          showingResult = false;
          predictionMade = false;
          playerPrediction = null;
          currentTip = 'Day $currentDay/$totalDays: Analyze the weather data and make your prediction.';
        });
      }
    });
  }

  WeatherCondition generateNextWeather() {
    if (humidity > 75 && cloudCover > 70) {
      temperature = temperature - (1 + random.nextDouble() * 3);
      humidity = (humidity + 5).clamp(0, 100);
      cloudCover = (cloudCover + 10).clamp(0, 100);
      windSpeed = windSpeed + (2 + random.nextDouble() * 5);
      return random.nextDouble() < 0.7 ? WeatherCondition.rainy : WeatherCondition.stormy;
    }
    
    if (humidity < 50 && temperature > 28) {
      temperature = temperature + (random.nextDouble() * 2);
      humidity = (humidity - 5).clamp(0, 100);
      cloudCover = (cloudCover - 10).clamp(0, 100);
      windSpeed = windSpeed - (1 + random.nextDouble() * 3);
      return WeatherCondition.sunny;
    }
    
    temperature = temperature + (random.nextDouble() * 4 - 2);
    humidity = humidity + (random.nextDouble() * 10 - 5);
    cloudCover = cloudCover + (random.nextInt(20) - 10);
    windSpeed = windSpeed + (random.nextDouble() * 4 - 2);
    
    temperature = temperature.clamp(15.0, 40.0);
    humidity = humidity.clamp(30.0, 100.0);
    cloudCover = cloudCover.clamp(0, 100);
    windSpeed = windSpeed.clamp(0.0, 40.0);
    
    if (cloudCover < 20) return WeatherCondition.sunny;
    if (cloudCover < 50) return WeatherCondition.partlyCloudy;
    if (cloudCover < 80) return WeatherCondition.cloudy;
    
    return humidity > 70 ? WeatherCondition.rainy : WeatherCondition.cloudy;
  }

  void endSimulation() {
    final accuracy = totalPredictions > 0 ? (correctPredictions / totalPredictions * 100).toDouble() : 0.0;
    
    confettiController.play();
    
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        showCompletionDialog(accuracy);
      }
    });
  }

  void showCompletionDialog(double accuracy) {
    String feedback;
    if (accuracy >= 70) {
      feedback = '🌟 Excellent! You have a great understanding of weather patterns!';
    } else if (accuracy >= 50) {
      feedback = '👍 Good job! Keep studying weather patterns to improve.';
    } else {
      feedback = '📚 Keep learning! Weather prediction takes practice and observation.';
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber, size: 32),
            SizedBox(width: 8),
            Text('Simulation Complete!'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '7-Day Weather Study Complete',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              resultRow('Total Predictions', '$totalPredictions'),
              resultRow('Correct Predictions', '$correctPredictions'),
              const Divider(),
              resultRow(
                'Accuracy',
                '${accuracy.toStringAsFixed(1)}%',
                color: accuracy >= 70 ? Colors.green : (accuracy >= 50 ? Colors.orange : Colors.red),
                isBold: true,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue),
                ),
                child: Text(feedback),
              ),
              const SizedBox(height: 16),
              const Text(
                'Key Learning Points:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              learningPoint('High humidity + clouds often lead to rain'),
              learningPoint('Temperature changes indicate weather shifts'),
              learningPoint('Wind patterns can signal storms'),
              learningPoint('Cloud cover is a key predictor'),
            ],
          ),
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

  Widget resultRow(String label, String value, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
              fontSize: isBold ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget learningPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  void showMessage(String message, {bool isError = false}) {
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

  String getWeatherName(WeatherCondition condition) {
    switch (condition) {
      case WeatherCondition.sunny:
        return 'Sunny';
      case WeatherCondition.partlyCloudy:
        return 'Partly Cloudy';
      case WeatherCondition.cloudy:
        return 'Cloudy';
      case WeatherCondition.rainy:
        return 'Rainy';
      case WeatherCondition.stormy:
        return 'Stormy';
    }
  }

  IconData getWeatherIcon(WeatherCondition condition) {
    switch (condition) {
      case WeatherCondition.sunny:
        return Icons.wb_sunny;
      case WeatherCondition.partlyCloudy:
        return Icons.wb_cloudy;
      case WeatherCondition.cloudy:
        return Icons.cloud;
      case WeatherCondition.rainy:
        return Icons.grain;
      case WeatherCondition.stormy:
        return Icons.flash_on;
    }
  }

  Color getWeatherColor(WeatherCondition condition) {
    switch (condition) {
      case WeatherCondition.sunny:
        return Colors.orange;
      case WeatherCondition.partlyCloudy:
        return Colors.amber;
      case WeatherCondition.cloudy:
        return Colors.grey;
      case WeatherCondition.rainy:
        return Colors.blue;
      case WeatherCondition.stormy:
        return Colors.deepPurple;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weather Prediction Lab'),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildTipBanner(),
                const SizedBox(height: 16),
                buildProgress(),
                const SizedBox(height: 16),
                buildWeatherDisplay(),
                const SizedBox(height: 16),
                buildWeatherData(),
                const SizedBox(height: 16),
                if (!predictionMade && !showingResult && currentDay < totalDays)
                  buildPredictionButtons(),
                if (predictionMade || currentDay == 1)
                  buildNextDayButton(),
                const SizedBox(height: 16),
                buildWeatherHistory(),
                const SizedBox(height: 16),
                buildObservations(),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              colors: const [Colors.blue, Colors.white, Colors.grey],
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
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.blue.shade100],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb, color: Colors.orange.shade700, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              currentTip,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildProgress() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Day $currentDay/$totalDays', 
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                if (totalPredictions > 0)
                  Text('Accuracy: ${(correctPredictions / totalPredictions * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 14, color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: currentDay / totalDays,
                minHeight: 12,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(primaryGreen),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildWeatherDisplay() {
    return Card(
      elevation: 6,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: showingResult 
              ? [Colors.green.shade200, Colors.green.shade400]
              : [Colors.lightBlue.shade200, Colors.lightBlue.shade400],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            if (cloudCover > 30)
              AnimatedBuilder(
                animation: cloudAnimController,
                builder: (BuildContext context, Widget? child) {
                  return Positioned(
                    top: 20 + (cloudAnimController.value * 10),
                    left: 30,
                    child: Icon(Icons.cloud, size: 60, color: Colors.white.withValues(alpha: 0.7)),
                  );
                },
              ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    getWeatherIcon(currentWeather),
                    size: 80,
                    color: getWeatherColor(currentWeather),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    getWeatherName(currentWeather),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  if (showingResult && playerPrediction != null)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: playerPrediction == currentWeather ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        playerPrediction == currentWeather ? '✓ Correct!' : '✗ Incorrect',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${temperature.toStringAsFixed(1)}°C',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildWeatherData() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Conditions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            dataRow('Temperature', '${temperature.toStringAsFixed(1)}°C', Icons.thermostat),
            dataRow('Humidity', '${humidity.toStringAsFixed(0)}%', Icons.water_drop),
            dataRow('Wind Speed', '${windSpeed.toStringAsFixed(1)} km/h', Icons.air),
            dataRow('Cloud Cover', '$cloudCover%', Icons.cloud),
          ],
        ),
      ),
    );
  }

  Widget dataRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget buildPredictionButtons() {
    return Card(
      elevation: 4,
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Predict Tomorrow\'s Weather',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: WeatherCondition.values.map((condition) {
                return ElevatedButton.icon(
                  onPressed: () => makePrediction(condition),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: getWeatherColor(condition),
                    foregroundColor: Colors.white,
                  ),
                  icon: Icon(getWeatherIcon(condition), size: 20),
                  label: Text(getWeatherName(condition)),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildNextDayButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: advanceDay,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: Icon(currentDay >= totalDays ? Icons.assessment : Icons.fast_forward, size: 28),
        label: Text(
          currentDay >= totalDays ? 'VIEW RESULTS' : 'NEXT DAY',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget buildWeatherHistory() {
    if (weatherHistory.length <= 1) return const SizedBox.shrink();
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weather History',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: weatherHistory.reversed.map((data) {
                  final weather = data['weather'] as WeatherCondition;
                  return Container(
                    width: 80,
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: getWeatherColor(weather).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: getWeatherColor(weather)),
                    ),
                    child: Column(
                      children: [
                        Text('Day ${data['day']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Icon(getWeatherIcon(weather), size: 32, color: getWeatherColor(weather)),
                        const SizedBox(height: 4),
                        Text('${(data['temp'] as double).toStringAsFixed(0)}°', style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildObservations() {
    if (observations.isEmpty) return const SizedBox.shrink();
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.notes, color: primaryGreen),
                SizedBox(width: 8),
                Text(
                  'Observations',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...observations.map((obs) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: 16)),
                  Expanded(child: Text(obs, style: const TextStyle(fontSize: 13))),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}

enum WeatherCondition {
  sunny,
  partlyCloudy,
  cloudy,
  rainy,
  stormy,
}