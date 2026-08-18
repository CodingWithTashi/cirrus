import 'package:flutter/material.dart';

import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_dimens.dart';
import '../../app/theme/lp_typography.dart';

/// Surface card with the 1.5px border language of the design system.
class LpCard extends StatelessWidget {
  const LpCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(LpDimens.lg),
    this.radius = LpDimens.rCard,
    this.borderColor,
    this.color,
    this.glowColor,
    this.subtle = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? borderColor;
  final Color? color;

  /// Soft outer glow (accented cards: streak, offers, SOS).
  final Color? glowColor;

  /// Uses the subdued surface (inline notes, footers).
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? (subtle ? lp.surfaceSubtle : lp.surface),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? lp.border, width: 1.5),
        boxShadow: glowColor == null
            ? null
            : [
                BoxShadow(
                  color: glowColor!.withValues(alpha: 0.10),
                  blurRadius: 22,
                ),
              ],
      ),
      child: child,
    );
  }
}

/// ALL-CAPS section label ("YOUR WHY", "COMING UP").
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.color, this.padding});

  final String text;
  final Color? color;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return Padding(
      padding: padding ?? const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: LpType.label(color ?? lp.textSecondary),
      ),
    );
  }
}

/// Inline info footer ("No spam…", privacy notes) — subtle, persistent.
class LpNoteCard extends StatelessWidget {
  const LpNoteCard(this.text, {super.key, this.leading});

  final String text;
  final String? leading;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return LpCard(
      subtle: true,
      radius: LpDimens.rInput,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          if (leading != null) ...[
            Text(leading!, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
          ],
          Expanded(child: Text(text, style: LpType.body13(lp.textSecondary))),
        ],
      ),
    );
  }
}

/// Emoji avatar inside a tinted ring (community identity).
class EmojiAvatar extends StatelessWidget {
  const EmojiAvatar(this.emoji, {super.key, this.size = 34, this.tint});

  final String emoji;
  final double size;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final base = tint ?? lp.volt;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: base.withValues(alpha: 0.15),
        border: Border.all(color: base.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Text(emoji, style: TextStyle(fontSize: size * 0.44)),
    );
  }
}
