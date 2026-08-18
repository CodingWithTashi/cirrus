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
import '../../data/stores/providers.dart';

/// Frame 24 — Day-1 checklist: three setup moves, CTA always points at the
/// next unchecked item.
class Day1Screen extends ConsumerWidget {
  const Day1Screen({super.key});

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
              Text(l10n.day1Subtitle, style: LpType.body14(lp.textSecondary)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GlowProgressBar(value: done.length / 3, height: 6),
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
                onTap: () {
                  ref.read(quitStoreProvider.notifier)
                    ..logPuff()
                    ..completeDay1Task(0);
                },
              ),
              task(
                index: 1,
                title: l10n.day1Task2,
                sub: l10n.day1Task2Sub,
                onTap: () {
                  ref.read(quitStoreProvider.notifier).completeDay1Task(1);
                  context.push(Routes.coach);
                },
              ),
              task(
                index: 2,
                title: l10n.day1Task3,
                sub: l10n.day1Task3Sub,
                onTap: () {
                  ref.read(quitStoreProvider.notifier).completeDay1Task(2);
                  context.push(Routes.settings);
                },
              ),
              const Spacer(),
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
                  switch (nextTask) {
                    case 0:
                      LpHaptics.medium();
                      ref.read(quitStoreProvider.notifier)
                        ..logPuff()
                        ..completeDay1Task(0);
                    case 1:
                      LpHaptics.medium();
                      ref.read(quitStoreProvider.notifier).completeDay1Task(1);
                      context.go(Routes.coach);
                    case 2:
                      LpHaptics.medium();
                      ref.read(quitStoreProvider.notifier).completeDay1Task(2);
                      context.push(Routes.settings);
                    default:
                      context.go(Routes.home);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
