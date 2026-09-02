import 'package:flutter/material.dart';

import '../../../app/theme/lp_colors.dart';
import '../../../app/theme/lp_typography.dart';

/// The combo as a huge, faint number behind the field (Piano Tiles 2's
/// trick). Appears from [threshold], pops on every rise, and keeps the last
/// value through the fade rather than snapping to zero.
class GhostCombo extends StatefulWidget {
  const GhostCombo({super.key, required this.combo, this.threshold = 3});

  final int combo;
  final int threshold;

  @override
  State<GhostCombo> createState() => _GhostComboState();
}

class _GhostComboState extends State<GhostCombo> {
  late int _shown = widget.combo;

  @override
  void didUpdateWidget(GhostCombo old) {
    super.didUpdateWidget(old);
    if (widget.combo >= widget.threshold) _shown = widget.combo;
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final visible = widget.combo >= widget.threshold;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: Duration(milliseconds: visible ? 80 : 260),
        child: TweenAnimationBuilder<double>(
          // A new key per rise restarts the pop; explicit begin so the first
          // build animates too.
          key: ValueKey(visible ? widget.combo : -1),
          tween: Tween(begin: visible && !reduced ? 1.16 : 1.0, end: 1.0),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Text(
            '$_shown',
            style: LpType.numberHero(
              lp.voltText.withValues(alpha: 0.16),
              size: 120,
            ),
          ),
        ),
      ),
    );
  }
}
