import '../models/models.dart';
import 'taper_engine.dart';

/// Money engine (docs/03 §4): every figure derives from the user's own spend.
///
/// One rule shared with the streak: a day counts only when it is CONFIRMED
/// (`DayLog.isConfirmed` — puffs logged, or vape-free confirmed). The day-1
/// journey is minted with an unconfirmed 0-puff log, and a mood check-in or a
/// survived craving mints one too; each used to be credited as a whole
/// baseline day kept, so a brand-new account read "$4 saved · 100 puffs not
/// taken" before its first puff. An unknown day is unknown, never a saving.
/// Mirrored by the coach card's sum in `functions/src/ai/memoryCard.ts`.
abstract final class MoneyEngine {
  /// Money kept on one confirmed day: `max(0, B − actual) × costPerPuff`;
  /// nothing for a day nobody confirmed.
  static double savedOn(QuitPlan plan, DayLog log) {
    if (!log.isConfirmed) return 0;
    final under = plan.baselinePuffsPerDay - log.puffs;
    return under <= 0 ? 0 : under * plan.costPerPuff;
  }

  /// Lifetime savings across all confirmed days.
  static double lifetimeSaved(QuitPlan plan, Iterable<DayLog> logs) =>
      logs.fold(0, (sum, log) => sum + savedOn(plan, log));

  /// Puffs avoided vs baseline across all confirmed days.
  static int puffsNotTaken(QuitPlan plan, Iterable<DayLog> logs) =>
      logs.fold(0, (sum, log) {
        if (!log.isConfirmed) return sum;
        final under = plan.baselinePuffsPerDay - log.puffs;
        return sum + (under > 0 ? under : 0);
      });

  /// Projected extra savings between tomorrow and Freedom Day if the user
  /// follows the curve.
  static double projectedToFreedom(QuitPlan plan, int fromDay) {
    var total = 0.0;
    for (var d = fromDay + 1; d <= plan.totalDays; d++) {
      total +=
          (plan.baselinePuffsPerDay - TaperEngine.limitFor(plan, d)) *
          plan.costPerPuff;
    }
    return total < 0 ? 0 : total;
  }

  /// Average money kept per confirmed day recently — powers "rolling in
  /// daily". Unconfirmed days are unknown, so they neither add nor dilute.
  static double dailyRunRate(QuitPlan plan, List<DayLog> recentLogs) {
    final known = [for (final log in recentLogs) if (log.isConfirmed) log];
    if (known.isEmpty) return 0;
    return lifetimeSaved(plan, known) / known.length;
  }

  /// Days until [goal] is funded at the current run rate (null = stalled).
  static int? daysToGoal(SavingsGoal goal, double saved, double runRate) {
    final remaining = goal.price - saved;
    if (remaining <= 0) return 0;
    if (runRate <= 0) return null;
    return (remaining / runRate).ceil();
  }
}
