import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// QA H1 (Aug 31 2026 E2E pass): 18 rapid taps on LOG PUFF logged 68 puffs,
/// a 5-tap burst logged 7, while deliberate single taps logged exactly one.
///
/// The instrumentation question was whether `JourneyStore.logPuff` fired more
/// than once per pointer-up. It did not — `puffLogged` is emitted exactly
/// once per `logPuff` call, and the counts below show one call per tap. The
/// inflation was the accelerating tap ramp (+1,+1,+1,+2,+2,+3,+3,+5…): a
/// stressed user hammering the button mid-craving is the exact cadence that
/// triggered it, and the inflated count poisons the limit, the streak, the
/// money and every number the coach quotes. A tap is one puff. Always.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Future<(ProviderContainer, RecordingAnalytics)> pumpHome(
    WidgetTester tester,
  ) async {
    final analytics = RecordingAnalytics();
    final container = ProviderContainer(
      overrides: fastBackendOverrides(analytics: analytics),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LastPuffApp(),
      ),
    );
    container.read(quitStoreProvider.notifier).seedDemoJourney();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text(l10n.homeLogPuff), findsOneWidget);
    return (container, analytics);
  }

  int puffsToday(ProviderContainer c) => c.read(todayProvider)!.puffs;

  Future<void> rapidTaps(WidgetTester tester, int count) async {
    for (var i = 0; i < count; i++) {
      await tester.tap(find.text(l10n.homeLogPuff));
      // 400ms is the cadence the QA pass hammered at — well inside the burst
      // window, so every tap after the first extends the same burst.
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  testWidgets('logPuff fires exactly once per pointer-up', (tester) async {
    final (container, analytics) = await pumpHome(tester);
    analytics.events.clear();

    await rapidTaps(tester, 5);

    expect(
      analytics.names.where((n) => n == 'puff_logged').length,
      5,
      reason: 'the gesture layer must hand the store one call per tap',
    );
    await tester.pump(const Duration(seconds: 6));
    expect(container.read(todayProvider), isNotNull);
  });

  testWidgets('5 rapid taps log exactly 5 puffs', (tester) async {
    // The QA burst that logged 7.
    final (container, _) = await pumpHome(tester);
    final before = puffsToday(container);

    await rapidTaps(tester, 5);

    expect(puffsToday(container), before + 5, reason: '5 taps, 5 puffs');
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('18 rapid taps log exactly 18 puffs, and Undo takes back 18', (
    tester,
  ) async {
    // The QA burst that logged 68. One burst per test on purpose: the burst
    // window reads the wall clock, which a widget test's pumps do not move.
    final (container, _) = await pumpHome(tester);
    final before = puffsToday(container);

    await rapidTaps(tester, 18);
    expect(puffsToday(container), before + 18, reason: '18 taps, 18 puffs');

    // The undo snack reports the burst's real size, and Undo takes back
    // exactly that many — nothing more, nothing less.
    expect(find.text(l10n.homeLoggedSnackCount(18)), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.commonUndo));
    await tester.pumpAndSettle();
    expect(puffsToday(container), before);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('a single deliberate tap logs one, and so does a hold tick', (
    tester,
  ) async {
    final (container, _) = await pumpHome(tester);
    final before = puffsToday(container);

    await tester.tap(find.text(l10n.homeLogPuff));
    await tester.pump();
    expect(puffsToday(container), before + 1);

    // A press-and-hold ticks the store once per interval, one puff a tick —
    // the ring's rolling number is the live feedback, so the count the user
    // watches is the count they get.
    await tester.pump(const Duration(seconds: 2));
    final gesture = await tester.startGesture(
      tester.getCenter(find.text(l10n.homeLogPuff)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    await tester.pump();
    expect(puffsToday(container), before + 2, reason: 'a 600ms hold = 1 tick');
    await tester.pump(const Duration(seconds: 6));
  });
}
