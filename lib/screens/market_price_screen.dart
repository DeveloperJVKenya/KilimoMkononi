// lib/education/education_market_price.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class MarketPriceScreen extends StatefulWidget {
  const MarketPriceScreen({super.key});

  @override
  State<MarketPriceScreen> createState() => _MarketPriceScreenState();
}

class _MarketPriceScreenState extends State<MarketPriceScreen> {
  bool _showDisclaimer = true;
  bool _isLaunching = false;

  static const String _kamisUrl = 'https://kamis.kilimo.go.ke/site/market';

  @override
  void initState() {
    super.initState();
    _loadDisclaimerPreference();
  }

  Future<void> _loadDisclaimerPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showDisclaimer = prefs.getBool('showMarketDisclaimer') ?? true;
    });
  }

  Future<void> _dismissDisclaimer() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showMarketDisclaimer', false);
    setState(() {
      _showDisclaimer = false;
    });
  }

  Future<void> _openKamisInBrowser() async {
    final uri = Uri.parse(_kamisUrl);
    setState(() => _isLaunching = true);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // Opens in Chrome/Safari
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open browser')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLaunching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Market Prices',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 3, 39, 4),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: _isLaunching
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isLaunching ? null : _openKamisInBrowser,
            tooltip: 'Open in Browser',
          ),
        ],
      ),
      body: Column(
        children: [
          // Disclaimer Banner
          if (_showDisclaimer)
            Container(
              width: double.infinity,
              color: Colors.amber[100],
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Data sourced from the official KAMIS (Kenya Agricultural Market Information System).",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: "Dismiss",
                    onPressed: _dismissDisclaimer,
                  ),
                ],
              ),
            ),

          // Main Content: Big Button to Open KAMIS
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.store,
                      size: 80,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'View Live Market Prices',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Tap below to open the official KAMIS website in your browser.',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _isLaunching ? null : _openKamisInBrowser,
                      icon: _isLaunching
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.open_in_browser),
                      label: Text(_isLaunching ? 'Opening...' : 'Open KAMIS'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}