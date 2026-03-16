// market_trading_simulation.dart - Interactive Market Trading Simulation
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

const Color primaryGreen = Color(0xFF003900);

class MarketTradingSimulation extends StatefulWidget {
  final String topic;
  final VoidCallback onComplete;

  const MarketTradingSimulation({
    super.key,
    required this.topic,
    required this.onComplete,
  });

  @override
  State<MarketTradingSimulation> createState() => _MarketTradingSimulationState();
}

class _MarketTradingSimulationState extends State<MarketTradingSimulation> {
  double cash = 1000.0;
  final Map<String, int> inventory = {
    'Maize': 0,
    'Tomatoes': 0,
    'Cabbage': 0,
    'Potatoes': 0,
  };

  Map<String, double> prices = {
    'Maize': 50.0,
    'Tomatoes': 80.0,
    'Cabbage': 60.0,
    'Potatoes': 45.0,
  };

  Map<String, PriceTrend> trends = {
    'Maize': PriceTrend.stable,
    'Tomatoes': PriceTrend.rising,
    'Cabbage': PriceTrend.falling,
    'Potatoes': PriceTrend.stable,
  };

  int day = 1;
  int totalTransactions = 0;
  double totalProfit = 0;
  Timer? marketTimer;
  late ConfettiController confettiController;
  
  List<String> newsEvents = [];
  List<Map<String, dynamic>> transactionHistory = [];
  
  final Random random = Random();
  bool simulationComplete = false;
  
  String currentTip = '';

  @override
  void initState() {
    super.initState();
    confettiController = ConfettiController(duration: const Duration(seconds: 2));
    startSimulation();
  }

  @override
  void dispose() {
    confettiController.dispose();
    marketTimer?.cancel();
    super.dispose();
  }

  void startSimulation() {
    setState(() {
      currentTip = 'Welcome to the Market! You have 1,000 Ksh. Buy low, sell high to make profit!';
      newsEvents.add('Market opens! Fresh produce available.');
    });
    
    marketTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (day >= 10) {
        endSimulation();
        timer.cancel();
      } else {
        updateMarketPrices();
      }
    });
  }

  void updateMarketPrices() {
    setState(() {
      prices.forEach((crop, currentPrice) {
        double change = 0;
        
        switch (trends[crop]!) {
          case PriceTrend.rising:
            change = currentPrice * (0.05 + random.nextDouble() * 0.1);
            break;
          case PriceTrend.falling:
            change = -currentPrice * (0.05 + random.nextDouble() * 0.1);
            break;
          case PriceTrend.stable:
            change = currentPrice * (random.nextDouble() * 0.06 - 0.03);
            break;
        }
        
        prices[crop] = (currentPrice + change).clamp(20.0, 200.0);
      });
      
      if (random.nextDouble() < 0.3) {
        generateMarketEvent();
      }
      
      if (random.nextDouble() < 0.4) {
        shiftTrends();
      }
    });
  }

  void generateMarketEvent() {
    final events = [
      {'msg': 'Rain expected! Vegetable prices rising.', 'crop': 'Tomatoes', 'trend': PriceTrend.rising},
      {'msg': 'Bumper harvest! Maize prices falling.', 'crop': 'Maize', 'trend': PriceTrend.falling},
      {'msg': 'High demand for potatoes in the city!', 'crop': 'Potatoes', 'trend': PriceTrend.rising},
      {'msg': 'Market surplus of cabbage.', 'crop': 'Cabbage', 'trend': PriceTrend.falling},
      {'msg': 'Export opportunity for tomatoes!', 'crop': 'Tomatoes', 'trend': PriceTrend.rising},
      {'msg': 'New farmers enter maize market.', 'crop': 'Maize', 'trend': PriceTrend.stable},
    ];
    
    final event = events[random.nextInt(events.length)];
    setState(() {
      newsEvents.insert(0, event['msg'] as String);
      if (newsEvents.length > 5) newsEvents.removeLast();
      
      trends[event['crop'] as String] = event['trend'] as PriceTrend;
    });
  }

  void shiftTrends() {
    final crop = prices.keys.elementAt(random.nextInt(prices.length));
    final trendsList = PriceTrend.values;
    setState(() {
      trends[crop] = trendsList[random.nextInt(trendsList.length)];
    });
  }

  void buy(String crop, int quantity) {
    final cost = prices[crop]! * quantity;
    
    if (cash < cost) {
      showMessage('Not enough cash! You need ${cost.toStringAsFixed(2)} Ksh.', isError: true);
      return;
    }
    
    setState(() {
      cash -= cost;
      inventory[crop] = (inventory[crop] ?? 0) + quantity;
      totalTransactions++;
      
      transactionHistory.insert(0, {
        'day': day,
        'type': 'BUY',
        'crop': crop,
        'quantity': quantity,
        'price': prices[crop],
        'total': cost,
      });
      
      if (transactionHistory.length > 10) transactionHistory.removeLast();
      
      currentTip = 'Bought $quantity $crop for ${cost.toStringAsFixed(2)} Ksh. Watch prices to sell at profit!';
    });
  }

  void sell(String crop, int quantity) {
    if ((inventory[crop] ?? 0) < quantity) {
      showMessage('Not enough $crop in inventory!', isError: true);
      return;
    }
    
    final revenue = prices[crop]! * quantity;
    
    setState(() {
      cash += revenue;
      inventory[crop] = (inventory[crop] ?? 0) - quantity;
      totalTransactions++;
      
      totalProfit += revenue * 0.2;
      
      transactionHistory.insert(0, {
        'day': day,
        'type': 'SELL',
        'crop': crop,
        'quantity': quantity,
        'price': prices[crop],
        'total': revenue,
      });
      
      if (transactionHistory.length > 10) transactionHistory.removeLast();
      
      currentTip = 'Sold $quantity $crop for ${revenue.toStringAsFixed(2)} Ksh. Good trade!';
    });
  }

  void nextDay() {
    if (day >= 10) {
      endSimulation();
      return;
    }
    
    setState(() {
      day++;
      currentTip = 'Day $day: Monitor prices and trends. Make smart trading decisions!';
      newsEvents.insert(0, 'Day $day begins. Market is active.');
    });
    
    updateMarketPrices();
  }

  void endSimulation() {
    if (simulationComplete) return;
    
    setState(() {
      simulationComplete = true;
      marketTimer?.cancel();
    });
    
    double inventoryValue = 0;
    inventory.forEach((crop, qty) {
      inventoryValue += prices[crop]! * qty;
    });
    
    final totalAssets = cash + inventoryValue;
    final netProfit = totalAssets - 1000;
    final profitPercent = (netProfit / 1000 * 100);
    
    confettiController.play();
    
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        showCompletionDialog(totalAssets, netProfit, profitPercent);
      }
    });
  }

  void showCompletionDialog(double totalAssets, double netProfit, double profitPercent) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber, size: 32),
            SizedBox(width: 8),
            Text('Market Closed!'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '10 Days of Trading Complete!',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              resultRow('Starting Capital', '1,000 Ksh'),
              resultRow('Final Cash', '${cash.toStringAsFixed(2)} Ksh'),
              resultRow('Inventory Value', '${(inventory.values.fold(0, (sum, qty) => sum + qty) * 50).toStringAsFixed(2)} Ksh'),
              const Divider(),
              resultRow(
                'Total Assets',
                '${totalAssets.toStringAsFixed(2)} Ksh',
                isBold: true,
              ),
              resultRow(
                'Net Profit',
                '${netProfit >= 0 ? '+' : ''}${netProfit.toStringAsFixed(2)} Ksh',
                color: netProfit >= 0 ? Colors.green : Colors.red,
                isBold: true,
              ),
              resultRow(
                'Return',
                '${profitPercent >= 0 ? '+' : ''}${profitPercent.toStringAsFixed(1)}%',
                color: profitPercent >= 0 ? Colors.green : Colors.red,
              ),
              const SizedBox(height: 12),
              resultRow('Total Transactions', '$totalTransactions'),
              const SizedBox(height: 16),
              if (profitPercent >= 20)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green),
                  ),
                  child: const Text(
                    '🌟 Excellent trading! You understand market dynamics!',
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                )
              else if (profitPercent >= 0)
                const Text(
                  '👍 Good job! Keep learning about market trends.',
                  style: TextStyle(color: Colors.orange),
                )
              else
                const Text(
                  '📚 Keep practicing! Watch trends and timing closely.',
                  style: TextStyle(color: Colors.blue),
                ),
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
            ),
          ),
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

  void showBuySellDialog(String crop) {
    final quantityController = TextEditingController(text: '5');
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text('Trade $crop'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current Price: ${prices[crop]!.toStringAsFixed(2)} Ksh/unit'),
            Text('Trend: ${getTrendIcon(trends[crop]!)} ${trends[crop]!.name}'),
            Text('Your Cash: ${cash.toStringAsFixed(2)} Ksh'),
            Text('Inventory: ${inventory[crop]} units'),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final qty = int.tryParse(quantityController.text) ?? 0;
              if (qty > 0) {
                buy(crop, qty);
                Navigator.pop(dialogContext);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('BUY'),
          ),
          ElevatedButton(
            onPressed: () {
              final qty = int.tryParse(quantityController.text) ?? 0;
              if (qty > 0) {
                sell(crop, qty);
                Navigator.pop(dialogContext);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('SELL'),
          ),
        ],
      ),
    );
  }

  String getTrendIcon(PriceTrend trend) {
    switch (trend) {
      case PriceTrend.rising:
        return '📈';
      case PriceTrend.falling:
        return '📉';
      case PriceTrend.stable:
        return '➡️';
    }
  }

  Color getTrendColor(PriceTrend trend) {
    switch (trend) {
      case PriceTrend.rising:
        return Colors.green;
      case PriceTrend.falling:
        return Colors.red;
      case PriceTrend.stable:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Market Trading Simulation'),
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
                buildPlayerStats(),
                const SizedBox(height: 16),
                buildMarketPrices(),
                const SizedBox(height: 16),
                buildNewsTicker(),
                const SizedBox(height: 16),
                buildTransactionHistory(),
                const SizedBox(height: 16),
                buildControls(),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              colors: const [Colors.green, Colors.yellow, Colors.orange],
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

  Widget buildPlayerStats() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                statItem('Day', '$day/10', Icons.calendar_today),
                statItem('Cash', '${cash.toStringAsFixed(0)} Ksh', Icons.account_balance_wallet),
                statItem('Trades', '$totalTransactions', Icons.swap_horiz),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget statItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: primaryGreen),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget buildMarketPrices() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Market Prices',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...prices.keys.map((crop) {
              final price = prices[crop]!;
              final trend = trends[crop]!;
              final inventoryQty = inventory[crop] ?? 0;
              
              return InkWell(
                onTap: () => showBuySellDialog(crop),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: getTrendColor(trend).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: getTrendColor(trend).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            getTrendIcon(trend),
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              crop,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              '${price.toStringAsFixed(2)} Ksh/unit • ${trend.name}',
                              style: TextStyle(color: getTrendColor(trend), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Stock: $inventoryQty',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'TAP TO TRADE',
                            style: TextStyle(fontSize: 10, color: Colors.blue),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget buildNewsTicker() {
    return Card(
      elevation: 4,
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.newspaper, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Market News',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...newsEvents.take(3).map((news) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: 16)),
                  Expanded(child: Text(news, style: const TextStyle(fontSize: 13))),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget buildTransactionHistory() {
    if (transactionHistory.isEmpty) return const SizedBox.shrink();
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Transactions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...transactionHistory.take(5).map((tx) {
              final isBuy = tx['type'] == 'BUY';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isBuy ? Colors.blue : Colors.orange).shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      isBuy ? Icons.arrow_downward : Icons.arrow_upward,
                      color: isBuy ? Colors.blue : Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${tx['type']} ${tx['quantity']} ${tx['crop']}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      '${tx['total'].toStringAsFixed(0)} Ksh',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget buildControls() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: day < 10 ? nextDay : endSimulation,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: Icon(day < 10 ? Icons.fast_forward : Icons.assessment, size: 28),
        label: Text(
          day < 10 ? 'NEXT DAY ($day/10)' : 'VIEW RESULTS',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

enum PriceTrend {
  rising,
  falling,
  stable,
}