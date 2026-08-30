import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

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
///
/// Privacy: no free text, no aliases, no message bodies — only enum names and
/// numbers the user gave us as structured answers. "We never sell your data"
/// (PRD §6) starts with not collecting it, and there are no third-party ad
/// SDKs in the app at all.
abstract final class LpAnalytics {
  static bool _enabled = false;

  /// Off for the fake backend (no Firebase project) and off in debug, so dev
  /// runs never pollute the funnel the launch gates are read from.
  static void configure({required bool enabled}) => _enabled = enabled;

  static Future<void> _log(
    String name, [
    Map<String, Object>? params,
  ]) async {
    if (!_enabled) return;
    try {
      await FirebaseAnalytics.instance.logEvent(name: name, parameters: params);
    } on Object catch (error) {
      // Analytics must never break a user flow.
      debugPrint('analytics: $name failed — $error');
    }
  }

  // --- onboarding funnel ---------------------------------------------------

  static Future<void> onboardingStart() => _log('onboarding_start');

  /// [screenId] is the `ObStep` name; [ms] is dwell time on that screen.
  static Future<void> screenCompleted(String screenId, int ms) =>
      _log('screen_completed', {'screen_id': screenId, 'ms': ms});

  /// Under-18s are turned away and nothing about them is stored (docs/02 A3).
  /// This counts the event only — no birth year, no identifiers.
  static Future<void> ageGateBlocked() => _log('age_gate_blocked');

  /// Someone typed an age instead of a year and took the offered swap.
  /// Tells us whether the age-entry affordance earns its keep. The value is
  /// never recorded — this is the same no-identifiers rule as [ageGateBlocked].
  static Future<void> ageEntryAdopted() => _log('age_entry_adopted');

  static Future<void> puffsEntered(int value, String badge) =>
      _log('puffs_entered', {'value': value, 'badge': badge});

  static Future<void> spendEntered(int weekly, int yearlyShown) =>
      _log('spend_entered', {'weekly': weekly, 'yearly_shown': yearlyShown});

  static Future<void> methodChosen(String method) =>
      _log('method_chosen', {'method': method});

  static Future<void> paceChosen(int days) =>
      _log('pace_chosen', {'pace_days': days});

  static Future<void> planRevealed() => _log('plan_revealed');

  static Future<void> commitHeld() => _log('commit_held');

  static Future<void> notifPrompt({required bool granted}) =>
      _log('notif_prompt', {'granted': granted.toString()});

  // --- paywall -------------------------------------------------------------

  static Future<void> paywallViewed(String variant) =>
      _log('paywall_viewed', {'variant': variant});

  static Future<void> trialStarted(String tier) =>
      _log('trial_started', {'tier': tier});

  static Future<void> freeContinued() => _log('free_continued');

  static Future<void> winbackShown() => _log('winback_shown');

  static Future<void> winbackConverted() => _log('winback_converted');

  // --- the habit loop ------------------------------------------------------

  /// Not in docs/02 §7, but the north star is Weekly Active Quitters — users
  /// who log on 4+ days a week — and that is uncountable without this.
  static Future<void> puffLogged() => _log('puff_logged');

  static Future<void> cravingSurvived({required bool survived}) =>
      _log('craving_outcome', {'survived': survived.toString()});
}
