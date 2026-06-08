// lib/services/connectivity_service.dart
//
// Wraps connectivity_plus in a ChangeNotifier so any widget in the tree can
// react to network changes via Provider / Consumer.
//
// Usage in a widget:
//   final conn = context.watch<ConnectivityService>();
//   if (!conn.isOnline) { /* show offline banner */ }
//
// Usage in an async method:
//   if (!context.read<ConnectivityService>().isOnline) {
//     showSnackBar('No internet connection');
//     return;
//   }

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _subscription;

  // Current connectivity results (can be multiple on some platforms)
  List<ConnectivityResult> _results = [ConnectivityResult.none];

  ConnectivityService() {
    _init();
  }

  Future<void> _init() async {
    // Get the initial state
    _results = await _connectivity.checkConnectivity();
    notifyListeners();

    // Listen for changes
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _results = results;
      notifyListeners();
    });
  }

  /// True when at least one non-none connection type is present.
  bool get isOnline =>
      _results.isNotEmpty &&
      _results.any((r) => r != ConnectivityResult.none);

  /// True when explicitly offline (all results are none).
  bool get isOffline => !isOnline;

  /// The primary connection type (first non-none result, or none).
  ConnectivityResult get connectionType {
    try {
      return _results.firstWhere((r) => r != ConnectivityResult.none);
    } catch (_) {
      return ConnectivityResult.none;
    }
  }

  /// Human-readable connection label.
  String get connectionLabel {
    switch (connectionType) {
      case ConnectivityResult.wifi:
        return 'Wi-Fi';
      case ConnectivityResult.mobile:
        return 'Mobile data';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.bluetooth:
        return 'Bluetooth';
      case ConnectivityResult.vpn:
        return 'VPN';
      case ConnectivityResult.other:
        return 'Connected';
      case ConnectivityResult.none:
      default:
        return 'Offline';
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}