import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kilimomkononi/models/market_data.dart';
import 'package:kilimomkononi/screens/view_saved_data_page.dart';

class MarketPricePredictionWidget extends StatefulWidget {
  const MarketPricePredictionWidget({super.key});

  @override
  MarketPricePredictionWidgetState createState() => MarketPricePredictionWidgetState();
}

class MarketPricePredictionWidgetState extends State<MarketPricePredictionWidget> {
  String? _selectedRegion;
  String? _selectedCrop;
  final TextEditingController _marketController = TextEditingController();
  final TextEditingController _retailPriceController = TextEditingController();
  double? _predictedPrice;
  double? _userRetailPrice;
  bool _isLoading = false;

  final Map<String, double> _mockPrices = {
    "Maize": 50.0,
    "Beans": 120.0,
    "Rice": 160.0,
    "Wheat": 300.0,
    "Potatoes": 80.0,
    "Cassava": 150.0,
    "Tomatoes": 150.0,
    "Cabbage": 50.0,
    "Sugarcane": 150.0,
    "Carrots": 120.0,
    "Kale": 80.0,
  };

  @override
  void dispose() {
    _marketController.dispose();
    _retailPriceController.dispose();
    super.dispose();
  }

  void _showPredictedPrice() async {
    if (_selectedCrop != null && _mockPrices.containsKey(_selectedCrop)) {
      setState(() => _isLoading = true);
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _predictedPrice = _mockPrices[_selectedCrop];
        _isLoading = false;
      });
    } else {
      _showLogger('Please select a crop type.');
    }
  }

  void _updateRetailPrice() {
    final value = double.tryParse(_retailPriceController.text);
    if (value != null && value >= 0) {
      setState(() => _userRetailPrice = value);
    } else {
      _showLogger('Please enter a valid non-negative price.');
      _retailPriceController.clear();
      setState(() => _userRetailPrice = null);
    }
  }

  void _saveMarketPrice() async {
    if (_selectedRegion == null || _marketController.text.isEmpty || _selectedCrop == null || _userRetailPrice == null) {
      _showLogger('Please complete all fields before saving.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showLogger('Please log in to save data.');
      return;
    }

    final marketData = MarketData(
      region: _selectedRegion!,
      market: _marketController.text.trim(),
      cropType: _selectedCrop!,
      predictedPrice: _predictedPrice ?? 0.0,
      retailPrice: _userRetailPrice!,
      userId: user.uid,
      timestamp: Timestamp.now(),
    );

    try {
      await FirebaseFirestore.instance
          .collection('marketdata')
          .doc()
          .set(marketData.toMap());
      _showLogger('Market price details saved successfully!');
    } catch (e) {
      _showLogger('Failed to save data: $e');
    }
  }

  void _resetFields() {
    setState(() {
      _selectedRegion = null;
      _selectedCrop = null;
      _marketController.clear();
      _retailPriceController.clear();
      _predictedPrice = null;
      _userRetailPrice = null;
    });
  }

  void _showLogger(String message) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(
            message,
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.grey[100],
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.black87),
          titleLarge: TextStyle(color: Color.fromARGB(255, 3, 39, 4), fontWeight: FontWeight.bold),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 3, 39, 4),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Market Price Prediction',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          elevation: 0,
          backgroundColor: const Color.fromARGB(255, 3, 39, 4),
          foregroundColor: Colors.white,
        ),
        body: Container(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedRegion,
                  items: ['Nairobi', 'Coast', 'Lake', 'Rift Valley', 'Central', 'Eastern']
                      .map((region) => DropdownMenuItem(value: region, child: Text(region)))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedRegion = value),
                  decoration: InputDecoration(
                    labelText: 'Select Region',
                    prefixIcon: const Icon(Icons.location_on, color: Color.fromARGB(255, 3, 39, 4)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _marketController,
                  decoration: InputDecoration(
                    labelText: 'Enter Market',
                    hintText: 'e.g., Gikomba',
                    prefixIcon: const Icon(Icons.store, color: Color.fromARGB(255, 3, 39, 4)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedCrop,
                  items: _mockPrices.keys.map((crop) => DropdownMenuItem(value: crop, child: Text(crop))).toList(),
                  onChanged: (value) => setState(() => _selectedCrop = value),
                  decoration: InputDecoration(
                    labelText: 'Select Crop Type',
                    prefixIcon: const Icon(Icons.grass, color: Color.fromARGB(255, 3, 39, 4)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _showPredictedPrice,
                  icon: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Icon(Icons.visibility, color: Colors.white),
                  label: Text(
                    _isLoading ? 'Loading...' : 'Show Predicted Price',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                if (_predictedPrice != null)
                  Row(
                    children: [
                      const Icon(Icons.price_check, color: Color.fromARGB(255, 3, 39, 4), size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Market Price: Ksh ${_predictedPrice!.toStringAsFixed(2)}/kg',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 3, 39, 4)),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _retailPriceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Your Retail Price (Ksh/kg)',
                    hintText: 'e.g., 60.0',
                    prefixIcon: const Icon(Icons.attach_money, color: Color.fromARGB(255, 3, 39, 4)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (_) => _updateRetailPrice(),
                ),
                const SizedBox(height: 16),
                if (_userRetailPrice != null)
                  Row(
                    children: [
                      Icon(
                        _userRetailPrice! > (_predictedPrice ?? 0) ? Icons.arrow_upward : Icons.arrow_downward,
                        color: _userRetailPrice! > (_predictedPrice ?? 0) ? Color.fromARGB(255, 3, 39, 4) : Colors.red,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Your Retail Price: Ksh ${_userRetailPrice!.toStringAsFixed(2)}/kg',
                        style: const TextStyle(fontSize: 18, color: Colors.black87),
                      ),
                    ],
                  ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _saveMarketPrice,
                      icon: const Icon(Icons.save, color: Colors.white),
                      label: const Text(
                        'Save',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _resetFields,
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      label: const Text(
                        'Reset',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ViewSavedDataPage()),
                    ),
                    icon: const Icon(Icons.list, color: Colors.white),
                    label: const Text(
                      'View Saved Data',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}