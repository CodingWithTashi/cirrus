import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/date_key.dart';

/// `LpDate` is the one place local midnight and day keys are computed, so its
/// tests are the gate on the journey's whole day map.
///
/// These are deliberately ZONE-INDEPENDENT properties rather than "run this
/// under TZ=America/New_York" cases. `flutter test` cannot set a timezone per
/// test, and Dart on Windows ignores `$env:TZ` entirely (it reads the OS zone),
/// so a zone-pinned suite would silently assert nothing on the dev machine.
/// The calendar properties below hold in every zone — including the DST ones,
/// which is what makes them worth more than a fixture.
void main() {
  group('LpDate.dayStart', () {
    test('is byte-for-byte DateTime(y, m, d)', () {
      // Pinned against the literal expression on purpose: the day map is keyed
      // by this value and there is no server backup of `journeys/{uid}`.
      for (final t in [
        DateTime(2026, 8, 30, 14, 37, 5, 123, 456),
        DateTime(2026, 1, 1),
        DateTime(2026, 12, 31, 23, 59, 59),
      ]) {
        expect(LpDate.dayStart(t), DateTime(t.year, t.month, t.day));
      }
    });

    test('is idempotent', () {
      final once = LpDate.dayStart(DateTime(2026, 3, 8, 9, 30));
      expect(LpDate.dayStart(once), once);
    });
  });

  group('LpDate.addDays', () {
    test('always lands on local midnight of the target calendar date', () {
      // The DST property. `.add(Duration(days: 1))` returns 23:00 or 01:00 of
      // the neighbouring date across a transition; this must not.
      var day = DateTime(2026, 1, 1);
      for (var i = 0; i < 800; i++) {
        final next = LpDate.addDays(day, 1);
        expect(
          next,
          LpDate.dayStart(next),
          reason: '$next is not local midnight',
        );
        expect(next.hour, 0);
        expect(next.isAfter(day), isTrue);
        day = next;
      }
    });

    test('normalizes month, year and leap boundaries', () {
      expect(LpDate.addDays(DateTime(2026, 12, 31), 1), DateTime(2027, 1, 1));
      expect(LpDate.addDays(DateTime(2027, 1, 1), -1), DateTime(2026, 12, 31));
      expect(LpDate.addDays(DateTime(2028, 2, 28), 1), DateTime(2028, 2, 29));
      expect(LpDate.addDays(DateTime(2026, 2, 28), 1), DateTime(2026, 3, 1));
      expect(LpDate.addDays(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 1));
    });

    test('a zero delta is the identity on a midnight', () {
      final d = DateTime(2026, 10, 25);
      expect(LpDate.addDays(d, 0), d);
    });
  });

  group('LpDate.daysBetween', () {
    test('inverts addDays for every offset in a two-year window', () {
      // The core property: n days forward is n days apart, in any zone, across
      // every DST change, month end and leap day in the range.
      for (final start in [
        DateTime(2026, 1, 1),
        DateTime(2026, 3, 8), // US spring forward
        DateTime(2026, 3, 29), // EU spring forward
        DateTime(2026, 10, 25), // EU fall back
        DateTime(2026, 11, 1), // US fall back
        DateTime(2028, 2, 29), // leap day
      ]) {
        for (var n = -400; n <= 400; n++) {
          expect(
            LpDate.daysBetween(start, LpDate.addDays(start, n)),
            n,
            reason: 'start=$start delta=$n',
          );
        }
      }
    });

    test('spans a DST change as whole calendar days', () {
      // `to.difference(from).inDays` truncates the 23-hour spring-forward gap
      // to 1 across these two, and the 25-hour fall-back gap likewise.
      expect(
        LpDate.daysBetween(DateTime(2026, 3, 7), DateTime(2026, 3, 9)),
        2,
      );
      expect(
        LpDate.daysBetween(DateTime(2026, 10, 31), DateTime(2026, 11, 2)),
        2,
      );
      expect(
        LpDate.daysBetween(DateTime(2026, 10, 24), DateTime(2026, 10, 26)),
        2,
      );
    });

    test('ignores the time of day on either side', () {
      expect(
        LpDate.daysBetween(
          DateTime(2026, 8, 30, 23, 59),
          DateTime(2026, 8, 31, 0, 1),
        ),
        1,
      );
    });

    test('is negative when the second date precedes the first', () {
      expect(
        LpDate.daysBetween(DateTime(2026, 8, 31), DateTime(2026, 8, 30)),
        -1,
      );
    });
  });

  group('LpDate.dayKey', () {
    test('round-trips through parseDayKey to local midnight', () {
      for (final t in [
        DateTime(2026, 8, 30, 14, 37),
        DateTime(2026, 1, 5),
        DateTime(2026, 11, 1, 1, 30), // inside a fall-back repeated hour
        DateTime(999, 12, 31),
      ]) {
        expect(LpDate.parseDayKey(LpDate.dayKey(t)), LpDate.dayStart(t));
      }
    });

    test('zero-pads to the wire shape', () {
      expect(LpDate.dayKey(DateTime(2026, 1, 5)), '2026-01-05');
      expect(LpDate.dayKey(DateTime(999, 12, 31)), '0999-12-31');
      expect(LpDate.dayKey(DateTime(2026, 12, 31)), '2026-12-31');
    });

    test('every key it emits satisfies isDayKey', () {
      var day = DateTime(2026, 1, 1);
      for (var i = 0; i < 400; i++) {
        expect(LpDate.isDayKey(LpDate.dayKey(day)), isTrue);
        day = LpDate.addDays(day, 1);
      }
    });
  });

  group('LpDate.isDayKey', () {
    test('rejects anything that is not exactly yyyy-MM-dd', () {
      // Shape validation guards a Firestore path, so a slash or a traversal
      // must never pass — mirrors dateKey.test.ts.
      for (final bad in [
        null,
        '',
        '2026-8-28',
        '2026-08-28T00:00:00',
        '26-08-28',
        '2026/08/28',
        '../../etc',
        '2026-08-28 ',
        'not a date',
      ]) {
        expect(LpDate.isDayKey(bad), isFalse, reason: '$bad');
      }
    });

    test('accepts a well-formed key', () {
      expect(LpDate.isDayKey('2026-08-28'), isTrue);
      expect(LpDate.isDayKey('0999-01-01'), isTrue);
    });
  });

  group('LpDate ymd ints', () {
    test('toYmdInt and fromYmdInt are inverses', () {
      // They live together so this is provable rather than a claim spread over
      // coach_store.dart (encode) and coach_screen.dart (decode).
      var day = DateTime(2026, 1, 1);
      for (var i = 0; i < 800; i++) {
        expect(LpDate.fromYmdInt(LpDate.toYmdInt(day)), day);
        day = LpDate.addDays(day, 1);
      }
    });

    test('packs the documented wire shape', () {
      expect(LpDate.toYmdInt(DateTime(2026, 9, 15)), 20260915);
      expect(LpDate.fromYmdInt(20260915), DateTime(2026, 9, 15));
    });
  });
}
