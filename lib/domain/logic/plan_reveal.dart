import '../models/models.dart';
import 'money_engine.dart';
import 'taper_engine.dart';

/// The four figures the plan reveal is made of, derived once from a [QuitPlan].
///
/// Onboarding step 16 shows a person their own Freedom Day, what they will have
/// saved by it, how many puffs they will not take, and the shape of the curve —
/// and then the paywall, four screens later, opened with six generic feature
/// rows and a price. The single strongest thing the funnel knows about someone
/// was computed, displayed once, and dropped immediately before the ask.
///
/// This exists so both screens read the same numbers from one place. The
/// engines stay the only source: nothing here computes, it only gathers.
class PlanReveal {
  const PlanReveal._({
    required this.totalDays,
    required this.freedomDate,
    required this.projectedSaved,
    required this.puffsAvoided,
    required this.curve,
  });

  /// Plan length including any stretch already earned.
  final int totalDays;

  /// The last day of the plan — the date both screens name.
  final DateTime freedomDate;

  /// Money not spent between now and [freedomDate].
  final double projectedSaved;

  /// Puffs the taper removes across the whole plan.
  final int puffsAvoided;

  /// The normalized taper curve, for the sparkline.
  final List<double> curve;

  /// Whether there is a saving worth putting on screen.
  ///
  /// Spend is a required onboarding answer, so this is true on every real
  /// path. It exists because "$0 saved by Freedom Day" is honest and useless,
  /// and an empty state beats a zero.
  bool get hasSaving => projectedSaved > 0;

  /// The reveal for [plan] as of [now], or null when there is nothing honest
  /// to show.
  ///
  /// **Everything here is what is still AHEAD of the person**, which is why
  /// [now] is required rather than optional. During onboarding the plan starts
  /// today, so "ahead" is the whole curve and this matches the reveal screen
  /// exactly. On the paywall a returning free user can be on day 25 of 30 —
  /// summing from day 1 there would offer them a month of savings they have
  /// already made, labelled "saved by Freedom Day". That is inventing the
  /// user's own data just as surely as a made-up statistic would.
  ///
  /// Two null cases, both deliberate:
  ///
  /// * **No baseline.** The paywall is reachable before any journey exists —
  ///   the launch paywall, a gate, Settings — and an untouched onboarding draft
  ///   would produce a Freedom Day computed from zero puffs a day.
  /// * **The plan is already over.** Past Freedom Day there is no upcoming
  ///   milestone to promise, and the launch paywall reappears daily forever;
  ///   printing a date from last month under a trophy is not proof of anything.
  static PlanReveal? of(QuitPlan plan, {required DateTime now}) {
    if (plan.baselinePuffsPerDay <= 0 || plan.totalDays <= 0) return null;

    // 1-based, so day one of a fresh plan leaves `fromDay` at 0 and the sums
    // below cover the whole curve — identical to the reveal screen.
    final today = plan.dayNumber(now);
    if (today > plan.totalDays) return null;
    final fromDay = (today - 1).clamp(0, plan.totalDays);

    return PlanReveal._(
      totalDays: plan.totalDays,
      freedomDate: plan.freedomDate,
      projectedSaved: MoneyEngine.projectedToFreedom(plan, fromDay),
      puffsAvoided: TaperEngine.projectedPuffsAvoided(plan, fromDay: fromDay),
      curve: TaperEngine.normalizedCurve(plan),
    );
  }
}
