import '../date_key.dart';
import '../models/journey_state.dart';
import '../models/models.dart';

/// The longest stretch without a logged puff, in whole hours — the Stats
/// "longest gap" record, derived from the hour buckets and never estimated.
///
/// It used to be `8 + longestStreak ~/ 2` capped at 16: a figure that read as
/// the user's own record and was a function of something else entirely ("8h"
/// for an account with no data at all). This walks what is actually known and
/// says nothing where nothing is.
///
/// Resolution is the hour bucket's. A puff at 09:05 and the next at 14:55 sit
/// in buckets 9 and 14, so hours 10–13 are empty and the record reads 4 —
/// "at least four whole hours" — where the true gap was 5h50. It never
/// overstates.
///
/// A day is KNOWN when its hours can be trusted: a confirmed vape-free day
/// (24 empty hours), or a logged day whose buckets account for every puff.
/// Anything else — no log, an unconfirmed zero day, a count the buckets do
/// not add up to (`editPastDay` changes the count, never the hours) — is
/// unknown: the run ends there and nothing is counted through it, the same
/// stance the streak takes on a day nobody logged.
///
/// And nothing is counted before the record has an anchor: the hours of the
/// first logged day before its first puff are the morning the account did
/// not exist yet — somebody who signed up at 9 PM after vaping all day would
/// otherwise open Stats to a 21-hour "record". A confirmed vape-free day is
/// its own anchor: the user vouched for the whole of it.
abstract final class PuffGaps {
  /// Whole hours of the longest puff-free stretch up to [now], or null when
  /// nothing known exists yet — a fresh account, or one with no trustworthy
  /// hours and no puff on record.
  ///
  /// The live stretch since [JourneyState.lastPuffAt] counts too, so a
  /// record still being set already shows (and agrees with the Health
  /// timeline, which is anchored to the same instant).
  static int? longestGapHours(JourneyState s, DateTime now) {
    final today = LpDate.dayStart(now);
    int? best;
    void record(int hours) {
      if (best == null || hours > best!) best = hours;
    }

    if (s.days.isNotEmpty) {
      var run = 0;
      // False until a puff has been walked or a confirmed vape-free day has:
      // before that there is nothing for a gap to be measured FROM.
      var anchored = false;
      var cursor = s.days.keys.reduce((a, b) => a.isBefore(b) ? a : b);
      while (!cursor.isAfter(today)) {
        final log = s.days[cursor];
        if (log == null || !_hoursKnown(log)) {
          // Unknown day: the run cannot continue through it.
          run = 0;
        } else {
          // Today's hours count only up to the current whole hour — the hour
          // in progress could still get a puff.
          final hours = cursor == today ? now.hour : 24;
          for (var h = 0; h < hours; h++) {
            if ((log.hourBuckets[h] ?? 0) > 0) {
              if (anchored) record(run);
              run = 0;
              anchored = true;
            } else if (anchored || log.puffs == 0) {
              run++;
            }
          }
          if (log.puffs == 0) anchored = true;
          if (anchored) record(run);
        }
        cursor = LpDate.addDays(cursor, 1);
      }
    }

    final lastPuffAt = s.lastPuffAt;
    if (lastPuffAt != null && !lastPuffAt.isAfter(now)) {
      record(now.difference(lastPuffAt).inHours);
    }
    return best;
  }

  /// Whether every puff of [log] is placed in an hour bucket (or the day is
  /// a confirmed vape-free one), so its empty hours are really empty.
  static bool _hoursKnown(DayLog log) {
    if (log.puffs == 0) return log.vapeFreeConfirmed;
    var placed = 0;
    for (final count in log.hourBuckets.values) {
      placed += count;
    }
    return placed == log.puffs;
  }
}
