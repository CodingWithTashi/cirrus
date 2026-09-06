import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/data/stores/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

/// The milestone ledger's two hardest questions, found by the Sep 5 2026
/// review pass (docs/10 §27.7): is an armed celebration one the user has
/// already received, and has disk answered yet.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('handing back an armed celebration', () {
    ProviderContainer container() {
      final c = ProviderContainer(overrides: fastBackendOverrides());
      addTearDown(c.dispose);
      return c;
    }

    test('one still on the clock becomes owed again', () {
      final c = container();
      final store = c.read(settingsStoreProvider.notifier);
      store.adoptMilestones({});
      store.markMilestonesCelebrated(
        'weekFlame',
        {'weekFlame'},
        DateTime(2026, 9, 6, 8),
      );

      // Notifications off at 20:00 the evening before it was due.
      store.releaseArmedMilestone(DateTime(2026, 9, 5, 20));

      final state = c.read(settingsStoreProvider);
      expect(state.armedMilestone, isNull);
      expect(state.armedMilestoneAt, isNull);
      expect(
        state.celebratedMilestones,
        isEmpty,
        reason: 'the promise is owed again, not destroyed',
      );
    });

    test('one that has already fired stays settled', () {
      // Nothing observes the notification going off. `armedMilestone` used
      // to stay set for ever after the 08:00 delivery, so switching
      // notifications off a month later un-settled the badge and switching
      // them back on delivered "Two weeks. TWO WEEKS." a second time.
      final c = container();
      final store = c.read(settingsStoreProvider.notifier);
      store.adoptMilestones({});
      store.markMilestonesCelebrated(
        'twoWeekFlame',
        {'twoWeekFlame'},
        DateTime(2026, 9, 6, 8),
      );

      store.releaseArmedMilestone(DateTime(2026, 10, 1, 12));

      final state = c.read(settingsStoreProvider);
      expect(state.armedMilestone, isNull);
      expect(state.celebratedMilestones, {'twoWeekFlame'});
    });

    test('at the due instant itself it counts as delivered', () {
      final c = container();
      final store = c.read(settingsStoreProvider.notifier);
      store.adoptMilestones({});
      store.markMilestonesCelebrated('spark', {'spark'}, DateTime(2026, 9, 6, 8));

      store.releaseArmedMilestone(DateTime(2026, 9, 6, 8));

      expect(c.read(settingsStoreProvider).celebratedMilestones, {'spark'});
    });
  });

  group('hydration', () {
    test('a restoring store says it is not hydrated until disk answers', () async {
      SharedPreferences.setMockInitialValues({
        'settings.themeMode': 'dark',
        'settings.milestonesAdopted': true,
      });
      final c = ProviderContainer(
        overrides: [
          ...fastBackendOverrides(),
          settingsStoreProvider.overrideWith(SettingsStore.new),
        ],
      );
      addTearDown(c.dispose);

      final before = c.read(settingsStoreProvider);
      expect(before.hydrated, isFalse);
      expect(before.themeMode, ThemeMode.system, reason: 'the defaults, said so');

      await pumpEventQueue();

      final after = c.read(settingsStoreProvider);
      expect(after.hydrated, isTrue);
      expect(after.themeMode, ThemeMode.dark);
      expect(after.milestonesAdopted, isTrue);
    });

    test('a change made before disk answers still ends up hydrated', () async {
      SharedPreferences.setMockInitialValues({'settings.themeMode': 'dark'});
      final c = ProviderContainer(
        overrides: [
          ...fastBackendOverrides(),
          settingsStoreProvider.overrideWith(SettingsStore.new),
        ],
      );
      addTearDown(c.dispose);

      // The user's action wins over the older stored value…
      c.read(settingsStoreProvider.notifier).setThemeMode(ThemeMode.light);
      await pumpEventQueue();

      final state = c.read(settingsStoreProvider);
      expect(state.themeMode, ThemeMode.light);
      // …and the automatic writers waiting on disk are still let through.
      expect(state.hydrated, isTrue);
    });

    test('a store that does not restore is hydrated from the first read', () {
      final c = ProviderContainer(overrides: fastBackendOverrides());
      addTearDown(c.dispose);
      expect(c.read(settingsStoreProvider).hydrated, isTrue);
    });
  });
}
