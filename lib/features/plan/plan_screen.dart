import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_dimens.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/utils/enum_labels.dart';
import '../../domain/date_key.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/utils/lp_format.dart';
import '../../core/utils/lp_haptics.dart';
import '../../core/widgets/lp_buttons.dart';
import '../../core/widgets/lp_card.dart';
import '../../core/widgets/lp_charts.dart';
import '../../core/widgets/lp_misc.dart';
import '../../core/widgets/lp_premium_gate.dart';
import '../../core/widgets/lp_selectables.dart';
import '../../data/stores/providers.dart';
import '../../domain/logic/plan_adjust.dart';
import '../../domain/logic/plan_paces.dart';
import '../../domain/logic/taper_engine.dart';
import '../../domain/models/models.dart';

/// Frame 37 — the plan: live curve with today marker, coming-up milestones,
/// and the no-reset adjust sheet.
class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final l10n = context.l10n;
    final locale = context.localeTag;
    final journey = ref.watch(quitStoreProvider);
    final snap = ref.watch(todayProvider);
    if (journey == null || snap == null) return const SizedBox.shrink();
    final plan = journey.plan;
    // Only today's verdict is shown. Yesterday's is not history worth
    // displaying — it describes a limit that has already been superseded, and
    // `JourneyStore.applyPlanAdvice` refuses to act on it for the same reason.
    final rawAdvice = journey.planAdvice;
    final advice = rawAdvice != null && rawAdvice.appliesTo(snap.now)
        ? rawAdvice
        : null;
    final halfway = TaperEngine.halfwayDay(plan);
    final halfwayLimit = TaperEngine.limitFor(plan, halfway);
    final cravingsFadeDay = TaperEngine.cravingsFadeDay(plan);
    final cravingsFadeDate = LpDate.addDays(
      plan.startDate,
      cravingsFadeDay - 1,
    );

    return Scaffold(
      appBar: AppBar(
        leading: BackChevron(onTap: () => context.pop()),
        title: Text(l10n.planTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Center(
              child: Text(
                l10n.planHeaderMeta(plan.method.label(context), plan.totalDays),
                style: LpType.caption(lp.textSecondary),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LpCard(
                radius: LpDimens.rCardLg,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TaperCurveChart(
                      samples: TaperEngine.normalizedCurve(plan),
                      height: 110,
                      todayFraction: plan.totalDays <= 1
                          ? 0
                          : ((snap.dayNumber - 1) / (plan.totalDays - 1))
                                .clamp(0, 1)
                                .toDouble(),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          LpFormat.shortDate(plan.startDate, locale),
                          style: LpType.caption11(lp.textSecondary),
                        ),
                        Text(
                          l10n.planTodayMarker(snap.limit),
                          style: LpType.caption11(
                            lp.voltText,
                            weight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          l10n.planFreedomMarker(
                            LpFormat.shortDate(plan.freedomDate, locale),
                          ),
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
              if (advice != null) ...[
                const SizedBox(height: 12),
                _AdaptiveCard(advice: advice),
              ] else if (!ref.watch(isPremiumProvider)) ...[
                // The nightly adjustment is Premium (docs/01 §10); the server
                // computes none for a free account, so there is nothing to
                // blur — the door alone, honestly labelled.
                const SizedBox(height: 12),
                LpPremiumGate(
                  source: 'plan',
                  pitch: l10n.premiumPitchPlan,
                  compact: true,
                ),
              ],
              const SizedBox(height: 16),
              SectionLabel(
                l10n.planComingUp,
                padding: const EdgeInsets.only(left: 4, bottom: 10),
              ),
              _upcoming(
                context,
                dot: lp.volt,
                title: l10n.planHalfwayTitle(halfway),
                sub: l10n.planHalfwaySub(halfwayLimit),
                trailing: LpFormat.shortDate(
                  LpDate.addDays(plan.startDate, halfway - 1),
                  locale,
                ),
              ),
              const SizedBox(height: 10),
              _upcoming(
                context,
                dot: lp.oxygen,
                title: l10n.planCravingsFadeTitle(cravingsFadeDay),
                sub: l10n.planCravingsFadeSub,
                trailing: LpFormat.shortDate(cravingsFadeDate, locale),
              ),
              const SizedBox(height: 10),
              LpCard(
                radius: LpDimens.rInput,
                borderColor: lp.ember.withValues(alpha: 0.45),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    const Text('🏆', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: l10n.planFreedomTitle(plan.totalDays),
                          style: LpType.body14(
                            lp.emberText,
                            weight: FontWeight.w600,
                          ),
                          children: [
                            TextSpan(
                              text:
                                  ' · ${LpFormat.shortDate(plan.freedomDate, locale)}',
                              style: LpType.caption(lp.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (snap.isMaintenance) ...[
                // Past the end there is nothing left to adjust: the sheet
                // re-drew the curve from the original baseline over the old
                // runway, and handed somebody now on 80 a day a line of 28.
                // What a finished plan has is a next one.
                Center(
                  child: Text(
                    l10n.planEnded(
                      LpFormat.shortDate(plan.freedomDate, locale),
                    ),
                    style: LpType.caption(lp.textSecondary),
                  ),
                ),
                const SizedBox(height: 10),
                LpButton(
                  l10n.planNewCta,
                  height: 52,
                  onTap: () => context.push(Routes.planNew),
                ),
              ] else ...[
                LpButton(
                  l10n.planAdjustCta,
                  style: LpButtonStyle.surface,
                  height: 52,
                  onTap: () => _showAdjustSheet(context, ref, plan),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    l10n.planAdjustNote,
                    style: LpType.caption(lp.textSecondary),
                  ),
                ),
                // And for a plan that no longer fits at all — a different
                // level, not a different pace.
                Center(
                  child: LpTextButton(
                    l10n.planNewCta,
                    onTap: () => context.push(Routes.planNew),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _upcoming(
    BuildContext context, {
    required Color dot,
    required String title,
    required String sub,
    required String trailing,
  }) {
    final lp = context.lp;
    return LpCard(
      radius: LpDimens.rInput,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: dot),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: title,
                style: LpType.body14(lp.textPrimary, weight: FontWeight.w600),
                children: [
                  TextSpan(
                    text: ' · $sub',
                    style: LpType.caption(lp.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          Text(trailing, style: LpType.caption11(lp.textSecondary)),
        ],
      ),
    );
  }

  /// Moves Freedom Day, and nothing else (docs/15 QP-A11).
  ///
  /// It used to preselect the plan's current length and always apply it, which
  /// the store read as "from today": an unchanged Apply on day 10 of 30 made a
  /// 39-day plan. Now nothing is preselected, Apply stays off until the choice
  /// would actually move the date, and the date shown is the one `PlanAdjust`
  /// would store. The method toggle left the sheet: switching method mid-taper
  /// is a new plan (`PlanRestart`), not an edit of this one.
  void _showAdjustSheet(BuildContext context, WidgetRef ref, QuitPlan plan) {
    final outer = context;
    final now = ref.read(nowProvider)();
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        int? pace;
        return StatefulBuilder(
          builder: (context, setState) {
            final lp = context.lp;
            final l10n = context.l10n;
            final locale = context.localeTag;
            final hasLengths = plan.method != QuitMethod.coldTurkey;
            final change = pace == null
                ? null
                : PlanAdjust.toReach(plan, now, pace!);
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.planAdjustSheetTitle,
                    style: LpType.titleSm(lp.textPrimary),
                  ),
                  const SizedBox(height: 16),
                  // Cold turkey has one date, the day it started, so there is
                  // no length to choose: only the way to a different plan.
                  if (hasLengths) ...[
                    Text(
                      l10n.planAdjustSheetNote,
                      style: LpType.caption(lp.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        for (final p in PlanPaces.options) ...[
                          if (p != PlanPaces.options.first)
                            const SizedBox(width: 8),
                          Expanded(
                            child: LpChip(
                              label: '$p',
                              selected: pace == p,
                              onTap: () => setState(() => pace = p),
                              fontSize: 14,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (pace != null && change == null)
                      Text(
                        l10n.planAdjustSame,
                        style: LpType.body13(lp.textPrimary),
                      ),
                    if (change != null) ...[
                      Text(
                        l10n.planAdjustPreview(
                          LpFormat.shortDate(change.freedomDate, locale),
                        ),
                        style: LpType.body13(
                          lp.textPrimary,
                          weight: FontWeight.w600,
                        ),
                      ),
                      // A later date is a quit date that slips (Hughes 2010).
                      if (change.deltaDays > 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          l10n.planAdjustLater,
                          style: LpType.caption(lp.textSecondary),
                        ),
                      ],
                    ],
                    const SizedBox(height: 18),
                    LpButton(
                      l10n.planAdjustApply,
                      // Off until the choice would move the date: a button
                      // that "applies" nothing and says it did is worse than
                      // no button.
                      onTap: change == null
                          ? null
                          : () {
                              LpHaptics.medium();
                              final chosen = pace!;
                              final landed = change.freedomDate;
                              // Leave first, then change the journey.
                              Navigator.of(sheetContext).pop();
                              ref
                                  .read(quitStoreProvider.notifier)
                                  .adjustPlan(paceDays: chosen);
                              showLpSnack(
                                outer,
                                l10n.planAdjusted(
                                  LpFormat.shortDate(landed, locale),
                                ),
                              );
                            },
                    ),
                  ],
                  LpTextButton(
                    l10n.planAdjustNewPlanLink,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      outer.push(Routes.planNew);
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

/// The nightly adaptive layer, made visible (docs/03 §3.3).
///
/// Without this card the taper simply changes its number overnight and the
/// user has no idea why — which reads as the app being unreliable rather than
/// responsive. The struggling copy in particular is load-bearing brand voice:
/// the plan bending is stated as the plan adapting, never as the user
/// failing (docs/07).
class _AdaptiveCard extends StatelessWidget {
  const _AdaptiveCard({required this.advice});

  final PlanAdvice advice;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    // Struggling is the only state that earns the caution tint; the other two
    // are good news and read Volt.
    final struggling = advice.adherence == PlanAdherence.struggling;
    final accent = struggling ? lp.caution : lp.volt;
    final accentText = struggling ? lp.cautionText : lp.voltText;
    final body = switch (advice.adherence) {
      PlanAdherence.crushing => l10n.planAdaptiveCrushing(advice.limit),
      PlanAdherence.onTrack => l10n.planAdaptiveOnTrack(advice.limit),
      PlanAdherence.struggling => l10n.planAdaptiveStruggling(advice.limit),
    };

    return LpCard(
      radius: LpDimens.rInput,
      borderColor: accent.withValues(alpha: 0.45),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.planAdaptiveLabel,
            style: LpType.caption11(
              accentText,
              weight: FontWeight.w700,
            ).copyWith(letterSpacing: 1.2),
          ),
          const SizedBox(height: 6),
          Text(body, style: LpType.body13(lp.textBody)),
          // Only shown when the runway actually moved — the server sends 0
          // once the stretch ceiling is reached, and claiming a stretch that did not
          // happen would be an invented number.
          if (advice.stretchDelta > 0) ...[
            const SizedBox(height: 6),
            Text(
              l10n.planAdaptiveStretched,
              style: LpType.caption(lp.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
