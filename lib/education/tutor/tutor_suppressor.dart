// lib/education/tutor/tutor_suppressor.dart
import 'package:flutter/material.dart';

/// true = FAB hidden.  false = FAB visible.
final ValueNotifier<bool> tutorSuppressed = ValueNotifier(false);

/// Mix into any State whose screen should hide the Shamba AI FAB.
mixin TutorSuppressorMixin<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      tutorSuppressed.value = true;
    });
  }

  @override
  void dispose() {
    tutorSuppressed.value = false;
    super.dispose();
  }
}