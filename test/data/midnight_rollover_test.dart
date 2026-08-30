import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/date_key.dart';

import '../helpers.dart';

/// `todayProvider` used to recompute only when the journey mutated, so an app
/// left open overnight showed yesterday's day number, limit and streak until
/// the user happened to tap something.
void main() {
  test('the day clock starts on today, at local midnight', () {
    final now = DateTime(2026, 8, 30, 23, 59, 58);
    final c = ProviderContainer(overrides: fastBackendOverrides(now: now));
    addTearDown(c.dispose);

    expect(c.read(dayClockProvider), DateTime(2026, 8, 30));
  });

  test('a resume after midnight moves the day on', () {
    // The path that matters on Android: the process was frozen overnight, so
    // its timers fired late or never, and only the resume hook is left.
    var now = DateTime(2026, 8, 30, 23, 59, 58);
    final c = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(),
        nowProvider.overrideWithValue(() => now),
        dayClockProvider.overrideWith(() => DayClock(tick: false)),
      ],
    );
    addTearDown(c.dispose);

    expect(c.read(dayClockProvider), DateTime(2026, 8, 30));

    now = DateTime(2026, 8, 31, 0, 0, 3);
    c.read(dayClockProvider.notifier).refresh();

    expect(c.read(dayClockProvider), DateTime(2026, 8, 31));
  });

  test('it crosses a DST boundary onto the next calendar day', () {
    // US falls back on 2026-11-01. A clock built on absolute hours lands back
    // on the day it just left.
    var now = DateTime(2026, 10, 31, 23, 30);
    final c = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(),
        nowProvider.overrideWithValue(() => now),
        dayClockProvider.overrideWith(() => DayClock(tick: false)),
      ],
    );
    addTearDown(c.dispose);

    now = LpDate.addDays(DateTime(2026, 10, 31), 1).add(
      const Duration(minutes: 1),
    );
    c.read(dayClockProvider.notifier).refresh();

    expect(c.read(dayClockProvider), DateTime(2026, 11, 1));
  });

  test('todayProvider follows the clock, not just journey mutations', () {
    var now = DateTime(2026, 8, 30, 12);
    final c = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(),
        nowProvider.overrideWithValue(() => now),
        dayClockProvider.overrideWith(() => DayClock(tick: false)),
      ],
    );
    addTearDown(c.dispose);
    c.read(quitStoreProvider.notifier).seedDemoJourney();

    final before = c.read(todayProvider)!.dayNumber;

    now = DateTime(2026, 8, 31, 12);
    c.read(dayClockProvider.notifier).refresh();

    expect(
      c.read(todayProvider)!.dayNumber,
      before + 1,
      reason: 'the day number must move without the user touching anything',
    );
  });
}
