import 'package:flutter/material.dart';

import '../../../app/theme/lp_colors.dart';
import '../../../app/theme/lp_typography.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/widgets/lp_buttons.dart';

/// Over the field while the app was away: the clock is held, a tap picks it
/// up, and "it passed" is still one tap away.
class PausedVeil extends StatelessWidget {
  const PausedVeil({super.key, required this.onResume, required this.onPassed});

  final VoidCallback onResume;
  final VoidCallback onPassed;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onResume,
      child: ColoredBox(
        color: lp.panicBackground.withValues(alpha: 0.72),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(l10n.gamePaused, style: LpType.title(lp.textPrimary)),
            const SizedBox(height: 8),
            Text(l10n.gamePausedTap, style: LpType.body14(lp.textSecondary)),
            const SizedBox(height: 28),
            LpTextButton(l10n.panicItPassed, onTap: onPassed),
          ],
        ),
      ),
    );
  }
}
