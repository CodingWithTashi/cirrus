import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_dimens.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/utils/enum_labels.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/utils/lp_format.dart';
import '../../core/utils/lp_haptics.dart';
import '../../core/widgets/lp_buttons.dart';
import '../../core/widgets/lp_card.dart';
import '../../core/widgets/lp_charts.dart';
import '../../core/widgets/lp_selectables.dart';
import '../../data/stores/providers.dart';
import '../../domain/logic/taper_engine.dart';
import '../../domain/models/models.dart';

/// Frames 48a/48b — relapse recovery. Teammate-reviewing-film tone, no red,
/// no streak-zero moment ever shown.
class SlipFlow extends ConsumerStatefulWidget {
  const SlipFlow({super.key});

  @override
  ConsumerState<SlipFlow> createState() => _SlipFlowState();
}

class _SlipFlowState extends ConsumerState<SlipFlow> {
  int _step = 0;
  SlipTrigger? _trigger;

  /// Frame 48b: the curve shows the slip bump honestly first, then visibly
  /// reflows to the stretched runway.
  bool _reflowed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: LpMotion.normal,
          child: KeyedSubtree(
            key: ValueKey(_step),
            child: _step == 0 ? _whatHappened(context) : _adjustment(context),
          ),
        ),
      ),
    );
  }

  Widget _whatHappened(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    final cleanDays = ref.watch(quitStoreProvider)?.pendingSlipCleanDays ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.slipTitle, style: LpType.title(lp.textPrimary, size: 32)),
          const SizedBox(height: 12),
          Text(
            l10n.slipSubtitle(cleanDays),
            style: LpType.body14(lp.textSecondary),
          ),
          const SizedBox(height: 30),
          SectionLabel(
            l10n.slipWhatHappened,
            padding: const EdgeInsets.only(bottom: 12),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final trigger in SlipTrigger.values)
                LpChip(
                  label: trigger.label(context),
                  selected: _trigger == trigger,
                  onTap: () => setState(() => _trigger = trigger),
                ),
            ],
          ),
          const Spacer(),
          LpNoteCard(l10n.slipNoBannedWords),
          const SizedBox(height: 14),
          LpButton(
            l10n.slipAdjustCta,
            onTap: _trigger == null
                ? null
                : () {
                    ref
                        .read(quitStoreProvider.notifier)
                        .recordSlipTrigger(_trigger!);
                    setState(() => _step = 1);
                    Future<void>.delayed(
                      const Duration(milliseconds: 1000),
                      () {
                        if (mounted && _step == 1) {
                          setState(() => _reflowed = true);
                        }
                      },
                    );
                  },
          ),
        ],
      ),
    );
  }

  Widget _adjustment(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    final locale = context.localeTag;
    final journey = ref.watch(quitStoreProvider);
    final snap = ref.watch(todayProvider);
    if (journey == null || snap == null) return const SizedBox.shrink();
    final reflown = TaperEngine.reflowAfterSlip(journey.plan);
    final extraDays = reflown.totalDays - journey.plan.totalDays;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.slipAdjustTitle,
            style: LpType.title(lp.textPrimary, size: 28),
          ),
          const SizedBox(height: 22),
          LpCard(
            radius: LpDimens.rCardLg,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionLabel(l10n.slipCurveLabel),
                TaperCurveChart(
                  samples: _reflowed
                      ? TaperEngine.normalizedCurve(reflown)
                      : _bumpedCurve(reflown),
                  height: 96,
                  todayFraction: reflown.totalDays <= 1
                      ? 0
                      : ((snap.dayNumber - 1) / (reflown.totalDays - 1))
                            .clamp(0, 1)
                            .toDouble(),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.slipTheBump,
                      style: LpType.caption11(lp.textSecondary),
                    ),
                    Text(
                      l10n.slipNewFreedom(
                        LpFormat.shortDate(reflown.freedomDate, locale),
                        extraDays,
                      ),
                      style: LpType.caption11(
                        lp.emberText,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  // The note names the trigger THEY picked, or none. One
                  // fixed "Party nights get…" string told a stressed person
                  // about their party habit (QA L2). Nothing here promises
                  // a feature the app does not have.
                  switch (_trigger) {
                    SlipTrigger.party => l10n.slipCurveNoteParty,
                    SlipTrigger.stress => l10n.slipCurveNoteStress,
                    SlipTrigger.boredom => l10n.slipCurveNoteBoredom,
                    SlipTrigger.drinking => l10n.slipCurveNoteDrinking,
                    SlipTrigger.friends => l10n.slipCurveNoteFriends,
                    SlipTrigger.justHappened => l10n.slipCurveNoteJustHappened,
                    null => l10n.slipCurveNote,
                  },
                  style: LpType.caption(lp.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          LpCard(
            radius: LpDimens.rCardLg,
            borderColor: lp.ember.withValues(alpha: 0.45),
            glowColor: lp.ember,
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Opacity(
                  opacity: 0.75,
                  child: const Text('🔥', style: TextStyle(fontSize: 34)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.slipStreakSurvives(snap.streak),
                        style: LpType.emphasis(lp.textPrimary, size: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.slipFlameDims,
                        style: LpType.body13(lp.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          LpButton(
            l10n.slipBackOnCurve,
            onTap: () {
              LpHaptics.medium();
              ref.read(quitStoreProvider.notifier).applySlipRecovery();
              context.go(Routes.home);
            },
          ),
          const SizedBox(height: 6),
          LpTextButton(
            l10n.slipTalkFirst,
            onTap: () {
              ref.read(quitStoreProvider.notifier).applySlipRecovery();
              context.go(Routes.coach);
            },
          ),
        ],
      ),
    );
  }

  /// The reflown curve with a small honest bump at today's position.
  List<double> _bumpedCurve(QuitPlan plan) {
    final samples = TaperEngine.normalizedCurve(plan);
    final snap = ref.read(todayProvider);
    if (snap == null || samples.length < 4) return samples;
    final i =
        ((samples.length - 1) * (snap.dayNumber - 1) / (plan.totalDays - 1))
            .round()
            .clamp(1, samples.length - 2);
    final bumped = [...samples];
    bumped[i] = (bumped[i] + 0.14).clamp(0.0, 1.0);
    return bumped;
  }
}
