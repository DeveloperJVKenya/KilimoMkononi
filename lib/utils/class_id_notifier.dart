// lib/education/utils/class_id_notifier.dart
import 'package:flutter/foundation.dart';

/// GLOBAL – used by every other education screen (e.g., for Firestore rules, navigation)
/// Example usage: classIdNotifier.value = 'MySchool_primary_5';
final classIdNotifier = ValueNotifier<String?>(null);