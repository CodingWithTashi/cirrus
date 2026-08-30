import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/logic/age_entry_engine.dart';

/// `currentYear` is injected, so unlike the age-gate cases in
/// `test/data/onboarding_test.dart` these do not drift when the wall clock does.
void main() {
  const year = 2026;
  BirthEntry read(String digits) =>
      AgeEntryEngine.interpret(digits, currentYear: year);
  BirthEntryKind kind(String digits) => read(digits).kind;

  group('four digits', () {
    test('an adult year resolves', () {
      final e = read('1998');
      expect(e.kind, BirthEntryKind.year);
      expect(e.year, 1998);
      expect(e.age, 28);
    });

    test('a future year never yields a year, so it cannot reach the gate', () {
      // The reported bug: 2812 used to compute age -786, which is < 18, and
      // dropped an adult into the under-18 screen whose only exit is closing
      // the app. `year` staying null is what keeps Continue disabled.
      for (final digits in ['2027', '2812', '9999']) {
        final e = read(digits);
        expect(e.kind, BirthEntryKind.future, reason: digits);
        expect(e.year, isNull, reason: digits);
      }
    });

    test('older than any verified human is rejected, not gated', () {
      expect(kind('1903'), BirthEntryKind.tooOld);
      expect(kind('1800'), BirthEntryKind.tooOld);
      expect(read('1903').year, isNull);
    });

    test('the age bounds are inclusive at both ends', () {
      expect(kind('1904'), BirthEntryKind.year); // exactly 122
      expect(kind('2008'), BirthEntryKind.year); // exactly 18
      expect(kind('2009'), BirthEntryKind.underAge); // 17
      expect(kind('2026'), BirthEntryKind.underAge); // 0
    });
  });

  group('age-shaped entries', () {
    test('an unambiguous age resolves to a birth year', () {
      final e = read('28');
      expect(e.kind, BirthEntryKind.ageOnly);
      expect(e.age, 28);
      expect(e.year, 1998);
    });

    test('an ambiguous two-digit entry is offered, never adopted', () {
      // "19" is an age AND the first half of 1998 — the two commonest birth
      // decades here start with digits that are also plausible ages.
      for (final digits in ['19', '20']) {
        final e = read(digits);
        expect(e.kind, BirthEntryKind.ageOffer, reason: digits);
        expect(e.year, year - int.parse(digits), reason: digits);
      }
    });

    test('the oldest plausible age still reads as an age', () {
      final e = read('122');
      expect(e.kind, BirthEntryKind.ageOnly);
      expect(e.year, 1904);
    });

    test('an under-18 age routes to the gate, like an under-18 year', () {
      // The gate must not be dodgeable by answering in a different unit.
      for (final digits in ['17', '15', '11']) {
        final e = read(digits);
        expect(e.kind, BirthEntryKind.underAge, reason: digits);
        expect(e.age, int.parse(digits), reason: digits);
      }
    });
  });

  group('in-progress and nonsense', () {
    test('an empty buffer is empty', () {
      expect(kind(''), BirthEntryKind.empty);
    });

    test('a year prefix is still being typed', () {
      for (final digits in ['1', '2', '199', '200', '190']) {
        expect(kind(digits), BirthEntryKind.typing, reason: digits);
      }
    });

    test('what is neither a year prefix nor an age is impossible', () {
      for (final digits in ['0', '999', '123', '09', '5', '8']) {
        expect(kind(digits), BirthEntryKind.impossible, reason: digits);
      }
    });
  });

  test('every buffer reachable from the keypad is classified', () {
    // The keypad can only ever produce 0-4 digits. Nothing may throw, and
    // anything carrying a year must carry an age that agrees with it.
    for (var n = 0; n <= 9999; n++) {
      for (final digits in {'$n', n.toString().padLeft(4, '0')}) {
        if (digits.length > 4) continue;
        final e = AgeEntryEngine.interpret(digits, currentYear: year);
        if (e.year != null) {
          expect(e.age, year - e.year!, reason: digits);
          expect(
            e.kind,
            isNot(BirthEntryKind.future),
            reason: 'a future entry must never resolve a year: $digits',
          );
        }
      }
    }
  });
}
