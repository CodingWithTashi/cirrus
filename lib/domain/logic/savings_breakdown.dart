import '../models/journey_state.dart';
import 'money_engine.dart';

/// What today adds to "saved so far" — the one sentence the (i) sheet says.
enum TodaySavings {
  /// Nothing logged or confirmed today, so today adds nothing yet.
  notCounted,

  /// Counted and under the usual day: every puff not taken is money kept.
  kept,

  /// Counted and at or over the usual day: today keeps nothing.
  nothingKept,

  /// The plan carries no spend (or no baseline), so nothing can be priced.
  unpriced,
}

/// The numbers behind the (i) beside every savings figure (docs/10 §40), each
/// one [MoneyEngine]'s — the sheet explains the figure, so it may never
/// compute a different one.
///
/// It exists because "saved so far" follows a rule nobody can read off the
/// number: a day counts only once it is CONFIRMED — a puff logged, or a
/// vape-free day confirmed. A new account reads $0 all morning, and its first
/// puff then adds nearly a whole usual day. Correct, and baffling unexplained.
class SavingsBreakdown {
  const SavingsBreakdown({
    required this.today,
    required this.usualPuffs,
    required this.usualDaySpend,
    required this.costPerPuff,
    required this.todayPuffs,
    required this.todayNotTaken,
    required this.todaySaved,
    required this.total,
  });

  factory SavingsBreakdown.of(JourneyState journey, TodaySnapshot snap) {
    final plan = journey.plan;
    final log = journey.logFor(snap.now);
    final counted = log?.isConfirmed ?? false;
    final puffs = log?.puffs ?? 0;
    final usual = plan.baselinePuffsPerDay;
    return SavingsBreakdown(
      today: plan.costPerPuff <= 0
          ? TodaySavings.unpriced
          : !counted
          ? TodaySavings.notCounted
          : puffs >= usual
          ? TodaySavings.nothingKept
          : TodaySavings.kept,
      usualPuffs: usual,
      usualDaySpend: plan.weeklySpend / 7,
      costPerPuff: plan.costPerPuff,
      todayPuffs: puffs,
      todayNotTaken: counted && puffs < usual ? usual - puffs : 0,
      todaySaved: log == null ? 0 : MoneyEngine.savedOn(plan, log),
      total: snap.savedLifetime,
    );
  }

  final TodaySavings today;

  /// The plan's baseline: puffs on a usual day before quitting.
  final int usualPuffs;

  /// What that usual day cost — the weekly spend over seven days.
  final double usualDaySpend;

  final double costPerPuff;

  /// Today's logged puffs.
  final int todayPuffs;

  /// Puffs under the usual day today; zero unless today is counted.
  final int todayNotTaken;

  /// What today adds to the total ([MoneyEngine.savedOn]).
  final double todaySaved;

  /// "Saved so far" — exactly the figure Home and Money show.
  final double total;
}
