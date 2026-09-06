import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/logic/week_trend.dart';
import 'package:last_puff/domain/models/models.dart';

/// The week card's three verdicts, shared by Stats and the coach.
///
/// The coach's card used to caption EVERY week "trending down — {day} was the
/// hard one" with no trend computed, and painted today as the win whatever
/// its count. Stats had the right hard/best rules inline; they live here now
/// so the two cards cannot name different days for the same seven.
void main() {
  final monday = DateTime(2026, 8, 31);
  // Today is the seventh day (Sunday Sep 6), mid-afternoon.
  final now = DateTime(2026, 9, 6, 15);

  /// Seven days Mon–Sun. `null` is an unlogged day (the zero-puff,
  /// unconfirmed log `DayWindow.trailing` fills in); `0` a confirmed
  /// vape-free day.
  List<DayLog> week(List<int?> puffs) => [
    for (var i = 0; i < puffs.length; i++)
      DayLog(
        date: LpDate.addDays(monday, i),
        puffs: puffs[i] ?? 0,
        limit: 50,
        vapeFreeConfirmed: puffs[i] == 0,
      ),
  ];

  group('hardest and best', () {
    test('the hard day needs puffs, the best day needs confirmation', () {
      final w = week([null, 5, 3, 0, 9, 2, 1]);
      expect(WeekTrend.hardestIndex(w), 4);
      // The confirmed vape-free Thursday, not the unlogged Monday: an empty
      // day is not a win nobody logged.
      expect(WeekTrend.bestIndex(w, now), 3);
    });

    test('the best day is never today, however quiet it is so far', () {
      // One puff at breakfast is not the week's best day; the day ends at
      // fifty. Tuesday's 40 is.
      final w = week([50, 40, 60, 45, 55, 41, 1]);
      expect(WeekTrend.bestIndex(w, now), 1);
      // Today can still be the hard day: the most puffs SO FAR is a fact.
      expect(WeekTrend.hardestIndex(week([5, 4, 3, 2, 1, 1, 9])), 6);
    });

    test('are -1 when nothing qualifies', () {
      expect(WeekTrend.hardestIndex(week([null, null, 0])), -1);
      expect(WeekTrend.bestIndex(week([null, null, null]), now), -1);
      // Only today is confirmed: still nothing.
      expect(WeekTrend.bestIndex(week([null, null, null, null, null, null, 3]), now), -1);
    });

    test('ties go to the earliest day', () {
      expect(WeekTrend.hardestIndex(week([4, 9, 9, 1])), 1);
      expect(WeekTrend.bestIndex(week([4, 1, 1, 9]), now), 1);
    });
  });

  group('isDown', () {
    test('is true when the later half averages fewer puffs', () {
      expect(WeekTrend.isDown(week([10, 9, 8, 4, 3, 2, 7]), now), isTrue);
    });

    test('is false when the week is flat or rising', () {
      expect(WeekTrend.isDown(week([2, 3, 4, 8, 9, 10, 1]), now), isFalse);
      expect(WeekTrend.isDown(week([5, 5, 5, 5, 5, 5, 0]), now), isFalse);
    });

    test('is null with fewer than two confirmed completed days', () {
      // One point is not a trend — the day-1 account that was being told
      // "trending down" from a single bar.
      expect(WeekTrend.isDown(week([5, null, null, null, null, null, 7]), now), isNull);
      expect(WeekTrend.isDown(week([null, null, null, null, null, null, 7]), now), isNull);
    });

    test('never counts today, which is still in progress', () {
      // Six equal completed days and a quiet today so far: flat, not down.
      expect(WeekTrend.isDown(week([10, 10, 10, 10, 10, 10, 0]), now), isFalse);
    });

    test('skips unlogged days rather than reading them as zero', () {
      // Two unlogged days in the later half would otherwise pull its average
      // down and invent a downtrend.
      expect(WeekTrend.isDown(week([5, 5, 5, null, null, 6, 0]), now), isFalse);
    });

    test('an odd middle day belongs to neither half', () {
      // Five completed days: the 100 sits in the middle and sways nothing.
      expect(WeekTrend.isDown(week([10, 9, 100, 3, 2, null, 0]), now), isTrue);
    });
  });
}
