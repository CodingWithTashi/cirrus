import '../date_key.dart';
import '../models/models.dart';

/// Freedom Streak + repair tokens (docs/03 §5).
///
/// One streak: consecutive confirmed days at-or-under that day's limit.
/// A repair token absorbs one over-limit day (flame dims, doesn't die);
/// tokens are earned 1 per 7 streak-days, wallet capped at 2.
///
/// Mirrored name-for-name by `functions/src/domain/streakEngine.ts`; any
/// change here lands there too, with parity cases in both test suites.
abstract final class StreakEngine {
  static const int tokenEveryDays = 7;
  static const int tokenWalletCap = 2;

  /// Whether a day keeps the chain alive: confirmed, and either under the
  /// line or saved by a token. The one predicate both walks below share.
  static bool holds(DayLog log) =>
      log.isConfirmed && (!log.isOverLimit || log.repairTokenUsed);

  /// Current streak counted backwards from [today] over [logsByDate].
  /// Days that used a repair token still count.
  static int currentStreak(Map<DateTime, DayLog> logsByDate, DateTime today) {
    var streak = 0;
    var cursor = LpDate.dayStart(today);
    // An unconfirmed (in-progress) or slipped today dims the flame, never
    // kills it (docs/02) — judge the chain from yesterday instead.
    final todayLog = logsByDate[cursor];
    if (todayLog == null || !holds(todayLog)) {
      cursor = LpDate.addDays(cursor, -1);
    }
    while (true) {
      final log = logsByDate[cursor];
      if (log == null || !holds(log)) break;
      streak++;
      cursor = LpDate.addDays(cursor, -1);
    }
    return streak;
  }

  /// The repair-token wallet, derived from history rather than stored.
  ///
  /// Walks every calendar day from the first log through YESTERDAY: each
  /// holding day extends a run, every [tokenEveryDays]th day of a run mints a
  /// token (never past [tokenWalletCap]), and a day that used a token spends
  /// one. A day that does not hold — unlogged, unconfirmed, over the line
  /// with no token — ends the run; the wallet itself carries over, because a
  /// token that was earned and never spent is still earned. Today can only
  /// SPEND: a token is earned by finishing the seventh day, not by starting
  /// it, so the day that would mint a token can never be the day it absorbs.
  /// (Minting mid-day funded a THIRD absorb on day 21 of the QA sim — the
  /// twenty-first holding day minted on its first puff and spent on its
  /// last.)
  ///
  /// Why derived: the wallet used to be stored and re-computed on every
  /// mutation as `streak ~/ 7`, which re-minted a spent token the moment the
  /// next commit ran — over-limit days 15, 20, 21 and 22 of a 30-day sim
  /// were ALL "absorbed" (QA H2, Aug 31 2026). A function of the day map
  /// cannot leak, and the server can recompute the same number, so Ember
  /// never quotes a wallet the Home screen contradicts. Clamped at zero: a
  /// `repairTokenUsed` day the old code let through still holds (nobody
  /// loses a streak over our bug), it just funds nothing.
  static int repairTokens(Map<DateTime, DayLog> logsByDate, DateTime today) {
    if (logsByDate.isEmpty) return 0;
    final todayKey = LpDate.dayStart(today);
    var cursor = logsByDate.keys.reduce((a, b) => a.isBefore(b) ? a : b);
    var run = 0;
    var tokens = 0;
    while (cursor.isBefore(todayKey)) {
      final log = logsByDate[cursor];
      if (log != null && holds(log)) {
        run++;
        if (run % tokenEveryDays == 0 && tokens < tokenWalletCap) tokens++;
        if (log.repairTokenUsed && tokens > 0) tokens--;
      } else {
        run = 0;
      }
      cursor = LpDate.addDays(cursor, 1);
    }
    final todayLog = logsByDate[todayKey];
    if (todayLog != null && todayLog.repairTokenUsed && tokens > 0) tokens--;
    return tokens;
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

  /// The next flame state that carries a BADGE — flicker (3), flame (7),
  /// blaze (14), inferno (30) — or null once the inferno is earned. Spark
  /// (1 day) is a flame state but not a milestone, which is how "next" read
  /// "day 0 of 1" after a streak reset (QA L5).
  static FlameState? nextBadgeFlame(int streakDays) {
    for (final state in FlameState.values) {
      if (state == FlameState.spark) continue;
      if (state.minDays > streakDays) return state;
    }
    return null;
  }
}
