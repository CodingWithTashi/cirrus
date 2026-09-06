import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/logic/taper_engine.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';

import '../helpers.dart';

/// `QuitPlan.dayNumber` — the ONE day-index formula on the client, read by
/// Home, the coach header, the widget mirror, the limit and the streak.
///
/// PARITY SUITE: mirrors the `dayNumber` cases in
/// `functions/test/taperEngine.test.ts` (1-based, survives a DST boundary),
/// which pin the server's `dayNumber(plan, dayKey)`; the Kotlin widget
/// recomputes the same thing from `planStartDayKey` with `LocalDate`.
void main() {
  QuitPlan planFrom(DateTime start, {int paceDays = 30}) => QuitPlan(
    method: QuitMethod.taper,
    paceDays: paceDays,
    startDate: start,
    baselinePuffsPerDay: 100,
    weeklySpend: 30,
    strength: NicStrength.mg50,
  );

  test('is 1-based from the start date, whatever the time of day', () {
    final plan = planFrom(DateTime(2026, 9, 4));
    expect(plan.dayNumber(DateTime(2026, 9, 4)), 1);
    expect(plan.dayNumber(DateTime(2026, 9, 4, 23, 59, 59)), 1);
    expect(plan.dayNumber(DateTime(2026, 9, 5, 0, 0, 1)), 2);
    expect(plan.dayNumber(DateTime(2026, 9, 5, 14, 12)), 2);
  });

  test('the day before the start is 0, and the snapshot clamps it to 1', () {
    // A journey seeded against a fixture clock, or a device clock set back.
    final plan = planFrom(DateTime(2026, 9, 4));
    expect(plan.dayNumber(DateTime(2026, 9, 3, 23)), 0);
    final s = journeyOnDay(1, now: DateTime(2026, 9, 4, 12));
    expect(TodaySnapshot.of(s, DateTime(2026, 9, 3, 12)).dayNumber, 1);
  });

  test('survives both DST boundaries without drifting a day', () {
    // US spring-forward 2026-03-08 and fall-back 2026-11-01. Calendar days,
    // never 24-hour arithmetic: the 23- and 25-hour days count as one each.
    final spring = planFrom(DateTime(2026, 3, 1));
    expect(spring.dayNumber(DateTime(2026, 3, 8, 23, 59)), 8);
    expect(spring.dayNumber(DateTime(2026, 3, 9, 0, 1)), 9);
    expect(spring.dayNumber(DateTime(2026, 3, 9, 23, 30)), 9);
    final fall = planFrom(DateTime(2026, 10, 25));
    expect(fall.dayNumber(DateTime(2026, 11, 1, 0, 30)), 8);
    expect(fall.dayNumber(DateTime(2026, 11, 1, 23, 30)), 8);
    expect(fall.dayNumber(DateTime(2026, 11, 2, 0, 30)), 9);
  });

  test('day 30 is the last day and day 31 is past the plan', () {
    final plan = planFrom(DateTime(2026, 9, 4));
    final freedom = LpDate.addDays(plan.startDate, 29);
    expect(plan.freedomDate, freedom);
    expect(plan.dayNumber(freedom), plan.totalDays);
    expect(plan.dayNumber(LpDate.addDays(freedom, 1)), plan.totalDays + 1);
    expect(TaperEngine.limitFor(plan, 30), 0);
  });

  test('a slip reflow moves Freedom Day, not the day number', () {
    final plan = planFrom(DateTime(2026, 9, 4));
    final stretched = TaperEngine.reflowAfterSlip(plan, extraDays: 2);
    final sep20 = DateTime(2026, 9, 20, 10);
    expect(stretched.totalDays, 32);
    expect(stretched.dayNumber(sep20), plan.dayNumber(sep20));
    expect(stretched.freedomDate, LpDate.addDays(plan.freedomDate, 2));
  });
}
