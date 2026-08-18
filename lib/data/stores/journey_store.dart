import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/logic/dependence_engine.dart';
import '../../domain/logic/money_engine.dart';
import '../../domain/logic/streak_engine.dart';
import '../../domain/logic/taper_engine.dart';
import '../../domain/models/journey_state.dart';
import '../../domain/models/models.dart';
import '../../domain/repositories/repositories.dart';
import '../seed/seed_data.dart';
import 'providers.dart';

/// View model of the quit journey. Session lifecycle is awaited API work
/// (auth + journey creation); every other mutation is optimistic: applied
/// locally through the engines, then synced write-behind via [_commit] —
/// so views keep reading fresh state synchronously right after a command.
class JourneyStore extends Notifier<JourneyState?> {
  @override
  JourneyState? build() => null;

  JourneyState? get journey => state;

  AuthRepository get _auth => ref.read(authRepositoryProvider);

  JourneyRepository get _journeys => ref.read(journeyRepositoryProvider);

  DateTime get _now => DateTime.now();

  DateTime get _todayKey => JourneyState.dateKey(_now);

  /// Applies a mutation locally and syncs it to the backend write-behind.
  /// A failed save (offline…) is deliberately swallowed: the app is
  /// local-first and the offline banner already tells the story — a real
  /// sync layer with a retry queue slots in here later.
  void _commit(JourneyState next) {
    state = next;
    _journeys.save(next).ignore();
  }

  // ---- session lifecycle (awaited API calls) --------------------------------

  /// Splash-time restore. Never clobbers an already-live journey (the frame
  /// map and tests seed state before navigation), and never blocks launch on
  /// a dead connection — no session restored simply lands on sign-in.
  Future<void> restoreSession() async {
    if (state != null) return;
    try {
      final restored = await _auth.restoreSession();
      if (restored != null && state == null) state = restored;
    } on Exception {
      // Offline or backend hiccup at launch — proceed signed out.
    }
  }

  /// Throws [InvalidCredentialsException] on a wrong password.
  Future<void> logIn({required String email, required String password}) async {
    state = await _auth.signInWithEmail(email: email, password: password);
  }

  /// Returns true when the Apple account already had a journey to restore;
  /// false → route to onboarding.
  Future<bool> signInWithApple() async {
    final restored = await _auth.signInWithApple();
    if (restored != null) state = restored;
    return restored != null;
  }

  /// Throws [EmailAlreadyInUseException].
  Future<void> register({required String email, required String password}) =>
      _auth.register(email: email, password: password);

  Future<void> requestPasswordReset(String email) =>
      _auth.requestPasswordReset(email);

  /// Ends onboarding: the backend creates the journey from the profile+plan.
  Future<void> startJourney({
    required UserProfile profile,
    required QuitPlan plan,
  }) async {
    state = await _journeys.create(profile: profile, plan: plan);
  }

  /// Optimistic: signed out locally at once, the API ack is write-behind.
  void signOut() {
    state = null;
    _auth.signOut().ignore();
  }

  void deleteAccount() {
    state = null;
    _auth.deleteAccount().ignore();
  }

  /// Frame-map/dev shortcut: seeds the demo journey synchronously (no router
  /// race) and plants it on the fake backend via the write-behind sync.
  void seedDemoJourney() => _commit(SeedData.journey(_now));

  // ---- daily log ------------------------------------------------------------

  void logPuff({DateTime? at}) {
    final s = state;
    if (s == null) return;
    final when = at ?? _now;
    final key = JourneyState.dateKey(when);
    final log =
        s.days[key] ??
        DayLog(date: key, puffs: 0, limit: _limitOn(s.plan, when));

    final wasOver = log.puffs > log.limit;
    final buckets = Map<int, int>.from(log.hourBuckets);
    buckets[when.hour] = (buckets[when.hour] ?? 0) + 1;
    var updated = log.copyWith(puffs: log.puffs + 1, hourBuckets: buckets);

    var tokens = s.repairTokens;
    int? pendingSlip = s.pendingSlipCleanDays;
    final nowOver = updated.puffs > updated.limit;
    if (!wasOver && nowOver) {
      // First over-limit puff today: a repair token absorbs it silently
      // (docs/03 §5); with no token the recovery flow arms.
      final streakBefore = StreakEngine.currentStreak(
        s.days,
        when.subtract(const Duration(days: 1)),
      );
      if (tokens > 0) {
        tokens -= 1;
        updated = updated.copyWith(repairTokenUsed: true);
      } else {
        pendingSlip = streakBefore;
      }
    }
    // Big relapse (docs/03 §5): over 2× the line always offers a plan reflow.
    if (updated.limit > 0 && updated.puffs > updated.limit * 2) {
      pendingSlip ??= StreakEngine.currentStreak(
        s.days,
        when.subtract(const Duration(days: 1)),
      );
    }

    _commit(
      _withBadges(
        s.copyWith(
          days: {...s.days, key: updated},
          lastPuffAt: when,
          repairTokens: tokens,
          pendingSlipCleanDays: () => pendingSlip,
          day1TasksDone: {...s.day1TasksDone, 0},
        ),
      ),
    );
  }

  void undoLastPuff() {
    final s = state;
    if (s == null) return;
    final log = s.days[_todayKey];
    if (log == null || log.puffs == 0) return;
    final buckets = Map<int, int>.from(log.hourBuckets);
    final lastHour = buckets.keys.isEmpty
        ? _now.hour
        : buckets.keys.reduce((a, b) => a > b ? a : b);
    if ((buckets[lastHour] ?? 0) > 1) {
      buckets[lastHour] = buckets[lastHour]! - 1;
    } else {
      buckets.remove(lastHour);
    }
    _commit(
      s.copyWith(
        days: {
          ...s.days,
          _todayKey: log.copyWith(puffs: log.puffs - 1, hourBuckets: buckets),
        },
      ),
    );
  }

  void confirmVapeFreeDay() {
    final s = state;
    if (s == null) return;
    final log =
        s.days[_todayKey] ??
        DayLog(date: _todayKey, puffs: 0, limit: _limitToday(s));
    _commit(
      _withBadges(
        s.copyWith(
          days: {...s.days, _todayKey: log.copyWith(vapeFreeConfirmed: true)},
        ),
      ),
    );
  }

  void editPastDay(DateTime date, int puffs) {
    final s = state;
    if (s == null) return;
    final key = JourneyState.dateKey(date);
    final log = s.days[key];
    if (log == null) return;
    _commit(
      _withBadges(
        s.copyWith(
          days: {
            ...s.days,
            key: log.copyWith(puffs: puffs),
          },
        ),
      ),
    );
  }

  // ---- cravings & slips -----------------------------------------------------

  void recordCravingSurvived() {
    final s = state;
    if (s == null) return;
    final log =
        s.days[_todayKey] ??
        DayLog(date: _todayKey, puffs: 0, limit: _limitToday(s));
    _commit(
      _withBadges(
        s.copyWith(
          cravingsSurvivedTotal: s.cravingsSurvivedTotal + 1,
          days: {
            ...s.days,
            _todayKey: log.copyWith(cravingsSurvived: log.cravingsSurvived + 1),
          },
        ),
      ),
    );
  }

  void recordSlipTrigger(SlipTrigger trigger) {
    final s = state;
    if (s == null) return;
    final log = s.days[_todayKey];
    if (log == null) return;
    _commit(
      s.copyWith(
        days: {
          ...s.days,
          _todayKey: log.copyWith(slipTrigger: trigger),
        },
      ),
    );
  }

  void applySlipRecovery() {
    final s = state;
    if (s == null) return;
    _commit(
      s.copyWith(
        plan: TaperEngine.reflowAfterSlip(s.plan),
        pendingSlipCleanDays: () => null,
      ),
    );
  }

  void dismissSlipRecovery() {
    final s = state;
    if (s == null) return;
    _commit(s.copyWith(pendingSlipCleanDays: () => null));
  }

  // ---- mood / goals / plan --------------------------------------------------

  void checkInMood(Mood mood, {String? note}) {
    final s = state;
    if (s == null) return;
    final log =
        s.days[_todayKey] ??
        DayLog(date: _todayKey, puffs: 0, limit: _limitToday(s));
    _commit(
      _withBadges(
        s.copyWith(
          days: {
            ...s.days,
            _todayKey: log.copyWith(mood: mood, moodNote: note),
          },
          moodCheckIns: s.moodCheckIns + 1,
        ),
      ),
    );
  }

  void addGoal(SavingsGoal goal) {
    final s = state;
    if (s == null) return;
    _commit(s.copyWith(goals: [...s.goals, goal]));
  }

  void adjustPlan({QuitMethod? method, int? paceDays}) {
    final s = state;
    if (s == null) return;
    final currentDay = s.plan.dayNumber(_now).clamp(1, 9999);
    // Curve regenerates from today over the new runway; past days keep their
    // recorded limits — no reset, no lost history (docs/03 §11).
    final newPace = paceDays == null
        ? s.plan.paceDays
        : currentDay - 1 + paceDays;
    _commit(
      s.copyWith(
        plan: s.plan.copyWith(
          method: method ?? s.plan.method,
          paceDays: newPace,
          stretchDays: 0,
        ),
      ),
    );
  }

  // ---- misc -----------------------------------------------------------------

  void completeDay1Task(int index) {
    final s = state;
    if (s == null) return;
    _commit(s.copyWith(day1TasksDone: {...s.day1TasksDone, index}));
  }

  void updateAlias(String alias, String avatarEmoji) {
    final s = state;
    if (s == null) return;
    _commit(
      s.copyWith(
        profile: s.profile.copyWith(alias: alias, avatarEmoji: avatarEmoji),
      ),
    );
  }

  void setTier(SubscriptionTier tier) {
    final s = state;
    if (s == null) return;
    _commit(s.copyWith(profile: s.profile.copyWith(tier: tier)));
  }

  /// Awards a badge from another feature (community, buddy…).
  void awardBadge(String id) {
    final s = state;
    if (s == null || s.earnedBadges.contains(id)) return;
    _commit(s.copyWith(earnedBadges: {...s.earnedBadges, id}));
  }

  int _limitToday(JourneyState s) => _limitOn(s.plan, _now);

  /// The curve limit on [when]; 0 once the runway is complete.
  static int _limitOn(QuitPlan plan, DateTime when) {
    final d = plan.dayNumber(when).clamp(1, 9999);
    return d <= plan.totalDays ? TaperEngine.limitFor(plan, d) : 0;
  }

  /// Recomputes streak-derived numbers + auto-earned badges after a mutation.
  JourneyState _withBadges(JourneyState s) {
    final streak = StreakEngine.currentStreak(s.days, _now);
    final longest = streak > s.longestStreak ? streak : s.longestStreak;
    // Repair tokens accrue 1 per 7 streak-days, wallet capped (docs/03 §5).
    final earnedTokens = streak ~/ StreakEngine.tokenEveryDays;
    final tokens = s.repairTokens > earnedTokens
        ? s.repairTokens
        : earnedTokens.clamp(s.repairTokens, StreakEngine.tokenWalletCap);

    final saved = MoneyEngine.lifetimeSaved(s.plan, s.days.values);
    final anyPuffs = s.days.values.any((l) => l.puffs > 0);
    final day = s.plan.dayNumber(_now);

    final badges = {...s.earnedBadges};
    void award(String id, bool condition) {
      if (condition) badges.add(id);
    }

    award('firstLog', anyPuffs);
    award('firstCraving', s.cravingsSurvivedTotal >= 1);
    award('tenCravings', s.cravingsSurvivedTotal >= 10);
    award('spark', streak >= 3);
    award('weekFlame', streak >= 7);
    award('twoWeekFlame', streak >= 14);
    award('inferno', streak >= 30);
    award('hundredSaved', saved >= 100);
    award('fiveHundredSaved', saved >= 500);
    award('moodWeek', s.moodCheckIns >= 7);
    award('quarterCurve', day >= (s.plan.totalDays / 4).ceil() && streak > 0);
    award('cleanWeekend', _hasCleanWeekend(s));
    award('halfNicotine', _isHalfNicotine(s));
    award('freedomDay', day > s.plan.totalDays && streak >= 1);

    return s.copyWith(
      longestStreak: longest,
      repairTokens: tokens,
      earnedBadges: badges,
    );
  }

  bool _hasCleanWeekend(JourneyState s) => s.days.values.any((l) {
    if (l.date.weekday != DateTime.saturday) return false;
    final sunday = s.days[l.date.add(const Duration(days: 1))];
    return !l.isOverLimit &&
        l.isConfirmed &&
        sunday != null &&
        sunday.isConfirmed &&
        !sunday.isOverLimit;
  });

  bool _isHalfNicotine(JourneyState s) {
    final logs = s.days.values.where((l) => l.isConfirmed).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (logs.length < 2) return false;
    final baselineMg = DependenceEngine.nicotineMg(
      s.plan.baselinePuffsPerDay,
      s.plan.strength,
    );
    final latestMg = DependenceEngine.nicotineMg(
      logs[logs.length - 2].puffs,
      s.plan.strength,
    );
    return latestMg <= baselineMg / 2;
  }
}
