import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/date_key.dart';
import '../../domain/logic/dependence_engine.dart';
import '../../domain/logic/money_engine.dart';
import '../../domain/logic/streak_engine.dart';
import '../../domain/logic/taper_engine.dart';
import '../../domain/models/journey_state.dart';
import '../../domain/models/models.dart';
import '../../domain/analytics/lp_events.dart';
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

  /// Pushes timezone, locale and (later) the push token into the server-owned
  /// user document. Fire-and-forget on purpose: it must never delay a sign-in,
  /// and a miss costs at most one cron cycle.
  ///
  /// It runs after every path that establishes a session because
  /// `users/{uid}` is created here and nowhere else — without it both nightly
  /// crons page over an empty collection and do nothing at all.
  void _syncUserContext() =>
      ref.read(userContextRepositoryProvider).sync().ignore();

  /// Binds analytics to the account.
  ///
  /// Without it every reinstall looks like a brand-new person, so retention
  /// and the onboarding funnel both read low for reasons that are not real.
  /// The sink is captured BEFORE the await — `ref` after an async gap is the
  /// bug this store has been bitten by elsewhere.
  void _identifyForAnalytics() {
    final analytics = ref.read(analyticsProvider);
    _auth
        .currentUserId()
        .then((uid) {
          if (uid != null) analytics.identify(uid);
        })
        .ignore();
  }

  /// Everything a freshly-established session should pull from the server.
  /// One call so a new session path cannot wire half of it.
  void _onSessionEstablished() {
    _syncUserContext();
    pullPlanAdvice();
    _identifyForAnalytics();
  }

  /// Reads the nightly taper verdict from the server-owned user document and
  /// folds it into the journey (docs/03 §3.3).
  ///
  /// Fire-and-forget, and called on every session start and app resume: the
  /// cron writes just after the user's local midnight, so a phone left open
  /// overnight would otherwise run all of the next day on yesterday's curve.
  /// A failure costs one day of adaptation — the raw curve still stands — so
  /// there is nothing here worth a dialog.
  void pullPlanAdvice() {
    ref
        .read(serverStateRepositoryProvider)
        .planAdvice()
        .then((advice) {
          if (advice != null) applyPlanAdvice(advice);
        })
        .ignore();
  }

  /// Folds a server verdict into the local journey.
  ///
  /// Two guards carry the whole correctness of this: advice is applied only
  /// on the day it is FOR (yesterday's verdict must not bend today's limit),
  /// and only once (it is re-read on every launch, and re-applying
  /// `stretchDelta` would push Freedom Day back a day per app open).
  void applyPlanAdvice(PlanAdvice advice) {
    final s = state;
    if (s == null) return;
    if (!advice.appliesTo(_now)) return;
    if (s.planAdvice?.appliesTo(advice.forDay) ?? false) return;
    _commit(
      s.copyWith(
        planAdvice: () => advice,
        // The +50% cap lives in the engine, so client and server agree on the
        // ceiling even if one of them is a build behind.
        plan: advice.stretchDelta > 0
            ? TaperEngine.reflowAfterSlip(
                s.plan,
                extraDays: advice.stretchDelta,
              )
            : s.plan,
      ),
    );
  }

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
      if (restored != null) _onSessionEstablished();
    } on Exception {
      // Offline or backend hiccup at launch — proceed signed out.
    }
  }

  /// Returns true when the account had a journey to restore; false → the
  /// account registered but never onboarded — route to onboarding. Throws
  /// [InvalidCredentialsException] on a wrong password.
  Future<bool> logIn({required String email, required String password}) async {
    final restored = await _auth.signInWithEmail(
      email: email,
      password: password,
    );
    if (restored != null) state = restored;
    _onSessionEstablished();
    return restored != null;
  }

  /// Returns true when the Apple account already had a journey to restore;
  /// false → route to onboarding.
  Future<bool> signInWithApple() async {
    final restored = await _auth.signInWithApple();
    if (restored != null) state = restored;
    _onSessionEstablished();
    return restored != null;
  }

  /// Returns true when the Google account already had a journey to restore;
  /// false → route to onboarding.
  Future<bool> signInWithGoogle() async {
    final restored = await _auth.signInWithGoogle();
    if (restored != null) state = restored;
    _onSessionEstablished();
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
    // Guest onboarding mints an anonymous account here, so this is the first
    // moment that uid exists to sync for.
    _onSessionEstablished();
  }

  /// Optimistic: signed out locally at once, the API ack is write-behind.
  void signOut() {
    state = null;
    // Before the sign-out call, so the identity is unbound even if the ack
    // never lands. On a shared phone the alternative is the next person's
    // events arriving under the last person's user id.
    ref.read(analyticsProvider).reset();
    _auth.signOut().ignore();
  }

  /// Erasure, and the one lifecycle call that is deliberately NOT optimistic.
  ///
  /// Everything else in this store can fail write-behind and be re-synced
  /// later; a deletion that quietly failed leaves the user believing their
  /// data is gone when the server still holds all of it. The caller awaits
  /// this and surfaces the failure — local state only clears once the backend
  /// confirms.
  Future<void> deleteAccount() async {
    await _auth.deleteAccount();
    ref.read(analyticsProvider).reset();
    state = null;
  }

  /// Test-only: installs a journey directly, for the states a public command
  /// cannot reach (a day with no log yet, a mid-plan restart). Named so it is
  /// obvious in a diff that production code has no business calling it.
  @visibleForTesting
  void replaceForTest(JourneyState journey) => _commit(journey);

  /// Frame-map/dev shortcut: seeds the demo journey synchronously (no router
  /// race) and plants it on the fake backend via the write-behind sync.
  void seedDemoJourney() => _commit(SeedData.journey(_now));

  // ---- daily log ------------------------------------------------------------

  void logPuff({DateTime? at}) {
    final s = state;
    if (s == null) return;
    // The north star is Weekly Active Quitters — people who log on 4+ days a
    // week — so this is the one habit-loop event the metric cannot be
    // computed without. Emitted from the store, not the four views that call
    // logPuff, so a new entry point can't ship unmeasured.
    ref.read(analyticsProvider).puffLogged();
    final when = at ?? _now;
    final key = JourneyState.dateKey(when);
    final log =
        s.days[key] ??
        DayLog(date: key, puffs: 0, limit: s.limitOn(when));

    final wasOver = log.puffs > log.limit;
    final buckets = Map<int, int>.from(log.hourBuckets);
    buckets[LpDate.hour(when)] = (buckets[LpDate.hour(when)] ?? 0) + 1;
    var updated = log.copyWith(puffs: log.puffs + 1, hourBuckets: buckets);

    var tokens = s.repairTokens;
    int? pendingSlip = s.pendingSlipCleanDays;
    final nowOver = updated.puffs > updated.limit;
    if (!wasOver && nowOver) {
      // First over-limit puff today: a repair token absorbs it silently
      // (docs/03 §5); with no token the recovery flow arms.
      final streakBefore = StreakEngine.currentStreak(
        s.days,
        LpDate.addDays(when, -1),
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
        LpDate.addDays(when, -1),
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
        // Same reason as adjustPlan: the runway just moved under the advice.
        planAdvice: () => null,
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
        // Last night's verdict was about the plan the user just replaced.
        // Keeping it would show today a limit derived from a curve that no
        // longer exists; tonight's cron produces the first honest one.
        planAdvice: () => null,
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

  /// Sends a chosen coach name to the server guard, then keeps it locally.
  ///
  /// Returns false only on a definite refusal. Offline, a timeout, or any
  /// other wire failure returns TRUE and the name is kept: it is the user's
  /// own private word, rendered to nobody else, so refusing it because a
  /// backend was slow would be the worse outcome. The server-owned copy — the
  /// only one the model ever sees — simply does not get written, so a name
  /// that never passed the guard can never reach a prompt.
  ///
  /// Usable before a journey exists (the onboarding step runs pre-paywall),
  /// which is why the local write is conditional and the callable is not.
  Future<bool> reserveCoachName(String name) async {
    var accepted = true;
    try {
      accepted = await ref.read(coachNameRepositoryProvider).reserve(name);
    } on Object {
      accepted = true;
    }
    if (!accepted) return false;
    final s = state;
    if (s != null) {
      _commit(s.copyWith(profile: s.profile.copyWith(coachName: name)));
    }
    return true;
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

  int _limitToday(JourneyState s) => s.limitOn(_now);

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
    award('comeback', _hasComeback(s));

    return s.copyWith(
      longestStreak: longest,
      repairTokens: tokens,
      earnedBadges: badges,
    );
  }

  /// docs/03 §5 — the Comeback: a day over the limit, then straight back
  /// under it the very next day.
  ///
  /// This badge shipped in the grid and was awarded by nothing. It sat
  /// permanently grey and inflated the "N/17 earned" denominator for
  /// everybody, so the one badge specifically about recovering from a bad day
  /// was itself a small standing reproach.
  ///
  /// "The next day" is the whole point: the promise is that a slip costs you
  /// one day and not the attempt, and a rule that let you claim it a week
  /// later would be describing something else.
  bool _hasComeback(JourneyState s) => s.days.values.any((over) {
    if (!over.isOverLimit || !over.isConfirmed) return false;
    final next = s.days[LpDate.addDays(over.date, 1)];
    return next != null && next.isConfirmed && !next.isOverLimit;
  });

  bool _hasCleanWeekend(JourneyState s) => s.days.values.any((l) {
    if (l.date.weekday != DateTime.saturday) return false;
    final sunday = s.days[LpDate.addDays(l.date, 1)];
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
