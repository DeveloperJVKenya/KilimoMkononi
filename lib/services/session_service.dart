// lib/services/session_service.dart
//
// One sign-out for the whole app (drawer, Settings, education screens):
// clears per-user caches so the next person on a shared phone never sees
// the previous user's farm, station readings or sensor data, then signs out
// of Firebase and the Google account on this device (so "Continue with
// Google" shows the account chooser again). NotificationService drops this
// device's push token when it sees the sign-out.

import 'package:flutter/foundation.dart';
import 'package:kilimomkononi/services/farm_location_service.dart';
import 'package:kilimomkononi/services/google_auth_service.dart';
import 'package:kilimomkononi/services/iot_sensor_service.dart';
import 'package:kilimomkononi/services/nuasense_service.dart';

class SessionService {
  SessionService._();

  static Future<void> signOut() async {
    try {
      await FarmLocationService.clear();
    } catch (e) {
      debugPrint('[SessionService] farm location clear: $e');
    }
    IotSensorService.clearCache();
    NuaSenseService.clearCache(); // all stations
    await GoogleAuthService.signOut(); // Firebase + Google account
  }
}
