/// When a free user opening the app is shown the paywall (docs/02 §5: upgrade
/// prompts are allowed at most once a day and must never become interstitial
/// spam; the founder's Sep 2 2026 call puts that one prompt on launch).
///
/// Pure, so every rule below is a one-line test rather than a device session.
abstract final class LaunchPaywallPolicy {
  /// Whether this launch gets the paywall.
  ///
  /// - No journey → nothing to gate; the sign-in and onboarding flows own the
  ///   screen.
  /// - Entitlement not [settled] → **no**. Offline at launch, or a billing
  ///   backend that has not answered yet, must never read as "known free":
  ///   a paying user would be shown a paywall for their own subscription.
  /// - Premium or trial → no.
  /// - Plan day 1 → no: they saw D5 minutes ago (and the day-1 checklist
  ///   redirect owns the tabs anyway).
  /// - Already shown today (local day key) → no. Once a day, never more.
  static bool shouldShow({
    required bool hasJourney,
    required int planDay,
    required bool settled,
    required bool isPremium,
    required String? lastShownDay,
    required String today,
  }) {
    if (!hasJourney) return false;
    if (!settled) return false;
    if (isPremium) return false;
    if (planDay <= 1) return false;
    if (lastShownDay == today) return false;
    return true;
  }
}
