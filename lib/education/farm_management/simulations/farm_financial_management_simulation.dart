// lib/education/farm_management/simulations/farm_financial_management_simulation.dart
// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

const Color primaryGreen = Color(0xFF003900);

class FarmFinancialManagementSimulation extends StatefulWidget {
  final VoidCallback onComplete;

  const FarmFinancialManagementSimulation({
    super.key,
    required this.onComplete,
  });

  @override
  State<FarmFinancialManagementSimulation> createState() => _FarmFinancialManagementSimulationState();
}

class _FarmFinancialManagementSimulationState extends State<FarmFinancialManagementSimulation> 
    with TickerProviderStateMixin {
  
  int currentMonth = 1;
  final int totalMonths = 12;
  
  // Financial state
  double cashBalance = 50000.0;
  double totalRevenue = 0.0;
  double totalExpenses = 0.0;
  double landSize = 2.0; // acres
  
  // Crop state
  String currentCrop = 'Maize';
  int cropAge = 0; // days
  int harvestDay = 90;
  double expectedYield = 0.0;
  
  // Monthly expenses
  double laborCost = 0.0;
  double inputCost = 0.0;
  double maintenanceCost = 500.0;
  
  // Decisions log
  List<String> decisionsLog = [];
  
  // Player choice
  String? selectedDecision;
  bool decisionMade = false;
  String feedbackMessage = '';
  
  late ConfettiController confettiController;
  final Random random = Random();

  final Map<String, Map<String, dynamic>> cropOptions = {
    'Maize': {
      'seedCost': 3000,
      'fertilizerCost': 4000,
      'harvestDays': 90,
      'pricePerBag': 3500,
      'yieldPerAcre': 15,
      'laborCost': 2000,
    },
    'Beans': {
      'seedCost': 4000,
      'fertilizerCost': 3000,
      'harvestDays': 75,
      'pricePerBag': 5000,
      'yieldPerAcre': 10,
      'laborCost': 1500,
    },
    'Vegetables': {
      'seedCost': 5000,
      'fertilizerCost': 5000,
      'harvestDays': 60,
      'pricePerBag': 4000,
      'yieldPerAcre': 20,
      'laborCost': 3000,
    },
  };

  final List<Map<String, dynamic>> monthlyEvents = [
    {'month': 3, 'event': 'Unexpected rain damage', 'impact': -5000},
    {'month': 5, 'event': 'Government subsidy received', 'impact': 8000},
    {'month': 7, 'event': 'Equipment breakdown', 'impact': -3000},
    {'month': 9, 'event': 'Good market prices', 'impact': 6000},
  ];

  @override
  void initState() {
    super.initState();
    confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _addLog('Month 1: Farm financial management simulation started with KES 50,000 capital.');
    _calculateExpectedYield();
  }

  @override
  void dispose() {
    confettiController.dispose();
    super.dispose();
  }

  void _calculateExpectedYield() {
    final crop = cropOptions[currentCrop]!;
    expectedYield = landSize * crop['yieldPerAcre'];
  }

  void _addLog(String entry) {
    setState(() {
      decisionsLog.insert(0, entry);
      if (decisionsLog.length > 8) decisionsLog.removeLast();
    });
  }

  void _applyDecision() {
    if (selectedDecision == null) return;

    setState(() => decisionMade = true);

    double cost = 0;
    double benefit = 0;
    String _ = '';

    switch (selectedDecision) {
      case 'invest_inputs':
        cost = 5000;
        if (cashBalance >= cost) {
          benefit = 8000;
          cashBalance -= cost;
          totalExpenses += cost;
          feedbackMessage = '✅ Good investment! Quality inputs increase yields by 25%.';
          expectedYield *= 1.25;
          confettiController.play();
        } else {
          feedbackMessage = '❌ Insufficient funds! You need KES 5,000.';
        }
        _addLog('Month $currentMonth: Attempted to invest in quality inputs.');
        break;

      case 'hire_labor':
        cost = 3000;
        if (cashBalance >= cost) {
          cashBalance -= cost;
          totalExpenses += cost;
          laborCost += cost;
          feedbackMessage = '✓ Labor hired. Farm operations more efficient.';
          _addLog('Month $currentMonth: Hired additional labor for KES 3,000.');
        } else {
          feedbackMessage = '❌ Cannot afford labor costs right now.';
        }
        break;

      case 'save_money':
        benefit = cashBalance * 0.02; // 2% savings interest
        cashBalance += benefit;
        feedbackMessage = '✓ Saved money wisely. Earned KES ${benefit.toStringAsFixed(0)} interest.';
        confettiController.play();
        _addLog('Month $currentMonth: Saved money and earned interest.');
        break;

      case 'expand_land':
        cost = 15000;
        if (cashBalance >= cost) {
          cashBalance -= cost;
          totalExpenses += cost;
          landSize += 0.5;
          _calculateExpectedYield();
          feedbackMessage = '✅ Excellent! Farm expanded by 0.5 acres. Future yields increased!';
          confettiController.play();
          _addLog('Month $currentMonth: Expanded farm to ${landSize.toStringAsFixed(1)} acres.');
        } else {
          feedbackMessage = '❌ Need KES 15,000 to expand land.';
        }
        break;

      case 'take_loan':
        benefit = 10000;
        cashBalance += benefit;
        feedbackMessage = '⚠️ Loan of KES 10,000 received. Must repay with 10% interest!';
        _addLog('Month $currentMonth: Took loan of KES 10,000. Repayment: KES 11,000 due.');
        break;

      case 'plant_new':
        final crop = cropOptions[currentCrop]!;
        cost = crop['seedCost'] + crop['fertilizerCost'];
        if (cashBalance >= cost && cropAge >= harvestDay) {
          cashBalance -= cost;
          totalExpenses += cost;
          cropAge = 0;
          harvestDay = crop['harvestDays'];
          _calculateExpectedYield();
          feedbackMessage = '✓ New $currentCrop crop planted. Harvest in $harvestDay days.';
          _addLog('Month $currentMonth: Planted new $currentCrop crop for KES ${cost.toStringAsFixed(0)}.');
        } else if (cropAge < harvestDay) {
          feedbackMessage = '⚠️ Cannot plant yet. Current crop still growing.';
        } else {
          feedbackMessage = '❌ Insufficient funds to plant.';
        }
        break;
    }

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          selectedDecision = null;
          decisionMade = false;
          feedbackMessage = '';
        });
      }
    });
  }

  void _nextMonth() {
    if (currentMonth < totalMonths) {
      setState(() {
        currentMonth++;
        cropAge += 30; // Approximate days per month
        
        // Deduct monthly maintenance
        cashBalance -= maintenanceCost;
        totalExpenses += maintenanceCost;
        _addLog('Month $currentMonth: Paid KES $maintenanceCost maintenance.');
        
        // Check for harvest
        if (cropAge >= harvestDay) {
          _harvestCrop();
        }
        
        // Random events
        final event = monthlyEvents.firstWhere(
          (e) => e['month'] == currentMonth,
          orElse: () => {},
        );
        
        if (event.isNotEmpty) {
          final impact = event['impact'] as int;
          cashBalance += impact;
          if (impact > 0) {
            totalRevenue += impact;
          } else {
            totalExpenses += impact.abs();
          }
          _addLog('Month $currentMonth: ${event['event']} (KES ${impact > 0 ? '+' : ''}$impact)');
        }
        
        if (cashBalance < 0) {
          _addLog('⚠️ WARNING: Negative balance! Farm in financial trouble!');
        }
      });
    } else {
      _completeSimulation();
    }
  }

  void _harvestCrop() {
    final crop = cropOptions[currentCrop]!;
    final revenue = expectedYield * crop['pricePerBag'];
    cashBalance += revenue;
    totalRevenue += revenue;
    confettiController.play();
    _addLog('🎉 Harvested $currentCrop! Revenue: KES ${revenue.toStringAsFixed(0)}');
    cropAge = 0; // Reset for next planting
  }

  void _completeSimulation() {
    final profit = totalRevenue - totalExpenses;
    final roi = (profit / totalExpenses) * 100;
    
    String performance;
    if (profit > 30000 && roi > 50) {
      performance = 'Outstanding! You\'re a financial management expert!';
      confettiController.play();
    } else if (profit > 10000) {
      performance = 'Well done! Good financial management.';
    } else if (profit > 0) {
      performance = 'Fair performance. Consider better planning.';
    } else {
      performance = 'Loss incurred. Review your financial decisions.';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Year Complete!'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(performance, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Divider(height: 24),
              Text('Final Cash Balance: KES ${cashBalance.toStringAsFixed(0)}'),
              Text('Total Revenue: KES ${totalRevenue.toStringAsFixed(0)}'),
              Text('Total Expenses: KES ${totalExpenses.toStringAsFixed(0)}'),
              const SizedBox(height: 8),
              Text(
                'Net Profit: KES ${profit.toStringAsFixed(0)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: profit > 0 ? Colors.green : Colors.red,
                  fontSize: 16,
                ),
              ),
              Text('ROI: ${roi.toStringAsFixed(1)}%'),
              const Divider(height: 24),
              Text('Final Farm Size: ${landSize.toStringAsFixed(1)} acres'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Farm Financial Management'),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Text(
                'Month $currentMonth/$totalMonths',
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
                // Financial Summary
                Card(
                  color: primaryGreen.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Cash Balance:', style: TextStyle(fontSize: 16)),
                            Text(
                              'KES ${cashBalance.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: cashBalance > 0 ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Revenue:'),
                            Text('KES ${totalRevenue.toStringAsFixed(0)}', style: const TextStyle(color: Colors.green)),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Expenses:'),
                            Text('KES ${totalExpenses.toStringAsFixed(0)}', style: const TextStyle(color: Colors.red)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Farm Status
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Farm Status:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Land Size:'),
                            Text('${landSize.toStringAsFixed(1)} acres', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Current Crop:'),
                            Text(currentCrop, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Crop Age:'),
                            Text('$cropAge days / $harvestDay days'),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Expected Yield:'),
                            Text('${expectedYield.toStringAsFixed(0)} bags'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Decision Options
                const Text('Monthly Decisions:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                _buildDecisionOption(
                  'invest_inputs',
                  'Invest in Quality Inputs',
                  'Cost: KES 5,000 | Increases yield by 25%',
                  Icons.agriculture,
                  Colors.green,
                ),
                _buildDecisionOption(
                  'hire_labor',
                  'Hire Additional Labor',
                  'Cost: KES 3,000 | Improves efficiency',
                  Icons.people,
                  Colors.blue,
                ),
                _buildDecisionOption(
                  'save_money',
                  'Save Money',
                  'Earn 2% interest on current balance',
                  Icons.savings,
                  Colors.orange,
                ),
                _buildDecisionOption(
                  'expand_land',
                  'Expand Farm (+0.5 acres)',
                  'Cost: KES 15,000 | Permanent increase',
                  Icons.landscape,
                  Colors.brown,
                ),
                _buildDecisionOption(
                  'take_loan',
                  'Take Loan',
                  'Borrow KES 10,000 | Repay KES 11,000',
                  Icons.account_balance,
                  Colors.red,
                ),
                if (cropAge >= harvestDay)
                  _buildDecisionOption(
                    'plant_new',
                    'Plant New Crop',
                    'Restart crop cycle',
                    Icons.spa,
                    Colors.purple,
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
                        onPressed: selectedDecision != null && !decisionMade ? _applyDecision : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Make Decision', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: decisionMade || selectedDecision == null ? _nextMonth : null,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          currentMonth < totalMonths ? 'Next Month →' : 'Finish Year',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Decisions Log
                const Text('Decisions Log:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: decisionsLog.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          decisionsLog[index],
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

  Widget _buildDecisionOption(String key, String title, String description, IconData icon, Color color) {
    final isSelected = selectedDecision == key;
    
    return Card(
      color: isSelected ? color.withOpacity(0.15) : null,
      elevation: isSelected ? 4 : 1,
      child: RadioListTile<String>(
        value: key,
        groupValue: selectedDecision,
        onChanged: decisionMade ? null : (value) => setState(() => selectedDecision = value),
        title: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
          ],
        ),
        subtitle: Text(description, style: const TextStyle(fontSize: 12)),
        activeColor: color,
      ),
    );
  }
}