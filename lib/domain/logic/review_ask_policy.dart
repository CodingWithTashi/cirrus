import '../date_key.dart';

/// When the app may ask for a store rating.
///
/// Apple Guideline 5.6.3 and the Ratings and Reviews HIG say the same thing
/// from two sides: ask only after the person has *demonstrated* engagement,
/// never on first launch or during onboarding, never in the middle of a task,
/// and never often. The Sep 11 2026 App Store rejection was for exactly the
/// first of those — the ask used to be onboarding step D3, one screen after
/// hold-to-commit and one before the paywall, on an account minutes old.
///
/// The ask now lives on the Survived screen (Frame 35), the moment a craving
/// has just been beaten, and only once the person has beaten a few of them
/// over a few days. That is the app's own proof of value, in the app's own
/// terms: "The panic button got me through week one" is the sentence a
/// reviewer would write, and it can only be written by somebody who used it.
///
/// Pure, so each rule below is a one-line test rather than a device session.
/// The gating rules that are NOT here are structural: review gating (asking
/// for an opinion first, or routing by sentiment) is forbidden by both stores
/// and there is no parameter to pass one in; and neither OS reports whether its
/// sheet appeared, so nothing downstream may claim a rating happened.
abstract final class ReviewAskPolicy {
  /// Whether the Survived screen shows the ask right now.
  ///
  /// - Plan day below [minPlanDay] → no. A day-1 or day-2 account has not had
  ///   "enough time to gain a clear understanding of the app's value" — the
  ///   rejection's own words.
  /// - Fewer than [minCravingsSurvived] cravings beaten (counting this one) →
  ///   no. One survived craving is the feature working once; three is a habit
  ///   of reaching for it.
  /// - Already asked [lifetimeCap] times → no, ever again.
  /// - Asked within the last [minDaysBetweenAsks] calendar days → no. A "not
  ///   now" means not now, not "ask me on the next craving".
  static bool shouldAsk({
    required int planDay,
    required int cravingsSurvived,
    required int askedCount,
    required DateTime? lastAskedAt,
    required DateTime now,
  }) {
    if (planDay < minPlanDay) return false;
    if (cravingsSurvived < minCravingsSurvived) return false;
    if (askedCount >= lifetimeCap) return false;
    if (lastAskedAt != null &&
        LpDate.daysBetween(lastAskedAt, now) < minDaysBetweenAsks) {
      return false;
    }
    return true;
  }

  /// The earliest plan day the ask may appear on.
  ///
  /// Three, like `LaunchPaywallPolicy.milestoneDays.first`: the first hard
  /// stretch is behind them, and it is unambiguously past "first launch".
  static const int minPlanDay = 3;

  /// How many cravings must have been beaten, in total, before the ask.
  static const int minCravingsSurvived = 3;

  /// How many times one device may ever be asked.
  ///
  /// Two: a "not now" during a distracted moment should not cost the review
  /// forever, and a second "not now" is an answer. iOS caps its own sheet at
  /// three a year on top of this, and decides for itself whether to show it.
  static const int lifetimeCap = 2;

  /// Calendar days between one ask and the next.
  static const int minDaysBetweenAsks = 14;
}
