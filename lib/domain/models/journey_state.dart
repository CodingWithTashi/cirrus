import '../date_key.dart';
import '../logic/danger_hours.dart';
import '../logic/games/game_id.dart';
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
    this.gameBests = const {},
    this.lastGame,
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

  /// Personal best per panic game in one 60-second round; absent until a
  /// round ran to the end. Never seeded, and it only goes up
  /// (`GameScore.beats`).
  final Map<GameId, int> gameBests;

  /// The game the arena opened on last; null until one has been played.
  final GameId? lastGame;

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
    DateTime? Function()? lastPuffAt,
    Set<int>? day1TasksDone,
    bool? day1TourSkipped,
    int? Function()? pendingSlipCleanDays,
    int? moodCheckIns,
    PlanAdvice? Function()? planAdvice,
    Map<GameId, int>? gameBests,
    GameId? lastGame,
  }) => JourneyState(
    profile: profile ?? this.profile,
    plan: plan ?? this.plan,
    days: days ?? this.days,
    cravingsSurvivedTotal: cravingsSurvivedTotal ?? this.cravingsSurvivedTotal,
    repairTokens: repairTokens ?? this.repairTokens,
    longestStreak: longestStreak ?? this.longestStreak,
    goals: goals ?? this.goals,
    earnedBadges: earnedBadges ?? this.earnedBadges,
    // A thunk, like `pendingSlipCleanDays`: taking back the only logged puff
    // leaves no anchor at all, which a plain `??` can never say (docs/10 §41).
    lastPuffAt: lastPuffAt != null ? lastPuffAt() : this.lastPuffAt,
    day1TasksDone: day1TasksDone ?? this.day1TasksDone,
    day1TourSkipped: day1TourSkipped ?? this.day1TourSkipped,
    pendingSlipCleanDays: pendingSlipCleanDays != null
        ? pendingSlipCleanDays()
        : this.pendingSlipCleanDays,
    moodCheckIns: moodCheckIns ?? this.moodCheckIns,
    planAdvice: planAdvice != null ? planAdvice() : this.planAdvice,
    // Plain `??`, not thunks: a best never needs resetting, and the last
    // game only ever moves to another game.
    gameBests: gameBests ?? this.gameBests,
    lastGame: lastGame ?? this.lastGame,
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
    final todayKey = JourneyState.dateKey(now);
    // Days after today are excluded. A log stamped in the future — a device
    // clock that was wrong when a puff was filed — would otherwise be counted
    // as money already saved and puffs already not taken.
    final logs = s.days.values.where((l) => !l.date.isAfter(todayKey)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final completed = logs.where((l) => l.date.isBefore(todayKey)).toList();
    // Plan day one against the latest completed day after it, CONFIRMED days
    // only (docs/10 §41). It compared the first and last logs of any kind, so
    // a skipped yesterday — unlogged, so zero puffs — read "-100% vs day 1".
    // Null when there is nothing honest to compare; never 0, which already
    // means "flat".
    final dayOneKey = JourneyState.dateKey(plan.startDate);
    final dayOne = s.days[dayOneKey];
    final latestAfter = completed
        .where((l) => l.isConfirmed && l.date.isAfter(dayOneKey))
        .lastOrNull;
    final vsDay1 =
        dayOne != null &&
            dayOne.puffs > 0 &&
            dayOne.date.isBefore(todayKey) &&
            latestAfter != null
        ? (((latestAfter.puffs - dayOne.puffs) / dayOne.puffs) * 100).round()
        : null;
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

  /// The latest completed, confirmed day against plan day one, as a signed
  /// percent (negative = down). Null when there is no honest comparison — day
  /// one unlogged or empty, or no confirmed day after it — and never 0 for
  /// that, because 0 already means "flat".
  final int? vsDay1Percent;

  /// (startHour, endHourExclusive) or null before enough data.
  final (int, int)? dangerWindow;
  final DateTime? lastPuffAt;
  final bool isOverLimit;
  final DateTime freedomDate;

  int get puffsLeft => (limit - puffs).clamp(0, 999999);

  /// The plan's last day, the Plan screen's "🏆 Freedom Day", rendered as
  /// the completion it is rather than an ordinary 0-limit day (QA M3).
  bool get isFreedomDay => dayNumber == totalDays;

  /// Past the plan's end: maintenance. "Day N of P" must never show N > P
  /// — Oct 1 of a 30-day September plan is not "Day 31 of 30".
  bool get isMaintenance => dayNumber > totalDays;

  /// Days since Freedom Day, 1 on the first day after it; 0 during the plan.
  int get daysPastPlan => isMaintenance ? dayNumber - totalDays : 0;

  int get daysToFreedom {
    final diff = LpDate.daysBetween(now, freedomDate);
    return diff < 0 ? 0 : diff;
  }
}
