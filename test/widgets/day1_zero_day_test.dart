import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/data/stores/day1_tour_store.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// The first Day-1 task for somebody whose line is zero.
///
/// The checklist's first move was "Log your first puff" for everyone, and its
/// tour said "go on, log one now". For somebody quitting cold turkey that is
/// an instruction to break the plan they made four minutes earlier: the puff
/// lands over a limit of zero, with no repair token to absorb it, so Home
/// shows "A slip is data, not defeat." before they have done anything, day 1
/// drops out of their streak, and the health clock restarts. 46% of new
/// people chose cold turkey (Nov 11 2026).
///
/// Their first move is the one their Home screen is built around: confirming
/// they are vape-free.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  final now = DateTime(2026, 11, 12, 15, 30);
  final today = JourneyState.dateKey(now);

  void ignoreFontWidthOverflow() {
    final prior = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('overflowed')) return;
      prior?.call(details);
    };
    addTearDown(() => FlutterError.onError = prior);
  }

  /// Day one, nothing ticked.
  JourneyState dayOne({required QuitMethod method}) {
    final j = journeyOnDay(1, now: now);
    return j.copyWith(
      plan: j.plan.copyWith(method: method),
      day1TasksDone: const {},
    );
  }

  Future<(ProviderContainer, RecordingAnalytics)> openDay1(
    WidgetTester tester,
    QuitMethod method,
  ) async {
    ignoreFontWidthOverflow();
    final analytics = RecordingAnalytics();
    final container = ProviderContainer(
      overrides: fastBackendOverrides(now: now, analytics: analytics),
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
        .replaceForTest(dayOne(method: method));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    container.read(routerProvider).go(Routes.day1);
    await tester.pumpAndSettle();
    return (container, analytics);
  }

  testWidgets('cold turkey is asked to lock in day one, not to log a puff', (
    tester,
  ) async {
    await openDay1(tester, QuitMethod.coldTurkey);

    expect(find.text(l10n.day1Task1Zero), findsWidgets);
    expect(find.text(l10n.day1Task1ZeroSub), findsOneWidget);
    expect(find.text(l10n.day1Task1), findsNothing);
  });

  testWidgets('a taper still starts with its first puff', (tester) async {
    await openDay1(tester, QuitMethod.taper);

    expect(find.text(l10n.day1Task1), findsWidgets);
    expect(find.text(l10n.day1Task1Zero), findsNothing);
  });

  testWidgets('the task walks to the confirmation, with nothing else to tap', (
    tester,
  ) async {
    final (c, _) = await openDay1(tester, QuitMethod.coldTurkey);

    await tester.tap(find.text(l10n.day1Task1Zero).first);
    await tester.pumpAndSettle();

    expect(c.read(day1TourStepProvider), Day1TourStep.logPuff);
    expect(find.text(l10n.homeStillVapeFree), findsOneWidget);
    expect(find.text(l10n.homeLogPuff), findsNothing);
    // The lesson is one deliberate tap; the way to log a puff is not offered
    // in the middle of being told this is not about puffs.
    expect(find.text(l10n.homeIVapedToday), findsNothing);
  });

  testWidgets('confirming ticks the box, and day one is clean and counted', (
    tester,
  ) async {
    final (c, analytics) = await openDay1(tester, QuitMethod.coldTurkey);
    await tester.tap(find.text(l10n.day1Task1Zero).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.homeStillVapeFree));
    await tester.pumpAndSettle();

    final journey = c.read(quitStoreProvider)!;
    expect(journey.day1TasksDone, contains(0));
    expect(journey.days[today]!.puffs, 0);
    expect(journey.days[today]!.vapeFreeConfirmed, isTrue);
    expect(journey.pendingSlipCleanDays, isNull, reason: 'no slip card');
    expect(c.read(todayProvider)!.streak, 1, reason: 'day one counts');
    // Back on the checklist with the box ticked and its own done line.
    expect(c.read(routerProvider).state.uri.path, Routes.day1);
    expect(find.text(l10n.day1Task1ZeroDone), findsOneWidget);
    // Named for what was done, so the dashboard can tell the two first
    // moves apart.
    expect(analytics.propsOfAll('day1_task_done'), [
      {'task': 'first_checkin'},
    ]);
    expect(analytics.names, isNot(contains('puff_logged')));
  });
}
