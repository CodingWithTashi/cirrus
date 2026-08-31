import '../date_key.dart';
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
    this.lastPuffAt,
    this.day1TasksDone = const {},
    this.day1TourSkipped = false,
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
  final DateTime? lastPuffAt;

  /// Day-1 checklist: which of tasks 1..3 are done.
  ///
  /// Only ever set by the real move — a logged puff, a coach reply that
  /// arrived, a danger hour saved. Never by tapping the row that describes it.
  final Set<int> day1TasksDone;

  /// They chose not to be walked through setup.
  ///
  /// Deliberately separate from [day1TasksDone], and deliberately does NOT
  /// tick anything: skipping means the three moves are still undone and still
  /// available, which is the honest record of what happened. Lives on the
  /// journey rather than in settings so it survives a reinstall the same way
  /// the checklist does.
  final bool day1TourSkipped;

  /// Set when an over-limit day awaits the recovery flow; value = clean days
  /// before the slip (for the "after N clean days" copy).
  final int? pendingSlipCleanDays;
  final int moodCheckIns;

  /// The most recent nightly advice the client has accepted (docs/03 §3.3).
  /// Null until `taperRecalc` has produced one, on the fake backend, and for
  /// anyone whose plan has already finished.
  final PlanAdvice? planAdvice;

  /// Local midnight — the day map's key. Delegates to the one truncation in
  /// the app; the name and its call sites stay put.
  static DateTime dateKey(DateTime d) => LpDate.dayStart(d);

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
    DateTime? lastPuffAt,
    Set<int>? day1TasksDone,
    bool? day1TourSkipped,
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
    lastPuffAt: lastPuffAt ?? this.lastPuffAt,
    day1TasksDone: day1TasksDone ?? this.day1TasksDone,
    day1TourSkipped: day1TourSkipped ?? this.day1TourSkipped,
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
    final diff = LpDate.daysBetween(now, freedomDate);
    return diff < 0 ? 0 : diff;
  }
}
