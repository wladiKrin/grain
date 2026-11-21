import 'package:flutter/services.dart';

/// Haptic feedback for dial detents.
abstract class Haptics {
  /// [strong] is used for full stops, otherwise a light selection tick.
  void tick({required bool strong});
}

class SystemHaptics implements Haptics {
  SystemHaptics({this.enabled = true});

  bool enabled;

  @override
  void tick({required bool strong}) {
    if (!enabled) return;
    if (strong) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
    }
  }
}
