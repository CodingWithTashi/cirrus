import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/logic/launch_paywall_policy.dart';

void main() {
  bool show({
    bool hasJourney = true,
    int planDay = 5,
    bool settled = true,
    bool isPremium = false,
    String? lastShownDay,
    String today = '2026-09-02',
  }) => LaunchPaywallPolicy.shouldShow(
    hasJourney: hasJourney,
    planDay: planDay,
    settled: settled,
    isPremium: isPremium,
    lastShownDay: lastShownDay,
    today: today,
  );

  test('a known-free user on a later day, not yet shown today, is shown', () {
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
}
