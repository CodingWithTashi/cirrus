import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/date_key.dart';
import '../../domain/logic/dependence_engine.dart';
import '../../domain/logic/games/game_id.dart';
import '../../domain/logic/games/game_score.dart';
import '../../domain/logic/money_engine.dart';
import '../../domain/logic/streak_engine.dart';
import '../../domain/logic/taper_engine.dart';
import '../../domain/models/journey_state.dart';
import '../../domain/models/models.dart';
import '../../domain/analytics/lp_events.dart';
import '../../domain/repositories/repositories.dart';
import '../seed/seed_data.dart';
import 'pending_puffs.dart';
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

  /// FCM rotated the device token. Re-register it — but only for a session
  /// that exists. FCM mints a token on a fresh install before anyone has
  /// signed in, and re-registering that one burned a refused callable on
  /// every sessionless cold launch (`syncUserContext failed —
  /// InvalidCredentialsException`, QA L6). The store is the one place that
  /// knows whether there is anyone to sync for.
  void onPushTokenRefreshed(String token) {
    if (state == null) return;
    ref.read(userContextRepositoryProvider).sync(fcmToken: token).ignore();
  }

  /// Binds the store identity to the account, so a purchase is filed under
  /// the same uid the server's entitlement mirror is keyed by. Same shape as
  /// [_identifyForAnalytics], for the same reason: the notifier is captured
  /// before the await.
  void _bindBilling() {
    final billing = ref.read(entitlementProvider.notifier);
    _auth.currentUserId().then(billing.bindSession).ignore();
  }

  /// Everything a freshly-established session should pull from the server.
  /// One call so a new session path cannot wire half of it.
  void _onSessionEstablished() {
    _syncUserContext();
    pullPlanAdvice();
    _identifyForAnalytics();
    _bindBilling();
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

  /// The clock, through the seam — so "what does this do on day 22 of a
  /// 30-day plan" is a test that advances a provider, not a 22-day wait.
  DateTime get _now => ref.read(nowProvider)();

  DateTime get _todayKey => JourneyState.dateKey(_now);

  /// True while [applyPendingPuffs] is replaying a batch, so the individual
  /// mutations update state without each issuing its own document write.
  bool _batching = false;

  /// Applies a mutation locally and syncs it to the backend write-behind.
  /// A failed save (offline…) is deliberately swallowed: the app is
  /// local-first and the offline banner already tells the story — a real
  /// sync layer with a retry queue slots in here later.
  void _commit(JourneyState next) {
    state = next;
    if (_batching) return;
    _journeys.save(next).ignore();
  }

  /// Replays puffs logged on the home-screen widget while the app was closed.
  ///
  /// Returns the highest sequence applied, which is what the caller publishes
  /// as the outbox cursor. Zero means nothing was applied and the cursor must
  /// not move.
  ///
  /// **One write, not one per event.** Each event still goes through
  /// [logPuff]/[undoPuffs] so that every per-puff transition — the over-limit
  /// crossing, the derived repair-token wallet, the slip arming, the 2×
  /// reflow — fires exactly as it would have in-app. But `_commit`'s write is
  /// held back until the end. Twelve events would otherwise be twelve
  /// unordered fire-and-forget whole-document `set()`s of strictly superseded
  /// states, eleven of them pure waste and any one of them the last thing the
  /// server sees if the app dies mid-drain.
  ///
  /// **The save is deliberately not awaited.** Firestore's write future
  /// completes on *server* ack, so awaiting it would hang for the whole of an
  /// offline session — and a cursor that waits for that ack never advances,
  /// which is precisely how the next launch double-counts. What makes
  /// "called" as good as "landed" is that the SDK's own mutation queue is
  /// durable and replays across a restart.
  ///
  /// Analytics stays one event per tap: `logPuff` counts logging behaviour,
  /// and twelve widget taps are twelve taps.
  Future<int> applyPendingPuffs(
    List<PendingPuff> events, {
    required DateTime now,
  }) async {
    final before = state;
    if (before == null || events.isEmpty) return 0;

    var highest = 0;
    _batching = true;
    try {
      for (final event in events) {
        // A stamp in the future is a clock that was wrong when the tap
        // happened — an NTP correction, or a timezone the device has since
        // left. Clamped, because the alternative is `logPuff(at:)` minting a
        // day log for a day that has not happened, which then sits in the map
        // as a confirmed day and can hand out a streak nobody lived.
        final at = event.at.isAfter(now) ? now : event.at;
        if (event.delta > 0) {
          logPuff(at: at);
        } else {
          undoPuffs(1, at: at);
        }
        if (event.seq > highest) highest = event.seq;
      }
    } finally {
      _batching = false;
    }

    final next = state;
    // `undoPuffs` no-ops on a day it cannot find, so a batch of only those
    // leaves state untouched and has nothing to persist — but the events were
    // still consumed, so the cursor still moves.
    if (next == null || identical(next, before)) return highest;

    // The write is awaited, and the THREE outcomes are deliberately not the
    // same thing:
    //
    // * it completes — the server has it. Advance.
    // * it times out — almost certainly offline. Firestore's own mutation
    //   queue is durable from the moment `set()` is called and replays across
    //   a restart, so the puffs are safe. Advance, because a cursor that waits
    //   for a server ack never advances offline, and the next launch would
    //   replay the same events on top of a journey that already has them.
    // * it THROWS — refused outright, most likely no signed-in account. The
    //   puffs exist only in this process's memory and a cold start would
    //   reload a journey that never received them. Do NOT advance: the events
    //   stay queued and the next drain tries again.
    final write = _journeys.save(next);
    // Attaches a swallowing listener so a late failure cannot surface as an
    // unhandled async error once the timeout below has stopped listening. The
    // `await` below registers its own listener and still sees the error.
    write.ignore();
    try {
      await write.timeout(widgetFlushTimeout);
    } on TimeoutException {
      // Queued durably. Nothing to do.
    } on Object {
      // Refused. Put the journey back exactly as it was, so that memory, the
      // cursor and the backend all agree that nothing happened — otherwise the
      // events stay queued (correct) on top of a state that has already
      // applied them (wrong), and the next drain counts every one of them
      // twice. The batch is all-or-nothing.
      state = before;
      return 0;
    }
    return highest;
  }

  /// How long a drain waits for the backend before assuming the write is
  /// queued rather than refused. Short: it runs on the launch path.
  static const Duration widgetFlushTimeout = Duration(seconds: 3);

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
  ///
  /// Establishes a session like every other path here, so it syncs like every
  /// other path here. It did not, and that was the whole reason a freshly
  /// registered account had NOTHING in Firestore: `users/{uid}` is written by
  /// `syncUserContext` and nowhere else, so an account that registered and
  /// stopped before the paywall was invisible to the server — no timezone, no
  /// locale, no `recalcHourUtc`, no device row. Both nightly crons skipped it,
  /// and nothing could push to it, including the nudge that would bring the
  /// user back to finish.
  ///
  /// After the await, never before: a refused registration is not a session,
  /// and syncing for one would create a row for a uid that does not exist.
  Future<void> register({
    required String email,
    required String password,
  }) async {
    await _auth.register(email: email, password: password);
    _onSessionEstablished();
  }

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
    // events arriving under the last person's user id — and, for billing,
    // the next person inheriting the last one's Premium.
    ref.read(analyticsProvider).reset();
    ref.read(entitlementProvider.notifier).unbind().ignore();
    // Release the push registration BEFORE the credential goes, and chain the
    // two rather than firing both: `syncUserContext` is a callable, so it
    // carries the caller's ID token, and a release that raced past
    // `_auth.signOut()` would arrive unauthenticated and do nothing at all.
    // Exactly the same shared-phone case as the analytics reset above — this
    // one is the pushes rather than the events.
    //
    // `unregister()` is bounded and never throws, so `whenComplete` always
    // runs and the sign-out cannot be held up by a slow backend.
    ref
        .read(userContextRepositoryProvider)
        .unregister()
        .whenComplete(() => _auth.signOut().ignore())
        .ignore();
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
    ref.read(entitlementProvider.notifier).unbind().ignore();
    // The server side of the push registry died with `recursiveDelete`; this
    // is the local half — without it the device keeps a live FCM token bound
    // to an account that no longer exists. After the await on purpose: a
    // refused deletion must not silence the account it failed to delete. The
    // release callable inside will fail (no session any more) and is
    // swallowed; the `deleteToken` is the part that matters.
    ref.read(userContextRepositoryProvider).unregister().ignore();
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

  /// [count] > 1 is one tap of the accelerating quick-log worth several
  /// puffs. The over-limit transition below is applied puff by puff, so a
  /// burst that crosses the line mid-count burns the repair token (or arms
  /// the slip flow) on exactly the puff that crossed, same as [count] calls.
  void logPuff({DateTime? at, int count = 1}) {
    final s = state;
    if (s == null) return;
    // The north star is Weekly Active Quitters — people who log on 4+ days a
    // week — so this is the one habit-loop event the metric cannot be
    // computed without. Emitted from the store, not the four views that call
    // logPuff, so a new entry point can't ship unmeasured. Once per tap, not
    // per puff: the metric counts logging behaviour, not inventory.
    ref.read(analyticsProvider).puffLogged();
    // The first puff ever logged also ticks Day-1 task zero below, whether or
    // not the checklist was the thing that sent them here.
    _reportDay1Task(s, 0);
    final when = at ?? _now;
    final key = JourneyState.dateKey(when);
    var updated =
        s.days[key] ??
        DayLog(date: key, puffs: 0, limit: s.limitOn(when));

    int? pendingSlip = s.pendingSlipCleanDays;
    for (var i = 0; i < count; i++) {
      final wasOver = updated.puffs > updated.limit;
      final buckets = Map<int, int>.from(updated.hourBuckets);
      buckets[LpDate.hour(when)] = (buckets[LpDate.hour(when)] ?? 0) + 1;
      updated = updated.copyWith(
        puffs: updated.puffs + 1,
        hourBuckets: buckets,
      );

      final nowOver = updated.puffs > updated.limit;
      // First over-limit puff today: a repair token absorbs it silently
      // (docs/03 §5); with no token the recovery flow arms. A day that
      // already burned its token is already absorbed — an undo back under
      // the line and a second crossing is the same slip, not a new one, so
      // it must neither spend again nor arm recovery.
      if (!wasOver && nowOver && !updated.repairTokenUsed) {
        //
        // The wallet is DERIVED from history at the moment of crossing,
        // never read from the stored number. Stored, it was re-minted on
        // every commit and absorbed four slips off a two-token wallet (QA
        // H2). Only completed days fund it, so today's own puffs cannot mint
        // the token that then absorbs them.
        final wallet = StreakEngine.repairTokens(s.days, when);
        if (wallet > 0) {
          updated = updated.copyWith(repairTokenUsed: true);
        } else {
          pendingSlip = StreakEngine.currentStreak(
            s.days,
            LpDate.addDays(when, -1),
          );
        }
      }
    }
    // Big relapse (docs/03 §5): over 2× the line always offers a plan reflow.
    if (updated.limit > 0 && updated.puffs > updated.limit * 2) {
      pendingSlip ??= StreakEngine.currentStreak(
        s.days,
        LpDate.addDays(when, -1),
      );
    }

    // The anchor only ever moves FORWARD. Every in-app caller passes `at:
    // null`, so `when` is now and this is a no-op for them — but a puff
    // logged from the home-screen widget is drained hours later, and applying
    // a 23:50 event at 09:00 the next morning would drag the anchor
    // backwards. The whole health timeline is measured from it (docs/03 §6),
    // so that would silently rewind every recovery node the user had earned.
    final anchor = s.lastPuffAt;
    final lastPuff = anchor == null || when.isAfter(anchor) ? when : anchor;

    _commit(
      _withBadges(
        s.copyWith(
          days: {...s.days, key: updated},
          lastPuffAt: lastPuff,
          pendingSlipCleanDays: () => pendingSlip,
          day1TasksDone: {...s.day1TasksDone, 0},
        ),
      ),
    );
  }

  void undoLastPuff() => undoPuffs(1);

  /// Takes back the last [count] puffs of [at]'s day — today by default, which
  /// is the undo for a quick-log burst, so the snack's single Undo reverses
  /// everything the burst logged. Clamped to what that day actually holds;
  /// buckets drain newest-hour-first, mirroring how logPuff filled them.
  ///
  /// [at] exists for the same reason it does on [logPuff]: a `−` tapped on the
  /// home-screen widget at 23:58 and drained at 00:04 must take a puff off
  /// *yesterday*. Without it the correction would land on today and corrupt
  /// two days at once — the day that keeps a puff it did not have, and the day
  /// that loses one it did. Every in-app caller omits it and is unaffected.
  void undoPuffs(int count, {DateTime? at}) {
    final s = state;
    if (s == null) return;
    final when = at ?? _now;
    final key = JourneyState.dateKey(when);
    final log = s.days[key];
    if (log == null || log.puffs == 0) return;
    final buckets = Map<int, int>.from(log.hourBuckets);
    var remaining = count.clamp(0, log.puffs);
    final removed = remaining;
    while (remaining > 0) {
      final lastHour = buckets.keys.isEmpty
          ? LpDate.hour(when)
          : buckets.keys.reduce((a, b) => a > b ? a : b);
      if ((buckets[lastHour] ?? 0) > 1) {
        buckets[lastHour] = buckets[lastHour]! - 1;
      } else {
        buckets.remove(lastHour);
      }
      remaining--;
    }
    _commit(
      s.copyWith(
        days: {
          ...s.days,
          key: log.copyWith(
            puffs: log.puffs - removed,
            hourBuckets: buckets,
          ),
        },
      ),
    );
  }

  /// Marks [date] — today by default — as a confirmed vape-free day.
  ///
  /// Takes a date because of the morning after: an unconfirmed day breaks
  /// the chain, and the one person who knows whether it was vape-free is the
  /// user, so Home ASKS about yesterday rather than assuming either way (QA
  /// H4: a perfect 0-limit day nobody confirmed zeroed a 21-day streak with
  /// no notice). Creates the log when the day has none; never invents puffs.
  void confirmVapeFreeDay({DateTime? date}) {
    final s = state;
    if (s == null) return;
    final key = JourneyState.dateKey(date ?? _now);
    final log =
        s.days[key] ?? DayLog(date: key, puffs: 0, limit: s.limitOn(key));
    _commit(
      _withBadges(
        s.copyWith(
          days: {...s.days, key: log.copyWith(vapeFreeConfirmed: true)},
        ),
      ),
    );
  }

  /// Sets today's count to [target] — the correction path for "I logged too
  /// many" after the undo snack is gone. Decreases go through [undoPuffs] so
  /// the hour buckets drain honestly; increases go through [logPuff] so a
  /// late catch-up still moves lastPuffAt and hits the over-limit
  /// transitions, exactly as the missed taps would have. Past days use
  /// [editPastDay]; today's log is live data, not history.
  void adjustToday(int target) {
    final s = state;
    if (s == null || target < 0) return;
    final current = s.days[_todayKey]?.puffs ?? 0;
    if (target > current) {
      logPuff(count: target - current);
    } else if (target < current) {
      undoPuffs(current - target);
    }
  }

  void editPastDay(DateTime date, int puffs) {
    final s = state;
    if (s == null || puffs < 0) return;
    final key = JourneyState.dateKey(date);
    // A day with no log yet is still the user's to fill in — the
    // morning-after prompt's "I vaped" lands here, and so does a long-press
    // on an empty Stats bar. It used to return early, which is why neither
    // repair path in QA H4 could reach an unlogged day. The limit is what the
    // plan said that day.
    final log =
        s.days[key] ?? DayLog(date: key, puffs: 0, limit: s.limitOn(key));
    _commit(
      _withBadges(
        s.copyWith(
          days: {
            ...s.days,
            key: log.copyWith(
              puffs: puffs,
              // Typing 0 for a past day is the user's own word that it was
              // vape-free — the sheet asked for a count and they gave one.
              // Left unconfirmed, correcting a mis-tap down to zero would
              // silently break the chain it was meant to repair.
              vapeFreeConfirmed: puffs == 0 ? true : log.vapeFreeConfirmed,
            ),
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

  /// A round of [id] ended with [score]. Returns true when that is a new
  /// best for the game (zero never is) and records it; either way the game
  /// is remembered as the last played.
  bool recordGameScore(GameId id, int score) {
    final s = state;
    if (s == null) return false;
    final newBest = GameScore.beats(score, s.gameBests[id]);
    if (!newBest && s.lastGame == id) return false;
    _commit(
      s.copyWith(
        gameBests: newBest ? {...s.gameBests, id: score} : null,
        lastGame: id,
      ),
    );
    return newBest;
  }

  /// The arena opened on, or switched to, [id]; a no-op when unchanged.
  void setLastGame(GameId id) {
    final s = state;
    if (s == null || s.lastGame == id) return;
    _commit(s.copyWith(lastGame: id));
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

  /// The Day-1 task names as the dashboard sees them.
  ///
  /// Spelled out rather than taken from `Day1TourStep.name` on purpose: the
  /// enum is a UI concern and renaming it would silently reclassify every row
  /// already recorded, the same way renaming `CoachRole.ember` would.
  static const _day1TaskNames = ['log_puff', 'meet_coach', 'danger_hours'];

  /// Reports a Day-1 task the first time it is ticked, and the completion of
  /// the list when the third one lands.
  ///
  /// It lives in the store because two different paths tick a task — the
  /// checklist buttons and the very first LOG PUFF tap — so activation is
  /// counted identically however it happened, and a new entry point cannot
  /// ship unmeasured. Guarded on the before-state, so the second puff of the
  /// day never re-reports task zero.
  void _reportDay1Task(JourneyState before, int index) {
    if (index < 0 || index >= _day1TaskNames.length) return;
    if (before.day1TasksDone.contains(index)) return;

    final analytics = ref.read(analyticsProvider);
    analytics.day1TaskDone(_day1TaskNames[index]);
    if (before.day1TasksDone.length + 1 >= _day1TaskNames.length) {
      analytics.day1Completed();
    }
  }

  /// They chose not to be walked through setup. Ticks nothing — see
  /// [JourneyState.day1TourSkipped].
  void skipDay1Tour() {
    final s = state;
    if (s == null) return;
    // How far they got before leaving is the whole point: abandoning at zero
    // and abandoning at two are different problems.
    //
    // Reported only on the transition. The screen hides the skip link once it
    // has been taken, so a second call should not happen — but the guard lives
    // here rather than relying on that, because a skip counted twice quietly
    // inflates the one rate this event exists to measure.
    if (!s.day1TourSkipped) {
      ref.read(analyticsProvider).day1Skipped(s.day1TasksDone.length);
    }
    _commit(s.copyWith(day1TourSkipped: true));
  }

  void completeDay1Task(int index) {
    final s = state;
    if (s == null) return;
    _reportDay1Task(s, index);
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

  /// How long [reserveCoachName] waits for the server guard before keeping
  /// the name on the client's say-so. Long enough for a warm callable on a
  /// slow mobile link, short enough that a cold start never reads as a hang.
  static const coachNameBudget = Duration(milliseconds: 1500);

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
  ///
  /// The wait is bounded by [coachNameBudget]. The policy above always said a
  /// timeout accepts — but nothing ever imposed one, so the step's CTA sat on
  /// a spinner for the whole of a cold start (3–4 s on an iPhone whose App
  /// Check attempt also has to fail first). A warm guard answers well inside
  /// the budget and still blocks on a definite no; past it, the name is kept
  /// and the callable finishes on its own — a late acceptance still lands the
  /// server copy, a late refusal simply never does.
  Future<bool> reserveCoachName(String name) async {
    var accepted = true;
    try {
      accepted = await ref
          .read(coachNameRepositoryProvider)
          .reserve(name)
          .timeout(coachNameBudget);
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
    // The wallet is a function of the day map (docs/03 §5: 1 per 7
    // streak-days, cap 2, one spent per absorbed day). The stored number is
    // only ever this derivation, never an input to it — a stored wallet that
    // fed its own recomputation is how four slips got absorbed off two
    // tokens (QA H2).
    final tokens = StreakEngine.repairTokens(s.days, _now);

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
