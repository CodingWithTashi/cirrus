import '../date_key.dart';
import '../models/models.dart';

/// What an adjustment would do: the plan that would be stored, the date it
/// lands on, and how far that moved from where Freedom Day is now.
class PlanAdjustment {
  const PlanAdjustment({
    required this.plan,
    required this.freedomDate,
    required this.deltaDays,
  });

  /// The plan to store. Differs from the current one only in how long its
  /// runway is.
  final QuitPlan plan;

  /// Where Freedom Day lands. Equal to `plan.freedomDate`; here so the sheet's
  /// preview and the stored plan are the same value, not two calculations.
  final DateTime freedomDate;

  /// Calendar days from the current Freedom Day to the new one: negative when
  /// it comes closer, positive when it moves out. Never zero.
  final int deltaDays;
}

/// "What if Freedom Day were N days from today?" (docs/15 QP-A11).
///
/// "Adjust my plan" used to preselect the plan's current length and always pass
/// it, and the store read any length as "from today" — so an unchanged Apply on
/// day 10 of 30 made a 39-day plan. This is the one place that answers the
/// question, for the sheet's preview and for the store alike, and it answers
/// nothing when the date would not move.
///
/// Changes the date only. The baseline, the start date, the strength and the
/// method are the plan's own; a person who wants a different method or a fresh
/// start has "Start a new plan" (`PlanRestart`), which exists for exactly that.
abstract final class PlanAdjust {
  /// The adjustment that reaches Freedom Day [days] days from [today], or null
  /// when there is nothing to adjust:
  ///
  /// - [days] is not positive;
  /// - the plan is cold turkey, which has one date, the day it started;
  /// - the plan has already ended — that is a new plan, not an adjustment;
  /// - the date would not change.
  ///
  /// The stretch is spent into the chosen date rather than stacked on top of
  /// it, so the result carries none. Past days keep their recorded limits: the
  /// runway is measured from the plan's start, and only the future is redrawn.
  ///
  /// All day arithmetic is calendar arithmetic through [LpDate]; a day count
  /// from `Duration(days:)` is off by an hour across a clock change.
  static PlanAdjustment? toReach(QuitPlan plan, DateTime today, int days) {
    if (days <= 0) return null;
    if (plan.method == QuitMethod.coldTurkey) return null;
    final dayNumber = plan.dayNumber(today);
    if (dayNumber > plan.totalDays) return null;
    final currentDay = dayNumber < 1 ? 1 : dayNumber;

    final next = plan.copyWith(paceDays: currentDay - 1 + days, stretchDays: 0);
    final delta = LpDate.daysBetween(plan.freedomDate, next.freedomDate);
    if (delta == 0) return null;
    return PlanAdjustment(
      plan: next,
      freedomDate: next.freedomDate,
      deltaDays: delta,
    );
  }
}
