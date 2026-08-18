import '../models/models.dart';

/// Freedom Streak + repair tokens (docs/03 §5).
///
/// One streak: consecutive confirmed days at-or-under that day's limit.
/// A repair token absorbs one over-limit day (flame dims, doesn't die);
/// tokens are earned 1 per 7 streak-days, wallet capped at 2.
abstract final class StreakEngine {
  static const int tokenEveryDays = 7;
  static const int tokenWalletCap = 2;

  /// Current streak counted backwards from [today] over [logsByDate].
  /// Days that used a repair token still count.
  static int currentStreak(Map<DateTime, DayLog> logsByDate, DateTime today) {
    var streak = 0;
    var cursor = DateTime(today.year, today.month, today.day);
    // An unconfirmed (in-progress) or slipped today dims the flame, never
    // kills it (docs/02) — judge the chain from yesterday instead.
    final todayLog = logsByDate[cursor];
    final todayHolds =
        todayLog != null &&
        todayLog.isConfirmed &&
        (!todayLog.isOverLimit || todayLog.repairTokenUsed);
    if (!todayHolds) cursor = cursor.subtract(const Duration(days: 1));
    while (true) {
      final log = logsByDate[cursor];
      if (log == null) break;
      final holds =
          log.isConfirmed && (!log.isOverLimit || log.repairTokenUsed);
      if (!holds) break;
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static FlameState flameFor(int streakDays) =>
      FlameState.forStreak(streakDays);

  /// Whether today's flame renders dimmed (token burned today).
  static bool isDimmed(DayLog? todayLog) => todayLog?.repairTokenUsed ?? false;

  /// Days until the next flame state, or null at Inferno.
  static int? daysToNextFlame(int streakDays) {
    for (final state in FlameState.values) {
      if (state.minDays > streakDays) return state.minDays - streakDays;
    }
    return null;
  }
}
