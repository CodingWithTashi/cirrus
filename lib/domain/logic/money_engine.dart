import '../models/models.dart';
import 'taper_engine.dart';

/// Money engine (docs/03 §4): every figure derives from the user's own spend.
abstract final class MoneyEngine {
  /// Money kept on one day: `max(0, B − actual) × costPerPuff`.
  static double savedOn(QuitPlan plan, DayLog log) {
    final under = plan.baselinePuffsPerDay - log.puffs;
    return under <= 0 ? 0 : under * plan.costPerPuff;
  }

  /// Lifetime savings across all logged days.
  static double lifetimeSaved(QuitPlan plan, Iterable<DayLog> logs) =>
      logs.fold(0, (sum, log) => sum + savedOn(plan, log));

  /// Puffs avoided vs baseline across all logged days.
  static int puffsNotTaken(QuitPlan plan, Iterable<DayLog> logs) =>
      logs.fold(0, (sum, log) {
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

  /// Average money kept per day recently — powers "rolling in daily".
  static double dailyRunRate(QuitPlan plan, List<DayLog> recentLogs) {
    if (recentLogs.isEmpty) return 0;
    return lifetimeSaved(plan, recentLogs) / recentLogs.length;
  }

  /// Days until [goal] is funded at the current run rate (null = stalled).
  static int? daysToGoal(SavingsGoal goal, double saved, double runRate) {
    final remaining = goal.price - saved;
    if (remaining <= 0) return 0;
    if (runRate <= 0) return null;
    return (remaining / runRate).ceil();
  }
}
