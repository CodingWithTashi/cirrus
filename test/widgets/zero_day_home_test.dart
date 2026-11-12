import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// Home on a day whose limit is zero.
///
/// 46% of the people who started in the four weeks to Nov 11 2026 chose cold
/// turkey, and 26% of them came back the next day against 57% of those
/// tapering. Their line is zero every day, and Home was built around a line
/// that is not: the one big button logged a puff (for them, a failure), a
/// clean day read "0 left on today's line. Tight — you've got this.", and the
/// ring said "0 of 0". The action that IS theirs — confirming the day
/// vape-free — was a card further down the list.
///
/// So on a zero-limit day with nothing logged, the main button is that
/// confirmation. It applies to every such day, not to a method: the taper's
/// last days and every day after Freedom Day are zero days too.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  // Mid-morning: before the evening mood prompt, and before the hour the
  // confirm card used to wait for on a day with a limit.
  final now = DateTime(2026, 11, 12, 10, 15);
  final today = JourneyState.dateKey(now);

  void ignoreFontWidthOverflow() {
    final prior = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('overflowed')) return;
      prior?.call(details);
    };
    addTearDown(() => FlutterError.onError = prior);
  }

  /// Day [day] of a cold-turkey plan with every earlier day confirmed clean.
  JourneyState coldTurkey(int day, {DateTime? lastPuffAt}) {
    final j = journeyOnDay(day, now: now, lastPuffAt: lastPuffAt);
    return j.copyWith(
      plan: j.plan.copyWith(method: QuitMethod.coldTurkey),
      days: {
        for (final e in j.days.entries)
          e.key: DayLog(
            date: e.key,
            puffs: 0,
            limit: 0,
            vapeFreeConfirmed: true,
          ),
      },
    );
  }

  Future<(ProviderContainer, RecordingAnalytics)> home(
    WidgetTester tester,
    JourneyState journey, {
    DateTime? at,
  }) async {
    ignoreFontWidthOverflow();
    final analytics = RecordingAnalytics();
    final container = ProviderContainer(
      overrides: fastBackendOverrides(now: at ?? now, analytics: analytics),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LastPuffApp(),
      ),
    );
    container.read(quitStoreProvider.notifier).replaceForTest(journey);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    container.read(routerProvider).go(Routes.home);
    await tester.pumpAndSettle();
    return (container, analytics);
  }

  /// Lets a snack's own close timer run out, so the test ends with none
  /// pending (`showLpSnack` force-closes at its duration plus a beat).
  Future<void> snackGone(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  }

  DayLog? todayLog(ProviderContainer c) =>
      c.read(quitStoreProvider)!.days[today];

  testWidgets('the main button is the confirmation, not a puff', (
    tester,
  ) async {
    await home(tester, coldTurkey(3));

    expect(find.text(l10n.homeStillVapeFree), findsOneWidget);
    expect(find.text(l10n.homeLogPuff), findsNothing);
    expect(find.text(l10n.homeIVapedToday), findsOneWidget);
    // One confirmation on the screen, not the button and the old card both.
    expect(find.text(l10n.homeVapeFreeCta, skipOffstage: false), findsNothing);
  });

  testWidgets('a clean zero day is not described as a tight one', (
    tester,
  ) async {
    await home(tester, coldTurkey(3));

    expect(find.text(l10n.homeZeroDayOpen), findsOneWidget);
    expect(find.text(l10n.homeLeftTight(0)), findsNothing);
    expect(find.text(l10n.homeLeftAhead(0)), findsNothing);
    expect(find.text(l10n.homeOfLimit(0)), findsNothing);
  });

  testWidgets('confirming marks the day, once, and the button rests', (
    tester,
  ) async {
    final (c, analytics) = await home(tester, coldTurkey(3));

    await tester.tap(find.text(l10n.homeStillVapeFree));
    await tester.pumpAndSettle();

    expect(todayLog(c)!.vapeFreeConfirmed, isTrue);
    expect(todayLog(c)!.puffs, 0);
    expect(find.text(l10n.homeVapeFreeToday), findsOneWidget);
    expect(find.text(l10n.homeStillVapeFree), findsNothing);
    expect(find.text(l10n.homeZeroDayDone), findsOneWidget);
    expect(analytics.propsOfAll('day_confirmed'), [
      {'day': 'today', 'zero_day': 'true'},
    ]);

    // Resting, not a second confirmation waiting to be tapped.
    await tester.tap(find.text(l10n.homeVapeFreeToday));
    await tester.pumpAndSettle();
    expect(analytics.propsOfAll('day_confirmed'), hasLength(1));
    // And the truth can still be told afterwards.
    expect(find.text(l10n.homeIVapedToday), findsOneWidget);
    await snackGone(tester);
  });

  testWidgets('"I vaped" is one puff, and the ordinary button comes back', (
    tester,
  ) async {
    final (c, _) = await home(tester, coldTurkey(3));

    await tester.tap(find.text(l10n.homeIVapedToday));
    await tester.pumpAndSettle();

    expect(todayLog(c)!.puffs, 1);
    expect(find.text(l10n.homeLogPuff), findsOneWidget);
    expect(find.text(l10n.homeStillVapeFree), findsNothing);
    expect(find.text(l10n.homeOverLimitTitle), findsOneWidget);
    await snackGone(tester);
  });

  testWidgets('time since the last puff is shown when one is known', (
    tester,
  ) async {
    await home(
      tester,
      coldTurkey(3, lastPuffAt: now.subtract(const Duration(hours: 52))),
    );

    expect(find.text(l10n.homeVapeFreeFor('2d')), findsOneWidget);
  });

  testWidgets('and never invented when none is', (tester) async {
    await home(tester, coldTurkey(3));

    expect(find.textContaining('vape-free for'), findsNothing);
  });

  testWidgets('every zero-limit day gets it: after Freedom Day too', (
    tester,
  ) async {
    // A finished 30-day taper, three days on. Not cold turkey; still zero.
    await home(tester, journeyOnDay(33, now: now));

    expect(find.text(l10n.homeStillVapeFree), findsOneWidget);
    expect(find.text(l10n.homeLogPuff), findsNothing);
  });

  testWidgets('a day with a limit is exactly as it was', (tester) async {
    await home(tester, journeyOnDay(5, now: now));

    expect(find.text(l10n.homeLogPuff), findsOneWidget);
    expect(find.text(l10n.homeStillVapeFree), findsNothing);
    expect(find.text(l10n.homeZeroDayOpen), findsNothing);
  });

  testWidgets('and still gets its evening confirm card', (tester) async {
    final evening = DateTime(2026, 11, 12, 21, 5);
    final j = journeyOnDay(5, now: evening);
    // The mood prompt would take the card slot at this hour; a mood already
    // checked in keeps this test about the confirm card.
    final key = JourneyState.dateKey(evening);
    final withMood = j.copyWith(
      days: {
        ...j.days,
        key: DayLog(date: key, puffs: 0, limit: j.limitOn(key), mood: Mood.okay),
      },
    );
    await home(tester, withMood, at: evening);

    expect(find.text(l10n.homeVapeFreeCta, skipOffstage: false), findsOneWidget);
    expect(find.text(l10n.homeLogPuff), findsOneWidget);
  });
}
