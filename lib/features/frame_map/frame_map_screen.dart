import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_dimens.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/widgets/lp_card.dart';
import '../../core/widgets/lp_error.dart';
import '../../core/widgets/lp_misc.dart';
import '../../core/widgets/lp_states.dart';
import '../../core/widgets/press_scale.dart';
import '../../data/stores/providers.dart';
import '../onboarding/onboarding_view_model.dart';
import '../panic/panic_screens.dart';

/// The whole handoff, tappable: all 52 design frames grouped by run, each
/// row jumping straight to that screen (seeding the demo journey or quiz
/// answers as needed). Reached from the sign-in screen and Settings.
class FrameMapScreen extends ConsumerWidget {
  const FrameMapScreen({super.key});

  /// App screens need the demo journey; onboarding previews must run
  /// signed-out so the router doesn't bounce them.
  void _withJourney(
    WidgetRef ref,
    BuildContext context,
    String route, {
    bool go = false,
  }) {
    if (ref.read(quitStoreProvider) == null) {
      ref.read(quitStoreProvider.notifier).seedDemoJourney();
    }
    go ? context.go(route) : context.push(route);
  }

  void _onboarding(WidgetRef ref, BuildContext context, ObStep step) {
    ref.read(onboardingProvider.notifier).previewStep(step);
    context.push(Routes.onboarding);
  }

  void _panic(WidgetRef ref, BuildContext context, int step) {
    if (ref.read(quitStoreProvider) == null) {
      ref.read(quitStoreProvider.notifier).seedDemoJourney();
    }
    ref.read(panicProvider.notifier).previewStep(step);
    context.push(Routes.panic);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final l10n = context.l10n;

    List<(int, String, void Function())> run1() => [
      (1, 'A1 · Welcome', () => _onboarding(ref, context, ObStep.welcome)),
      (2, 'A2 · Gender', () => _onboarding(ref, context, ObStep.gender)),
      (3, 'A3 · Birth year', () => _onboarding(ref, context, ObStep.birthYear)),
      (
        4,
        'A3b · Under-18 gate',
        () => _onboarding(ref, context, ObStep.under18),
      ),
      (5, 'A4 · Tried before?', () => _onboarding(ref, context, ObStep.tried)),
      (6, 'B1 · Frequency', () => _onboarding(ref, context, ObStep.frequency)),
      (7, 'B2 · Puffs per day', () => _onboarding(ref, context, ObStep.puffs)),
      (
        8,
        'B3 · Nicotine strength',
        () => _onboarding(ref, context, ObStep.strength),
      ),
      (9, 'B4 · Weekly spend', () => _onboarding(ref, context, ObStep.spend)),
      (
        10,
        'B5 · First puff',
        () => _onboarding(ref, context, ObStep.firstPuff),
      ),
      (11, 'C1 · Your why', () => _onboarding(ref, context, ObStep.why)),
      (12, 'C2 · Worries', () => _onboarding(ref, context, ObStep.worries)),
      (13, 'C3 · Method', () => _onboarding(ref, context, ObStep.method)),
      (14, 'C4 · Pace', () => _onboarding(ref, context, ObStep.pace)),
      (
        15,
        'C5 · Building your plan',
        () => _onboarding(ref, context, ObStep.building),
      ),
      (16, 'D1 · Plan reveal', () => _onboarding(ref, context, ObStep.reveal)),
      (
        17,
        'D1b · Name your coach',
        () => _onboarding(ref, context, ObStep.coachName),
      ),
      (
        18,
        'D2 · Hold to commit',
        () => _onboarding(ref, context, ObStep.commit),
      ),
      (19, 'D3 · Rating ask', () => _onboarding(ref, context, ObStep.rating)),
      (
        20,
        'D4 · Notifications',
        () => _onboarding(ref, context, ObStep.notifications),
      ),
      (21, 'D5 · Paywall', () => _withJourney(ref, context, Routes.paywall)),
      (
        22,
        'D5b · Free plan',
        () => _withJourney(ref, context, Routes.paywallFree),
      ),
      (
        23,
        'D5c · Win-back offer',
        () => _withJourney(ref, context, Routes.winback),
      ),
      (
        24,
        'D5d · Trial ending',
        () => _withJourney(ref, context, Routes.trialEnding),
      ),
      (25, 'Day-1 checklist', () => _withJourney(ref, context, Routes.day1)),
    ];

    List<(int, String, void Function())> run2() => [
      (25, 'Splash / welcome', () => context.go(Routes.splash)),
      (26, 'Sign in', () => context.push(Routes.auth)),
      (27, 'Email register', () => context.push(Routes.register)),
      (28, 'Email login', () => context.push(Routes.login)),
      (29, 'Forgot password', () => context.push(Routes.forgot)),
      (
        30,
        'HOME · Today',
        () => _withJourney(ref, context, Routes.home, go: true),
      ),
      (
        31,
        'Log feedback · over-limit',
        () => _withJourney(ref, context, Routes.home, go: true),
      ),
      (32, 'PANIC 1 · Breathe', () => _panic(ref, context, 0)),
      (33, 'PANIC 2 · Your why', () => _panic(ref, context, 1)),
      (34, 'PANIC 3 · Break the loop', () => _panic(ref, context, 2)),
      (
        35,
        'Craving survived 🎉',
        () => _withJourney(ref, context, Routes.survived),
      ),
      (
        36,
        'AI Coach chat',
        () => _withJourney(ref, context, Routes.coach, go: true),
      ),
      (37, 'Plan', () => _withJourney(ref, context, Routes.plan)),
      (38, 'Stats', () => _withJourney(ref, context, Routes.stats, go: true)),
    ];

    List<(int, String, void Function())> run3() => [
      (39, 'Health timeline', () => _withJourney(ref, context, Routes.health)),
      (40, 'Money', () => _withJourney(ref, context, Routes.money)),
      (
        41,
        'Mood check-in',
        () => _withJourney(ref, context, Routes.home, go: true),
      ),
      (
        42,
        'Weekly AI insight',
        () => _withJourney(ref, context, Routes.insight),
      ),
      (
        43,
        'Community feed',
        () => _withJourney(ref, context, Routes.community, go: true),
      ),
      (44, 'Post composer', () => _withJourney(ref, context, Routes.compose)),
      (
        45,
        'SOS post + rally',
        () => _withJourney(ref, context, '/community/post/seed-sos'),
      ),
      (47, 'Milestones', () => _withJourney(ref, context, Routes.milestones)),
      (
        48,
        'Slip recovery (a+b)',
        () => _withJourney(ref, context, Routes.slip),
      ),
      (49, 'Profile', () => _withJourney(ref, context, Routes.profile)),
      (50, 'Settings', () => _withJourney(ref, context, Routes.settings)),
      (
        51,
        'Push set (previews)',
        () => _onboarding(ref, context, ObStep.notifications),
      ),
      (52, 'Widgets + edge states', () => context.push(Routes.framesEdge)),
    ];

    Widget section(
      String label,
      Color accent,
      List<(int, String, void Function())> frames,
    ) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    label,
                    style: LpType.displaySmall(lp.onVolt, size: 12),
                  ),
                ),
              ],
            ),
          ),
          for (final (number, title, go) in frames)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PressScale(
                onTap: go,
                child: LpCard(
                  radius: LpDimens.rInput,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 34,
                        child: Text(
                          '$number',
                          style: LpType.displaySmall(lp.voltText, size: 14),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          title,
                          style: LpType.body14(
                            lp.textPrimary,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: lp.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: BackChevron(
          onTap: () {
            context.canPop() ? context.pop() : context.go(Routes.auth);
          },
        ),
        title: Text(l10n.frameMapTitle),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            LpNoteCard(l10n.frameMapNote),
            section('RUN 1 · 1–24', lp.volt, run1()),
            section('RUN 2 · 25–38', lp.oxygen, run2()),
            section('RUN 3 · 39–52', lp.ember, run3()),
          ],
        ),
      ),
    );
  }
}

/// Frame 52 — the edge-state components, finally on a real surface:
/// offline pill, warm error card, and the first-day empty state.
class EdgeStatesPreviewScreen extends StatelessWidget {
  const EdgeStatesPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        leading: BackChevron(onTap: () => context.pop()),
        title: const Text('Widgets + edge states'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            // The real surfaces, not lookalikes. This screen used to preview
            // `LpOfflineBanner` and `LpErrorCard` — a second, blander copy of
            // the error voice that nothing else in the app rendered, so the
            // design system showed one thing and users saw another.
            const SectionLabel('Error + retry'),
            LpErrorState(
              emoji: '📡',
              title: l10n.errorFeedTitle,
              body: l10n.errorFeedBody,
              retryLabel: l10n.errorRetry,
              onRetry: () {},
            ),
            const SizedBox(height: 20),
            const SectionLabel('Loading'),
            LpLoadingState(label: l10n.communityLoading),
            const SizedBox(height: 20),
            const SectionLabel('Empty'),
            LpEmptyState(
              emoji: '📈',
              title: l10n.statsEmptyTitle,
              body: l10n.statsEmptyBody,
            ),
            const SizedBox(height: 20),
            SectionLabel(l10n.statsTitle),
            LpCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  const Text('📈', style: TextStyle(fontSize: 24)),
                  const SizedBox(height: 8),
                  Text(
                    l10n.statsEmptyTitle,
                    style: LpType.body14(
                      lp.textPrimary,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.statsEmptyBody,
                    textAlign: TextAlign.center,
                    style: LpType.caption(lp.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            LpNoteCard(l10n.frameMapEdgeNote),
          ],
        ),
      ),
    );
  }
}
