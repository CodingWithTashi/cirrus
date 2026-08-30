import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_dimens.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/widgets/lp_misc.dart';
import 'onboarding_view_model.dart';
import 'steps/coach_name_step.dart';
import 'steps/habit_steps.dart';
import 'steps/identity_steps.dart';
import 'steps/payoff_steps.dart';
import 'steps/plan_steps.dart';
import 'steps/welcome_step.dart';

/// The 19-screen first-session flow (docs/02). One question per screen,
/// progress always visible, back always works, every tap reacts.
class OnboardingFlow extends ConsumerWidget {
  const OnboardingFlow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final vm = ref.read(onboardingProvider.notifier);
    final lp = context.lp;

    final showHeader = state.progress != null;

    final step = switch (state.step) {
      ObStep.welcome => const WelcomeStep(),
      ObStep.gender => const GenderStep(),
      ObStep.birthYear => const BirthYearStep(),
      ObStep.under18 => const Under18Step(),
      ObStep.tried => const TriedStep(),
      ObStep.frequency => const FrequencyStep(),
      ObStep.puffs => const PuffsStep(),
      ObStep.strength => const StrengthStep(),
      ObStep.spend => const SpendStep(),
      ObStep.firstPuff => const FirstPuffStep(),
      ObStep.why => const WhyStep(),
      ObStep.worries => const WorriesStep(),
      ObStep.method => const MethodStep(),
      ObStep.pace => const PaceStep(),
      ObStep.building => const BuildingStep(),
      ObStep.reveal => const RevealStep(),
      ObStep.coachName => const CoachNameStep(),
      ObStep.commit => const CommitStep(),
      ObStep.rating => const RatingStep(),
      ObStep.notifications => const NotificationsStep(),
    };

    // Backing out of the first step leaves the funnel: pop back to the
    // pusher (Frame Map preview) when there is one, else return to auth.
    void exitFlow() {
      final nav = Navigator.of(context);
      nav.canPop() ? nav.pop() : context.go('/auth');
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (!vm.back()) exitFlow();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              if (showHeader)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 20, 8),
                  child: Row(
                    children: [
                      BackChevron(
                        onTap: () {
                          if (!vm.back()) exitFlow();
                        },
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: GlowProgressBar(
                          value: state.progress!.$1 / state.progress!.$2,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        context.l10n.obProgressOf(
                          state.progress!.$1,
                          state.progress!.$2,
                        ),
                        style: LpType.displaySmall(lp.textSecondary),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: LpMotion.normal,
                  switchInCurve: LpMotion.ease,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0.06, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(key: ValueKey(state.step), child: step),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
