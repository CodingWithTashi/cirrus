import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// The health timeline, anchored to the last logged puff.
///
/// It read `DateTime.now()` in build — untestable, and frozen for as long as
/// the screen stayed alive — and with no puff on record it said "0m ago"
/// about a puff that never happened. It had no test at all.
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

  final start = DateTime(2026, 9, 7, 16);

  Future<(ProviderContainer, void Function(DateTime))> openHealth(
    WidgetTester tester, {
    required DateTime? lastPuffAt,
  }) async {
    ignoreFontWidthOverflow();
    var now = start;
    final container = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(),
        nowProvider.overrideWithValue(() => now),
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
      journeyOnDay(3, now: now, lastPuffAt: lastPuffAt),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    unawaited(container.read(routerProvider).push(Routes.health));
    await tester.pumpAndSettle();
    return (container, (t) => now = t);
  }

  testWidgets('eight hours in: the 12-hour node is next, and the clock moves', (
    tester,
  ) async {
    final (container, setNow) = await openHealth(
      tester,
      lastPuffAt: start.subtract(const Duration(hours: 8, minutes: 20)),
    );
    expect(find.text(l10n.healthAnchor('8h')), findsOneWidget);
    expect(find.text(l10n.healthYouAreHere(l10n.healthM12h)), findsOneWidget);
    expect(find.text(l10n.healthM8h), findsOneWidget, reason: 'done, plain');

    // Four hours later the minute clock ticks and the next node is reached.
    // (The tick itself is pinned off under test; a rebuild of the clock
    // provider is what a tick does.)
    setNow(start.add(const Duration(hours: 4)));
    container.invalidate(minuteClockProvider);
    await tester.pumpAndSettle();
    expect(find.text(l10n.healthAnchor('12h')), findsOneWidget);
    expect(find.text(l10n.healthYouAreHere(l10n.healthM24h)), findsOneWidget);
  });

  testWidgets('a week in, hours past 24 stay hours and the node is 2 weeks', (
    tester,
  ) async {
    await openHealth(
      tester,
      lastPuffAt: start.subtract(const Duration(days: 7, hours: 1)),
    );
    expect(find.text(l10n.healthAnchor('169h')), findsOneWidget);
    expect(find.text(l10n.healthYouAreHere(l10n.healthM2w)), findsOneWidget);
  });

  testWidgets('with no puff on record it says so, never "0m ago"', (
    tester,
  ) async {
    await openHealth(tester, lastPuffAt: null);
    expect(find.text(l10n.healthAnchorNone), findsOneWidget);
    expect(find.text(l10n.healthAnchor('0m')), findsNothing);
  });
}
