import 'package:flutter/material.dart';

import '../../../app/theme/lp_colors.dart';
import '../../../app/theme/lp_typography.dart';
import '../../../core/utils/lp_haptics.dart';
import '../../../core/widgets/press_scale.dart';

/// "How bad is it now?" — ten circles, one tap, optional. The studies rate
/// the craving before and after; this is the after, in their own number.
class IntensityRow extends StatelessWidget {
  const IntensityRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;

  /// 1–10, or null while unanswered.
  final int? value;
  final ValueChanged<int> onChanged;

  static const double _size = 28;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: LpType.caption(lp.textSecondary),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var n = 1; n <= 10; n++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: PressScale(
                  onTap: () {
                    LpHaptics.tick();
                    onChanged(n);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: _size,
                    height: _size,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: value == n ? lp.volt : lp.surfaceInset,
                      border: Border.all(
                        color: value == n ? lp.volt : lp.border,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      '$n',
                      style: LpType.caption11(
                        value == n ? lp.onVolt : lp.textSecondary,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
