import '../logic/games/game_id.dart';
import '../logic/widget_prompt_policy.dart';
import 'analytics.dart';

/// The server-enforced allowances a person can run out of.
///
/// Only limits the BACKEND refuses belong here. A client-side gate reports
/// `gate_shown`/`gate_tapped` instead — it is a locked surface, not a wall
/// somebody walked into. The two are different events on purpose: a gate is
/// something we chose to show, a limit is something the user hit.
///
/// The wire value is explicit rather than `.name`, because three of the four
/// are multi-word and `.name` would put camelCase in a snake_case vocabulary.
/// Renaming a Dart constant then cannot reclassify a dashboard's history.
enum LpLimit {
  /// The daily coach allowance (docs/04 §7).
  coach('coach'),

  /// Posting refused for tier — a free account on a non-SOS tag.
  communityPost('community_post'),

  /// The daily post cap, which applies to both tiers.
  communityCap('community_cap'),

  /// `panicSession` narrowed the AI option for the rest of the day.
  panicAi('panic_ai');

  const LpLimit(this.wire);

  final String wire;
}

/// How a session was asked for on the sign-in screens.
///
/// Explicit wire values for the same reason as [LpLimit]: `register` is the
/// email form's other half, and its dashboard name should say so.
enum LpSignInMethod {
  apple('apple'),
  google('google'),

  /// Email and password, an existing account.
  email('email'),

  /// Email and password, a new account.
  register('email_register');

  const LpSignInMethod(this.wire);

  final String wire;
}

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
  // --- the front door ------------------------------------------------------
  // Not in docs/02 §7, whose funnel opens at `onboarding_start`. An account is
  // asked for BEFORE the first question, so everything between the first app
  // open and that event was two screen views: the Oct 5 2026 read found nine
  // of thirty-two real people gone before it, five of them on Android, and
  // nothing that could say whether they left or were turned away.

  /// A session was established from the sign-in screens.
  ///
  /// [returning] is true when the account already had a journey — a person
  /// coming back on a new phone, not a new person. Never fired by a launch
  /// that restores a session: that is not a sign-in.
  void signInCompleted(LpSignInMethod method, {required bool returning}) =>
      track(
        AnalyticsEvent('sign_in_completed', {
          'method': method.wire,
          'returning': returning.toString(),
        }),
      );

  /// The native Apple or Google sheet was dismissed. Its own event for the
  /// reason `purchase_cancelled` is: the person chose it, and nothing broke.
  void signInCancelled(LpSignInMethod method) =>
      track(AnalyticsEvent('sign_in_cancelled', {'method': method.wire}));

  /// [code] is the exception's taxonomy name (`offline`,
  /// `invalid_credentials`, `email_in_use`, `weak_password`,
  /// `provider_unavailable`, `other`) — never the provider's own message, and
  /// never the address that was typed.
  ///
  /// [detail] is the provider's own CODE behind `other` and
  /// `provider_unavailable` (`unknown/1000`, `journey/cloud_firestore/
  /// permission-denied`), sanitized to `[a-z0-9_/-]` by the repository. It is
  /// absent for the named codes, which already say everything. Without it,
  /// the first funnel read after launch held thirteen Apple failures that all
  /// said `other` and nothing else.
  void signInFailed(LpSignInMethod method, String code, {String? detail}) =>
      track(
        AnalyticsEvent('sign_in_failed', {
          'method': method.wire,
          'code': code,
          'detail': ?detail,
        }),
      );

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

  /// The journey exists: onboarding is over and Day 1 is next.
  ///
  /// The funnel used to end on `paywall_viewed`, because the D5 paywall was
  /// the last onboarding screen and the free path ended there. Since Oct 16
  /// 2026 onboarding no longer passes through a paywall at all, so without
  /// this the funnel would stop at `notif_prompt` with no way to tell a
  /// finished onboarding from an abandoned one. Fired once, by
  /// `OnboardingViewModel.complete` after the backend has the journey.
  void onboardingCompleted() =>
      track(const AnalyticsEvent('onboarding_completed'));

  void notifPrompt({required bool granted}) =>
      track(AnalyticsEvent('notif_prompt', {'granted': granted.toString()}));

  /// A reminder the DEVICE scheduled was tapped — the danger-hour nudge, the
  /// trial heads-up, a milestone, the evening check-in. [kind] is the
  /// `ReminderKind` name.
  ///
  /// `push_opened` covers what the server sends and nothing here did: until
  /// Oct 16 2026 a reminder tap reported nothing at all, so whether any of
  /// them ever brought somebody back was unknowable — the very question the
  /// evening check-in was added to answer.
  void reminderOpened(String kind) =>
      track(AnalyticsEvent('reminder_opened', {'kind': kind}));

  /// A push was tapped, and where it went.
  ///
  /// The pair `push_opened` and the server's own `push.sent` log line is what
  /// makes this feature evaluable at all — whether the collapse throttle is
  /// too aggressive, and whether a route we sent is a route the app accepted.
  /// It matters more here than for most events because, as `lib/push.ts`'s
  /// header puts it, the failure of a push is silence, and silence looks
  /// exactly like having nothing to say.
  ///
  /// [kind] is the server's `PushKind` and carries no user text; [opened] is
  /// false when a route was refused by the allow-list.
  void pushOpened({required String kind, required bool opened}) => track(
    AnalyticsEvent('push_opened', {
      'kind': kind,
      'opened': opened.toString(),
    }),
  );

  // --- paywall -------------------------------------------------------------

  /// [variant] is what was actually rendered — the A/B slot docs/06 §3 reads,
  /// and, until an arm exists, the real difference between a paywall showing
  /// live store prices and one showing the typed fallbacks under their
  /// "prices unavailable" caption. That second case happens in production and
  /// converts differently, and it used to be invisible: the dimension was the
  /// constant `d5_default`, so every chart cut by it had one bucket.
  ///
  /// [source] is what put the person on the paywall, so a conversion rate can
  /// be read per door and not just per layout. There is no enum — the value
  /// is a bare `String` at every call site — so THIS COMMENT IS THE ONLY
  /// REGISTRY, and it has already been stale once. The full list:
  ///
  /// `offer_card` · `settings` · `coach_cap` · `insight` · `forecast` ·
  /// `health` · `plan` · `history` · `compose` · `nudge` · `panic_game` ·
  /// `theme` · `push` · `free_plan` · `direct`
  ///
  /// (`direct` is the fallback when a `/paywall` route carries no `?source=`;
  /// `push` is stamped on by `taggedPushRoute()`.) Add a door, add it here.
  ///
  /// Retired Oct 16 2026, and still in the history: `onboarding` (the D5
  /// paywall at the end of the quiz, gone with "free first") and `launch`
  /// (the paywall pushed on a day-3/7/14/30 launch, now the Home card that
  /// reports `offer_card`).
  ///
  /// [planDay] is where they were in their own quit when the door opened. A
  /// day-3 gate and a day-40 gate are different products of different
  /// motivations, and they used to be the same row. Every paywall has a
  /// journey under it now (the router enforces it), so it is null only in
  /// events recorded before that.
  void paywallViewed(String variant, {required String source, int? planDay}) =>
      track(
        AnalyticsEvent('paywall_viewed', {
          'variant': variant,
          'source': source,
          'plan_day': ?planDay,
        }),
      );

  /// A plan card was chosen on the paywall. [period] is `weekly`/`monthly`/
  /// `yearly`.
  ///
  /// The gap between what people *consider* and what they buy is the whole
  /// question behind the price-ladder work, and `trial_started` only ever
  /// reported the winner.
  void planSelected(String period, {required String source}) => track(
    AnalyticsEvent('plan_selected', {'period': period, 'source': source}),
  );

  /// The paywall was left without buying and without taking the free path.
  ///
  /// `purchase_cancelled` only fires once the STORE sheet has opened, so
  /// backing out of the paywall itself was invisible — and for the launch
  /// paywall, which nobody asked for, that is the number that says whether it
  /// is a door or a nag. [plan] is what was selected when they left.
  void paywallDismissed({required String source, required String plan}) =>
      track(
        AnalyticsEvent('paywall_dismissed', {'source': source, 'plan': plan}),
      );

  void trialStarted(String tier) =>
      track(AnalyticsEvent('trial_started', {'tier': tier}));

  void freeContinued() => track(const AnalyticsEvent('free_continued'));

  void winbackShown() => track(const AnalyticsEvent('winback_shown'));

  void winbackConverted() => track(const AnalyticsEvent('winback_converted'));

  // --- premium gates -------------------------------------------------------

  /// A locked surface rendered, with the [source] its door would carry.
  ///
  /// `paywall_viewed` fires only after a TAP, so without this a gate's view→tap
  /// rate is unknowable: the funnel can say which door was walked through,
  /// never which door was seen and ignored. Those are different problems with
  /// different fixes — a gate nobody taps is bad copy, a gate nobody sees is
  /// bad placement.
  ///
  /// Fires once per mount, never per rebuild, or a scrolling list would report
  /// impressions in the thousands.
  ///
  /// [planDay] is where the reader was in their own quit. Same reason as
  /// `paywall_viewed`: a gate on day 3 and a gate on day 40 are different
  /// questions, and they used to land in the same row.
  void gateShown(String source, {int? planDay}) => track(
    AnalyticsEvent('gate_shown', {'source': source, 'plan_day': ?planDay}),
  );

  /// The lock card or its CTA was tapped. `paywall_viewed` follows with the
  /// same `source`, so the two divide cleanly.
  void gateTapped(String source) =>
      track(AnalyticsEvent('gate_tapped', {'source': source}));

  // --- server-enforced walls -----------------------------------------------

  /// A backend allowance refused something the user asked for.
  ///
  /// The gates above report doors we CHOSE to show; this reports walls people
  /// actually hit, which is the higher-intent event of the two and was
  /// completely dark until now. The coach cap rendered a template, `createPost`
  /// threw `permission-denied`, and `panicSession` quietly narrowed the AI
  /// option — none of them told the funnel anything, so "ran out of coach
  /// messages" was indistinguishable from "never opened the coach".
  ///
  /// [premium] is the allowance that was in force, not the entitlement's exact
  /// tier: a trial is on the premium allowance and reports as one. A bool
  /// rather than a tier string because there is no way to misspell it.
  ///
  /// [used] and [limit] are sent only where the backend actually said. Deriving
  /// them from a client-side constant would put our guess in the same column as
  /// the server's fact.
  void limitReached(
    LpLimit capability, {
    required bool premium,
    int? used,
    int? limit,
  }) => track(
    AnalyticsEvent('limit_reached', {
      'capability': capability.wire,
      'tier': premium ? 'premium' : 'free',
      'used': ?used,
      'limit': ?limit,
    }),
  );

  // --- day-one activation --------------------------------------------------

  /// The Day-1 checklist appeared.
  ///
  /// The router redirects every root tab here while the list is unfinished, so
  /// this is the gate every new account must pass — and it emitted nothing at
  /// all, which left the largest single drop-off risk in the app completely
  /// dark. Install→activation could not be computed.
  void day1Viewed() => track(const AnalyticsEvent('day1_viewed'));

  /// One task ticked. [task] is `log_puff`, `meet_coach` or `danger_hours` —
  /// or `first_checkin` when the first move was confirming a vape-free day,
  /// which is what it is for somebody whose line is zero.
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

  /// A new plan was started on the same account (`PlanRestart`).
  ///
  /// [fromDay] is the day of the plan being left and [pastFreedom] whether it
  /// had already ended — the two cases the feature exists for are a finished
  /// plan with the person still vaping, and a plan that stopped fitting
  /// half-way. Before Nov 2026 both ended in a sign-out and a new account.
  void planRestarted({
    required int fromDay,
    required bool pastFreedom,
    required String method,
    required int pace,
    required int planNumber,
  }) => track(
    AnalyticsEvent('plan_restarted', {
      'from_day': fromDay,
      'past_freedom': pastFreedom.toString(),
      'method': method,
      'pace': pace,
      'plan_number': planNumber,
    }),
  );

  /// The daily program's card was shown (docs/15 QP-B4): [day] is the program
  /// day (days from the quit date, −7 … 56) and [slot] is `morning`, `evening`
  /// or `checkup` for a day that carries only a question. Once per day and slot
  /// per visit to Home, so a rebuild is never counted twice.
  void programShown({required int day, required String slot}) =>
      track(AnalyticsEvent('program_shown', {'day': day, 'slot': slot}));

  /// A mood was answered on the card and its written reply shown. [mood] is the
  /// `Mood` name and [track] is `onTrack` or `slipped` — the two things the
  /// reply depends on. Never the note.
  void programReply({required String mood, required String track}) =>
      // `this.`: the parameter named `track` would otherwise shadow the method.
      this.track(AnalyticsEvent('program_reply', {'mood': mood, 'track': track}));

  /// One of the card's help buttons was tapped. [kind] is `craving`, `stress`,
  /// `slipped` or `more`.
  void programHelp(String kind) =>
      track(AnalyticsEvent('program_help', {'kind': kind}));

  /// A daily-program check-up was answered (docs/15 QP-B7). [kind] is the
  /// question (`nicotine`, `vaped30`, `vaped90`) and [answer] what it was
  /// answered with, both enum names — coarse values, never anything typed.
  ///
  /// Reported when GIVEN, as well as stored on the journey: an older build on a
  /// second device rewrites the whole journey document and would drop the
  /// stored copy, so this is the record that cannot be overwritten.
  void checkupAnswered({required String kind, required String answer}) => track(
    AnalyticsEvent('checkup_answered', {'kind': kind, 'answer': answer}),
  );

  /// The 30- or 90-day question was answered: [at] is the horizon in days and
  /// [vapeFree] whether the person says they have not vaped in the last thirty.
  /// The number the program exists to move, read straight off the funnel.
  void quitStatusReported({required int at, required bool vapeFree}) => track(
    AnalyticsEvent('quit_status_reported', {
      'at': at,
      'vape_free': vapeFree.toString(),
    }),
  );

  /// The one-time home-screen widget card was put on Home (docs/15 QP-C2).
  /// [way] is how this device adds one: `pinDialog` (Android's system dialog)
  /// or `walkthrough` (the three steps on an iPhone). Marked once per device
  /// and account, so this is also the denominator for `widget_prompt_accepted`.
  void widgetPromptShown(WidgetAddWay way) =>
      track(AnalyticsEvent('widget_prompt_shown', {'way': way.name}));

  /// The card's button was tapped: the system dialog was requested
  /// (`pinDialog`) or "Got it" was pressed after the three steps
  /// (`walkthrough`). **Not** that a widget was added — the dialog has no
  /// callback — which is what `widget_installed` is for.
  ///
  /// The two ways are not the same act, so read them apart: on Android this is
  /// a request the launcher has just been given, on an iPhone it only says the
  /// steps were read, before the person has gone to the home screen at all.
  void widgetPromptAccepted(WidgetAddWay way) =>
      track(AnalyticsEvent('widget_prompt_accepted', {'way': way.name}));

  /// A Cirrus widget was found on the home screen after the person accepted
  /// the offer: the first re-read of the launcher on resume that counted more
  /// widgets than before the dialog. Once per acceptance. It is attributed to
  /// the card by order alone — a widget added from the home screen's own
  /// picker between the request and the re-read would be counted too, and
  /// nothing can tell the two apart.
  void widgetInstalled() => track(const AnalyticsEvent('widget_installed', {}));

  /// "Adjust my plan" moved Freedom Day (docs/15 QP-A11). [deltaDays] is the
  /// shift in calendar days: negative when the date came closer, positive when
  /// it moved out. Never reported for an adjustment that left the date where it
  /// was — that one is not an adjustment.
  void planAdjusted({required int deltaDays}) =>
      track(AnalyticsEvent('plan_adjusted', {'delta_days': deltaDays}));

  /// A slip was resolved on the slip screen (docs/15 QP-A10). [keptDate] is
  /// whether the person kept their Freedom Day (true) or added days to it
  /// (false). "Talk it through first" is not a resolution, so it reports
  /// nothing: the slip card stays until they decide.
  ///
  /// A slip used to stretch the plan whichever button was pressed, so this
  /// split could not be asked of the data at all.
  void slipResolved({required bool keptDate}) => track(
    AnalyticsEvent('slip_resolved', {'kept_date': keptDate.toString()}),
  );

  /// The More help page was opened (docs/15 QP-A7). [source] is the door:
  /// `settings`, `onboarding`, `home`, `slip`, `program`, or `direct` for a link
  /// with none.
  ///
  /// Whether anyone ever looks for a person or a medicine was unmeasured. Add
  /// a door, add it here.
  void helpViewed(String source) =>
      track(AnalyticsEvent('help_viewed', {'source': source}));

  /// A link on the More help page was opened. [kind] is `call`, `web`,
  /// `source` (the official page an entry was checked against) or `medicine`
  /// (the research link). Never the number or the URL: those say where a
  /// person was, and the kind is enough to tell what the page is for.
  void helpLinkOpened(String kind) =>
      track(AnalyticsEvent('help_link_opened', {'kind': kind}));

  /// Somebody signed out, and where they were when they did.
  ///
  /// Five of the seven people who signed out before Nov 2026 created a new
  /// account straight afterwards — one of them a paying subscriber — and it
  /// could only be seen by reading the screens before it. Fired before the
  /// identity is reset, so it lands under the account that left.
  void signedOut({
    required int planDay,
    required bool pastFreedom,
    required bool premium,
  }) => track(
    AnalyticsEvent('signed_out', {
      'plan_day': planDay,
      'past_freedom': pastFreedom.toString(),
      'premium': premium.toString(),
    }),
  );

  /// The tier changed from anything other than a purchase on this device:
  /// a renewal, an expiry, a restore, a change made on another device.
  void entitlementChanged(String tier) =>
      track(AnalyticsEvent('entitlement_changed', {'tier': tier}));

  // --- the habit loop ------------------------------------------------------

  /// Not in docs/02 §7, but the north star is Weekly Active Quitters — users
  /// who log on 4+ days a week — and that is uncountable without this.
  ///
  /// [source] is `app` for a tap inside the app and `widget` for one that
  /// came off the outbox — the home-screen widget, the lock screen or the
  /// wrist, which queue through the same log and are not told apart there.
  /// Until Nov 12 2026 the event carried nothing, so whether anybody used the
  /// widget at all could not be read.
  void puffLogged({String source = 'app'}) =>
      track(AnalyticsEvent('puff_logged', {'source': source}));

  /// A day was confirmed vape-free: the card on Home, the morning-after
  /// question about yesterday, or the main button on a zero-limit day.
  ///
  /// The habit loop of somebody who has stopped. `puff_logged` was the only
  /// loop event, so a person quitting cold turkey who opened the app every
  /// evening and confirmed the day looked exactly like one who never came
  /// back. [today] is false for a past day; [zeroDay] says the day's limit
  /// was 0 (cold turkey, the taper's last days, after Freedom Day).
  void dayConfirmed({required bool today, required bool zeroDay}) => track(
    AnalyticsEvent('day_confirmed', {
      'day': today ? 'today' : 'past',
      'zero_day': zeroDay.toString(),
    }),
  );

  /// The evening mood check-in was answered. [mood] is the `Mood` name —
  /// one of five — and the note the person may have typed is never sent.
  void moodCheckedIn(String mood) =>
      track(AnalyticsEvent('mood_checked_in', {'mood': mood}));

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

  // --- the coach and the community -----------------------------------------
  // Two of the four tabs, and until Oct 5 2026 neither said anything but
  // "this screen was opened". Opening the coach and talking to it are not the
  // same thing, and only one of them costs a model call.

  /// Something was said to the coach. Counts the ask, not the answer, so a
  /// turn the connection lost is still a person who tried.
  ///
  /// [chip] is one of the four static chips rather than typed words; [panic]
  /// is a turn sent from inside the craving flow. The words themselves never
  /// leave the device through this door.
  void coachMessageSent({required bool chip, required bool panic}) => track(
    AnalyticsEvent('coach_message_sent', {
      'kind': chip ? 'chip' : 'typed',
      'panic': panic.toString(),
    }),
  );

  /// The backend accepted a post. [tag] is the `PostTag` name.
  ///
  /// Fired on the acknowledgement, not on the tap: a post the server refused
  /// is a `limit_reached` or a moderation matter, and one that never left the
  /// phone reached nobody.
  void communityPostCreated(String tag) =>
      track(AnalyticsEvent('community_post_created', {'tag': tag}));

  /// The backend accepted a reply. [toSos] is whether the thread is somebody's
  /// SOS — the loop docs/03 §7 calls someone else pulling you out.
  void communityReplyCreated({required bool toSos}) => track(
    AnalyticsEvent('community_reply_created', {'sos': toSos.toString()}),
  );
}
