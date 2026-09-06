import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/core/utils/lp_format.dart';
import 'package:last_puff/core/widgets/progress_ring.dart';
import 'package:last_puff/core/widgets/rolling_number.dart';
import 'package:last_puff/data/api/widget_store.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/data/stores/widget_coordinator.dart';
import 'package:last_puff/data/stores/widget_mirror.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// Home across midnight, RENDERED — `midnight_rollover_test.dart` pins the
/// day clock and the snapshot at container level; this is the header, the
/// line, the ring, the streak pill and the widget mirror turning over on
/// screen, and the day editor keeping its day when the clock moves under it.
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

  final beforeMidnight = DateTime(2026, 9, 5, 23, 59, 30);
  final afterMidnight = DateTime(2026, 9, 6, 0, 0, 30);

  /// Home on day 2 at 23:59:30, with a mutable clock the test moves.
  Future<(ProviderContainer, MemoryWidgetStore, void Function(DateTime))> open(
    WidgetTester tester,
  ) async {
    ignoreFontWidthOverflow();
    var now = beforeMidnight;
    final store = MemoryWidgetStore();
    final container = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(),
        nowProvider.overrideWithValue(() => now),
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
    container.read(quitStoreProvider.notifier).replaceForTest(
      journeyOnDay(2, now: now, puffsByDay: {1: 36}),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    container.read(routerProvider).go(Routes.home);
    await tester.pumpAndSettle();
    return (container, store, (t) => now = t);
  }

  Finder ring(int value) => find.byWidgetPredicate(
    (w) => w is RollingNumber && w.format == null && w.value == value,
  );

  testWidgets('the header, line, ring, streak and widget all turn over', (
    tester,
  ) async {
    final (container, store, setNow) = await open(tester);
    expect(
      find.text(l10n.homeGreetingDate(LpFormat.weekdayDate(beforeMidnight, 'en'), 2, 30)),
      findsOneWidget,
    );
    expect(find.text(l10n.homeOfLimit(90)), findsOneWidget);

    // One puff before bed, so day 2 is a confirmed day the streak can count.
    await tester.tap(find.text(l10n.homeLogPuff));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(ring(1), findsWidgets);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    // Midnight. The day clock's resume hook is what a frozen Android process
    // has left; the timer is pinned off under test.
    setNow(afterMidnight);
    container.read(dayClockProvider.notifier).refresh();
    await tester.pumpAndSettle();

    expect(
      find.text(l10n.homeGreetingDate(LpFormat.weekdayDate(afterMidnight, 'en'), 3, 30)),
      findsOneWidget,
    );
    expect(find.text(l10n.homeOfLimit(85)), findsOneWidget, reason: 'day 3 of the curve');
    expect(ring(0), findsWidgets, reason: 'a new day starts at zero');
    expect(ring(1), findsNothing);
    expect(find.text(l10n.homeStreakChip(2)), findsOneWidget, reason: 'days 1 and 2 held');
    expect(find.text(l10n.homeLeftAhead(85)), findsOneWidget);

    final mirror = jsonDecode(store.values[WidgetMirror.key]!) as Map<String, dynamic>;
    expect(mirror['dayNumber'], 3);
    expect(mirror['puffs'], 0);
    expect(mirror['limit'], 85);
    expect(mirror['dayKey'], '2026-09-06');
  });

  testWidgets('a day editor opened before midnight still edits that day', (
    tester,
  ) async {
    // `edit_day_sheet` read `DateTime.now()` at save time. Opened at 23:59
    // for today and saved at 00:00, it decided "not today" and routed through
    // `editPastDay` — which is the RIGHT day, but only because that path
    // takes the sheet's own date; this pins that the count lands on Sep 5
    // and never on Sep 6.
    final (container, _, setNow) = await open(tester);
    await tester.tap(find.byType(ProgressRing));
    await tester.pumpAndSettle();
    expect(find.text(l10n.statsEditDayNote), findsOneWidget);

    setNow(afterMidnight);
    // The sheet's own stepper — the tab bar's quick-log "+" shares the icon.
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byIcon(Icons.add_rounded),
      ),
    );
    await tester.pump();
    await tester.tap(find.text(l10n.commonSave));
    await tester.pumpAndSettle();

    final days = container.read(quitStoreProvider)!.days;
    expect(days[DateTime(2026, 9, 5)]?.puffs, 1);
    expect(days[DateTime(2026, 9, 6)], isNull);
  });
}
