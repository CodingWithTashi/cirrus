import '../date_key.dart';
import '../models/models.dart';

/// Where "last puff" may honestly sit once puffs are taken back (docs/10 §41).
///
/// `lastPuffAt` only ever moves forward when a puff is logged, and nothing
/// moved it back when one was taken away — so an accidental tap and its Undo
/// restarted the health timeline from the moment of the tap, for a puff that no
/// longer existed.
abstract final class PuffAnchor {
  /// [anchor] while a logged puff still sits in its hour; otherwise the end of
  /// the latest earlier hour that still holds one.
  ///
  /// The hour's END is the latest moment that puff can have happened, so a
  /// correction never makes the stretch since the last puff look longer than
  /// it was. A day whose hour buckets do not account for its count — logged
  /// without hours, or corrected since (`editPastDay` changes the count and
  /// never the hours) — gives nothing to judge by, the rule `PuffGaps`
  /// applies: an anchor inside it stays, and an earlier such day counts to
  /// its last second. Null when no logged puff is left at all.
  static DateTime? settle(Map<DateTime, DayLog> days, DateTime? anchor) {
    if (anchor == null) return null;
    final anchorDay = LpDate.dayStart(anchor);
    final anchorHour = LpDate.hour(anchor);
    final own = days[anchorDay];
    if (own != null &&
        own.puffs > 0 &&
        (!_hoursKnown(own) || (own.hourBuckets[anchorHour] ?? 0) > 0)) {
      return anchor;
    }
    final earlier = [
      for (final day in days.keys)
        if (!day.isAfter(anchorDay)) day,
    ]..sort((a, b) => b.compareTo(a));
    for (final day in earlier) {
      final log = days[day]!;
      if (log.puffs <= 0) continue;
      if (!_hoursKnown(log)) {
        if (day == anchorDay) continue;
        return LpDate.addDays(day, 1).subtract(const Duration(seconds: 1));
      }
      final hours = [
        for (final entry in log.hourBuckets.entries)
          if (entry.value > 0 && (day != anchorDay || entry.key < anchorHour))
            entry.key,
      ];
      if (hours.isEmpty) continue;
      final latest = hours.reduce((a, b) => a > b ? a : b);
      return DateTime(day.year, day.month, day.day, latest, 59, 59);
    }
    return null;
  }

  static bool _hoursKnown(DayLog log) =>
      log.hourBuckets.values.fold(0, (a, b) => a + b) == log.puffs;
}
