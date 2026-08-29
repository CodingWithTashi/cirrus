import '../logic/danger_hours.dart';
import '../logic/money_engine.dart';
import '../logic/streak_engine.dart';
import '../logic/taper_engine.dart';
import 'models.dart';

/// Whole-journey aggregate held by the quit store. Immutable.
class JourneyState {
  const JourneyState({
    required this.profile,
    required this.plan,
    required this.days,
    required this.cravingsSurvivedTotal,
    required this.repairTokens,
    required this.longestStreak,
    required this.goals,
    required this.earnedBadges,
    required this.buddy,
    this.lastPuffAt,
    this.day1TasksDone = const {},
    this.pendingSlipCleanDays,
    this.moodCheckIns = 0,
    this.planAdvice,
  });

  final UserProfile profile;
  final QuitPlan plan;

  /// Date-only key → log.
  final Map<DateTime, DayLog> days;
  final int cravingsSurvivedTotal;
  final int repairTokens;
  final int longestStreak;
  final List<SavingsGoal> goals;
  final Set<String> earnedBadges;
  final Buddy buddy;
  final DateTime? lastPuffAt;

  /// Day-1 checklist: which of tasks 1..3 are done.
  final Set<int> day1TasksDone;

  /// Set when an over-limit day awaits the recovery flow; value = clean days
  /// before the slip (for the "after N clean days" copy).
  final int? pendingSlipCleanDays;
  final int moodCheckIns;

  /// The most recent nightly advice the client has accepted (docs/03 §3.3).
  /// Null until `taperRecalc` has produced one, on the fake backend, and for
  /// anyone whose plan has already finished.
  final PlanAdvice? planAdvice;

  static DateTime dateKey(DateTime d) => DateTime(d.year, d.month, d.day);

  DayLog? logFor(DateTime date) => days[dateKey(date)];

  /// The limit in force on [date] — the single answer the whole app reads.
  ///
  /// The raw curve is the floor of this, not the whole of it: the nightly
  /// adaptive layer may bend today's number up (a struggling stretch) or down
  /// (crushing it), and `TodaySnapshot`, `logPuff`'s over-limit test and the
  /// Plan screen must never disagree about which number is live.
  int limitOn(DateTime date) {
    final advice = planAdvice;
    if (advice != null && advice.appliesTo(date)) return advice.limit;
    final d = plan.dayNumber(date).clamp(1, 9999);
    return d <= plan.totalDays ? TaperEngine.limitFor(plan, d) : 0;
  }

  JourneyState copyWith({
    UserProfile? profile,
    QuitPlan? plan,
    Map<DateTime, DayLog>? days,
    int? cravingsSurvivedTotal,
    int? repairTokens,
    int? longestStreak,
    List<SavingsGoal>? goals,
    Set<String>? earnedBadges,
    Buddy? buddy,
    DateTime? lastPuffAt,
    Set<int>? day1TasksDone,
    int? Function()? pendingSlipCleanDays,
    int? moodCheckIns,
    PlanAdvice? Function()? planAdvice,
  }) => JourneyState(
    profile: profile ?? this.profile,
    plan: plan ?? this.plan,
    days: days ?? this.days,
    cravingsSurvivedTotal: cravingsSurvivedTotal ?? this.cravingsSurvivedTotal,
    repairTokens: repairTokens ?? this.repairTokens,
    longestStreak: longestStreak ?? this.longestStreak,
    goals: goals ?? this.goals,
    earnedBadges: earnedBadges ?? this.earnedBadges,
    buddy: buddy ?? this.buddy,
    lastPuffAt: lastPuffAt ?? this.lastPuffAt,
    day1TasksDone: day1TasksDone ?? this.day1TasksDone,
    pendingSlipCleanDays: pendingSlipCleanDays != null
        ? pendingSlipCleanDays()
        : this.pendingSlipCleanDays,
    moodCheckIns: moodCheckIns ?? this.moodCheckIns,
    planAdvice: planAdvice != null ? planAdvice() : this.planAdvice,
  );
}

/// Everything the Today surfaces need, derived once per state change.
/// Pure function of (state, now) — unit-testable without Flutter.
class TodaySnapshot {
  const TodaySnapshot({
    required this.now,
    required this.dayNumber,
    required this.totalDays,
    required this.limit,
    required this.puffs,
    required this.streak,
    required this.flame,
    required this.flameDimmed,
    required this.savedLifetime,
    required this.savedRunRatePerDay,
    required this.puffsNotTaken,
    required this.cravingsSurvivedTotal,
    required this.vsDay1Percent,
    required this.dangerWindow,
    required this.lastPuffAt,
    required this.isOverLimit,
    required this.freedomDate,
  });

  factory TodaySnapshot.of(JourneyState s, DateTime now) {
    final plan = s.plan;
    final day = plan.dayNumber(now).clamp(1, 9999);
    final todayLog = s.logFor(now);
    final limit = s.limitOn(now);
    final streak = StreakEngine.currentStreak(s.days, now);
    final logs = s.days.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final completed = logs
        .where((l) => l.date.isBefore(JourneyState.dateKey(now)))
        .toList();
    int vsDay1 = 0;
    if (completed.length >= 2) {
      final first = completed.first.puffs;
      final latest = completed.last.puffs;
      if (first > 0) vsDay1 = (((latest - first) / first) * 100).round();
    }
    final recent = completed.length > 7
        ? completed.sublist(completed.length - 7)
        : completed;
    return TodaySnapshot(
      now: now,
      dayNumber: day,
      totalDays: plan.totalDays,
      limit: limit,
      puffs: todayLog?.puffs ?? 0,
      streak: streak,
      flame: StreakEngine.flameFor(streak),
      flameDimmed: StreakEngine.isDimmed(todayLog),
      savedLifetime: MoneyEngine.lifetimeSaved(plan, logs),
      savedRunRatePerDay: MoneyEngine.dailyRunRate(plan, recent),
      puffsNotTaken: MoneyEngine.puffsNotTaken(plan, logs),
      cravingsSurvivedTotal: s.cravingsSurvivedTotal,
      vsDay1Percent: vsDay1,
      dangerWindow: DangerHours.window(logs.reversed.take(14)),
      lastPuffAt: s.lastPuffAt,
      isOverLimit: todayLog != null && todayLog.puffs > limit,
      freedomDate: plan.freedomDate,
    );
  }

  final DateTime now;
  final int dayNumber;
  final int totalDays;
  final int limit;
  final int puffs;
  final int streak;
  final FlameState flame;
  final bool flameDimmed;
  final double savedLifetime;
  final double savedRunRatePerDay;
  final int puffsNotTaken;
  final int cravingsSurvivedTotal;

  /// Latest completed day vs day 1, signed percent (negative = down).
  final int vsDay1Percent;

  /// (startHour, endHourExclusive) or null before enough data.
  final (int, int)? dangerWindow;
  final DateTime? lastPuffAt;
  final bool isOverLimit;
  final DateTime freedomDate;

  int get puffsLeft => (limit - puffs).clamp(0, 999999);

  int get daysToFreedom {
    final diff = JourneyState.dateKey(
      freedomDate,
    ).difference(JourneyState.dateKey(now)).inDays;
    return diff < 0 ? 0 : diff;
  }
}
