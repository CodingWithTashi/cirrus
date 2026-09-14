import '../date_key.dart';
import '../models/models.dart';
import 'dependence_engine.dart';

/// Which way a series moved between its last two points.
enum TrendDirection { down, up, flat }

/// What the Stats nicotine card may honestly say (docs/10 §41).
///
/// The card printed "≈ 14mg ↓" with the arrow inside the translated string, so
/// it pointed down beside a line that climbed. Its figure was the second-to-last
/// LOGGED day — yesterday only when today already had a log, the day before
/// yesterday on any morning before the first puff — and its line plotted every
/// log, so a day nobody logged dropped to zero and today's unfinished count
/// dragged the end of the line down.
///
/// Everything here is over completed, confirmed days: a day that is over, which
/// the person logged or confirmed vape-free.
class NicotineTrend {
  const NicotineTrend({
    required this.series,
    required this.latestMg,
    required this.direction,
  });

  factory NicotineTrend.of(
    Iterable<DayLog> logs,
    NicStrength strength,
    DateTime now,
  ) {
    final today = LpDate.dayStart(now);
    final days = [
      for (final log in logs)
        if (log.isConfirmed && log.date.isBefore(today)) log,
    ]..sort((a, b) => a.date.compareTo(b.date));
    final series = [
      for (final day in days) DependenceEngine.nicotineMg(day.puffs, strength),
    ];
    return NicotineTrend(
      series: series,
      latestMg: series.isEmpty ? null : series.last,
      direction: series.length < 2
          ? null
          : series.last < series[series.length - 2]
          ? TrendDirection.down
          : series.last > series[series.length - 2]
          ? TrendDirection.up
          : TrendDirection.flat,
    );
  }

  /// Milligrams per completed, confirmed day, oldest first.
  final List<double> series;

  /// The most recent of them; null until one exists.
  final double? latestMg;

  /// The most recent against the one before it; null with fewer than two.
  final TrendDirection? direction;
}
