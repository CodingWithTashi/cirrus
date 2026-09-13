import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/logic/review_ask_policy.dart';

/// When the app may ask for a store rating.
///
/// The Sep 11 2026 App Store rejection (Guideline 5.6.3): "The app requests
/// users to rate the app on first launch or during onboarding, before they've
/// had enough time to gain a clear understanding of the app's value." The ask
/// was onboarding step D3. It is on the Survived screen now, and these are the
/// rules that keep it from being asked too early or too often there.
void main() {
  final now = DateTime(2026, 9, 11, 21, 30);

  bool ask({
    int planDay = 5,
    int cravingsSurvived = 3,
    int askedCount = 0,
    DateTime? lastAskedAt,
  }) => ReviewAskPolicy.shouldAsk(
    planDay: planDay,
    cravingsSurvived: cravingsSurvived,
    askedCount: askedCount,
    lastAskedAt: lastAskedAt,
    now: now,
  );

  test('an engaged account — day 3+, three cravings beaten — is asked', () {
    expect(ask(), isTrue);
    expect(ask(planDay: 3, cravingsSurvived: 3), isTrue);
    expect(ask(planDay: 40, cravingsSurvived: 60), isTrue);
  });

  test('never on day 1 or day 2, however many cravings', () {
    // The reviewer's account: created minutes ago.
    expect(ask(planDay: 1, cravingsSurvived: 1), isFalse);
    expect(ask(planDay: 1, cravingsSurvived: 50), isFalse);
    expect(ask(planDay: 2, cravingsSurvived: 50), isFalse);
  });

  test('never before the third survived craving', () {
    // One survived craving is the feature working once; the review is about
    // it having become a habit.
    expect(ask(cravingsSurvived: 0), isFalse);
    expect(ask(cravingsSurvived: 1), isFalse);
    expect(ask(cravingsSurvived: 2), isFalse);
  });

  test('a "not now" holds for two weeks', () {
    final yesterday = now.subtract(const Duration(days: 1));
    final thirteenDaysAgo = DateTime(2026, 8, 29, 21, 30);
    final fourteenDaysAgo = DateTime(2026, 8, 28, 21, 30);
    expect(ask(askedCount: 1, lastAskedAt: now), isFalse);
    expect(ask(askedCount: 1, lastAskedAt: yesterday), isFalse);
    expect(ask(askedCount: 1, lastAskedAt: thirteenDaysAgo), isFalse);
    expect(ask(askedCount: 1, lastAskedAt: fourteenDaysAgo), isTrue);
  });

  test('two asks, ever', () {
    final longAgo = DateTime(2026, 1, 1);
    expect(ask(askedCount: 1, lastAskedAt: longAgo), isTrue);
    expect(ask(askedCount: 2, lastAskedAt: longAgo), isFalse);
    expect(ask(askedCount: 9, lastAskedAt: longAgo), isFalse);
  });

  test('the spacing is calendar days, not 24-hour blocks', () {
    // 23 hours across a spring-forward is still "yesterday" and still no.
    // The point of the test is that the comparison is by date, which is what
    // `LpDate.daysBetween` guarantees; an `inDays` on the raw difference
    // would truncate a DST-shortened day to 0 and count it as today.
    final askedAt = DateTime(2026, 8, 28, 23, 59);
    final askedNow = DateTime(2026, 9, 11, 0, 1);
    expect(
      ReviewAskPolicy.shouldAsk(
        planDay: 5,
        cravingsSurvived: 3,
        askedCount: 1,
        lastAskedAt: askedAt,
        now: askedNow,
      ),
      isTrue,
    );
  });

  test('the thresholds are the documented ones', () {
    // Pinned so a "let's ask a bit earlier" is a deliberate edit here, with
    // the guideline in view, rather than a drift.
    expect(ReviewAskPolicy.minPlanDay, 3);
    expect(ReviewAskPolicy.minCravingsSurvived, 3);
    expect(ReviewAskPolicy.lifetimeCap, 2);
    expect(ReviewAskPolicy.minDaysBetweenAsks, 14);
  });
}
