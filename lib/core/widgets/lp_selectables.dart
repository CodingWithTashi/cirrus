import 'package:flutter/material.dart';

import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_dimens.dart';
import '../../app/theme/lp_typography.dart';
import 'press_scale.dart';

/// Check circle used across option cards.
class SelectCheck extends StatelessWidget {
  const SelectCheck({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return AnimatedContainer(
      duration: LpMotion.fast,
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? lp.volt : Colors.transparent,
        border: selected ? null : Border.all(color: lp.border, width: 1.5),
      ),
      child: selected
          ? Text(
              '✓',
              style: TextStyle(
                color: lp.onVolt,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
    );
  }
}

/// Full-width selectable option card (gender, first-puff, frequency…).
/// Selected: Volt border + soft glow, 150ms fade (Run 1 notes).
class OptionCard extends StatelessWidget {
  const OptionCard({
    super.key,
    required this.selected,
    required this.onTap,
    required this.title,
    this.subtitle,
    this.titleColorSelected = true,
    this.trailingCheck = true,
    this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final String title;
  final String? subtitle;
  final bool titleColorSelected;
  final bool trailingCheck;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return PressScale(
      onTap: onTap,
      child: AnimatedContainer(
        // Frame 2 note: Volt border fades in over 150ms.
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(LpDimens.optionCardPad),
        decoration: BoxDecoration(
          color: lp.surface,
          borderRadius: BorderRadius.circular(LpDimens.rCard),
          border: Border.all(
            color: selected ? lp.voltFocus : lp.border,
            width: 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: lp.volt.withValues(alpha: 0.15),
                    blurRadius: 20,
                  ),
                ]
              : null,
        ),
        child:
            child ??
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: LpType.emphasis(
                          selected && titleColorSelected
                              ? lp.voltText
                              : lp.textPrimary,
                          size: 16,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 5),
                        Text(subtitle!, style: LpType.body13(lp.textSecondary)),
                      ],
                    ],
                  ),
                ),
                if (trailingCheck) SelectCheck(selected: selected),
              ],
            ),
      ),
    );
  }
}

/// Selectable pill chip (whys, worries, tags, paces).
class LpChip extends StatelessWidget {
  const LpChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedColor,
    this.fontSize = 15,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Accent family when selected (defaults to Volt).
  final Color? selectedColor;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final accent = selectedColor ?? lp.volt;
    // Every accent family pairs with its on-background text token — raw
    // Ember/Oxygen fail contrast on the Daylight ground.
    final accentText = accent == lp.ember
        ? lp.emberText
        : accent == lp.oxygen
        ? lp.oxygenText
        : lp.voltText;
    return PressScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: LpMotion.fast,
        padding: padding,
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.12) : lp.surface,
          borderRadius: BorderRadius.circular(LpDimens.rChip),
          border: Border.all(
            color: selected ? accent.withValues(alpha: 0.6) : lp.border,
            width: 1.5,
          ),
        ),
        child: Text(
          selected ? '$label ✓' : label,
          style: TextStyle(
            fontFamily: LpType.body,
            fontWeight: FontWeight.w600,
            fontSize: fontSize,
            color: selected ? accentText : lp.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// Static (non-selectable) tag pill, e.g. "Health" chips on the Why card.
class StaticChip extends StatelessWidget {
  const StaticChip(this.label, {super.key, this.color, this.small = false});

  final String label;
  final Color? color;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final accentBorder = color ?? lp.voltFocus;
    final accentText = color == null ? lp.voltText : accentBorder;
    return Container(
      padding: small
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
          : const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: lp.surfaceInset,
        borderRadius: BorderRadius.circular(LpDimens.rChip),
        border: Border.all(color: accentBorder, width: 1.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: LpType.body,
          fontWeight: FontWeight.w600,
          fontSize: small ? 12 : 13,
          color: accentText,
        ),
      ),
    );
  }
}

/// Segmented pill control (Stats: Day / Week / Month).
class SegmentedPills extends StatelessWidget {
  const SegmentedPills({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: lp.surface,
        borderRadius: BorderRadius.circular(LpDimens.rChip),
        border: Border.all(color: lp.border, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++)
            PressScale(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: LpMotion.fast,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: i == selectedIndex ? lp.volt : Colors.transparent,
                  borderRadius: BorderRadius.circular(LpDimens.rChip),
                ),
                child: Text(
                  labels[i],
                  style: LpType.caption(
                    i == selectedIndex ? lp.onVolt : lp.textSecondary,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
