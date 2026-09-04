import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/data/api/widget_store.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/data/stores/widget_coordinator.dart';
import 'package:last_puff/data/stores/widget_mirror.dart';
import 'package:last_puff/domain/date_key.dart';

import '../helpers.dart';

/// What the app pushes to the home-screen widget.
///
/// The widget owns no arithmetic beyond adding one to a counter, so everything
/// it draws has to arrive here already computed — and already localized, which
/// is what lets the native layout ship with no `res/values-*/strings.xml` of
/// its own.
void main() {
  Future<(ProviderContainer, MemoryWidgetStore)> open(
    WidgetTester tester, {
    Locale? locale,
  }) async {
    final store = MemoryWidgetStore();
    final container = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(),
        widgetCoordinatorProvider.overrideWithValue(WidgetCoordinator(store)),
      ],
    );
    addTearDown(container.dispose);
    if (locale != null) {
      container.read(settingsStoreProvider.notifier).setLocale(locale);
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LastPuffApp(),
      ),
    );
    await tester.pumpAndSettle();
    return (container, store);
  }

  Map<String, dynamic> mirrorIn(MemoryWidgetStore store) =>
      jsonDecode(store.values[WidgetMirror.key]!) as Map<String, dynamic>;

  testWidgets('with no journey it says so, and carries no numbers', (
    tester,
  ) async {
    final (_, store) = await open(tester);

    final mirror = mirrorIn(store);
    expect(mirror['hasJourney'], isFalse);
    expect(mirror.containsKey('puffs'), isFalse);
    expect(
      (mirror['copy'] as Map)['emptyTitle'],
      'Start your plan',
      reason: 'the widget still needs something honest to draw',
    );
  });

  testWidgets('carries the same numbers the app is showing', (tester) async {
    final (container, store) = await open(tester);
    container.read(quitStoreProvider.notifier).seedDemoJourney();
    await tester.pumpAndSettle();

    final mirror = mirrorIn(store);
    final snapshot = container.read(todayProvider)!;
    expect(mirror['hasJourney'], isTrue);
    expect(mirror['dayNumber'], snapshot.dayNumber);
    expect(mirror['puffs'], snapshot.puffs);
    expect(mirror['limit'], snapshot.limit);
    expect(mirror['streak'], snapshot.streak);
  });

  testWidgets('ships plan day 1 as a day key, never an epoch number', (
    tester,
  ) async {
    // It used to ship an epoch day derived as
    // `dayStart(start).millisecondsSinceEpoch ~/ millisecondsPerDay`, which
    // floors the UTC INSTANT of local midnight rather than the local calendar
    // day. East of Greenwich that is a day early, and the native side — which
    // computes today with a true local day — read one day too high. Every user
    // at a positive UTC offset would have seen the widget say "day 13" while
    // Home said "day 12", for ever, and no test on a UTC-4 laptop could catch
    // it. A `yyyy-MM-dd` has no timezone to get wrong.
    final (container, store) = await open(tester);
    container.read(quitStoreProvider.notifier).seedDemoJourney();
    await tester.pumpAndSettle();

    final mirror = mirrorIn(store);
    final journey = container.read(quitStoreProvider)!;
    expect(
      mirror['planStartDayKey'],
      LpDate.dayKey(LpDate.dayStart(journey.plan.startDate)),
    );
    expect(mirror['planStartDayKey'], matches(r'^\d{4}-\d{2}-\d{2}$'));
    expect(mirror.containsKey('planStartEpochDay'), isFalse);
  });

  testWidgets('carries a week of limits, so a rollover still draws a line', (
    tester,
  ) async {
    final (container, store) = await open(tester);
    container.read(quitStoreProvider.notifier).seedDemoJourney();
    await tester.pumpAndSettle();

    final limits = mirrorIn(store)['limits'] as Map<String, dynamic>;
    expect(limits, hasLength(kMirrorLimitDays));
    // The taper only ever falls, so a rollover can never raise the line.
    final byDay = limits.keys.toList()..sort();
    for (var i = 1; i < byDay.length; i++) {
      expect(limits[byDay[i]] as int, lessThanOrEqualTo(limits[byDay[i - 1]] as int));
    }
  });

  testWidgets('the copy follows the app language, not the OS', (tester) async {
    // This is the whole reason the strings are pushed rather than duplicated
    // into res/values-fr: ARB stays the single source, l10n_parity_test keeps
    // covering it, and a language change in Settings repaints the widget on
    // the next push.
    final (_, store) = await open(tester, locale: const Locale('fr'));

    final copy = mirrorIn(store)['copy'] as Map<String, dynamic>;
    expect(copy['emptyTitle'], 'Commence ton plan');
    expect(copy['day'], 'jour %1\$d');
  });

  testWidgets('every count template keeps exactly one native placeholder', (
    tester,
  ) async {
    // Kotlin formats these with String.format; a template that lost its %1$d
    // in translation would render a sentence with a hole in it, or throw.
    for (final locale in ['en', 'es', 'fr', 'de', 'pt']) {
      final (_, store) = await open(tester, locale: Locale(locale));
      final copy = mirrorIn(store)['copy'] as Map<String, dynamic>;
      for (final key in ['day', 'leftAhead', 'leftTight']) {
        expect(
          RegExp(r'%1\$d').allMatches(copy[key] as String).length,
          1,
          reason: '$locale/$key must interpolate the count exactly once',
        );
      }
      expect(
        (copy['overLimit'] as String).contains(r'%1$d'),
        isFalse,
        reason: 'over is over — that line carries no count',
      );
    }
  });

  testWidgets('a puff logged in the app reaches the widget', (tester) async {
    final (container, store) = await open(tester);
    container.read(quitStoreProvider.notifier).seedDemoJourney();
    await tester.pumpAndSettle();
    final before = mirrorIn(store)['puffs'] as int;

    container.read(quitStoreProvider.notifier).logPuff();
    await tester.pumpAndSettle();

    expect(mirrorIn(store)['puffs'], before + 1);
  });

  testWidgets('an unchanged journey does not redraw the widget', (
    tester,
  ) async {
    // `todayProvider` recomputes on every journey mutation, so without the
    // fingerprint a heavy logging day would cross the platform channel and ask
    // the OS to redraw a hundred times — the reloadTimelines spam docs/03 §10
    // warns about.
    final (container, store) = await open(tester);
    container.read(quitStoreProvider.notifier).seedDemoJourney();
    await tester.pumpAndSettle();
    final redraws = store.refreshes;

    container.read(settingsStoreProvider.notifier).setThemeMode(ThemeMode.dark);
    await tester.pumpAndSettle();

    expect(store.refreshes, redraws);
  });
}
