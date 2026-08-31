import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_dimens.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/utils/lp_format.dart';
import '../../core/utils/lp_haptics.dart';
import '../../core/widgets/lp_buttons.dart';
import '../../core/widgets/lp_card.dart';
import '../../core/widgets/lp_misc.dart';
import '../../core/widgets/lp_selectables.dart';
import '../../core/widgets/press_scale.dart';
import '../../data/stores/day1_tour_store.dart';
import '../../data/stores/providers.dart';

/// Frame 24 — Day-1 checklist: three setup moves, CTA always points at the
/// next unchecked item.
///
/// **A row navigates. That is all a row does.** Every one of them used to mark
/// itself done the moment it was tapped — the first by logging a puff on the
/// user's behalf, the other two before a word had been said to the coach or a
/// single hour set. Three checkmarks claiming work nobody had done, and the
/// user never saw the controls the app is actually made of.
///
/// What ticks a box now is the real move, made on the real screen, with the
/// walkthrough holding everything else closed until it happens. See
/// [Day1TourStore].
class Day1Screen extends ConsumerWidget {
  const Day1Screen({super.key});

  /// Opens the walkthrough at [step] and sends them to the screen it lives on.
  ///
  /// The step is passed through: the rows are tappable in any order, and the
  /// spotlight must light up on the screen the user chose to go to — deriving
  /// "first undone" here once sent someone to the coach with the Home
  /// spotlight active and nothing on their screen explaining anything.
  static void _begin(WidgetRef ref, BuildContext context, Day1TourStep step) {
    ref.read(day1TourProvider.notifier).start(step);
    context.go(switch (step) {
      Day1TourStep.logPuff => Routes.home,
      Day1TourStep.meetCoach => Routes.coach,
      // The Stats heatmap, not Settings: it opens the same sheet, it is a
      // shell tab rather than a route push out of the tour, and it is a
      // full-width target instead of a row buried in a scrolling list.
      Day1TourStep.dangerHours => Routes.stats,
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final l10n = context.l10n;
    final locale = context.localeTag;
    final journey = ref.watch(quitStoreProvider);
    final snap = ref.watch(todayProvider);
    if (journey == null || snap == null) return const SizedBox.shrink();
    final done = journey.day1TasksDone;

    Widget task({
      required int index,
      required String title,
      required String sub,
      String? doneSub,
      VoidCallback? onTap,
    }) {
      final isDone = done.contains(index);
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: PressScale(
          onTap: isDone ? null : onTap,
          child: AnimatedOpacity(
            duration: LpMotion.fast,
            opacity: isDone ? 0.75 : 1,
            child: LpCard(
              borderColor: isDone ? lp.volt.withValues(alpha: 0.5) : lp.border,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
              child: Row(
                children: [
                  SelectCheck(selected: isDone),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style:
                              LpType.emphasis(
                                isDone ? lp.textSecondary : lp.textPrimary,
                                size: 15,
                              ).copyWith(
                                decoration: isDone
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isDone ? (doneSub ?? sub) : sub,
                          style: LpType.caption(lp.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (!isDone)
                    Icon(Icons.chevron_right_rounded, color: lp.textSecondary),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final nextTask = [
      0,
      1,
      2,
    ].firstWhere((i) => !done.contains(i), orElse: () => -1);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Scrolls, so adding a row or a line of copy can never push the
              // CTA off the bottom of a small screen. A bare Column here
              // overflowed the moment the skip link was added — the same
              // failure the auth forms and the onboarding steps already carry
              // a scroll view to prevent.
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              l10n.day1Title,
                              style: LpType.title(lp.textPrimary),
                            ),
                          ),
                          StreakChip(days: snap.streak > 0 ? snap.streak : 1),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.day1Subtitle,
                        style: LpType.body14(lp.textSecondary),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: GlowProgressBar(
                              value: done.length / 3,
                              height: 6,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${done.length}/3',
                            style: LpType.displaySmall(lp.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      task(
                        index: 0,
                        title: l10n.day1Task1,
                        doneSub: l10n.day1Task1Done,
                        sub: l10n.day1Task1Sub,
                        onTap: () => _begin(ref, context, Day1TourStep.logPuff),
                      ),
                      task(
                        index: 1,
                        title: l10n.day1Task2,
                        sub: l10n.day1Task2Sub,
                        onTap: () =>
                            _begin(ref, context, Day1TourStep.meetCoach),
                      ),
                      task(
                        index: 2,
                        title: l10n.day1Task3,
                        sub: l10n.day1Task3Sub,
                        onTap: () =>
                            _begin(ref, context, Day1TourStep.dangerHours),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // A real escape hatch, offered until the last box ticks. It
              // ticks NOTHING — the three moves stay undone, stay listed and
              // stay available. A forced flow with no way out is a churn risk
              // and a store-review risk, and ticking boxes on the way out
              // would put back the exact lie this screen just stopped
              // telling. It used to vanish after the first tick, which left
              // an offline user with a coach step they could not finish and
              // no exit of any kind.
              if (done.length < 3 && !journey.day1TourSkipped) ...[
                Center(
                  child: LpTextButton(
                    l10n.day1Skip,
                    onTap: () {
                      ref.read(day1TourProvider.notifier).skip();
                      context.go(Routes.home);
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
              LpNoteCard(
                l10n.day1FreedomNote(
                  LpFormat.shortDate(snap.freedomDate, locale),
                  snap.daysToFreedom,
                ),
              ),
              const SizedBox(height: 14),
              // Frame 24: the CTA always points at the next unchecked item.
              LpButton(
                switch (nextTask) {
                  0 => l10n.day1Task1,
                  1 => l10n.day1CtaCoach,
                  2 => l10n.day1Task3,
                  _ => l10n.day1CtaHome,
                },
                onTap: () {
                  if (nextTask == -1) {
                    // All three done. The gate is already open; hand over.
                    context.go(Routes.home);
                    return;
                  }
                  LpHaptics.medium();
                  _begin(ref, context, Day1TourStep.values[nextTask]);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
