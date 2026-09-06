import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/logic/danger_hours.dart';
import 'package:last_puff/domain/models/models.dart';

/// `DangerHours` — the window behind the Home nudge, the Stats heatmap and
/// the reminder planner. It had no engine test; the sheet test covered only
/// the reminder UI around it.
void main() {
  final monday = DateTime(2026, 8, 31);

  DayLog day(int i, Map<int, int> buckets, {bool confirmed = true}) {
    final puffs = buckets.values.fold(0, (a, b) => a + b);
    return DayLog(
      date: LpDate.addDays(monday, i),
      puffs: confirmed ? puffs : 0,
      limit: 50,
      hourBuckets: buckets,
    );
  }

  group('window', () {
    test('needs three confirmed days', () {
      final two = [day(0, {21: 5}), day(1, {21: 5})];
      expect(DangerHours.window(two), isNull);
      expect(DangerHours.window([...two, day(2, {21: 5})]), isNotNull);
    });

    test('unconfirmed days do not count toward the three', () {
      // A mood check-in mints a 0-puff log with no hours; it must not make
      // two real days look like three.
      final logs = [
        day(0, {21: 5}),
        day(1, {21: 5}),
        day(2, {21: 5}, confirmed: false),
      ];
      expect(DangerHours.window(logs), isNull);
    });

    test('is the peak hour alone when its neighbours are quiet', () {
      final logs = [for (var i = 0; i < 3; i++) day(i, {20: 1, 21: 10, 22: 1})];
      expect(DangerHours.window(logs), (21, 22));
    });

    test('widens to a neighbour at least half as hot as the peak', () {
      final logs = [for (var i = 0; i < 3; i++) day(i, {20: 6, 21: 10, 22: 5})];
      expect(DangerHours.window(logs), (20, 23));
      final left = [for (var i = 0; i < 3; i++) day(i, {20: 5, 21: 10, 22: 4})];
      expect(DangerHours.window(left), (20, 22));
    });

    test('clamps at the ends of the day', () {
      final midnight = [for (var i = 0; i < 3; i++) day(i, {0: 10, 1: 6})];
      expect(DangerHours.window(midnight), (0, 2));
      final lateAlone = [for (var i = 0; i < 3; i++) day(i, {23: 10})];
      expect(DangerHours.window(lateAlone), (23, 24));
      final late = [for (var i = 0; i < 3; i++) day(i, {22: 5, 23: 10})];
      expect(DangerHours.window(late), (22, 24));
    });
  });

  group('heat', () {
    test('is normalized to the hottest hour across the window', () {
      final logs = [day(0, {20: 5, 21: 10}), day(1, {21: 10})];
      expect(DangerHours.heat(logs), {20: 0.25, 21: 1.0});
    });

    test('is empty when nothing was logged', () {
      expect(DangerHours.heat(const []), isEmpty);
      expect(DangerHours.heat([day(0, {})]), isEmpty);
      expect(DangerHours.heat([day(0, {21: 0})]), isEmpty);
    });
  });

  test('aggregate sums buckets across days', () {
    final logs = [day(0, {20: 5, 21: 10}), day(1, {21: 2, 9: 1})];
    expect(DangerHours.aggregate(logs), {20: 5, 21: 12, 9: 1});
  });
}
