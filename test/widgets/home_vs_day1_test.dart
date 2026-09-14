import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/app/theme/lp_colors.dart';
import 'package:last_puff/core/utils/lp_format.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// Home's "vs day 1" chip (docs/10 §41): the latest confirmed day against day
/// one, in ember when it went up, and absent when there is nothing honest to
/// compare.
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

  final now = DateTime(2026, 9, 13, 10);

  Future<void> pumpHome(WidgetTester tester, JourneyState journey) async {
    ignoreFontWidthOverflow();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
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
    container.read(quitStoreProvider.notifier).replaceForTest(journey);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    container.read(routerProvider).go(Routes.home);
    await tester.pumpAndSettle();
  }

  Color? colorOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style?.color;

  testWidgets('more puffs than day one reads in ember, not in volt', (
    tester,
  ) async {
    await pumpHome(
      tester,
      journeyOnDay(5, now: now, puffsByDay: {1: 50, 4: 60}),
    );
    final chip = l10n.homeVsDay1(LpFormat.signedPercent(20));
    final lp = tester.element(find.text(chip)).lp;

    expect(colorOf(tester, chip), lp.emberText);
  });

  testWidgets('fewer puffs than day one reads in volt', (tester) async {
    await pumpHome(
      tester,
      journeyOnDay(5, now: now, puffsByDay: {1: 100, 4: 60}),
    );
    final chip = l10n.homeVsDay1(LpFormat.signedPercent(-40));
    final lp = tester.element(find.text(chip)).lp;

    expect(colorOf(tester, chip), lp.voltText);
  });

  testWidgets('an unlogged yesterday is skipped, never shown as -100%', (
    tester,
  ) async {
    final base = journeyOnDay(5, now: now, puffsByDay: {1: 100, 3: 70});
    final dayFour = LpDate.addDays(base.plan.startDate, 3);
    await pumpHome(
      tester,
      base.copyWith(
        days: {
          ...base.days,
          dayFour: DayLog(date: dayFour, puffs: 0, limit: 80),
        },
      ),
    );

    expect(
      find.text(l10n.homeVsDay1(LpFormat.signedPercent(-100))),
      findsNothing,
    );
    expect(
      find.text(l10n.homeVsDay1(LpFormat.signedPercent(-30))),
      findsOneWidget,
    );
  });

  testWidgets('day two has nothing to compare yet, so there is no chip', (
    tester,
  ) async {
    await pumpHome(tester, journeyOnDay(2, now: now, puffsByDay: {1: 80}));

    expect(find.textContaining('%'), findsNothing);
  });
}
