import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/logic/puff_gaps.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';

/// The Stats "longest gap" record.
///
/// It used to be `8 + longestStreak ~/ 2` capped at 16 — always between 8h
/// and 16h, "8h" for an account with no data at all, rendered as the user's
/// own record. This suite pins the honest version: whole hours walked off the
/// hour buckets, unknown days breaking the run, nothing where nothing is.
void main() {
  final plan = QuitPlan(
    method: QuitMethod.taper,
    paceDays: 30,
    startDate: DateTime(2026, 9, 1),
    baselinePuffsPerDay: 100,
    weeklySpend: 30,
    strength: NicStrength.mg50,
  );

  JourneyState journey(Map<DateTime, DayLog> days, {DateTime? lastPuffAt}) =>
      JourneyState(
        profile: const UserProfile(alias: '@gapfox', avatarEmoji: '🦊'),
        plan: plan,
        days: days,
        cravingsSurvivedTotal: 0,
        repairTokens: 0,
        longestStreak: 0,
        goals: const [],
        earnedBadges: const {},
        lastPuffAt: lastPuffAt,
      );

  /// A logged day whose buckets account for every puff — unless [puffs] says
  /// otherwise, which is what `editPastDay` leaves behind.
  DayLog logged(DateTime date, Map<int, int> buckets, {int? puffs}) {
    final placed = buckets.values.fold(0, (a, b) => a + b);
    return DayLog(
      date: date,
      puffs: puffs ?? placed,
      limit: 95,
      hourBuckets: buckets,
    );
  }

  DayLog vapeFree(DateTime date) =>
      DayLog(date: date, puffs: 0, limit: 95, vapeFreeConfirmed: true);

  final sep1 = DateTime(2026, 9, 1);
  final sep2 = DateTime(2026, 9, 2);
  final sep3 = DateTime(2026, 9, 3);

  int? gap(JourneyState s, DateTime now) => PuffGaps.longestGapHours(s, now);

  test('nothing known means no record, not a number', () {
    expect(gap(journey({}), DateTime(2026, 9, 3, 14)), isNull);
  });

  test('a confirmed vape-free day is 24 empty hours', () {
    expect(gap(journey({sep1: vapeFree(sep1)}), DateTime(2026, 9, 2, 0, 30)), 24);
  });

  test('the hours before the first puff ever logged are not a gap', () {
    // Signed up at 9 PM after vaping all day: the twenty-one hours before
    // that first puff belong to a morning the account did not exist for.
    // Only the two hours after it are known-empty.
    final s = journey({
      sep1: logged(sep1, {21: 1}),
    });
    expect(gap(s, DateTime(2026, 9, 2, 0, 30)), 2);
  });

  test('a confirmed vape-free first day anchors the record from midnight', () {
    // The user vouched for the whole day, so the walk into the next morning
    // carries it: 24 hours plus the nine before the 9 AM puff.
    final s = journey({
      sep1: vapeFree(sep1),
      sep2: logged(sep2, {9: 2}),
    });
    expect(gap(s, DateTime(2026, 9, 2, 12)), 33);
  });

  test('only the whole hours between two puff hours count', () {
    // Puffs in buckets 1, 14 and 23: the empty stretches are 0, 2–13 and
    // 15–22. Twelve whole hours is the record; the true gap between the 1 AM
    // and 2 PM puffs is somewhere in (12h, 14h) and the record never claims
    // more than it knows.
    final s = journey({
      sep1: logged(sep1, {1: 5, 14: 3, 23: 2}),
    });
    expect(gap(s, DateTime(2026, 9, 2, 0, 30)), 12);
  });

  test('a run continues across midnight between two known days', () {
    // Sep 1: puffs at 2 AM and 6 PM, so 7 PM–midnight is five empty hours.
    // Sep 2: first puff at 2 PM — fourteen more. Nineteen in one stretch,
    // longer than anything inside either day alone.
    final s = journey(
      {
        sep1: logged(sep1, {2: 1, 18: 4}),
        sep2: logged(sep2, {14: 2}),
      },
      lastPuffAt: DateTime(2026, 9, 2, 14, 30),
    );
    expect(gap(s, DateTime(2026, 9, 2, 16)), 19);
  });

  test('an unlogged day breaks the run and contributes nothing', () {
    // Sep 1 ends with seventeen empty hours (7 AM–midnight); Sep 3 opens with
    // fourteen. Sep 2 is unknown, so those are two stretches, never one of
    // 17 + 24 + 14. Silence is not a clean day.
    final s = journey({
      sep1: logged(sep1, {2: 1, 6: 4}),
      sep3: logged(sep3, {14: 2}),
    });
    expect(gap(s, DateTime(2026, 9, 3, 16)), 17);
  });

  test('an unconfirmed zero-puff day is unknown, not empty', () {
    // The log a mood check-in mints: 0 puffs, nobody said vape-free.
    final s = journey({
      sep1: logged(sep1, {2: 1, 6: 4}),
      sep2: DayLog(date: sep2, puffs: 0, limit: 95),
      sep3: logged(sep3, {14: 2}),
    });
    expect(gap(s, DateTime(2026, 9, 3, 16)), 17);
  });

  test('a day whose count the buckets do not add up to is unknown', () {
    // `editPastDay` changes the count and leaves the hours alone, so a day
    // edited to 5 puffs with one placed in a bucket has four at unknown
    // hours. Its empty hours cannot be trusted.
    final s = journey({
      sep1: logged(sep1, {2: 1, 6: 4}),
      sep2: logged(sep2, {10: 1}, puffs: 5),
      sep3: logged(sep3, {14: 2}),
    });
    expect(gap(s, DateTime(2026, 9, 3, 16)), 17);
  });

  test('today counts only the hours already elapsed', () {
    // A puff at 1 AM, and it is 3:30 PM: hours 2–14 are thirteen known-empty
    // ones. Hours 15–23 have not happened and must not be counted as empty.
    final s = journey({
      sep1: logged(sep1, {1: 3}),
    });
    expect(gap(s, DateTime(2026, 9, 1, 15, 30)), 13);
  });

  test('the live stretch since the last puff can be the record', () {
    // Nothing logged since a 3 AM puff two days ago. The days since are
    // unknown to the walk, but the last puff itself is a fact the Health
    // timeline already anchors on: 54 hours and counting.
    final s = journey(
      {
        sep1: logged(sep1, {1: 3, 3: 2}),
      },
      lastPuffAt: DateTime(2026, 9, 1, 3, 30),
    );
    expect(gap(s, DateTime(2026, 9, 3, 10)), 54);
  });

  test('a last puff stamped after now is ignored', () {
    final s = journey({}, lastPuffAt: DateTime(2026, 9, 5));
    expect(gap(s, DateTime(2026, 9, 3)), isNull);
  });

  test('whole hours, never rounded up', () {
    final s = journey({}, lastPuffAt: DateTime(2026, 9, 3, 12, 1));
    expect(gap(s, DateTime(2026, 9, 3, 14)), 1);
  });

  test('walks the fall-back day as 24 buckets, not 25 hours', () {
    // US clocks fall back on 2026-11-01. Two confirmed vape-free days either
    // side of it are 48 known-empty hours; a walk on absolute time would
    // land off the day map and count them as one.
    final oct31 = DateTime(2026, 10, 31);
    final nov1 = DateTime(2026, 11, 1);
    final s = journey({oct31: vapeFree(oct31), nov1: vapeFree(nov1)});
    expect(gap(s, DateTime(2026, 11, 2, 0, 30)), 48);
  });
}
