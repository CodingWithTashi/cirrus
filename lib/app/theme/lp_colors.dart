import 'package:flutter/material.dart';

/// Semantic color tokens for the LastPuff design system.
///
/// Three palette FAMILIES exist, each with a dark and a light mode. Which one
/// is active is `LpPalette` (see `lp_palette.dart`), chosen in Settings and
/// clamped to the free family for anyone without Premium:
///
///  * **Ember** — free, the brand default (docs/07 §3 + Claude Design runs
///    1–3). [LpColors.midnight] dark, [LpColors.daylight] light.
///  * **Hearth** — Premium. Warm and Ember-led: amber takes the primary slot
///    from Volt lime over a warm charcoal / linen ground.
///  * **Tide** — Premium. Cool and Oxygen-led: a teal-cyan primary over deep
///    indigo / arctic.
///
/// The token names are HUE-named for historical reasons but ROLE-used: [volt]
/// is "the primary accent", [onVolt] is "ink on the primary fill", [voltText]
/// is "accent text on the ground". A new family therefore repaints the slots
/// and never renames them — which is why adding two families touched no
/// widget. Do not read [volt] as "lime"; read it as "primary".
///
/// Widgets never reference raw hex values; they read roles off this extension
/// via `context.lp` so every family stays in lockstep.
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

  /// Hearth Night — Premium. Warm charcoal ground, amber primary.
  ///
  /// [oxygen] is deliberately left at the brand cyan: it is the only cold
  /// thing on the screen, and without it a warm ground plus a warm primary
  /// plus a warm streak colour reads as mud. [caution] is pulled off the
  /// brand `0xFFE8C547` to a duller gold, because beside an amber primary the
  /// brand yellow stops reading as a separate signal — and caution is a
  /// dependence badge, so it has to stay legible AS a warning.
  const LpColors.hearthNight()
    : this(
        background: const Color(0xFF12100D),
        panicBackground: const Color(0xFF090807),
        surface: const Color(0xFF1D1915),
        surfaceSubtle: const Color(0xFF17130F),
        surfaceInset: const Color(0xFF12100D),
        border: const Color(0xFF302921),
        borderSubtle: const Color(0xFF251F19),
        textPrimary: const Color(0xFFFFFFFF),
        textBody: const Color(0xFFF2ECE2),
        textSecondary: const Color(0xFFB3A492),
        textFaint: const Color(0xFF5E5346),
        volt: const Color(0xFFFFA62B),
        voltStrong: const Color(0xFFFFA62B),
        voltText: const Color(0xFFFFBC5C),
        voltFocus: const Color(0xFFFFA62B),
        voltSoft: const Color(0x1FFFA62B),
        onVolt: const Color(0xFF14100C),
        ember: const Color(0xFFFF6B3D),
        emberText: const Color(0xFFFF8F66),
        emberSoft: const Color(0x1FFF6B3D),
        oxygen: const Color(0xFF6EE7FF),
        oxygenText: const Color(0xFF6EE7FF),
        oxygenSoft: const Color(0x1F6EE7FF),
        caution: const Color(0xFFD6B24A),
        cautionText: const Color(0xFFE4C46A),
        danger: const Color(0xFFFF5C5C),
        dangerText: const Color(0xFFFF7A7A),
        dangerSoft: const Color(0x1AFF5C5C),
        navBar: const Color(0xF217130F),
        brightness: Brightness.dark,
      );

  /// Hearth Day — Premium. Warm linen ground, amber primary.
  const LpColors.hearthDay()
    : this(
        background: const Color(0xFFFBF6EE),
        panicBackground: const Color(0xFFF5EDE2),
        surface: const Color(0xFFFFFFFF),
        surfaceSubtle: const Color(0xFFF4EDE2),
        surfaceInset: const Color(0xFFFBF6EE),
        border: const Color(0xFFE8DFD0),
        borderSubtle: const Color(0xFFEFE7DA),
        textPrimary: const Color(0xFF211B14),
        textBody: const Color(0xFF453A2D),
        textSecondary: const Color(0xFF786A58),
        textFaint: const Color(0xFFB3A794),
        volt: const Color(0xFFFFA62B),
        voltStrong: const Color(0xFFC97A00),
        voltText: const Color(0xFFA35F00),
        voltFocus: const Color(0xFFE08C0F),
        voltSoft: const Color(0x1AFFA62B),
        onVolt: const Color(0xFF14100C),
        ember: const Color(0xFFFF6B3D),
        emberText: const Color(0xFFC4441A),
        emberSoft: const Color(0x1FFF6B3D),
        oxygen: const Color(0xFF6EE7FF),
        oxygenText: const Color(0xFF0F7A9E),
        oxygenSoft: const Color(0x1F6EE7FF),
        caution: const Color(0xFFD6B24A),
        cautionText: const Color(0xFF8A6D00),
        danger: const Color(0xFFFF5C5C),
        dangerText: const Color(0xFFC23B3B),
        dangerSoft: const Color(0x1AFF5C5C),
        navBar: const Color(0xF7FFFFFF),
        brightness: Brightness.light,
      );

  /// Deep Tide — Premium. Deep indigo ground, teal-cyan primary.
  ///
  /// [ember] stays the brand orange: against a cold ground it is the
  /// hardest-popping colour the brand owns, and a streak milestone should hit
  /// hardest here. [oxygen] moves to periwinkle instead, so the "calm" family
  /// can never be mistaken for the primary — they would otherwise be two
  /// cyans a shade apart.
  const LpColors.deepTide()
    : this(
        background: const Color(0xFF080F18),
        panicBackground: const Color(0xFF04080E),
        surface: const Color(0xFF101B2A),
        surfaceSubtle: const Color(0xFF0B1420),
        surfaceInset: const Color(0xFF080F18),
        border: const Color(0xFF1C2C42),
        borderSubtle: const Color(0xFF162435),
        textPrimary: const Color(0xFFFFFFFF),
        textBody: const Color(0xFFE4EEF6),
        textSecondary: const Color(0xFF8FA6BE),
        textFaint: const Color(0xFF47586E),
        volt: const Color(0xFF4FD8E8),
        voltStrong: const Color(0xFF4FD8E8),
        voltText: const Color(0xFF6FE6F4),
        voltFocus: const Color(0xFF4FD8E8),
        voltSoft: const Color(0x1F4FD8E8),
        onVolt: const Color(0xFF04121A),
        ember: const Color(0xFFFF8A00),
        emberText: const Color(0xFFFFA23D),
        emberSoft: const Color(0x1FFF8A00),
        oxygen: const Color(0xFF8B9BFF),
        oxygenText: const Color(0xFFA3AFFF),
        oxygenSoft: const Color(0x1F8B9BFF),
        caution: const Color(0xFFE8C547),
        cautionText: const Color(0xFFE8C547),
        danger: const Color(0xFFFF5C5C),
        dangerText: const Color(0xFFFF7A7A),
        dangerSoft: const Color(0x1AFF5C5C),
        navBar: const Color(0xF20B1420),
        brightness: Brightness.dark,
      );

  /// Arctic Tide — Premium. Arctic ground, teal-cyan primary.
  const LpColors.arcticTide()
    : this(
        background: const Color(0xFFF2F7FB),
        panicBackground: const Color(0xFFE6F1F8),
        surface: const Color(0xFFFFFFFF),
        surfaceSubtle: const Color(0xFFEAF1F7),
        surfaceInset: const Color(0xFFF2F7FB),
        border: const Color(0xFFD7E3EE),
        borderSubtle: const Color(0xFFE2EAF2),
        textPrimary: const Color(0xFF101B2A),
        textBody: const Color(0xFF2D3D50),
        textSecondary: const Color(0xFF5E7186),
        textFaint: const Color(0xFFA2B2C2),
        volt: const Color(0xFF4FD8E8),
        voltStrong: const Color(0xFF0E8FA3),
        voltText: const Color(0xFF0A6E7E),
        voltFocus: const Color(0xFF2AAEC2),
        voltSoft: const Color(0x1A4FD8E8),
        onVolt: const Color(0xFF04121A),
        ember: const Color(0xFFFF8A00),
        emberText: const Color(0xFFC25F00),
        emberSoft: const Color(0x1FFF8A00),
        oxygen: const Color(0xFF8B9BFF),
        oxygenText: const Color(0xFF4652C9),
        oxygenSoft: const Color(0x1F8B9BFF),
        caution: const Color(0xFFE8C547),
        cautionText: const Color(0xFF8A6D00),
        danger: const Color(0xFFFF5C5C),
        dangerText: const Color(0xFFC23B3B),
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

  /// The raw primary — CTA fills and glows. Identical across a family's two
  /// modes; different in every family (Volt lime, Hearth amber, Tide teal).
  final Color volt;

  /// The primary with enough contrast to draw strokes/rings on [background].
  final Color voltStrong;

  /// The primary with enough contrast to set text on [background].
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
