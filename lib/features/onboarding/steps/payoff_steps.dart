import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/lp_colors.dart';
import '../../../app/theme/lp_dimens.dart';
import '../../../app/theme/lp_typography.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/utils/lp_format.dart';
import '../../../core/utils/lp_haptics.dart';
import '../../../core/widgets/confetti_burst.dart';
import '../../../core/widgets/lp_buttons.dart';
import '../../../core/widgets/lp_card.dart';
import '../../../core/widgets/lp_charts.dart';
import '../../../core/widgets/lp_misc.dart';
import '../../../core/widgets/press_scale.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../core/widgets/rolling_number.dart';
import '../../../domain/logic/money_engine.dart';
import '../../../domain/logic/taper_engine.dart';
import '../onboarding_view_model.dart';
import 'step_body.dart';

/// D1 — the dopamine reveal: curve draws in, counters roll up staggered.
class RevealStep extends ConsumerWidget {
  const RevealStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final l10n = context.l10n;
    final locale = context.localeTag;
    final state = ref.watch(onboardingProvider);
    final vm = ref.read(onboardingProvider.notifier);
    final plan = vm.draftPlan();
    final projectedSaved = MoneyEngine.projectedToFreedom(plan, 0);
    final puffsAvoided = TaperEngine.projectedPuffsAvoided(plan);

    return StepBody(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text(
          l10n.obRevealTitle(state.paceDays),
          style: LpType.title(lp.textPrimary, size: 32),
        ),
        const SizedBox(height: 18),
        LpCard(
          radius: LpDimens.rCardLg,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TaperCurveChart(
                samples: TaperEngine.normalizedCurve(plan),
                height: 104,
                animate: true,
                milestones: [(0.1, lp.ember), (0.23, lp.oxygen)],
              ),
              const SizedBox(height: 10),
              _milestone(
                context,
                lp.ember,
                l10n.commonDayN(3),
                l10n.obRevealMilestone3,
              ),
              _milestone(
                context,
                lp.oxygen,
                l10n.commonDayN(7),
                l10n.obRevealMilestone7,
              ),
              _milestone(
                context,
                lp.ember,
                l10n.commonDayN(plan.totalDays),
                l10n.obRevealMilestoneFreedom(
                  LpFormat.shortDate(plan.freedomDate, locale),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _statCard(
                context,
                RollingNumber(
                  projectedSaved,
                  format: (v) => LpFormat.money(v, locale),
                  style: LpType.number(lp.voltText, size: 30).copyWith(
                    shadows: [
                      Shadow(
                        color: lp.volt.withValues(alpha: 0.4),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                ),
                l10n.obRevealSavedLabel,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                context,
                // Frame 16: counters roll up staggered — this one lands second.
                RollingNumber(
                  puffsAvoided,
                  duration: const Duration(milliseconds: 1400),
                  curve: const Interval(0.4, 1, curve: LpMotion.emphasized),
                  format: (v) => LpFormat.integer(v, locale),
                  style: LpType.number(lp.voltText, size: 30).copyWith(
                    shadows: [
                      Shadow(
                        color: lp.volt.withValues(alpha: 0.4),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                ),
                l10n.obRevealPuffsLabel,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LpCard(
          radius: LpDimens.rInput,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.obRevealProofLabel,
                style: LpType.caption11(
                  lp.voltText,
                  weight: FontWeight.w600,
                ).copyWith(letterSpacing: 0.5),
              ),
              const SizedBox(height: 5),
              Text(l10n.obRevealProof, style: LpType.body13(lp.textSecondary)),
            ],
          ),
        ),
        const Spacer(),
        LpButton(l10n.obRevealCta, onTap: vm.next),
      ],
    );
  }

  Widget _milestone(BuildContext context, Color dot, String day, String label) {
    final lp = context.lp;
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: dot),
          ),
          const SizedBox(width: 8),
          Text(
            day,
            style: LpType.caption(lp.textPrimary, weight: FontWeight.w600),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: LpType.caption(lp.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(BuildContext context, Widget number, String label) {
    final lp = context.lp;
    return LpCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          number,
          const SizedBox(height: 4),
          Text(label, style: LpType.caption(lp.textSecondary)),
        ],
      ),
    );
  }
}

/// D2 — hold-to-commit: 3s Ember ring, haptic ramp, confetti on completion.
class CommitStep extends ConsumerStatefulWidget {
  const CommitStep({super.key});

  @override
  ConsumerState<CommitStep> createState() => _CommitStepState();
}

class _CommitStepState extends ConsumerState<CommitStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
    reverseDuration: const Duration(milliseconds: 500),
  );
  bool _done = false;
  int _hapticStage = 0;

  @override
  void initState() {
    super.initState();
    _hold.addListener(() {
      final stage = (_hold.value * 6).floor();
      if (stage > _hapticStage) {
        _hapticStage = stage;
        // Frame 17: haptic ramps light → medium → heavy through the hold.
        if (stage >= 5) {
          LpHaptics.heavy();
        } else if (stage >= 3) {
          LpHaptics.medium();
        } else {
          LpHaptics.light();
        }
      }
    });
    _hold.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_done) {
        _done = true;
        LpHaptics.celebrate();
        ref.read(onboardingProvider.notifier).markCommitted();
        setState(() {});
        Timer(const Duration(milliseconds: 1400), () {
          if (mounted) ref.read(onboardingProvider.notifier).next();
        });
      }
    });
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    final locale = context.localeTag;
    final vm = ref.read(onboardingProvider.notifier);
    final plan = vm.draftPlan();

    // Frame 17: static Ember/Volt specks decorate the top of the frame.
    Widget speck(
      double? top,
      double? left,
      double? right,
      double w,
      double h,
      Color color,
      double angle,
    ) => Positioned(
      top: top,
      left: left,
      right: right,
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );

    return Stack(
      children: [
        speck(120, 60, null, 6, 6, lp.volt, 0.35),
        speck(90, null, 80, 7, 7, lp.ember, -0.26),
        speck(200, null, 44, 5, 5, lp.volt, 0),
        speck(170, 36, null, 5, 9, lp.ember, 0.7),
        speck(250, 90, null, 4, 4, lp.ember, 0),
        speck(240, null, 110, 6, 6, lp.volt, 1.05),
        StepBody(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          children: [
            Center(
              child: Text(
                l10n.obCommitTitle,
                style: LpType.title(lp.textPrimary, size: 32),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                l10n.obCommitSubtitle,
                style: LpType.body14(lp.textSecondary),
              ),
            ),
            const SizedBox(height: 34),
            Center(
              child: GestureDetector(
                onTapDown: (_) {
                  if (!_done) _hold.forward();
                },
                onTapUp: (_) {
                  if (!_done) _hold.reverse();
                },
                onTapCancel: () {
                  if (!_done) _hold.reverse();
                },
                child: AnimatedBuilder(
                  animation: _hold,
                  builder: (context, _) => ProgressRing(
                    progress: _hold.value,
                    size: 170,
                    strokeWidth: 8,
                    color: lp.ember,
                    child: Container(
                      width: 132,
                      height: 132,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: lp.surface,
                        border: Border.all(color: lp.border, width: 1.5),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 26)),
                          const SizedBox(height: 4),
                          Text(
                            l10n.obCommitHold,
                            textAlign: TextAlign.center,
                            style: LpType.heading(lp.textPrimary, size: 15),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 34),
            AnimatedScale(
              scale: _done ? 1 : 0.96,
              duration: LpMotion.normal,
              curve: LpMotion.spring,
              child: LpCard(
                radius: LpDimens.rCardLg,
                borderColor: lp.ember.withValues(alpha: 0.45),
                glowColor: lp.ember,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      l10n.obCommitFreedomLabel,
                      style: LpType.caption(
                        lp.emberText,
                        weight: FontWeight.w600,
                      ).copyWith(letterSpacing: 1),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      LpFormat.mediumDate(plan.freedomDate, locale),
                      style: LpType.number(lp.textPrimary, size: 32),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.obCommitDaysOut(plan.totalDays),
                      style: LpType.body13(lp.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Center(
              child: Text(
                l10n.obCommitPrivacy,
                textAlign: TextAlign.center,
                style: LpType.caption(lp.textSecondary),
              ),
            ),
          ],
        ),
        if (_done) const Positioned.fill(child: ConfettiBurst()),
      ],
    );
  }
}

/// D3 — the honest rating ask at peak motivation.
class RatingStep extends ConsumerWidget {
  const RatingStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final l10n = context.l10n;
    final vm = ref.read(onboardingProvider.notifier);

    Widget quote(String text) => LpCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '★★★★★',
                style: TextStyle(
                  color: lp.volt,
                  fontSize: 14,
                  letterSpacing: 2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: lp.surfaceInset,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: lp.border),
                ),
                child: Text(
                  l10n.obRatingBetaTester,
                  style: LpType.micro(
                    lp.textSecondary,
                    weight: FontWeight.w700,
                  ).copyWith(letterSpacing: 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(text, style: LpType.body13(lp.textPrimary)),
        ],
      ),
    );

    return StepBody(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        Text(l10n.obRatingTitle, style: LpType.title(lp.textPrimary, size: 28)),
        const SizedBox(height: 8),
        Text(l10n.obRatingSubtitle, style: LpType.body14(lp.textSecondary)),
        const SizedBox(height: 22),
        quote(l10n.obRatingQuote1),
        const SizedBox(height: 12),
        quote(l10n.obRatingQuote2),
        const Spacer(),
        LpCard(
          radius: LpDimens.rBento,
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
          child: Column(
            children: [
              Text(
                l10n.obRatingCardTitle,
                style: LpType.emphasis(lp.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.obRatingCardSubtitle,
                style: LpType.caption(lp.textSecondary),
              ),
              const SizedBox(height: 12),
              PressScale(
                onTap: () {
                  // Real build: trigger StoreKit in_app_review here.
                  LpHaptics.medium();
                  vm.next();
                },
                child: Text(
                  '★★★★★',
                  style: TextStyle(
                    color: lp.textFaint,
                    fontSize: 26,
                    letterSpacing: 6,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Divider(color: lp.border, height: 16),
              LpTextButton(
                l10n.commonNotNow,
                // Deliberately the iOS system-dialog link blue in both themes
                // — this card pastiches the StoreKit rating sheet.
                color: const Color(0xFF6EA5FF),
                size: 15,
                onTap: vm.next,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// D4 — notification pre-permission with a real push preview.
class NotificationsStep extends ConsumerWidget {
  const NotificationsStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final l10n = context.l10n;

    Widget bullet(String label) => Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: lp.voltSoft,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: lp.volt.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Text(
              '✓',
              style: LpType.body13(lp.voltText, weight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(child: Text(label, style: LpType.body14(lp.textBody))),
        ],
      ),
    );

    return StepBody(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        Text(l10n.obNotifTitle, style: LpType.title(lp.textPrimary)),
        const SizedBox(height: 8),
        Text(l10n.obNotifSubtitle, style: LpType.body14(lp.textSecondary)),
        const SizedBox(height: 26),
        PushPreviewCard(
          time: l10n.obNotifPreviewTime,
          body: l10n.obNotifPreviewBody,
        ),
        const SizedBox(height: 22),
        bullet(l10n.obNotifBullet1),
        bullet(l10n.obNotifBullet2),
        bullet(l10n.obNotifBullet3),
        const Spacer(),
        LpButton(l10n.obNotifCta, onTap: () => context.go(Routes.paywall)),
        const SizedBox(height: 4),
        LpTextButton(
          l10n.commonMaybeLater,
          onTap: () => context.go(Routes.paywall),
        ),
      ],
    );
  }
}
