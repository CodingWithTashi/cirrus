import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/logic/money_engine.dart';
import 'package:last_puff/domain/logic/plan_reveal.dart';
import 'package:last_puff/domain/logic/taper_engine.dart';
import 'package:last_puff/domain/models/models.dart';

/// The four figures the reveal screen and the paywall both quote.
///
/// They used to be computed inline on the reveal step and nowhere else, so the
/// paywall — four screens later, and the screen that actually asks for money —
/// had none of them. Gathering them in one place is what stops the two screens
/// drifting apart; these tests are what stop the gathering from inventing
/// anything on the way.
void main() {
  final start = DateTime(2026, 9, 3);

  QuitPlan planWith({
    int puffs = 200,
    double spend = 25,
    int pace = 30,
    int stretch = 0,
  }) => QuitPlan(
    method: QuitMethod.taper,
    paceDays: pace,
    startDate: start,
    baselinePuffsPerDay: puffs,
    weeklySpend: spend,
    strength: NicStrength.mg50,
    stretchDays: stretch,
  );

  /// Day 1 of the plan — where onboarding always stands.
  DateTime onDay(int n) => LpDate.addDays(start, n - 1);

  group('PlanReveal.of', () {
    test('on day one it reads the engines, whole-curve', () {
      final plan = planWith();
      final reveal = PlanReveal.of(plan, now: onDay(1))!;

      // Pinned against the engines directly: if this type ever starts
      // computing instead of gathering, the two answers diverge and the app
      // quietly shows a person two different Freedom Days.
      expect(reveal.projectedSaved, MoneyEngine.projectedToFreedom(plan, 0));
      expect(reveal.puffsAvoided, TaperEngine.projectedPuffsAvoided(plan));
      expect(reveal.curve, TaperEngine.normalizedCurve(plan));
      expect(reveal.totalDays, plan.totalDays);
      expect(reveal.freedomDate, plan.freedomDate);
    });

    test('mid-plan it counts only what is still ahead', () {
      // THE REGRESSION THIS FILE EXISTS FOR. The paywall is reachable by a
      // returning free user on day 25 of 30 — the launch paywall, a premium
      // gate, Settings. Summing from day 1 there offers them a month of
      // savings they have already banked, under the label "saved by Freedom
      // Day". That is inventing the user's own data exactly as much as a
      // made-up statistic would be.
      final plan = planWith();
      final day1 = PlanReveal.of(plan, now: onDay(1))!;
      final day25 = PlanReveal.of(plan, now: onDay(25))!;

      expect(
        day25.projectedSaved,
        lessThan(day1.projectedSaved),
        reason: 'five days left cannot be worth as much as thirty',
      );
      expect(day25.puffsAvoided, lessThan(day1.puffsAvoided));

      // Exactly the engines' own answer for "the days after day 24".
      expect(day25.projectedSaved, MoneyEngine.projectedToFreedom(plan, 24));
      expect(
        day25.puffsAvoided,
        TaperEngine.projectedPuffsAvoided(plan, fromDay: 24),
      );

      // The date and the curve are properties of the plan, not of today.
      expect(day25.freedomDate, day1.freedomDate);
      expect(day25.curve, day1.curve);
    });

    test('the last day still has something ahead of it', () {
      final reveal = PlanReveal.of(planWith(), now: onDay(30));
      expect(reveal, isNotNull, reason: 'Freedom Day itself is not the past');
    });

    test('is null once the plan is over', () {
      // The launch paywall reappears once a day, forever. Past Freedom Day
      // there is no upcoming milestone to promise, and printing a date from
      // last month under a trophy is not proof of anything.
      expect(PlanReveal.of(planWith(), now: onDay(31)), isNull);
      expect(PlanReveal.of(planWith(), now: onDay(400)), isNull);
    });

    test('carries the stretch a slip already earned', () {
      // A stretched plan moves Freedom Day. The paywall must quote the moved
      // one, not the original — that is the whole promise of "the plan bends".
      final stretched = planWith(stretch: 6);
      final reveal = PlanReveal.of(stretched, now: onDay(1))!;

      expect(reveal.totalDays, 36);
      expect(reveal.freedomDate, stretched.freedomDate);
      expect(reveal.freedomDate.isAfter(planWith().freedomDate), isTrue);

      // And the stretch keeps the plan alive past the original Freedom Day.
      expect(PlanReveal.of(stretched, now: onDay(31)), isNotNull);
    });

    test('is null when there is no real baseline to reveal', () {
      // An untouched onboarding draft has a baseline of zero. Rendering a
      // Freedom Day off that would invent the user's own data, so the caller
      // gets nothing to render instead.
      expect(PlanReveal.of(planWith(puffs: 0), now: onDay(1)), isNull);
      expect(PlanReveal.of(planWith(puffs: -1), now: onDay(1)), isNull);
    });

    test('is null when the plan has no days in it', () {
      expect(PlanReveal.of(planWith(pace: 0), now: onDay(1)), isNull);
    });

    test('survives a plan with no spend, and says so', () {
      // Spend is a required onboarding answer, so this is off the real path.
      // It still must not crash or print "$0 saved by Freedom Day": the puff
      // count and the date are real even when the money is not.
      final reveal = PlanReveal.of(planWith(spend: 0), now: onDay(1))!;

      expect(reveal.hasSaving, isFalse);
      expect(reveal.projectedSaved, 0);
      expect(
        reveal.puffsAvoided,
        greaterThan(0),
        reason: 'the taper still removes puffs when the spend is unknown',
      );
    });

    test('reports a saving whenever one exists', () {
      expect(PlanReveal.of(planWith(), now: onDay(1))!.hasSaving, isTrue);
    });
  });
}
