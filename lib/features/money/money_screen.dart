import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_dimens.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/utils/lp_format.dart';
import '../../core/utils/lp_haptics.dart';
import '../../core/widgets/confetti_burst.dart';
import '../../core/widgets/lp_buttons.dart';
import '../../core/widgets/lp_card.dart';
import '../../core/widgets/lp_misc.dart';
import '../../core/widgets/press_scale.dart';
import '../../core/widgets/rolling_number.dart';
import '../../data/stores/providers.dart';
import '../../domain/logic/money_engine.dart';
import '../../domain/models/models.dart';

/// Frame 40 — Money back: rolling hero, goal bars, "the math is yours".
/// A goal crossing 100% while on screen fires confetti (true milestone).
class MoneyScreen extends ConsumerWidget {
  const MoneyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final l10n = context.l10n;
    final locale = context.localeTag;
    final journey = ref.watch(quitStoreProvider);
    final snap = ref.watch(todayProvider);
    if (journey == null || snap == null) return const SizedBox.shrink();

    // Goals already funded when the screen opens don't re-celebrate; only a
    // goal crossing the line while watching earns the burst.
    final funded = {
      for (final goal in journey.goals)
        if (snap.savedLifetime >= goal.price) goal.id,
    };

    return Scaffold(
      appBar: AppBar(
        leading: BackChevron(onTap: () => context.pop()),
        title: Text(l10n.moneyTitle),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Center(
                  child: RollingNumber(
                    snap.savedLifetime,
                    format: (v) => LpFormat.money(v, locale),
                    style: LpType.numberHero(lp.voltText, size: 84).copyWith(
                      shadows: [
                        Shadow(
                          color: lp.volt.withValues(alpha: 0.45),
                          blurRadius: 48,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    l10n.moneySavedSince(
                      LpFormat.shortDate(journey.plan.startDate, locale),
                      LpFormat.money(
                        snap.savedRunRatePerDay,
                        locale,
                        cents: true,
                      ),
                    ),
                    style: LpType.body13(lp.textSecondary),
                  ),
                ),
                const SizedBox(height: 24),
                SectionLabel(l10n.moneyBuysLabel),
                for (final goal in journey.goals) ...[
                  _GoalCard(
                    goal: goal,
                    saved: snap.savedLifetime,
                    runRate: snap.savedRunRatePerDay,
                    locale: locale,
                  ),
                  const SizedBox(height: 10),
                ],
                PressScale(
                  onTap: () => _showGoalSheet(context, ref),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: lp.surfaceSubtle,
                      borderRadius: BorderRadius.circular(LpDimens.rCard),
                      border: Border.all(color: lp.border, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: lp.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: lp.border, width: 1.5),
                          ),
                          child: Text(
                            '+',
                            style: LpType.heading(lp.voltText, size: 20),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.moneySetGoal,
                              style: LpType.body14(
                                lp.textPrimary,
                                weight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.moneySetGoalSub,
                              style: LpType.caption(lp.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                LpNoteCard(
                  l10n.moneyMathNote(
                    LpFormat.money(journey.plan.weeklySpend, locale),
                    LpFormat.money(journey.plan.weeklySpend * 52, locale),
                  ),
                ),
              ],
            ),
            Positioned.fill(child: NewIdConfetti(ids: funded)),
          ],
        ),
      ),
    );
  }

  void _showGoalSheet(BuildContext context, WidgetRef ref) {
    final name = TextEditingController();
    final price = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final lp = sheetContext.lp;
        final l10n = sheetContext.l10n;
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.moneyGoalSheetTitle,
                style: LpType.titleSm(lp.textPrimary),
              ),
              const SizedBox(height: 16),
              LpField(
                label: l10n.moneySetGoal,
                controller: name,
                hint: l10n.moneyGoalNameHint,
                autofocus: true,
              ),
              const SizedBox(height: 10),
              LpField(
                label: l10n.moneyGoalPriceHint,
                controller: price,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 18),
              LpButton(
                l10n.moneyGoalCreate,
                onTap: () {
                  final p = double.tryParse(price.text) ?? 0;
                  if (name.text.trim().isEmpty || p <= 0) return;
                  LpHaptics.medium();
                  ref
                      .read(quitStoreProvider.notifier)
                      .addGoal(
                        SavingsGoal(
                          id: 'g${DateTime.now().microsecondsSinceEpoch}',
                          emoji: '🎯',
                          name: name.text.trim(),
                          price: p,
                        ),
                      );
                  Navigator.of(sheetContext).pop();
                },
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      name.dispose();
      price.dispose();
    });
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.saved,
    required this.runRate,
    required this.locale,
  });

  final SavingsGoal goal;
  final double saved;
  final double runRate;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    final fraction = (saved / goal.price).clamp(0.0, 1.0);
    final toGo = (goal.price - saved).clamp(0, goal.price);
    final days = MoneyEngine.daysToGoal(goal, saved, runRate);
    final funded = fraction >= 1;

    // Seeded goals resolve through l10n like community seed posts; the raw
    // name is only ever user input.
    final name = switch (goal.id) {
      'g1' => l10n.seedGoalKicks,
      'g2' || 'onboarding-goal' => l10n.seedGoalTokyo,
      _ => goal.name,
    };

    return LpCard(
      padding: const EdgeInsets.all(16),
      borderColor: funded ? lp.volt.withValues(alpha: 0.5) : lp.border,
      glowColor: funded ? lp.volt : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${goal.emoji} $name',
                style: LpType.body14(lp.textPrimary, weight: FontWeight.w600),
              ),
              Text(
                '${(fraction * 100).round()}%',
                style: LpType.caption(
                  fraction > 0.5 ? lp.voltText : lp.textSecondary,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          // Frame 40: goal bars fill with spring ease.
          GlowProgressBar(value: fraction, height: 8, curve: LpMotion.spring),
          const SizedBox(height: 7),
          Text(
            funded
                ? l10n.moneyGoalDone
                : goal.fromOnboarding
                ? l10n.moneyFromOnboarding(LpFormat.money(toGo, locale))
                : days == null
                ? l10n.moneyToGoShort(LpFormat.money(toGo, locale))
                : l10n.moneyToGo(LpFormat.money(toGo, locale), days),
            style: LpType.caption11(lp.textSecondary),
          ),
        ],
      ),
    );
  }
}
