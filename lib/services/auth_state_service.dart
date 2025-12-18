// lib/services/auth_state_service.dart
import 'package:flutter/foundation.dart';

class AuthStateService extends ChangeNotifier {
  bool _skipNextAuthCheck = false;

  bool get skipNextAuthCheck => _skipNextAuthCheck;

  void setSkipNext() {
    _skipNextAuthCheck = true;
    notifyListeners();
  }

  void clearSkip() {
    _skipNextAuthCheck = false;
  }
}