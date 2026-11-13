import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/logic/plan_adjust.dart';
import 'package:last_puff/domain/models/models.dart';

/// docs/15 QP-A11. "Adjust my plan" preselected the current length and always
/// passed it, and the store read any length as "from today": day 10 of 30
/// became a 39-day plan on an unchanged Apply. A later quit date is a quit
/// date that slips (each week of delay raised the chance of lapsing by 19%,
/// Hughes 2010), so the helper answers one question — "what if Freedom Day
/// were N days from today?" — and says nothing when the date would not move.
void main() {
  QuitPlan plan({
    DateTime? start,
    int pace = 30,
    int stretch = 0,
    QuitMethod method = QuitMethod.taper,
  }) => QuitPlan(
    method: method,
    paceDays: pace,
    startDate: start ?? DateTime(2026, 11, 3),
    baselinePuffsPerDay: 200,
    weeklySpend: 45,
    strength: NicStrength.mg50,
    stretchDays: stretch,
  );

  // Day 10 of a plan that began Nov 3: today is Nov 12, Freedom Day is Dec 2,
  // which is 20 days from today.
  final today = DateTime(2026, 11, 12, 15, 30);
  final base = plan();

  test('the fixture is what the comments say it is', () {
    expect(base.dayNumber(today), 10);
    expect(base.freedomDate, DateTime(2026, 12, 2));
    expect(LpDate.daysBetween(LpDate.dayStart(today), base.freedomDate), 20);
  });

  group('choosing a length counts from today', () {
    test('a shorter one brings Freedom Day closer', () {
      final change = PlanAdjust.toReach(base, today, 14)!;
      // 14 days from today: Nov 12 + 13 = Nov 25.
      expect(change.freedomDate, DateTime(2026, 11, 25));
      expect(change.deltaDays, -7);
      expect(change.plan.freedomDate, change.freedomDate);
    });

    test('a longer one pushes it out', () {
      final change = PlanAdjust.toReach(base, today, 30)!;
      expect(change.freedomDate, DateTime(2026, 12, 11));
      expect(change.deltaDays, 9, reason: 'this is the old surprise: 30 on day 10');
    });

    test('the longest on offer', () {
      expect(PlanAdjust.toReach(base, today, 42)!.deltaDays, 21);
    });
  });

  group('a choice that would not move the date is not a change', () {
    test('21 days from day 10 of 30 is exactly where Freedom Day already is', () {
      expect(PlanAdjust.toReach(base, today, 21), isNull);
    });

    test('on day 1, choosing the plan\'s own length changes nothing', () {
      final dayOne = DateTime(2026, 11, 3, 9);
      expect(PlanAdjust.toReach(base, dayOne, 30), isNull);
    });
  });

  group('what the stored plan keeps and drops', () {
    test('the baseline, the start and the method never move', () {
      // The baseline is what every day already lived is priced against;
      // moving it would rewrite money saved backwards.
      final next = PlanAdjust.toReach(base, today, 30)!.plan;
      expect(next.baselinePuffsPerDay, base.baselinePuffsPerDay);
      expect(next.weeklySpend, base.weeklySpend);
      expect(next.startDate, base.startDate);
      expect(next.method, QuitMethod.taper);
      expect(next.strength, base.strength);
    });

    test('the runway is measured from the start, so past days keep their limits', () {
      final next = PlanAdjust.toReach(base, today, 30)!.plan;
      // 9 days already lived + 30 ahead.
      expect(next.paceDays, 39);
      expect(next.dayNumber(today), 10, reason: 'today is still day 10');
    });

    test('a stretch given earlier is folded into the date they chose', () {
      // Stretched by 4: Freedom Day is Dec 6 (24 days out). Asking for 30
      // days from today is Dec 11 — later by 5 — and the stretch is spent into
      // that date rather than stacked on top of it.
      final stretched = plan(stretch: 4);
      final change = PlanAdjust.toReach(stretched, today, 30)!;
      expect(change.deltaDays, 5);
      expect(change.plan.stretchDays, 0);
      expect(change.plan.freedomDate, DateTime(2026, 12, 11));
    });
  });

  group('when there is nothing to adjust', () {
    test('cold turkey has one date, the day it started', () {
      final cold = plan(method: QuitMethod.coldTurkey, pace: 1);
      expect(PlanAdjust.toReach(cold, today, 30), isNull);
    });

    test('a plan that has already ended is a new plan, not an adjustment', () {
      final long = DateTime(2026, 12, 20);
      expect(base.dayNumber(long), greaterThan(base.totalDays));
      expect(PlanAdjust.toReach(base, long, 30), isNull);
    });

    test('a non-positive length is refused', () {
      expect(PlanAdjust.toReach(base, today, 0), isNull);
      expect(PlanAdjust.toReach(base, today, -3), isNull);
    });
  });

  test('day arithmetic is calendar days across a clock change', () {
    // US clocks go back on Nov 1 2026. Counting 24-hour blocks instead of
    // calendar days lands an hour off the date key and miscounts by one — the
    // bug that zeroed every streak twice a year (CLAUDE.md, `LpDate`).
    final span = plan(start: DateTime(2026, 10, 20));
    final nov5 = DateTime(2026, 11, 5, 22, 40);
    expect(span.dayNumber(nov5), 17);
    expect(span.freedomDate, DateTime(2026, 11, 18));
    // 14 days from Nov 5 is Nov 18: unchanged.
    expect(PlanAdjust.toReach(span, nov5, 14), isNull);
    // 21 days from Nov 5 is Nov 25: seven days later.
    final later = PlanAdjust.toReach(span, nov5, 21)!;
    expect(later.freedomDate, DateTime(2026, 11, 25));
    expect(later.deltaDays, 7);
  });
}
