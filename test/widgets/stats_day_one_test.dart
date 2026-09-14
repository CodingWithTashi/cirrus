import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/core/utils/lp_format.dart';
import 'package:last_puff/core/widgets/lp_charts.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// Stats from the first puff (docs/10 §40).
///
/// The screen held every chart behind "two days on the books", so a first day
/// with fourteen puffs logged read "Charts show up tomorrow." on the Day view
/// — whose whole subject is today — and day two read it again until its first
/// puff. When the week did appear, its bars were one `Expanded` column per day
/// of a window as long as the plan: two slabs half the card wide on day two,
/// one slab across all of it on day one. And the Day view covered 6 AM to
/// midnight, so a 2:30 AM puff counted in the total and was drawn nowhere.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  /// `flutter test` substitutes a square-glyph fallback font; overflow here
  /// says nothing about the device (see `screen_layout_test`).
  void ignoreFontWidthOverflow() {
    final prior = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('overflowed')) return;
      prior?.call(details);
    };
    addTearDown(() => FlutterError.onError = prior);
  }

  /// Sun Sep 13 2026, 2 PM.
  final now = DateTime(2026, 9, 13, 14);
  final today = LpDate.dayStart(now);

  Future<ProviderContainer> pumpStats(
    WidgetTester tester,
    JourneyState journey,
  ) async {
    ignoreFontWidthOverflow();
    // A phone-sized screen, so widths mean what they would on a device.
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
    container.read(routerProvider).go(Routes.stats);
    await tester.pumpAndSettle();
    return container;
  }

  Finder bar(DateTime date) => find.byKey(ValueKey(date));
  double heightOf(WidgetTester tester, DateTime date) =>
      tester.widget<FractionallySizedBox>(bar(date)).heightFactor!;
  Finder editableDays() => find.byWidgetPredicate(
    (w) => w is GestureDetector && w.onLongPress != null,
  );

  testWidgets('day one shows its puffs on the week, as a bar, not a slab', (
    tester,
  ) async {
    final container = await pumpStats(tester, journeyOnDay(1, now: now));
    container
        .read(quitStoreProvider.notifier)
        .logPuff(at: DateTime(2026, 9, 13, 9, 5), count: 14);
    await tester.pumpAndSettle();

    expect(find.text(l10n.statsPuffsThisWeek), findsOneWidget);
    expect(heightOf(tester, today), 1.0);
    expect(find.text('14'), findsOneWidget, reason: 'the count rides the bar');
    expect(
      tester.getSize(bar(today)).width,
      lessThanOrEqualTo(26),
      reason: 'one day must never stretch across the card',
    );
    // The rest of the first week holds its place, and only a day that has
    // happened can be long-pressed and fixed.
    expect(editableDays(), findsOneWidget);
  });

  testWidgets('each puff grows the bar and its count while you watch', (
    tester,
  ) async {
    final container = await pumpStats(tester, journeyOnDay(1, now: now));
    final store = container.read(quitStoreProvider.notifier);

    store.logPuff(at: DateTime(2026, 9, 13, 9), count: 3);
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);

    store.logPuff(at: DateTime(2026, 9, 13, 13), count: 2);
    await tester.pumpAndSettle();
    expect(find.text('5'), findsOneWidget, reason: 'no restart, no pull');
    expect(find.text('3'), findsNothing);
  });

  testWidgets('before the first puff, each view says so instead of charting', (
    tester,
  ) async {
    await pumpStats(tester, journeyOnDay(1, now: now));
    expect(find.text(l10n.statsPuffsThisWeek), findsOneWidget);
    expect(find.text(l10n.statsWindowNoPuffs), findsOneWidget);

    await tester.tap(find.text(l10n.statsRangeDay));
    await tester.pumpAndSettle();
    expect(find.text(l10n.statsDayNoPuffs), findsOneWidget);
    expect(find.byType(BarChart), findsNothing);
  });

  testWidgets('the Day view draws the whole day, 2:30 AM included', (
    tester,
  ) async {
    final container = await pumpStats(tester, journeyOnDay(1, now: now));
    final store = container.read(quitStoreProvider.notifier);
    store.logPuff(at: DateTime(2026, 9, 13, 2, 30), count: 3);
    store.logPuff(at: DateTime(2026, 9, 13, 11), count: 5);
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.statsRangeDay));
    await tester.pumpAndSettle();

    final chart = tester.widget<BarChart>(find.byType(BarChart).first);
    expect(chart.values, hasLength(8));
    expect(
      chart.values.fold<num>(0, (a, b) => a + b),
      8,
      reason: 'every logged puff is drawn',
    );
    expect(chart.values.first, 3, reason: 'midnight to 3 AM leads the day');
  });

  testWidgets('day two before its first puff still charts yesterday', (
    tester,
  ) async {
    await pumpStats(tester, journeyOnDay(2, now: now, puffsByDay: {1: 40}));
    final yesterday = LpDate.addDays(today, -1);

    expect(find.text(l10n.statsPuffsThisWeek), findsOneWidget);
    expect(heightOf(tester, yesterday), 1.0);
    expect(heightOf(tester, today), 0.04);
    expect(tester.getSize(bar(yesterday)).width, lessThanOrEqualTo(26));
    expect(editableDays(), findsNWidgets(2));
  });

  testWidgets('Month on day one is thirty slots, not one slab', (tester) async {
    final container = await pumpStats(tester, journeyOnDay(1, now: now));
    container
        .read(quitStoreProvider.notifier)
        .logPuff(at: DateTime(2026, 9, 13, 9), count: 4);
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.statsRangeMonth));
    await tester.pumpAndSettle();

    expect(find.text(l10n.statsPuffsThisMonth), findsOneWidget);
    expect(tester.getSize(bar(today)).width, lessThanOrEqualTo(9));
  });

  testWidgets('a confirmed vape-free day shows its 0; an unlogged one shows '
      'nothing', (tester) async {
    await pumpStats(
      tester,
      journeyOnDay(3, now: now, puffsByDay: {1: 12, 2: 0}),
    );
    final dayTwo = LpDate.addDays(today, -1);
    // The count rides in the same Stack as its bar.
    Finder stackOf(DateTime day) =>
        find.ancestor(of: bar(day), matching: find.byType(Stack)).first;

    expect(
      find.descendant(of: stackOf(dayTwo), matching: find.text('0')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: stackOf(today), matching: find.text('0')),
      findsNothing,
    );
  });

  testWidgets('day one does not claim a recovery from a day still going', (
    tester,
  ) async {
    final container = await pumpStats(tester, journeyOnDay(1, now: now));
    container
        .read(quitStoreProvider.notifier)
        .logPuff(at: DateTime(2026, 9, 13, 9), count: 5);
    await tester.pumpAndSettle();

    expect(find.text(l10n.statsHardDayToday), findsOneWidget);
    expect(find.textContaining('recovered'), findsNothing);
  });

  testWidgets('a lighter next day earns the recovery line', (tester) async {
    // Day one 60, day two a confirmed 40, today still open.
    await pumpStats(
      tester,
      journeyOnDay(3, now: now, puffsByDay: {1: 60, 2: 40}),
    );
    final dayOne = LpDate.addDays(today, -2);

    expect(
      find.text(l10n.statsHardDayCaptionPlain(LpFormat.weekday(dayOne, 'en'))),
      findsOneWidget,
    );
  });

  testWidgets('the Day view prints the count on each hour bucket', (
    tester,
  ) async {
    final container = await pumpStats(tester, journeyOnDay(1, now: now));
    container
        .read(quitStoreProvider.notifier)
        .logPuff(at: DateTime(2026, 9, 13, 13), count: 21);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.statsRangeDay));
    await tester.pumpAndSettle();
    expect(find.text('21'), findsOneWidget);

    container
        .read(quitStoreProvider.notifier)
        .logPuff(at: DateTime(2026, 9, 13, 13, 30));
    await tester.pumpAndSettle();
    expect(
      find.text('22'),
      findsOneWidget,
      reason: 'one bucket holding every puff must still show the new one',
    );
  });
}
