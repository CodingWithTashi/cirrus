import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/lp_colors.dart';
import '../../../app/theme/lp_dimens.dart';
import '../../../app/theme/lp_typography.dart';
import '../../../core/utils/enum_labels.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/utils/lp_format.dart';
import '../../../core/utils/lp_haptics.dart';
import '../../../core/widgets/lp_buttons.dart';
import '../../../core/widgets/lp_card.dart';
import '../../../core/widgets/lp_charts.dart';
import '../../../core/widgets/lp_selectables.dart';
import '../../../core/widgets/press_scale.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../domain/logic/taper_engine.dart';
import '../../../domain/models/models.dart';
import '../onboarding_view_model.dart';
import '../tailoring.dart';
import 'step_fact.dart';
import 'step_body.dart';

/// C1 — whys stack into a visible "Your Why" card (IKEA effect).
class WhyStep extends ConsumerWidget {
  const WhyStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final l10n = context.l10n;
    final state = ref.watch(onboardingProvider);
    final vm = ref.read(onboardingProvider.notifier);

    return StepBody(
      title: l10n.obWhyTitle,
      subtitle: l10n.obWhySubtitle,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final chip in WhyChip.values)
              LpChip(
                label: chip.label(context),
                selected: state.whys.contains(chip),
                onTap: () => vm.toggleWhy(chip),
              ),
          ],
        ),
        const Spacer(),
        LpCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionLabel(l10n.obWhyCardLabel),
              state.whys.isEmpty
                  ? Text('—', style: LpType.body14(lp.textFaint))
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // Frame 11: chips land in the card with a pop +
                        // catch-haptic (the IKEA-effect beat).
                        for (final chip in state.whys)
                          _ChipCatch(
                            key: ValueKey(chip),
                            child: StaticChip(chip.label(context), small: true),
                          ),
                      ],
                    ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LpButton(
          l10n.commonContinue,
          onTap: state.canContinue ? vm.next : null,
        ),
      ],
    );
  }
}

/// C2 — worries seed the coach's memory.
class WorriesStep extends ConsumerWidget {
  const WorriesStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final l10n = context.l10n;
    final state = ref.watch(onboardingProvider);
    final vm = ref.read(onboardingProvider.notifier);

    return StepBody(
      title: l10n.obWorriesTitle,
      subtitle: l10n.obWorriesSubtitle,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final chip in WorryChip.values)
              LpChip(
                label: chip.label(context),
                selected: state.worries.contains(chip),
                onTap: () => vm.toggleWorry(chip),
              ),
          ],
        ),
        const Spacer(),
        LpCard(
          radius: LpDimens.rInput,
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AiBadge(),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.obWorriesAiNote,
                  style: LpType.body13(lp.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        StepFact(text: ObTailoring.fact(context, ObStep.worries, state)?.$1),
        const SizedBox(height: 14),
        LpButton(
          l10n.commonContinue,
          onTap: state.canContinue ? vm.next : null,
        ),
      ],
    );
  }
}

/// Pops a newly-caught chip into the Your Why card (scale-in + tick haptic).
/// Keyed per chip so existing chips don't re-pop on rebuild.
class _ChipCatch extends StatefulWidget {
  const _ChipCatch({super.key, required this.child});

  final Widget child;

  @override
  State<_ChipCatch> createState() => _ChipCatchState();
}

class _ChipCatchState extends State<_ChipCatch> {
  @override
  void initState() {
    super.initState();
    // The catch lands just after the flight beat.
    Future<void>.delayed(const Duration(milliseconds: 180), () {
      if (mounted) LpHaptics.tick();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: 1),
      duration: LpMotion.normal,
      curve: LpMotion.spring,
      builder: (context, t, child) => Transform.scale(
        scale: t,
        child: Opacity(opacity: t.clamp(0, 1), child: child),
      ),
      child: widget.child,
    );
  }
}

class _AiBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: lp.oxygenSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: lp.oxygen.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Text('AI', style: LpType.displaySmall(lp.oxygenText, size: 13)),
    );
  }
}

/// C3 — method, with the recommendation computed from B2.
class MethodStep extends ConsumerWidget {
  const MethodStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final l10n = context.l10n;
    final state = ref.watch(onboardingProvider);
    final vm = ref.read(onboardingProvider.notifier);
    final recommendTaper = state.puffsPerDay >= 100;

    return StepBody(
      title: l10n.obMethodTitle,
      subtitle: l10n.obMethodSubtitle,
      children: [
        // Frame 12 note: picking "Fear of failing" earns a gentle coach note
        // here on the next screen — never a warning.
        if (state.worries.contains(WorryChip.failing)) ...[
          LpCard(
            radius: LpDimens.rInput,
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AiBadge(),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.obMethodFailingNote,
                    style: LpType.body13(lp.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        OptionCard(
          selected: state.method == QuitMethod.taper,
          onTap: () => vm.selectMethod(QuitMethod.taper),
          title: l10n.obMethodTaper,
          trailingCheck: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.trending_down_rounded,
                    color: state.method == QuitMethod.taper
                        ? lp.voltText
                        : lp.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.obMethodTaper,
                      style: LpType.heading(
                        state.method == QuitMethod.taper
                            ? lp.voltText
                            : lp.textPrimary,
                        size: 21,
                      ),
                    ),
                  ),
                  SelectCheck(selected: state.method == QuitMethod.taper),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l10n.obMethodTaperSub,
                style: LpType.body14(lp.textSecondary),
              ),
              if (recommendTaper) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: lp.voltSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l10n.obMethodTaperReco,
                    style: LpType.caption(lp.voltText, weight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        OptionCard(
          selected: state.method == QuitMethod.coldTurkey,
          onTap: () => vm.selectMethod(QuitMethod.coldTurkey),
          title: l10n.obMethodCold,
          trailingCheck: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.local_fire_department_outlined, color: lp.ember),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.obMethodCold,
                      style: LpType.heading(
                        state.method == QuitMethod.coldTurkey
                            ? lp.voltText
                            : lp.textPrimary,
                        size: 21,
                      ),
                    ),
                  ),
                  SelectCheck(selected: state.method == QuitMethod.coldTurkey),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l10n.obMethodColdSub,
                style: LpType.body14(lp.textSecondary),
              ),
              if (!recommendTaper) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: lp.voltSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l10n.obMethodColdReco,
                    style: LpType.caption(lp.voltText, weight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ),
        const Spacer(),
        LpButton(l10n.commonContinue, onTap: vm.next),
      ],
    );
  }
}

/// C4 — pace pills + live-morphing curve with real dates.
class PaceStep extends ConsumerWidget {
  const PaceStep({super.key});

  static const paces = [14, 21, 30, 60, 90];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final l10n = context.l10n;
    final locale = context.localeTag;
    final state = ref.watch(onboardingProvider);
    final vm = ref.read(onboardingProvider.notifier);
    final plan = vm.draftPlan();
    final freedom = plan.freedomDate;

    return StepBody(
      title: l10n.obPaceTitle,
      children: [
        Row(
          children: [
            for (final (i, pace) in paces.indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: PressScale(
                  onTap: () {
                    LpHaptics.light();
                    vm.selectPace(pace);
                  },
                  child: AnimatedContainer(
                    duration: LpMotion.fast,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: state.paceDays == pace ? lp.voltSoft : lp.surface,
                      borderRadius: BorderRadius.circular(LpDimens.rChip),
                      border: Border.all(
                        color: state.paceDays == pace
                            ? lp.voltFocus
                            : lp.border,
                        width: 1.5,
                      ),
                      boxShadow: state.paceDays == pace
                          ? [
                              BoxShadow(
                                color: lp.volt.withValues(alpha: 0.2),
                                blurRadius: 16,
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      '$pace',
                      style: LpType.displaySmall(
                        state.paceDays == pace ? lp.voltText : lp.textPrimary,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            l10n.obPaceMostChosen(30),
            style: LpType.caption(lp.voltText, weight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 20),
        LpCard(
          radius: LpDimens.rCardLg,
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.obPaceCurveStart(state.puffsPerDay),
                    style: LpType.caption11(lp.textSecondary),
                  ),
                  Text(
                    l10n.obPaceCurveLabel,
                    style: LpType.caption11(lp.textSecondary),
                  ),
                  Text(
                    l10n.obPaceCurveEnd,
                    style: LpType.caption11(lp.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TaperCurveChart(
                samples: TaperEngine.normalizedCurve(plan),
                height: 120,
                pulseEndDot: true,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    LpFormat.shortDate(plan.startDate, locale),
                    style: LpType.caption11(lp.textSecondary),
                  ),
                  Text(
                    l10n.obPaceFreedomDay(LpFormat.shortDate(freedom, locale)),
                    style: LpType.caption11(
                      lp.emberText,
                      weight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LpNoteCard(l10n.obPaceNote),
        const Spacer(),
        LpButton(
          l10n.obPaceCta,
          onTap: () {
            LpHaptics.medium();
            vm.next();
          },
        ),
      ],
    );
  }
}

/// C5 — the 3-second labor illusion. Ring fills, ticks land with haptics.
class BuildingStep extends ConsumerStatefulWidget {
  const BuildingStep({super.key});

  @override
  ConsumerState<BuildingStep> createState() => _BuildingStepState();
}

class _BuildingStepState extends ConsumerState<BuildingStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );
  int _ticked = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final tick = (_controller.value * 4).floor();
      if (tick > _ticked && tick <= 3) {
        _ticked = tick;
        LpHaptics.light();
        setState(() {});
      }
    });
    _controller.forward().whenComplete(() {
      if (mounted) ref.read(onboardingProvider.notifier).next();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    final state = ref.watch(onboardingProvider);
    final steps = [
      l10n.obBuildingStep1(state.puffsPerDay),
      l10n.obBuildingStep2,
      l10n.obBuildingStep3(state.paceDays),
      l10n.obBuildingStep4,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => ProgressRing(
                progress: _controller.value,
                size: 150,
                strokeWidth: 10,
                child: Text(
                  '${(_controller.value * 100).round()}%',
                  style: LpType.number(lp.textPrimary, size: 32),
                ),
              ),
            ),
          ),
          const SizedBox(height: 36),
          Center(
            child: Text(
              l10n.obBuildingTitle,
              style: LpType.title(lp.textPrimary, size: 26),
            ),
          ),
          const SizedBox(height: 28),
          for (final (i, label) in steps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  SelectCheck(selected: i < _ticked),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: LpType.body15(
                        i < _ticked ? lp.textPrimary : lp.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
