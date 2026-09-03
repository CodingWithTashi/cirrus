import '../logic/games/game_id.dart';
import 'analytics.dart';

/// The funnel instrumentation from docs/02 §7.
///
/// The point of this file is a single alert: **any onboarding screen losing
/// more than 15% of the people who reached it**. That number is unknowable
/// without `screen_completed` firing from every step, so the event is emitted
/// centrally from the onboarding view model rather than sprinkled across 19
/// widgets — one place to forget instead of nineteen.
///
/// Names are snake_case because that is what Firebase Analytics accepts, and
/// they match docs/02 §7 exactly so the dashboard and the spec cannot drift.
/// `test/analytics_test.dart` pins every name against that list, so renaming
/// one in Dart is a red test rather than a silently orphaned chart.
///
/// Privacy: no free text, no aliases, no message bodies — only enum names and
/// numbers the user gave us as structured answers. "We never sell your data"
/// (PRD §6) starts with not collecting it, and there are no third-party ad
/// SDKs in the app at all.
///
/// This is an extension rather than a base class on purpose: every sink gets
/// the whole vocabulary for free, and no vendor implementation ever learns
/// that `paywall_viewed` exists.
extension LpEvents on AnalyticsSink {
  // --- onboarding funnel ---------------------------------------------------

  void onboardingStart() => track(const AnalyticsEvent('onboarding_start'));

  /// [screenId] is the `ObStep` name; [ms] is dwell time on that screen.
  void screenCompleted(String screenId, int ms) =>
      track(AnalyticsEvent('screen_completed', {'screen_id': screenId, 'ms': ms}));

  /// Under-18s are turned away and nothing about them is stored (docs/02 A3).
  /// This counts the event only — no birth year, no identifiers.
  void ageGateBlocked() => track(const AnalyticsEvent('age_gate_blocked'));

  /// Someone typed an age instead of a year and took the offered swap.
  /// Tells us whether the age-entry affordance earns its keep. The value is
  /// never recorded — this is the same no-identifiers rule as [ageGateBlocked].
  void ageEntryAdopted() => track(const AnalyticsEvent('age_entry_adopted'));

  void puffsEntered(int value, String badge) =>
      track(AnalyticsEvent('puffs_entered', {'value': value, 'badge': badge}));

  void spendEntered(int weekly, int yearlyShown) => track(
    AnalyticsEvent('spend_entered', {
      'weekly': weekly,
      'yearly_shown': yearlyShown,
    }),
  );

  void methodChosen(String method) =>
      track(AnalyticsEvent('method_chosen', {'method': method}));

  void paceChosen(int days) =>
      track(AnalyticsEvent('pace_chosen', {'pace_days': days}));

  void planRevealed() => track(const AnalyticsEvent('plan_revealed'));

  void commitHeld() => track(const AnalyticsEvent('commit_held'));

  void notifPrompt({required bool granted}) =>
      track(AnalyticsEvent('notif_prompt', {'granted': granted.toString()}));

  // --- paywall -------------------------------------------------------------

  /// [variant] is the A/B layout slot docs/06 §3 reads; [source] is what put
  /// the person on the paywall — `onboarding`, `launch`, `settings`,
  /// `coach_cap`, `insight`, `forecast`, `history`, `compose`, `panic`,
  /// `push` — so a conversion rate can be read per door, not just per layout.
  void paywallViewed(String variant, {required String source}) => track(
    AnalyticsEvent('paywall_viewed', {'variant': variant, 'source': source}),
  );

  void trialStarted(String tier) =>
      track(AnalyticsEvent('trial_started', {'tier': tier}));

  void freeContinued() => track(const AnalyticsEvent('free_continued'));

  void winbackShown() => track(const AnalyticsEvent('winback_shown'));

  void winbackConverted() => track(const AnalyticsEvent('winback_converted'));

  // --- premium gates -------------------------------------------------------

  /// A locked surface rendered, with the [source] its door would carry.
  ///
  /// `paywall_viewed` fires only after a TAP, so without this the view→tap rate
  /// of the eleven gates is unknowable: the funnel can say which door was
  /// walked through, never which door was seen and ignored. Those are different
  /// problems with different fixes — a gate nobody taps is bad copy, a gate
  /// nobody sees is bad placement.
  ///
  /// Fires once per mount, never per rebuild, or a scrolling list would report
  /// impressions in the thousands.
  void gateShown(String source) =>
      track(AnalyticsEvent('gate_shown', {'source': source}));

  /// The lock card or its CTA was tapped. `paywall_viewed` follows with the
  /// same `source`, so the two divide cleanly.
  void gateTapped(String source) =>
      track(AnalyticsEvent('gate_tapped', {'source': source}));

  // --- day-one activation --------------------------------------------------

  /// The Day-1 checklist appeared.
  ///
  /// The router redirects every root tab here while the list is unfinished, so
  /// this is the gate every new account must pass — and it emitted nothing at
  /// all, which left the largest single drop-off risk in the app completely
  /// dark. Install→activation could not be computed.
  void day1Viewed() => track(const AnalyticsEvent('day1_viewed'));

  /// One task ticked. [task] is `log_puff`, `meet_coach` or `danger_hours`.
  void day1TaskDone(String task) =>
      track(AnalyticsEvent('day1_task_done', {'task': task}));

  /// All three ticked.
  void day1Completed() => track(const AnalyticsEvent('day1_completed'));

  /// "Skip setup for now" was taken, with how many tasks were done first —
  /// abandoning at zero and abandoning at two are not the same event.
  void day1Skipped(int done) =>
      track(AnalyticsEvent('day1_skipped', {'done': done}));

  // --- billing -------------------------------------------------------------
  // Not in docs/02 §7, whose funnel stops at `trial_started` (fired at intent,
  // before the store sheet). These are the outcomes of that sheet. Revenue
  // itself is not tracked here: RevenueCat forwards it to Amplitude keyed on
  // the same user id, and two sources of one number always disagree.

  /// The store took the payment and the entitlement is active.
  void purchaseCompleted(String plan, {required bool trial}) => track(
    AnalyticsEvent('purchase_completed', {
      'plan': plan,
      'trial': trial.toString(),
    }),
  );

  /// The sheet was dismissed. Distinct from `free_continued`, which is the
  /// user choosing the free path on purpose.
  void purchaseCancelled(String plan) =>
      track(AnalyticsEvent('purchase_cancelled', {'plan': plan}));

  /// [code] is the exception's taxonomy name (`offline`, `store`,
  /// `not_allowed`, `receipt_owned`, `other`) — never the raw store message.
  void purchaseFailed(String code) =>
      track(AnalyticsEvent('purchase_failed', {'code': code}));

  void restoreCompleted({required bool found}) =>
      track(AnalyticsEvent('restore_completed', {'found': found.toString()}));

  /// The tier changed from anything other than a purchase on this device:
  /// a renewal, an expiry, a restore, a change made on another device.
  void entitlementChanged(String tier) =>
      track(AnalyticsEvent('entitlement_changed', {'tier': tier}));

  // --- the habit loop ------------------------------------------------------

  /// Not in docs/02 §7, but the north star is Weekly Active Quitters — users
  /// who log on 4+ days a week — and that is uncountable without this.
  void puffLogged() => track(const AnalyticsEvent('puff_logged'));

  /// A panic session ended, with the game on screen (`none` when unplayed),
  /// its rounds, and their 1–10 before and (optionally) after.
  void cravingSurvived({
    required bool survived,
    GameId? game,
    int rounds = 0,
    int? intensity,
    int? intensityAfter,
  }) => track(
    AnalyticsEvent('craving_outcome', {
      'survived': survived.toString(),
      'game': game?.name ?? 'none',
      'rounds': rounds,
      'intensity': ?intensity,
      'intensity_after': ?intensityAfter,
    }),
  );

  /// A 60-second round ran to the end (docs/09 §8); the tempo ramps are
  /// tuned off this. Numbers only, and never for a round cut short.
  void gameFinished({
    required GameId game,
    required int round,
    required int score,
    required int bestCombo,
    required int misses,
  }) => track(
    AnalyticsEvent('game_finished', {
      'game': game.name,
      'round': round,
      'score': score,
      'best_combo': bestCombo,
      'misses': misses,
    }),
  );

  /// The arena's pills swapped games mid-session.
  void gameSwitched({required GameId from, required GameId to}) => track(
    AnalyticsEvent('game_switched', {'from': from.name, 'to': to.name}),
  );
}
