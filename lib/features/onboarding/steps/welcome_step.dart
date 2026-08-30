import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/lp_colors.dart';
import '../../../app/theme/lp_typography.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/widgets/lp_buttons.dart';
import '../../../core/widgets/lp_card.dart';
import '../../../core/widgets/lp_misc.dart';
import '../onboarding_view_model.dart';
import 'step_body.dart';

/// A1 — the hook. Dimmed "___" counter teases the diagnosis to come.
class WelcomeStep extends ConsumerWidget {
  const WelcomeStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final l10n = context.l10n;
    final vm = ref.read(onboardingProvider.notifier);
    // A draft found on disk waits for an explicit yes: two auth entry points
    // set an email and then push straight here, so silently adopting an
    // abandoned OTHER account's answers would be a data bug, not a nicety.
    final resumable = ref.watch(
      onboardingProvider.select((s) => s.resumable),
    );
    // Wrapped for the same reason StepBody is: this is the screen the register
    // flow lands on with the keyboard still up.
    return StepScrollView(
      child: Padding(
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
            // A card here used to read "83% finish in under 2 min". That number
            // is in no source, and docs/02 §8 lists any uncited number as
            // banned forever — on screen one of the funnel, of all places.
            // What belongs here instead is a draft they can actually resume.
            if (resumable != null) ...[
              LpCard(
                radius: 14,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.obResumeTitle,
                      style: LpType.emphasis(lp.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.obResumeBody(resumable.answered, resumable.total),
                      style: LpType.body13(lp.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        LpTextButton(
                          l10n.obResumeCta,
                          color: lp.voltText,
                          size: 14,
                          onTap: vm.resumeDraft,
                        ),
                        const SizedBox(width: 18),
                        LpTextButton(
                          l10n.obResumeFresh,
                          size: 14,
                          onTap: vm.discardDraft,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            LpButton(l10n.obWelcomeCta, onTap: vm.next),
            // "Restore purchase" lived here and only showed a snack. There is
            // no billing SDK to restore from (docs/08 B4), so it was claiming
            // to restore purchases that cannot exist. It returns with
            // subscriptions (S1-7), where it is a store requirement.
          ],
        ),
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
