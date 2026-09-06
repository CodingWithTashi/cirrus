import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/core/utils/lp_format.dart';
import 'package:last_puff/core/widgets/rolling_number.dart';
import 'package:last_puff/data/api/widget_store.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/data/stores/widget_coordinator.dart';
import 'package:last_puff/data/stores/widget_mirror.dart';
import 'package:last_puff/domain/logic/taper_engine.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// Home, day by day — the headline surfaces read back from the rendered
/// tree, for every shape a plan day can take.
///
/// Sep 5 2026: the founder's Home said "Day 2 of 30 · 0 of 90 · 🔥 1 day"
/// and asked whether the day was right everywhere. It was — but nothing
/// asserted `homeGreetingDate(date, N, P)` positively for ANY N, nor the
/// "of 90", nor the ahead/tight/over line, nor that the coach header and the
/// home-screen widget read the same number. This does, for eleven days that
/// each exercise a different branch: day 1, the first rollover, the first
/// repair-token day, the taper's tail, Freedom Day and maintenance.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  /// Same rule as `screen_layout_test`: the fallback font overflows where the
  /// device does not.
  void ignoreFontWidthOverflow() {
    final prior = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('overflowed')) return;
      prior?.call(details);
    };
    addTearDown(() => FlutterError.onError = prior);
  }

  /// Sat Sep 5 2026, 14:12 — before the 18:00 mood prompt, so Home's one
  /// optional card never competes with the assertions.
  final now = DateTime(2026, 9, 5, 14, 12);

  Future<(ProviderContainer, MemoryWidgetStore)> openHome(
    WidgetTester tester,
    int day,
  ) async {
    ignoreFontWidthOverflow();
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
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    container.read(routerProvider).go(Routes.home);
    await tester.pumpAndSettle();
    expect(find.text(l10n.homeLogPuff), findsOneWidget);
    return (container, store);
  }

  Map<String, dynamic> mirrorIn(MemoryWidgetStore store) =>
      jsonDecode(store.values[WidgetMirror.key]!) as Map<String, dynamic>;

  /// Home's status line under the ring, from the rule the screen uses.
  String statusLine(int puffs, int limit) {
    if (puffs > limit) return l10n.homeOverLimitBody;
    final left = limit - puffs;
    return left > limit * 0.25 ? l10n.homeLeftAhead(left) : l10n.homeLeftTight(left);
  }

  Finder ring(int value) => find.byWidgetPredicate(
    (w) => w is RollingNumber && w.format == null && w.value == value,
  );

  Future<void> tapLogPuff(WidgetTester tester) async {
    await tester.tap(find.text(l10n.homeLogPuff));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
  }

  /// Let the log snack's force-close fallback timer expire before teardown.
  Future<void> drainSnack(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  }

  for (final day in [1, 2, 3, 7, 8, 14, 15, 29, 30, 31, 45]) {
    testWidgets('day $day: header, line, streak, ring, coach and widget agree', (
      tester,
    ) async {
      final (container, store) = await openHome(tester, day);
      // After the app is up: date formatting needs the locale data the
      // localizations delegates load.
      final date = LpFormat.weekdayDate(now, 'en');
      final store_ = container.read(quitStoreProvider.notifier);
      final plan = container.read(quitStoreProvider)!.plan;
      final limit = day <= 30 ? TaperEngine.limitFor(plan, day) : 0;
      final snap = container.read(todayProvider)!;
      expect(snap.dayNumber, day);
      expect(snap.limit, limit);

      // The header: "Day N of 30" during the plan, Freedom Day on its last
      // day, "N days past Freedom Day" after it — never "Day 31 of 30".
      final header = day < 30
          ? l10n.homeGreetingDate(date, day, 30)
          : day == 30
          ? l10n.homeGreetingFreedomDay(date)
          : l10n.homeGreetingMaintenance(date, day - 30);
      expect(find.text(header), findsOneWidget, reason: 'day $day header');
      if (day != 30 && day != 31) {
        expect(find.text(l10n.homeGreetingDate(date, day, 30)), day < 30 ? findsOneWidget : findsNothing);
      }

      // Nothing logged yet today: 0 of the day's line, and the streak is
      // every completed day before it (an unconfirmed today anchors on
      // yesterday — "🔥 1 day" beside "Day 2 of 30" is correct).
      expect(find.text(l10n.homeOfLimit(limit)), findsOneWidget);
      expect(ring(0), findsWidgets, reason: 'the ring shows 0 puffs');
      expect(find.text(statusLine(0, limit)), findsOneWidget);
      expect(find.text(l10n.homeStreakChip(day - 1)), findsOneWidget);
      expect(find.text(l10n.homeOverLimitTitle), findsNothing);

      // A tap is one puff, and the line moves with it.
      if (limit >= 24) {
        store_.adjustToday(limit - 23);
        await tester.pumpAndSettle();
        await tapLogPuff(tester);
        expect(container.read(todayProvider)!.puffs, limit - 22);
        expect(ring(limit - 22), findsWidgets);
        expect(find.text(statusLine(limit - 22, limit)), findsOneWidget);
        expect(find.text(l10n.homeOverLimitTitle), findsNothing);
      }

      // One past the line is over, whatever the line is — including the
      // zero line of Freedom Day and every maintenance day after it.
      store_.adjustToday(limit);
      await tester.pumpAndSettle();
      await tapLogPuff(tester);
      expect(container.read(todayProvider)!.puffs, limit + 1);
      expect(ring(limit + 1), findsWidgets);
      expect(find.text(l10n.homeOverLimitTitle), findsOneWidget);
      expect(find.text(l10n.homeOverLimitBody), findsOneWidget);
      await drainSnack(tester);

      // One snapshot, three surfaces: the coach header and the home-screen
      // widget carry the number Home just rendered.
      container.read(routerProvider).go(Routes.coach);
      await tester.pumpAndSettle();
      expect(find.text(l10n.coachStatus(day)), findsOneWidget);
      final mirror = mirrorIn(store);
      expect(mirror['dayNumber'], day);
      expect(mirror['totalDays'], 30);
      expect(mirror['puffs'], limit + 1);
      expect(mirror['isOverLimit'], isTrue);
    });
  }

  testWidgets('the money tile is the engine\'s figure, rounded like Home', (
    tester,
  ) async {
    // The Sep 5 screenshot: 36 puffs on day 1 of a 100-a-day, $30-a-week
    // plan. "$3 saved so far" — the same 2.742857… the coach card now shows
    // as $3 instead of "2.74 dollars".
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
      journeyOnDay(2, now: now, puffsByDay: {1: 36}),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    container.read(routerProvider).go(Routes.home);
    await tester.pumpAndSettle();

    final snap = container.read(todayProvider)!;
    expect(snap.savedLifetime, closeTo(64 * 30 / 700, 1e-9));
    expect(find.text(r'$3'), findsOneWidget);
    expect(find.text(l10n.homeSavedSoFar), findsOneWidget);
    expect(find.text(l10n.homeStreakChip(1)), findsOneWidget);
    expect(
      find.text(l10n.homeGreetingDate(LpFormat.weekdayDate(now, 'en'), 2, 30)),
      findsOneWidget,
    );
  });
}
