import 'package:flutter/material.dart';

import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_dimens.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/widgets/press_scale.dart';

/// The "Sign in with Apple" CTA — the Apple HIG button, with the same `busy`
/// contract as `LpButton`: taps are inert and the label swaps for a spinner
/// while the sign-in is in flight.
///
/// Lives under `features/auth`, not `core/widgets`, on purpose: it is the one
/// sanctioned exception to "no raw hex in widgets" (Apple ships fixed
/// black-on-light / white-on-dark, not theme tokens), and keeping it here keeps
/// that exception from being reused elsewhere.
class AppleSignInButton extends StatelessWidget {
  const AppleSignInButton(
    this.label, {
    super.key,
    this.onTap,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onTap;

  /// While the awaited sign-in is in flight. Pixel-identical when false.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    // Apple HIG button colors, not theme tokens on purpose:
    // white-on-dark / black-on-light, exactly as Apple ships.
    final bg = lp.isDark ? Colors.white : const Color(0xFF111419);
    final fg = lp.isDark ? Colors.black : const Color(0xFFFDFDFC);
    return PressScale(
      onTap: busy ? null : onTap,
      child: Container(
        height: LpDimens.ctaHeight,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(LpDimens.rButton),
        ),
        child: busy
            ? Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(fg),
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.apple, size: 24, color: fg),
                  const SizedBox(width: 8),
                  Text(label, style: LpType.emphasis(fg, size: 17)),
                ],
              ),
      ),
    );
  }
}
