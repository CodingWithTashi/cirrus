import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/date_key.dart';
import '../../domain/logic/dependence_engine.dart';
import '../../domain/logic/games/game_id.dart';
import '../../domain/logic/games/game_score.dart';
import '../../domain/logic/money_engine.dart';
import '../../domain/logic/plan_adjust.dart';
import '../../domain/logic/plan_restart.dart';
import '../../domain/logic/puff_anchor.dart';
import '../../domain/logic/streak_engine.dart';
import '../../domain/logic/taper_engine.dart';
import '../../domain/models/journey_state.dart';
import '../../domain/models/models.dart';
import '../../domain/analytics/analytics.dart';
import '../../domain/analytics/lp_events.dart';
import '../../domain/repositories/repositories.dart';
import '../dto/journey_codec.dart';
import '../seed/seed_data.dart';
import 'pending_puffs.dart';
import 'providers.dart';

/// What a launch-time [JourneyStore.restoreSession] found.
enum SessionRestore {
  /// A journey is live — restored now, or already there.
  restored,

  /// Nobody is signed in, or the account has no journey yet: sign-in.
  signedOut,

  /// Somebody IS signed in and their journey could not be read: a retry,
  /// never sign-in (docs/10 §40).
  unavailable,
}

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
  void _syncUserContext() {
    // Timezone, locale and the read-marks. The DEVICE TOKEN is deliberately
    // not this call's job any more: it is the one field whose absence is
    // invisible and unrecoverable, so it belongs to something that checks
    // and retries rather than to a fire-and-forget whose failure reached
    // nobody.
    ref.read(userContextRepositoryProvider).sync().ignore();
    ref.read(pushTokenRegistrarProvider).onSessionEstablished();
  }

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

  /// FCM rotated the device token.
  ///
  /// Delegated to [PushTokenRegistrar], which is the one thing that knows
  /// whether this device is currently registered and is the only thing that
  /// retries. The store used to own this and answered a refresh that arrived
  /// before `restoreSession()` had finished — which is the ordinary cold
  /// start, and the moment a REINSTALL mints its new token — by discarding
  /// it.
  void onPushTokenRefreshed(String token) =>
      ref.read(pushTokenRegistrarProvider).onTokenRefreshed(token);

  /// Binds the store identity to the account, so a purchase is filed under
  /// the same uid the server's entitlement mirror is keyed by. Same shape as
  /// [_identifyForAnalytics], for the same reason: the notifier is captured
  /// before the await.
  void _bindBilling() {
    final billing = ref.read(entitlementProvider.notifier);
    _auth.currentUserId().then(billing.bindSession).ignore();
  }

  /// Names the account the home-screen mirror belongs to, for the Apple Watch.
  ///
  /// Same shape as [_identifyForAnalytics] and [_bindBilling] — notifier
  /// captured before the await, for the reason this store has been bitten by
  /// elsewhere. The watch is the one surface that has to tell one person's
  /// numbers from the next person's, because it is a second device and cannot
  /// be forgotten synchronously when someone signs out.
  void _bindWidgetSession() {
    final session = ref.read(widgetSessionProvider.notifier);
    _auth.currentUserId().then(session.bind).ignore();
  }

  /// A sign-in, a registration, a restore or a created journey has opened a
  /// session in this process. Cleared by the two things that end one.
  bool _sessionOpen = false;

  /// Whether somebody is signed in — with or without a journey yet.
  ///
  /// Onboarding asks this once, after the hold-to-commit, to decide whether
  /// the plan already has an account to live in (docs/10 §49). Two sources,
  /// because neither backend answers alone: the flag covers the fake, whose
  /// `currentUserId()` is always null, and the repository covers a real
  /// account that signed in on an earlier launch and never finished the quiz
  /// — `restoreSession` reports that one as signed out, since it has no
  /// journey to restore.
  Future<bool> hasSession() async =>
      _sessionOpen || await _auth.currentUserId() != null;

  /// Everything a freshly-established session should pull from the server.
  /// One call so a new session path cannot wire half of it.
  void _onSessionEstablished() {
    _sessionOpen = true;
    _syncUserContext();
    pullPlanAdvice();
    _identifyForAnalytics();
    _bindBilling();
    _bindWidgetSession();
    _syncCoachName();
  }

  /// The name last handed to the server by [_syncCoachName] in this process,
  /// so one session asks once. In memory only, and dropped with the session:
  /// the next account may have chosen the same word.
  String? _coachNameSent;

  /// Gives the server its copy of the coach's name, now that there is an
  /// account for it to belong to.
  ///
  /// The onboarding step asks [reserveCoachName] with nobody signed in — the
  /// quiz runs before the account (docs/10 §49) — so the callable answers
  /// "Sign in to continue", the step keeps the name locally as designed, and
  /// until Nov 12 2026 nothing ever asked again: 101 of 127 accounts had no
  /// server copy, and the model, which may read only the server's, called
  /// itself Ember under every screen showing the name the person chose.
  ///
  /// Here because this is the first moment both halves exist, on every path:
  /// a journey just created, a sign-in, a restored launch. That last one is
  /// what catches up every account made before the fix.
  ///
  /// A definite refusal puts the default back. It cannot be shown at the step
  /// any more, and keeping a name the model will never be told about is the
  /// very disagreement this exists to end; Settings is where a new one is
  /// picked, with the refusal on screen. No answer at all changes nothing and
  /// is asked again on the next session.
  void _syncCoachName() {
    final name = state?.profile.coachName;
    if (name == null || name == _coachNameSent) return;
    _coachNameSent = name;
    final guard = ref.read(coachNameRepositoryProvider);
    unawaited(() async {
      final bool accepted;
      try {
        accepted = await guard.reserve(name);
      } on Object {
        if (_coachNameSent == name) _coachNameSent = null;
        return;
      }
      if (accepted) return;
      final s = state;
      if (s == null || s.profile.coachName != name) return;
      _commit(s.copyWith(profile: s.profile.withDefaultCoachName()));
    }());
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
    // Never on a plan's first day. The server advises days 2 onward — there
    // is no completed day to read before that — so a verdict stamped for
    // "today" on day one can only have been worked out last night for the
    // plan that was just replaced (`startNewPlan`). It is re-read on every
    // resume, and a restart clears the accepted copy the guard below looks
    // at: the old plan's zero became the new plan's day-one line, and its
    // stretch lengthened a runway chosen minutes earlier.
    if (s.plan.dayNumber(_now) <= 1) return;
    if (s.planAdvice?.appliesTo(advice.forDay) ?? false) return;
    // The stretch ceiling lives in the engine (`maxStretchDays`), so the client
    // decides how much of a requested stretch actually happens, whatever build
    // the server is on. A server one deploy behind can still ask for a day on
    // a plan already at the ceiling (docs/15 QP-A9).
    final stretched = advice.stretchDelta > 0
        ? TaperEngine.reflowAfterSlip(s.plan, extraDays: advice.stretchDelta)
        : s.plan;
    final moved = stretched.stretchDays - s.plan.stretchDays;
    _commit(
      s.copyWith(
        // What is STORED is the stretch that moved, not the one requested: the
        // Plan screen says "your runway moved" whenever it is above zero, and
        // claiming a day the engine refused would be an invented fact.
        planAdvice: () => moved == advice.stretchDelta
            ? advice
            : PlanAdvice(
                forDay: advice.forDay,
                limit: advice.limit,
                adherence: advice.adherence,
                stretchDelta: moved,
              ),
        plan: stretched,
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
    // Put back with the journey if the write is refused below: those puffs
    // never landed, so neither did the anchors they set or took back.
    final trailBefore = List.of(_anchorTrail);

    var highest = 0;
    _batchedPuffLogs = 0;
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
    if (next == null || identical(next, before)) {
      _flushBatchedPuffLogs();
      return highest;
    }

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
      //
      // Only while the batch is still the newest thing in memory. `_batching`
      // was cleared before the await, so an in-app tap, a mood check-in or
      // the plan-advice pull can have committed on top of it meanwhile; a
      // blind restore would erase THAT mutation too. In that case the state
      // stays (the later commit's own whole-document write carried these
      // puffs along) and the cursor still does not move: `restoreSession`
      // replaces the journey from the backend whenever an account is
      // established, and the events drain onto it exactly once.
      if (identical(state, next)) {
        state = before;
        _anchorTrail
          ..clear()
          ..addAll(trailBefore);
      }
      // Discarded, not flushed: none of these taps landed.
      _batchedPuffLogs = 0;
      return 0;
    }
    _flushBatchedPuffLogs();
    return highest;
  }

  /// One `puff_logged` per widget tap that actually landed. Still one per tap
  /// rather than per puff — the metric counts logging behaviour.
  void _flushBatchedPuffLogs() {
    final analytics = ref.read(analyticsProvider);
    for (var i = 0; i < _batchedPuffLogs; i++) {
      analytics.puffLogged(source: 'widget');
    }
    _batchedPuffLogs = 0;
  }

  /// `puff_logged` events owed by the drain in progress. See [logPuff].
  int _batchedPuffLogs = 0;

  /// How long a drain waits for the backend before assuming the write is
  /// queued rather than refused. Short: it runs on the launch path.
  static const Duration widgetFlushTimeout = Duration(seconds: 3);

  // ---- session lifecycle (awaited API calls) --------------------------------

  /// Splash-time restore. Never clobbers an already-live journey (the frame
  /// map and tests seed state before navigation), and never blocks launch on
  /// a dead connection.
  ///
  /// Answers what it found, because the splash has to tell apart two failures
  /// that used to share one outcome: nobody is signed in (sign-in), and
  /// somebody IS signed in whose journey could not be read (a retry). Every
  /// throw used to read as the first, so a returning user whose launch read
  /// outlasted its budget was shown the sign-in screen for an account they
  /// were still signed into (docs/10 §40).
  Future<SessionRestore> restoreSession() async {
    if (state != null) return SessionRestore.restored;
    try {
      final restored = await _auth.restoreSession();
      if (restored == null) return SessionRestore.signedOut;
      if (state == null) state = restored;
      _onSessionEstablished();
      _adoptServerCopy(restored);
      return SessionRestore.restored;
    } on JourneyUnavailableException {
      return SessionRestore.unavailable;
    } on Exception {
      // No session could be read at all — proceed signed out.
      return SessionRestore.signedOut;
    }
  }

  /// Launch may have restored the copy of the journey this device keeps —
  /// what `restoreSession` falls back to when the server is too slow — and
  /// that copy is only as fresh as this device's last sync. So the server's
  /// copy is read once, in the background, and adopted only when nothing has
  /// changed locally since: a local change is already on its way to the server
  /// as a whole-document write, the same last-writer-wins every mutation here
  /// has always had.
  void _adoptServerCopy(JourneyState restored) {
    _journeys
        .fetchLatest()
        .then((latest) {
          if (latest == null || !identical(state, restored)) return;
          final same =
              jsonEncode(JourneyCodec.encode(latest)) ==
              jsonEncode(JourneyCodec.encode(restored));
          if (!same) state = latest;
        })
        .ignore();
  }

  /// Returns true when the account had a journey to restore; false → the
  /// account registered but never onboarded — route to onboarding. Throws
  /// [InvalidCredentialsException] on a wrong password.
  Future<bool> logIn({required String email, required String password}) =>
      _signIn(
        LpSignInMethod.email,
        () => _auth.signInWithEmail(email: email, password: password),
      );

  /// Returns true when the Apple account already had a journey to restore;
  /// false → route to onboarding.
  Future<bool> signInWithApple() =>
      _signIn(LpSignInMethod.apple, _auth.signInWithApple);

  /// Returns true when the Google account already had a journey to restore;
  /// false → route to onboarding.
  Future<bool> signInWithGoogle() =>
      _signIn(LpSignInMethod.google, _auth.signInWithGoogle);

  /// One attempt at a session, reported with how it ended.
  ///
  /// The three sign-in paths were three copies of the same four lines, and
  /// none of them told the funnel anything: a dismissed sheet, a wrong
  /// password and a provider that refused all looked like a person who saw
  /// the sign-in screen and left. The sink is captured before the await, as
  /// everywhere else in this store, and the error is rethrown untouched — the
  /// views own what the person is told.
  Future<bool> _signIn(
    LpSignInMethod method,
    Future<JourneyState?> Function() attempt,
  ) async {
    final analytics = ref.read(analyticsProvider);
    final JourneyState? restored;
    try {
      restored = await attempt();
    } on Object catch (error) {
      _reportSignInMiss(analytics, method, error);
      rethrow;
    }
    if (restored != null) state = restored;
    _onSessionEstablished();
    analytics.signInCompleted(method, returning: restored != null);
    return restored != null;
  }

  static void _reportSignInMiss(
    AnalyticsSink analytics,
    LpSignInMethod method,
    Object error,
  ) {
    if (error is SignInCancelledException) {
      analytics.signInCancelled(method);
      return;
    }
    analytics.signInFailed(
      method,
      switch (error) {
        NoConnectionException() => 'offline',
        InvalidCredentialsException() => 'invalid_credentials',
        EmailAlreadyInUseException() => 'email_in_use',
        WeakPasswordException() => 'weak_password',
        SignInUnavailableException() => 'provider_unavailable',
        _ => 'other',
      },
      detail: switch (error) {
        SignInUnavailableException(:final detail) => detail,
        AuthProviderException(:final detail) => detail,
        _ => null,
      },
    );
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
    final analytics = ref.read(analyticsProvider);
    try {
      await _auth.register(email: email, password: password);
    } on Object catch (error) {
      _reportSignInMiss(analytics, LpSignInMethod.register, error);
      rethrow;
    }
    _onSessionEstablished();
    analytics.signInCompleted(LpSignInMethod.register, returning: false);
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
    // Said before anything is forgotten: the event has to land under the
    // account that is leaving, and it needs the journey to say where they
    // were. `reset()` below is what unbinds the identity.
    final leaving = state;
    if (leaving != null) {
      final day = leaving.plan.dayNumber(_now);
      ref
          .read(analyticsProvider)
          .signedOut(
            planDay: day,
            pastFreedom: day > leaving.plan.totalDays,
            premium: ref.read(isPremiumProvider),
          );
    }
    state = null;
    _sessionOpen = false;
    _coachNameSent = null;
    // The undo trail names this account's puffs (docs/10 §41).
    _anchorTrail.clear();
    _slipArmedOn = null;
    _tokenSpentOn = null;
    // Before the sign-out call, so the identity is unbound even if the ack
    // never lands. On a shared phone the alternative is the next person's
    // events arriving under the last person's user id — and, for billing,
    // the next person inheriting the last one's Premium.
    ref.read(analyticsProvider).reset();
    ref.read(entitlementProvider.notifier).unbind().ignore();
    // Same shared-phone rule, third instance: the milestone ledger is
    // device-scoped SharedPreferences with no uid in the key, and a settled
    // badge makes the planner answer null — so without this the next person to
    // sign in inherits this account's settled badges and never gets a single
    // celebration.
    ref.read(settingsStoreProvider.notifier).resetMilestoneLedger();
    // Fourth instance, and the one that reaches another device: an Apple Watch
    // holds its own copy of the mirror and its own queue of taps, and it cannot
    // be cleared synchronously — it may be out of range. Dropping the id here is
    // what makes the NEXT account's mirror look different to the wrist, which is
    // the only thing that empties it; until then the wrist simply shows no
    // numbers, because the mirror says there is no journey. The phone is the
    // real guard either way: `WatchWire.relay` refuses a batch whose `sid` is
    // not the phone's own. `_WidgetSync` calls `discardQueued()` for this
    // device's own queue.
    ref.read(widgetSessionProvider.notifier).unbind();
    // Release the push registration BEFORE the credential goes, and chain the
    // two rather than firing both: `syncUserContext` is a callable, so it
    // carries the caller's ID token, and a release that raced past
    // `_auth.signOut()` would arrive unauthenticated and do nothing at all.
    // Exactly the same shared-phone case as the analytics reset above — this
    // one is the pushes rather than the events.
    //
    // `unregister()` is bounded and never throws, so `whenComplete` always
    // runs and the sign-out cannot be held up by a slow backend.
    // Sixth thing to forget on a shared phone: the belief that this device is
    // already registered. Without it the next account on the same handset is
    // assumed done and never registered at all.
    ref.read(pushTokenRegistrarProvider).forget();
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
    // As in `signOut`: erasing the account must erase the device's record of
    // what it already celebrated, or starting over on the same phone is a quit
    // with no milestones at all.
    ref.read(settingsStoreProvider.notifier).resetMilestoneLedger();
    // As in `signOut`, and for the same reason: a wrist still showing a deleted
    // account's count is the leak in its most public form.
    ref.read(widgetSessionProvider.notifier).unbind();
    // The server side of the push registry died with `recursiveDelete`; this
    // is the local half — without it the device keeps a live FCM token bound
    // to an account that no longer exists. After the await on purpose: a
    // refused deletion must not silence the account it failed to delete. The
    // release callable inside will fail (no session any more) and is
    // swallowed; the `deleteToken` is the part that matters.
    ref.read(pushTokenRegistrarProvider).forget();
    ref.read(userContextRepositoryProvider).unregister().ignore();
    _anchorTrail.clear();
    _slipArmedOn = null;
    _tokenSpentOn = null;
    _sessionOpen = false;
    _coachNameSent = null;
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

  /// The day this session armed the slip-recovery card on, and the day it
  /// spent a repair token on — what [undoPuffs] may take back. In memory like
  /// the anchor trail, and forgotten with it: after a restart the Undo snack
  /// is long gone, and a slip that survived one is real.
  DateTime? _slipArmedOn;
  DateTime? _tokenSpentOn;

  /// What "last puff" was before each puff logged this session, newest last
  /// (docs/10 §41).
  ///
  /// Undo used to leave `lastPuffAt` wherever the undone puff had put it, so
  /// an accidental tap and its Undo restarted the health timeline from the
  /// tap: the puff was gone and its clock stayed. Each entry names the day the
  /// puff went to, the anchor before it and the anchor it set. An undo follows
  /// the trail back only while the anchor still matches, so an entry that a
  /// sign-out, a refused drain or a server copy has overtaken is never used.
  final _anchorTrail = <({DateTime day, DateTime? before, DateTime? after})>[];

  /// A session convenience, not history.
  static const _anchorTrailCap = 200;

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
    // Buffered during a drain: the batch is all-or-nothing, and a refused
    // write rolls the journey back and leaves the events queued for the next
    // drain. Emitting here would have already counted taps that did not land,
    // and the replay would count them a second time — inflating the Weekly
    // Active Quitters funnel this event exists to compute.
    if (_batching) {
      _batchedPuffLogs++;
    } else {
      ref.read(analyticsProvider).puffLogged();
    }
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

    // Remember which day this session armed a slip or spent a token on, so
    // an Undo that brings the day back under its line can take those back
    // too (see [undoPuffs]). Only the transition is recorded: a slip already
    // pending from an earlier day is not this day's to clear.
    if (s.pendingSlipCleanDays == null && pendingSlip != null) {
      _slipArmedOn = key;
    }
    if (!(s.days[key]?.repairTokenUsed ?? false) && updated.repairTokenUsed) {
      _tokenSpentOn = key;
    }

    // The anchor only ever moves FORWARD. Every in-app caller passes `at:
    // null`, so `when` is now and this is a no-op for them — but a puff
    // logged from the home-screen widget is drained hours later, and applying
    // a 23:50 event at 09:00 the next morning would drag the anchor
    // backwards. The whole health timeline is measured from it (docs/03 §6),
    // so that would silently rewind every recovery node the user had earned.
    final anchor = s.lastPuffAt;
    final lastPuff = anchor == null || when.isAfter(anchor) ? when : anchor;
    // One entry per puff: taking back part of a burst keeps the burst's time,
    // and taking back all of it restores the time before it.
    for (var i = 0; i < count; i++) {
      _anchorTrail.add((
        day: key,
        before: i == 0 ? anchor : lastPuff,
        after: lastPuff,
      ));
    }
    if (_anchorTrail.length > _anchorTrailCap) {
      _anchorTrail.removeRange(0, _anchorTrail.length - _anchorTrailCap);
    }

    _commit(
      _withBadges(
        s.copyWith(
          days: {...s.days, key: updated},
          lastPuffAt: () => lastPuff,
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
    var next = log.copyWith(puffs: log.puffs - removed, hourBuckets: buckets);
    // Taking puffs back takes back what they caused. A tap that crossed the
    // line armed the recovery card or spent a repair token, and Undo used to
    // remove only the puff — so an accidental tap on a zero-limit day left "A
    // slip is data, not defeat." on Home with nothing logged, holding the one
    // card slot the mood prompt and the nudge share (Nov 12 2026). Only what
    // THIS session did on THIS day: a slip pending from yesterday stays.
    var pendingSlip = s.pendingSlipCleanDays;
    if (next.puffs <= next.limit && _tokenSpentOn == key) {
      next = next.copyWith(repairTokenUsed: false);
      _tokenSpentOn = null;
    }
    final stillSlipped =
        (next.puffs > next.limit && !next.repairTokenUsed) ||
        (next.limit > 0 && next.puffs > next.limit * 2);
    if (!stillSlipped && _slipArmedOn == key) {
      pendingSlip = null;
      _slipArmedOn = null;
    }
    final days = {...s.days, key: next};
    // Taking puffs back takes their clock back too (docs/10 §41): follow this
    // session's trail while it still matches the anchor, then make sure the
    // anchor sits in an hour that still holds a puff.
    var anchor = s.lastPuffAt;
    var undone = 0;
    while (undone < removed &&
        _anchorTrail.isNotEmpty &&
        _anchorTrail.last.day == key &&
        _anchorTrail.last.after == anchor) {
      anchor = _anchorTrail.removeLast().before;
      undone++;
    }
    final settled = PuffAnchor.settle(days, anchor);
    _commit(
      s.copyWith(
        days: days,
        lastPuffAt: () => settled,
        pendingSlipCleanDays: () => pendingSlip,
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
    // Once per day confirmed, not once per tap: the card answers itself away,
    // but the store is also reachable from the edit sheet and the tour.
    // The line as Home shows it, not the one stored when the log was minted:
    // a day created on a taper and switched to cold turkey that afternoon
    // carries the old number, and Home's zero-day button reads the live one.
    final zeroLine = s.limitOn(key) == 0;
    if (!log.vapeFreeConfirmed) {
      ref
          .read(analyticsProvider)
          .dayConfirmed(today: key == _todayKey, zeroDay: zeroLine);
    }
    // On a zero line this IS the first move, the way the first puff is on a
    // taper — so it ticks Day-1 task zero from wherever it was tapped, and
    // is reported under its own name: the dashboard has to be able to tell a
    // first check-in from a first puff.
    //
    // Only while setup is still on offer (the first three days of a first
    // plan, the window Home's "Finish setup" card keeps). Every cold-turkey
    // account made before this shipped has task zero undone — there was
    // never a puff to log — and their next confirmation, weeks in, must not
    // arrive in the Day-1 funnel as a new person.
    final firstMove =
        key == _todayKey &&
        zeroLine &&
        s.plan.planNumber == 1 &&
        s.plan.dayNumber(_now) <= 3;
    if (firstMove) _reportDay1Task(s, 0, name: 'first_checkin');
    _commit(
      _withBadges(
        s.copyWith(
          days: {...s.days, key: log.copyWith(vapeFreeConfirmed: true)},
          day1TasksDone: firstMove ? {...s.day1TasksDone, 0} : null,
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
    final days = {
      ...s.days,
      key: log.copyWith(
        puffs: puffs,
        // A typed 0 leaves no hour with a puff in it. The buckets kept the old
        // count's hours, so a day corrected to zero still read as holding
        // puffs to anything that walks them (docs/10 §41).
        hourBuckets: puffs == 0 ? const <int, int>{} : null,
        // Typing 0 for a past day is the user's own word that it was
        // vape-free — the sheet asked for a count and they gave one.
        // Left unconfirmed, correcting a mis-tap down to zero would
        // silently break the chain it was meant to repair.
        vapeFreeConfirmed: puffs == 0 ? true : log.vapeFreeConfirmed,
      ),
    };
    // "Last puff" moves with a correction (docs/10 §41). Fewer puffs: it may
    // no longer name one that exists. Puffs added on its own day or a later
    // one carry no time, so they count as late as that day allows — the
    // morning-after "I vaped" used to leave the health timeline running from
    // two days back. Never later than now.
    var anchor = PuffAnchor.settle(days, s.lastPuffAt);
    final anchorDay = anchor == null ? null : LpDate.dayStart(anchor);
    if (puffs > 0 &&
        !key.isAfter(_todayKey) &&
        (anchorDay == null ||
            key.isAfter(anchorDay) ||
            (key == anchorDay && puffs > log.puffs))) {
      final endOfDay = LpDate.addDays(
        key,
        1,
      ).subtract(const Duration(seconds: 1));
      anchor = endOfDay.isAfter(_now) ? _now : endOfDay;
    }
    final settled = anchor;
    _commit(
      _withBadges(s.copyWith(days: days, lastPuffAt: () => settled)),
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

  /// Whether they have smoked cigarettes (docs/15 QP-A3): the same question
  /// onboarding asks, put to accounts made before it existed. Synchronous and
  /// optimistic like every other mutation, so Home can drop the card on the
  /// frame of the tap. A no-op when unchanged or with no journey.
  void setSmokingHistory(SmokingHistory value) {
    final s = state;
    if (s == null || s.profile.smoking == value) return;
    _commit(s.copyWith(profile: s.profile.copyWith(smoking: value)));
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

  /// Records how today is going. **A check-in counts once a day** (docs/15
  /// QP-B3): the daily card turns this into a question that can be answered
  /// again, and seven check-ins award the week badge, so the counter counts
  /// days, not taps. A changed answer updates the mood and the note and counts
  /// nothing; the event is reported with the day's first answer only, like
  /// `day_confirmed`, so the funnel counts days with a check-in.
  void checkInMood(Mood mood, {String? note}) {
    final s = state;
    if (s == null) return;
    final log =
        s.days[_todayKey] ??
        DayLog(date: _todayKey, puffs: 0, limit: _limitToday(s));
    final firstToday = log.mood == null;
    // The mood, never the note: the note is the person's own sentence.
    if (firstToday) ref.read(analyticsProvider).moodCheckedIn(mood.name);
    _commit(
      _withBadges(
        s.copyWith(
          days: {
            ...s.days,
            _todayKey: log.copyWith(mood: mood, moodNote: note),
          },
          moodCheckIns: s.moodCheckIns + (firstToday ? 1 : 0),
        ),
      ),
    );
  }

  /// Files a daily-program check-up answer under today (docs/15 QP-B7).
  ///
  /// Only an answer that belongs to the question is accepted: the sheet offers
  /// nothing else, and a mismatched pair would be dropped by both codecs on the
  /// next read anyway, so writing one would be a silent loss. Answering again
  /// the same day replaces the answer; answering the same thing twice is one
  /// write and one event. The event is reported on acceptance, not just stored:
  /// see `AnalyticsEvents.checkupAnswered`.
  void recordCheckup(CheckupKind kind, CheckupAnswer answer) {
    final s = state;
    if (s == null || !kind.answers.contains(answer)) return;
    final today = _todayKey;
    final existing = s.checkups[today] ?? const {};
    if (existing[kind] == answer) return;
    final analytics = ref.read(analyticsProvider);
    analytics.checkupAnswered(kind: kind.name, answer: answer.name);
    if (kind != CheckupKind.nicotine) {
      analytics.quitStatusReported(
        at: kind == CheckupKind.vaped30 ? 30 : 90,
        vapeFree: answer == CheckupAnswer.notVaped,
      );
    }
    _commit(
      s.copyWith(
        checkups: {
          ...s.checkups,
          today: {...existing, kind: answer},
        },
      ),
    );
  }

  void addGoal(SavingsGoal goal) {
    final s = state;
    if (s == null) return;
    _commit(s.copyWith(goals: [...s.goals, goal]));
  }

  /// Starts a new plan today on this account — see [PlanRestart] for what
  /// that keeps (everything already lived) and what it changes (the line
  /// from here on).
  ///
  /// Synchronous and optimistic like every other mutation. A screen that
  /// calls this and leaves must leave FIRST: it changes the journey, and the
  /// router's refresh after an imperative navigation undoes the navigation.
  void startNewPlan({
    required QuitMethod method,
    required int paceDays,
    required int level,
  }) {
    final s = state;
    if (s == null) return;
    final now = _now;
    final fromDay = s.plan.dayNumber(now);
    final next = PlanRestart.apply(
      s,
      now: now,
      method: method,
      paceDays: paceDays,
      level: level,
    );
    ref
        .read(analyticsProvider)
        .planRestarted(
          fromDay: fromDay,
          pastFreedom: fromDay > s.plan.totalDays,
          method: method.name,
          pace: paceDays,
          planNumber: next.plan.planNumber,
        );
    // The slip this session may have armed belonged to the plan just left.
    _slipArmedOn = null;
    _commit(_withBadges(next));
  }

  /// Puts Freedom Day [paceDays] days from today (docs/15 QP-A11).
  ///
  /// Changes the date and nothing else — the method is `startNewPlan`'s job —
  /// and does nothing at all when the date would not move: no write, no event,
  /// and tonight's advice on the current curve is kept. `PlanAdjust` answers
  /// "where would it land", for this and for the sheet's preview alike.
  ///
  /// The curve regenerates from today over the new runway; past days keep their
  /// recorded limits — no reset, no lost history (docs/03 §11).
  void adjustPlan({required int paceDays}) {
    final s = state;
    if (s == null) return;
    final change = PlanAdjust.toReach(s.plan, _now, paceDays);
    if (change == null) return;
    _commit(
      s.copyWith(
        plan: change.plan,
        // Last night's verdict was about the plan the user just replaced.
        // Keeping it would show today a limit derived from a curve that no
        // longer exists; tonight's cron produces the first honest one.
        planAdvice: () => null,
      ),
    );
    ref.read(analyticsProvider).planAdjusted(deltaDays: change.deltaDays);
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
  void _reportDay1Task(JourneyState before, int index, {String? name}) {
    if (index < 0 || index >= _day1TaskNames.length) return;
    if (before.day1TasksDone.contains(index)) return;

    final analytics = ref.read(analyticsProvider);
    analytics.day1TaskDone(name ?? _day1TaskNames[index]);
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

    // Through today only, the window `TodaySnapshot` renders money over: a
    // log a wrong device clock filed for tomorrow must not mint the $100
    // badge (and its celebration) for a saving no screen shows.
    final today = _todayKey;
    final saved = MoneyEngine.lifetimeSaved(
      s.plan,
      s.days.values.where((l) => !l.date.isAfter(today)),
    );
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
