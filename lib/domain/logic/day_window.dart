import '../date_key.dart';
import '../models/journey_state.dart';
import '../models/models.dart';

/// Calendar-day windows over the journey's day map.
///
/// Exists because the Stats chart and the coach's week card used to window
/// over "the last N LOGGED days" — `logs.sublist(logs.length - 7)` — so any
/// day without a log fell out of the window and the whole chart slid into
/// the past. On Tue Sep 29 the "week" was Sep 21–27, long-pressing the "M"
/// bar opened "Edit Sep 21", and the day nobody logged could not be reached
/// to fix (QA M1 + H4, Aug 31 2026). A window is calendar days, walked with
/// [LpDate] so it survives DST; a day with no log is an empty log the user
/// can still long-press and fill in.
abstract final class DayWindow {
  /// The last [length] calendar days ending on [today] (inclusive), clamped
  /// to the plan's first day so day 3 shows three bars rather than four
  /// empty ones. Days with no log come back as zero-puff, unconfirmed logs
  /// carrying the limit the plan set that day.
  static List<DayLog> trailing(JourneyState s, DateTime today, int length) {
    final end = LpDate.dayStart(today);
    final planStart = LpDate.dayStart(s.plan.startDate);
    var first = LpDate.addDays(end, -(length - 1));
    if (first.isBefore(planStart)) first = planStart;
    // A plan that starts after today (frame-map previews, a journey seeded
    // against a fixture clock) still renders today rather than nothing.
    if (first.isAfter(end)) first = end;
    final count = LpDate.daysBetween(first, end) + 1;
    return [
      for (var i = 0; i < count; i++)
        s.days[LpDate.addDays(first, i)] ?? _empty(s, LpDate.addDays(first, i)),
    ];
  }

  /// The [length] calendar days immediately before the window
  /// [trailing] would return — for "vs last week" comparisons. Empty when
  /// the plan had not started yet.
  static List<DayLog> previous(JourneyState s, DateTime today, int length) {
    final current = trailing(s, today, length);
    final dayBefore = LpDate.addDays(current.first.date, -1);
    if (dayBefore.isBefore(LpDate.dayStart(s.plan.startDate))) return const [];
    return trailing(s, dayBefore, length);
  }

  static DayLog _empty(JourneyState s, DateTime day) =>
      DayLog(date: day, puffs: 0, limit: s.limitOn(day));
}
