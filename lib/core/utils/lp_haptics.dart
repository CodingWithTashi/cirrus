import 'package:flutter/services.dart';

/// Semantic haptic vocabulary (docs/03 §1: every action gets a reaction).
abstract final class LpHaptics {
  /// Chip select, keypad tick, log tap.
  static void light() => HapticFeedback.lightImpact();

  /// Landing a rolled-up number, plan lock.
  static void medium() => HapticFeedback.mediumImpact();

  /// Commit complete, milestone confetti.
  static void heavy() => HapticFeedback.heavyImpact();

  /// Selection tick inside pickers/sliders.
  static void tick() => HapticFeedback.selectionClick();

  /// Celebration pattern — a quick double pulse.
  static Future<void> celebrate() async {
    HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    HapticFeedback.heavyImpact();
  }
}
