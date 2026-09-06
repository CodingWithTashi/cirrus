import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/core/utils/lp_format.dart';
import 'package:last_puff/core/widgets/lp_charts.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/logic/day_window.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// Ember's in-thread "YOUR WEEK" card.
///
/// It captioned EVERY week "trending down — {day} was the hard one" with no
/// trend computed, and painted today as the win whatever its count. Now the
/// three verdicts come from `WeekTrend`, the engine Stats reads too.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  void ignoreFontWidthOverflow() {
    final prior = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('overflowed')) return;
      prior?.call(details);
    };
    addTearDown(() => FlutterError.onError = prior);
  }

  /// Tue Sep 8 2026, 15:00 — day 8; the card's week is Wed Sep 2 → Tue Sep 8.
  final now = DateTime(2026, 9, 8, 15);

  Future<ProviderContainer> openCard(
    WidgetTester tester,
    Map<int, int> puffsByDay,
  ) async {
    ignoreFontWidthOverflow();
    final container = ProviderContainer(
      overrides: fastBackendOverrides(now: now),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LastPuffApp(),
      ),
    );
    container.read(quitStoreProvider.notifier).replaceForTest(
      journeyOnDay(8, now: now, puffsByDay: puffsByDay),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    container.read(routerProvider).go(Routes.coach);
    await tester.pumpAndSettle();
    // The progress chip is the one reply that carries the card. Not awaited:
    // the fake backend answers on a zero-length timer, and under the test's
    // fake clock timers fire only when the tester pumps — awaiting the store
    // call directly is a deadlock.
    unawaited(
      container.read(coachStoreProvider.notifier).sendChip(CoachChip.progress),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    return container;
  }

  BarChart weekChart(WidgetTester tester) => tester.widget<BarChart>(
    find.byWidgetPredicate((w) => w is BarChart && w.values.length == 7),
  );

  // After the app is up — date formatting needs the loaded locale data.
  String wednesday() => LpFormat.weekday(DateTime(2026, 9, 2), 'en');

  testWidgets('a falling week is captioned as one, with the hard day named', (
    tester,
  ) async {
    final container = await openCard(tester, {
      2: 90, 3: 90, 4: 90, 5: 50, 6: 50, 7: 50,
    });
    expect(find.text(l10n.coachWeekCardLabel), findsOneWidget);

    final chart = weekChart(tester);
    final journey = container.read(quitStoreProvider)!;
    // The same seven calendar days Stats draws, today included and empty.
    expect(
      chart.values,
      [for (final d in DayWindow.trailing(journey, now, 7)) d.puffs],
    );
    expect(chart.values, [90, 90, 90, 50, 50, 50, 0]);
    expect(chart.highlight, {0}, reason: 'Wednesday, the first 90');
    expect(chart.positive, {3}, reason: 'the first confirmed 50 — never today');
    expect(find.text(l10n.coachWeekCardCaption(wednesday())), findsOneWidget);
    expect(find.text(l10n.coachWeekCardCaptionFlat(wednesday())), findsNothing);
  });

  testWidgets('a flat week is not "trending down"', (tester) async {
    await openCard(tester, {2: 60, 3: 60, 4: 60, 5: 60, 6: 60, 7: 60});
    expect(find.text(l10n.coachWeekCardCaptionFlat(wednesday())), findsOneWidget);
    expect(find.text(l10n.coachWeekCardCaption(wednesday())), findsNothing);
  });

  testWidgets('a rising week is not "trending down" either', (tester) async {
    await openCard(tester, {2: 20, 3: 20, 4: 20, 5: 70, 6: 70, 7: 70});
    final friday = LpFormat.weekday(DateTime(2026, 9, 5), 'en');
    expect(find.text(l10n.coachWeekCardCaptionFlat(friday)), findsOneWidget);
    expect(find.text(l10n.coachWeekCardCaption(friday)), findsNothing);
  });

  testWidgets('one day with puffs is not a week', (tester) async {
    // QA M2: a day-1 account was told "trending down — Monday was the hard
    // one" from a single bar.
    await openCard(tester, {2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 40});
    expect(find.text(l10n.coachWeekCardLabel), findsNothing);
  });
}
