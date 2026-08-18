import 'package:flutter/animation.dart';

/// Spacing, radius, and motion constants shared across the app.
abstract final class LpDimens {
  // Spacing scale.
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double screenPad = 16;
  static const double screenPadWide = 20;

  // Corner radii (from the design frames).
  static const double rChip = 999;
  static const double rInput = 14;
  static const double rCard = 16;
  static const double rCardLg = 18;
  static const double rBento = 20;
  static const double rButton = 16;
  static const double rSheet = 24;

  // Component sizes.
  static const double ctaHeight = 56;
  static const double ctaHeightHero = 64;
  static const double optionCardPad = 18;
}

/// Motion language: every tap reacts; nothing over ~400ms except celebrations.
abstract final class LpMotion {
  static const Duration tap = Duration(milliseconds: 120);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 450);
  static const Duration reveal = Duration(milliseconds: 800);

  static const Curve spring = Curves.easeOutBack;
  static const Curve ease = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
}
