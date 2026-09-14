import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/features/money/savings_info.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// The (i) beside "saved so far" (docs/10 §40).
///
/// A day counts toward savings only once it is confirmed, so a new account
/// reads $0 all morning and its first puff then adds nearly a whole usual day.
/// Correct, and baffling with nothing to explain it. The plan is the helper's:
/// 100 puffs a day at $30 a week — a usual day costs $4.29.
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

  /// Sun Sep 13 2026, 10 AM — day one, nothing logged.
  final now = DateTime(2026, 9, 13, 10);

  Future<ProviderContainer> pumpHome(WidgetTester tester) async {
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
    container
        .read(quitStoreProvider.notifier)
        .replaceForTest(journeyOnDay(1, now: now));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(container.read(routerProvider).state.uri.path, Routes.home);
    return container;
  }

  Future<void> openInfo(WidgetTester tester) async {
    await tester.tap(find.byType(SavingsInfoButton).last);
    await tester.pumpAndSettle();
    expect(find.text(l10n.savingsInfoTitle), findsOneWidget);
  }

  testWidgets('before the first puff, the (i) says why today adds nothing', (
    tester,
  ) async {
    final container = await pumpHome(tester);
    await openInfo(tester);

    expect(find.text(l10n.savingsInfoTodayNotCounted), findsOneWidget);
    expect(find.text(l10n.savingsInfoWhyNotCounted), findsOneWidget);
    expect(
      find.text(l10n.savingsInfoUsualDayValue(100, r'$4.29')),
      findsOneWidget,
    );
    expect(find.text(r'$0.00'), findsOneWidget, reason: 'saved so far');
    expect(
      container.read(routerProvider).state.uri.path,
      Routes.home,
      reason: 'the (i) explains; it does not open Money',
    );
  });

  testWidgets('after a puff, the same (i) shows the math', (tester) async {
    final container = await pumpHome(tester);
    container.read(quitStoreProvider.notifier).logPuff(count: 12);
    await tester.pumpAndSettle();
    await openInfo(tester);

    // (100 − 12) × $30 / 700 = $3.77 kept today — on day one, the total.
    expect(find.text(l10n.savingsInfoTodayValue(12, r'$3.77')), findsOneWidget);
    expect(
      // A puff here is 4.3 cents, so the sheet prices ten of them: "about
      // $0.04" times 88 would not add up to the $3.77 beside it.
      find.text(l10n.savingsInfoWhyKeptPerTen(100, r'$0.43', 88)),
      findsOneWidget,
    );
    expect(find.text(r'$3.77'), findsOneWidget, reason: 'saved so far');
  });

  testWidgets('at or over the usual day, it says nothing is kept', (
    tester,
  ) async {
    final container = await pumpHome(tester);
    container.read(quitStoreProvider.notifier).logPuff(count: 100);
    await tester.pumpAndSettle();
    await openInfo(tester);

    expect(find.text(l10n.savingsInfoWhyNothingKept(100)), findsOneWidget);
  });

  testWidgets('Money carries the same (i), opening the same sheet', (
    tester,
  ) async {
    final container = await pumpHome(tester);
    unawaited(container.read(routerProvider).push(Routes.money));
    await tester.pumpAndSettle();
    await openInfo(tester);

    expect(find.text(l10n.savingsInfoWhyNotCounted), findsOneWidget);
  });
}
