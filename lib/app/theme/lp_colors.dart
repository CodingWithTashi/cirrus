import 'package:flutter/material.dart';

/// Semantic color tokens for the LastPuff design system.
///
/// Two official palettes exist (docs/07 §3 + Claude Design runs 1–3):
///  * **Midnight Ember** — dark, the brand default.
///  * **Daylight Ember** — light, from "LastPuff Run 2 Light".
///
/// Widgets never reference raw hex values; they read roles off this extension
/// via `context.lp` so both themes stay in lockstep.
class LpColors extends ThemeExtension<LpColors> {
  const LpColors({
    required this.background,
    required this.panicBackground,
    required this.surface,
    required this.surfaceSubtle,
    required this.surfaceInset,
    required this.border,
    required this.borderSubtle,
    required this.textPrimary,
    required this.textBody,
    required this.textSecondary,
    required this.textFaint,
    required this.volt,
    required this.voltStrong,
    required this.voltText,
    required this.voltFocus,
    required this.voltSoft,
    required this.onVolt,
    required this.ember,
    required this.emberText,
    required this.emberSoft,
    required this.oxygen,
    required this.oxygenText,
    required this.oxygenSoft,
    required this.caution,
    required this.cautionText,
    required this.danger,
    required this.dangerText,
    required this.dangerSoft,
    required this.navBar,
    required this.brightness,
  });

  /// Midnight Ember — Void ground, Volt/Ember/Oxygen accents.
  const LpColors.midnight()
    : this(
        background: const Color(0xFF0A0C10),
        panicBackground: const Color(0xFF05070B),
        surface: const Color(0xFF161A22),
        surfaceSubtle: const Color(0xFF10131A),
        surfaceInset: const Color(0xFF0A0C10),
        border: const Color(0xFF232A36),
        borderSubtle: const Color(0xFF1C222D),
        textPrimary: const Color(0xFFFFFFFF),
        textBody: const Color(0xFFE7EAF0),
        textSecondary: const Color(0xFF9AA3B2),
        textFaint: const Color(0xFF4A5468),
        volt: const Color(0xFFC8F542),
        voltStrong: const Color(0xFFC8F542),
        voltText: const Color(0xFFC8F542),
        voltFocus: const Color(0xFFC8F542),
        voltSoft: const Color(0x1FC8F542),
        onVolt: const Color(0xFF0A0C10),
        ember: const Color(0xFFFF8A00),
        emberText: const Color(0xFFFF8A00),
        emberSoft: const Color(0x1FFF8A00),
        oxygen: const Color(0xFF6EE7FF),
        oxygenText: const Color(0xFF6EE7FF),
        oxygenSoft: const Color(0x1F6EE7FF),
        caution: const Color(0xFFE8C547),
        cautionText: const Color(0xFFE8C547),
        danger: const Color(0xFFFF5C5C),
        dangerText: const Color(0xFFFF5C5C),
        dangerSoft: const Color(0x1AFF5C5C),
        navBar: const Color(0xF210131A),
        brightness: Brightness.dark,
      );

  /// Daylight Ember — the light theme from "LastPuff Run 2 Light".
  const LpColors.daylight()
    : this(
        background: const Color(0xFFF6F8F4),
        panicBackground: const Color(0xFFEAF4F9),
        surface: const Color(0xFFFFFFFF),
        surfaceSubtle: const Color(0xFFF0F3EC),
        surfaceInset: const Color(0xFFF6F8F4),
        border: const Color(0xFFE3E7EE),
        borderSubtle: const Color(0xFFE4E6DF),
        textPrimary: const Color(0xFF191D27),
        textBody: const Color(0xFF39404E),
        textSecondary: const Color(0xFF68727E),
        textFaint: const Color(0xFFABB2BD),
        volt: const Color(0xFFC8F542),
        voltStrong: const Color(0xFF84B400),
        voltText: const Color(0xFF587E00),
        voltFocus: const Color(0xFFA5CD1F),
        voltSoft: const Color(0x1AC8F542),
        onVolt: const Color(0xFF0A0C10),
        ember: const Color(0xFFFF8A00),
        emberText: const Color(0xFFCE6A00),
        emberSoft: const Color(0x1FFF8A00),
        oxygen: const Color(0xFF6EE7FF),
        oxygenText: const Color(0xFF0787B4),
        oxygenSoft: const Color(0x1F6EE7FF),
        caution: const Color(0xFFE8C547),
        cautionText: const Color(0xFF9A7B00),
        danger: const Color(0xFFFF5C5C),
        dangerText: const Color(0xFFCC4444),
        dangerSoft: const Color(0x1AFF5C5C),
        navBar: const Color(0xF7FFFFFF),
        brightness: Brightness.light,
      );

  final Color background;
  final Color panicBackground;
  final Color surface;
  final Color surfaceSubtle;
  final Color surfaceInset;
  final Color border;
  final Color borderSubtle;
  final Color textPrimary;
  final Color textBody;
  final Color textSecondary;
  final Color textFaint;

  /// Raw Volt — CTA fills and glows; identical in both themes.
  final Color volt;

  /// Volt with enough contrast to draw strokes/rings on [background].
  final Color voltStrong;

  /// Volt with enough contrast to set text on [background].
  final Color voltText;

  /// Border color of a focused input.
  final Color voltFocus;
  final Color voltSoft;
  final Color onVolt;

  final Color ember;
  final Color emberText;
  final Color emberSoft;

  final Color oxygen;
  final Color oxygenText;
  final Color oxygenSoft;

  /// Mid-tier warning family (the Moderate dependence badge).
  final Color caution;
  final Color cautionText;

  final Color danger;
  final Color dangerText;
  final Color dangerSoft;

  final Color navBar;
  final Brightness brightness;

  bool get isDark => brightness == Brightness.dark;

  /// Signature Volt glow, e.g. behind the primary CTA.
  List<BoxShadow> voltGlow({double blur = 28, double opacity = 0.25}) => [
    BoxShadow(
      color: volt.withValues(alpha: opacity),
      blurRadius: blur,
    ),
  ];

  List<BoxShadow> emberGlow({double blur = 24, double opacity = 0.35}) => [
    BoxShadow(
      color: ember.withValues(alpha: opacity),
      blurRadius: blur,
    ),
  ];

  List<BoxShadow> oxygenGlow({double blur = 28, double opacity = 0.3}) => [
    BoxShadow(
      color: oxygen.withValues(alpha: opacity),
      blurRadius: blur,
    ),
  ];

  @override
  LpColors copyWith({Brightness? brightness}) => this;

  @override
  LpColors lerp(ThemeExtension<LpColors>? other, double t) {
    if (other is! LpColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return LpColors(
      background: c(background, other.background),
      panicBackground: c(panicBackground, other.panicBackground),
      surface: c(surface, other.surface),
      surfaceSubtle: c(surfaceSubtle, other.surfaceSubtle),
      surfaceInset: c(surfaceInset, other.surfaceInset),
      border: c(border, other.border),
      borderSubtle: c(borderSubtle, other.borderSubtle),
      textPrimary: c(textPrimary, other.textPrimary),
      textBody: c(textBody, other.textBody),
      textSecondary: c(textSecondary, other.textSecondary),
      textFaint: c(textFaint, other.textFaint),
      volt: c(volt, other.volt),
      voltStrong: c(voltStrong, other.voltStrong),
      voltText: c(voltText, other.voltText),
      voltFocus: c(voltFocus, other.voltFocus),
      voltSoft: c(voltSoft, other.voltSoft),
      onVolt: c(onVolt, other.onVolt),
      ember: c(ember, other.ember),
      emberText: c(emberText, other.emberText),
      emberSoft: c(emberSoft, other.emberSoft),
      oxygen: c(oxygen, other.oxygen),
      oxygenText: c(oxygenText, other.oxygenText),
      oxygenSoft: c(oxygenSoft, other.oxygenSoft),
      caution: c(caution, other.caution),
      cautionText: c(cautionText, other.cautionText),
      danger: c(danger, other.danger),
      dangerText: c(dangerText, other.dangerText),
      dangerSoft: c(dangerSoft, other.dangerSoft),
      navBar: c(navBar, other.navBar),
      brightness: t < 0.5 ? brightness : other.brightness,
    );
  }
}

extension LpColorsX on BuildContext {
  /// Shorthand for the LastPuff palette of the active theme.
  LpColors get lp => Theme.of(this).extension<LpColors>()!;
}
