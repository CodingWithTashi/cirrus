import 'package:flutter/material.dart';

/// Type system: Space Grotesk (700/500) for display + every number
/// (tabular figures), Inter (400–700) for body. Never serif (docs/07 §3).
abstract final class LpType {
  static const String display = 'SpaceGrotesk';
  static const String body = 'Inter';

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  // ---- Space Grotesk display ------------------------------------------------

  /// Hero numerals (onboarding puff counter, money hero…). Pair with a size.
  static TextStyle numberHero(Color color, {double size = 84}) => TextStyle(
    fontFamily: display,
    fontWeight: FontWeight.w700,
    fontSize: size,
    height: 1,
    letterSpacing: -2,
    color: color,
    fontFeatures: _tabular,
  );

  /// Stat-card numerals (24–30 px).
  static TextStyle number(Color color, {double size = 26}) => TextStyle(
    fontFamily: display,
    fontWeight: FontWeight.w700,
    fontSize: size,
    height: 1.05,
    letterSpacing: -0.5,
    color: color,
    fontFeatures: _tabular,
  );

  /// Screen hero title (30–34 px).
  static TextStyle title(Color color, {double size = 30}) => TextStyle(
    fontFamily: display,
    fontWeight: FontWeight.w700,
    fontSize: size,
    height: 1.15,
    letterSpacing: -0.8,
    color: color,
  );

  /// App-bar / section title (22 px).
  static TextStyle titleSm(Color color, {double size = 22}) => TextStyle(
    fontFamily: display,
    fontWeight: FontWeight.w700,
    fontSize: size,
    height: 1.2,
    letterSpacing: -0.5,
    color: color,
  );

  /// Card heading (16–17 px display bold).
  static TextStyle heading(Color color, {double size = 17}) => TextStyle(
    fontFamily: display,
    fontWeight: FontWeight.w700,
    fontSize: size,
    height: 1.25,
    color: color,
  );

  /// CTA label (Space Grotesk 700 · 17).
  static TextStyle button(Color color, {double size = 17}) => TextStyle(
    fontFamily: display,
    fontWeight: FontWeight.w700,
    fontSize: size,
    height: 1.1,
    color: color,
  );

  /// Small display accent (progress "5/12", chips with numbers).
  static TextStyle displaySmall(Color color, {double size = 13}) => TextStyle(
    fontFamily: display,
    fontWeight: FontWeight.w700,
    fontSize: size,
    height: 1.2,
    color: color,
    fontFeatures: _tabular,
  );

  // ---- Inter body -----------------------------------------------------------

  static TextStyle body15(Color color, {FontWeight weight = FontWeight.w400}) =>
      TextStyle(
        fontFamily: body,
        fontWeight: weight,
        fontSize: 15,
        height: 1.5,
        color: color,
      );

  static TextStyle body14(Color color, {FontWeight weight = FontWeight.w400}) =>
      TextStyle(
        fontFamily: body,
        fontWeight: weight,
        fontSize: 14,
        height: 1.5,
        color: color,
      );

  static TextStyle body13(Color color, {FontWeight weight = FontWeight.w400}) =>
      TextStyle(
        fontFamily: body,
        fontWeight: weight,
        fontSize: 13,
        height: 1.5,
        color: color,
      );

  static TextStyle caption(
    Color color, {
    FontWeight weight = FontWeight.w400,
  }) => TextStyle(
    fontFamily: body,
    fontWeight: weight,
    fontSize: 12,
    height: 1.45,
    color: color,
  );

  static TextStyle caption11(
    Color color, {
    FontWeight weight = FontWeight.w400,
  }) => TextStyle(
    fontFamily: body,
    fontWeight: weight,
    fontSize: 11,
    height: 1.4,
    color: color,
  );

  static TextStyle micro(Color color, {FontWeight weight = FontWeight.w400}) =>
      TextStyle(
        fontFamily: body,
        fontWeight: weight,
        fontSize: 10,
        height: 1.35,
        color: color,
      );

  /// ALL-CAPS section label ("YOUR WHY", "COMING UP").
  static TextStyle label(Color color) => TextStyle(
    fontFamily: body,
    fontWeight: FontWeight.w600,
    fontSize: 12,
    height: 1.3,
    letterSpacing: 0.5,
    color: color,
  );

  /// Emphasized inline (semibold 14–16).
  static TextStyle emphasis(Color color, {double size = 16}) => TextStyle(
    fontFamily: body,
    fontWeight: FontWeight.w600,
    fontSize: size,
    height: 1.35,
    color: color,
  );
}
