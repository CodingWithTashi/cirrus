import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/app/theme/lp_theme.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/features/onboarding/onboarding_flow.dart';
import 'package:last_puff/features/onboarding/onboarding_view_model.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// docs/15 QP-A8. Three screens offer a plan length — onboarding, "Start a new
/// plan" and the Adjust sheet — and each used to carry its own copy of
/// `[14, 21, 30, 60, 90]`. All three read `PlanPaces` now, so a length cannot
/// be on offer in one place and gone in another.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  final now = DateTime(2026, 11, 12, 10, 15);

  void ignoreFontWidthOverflow() {
    final prior = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('overflowed')) return;
      prior?.call(details);
    };
    addTearDown(() => FlutterError.onError = prior);
  }

  /// The chip for [days]. A selected chip reads "30 ✓" on some screens, so
  /// an exact-text match would miss exactly the one that is selected.
  Finder chip(Finder within, int days) => find.descendant(
    of: within,
    matching: find.byWidgetPredicate(
      (w) => w is Text && (w.data == '$days' || w.data == '$days ✓'),
    ),
  );

  void expectFourChips(Finder within) {
    for (final p in [14, 21, 30, 42]) {
      expect(chip(within, p), findsOneWidget, reason: 'the $p-day choice');
    }
    for (final retired in [60, 90]) {
      expect(
        chip(within, retired),
        findsNothing,
        reason: 'the retired $retired-day choice',
      );
    }
  }

  testWidgets('onboarding offers 14, 21, 30 and 42', (tester) async {
    ignoreFontWidthOverflow();
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(overrides: fastBackendOverrides());
    addTearDown(container.dispose);
    container.read(onboardingProvider.notifier).previewStep(ObStep.pace);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: LpTheme.midnight(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const OnboardingFlow(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expectFourChips(find.byType(Scaffold));
  });

  Future<ProviderContainer> openApp(WidgetTester tester) async {
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
    container
        .read(quitStoreProvider.notifier)
        .replaceForTest(journeyOnDay(10, now: now));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('Start a new plan offers 14, 21, 30 and 42', (tester) async {
    final container = await openApp(tester);
    unawaited(container.read(routerProvider).push(Routes.planNew));
    await tester.pumpAndSettle();

    expectFourChips(find.byType(Scaffold).last);
  });

  testWidgets('the Adjust sheet offers 14, 21, 30 and 42', (tester) async {
    final container = await openApp(tester);
    unawaited(container.read(routerProvider).push(Routes.plan));
    await tester.pumpAndSettle();

    // The Plan screen is not scrollable, so the CTA is simply on screen.
    await tester.tap(find.text(l10n.planAdjustCta));
    await tester.pumpAndSettle();

    expectFourChips(find.byType(BottomSheet));
  });
}
