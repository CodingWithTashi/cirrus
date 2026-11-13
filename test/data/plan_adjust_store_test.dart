import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/date_key.dart';

import '../helpers.dart';

/// docs/15 QP-A11, the store half: an adjustment that would not move the date
/// is not an adjustment — nothing is written, nothing is reported, and the
/// nightly advice built on the current curve is kept.
void main() {
  final now = DateTime(2026, 11, 12, 15, 30);

  ({ProviderContainer c, RecordingAnalytics a}) open() {
    final a = RecordingAnalytics();
    final c = ProviderContainer(
      overrides: fastBackendOverrides(now: now, analytics: a),
    );
    addTearDown(c.dispose);
    c.read(quitStoreProvider.notifier).replaceForTest(journeyOnDay(10, now: now));
    return (c: c, a: a);
  }

  test('an unchanged date writes nothing and reports nothing', () {
    final (:c, :a) = open();
    final before = c.read(quitStoreProvider)!;
    // 21 days from day 10 of 30 is where Freedom Day already is.
    c.read(quitStoreProvider.notifier).adjustPlan(paceDays: 21);

    expect(identical(c.read(quitStoreProvider), before), isTrue);
    expect(a.propsOfAll('plan_adjusted'), isEmpty);
  });

  test('a changed date moves it, drops stale advice and reports the shift', () {
    final (:c, :a) = open();
    final before = c.read(quitStoreProvider)!;
    c.read(quitStoreProvider.notifier).adjustPlan(paceDays: 30);

    final after = c.read(quitStoreProvider)!;
    expect(
      LpDate.daysBetween(before.plan.freedomDate, after.plan.freedomDate),
      9,
    );
    expect(after.plan.baselinePuffsPerDay, before.plan.baselinePuffsPerDay);
    expect(a.propsOfAll('plan_adjusted'), [
      {'delta_days': 9},
    ]);
  });

  test('bringing the date closer reports a negative shift', () {
    final (:c, :a) = open();
    c.read(quitStoreProvider.notifier).adjustPlan(paceDays: 14);
    expect(a.propsOfAll('plan_adjusted'), [
      {'delta_days': -7},
    ]);
  });

  test('with no journey it does nothing', () {
    final c = ProviderContainer(overrides: fastBackendOverrides(now: now));
    addTearDown(c.dispose);
    c.read(quitStoreProvider.notifier).adjustPlan(paceDays: 30);
    expect(c.read(quitStoreProvider), isNull);
  });
}
