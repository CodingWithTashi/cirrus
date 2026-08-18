import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/lp_colors.dart';
import '../../../app/theme/lp_typography.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/widgets/lp_buttons.dart';
import '../../../core/widgets/lp_card.dart';
import '../../../core/widgets/lp_misc.dart';
import '../onboarding_view_model.dart';

/// A1 — the hook. Dimmed "___" counter teases the diagnosis to come.
class WelcomeStep extends ConsumerWidget {
  const WelcomeStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: Wordmark(fontSize: 20)),
          const SizedBox(height: 34),
          Center(
            child: _ShimmerTease(
              child: Text(
                '___',
                style: TextStyle(
                  fontFamily: LpType.display,
                  fontWeight: FontWeight.w700,
                  fontSize: 88,
                  height: 1,
                  letterSpacing: -2,
                  color: lp.border,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              l10n.obWelcomeCounterHint,
              style: LpType.body15(lp.textSecondary),
            ),
          ),
          const SizedBox(height: 26),
          Text(
            l10n.obWelcomeTitle,
            textAlign: TextAlign.center,
            style: LpType.title(lp.textPrimary, size: 34),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.obWelcomeSubtitle,
            textAlign: TextAlign.center,
            style: LpType.body15(lp.textSecondary),
          ),
          const Spacer(),
          LpCard(
            radius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.obWelcomeFactLabel,
                  style: LpType.body13(lp.textSecondary),
                ),
                Text(
                  l10n.obWelcomeFactValue,
                  style: LpType.body13(lp.textPrimary, weight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          LpButton(
            l10n.obWelcomeCta,
            onTap: () => ref.read(onboardingProvider.notifier).next(),
          ),
          const SizedBox(height: 4),
          LpTextButton(
            l10n.authRestorePurchase,
            size: 12,
            onTap: () => showLpSnack(context, l10n.settingsRestored),
          ),
        ],
      ),
    );
  }
}

/// Frame 1 note: "dimmed counter flickers a slow shimmer (tease, no roll yet)".
class _ShimmerTease extends StatefulWidget {
  const _ShimmerTease({required this.child});

  final Widget child;

  @override
  State<_ShimmerTease> createState() => _ShimmerTeaseState();
}

class _ShimmerTeaseState extends State<_ShimmerTease>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MediaQuery.disableAnimationsOf(context)
        ? _controller.stop()
        : _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(
        begin: 0.55,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeInOut)).animate(_controller),
      child: widget.child,
    );
  }
}
