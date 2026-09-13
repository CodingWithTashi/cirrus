import '../date_key.dart';
import '../models/models.dart';

/// The week card's verdicts — the hard day, the best day, and whether the
/// week is trending down — shared by Stats and the coach's in-thread card so
/// the two can never name different days for the same seven.
///
/// The coach card used to caption every week "trending down — {day} was the
/// hard one" with no trend computed at all, and painted today as the win
/// whatever its count was.
abstract final class WeekTrend {
  /// Index of the most puffs among days that had any; -1 when no day did.
  /// An empty day is not a hard day.
  static int hardestIndex(List<DayLog> week) {
    var hardest = -1;
    for (var i = 0; i < week.length; i++) {
      final log = week[i];
      if (log.puffs > 0 &&
          (hardest == -1 || log.puffs > week[hardest].puffs)) {
        hardest = i;
      }
    }
    return hardest;
  }

  /// Index of the fewest puffs among CONFIRMED, COMPLETED days; -1 when none
  /// is. An unlogged day is not a win nobody logged, and today is not a win
  /// yet: one puff at 08:10 would otherwise paint a day that ends at fifty
  /// as the best of the week.
  static int bestIndex(List<DayLog> week, DateTime now) {
    final today = LpDate.dayStart(now);
    var best = -1;
    for (var i = 0; i < week.length; i++) {
      final log = week[i];
      if (log.isConfirmed &&
          log.date.isBefore(today) &&
          (best == -1 || log.puffs < week[best].puffs)) {
        best = i;
      }
    }
    return best;
  }

  /// Whether [week] is trending down: its later completed, confirmed days
  /// average fewer puffs than its earlier ones.
  ///
  /// Today is excluded — it is still in progress. The confirmed completed
  /// days are split into an earlier and a later half of equal size (an odd
  /// middle day belongs to neither), and the answer is null when fewer than
  /// two such days exist: one point is not a trend.
  static bool? isDown(List<DayLog> week, DateTime now) {
    final today = LpDate.dayStart(now);
    final done = [
      for (final log in week)
        if (log.isConfirmed && log.date.isBefore(today)) log,
    ];
    if (done.length < 2) return null;
    final half = done.length ~/ 2;
    return _mean(done.sublist(done.length - half)) < _mean(done.sublist(0, half));
  }

  /// How [current] compares with [previous] as a signed percent, or null when
  /// the question has no honest answer.
  ///
  /// The average of a window's CONFIRMED days against the average of the
  /// window before it — an average, not a sum, so a week with three confirmed
  /// days is still comparable with one that has seven. Unconfirmed days are
  /// dropped from both sides rather than counted as zero: an unlogged day is
  /// unknown, and reading it as a perfect one is the same lie `MoneyEngine`
  /// refuses to tell.
  ///
  /// **Null is a real answer and must not collapse to 0** — `0` already means
  /// "flat", which the Stats pill paints volt as good news. Four ways to get
  /// nothing: an empty previous window (the plan is younger than two windows),
  /// no confirmed day in it, no confirmed day in [current], or a previous
  /// window that averaged zero — where the ratio is undefined and −100% would
  /// be an invention.
  ///
  /// Lifted out of `stats_screen.dart`, where it was inline in a build method,
  /// so the Stats pill and the watch's week card cannot drift apart. The
  /// caller supplies the windows (`DayWindow.trailing` / `.previous`), which
  /// keeps this pure over two lists like everything else here.
  static int? vsPrevious(List<DayLog> current, List<DayLog> previous) {
    final before = [
      for (final log in previous)
        if (log.isConfirmed) log,
    ];
    final now = [
      for (final log in current)
        if (log.isConfirmed) log,
    ];
    if (before.isEmpty || now.isEmpty) return null;
    final beforeAvg = _mean(before);
    if (beforeAvg <= 0) return null;
    return (((_mean(now) - beforeAvg) / beforeAvg) * 100).round();
  }

  static double _mean(List<DayLog> logs) =>
      logs.fold<int>(0, (sum, log) => sum + log.puffs) / logs.length;
}
