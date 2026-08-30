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

  void paywallViewed(String variant) =>
      track(AnalyticsEvent('paywall_viewed', {'variant': variant}));

  void trialStarted(String tier) =>
      track(AnalyticsEvent('trial_started', {'tier': tier}));

  void freeContinued() => track(const AnalyticsEvent('free_continued'));

  void winbackShown() => track(const AnalyticsEvent('winback_shown'));

  void winbackConverted() => track(const AnalyticsEvent('winback_converted'));

  // --- the habit loop ------------------------------------------------------

  /// Not in docs/02 §7, but the north star is Weekly Active Quitters — users
  /// who log on 4+ days a week — and that is uncountable without this.
  void puffLogged() => track(const AnalyticsEvent('puff_logged'));

  void cravingSurvived({required bool survived}) =>
      track(AnalyticsEvent('craving_outcome', {'survived': survived.toString()}));
}
