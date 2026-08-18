import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/lp_colors.dart';
import '../../../app/theme/lp_dimens.dart';
import '../../../app/theme/lp_typography.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/utils/lp_format.dart';
import '../../../core/utils/lp_haptics.dart';
import '../../../core/widgets/lp_buttons.dart';
import '../../../core/widgets/lp_card.dart';
import '../../../core/widgets/lp_selectables.dart';
import '../../../core/widgets/numeric_keypad.dart';
import '../../../core/widgets/press_scale.dart';
import '../../../core/widgets/rolling_number.dart';
import '../../../domain/logic/dependence_engine.dart';
import '../../../domain/models/models.dart';
import '../onboarding_view_model.dart';
import 'step_body.dart';

/// B1 — frequency, blunt-friendly copy.
class FrequencyStep extends ConsumerWidget {
  const FrequencyStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(onboardingProvider);
    final vm = ref.read(onboardingProvider.notifier);

    Widget option(VapeFrequency f, String big, String sub) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: OptionCard(
        selected: state.frequency == f,
        onTap: () => vm.selectFrequency(f),
        title: big,
        subtitle: sub,
      ),
    );

    return StepBody(
      title: l10n.obFrequencyTitle,
      subtitle: l10n.obFrequencySubtitle,
      children: [
        option(VapeFrequency.daily, l10n.obFreqDaily, l10n.obFreqDailySub),
        option(VapeFrequency.often, l10n.obFreqOften, l10n.obFreqOftenSub),
        option(VapeFrequency.always, l10n.obFreqAlways, l10n.obFreqAlwaysSub),
        const Spacer(),
        LpButton(
          l10n.commonContinue,
          onTap: state.canContinue ? vm.next : null,
        ),
      ],
    );
  }
}

/// B2 — the signature dopamine screen: live badge morphs with the number.
class PuffsStep extends ConsumerWidget {
  const PuffsStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final l10n = context.l10n;
    final state = ref.watch(onboardingProvider);
    final vm = ref.read(onboardingProvider.notifier);
    final puffs = state.puffsPerDay;

    // Frame 7 / docs/02 B2: crossing into Severe lands with a soft haptic thud.
    ref.listen(onboardingProvider.select((s) => s.dependence), (prev, next) {
      if (next == DependenceLevel.severe && prev != DependenceLevel.severe) {
        LpHaptics.medium();
      }
    });

    final (badgeColor, badgeLabel) = switch (state.dependence) {
      DependenceLevel.light => (lp.voltStrong, l10n.obPuffsBadgeLight),
      DependenceLevel.moderate => (lp.caution, l10n.obPuffsBadgeModerate),
      DependenceLevel.heavy => (lp.ember, l10n.obPuffsBadgeHeavy),
      DependenceLevel.severe => (lp.danger, l10n.obPuffsBadgeSevere),
    };

    return StepBody(
      title: l10n.obPuffsTitle,
      children: [
        Center(
          child: RollingNumber(
            puffs,
            duration: LpMotion.normal,
            style: LpType.numberHero(lp.voltText, size: 96).copyWith(
              shadows: [
                Shadow(color: lp.volt.withValues(alpha: 0.45), blurRadius: 44),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: LpMotion.fast,
          child: puffs == 0
              ? const SizedBox(height: 34)
              : Center(
                  key: ValueKey(state.dependence),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(LpDimens.rChip),
                      border: Border.all(
                        color: badgeColor.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: badgeColor,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          badgeLabel,
                          style: LpType.body13(
                            state.dependence == DependenceLevel.moderate
                                ? lp.cautionText
                                : badgeColor,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            puffs == 0
                ? ' '
                : l10n.obPuffsCigEquiv(
                    DependenceEngine.cigaretteEquivalent(puffs),
                  ),
            style: LpType.body14(lp.textSecondary),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: PressScale(
            onTap: () => _showEstimator(context, ref),
            child: Text(
              l10n.obPuffsNotSure,
              style: LpType.body13(lp.voltText, weight: FontWeight.w600),
            ),
          ),
        ),
        const Spacer(),
        NumericKeypad(
          onDigit: vm.typePuffDigit,
          onBackspace: vm.backspacePuffs,
        ),
        const SizedBox(height: 14),
        LpButton(
          l10n.commonContinue,
          onTap: state.canContinue ? vm.next : null,
        ),
      ],
    );
  }

  void _showEstimator(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        var devices = 2.0;
        return StatefulBuilder(
          builder: (context, setState) {
            final lp = context.lp;
            final estimate = DependenceEngine.puffsPerDayFromDevices(devices);
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.obPuffsHelperTitle,
                    style: LpType.titleSm(lp.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.obPuffsHelperBody,
                    style: LpType.body14(lp.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      l10n.obPuffsHelperDevicesPerWeek(devices),
                      style: LpType.heading(lp.voltText, size: 18),
                    ),
                  ),
                  Slider(
                    value: devices,
                    min: 0.5,
                    max: 7,
                    divisions: 13,
                    onChanged: (v) {
                      LpHaptics.tick();
                      setState(() => devices = v);
                    },
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      l10n.obPuffsHelperResult(estimate),
                      textAlign: TextAlign.center,
                      style: LpType.body13(lp.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 18),
                  LpButton(
                    l10n.commonDone,
                    onTap: () {
                      ref
                          .read(onboardingProvider.notifier)
                          .setPuffsEstimate(estimate);
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// B3 — nicotine strength 2×2.
class StrengthStep extends ConsumerWidget {
  const StrengthStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final l10n = context.l10n;
    final state = ref.watch(onboardingProvider);
    final vm = ref.read(onboardingProvider.notifier);

    Widget cell(NicStrength s, String big, String sub, {String? unit}) {
      final selected = state.strength == s;
      return OptionCard(
        selected: selected,
        onTap: () => vm.selectStrength(s),
        title: big,
        trailingCheck: false,
        child: Column(
          children: [
            Text.rich(
              TextSpan(
                text: big,
                style: LpType.number(
                  selected ? lp.voltText : lp.textPrimary,
                  size: unit == null ? 22 : 26,
                ),
                children: unit == null
                    ? null
                    : [
                        TextSpan(
                          text: unit,
                          style: LpType.body15(
                            lp.textSecondary,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ],
              ),
            ),
            const SizedBox(height: 4),
            Text(sub, style: LpType.caption(lp.textSecondary)),
          ],
        ),
      );
    }

    return StepBody(
      title: l10n.obStrengthTitle,
      children: [
        Row(
          children: [
            Expanded(
              child: cell(
                NicStrength.mg20,
                '20',
                l10n.obStrength20Sub,
                unit: 'mg',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: cell(
                NicStrength.mg35,
                '35',
                l10n.obStrength35Sub,
                unit: 'mg',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: cell(
                NicStrength.mg50,
                '50',
                l10n.obStrength50Sub,
                unit: 'mg',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: cell(
                NicStrength.notSure,
                l10n.obStrengthNotSure,
                l10n.obStrengthNotSureSub,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        LpNoteCard(l10n.obStrengthNote),
        const Spacer(),
        LpButton(
          l10n.commonContinue,
          onTap: state.canContinue ? vm.next : null,
        ),
      ],
    );
  }
}

/// B4 — weekly spend with the rolling yearly shock counter.
class SpendStep extends ConsumerWidget {
  const SpendStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final l10n = context.l10n;
    final locale = context.localeTag;
    final state = ref.watch(onboardingProvider);
    final vm = ref.read(onboardingProvider.notifier);
    final weekly = state.weeklySpend;

    final kicker = weekly <= 0
        ? ''
        : state.yearlySpend < 800
        ? l10n.obSpendKickerSmall
        : state.yearlySpend < 2600
        ? l10n.obSpendKickerMid
        : l10n.obSpendKickerBig;

    return StepBody(
      title: l10n.obSpendTitle,
      children: [
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                LpFormat.money(weekly, locale),
                style: LpType.numberHero(lp.textPrimary, size: 72),
              ),
              const SizedBox(width: 6),
              const BlinkingCaret(height: 52),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            l10n.obSpendPerWeek,
            style: LpType.body14(lp.textSecondary),
          ),
        ),
        const SizedBox(height: 20),
        AnimatedOpacity(
          duration: LpMotion.fast,
          opacity: weekly > 0 ? 1 : 0,
          child: LpCard(
            padding: const EdgeInsets.all(20),
            radius: LpDimens.rCard,
            child: Column(
              children: [
                Text(l10n.obSpendThats, style: LpType.body13(lp.textSecondary)),
                const SizedBox(height: 6),
                RollingNumber(
                  state.yearlySpend,
                  hapticOnLand: true,
                  format: (v) => l10n.obSpendPerYear(LpFormat.money(v, locale)),
                  style: LpType.number(lp.voltText, size: 40).copyWith(
                    shadows: [
                      Shadow(
                        color: lp.volt.withValues(alpha: 0.4),
                        blurRadius: 36,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  kicker,
                  style: LpType.body14(lp.textPrimary, weight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (weekly > 0)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(
                context,
                l10n.obSpendPerMonthChip(
                  LpFormat.money(weekly * 52 / 12, locale),
                ),
              ),
              _chip(
                context,
                l10n.obSpendPerDayChip(
                  LpFormat.money(weekly / 7, locale, cents: true),
                ),
              ),
              _chip(context, l10n.obSpendYourMath),
            ],
          ),
        const Spacer(),
        NumericKeypad(
          onDigit: vm.typeSpendDigit,
          onBackspace: vm.backspaceSpend,
        ),
        const SizedBox(height: 14),
        LpButton(
          l10n.commonContinue,
          onTap: state.canContinue ? vm.next : null,
        ),
      ],
    );
  }

  Widget _chip(BuildContext context, String label) {
    final lp = context.lp;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: lp.surface,
        borderRadius: BorderRadius.circular(LpDimens.rChip),
        border: Border.all(color: lp.border, width: 1.5),
      ),
      child: Text(label, style: LpType.caption(lp.textSecondary)),
    );
  }
}

/// B5 — the Fagerström science question.
class FirstPuffStep extends ConsumerWidget {
  const FirstPuffStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final l10n = context.l10n;
    final state = ref.watch(onboardingProvider);
    final vm = ref.read(onboardingProvider.notifier);

    Widget option(FirstPuffWindow w, String label) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: OptionCard(
        selected: state.firstPuff == w,
        onTap: () => vm.selectFirstPuff(w),
        title: label,
      ),
    );

    return StepBody(
      title: l10n.obFirstPuffTitle,
      children: [
        option(FirstPuffWindow.withinFive, l10n.obFirstPuffWithin5),
        option(FirstPuffWindow.fiveToThirty, l10n.obFirstPuff5to30),
        option(FirstPuffWindow.thirtyToSixty, l10n.obFirstPuff30to60),
        option(FirstPuffWindow.hourPlus, l10n.obFirstPuffHourPlus),
        const SizedBox(height: 6),
        LpCard(
          radius: LpDimens.rInput,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.obFirstPuffScienceLabel,
                style: LpType.caption11(
                  lp.voltText,
                  weight: FontWeight.w600,
                ).copyWith(letterSpacing: 0.5),
              ),
              const SizedBox(height: 5),
              Text(
                l10n.obFirstPuffScience,
                style: LpType.body13(lp.textSecondary),
              ),
            ],
          ),
        ),
        const Spacer(),
        LpButton(
          l10n.commonContinue,
          onTap: state.canContinue ? vm.next : null,
        ),
      ],
    );
  }
}
