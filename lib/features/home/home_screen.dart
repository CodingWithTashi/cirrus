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
import '../../core/widgets/lp_card.dart';
import '../../core/widgets/lp_misc.dart';
import '../../core/widgets/press_scale.dart';
import '../../core/widgets/progress_ring.dart';
import '../../core/widgets/rolling_number.dart';
import '../../data/stores/day1_tour_store.dart';
import '../../data/stores/providers.dart';
import '../day1/day1_spotlight.dart';
import '../stats/edit_day_sheet.dart';
import '../../domain/date_key.dart';
import '../../domain/models/journey_state.dart';
import '../../domain/models/models.dart';
import 'widgets/log_feedback.dart';
import 'widgets/mood_sheet.dart';

/// Frame 30 — HOME / Today. Bento grid, rolling counters, LOG PUFF in the
/// thumb zone, SOS always floating. Over-limit state folds in from frame 31.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _nudgeDismissed = false;
  bool _ringPulse = false;
  final _hold = HoldToLog();
  bool _holdTokenBefore = false;

  @override
  void dispose() {
    _hold.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    final locale = context.localeTag;
    final journey = ref.watch(quitStoreProvider);
    final snap = ref.watch(todayProvider);
    if (journey == null || snap == null) return const SizedBox.shrink();

    // Day-1 step one holds everything but the log button closed.
    final tourLocked = ref.watch(day1TourLockedProvider);

    final over = snap.isOverLimit;
    final ringColor = over ? lp.danger : lp.voltStrong;
    // `snap.now` is the clock seam, so "what does Home show at 10:15 on a
    // 0-limit day" is a widget test rather than a 29-day wait.
    final now = snap.now;
    final todayLog = journey.logFor(now);
    // On a 0-limit day zero puffs IS the goal, so the confirm card is there
    // all day; on any other day confirming "no puffs today" at breakfast
    // would be a guess about the evening, so it waits for 8pm. Evening-only
    // on the tail days is how a perfect day 28 zeroed a 21-day streak (QA H4).
    final showVapeFree =
        snap.puffs == 0 &&
        !(todayLog?.vapeFreeConfirmed ?? false) &&
        (snap.limit == 0 || now.hour >= 20);
    // The morning after an unconfirmed day: ask, never assume. A day with no
    // log — or a zero-puff log nobody confirmed — breaks the chain, and the
    // only honest way to know what happened is to ask the one person who
    // does. Never about a day before the plan existed.
    final yesterdayKey = LpDate.addDays(JourneyState.dateKey(now), -1);
    final yesterdayLog = journey.days[yesterdayKey];
    final askYesterday =
        !yesterdayKey.isBefore(JourneyState.dateKey(journey.plan.startDate)) &&
        !(yesterdayLog?.isConfirmed ?? false);
    final showMoodPrompt = todayLog?.mood == null && now.hour >= 18;

    bool onTourStep() =>
        ref.read(day1TourStepProvider) == Day1TourStep.logPuff;

    bool tokenUsedToday() =>
        ref.read(quitStoreProvider)?.logFor(now)?.repairTokenUsed ??
        false;

    // Frame 31: "+1 = ring tick + 1.02 bounce + light haptic".
    void pulse() {
      setState(() => _ringPulse = true);
      Future<void>.delayed(const Duration(milliseconds: 140), () {
        if (mounted) setState(() => _ringPulse = false);
      });
    }

    void showFeedback({required bool tokenBefore}) {
      if (!tokenBefore && tokenUsedToday()) {
        // The exact tap (or hold) that burned a repair token: flame dims,
        // doesn't die. Before/after, not `puffs == limit + 1` — a burst can
        // jump past the line by more than one and still deserves the note.
        showLpSnack(context, l10n.homeTokenUsedNote);
      } else {
        showLogUndoSnack(
          context,
          ref,
          count: ref.read(puffBurstProvider),
          aboveCta: true,
        );
      }
    }

    void logPuff() {
      LpHaptics.light();
      if (onTourStep()) {
        // Day-1 step one: `logPuff` already ticks task 0 in the store; this
        // is the half nothing else does — ending the step and returning to
        // the checklist. Without it the step flipped to `meetCoach` with the
        // user still on a fully locked Home, and the only way out was
        // killing the app. No snack and no burst on this path: the route
        // changes underneath it, and the ticking box IS the feedback.
        ref.read(quitStoreProvider.notifier).logPuff();
        ref.read(day1TourProvider.notifier).complete(Day1TourStep.logPuff);
        return;
      }
      final tokenBefore = tokenUsedToday();
      quickLogStep(ref);
      pulse();
      showFeedback(tokenBefore: tokenBefore);
    }

    // Press-and-hold auto-repeat: the ring's rolling number is the live
    // feedback while held; the undo snack (with the whole burst's total)
    // waits for release so it isn't re-animating every 180ms.
    void startHold() {
      // The tour teaches ONE deliberate tap; a hold would blow through the
      // lesson and log a pile of puffs the user didn't mean.
      if (onTourStep()) return;
      LpHaptics.medium();
      _holdTokenBefore = tokenUsedToday();
      _hold.start(() {
        quickLogStep(ref);
        pulse();
      });
    }

    void endHold() {
      if (!_hold.held) return;
      _hold.stop();
      showFeedback(tokenBefore: _holdTokenBefore);
    }

    final settings = ref.watch(settingsStoreProvider);
    final showFoundingOffer =
        journey.profile.tier == SubscriptionTier.free && !settings.winbackShown;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: IgnorePointer(
                // Day-1 step one: everything except the log button below is
                // held closed. One wrapper rather than an `enabled:` flag on
                // each of the fifteen controls in here — the flag would be
                // fifteen chances to miss one, and a sixteenth control added
                // later would ship unguarded.
                ignoring: tourLocked,
                child: Stack(
                  children: [
                    ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        // Header — date/day link to Plan, avatar to Profile.
                        Row(
                          children: [
                            Expanded(
                              child: PressScale(
                                onTap: () => context.push(Routes.plan),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      // Never "Day 31 of 30": the last day
                                      // is Freedom Day and every day after
                                      // is maintenance, said so (QA M3).
                                      snap.isMaintenance
                                          ? l10n.homeGreetingMaintenance(
                                              LpFormat.weekdayDate(
                                                snap.now,
                                                locale,
                                              ),
                                              snap.daysPastPlan,
                                            )
                                          : snap.isFreedomDay
                                          ? l10n.homeGreetingFreedomDay(
                                              LpFormat.weekdayDate(
                                                snap.now,
                                                locale,
                                              ),
                                            )
                                          : l10n.homeGreetingDate(
                                              LpFormat.weekdayDate(
                                                snap.now,
                                                locale,
                                              ),
                                              snap.dayNumber,
                                              snap.totalDays,
                                            ),
                                      style: LpType.caption(lp.textSecondary),
                                    ),
                                    Text(
                                      l10n.homeTitle,
                                      style: LpType.titleSm(lp.textPrimary),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            PressScale(
                              onTap: () => context.push(Routes.profile),
                              child: EmojiAvatar(
                                journey.profile.avatarEmoji,
                                size: 38,
                              ),
                            ),
                            const SizedBox(width: 8),
                            StreakChip(
                              days: snap.streak,
                              dimmed: snap.flameDimmed,
                              onTap: () => context.push(Routes.milestones),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Bento: ring + status. Tapping it opens the adjust
                        // sheet — the way back when the undo snack is gone
                        // and the count is wrong (a hold overshoots easily).
                        AnimatedScale(
                          scale: _ringPulse ? 1.02 : 1,
                          duration: const Duration(milliseconds: 130),
                          curve: Curves.easeOut,
                          child: PressScale(
                            onTap: () => showEditDaySheet(
                              context,
                              ref,
                              todayLog ??
                                  DayLog(
                                    date: now,
                                    puffs: 0,
                                    limit: snap.limit,
                                  ),
                            ),
                            child: LpCard(
                            radius: LpDimens.rBento,
                            borderColor: over
                                ? lp.danger.withValues(alpha: 0.5)
                                : lp.border,
                            glowColor: over ? lp.danger : null,
                            padding: const EdgeInsets.all(18),
                            child: Row(
                              children: [
                                ProgressRing(
                                  progress: snap.limit == 0
                                      ? 1
                                      : snap.puffs / snap.limit,
                                  size: 108,
                                  color: ringColor,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      RollingNumber(
                                        snap.puffs,
                                        duration: LpMotion.normal,
                                        style:
                                            LpType.number(
                                              over
                                                  ? lp.dangerText
                                                  : lp.voltText,
                                              size: 30,
                                            ).copyWith(
                                              shadows: [
                                                Shadow(
                                                  color:
                                                      (over
                                                              ? lp.danger
                                                              : lp.volt)
                                                          .withValues(
                                                            alpha: 0.5,
                                                          ),
                                                  blurRadius: 20,
                                                ),
                                              ],
                                            ),
                                      ),
                                      Text(
                                        l10n.homeOfLimit(snap.limit),
                                        style: LpType.micro(lp.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        over
                                            ? l10n.homeOverLimitTitle
                                            : l10n.homePuffsToday,
                                        style: LpType.heading(lp.textPrimary),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        over
                                            ? l10n.homeOverLimitBody
                                            : snap.puffsLeft > snap.limit * 0.25
                                            ? l10n.homeLeftAhead(snap.puffsLeft)
                                            : l10n.homeLeftTight(
                                                snap.puffsLeft,
                                              ),
                                        style: LpType.caption(lp.textSecondary),
                                      ),
                                      const SizedBox(height: 10),
                                      if (snap.vsDay1Percent != 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 9,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: lp.surfaceInset,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: lp.border,
                                            ),
                                          ),
                                          child: Text(
                                            l10n.homeVsDay1(
                                              LpFormat.signedPercent(
                                                snap.vsDay1Percent,
                                              ),
                                            ),
                                            style: LpType.caption11(
                                              lp.voltText,
                                              weight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Over-limit actions + honest footer (frame 31 state B).
                        if (over) ...[
                          Row(
                            children: [
                              Expanded(
                                child: PressScale(
                                  onTap: () => context.push(Routes.panic),
                                  child: Container(
                                    height: 48,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: lp.oxygenSoft,
                                      borderRadius: BorderRadius.circular(
                                        LpDimens.rInput,
                                      ),
                                      border: Border.all(
                                        color: lp.oxygen.withValues(alpha: 0.4),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Text(
                                      l10n.homeOverLimitBreathe,
                                      style: LpType.body14(
                                        lp.oxygenText,
                                        weight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: PressScale(
                                  onTap: () => context.go(Routes.coach),
                                  child: Container(
                                    height: 48,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: lp.surface,
                                      borderRadius: BorderRadius.circular(
                                        LpDimens.rInput,
                                      ),
                                      border: Border.all(
                                        color: lp.border,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Text(
                                      l10n.homeOverLimitCoach,
                                      style: LpType.body14(
                                        lp.textPrimary,
                                        weight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          LpNoteCard(l10n.homeOverLimitFooter),
                          const SizedBox(height: 10),
                        ],
                        // Money + cravings bento row.
                        Row(
                          children: [
                            Expanded(
                              child: PressScale(
                                onTap: () => context.push(Routes.money),
                                child: LpCard(
                                  radius: LpDimens.rBento,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      RollingNumber(
                                        snap.savedLifetime,
                                        format: (v) =>
                                            LpFormat.money(v, locale),
                                        style:
                                            LpType.number(
                                              lp.voltText,
                                              size: 26,
                                            ).copyWith(
                                              shadows: [
                                                Shadow(
                                                  color: lp.volt.withValues(
                                                    alpha: 0.4,
                                                  ),
                                                  blurRadius: 18,
                                                ),
                                              ],
                                            ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        l10n.homeSavedSoFar,
                                        style: LpType.caption11(
                                          lp.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: PressScale(
                                onTap: () => context.push(Routes.milestones),
                                child: LpCard(
                                  radius: LpDimens.rBento,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      RollingNumber(
                                        snap.cravingsSurvivedTotal,
                                        style: LpType.number(
                                          lp.textPrimary,
                                          size: 26,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        l10n.homeCravingsBeaten,
                                        style: LpType.caption11(
                                          lp.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Slip-recovery entry, coach nudge, or mood prompt.
                        if (journey.pendingSlipCleanDays != null)
                          _SlipCard(onTap: () => context.push(Routes.slip))
                        else if (showMoodPrompt)
                          _MoodPromptCard(
                            onTap: () => showMoodSheet(context, ref),
                          )
                        // Only once a real danger window exists. "I noticed"
                        // with a hardcoded 3 PM told every day-1 user about a
                        // spike nobody observed — an invented number wearing
                        // the coach's voice.
                        else if (!_nudgeDismissed && snap.dangerWindow != null)
                          Dismissible(
                            key: const ValueKey('nudge'),
                            onDismissed: (_) =>
                                setState(() => _nudgeDismissed = true),
                            child: _CoachNudgeCard(
                              weekday: LpFormat.weekday(snap.now, locale),
                              hour: LpFormat.hour(
                                snap.dangerWindow!.$1,
                                locale,
                              ),
                              onTap: () => context.go(Routes.coach),
                            ),
                          ),
                        const SizedBox(height: 12),
                        // The completion state. Day 30 of 30 used to render
                        // as any other 0-limit day (QA M3).
                        if (snap.isFreedomDay) ...[
                          PressScale(
                            onTap: () => context.push(Routes.plan),
                            child: LpCard(
                              borderColor: lp.ember.withValues(alpha: 0.5),
                              glowColor: lp.ember,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 15,
                              ),
                              child: Row(
                                children: [
                                  const Text(
                                    '🏆',
                                    style: TextStyle(fontSize: 26),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l10n.homeFreedomDayTitle,
                                          style: LpType.body14(
                                            lp.textPrimary,
                                            weight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          l10n.homeFreedomDayBody,
                                          style: LpType.caption(
                                            lp.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (askYesterday) ...[
                          _YesterdayCard(
                            date: LpFormat.mediumDate(yesterdayKey, locale),
                            onVapeFree: () {
                              LpHaptics.celebrate();
                              ref
                                  .read(quitStoreProvider.notifier)
                                  .confirmVapeFreeDay(date: yesterdayKey);
                              showLpSnack(context, l10n.homeYesterdayDone);
                            },
                            onVaped: () => showEditDaySheet(
                              context,
                              ref,
                              yesterdayLog ??
                                  DayLog(
                                    date: yesterdayKey,
                                    puffs: 0,
                                    limit: journey.limitOn(yesterdayKey),
                                  ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (showVapeFree) ...[
                          PressScale(
                            onTap: () {
                              LpHaptics.celebrate();
                              ref
                                  .read(quitStoreProvider.notifier)
                                  .confirmVapeFreeDay();
                              showLpSnack(context, l10n.homeVapeFreeDone);
                            },
                            child: LpCard(
                              borderColor: lp.volt.withValues(alpha: 0.5),
                              glowColor: lp.volt,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 15,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      l10n.homeVapeFreeTitle,
                                      style: LpType.body14(
                                        lp.textPrimary,
                                        weight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    l10n.homeVapeFreeCta,
                                    style: LpType.body13(
                                      lp.voltText,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        // One-time founding offer — the spec's in-app win-back card
                        // (docs/02 §4), shown to Free users until opened.
                        if (showFoundingOffer) ...[
                          PressScale(
                            onTap: () => context.push(Routes.winback),
                            child: LpCard(
                              borderColor: lp.ember.withValues(alpha: 0.45),
                              glowColor: lp.ember,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l10n.winbackBadge,
                                          style: LpType.micro(
                                            lp.emberText,
                                            weight: FontWeight.w700,
                                          ).copyWith(letterSpacing: 1.2),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          l10n.winbackTitle,
                                          style: LpType.body13(
                                            lp.textPrimary,
                                            weight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: lp.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        // Quick links — every lifecycle surface reachable from Today.
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          runSpacing: 6,
                          children: [
                            _QuickLink(
                              label: l10n.planTitle,
                              route: Routes.plan,
                            ),
                            _dot(lp),
                            _QuickLink(
                              label: l10n.healthTitle,
                              route: Routes.health,
                            ),
                            _dot(lp),
                            _QuickLink(
                              label: l10n.moneyTitle,
                              route: Routes.money,
                            ),
                            _dot(lp),
                            _QuickLink(
                              label: l10n.milestonesTitle,
                              route: Routes.milestones,
                            ),
                            _dot(lp),
                            _QuickLink(
                              label: l10n.insightLinkTitle,
                              route: Routes.insight,
                            ),
                          ],
                        ),
                      ],
                    ),
                    // SOS — persistent, never moves (Ember).
                    Positioned(
                      right: 16,
                      bottom: 12,
                      child: PressScale(
                        onTap: () => context.push(Routes.panic),
                        child: Container(
                          width: 54,
                          height: 54,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: lp.ember,
                            boxShadow: lp.emberGlow(blur: 24, opacity: 0.5),
                          ),
                          child: Text(
                            l10n.homeSos,
                            style: LpType.displaySmall(lp.onVolt, size: 11),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // LOG PUFF — pinned in the thumb zone (frame 30), never scrolls.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Day1Spotlight(
                step: Day1TourStep.logPuff,
                title: l10n.day1TourLogTitle,
                description: l10n.day1TourLogBody,
                child: PressScale(
                  onTap: logPuff,
                  onHoldStart: startHold,
                  onHoldEnd: endHold,
                  haptic: false,
                  child: Container(
                    height: LpDimens.ctaHeightHero,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: lp.volt,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: lp.voltGlow(blur: 32, opacity: 0.3),
                    ),
                    child: Text(
                      l10n.homeLogPuff,
                      style: LpType.button(lp.onVolt, size: 19),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(LpColors lp) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Text('·', style: TextStyle(color: lp.textFaint)),
  );
}

class _QuickLink extends ConsumerWidget {
  const _QuickLink({required this.label, required this.route});

  final String label;
  final String route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    return PressScale(
      onTap: () => context.push(route),
      child: Text(
        label,
        style: LpType.caption(lp.textSecondary, weight: FontWeight.w600),
      ),
    );
  }
}

class _CoachNudgeCard extends StatelessWidget {
  const _CoachNudgeCard({
    required this.weekday,
    required this.hour,
    required this.onTap,
  });

  final String weekday;
  final String hour;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    return PressScale(
      onTap: onTap,
      child: LpCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: lp.oxygenSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: lp.oxygen.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Text(
                'AI',
                style: LpType.displaySmall(lp.oxygenText, size: 13),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: '${l10n.homeCoachNudgeTitle(weekday)} ',
                  style: LpType.body13(lp.textPrimary, weight: FontWeight.w600),
                  children: [
                    TextSpan(
                      text: l10n.homeCoachNudgeBody(hour),
                      style: LpType.body13(lp.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: lp.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _MoodPromptCard extends StatelessWidget {
  const _MoodPromptCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    return PressScale(
      onTap: onTap,
      child: LpCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Text('🙂', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.moodTitle,
                style: LpType.body13(lp.textPrimary, weight: FontWeight.w600),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: lp.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// "Was yesterday vape-free?" — the morning-after prompt (QA H4).
///
/// Two answers, both the user's own word: vape-free confirms the day; "I
/// vaped" opens the day editor so the count they enter is the count that
/// stands. No third option that quietly picks for them.
class _YesterdayCard extends StatelessWidget {
  const _YesterdayCard({
    required this.date,
    required this.onVapeFree,
    required this.onVaped,
  });

  final String date;
  final VoidCallback onVapeFree;
  final VoidCallback onVaped;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    return LpCard(
      borderColor: lp.volt.withValues(alpha: 0.5),
      glowColor: lp.volt,
      padding: const EdgeInsets.fromLTRB(18, 15, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.homeYesterdayTitle,
            style: LpType.body14(lp.textPrimary, weight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.homeYesterdayBody(date),
            style: LpType.caption(lp.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: PressScale(
                  onTap: onVapeFree,
                  child: Container(
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: lp.volt,
                      borderRadius: BorderRadius.circular(LpDimens.rChip),
                    ),
                    child: Text(
                      l10n.homeYesterdayYes,
                      style: LpType.body13(lp.onVolt, weight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PressScale(
                  onTap: onVaped,
                  child: Container(
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: lp.surface,
                      borderRadius: BorderRadius.circular(LpDimens.rChip),
                      border: Border.all(color: lp.border, width: 1.5),
                    ),
                    child: Text(
                      l10n.homeYesterdayNo,
                      style: LpType.body13(
                        lp.textPrimary,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SlipCard extends StatelessWidget {
  const _SlipCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    return PressScale(
      onTap: onTap,
      child: LpCard(
        borderColor: lp.ember.withValues(alpha: 0.45),
        glowColor: lp.ember,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Text('🔥', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.slipTitle,
                style: LpType.body13(lp.textPrimary, weight: FontWeight.w600),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: lp.textSecondary),
          ],
        ),
      ),
    );
  }
}
