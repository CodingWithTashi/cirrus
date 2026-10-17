/// When a free user opening the app is OFFERED Premium (docs/02 §5: upgrade
/// prompts are allowed at most once a day and must never become interstitial
/// spam; the founder's Sep 2 2026 call puts that one prompt on launch).
///
/// Since Oct 16 2026 the offer is a dismissible card on Home, not a paywall
/// pushed over it — users before money, and a full screen of price on opening
/// the app was the one unrequested prompt the product had (docs/10 §51). The
/// rules below did not change; only what a `true` puts on screen did. The
/// name stayed so the persisted counters it reads keep theirs.
///
/// Pure, so every rule below is a one-line test rather than a device session.
abstract final class LaunchPaywallPolicy {
  /// Whether this launch gets the offer.
  ///
  /// - No journey → nothing to gate; the sign-in and onboarding flows own the
  ///   screen.
  /// - Entitlement not [settled] → **no**. Offline at launch, or a billing
  ///   backend that has not answered yet, must never read as "known free":
  ///   a paying user would be shown a paywall for their own subscription.
  /// - Premium or trial → no.
  /// - Plan day 1 → no: they finished onboarding minutes ago (and the day-1
  ///   checklist redirect owns the tabs anyway).
  /// - Not a milestone day → no. See [milestoneDays].
  /// - Already shown [lifetimeCap] times → no, ever again.
  /// - Already shown today (local day key) → no. Once a day, never more.
  static bool shouldShow({
    required bool hasJourney,
    required int planDay,
    required bool settled,
    required bool isPremium,
    required String? lastShownDay,
    required String today,
    required int shownCount,
  }) {
    if (!hasJourney) return false;
    if (!settled) return false;
    if (isPremium) return false;
    if (planDay <= 1) return false;
    if (!milestoneDays.contains(planDay)) return false;
    if (shownCount >= lifetimeCap) return false;
    if (lastShownDay == today) return false;
    return true;
  }

  /// The only days the offer may appear on.
  ///
  /// This used to fire on EVERY launch-day of a free account's life, forever.
  /// Two problems with that, and they compound. It is the one door docs/02 §5
  /// forbids in its own words — "never interstitial spam", a full-screen
  /// paywall on app open, tied to no cap the user just hit. And it sits in the
  /// worst-converting placement band there is (in-app, no context, 0.76–0.89%
  /// against the D5 slot's 1.35% — Adapty 2026), so it was buying very little
  /// with a very slow-burning one-star risk.
  ///
  /// The days themselves are chosen to be *about* something: day 3 is where
  /// the first hard stretch lands, 7 is the first full week, 14 and 30 are the
  /// milestones the health timeline and the taper program already celebrate.
  /// A person on one of those days has just done something worth marking,
  /// which is the nearest a launch-time paywall can get to being contextual.
  static const List<int> milestoneDays = [3, 7, 14, 30];

  /// How many offers one account may ever see.
  ///
  /// Belt to [milestoneDays]' braces: `planDay` is not guaranteed monotonic —
  /// a Comeback restarts the plan, and day 3 would come round again. Four is
  /// the whole ladder above; a fifth would mean something re-ran.
  static const int lifetimeCap = 4;
}
