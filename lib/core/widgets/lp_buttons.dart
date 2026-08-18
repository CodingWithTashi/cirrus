import 'package:flutter/material.dart';

import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_dimens.dart';
import '../../app/theme/lp_typography.dart';
import 'press_scale.dart';

enum LpButtonStyle { volt, oxygen, surface }

/// The signature CTA — Volt fill, Space Grotesk 700, soft glow.
class LpButton extends StatelessWidget {
  const LpButton(
    this.label, {
    super.key,
    this.onTap,
    this.style = LpButtonStyle.volt,
    this.height = LpDimens.ctaHeight,
    this.fontSize = 17,
    this.glow = true,
  });

  final String label;
  final VoidCallback? onTap;
  final LpButtonStyle style;
  final double height;
  final double fontSize;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final (bg, fg, shadows) = switch (style) {
      LpButtonStyle.volt => (lp.volt, lp.onVolt, glow ? lp.voltGlow() : null),
      LpButtonStyle.oxygen => (
        lp.oxygen,
        lp.onVolt,
        glow ? lp.oxygenGlow() : null,
      ),
      LpButtonStyle.surface => (lp.surface, lp.textPrimary, null),
    };
    return PressScale(
      onTap: onTap,
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(LpDimens.rButton),
          border: style == LpButtonStyle.surface
              ? Border.all(color: lp.border, width: 1.5)
              : null,
          boxShadow: shadows,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: style == LpButtonStyle.surface
              ? LpType.emphasis(fg, size: fontSize - 2)
              : LpType.button(fg, size: fontSize),
        ),
      ),
    );
  }
}

/// Quiet text link ("Maybe later", "Continue with Free plan →").
class LpTextButton extends StatelessWidget {
  const LpTextButton(
    this.label, {
    super.key,
    this.onTap,
    this.color,
    this.size = 13,
  });

  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return PressScale(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: LpType.body13(
            color ?? lp.textSecondary,
            weight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
