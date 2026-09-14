import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/logic/dependence_engine.dart';
import 'package:last_puff/domain/logic/nicotine_trend.dart';
import 'package:last_puff/domain/models/models.dart';

/// What the Stats nicotine card may honestly say (docs/10 §41).
void main() {
  final now = DateTime(2026, 9, 13, 10);
  const strength = NicStrength.mg50;

  DayLog log(int daysAgo, int puffs, {bool confirmed = true}) => DayLog(
    date: LpDate.addDays(LpDate.dayStart(now), -daysAgo),
    puffs: puffs,
    limit: 100,
    vapeFreeConfirmed: confirmed && puffs == 0,
  );

  double mg(int puffs) => DependenceEngine.nicotineMg(puffs, strength);

  test('before any completed day there is no figure, line or arrow', () {
    final trend = NicotineTrend.of([log(0, 14)], strength, now);
    expect(trend.latestMg, isNull);
    expect(trend.series, isEmpty);
    expect(trend.direction, isNull);
  });

  test('one completed day gives a figure and no arrow', () {
    final trend = NicotineTrend.of([log(1, 20), log(0, 3)], strength, now);
    expect(trend.latestMg, mg(20));
    expect(trend.direction, isNull);
  });

  test('the arrow is the latest day against the one before it', () {
    expect(
      NicotineTrend.of([log(2, 40), log(1, 30)], strength, now).direction,
      TrendDirection.down,
    );
    expect(
      NicotineTrend.of([log(2, 20), log(1, 21)], strength, now).direction,
      TrendDirection.up,
    );
    expect(
      NicotineTrend.of([log(2, 20), log(1, 20)], strength, now).direction,
      TrendDirection.flat,
    );
  });

  test('the figure is yesterday even before today has a log', () {
    // The old card took the second-to-last LOGGED day, which with today
    // unlogged is the day before yesterday.
    final trend = NicotineTrend.of(
      [log(3, 60), log(2, 50), log(1, 40)],
      strength,
      now,
    );
    expect(trend.latestMg, mg(40));
  });

  test('an unlogged day is left out, never drawn as a zero', () {
    final trend = NicotineTrend.of(
      [log(3, 60), log(2, 0, confirmed: false), log(1, 40)],
      strength,
      now,
    );
    expect(trend.series, [mg(60), mg(40)]);
    expect(trend.direction, TrendDirection.down);
  });

  test('a confirmed vape-free day is a real zero', () {
    final trend = NicotineTrend.of([log(2, 10), log(1, 0)], strength, now);
    expect(trend.series, [mg(10), 0]);
    expect(trend.direction, TrendDirection.down);
  });

  test("today's unfinished count is never part of it", () {
    final trend = NicotineTrend.of([log(1, 30), log(0, 90)], strength, now);
    expect(trend.series, [mg(30)]);
  });
}
