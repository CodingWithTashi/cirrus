import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/logic/puff_anchor.dart';
import 'package:last_puff/domain/models/models.dart';

/// Where "last puff" may sit once puffs are taken back (docs/10 §41).
void main() {
  final sep12 = DateTime(2026, 9, 12);
  final sep13 = DateTime(2026, 9, 13);

  DayLog day(DateTime date, Map<int, int> buckets) => DayLog(
    date: date,
    puffs: buckets.values.fold(0, (a, b) => a + b),
    limit: 100,
    hourBuckets: buckets,
  );

  test('an anchor whose hour still holds a puff stays exactly where it is', () {
    final days = {
      sep13: day(sep13, {9: 2, 20: 1}),
    };
    final anchor = DateTime(2026, 9, 13, 20, 1);
    expect(PuffAnchor.settle(days, anchor), anchor);
  });

  test('an emptied hour falls back to the end of the latest earlier one', () {
    final days = {
      sep13: day(sep13, {9: 2, 18: 3}),
    };
    expect(
      PuffAnchor.settle(days, DateTime(2026, 9, 13, 20, 1)),
      DateTime(2026, 9, 13, 18, 59, 59),
    );
  });

  test('an emptied day falls back to the latest hour of an earlier day', () {
    final days = {
      sep12: day(sep12, {21: 4}),
      sep13: day(sep13, {}),
    };
    expect(
      PuffAnchor.settle(days, DateTime(2026, 9, 13, 8, 30)),
      DateTime(2026, 9, 12, 21, 59, 59),
    );
  });

  test('no logged puff left anywhere means no anchor', () {
    final days = {sep13: day(sep13, {})};
    expect(PuffAnchor.settle(days, DateTime(2026, 9, 13, 8, 30)), isNull);
  });

  test('a day logged without hours gives nothing to judge by', () {
    final anchor = DateTime(2026, 9, 13, 20, 1);
    final days = {sep13: DayLog(date: sep13, puffs: 5, limit: 100)};
    expect(PuffAnchor.settle(days, anchor), anchor);

    final earlier = {
      sep12: DayLog(date: sep12, puffs: 5, limit: 100),
      sep13: day(sep13, {}),
    };
    expect(
      PuffAnchor.settle(earlier, anchor),
      DateTime(2026, 9, 12, 23, 59, 59),
    );
  });

  test('a day its hours do not add up to gives nothing to judge by', () {
    // `editPastDay` raised this day from 10 to 15 and left the hours alone,
    // so five puffs sit at hours nobody knows — possibly after 9 AM.
    final edited = DayLog(
      date: sep12,
      puffs: 15,
      limit: 100,
      hourBuckets: const {9: 10},
    );
    final anchor = DateTime(2026, 9, 12, 23, 59, 59);
    expect(PuffAnchor.settle({sep12: edited}, anchor), anchor);
    expect(
      PuffAnchor.settle({
        sep12: edited,
        sep13: day(sep13, {}),
      }, DateTime(2026, 9, 13, 8, 30)),
      DateTime(2026, 9, 12, 23, 59, 59),
    );
  });

  test('a null anchor stays null', () {
    expect(PuffAnchor.settle(const {}, null), isNull);
  });
}
