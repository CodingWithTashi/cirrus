import 'dart:math' as math;

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
import '../../core/widgets/lp_charts.dart';
import '../../core/widgets/lp_premium_gate.dart';
import '../../core/widgets/lp_selectables.dart';
import '../../core/widgets/press_scale.dart';
import '../../data/stores/day1_tour_store.dart';
import '../../data/stores/providers.dart';
import '../day1/day1_spotlight.dart';
import '../settings/danger_hours_sheet.dart';
import 'edit_day_sheet.dart';
import '../../domain/logic/danger_hours.dart';
import '../../domain/date_key.dart';
import '../../domain/logic/allowances.dart';
import '../../domain/logic/day_window.dart';
import '../../domain/logic/nicotine_trend.dart';
import '../../domain/logic/puff_gaps.dart';
import '../../domain/logic/week_trend.dart';
import '../../domain/models/journey_state.dart';
import '../../domain/models/models.dart';

/// Frame 38 — Stats: week bars ("difficult day" in Ember, kindly captioned),
/// trigger-hour heatmap, nicotine trend, personal records. Long-press a bar
/// to fix a day (history is user-ownable, docs/03 §2).
class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  int _range = 1; // 0=day, 1=week, 2=month

  /// The Day chart's height with its hour labels, which the "no puffs today"
  /// line matches so the first puff grows bars in place.
  static const double _dayChartHeight = 89;

  /// The range actually rendered: Month is Premium, so a free account (or
  /// one whose Premium lapsed with Month selected) is clamped to Week.
  int get _shownRange =>
      ref.read(isPremiumProvider) ? _range : math.min(_range, 1);

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    final locale = context.localeTag;
    final journey = ref.watch(quitStoreProvider);
    final snap = ref.watch(todayProvider);
    if (journey == null || snap == null) return const SizedBox.shrink();

    final logs = journey.days.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    // The clock seam, so "what does Stats show on Tue Sep 29 with nothing
    // logged since Sunday" is a widget test.
    final now = snap.now;
    // Free shows the last `LpAllowances.freeHistoryDays`, Premium the whole
    // journey. It went 7 → 30 (docs/12 §4.1: a 7-day window cannot show a
    // 30-day taper working) and back to 7 the same day (docs/12 §5c: Stats is
    // where the product's central question gets answered, so it is the door
    // worth keeping). The number lives in `LpAllowances`, never here. The
    // Month pill and the forecast stay Premium: those are different *views*,
    // not a shorter slice of the same data.
    final premium = ref.watch(isPremiumProvider);
    final historyFloor = LpDate.addDays(
      LpDate.dayStart(now),
      -(LpAllowances.freeHistoryDays - 1),
    );
    final visibleLogs = premium
        ? logs
        : [
            for (final log in logs)
              if (!log.date.isBefore(historyFloor)) log,
          ];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.statsTitle, style: LpType.titleSm(lp.textPrimary)),
                SegmentedPills(
                  labels: [
                    l10n.statsRangeDay,
                    l10n.statsRangeWeek,
                    l10n.statsRangeMonth,
                  ],
                  selectedIndex: _shownRange,
                  onChanged: (i) {
                    // The month view is Premium. The pill stays visible so the
                    // feature is not hidden; tapping it opens the door.
                    if (i == 2 && !premium) {
                      context.push(Routes.paywallFrom('history'));
                      return;
                    }
                    setState(() => _range = i);
                  },
                ),
              ],
            ),
            if (!premium)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  l10n.premiumFreeHistoryNote(LpAllowances.freeHistoryDays),
                  style: LpType.caption11(lp.textFaint),
                ),
              ),
            const SizedBox(height: 14),
            // Every card from day one (docs/10 §40). The screen used to hold
            // all of them behind "at least two days on the books", so a first
            // day with fourteen puffs logged read "Charts show up tomorrow." on
            // the Day view — whose whole subject is today — and on the week,
            // and day two read it again until its first puff. An empty window
            // now says so inside its own card, and the charts move with every
            // tap because they are built from the journey the store just set.
            _puffsCard(context, journey, now, locale),
            const SizedBox(height: 10),
            // The trigger-hours card: the heat is honest with one day of data
            // (today's own hours), tapping it is how the danger window gets
            // set — and it is Day-1 step three's spotlight target, which must
            // exist for a REAL day-1 account and not only for the 12-day demo
            // seed the tests use.
            _triggerHoursCard(context, logs, snap.dangerWindow, locale),
            const SizedBox(height: 10),
            _nicotineCard(context, journey, visibleLogs, now),
            const SizedBox(height: 10),
            // Records are records, not history browsing: a "best day" over
            // seven days would be a wrong number, not a hidden one.
            _recordsRow(context, journey, logs, now),
            const SizedBox(height: 12),
            Center(
              child: Text(
                l10n.statsEditHint,
                style: LpType.caption11(lp.textFaint),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _puffsCard(
    BuildContext context,
    JourneyState journey,
    DateTime now,
    String locale,
  ) {
    final lp = context.lp;
    final l10n = context.l10n;

    final (window, label) = switch (_shownRange) {
      0 => (1, l10n.statsPuffsToday),
      1 => (7, l10n.statsPuffsThisWeek),
      _ => (30, l10n.statsPuffsThisMonth),
    };

    if (_shownRange == 0) {
      // TODAY by hour — `journey.logFor(now)`, never "the last logged day":
      // that drew Sep 27's 10 AM bucket on a Sep 29 with no puffs (QA L7).
      // Long-press opens today's editor, which is what the caption under the
      // cards promises for every bar.
      final today =
          journey.logFor(now) ??
          DayLog(date: JourneyState.dateKey(now), puffs: 0, limit: 0);
      final buckets = today.hourBuckets;
      // The whole calendar day, midnight first, in three-hour buckets. It was
      // 6 AM to midnight in twos, so a puff logged at 2:30 AM counted in
      // today's total and was drawn nowhere (docs/10 §40). Eight buckets is
      // also what fits eight hour labels — the same eight the trigger-hours
      // heatmap prints under this card.
      final starts = [for (var h = 0; h < 24; h += 3) h];
      return GestureDetector(
        onLongPress: () {
          LpHaptics.medium();
          showEditDaySheet(context, ref, today);
        },
        child: LpCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionLabel(label, padding: const EdgeInsets.only(bottom: 12)),
              if (today.puffs == 0)
                // Nothing logged today: a sentence, not eight slivers that
                // read as a chart of zeros.
                _NoPuffs(l10n.statsDayNoPuffs, height: _dayChartHeight)
              else
                BarChart(
                  values: [
                    for (final h in starts)
                      (buckets[h] ?? 0) +
                          (buckets[h + 1] ?? 0) +
                          (buckets[h + 2] ?? 0),
                  ],
                  labels: [for (final h in starts) LpFormat.hour(h, locale)],
                  height: 70,
                  gap: 8,
                  // With every puff in one bucket that bar is already full
                  // height; its number is what shows the next puff land.
                  showValues: true,
                ),
            ],
          ),
        ),
      );
    }

    // Calendar days ending TODAY (QA M1): an unlogged day is an empty bar
    // that can still be long-pressed and fixed, never a hole that slides the
    // whole chart back into last week.
    final shown = DayWindow.trailing(journey, now, window);
    // The hard day is the most puffs among days that had any; the best day
    // is the fewest among days the user actually confirmed. An empty day is
    // neither — it is not a win nobody logged. The same two rules the coach's
    // week card reads, from the one engine.
    final hardest = WeekTrend.hardestIndex(shown);
    final best = WeekTrend.bestIndex(shown, now);

    // Percent vs the previous equal-length window, over confirmed days only
    // — unlogged days are unknown, not zero. The engine answers null when
    // there is nothing honest to say, and the pill below is simply not built.
    // Shared with the watch's week card so the two can never disagree.
    final vsLast = WeekTrend.vsPrevious(
      shown,
      DayWindow.previous(journey, now, window),
    );

    return LpCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SectionLabel(label, padding: EdgeInsets.zero),
              if (vsLast != null)
                Text(
                  l10n.statsVsLast(LpFormat.signedPercent(vsLast)),
                  style: LpType.caption(
                    vsLast <= 0 ? lp.voltText : lp.emberText,
                    weight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _EditableBars(
            logs: shown,
            slots: window,
            hardest: hardest,
            best: best,
            locale: locale,
            compact: _shownRange == 2,
          ),
          const SizedBox(height: 8),
          Text(
            hardest == -1
                ? l10n.statsWindowNoPuffs
                : _hardDayCaption(context, shown, hardest, now, locale),
            style: LpType.caption11(lp.textSecondary),
          ),
        ],
      ),
    );
  }

  /// The line under the bars about the day with the most puffs.
  ///
  /// It used to end "You recovered next morning." whatever the next morning
  /// held — including when the hard day was TODAY, which on day one it always
  /// is, so a first-day account was told it had recovered from a day still in
  /// progress (docs/10 §40). The claim is made only when the next day is over,
  /// confirmed and lighter ([WeekTrend.recoveredAfter]).
  String _hardDayCaption(
    BuildContext context,
    List<DayLog> shown,
    int hardest,
    DateTime now,
    String locale,
  ) {
    final l10n = context.l10n;
    final day = shown[hardest];
    // No note, no rough mood — drop the dash clause entirely.
    final reason =
        day.moodNote ?? (day.mood == Mood.rough ? l10n.moodRough : null);
    if (!day.date.isBefore(LpDate.dayStart(now))) {
      return reason == null
          ? l10n.statsHardDayToday
          : l10n.statsHardDayTodayReason(reason);
    }
    final weekday = LpFormat.weekday(day.date, locale);
    if (WeekTrend.recoveredAfter(shown, hardest, now)) {
      return reason == null
          ? l10n.statsHardDayCaptionPlain(weekday)
          : l10n.statsHardDayCaption(weekday, reason);
    }
    return reason == null
        ? l10n.statsHardDayNoRecovery(weekday)
        : l10n.statsHardDayNoRecoveryReason(weekday, reason);
  }

  Widget _triggerHoursCard(
    BuildContext context,
    List<DayLog> logs,
    (int, int)? window,
    String locale,
  ) {
    final lp = context.lp;
    final l10n = context.l10n;
    final heat = DangerHours.heat(logs.reversed.take(14));
    final buckets = [for (var h = 6; h < 30; h += 3) h % 24];
    double bucketHeat(int start) {
      var max = 0.0;
      for (var h = start; h < start + 3; h++) {
        final v = heat[h % 24] ?? 0;
        if (v > max) max = v;
      }
      return max;
    }

    final forecast = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HourHeatmap(
          heat: [for (final b in buckets) bucketHeat(b)],
          labels: [for (final b in buckets) LpFormat.hour(b, locale)],
        ),
        if (window != null) ...[
          const SizedBox(height: 8),
          Text(
            l10n.statsDangerWindow(
              '${LpFormat.hour(window.$1, locale)}–${LpFormat.hour(window.$2 % 24, locale)}',
            ),
            style: LpType.caption11(lp.textSecondary),
          ),
        ],
      ],
    );

    // Frame 38: tapping the heatmap opens the danger-hours editor.
    //
    // Also Day-1 step three's target. This card rather than the Settings row
    // that opens the same sheet: it is a shell tab (so the tour never has to
    // push a route out of itself), it is a full-width target, and the
    // Settings row is a `ListView` child that may not even be on screen.
    return Day1Spotlight(
      step: Day1TourStep.dangerHours,
      title: l10n.day1TourHoursTitle,
      description: l10n.day1TourHoursBody,
      child: PressScale(
        onTap: () => showDangerHoursSheet(context, ref),
        child: LpCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionLabel(l10n.statsTriggerHours),
              // The forecast — a window worth a nudge — is Premium (docs/01
              // §10). Before one exists (day 1, the tour's target) the heatmap
              // is only the day's shape and stays open to everyone.
              if (window != null && !ref.watch(isPremiumProvider))
                LpPremiumGate(
                  source: 'forecast',
                  pitch: l10n.premiumPitchForecast,
                  compact: true,
                  child: forecast,
                )
              else
                forecast,
            ],
          ),
        ),
      ),
    );
  }

  Widget _nicotineCard(
    BuildContext context,
    JourneyState journey,
    List<DayLog> logs,
    DateTime now,
  ) {
    final lp = context.lp;
    final l10n = context.l10n;
    // Completed, confirmed days only, and an arrow only when two of them say
    // which way it went (docs/10 §41). The card printed "≈ 14mg ↓" with the
    // arrow inside the string — pointing down beside a line that climbed —
    // named the day before yesterday on any morning before the first puff,
    // and dropped its line to zero for every day nobody logged.
    final trend = NicotineTrend.of(logs, journey.plan.strength, now);
    final latest = trend.latestMg;
    final direction = trend.direction;
    final down = direction == TrendDirection.down;

    return LpCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SectionLabel(l10n.statsNicotinePerDay, padding: EdgeInsets.zero),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    latest == null
                        ? '—'
                        : '≈ ${l10n.statsNicotineValue(latest.round())}',
                    style: LpType.displaySmall(lp.textPrimary, size: 14),
                  ),
                  if (direction == TrendDirection.down ||
                      direction == TrendDirection.up) ...[
                    const SizedBox(width: 4),
                    Icon(
                      down
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                      size: 15,
                      color: down ? lp.voltText : lp.emberText,
                      semanticLabel: down
                          ? l10n.statsNicotineDown
                          : l10n.statsNicotineUp,
                    ),
                  ],
                ],
              ),
            ],
          ),
          // A trend needs two points; before that the card is the figure alone
          // rather than a blank strip where a line would be.
          if (trend.series.length >= 2) ...[
            const SizedBox(height: 10),
            TrendLine(values: trend.series),
          ],
        ],
      ),
    );
  }

  Widget _recordsRow(
    BuildContext context,
    JourneyState journey,
    List<DayLog> logs,
    DateTime now,
  ) {
    final lp = context.lp;
    final l10n = context.l10n;
    // Records are about days the user actually lived through and confirmed:
    // a completed day, logged or confirmed vape-free. The unconfirmed 0-puff
    // log every account is minted with (and any a mood check-in mints) used
    // to read as "best day 0" — a win nobody had. With nothing to show, the
    // cell says so rather than showing a zero.
    final today = JourneyState.dateKey(now);
    final best = logs
        .where((l) => l.isConfirmed && l.date.isBefore(today))
        .fold<int?>(
          null,
          (min, l) => min == null || l.puffs < min ? l.puffs : min,
        );
    // The real longest stretch without a puff, from the hour buckets. It was
    // `8 + longestStreak ~/ 2` — a fabricated number rendered as a record.
    final longestGapH = PuffGaps.longestGapHours(journey, now);

    Widget cell(String value, String label) => Expanded(
      child: LpCard(
        subtle: true,
        radius: 12,
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Column(
          children: [
            Text(value, style: LpType.number(lp.emberText, size: 17)),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: LpType.micro(lp.textSecondary),
            ),
          ],
        ),
      ),
    );

    return Row(
      children: [
        cell(longestGapH == null ? '—' : '${longestGapH}h', l10n.statsLongestGap),
        const SizedBox(width: 8),
        cell(best == null ? '—' : '$best', l10n.statsBestDay),
        const SizedBox(width: 8),
        cell('${journey.cravingsSurvivedTotal}', l10n.statsCravingsBeaten),
      ],
    );
  }
}

/// A chart area with nothing to draw, saying so at the height of the chart it
/// stands in for.
class _NoPuffs extends StatelessWidget {
  const _NoPuffs(this.text, {required this.height});

  final String text;
  final double height;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_rounded, size: 22, color: lp.textFaint),
          const SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            style: LpType.body13(lp.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Bars with long-press-to-edit (stepper sheet, min 0).
///
/// Always [slots] columns — seven for the week, thirty for the month — so a
/// bar is as wide on day one as on day ninety. It used to be one `Expanded`
/// column per day in the window, and a young plan's window is only as long as
/// the plan (`DayWindow.trailing`), so day two drew two slabs half the card
/// wide and day one a single slab across all of it (docs/10 §40). The days a
/// young plan's window has not reached yet hold their place as a faint mark
/// with nothing to press, and no bar is ever wider than [_barWidth].
class _EditableBars extends ConsumerWidget {
  const _EditableBars({
    required this.logs,
    required this.slots,
    required this.hardest,
    required this.best,
    required this.locale,
    this.compact = false,
  });

  final List<DayLog> logs;
  final int slots;
  final int hardest;
  final int best;
  final String locale;
  final bool compact;

  /// Wide enough to read as a bar, never as a slab.
  static const double _barWidth = 26;
  static const double _compactBarWidth = 9;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final maxPuffs = logs.fold(1, (m, l) => l.puffs > m ? l.puffs : m);
    final gap = compact ? 3.0 : 7.0;
    final barWidth = compact ? _compactBarWidth : _barWidth;
    // The window ends today, so what a young plan's window is missing is the
    // days still to come.
    final upcoming = [
      if (logs.isNotEmpty)
        for (var i = 1; i <= slots - logs.length; i++)
          LpDate.addDays(logs.last.date, i),
    ];

    Widget weekday(DateTime date, Color color, {bool strong = false}) => Text(
      LpFormat.weekday(date, locale).characters.first.toUpperCase(),
      style: LpType.micro(
        color,
        weight: strong ? FontWeight.w600 : FontWeight.w400,
      ),
    );

    return SizedBox(
      height: compact ? 96 : 112,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (i, log) in logs.indexed) ...[
            if (i > 0) SizedBox(width: gap),
            Expanded(
              child: GestureDetector(
                // The whole column, not just the painted bar: an empty day
                // is a 4%-tall sliver, and the day you most need to fix is
                // the one with nothing on it (QA H4's repair path).
                behavior: HitTestBehavior.opaque,
                onLongPress: () {
                  LpHaptics.medium();
                  showEditDaySheet(context, ref, log);
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: _Bar(
                        log: log,
                        fraction: (log.puffs / maxPuffs).clamp(0.04, 1.0),
                        width: barWidth,
                        color: i == hardest
                            ? lp.ember
                            : i == best
                            ? lp.volt
                            : lp.border,
                        glow: i == hardest
                            ? lp.ember.withValues(alpha: 0.4)
                            : i == best
                            ? lp.volt.withValues(alpha: 0.5)
                            : null,
                        countColor: i == hardest
                            ? lp.emberText
                            : i == best
                            ? lp.voltText
                            : lp.textSecondary,
                        showCount: !compact,
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 5),
                      weekday(
                        log.date,
                        i == hardest
                            ? lp.emberText
                            : i == best
                            ? lp.voltText
                            : lp.textSecondary,
                        strong: i == hardest || i == best,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          for (final date in upcoming) ...[
            SizedBox(width: gap),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: barWidth,
                    height: 3,
                    decoration: BoxDecoration(
                      color: lp.border.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 5),
                    weekday(date, lp.textFaint),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One day's bar, with its count riding just above it.
///
/// Animated from where it stood, so logging a puff grows the bar rather than
/// snapping it. The count lives in headroom reserved above the tallest bar,
/// so it never runs into the card's edge.
class _Bar extends StatelessWidget {
  const _Bar({
    required this.log,
    required this.fraction,
    required this.width,
    required this.color,
    required this.glow,
    required this.countColor,
    required this.showCount,
  });

  final DayLog log;
  final double fraction;
  final double width;
  final Color color;
  final Color? glow;
  final Color countColor;
  final bool showCount;

  static const double _countHeight = 14;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final track = math.max(
          0.0,
          box.maxHeight - (showCount ? _countHeight : 0),
        );
        return TweenAnimationBuilder<double>(
          // An explicit begin, or the first build never animates (CLAUDE.md).
          tween: Tween(begin: 0.04, end: fraction),
          duration: LpMotion.slow,
          curve: LpMotion.ease,
          builder: (context, t, _) => Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: track,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    width: width,
                    child: FractionallySizedBox(
                      // Keyed by the day, so a test can read the bar a
                      // calendar day is drawn as.
                      key: ValueKey(log.date),
                      heightFactor: t,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(5),
                          boxShadow: glow == null
                              ? null
                              : [BoxShadow(color: glow!, blurRadius: 10)],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // A confirmed vape-free day shows its 0 — a win, not a blank.
              // An unlogged day shows nothing: it is unknown, not zero.
              if (showCount && (log.puffs > 0 || log.isConfirmed))
                Positioned(
                  left: -4,
                  right: -4,
                  bottom: track * t + 2,
                  child: Text(
                    '${log.puffs}',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: LpType.micro(countColor, weight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
