import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/logic/launch_paywall_policy.dart';

/// The one paywall nobody asks for.
///
/// docs/02 §5 says upgrade prompts are "contextual only … never interstitial
/// spam, max 1/day" — and this is a full-screen paywall on app open, tied to no
/// cap the user just hit. It used to fire on every launch-day of a free
/// account's life, forever, from the worst-converting placement band there is
/// (in-app with no context, 0.76–0.89% against the D5 slot's 1.35%, Adapty
/// 2026). Very little bought, with a slow-burning one-star risk.
///
/// It now appears on four days, ever (docs/12 §4.2).
void main() {
  bool show({
    bool hasJourney = true,
    int planDay = 3,
    bool settled = true,
    bool isPremium = false,
    String? lastShownDay,
    String today = '2026-09-02',
    int shownCount = 0,
  }) => LaunchPaywallPolicy.shouldShow(
    hasJourney: hasJourney,
    planDay: planDay,
    settled: settled,
    isPremium: isPremium,
    lastShownDay: lastShownDay,
    today: today,
    shownCount: shownCount,
  );

  test('a known-free user on a milestone day, not yet shown today, is shown', () {
    expect(show(), isTrue);
    expect(show(lastShownDay: '2026-09-01'), isTrue);
  });

  test('once a day: shown today means not again today', () {
    expect(show(lastShownDay: '2026-09-02'), isFalse);
  });

  test('never for premium or trial', () {
    expect(show(isPremium: true), isFalse);
  });

  test('never when the entitlement is not settled — offline is not free', () {
    expect(show(settled: false), isFalse);
  });

  test('never on plan day 1, and never without a journey', () {
    expect(show(planDay: 1), isFalse);
    expect(show(planDay: 0), isFalse);
    expect(show(hasJourney: false), isFalse);
  });

  test('only on the milestone days', () {
    for (final day in LaunchPaywallPolicy.milestoneDays) {
      expect(show(planDay: day), isTrue, reason: 'day $day');
    }
    // The days in between are the ones this used to take, every single one of
    // them, for as long as the account stayed free.
    for (final day in [2, 4, 5, 6, 8, 13, 15, 29, 31, 60, 365]) {
      expect(show(planDay: day), isFalse, reason: 'day $day');
    }
  });

  test('the milestones are days the app already marks, in order', () {
    expect(LaunchPaywallPolicy.milestoneDays, [3, 7, 14, 30]);
    expect(
      LaunchPaywallPolicy.milestoneDays,
      orderedEquals([...LaunchPaywallPolicy.milestoneDays]..sort()),
    );
    expect(LaunchPaywallPolicy.milestoneDays.toSet(), hasLength(4));
  });

  test('four times, ever', () {
    expect(show(shownCount: LaunchPaywallPolicy.lifetimeCap - 1), isTrue);
    expect(show(shownCount: LaunchPaywallPolicy.lifetimeCap), isFalse);
    expect(show(shownCount: LaunchPaywallPolicy.lifetimeCap + 5), isFalse);
  });

  test('the cap holds even when a plan restart repeats a milestone', () {
    // `planDay` is NOT monotonic: a Comeback restarts the plan and brings day
    // 3 round again. Without the counter that is a fifth paywall on a day the
    // milestone list happily allows.
    expect(
      show(planDay: 3, shownCount: LaunchPaywallPolicy.lifetimeCap),
      isFalse,
    );
  });

  test('the cap matches the ladder — a fifth showing means something re-ran', () {
    expect(
      LaunchPaywallPolicy.lifetimeCap,
      LaunchPaywallPolicy.milestoneDays.length,
    );
  });
}
