import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/lp_colors.dart';
import '../../../app/theme/lp_dimens.dart';
import '../../../app/theme/lp_typography.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../data/api/firebase/push_service.dart';
import '../../../data/stores/providers.dart';
import '../../../domain/analytics/lp_events.dart';
import '../../../core/utils/lp_format.dart';
import '../../../core/utils/lp_haptics.dart';
import '../../../core/utils/lp_review.dart';
import '../../../core/widgets/confetti_burst.dart';
import '../../../core/widgets/lp_buttons.dart';
import '../../../core/widgets/lp_card.dart';
import '../../../core/widgets/lp_charts.dart';
import '../../../core/widgets/lp_misc.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../core/widgets/rolling_number.dart';
import '../../../domain/logic/plan_reveal.dart';
import '../onboarding_view_model.dart';
import '../tailoring.dart';
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
    // One source for the four figures, shared with the paywall's proof card, so
    // the two screens can never quote different numbers at the same person.
    //
    // Null only if puffs/day were somehow unanswered, which the flow prevents —
    // the block below is then simply absent. An honest gap beats a Freedom Day
    // computed from a baseline of zero.
    final reveal = PlanReveal.of(plan, now: ref.read(nowProvider)());

    return StepBody(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text(
          l10n.obRevealTitle(state.paceDays),
          style: LpType.title(lp.textPrimary, size: 32),
        ),
        const SizedBox(height: 18),
        if (reveal != null) ...[
          LpCard(
            radius: LpDimens.rCardLg,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TaperCurveChart(
                  samples: reveal.curve,
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
                  l10n.commonDayN(reveal.totalDays),
                  l10n.obRevealMilestoneFreedom(
                    LpFormat.shortDate(reveal.freedomDate, locale),
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
                    reveal.projectedSaved,
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
                    reveal.puffsAvoided,
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
          // What the projected saving actually buys. A different figure from the
          // spend screen's, and by now every answer exists, so the catalogue can
          // draw on their reasons too — the two screens never repeat each other.
          if (ObTailoring.revealComparison(
                context,
                state,
                reveal.projectedSaved,
              )
              case final line?) ...[
            Text(
              line,
              textAlign: TextAlign.center,
              style: LpType.body14(lp.textPrimary, weight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
          ],
        ],
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
  /// 1.8s, down from 3.
  ///
  /// Three seconds reads as deliberate on paper and as a stuck button in the
  /// hand — long enough that a thumb settles and shifts, which is the drift
  /// the old tap recognizer used to reject. The haptic ramp is what makes the
  /// gesture feel weighty; the duration was only ever carrying the ramp.
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
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
      if (status == AnimationStatus.completed) _finish();
    });
  }

  /// The commit itself, reached either by holding the ring out or by the
  /// semantic action below. Idempotent: `_done` is set first, so the second
  /// caller of a race does nothing.
  void _finish() {
    if (_done) return;
    _done = true;
    LpHaptics.celebrate();
    ref.read(onboardingProvider.notifier).markCommitted();
    setState(() {});
    Timer(const Duration(milliseconds: 1400), () {
      if (mounted) ref.read(onboardingProvider.notifier).next();
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
            const SizedBox(height: 30),
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
                      // Day 1 is today, so Freedom Day is totalDays − 1
                      // days out — the checklist already said "29 days";
                      // this said "30 days from today" (QA copy sweep).
                      l10n.obCommitDaysOut(plan.totalDays - 1),
                      style: LpType.body13(lp.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            // The ring lives BELOW the payoff card, not above it. The frame
            // put it at ~28% of screen height with the bottom 45% empty,
            // which stranded the only control on the screen outside the thumb
            // arc of a 6.7" phone. Read the date, then reach for the ring.
            // Weighted so it lands in the lower third without touching the
            // bottom edge.
            const Spacer(flex: 2),
            Center(
              child: Semantics(
                container: true,
                button: true,
                // The hold is a gesture some people cannot make — switch
                // access, a tremor, one working hand — and this is the one
                // gate in the funnel with no way around it. The semantic
                // action is that way around.
                label: l10n.obCommitHold.replaceAll('\n', ' '),
                onTap: _finish,
                excludeSemantics: true,
                child: Listener(
                  // A raw pointer listener, never a tap recognizer: a tap
                  // rejects the moment the pointer drifts past kTouchSlop, so
                  // a thumb settling two thirds of the way through the hold
                  // silently threw the whole hold away.
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (_) {
                    if (!_done) _hold.forward();
                  },
                  onPointerUp: (_) {
                    if (!_done) _hold.reverse();
                  },
                  onPointerCancel: (_) {
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
    final state = ref.watch(onboardingProvider);
    final vm = ref.read(onboardingProvider.notifier);

    // Warmed on leaving the worries screen, four steps back. Empty means the
    // fetch found nothing, came back short, or never landed — and then this
    // screen shows NO quote cards at all.
    //
    // It used to fall back to two quotes bundled in the ARB files, which was
    // honest only for as long as real ones were coming. The beta cohort that
    // was to supply them was descoped on Sep 3 2026 (docs/08 §7 #29), so the
    // `testimonials` collection is empty until somebody consents to a quote —
    // and the fallback stopped being a safety net and became the content: two
    // five-star reviews nobody said, on the screen before the paywall. That is
    // the exact thing docs/02 §7 forbids, and the same rule that killed the
    // invented "Tokyo flight" goal and the buddy named Sam.
    //
    // The title and the ask stand on their own without them. When real quotes
    // exist, they appear here with no further change.
    final quotes = state.testimonials.map((t) => t.text).toList();

    Widget quote(String text) => LpCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // The stars belong to the QUOTE — they are what this person
              // rated us, not a control. See the CTA below for why there is no
              // star picker anywhere near the store prompt.
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
                  l10n.obRatingQuoteBadge,
                  style: LpType.micro(
                    lp.textSecondary,
                    weight: FontWeight.w700,
                  ).copyWith(letterSpacing: 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: LpType.body13(lp.textPrimary),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    return StepBody(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        // Balances the Spacer above the CTA when there are no quote cards to
        // fill the middle. Without it the ask sits jammed against the status
        // bar over an empty half-screen, which reads as a screen that failed
        // to load rather than one with nothing to show.
        if (quotes.isEmpty) const Spacer(),
        Text(l10n.obRatingTitle, style: LpType.title(lp.textPrimary, size: 28)),
        const SizedBox(height: 8),
        Text(l10n.obRatingSubtitle, style: LpType.body14(lp.textSecondary)),
        // Indexed nowhere — the list is whatever the server had, including
        // none and including one.
        for (final text in quotes) ...[
          const SizedBox(height: 12),
          quote(text),
        ],
        const Spacer(),
        // This used to be a five-star row inside a card pastiching the StoreKit
        // sheet, and tapping it did nothing but advance. It cannot come back:
        // asking for a rating ahead of the system prompt, or routing by
        // sentiment, is review gating — Apple Guideline 1.1.7, and Google Play
        // forbids asking the user's opinion at all before presenting the
        // rating card, including a picker that routes every value identically.
        // Android is the launch platform.
        //
        // So: one honest button, and no claim about what happened afterwards.
        // Neither OS reports whether its sheet appeared or what the user did,
        // so a "thanks for rating!" here would be a control that only shows a
        // success snack — about something we could not have observed.
        //
        // The same button opens the Play listing on a build that did not come
        // from Play: Play's sheet is silent for those, which is what the Sep 1
        // field test saw as "Rate Cirrus does nothing" (docs/09 issue 3).
        // `LpReview.request` picks the route; this widget does not know it.
        if (state.reviewAvailable)
          LpButton(
            l10n.obRatingCta,
            onTap: () async {
              LpHaptics.medium();
              await LpReview.request();
              vm.next();
            },
          )
        else
          // Nowhere for a tap to go — no Play Store on the device, or a
          // desktop. A dead button is worse than none, so it is simply not here.
          LpButton(l10n.commonContinue, onTap: vm.next),
        const SizedBox(height: 6),
        LpTextButton(l10n.commonNotNow, size: 15, onTap: vm.next),
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
        LpButton(
          l10n.obNotifCta,
          onTap: () async {
            // The screen above IS the pre-permission ask (docs/02 D4), so the
            // OS prompt only ever fires from this tap — never cold. A denial
            // is not a dead end: the flow continues either way, and docs/03
            // §8 re-asks after the first survived craving.
            final granted = await PushService.requestPermission();
            ref.read(analyticsProvider).notifPrompt(granted: granted);
            // Register the freshly minted token NOW. The session already
            // exists (startJourney ran before this step), and the only other
            // registration points are the next resume or the next cold start
            // — a grant that waits for those loses the first day of pushes.
            if (granted) {
              ref.read(userContextRepositoryProvider).sync().ignore();
            }
            if (context.mounted) context.go(Routes.paywallFrom('onboarding'));
          },
        ),
        const SizedBox(height: 4),
        LpTextButton(
          l10n.commonMaybeLater,
          onTap: () {
            // Skipping never opens the OS dialog, so this is a decline we
            // made ourselves — still a denied outcome for the funnel.
            ref.read(analyticsProvider).notifPrompt(granted: false);
            context.go(Routes.paywallFrom('onboarding'));
          },
        ),
      ],
    );
  }
}
