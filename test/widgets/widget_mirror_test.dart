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

import 'package:last_puff/data/seed/seed_data.dart';
import 'package:last_puff/domain/models/journey_state.dart';

import '../helpers.dart';

/// Placeholder copy for the pure-`buildMirror` cases below; the widget cases
/// take the real thing from ARB through `_WidgetSync`.
const _copy = WidgetCopy(
  day: r'day %1$d',
  dayFreedom: 'Freedom Day',
  dayPastOne: r'%1$d day past',
  dayPastOther: r'%1$d days past',
  leftAhead: r'%1$d left',
  leftTight: r'%1$d left',
  overLimit: 'over',
  emptyTitle: 'Start your plan',
  emptyBody: 'Tap to open Cirrus',
  watchOpenPhone: 'Open Cirrus on your iPhone',
);

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
      for (final key in ['day', 'dayPastOne', 'dayPastOther', 'leftAhead', 'leftTight']) {
        expect(
          RegExp(r'%1\$d').allMatches(copy[key] as String).length,
          1,
          reason: '$locale/$key must interpolate the count exactly once',
        );
      }
      for (final key in ['overLimit', 'dayFreedom']) {
        expect(
          (copy[key] as String).contains(r'%1$d'),
          isFalse,
          reason: '$key carries no count',
        );
      }
    }
  });

  group('past Freedom Day', () {
    // The widget recomputes the day number itself and used to keep counting:
    // "day 31" of a 30-day plan on the launcher while Home said "1 day past
    // Freedom Day". The mirror ships the plan length and Home's own copy for
    // the last day and every day after it; Kotlin picks the line.
    Future<Map<String, dynamic>> mirrorOnDay(WidgetTester tester, int day) async {
      final now = DateTime(2026, 10, 4, 9);
      final store = MemoryWidgetStore();
      final container = ProviderContainer(
        overrides: [
          ...fastBackendOverrides(now: now),
          widgetCoordinatorProvider.overrideWithValue(WidgetCoordinator(store)),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const LastPuffApp(),
        ),
      );
      container
          .read(quitStoreProvider.notifier)
          .replaceForTest(journeyOnDay(day, now: now));
      await tester.pumpAndSettle();
      return mirrorIn(store);
    }

    testWidgets('ships the plan length beside the day number', (tester) async {
      for (final day in [1, 30, 31]) {
        final mirror = await mirrorOnDay(tester, day);
        expect(mirror['dayNumber'], day);
        expect(mirror['totalDays'], 30);
        expect(mirror['limit'], day < 30 ? greaterThan(0) : 0);
      }
    });

    testWidgets('and the copy Home uses for the last day and after', (
      tester,
    ) async {
      final copy = (await mirrorOnDay(tester, 31))['copy'] as Map<String, dynamic>;
      expect(copy['dayFreedom'], 'Freedom Day 🏆');
      expect(copy['dayPastOne'], r'%1$d day past Freedom Day');
      expect(copy['dayPastOther'], r'%1$d days past Freedom Day');
    });
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

  group('when the journey goes away', () {
    // The home screen outlives the app's session. A widget still showing the
    // last account's day number, count and working +/- buttons is the shared-
    // phone leak in its most visible form — and unlike the outbox, this one
    // the next person can SEE.
    // Deleting the account reaches the mirror through the very same
    // `journey == null` branch of `_WidgetSync.build`, and is covered at
    // container level in `account_deletion_test.dart`. Not duplicated here:
    // `await`ing the erasure inside `testWidgets` deadlocks the fake-async
    // zone against its own pending timers, and a hanging test is worse than
    // an absent one.
    testWidgets('signing out replaces the numbers with the empty card', (
      tester,
    ) async {
      final (container, store) = await open(tester);
      container.read(quitStoreProvider.notifier).seedDemoJourney();
      await tester.pumpAndSettle();
      expect(mirrorIn(store)['hasJourney'], isTrue);

      container.read(quitStoreProvider.notifier).signOut();
      await tester.pumpAndSettle();

      final mirror = mirrorIn(store);
      expect(mirror['hasJourney'], isFalse);
      // Not merely flagged — the numbers must be GONE. `append` refuses on
      // `hasJourney`, but a stale count left in the document is one bad read
      // away from being drawn again.
      expect(mirror.containsKey('puffs'), isFalse);
      expect(mirror.containsKey('dayNumber'), isFalse);
      expect(mirror.containsKey('streak'), isFalse);
    });

    testWidgets('and the launcher is told to repaint', (tester) async {
      // Writing the document is not enough: nothing redraws a home-screen
      // widget on its own, so without the refresh the old pixels stay up
      // until something else happens to ask.
      final (container, store) = await open(tester);
      container.read(quitStoreProvider.notifier).seedDemoJourney();
      await tester.pumpAndSettle();
      final before = store.refreshes;

      container.read(quitStoreProvider.notifier).signOut();
      await tester.pumpAndSettle();

      expect(store.refreshes, greaterThan(before));
    });
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

  group('the Apple Watch half of the mirror', () {
    // A watch is a second DEVICE, not a second process, so two things the
    // home-screen widget never needed are in the document for it: the account
    // the numbers belong to, and a line of copy that does not say "tap to open
    // Cirrus" (watchOS cannot launch its companion iPhone app).

    testWidgets('the account id travels with the numbers, and only with them', (
      tester,
    ) async {
      final (container, store) = await open(tester);
      // Signed out: nothing numeric, and nothing to attribute either.
      expect(mirrorIn(store).containsKey('sid'), isFalse);

      container.read(quitStoreProvider.notifier).seedDemoJourney();
      container.read(widgetSessionProvider.notifier).bind('uid-demo');
      await tester.pumpAndSettle();
      expect(mirrorIn(store)['sid'], 'uid-demo');

      // And it goes when the account does — which is what makes the wrist
      // forget a queue it can no longer attribute to anyone.
      container.read(quitStoreProvider.notifier).signOut();
      await tester.pumpAndSettle();
      final after = mirrorIn(store);
      expect(after['hasJourney'], isFalse);
      expect(after.containsKey('sid'), isFalse);
    });

    test('an unresolved id is absent, never empty', () {
      // The race the watch's keep-what-you-have rule exists for: the first push
      // of a cold launch can beat the async uid lookup, and an EMPTY sid would
      // be indistinguishable from a different one.
      final journey = SeedData.journey(DateTime.now());
      Map<String, dynamic> build(String? sid) => buildMirror(
        journey: journey,
        snapshot: TodaySnapshot.of(journey, DateTime.now()),
        copy: _copy,
        now: DateTime.now(),
        sid: sid,
      );
      expect(build('uid-x')['sid'], 'uid-x');
      expect(build(null).containsKey('sid'), isFalse);
      expect(build('').containsKey('sid'), isFalse);
    });

    testWidgets('the wrist gets its own empty line, in every language', (
      tester,
    ) async {
      const expected = {
        'en': 'Open Cirrus on your iPhone',
        'es': 'Abre Cirrus en tu iPhone',
        'fr': 'Ouvre Cirrus sur ton iPhone',
        'de': 'Öffne Cirrus auf deinem iPhone',
        'pt': 'Abra o Cirrus no seu iPhone',
      };
      for (final locale in expected.keys) {
        final (_, store) = await open(tester, locale: Locale(locale));
        final copy = mirrorIn(store)['copy'] as Map<String, dynamic>;
        expect(copy['watchOpenPhone'], expected[locale], reason: locale);
        // Distinct from the home screen's line, which tells you to tap.
        expect(copy['watchOpenPhone'], isNot(copy['emptyBody']), reason: locale);
      }
    });

    testWidgets('every push reaches the wrist, sign-out included', (
      tester,
    ) async {
      // Writing the document is not enough for a watch either — but where the
      // launcher needs a repaint, the watch needs a radio. Without this the
      // wrist keeps the last person's count until it next comes forward.
      final (container, store) = await open(tester);
      final before = store.watchSyncs;
      expect(before, greaterThan(0));

      container.read(quitStoreProvider.notifier).seedDemoJourney();
      await tester.pumpAndSettle();
      final afterSeed = store.watchSyncs;
      expect(afterSeed, greaterThan(before));

      container.read(quitStoreProvider.notifier).signOut();
      await tester.pumpAndSettle();
      expect(store.watchSyncs, greaterThan(afterSeed));
    });
  });
}
